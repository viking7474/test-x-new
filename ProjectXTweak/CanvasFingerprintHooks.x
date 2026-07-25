#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "ProjectXLogging.h"
#import <objc/runtime.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate

#import "PXScope.h"
#import "PXPaths.h"
#import "PXDeviceProfileSchema.h"
#import "PXFileDebug.h"
#import <os/lock.h>

extern void PXInstallDeviceSpecUserScripts(WKUserContentController *userContentController);

// Decision and seed maps are initialized once and protected by one lock.
static os_unfair_lock gCanvasCacheLock = OS_UNFAIR_LOCK_INIT;
static NSMutableDictionary *cachedBundleDecisions = nil;
static NSMutableDictionary *noiseSeedCache = nil;
static NSTimeInterval kCacheValidityDuration = 300.0;

static void PXEnsureCanvasCache(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedBundleDecisions = [NSMutableDictionary dictionary];
        noiseSeedCache = [NSMutableDictionary dictionary];
    });
}

// Configuration for fingerprint noise
static CGFloat kNoiseIntensity = 0.02;  // Default noise intensity (2% variation)
static BOOL kConsistentNoise = YES;     // Whether to use consistent noise per session

#pragma mark - Helper Functions

// Helper: Always read enablement from profile/plist, not IdentifierManager
static BOOL isCanvasFingerprintProtectionEnabledForCurrentApp(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) return NO;
    NSArray *possiblePaths = @[@"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
                               @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
                               @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"];
    NSDictionary *settingsDict = nil;
    for (NSString *path in possiblePaths) {
        settingsDict = [NSDictionary dictionaryWithContentsOfFile:path];
        if (settingsDict) break;
    }
    if (!settingsDict) return NO;
    NSNumber *enabled = settingsDict[@"canvasFingerprintingEnabled"];
    if (!enabled) enabled = settingsDict[@"CanvasFingerprint"];
    return enabled ? [enabled boolValue] : NO;
}

static NSDictionary *PXReadCurrentDeviceIdsForFingerprint(void) {
    @try {
        NSString *deviceIDsPath = PXActiveProfileDeviceIDsPath();
        if (!deviceIDsPath.length) return nil;
        NSDictionary *deviceIDs = [NSDictionary dictionaryWithContentsOfFile:deviceIDsPath];
        return [deviceIDs isKindOfClass:[NSDictionary class]] && deviceIDs.count ? deviceIDs : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static uint32_t PXStableSeedForBundle(NSString *bundleID, NSDictionary *deviceIds) {
    // FNV-1a 32-bit
    uint32_t h = 2166136261u;
    NSString *model = PXProfileString(deviceIds[@"DeviceModel"]) ?: @"";
    NSString *build = PXProfileString(deviceIds[@"IOSBuild"]) ?: @"";
    NSString *s = [NSString stringWithFormat:@"%@|%@|%@", bundleID ?: @"", model, build];
    NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        h ^= bytes[i];
        h *= 16777619u;
    }
    if (h == 0) h = 1;
    return h;
}

static BOOL PXParseResolutionString(NSString *res, NSInteger *outW, NSInteger *outH) {
    if (!outW || !outH) return NO;
    *outW = 0; *outH = 0;
    if (![res isKindOfClass:[NSString class]] || res.length == 0) return NO;
    NSArray *parts = [res componentsSeparatedByString:@"x"];
    if (parts.count != 2) return NO;
    NSInteger w = [parts[0] integerValue];
    NSInteger h = [parts[1] integerValue];
    if (w <= 0 || h <= 0) return NO;
    *outW = w; *outH = h;
    return YES;
}

static NSString *PXBuildWebScreenSpoofScript(NSDictionary *deviceIds) {
    if (!PXDisplayWebScreenSpoofEnabled()) return nil;

    NSString *viewportRes = PXProfileString(deviceIds[@"ViewportResolution"]);
    NSString *screenRes = PXProfileString(deviceIds[@"ScreenResolution"]);
    NSNumber *dprNum = PXProfilePositiveNumber(deviceIds[@"DevicePixelRatio"]);
    CGFloat dpr = dprNum ? [dprNum floatValue] : 0.0;
    if (dpr <= 0.0) dpr = 1.0;

    NSInteger vwPx = 0, vhPx = 0;
    if (!PXParseResolutionString(viewportRes, &vwPx, &vhPx)) {
        return nil;
    }

    NSInteger swPx = 0, shPx = 0;
    BOOL hasScreenRes = PXParseResolutionString(screenRes, &swPx, &shPx);

    // Some profiles store ViewportResolution in CSS pixels/points (e.g. 375x812) instead of hardware pixels.
    // If we divide by DPR again, we end up with tiny values like 125x271.
    BOOL viewportIsPoints = NO;
    if (hasScreenRes) {
        NSInteger screenMax = MAX(swPx, shPx);
        NSInteger viewportMax = MAX(vwPx, vhPx);
        if (screenMax > 1500 && viewportMax > 0 && viewportMax < 1500) {
            viewportIsPoints = YES;
        }
    }

    // Convert to CSS pixels/points.
    NSInteger wPt = viewportIsPoints ? vwPx : (NSInteger)llround((double)vwPx / (double)dpr);
    NSInteger hPt = viewportIsPoints ? vhPx : (NSInteger)llround((double)vhPx / (double)dpr);

    // Normalize to portrait-style reporting for consistency.
    NSInteger sw = MIN(wPt, hPt);
    NSInteger sh = MAX(wPt, hPt);

    return [NSString stringWithFormat:
            @"(function(){try{\n"
             "if(window.__weaponx_screen_spoof__)return;\n"
             "window.__weaponx_screen_spoof__=true;\n"
             "const dpr=%.6g;const sw=%ld;const sh=%ld;\n"
             "function def(obj,prop,val){try{Object.defineProperty(obj,prop,{get:function(){return val;},configurable:true});}catch(e){}}\n"
             "def(window,'devicePixelRatio',dpr);\n"
             "try{if(window.screen){def(screen,'width',sw);def(screen,'height',sh);def(screen,'availWidth',sw);def(screen,'availHeight',sh);} }catch(e){}\n"
             "def(window,'innerWidth',sw);def(window,'innerHeight',sh);\n"
             "def(window,'outerWidth',sw);def(window,'outerHeight',sh);\n"
             "try{if(window.visualViewport){def(visualViewport,'width',sw);def(visualViewport,'height',sh);def(visualViewport,'scale',1);} }catch(e){}\n"
             "}catch(e){}})();",
            dpr, (long)sw, (long)sh];
}

static NSString *PXJavaScriptJSONStringLiteral(NSString *value) {
    NSString *safeValue = [value isKindOfClass:[NSString class]] ? value : @"";
    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[safeValue]
                                                   options:0
                                                     error:&serializationError];
    if (!data || serializationError) return @"\"\"";
    NSString *arrayLiteral = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (arrayLiteral.length < 2 || ![arrayLiteral hasPrefix:@"["] || ![arrayLiteral hasSuffix:@"]"]) {
        return @"\"\"";
    }
    NSString *literal = [arrayLiteral substringWithRange:NSMakeRange(1, arrayLiteral.length - 2)];
    unichar lineSeparator = 0x2028;
    unichar paragraphSeparator = 0x2029;
    NSString *lineSeparatorString = [NSString stringWithCharacters:&lineSeparator length:1];
    NSString *paragraphSeparatorString = [NSString stringWithCharacters:&paragraphSeparator length:1];
    literal = [literal stringByReplacingOccurrencesOfString:lineSeparatorString withString:@"\\u2028"];
    literal = [literal stringByReplacingOccurrencesOfString:paragraphSeparatorString withString:@"\\u2029"];
    return literal;
}

static NSString *PXJavaScriptNullableStringLiteral(NSString *value) {
    return value.length ? PXJavaScriptJSONStringLiteral(value) : @"null";
}

static NSString *PXBuildSeededFingerprintProtectionScript(NSString *bundleID) {
    NSDictionary *deviceIds = PXReadCurrentDeviceIdsForFingerprint();
    if (!deviceIds) return nil;

    uint32_t seed = PXStableSeedForBundle(bundleID, deviceIds);

    NSDictionary *webGLInfo = PXWebGLInfoFromDeviceIDs(deviceIds);
    NSString *webGLVendor = PXProfileString(webGLInfo[PXWebGLVendorKey]);
    NSString *webGLRenderer = PXProfileString(webGLInfo[PXWebGLRendererKey]);
    NSString *webGLVersion = PXProfileString(webGLInfo[PXWebGLVersionKey]);
    NSString *unmaskedVendor = PXProfileString(webGLInfo[PXWebGLUnmaskedVendorKey]);
    NSString *unmaskedRenderer = PXProfileString(webGLInfo[PXWebGLUnmaskedRendererKey]);
    NSNumber *maxTextureSize = PXProfilePositiveNumber(webGLInfo[PXWebGLMaxTextureSizeKey]);
    NSNumber *maxRenderbufferSize = PXProfilePositiveNumber(webGLInfo[PXWebGLMaxRenderbufferSizeKey]);

    NSString *webGLVendorLiteral = PXJavaScriptNullableStringLiteral(webGLVendor);
    NSString *webGLRendererLiteral = PXJavaScriptNullableStringLiteral(webGLRenderer);
    NSString *webGLVersionLiteral = PXJavaScriptNullableStringLiteral(webGLVersion);
    NSString *unmaskedVendorLiteral = PXJavaScriptNullableStringLiteral(unmaskedVendor);
    NSString *unmaskedRendererLiteral = PXJavaScriptNullableStringLiteral(unmaskedRenderer);
    NSString *maxTextureSizeLiteral = maxTextureSize ? [maxTextureSize stringValue] : @"null";
    NSString *maxRenderbufferSizeLiteral = maxRenderbufferSize ? [maxRenderbufferSize stringValue] : @"null";
    NSString *script =
        @"(function () {\n"
         "    \"use strict\";\n"
         "    const __wxRoot = typeof globalThis !== \"undefined\" ? globalThis :\n"
         "        (typeof self !== \"undefined\" ? self : (typeof window !== \"undefined\" ? window : this));\n"
         "\n"
         "    function __wxInstallMainFailClosed(g) {\n"
         "        if (!g) return;\n"
         "        const message = \"Fingerprint protection failed closed because complete surface coverage was unavailable\";\n"
         "        function blocked() { throw new TypeError(message); }\n"
         "        function replace(target, name, value) {\n"
         "            if (!target) return false;\n"
         "            try {\n"
         "                Object.defineProperty(target, name, {\n"
         "                    value: value,\n"
         "                    configurable: false,\n"
         "                    writable: false\n"
         "                });\n"
         "                return true;\n"
         "            } catch (_) {\n"
         "                try {\n"
         "                    target[name] = value;\n"
         "                    return target[name] === value;\n"
         "                } catch (_) {\n"
         "                    return false;\n"
         "                }\n"
         "            }\n"
         "        }\n"
         "        function blockContextFactory(proto) {\n"
         "            if (!proto || typeof proto.getContext !== \"function\") return;\n"
         "            const originalGetContext = proto.getContext;\n"
         "            replace(proto, \"getContext\", function (type) {\n"
         "                const key = String(type == null ? \"\" : type).toLowerCase();\n"
         "                if (key === \"2d\" || key === \"webgl\" || key === \"webgl2\" || key === \"experimental-webgl\") {\n"
         "                    throw new TypeError(message);\n"
         "                }\n"
         "                return originalGetContext.apply(this, arguments);\n"
         "            });\n"
         "        }\n"
         "        try {\n"
         "            Object.defineProperty(g, \"__weaponx_fp_spoof_failed__\", {\n"
         "                value: true,\n"
         "                configurable: false,\n"
         "                enumerable: false,\n"
         "                writable: false\n"
         "            });\n"
         "        } catch (_) {}\n"
         "        if (g.HTMLCanvasElement && g.HTMLCanvasElement.prototype) {\n"
         "            blockContextFactory(g.HTMLCanvasElement.prototype);\n"
         "            replace(g.HTMLCanvasElement.prototype, \"toDataURL\", blocked);\n"
         "            replace(g.HTMLCanvasElement.prototype, \"toBlob\", blocked);\n"
         "        }\n"
         "        if (g.CanvasRenderingContext2D && g.CanvasRenderingContext2D.prototype) {\n"
         "            replace(g.CanvasRenderingContext2D.prototype, \"getImageData\", blocked);\n"
         "            replace(g.CanvasRenderingContext2D.prototype, \"measureText\", blocked);\n"
         "        }\n"
         "        if (g.OffscreenCanvas && g.OffscreenCanvas.prototype) {\n"
         "            blockContextFactory(g.OffscreenCanvas.prototype);\n"
         "            replace(g.OffscreenCanvas.prototype, \"convertToBlob\", blocked);\n"
         "            replace(g.OffscreenCanvas.prototype, \"transferToImageBitmap\", blocked);\n"
         "        }\n"
         "        [g.WebGLRenderingContext, g.WebGL2RenderingContext].forEach(function (constructorValue) {\n"
         "            const proto = constructorValue && constructorValue.prototype;\n"
         "            replace(proto, \"getParameter\", blocked);\n"
         "            replace(proto, \"getSupportedExtensions\", blocked);\n"
         "            replace(proto, \"getShaderPrecisionFormat\", blocked);\n"
         "            replace(proto, \"readPixels\", blocked);\n"
         "        });\n"
         "        if (g.AnalyserNode && g.AnalyserNode.prototype) {\n"
         "            replace(g.AnalyserNode.prototype, \"getFloatFrequencyData\", blocked);\n"
         "        }\n"
         "        if (g.AudioBuffer && g.AudioBuffer.prototype) {\n"
         "            replace(g.AudioBuffer.prototype, \"getChannelData\", blocked);\n"
         "        }\n"
         "        if (g.navigator && g.navigator.fonts) {\n"
         "            replace(g.navigator.fonts, \"query\", blocked);\n"
         "        }\n"
         "        [\"Worker\", \"SharedWorker\"].forEach(function (name) {\n"
         "            if (typeof g[name] === \"function\") replace(g, name, blocked);\n"
         "        });\n"
         "        if (g.ServiceWorker && g.ServiceWorker.prototype) {\n"
         "            replace(g.ServiceWorker.prototype, \"postMessage\", blocked);\n"
         "        }\n"
         "        const serviceWorkerContainer = g.navigator && g.navigator.serviceWorker;\n"
         "        if (serviceWorkerContainer) {\n"
         "            const proto = Object.getPrototypeOf(serviceWorkerContainer);\n"
         "            replace(proto, \"register\", function () {\n"
         "                return typeof Promise === \"function\" ? Promise.reject(new TypeError(message)) : undefined;\n"
         "            });\n"
         "            replace(proto, \"addEventListener\", blocked);\n"
         "            replace(proto, \"startMessages\", blocked);\n"
         "            try {\n"
         "                Object.defineProperty(serviceWorkerContainer, \"onmessage\", {\n"
         "                    get: function () { return null; },\n"
         "                    set: blocked,\n"
         "                    configurable: false\n"
         "                });\n"
         "            } catch (_) {}\n"
         "        }\n"
         "    }\n"
         "\n"
         "    try {\n"
         "        function __wxInstallScope(g, baseSeed, webGLVendor, webGLRenderer, webGLVersion, unmaskedVendor, unmaskedRenderer, maxTextureSize, maxRenderbufferSize) {\n"
         "            if (!g || g.__weaponx_fp_spoof__) return;\n"
         "            try {\n"
         "                Object.defineProperty(g, \"__weaponx_fp_spoof__\", {\n"
         "                    value: true,\n"
         "                    configurable: false,\n"
         "                    enumerable: false,\n"
         "                    writable: false\n"
         "                });\n"
         "            } catch (_) {\n"
         "                g.__weaponx_fp_spoof__ = true;\n"
         "            }\n"
         "\n"
         "            baseSeed = (baseSeed >>> 0) || 1;\n"
         "            const __wxNoiseRate = 0.02;\n"
         "            const __wx2DOriginals = [];\n"
         "            const __wxAudioChannelCache = typeof WeakMap === \"function\" ? new WeakMap() : null;\n"
         "\n"
         "            function __wxMix32(hash, value) {\n"
         "                hash ^= value >>> 0;\n"
         "                return Math.imul(hash, 16777619) >>> 0;\n"
         "            }\n"
         "\n"
         "            function __wxHashString(value, seed) {\n"
         "                const text = String(value == null ? \"\" : value);\n"
         "                let hash = (seed >>> 0) || 2166136261;\n"
         "                hash = __wxMix32(hash, text.length);\n"
         "                for (let index = 0; index < text.length; index++) {\n"
         "                    const code = text.charCodeAt(index);\n"
         "                    hash = __wxMix32(hash, code & 255);\n"
         "                    hash = __wxMix32(hash, code >>> 8);\n"
         "                }\n"
         "                return hash || 1;\n"
         "            }\n"
         "\n"
         "            function __wxHashBytes(bytes, seed) {\n"
         "                let hash = (seed >>> 0) || 2166136261;\n"
         "                hash = __wxMix32(hash, bytes.length);\n"
         "                for (let index = 0; index < bytes.length; index++) {\n"
         "                    hash = __wxMix32(hash, bytes[index]);\n"
         "                }\n"
         "                return hash || 1;\n"
         "            }\n"
         "\n"
         "            function __wxCreatePRNG(seed) {\n"
         "                let state = (seed >>> 0) || 1;\n"
         "                return function () {\n"
         "                    state ^= state << 13;\n"
         "                    state >>>= 0;\n"
         "                    state ^= state >>> 17;\n"
         "                    state >>>= 0;\n"
         "                    state ^= state << 5;\n"
         "                    state >>>= 0;\n"
         "                    return state / 4294967296;\n"
         "                };\n"
         "            }\n"
         "\n"
         "            function __wxImageSeed(imageData, x, y, width, height) {\n"
         "                let hash = baseSeed;\n"
         "                hash = __wxMix32(hash, x | 0);\n"
         "                hash = __wxMix32(hash, y | 0);\n"
         "                hash = __wxMix32(hash, width | 0);\n"
         "                hash = __wxMix32(hash, height | 0);\n"
         "                return __wxHashBytes(imageData.data, hash);\n"
         "            }\n"
         "\n"
         "            function __wxNoiseImageData(imageData, x, y, width, height) {\n"
         "                if (!imageData || !imageData.data || imageData.data.length === 0) return imageData;\n"
         "                const random = __wxCreatePRNG(__wxImageSeed(imageData, x, y, width, height));\n"
         "                const pixels = imageData.data;\n"
         "                for (let index = 0; index < pixels.length; index += 4) {\n"
         "                    if (random() >= __wxNoiseRate) continue;\n"
         "                    const delta = random() < 0.5 ? -1 : 1;\n"
         "                    pixels[index] = Math.max(0, Math.min(255, pixels[index] + delta));\n"
         "                    pixels[index + 1] = Math.max(0, Math.min(255, pixels[index + 1] + delta));\n"
         "                    pixels[index + 2] = Math.max(0, Math.min(255, pixels[index + 2] + delta));\n"
         "                }\n"
         "                return imageData;\n"
         "            }\n"
         "\n"
         "            function __wxStableUnit(key, salt) {\n"
         "                const random = __wxCreatePRNG(__wxHashString(key, baseSeed ^ (salt >>> 0)));\n"
         "                return random();\n"
         "            }\n"
         "\n"
         "            function __wxStableSort(values, salt) {\n"
         "                return values.slice().sort(function (left, right) {\n"
         "                    const leftText = String(left);\n"
         "                    const rightText = String(right);\n"
         "                    const leftHash = __wxHashString(leftText, baseSeed ^ (salt >>> 0));\n"
         "                    const rightHash = __wxHashString(rightText, baseSeed ^ (salt >>> 0));\n"
         "                    if (leftHash !== rightHash) return leftHash < rightHash ? -1 : 1;\n"
         "                    return leftText < rightText ? -1 : leftText > rightText ? 1 : 0;\n"
         "                });\n"
         "            }\n"
         "\n"
         "            function __wxRecord2DPrototype(proto) {\n"
         "                if (!proto || typeof proto.getImageData !== \"function\") return;\n"
         "                for (let index = 0; index < __wx2DOriginals.length; index++) {\n"
         "                    if (__wx2DOriginals[index].proto === proto) return;\n"
         "                }\n"
         "                const originalGetImageData = proto.getImageData;\n"
         "                __wx2DOriginals.push({ proto: proto, getImageData: originalGetImageData });\n"
         "                proto.getImageData = function () {\n"
         "                    const imageData = originalGetImageData.apply(this, arguments);\n"
         "                    const x = Number(arguments[0]) || 0;\n"
         "                    const y = Number(arguments[1]) || 0;\n"
         "                    const width = imageData && imageData.width ? imageData.width : (Number(arguments[2]) || 0);\n"
         "                    const height = imageData && imageData.height ? imageData.height : (Number(arguments[3]) || 0);\n"
         "                    return __wxNoiseImageData(imageData, x, y, width, height);\n"
         "                };\n"
         "\n"
         "                if (typeof proto.measureText === \"function\") {\n"
         "                    const originalMeasureText = proto.measureText;\n"
         "                    proto.measureText = function (text) {\n"
         "                        const result = originalMeasureText.apply(this, arguments);\n"
         "                        try {\n"
         "                            const key = [\n"
         "                                text,\n"
         "                                this.font,\n"
         "                                this.textAlign,\n"
         "                                this.textBaseline,\n"
         "                                this.direction,\n"
         "                                result.width\n"
         "                            ].join(\"|\");\n"
         "                            const factor = 1 + (__wxStableUnit(key, 0x6d747874) - 0.5) * 0.002;\n"
         "                            Object.defineProperty(result, \"width\", {\n"
         "                                value: result.width * factor,\n"
         "                                configurable: true\n"
         "                            });\n"
         "                        } catch (_) {}\n"
         "                        return result;\n"
         "                    };\n"
         "                }\n"
         "            }\n"
         "\n"
         "            function __wxOriginalGetImageData(context, x, y, width, height) {\n"
         "                for (let index = 0; index < __wx2DOriginals.length; index++) {\n"
         "                    const entry = __wx2DOriginals[index];\n"
         "                    if (entry.proto && entry.proto.isPrototypeOf(context)) {\n"
         "                        return entry.getImageData.call(context, x, y, width, height);\n"
         "                    }\n"
         "                }\n"
         "                throw new TypeError(\"Fingerprint protection could not resolve the native 2D readback path\");\n"
         "            }\n"
         "\n"
         "            function __wxCreateCanvasLike(source) {\n"
         "                const width = Number(source && source.width) || 0;\n"
         "                const height = Number(source && source.height) || 0;\n"
         "                if (g.OffscreenCanvas && source instanceof g.OffscreenCanvas) {\n"
         "                    return new g.OffscreenCanvas(width, height);\n"
         "                }\n"
         "                if (g.document && typeof g.document.createElement === \"function\") {\n"
         "                    const canvas = g.document.createElement(\"canvas\");\n"
         "                    canvas.width = width;\n"
         "                    canvas.height = height;\n"
         "                    return canvas;\n"
         "                }\n"
         "                if (g.OffscreenCanvas) {\n"
         "                    return new g.OffscreenCanvas(width, height);\n"
         "                }\n"
         "                return null;\n"
         "            }\n"
         "\n"
         "            function __wxNoisyCanvasCopy(source) {\n"
         "                const width = Number(source && source.width) || 0;\n"
         "                const height = Number(source && source.height) || 0;\n"
         "                const copy = __wxCreateCanvasLike(source);\n"
         "                if (!copy) {\n"
         "                    throw new TypeError(\"Fingerprint protection cannot create an isolated canvas copy\");\n"
         "                }\n"
         "                if (width === 0 || height === 0) return copy;\n"
         "                const context = copy.getContext(\"2d\", { willReadFrequently: true });\n"
         "                if (!context) {\n"
         "                    throw new TypeError(\"Fingerprint protection cannot create an isolated 2D context\");\n"
         "                }\n"
         "                context.drawImage(source, 0, 0, width, height);\n"
         "                const imageData = __wxOriginalGetImageData(context, 0, 0, width, height);\n"
         "                __wxNoiseImageData(imageData, 0, 0, width, height);\n"
         "                context.putImageData(imageData, 0, 0);\n"
         "                return copy;\n"
         "            }\n"
         "\n"
         "            function __wxPatchHTMLCanvas() {\n"
         "                if (!g.HTMLCanvasElement || !g.HTMLCanvasElement.prototype) return;\n"
         "                const proto = g.HTMLCanvasElement.prototype;\n"
         "                const originalToDataURL = typeof proto.toDataURL === \"function\" ? proto.toDataURL : null;\n"
         "                const originalToBlob = typeof proto.toBlob === \"function\" ? proto.toBlob : null;\n"
         "                if (originalToDataURL) {\n"
         "                    proto.toDataURL = function () {\n"
         "                        if ((Number(this.width) || 0) === 0 || (Number(this.height) || 0) === 0) {\n"
         "                            return originalToDataURL.apply(this, arguments);\n"
         "                        }\n"
         "                        const copy = __wxNoisyCanvasCopy(this);\n"
         "                        return originalToDataURL.apply(copy, arguments);\n"
         "                    };\n"
         "                }\n"
         "                if (originalToBlob) {\n"
         "                    proto.toBlob = function () {\n"
         "                        if ((Number(this.width) || 0) === 0 || (Number(this.height) || 0) === 0) {\n"
         "                            return originalToBlob.apply(this, arguments);\n"
         "                        }\n"
         "                        const copy = __wxNoisyCanvasCopy(this);\n"
         "                        return originalToBlob.apply(copy, arguments);\n"
         "                    };\n"
         "                }\n"
         "            }\n"
         "\n"
         "            function __wxPatchOffscreenCanvas() {\n"
         "                if (!g.OffscreenCanvas || !g.OffscreenCanvas.prototype) return;\n"
         "                const proto = g.OffscreenCanvas.prototype;\n"
         "                const originalConvertToBlob = typeof proto.convertToBlob === \"function\" ? proto.convertToBlob : null;\n"
         "                const originalTransferToImageBitmap = typeof proto.transferToImageBitmap === \"function\" ? proto.transferToImageBitmap : null;\n"
         "                if (originalConvertToBlob) {\n"
         "                    proto.convertToBlob = function () {\n"
         "                        const copy = __wxNoisyCanvasCopy(this);\n"
         "                        return originalConvertToBlob.apply(copy, arguments);\n"
         "                    };\n"
         "                }\n"
         "                if (originalTransferToImageBitmap) {\n"
         "                    proto.transferToImageBitmap = function () {\n"
         "                        const protectedCopy = __wxNoisyCanvasCopy(this);\n"
         "                        if (!(protectedCopy instanceof g.OffscreenCanvas)) {\n"
         "                            throw new TypeError(\"Fingerprint protection requires an OffscreenCanvas transfer copy\");\n"
         "                        }\n"
         "                        const protectedBitmap = originalTransferToImageBitmap.call(protectedCopy);\n"
         "                        try {\n"
         "                            const discardedOriginalBitmap = originalTransferToImageBitmap.apply(this, arguments);\n"
         "                            if (discardedOriginalBitmap && typeof discardedOriginalBitmap.close === \"function\") {\n"
         "                                discardedOriginalBitmap.close();\n"
         "                            }\n"
         "                        } catch (error) {\n"
         "                            if (protectedBitmap && typeof protectedBitmap.close === \"function\") protectedBitmap.close();\n"
         "                            throw error;\n"
         "                        }\n"
         "                        return protectedBitmap;\n"
         "                    };\n"
         "                }\n"
         "            }\n"
         "\n"
         "            function __wxPatchWebGLConstructor(constructorValue, contextVersion) {\n"
         "                if (!constructorValue || !constructorValue.prototype) return;\n"
         "                const proto = constructorValue.prototype;\n"
         "                if (typeof proto.getParameter === \"function\") {\n"
         "                    const originalGetParameter = proto.getParameter;\n"
         "                    proto.getParameter = function (parameter) {\n"
         "                        if (parameter === 37445 && unmaskedVendor != null) return unmaskedVendor;\n"
         "                        if (parameter === 37446 && unmaskedRenderer != null) return unmaskedRenderer;\n"
         "                        if (parameter === 7936 && webGLVendor != null) return webGLVendor;\n"
         "                        if (parameter === 7937 && webGLRenderer != null) return webGLRenderer;\n"
         "                        if (parameter === 7938 && webGLVersion != null) return webGLVersion;\n"
         "                        if (parameter === 3379 && maxTextureSize != null) return maxTextureSize;\n"
         "                        if (parameter === 34024 && maxRenderbufferSize != null) return maxRenderbufferSize;\n"
         "                        return originalGetParameter.call(this, parameter);\n"
         "                    };\n"
         "                }\n"
         "                if (typeof proto.getSupportedExtensions === \"function\") {\n"
         "                    const originalGetSupportedExtensions = proto.getSupportedExtensions;\n"
         "                    proto.getSupportedExtensions = function () {\n"
         "                        const extensions = originalGetSupportedExtensions.call(this);\n"
         "                        return Array.isArray(extensions)\n"
         "                            ? __wxStableSort(extensions, (webGLVersion || contextVersion) === \"WebGL 2.0\" ? 0x77673265 : 0x77673165)\n"
         "                            : extensions;\n"
         "                    };\n"
         "                }\n"
         "            }\n"
         "\n"
         "            function __wxPatchAudio() {\n"
         "                if (g.AnalyserNode && g.AnalyserNode.prototype &&\n"
         "                    typeof g.AnalyserNode.prototype.getFloatFrequencyData === \"function\") {\n"
         "                    const originalGetFloatFrequencyData = g.AnalyserNode.prototype.getFloatFrequencyData;\n"
         "                    g.AnalyserNode.prototype.getFloatFrequencyData = function (array) {\n"
         "                        originalGetFloatFrequencyData.call(this, array);\n"
         "                        if (!array) return;\n"
         "                        for (let index = 0; index < array.length; index++) {\n"
         "                            const value = Number(array[index]);\n"
         "                            if (!Number.isFinite(value)) continue;\n"
         "                            const key = index + \"|\" + value.toFixed(6);\n"
         "                            array[index] = value + (__wxStableUnit(key, 0x61756466) - 0.5) * 0.1;\n"
         "                        }\n"
         "                    };\n"
         "                }\n"
         "\n"
         "                if (__wxAudioChannelCache && g.AudioBuffer && g.AudioBuffer.prototype &&\n"
         "                    typeof g.AudioBuffer.prototype.getChannelData === \"function\") {\n"
         "                    const originalGetChannelData = g.AudioBuffer.prototype.getChannelData;\n"
         "                    g.AudioBuffer.prototype.getChannelData = function (channel) {\n"
         "                        const source = originalGetChannelData.apply(this, arguments);\n"
         "                        if (!source || typeof Float32Array !== \"function\") return source;\n"
         "                        let channels = __wxAudioChannelCache.get(this);\n"
         "                        if (!channels) {\n"
         "                            channels = [];\n"
         "                            __wxAudioChannelCache.set(this, channels);\n"
         "                        }\n"
         "                        let copy = channels[channel];\n"
         "                        if (!(copy instanceof Float32Array) || copy.length !== source.length) {\n"
         "                            copy = new Float32Array(source.length);\n"
         "                            channels[channel] = copy;\n"
         "                        }\n"
         "                        copy.set(source);\n"
         "                        const bytes = new Uint8Array(source.buffer, source.byteOffset, source.byteLength);\n"
         "                        const random = __wxCreatePRNG(__wxHashBytes(bytes, baseSeed ^ ((Number(channel) || 0) + 0x61756462)));\n"
         "                        for (let index = 0; index < copy.length; index += 100) {\n"
         "                            copy[index] += (random() - 0.5) * 0.0001;\n"
         "                        }\n"
         "                        return copy;\n"
         "                    };\n"
         "                }\n"
         "            }\n"
         "\n"
         "            function __wxPatchFontQuery() {\n"
         "                const fontSet = g.navigator && g.navigator.fonts;\n"
         "                if (!fontSet || typeof fontSet.query !== \"function\") return;\n"
         "                const originalQuery = fontSet.query;\n"
         "                fontSet.query = function () {\n"
         "                    const result = originalQuery.apply(this, arguments);\n"
         "                    if (!result || typeof result.then !== \"function\") return result;\n"
         "                    return result.then(function (fonts) {\n"
         "                        return Array.isArray(fonts) ? __wxStableSort(fonts, 0x666f6e74) : fonts;\n"
         "                    });\n"
         "                };\n"
         "            }\n"
         "\n"
         "            function __wxWorkerBootstrapSource() {\n"
         "                return \"(\" + __wxInstallScope.toString() + \")((typeof globalThis!==\\\"undefined\\\"?globalThis:self),\" +\n"
         "                    (baseSeed >>> 0) + \",\" + JSON.stringify(webGLVendor) + \",\" +\n"
         "                    JSON.stringify(webGLRenderer) + \",\" + JSON.stringify(webGLVersion) + \",\" +\n"
         "                    JSON.stringify(unmaskedVendor) + \",\" + JSON.stringify(unmaskedRenderer) + \",\" +\n"
         "                    JSON.stringify(maxTextureSize) + \",\" + JSON.stringify(maxRenderbufferSize) + \");\\n\";\n"
         "            }\n"
         "\n"
         "            function __wxAbsoluteWorkerURL(url) {\n"
         "                const text = String(url);\n"
         "                if (typeof g.URL === \"function\") {\n"
         "                    const base = g.location && g.location.href ? g.location.href : undefined;\n"
         "                    return new g.URL(text, base).href;\n"
         "                }\n"
         "                return text;\n"
         "            }\n"
         "\n"
         "            function __wxCreateWorkerWrapperURL(url, options) {\n"
         "                if (typeof g.Blob !== \"function\" || !g.URL ||\n"
         "                    typeof g.URL.createObjectURL !== \"function\") {\n"
         "                    throw new TypeError(\"Fingerprint protection cannot bootstrap this worker context\");\n"
         "                }\n"
         "                const absoluteURL = __wxAbsoluteWorkerURL(url);\n"
         "                const isModule = options && options.type === \"module\";\n"
         "                let source = __wxWorkerBootstrapSource();\n"
         "                if (isModule) {\n"
         "                    source += \"import(\" + JSON.stringify(absoluteURL) + \").catch(function(error){setTimeout(function(){throw error;},0);});\\n\";\n"
         "                } else {\n"
         "                    source += \"importScripts(\" + JSON.stringify(absoluteURL) + \");\\n\";\n"
         "                }\n"
         "                return g.URL.createObjectURL(new g.Blob([source], { type: \"text/javascript\" }));\n"
         "            }\n"
         "\n"
         "            function __wxScheduleWorkerURLRevoke(url) {\n"
         "                if (!g.URL || typeof g.URL.revokeObjectURL !== \"function\") return;\n"
         "                const revoke = function () {\n"
         "                    try { g.URL.revokeObjectURL(url); } catch (_) {}\n"
         "                };\n"
         "                if (typeof g.setTimeout === \"function\") g.setTimeout(revoke, 60000);\n"
         "            }\n"
         "\n"
         "            function __wxPatchWorkerConstructor(propertyName) {\n"
         "                const OriginalWorker = g[propertyName];\n"
         "                if (typeof OriginalWorker !== \"function\") return;\n"
         "                function ProtectedWorker(url, options) {\n"
         "                    const wrapperURL = __wxCreateWorkerWrapperURL(url, options);\n"
         "                    try {\n"
         "                        const args = arguments.length > 1 ? [wrapperURL, options] : [wrapperURL];\n"
         "                        const target = new.target || ProtectedWorker;\n"
         "                        const instance = Reflect.construct(OriginalWorker, args, target);\n"
         "                        __wxScheduleWorkerURLRevoke(wrapperURL);\n"
         "                        return instance;\n"
         "                    } catch (error) {\n"
         "                        try { g.URL.revokeObjectURL(wrapperURL); } catch (_) {}\n"
         "                        throw error;\n"
         "                    }\n"
         "                }\n"
         "                try { Object.setPrototypeOf(ProtectedWorker, OriginalWorker); } catch (_) {}\n"
         "                ProtectedWorker.prototype = OriginalWorker.prototype;\n"
         "                Object.defineProperty(g, propertyName, {\n"
         "                    value: ProtectedWorker,\n"
         "                    configurable: true,\n"
         "                    writable: true\n"
         "                });\n"
         "            }\n"
         "\n"
         "            function __wxFailClosedServiceWorkers() {\n"
         "                const blockedMessage = \"ServiceWorker messaging is blocked while fingerprint protection is active\";\n"
         "                if (g.ServiceWorker && g.ServiceWorker.prototype &&\n"
         "                    typeof g.ServiceWorker.prototype.postMessage === \"function\") {\n"
         "                    try {\n"
         "                        g.ServiceWorker.prototype.postMessage = function () {\n"
         "                            throw new TypeError(blockedMessage);\n"
         "                        };\n"
         "                    } catch (_) {}\n"
         "                }\n"
         "                const container = g.navigator && g.navigator.serviceWorker;\n"
         "                if (!container) return;\n"
         "                const proto = Object.getPrototypeOf(container);\n"
         "                if (proto && typeof proto.register === \"function\") {\n"
         "                    try {\n"
         "                        proto.register = function () {\n"
         "                            const error = new TypeError(\"ServiceWorker registration is blocked while fingerprint protection is active\");\n"
         "                            return typeof Promise === \"function\" ? Promise.reject(error) : undefined;\n"
         "                        };\n"
         "                    } catch (_) {}\n"
         "                }\n"
         "                if (proto && typeof proto.addEventListener === \"function\") {\n"
         "                    const originalAddEventListener = proto.addEventListener;\n"
         "                    try {\n"
         "                        proto.addEventListener = function (type) {\n"
         "                            if (String(type) === \"message\") throw new TypeError(blockedMessage);\n"
         "                            return originalAddEventListener.apply(this, arguments);\n"
         "                        };\n"
         "                    } catch (_) {}\n"
         "                }\n"
         "                if (proto && typeof proto.startMessages === \"function\") {\n"
         "                    try {\n"
         "                        proto.startMessages = function () {\n"
         "                            throw new TypeError(blockedMessage);\n"
         "                        };\n"
         "                    } catch (_) {}\n"
         "                }\n"
         "                try {\n"
         "                    Object.defineProperty(container, \"onmessage\", {\n"
         "                        get: function () { return null; },\n"
         "                        set: function () { throw new TypeError(blockedMessage); },\n"
         "                        configurable: false\n"
         "                    });\n"
         "                } catch (_) {}\n"
         "            }\n"
         "\n"
         "            if (g.CanvasRenderingContext2D && g.CanvasRenderingContext2D.prototype) {\n"
         "                __wxRecord2DPrototype(g.CanvasRenderingContext2D.prototype);\n"
         "            }\n"
         "            if (g.OffscreenCanvas) {\n"
         "                try {\n"
         "                    const probe = new g.OffscreenCanvas(1, 1);\n"
         "                    const probeContext = probe.getContext(\"2d\");\n"
         "                    if (probeContext) __wxRecord2DPrototype(Object.getPrototypeOf(probeContext));\n"
         "                } catch (_) {}\n"
         "            }\n"
         "\n"
         "            __wxPatchHTMLCanvas();\n"
         "            __wxPatchOffscreenCanvas();\n"
         "            __wxPatchWebGLConstructor(g.WebGLRenderingContext, \"WebGL 1.0\");\n"
         "            __wxPatchWebGLConstructor(g.WebGL2RenderingContext, \"WebGL 2.0\");\n"
         "            __wxPatchAudio();\n"
         "            __wxPatchFontQuery();\n"
         "            __wxPatchWorkerConstructor(\"Worker\");\n"
         "            __wxPatchWorkerConstructor(\"SharedWorker\");\n"
         "            __wxFailClosedServiceWorkers();\n"
         "        }\n"
         "\n"
         "        __wxInstallScope(__wxRoot, __WX_BASE_SEED__, __WX_WEBGL_VENDOR_JSON__, __WX_WEBGL_RENDERER_JSON__, __WX_WEBGL_VERSION_JSON__, __WX_UNMASKED_VENDOR_JSON__, __WX_UNMASKED_RENDERER_JSON__, __WX_MAX_TEXTURE_SIZE__, __WX_MAX_RENDERBUFFER_SIZE__);\n"
         "    } catch (_) {\n"
         "        __wxInstallMainFailClosed(__wxRoot);\n"
         "    }\n"
         "})();\n";
    script = [script stringByReplacingOccurrencesOfString:@"__WX_BASE_SEED__"
                                               withString:[NSString stringWithFormat:@"%u", seed]];
    script = [script stringByReplacingOccurrencesOfString:@"__WX_WEBGL_VENDOR_JSON__"
                                               withString:webGLVendorLiteral];
    script = [script stringByReplacingOccurrencesOfString:@"__WX_WEBGL_RENDERER_JSON__"
                                               withString:webGLRendererLiteral];
    script = [script stringByReplacingOccurrencesOfString:@"__WX_WEBGL_VERSION_JSON__"
                                               withString:webGLVersionLiteral];
    script = [script stringByReplacingOccurrencesOfString:@"__WX_UNMASKED_VENDOR_JSON__"
                                               withString:unmaskedVendorLiteral];
    script = [script stringByReplacingOccurrencesOfString:@"__WX_UNMASKED_RENDERER_JSON__"
                                               withString:unmaskedRendererLiteral];
    script = [script stringByReplacingOccurrencesOfString:@"__WX_MAX_TEXTURE_SIZE__"
                                               withString:maxTextureSizeLiteral];
    script = [script stringByReplacingOccurrencesOfString:@"__WX_MAX_RENDERBUFFER_SIZE__"
                                               withString:maxRenderbufferSizeLiteral];
    return script;
}

// Update shouldProtectBundle to use only the new function
static BOOL shouldProtectBundle(NSString *bundleID) {
    if (!bundleID.length) return NO;
    PXEnsureCanvasCache();
    NSString *timestampKey = [bundleID stringByAppendingString:@"_timestamp"];
    NSDate *now = [NSDate date];

    os_unfair_lock_lock(&gCanvasCacheLock);
    NSNumber *cachedDecision = cachedBundleDecisions[bundleID];
    NSDate *decisionTimestamp = cachedBundleDecisions[timestampKey];
    BOOL valid = cachedDecision && decisionTimestamp &&
        [now timeIntervalSinceDate:decisionTimestamp] < kCacheValidityDuration;
    BOOL cachedValue = [cachedDecision boolValue];
    os_unfair_lock_unlock(&gCanvasCacheLock);
    if (valid) return cachedValue;

    BOOL shouldProtect = isCanvasFingerprintProtectionEnabledForCurrentApp() || PXFullSpoofTestModeEnabled();
    os_unfair_lock_lock(&gCanvasCacheLock);
    cachedBundleDecisions[bundleID] = @(shouldProtect);
    cachedBundleDecisions[timestampKey] = now;
    os_unfair_lock_unlock(&gCanvasCacheLock);
    return shouldProtect;
}

// Get or create a noise seed for consistent variations
static NSInteger getNoiseSeedForBundle(NSString *bundleID) {
    if (!bundleID.length) return 1;
    PXEnsureCanvasCache();
    os_unfair_lock_lock(&gCanvasCacheLock);
    NSNumber *cachedSeed = noiseSeedCache[bundleID];
    os_unfair_lock_unlock(&gCanvasCacheLock);
    if (cachedSeed) return [cachedSeed integerValue];

    NSInteger candidate = arc4random_uniform(1000000) + 1;
    os_unfair_lock_lock(&gCanvasCacheLock);
    cachedSeed = noiseSeedCache[bundleID];
    if (!cachedSeed) {
        cachedSeed = @(candidate);
        noiseSeedCache[bundleID] = cachedSeed;
    }
    os_unfair_lock_unlock(&gCanvasCacheLock);
    return [cachedSeed integerValue];
}

// Add subtle noise to image data based on seed
static void addNoiseToImageData(NSMutableData *imageData, NSString *bundleID) {
    if (!imageData || imageData.length == 0) return;
    
    uint32_t state = (uint32_t)(kConsistentNoise ? getNoiseSeedForBundle(bundleID) : arc4random_uniform(UINT32_MAX));
    if (state == 0) state = 1;
    UInt8 *bytes = (UInt8 *)imageData.mutableBytes;
    NSUInteger length = imageData.length;
    
    // Skip the first 8 bytes (header data) to preserve PNG/JPEG validity
    NSUInteger startOffset = 8;
    
    // Add subtle noise to pixel values
    for (NSUInteger i = startOffset; i < length; i++) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        if ((CGFloat)(state & 0xFFFFu) / 65535.0f < kNoiseIntensity) {
            state = state * 1664525u + 1013904223u;
            int variation = (int)(state % 3u) - 1;
            
            // Apply variation ensuring value stays within 0-255 range
            int newValue = bytes[i] + variation;
            bytes[i] = (UInt8)MAX(0, MIN(255, newValue));
        }
    }
}

#pragma mark - Shared Document-Start WKUserScript Installation

static BOOL PXUserContentControllerContainsMarker(WKUserContentController *controller, NSString *marker) {
    if (!controller || !marker.length) return NO;
    for (WKUserScript *script in controller.userScripts) {
        if ([script.source containsString:marker]) return YES;
    }
    return NO;
}

static void PXAddDocumentStartUserScriptIfNeeded(WKUserContentController *controller,
                                                  NSString *source,
                                                  NSString *marker) {
    if (!controller || !source.length || !marker.length) return;
    if (PXUserContentControllerContainsMarker(controller, marker)) return;

    WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:NO];
    [controller addUserScript:script];
}

static void PXInstallDocumentStartSpoofScripts(WKUserContentController *controller) {
    if (!controller) return;

    BOOL hasScreen = PXUserContentControllerContainsMarker(controller,
                                                            @"__weaponx_screen_spoof__");
    BOOL hasFingerprint = PXUserContentControllerContainsMarker(controller,
                                                                 @"__weaponx_fp_spoof__");

    // DeviceSpec owns generation-aware capability deduplication. Always delegate:
    // the legacy marker is compatibility evidence, not an outer installation gate.
    PXInstallDeviceSpecUserScripts(controller);

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID.length) return;

    if (!hasScreen && PXDisplayWebScreenSpoofEnabled()) {
        NSDictionary *deviceIds = PXReadCurrentDeviceIdsForFingerprint();
        NSString *screenScript = deviceIds ? PXBuildWebScreenSpoofScript(deviceIds) : nil;
        PXAddDocumentStartUserScriptIfNeeded(controller,
                                             screenScript,
                                             @"__weaponx_screen_spoof__");
    }

    if (!hasFingerprint && shouldProtectBundle(bundleID)) {
        NSString *fingerprintScript = PXBuildSeededFingerprintProtectionScript(bundleID);
        PXAddDocumentStartUserScriptIfNeeded(controller,
                                             fingerprintScript,
                                             @"__weaponx_fp_spoof__");
    }
}

static void PXStageDocumentStartScriptsForExistingWebViews(void) {
    void (^stageBlock)(void) = ^{
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:window];
                while (stack.count > 0) {
                    UIView *view = stack.lastObject;
                    [stack removeLastObject];
                    if ([view isKindOfClass:[WKWebView class]]) {
                        WKWebView *webView = (WKWebView *)view;
                        PXInstallDocumentStartSpoofScripts(webView.configuration.userContentController);
                    }
                    [stack addObjectsFromArray:view.subviews];
                }
            }
        }
    };

    if ([NSThread isMainThread]) {
        stageBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), stageBlock);
    }
}

#pragma mark - WKWebView Configuration Hooks

%hook WKWebViewConfiguration

- (instancetype)init {
    WKWebViewConfiguration *configuration = %orig;
    if (configuration) {
        PXInstallDocumentStartSpoofScripts(configuration.userContentController);
    }
    return configuration;
}

- (WKUserContentController *)userContentController {
    WKUserContentController *controller = %orig;
    PXInstallDocumentStartSpoofScripts(controller);
    return controller;
}

- (void)setUserContentController:(WKUserContentController *)userContentController {
    PXInstallDocumentStartSpoofScripts(userContentController);
    %orig(userContentController);
}

%end

#pragma mark - WKWebView Construction Hook

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if (configuration) {
        PXInstallDocumentStartSpoofScripts(configuration.userContentController);
    }
    return %orig(frame, configuration);
}

%end

#pragma mark - WKNativeCanvas Hooks

// Hook WKNativeCanvas data access methods if they exist
%hook WKNativeCanvas

// Method for getting pixel data
- (NSData *)drawingData {
    NSData *originalData = %orig;
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID || !shouldProtectBundle(bundleID) || !originalData) {
        return originalData;
    }
    
    // Create a mutable copy to modify
    NSMutableData *modifiedData = [originalData mutableCopy];
    
    // Add noise to the image data
    addNoiseToImageData(modifiedData, bundleID);
    
    return modifiedData;
}

%end

#pragma mark - Notification Handlers

// Refresh settings when profile or settings change
static void refreshSettings(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *notificationName = (__bridge NSString *)name;
    PXLog(@"[CanvasFingerprint] Received settings notification: %@", notificationName);
    PXInvalidateScopeDecisionCache();
    PXEnsureCanvasCache();
    os_unfair_lock_lock(&gCanvasCacheLock);
    [cachedBundleDecisions removeAllObjects];
    [noiseSeedCache removeAllObjects];
    os_unfair_lock_unlock(&gCanvasCacheLock);
    PXStageDocumentStartScriptsForExistingWebViews();
}

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        PXFileDebugAIDA64Log("[Canvas.ctor] enter");
        PXLog(@"[CanvasFingerprint] Initializing Canvas Fingerprint Protection hooks");
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXIsWebKitHelperProcess(bundleID, proc)) {
            PXFileDebugWebKitTrace(@"Canvas.ctor");
        }
        PXScopeOptions options = (isCanvasFingerprintProtectionEnabledForCurrentApp() || PXFullSpoofTestModeEnabled() || PXDisplayWebScreenSpoofEnabled()) ? PXScopeOptionAllowSafariAuthStack : PXScopeOptionNone;
        BOOL allowed = PXProcessIsAllowedForSpoofing(bundleID, proc, options);
        PXFileDebugAIDA64Log("[Canvas.ctor] scope allowed=%d options=%lu bundle=%s", allowed, (unsigned long)options, bundleID.UTF8String ?: "<nil>");
        if (!allowed) {
            PXLog(@"[CanvasFingerprint] App is not scoped, skipping hook installation");
            return;
        }
        PXEnsureCanvasCache();
        // Register for notifications about profile or settings changes
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.settings.changed"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.profileChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.scopedAppsChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.toggleCanvasFingerprint"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.canvasFingerprintToggleChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.enableCanvasFingerprintProtection"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.disableCanvasFingerprintProtection"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            refreshSettings,
            CFSTR("com.hydra.projectx.resetCanvasNoise"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        // Initialize hooks
        PXFileDebugAIDA64Log("[Canvas.ctor] before %%init");
        %init();
        PXFileDebugAIDA64Log("[Canvas.ctor] after %%init exit");
    }
}
