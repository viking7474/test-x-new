#!/usr/bin/env python3
"""Host-independent P0-04 pedometer/altitude contracts."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TWEAK = (ROOT / "TLinkIOSTweak" / "Tweak.x").read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


selectors = (
    "activeTime",
    "numberOfSteps",
    "distance",
    "averageActivePace",
    "distanceSource",
    "elevationAscended",
    "elevationDescended",
    "currentPace",
    "floorsAscended",
    "floorsDescended",
    "numberOfPushes",
    "currentCadence",
    "workoutType",
    "pressure",
    "relativeAltitude",
)
for selector in selectors:
    require(f'"{selector}"' in TWEAK, f"missing P0-04 getter rule: {selector}")

rules = re.findall(
    r'\{ "(?:CMPedometerData|CMAltitudeData)", "([A-Za-z]+)", '
    r'PXCoreMotionNumber[A-Za-z]+, NULL \}',
    TWEAK,
)
require(tuple(rules) == selectors, f"P0-04 rule inventory drifted: {rules}")

for token in (
    "objc_getClass(rule->className)",
    "class_getInstanceMethod(cls, selector)",
    "class_getImageName(cls)",
    'strstr(imageName, "/System/Library/Frameworks/CoreMotion.framework/")',
    "PXCoreMotionObjectGetterEncodingMatches(method)",
    "method_getNumberOfArguments(method) != 2",
    "returnType[0] == '@'",
    "MSHookMessageEx(cls",
    "&rule->original",
    "PXInstallPedometerAltitudeDirectHooks();",
):
    require(token in TWEAK, f"runtime safety contract missing: {token}")

getter = re.search(
    r"static NSNumber \*PXCoreMotionProjectedNumberGetter\(id self, SEL _cmd\) \{(.*?)\n\}",
    TWEAK,
    re.S,
)
require(getter is not None, "typed number getter replacement missing")
getter_body = getter.group(1)
require(getter_body.find("rule->original)(self, _cmd)") < getter_body.find("PXCurrentSensorSnapshot()"),
        "direct getters are not original-first")
require("if (!snap.active)" in getter_body and "return originalValue;" in getter_body,
        "OFF/out-of-scope getter path does not fail open")
require("PXClearPedometerOverride(self)" in getter_body and
        "PXClearAltitudeOverride(self)" in getter_body,
        "OFF transition can leak a stale associated payload")

section_start = TWEAK.index("#pragma mark - P0-04 pedometer / altitude projection")
section_end = TWEAK.index("// Add new group for sensor data integration", section_start)
projection = TWEAK[section_start:section_end]
for forbidden in (
    "arc4random",
    "setValue:",
    "NSTimer",
    "CFRunLoopRun",
    "dispatch_async",
    "class_addMethod",
    '[[objc_getClass("CMAltitudeData") alloc] init]',
):
    require(forbidden not in projection, f"nondeterministic/synthetic P0-04 path remains: {forbidden}")

require("startDate" in projection and "endDate" in projection and
        "timeIntervalSinceDate:startDate" in projection,
        "pedometer projection does not preserve/use the real interval")
require("activeTime = MAX(activeTime" in projection and
        "steps = MAX(steps" in projection and
        "distance = MAX(distance" in projection,
        "cumulative pedometer fields are not monotonic per session")
require("payload.numberOfSteps = @((NSUInteger)steps);" in projection,
        "step count is not integral")
require("101.325 * pow(ratio, 5.255)" in projection,
        "altitude pressure is not projected in CoreMotion kilopascals")
require("baselineGeneration == NSUIntegerMax" in projection and
        "if (snap.active)" in projection,
        "altitude baseline is not anchored to the first active callback")

for token in (
    "handler(PXTransformPedometerData(data, PXCurrentSensorSnapshot()), error);",
    "handler(PXTransformAltitudeData(data, snap, baseline), error);",
    "%orig(start, PXWrapPedometerHandler(handler));",
    "%orig(start, end, PXWrapPedometerHandler(handler));",
    "%orig(queue, PXWrapAltitudeHandler(handler));",
):
    require(token in TWEAK, f"callback pointer/queue/cardinality contract missing: {token}")

require("static id PXTransformPedometerData" in projection and "return data;" in projection,
        "pedometer callback does not retain the original object")
require("static CMAltitudeData *PXTransformAltitudeData" in projection,
        "altitude callback transformer missing")
require("kAltimeterTimerKey" not in TWEAK and "Started custom altitude updates" not in TWEAK,
        "legacy synthetic altitude owner is still installed")

print("P0-04 pedometer/altitude static contract: PASS")
