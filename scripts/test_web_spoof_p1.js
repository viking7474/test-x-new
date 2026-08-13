"use strict";

const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

const canvas = fs.readFileSync("TLinkIOSTweak/CanvasFingerprintHooks.x", "utf8");
const device = fs.readFileSync("TLinkIOSTweak/DeviceSpecHooks.x", "utf8");
const ios = fs.readFileSync("TLinkIOSTweak/IOSVersionHooks.x", "utf8");


function extractObjectiveCStringAssignment(source, functionMarker, endMarker) {
    const functionStart = source.indexOf(functionMarker);
    assert.ok(functionStart >= 0, `missing function marker: ${functionMarker}`);
    const assignmentStart = source.indexOf("NSString *script =", functionStart);
    const assignmentEnd = source.indexOf(endMarker, assignmentStart);
    assert.ok(assignmentStart >= 0 && assignmentEnd > assignmentStart, "missing Objective-C script assignment");
    const assignment = source.slice(assignmentStart, assignmentEnd);
    const literalPattern = /@?("(?:\\.|[^"\\])*")/g;
    const fragments = [];
    for (const match of assignment.matchAll(literalPattern)) fragments.push(JSON.parse(match[1]));
    assert.ok(fragments.length > 5, "capability script fragments were not extracted");
    return fragments.join("");
}

function methodBody(source, signature) {
    const start = source.indexOf(signature);
    assert.ok(start >= 0, `missing method: ${signature}`);
    const nextMethod = source.indexOf("\n- (", start + signature.length);
    const nextClassMethod = source.indexOf("\n+ (", start + signature.length);
    const endHook = source.indexOf("\n%end", start + signature.length);
    const candidates = [nextMethod, nextClassMethod, endHook].filter((value) => value >= 0);
    assert.ok(candidates.length > 0, `cannot find method end: ${signature}`);
    return source.slice(start, Math.min(...candidates));
}

for (const forbidden of [
    "_didFinishLoadForFrame:",
    "_didStartProvisionalLoadForFrame:",
    "_didCreateJavaScriptContext:"
]) {
    assert.ok(!canvas.includes(forbidden), `Canvas must not use private late hook ${forbidden}`);
    assert.ok(!device.includes(forbidden), `DeviceSpec must not use private late hook ${forbidden}`);
}
assert.ok(!canvas.includes("%hook UIImage"), "global UIImage decode hook must be removed");
assert.ok(!canvas.includes("evaluateJavaScript:"), "fingerprint injection must not evaluate into live documents");
assert.ok(!device.includes("evaluateJavaScript:"), "device capability injection must not be late");

for (const invariant of [
    "WKUserScriptInjectionTimeAtDocumentStart",
    "forMainFrameOnly:NO",
    "PXInstallDocumentStartSpoofScripts(configuration.userContentController)",
    "PXInstallDocumentStartSpoofScripts(controller)",
    "PXInstallDeviceSpecUserScripts(controller)"
]) {
    assert.ok(canvas.includes(invariant), `missing centralized document-start invariant: ${invariant}`);
}
for (const invariant of [
    "void PXInstallDeviceSpecUserScripts",
    "__weaponx_device_capabilities__",
    "def('deviceMemory'",
    "def('hardwareConcurrency'",
    "WKUserScriptInjectionTimeAtDocumentStart",
    "forMainFrameOnly:NO"
]) {
    assert.ok(device.includes(invariant), `missing capability invariant: ${invariant}`);
}

assert.ok(!ios.includes("_allowedTopLevelWebView:"), "private UA WebView selector must be removed");
assert.ok(!ios.includes("- (void)evaluateJavaScript:"), "UA logic must not hook JS evaluation");
assert.ok(!ios.includes("evaluateJavaScript:@\"navigator.userAgent\""), "UA base must not be discovered asynchronously");
assert.ok(ios.includes("_standardUserAgentWithApplicationName:"), "canonical native UA resolver must be present");
assert.ok(ios.includes("PXUASyntheticSpoofedUserAgent"), "fail-safe synchronous UA fallback must be present");
assert.ok(ios.includes("PXUAHostIsSensitive(host)"), "sensitive-host policy must be applied before loads");
assert.ok(ios.includes("PXUASetExactCustomUserAgent(webView, baseUserAgent, NO)"), "sensitive hosts must restore the base UA");

const initBody = methodBody(ios, "- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {");
assert.ok(initBody.indexOf("PXUANativeBaseUserAgent(configuration)") < initBody.indexOf("%orig(frame, configuration)"),
    "native UA base must be resolved synchronously before WKWebView construction returns");
assert.ok(initBody.indexOf("PXUAEnsureCanonicalUserAgent") > initBody.indexOf("%orig(frame, configuration)"),
    "canonical customUserAgent must be installed before init returns");
assert.ok(!initBody.includes("evaluateJavaScript"), "WKWebView init must not use async JS UA discovery");

const loadMethods = [
    ["- (WKNavigation *)loadRequest:(NSURLRequest *)request {", "%orig(request)"],
    ["- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {", "%orig(string, baseURL)"],
    ["- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {", "%orig(URL, readAccessURL)"],
    ["- (WKNavigation *)loadData:(NSData *)data", "%orig(data, MIMEType, characterEncodingName, baseURL)"]
];
for (const [signature, originalCall] of loadMethods) {
    const body = methodBody(ios, signature);
    assert.ok(body.includes("PXUAEnsureCanonicalUserAgent"), `missing canonical UA gate: ${signature}`);
    assert.ok(body.indexOf("PXUAEnsureCanonicalUserAgent") < body.indexOf(originalCall),
        `canonical UA gate must run before native load: ${signature}`);
}


const capabilityTemplate = extractObjectiveCStringAssignment(
    device,
    "void PXInstallDeviceSpecUserScripts",
    "WKUserScript *userScript"
);
function renderCapabilitySource(generation, deviceMemory, hardwareConcurrency) {
    let replacementIndex = 0;
    return capabilityTemplate
        .replace(/%llu/g, String(generation))
        .replace(/%ld/g, () => String([deviceMemory, hardwareConcurrency][replacementIndex++]));
}

const navigatorPrototype = {};
const runtimeContext = {
    navigator: Object.create(navigatorPrototype),
    Object,
    Number
};
runtimeContext.globalThis = runtimeContext;

const capabilitySourceV1 = renderCapabilitySource(1, 8, 6);
vm.runInNewContext(capabilitySourceV1, runtimeContext, { filename: "device-capabilities-v1.js" });
assert.strictEqual(runtimeContext.navigator.deviceMemory, 8, "deviceMemory must be installed at runtime");
assert.strictEqual(runtimeContext.navigator.hardwareConcurrency, 6, "hardwareConcurrency must be installed at runtime");
assert.strictEqual(runtimeContext.__weaponx_device_capabilities__, true, "legacy capability marker must remain published");
assert.strictEqual(runtimeContext.__weaponx_device_capabilities_generation__, 1, "generation 1 must be published");

vm.runInNewContext(capabilitySourceV1, runtimeContext, { filename: "device-capabilities-v1-repeat.js" });
assert.strictEqual(runtimeContext.navigator.deviceMemory, 8, "same generation must be idempotent");
assert.strictEqual(runtimeContext.navigator.hardwareConcurrency, 6, "same generation must be idempotent");

const capabilitySourceV2 = renderCapabilitySource(2, 12, 10);
vm.runInNewContext(capabilitySourceV2, runtimeContext, { filename: "device-capabilities-v2.js" });
assert.strictEqual(runtimeContext.navigator.deviceMemory, 12, "newer generation must update deviceMemory");
assert.strictEqual(runtimeContext.navigator.hardwareConcurrency, 10, "newer generation must update hardwareConcurrency");
assert.strictEqual(runtimeContext.__weaponx_device_capabilities_generation__, 2, "newer generation marker must replace the old marker");

const staleCapabilitySource = renderCapabilitySource(1, 2, 2);
vm.runInNewContext(staleCapabilitySource, runtimeContext, { filename: "device-capabilities-stale.js" });
assert.strictEqual(runtimeContext.navigator.deviceMemory, 12, "stale generation must not downgrade deviceMemory");
assert.strictEqual(runtimeContext.navigator.hardwareConcurrency, 10, "stale generation must not downgrade hardwareConcurrency");
assert.strictEqual(runtimeContext.__weaponx_device_capabilities_generation__, 2, "stale generation must not downgrade the marker");

console.log("web spoof P1 source invariants: PASS");
