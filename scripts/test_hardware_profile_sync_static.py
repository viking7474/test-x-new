#!/usr/bin/env python3
"""Static regression checks for model/RAM/camera/storage profile parity."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


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
        "Reset reapplies storage from the final fake model": "randomizeStorageCapacityForDeviceModel:model" in dashboard,
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
    print(f"hardware profile sync static test: PASS ({len(checks)}/{len(checks)})")


if __name__ == "__main__":
    main()
