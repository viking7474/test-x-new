#!/usr/bin/env python3
"""B-06 static regression gate for safe Phase-B parity additions."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_ROOT = ROOT / "TLinkIOSTweak"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def production_text() -> str:
    chunks: list[str] = []
    for suffix in ("*.x", "*.m", "*.mm", "*.c"):
        for path in sorted(PRODUCTION_ROOT.glob(suffix)):
            chunks.append(f"\n/* {path.name} */\n")
            chunks.append(path.read_text(encoding="utf-8", errors="replace"))
    return "".join(chunks)


matrix = read("tests/PXPhaseBRegressionGateTests.m")
for case in (
    "PXPhaseBCaseSpoofDisabled",
    "PXPhaseBCaseSpoofEnabledFullProfile",
    "PXPhaseBCaseJailbreakBypassDisabled",
    "PXPhaseBCaseJailbreakBypassEnabled",
    "PXPhaseBCaseMissingSnapshot",
    "PXPhaseBCaseAppExtension",
    "PXPhaseBCaseWebKitHelper",
    "PXPhaseBCaseSpringBoardMinimal",
):
    require(case in matrix, f"B-06 regression matrix missing case: {case}")

for token in (
    "PXP1CScopeBundleEnabled",
    "PXP1CJBRequestedMask",
    "PXP1CJBEffectivePolicyMask",
    "PXP1CJBFeatureActive",
    "PXP1CSnapshotNeedsRefresh",
    "PXInjectionComputeTweakBundles",
    "PXInjectionComputeBridgeBundles",
    "PXP1CWebKitHostScoped",
    "PXInjectionSpringBoardBundleID",
):
    require(token in matrix, f"B-06 matrix does not exercise canonical helper: {token}")

# Full identity profile, scope-off, missing/malformed fields and generation swap
# remain owned by the Phase-A integration fixture rather than being duplicated.
phase_a = read("tests/PXPhaseAConsistencyGateTests.m")
for token in (
    'PXPhaseAAssertMatrixScenario(ids, allOn, YES, @"canonical")',
    '@"missing UDID"',
    '@"malformed IMEI"',
    '@"scope off"',
    '@"generation swap"',
):
    require(token in phase_a, f"B-06 lost Phase-A identity regression prerequisite: {token}")

# App/extension/WebKit injection expansion remains centralized and bridge-safe.
injection = read("tests/PXInjectionFilterTests.m")
for token in (
    '"tweak keeps extension bundle"',
    '"bridge keeps only third-party app/extensions, sorted"',
    '"bridge drops SpringBoard"',
    '"bridge drops WebKit helpers"',
    '"empty scope -> placeholder-only tweak filter"',
):
    require(token in injection, f"B-06 injection-filter prerequisite drifted: {token}")

scope = read("TLinkIOSTweak/PXScope.m")
for token in (
    "if (!PXDeviceSpoofingEnabled()) return NO;",
    "if (!host.length) return NO; // fail closed",
    "PXWebKitHostIsScopedForSpoofing()",
    "PXScopeOptionAllowSafariAuthStack",
):
    require(token in scope, f"B-06 WebKit fail-closed scope contract drifted: {token}")

jb = read("TLinkIOSTweak/JailbreakBypassHooks.x")
for token in (
    'if (!PXJBSettingEnabled(settings, @"jailbreakDetectionEnabled")) return 0;',
    'BOOL masterJB = PXJBSettingEnabled(launchSettings, @"jailbreakDetectionEnabled");',
    "if (!masterJB) {",
    "return;",
):
    require(token in jb, f"B-06 JB launch gate drifted: {token}")

# SpringBoard may host the profile indicator, but must return before the identity
# observer/full app spoof stack starts. WebKit helpers likewise cannot install the
# ordinary native spoof hook group just because the helper process is injected.
tweak = read("TLinkIOSTweak/Tweak.x")
minimal = '''        });\n        return;\n    }\n\n    PXIdentitySnapshotStartObserving();'''
require(minimal in tweak,
        "B-06 SpringBoard minimal return no longer precedes identity/full spoof initialization")
require("shouldInstallSpoofHooks = enabled && !isWebKitHelper;" in tweak,
        "B-06 WebKit helper can enter ordinary native spoof hook profile")
require("if (!shouldInstallSpoofHooks) {" in tweak and "return;" in tweak.split("if (!shouldInstallSpoofHooks) {", 1)[1][:600],
        "B-06 ordinary native spoof hook profile no longer fails closed")

production = production_text()

# Security.framework falsification is a raw absence requirement.
blocked_security = (
    "SecTaskCopyValueForEntitlement",
    "SecCodeCopySigningInformation",
    "SecStaticCodeCreateWithPath",
    "SecStaticCodeCheckValidityWithErrors",
    "SecStaticCodeCheckValidity",
)
for symbol in blocked_security:
    require(symbol not in production, f"B-06 BLOCKED Security surface appeared: {symbol}")

# Generic/high-risk primitives may be referenced by helpers; forbid hook installers,
# not ordinary API calls. Dyld image APIs may be read for provenance but cardinality
# interception remains forbidden.
blocked_installers = {
    "generic syscall": [r'FindSymbol\("syscall"\).*?MSHookFunction', r'MSHookFunction\([^;]{0,240}\bsyscall\b'],
    "sandbox_check": [r'FindSymbol\("sandbox_check"\).*?MSHookFunction', r'MSHookFunction\([^;]{0,240}\bsandbox_check\b'],
    "generic fcntl": [r'MSHookFunction\([^;]{0,240}\bhook_fcntl\b'],
    "dyld image count": [r'MSHookFunction\([^;]{0,240}\b_dyld_image_count\b'],
    "dyld image header": [r'MSHookFunction\([^;]{0,240}\b_dyld_get_image_header\b'],
    "dyld image slide": [r'MSHookFunction\([^;]{0,240}\b_dyld_get_image_vmaddr_slide\b'],
    "generic memory patch": [r'\bMSHookMemory\s*\('],
}
for label, patterns in blocked_installers.items():
    require(not any(re.search(pattern, production, re.S) for pattern in patterns),
            f"B-06 BLOCKED/high-risk production installer appeared: {label}")

# Phase B must not regress TLS/certificate behavior while proxy and network parity
# surfaces are present.
vpn = read("TLinkIOSTweak/VPNDetectionBypass.x")
for token in ("SecTrust", "serverTrust", "NSURLAuthenticationChallenge"):
    require(token not in vpn, f"B-06 VPN/PAC module gained TLS/trust behavior: {token}")

pac = read("TLinkIOSTweak/PXPACProxySanitizer.m")
require("kCFProxyTypeKey" in pac and "kCFProxyTypeNone" in pac,
        "B-06 PAC sanitizer must use CFNetwork's canonical proxy key/type constants")
require('@"direct"' not in pac,
        "B-06 PAC sanitizer must not invent a non-CFNetwork direct proxy type")

print("Phase-B regression static gate: PASS")
