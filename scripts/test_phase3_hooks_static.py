#!/usr/bin/env python3
"""Host-independent Phase-3 registry/hook contracts."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [n for n in needles if n not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")

def forbid(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    present = [n for n in needles if n in text]
    if present:
        raise AssertionError(f"{path}: forbidden contracts present: {present}")

require("common/PXIdentitySurfaceRegistry.h", [
    'PXIdentitySurfaceManagedConfiguration',
    'PXIdentitySurfaceCoreTelephonyServer',
    'PXIdentitySurfacePrivateWrapper',
])
require("common/PXIdentitySurfaceRegistry.m", [
    '@"ProductType"', '@"HWModelStr"', '@"HardwareModel"', '@"BoardId"',
    '@"ProductVersion"', '@"ProductBuildVersion"', '@"BuildVersion"',
    '@"device-model"', '@"product-name"', '@"model"', '@"board-id"',
    '@"compatible"', 'PXIdentityExpectedTypeData', 'duplicate surface alias',
    '@"MCCTIMEI"', '@"MCIOSerialString"', '@"MCProductVersion"',
    '@"MCProductBuildVersion"', '@"MCGestaltGetProductName"', '@"MCGestaltGetDeviceUUID"',
    '@"kCTMobileEquipmentInfoCurrentMobileId"', '@"kCTMobileEquipmentInfoIMEI"',
    '@"kCTMobileEquipmentInfoIMSI"', '@"kCTMobileEquipmentInfoMEID"',
    '@"kCTPostponementInfoIMEI"', '@"kCTPostponementInfoMEID"',
    '@"sf_productType"', '@"sf_serialNumber"', '@"sf_udidString"', '@"sf_uuidString"',
    '@"applicationDSID"', '@"internationalMobileEquipmentIdentity2"', '@"_iOSComponentBuildVersion"',
    'bit <= PXIdentitySurfacePrivateWrapper',
])
require("TLinkIOSTweak/ManagedConfigurationIdentityHooks.x", [
    'ManagedConfiguration.framework/ManagedConfiguration',
    'MCCTIMEI', 'MCIOSerialString', 'MCProductVersion', 'MCProductBuildVersion',
    'MCGestaltGetProductName', 'MCGestaltGetDeviceUUID',
    'PXIdentitySurfaceManagedConfiguration', 'PXCurrentIdentitySnapshot()',
    'PXProcessIsAllowedForSpoofing', 'isIdentifierEnabled:entry.toggle',
    'MSHookFunction(symbol, specs[index].replacement',
])
require("TLinkIOSTweak/CoreTelephonyServerIdentityHooks.x", [
    'CoreTelephony.framework/CoreTelephony',
    '_CTServerConnectionCopyMobileEquipmentInfo',
    '_CTServerConnectionCopyMobileEquipmentInfoV2',
    'PXIdentitySurfaceCoreTelephonyServer', 'PXCurrentIdentitySnapshot()',
    'PXProcessIsAllowedForSpoofing', 'PXCoreTelephonyServerApplyIdentityOverlay',
    'int64_t status = original ? original(arg1, arg2, outInformation) : 0;',
    'MSHookFunction(symbol, specs[index].replacement',
])
require("TLinkIOSTweak/PXNativeHookCoordinator.h", [
    'PXSysctlNameToMIBPreBlock', 'PXSysctlNameToMIBPostBlock',
    'registerSysctlNameToMIBProvider', 'kPXNativeSymbolSysctlNameToMIB',
])
require("TLinkIOSTweak/PXNativeHookCoordinator.m", [
    'kPXNativeSymbolSysctlNameToMIB = @"sysctlnametomib"',
    'g_orig_sysctlnametomib', 'g_inside_sysctlnametomib',
    'PXCoord_sysctlnametomib', 'registerSysctlNameToMIBProvider',
    '_installSymbol:kPXNativeSymbolSysctlNameToMIB',
])
require("tests/PXSysctlNameToMIBContractTests.m", [
    'sysctlnametomib("kern.osrelease"',
    'PXAssertDirectAndIndirectSysctlAgree("kern.osrelease")',
    'PXAssertDirectAndIndirectSysctlAgree("hw.machine")',
    'errno == ENOMEM', 'unknown sysctl name unexpectedly resolved',
])
require("TLinkIOSTweak/LocaleTimeZoneHooks.x", [
    '%hookf(struct tm *, localtime,', '%hookf(struct tm *, localtime_r,',
    '%hookf(char *, setlocale,', 'gLTZInsideCLibTimeHook',
    'PXSetlocaleShouldUseCanonicalInput', 'LTZApplyProcessTimeZone();',
    'gLTZProcessTimeZoneLock',
])
require("common/PXLocaleRuntimeProjection.m", [
    'PXCanonicalCLocaleName', 'PXSetlocaleCategorySupportsProjection',
    'PXSetlocaleShouldUseCanonicalInput', 'stringByAppendingString:@".UTF-8"',
])
require("tests/PXLocaleRuntimeProjectionTests.m", [
    'en_US.UTF-8', 'setlocale query semantics must not be rewritten',
    'localtime and localtime_r diverged', 'Asia/Ho_Chi_Minh',
])
require("common/PXPrivateIdentityWrapperProjection.m", [
    'PXPrivateIdentityWrapperRuleDescriptors', 'PXPrivateIdentityWrapperMethodEncodingIsSupported',
    '@"UIDevice"', '@"deviceInfoForKey:"', '@"AMSDevice"', '@"AADeviceInfo"',
    '@"AKDevice"', '@"AMSUserAgent"', 'PXIdentitySurfacePrivateWrapper',
])
require("TLinkIOSTweak/PrivateIdentityWrapperHooks.x", [
    'PXPrivateIdentityClassIsSystemOwned', '/System/Library/', '/usr/lib/',
    'PXPrivateIdentityProcessAllowed', 'PXPrivateIdentityProjectionContext',
    'PXProcessIsAllowedForSpoofing',
    'MSHookMessageEx(targetClass, selector, replacement, &original)',
    'PXPrivateIdentityAlreadyInstalled', '_dyld_register_func_for_add_image',
    'PXPrivateIdentityWrapperMethodEncodingIsSupported', 'PXCurrentIdentitySnapshot()',
    'isIdentifierEnabled:entry.toggle',
])
require("tests/PXPrivateIdentityWrapperProjectionTests.m", [
    'generic Device class must stay excluded', 'Secure Element / PassKit evidence class entered A-05 allowlist',
    'vendor anti-fraud class entered A-05 allowlist', 'sf_uuidString must project canonical IDFA',
    'unknown keyed lookup did not fail open', 'unexpected object class must fail open',
])
require("common/PXCoreTelephonyServerIdentity.m", [
    '@"kCTMobileEquipmentInfoCurrentMobileId"', '@"kCTMobileEquipmentInfoIMEI"',
    '@"kCTMobileEquipmentInfoIMSI"', '@"kCTMobileEquipmentInfoMEID"',
    '@"kCTPostponementInfoIMEI"', '@"kCTPostponementInfoMEID"',
    'if ([information objectForKey:runtimeKey] == nil) continue;',
])
require("tests/PXCoreTelephonyServerIdentityTests.m", [
    'unknown field was modified', 'absent MEID field was synthesized',
    'IMEI2 incorrectly collapsed into CTServer primary IMEI',
    'V1/V2 IMEI diverged', 'generation swap returned stale IMEI',
])
require("TLinkIOSTweak/Tweak.x", [
    '#import "PXIdentitySurfaceRegistry.h"',
    'PXIdentitySurfaceEntryForKey(propertyString, PXIdentitySurfaceMobileGestalt)',
    'PXIdentitySurfaceResolveValue(surfaceEntry, deviceIds)',
    'PXIdentitySurfaceEntryForKey(key, PXIdentitySurfaceIORegistry)',
    'PXIOKitCreateRegistryReplacement', '@"IOKitBulk"', '@"IOKitSearch"',
    'PXIdentityExpectedTypeData',
])
require("tests/PXIdentitySurfaceRegistryTests.m", [
    'registry malformed', 'MG alias did not canonicalize',
    'device-tree ABI type must be CFData', 'surface isolation failed',
    'ManagedConfiguration serial source drifted',
    'CTServer IMEI drifted', 'CTServer IMSI drifted', 'CTServer MEID drifted',
    'private wrapper IMEI2 source drifted',
    'private wrapper sf_uuidString must follow advertising identity',
    'private wrapper applicationDSID must follow advertising identity',
    'secure-element evidence must not enter generic private-wrapper parity registry',
])
require("common/PXConsistencyMatrix.m", [
    '@"ManagedConfiguration"', '@"CoreTelephonyServer"', '@"PrivateWrapper"',
    '@"sysctlnametomib+sysctl"',
    '@"SerialNumber"', '@"MLBSerialNumber"', '@"UDID"', '@"SystemBootUUID"', '@"IDFA"',
    '@"IMEI"', '@"IMEI2"', '@"MEID"', '@"IMSI"',
])
require("tests/PXPhaseAConsistencyGateTests.m", [
    'PXPhaseAAssertMatrixScenario', 'PXPhaseAAssertManagedConfiguration',
    'PXPhaseAAssertPrivateWrappers', 'PXPhaseAAssertCTServer',
    'PXPhaseAAssertIndirectSysctlRows',
    '@"whole-group blank"', '@"missing UDID"', '@"malformed IMEI"',
    '@"DeviceModel toggle off"', '@"scope off"', '@"generation swap"',
    'sf_uuidString', 'MCIOSerialString', 'MCGestaltGetProductName',
])

# B-00: native query sanitizer foundation. The hidden-path corpus remains owned
# by JailbreakBypassHooks.x, while pure normalization/disposition/errno semantics
# are shared through PXP1CFilters. B-01 below must reuse this owner/contract.
require("common/PXP1CFilters.h", [
    'PXJBFilesystemDisposition', 'PXJBFilesystemOperation',
    'PXP1CJBNormalizeAbsolutePath', 'PXP1CJBJoinAbsoluteBaseAndNormalize',
    'PXP1CJBResolvedPathDisposition', 'PXP1CJBErrnoForDisposition',
])
require("common/PXP1CFilters.m", [
    'PXP1CJBNormalizeAbsolutePath', 'PXP1CJBJoinAbsoluteBaseAndNormalize',
    'kPXJBFilesystemDenyWrite', 'kPXJBFilesystemHide', 'ENOENT', 'EACCES',
])
require("TLinkIOSTweak/JailbreakBypassHooks.x", [
    '#import "PXP1CFilters.h"',
    'return PXP1CJBNormalizeAbsolutePath(inPath, out, outsz);',
    'return PXP1CJBJoinAbsoluteBaseAndNormalize(basePath,',
    'return PXP1CJBResolvedPathDisposition(operation,',
    'return PXP1CJBErrnoForDisposition(disposition);',
    'PXJBPathMatchesHiddenRules(target)', 'PXJBPathMatchesDenyWriteRules(target, flags)',
    'PXJB_PATH_RULE("/Applications/Cydia.app")',
    'PXJB_PATH_RULE("/var/jb/Applications")', 'PXJBPrivatePrebootPathShouldHide',
])
require("tests/PXP1CFiltersTests.m", [
    'testJBNativeQuerySanitizerContract', '/private//var/jb/./usr/../Library',
    'symlink-ish lexical path', 'missing dirfd provenance rejected',
    'write probe denial wins over hidden path', 'UNRESOLVED has no synthetic errno',
])
# B-01: exact directory/stat64 parity lands on the same sanitizer owner.
require("TLinkIOSTweak/JailbreakBypassHooks.x", [
    'typedef DIR *(*PXJBOpenDir2Function)(const char *, int);',
    'static DIR *hook___opendir2(const char *path, int flags)',
    'PXJBOriginalOpenDir2(path, flags)',
    'static PXJBFilesystemDisposition PXJBClassifyFileDescriptorPath(int fd)',
    'static int hook_fstat64(int fd, struct stat *buf)',
    'static int hook_fstatat64(int dirfd, const char *pathname, struct stat *buf, int flags)',
    'static int hook_fstatfs64(int fd, PXStatfs64Buf *buf)',
    'FindSymbol("__opendir2")', 'FindSymbol("fstat64")',
    'FindSymbol("fstatat64")', 'FindSymbol("fstatfs64")',
    'PXJB_AUDIT(kPXJBCapabilityCore, "__opendir2", orig___opendir2, false)',
    'PXJB_AUDIT(kPXJBCapabilityCore, "fstat64", orig_fstat64, false)',
    'PXJB_AUDIT(kPXJBCapabilityCore, "fstatat64", orig_fstatat64, false)',
    'PXJB_AUDIT(kPXJBCapabilityStatfs, "fstatfs64", orig_fstatfs64, false)',
])
require("tests/PXP1CFiltersTests.m", [
    'testB01DirectoryAndStat64Contracts',
    'B-01 normal file provenance normalizes',
    'B-01 relative dirfd/rootless normalization drifted',
    'B-01 invalid/missing fd provenance must stay unresolved',
    'B-01 normal query must remain ALLOW/original',
])

# B-02: safe read-only pathconf/attr/xattr surfaces. Normal and sizing-query
# calls must forward the caller's buffers, lengths, positions and options intact.
require("common/PXP1CFilters.h", [
    'PXJBHiddenReadErrnoPolicy', 'kPXJBHiddenReadErrnoPathNotFound',
    'kPXJBHiddenReadErrnoBadFileDescriptor', 'kPXJBHiddenReadErrnoPermissionDenied',
    'PXP1CJBErrnoForHiddenRead',
])
require("common/PXP1CFilters.m", [
    'PXP1CJBErrnoForHiddenRead', 'return EBADF;', 'return EPERM;', 'return ENOENT;',
])
require("TLinkIOSTweak/JailbreakBypassHooks.x", [
    'static long hook_pathconf(const char *path, int name)',
    'orig_pathconf(path, name)',
    'static long hook_fpathconf(int fd, int name)',
    'orig_fpathconf(fd, name)',
    'static int hook_getattrlist(const char *path,',
    'orig_getattrlist(path, attrList, attrBuf, attrBufSize, options)',
    'static int hook_fgetattrlist(int fd,',
    'orig_fgetattrlist(fd, attrList, attrBuf, attrBufSize, options)',
    'static ssize_t hook_getxattr(const char *path,',
    'orig_getxattr(path, name, value, size, position, options)',
    'static ssize_t hook_fgetxattr(int fd,',
    'orig_fgetxattr(fd, name, value, size, position, options)',
    'static ssize_t hook_listxattr(const char *path,',
    'orig_listxattr(path, nameBuffer, size, options)',
    'static ssize_t hook_flistxattr(int fd,',
    'orig_flistxattr(fd, nameBuffer, size, options)',
    'PXJBRejectHiddenPathReadQuery', 'PXJBRejectHiddenFDReadQuery',
    'int incomingErrno = errno;', 'errno = incomingErrno;',
    'FindSymbol("pathconf")', 'FindSymbol("fpathconf")',
    'FindSymbol("getattrlist")', 'FindSymbol("fgetattrlist")',
    'FindSymbol("getxattr")', 'FindSymbol("fgetxattr")',
    'FindSymbol("listxattr")', 'FindSymbol("flistxattr")',
])
require("tests/PXP1CFiltersTests.m", [
    'testB02ReadQueryErrnoContracts',
    'B-02 hidden path read must use ENOENT',
    'B-02 hidden fd read must use EBADF',
    'B-02 hidden listxattr must preserve EPERM parity',
    'B-02 unresolved provenance must not synthesize errno',
])
forbid("TLinkIOSTweak/JailbreakBypassHooks.x", [
    'FindSymbol("setxattr")', 'FindSymbol("fsetxattr")',
    'FindSymbol("removexattr")', 'FindSymbol("fremovexattr")',
])

# B-03: readdir_r parity plus narrowly scoped process/socket query sanitation.
require("common/PXP1CFilters.h", [
    'PXP1CJBCompactNonRootGroups', 'PXP1CJBEndpointPortShouldHide',
])
require("common/PXP1CFilters.m", [
    'if (group == 0) continue;',
    'hostOrderPort == 27042u || hostOrderPort == 27043u',
])
require("TLinkIOSTweak/JailbreakBypassHooks.x", [
    'typedef int (*PXJBReaddirRFunction)(DIR *, struct dirent *, struct dirent **);',
    'static int hook_readdir_r(DIR *dirp,',
    'PXJBDirectoryEntryShouldHide(tracked ? parentPath : NULL,',
    'PXJBRecordBlockedEvent("readdir_r", candidate->d_name);',
    'FindSymbol("readdir_r")',
    'PXJB_AUDIT(kPXJBCapabilityCore, "readdir_r", orig_readdir_r, false)',
    'static int hook_issetugid(void)',
    'if (PXJBShouldBypassCached() && original != 0) return 0;',
    'FindSymbol("issetugid")',
    'static int hook_getgroups(int gidsetsize, gid_t *grouplist)',
    'PXP1CJBCompactNonRootGroups(grouplist, count)',
    'FindSymbol("getgroups")',
    'static BOOL PXJBSocketEndpointShouldHide(const struct sockaddr *address,',
    'address->sa_family != AF_INET',
    'PXP1CJBEndpointPortShouldHide(ntohs(ipv4->sin_port))',
    'static int hook_getpeername(int socketFD,',
    'static int hook_getsockname(int socketFD,',
    'errno = ENOTCONN;',
    'FindSymbol("getpeername")', 'FindSymbol("getsockname")',
    'PXJB_AUDIT(kPXJBCapabilityCore, "getpeername", orig_getpeername, false)',
    'PXJB_AUDIT(kPXJBCapabilityCore, "getsockname", orig_getsockname, false)',
])
require("tests/PXP1CFiltersTests.m", [
    'testB03ProcessSocketContracts',
    'B-03 getgroups visible order changed',
    'B-03 getgroups sizing/null contract drifted',
    'B-03 peer port 27042 must hide', 'B-03 peer port 27043 must hide',
    'B-03 peer filter must stay narrower than connect policy',
    'B-03 ordinary peer port must stay visible',
])
forbid("TLinkIOSTweak/JailbreakBypassHooks.x", [
    '*addressLength =',
])

# B-04: PAC proxy results share the existing VPN/proxy policy owner. The hook
# must call the Copy API original first, fail open on errors/malformed shape,
# preserve CF Create ownership, and never introduce TLS/trust behavior.
require("TLinkIOSTweak/PXPACProxySanitizer.m", [
    'PXPACProxyTypeKey', 'kCFProxyTypeKey',
    'PXPACDirectType', 'kCFProxyTypeNone',
    '@"kCFProxyHostNameKey"', '@"kCFProxyPortNumberKey"',
    '@"kCFProxyAutoConfigurationURLKey"', '@"kCFProxyAutoConfigurationJavaScriptKey"',
    'if (!bypassEnabled || !originalValue) return originalValue;',
    'if (![entry isKindOfClass:[NSDictionary class]]) return originalValue;',
    'sanitized[PXPACProxyTypeKey()] = PXPACDirectType();',
])
require("TLinkIOSTweak/VPNDetectionBypass.x", [
    'typedef CFArrayRef (*PXCFNetworkCopyPACProxiesFunction)(CFStringRef, CFURLRef, CFErrorRef *);',
    'PXHookCFNetworkCopyProxiesForAutoConfigurationScript',
    'originalFunction(script, targetURL, error)',
    'if (!PXVPNBypassActive() || !original) return original;',
    'if (error && *error) return original;',
    'CFGetTypeID(original) != CFArrayGetTypeID()',
    'PXPACProjectedProxyValue(originalObject, YES)',
    'CFBridgingRetain(projected)', 'CFRelease(original);',
    'PXVPNInstallFunctionHook(cfNetwork, "CFNetworkCopyProxiesForAutoConfigurationScript"',
])
require("tests/PXPACProxySanitizerTests.m", [
    'testProfileOffAndNilFailOpen', 'testDirectOnlyPreservesShape',
    'testHTTPAndSOCKSBecomeDirect', 'testPACConfigurationFieldsAreRemoved',
    'testMalformedResultFailsOpen',
    'B-04 profile-off must return exact original object',
    'B-04 HTTP/SOCKS cardinality preserved',
    'B-04 malformed PAC entry must return exact original array',
])
forbid("TLinkIOSTweak/VPNDetectionBypass.x", [
    'SecTrust', 'serverTrust', 'NSURLAuthenticationChallenge',
])

# B-05: secondary ObjC parity remains selective. Call-stack arrays preserve
# cardinality, argv uses the exact five recovered marker families, LaunchServices
# shares the 18-entry URL-scheme corpus, and bundle locale uses the canonical LTZ source.
require("common/PXP1CFilters.m", [
    '@"jailbreak", @"dyld", @"roothide", @"theos", @"substrate"',
    '[argument containsString:marker]',
    '@"activator", @"aptbackup", @"checkra1n", @"com.example.package"',
    '@"trollinstallerx", @"trollstore", @"unc0ver"',
    '@"undecimus", @"zbra", @"zebra"',
    'PXP1CJBArrayByReplacingMatchingObjects',
])
require("TLinkIOSTweak/JailbreakBypassHooks.x", [
    '%hook NSThread', '+ (NSArray<NSNumber *> *)callStackReturnAddresses',
    '+ (NSArray<NSString *> *)callStackSymbols', 'dladdr((const void *)address, &info)',
    'PXJBShouldHideImageName(info.dli_fname)', '@"<redacted frame>"',
    '%hook NSProcessInfo', '- (NSArray<NSString *> *)arguments',
    'PXP1CJBFilterProcessArguments(original,',
    'PXP1CJBURLSchemeShouldHide(url.scheme)',
    'objc_getClass("_LSCanOpenURLManager")',
    'sel_registerName("canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:")',
    'PXJBLSCanOpenURLMethodEncodingMatches(method)',
    'MSHookMessageEx(cls,', 'PXJBInstallLSCanOpenURLManagerHook();',
    'PXP1CJBURLSchemeShouldHide([(NSURL *)url scheme])',
    '"_LSCanOpenURLManager.canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:"',
])
require("TLinkIOSTweak/LocaleTimeZoneHooks.x", [
    '%hook NSBundle', '- (NSArray<NSString *> *)preferredLocalizations',
    'PXPreferredLocalizationsProjection(original,',
    'LTZPinnedPreferredLanguages()', 'LTZPinnedLocaleIdentifier()',
])
require("common/PXLocaleRuntimeProjection.m", [
    'PXPreferredLocalizationsProjection',
    'PXFirstValidPreferredLanguage', 'PXLanguageComponentFromLocaleIdentifier',
])
require("tests/PXP1CFiltersTests.m", [
    'testB05SecondaryObjCContracts',
    'B-05 argv exact lowercase marker must match',
    'B-05 argv marker semantics must remain iFake case-sensitive',
    'B-05 callstack redaction must preserve cardinality',
    'B-05 no matching callstack frame must return exact original array',
])
require("tests/PXLocaleRuntimeProjectionTests.m", [
    'PXTestPreferredLocalizationsProjection',
    'B-05 disabled preferredLocalizations must preserve exact original array',
    'B-05 locale fallback must project first hyphen component',
    'B-05 partial/invalid locale profile must fail open to exact original array',
])
forbid("TLinkIOSTweak/JailbreakBypassHooks.x", [
    'return @[];',
])

# C-01: only the generic SystemConfiguration debugger scalar is added. The
# symbol is runtime-optional, inherits the existing scoped JB master gate, and
# falls back to the saved original whenever that effective capability is off.
require("common/PXP1CFilters.h", [
    'PXP1CJBProjectedDebuggerState',
])
require("common/PXP1CFilters.m", [
    'BOOL PXP1CJBProjectedDebuggerState(BOOL originalValue, BOOL bypassEnabled)',
    'return bypassEnabled ? NO : originalValue;',
])
require("tests/PXP1CFiltersTests.m", [
    'testC01DebuggerScalarProjection',
    'C-01 scope/master off must request no debugger capability',
    'C-01 symbol-absent capability must remain inactive',
    'C-01 audited debugger capability must become active',
    'C-01 capability/scope off must preserve original true debugger state',
    'C-01 capability/scope off must preserve original false debugger state',
    'C-01 active capability must project original true to false',
    'C-01 active capability must keep original false false',
])
require("TLinkIOSTweak/JailbreakBypassHooks.x", [
    'typedef Boolean (*PXJBSCIsRunningWithDebuggerFunction)(void);',
    'kPXJBPolicySCDebuggerScalar            = 1ull << 11',
    'kPXJBCapabilitySCDebuggerScalar',
    '{ .name = "sc-debugger",     .policyBit = kPXJBPolicySCDebuggerScalar }',
    'PXJBPolicyMask mask = kPXJBPolicyMaster | kPXJBPolicySCDebuggerScalar;',
    'static BOOL PXJBSCDebuggerScalarEnabled(void)',
    'return PXJBPolicyFeatureEnabled(kPXJBPolicySCDebuggerScalar);',
    'static Boolean hook_SCIsRunningWithDebugger(void)',
    'if (PXJBSCDebuggerScalarEnabled()) return (Boolean)0;',
    'return original ? original() : (Boolean)0;',
    'sym = FindSymbol("SCIsRunningWithDebugger");',
    'if (sym) {',
    '(void *)hook_SCIsRunningWithDebugger',
    '(void **)&orig_SCIsRunningWithDebugger',
    'PXJB_AUDIT(kPXJBCapabilitySCDebuggerScalar,',
    '"SCIsRunningWithDebugger",',
    'orig_SCIsRunningWithDebugger,',
    'true);',
])
forbid("TLinkIOSTweak/JailbreakBypassHooks.x", [
    'dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration"',
    'dlopen(@"/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration"',
])
print("Phase-3 static contracts: PASS")
