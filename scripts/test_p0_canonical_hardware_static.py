#!/usr/bin/env python3
"""Static regression checks for the P0 canonical iPhone hardware profile."""

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    print(("PASS" if condition else "FAIL") + ": " + message)
    if not condition:
        raise AssertionError(message)


def main() -> None:
    model_root = json.loads(read("data/iphone_model_db.json"))
    hardware_root = json.loads(read("data/iphone_hardware_db.json"))
    cellular_root = json.loads(read("data/iphone_cellular_db.json"))
    tac_root = json.loads(read("data/iphone_tac_catalog.json"))
    tac_supplement = json.loads(read("data/iphone_tac_supplement.json"))
    models = {row["productType"]: row for row in model_root["models"]}

    check(bool(model_root.get("hardwareCatalogVersion")), "generated model DB declares P0 hardware catalog")
    check(bool(model_root.get("cellularCatalogVersion")), "generated model DB declares regional cellular catalog")
    check(len(models) > 0, "generated model DB contains iPhone models")

    required_model_fields = [
        "screen", "cpuArchitecture", "cpuProfileKey", "deviceMemoryGB", "cpuCores",
        "frontCameraMegapixels", "rearCameraMegapixels", "rearCameraCount",
        "hasFrontCamera", "hasRearCamera", "hasPanoramaCamera", "hasUltraWideCamera",
        "hasTelephotoCamera", "hasLiDARScanner", "supports4KVideo", "storageCapacitiesGB",
        "cellular", "variants",
    ]
    for product_type, row in models.items():
        missing = [key for key in required_model_fields if key not in row]
        check(not missing, f"{product_type} has all P0 model fields")
        screen = row["screen"]
        check(all(key in screen for key in ["resolution", "viewport", "scale", "nativeScale", "ppi"]),
              f"{product_type} has explicit display geometry")
        check(bool(row["variants"]), f"{product_type} has at least one hardware variant")
        aggregate = set(row.get("regulatoryModelNumbers", []))
        for variant in row["variants"]:
            nums = set(variant.get("regulatoryModelNumbers", []))
            check(bool(variant.get("boardID")) and bool(variant.get("hwModel")) and bool(nums),
                  f"{product_type} variant keeps board/hwModel/regulatory A-number relation")
            check(nums.issubset(aggregate), f"{product_type} variant A-numbers are contained in aggregate compatibility list")

    check(models["iPhone10,3"]["variants"] == [{
        "boardID": "D22AP", "hwModel": "D22AP", "regulatoryModelNumbers": ["A1865", "A1902"]
    }], "iPhone10,3 uses D22AP and preserves its exact A-numbers")
    check(models["iPhone10,6"]["variants"] == [{
        "boardID": "D221AP", "hwModel": "D221AP", "regulatoryModelNumbers": ["A1901"]
    }], "iPhone10,6 keeps D221AP separate from iPhone10,3")
    check(hardware_root["models"]["iPhone14,7"]["deviceMemoryGB"] == 6 and
          hardware_root["models"]["iPhone14,8"]["deviceMemoryGB"] == 6,
          "iPhone 14 and 14 Plus RAM is explicit 6 GB rather than prefix-derived 4 GB")
    check(hardware_root["models"]["iPhone16,2"]["storageCapacitiesGB"] == [256, 512, 1024],
          "iPhone 15 Pro Max storage starts at 256 GB")

    iphone13_mini = models.get("iPhone14,4", {})
    iphone13 = models.get("iPhone14,5", {})
    check("A2626" in set(iphone13_mini.get("regulatoryModelNumbers", [])),
          "iPhone 13 mini owns regulatory model A2626")
    check("A2631" in set(iphone13.get("regulatoryModelNumbers", [])) and
          "A2626" not in set(iphone13.get("regulatoryModelNumbers", [])),
          "iPhone 13 owns A2631 and does not reuse iPhone 13 mini A2626")

    modern_expectations = {
        "iPhone15,4": ("D37AP", {"A2846", "A3089", "A3090", "A3092"}, "17.0.0"),
        "iPhone15,5": ("D38AP", {"A2847", "A3093", "A3094", "A3096"}, "17.0.0"),
        "iPhone16,1": ("D83AP", {"A2848", "A3101", "A3102", "A3104"}, "17.0.0"),
        "iPhone16,2": ("D84AP", {"A2849", "A3105", "A3106", "A3108"}, "17.0.0"),
        "iPhone17,1": ("D93AP", {"A3083", "A3292", "A3293", "A3294"}, "18.0.0"),
        "iPhone17,2": ("D94AP", {"A3084", "A3295", "A3296", "A3297"}, "18.0.0"),
        "iPhone17,3": ("D47AP", {"A3081", "A3286", "A3287", "A3288"}, "18.0.0"),
        "iPhone17,4": ("D48AP", {"A3082", "A3289", "A3290", "A3291"}, "18.0.0"),
        "iPhone17,5": ("V59AP", {"A3212", "A3408", "A3409", "A3410"}, "18.3.1"),
        "iPhone18,1": ("V53AP", {"A3256", "A3522", "A3523", "A3524"}, "26.0.0"),
        "iPhone18,2": ("V54AP", {"A3257", "A3525", "A3526", "A3527"}, "26.0.0"),
        "iPhone18,3": ("V57AP", {"A3258", "A3519", "A3520", "A3521"}, "26.0.0"),
        "iPhone18,4": ("D23AP", {"A3260", "A3516", "A3517", "A3518"}, "26.0.0"),
        "iPhone18,5": ("V159AP", {"A3575", "A3634", "A3635"}, "26.3.0"),
    }
    for product_type, (board, regulatory_numbers, min_ios) in modern_expectations.items():
        row = models.get(product_type)
        check(bool(row), f"{product_type} is published by generated canonical model DB")
        check(row.get("minIOS") == min_ios, f"{product_type} minimum iOS is {min_ios}")
        check(row.get("maxIOS") == "27.0.1", f"{product_type} maximum curated iOS is 27.0.1")
        check(row.get("variants") == [{
            "boardID": board,
            "hwModel": board,
            "regulatoryModelNumbers": sorted(regulatory_numbers),
        }], f"{product_type} preserves exact board/regulatory A-number tuple")
        regional = row.get("cellularByRegulatoryModelNumber", {})
        check(set(regional) == regulatory_numbers,
              f"{product_type} publishes regional cellular slots for every A-number")
        check(all(spec.get("known") is True for spec in regional.values()),
              f"{product_type} regional cellular is publication-ready from curated P1 data")
        check(all(isinstance(spec.get("imeiTACs"), list) and spec.get("imeiTACs")
                  for spec in regional.values()),
              f"{product_type} has non-empty authoritative TAC evidence")

    builder = read("scripts/build_ios_db.py")
    manager = read("common/IdentifierManager.m")
    validator = read("common/PXIdentityDependencyValidator.m")
    storage = read("common/StorageManager.m")
    device_spec = read("TLinkIOSTweak/DeviceSpecHooks.x")
    dashboard = read("TLinkIOSViewController.m")
    versioned = read("common/PXVersionedIOSDatabase.m")
    surfaces = read("common/PXIdentitySurfaceRegistry.m")
    cellular_schema = read("common/PXCellularIdentitySchema.m")

    check('"regulatoryModelNumbers": variant_numbers' in builder,
          "DB builder publishes A-numbers inside exact hardware variants")
    check("Duplicate KMOS OSBuild" in builder,
          "DB builder fails closed on duplicate OSBuild rows")
    check("canonicalHardwareSpecForProductType:productType" in manager,
          "profile generation reads model-level P0 hardware from canonical DB")
    check("PXPickRegulatoryModelNumberFromModelSpec(modelSpec, pickedVariant)" in manager,
          "profile generation selects regulatory A-number from selected variant")
    check("board-hwmodel-regulatory-model-variant-mismatch" in validator,
          "dependency validator checks BoardID/HwModel/A-number as one tuple")
    check("PXValidateCanonicalModelHardware" in validator,
          "dependency validator checks RAM/display/camera/storage/CPU model fields")
    check("canonicalHardwareSpecForProductType:deviceModel" in storage,
          "storage tier resolution uses canonical model DB")
    check('source = @"iphone_model_db"' in device_spec,
          "DeviceSpec fallback prefers canonical model DB")
    check('specs[@"cpuProfileKey"]' in device_spec,
          "CPU hooks consume exact CPUProfileKey")
    check('specs[@"nativeScale"]' in device_spec and "screenDensity / 163.0" not in device_spec,
          "display hooks consume exact NativeScale instead of deriving from PPI")
    check('@"partNumber":' in dashboard and 'preview[@"ModelNumber"]' not in dashboard,
          "Dashboard part number metadata never writes hardware/retail ModelNumber")
    check("No canonical hardware model is available in the selected range" in dashboard,
          "Dashboard rejects models that lack canonical hardware DB records")
    check("P0 hardware catalog contains an incomplete model record" in versioned,
          "database publisher validates P0 hardware payload before publishing")
    check("cellularByRegulatoryModelNumber" in versioned and "regionalCellularValid" in versioned,
          "database publisher validates regional cellular A-number overrides")
    check('@"RegulatoryModelNumber"' in surfaces and '@"regulatory-model-number"' in surfaces,
          "regulatory A-number has dedicated MG and IORegistry surfaces")
    check('deviceIds[@"RegulatoryModelNumber"]' in manager and
          'deviceIds[@"ModelNumber"] = regulatoryModelNumber' not in manager,
          "A-number is never published as retail ModelNumber")
    check('known=false is an explicit' in cellular_schema and
          'cellularSpec[@"known"]' in cellular_schema,
          "unknown cellular capability is explicit and is not guessed")
    check('cellularByRegulatoryModelNumber' in cellular_schema and
          'RegulatoryModelNumber' in cellular_schema and
          'PXResolvedCellularSpec' in cellular_schema,
          "cellular resolver prefers the exact regulatory A-number override")
    expected_regulatory_numbers = set().union(
        *(numbers for _, numbers, _ in modern_expectations.values())
    )
    check(set(cellular_root.get("regulatoryModels", {})) == expected_regulatory_numbers,
          "manual cellular catalog exposes exactly the covered iPhone 15/16/17 regional A-number slots")
    check(all(
        isinstance(tac, str) and len(tac) == 8 and tac.isdigit()
        for spec in cellular_root.get("regulatoryModels", {}).values()
        for tac in spec.get("imeiTACs", [])
    ), "all collected IMEI TAC evidence is normalized to exact 8-digit strings")
    tac_records = tac_root.get("regulatoryModels", {})
    check(tac_root.get("schemaVersion") == 1 and
          tac_root.get("sourceFile") == "Apple.csv" and
          tac_root.get("sourceSha256") == "48d0bee4b850bc8666c37852f81c99d557f3939112b8092068b37b3cf357d211",
          "TAC evidence catalog is pinned to the imported Apple.csv SHA-256")
    supplement_pools = tac_supplement.get("sharedPools", {})
    pool17e = supplement_pools.get("iPhone18,5", {})
    shared_17e_numbers = set(pool17e.get("regulatoryModelNumbers", []))
    shared_17e_tacs = pool17e.get("imeiTACs", [])
    check(set(tac_records) == expected_regulatory_numbers.difference(shared_17e_numbers),
          "Apple.csv TAC evidence covers the original regulatory slots and 17e is isolated in a supplement")
    check(shared_17e_numbers == {"A3575", "A3634", "A3635"} and
          len(shared_17e_tacs) == 10 and
          all(isinstance(tac, str) and len(tac) == 8 and tac.isdigit() for tac in shared_17e_tacs),
          "iPhone 17e supplement declares the exact shared 10-TAC pool for all three A-numbers")
    check(all(
        cellular_root["regulatoryModels"][number].get("imeiTACs") == shared_17e_tacs
        for number in shared_17e_numbers
    ), "iPhone 17e A3575/A3634/A3635 intentionally share one unclassified TAC pool")

    tac_owners = {}
    for number, spec in cellular_root.get("regulatoryModels", {}).items():
        for tac in spec.get("imeiTACs", []):
            tac_owners.setdefault(tac, set()).add(number)
    unexpected_duplicate_tacs = {
        tac: sorted(owners)
        for tac, owners in tac_owners.items()
        if len(owners) > 1 and not (tac in shared_17e_tacs and owners == shared_17e_numbers)
    }
    check(not unexpected_duplicate_tacs,
          "TAC sharing is allowed only for the explicitly declared iPhone 17e shared pool")
    check(all(
        cellular_root["regulatoryModels"][number].get("imeiTACs") == spec.get("imeiTACs")
        for number, spec in tac_records.items()
    ), "cellular TAC arrays stay byte-for-byte synchronized with imported Apple.csv evidence")
    excluded_tacs = {
        (str(row.get("Model Info")), str(row.get("TAC")))
        for row in tac_root.get("excluded", []) if isinstance(row, dict)
    }
    check(("A3296", "35512783") in excluded_tacs and
          "35512783" not in cellular_root["regulatoryModels"]["A3296"].get("imeiTACs", []),
          "conflicting A3296 TAC remains explicitly excluded fail-closed")
    check("Fallback to legacy generation paths if DB-based generation is unavailable" not in manager,
          "grouped generation no longer falls back to independent legacy model/iOS randomization")

    print("P0 canonical hardware static test: PASS")


if __name__ == "__main__":
    main()
