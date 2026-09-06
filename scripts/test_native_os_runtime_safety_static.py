#!/usr/bin/env python3
"""Static contract for Hybrid Upward OS reporting + physical runtime safety.

Guards the crash class reported by CPUDasher (new UITableView selector), ARMCPUZ
(WidgetKit Swift symbol on pre-14 runtime), and Chrome (newer interaction path on
legacy UIKit) without silently disabling upward iOS identity spoofing.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS: {message}")


def body(source: str, marker: str, limit: int = 7000) -> str:
    start = source.find(marker)
    require(start >= 0, f"found {marker}")
    return source[start:start + limit]


compat_h = read("common/PXRuntimeOSCompatibility.h")
compat_m = read("common/PXRuntimeOSCompatibility.m")
transform_h = read("common/PXSystemVersionTransformer.h")
transform_m = read("common/PXSystemVersionTransformer.m")
registry = read("common/PXIdentitySurfaceRegistry.m")
ios = read("TLinkIOSTweak/IOSVersionHooks.x")
tweak = read("TLinkIOSTweak/Tweak.x")
uuid = read("TLinkIOSTweak/UUIDHooks.x")
fix_apps = read("FixVersionAppsViewController.m")
security_ui = read("SecurityTabViewController.m")
release = read("scripts/release_hardening.py")

# Physical runtime provenance must bypass spoofable Foundation plist convenience APIs.
for token in (
    "PXRealRuntimeOSInfo",
    "PXRealRuntimeIOSVersion",
    "PXRealRuntimeIOSBuild",
    "PXRealRuntimeIOSVersionIsAtLeast",
    "PXConfiguredIOSVersionExceedsRealRuntime",
):
    require(token in compat_h and token in compat_m, f"runtime compatibility exports {token}")
require("open(path.fileSystemRepresentation, O_RDONLY)" in compat_m and "read(fd," in compat_m,
        "real runtime SystemVersion is read through POSIX IO")
require("dictionaryWithContentsOfFile" not in compat_m,
        "real runtime reader does not recurse through hooked Foundation plist loaders")
require('plist[@"ProductVersion"]' in compat_m and 'plist[@"ProductBuildVersion"]' in compat_m,
        "real runtime version/build are captured as one source pair")

# Legacy Fix Version policy: profile reporting stays active everywhere except the
# selected app's kern.osproductversion query, which falls through to the real syscall.
for token in (
    "PXFixVersionAppliesToBundle",
    "PXReportingIOSVersionBuildForBundle",
    "PXReportingIOSValueForDeviceIDKey",
    "PXKernelIOSProfileMayExposeTupleForBundle",
):
    require(token in compat_h and token in compat_m, f"OS projection policy exports {token}")
require('PXReadSecurityBool(@"fixVersionEnabled", NO)' in compat_m and
        'PXReadSecuritySetting(@"fixVersionApps")' in compat_m,
        "Fix Version policy is driven by authoritative security settings")
report_policy = body(compat_m, "BOOL PXReportingIOSVersionBuildForBundle", 2200)
require("if (outVersion) *outVersion = configuredV;" in report_policy and
        "if (outBuild) *outBuild = configuredB;" in report_policy,
        "all normal OS reporting preserves the configured profile version/build")
require("PXFixVersionAppliesToBundle" not in report_policy and
        "PXRealRuntimeIOSVersion" not in report_policy and "PXRealRuntimeIOSBuild" not in report_policy,
        "Fix Version does not broaden into UIDevice/NSProcessInfo/SystemVersion reporting")

# SystemVersion dictionary/raw-file surfaces use the per-app reporting projection.
require("PXCurrentReportingSystemVersionProjectionForBundle" in transform_h and
        "PXReportingIOSVersionBuildForBundle" in transform_m,
        "SystemVersion transformer exposes per-app reporting projection")
require("PXCurrentReportingSystemVersionProjectionForBundle(bundleID)" in ios,
        "IOSVersion SystemVersion hooks consume per-app reporting projection")
require("PXCurrentReportingSystemVersionProjectionForBundle(bundleID)" in tweak,
        "coordinator CFCopySystemVersionDictionary consumes per-app reporting projection")

# UIDevice / NSProcessInfo reporting getters always preserve the configured profile;
# legacy Fix Version must not alter these surfaces.
uid_body = body(ios, "- (NSString *)systemVersion", 2600)
require("PXReportingIOSVersionBuildForBundle" in uid_body and "return reportedVersion;" in uid_body,
        "UIDevice.systemVersion uses Hybrid/Fix-Version reporting policy")
require("PXNativeSafeIOSVersionBuild" not in uid_body,
        "UIDevice.systemVersion is no longer globally runtime-capped")

os_struct_body = body(ios, "- (NSOperatingSystemVersion)operatingSystemVersion", 2800)
require("PXReportingIOSVersionBuildForBundle" in os_struct_body and "reportedStructVersion" in os_struct_body,
        "NSProcessInfo.operatingSystemVersion uses Hybrid/Fix-Version reporting policy")
require("PXNativeSafeIOSVersionBuild" not in os_struct_body,
        "NSProcessInfo reporting struct is no longer globally runtime-capped")

os_string_body = body(ios, "- (NSString *)operatingSystemVersionString", 2600)
require("PXReportingIOSVersionBuildForBundle" in os_string_body and
        "reportedVersion" in os_string_body and "reportedBuild" in os_string_body,
        "NSProcessInfo version string uses Hybrid/Fix-Version reporting pair")

# Capability/availability primitive must remain native. Do not override it to profile or clamp logic.
require("- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version" not in ios,
        "NSProcessInfo availability primitive is not hooked")
require("Availability/capability checks are intentionally not hooked" in ios,
        "source documents physical availability contract")

# MobileGestalt / ManagedConfiguration / private wrappers remain profile-backed.
require('entry.toggle isEqualToString:@"IOSVersion"' in registry and
        "PXReportingIOSValueForDeviceIDKey" in registry and
        "[[NSBundle mainBundle] bundleIdentifier]" in registry,
        "native identity registry resolves ProductVersion/Build from the configured profile")

# Legacy Fix Version is kern.osproductversion-only. Every other intended OS/kernel
# reporting surface remains profile-backed, including upward profiles such as iOS 13.x.
kern_product = body(tweak, 'strcmp(name, "kern.osproductversion") == 0', 1200)
require("PXFixVersionAppliesToBundle(bundleID)" in kern_product and
        "if (outHandled) *outHandled = YES;" not in kern_product.split("PXFixVersionAppliesToBundle(bundleID)", 1)[1].split("}", 1)[0],
        "Fix Version selected apps leave kern.osproductversion unhandled for the real syscall")
require('spoofedValue = deviceIds[@"IOSVersion"]' in kern_product,
        "kern.osproductversion still reports the profile when Fix Version does not apply")

kern_numeric = body(tweak, "if (name[0] == CTL_KERN", 3200)
require("name[1] == KERN_OSVERSION" in kern_numeric and 'deviceIds[@"IOSBuild"]' in kern_numeric,
        "numeric KERN_OSVERSION remains profile-backed")
require("PXFixVersionAppliesToBundle(bundleID)" not in kern_numeric,
        "Fix Version does not affect numeric CTL_KERN reporting")

kern_named = body(tweak, 'strcmp(name, "kern.osversion") == 0', 2600)
require('spoofedValue = deviceIds[@"IOSBuild"]' in kern_named and
        "PXFixVersionAppliesToBundle(bundleID)" not in kern_named,
        "kern.osversion remains profile-backed under Fix Version")
require('spoofedValue = deviceIds[@"Darwin"]' in kern_named and
        'spoofedValue = deviceIds[@"KernelVersion"]' in kern_named,
        "kern.osrelease and kern.version remain profile-backed")

kernel_policy = body(compat_m, "BOOL PXKernelIOSProfileMayExposeTupleForBundle", 900)
require("PXFixVersionAppliesToBundle" not in kernel_policy and
        "PXNativeIOSProfileMayExposeKernelTuple" not in kernel_policy,
        "default kernel reporting policy is not runtime-clamped by Fix Version")
require("PXKernelIOSProfileMayExposeTupleForBundle(deviceIDs[@\"IOSVersion\"], deviceIDs[@\"IOSBuild\"], bundleID)" in tweak,
        "uname keeps using the profile kernel tuple policy")

# App binary metadata is not runtime identity and must remain original.
nsbundle_body = body(ios, "%hook NSBundle", 5200)
for key in ("MinimumOSVersion", "DTPlatformVersion", "DTSDKName"):
    require(key in nsbundle_body, f"NSBundle explicitly recognizes {key} as build metadata")
require("return %orig;" in nsbundle_body,
        "NSBundle build metadata stays original instead of following spoofed OS")
require("return original_CFBundleGetValueForInfoDictionaryKey" in ios,
        "CFBundle build metadata stays original instead of following spoofed OS")

# Do not fake whole missing UIKit/WebKit/WidgetKit capabilities.
require("PXInstallCompatibilityShims();" not in tweak,
        "tweak constructor no longer installs synthetic newer-OS compatibility shims")
shim_body = body(tweak, "static void PXInstallCompatibilityShims(void)", 700)
require("Intentionally inert" in shim_body and "PXCompatAddMethodIfMissing" not in shim_body and
        "PXRebindWidgetKitSymbolsInMainImage();" not in shim_body,
        "compatibility shim installer itself is inert")

# Tweak-internal compatibility decisions must never trust spoofable version getters.
real_major_body = body(tweak, "static NSInteger PXRealOSMajorVersion(void)", 700)
require("PXRealRuntimeIOSVersion()" in real_major_body and "dictionaryWithContentsOfFile" not in real_major_body,
        "legacy compatibility helper reads physical runtime source")
require('PXRealRuntimeIOSVersionIsAtLeast(@"16.0")' in tweak and
        "[[NSProcessInfo processInfo] operatingSystemVersion]" not in tweak,
        "main tweak constructor uses physical runtime for compatibility branching")
require("PXRuntimeOSCompatibility.h" in uuid and
        "PXRealRuntimeIOSVersionIsAtLeast((v))" in uuid and
        "[[[UIDevice currentDevice] systemVersion] compare" not in uuid,
        "UUID hook version-dependent layout logic uses physical runtime")

# Fix Version app selection is verified/persistent and hot-reloads injected processes.
require('PXReadSecuritySetting(@"fixVersionApps")' in fix_apps and
        'PXWriteSecuritySetting(@"fixVersionApps", toSave, &error)' in fix_apps,
        "Fix Version app list uses authoritative verified settings store")
require('CFSTR("com.hydra.tlinkios.settings.changed")' in fix_apps,
        "Fix Version app-list save posts Darwin hot-reload notification")
fix_toggle_body = body(security_ui, "- (void)fixVersionToggleChanged:", 1800)
require("PXWriteSecurityBool" in fix_toggle_body and
        'CFSTR("com.hydra.tlinkios.settings.changed")' in fix_toggle_body,
        "Fix Version master toggle persists and hot-reloads injected processes")
require("only kern.osproductversion falls through" in security_ui and
        "remain spoofed from the selected profile" in security_ui,
        "Fix Version UI documents the narrow kern.osproductversion-only behavior")

# Web/User-Agent projection intentionally remains profile-backed.
require("static NSString *getSpoofedSystemVersion()" in ios and
        "PXNormalizeUserAgent" in ios and "getIOSVersionInfo()" in ios,
        "Web/User-Agent spoof continues to use configured profile version")

require('"scripts/test_native_os_runtime_safety_static.py"' in release,
        "Hybrid OS runtime safety contract is wired into release hardening")

print("native OS Hybrid/Fix-Version runtime safety static contract: PASS")
