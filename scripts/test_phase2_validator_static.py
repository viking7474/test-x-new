#!/usr/bin/env python3
"""Host-independent Phase-2 contract check for Windows/static CI."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require(path: str, needles: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")

def forbid(path: str, needles: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    present = [needle for needle in needles if needle in text]
    if present:
        raise AssertionError(f"{path}: forbidden contracts present: {present}")

require("common/PXIdentityDependencyValidator.m", [
    'incomplete-version-build-kernel-tuple',
    'build-not-in-versioned-database',
    'does-not-match-build-',
    'kernel-banner-does-not-contain-darwin-xnu',
    'model-not-in-versioned-database',
    'build-not-supported-by-model',
    'board-or-hwmodel-does-not-match-product-type',
    'cellular-identifiers-on-noncellular-model',
    'secondary-imei-requires-primary-imei',
    'coherent-ios-database-required',
])
require("common/PXIdentitySnapshot.m", [
    '#import "PXIdentityDependencyValidator.h"',
    '#import "PXVersionedIOSDatabase.h"',
    'PXValidateIdentityDependencies(deviceIDs, buildRoot, modelRoot)',
    'BOOL valid = profileID.length > 0 && validation.inputValid && deviceIDs.count > 0;',
    '@"dependency-validation-failed"',
    'transientFailure && sameProfile && gPXIdentitySnapshot.valid',
])
# Dependency validation must keep running and recording issues for diagnostics,
# but it must NOT gate snapshot validity. The old hard gate (ae3ddac) nil-ed out
# DeviceIDs on any mismatch and reverted Device Model/Type/iOS Version to the
# real device values. Keep the gate free of dependencies.valid.
forbid("common/PXIdentitySnapshot.m", [
    'validation.inputValid && dependencies.valid',
    'dependencies.valid && deviceIDs.count',
])
require("tests/PXPhase2ValidatorTests.m", [
    'version/build mismatch was accepted',
    'partial software tuple was accepted',
    'invalid hardware variant was accepted',
    'cellular value on Wi-Fi-only model was accepted',
    'profile requiring a database was accepted without one',
])
print("Phase-2 static contracts: PASS")
sys.exit(0)
