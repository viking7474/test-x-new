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
    }
    all_expected = set().union(*expected.values())

    check(model_root.get("basebandCatalogVersion") == baseband_root.get("databaseVersion"),
          "generated model DB declares exact P1 baseband catalog version")
    check(set(baseband_root.get("regulatoryModels", {})) == all_expected,
          "baseband source exposes exactly the iPhone 15-family regional slots")
    check(set(cell_root.get("regulatoryModels", {})) == all_expected,
          "cellular and baseband sources cover the same iPhone 15-family A-numbers")

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
        check(all(int(build_root["buildToMeta"][build]["version"].split(".", 1)[0]) >= 17
                  for build in dtb[product_type]),
              f"{product_type} baseband-supported model range has no pre-iOS-17 build")

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
