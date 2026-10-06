#!/usr/bin/env python3
"""Static regression checks for P1 regional cellular/baseband coherence."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def load(path: str):
    return json.loads(read(path))


def check(condition: bool, message: str) -> None:
    print(("PASS" if condition else "FAIL") + ": " + message)
    if not condition:
        raise AssertionError(message)


def main() -> None:
    model_root = load("data/iphone_model_db.json")
    build_root = load("data/ios_build_db.json")
    cell_root = load("data/iphone_cellular_db.json")
    baseband_root = load("data/iphone_baseband_db.json")
    models = {row["productType"]: row for row in model_root["models"]}
    dtb = build_root["deviceToBuilds"]

    expected = {
        "iPhone15,4": {"A2846", "A3089", "A3090", "A3092"},
        "iPhone15,5": {"A2847", "A3093", "A3094", "A3096"},
        "iPhone16,1": {"A2848", "A3101", "A3102", "A3104"},
        "iPhone16,2": {"A2849", "A3105", "A3106", "A3108"},
        "iPhone17,1": {"A3083", "A3292", "A3293", "A3294"},
        "iPhone17,2": {"A3084", "A3295", "A3296", "A3297"},
        "iPhone17,3": {"A3081", "A3286", "A3287", "A3288"},
        "iPhone17,4": {"A3082", "A3289", "A3290", "A3291"},
        "iPhone17,5": {"A3212", "A3408", "A3409", "A3410"},
        "iPhone18,1": {"A3256", "A3522", "A3523", "A3524"},
        "iPhone18,2": {"A3257", "A3525", "A3526", "A3527"},
        "iPhone18,3": {"A3258", "A3519", "A3520", "A3521"},
        "iPhone18,4": {"A3260", "A3516", "A3517", "A3518"},
    }
    all_expected = set().union(*expected.values())

    check(model_root.get("basebandCatalogVersion") == baseband_root.get("databaseVersion"),
          "generated model DB declares exact P1 baseband catalog version")
    check(set(baseband_root.get("regulatoryModels", {})) == all_expected,
          "baseband source exposes exactly the covered iPhone 15/16/17 regional slots")
    check(set(cell_root.get("regulatoryModels", {})) == all_expected,
          "cellular and baseband sources cover the same modern iPhone A-numbers")

    for product_type in ("iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2"):
        check("21A329" not in dtb[product_type] and "21A350" in dtb[product_type],
              f"{product_type} uses an iPhone-15-compatible iOS 17 launch-era build instead of 21A329")
    for product_type in ("iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4"):
        check("22A3354" in dtb[product_type],
              f"{product_type} carries the verified iOS 18.0 launch build")
    check("22D72" not in dtb["iPhone17,5"],
          "iPhone 16e does not inherit the generic 18.3.1 build that predates its device-specific launch branch")
    for product_type in ("iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"):
        check("23A341" in dtb[product_type],
              f"{product_type} carries the verified iOS 26.0 launch build")

    for product_type in expected:
        check(all(build in dtb[product_type] for build in ("23A355", "24A437", "24A446")),
              f"{product_type} carries curated iOS 26.0.1 through 27.0.1 builds")
        check(models[product_type].get("maxIOS") == "27.0.1",
              f"{product_type} publishes current curated max iOS 27.0.1")

    for product_type, numbers in expected.items():
        row = models[product_type]
        regional_cell = row.get("cellularByRegulatoryModelNumber", {})
        regional_baseband = row.get("basebandByRegulatoryModelNumber", {})
        check(set(regional_cell) == numbers,
              f"{product_type} publishes cellular override for every A-number")
        check(set(regional_baseband) == numbers,
              f"{product_type} publishes baseband override for every A-number")
        check(all(spec == {"known": False} for spec in regional_baseband.values()),
              f"{product_type} baseband stays explicit unknown until firmware data is verified")
        for number in numbers:
            source = baseband_root["regulatoryModels"][number]
            check(source.get("productType") == product_type,
                  f"{number} baseband source is bound to {product_type}")
        minimum_major = 26 if product_type.startswith("iPhone18,") else (
            18 if product_type.startswith("iPhone17,") else 17
        )
        check(all(int(build_root["buildToMeta"][build]["version"].split(".", 1)[0]) >= minimum_major
                  for build in dtb[product_type]),
              f"{product_type} supported build allow-list respects its hardware generation")

    builder = read("scripts/build_ios_db.py")
    exporter = read("scripts/export_p1_manual_template.py")
    importer = read("scripts/import_p1_manual_data.py")
    model_db_h = read("common/IPhoneModelDB.h")
    model_db_m = read("common/IPhoneModelDB.m")
    identifier = read("common/IdentifierManager.m")
    device_vc = read("DeviceSpecificSpoofingViewController.m")
    tweak = read("TLinkIOSTweak/Tweak.x")
    lockdown_hook = read("TLinkIOSTweak/LockdownIdentityHooks.x")
    lockdown_provider = read("research/PXLockdownSoCCellularProvider.m")
    cellular = read("common/PXCellularIdentitySchema.m")
    versioned = read("common/PXVersionedIOSDatabase.m")
    schema = read("common/PXDeviceProfileSchema.m")

    for token in (
        "BASEBAND_DB",
        "basebandByRegulatoryModelNumber",
        "missing supported IOSBuild entries",
        "enabled cellular requires imeiTACs",
        "known=true requires cellular known=true enabled=true",
        "regulatory A-number has multiple ProductType owners",
    ):
        check(token in builder, f"generator P1 contract present: {token}")

    for token in (
        "requiredBuilds",
        "baseband_families",
        'family_builds.get(build, "")',
    ):
        check(token in exporter, f"worksheet exporter preserves P1 data: {token}")

    for token in (
        "DRY RUN PASS",
        "validate_database_versions",
        "--allow-stale",
        "enabled cellular requires physicalSIM=true or eSIM=true",
        "disabled cellular cannot advertise SIM/CDMA capabilities",
        "requiredBuilds must exactly match canonical IOSBuild set",
        "baseband known=true requires cellular known=true enabled=true",
        "atomic_write_json",
    ):
        check(token in importer, f"worksheet importer validation present: {token}")

    check("basebandMetaForProductType" in model_db_h and
          "basebandMetaForProductType" in model_db_m,
          "IPhoneModelDB exposes exact ProductType/A-number/IOSBuild baseband resolver")
    check("cellularSpecForProductType" in model_db_h and
          "cellularSpecForProductType" in model_db_m,
          "IPhoneModelDB exposes exact regional cellular resolver")

    check("PXGenerateIMEIFromAuthoritativeTACs" in identifier and
          "PXGenerateMEIDFromAuthoritativePrefixes" in identifier,
          "canonical telephony generation uses authoritative regional prefixes")
    check('NSArray *usTACs' not in identifier and 'NSArray *usMEIDPrefixes' not in identifier,
          "public IMEI/MEID generators no longer contain generic fallback prefix pools")
    check('if ([productType hasPrefix:@"iPhone"])' in identifier and
          'if (!regulatoryModelNumber.length) return NO;' in identifier,
          "manual iPhone IMEI/MEID writes fail closed without a canonical A-number")
    check('for (NSUInteger i = 0; i < 6; i++)' in identifier,
          "canonical IMEI uses 8-digit TAC + six serial digits + Luhn digit")
    check('@"IMEI", @"IMEI2", @"MEID", @"ICCID", @"IMSI"' in identifier,
          "device profile group clears stale telephony fields before repopulation")
    check("PXPopulateCanonicalCellularIdentity" in identifier and
          "refreshCanonicalCellularIdentityForCurrentProfile" in identifier,
          "profile generation and individual toggles share canonical cellular path")
    check("PXIdentityHasAllowedPrefix(value, tacs)" in identifier and
          "PXIdentityHasAllowedPrefix(value, prefixes)" in identifier,
          "manual IMEI/MEID setters enforce exact regional TAC/prefix data")
    check("PXIdentityHasAllowedPrefix(existingIMEI, tacs)" in identifier and
          "PXIdentityHasAllowedPrefix(existingMEID, prefixes)" in identifier,
          "toggle refresh preserves only identifiers valid for the current regional tuple")
    check('else if ([type isEqualToString:@"IMEI"] || [type isEqualToString:@"MEID"])' in identifier and
          "Never fall back to generic TAC/MEID data" in identifier,
          "IMEI/MEID toggles cannot bypass canonical regional data")
    check('NSString *imei = [self generateIMEI];' not in
          identifier.split("- (void)regenerateAllEnabledIdentifiers", 1)[1].split("#pragma mark - Settings Management", 1)[0],
          "Regenerate All no longer creates generic IMEI before model/baseband selection")
    check("[manager generateIMEI]" not in device_vc and "[manager generateMEID]" not in device_vc,
          "new-profile UI cannot seed generic telephony identity before canonical model selection")
    check("PXValidatedTelephonySnapshotString" in tweak and
          'PXValidatedTelephonySnapshotString(@"IMEI")' in tweak and
          'PXValidatedTelephonySnapshotString(@"MEID")' in tweak,
          "direct MobileGestalt/IORegistry telephony hooks reject stale dependency-invalid values")
    check("entry.requiresCellular" in lockdown_hook and
          "snapshot.validationIssues" in lockdown_hook and
          '@"BasebandFamily"' in lockdown_hook,
          "Lockdown cellular projection is blocked by canonical dependency issues")
    check("PXBasebandFamilyMatchesValidatedSpecs" in lockdown_provider and
          "fixtureFamily.length ? [fixtureFamily isEqualToString:family] : YES" in lockdown_provider,
          "Lockdown provider keeps fixture pins but accepts dependency-gated canonical families for new models")

    check("PXResolvedBasebandSpec" in cellular and
          "does-not-match-canonical-baseband-build" in cellular and
          "does-not-match-canonical-baseband-family" in cellular,
          "cellular validator enforces exact build-specific baseband tuple")
    check("if (regionalValue)" in cellular and
          "requiresRegionalCellular" in cellular and
          "authoritative-cellular-required-for-regulatory-model" in cellular and
          "authoritative-sim-capability-required" in cellular and
          cellular.index("if (hasCellular && !physical && !esim) physical = YES;") >
          cellular.index("Backward-compatible schema used by older database generations"),
          "regional cellular lookup and authoritative SIM capabilities fail closed")
    check("authoritative-baseband-required-for-regulatory-model" in cellular,
          "known cellular fails closed when regional baseband is still unknown")

    check("requiresP1Baseband" in versioned and
          "Known P1 baseband requires known enabled regional cellular capability" in versioned and
          "Known P1 baseband must cover every supported IOSBuild for the model" in versioned,
          "versioned DB publisher validates P1 baseband completeness")

    for token in (
        'specs[@"ProductType"] = model;',
        '@"BasebandFamily"',
        '@"CellularCapable"',
        '@"AdvertisedSIMCount"',
    ):
        check(token in schema, f"runtime DeviceSpec publishes Lockdown cellular field: {token}")

    print("P1 regional cellular/baseband static test: PASS")


if __name__ == "__main__":
    main()
