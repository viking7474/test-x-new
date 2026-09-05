#!/usr/bin/env python3
"""Static contract for Canvas Fingerprint Noise controls and persistence wiring."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS: {message}")


ui = read("CanvasDetailViewController.m")
security = read("SecurityTabViewController.m")
hook = read("TLinkIOSTweak/CanvasFingerprintHooks.x")
identifier_h = read("common/IdentifierManager.h")
identifier_m = read("common/IdentifierManager.m")

for key in (
    "canvasNoiseLevel",
    "canvasWebKitNoiseEnabled",
    "canvasNativeNoiseEnabled",
    "canvasStableSeedEnabled",
):
    require(key in ui, f"Canvas detail persists {key}")
    require(key in hook, f"Canvas hook consumes {key}")

for label in ("Noise level", "WebKit / Canvas APIs", "Native Canvas Bridge", "Stable Noise Seed", "Reset Noise"):
    require(label in ui, f"Canvas detail exposes {label}")

require("PXSecuritySettingsPath()" in ui, "Canvas detail uses shared security settings path")
require("persistCanvasValues:" in ui and "if (!success)" in ui, "Canvas detail has persistence failure handling")
require("primaryTextColor" in ui and "@available(iOS 13.0, *)" in ui, "Canvas detail has iOS 12 color fallbacks")
require("resetCanvasNoiseAndPersist" in ui, "Canvas detail uses persistent reset API")

require("PXCanvasNoiseIntensityForLevel" in hook, "Canvas hook maps discrete noise levels")
require("case 0: return 0.0" in hook and "case 3: return 0.08" in hook, "Canvas hook defines Off through High intensities")
require("PXCanvasWebKitScopeEnabled" in hook and "YES" in hook.split("PXCanvasWebKitScopeEnabled", 1)[1][:180],
        "WebKit Canvas scope defaults on")
require("PXCanvasNativeScopeEnabled" in hook and "NO" in hook.split("PXCanvasNativeScopeEnabled", 1)[1][:180],
        "Native Canvas scope defaults off")
require("PXCanvasStableSeedEnabled" in hook, "Canvas hook supports stable seed mode")
require("PXCanvasSeedNonce" in hook and "PXEffectiveCanvasSeed" in hook, "Canvas hook includes reset nonce in effective seed")
require("__weaponx_fp_update__" in hook and "PXBuildFingerprintRuntimeUpdateScript" in hook,
        "Canvas hook supports runtime seed/noise/scope updates")
require("!PXCanvasNativeScopeEnabled(settings)" in hook, "WKNativeCanvas obeys Native scope control")
require("rotateSessionSeed" in hook and "resetCanvasNoise" in hook, "runtime reset rotates session seed cache")

require("resetCanvasNoiseAndPersist" in identifier_h, "IdentifierManager exposes persistent Canvas reset")
require("canvasNoiseSeedNonce" in identifier_m, "IdentifierManager persists Canvas reset nonce")
require("Failed to persist Canvas Fingerprint Protection" in identifier_m and "return NO;" in identifier_m,
        "IdentifierManager reports Canvas persistence failures")
require("if (![self setCanvasFingerprintProtection:newValue])" in identifier_m,
        "IdentifierManager toggle respects Canvas persistence failure")

require("[self refreshCanvasFingerprintingControlState];" in security,
        "Security tab refreshes Canvas state when returning from detail")
require("currentCanvasFingerprintingEnabled" in security, "Security tab uses one Canvas state helper")
require("persistenceSuccess = [manager setCanvasFingerprintProtection:enabled]" in security,
        "Security tab checks Canvas toggle persistence result")
require("resetCanvasNoiseAndPersist" in security, "Security tab uses persistent Canvas reset")
require('if (![self.securitySettings objectForKey:@"canvasFingerprintingEnabled"] &&' not in security,
        "inverted Canvas suite-default load branch is removed")

print("canvas noise controls static contract: PASS")
