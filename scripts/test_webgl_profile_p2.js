"use strict";

const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

function extractFingerprintScript() {
    const objectiveC = fs.readFileSync("TLinkIOSTweak/CanvasFingerprintHooks.x", "utf8");
    const functionStart = objectiveC.indexOf("static NSString *PXBuildSeededFingerprintProtectionScript");
    assert.ok(functionStart >= 0, "missing fingerprint script builder");
    const assignmentStart = objectiveC.indexOf("NSString *script =", functionStart);
    const replacementStart = objectiveC.indexOf(
        "script = [script stringByReplacingOccurrencesOfString:@\"__WX_BASE_SEED__\"",
        assignmentStart
    );
    assert.ok(assignmentStart >= 0 && replacementStart > assignmentStart,
        "fingerprint script assignment must be present");
    const assignment = objectiveC.slice(assignmentStart, replacementStart);
    const literalPattern = /@?("(?:\\.|[^"\\])*")/g;
    const fragments = [];
    for (const match of assignment.matchAll(literalPattern)) {
        fragments.push(JSON.parse(match[1]));
    }
    assert.ok(fragments.length > 20, "fingerprint script fragments were not extracted");
    return fragments.join("");
}

function renderScript(values) {
    return extractFingerprintScript()
        .replace("__WX_BASE_SEED__", "305419896")
        .replace("__WX_WEBGL_VENDOR_JSON__", JSON.stringify(values.webglVendor ?? null))
        .replace("__WX_WEBGL_RENDERER_JSON__", JSON.stringify(values.webglRenderer ?? null))
        .replace("__WX_WEBGL_VERSION_JSON__", JSON.stringify(values.webglVersion ?? null))
        .replace("__WX_UNMASKED_VENDOR_JSON__", JSON.stringify(values.unmaskedVendor ?? null))
        .replace("__WX_UNMASKED_RENDERER_JSON__", JSON.stringify(values.unmaskedRenderer ?? null))
        .replace("__WX_MAX_TEXTURE_SIZE__", values.maxTextureSize == null ? "null" : String(values.maxTextureSize))
        .replace("__WX_MAX_RENDERBUFFER_SIZE__", values.maxRenderbufferSize == null ? "null" : String(values.maxRenderbufferSize));
}

function makeContext() {
    class MockWebGL {
        getParameter(parameter) {
            const originals = {
                3379: 2048,
                7936: "Real Vendor",
                7937: "Real Renderer",
                7938: "Real WebGL Version",
                34024: 1024,
                37445: "Real Unmasked Vendor",
                37446: "Real Unmasked Renderer"
            };
            return Object.prototype.hasOwnProperty.call(originals, parameter)
                ? originals[parameter]
                : "real-" + parameter;
        }
        getSupportedExtensions() {
            return ["EXT_c", "EXT_a", "EXT_b"];
        }
    }

    class MockWebGL2 extends MockWebGL {}

    const context = {
        console,
        Math,
        Number,
        String,
        Object,
        Array,
        Promise,
        Reflect,
        TypeError,
        Uint8Array,
        Uint8ClampedArray,
        Float32Array,
        WeakMap,
        WebGLRenderingContext: MockWebGL,
        WebGL2RenderingContext: MockWebGL2,
        navigator: {}
    };
    context.globalThis = context;
    return context;
}

function evaluate(values, filename) {
    const context = makeContext();
    const source = renderScript(values);
    assert.ok(!source.includes("__WX_"), "all WebGL placeholders must be replaced");
    vm.runInNewContext(source, context, { filename });
    assert.ok(!context.__weaponx_fp_spoof_failed__, "WebGL profile script must not fail closed");
    return {
        gl1: new context.WebGLRenderingContext(),
        gl2: new context.WebGL2RenderingContext()
    };
}

const full = evaluate({
    webglVendor: "Apple",
    webglRenderer: "Apple GPU",
    webglVersion: "WebGL 2.0 Profile",
    unmaskedVendor: "Apple Inc.",
    unmaskedRenderer: "Apple A17 Pro GPU",
    maxTextureSize: 16384,
    maxRenderbufferSize: 8192
}, "webgl-profile-full.js");

for (const gl of [full.gl1, full.gl2]) {
    assert.strictEqual(gl.getParameter(7936), "Apple");
    assert.strictEqual(gl.getParameter(7937), "Apple GPU");
    assert.strictEqual(gl.getParameter(7938), "WebGL 2.0 Profile");
    assert.strictEqual(gl.getParameter(37445), "Apple Inc.");
    assert.strictEqual(gl.getParameter(37446), "Apple A17 Pro GPU");
    assert.strictEqual(gl.getParameter(3379), 16384);
    assert.strictEqual(gl.getParameter(34024), 8192);
}

const missing = evaluate({}, "webgl-profile-missing.js");
for (const gl of [missing.gl1, missing.gl2]) {
    assert.strictEqual(gl.getParameter(7936), "Real Vendor", "missing vendor must preserve original");
    assert.strictEqual(gl.getParameter(7937), "Real Renderer", "missing renderer must preserve original");
    assert.strictEqual(gl.getParameter(7938), "Real WebGL Version", "missing version must preserve original");
    assert.strictEqual(gl.getParameter(37445), "Real Unmasked Vendor", "missing unmasked vendor must preserve original");
    assert.strictEqual(gl.getParameter(37446), "Real Unmasked Renderer", "missing unmasked renderer must preserve original");
    assert.strictEqual(gl.getParameter(3379), 2048, "missing max texture must preserve original");
    assert.strictEqual(gl.getParameter(34024), 1024, "missing max renderbuffer must preserve original");
}

const partial = evaluate({
    unmaskedRenderer: "Apple M2 GPU"
}, "webgl-profile-partial.js");
assert.strictEqual(partial.gl1.getParameter(37446), "Apple M2 GPU");
assert.strictEqual(partial.gl1.getParameter(7938), "Real WebGL Version");
assert.strictEqual(partial.gl1.getParameter(3379), 2048);

console.log("WebGL profile P2 runtime regression: PASS");
