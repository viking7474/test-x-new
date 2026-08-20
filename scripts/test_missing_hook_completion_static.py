#!/usr/bin/env python3
"""Static contract for the runtime hook gaps completed outside the five UUID surfaces."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


vpn = read("TLinkIOSTweak/VPNDetectionBypass.x")
for token in (
    "vpnDetectionBypassEnabled",
    'registerGetifaddrsProvider:@"vpn.interface-sanitize"',
    "CFNetworkCopySystemProxySettings",
    "SCDynamicStoreCopyProxies",
    "%hook NSURLSessionConfiguration",
    "%hook NWPath",
    "%hook NWInterface",
    'NSClassFromString(@"NEVPNConnection")',
):
    require(token in vpn, f"VPN/proxy runtime surface is missing: {token}")

coordinator = read("TLinkIOSTweak/PXNativeHookCoordinator.m")
getifaddrs_start = coordinator.index("static int PXCoord_getifaddrs")
getifaddrs_end = coordinator.index("static int PXCoord_statfs", getifaddrs_start)
getifaddrs_body = coordinator[getifaddrs_start:getifaddrs_end]
require("BOOL handled = NO" in getifaddrs_body,
        "getifaddrs dispatcher does not track terminal pre-provider handling")
require(getifaddrs_body.index("if (!handled)") < getifaddrs_body.index("PXGetifaddrsPostBlock post"),
        "getifaddrs post sanitizers must run after either original or terminal pre result")

timezone = read("TLinkIOSTweak/LocaleTimeZoneHooks.x")
for token in (
    'settings[@"timeSpoofingMode"]',
    'settings[@"timeSpoofIPAddressTimeZoneName"]',
    'settings[@"timeSpoofLocationTimeZoneName"]',
    "%hook NSTimeZone",
    "CFTimeZoneCopySystem",
    "CFTimeZoneCopyDefault",
    "setenv(\"TZ\"",
    "tzset()",
    "PXInstallLocaleTimeZoneUserScript",
    "Intl.DateTimeFormat.prototype.resolvedOptions",
    "Date.prototype.getTimezoneOffset",
):
    require(token in timezone, f"timezone runtime surface is missing: {token}")
canvas = read("TLinkIOSTweak/CanvasFingerprintHooks.x")
require("PXInstallLocaleTimeZoneUserScript(controller)" in canvas,
        "canonical WebKit owner does not install the timezone script")

mobile_gestalt_h = read("TLinkIOSTweak/MobileGestalt.h")
tweak = read("TLinkIOSTweak/Tweak.x")
for signature in (
    "MGCopyAnswer(CFStringRef property, CFDictionaryRef options)",
    "MGCopyAnswerWithError(CFStringRef property, CFDictionaryRef options, int *error)",
    "MGCopyMultipleAnswers(CFArrayRef properties, CFDictionaryRef options)",
):
    require(signature in mobile_gestalt_h, f"MobileGestalt ABI declaration is incomplete: {signature}")
for token in (
    "%hookf(CFTypeRef, MGCopyAnswer, CFStringRef property, CFDictionaryRef options)",
    "MGCopyAnswerWithError",
    "MGCopyMultipleAnswers",
    "MGGetBoolAnswer",
    "PXMGCreateAlternateProjectedAnswer",
):
    require(token in tweak, f"MobileGestalt alternate entry point is missing: {token}")

sensor_start = tweak.index("#pragma mark - Sensor transform pipeline")
sensor_end = tweak.index("// Add barometer/altitude data spoofing", sensor_start)
sensor = tweak[sensor_start:sensor_end]
for token in (
    "PXTransformDeviceMotionData",
    "%hook CMAttitude",
    "%hook CMDeviceMotion",
    "- (CMDeviceMotion *)deviceMotion",
    "startDeviceMotionUpdatesToQueue:",
    "startDeviceMotionUpdatesUsingReferenceFrame:",
    "CMCalibratedMagneticField",
):
    require(token in sensor, f"CMDeviceMotion coverage is missing: {token}")
for forbidden in ("setValue:", "valueForKey:", "setValue:forKey:"):
    require(forbidden not in sensor, f"CMDeviceMotion must not mutate private CoreMotion state via KVC: {forbidden}")

makefile = read("Makefile")
require("CoreLocation CoreMotion CoreFoundation" in makefile,
        "CoreMotion must be linked explicitly for the sensor hooks")

security_ui = read("SecurityTabViewController.m")
vpn_ui = read("VPNDetectionDetailViewController.m")
time_ui = read("TimeSpoofDetailViewController.m")
require("vpnDetectionBypassEnabled" in security_ui and
        "com.hydra.tlinkios.settings.changed" in security_ui and
        "com.hydra.tlinkios.settings.changed" in vpn_ui,
        "VPN UI changes are not published to injected processes")
require("timeSpoofLocationTimeZoneName" in time_ui and
        "timeSpoofIPAddressTimeZoneName" in security_ui,
        "time spoof mode does not persist both IP and pinned-location timezone inputs")

print("missing hook completion static test: PASS")
