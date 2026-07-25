#!/usr/bin/env python3
"""P2 profile schema, path resolution and WebGL source/semantic matrix."""

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PATHS_H = (ROOT / "common" / "PXPaths.h").read_text(encoding="utf-8")
PATHS_M = (ROOT / "common" / "PXPaths.m").read_text(encoding="utf-8")
SCHEMA_H = (ROOT / "common" / "PXDeviceProfileSchema.h").read_text(encoding="utf-8")
SCHEMA_M = (ROOT / "common" / "PXDeviceProfileSchema.m").read_text(encoding="utf-8")
IDENTIFIER = (ROOT / "common" / "IdentifierManager.m").read_text(encoding="utf-8")
DEVICE_MODEL = (ROOT / "common" / "DeviceModelManager.m").read_text(encoding="utf-8")
DEVICE_SPEC = (ROOT / "ProjectXTweak" / "DeviceSpecHooks.x").read_text(encoding="utf-8")
CANVAS = (ROOT / "ProjectXTweak" / "CanvasFingerprintHooks.x").read_text(encoding="utf-8")
TWEAK = (ROOT / "ProjectXTweak" / "Tweak.x").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github" / "workflows" / "build-ios-arm.yml").read_text(encoding="utf-8")

TARGET_SOURCES = {
    "IdentifierManager": IDENTIFIER,
    "DeviceModelManager": DEVICE_MODEL,
    "DeviceSpecHooks": DEVICE_SPEC,
    "CanvasFingerprintHooks": CANVAS,
}

CANONICAL_DEVICE_ID_WEBGL_KEYS = {
    "WebGLVendor",
    "WebGLRenderer",
    "WebGLVersion",
    "WebGLUnmaskedVendor",
    "WebGLUnmaskedRenderer",
    "WebGLMaxTextureSize",
    "WebGLMaxRenderbufferSize",
}

CANONICAL_RUNTIME_WEBGL_KEYS = {
    "webglVendor",
    "webglRenderer",
    "webglVersion",
    "unmaskedVendor",
    "unmaskedRenderer",
    "maxTextureSize",
    "maxRenderbufferSize",
}


class Matrix:
    def __init__(self) -> None:
        self.total = 0
        self.failed = 0

    def check(self, name: str, condition: bool) -> None:
        self.total += 1
        if condition:
            print(f"PASS: {name}")
        else:
            self.failed += 1
            print(f"FAIL: {name}")

    def finish(self) -> None:
        if self.failed:
            print(f"device profile/WebGL P2 matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"device profile/WebGL P2 matrix: PASS ({self.total}/{self.total})")


def extract_function(source: str, name: str) -> str:
    match = None
    brace = -1
    for candidate in re.finditer(
        rf"(?m)^\s*(?:static\s+)?[^;{{\n]+\b{re.escape(name)}\s*\(", source
    ):
        candidate_brace = source.find("{", candidate.end())
        candidate_semicolon = source.find(";", candidate.end())
        if candidate_brace >= 0 and (candidate_semicolon < 0 or candidate_brace < candidate_semicolon):
            match = candidate
            brace = candidate_brace
            break
    if match is None or brace < 0:
        raise RuntimeError(f"missing function: {name}")

    depth = 0
    state = "code"
    quote = ""
    escaped = False
    index = brace
    while index < len(source):
        char = source[index]
        nxt = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if char == "/" and nxt == "/":
                state = "line"
                index += 2
                continue
            if char == "/" and nxt == "*":
                state = "block"
                index += 2
                continue
            if char in {'"', "'"}:
                state = "string"
                quote = char
                index += 1
                continue
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return source[match.start() : index + 1]
            index += 1
        elif state == "line":
            if char == "\n":
                state = "code"
            index += 1
        elif state == "block":
            if char == "*" and nxt == "/":
                state = "code"
                index += 2
            else:
                index += 1
        else:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                state = "code"
            index += 1
    raise RuntimeError(f"unterminated function: {name}")


def method_body(source: str, signature: str) -> str:
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    state = "code"
    quote = ""
    escaped = False
    index = brace
    while index < len(source):
        char = source[index]
        nxt = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if char == "/" and nxt == "/":
                state = "line"
                index += 2
                continue
            if char == "/" and nxt == "*":
                state = "block"
                index += 2
                continue
            if char in {'"', "'"}:
                state = "string"
                quote = char
                index += 1
                continue
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return source[start : index + 1]
            index += 1
        elif state == "line":
            if char == "\n":
                state = "code"
            index += 1
        elif state == "block":
            if char == "*" and nxt == "/":
                state = "code"
                index += 2
            else:
                index += 1
        else:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                state = "code"
            index += 1
    raise RuntimeError(f"unterminated method: {signature}")


def profile_string(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    if not trimmed or trimmed.casefold() == "unknown":
        return None
    return trimmed


def positive_number(value: Any) -> int | float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    numeric = float(value)
    if not math.isfinite(numeric) or numeric <= 0:
        return None
    return value


def first_present(sources: list[dict[str, Any]], keys: list[str]) -> Any:
    for source in sources:
        for key in keys:
            value = source.get(key)
            if profile_string(value) is not None:
                return value
            if positive_number(value) is not None:
                return value
    return None


def canonical_webgl(source: Any) -> dict[str, Any]:
    if not isinstance(source, dict):
        return {}
    nested = source.get("webGLInfo") if isinstance(source.get("webGLInfo"), dict) else {}
    model_webgl = source.get("webgl") if isinstance(source.get("webgl"), dict) else {}

    aliases = {
        "webglVendor": (["webglVendor"], ["webglVendor", "vendor"], ["webglVendor", "WebGLVendor"]),
        "webglRenderer": (["webglRenderer"], ["webglRenderer", "renderer"], ["webglRenderer", "WebGLRenderer"]),
        "webglVersion": (["webglVersion"], ["webglVersion", "version"], ["webglVersion", "WebGLVersion"]),
        "unmaskedVendor": (["unmaskedVendor"], ["unmaskedVendor"], ["unmaskedVendor", "WebGLUnmaskedVendor"]),
        "unmaskedRenderer": (["unmaskedRenderer"], ["unmaskedRenderer"], ["unmaskedRenderer", "WebGLUnmaskedRenderer"]),
        "maxTextureSize": (["maxTextureSize"], ["maxTextureSize"], ["maxTextureSize", "WebGLMaxTextureSize"]),
        "maxRenderbufferSize": (
            ["maxRenderbufferSize", "maxRenderBufferSize"],
            ["maxRenderbufferSize", "maxRenderBufferSize"],
            ["maxRenderbufferSize", "maxRenderBufferSize", "WebGLMaxRenderbufferSize", "WebGLMaxRenderBufferSize"],
        ),
    }

    result: dict[str, Any] = {}
    for target, (nested_keys, model_keys, top_keys) in aliases.items():
        value = first_present([nested], nested_keys)
        if value is None:
            value = first_present([model_webgl], model_keys)
        if value is None:
            value = first_present([source], top_keys)
        normalized_string = profile_string(value)
        normalized_number = positive_number(value)
        if normalized_string is not None:
            result[target] = normalized_string
        elif normalized_number is not None:
            result[target] = normalized_number
    return result


def device_specs_from_ids(device_ids: Any) -> dict[str, Any] | None:
    if not isinstance(device_ids, dict):
        return None
    model = profile_string(device_ids.get("DeviceModel"))
    if model is None:
        return None

    specs: dict[str, Any] = {"value": model}
    string_fields = {
        "name": "DeviceModelName",
        "screenResolution": "ScreenResolution",
        "viewportResolution": "ViewportResolution",
        "cpuArchitecture": "CPUArchitecture",
        "gpuFamily": "GPUFamily",
        "metalFeatureSet": "MetalFeatureSet",
        "boardID": "BoardID",
        "hwModel": "HwModel",
        "modelNumber": "ModelNumber",
    }
    number_fields = {
        "devicePixelRatio": "DevicePixelRatio",
        "screenDensity": "ScreenDensityPPI",
        "deviceMemory": "DeviceMemory",
        "cpuCoreCount": "CPUCoreCount",
        "freeMemoryPercentage": "FreeMemoryPercentage",
    }
    for target, source_key in string_fields.items():
        value = profile_string(device_ids.get(source_key))
        if value is not None:
            specs[target] = value
    for target, source_key in number_fields.items():
        value = positive_number(device_ids.get(source_key))
        if value is not None:
            specs[target] = value
    webgl = canonical_webgl(device_ids)
    if webgl:
        specs["webGLInfo"] = webgl
    return specs


def write_webgl_to_ids(existing: dict[str, Any], webgl: Any) -> dict[str, Any]:
    result = dict(existing)
    for key in CANONICAL_DEVICE_ID_WEBGL_KEYS | {"WebGLMaxRenderBufferSize"}:
        result.pop(key, None)
    canonical = canonical_webgl(webgl)
    output_map = {
        "webglVendor": "WebGLVendor",
        "webglRenderer": "WebGLRenderer",
        "webglVersion": "WebGLVersion",
        "unmaskedVendor": "WebGLUnmaskedVendor",
        "unmaskedRenderer": "WebGLUnmaskedRenderer",
        "maxTextureSize": "WebGLMaxTextureSize",
        "maxRenderbufferSize": "WebGLMaxRenderbufferSize",
    }
    for source_key, output_key in output_map.items():
        if source_key in canonical:
            result[output_key] = canonical[source_key]
    return result


def valid_profile_id(value: Any) -> str | None:
    normalized = profile_string(value)
    if normalized is None or len(normalized) > 128:
        return None
    if normalized in {".", ".."} or "/" in normalized or "\\" in normalized:
        return None
    return normalized


def run_source_matrix(matrix: Matrix) -> None:
    missing_fn = extract_function(SCHEMA_M, "PXProfileValueIsMissing")
    string_fn = extract_function(SCHEMA_M, "PXProfileString")
    webgl_fn = extract_function(SCHEMA_M, "PXCanonicalWebGLInfo")
    writer_fn = extract_function(SCHEMA_M, "PXWriteWebGLInfoToDeviceIDs")
    ids_fn = extract_function(SCHEMA_M, "PXDeviceSpecificationsFromDeviceIDs")
    active_id_fn = extract_function(PATHS_M, "PXActiveProfileID")
    validated_id_fn = extract_function(PATHS_M, "PXValidatedProfileID")
    device_spec_builder = extract_function(DEVICE_SPEC, "PXBuildDeviceSpecSnapshot")
    canvas_reader = extract_function(CANVAS, "PXReadCurrentDeviceIdsForFingerprint")
    canvas_script = extract_function(CANVAS, "PXBuildSeededFingerprintProtectionScript")
    device_webgl_method = method_body(DEVICE_MODEL, "- (NSDictionary *)webGLInfoForModel:(NSString *)deviceString")
    identifier_specs_method = method_body(IDENTIFIER, "- (NSDictionary *)getDeviceModelSpecifications")

    matrix.check("source: shared schema header declares seven canonical runtime keys", all(f'NSString *const PXWebGL{suffix}Key' in SCHEMA_H for suffix in ["Vendor", "Renderer", "Version", "UnmaskedVendor", "UnmaskedRenderer", "MaxTextureSize", "MaxRenderbufferSize"]))
    matrix.check("source: all four consumers import shared schema", all('#import "PXDeviceProfileSchema.h"' in source for source in TARGET_SOURCES.values()))
    matrix.check("source: Unknown is case-insensitive missing", 'caseInsensitiveCompare:@"Unknown"' in missing_fn and 'caseInsensitiveCompare:@"Unknown"' in string_fn)
    matrix.check("source: empty strings are missing", "trimmed.length == 0" in missing_fn and "trimmed.length == 0" in string_fn)
    matrix.check("source: WebGL helper emits no default WebGL 2.0", 'WebGL 2.0' not in webgl_fn)
    matrix.check("source: WebGL helper emits no default 16384", "16384" not in webgl_fn)
    matrix.check("source: WebGL helper reads legacy max-renderbuffer aliases", 'maxRenderBufferSize' in webgl_fn and 'WebGLMaxRenderBufferSize' in webgl_fn)
    matrix.check("source: WebGL helper returns canonical maxRenderbuffer spelling", 'PXWebGLMaxRenderbufferSizeKey' in webgl_fn)
    matrix.check("source: writer owns exactly seven canonical device ID outputs", all(f'deviceIDs[@"{key}"]' in writer_fn for key in CANONICAL_DEVICE_ID_WEBGL_KEYS))
    matrix.check("source: writer never assigns legacy maxRenderBuffer spelling", 'deviceIDs[@"WebGLMaxRenderBufferSize"] =' not in writer_fn)
    matrix.check("source: writer clears legacy maxRenderBuffer spelling", '@"WebGLMaxRenderBufferSize"' in writer_fn)
    matrix.check("source: device IDs schema copies BoardID and HwModel independently", 'PXCopyStringField(specs, deviceIDs, @"boardID", @"BoardID")' in ids_fn and 'PXCopyStringField(specs, deviceIDs, @"hwModel", @"HwModel")' in ids_fn)
    matrix.check("source: schema never assigns HwModel from BoardID", not re.search(r'hwModel[^;\n]*(?:boardID|BoardID)|HwModel[^;\n]*(?:boardID|BoardID)', SCHEMA_M))
    identifier_code_without_logs = "\n".join(
        line for line in IDENTIFIER.splitlines()
        if "PXLog(" not in line and "PXDBLog(" not in line and "NSLog(" not in line
    )
    matrix.check("source: IdentifierManager never falls back HwModel to BoardID", 'modelSpec[@"hwModel"] : boardID' not in identifier_code_without_logs and not re.search(r'(?m)^\s*hwModel\s*=.*\bboardID\b', identifier_code_without_logs))
    matrix.check("source: native identity hooks never fall back HwModel to BoardID", 'PXRequireKeysAny' not in TWEAK and '@[@"HwModel", @"BoardID"]' not in TWEAK and not re.search(r'if \(!\w+\.length\) \w+ = deviceIds\[@"BoardID"\]', TWEAK))
    matrix.check("source: native required-key gate treats Unknown as missing", '#import "PXDeviceProfileSchema.h"' in TWEAK and "if (!PXProfileString(v))" in TWEAK)
    matrix.check("source: IdentifierManager writes shared WebGL schema in all profile writers", IDENTIFIER.count("PXWriteWebGLInfoToDeviceIDs(deviceIds, webGLInfo)") == 3)
    matrix.check("source: IdentifierManager reads shared device ID schema", "PXDeviceSpecificationsFromDeviceIDs(deviceIds)" in identifier_specs_method)
    matrix.check("source: DeviceModelManager returns canonical specs", "PXCanonicalDeviceSpecifications(rawSpecs, model)" in DEVICE_MODEL)
    matrix.check("source: DeviceModelManager returns canonical WebGL info", "PXCanonicalWebGLInfo(specs)" in device_webgl_method)
    matrix.check("source: DeviceModelManager uses canonical maxRenderbuffer spelling", 'maxRenderBufferSize' not in DEVICE_MODEL and 'maxRenderbufferSize' in DEVICE_MODEL)
    matrix.check("source: explicit model limits are not uniform defaults", '@(8192)' in DEVICE_MODEL and '@(16384)' in DEVICE_MODEL)
    matrix.check("source: built-in models declare unmasked fields separately", DEVICE_MODEL.count('@"unmaskedVendor": @"Apple Inc."') == 8 and DEVICE_MODEL.count('@"unmaskedRenderer": [gpuFamily copy]') == 8)
    matrix.check("source: iPad WebGL limits are assigned by SoC group", "webGLMaxTextureSize = 8192" in DEVICE_MODEL and "webGLMaxTextureSize = 16384" in DEVICE_MODEL and '@"maxTextureSize": @(webGLMaxTextureSize)' in DEVICE_MODEL)
    matrix.check("source: DeviceSpec uses shared active profile paths", all(token in device_spec_builder for token in ["PXActiveProfileID()", "PXProfileRootPath(profileID)", "PXProfileDeviceIDsPath(profileID)"]))
    matrix.check("source: DeviceSpec uses shared device ID schema", "PXDeviceSpecificationsFromDeviceIDs(deviceIDs)" in device_spec_builder)
    matrix.check("source: DeviceSpec no longer owns profile reconstruction", "PXDeviceSpecReconstructSpecs" not in DEVICE_SPEC)
    matrix.check("source: DeviceSpec uses correct MAX_RENDERBUFFER_SIZE enum", "pname == 0x84E8" in DEVICE_SPEC and "pname == 0x8D57" not in DEVICE_SPEC)
    matrix.check("source: DeviceSpec uses correct unmasked WebGL enums", "pname == 0x9245 || pname == 0x9246" in DEVICE_SPEC and "pname == 0x8B4F || pname == 0x8B4E" not in DEVICE_SPEC)
    matrix.check("source: DeviceSpec missing WebGL fields preserve original", "return original;" in method_body(DEVICE_SPEC, "- (id)getParameter:(unsigned)pname"))
    matrix.check("source: Canvas uses shared active device IDs path", "PXActiveProfileDeviceIDsPath()" in canvas_reader)
    matrix.check("source: Canvas has no hardcoded Profiles root", "/WeaponX/Profiles" not in CANVAS and "current_profile_info.plist" not in CANVAS)
    matrix.check("source: Canvas consumes all seven canonical WebGL fields", all(key in canvas_script for key in ["PXWebGLVendorKey", "PXWebGLRendererKey", "PXWebGLVersionKey", "PXWebGLUnmaskedVendorKey", "PXWebGLUnmaskedRendererKey", "PXWebGLMaxTextureSizeKey", "PXWebGLMaxRenderbufferSizeKey"]))
    matrix.check("source: Canvas propagates all seven fields to workers", all(f"JSON.stringify({name})" in canvas_script for name in ["webGLVendor", "webGLRenderer", "webGLVersion", "unmaskedVendor", "unmaskedRenderer", "maxTextureSize", "maxRenderbufferSize"]))
    matrix.check("source: Canvas spoofs only non-null WebGL fields", all(fragment in canvas_script for fragment in ["webGLVendor != null", "webGLRenderer != null", "webGLVersion != null", "unmaskedVendor != null", "unmaskedRenderer != null", "maxTextureSize != null", "maxRenderbufferSize != null"]))
    matrix.check("source: Canvas covers texture and renderbuffer limits", "parameter === 3379" in canvas_script and "parameter === 34024" in canvas_script)
    matrix.check("source: Canvas no longer hardcodes WebKit WebGL identity", 'return \\"WebKit\\"' not in canvas_script and 'return \\"WebKit WebGL\\"' not in canvas_script)

    matrix.check("source: shared Paths header exposes profile root helpers", all(name in PATHS_H for name in ["PXActiveProfileID", "PXProfileRootPath", "PXProfileIdentityPath", "PXProfileDeviceIDsPath", "PXActiveProfileDeviceIDsPath"]))
    matrix.check("source: active profile resolution uses current then legacy stores", "PXCurrentProfileInfoPath()" in active_id_fn and "PXLegacyActiveProfileInfoPath()" in active_id_fn)
    matrix.check("source: active profile resolution does not choose arbitrary directory", "contentsOfDirectoryAtPath" not in active_id_fn)
    matrix.check("source: profile ID rejects Unknown and path traversal", 'caseInsensitiveCompare:@"Unknown"' in validated_id_fn and 'rangeOfString:@"/"' in validated_id_fn and 'rangeOfString:@"\\\\"' in validated_id_fn)
    matrix.check("source: target modules contain no hardcoded Profiles root", all("/WeaponX/Profiles" not in source for source in [IDENTIFIER, DEVICE_SPEC, CANVAS]))

    matrix.check("source: CI includes P2 matrix", "python3 scripts/test_device_profile_webgl_p2.py" in WORKFLOW)
    matrix.check("source: CI includes WebGL P2 runtime regression", "node scripts/test_webgl_profile_p2.js" in WORKFLOW)


def run_semantic_matrix(matrix: Matrix) -> None:
    matrix.check("model: Unknown string is missing", profile_string(" Unknown ") is None)
    matrix.check("model: Unknown matching is case-insensitive", profile_string("uNkNoWn") is None)
    matrix.check("model: whitespace-only string is missing", profile_string(" \t\n ") is None)
    matrix.check("model: valid string is trimmed", profile_string(" Apple A17 Pro ") == "Apple A17 Pro")
    matrix.check("model: non-string is not a profile string", profile_string(123) is None)
    matrix.check("model: positive finite number is accepted", positive_number(8192) == 8192)
    matrix.check("model: zero and negative numbers are missing", positive_number(0) is None and positive_number(-1) is None)
    matrix.check("model: NaN and infinity are missing", positive_number(float("nan")) is None and positive_number(float("inf")) is None)

    complete_ids = {
        "DeviceModel": "iPhone16,1",
        "BoardID": "D83AP",
        "HwModel": "D84AP",
        "WebGLVendor": "Apple",
        "WebGLRenderer": "Apple GPU",
        "WebGLVersion": "WebGL 2.0 Profile",
        "WebGLUnmaskedVendor": "Apple Inc.",
        "WebGLUnmaskedRenderer": "Apple A17 Pro GPU",
        "WebGLMaxTextureSize": 16384,
        "WebGLMaxRenderbufferSize": 8192,
    }
    complete_specs = device_specs_from_ids(complete_ids)
    assert complete_specs is not None
    matrix.check("model: BoardID and HwModel remain independent", complete_specs.get("boardID") == "D83AP" and complete_specs.get("hwModel") == "D84AP")
    matrix.check("model: all seven WebGL fields round-trip", set(complete_specs.get("webGLInfo", {})) == CANONICAL_RUNTIME_WEBGL_KEYS)
    matrix.check("model: complete WebGL values are preserved exactly", complete_specs["webGLInfo"]["webglVersion"] == "WebGL 2.0 Profile" and complete_specs["webGLInfo"]["maxRenderbufferSize"] == 8192)

    board_only = device_specs_from_ids({"DeviceModel": "iPhone15,2", "BoardID": "D73AP"})
    assert board_only is not None
    matrix.check("model: BoardID alone never creates HwModel", board_only.get("boardID") == "D73AP" and "hwModel" not in board_only)

    unknown_values = device_specs_from_ids({
        "DeviceModel": "iPhone15,2",
        "HwModel": "Unknown",
        "GPUFamily": " UNKNOWN ",
        "WebGLVersion": "Unknown",
        "WebGLMaxTextureSize": 0,
    })
    assert unknown_values is not None
    matrix.check("model: Unknown hardware/profile strings are omitted", "hwModel" not in unknown_values and "gpuFamily" not in unknown_values)
    matrix.check("model: Unknown/zero WebGL fields are omitted", "webGLInfo" not in unknown_values)

    missing_webgl = canonical_webgl({"DeviceModel": "iPhone15,2"})
    matrix.check("model: missing WebGL stays empty", missing_webgl == {})
    matrix.check("model: unrelated top-level version/vendor are ignored", canonical_webgl({"version": "18.5", "vendor": "Unrelated"}) == {})
    matrix.check("model: missing WebGL does not become 2.0/16384", "webglVersion" not in missing_webgl and "maxTextureSize" not in missing_webgl and "maxRenderbufferSize" not in missing_webgl)

    legacy = canonical_webgl({"maxRenderBufferSize": 4096})
    matrix.check("model: legacy maxRenderBuffer alias is read", legacy == {"maxRenderbufferSize": 4096})
    legacy_ids = write_webgl_to_ids({"WebGLMaxRenderBufferSize": 2048}, legacy)
    matrix.check("model: writer migrates legacy spelling to canonical spelling", legacy_ids.get("WebGLMaxRenderbufferSize") == 4096 and "WebGLMaxRenderBufferSize" not in legacy_ids)

    partial = canonical_webgl({
        "WebGLVendor": "Apple",
        "WebGLRenderer": "Unknown",
        "WebGLUnmaskedRenderer": "Apple M2 GPU",
    })
    matrix.check("model: partial WebGL schema preserves only declared fields", partial == {"webglVendor": "Apple", "unmaskedRenderer": "Apple M2 GPU"})

    written = write_webgl_to_ids({"Other": "keep"}, complete_specs["webGLInfo"])
    matrix.check("model: canonical writer emits exactly seven WebGL device ID fields", set(written) == CANONICAL_DEVICE_ID_WEBGL_KEYS | {"Other"})
    matrix.check("model: writer preserves unrelated fields", written["Other"] == "keep")

    matrix.check("model: normal profile ID is valid", valid_profile_id(" profile-123 ") == "profile-123")
    matrix.check("model: Unknown profile ID is invalid", valid_profile_id("Unknown") is None)
    matrix.check("model: parent traversal profile ID is invalid", valid_profile_id("../profile") is None and valid_profile_id("..") is None)
    matrix.check("model: Windows path profile ID is invalid", valid_profile_id(r"folder\profile") is None)


def main() -> None:
    matrix = Matrix()
    run_source_matrix(matrix)
    run_semantic_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
