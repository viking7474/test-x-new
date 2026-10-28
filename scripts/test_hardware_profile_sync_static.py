#!/usr/bin/env python3
"""Static regression checks for model/RAM/camera/storage profile parity."""

from pathlib import Path
from test_runtime_identifier_writers import method


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def reset_storage_contract(dashboard: str, manager: str) -> bool:
    """Follow the UI adapter into the owned coordinator, not an old UI body."""
    try:
        ui = method(dashboard, '- (BOOL)applyFakePreviewToCurrentProfile:(NSDictionary *)preview')
        apply = method(manager, '- (BOOL)applyDashboardPreview:(NSDictionary *)preview expectedActiveProfileID:(NSString *)profileID error:(NSError **)error')
    except (ValueError, AssertionError):
        return False
    if '[self.manager applyDashboardPreview:preview error:&error]' not in ui:
        return False
    # Resolve the final hardware identity before capacity selection, then stage
    # storage with the identifiers and publish its cache only after commit/release.
    ordered = (
        'model = resolved[@"DeviceModel"]',
        'if (!model.length && requestedVersion.length && tupleProduct.length) model = targetProduct = tupleProduct;',
        'if (model.length && [self isIdentifierEnabled:@"StorageSystem"])',
        'randomizeStorageCapacityForDeviceModel:model',
        'generateStorageForCapacity:capacity',
        'committed = [mutation performSourceWrite:',
        'PXStageRuntimeIdentifierState(tx, identity, packet[@"updates"]',
        '[tx setDictionary:storage atPath:[mutation.profileDirectory stringByAppendingPathComponent:@"storage.plist"] error:stageError]',
        '} error:&writeError];',
        '[mutation invalidate]',
        'if (!committed) return NO;',
        'adoptCommittedStorageInfo:storage',
    )
    positions = [apply.find(token) for token in ordered]
    return all(position >= 0 for position in positions) and positions == sorted(positions)


def check_reset_storage_regressions(dashboard: str, manager: str) -> None:
    # Tokens elsewhere in a file must not hide a broken coordinator/adapter.
    cases = (
        ('UI delegation', dashboard, 'applyDashboardPreview:preview error:&error'),
        ('software-only final model', manager, 'model = targetProduct = tupleProduct;'),
        ('capacity model', manager, 'randomizeStorageCapacityForDeviceModel:model'),
        ('storage staging', manager, '[tx setDictionary:storage atPath:'),
        ('post-commit cache', manager, 'adoptCommittedStorageInfo:storage'),
    )
    for name, source, token in cases:
        assert token in source, f'missing regression fixture token: {name}'
        broken = source.replace(token, 'BROKEN_STORAGE_CONTRACT') + '\n' + token
        ui, coordinator = (broken, manager) if name == 'UI delegation' else (dashboard, broken)
        assert not reset_storage_contract(ui, coordinator), f'gate missed regression: {name}'
    print(f'PASS: Reset storage gate rejects broken delegation/model/staging/publication ({len(cases)}/{len(cases)})')


def main() -> None:
    model = read("common/DeviceModelManager.m")
    schema = read("common/PXDeviceProfileSchema.m")
    manager = read("common/IdentifierManager.m")
    storage = read("common/StorageManager.m")
    registry = read("common/PXIdentitySurfaceRegistry.m")
    device_hook = read("TLinkIOSTweak/DeviceSpecHooks.x")
    dashboard = read("TLinkIOSViewController.m")
    model_db = read("data/iphone_model_db.json")

    checks = {
        "Reset Data enables storage with Fake Model": '@"StorageSystem": @(fakeModel)' in dashboard,
        "Reset prefers a changed hardware signature": "differentHardware.count ? differentHardware" in dashboard and "signatureKeys" in dashboard,
        "legacy storage enable stays atomic with primary toggle": 'saveDict[@"StorageSystemEnabled"]' in manager,
        "DB generation resolves canonical model hardware": "canonicalHardwareSpecForProductType:productType" in manager,
        "all model writers persist hardware capabilities": manager.count("PXWriteHardwareCapabilitiesToDeviceIDs") >= 2,
        "schema preserves camera booleans including false": all(k in schema for k in [
            'hasFrontCamera', 'hasRearCamera', 'hasUltraWideCamera', 'hasTelephotoCamera',
            'hasLiDARScanner', 'supports4KVideo']),
        "schema carries supported storage tiers": 'storageCapacitiesGB' in schema and 'StorageCapacitiesGB' in schema,
        "storage selection is model-aware": "randomizeStorageCapacityForDeviceModel" in storage and 'storageCapacitiesGB' in storage,
        "Reset reapplies storage from the final fake model": reset_storage_contract(dashboard, manager),
        "fake iOS only preserves current hardware identity": "Fake iOS without Fake Model must preserve the current hardware identity" in dashboard and '@"BoardID", @"HwModel"' in dashboard,
        "iPhone 15 Pro Max storage tiers exclude 128GB": '[model isEqualToString:@"iPhone16,2"] || [model isEqualToString:@"iPhone17,2"]) capacities = @[@256, @512, @1024]' in model,
        "storage selection avoids immediate repeat": "[candidates removeObject:previous]" in storage,
        "camera MobileGestalt capabilities are typed": all(k in registry for k in [
            'ForwardCameraCapability', 'RearCameraCapability', 'PanoramaCameraCapability',
            'FrontCameraMegapixels', 'RearCameraMegapixels', 'RearCameraCount']),
        "RAM basic info uses host_info": 'dlsym(RTLD_DEFAULT, "host_info")' in device_hook and "hook_host_info_device_spec" in device_hook,
        "RAM legacy usermem is covered": 'strcmp(name, "hw.usermem") == 0' in device_hook,
        "invalid Objective-C struct hook is removed": "%hook host_basic_info" not in device_hook,
    }

    # Every product type eligible for random selection must have a canonical
    # DeviceModelManager row, otherwise a rare reset can silently lose RAM and
    # camera fields.
    import json
    payload = json.loads(model_db)
    rows = payload if isinstance(payload, list) else next(v for v in payload.values() if isinstance(v, list))
    missing = [row["productType"] for row in rows if f'addSpecsForDevice:@"{row["productType"]}"' not in model]
    checks["all randomizable iPhone models have hardware rows"] = not missing

    failed = [name for name, ok in checks.items() if not ok]
    for name, ok in checks.items():
        print(("PASS" if ok else "FAIL") + ": " + name)
    if missing:
        print("missing models: " + ", ".join(missing))
    if failed:
        raise SystemExit(f"hardware profile sync static test: FAIL ({len(failed)}/{len(checks)})")
    check_reset_storage_regressions(dashboard, manager)
    print(f"hardware profile sync static test: PASS ({len(checks)}/{len(checks)})")


if __name__ == "__main__":
    main()
