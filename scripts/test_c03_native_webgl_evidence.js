"use strict";

// C-03 Stage-1/Stage-2 decision fixture.
//
// Models the three iFake native candidates at the JavaScript-observable boundary:
//   1) WebCore HTMLCanvasElement::toDataURL -> HTMLCanvasElement.prototype.toDataURL
//   2) glGetString vendor/renderer/version -> WebGL getParameter pnames
//   3) glReadPixels client-memory RGBA/U8 -> WebGL readPixels output buffer
//
// The fixture intentionally does not model a native symbol trampoline. If the
// scoped injected script covers these observations while preserving original-call
// and pass-through semantics, adding process-global WebCore/OpenGL hooks is not
// justified by current evidence.

const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

class MockImageData {
    constructor(data, width, height) {
        this.data = data;
        this.width = width;
        this.height = height;
    }
}

class Mock2DContext {
    constructor(canvas) {
        this.canvas = canvas;
    }
    getImageData(x, y, width, height) {
        return new MockImageData(new Uint8ClampedArray(this.canvas._pixels), width, height);
    }
    putImageData(imageData) {
        this.canvas._pixels.set(imageData.data);
    }
    drawImage(source) {
        this.canvas._pixels.set(source._pixels);
    }
    measureText(text) {
        return { width: String(text).length * 8 };
    }
}

class MockCanvas {
    constructor(width = 32, height = 32) {
        this.width = width;
        this.height = height;
        this._pixels = new Uint8ClampedArray(width * height * 4);
    }
    getContext(type) {
        return type === "2d" ? new Mock2DContext(this) : null;
    }
    toDataURL() {
        MockCanvas.nativeToDataURLCalls++;
        return "data:native," + Buffer.from(this._pixels).toString("hex");
    }
    toBlob(callback) {
        callback({ hex: Buffer.from(this._pixels).toString("hex") });
    }
}
MockCanvas.nativeToDataURLCalls = 0;

function realPixelByte(index) {
    return (index * 29 + 17) & 0xff;
}

class MockWebGL {
    constructor() {
        this.nativeGetParameterCalls = 0;
        this.nativeReadPixelsCalls = 0;
    }
    getParameter(parameter) {
        this.nativeGetParameterCalls++;
        const nativeStrings = {
            7936: "Native Vendor",
            7937: "Native Renderer",
            7938: "Native WebGL 1.0",
            35724: "Native GLSL"
        };
        return Object.prototype.hasOwnProperty.call(nativeStrings, parameter)
            ? nativeStrings[parameter]
            : "native-" + parameter;
    }
    getSupportedExtensions() {
        return ["EXT_c", "EXT_a", "EXT_b"];
    }
    readPixels(x, y, width, height, format, type, pixels) {
        this.nativeReadPixelsCalls++;
        if (pixels && typeof pixels.length === "number") {
            for (let index = 0; index < pixels.length; index++) pixels[index] = realPixelByte(index);
        }
        return "native-read-result";
    }
}

class MockWebGL2 extends MockWebGL {}

function extractFingerprintScript() {
    const objectiveC = fs.readFileSync("TLinkIOSTweak/CanvasFingerprintHooks.x", "utf8");
    const functionStart = objectiveC.indexOf("static NSString *PXBuildSeededFingerprintProtectionScript");
    assert.ok(functionStart >= 0, "C-03 missing fingerprint script builder");
    const assignmentStart = objectiveC.indexOf("NSString *script =", functionStart);
    const replacementStart = objectiveC.indexOf(
        "script = [script stringByReplacingOccurrencesOfString:@\"__WX_BASE_SEED__\"",
        assignmentStart
    );
    assert.ok(assignmentStart >= 0 && replacementStart > assignmentStart,
        "C-03 fingerprint script assignment must be present");
    const assignment = objectiveC.slice(assignmentStart, replacementStart);
    const literalPattern = /@?("(?:\\.|[^"\\])*")/g;
    const fragments = [];
    for (const match of assignment.matchAll(literalPattern)) fragments.push(JSON.parse(match[1]));
    assert.ok(fragments.length > 20, "C-03 fingerprint script fragments were not extracted");
    return fragments.join("");
}

function renderFingerprintScript() {
    return extractFingerprintScript()
        .split("__WX_NOISE_RATE__").join("0.02")
        .replace("__WX_BASE_SEED__", "305419896")
        .replace("__WX_WEBGL_VENDOR_JSON__", JSON.stringify("Profile Vendor"))
        .replace("__WX_WEBGL_RENDERER_JSON__", JSON.stringify("Profile Renderer"))
        .replace("__WX_WEBGL_VERSION_JSON__", JSON.stringify("WebGL 2.0 Profile"))
        .replace("__WX_UNMASKED_VENDOR_JSON__", JSON.stringify("Profile Unmasked Vendor"))
        .replace("__WX_UNMASKED_RENDERER_JSON__", JSON.stringify("Profile Unmasked Renderer"))
        .replace("__WX_MAX_TEXTURE_SIZE__", "8192")
        .replace("__WX_MAX_RENDERBUFFER_SIZE__", "4096");
}

const context = {
    console,
    Buffer,
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
    HTMLCanvasElement: MockCanvas,
    CanvasRenderingContext2D: Mock2DContext,
    WebGLRenderingContext: MockWebGL,
    WebGL2RenderingContext: MockWebGL2,
    navigator: {},
    document: {
        createElement(name) {
            assert.strictEqual(name, "canvas");
            return new MockCanvas();
        }
    }
};
context.globalThis = context;

const source = renderFingerprintScript();
for (const invariant of [
    "proto.toDataURL = function ()",
    "proto.getParameter = function (parameter)",
    "proto.readPixels = function ()",
    "const result = originalReadPixels.apply(this, arguments)",
    "arguments.length !== 7",
    "format !== 6408 || type !== 5121",
    "__wxNoiseImageData({ data: view }, x, y, width, height)"
]) {
    assert.ok(source.includes(invariant), "C-03 missing scoped JS invariant: " + invariant);
}
assert.ok(!source.includes("__WX_"), "C-03 all fingerprint placeholders must be replaced");
vm.runInNewContext(source, context, { filename: "c03-native-webgl-evidence.js" });
assert.ok(!context.__weaponx_fp_spoof_failed__, "C-03 main fingerprint install must not fail closed");

// Candidate 1: native WebCore canvas backing is observed through JS toDataURL.
const canvas = new context.HTMLCanvasElement(32, 32);
for (let index = 0; index < canvas._pixels.length; index++) canvas._pixels[index] = realPixelByte(index);
const sourcePixels = Array.from(canvas._pixels);
const rawCanvasURL = "data:native," + Buffer.from(canvas._pixels).toString("hex");
const protectedCanvasURL1 = canvas.toDataURL();
const protectedCanvasURL2 = canvas.toDataURL();
assert.notStrictEqual(protectedCanvasURL1, rawCanvasURL,
    "C-03 canvas export leaked the native backing pixels");
assert.strictEqual(protectedCanvasURL1, protectedCanvasURL2,
    "C-03 canvas export projection must be deterministic");
assert.deepStrictEqual(Array.from(canvas._pixels), sourcePixels,
    "C-03 canvas export must not mutate source canvas pixels");
assert.strictEqual(MockCanvas.nativeToDataURLCalls, 2,
    "C-03 canvas wrapper must invoke native backing exactly once per export");

// Candidate 2: glGetString-equivalent vendor/renderer/version observations are
// intercepted by getParameter before the native backing getter is consulted.
const gl = new context.WebGLRenderingContext();
assert.strictEqual(gl.getParameter(7936), "Profile Vendor");
assert.strictEqual(gl.getParameter(7937), "Profile Renderer");
assert.strictEqual(gl.getParameter(7938), "WebGL 2.0 Profile");
assert.strictEqual(gl.nativeGetParameterCalls, 0,
    "C-03 configured GL string pnames should not consult native backing");
assert.strictEqual(gl.getParameter(35724), "Native GLSL",
    "C-03 unmanaged GL string pname must preserve native value");
assert.strictEqual(gl.nativeGetParameterCalls, 1,
    "C-03 unmanaged GL string pname must call native backing exactly once");

// Candidate 3: the proven Stage-1 gap. The main JS path must call native
// readPixels exactly once, preserve its return value, then deterministically
// perturb only the ordinary RGBA/U8 client-memory bytes.
const width = 32;
const height = 32;
const byteCount = width * height * 4;
const rawPixels = Array.from({ length: byteCount }, (_, index) => realPixelByte(index));
const read1 = new Uint8Array(byteCount);
const read2 = new Uint8Array(byteCount);
const return1 = gl.readPixels(0, 0, width, height, 6408, 5121, read1);
const return2 = gl.readPixels(0, 0, width, height, 6408, 5121, read2);
assert.strictEqual(return1, "native-read-result", "C-03 readPixels return contract changed");
assert.strictEqual(return2, "native-read-result", "C-03 repeated readPixels return contract changed");
assert.strictEqual(gl.nativeReadPixelsCalls, 2,
    "C-03 readPixels wrapper must call native backing exactly once per invocation");
assert.notDeepStrictEqual(Array.from(read1), rawPixels,
    "C-03 readPixels leaked the exact native RGBA buffer");
assert.deepStrictEqual(Array.from(read1), Array.from(read2),
    "C-03 readPixels projection must be deterministic for equal native pixels");
for (let index = 3; index < byteCount; index += 4) {
    assert.strictEqual(read1[index], rawPixels[index],
        "C-03 readPixels projection must preserve alpha bytes");
}

// Unsupported GL format/type and WebGL2-style overloads stay exact pass-through.
const unsupportedFormat = new Uint8Array(byteCount);
const unsupportedReturn = gl.readPixels(0, 0, width, height, 6407, 5121, unsupportedFormat);
assert.strictEqual(unsupportedReturn, "native-read-result");
assert.deepStrictEqual(Array.from(unsupportedFormat), rawPixels,
    "C-03 unsupported readPixels format must remain exact native output");

const offsetOverload = new Uint8Array(byteCount);
const offsetReturn = gl.readPixels(0, 0, width, height, 6408, 5121, offsetOverload, 4);
assert.strictEqual(offsetReturn, "native-read-result");
assert.deepStrictEqual(Array.from(offsetOverload), rawPixels,
    "C-03 8-argument readPixels overload must remain exact native output");

console.log("C-03 native WebCore/OpenGL evidence: PASS (scoped JS boundary closes observed paths)");
