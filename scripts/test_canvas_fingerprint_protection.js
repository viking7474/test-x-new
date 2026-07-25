"use strict";

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
        this.font = "10px sans-serif";
        this.textAlign = "start";
        this.textBaseline = "alphabetic";
        this.direction = "inherit";
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
        return { width: String(text).length * 10 };
    }
}

class MockCanvas {
    constructor(width = 2, height = 2) {
        this.width = width;
        this.height = height;
        this._pixels = new Uint8ClampedArray(width * height * 4);
    }
    getContext(type) {
        if (type === "2d") return new Mock2DContext(this);
        return null;
    }
    toDataURL() {
        return "data:mock," + Buffer.from(this._pixels).toString("hex");
    }
    toBlob(callback) {
        const blob = { hex: Buffer.from(this._pixels).toString("hex") };
        callback(blob);
    }
}

class MockOffscreenCanvas extends MockCanvas {
    convertToBlob() {
        return Promise.resolve({ hex: Buffer.from(this._pixels).toString("hex") });
    }
    transferToImageBitmap() {
        if (!(this instanceof MockOffscreenCanvas)) {
            throw new TypeError("Illegal invocation");
        }
        const bitmap = {
            width: this.width,
            height: this.height,
            _pixels: new Uint8ClampedArray(this._pixels),
            hex: Buffer.from(this._pixels).toString("hex"),
            closed: false,
            close() { this.closed = true; }
        };
        this._pixels.fill(0);
        return bitmap;
    }
}

class MockWebGL {
    getParameter(parameter) {
        if (parameter === 7938) return "WebGL 1.0 Mock";
        return "real-" + parameter;
    }
    getSupportedExtensions() {
        return ["EXT_c", "EXT_a", "EXT_b"];
    }
}

class MockWebGL2 extends MockWebGL {
    getParameter(parameter) {
        if (parameter === 7938) return "WebGL 2.0 Mock";
        return "real2-" + parameter;
    }
}

class MockAnalyserNode {
    getFloatFrequencyData(array) {
        for (let index = 0; index < array.length; index++) array[index] = -20 - index;
    }
}

class MockAudioBuffer {
    constructor() {
        this.channel = new Float32Array([0.1, 0.2, 0.3, 0.4]);
    }
    getChannelData() {
        return this.channel;
    }
}

class MockServiceWorker {
    postMessage() {
        return "posted";
    }
}

class MockWorker {
    constructor(url, options) {
        this.url = url;
        this.options = options;
    }
}

class MockSharedWorker extends MockWorker {}

const blobStore = new Map();
let nextBlob = 1;
class MockBlob {
    constructor(parts, options) {
        this.parts = parts;
        this.options = options;
    }
    async text() {
        return this.parts.join("");
    }
}

function MockURL(value, base) {
    return new URL(value, base);
}
MockURL.createObjectURL = function (blob) {
    const value = "blob:mock-" + nextBlob++;
    blobStore.set(value, blob);
    return value;
};
MockURL.revokeObjectURL = function () {};

const serviceWorkerContainerProto = {
    register() {
        return Promise.resolve("registered");
    },
    addEventListener() {
        return "listener-added";
    },
    startMessages() {
        return "messages-started";
    }
};
const serviceWorkerContainer = Object.create(serviceWorkerContainerProto);

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
    setTimeout(callback) { callback(); return 0; },
    clearTimeout() {},
    HTMLCanvasElement: MockCanvas,
    CanvasRenderingContext2D: Mock2DContext,
    OffscreenCanvas: MockOffscreenCanvas,
    WebGLRenderingContext: MockWebGL,
    WebGL2RenderingContext: MockWebGL2,
    AnalyserNode: MockAnalyserNode,
    AudioBuffer: MockAudioBuffer,
    Worker: MockWorker,
    SharedWorker: MockSharedWorker,
    ServiceWorker: MockServiceWorker,
    Blob: MockBlob,
    URL: MockURL,
    location: { href: "https://example.test/page" },
    navigator: {
        fonts: {
            query() {
                return Promise.resolve(["Font C", "Font A", "Font B"]);
            }
        },
        serviceWorker: serviceWorkerContainer
    },
    document: {
        createElement(name) {
            assert.strictEqual(name, "canvas");
            return new MockCanvas();
        }
    }
};
context.globalThis = context;

function extractFingerprintScript() {
    const objectiveC = fs.readFileSync("ProjectXTweak/CanvasFingerprintHooks.x", "utf8");
    const assignmentStart = objectiveC.indexOf("NSString *script =");
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
    assert.ok(fragments.length > 20, "fingerprint script must contain the expected literal fragments");
    return fragments.join("");
}

let source = extractFingerprintScript();
assert.ok(!source.includes("let __wxSeed"), "global mutable PRNG state must not return");
assert.ok(!source.includes("addNoise(this)"), "canvas export must not mutate the source canvas");
for (const token of [
    "const __wxRoot = typeof globalThis",
    "__wxInstallMainFailClosed",
    "__wxImageSeed",
    "__wxNoisyCanvasCopy",
    "WebGL2RenderingContext",
    "OffscreenCanvas",
    "__wxPatchWorkerConstructor(\"Worker\")",
    "__wxPatchWorkerConstructor(\"SharedWorker\")",
    "__wxFailClosedServiceWorkers"
]) {
    assert.ok(source.includes(token), "missing fingerprint protection invariant: " + token);
}
source = source
    .replace("__WX_BASE_SEED__", "305419896")
    .replace("__WX_WEBGL_VENDOR_JSON__", JSON.stringify("Apple"))
    .replace("__WX_WEBGL_RENDERER_JSON__", JSON.stringify("Apple GPU"))
    .replace("__WX_WEBGL_VERSION_JSON__", JSON.stringify("WebGL 2.0 Profile"))
    .replace("__WX_UNMASKED_VENDOR_JSON__", JSON.stringify("Apple Inc."))
    .replace("__WX_UNMASKED_RENDERER_JSON__", JSON.stringify("Apple A15 GPU"))
    .replace("__WX_MAX_TEXTURE_SIZE__", "8192")
    .replace("__WX_MAX_RENDERBUFFER_SIZE__", "4096");
vm.runInNewContext(source, context, { filename: "canvas-fingerprint-protection.js" });

async function main() {
    const canvas = new context.HTMLCanvasElement(2, 2);
    canvas._pixels.set([
        10, 20, 30, 255,
        40, 50, 60, 255,
        70, 80, 90, 255,
        100, 110, 120, 255
    ]);
    const original = Array.from(canvas._pixels);
    const firstURL = canvas.toDataURL();
    const secondURL = canvas.toDataURL();
    assert.strictEqual(firstURL, secondURL, "toDataURL must be idempotent");
    assert.deepStrictEqual(Array.from(canvas._pixels), original, "toDataURL must not mutate source pixels");
    const firstCanvasBlob = await new Promise((resolve) => canvas.toBlob(resolve));
    const secondCanvasBlob = await new Promise((resolve) => canvas.toBlob(resolve));
    assert.strictEqual(firstCanvasBlob.hex, secondCanvasBlob.hex, "toBlob must be idempotent");
    assert.deepStrictEqual(Array.from(canvas._pixels), original, "toBlob must not mutate source pixels");

    const context2D = canvas.getContext("2d");
    const firstRead = Array.from(context2D.getImageData(0, 0, 2, 2).data);
    const secondRead = Array.from(context2D.getImageData(0, 0, 2, 2).data);
    assert.deepStrictEqual(firstRead, secondRead, "getImageData must be idempotent");
    assert.deepStrictEqual(Array.from(canvas._pixels), original, "getImageData must not mutate source pixels");
    const firstMetrics = context2D.measureText("WeaponX deterministic metrics");
    const secondMetrics = context2D.measureText("WeaponX deterministic metrics");
    assert.strictEqual(firstMetrics.width, secondMetrics.width, "measureText noise must be deterministic");

    canvas._pixels[0] += 7;
    assert.notStrictEqual(canvas.toDataURL(), firstURL, "different source content should produce different output");

    const offscreen = new context.OffscreenCanvas(2, 2);
    offscreen._pixels.set(original);
    const offscreenOriginal = Array.from(offscreen._pixels);
    const firstBlob = await offscreen.convertToBlob();
    const secondBlob = await offscreen.convertToBlob();
    assert.strictEqual(firstBlob.hex, secondBlob.hex, "OffscreenCanvas.convertToBlob must be idempotent");
    assert.deepStrictEqual(Array.from(offscreen._pixels), offscreenOriginal, "Offscreen export must not mutate source pixels");
    const firstBitmap = offscreen.transferToImageBitmap();
    assert.ok(Array.from(offscreen._pixels).every((value) => value === 0),
        "protected transferToImageBitmap must preserve the native source-transfer side effect");
    offscreen._pixels.set(offscreenOriginal);
    const secondBitmap = offscreen.transferToImageBitmap();
    assert.strictEqual(firstBitmap.hex, secondBitmap.hex,
        "OffscreenCanvas.transferToImageBitmap must be deterministic for equal source content");

    const gl1 = new context.WebGLRenderingContext();
    const gl2 = new context.WebGL2RenderingContext();
    for (const gl of [gl1, gl2]) {
        assert.strictEqual(gl.getParameter(37445), "Apple Inc.");
        assert.strictEqual(gl.getParameter(37446), "Apple A15 GPU");
        assert.strictEqual(gl.getParameter(7936), "Apple");
        assert.strictEqual(gl.getParameter(7937), "Apple GPU");
        assert.strictEqual(gl.getParameter(7938), "WebGL 2.0 Profile");
        assert.strictEqual(gl.getParameter(3379), 8192);
        assert.strictEqual(gl.getParameter(34024), 4096);
        assert.deepStrictEqual(gl.getSupportedExtensions(), gl.getSupportedExtensions(), "extension order must be stable");
    }

    const analyser = new context.AnalyserNode();
    const frequencies1 = new Float32Array(8);
    const frequencies2 = new Float32Array(8);
    analyser.getFloatFrequencyData(frequencies1);
    analyser.getFloatFrequencyData(frequencies2);
    assert.deepStrictEqual(Array.from(frequencies1), Array.from(frequencies2), "audio analyser noise must be deterministic");

    const audioBuffer = new context.AudioBuffer();
    const sourceChannel = Array.from(audioBuffer.channel);
    const channel1 = audioBuffer.getChannelData(0);
    const channel2 = audioBuffer.getChannelData(0);
    assert.strictEqual(channel1, channel2, "audio shadow channel identity must be stable");
    assert.deepStrictEqual(Array.from(channel1), Array.from(channel2), "audio channel noise must be deterministic");
    assert.deepStrictEqual(Array.from(audioBuffer.channel), sourceChannel, "audio noise must not mutate source channel");

    const worker = new context.Worker("/worker.js");
    const workerSource = await blobStore.get(worker.url).text();
    assert.ok(workerSource.indexOf("__wxInstallScope") < workerSource.indexOf("importScripts("), "classic worker bootstrap must precede importScripts");

    const moduleWorker = new context.Worker("/module-worker.js", { type: "module" });
    const moduleSource = await blobStore.get(moduleWorker.url).text();
    assert.ok(moduleSource.indexOf("__wxInstallScope") < moduleSource.lastIndexOf("import("), "module worker bootstrap must precede dynamic import");

    const sharedWorker = new context.SharedWorker("/shared.js");
    const sharedSource = await blobStore.get(sharedWorker.url).text();
    assert.ok(sharedSource.includes("importScripts("), "SharedWorker must be wrapped");

    await assert.rejects(() => context.navigator.serviceWorker.register("/sw.js"), /blocked/);
    assert.throws(() => new context.ServiceWorker().postMessage("x"), /blocked/);
    assert.throws(() => context.navigator.serviceWorker.addEventListener("message", function () {}), /blocked/);
    assert.throws(() => context.navigator.serviceWorker.startMessages(), /blocked/);
    assert.throws(() => { context.navigator.serviceWorker.onmessage = function () {}; }, /blocked/);

    const fonts1 = await context.navigator.fonts.query();
    const fonts2 = await context.navigator.fonts.query();
    assert.deepStrictEqual(fonts1, fonts2, "font query ordering must be deterministic");

    console.log("canvas fingerprint source/runtime regression: PASS");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
