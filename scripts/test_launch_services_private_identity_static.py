#!/usr/bin/env python3
"""Static contract for P0-02 LaunchServices/private identity consistency."""

from __future__ import annotations

import json
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8", errors="strict")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


projection_h = read("common/PXPrivateIdentityWrapperProjection.h")
projection_m = read("common/PXPrivateIdentityWrapperProjection.m")
uuid_h = read("common/PXIdentifierUUIDProjection.h")
uuid_m = read("common/PXIdentifierUUIDProjection.m")
registry = read("common/PXIdentitySurfaceRegistry.m")
hooks = read("TLinkIOSTweak/PrivateIdentityWrapperHooks.x")
tweak = read("TLinkIOSTweak/Tweak.x")
matrix = read("common/PXConsistencyMatrix.m")
tests = read("tests/PXPrivateIdentityWrapperProjectionTests.m")
phase_a = read("tests/PXPhaseAConsistencyGateTests.m")
fixture = json.loads(read("tests/fixtures/ifake_parity_profile.json"))["deviceIDs"]

launch_services_rules = (
    'PXPrivateWrapperUUIDRule(@"LSApplicationWorkspace", @"deviceIdentifierForVendor")',
    'PXPrivateWrapperUUIDRule(@"LSApplicationWorkspace", @"deviceIdentifierForAdvertising")',
    'PXPrivateWrapperUUIDRule(@"LSApplicationProxy", @"deviceIdentifierForVendor")',
    'PXPrivateWrapperUUIDRule(@"LSApplicationProxy", @"deviceIdentifierForAdvertising")',
)
for token in launch_services_rules:
    require(token in projection_m, f"LaunchServices UUID rule missing: {token}")

for token in (
    'PXPrivateWrapperRule(@"AMSDevice", @"uniqueDeviceId", YES, NO)',
    'PXPrivateWrapperRule(@"AMSDevice", @"hardwarePlatform", YES, NO)',
    'PXPrivateWrapperRule(@"CTMobileEquipmentInfo", @"ICCID", NO, NO)',
    'PXPrivateWrapperRule(@"CTMobileEquipmentInfo", @"IMSI", NO, NO)',
    'PXPrivateWrapperRule(@"DMFDevice", @"ICCID", NO, NO)',
    'PXPrivateWrapperRule(@"DMFDevice", @"marketingName", NO, NO)',
):
    require(token in projection_m, f"evidence-backed private wrapper rule missing: {token}")

for token in (
    'PXEntry(@"deviceIdentifierForAdvertising", @[], @"IDFA", @"IDFA"',
    'PXEntry(@"deviceIdentifierForVendor", @[], @"IDFV", @"IDFV"',
    'PXEntry(@"uniqueDeviceId", @[], @"UDID", @"UDID"',
    'PXEntry(@"hardwarePlatform", @[], @"DeviceModel", @"HwModel"',
    'PXEntry(@"marketingName", @[], @"DeviceModel", @"DeviceModelName"',
):
    require(token in registry, f"private identity registry mapping missing: {token}")

require("PXPrivateIdentityWrapperProjectUUID" in projection_h,
        "NSUUID projection API is not exported")
for token in (
    "if (![original isKindOfClass:[NSUUID class]]) return original;",
    "PXProjectAdvertisingIdentityUUID(original, deviceIDs)",
    "PXProjectIdentityUUID(original, value)",
):
    require(token in projection_m, f"LaunchServices fail-open/type contract missing: {token}")

for token in (
    "PXProjectIdentityUUID",
    "PXProjectAdvertisingIdentityUUID",
    "PXIdentitySnapshotATTAuthorizationStatus",
):
    require(token in uuid_h, f"shared UUID projection API missing: {token}")
for token in (
    "if (![original isKindOfClass:[NSUUID class]]) return original;",
    "[[NSUUID alloc] initWithUUIDString:value]",
    "PXIdentitySnapshotATTAuthorizationStatus(deviceIDs) != 3",
    "kPXProjectedZeroIDFAUUID",
    'deviceIDs[@"IDFA"]',
):
    require(token in uuid_m, f"shared IDFA/IDFV projection contract missing: {token}")

for token in (
    '#import "PXIdentifierUUIDProjection.h"',
    "PXProjectAdvertisingIdentityUUID(originalIdentifier, snapshot.deviceIDs)",
    'PXProjectIdentityUUID(originalIdentifier, snapshot.deviceIDs[@"IDFV"])',
    "PXIdentitySnapshotATTAuthorizationStatus(snapshot.deviceIDs)",
):
    require(token in tweak, f"public IDFA/IDFV hook is not using the shared snapshot projection: {token}")
require("idfvCache" not in tweak,
        "IDFV cache can retain a stale value across identity generations")

for token in (
    "class_getInstanceMethod(cls, selector)",
    "PXPrivateIdentityWrapperMethodEncodingIsSupported(types, keyedGetter)",
    "PXPrivateIdentityClassIsSystemOwned(cls)",
    "PXPrivateIdentityWrapperProjectUUID(original, surfaceKey, snapshot.deviceIDs)",
    "isIdentifierEnabled:entry.toggle",
    "_dyld_register_func_for_add_image",
):
    require(token in hooks, f"runtime-gated LaunchServices hook contract missing: {token}")
require("class_addMethod" not in hooks,
        "P0-02 must never synthesize an unavailable selector")

getter_start = hooks.index("static id PXPrivateIdentityGetter")
getter_end = hooks.index("static PXIdentitySurfaceEntry *PXPrivateIdentityEntryForQueriedKey", getter_start)
getter = hooks[getter_start:getter_end]
require(getter.index("PXPrivateIdentityCallOriginal0") < getter.index("PXPrivateIdentityProjectionContext"),
        "private identity hook must call original before projection gates")

for token in (
    '@"LSApplicationWorkspace.deviceIdentifierForAdvertising", @"IDFA", @"IDFA", @"IDFA"',
    '@"LSApplicationProxy.deviceIdentifierForAdvertising", @"IDFA", @"IDFA", @"IDFA"',
    '@"LSApplicationWorkspace.deviceIdentifierForVendor", @"IDFV", @"IDFV", @"IDFV"',
    '@"LSApplicationProxy.deviceIdentifierForVendor", @"IDFV", @"IDFV", @"IDFV"',
    '@"UIDevice", @"identifierForVendor", @"IDFV", @"IDFV", @"IDFV"',
):
    require(token in matrix, f"cross-surface IDFA/IDFV matrix row missing: {token}")

for key in ("IDFA", "IDFV"):
    require(isinstance(fixture.get(key), str), f"fixture missing string {key}")
    uuid.UUID(fixture[key])
require(fixture.get("ATTAuthorizationStatus") == 3,
        "parity fixture must authorize ATT for canonical IDFA projection")

for token in (
    "LaunchServices UUID rule inventory drifted",
    "LaunchServices advertising identifier must match canonical IDFA as NSUUID",
    "LaunchServices vendor identifier must match canonical IDFV as NSUUID",
    "LaunchServices advertising identifier must honor denied ATT with zero UUID",
    "invalid LaunchServices UUID must fail open",
    "nil LaunchServices original must not synthesize a selector result",
    "non-NSUUID LaunchServices result must fail open",
    "P0-02 private wrapper projection drifted",
):
    require(token in tests, f"P0-02 unit-test assertion missing: {token}")
require('PXPhaseAExpected(@"LaunchServices"' in phase_a,
        "Phase-A gate does not compare LaunchServices to the canonical matrix")
require('@"missing IDFV"' in phase_a and "missing IDFV did not fail open in LaunchServices" in phase_a,
        "Phase-A gate lacks missing-IDFV fail-open coverage")

for forbidden in (
    'PXPrivateWrapperRule(@"PK',
    'PXPrivateWrapperUUIDRule(@"PK',
    'PXPrivateWrapperRule(@"NF',
    'PXPrivateWrapperUUIDRule(@"NF',
):
    require(forbidden not in projection_m,
            f"Secure Element/PassKit rule entered P0-02 allowlist: {forbidden}")

print("LaunchServices/private identity consistency static contract: PASS")
