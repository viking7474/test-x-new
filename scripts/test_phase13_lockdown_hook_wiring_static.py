#!/usr/bin/env python3
"""Host-independent contracts for the Lockdown identity runtime hook wiring (plan §4).

Phases 5/6/7 shipped the PXLockdown*Resolve providers plus the L0 observe-only layer,
but nothing intercepted a live Lockdown lookup to call them. TLinkIOSTweak/
LockdownIdentityHooks.x is that missing wiring. These checks pin the safety-critical
invariants so the hook can never regress into an always-on or value-leaking state.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOOK = "TLinkIOSTweak/LockdownIdentityHooks.x"


def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")


hook = (ROOT / HOOK).read_text(encoding="utf-8")

# 1. The entire hook is build-gated: no research symbol is referenced outside the gate.
if "#if INTERNAL_SECURITY_RESEARCH" not in hook:
    raise AssertionError("Lockdown hook must be gated behind INTERNAL_SECURITY_RESEARCH")
gate_start = hook.index("#if INTERNAL_SECURITY_RESEARCH")
if "#endif" not in hook[gate_start:]:
    raise AssertionError("Lockdown hook research gate is not closed")
provider_symbols = (
    "PXLockdownDeviceIdentityResolve",
    "PXLockdownSoftwareModelResolve",
    "PXLockdownSoCCellularResolve",
    "PXLockdownResearchRuntime",
)
for symbol in provider_symbols:
    first = hook.index(symbol) if symbol in hook else None
    if first is not None and first < gate_start:
        raise AssertionError(f"{symbol} referenced outside the research gate")

# 2. Wires every provider family plus the safety runtime and observability layer.
require(HOOK, [
    '#import "PXLockdownResearchSafety.h"',
    '#import "PXLockdownSoftwareModelProvider.h"',
    '#import "PXLockdownDeviceIdentityProvider.h"',
    '#import "PXLockdownSoCCellularProvider.h"',
    '#import "PXLockdownObservability.h"',
    # dispatch by key group through the real resolvers
    "PXLockdownDeviceIdentityEntryForKey",
    "PXLockdownSoftwareModelEntryForKey",
    "PXLockdownSoCCellularEntryForKey",
    "PXLockdownDeviceIdentityResolve",
    "PXLockdownSoftwareModelResolve",
    "PXLockdownSoCCellularResolve",
    # options are derived from the profile settings, never hard-coded
    "PXLockdownDeviceIdentityOptionsFromSettings",
    "PXLockdownSoftwareModelOptionsFromSettings",
    "PXLockdownSoCCellularOptionsFromSettings",
    # per-process safety decision drives every replacement
    "decisionForBundleID:",
    "processName:",
    "now:",
    "activateAt:",
    # runtime key -> firmware constant-name translation
    "PXLockdownConstNameForRuntimeKey",
    '@"kLockdownUniqueDeviceIDKey"',
    '@"kLockdownProductTypeKey"',
    '@"kLockdownUniqueChipIDKey"',
    '@"kLockdownIMEIKey"',
    # the live interception target
    "lockdown_copy_value",
    "MSHookFunction",
    "liblockdown.dylib",
])

# 3. Fail-closed and least-privilege guarantees.
require(HOOK, [
    "PXLockdownObservationDomainIsForbidden",  # never touch pairing/cert/escrow domains
    "policy.masterEnabled",                    # off unless the master switch is on
    "bundleAllowlist",                         # armed only for allowlisted processes
    "gInsideLockdownHook",                     # reentrancy guard
    "CFBridgingRetain",                        # correct +1 ownership when replacing
])
if "return original" not in hook:
    raise AssertionError("Lockdown hook must fail closed to the original value")

# 4. Redacted audit only: the hook must never log a raw resolved/candidate value.
if "PXLockdownRedactedAuditEvent" not in hook:
    raise AssertionError("Lockdown hook must emit redacted audit metadata only")
for banned in ("PXLog(@\"[LockdownIdentityHooks] value", "resolved]", "originalObj]"):
    if banned in hook:
        raise AssertionError(f"Lockdown hook must not log raw runtime values ({banned})")

# 5. The Makefile compiles TLinkIOSTweak/*.x unconditionally (so this file ships in
#    research builds) while the research .m sources stay on an explicit allowlist.
makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
if "$(wildcard TLinkIOSTweak/*.x)" not in makefile:
    raise AssertionError("TLinkIOSTweak/*.x wildcard missing; hook would not compile")
if "$(wildcard research/*.m)" in makefile:
    raise AssertionError("Research source must use an explicit allowlist, not a wildcard")

print("Phase-13 Lockdown hook wiring contracts: PASS")
