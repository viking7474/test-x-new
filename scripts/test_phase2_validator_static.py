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
    'validation.inputValid && dependencies.valid',
    '@"dependency-validation-failed"',
    'transientFailure && sameProfile && gPXIdentitySnapshot.valid',
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
