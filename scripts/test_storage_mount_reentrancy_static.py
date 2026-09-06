#!/usr/bin/env python3
"""Regression guard for CoreServices MountInfo recursion across filesystem/AppVersion hooks."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STORAGE = (ROOT / "TLinkIOSTweak" / "StorageHooks.x").read_text(encoding="utf-8")
COORD = (ROOT / "TLinkIOSTweak" / "PXNativeHookCoordinator.m").read_text(encoding="utf-8")
JB = (ROOT / "TLinkIOSTweak" / "JailbreakBypassHooks.x").read_text(encoding="utf-8")
APP_VERSION = (ROOT / "TLinkIOSTweak" / "AppVersionHooks.x").read_text(encoding="utf-8")
IOS_VERSION = (ROOT / "TLinkIOSTweak" / "IOSVersionHooks.x").read_text(encoding="utf-8")
REENTRY_H = (ROOT / "common" / "PXNativeFilesystemReentry.h").read_text(encoding="utf-8")
REENTRY_M = (ROOT / "common" / "PXNativeFilesystemReentry.m").read_text(encoding="utf-8")


def block(source: str, start: str, end: str) -> str:
    begin = source.index(start)
    finish = source.index(end, begin)
    return source[begin:finish]


# Shared critical-path signal must be native/TLS only. Pulling Foundation into this
# helper would recreate the exact CoreServices lock cycle it is meant to break.
for source_name, source in (("header", REENTRY_H), ("implementation", REENTRY_M)):
    for forbidden in ("Foundation/Foundation.h", "NSBundle", "NSFileManager", "NSString", "NSArray"):
        if forbidden in source:
            raise AssertionError(f"native filesystem reentry {source_name} is not Foundation-free: {forbidden}")

for required in (
    "static __thread uint32_t gPXNativeFilesystemCriticalDepth",
    "PXNativeFilesystemCriticalEnter",
    "PXNativeFilesystemCriticalLeave",
    "PXNativeFilesystemCriticalIsActive",
):
    if required not in REENTRY_M:
        raise AssertionError(f"missing native filesystem TLS primitive: {required}")

# Native coordinator wrappers must mark the critical region before invoking libc.
# Nested filesystem calls must not re-enter Objective-C provider dispatch.
for fn_name, original_call, symbol in (
    ("PXCoord_statfs", "g_orig_statfs ? g_orig_statfs", "kPXNativeSymbolStatfs"),
    ("PXCoord_statfs64", "g_orig_statfs64 ? g_orig_statfs64", "kPXNativeSymbolStatfs64"),
    ("PXCoord_getfsstat", "g_orig_getfsstat ? g_orig_getfsstat", "kPXNativeSymbolGetfsstat"),
    ("PXCoord_getfsstat64", "g_orig_getfsstat64 ? g_orig_getfsstat64", "kPXNativeSymbolGetfsstat64"),
):
    body = block(COORD, f"static int {fn_name}", "\n}\n")
    for required in (
        "PXNativeFilesystemCriticalIsActive()",
        "PXNativeFilesystemCriticalEnter();",
        "PXNativeFilesystemCriticalLeave();",
        "if (!nestedFilesystemCritical)",
        original_call,
        symbol,
    ):
        if required not in body:
            raise AssertionError(f"{fn_name} missing MountInfo reentry contract: {required}")
    if body.index("PXNativeFilesystemCriticalEnter();") > body.index(original_call):
        raise AssertionError(f"{fn_name} enters TLS guard after original filesystem call")
    if body.index("if (!nestedFilesystemCritical)") > body.index(symbol):
        raise AssertionError(f"{fn_name} looks up Objective-C providers before nested-call bypass")

# Direct getmntinfo hook must mark the shared critical scope before calling libc so
# getmntinfo_internal -> getfsstat is recognized as nested by the coordinator.
getmntinfo = block(JB, "static int hook_getmntinfo", "\n}\n")
for required in (
    "PXNativeFilesystemCriticalIsActive()",
    "PX_NATIVE_FILESYSTEM_CRITICAL_SCOPE",
    "PXJBOriginalGetmntinfo",
    "if (nestedFilesystemCritical) pxjbFilterFilesystem = NO;",
):
    if required not in getmntinfo:
        raise AssertionError(f"getmntinfo missing shared reentry guard: {required}")
if getmntinfo.index("PX_NATIVE_FILESYSTEM_CRITICAL_SCOPE") > getmntinfo.index("PXJBOriginalGetmntinfo"):
    raise AssertionError("getmntinfo enters shared filesystem scope too late")

# Storage's native providers themselves remain Foundation-free.
providers = block(
    STORAGE,
    'registerStatfsProvider:@"storage.statfs"',
    'PXLog(@"[StorageHooks] Registered statfs family providers',
)
for forbidden in (
    "shouldApplyStorageSpoofing()",
    "getStorageValuesForApp",
    "getCurrentBundleID",
    "NSBundle",
    "NSFileManager",
    "PXProcessIsAllowedForSpoofing",
):
    if forbidden in providers:
        raise AssertionError(f"native mount provider calls Foundation/scope helper: {forbidden}")
for required in (
    "PXStorageCopyNativeSnapshot",
    "PXStorageModifyStatfsWithValues",
    "gStorageNativeRefreshInProgress",
):
    if required not in STORAGE:
        raise AssertionError(f"missing mount reentrancy safeguard: {required}")

# AppVersion must refuse all profile/settings/mtime resolution while the filesystem
# TLS guard is active. This is the exact failing chain from the crash:
# getmntinfo -> bundleIdentifier -> PXGetSpoofedAppVersionForBundle -> file attrs.
for marker in (
    "static NSDate *PXFileMTime",
    "static NSDictionary *PXReadPlist",
    "static NSString *PXResolveExistingPath",
    "BOOL PXAppVersionSpoofMasterEnabled",
    "BOOL PXGetSpoofedAppVersionForBundle",
    "static BOOL PXAppVersionScopeAllows",
):
    body = block(APP_VERSION, marker, "\n}\n")
    if "PXNativeFilesystemCriticalIsActive()" not in body:
        raise AssertionError(f"AppVersion critical-path fail-open missing in {marker}")

for marker in (
    "- (NSDictionary *)infoDictionary",
    "- (NSDictionary *)localizedInfoDictionary",
    "static CFDictionaryRef replaced_CFBundleGetInfoDictionary",
    "static CFDictionaryRef replaced_CFBundleGetLocalInfoDictionary",
):
    body = block(APP_VERSION, marker, "\n}\n")
    if "PXNativeFilesystemCriticalIsActive()" not in body:
        raise AssertionError(f"AppVersion bundle hook reenters during mount callback: {marker}")

# IOSVersion's per-key AppVersion surfaces must also fail open before asking a
# bundle for its identifier, otherwise bundleIdentifier can re-enter the full-dict hook.
ns_bundle_key = block(IOS_VERSION, "- (id)objectForInfoDictionaryKey", "\n}\n")
if "PXNativeFilesystemCriticalIsActive()" not in ns_bundle_key:
    raise AssertionError("NSBundle objectForInfoDictionaryKey lacks native-filesystem fail-open")
cf_bundle_key = block(IOS_VERSION, "CFTypeRef replaced_CFBundleGetValueForInfoDictionaryKey", "\n}\n")
if "PXNativeFilesystemCriticalIsActive()" not in cf_bundle_key:
    raise AssertionError("CFBundleGetValueForInfoDictionaryKey lacks native-filesystem fail-open")

# NSURL resource resolution is the second MountInfoPrepare seen in the crash. Guard
# before %orig; checking only after it is already too late.
for marker in (
    "- (BOOL)getResourceValue:(id *)value",
    "- (NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys",
    "- (NSDictionary *)attributesOfFileSystemForPath",
):
    body = block(STORAGE, marker, "\n}\n")
    guard_pos = body.find("PXNativeFilesystemCriticalIsActive()")
    orig_pos = body.find("%orig")
    if guard_pos < 0:
        raise AssertionError(f"Storage Foundation hook missing MountInfo reentry brake: {marker}")
    if orig_pos >= 0 and guard_pos > orig_pos:
        raise AssertionError(f"Storage MountInfo guard runs after %orig in {marker}")

print("storage mount reentrancy static test: PASS")
