#!/usr/bin/env python3
"""Static contract for P0-01 MobileGestalt typed key parity."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8", errors="strict")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


header = read("common/PXIdentitySurfaceRegistry.h")
registry = read("common/PXIdentitySurfaceRegistry.m")
tweak = read("TLinkIOSTweak/Tweak.x")
tests = read("tests/PXIdentitySurfaceRegistryTests.m")
fixture = json.loads(read("Tests/fixtures/ifake_parity_profile.json"))["deviceIDs"]

for token in (
    "PXIdentityExpectedTypeNumber",
    "PXIdentityExpectedTypeBoolean",
    "PXIdentityProjectionPositiveNumber",
    "PXIdentityProjectionUnsignedInteger",
    "PXIdentityProjectionMACAddressData",
    "PXIdentityProjectionResolutionWidth",
    "PXIdentityProjectionResolutionHeight",
    "PXIdentityProjectionFractionToPercent",
    "PXIdentitySurfaceResolveObject",
):
    require(token in header, f"typed registry contract missing: {token}")

required_entries = {
    'PXEntry(@"MLBSerialNumber"': "MLB serial",
    'PXEntryWithProjection(@"UniqueChipID", @[@"ChipID"]': "chip ID alias",
    'PXEntry(@"CPUArchitecture"': "CPU architecture",
    'PXEntry(@"HardwarePlatform"': "hardware platform",
    'PXEntry(@"UserAssignedDeviceName"': "device name",
    'PXEntry(@"marketing-name"': "marketing name",
    'PXEntry(@"InternationalMobileEquipmentIdentity2"': "second IMEI",
    'PXEntry(@"InternationalMobileSubscriberIdentity"': "IMSI",
    'PXEntry(@"IntegratedCircuitCardIdentifier"': "ICCID",
    'PXEntry(@"BasebandFirmwareVersion"': "baseband version",
    'PXEntry(@"WifiAddress"': "Wi-Fi address",
    'PXEntryWithProjection(@"WifiAddressData"': "binary Wi-Fi address",
    'PXEntry(@"BluetoothAddress"': "Bluetooth address",
    'PXEntryWithProjection(@"main-screen-width"': "screen width",
    'PXEntryWithProjection(@"main-screen-height"': "screen height",
    'PXEntryWithProjection(@"main-screen-scale"': "screen scale",
    'PXEntryWithProjection(@"main-screen-pitch"': "screen pitch",
    'PXEntryWithProjection(@"BatteryCurrentCapacity"': "battery percent",
}
for token, label in required_entries.items():
    require(token in registry, f"MobileGestalt registry entry missing: {label}")

for token in (
    "PXMACAddressData",
    "PXResolutionComponent",
    "PXStrictNumber",
    "PXStrictUnsignedInteger",
    "llround(value * 100.0)",
    "data projection has non-data ABI",
    "numeric projection has non-number ABI",
):
    require(token in registry, f"typed projection safety contract missing: {token}")

require(tweak.count("PXIdentitySurfaceResolveObject(entry, deviceIDs)") == 1,
        "alternate MobileGestalt path must use typed resolver exactly once")
require("PXIdentitySurfaceResolveObject(surfaceEntry, deviceIds)" in tweak,
        "MGCopyAnswer must use typed resolver")
require(tweak.count("PXMGCreateTypedRegistryValue") >= 3,
        "both MobileGestalt paths must use the shared CF type adapter")

fixture_types = {
    "MLBSerialNumber": str,
    "UniqueChipID": int,
    "CPUArchitecture": str,
    "ScreenResolution": str,
    "DevicePixelRatio": (int, float),
    "ScreenDensityPPI": (int, float),
    "IMEI2": str,
    "IMSI": str,
    "ICCID": str,
    "BasebandVersion": str,
    "WiFiAddress": str,
    "BluetoothAddress": str,
    "BatteryLevel": str,
}
for key, expected in fixture_types.items():
    require(key in fixture, f"typed parity fixture missing {key}")
    require(isinstance(fixture[key], expected), f"typed parity fixture has wrong type for {key}")

for token in (
    "MG UniqueChipID must be a CFNumber-compatible NSNumber",
    "MG decimal UniqueChipID must preserve unsigned integer precision",
    "MG direct string projection drifted",
    "MG WifiAddressData must contain six binary MAC bytes",
    "MG screen width projection drifted",
    "MG battery capacity must be percent CFNumber",
    "malformed MAC data must fail open",
    "out-of-range battery must fail open",
    "invalid chip ID must fail open",
    "overflowing chip ID must fail open",
    "non-positive screen scale must fail open",
):
    require(token in tests, f"typed registry test assertion missing: {token}")

print("MobileGestalt typed parity static contract: PASS")
