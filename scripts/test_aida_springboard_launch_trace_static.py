#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT / "TLinkIOSTweak/SpringBoardLaunchHook.x").read_text(encoding="utf-8", errors="replace")
TWEAK = (ROOT / "TLinkIOSTweak/Tweak.x").read_text(encoding="utf-8", errors="replace")

def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS: {message}")

require('#import "PXFileDebug.h"' in SRC,
        "SpringBoard launch probe uses the existing marker-gated file logger")
require('com.finalwire.aida64' in SRC and 'PXAIDA64IsTargetBundle' in SRC,
        "probe is restricted to AIDA64 bundle")
require('PXFileDebugAIDA64Enabled()' in SRC,
        "probe is opt-in and inert by default")
require('"shouldBlock.begin"' in SRC and '"shouldBlock.end"' in SRC,
        "freeze/scope launch check has paired begin/end trace")
require(SRC.count('"orig.begin"') >= 4 and SRC.count('"orig.end"') >= 4,
        "major SpringBoard original launch calls have paired begin/end trace")
require('PXAIDA64TraceShouldBlockAppLaunch' in SRC,
        "all targeted launch checks pass through diagnostic wrapper")
require('return orig_activateApplication(self, _cmd, application, icon, location);' not in SRC,
        "activateApplication original call cannot bypass trace pair")
require('orig_activateApplication = (BOOL (*)(id, SEL, id, id, int))method_getImplementation(method);' in SRC,
        "activateApplication:fromIcon:location: ABI remains unchanged and correct")
require('@selector(activateApplication:fromIcon:location:)' in SRC,
        "probe guards the actual three-argument SpringBoard selector")
require('PXTLinkIOSTweakEarlyLoadMarker' in TWEAK and 'PXFileDebugLoadMarker("TLinkIOSTweak.early")' in TWEAK,
        "priority early-load marker can prove dylib load before normal ctors")
pre_scope = TWEAK.index('[Tweak.ctor] pre-scope')
scope_return = TWEAK.index('if (!currentProcessAllowed)')
require(pre_scope < scope_return,
        "AIDA ctor marker executes before unscoped process early-return")
print("PASS: AIDA64 SpringBoard launch root-cause trace static regression")
