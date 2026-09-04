#!/usr/bin/env python3
"""P0-00 static hook-parity baseline against the locked iFake inventory.

This test intentionally records both covered surfaces and expected gaps.  It must
fail when an existing covered surface disappears, when a Phase-A/B expected gap
is silently added without updating the baseline, or when a BLOCKED/high-risk
installer appears in production tweak source.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TWEAK_ROOT = ROOT / "TLinkIOSTweak"
FIXTURE = ROOT / "tests" / "fixtures" / "ifake_parity_profile.json"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def production_tweak_text() -> str:
    parts: list[str] = []
    for path in sorted(TWEAK_ROOT.glob("*")):
        if path.suffix not in {".x", ".m", ".h"}:
            continue
        parts.append(f"\n/* FILE: {path.name} */\n")
        parts.append(path.read_text(encoding="utf-8", errors="replace"))
    return "".join(parts)


PRODUCTION = production_tweak_text()

# Covered surfaces are expressed as source contracts rather than raw hook counts.
COVERED = {
    "TLinkIOSTweak/Tweak.x": [
        r"%hookf\(CFTypeRef,\s*MGCopyAnswer,",
        r"PXInstallAlternateMobileGestaltHooks\(\);",
        r"MSHookFunction\(unamePtr,\s*\(void \*\)uname_hook",
        r"locationManager:\(CLLocationManager \*\)manager didUpdateLocations:",
        r"locationManager:\(CLLocationManager \*\)manager didUpdateToLocation:",
        r"locationManager:\(CLLocationManager \*\)manager didUpdateHeading:",
        r"locationManager:\(CLLocationManager \*\)manager didEnterRegion:",
        r"locationManager:\(CLLocationManager \*\)manager didExitRegion:",
        r"%hook CMAccelerometerData",
        r"%hook CMGyroData",
        r"%hook CMMagnetometerData",
        r"%hook CMDeviceMotion",
        r"%hook CMMotionManager",
    ],
    "TLinkIOSTweak/PXNativeHookCoordinator.m": [
        r'kPXNativeSymbolSysctl\s*=\s*@"sysctl"',
        r'kPXNativeSymbolSysctlByname\s*=\s*@"sysctlbyname"',
        r'kPXNativeSymbolSysctlNameToMIB\s*=\s*@"sysctlnametomib"',
        r'PXCoord_sysctlnametomib',
        r'_installSymbol:kPXNativeSymbolSysctlNameToMIB',
        r'kPXNativeSymbolIORegistryEntryCreateCFProperty\s*=\s*@"IORegistryEntryCreateCFProperty"',
        r'kPXNativeSymbolIORegistryEntryCreateCFProperties\s*=\s*@"IORegistryEntryCreateCFProperties"',
        r'kPXNativeSymbolIORegistryEntrySearchCFProperty\s*=\s*@"IORegistryEntrySearchCFProperty"',
        r'kPXNativeSymbolGetifaddrs\s*=\s*@"getifaddrs"',
        r'kPXNativeSymbolCNCopyCurrentNetworkInfo\s*=\s*@"CNCopyCurrentNetworkInfo"',
    ],
    "TLinkIOSTweak/LockdownIdentityHooks.x": [
        r'dlsym\(handle,\s*"lockdown_copy_value"\)',
        r'MSHookFunction\(symbol,\s*\(void \*\)px_lockdown_copy_value',
    ],
    "TLinkIOSTweak/JailbreakBypassHooks.x": [
        r"%hook NSFileManager",
        r"%hook NSFileHandle",
        r"%hook NSFileWrapper",
        r"%hook NSFileVersion",
        r"%hook UIImage",
        r"%hook LSApplicationWorkspace",
        r'FindSymbol\("objc_copyClassNamesForImage"\)',
        r'FindSymbol\("bootstrap_look_up"\)',
        r'FindSymbol\("__opendir2"\)',
        r'FindSymbol\("fstat64"\)',
        r'FindSymbol\("fstatat64"\)',
        r'FindSymbol\("fstatfs64"\)',
        r'static DIR \*hook___opendir2.*?PXJBClassifyFilesystemPathAt.*?errno = ENOENT;.*?PXJBOriginalOpenDir2',
        r'static int hook_fstat64.*?PXJBClassifyFileDescriptorPath.*?errno = EBADF;.*?orig_fstat64',
        r'static int hook_fstatat64.*?PXJBClassifyFilesystemPathAt.*?errno = ENOENT;.*?orig_fstatat64',
        r'static int hook_fstatfs64.*?PXJBClassifyFileDescriptorPath.*?errno = EBADF;.*?orig_fstatfs64',
        r'FindSymbol\("pathconf"\)', r'FindSymbol\("fpathconf"\)',
        r'FindSymbol\("getattrlist"\)', r'FindSymbol\("fgetattrlist"\)',
        r'FindSymbol\("getxattr"\)', r'FindSymbol\("fgetxattr"\)',
        r'FindSymbol\("listxattr"\)', r'FindSymbol\("flistxattr"\)',
        r'hook_pathconf.*?PXJBRejectHiddenPathReadQuery.*?orig_pathconf\(path, name\)',
        r'hook_fpathconf.*?PXJBRejectHiddenFDReadQuery.*?orig_fpathconf\(fd, name\)',
        r'hook_getattrlist.*?orig_getattrlist\(path, attrList, attrBuf, attrBufSize, options\)',
        r'hook_fgetattrlist.*?orig_fgetattrlist\(fd, attrList, attrBuf, attrBufSize, options\)',
        r'hook_getxattr.*?orig_getxattr\(path, name, value, size, position, options\)',
        r'hook_fgetxattr.*?orig_fgetxattr\(fd, name, value, size, position, options\)',
        r'hook_listxattr.*?orig_listxattr\(path, nameBuffer, size, options\)',
        r'hook_flistxattr.*?orig_flistxattr\(fd, nameBuffer, size, options\)',
        r'FindSymbol\("readdir_r"\)', r'FindSymbol\("issetugid"\)',
        r'FindSymbol\("getgroups"\)', r'FindSymbol\("getpeername"\)',
        r'FindSymbol\("getsockname"\)',
        r'hook_readdir_r.*?PXJBDirectoryEntryShouldHide.*?PXJBRecordBlockedEvent\("readdir_r"',
        r'hook_issetugid.*?orig_issetugid.*?PXJBShouldBypassCached\(\).*?original != 0.*?return 0',
        r'hook_getgroups.*?orig_getgroups.*?PXP1CJBCompactNonRootGroups\(grouplist, count\)',
        r'PXJBSocketEndpointShouldHide.*?address->sa_family != AF_INET.*?PXP1CJBEndpointPortShouldHide',
        r'hook_getpeername.*?orig_getpeername.*?PXJBSocketEndpointShouldHide.*?errno = ENOTCONN',
        r'hook_getsockname.*?orig_getsockname.*?PXJBSocketEndpointShouldHide.*?errno = ENOTCONN',
        r'%hook NSThread',
        r'callStackReturnAddresses.*?PXP1CJBArrayByReplacingMatchingObjects.*?@0',
        r'callStackSymbols.*?PXP1CJBArrayByReplacingMatchingObjects.*?@"<redacted frame>"',
        r'PXJBCallStackAddressBelongsToHiddenImage.*?dladdr.*?PXJBShouldHideImageName',
        r'%hook NSProcessInfo.*?- \(NSArray<NSString \*> \*\)arguments.*?PXP1CJBFilterProcessArguments',
        r'PXP1CJBURLSchemeShouldHide\(url\.scheme\)',
        r'objc_getClass\("_LSCanOpenURLManager"\)',
        r'canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:',
        r'PXJBLSCanOpenURLMethodEncodingMatches',
        r'MSHookMessageEx\(cls,.*?PXJBHookLSCanOpenURL',
        r'typedef Boolean \(\*PXJBSCIsRunningWithDebuggerFunction\)\(void\);',
        r'kPXJBPolicySCDebuggerScalar\s*=\s*1ull << 11',
        r'kPXJBCapabilitySCDebuggerScalar',
        r'\.name = "sc-debugger".*?\.policyBit = kPXJBPolicySCDebuggerScalar',
        r'PXJBPolicyMask mask = kPXJBPolicyMaster \| kPXJBPolicySCDebuggerScalar;',
        r'static Boolean hook_SCIsRunningWithDebugger\(void\).*?PXJBSCDebuggerScalarEnabled\(\).*?return \(Boolean\)0;.*?original \? original\(\)',
        r'FindSymbol\("SCIsRunningWithDebugger"\).*?MSHookFunction\(sym,.*?hook_SCIsRunningWithDebugger.*?orig_SCIsRunningWithDebugger',
        r'PXJB_AUDIT\(kPXJBCapabilitySCDebuggerScalar,.*?"SCIsRunningWithDebugger",.*?orig_SCIsRunningWithDebugger,.*?true\)',
    ],
    "TLinkIOSTweak/VPNDetectionBypass.x": [
        r'CFNetworkCopySystemProxySettings',
        r'SCDynamicStoreCopyProxies',
        r'CFNetworkCopyProxiesForAutoConfigurationScript',
        r'PXHookCFNetworkCopyProxiesForAutoConfigurationScript.*?originalFunction\(script, targetURL, error\)',
        r'error && \*error',
        r'CFGetTypeID\(original\) != CFArrayGetTypeID\(\)',
        r'PXPACProjectedProxyValue\(originalObject, YES\)',
        r'CFBridgingRetain\(projected\)',
        r'CFRelease\(original\)',
    ],
    "TLinkIOSTweak/PXPACProxySanitizer.m": [
        r'PXPACProxyTypeKey.*?kCFProxyTypeKey',
        r'PXPACDirectType.*?kCFProxyTypeNone',
        r'kCFProxyHostNameKey',
        r'kCFProxyPortNumberKey',
        r'kCFProxyAutoConfigurationURLKey',
        r'kCFProxyAutoConfigurationJavaScriptKey',
        r'return originalValue;',
    ],
    "TLinkIOSTweak/LocaleTimeZoneHooks.x": [
        r"%hook NSLocale",
        r"%hook NSTimeZone",
        r"CFTimeZoneCopySystem",
        r"CFTimeZoneCopyDefault",
        r"%hookf\(struct tm \*, localtime,",
        r"%hookf\(struct tm \*, localtime_r,",
        r"%hookf\(char \*, setlocale,",
        r"gLTZInsideCLibTimeHook",
        r"PXSetlocaleShouldUseCanonicalInput",
        r"LTZApplyProcessTimeZone\(\);",
        r"%hook NSBundle",
        r"preferredLocalizations",
        r"PXPreferredLocalizationsProjection\(original,",
        r"LTZPinnedPreferredLanguages\(\)",
        r"LTZPinnedLocaleIdentifier\(\)",
    ],
    "TLinkIOSTweak/CanvasFingerprintHooks.x": [
        r"HTMLCanvasElement",
        r"toDataURL",
        r"WebGLRenderingContext",
        r"readPixels",
    ],
    "TLinkIOSTweak/ManagedConfigurationIdentityHooks.x": [
        r'"MCCTIMEI"',
        r'"MCIOSerialString"',
        r'"MCProductVersion"',
        r'"MCProductBuildVersion"',
        r'"MCGestaltGetProductName"',
        r'"MCGestaltGetDeviceUUID"',
        r'PXIdentitySurfaceManagedConfiguration',
        r'PXCurrentIdentitySnapshot\(\)',
        r'PXProcessIsAllowedForSpoofing',
        r'isIdentifierEnabled:entry\.toggle',
        r'MSHookFunction\(symbol, specs\[index\]\.replacement',
    ],
    "TLinkIOSTweak/CoreTelephonyServerIdentityHooks.x": [
        r'"_CTServerConnectionCopyMobileEquipmentInfo"',
        r'"_CTServerConnectionCopyMobileEquipmentInfoV2"',
        r'PXIdentitySurfaceCoreTelephonyServer',
        r'PXCurrentIdentitySnapshot\(\)',
        r'PXProcessIsAllowedForSpoofing',
        r'PXCoreTelephonyServerApplyIdentityOverlay',
        r'int64_t status = original \? original\(arg1, arg2, outInformation\) : 0;',
        r'MSHookFunction\(symbol, specs\[index\]\.replacement',
    ],
    "TLinkIOSTweak/PrivateIdentityWrapperHooks.x": [
        r'PXPrivateIdentityClassIsSystemOwned',
        r'PXPrivateIdentityWrapperRuleDescriptors',
        r'PXPrivateIdentityWrapperMethodEncodingIsSupported',
        r'PXIdentitySurfacePrivateWrapper',
        r'MSHookMessageEx\(targetClass, selector, replacement, &original\)',
        r'_dyld_register_func_for_add_image\(PXPrivateIdentityDyldImageAdded\)',
    ],
}

for rel, patterns in COVERED.items():
    text = read(rel)
    for pattern in patterns:
        require(re.search(pattern, text, re.S) is not None,
                f"covered parity surface disappeared: {rel}: /{pattern}/")

# Exact parity gaps that are approved for implementation but have not landed yet.
# C-01 closes the final raw symbol in this bucket; later Phase-C candidates are
# evidence-gated and therefore are not treated as unconditional expected gaps.
EXPECTED_MISSING_RAW = []
for symbol in EXPECTED_MISSING_RAW:
    require(symbol not in PRODUCTION,
            f"expected-missing parity surface is now present; update baseline/task evidence: {symbol}")

# Phase-C evidence-gated omissions are intentionally absent until a concrete
# bypass fixture proves that the narrower existing owners cannot cover them.
EVIDENCE_GATED_ABSENT_RAW = [
    "CFPropertyListCreateWithData",
    "HTMLCanvasElement::toDataURL",
    "glReadPixels",
    "glGetString",
]
for symbol in EVIDENCE_GATED_ABSENT_RAW:
    require(symbol not in PRODUCTION,
            f"evidence-gated parity surface appeared without reclassification: {symbol}")

c03 = read("scripts/test_c03_native_webgl_evidence.js")
for token in (
    "HTMLCanvasElement.prototype.toDataURL",
    "glGetString vendor/renderer/version",
    "glReadPixels client-memory RGBA/U8",
    "proto.toDataURL = function ()",
    "proto.getParameter = function (parameter)",
    "proto.readPixels = function ()",
    "originalReadPixels.apply(this, arguments)",
    "C-03 native WebCore/OpenGL evidence: PASS",
):
    require(token in c03, f"C-03 evidence fixture drifted: {token}")

# The C locale/time trio moved to covered in A-04. Keep this bucket for future
# install-pattern-only gaps whose symbol names may also appear as ordinary calls.
EXPECTED_MISSING_INSTALL_PATTERNS = {}

# BLOCKED parity gaps: these must remain absent from production tweak source.
BLOCKED_RAW = [
    "SecTaskCopyValueForEntitlement",
    "SecCodeCopySigningInformation",
    "SecStaticCodeCreateWithPath",
    "SecStaticCodeCheckValidityWithErrors",
    "SecStaticCodeCheckValidity",
]
for symbol in BLOCKED_RAW:
    require(symbol not in PRODUCTION, f"BLOCKED Security.framework surface appeared: {symbol}")

# High-risk generic entry points may be referenced/called by normal code. Assert
# that production does not install them as hooks. These regexes intentionally
# target installer syntax/comments are not enough to fail the gate.
BLOCKED_INSTALL_PATTERNS = {
    "syscall": [r'FindSymbol\("syscall"\).*?MSHookFunction', r'MSHookFunction\([^;]{0,240}\bsyscall\b'],
    "sandbox_check": [r'FindSymbol\("sandbox_check"\).*?MSHookFunction', r'MSHookFunction\([^;]{0,240}\bsandbox_check\b'],
    "generic fcntl": [r'MSHookFunction\([^;]{0,240}\bhook_fcntl\b'],
    "dyld image count": [r'MSHookFunction\([^;]{0,240}\b_dyld_image_count\b'],
    "dyld image header": [r'MSHookFunction\([^;]{0,240}\b_dyld_get_image_header\b'],
    "dyld image slide": [r'MSHookFunction\([^;]{0,240}\b_dyld_get_image_vmaddr_slide\b'],
}
for label, patterns in BLOCKED_INSTALL_PATTERNS.items():
    require(not any(re.search(p, PRODUCTION, re.S) for p in patterns),
            f"BLOCKED/high-risk production installer appeared: {label}")

# Machine-readable canonical fixture used by subsequent parity tasks.
fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
require(fixture.get("profileID") == "ifake-parity-fixture", "parity fixture profileID drifted")
require(isinstance(fixture.get("generation"), int) and fixture["generation"] > 0,
        "parity fixture generation must be a positive integer")
ids = fixture.get("deviceIDs")
require(isinstance(ids, dict), "parity fixture deviceIDs must be an object")
REQUIRED_FIXTURE_KEYS = {
    "IOSVersion", "IOSBuild", "Darwin", "KernelVersion",
    "DeviceModel", "DeviceModelName", "HwModel", "BoardID", "ModelNumber", "DeviceName",
    "SerialNumber", "MLBSerialNumber", "UDID", "SystemBootUUID", "IDFA",
    "IMEI", "IMEI2", "MEID", "IMSI", "ICCID", "BasebandVersion",
    "LocaleIdentifier", "Language", "TimeZone",
}
missing = sorted(REQUIRED_FIXTURE_KEYS - set(ids))
require(not missing, f"parity fixture is missing canonical fields: {missing}")

summary = {
    "covered_contract_files": len(COVERED),
    "phase_a_exact_missing": sorted(EXPECTED_MISSING_RAW),
    "phase_a_c_locale_missing": sorted(EXPECTED_MISSING_INSTALL_PATTERNS),
    "evidence_gated_absent": sorted(EVIDENCE_GATED_ABSENT_RAW),
    "blocked_security": BLOCKED_RAW,
    "fixture_required_keys": len(REQUIRED_FIXTURE_KEYS),
}
print("ifake parity static baseline: PASS")
print(json.dumps(summary, sort_keys=True))
