#!/usr/bin/env python3
"""Host-independent Phase-3 registry/hook contracts."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [n for n in needles if n not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")

require("common/PXIdentitySurfaceRegistry.m", [
    '@"ProductType"', '@"HWModelStr"', '@"HardwareModel"', '@"BoardId"',
    '@"ProductVersion"', '@"ProductBuildVersion"', '@"BuildVersion"',
    '@"device-model"', '@"product-name"', '@"model"', '@"board-id"',
    '@"compatible"', 'PXIdentityExpectedTypeData', 'duplicate surface alias',
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
])
print("Phase-3 static contracts: PASS")
