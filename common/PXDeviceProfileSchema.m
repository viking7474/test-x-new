#import "PXDeviceProfileSchema.h"
#import <math.h>

NSString *const PXDeviceSpecWebGLInfoKey = @"webGLInfo";
NSString *const PXWebGLVendorKey = @"webglVendor";
NSString *const PXWebGLRendererKey = @"webglRenderer";
NSString *const PXWebGLVersionKey = @"webglVersion";
NSString *const PXWebGLUnmaskedVendorKey = @"unmaskedVendor";
NSString *const PXWebGLUnmaskedRendererKey = @"unmaskedRenderer";
NSString *const PXWebGLMaxTextureSizeKey = @"maxTextureSize";
NSString *const PXWebGLMaxRenderbufferSizeKey = @"maxRenderbufferSize";

static id PXFirstPresentValue(NSDictionary *source, NSArray<NSString *> *keys) {
    if (![source isKindOfClass:[NSDictionary class]]) return nil;
    for (NSString *key in keys) {
        id value = source[key];
        if (!PXProfileValueIsMissing(value)) return value;
    }
    return nil;
}

BOOL PXProfileValueIsMissing(id value) {
    if (!value || value == [NSNull null]) return YES;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return trimmed.length == 0 || [trimmed caseInsensitiveCompare:@"Unknown"] == NSOrderedSame;
    }
    return NO;
}

NSString *PXProfileString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0 || [trimmed caseInsensitiveCompare:@"Unknown"] == NSOrderedSame) return nil;
    return trimmed;
}

NSNumber *PXProfilePositiveNumber(id value) {
    if (![value isKindOfClass:[NSNumber class]]) return nil;
    double numeric = [(NSNumber *)value doubleValue];
    if (!isfinite(numeric) || numeric <= 0.0) return nil;
    return value;
}

static void PXSetStringIfPresent(NSMutableDictionary *target, NSString *key, id value) {
    NSString *normalized = PXProfileString(value);
    if (normalized) target[key] = normalized;
}

static void PXSetNumberIfPresent(NSMutableDictionary *target, NSString *key, id value) {
    NSNumber *normalized = PXProfilePositiveNumber(value);
    if (normalized) target[key] = normalized;
}

NSDictionary *PXCanonicalWebGLInfo(id sourceValue) {
    if (![sourceValue isKindOfClass:[NSDictionary class]]) return @{};
    NSDictionary *source = (NSDictionary *)sourceValue;
    NSDictionary *nested = [source[PXDeviceSpecWebGLInfoKey] isKindOfClass:[NSDictionary class]]
        ? source[PXDeviceSpecWebGLInfoKey]
        : nil;
    NSDictionary *webgl = [source[@"webgl"] isKindOfClass:[NSDictionary class]] ? source[@"webgl"] : nil;

    id (^lookup)(NSArray<NSString *> *, NSArray<NSString *> *, NSArray<NSString *> *) =
        ^id(NSArray<NSString *> *nestedKeys,
            NSArray<NSString *> *modelKeys,
            NSArray<NSString *> *topLevelKeys) {
            id value = PXFirstPresentValue(nested, nestedKeys);
            if (value) return value;
            value = PXFirstPresentValue(webgl, modelKeys);
            if (value) return value;
            return PXFirstPresentValue(source, topLevelKeys);
        };

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    PXSetStringIfPresent(result, PXWebGLVendorKey,
                         lookup(@[PXWebGLVendorKey],
                                @[PXWebGLVendorKey, @"vendor"],
                                @[PXWebGLVendorKey, @"WebGLVendor"]));
    PXSetStringIfPresent(result, PXWebGLRendererKey,
                         lookup(@[PXWebGLRendererKey],
                                @[PXWebGLRendererKey, @"renderer"],
                                @[PXWebGLRendererKey, @"WebGLRenderer"]));
    PXSetStringIfPresent(result, PXWebGLVersionKey,
                         lookup(@[PXWebGLVersionKey],
                                @[PXWebGLVersionKey, @"version"],
                                @[PXWebGLVersionKey, @"WebGLVersion"]));
    PXSetStringIfPresent(result, PXWebGLUnmaskedVendorKey,
                         lookup(@[PXWebGLUnmaskedVendorKey],
                                @[PXWebGLUnmaskedVendorKey],
                                @[PXWebGLUnmaskedVendorKey, @"WebGLUnmaskedVendor"]));
    PXSetStringIfPresent(result, PXWebGLUnmaskedRendererKey,
                         lookup(@[PXWebGLUnmaskedRendererKey],
                                @[PXWebGLUnmaskedRendererKey],
                                @[PXWebGLUnmaskedRendererKey, @"WebGLUnmaskedRenderer"]));
    PXSetNumberIfPresent(result, PXWebGLMaxTextureSizeKey,
                         lookup(@[PXWebGLMaxTextureSizeKey],
                                @[PXWebGLMaxTextureSizeKey],
                                @[PXWebGLMaxTextureSizeKey, @"WebGLMaxTextureSize"]));
    PXSetNumberIfPresent(result, PXWebGLMaxRenderbufferSizeKey,
                         lookup(@[PXWebGLMaxRenderbufferSizeKey, @"maxRenderBufferSize"],
                                @[PXWebGLMaxRenderbufferSizeKey, @"maxRenderBufferSize"],
                                @[PXWebGLMaxRenderbufferSizeKey,
                                  @"maxRenderBufferSize",
                                  @"WebGLMaxRenderbufferSize",
                                  @"WebGLMaxRenderBufferSize"]));
    return [result copy];
}

NSDictionary *PXWebGLInfoFromModelSpec(NSDictionary *modelSpec) {
    return PXCanonicalWebGLInfo(modelSpec);
}

NSDictionary *PXWebGLInfoFromDeviceIDs(NSDictionary *deviceIDs) {
    return PXCanonicalWebGLInfo(deviceIDs);
}

void PXWriteWebGLInfoToDeviceIDs(NSMutableDictionary *deviceIDs, NSDictionary *webGLInfo) {
    if (![deviceIDs isKindOfClass:[NSMutableDictionary class]]) return;

    NSArray<NSString *> *managedKeys = @[
        @"WebGLVendor",
        @"WebGLRenderer",
        @"WebGLVersion",
        @"WebGLUnmaskedVendor",
        @"WebGLUnmaskedRenderer",
        @"WebGLMaxTextureSize",
        @"WebGLMaxRenderbufferSize",
        @"WebGLMaxRenderBufferSize"
    ];
    for (NSString *key in managedKeys) [deviceIDs removeObjectForKey:key];

    NSDictionary *canonical = PXCanonicalWebGLInfo(webGLInfo);
    if (canonical[PXWebGLVendorKey]) deviceIDs[@"WebGLVendor"] = canonical[PXWebGLVendorKey];
    if (canonical[PXWebGLRendererKey]) deviceIDs[@"WebGLRenderer"] = canonical[PXWebGLRendererKey];
    if (canonical[PXWebGLVersionKey]) deviceIDs[@"WebGLVersion"] = canonical[PXWebGLVersionKey];
    if (canonical[PXWebGLUnmaskedVendorKey]) deviceIDs[@"WebGLUnmaskedVendor"] = canonical[PXWebGLUnmaskedVendorKey];
    if (canonical[PXWebGLUnmaskedRendererKey]) deviceIDs[@"WebGLUnmaskedRenderer"] = canonical[PXWebGLUnmaskedRendererKey];
    if (canonical[PXWebGLMaxTextureSizeKey]) deviceIDs[@"WebGLMaxTextureSize"] = canonical[PXWebGLMaxTextureSizeKey];
    if (canonical[PXWebGLMaxRenderbufferSizeKey]) deviceIDs[@"WebGLMaxRenderbufferSize"] = canonical[PXWebGLMaxRenderbufferSizeKey];
}

static void PXCopyStringField(NSMutableDictionary *target,
                              NSDictionary *source,
                              NSString *targetKey,
                              NSString *sourceKey) {
    NSString *value = PXProfileString(source[sourceKey]);
    if (value) target[targetKey] = value;
}

static void PXCopyNumberField(NSMutableDictionary *target,
                              NSDictionary *source,
                              NSString *targetKey,
                              NSString *sourceKey) {
    NSNumber *value = PXProfilePositiveNumber(source[sourceKey]);
    if (value) target[targetKey] = value;
}

NSDictionary *PXDeviceSpecificationsFromDeviceIDs(NSDictionary *deviceIDs) {
    if (![deviceIDs isKindOfClass:[NSDictionary class]]) return nil;
    NSString *model = PXProfileString(deviceIDs[@"DeviceModel"]);
    if (!model) return nil;

    NSMutableDictionary *specs = [NSMutableDictionary dictionary];
    specs[@"value"] = model;
    PXCopyStringField(specs, deviceIDs, @"name", @"DeviceModelName");
    PXCopyStringField(specs, deviceIDs, @"screenResolution", @"ScreenResolution");
    PXCopyStringField(specs, deviceIDs, @"viewportResolution", @"ViewportResolution");
    PXCopyNumberField(specs, deviceIDs, @"devicePixelRatio", @"DevicePixelRatio");
    PXCopyNumberField(specs, deviceIDs, @"screenDensity", @"ScreenDensityPPI");
    PXCopyStringField(specs, deviceIDs, @"cpuArchitecture", @"CPUArchitecture");
    PXCopyNumberField(specs, deviceIDs, @"deviceMemory", @"DeviceMemory");
    PXCopyStringField(specs, deviceIDs, @"gpuFamily", @"GPUFamily");
    PXCopyNumberField(specs, deviceIDs, @"cpuCoreCount", @"CPUCoreCount");
    PXCopyStringField(specs, deviceIDs, @"metalFeatureSet", @"MetalFeatureSet");
    PXCopyStringField(specs, deviceIDs, @"boardID", @"BoardID");
    PXCopyStringField(specs, deviceIDs, @"hwModel", @"HwModel");
    PXCopyStringField(specs, deviceIDs, @"modelNumber", @"ModelNumber");

    NSNumber *freeMemory = PXProfilePositiveNumber(deviceIDs[@"FreeMemoryPercentage"]);
    if (freeMemory) specs[@"freeMemoryPercentage"] = freeMemory;

    NSDictionary *webGLInfo = PXWebGLInfoFromDeviceIDs(deviceIDs);
    if (webGLInfo.count) specs[PXDeviceSpecWebGLInfoKey] = webGLInfo;
    return [specs copy];
}

NSDictionary *PXCanonicalDeviceSpecifications(NSDictionary *source, NSString *modelIdentifier) {
    if (![source isKindOfClass:[NSDictionary class]]) return nil;
    NSString *model = PXProfileString(modelIdentifier) ?: PXProfileString(source[@"value"]);
    if (!model) return nil;

    NSMutableDictionary *specs = [NSMutableDictionary dictionary];
    specs[@"value"] = model;
    for (NSString *key in @[@"name", @"screenResolution", @"viewportResolution",
                             @"cpuArchitecture", @"gpuFamily", @"metalFeatureSet",
                             @"boardID", @"hwModel", @"modelNumber"]) {
        NSString *value = PXProfileString(source[key]);
        if (value) specs[key] = value;
    }
    for (NSString *key in @[@"devicePixelRatio", @"screenDensity", @"deviceMemory",
                             @"cpuCoreCount", @"freeMemoryPercentage"]) {
        NSNumber *value = PXProfilePositiveNumber(source[key]);
        if (value) specs[key] = value;
    }

    NSDictionary *webGLInfo = PXCanonicalWebGLInfo(source);
    if (webGLInfo.count) specs[PXDeviceSpecWebGLInfoKey] = webGLInfo;
    return [specs copy];
}
