#!/usr/bin/env python3
"""T-0097 / C-04 evidence gate for SBS/NX private-symbol parity candidates.

C-04 is intentionally evidence-only: x-new must keep using its existing
LaunchServices/SpringBoard and jailbreak/runtime owners unless an on-device
fixture proves a concrete bypass that requires one of the four private symbols.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TWEAK_ROOT = ROOT / "TLinkIOSTweak"
REPORT = ROOT / "iFakePro_vs_x-new_Hook_Gap_Assessment.md"
PLAN = ROOT / "iFakePro_vs_x-new_Agent_Implementation_Plan.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="replace")


def production_text() -> str:
    chunks: list[str] = []
    for suffix in ("*.x", "*.m", "*.mm", "*.c", "*.h"):
        for path in sorted(TWEAK_ROOT.glob(suffix)):
            chunks.append(path.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(chunks)


PRODUCTION = production_text()
SPRINGBOARD = read("TLinkIOSTweak/SpringBoardLaunchHook.x")
JB = read("TLinkIOSTweak/JailbreakBypassHooks.x")
REPORT_TEXT = REPORT.read_text(encoding="utf-8")
PLAN_TEXT = PLAN.read_text(encoding="utf-8")

PRIVATE_CANDIDATES = (
    "SBSLaunchApplicationWithIdentifierAndURLAndLaunchOptions",
    "SBSLaunchApplicationWithIdentifierAndLaunchOptions",
    "NXMapGet",
    "NXHashGet",
)
for symbol in PRIVATE_CANDIDATES:
    require(symbol not in PRODUCTION,
            f"C-04 private symbol appeared in production without a failing evidence fixture: {symbol}")

# x-new already owns its product launch behavior above the private SBS C layer.
# Pin the concrete SpringBoard-only launch/activation surfaces so the evidence
# decision cannot silently degrade into "no launch owner exists".
for token in (
    'if (![processName isEqualToString:@"SpringBoard"])',
    "static BOOL shouldBlockAppLaunch",
    "new_launchWithDelegate",
    "new_openApplicationWithBundleID",
    "new_openURL",
    "new_activateApplication",
    "openApplicationWithBundleID:",
    "openURL:withOptions:",
):
    require(token in SPRINGBOARD, f"C-04 launch owner drifted: {token}")

# Anti-detection/app-availability and runtime-image hiding remain owned by the
# narrower generic JB layer rather than by SBS/NX process-global private hooks.
for token in (
    "%hook LSApplicationWorkspace",
    "allInstalledApplications",
    "installedApplications",
    "allApplications",
    'objc_getClass("_LSCanOpenURLManager")',
    "canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:",
    'FindSymbol("objc_copyClassNamesForImage")',
    'FindSymbol("class_getImageName")',
    "PXJBShouldHideImageName",
):
    require(token in JB, f"C-04 generic JB/runtime owner drifted: {token}")

# Documentation must record the evidence decision, not leave these four symbols
# looking like an unconditional implementation backlog.
for token in (
    "C-04 CLOSED / EVIDENCE-GATED ABSENT",
    "SBS launch pair",
    "NXMapGet/NXHashGet",
    "do not add production hooks",
):
    require(token in REPORT_TEXT or token in PLAN_TEXT,
            f"C-04 evidence classification drifted: {token}")

print("C-04 SBS/NX evidence static gate: PASS")
print(f"private_candidates={len(PRIVATE_CANDIDATES)} production_hooks=0")
