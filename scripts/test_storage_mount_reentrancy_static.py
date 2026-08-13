#!/usr/bin/env python3
"""Regression guard for CoreServices MountInfo recursion in storage hooks."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "TLinkIOSTweak" / "StorageHooks.x").read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    begin = SOURCE.index(start)
    finish = SOURCE.index(end, begin)
    return SOURCE[begin:finish]


providers = block('registerStatfsProvider:@"storage.statfs"',
                  'PXLog(@"[StorageHooks] Registered statfs family providers')

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
    if required not in SOURCE:
        raise AssertionError(f"missing mount reentrancy safeguard: {required}")

print("storage mount reentrancy static test: PASS")
