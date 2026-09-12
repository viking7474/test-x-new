"""Guard every shipped startup entry, including future wildcard build additions."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")
makefile = read("Makefile")
assert "$(filter-out TLinkIOSTweak/UberURLHooks.x,$(wildcard TLinkIOSTweak/*.x))" in makefile
assert "$(filter-out TLinkIOSTweak/AAA_%,$(wildcard TLinkIOSTweak/*.m))" in makefile
pattern = re.compile(r"%ctor\s*\{|__attribute__\s*\(\(constructor(?:\(\d+\))?\)\)\s*"
                     r"(?:static\s+)?void\s+(\w+)\s*\(void\)\s*\{")
entries = 0
for folder in ("TLinkIOSTweak", "common"):
    for path in (ROOT / folder).iterdir():
        if path.suffix not in {".x", ".m"} or path.name.startswith("AAA_") or path.name == "UberURLHooks.x":
            continue
        src = path.read_text(encoding="utf-8")
        assert not re.search(r"^\s*\+\s*\([^)]*\)\s*load\s*\{", src, re.M), f"Audit new +load: {path}"
        matches = list(pattern.finditer(src))
        if path.suffix == ".x" and re.search(r"^%hook\b", src, re.M):
            assert matches, f"Implicit Logos constructor is not gated: {path}"
        for match in matches:
            if match.group(1) == "PXTLinkIOSTweakEarlyLoadMarker":
                assert 'PXFileDebugLoadMarker("TLinkIOSTweak.early");' in src[match.end():match.end()+100]
                continue  # explicit debug-only load telemetry, no hooks/observers
            body = src[match.end():].lstrip()
            body = re.sub(r"^@autoreleasepool\s*\{\s*", "", body)
            assert body.startswith("if (!PXBootstrapAllows("), f"Work before bootstrap gate: {path}"
            entries += 1

assert entries >= 27, f"Startup inventory unexpectedly shrank: {entries}"
scope = read("TLinkIOSTweak/PXScope.m")
assert "static void PXScopeStartObserving(void)" in scope and "PXScopeInit" not in scope
assert "if (result.capabilities) PXScopeStartObserving();" in scope
assert "BOOL safari = NO;" in scope, "No implicit grant to unscoped Safari"
helper = scope.split("BOOL PXIsWebKitHelperProcess(", 1)[1].split("NSString *PXWebKitHostBundleIdentifier", 1)[0]
assert "containsString:" not in helper, "App names must not be mistaken for helper ownership"
host = scope.split("NSString *PXWebKitHostBundleIdentifier(void) {", 1)[1].split("BOOL PXWebKitHostIsScopedForSpoofing", 1)[0]
assert "dispatch_once(" not in host, "Unresolved host must be retryable"
assert "cachedGeneration" in host and "expires = now + 1.0;" in host
assert "resolved && ![resolved isEqualToString:identifier]" in host, "Conflicting host evidence must deny"
assert "stringByResolvingSymlinksInPath" in host and "Containers/Data/Application/" in host
assert "snap.scopedApps[bundleID] == nil" in scope and "gPXExtensionOwner" in scope

for name in ("UUIDHooks", "ObjcClassPairGuard", "DeviceModelHooks", "PrivateIdentityWrapperHooks",
             "ManagedConfigurationIdentityHooks", "UserDefaultsHooks", "PasteboardHooks", "BootTimeHooks"):
    assert "if (!PXBootstrapAllows(PXHookCapabilityNative)) return;" in read(f"TLinkIOSTweak/{name}.x")
assert "PXBootstrapAllows(PXHookCapabilitySpringBoard)" in read("TLinkIOSTweak/SpringBoardLaunchHook.x")
assert "PXBootstrapAllows(PXHookCapabilityTelephony)" in read("TLinkIOSTweak/CoreTelephonyServerIdentityHooks.x")
assert "PXBootstrapAllows(PXHookCapabilityWebContent)" in read("TLinkIOSTweak/CanvasFingerprintHooks.x")
marker = read("TLinkIOSTweak/PXFileDebug.h").split("static inline void PXFileDebugLoadMarker", 1)[1]
assert marker.index('access("/tmp/px_debug_all"') < marker.index("PXFileDebugWritePath(")
print(f"PASS: {entries} constructor gates, retired module exclusion, lazy observers and host resolution contracts")
