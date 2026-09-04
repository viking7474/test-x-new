#!/usr/bin/env python3
"""C-02 evidence gate: keep CFPropertyListCreateWithData unhooked unless provenance bypass is proven."""
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


transformer_h = read("common/PXSystemVersionTransformer.h")
transformer_m = read("common/PXSystemVersionTransformer.m")
ios = read("TLinkIOSTweak/IOSVersionHooks.x")
tweak = read("TLinkIOSTweak/Tweak.x")
evidence = read("tests/PXCFPropertyListParityEvidenceTests.m")
main = read("tests/PXCFPropertyListParityEvidenceMain.m")
production = production_text()

# Canonical transformer must keep a path-provenance classifier and structural
# dictionary/data transformers with fail-open behavior.
for token in (
    "PXIsSystemVersionPlistPath",
    "PXTransformSystemVersionDictionary",
    "PXTransformSystemVersionData",
):
    require(token in transformer_h, f"C-02 transformer API missing: {token}")

for token in (
    'static NSString *const canonical = @"/System/Library/CoreServices/SystemVersion.plist";',
    "[normalized isEqualToString:canonical] || [normalized hasSuffix:canonical]",
    "if (parseError || ![root isKindOfClass:[NSDictionary class]]) return original;",
    "if (transformed == root) return original;",
    "return (!serializeError && candidate.length > 0) ? candidate : original;",
):
    require(token in transformer_m, f"C-02 structural/fail-open transformer contract drifted: {token}")

# The production file boundary must transform proven SystemVersion bytes before
# any downstream parser consumes them. Direct dictionary/string readers use the
# same owner rather than introducing a second policy.
for token in (
    "NSData *replaced_NSData_dataWithContentsOfFile",
    "if (!originalData || !isSystemVersionFile(path)) return originalData;",
    "return projection ? PXTransformSystemVersionData(originalData, projection) : originalData;",
    "NSDictionary *replaced_NSDictionary_dictionaryWithContentsOfFile",
    "return spoofSystemVersionPlist(originalDictionary);",
    "replaced_NSString_stringWithContentsOfFile",
    "PXTransformSystemVersionString(originalString, encoding, projection)",
):
    require(token in ios, f"C-02 upstream SystemVersion loader contract missing: {token}")

# Direct CoreFoundation SystemVersion queries are already transformed through the
# same canonical dictionary transformer and preserve Copy ownership.
for token in (
    "static CFDictionaryRef CFCopySystemVersionDictionary_hook(void)",
    "PXTransformSystemVersionDictionary(base, projection)",
    "CFDictionaryRef result = CFBridgingRetain(transformed);",
    "if (original) CFRelease(original);",
    'registerCFCopySystemVersionDictionaryProvider:@"tweak.cf.systemversion"',
):
    require(token in tweak, f"C-02 direct CF SystemVersion coverage drifted: {token}")

# Evidence fixture must exercise the exact parser API after path-bound upstream
# transformation and must include a same-key generic plist counterexample.
for token in (
    "CFPropertyListCreateWithData(kCFAllocatorDefault",
    "PXC02PathBoundRawRead",
    'NSString *canonicalPath = @"/System/Library/CoreServices/SystemVersion.plist";',
    'NSString *rootlessPath = @"/var/jb/System/Library/CoreServices/SystemVersion.plist";',
    'NSString *genericPath = @"/tmp/app-owned.plist";',
    "C-02 canonical raw-data boundary did not transform",
    "C-02 generic app plist was rewritten without provenance",
    "C-02 malformed data must fail open before parser",
    "C-02 malformed exact-CF parse must preserve native failure behavior",
    "C-02 dictionary/data routes diverged on ProductVersion",
):
    require(token in evidence, f"C-02 evidence fixture incomplete: {token}")

require("PXRunCFPropertyListParityEvidenceTests();" in main,
        "C-02 evidence fixture is not wired into the consistency harness")

# Decision gate: no production parser interception is justified by current
# evidence. The exact symbol may appear in tests/docs, but not the tweak source.
require("CFPropertyListCreateWithData" not in production,
        "C-02 evidence-gated parser hook/call appeared in production without a proven bypass")

# Also defend against obfuscated/indirect installer variants should the raw token
# eventually appear near generic hook machinery.
for pattern in (
    r'FindSymbol\("CFPropertyListCreateWithData"\)',
    r'dlsym\([^;]{0,240}"CFPropertyListCreateWithData"',
    r'MSHookFunction\([^;]{0,320}CFPropertyListCreateWithData',
):
    require(not re.search(pattern, production, re.S),
            f"C-02 production parser installer appeared: {pattern}")

print("C-02 CFPropertyList evidence gate: PASS (no parser hook justified)")
