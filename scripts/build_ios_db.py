#!/usr/bin/env python3
"""Convert the embedded legacy layout/Library/IOS.db (SQLite) into the versioned
iOS database JSON files consumed by PXVersionedIOSDatabase (legacy route):
  data/ios_build_db.json    -> {schemaVersion,buildToMeta,deviceToBuilds}
  data/iphone_model_db.json -> {schemaVersion,models:[{productType,name,minIOS,maxIOS,
                                                       variants,hardware...}]}

KMDevices remains authoritative for release range and the exact
board/hwModel -> A-number relation. P0 model-level hardware metadata is merged
from data/iphone_hardware_db.json so runtime code no longer infers RAM/display/
camera/storage from ProductType prefixes. KMDevices `anumber` is published as
RegulatoryModelNumber (Axxxx), not MobileGestalt/IOKit retail ModelNumber.
Every generated variant carries its own regulatoryModelNumbers relation.
"""
import sqlite3, json, re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "layout", "Library", "IOS.db")
DATA = os.path.join(ROOT, "data")
HARDWARE_DB = os.path.join(DATA, "iphone_hardware_db.json")
CELLULAR_DB = os.path.join(DATA, "iphone_cellular_db.json")
BASEBAND_DB = os.path.join(DATA, "iphone_baseband_db.json")

with open(HARDWARE_DB, "r", encoding="utf-8") as f:
    hardware_root = json.load(f)
hardware_models = hardware_root.get("models", {})
if not isinstance(hardware_models, dict):
    raise RuntimeError("iphone_hardware_db.json: models must be an object")

with open(CELLULAR_DB, "r", encoding="utf-8") as f:
    cellular_root = json.load(f)
cellular_records = cellular_root.get("regulatoryModels", {})
if not isinstance(cellular_records, dict):
    raise RuntimeError("iphone_cellular_db.json: regulatoryModels must be an object")
for regulatory_number, spec in cellular_records.items():
    if not isinstance(regulatory_number, str) or not re.fullmatch(r"A\d{4}", regulatory_number):
        raise RuntimeError(f"iphone_cellular_db.json: invalid regulatory key {regulatory_number!r}")
    if not isinstance(spec, dict) or not isinstance(spec.get("known"), bool):
        raise RuntimeError(f"iphone_cellular_db.json: {regulatory_number} must contain boolean known")
    if spec["known"]:
        for key in ("enabled", "physicalSIM", "eSIM", "dualSIM", "cdma"):
            if not isinstance(spec.get(key), bool):
                raise RuntimeError(f"iphone_cellular_db.json: {regulatory_number} known=true requires {key}")
        if spec["enabled"] and not (spec["physicalSIM"] or spec["eSIM"]):
            raise RuntimeError(
                f"iphone_cellular_db.json: {regulatory_number} enabled cellular requires "
                "physicalSIM=true or eSIM=true"
            )
        if not spec["enabled"] and any(
            spec[key] for key in ("physicalSIM", "eSIM", "dualSIM", "cdma")
        ):
            raise RuntimeError(
                f"iphone_cellular_db.json: {regulatory_number} disabled cellular cannot "
                "advertise SIM/CDMA capabilities"
            )
        if spec["enabled"]:
            tacs = spec.get("imeiTACs")
            if not isinstance(tacs, list) or not tacs:
                raise RuntimeError(
                    f"iphone_cellular_db.json: {regulatory_number} enabled cellular requires imeiTACs"
                )
            for tac in tacs:
                if not isinstance(tac, str) or not re.fullmatch(r"\d{8}", tac):
                    raise RuntimeError(
                        f"iphone_cellular_db.json: {regulatory_number} contains invalid 8-digit IMEI TAC {tac!r}"
                    )
        if spec["cdma"]:
            prefixes = spec.get("meidPrefixes")
            if not isinstance(prefixes, list) or not prefixes:
                raise RuntimeError(
                    f"iphone_cellular_db.json: {regulatory_number} cdma=true requires meidPrefixes"
                )
            for prefix in prefixes:
                if not isinstance(prefix, str) or not re.fullmatch(r"[0-9A-Fa-f]{6}", prefix):
                    raise RuntimeError(
                        f"iphone_cellular_db.json: {regulatory_number} contains invalid MEID prefix {prefix!r}"
                    )

with open(BASEBAND_DB, "r", encoding="utf-8") as f:
    baseband_root = json.load(f)
baseband_families = baseband_root.get("families", {})
baseband_records = baseband_root.get("regulatoryModels", {})
if not isinstance(baseband_families, dict) or not isinstance(baseband_records, dict):
    raise RuntimeError("iphone_baseband_db.json: families/regulatoryModels must be objects")
for family, spec in baseband_families.items():
    if not isinstance(family, str) or not family.strip() or not isinstance(spec, dict):
        raise RuntimeError(f"iphone_baseband_db.json: invalid family record {family!r}")
    builds = spec.get("builds")
    if not isinstance(builds, dict):
        raise RuntimeError(f"iphone_baseband_db.json: family {family!r} requires builds object")
    for build, version in builds.items():
        if not isinstance(build, str) or not build.strip() or not isinstance(version, str) or not version.strip():
            raise RuntimeError(f"iphone_baseband_db.json: invalid {family!r} build/version entry")
for regulatory_number, spec in baseband_records.items():
    if not isinstance(regulatory_number, str) or not re.fullmatch(r"A\d{4}", regulatory_number):
        raise RuntimeError(f"iphone_baseband_db.json: invalid regulatory key {regulatory_number!r}")
    if not isinstance(spec, dict) or not isinstance(spec.get("known"), bool):
        raise RuntimeError(f"iphone_baseband_db.json: {regulatory_number} must contain boolean known")
    product_type = spec.get("productType")
    if not isinstance(product_type, str) or not product_type.startswith("iPhone"):
        raise RuntimeError(f"iphone_baseband_db.json: {regulatory_number} requires productType")
    if spec["known"]:
        family = spec.get("basebandFamily")
        if not isinstance(family, str) or family not in baseband_families:
            raise RuntimeError(f"iphone_baseband_db.json: {regulatory_number} known=true requires known basebandFamily")


def sortver_to_ios(s):
    # '016.007.009' -> '16.7.9'
    return ".".join(str(int(x)) for x in s.split("."))


con = sqlite3.connect(DB)
con.text_factory = lambda b: b.decode("utf-8", "replace")
cur = con.cursor()

# ---- buildToMeta from KMOS ----
buildToMeta = {}
kmos = []  # list of (sortVersion, build)
skipped = 0
for version, build, sortv, kver, ktime in cur.execute(
        "SELECT version, OSBuild, sortVersion, kernelversion, kernelversiontime FROM KMOS"):
    if not (version and build and sortv and kver and ktime):
        skipped += 1
        continue
    m = re.search(r"xnu-(\S+)", ktime)
    if not m:
        skipped += 1
        continue
    xnu = m.group(1).split("/")[0]
    darwin = kver.strip()
    kernel_version = f"Darwin Kernel Version {darwin}: {ktime.strip()}"
    if f"Darwin Kernel Version {darwin}" not in kernel_version or f"xnu-{xnu}" not in kernel_version:
        skipped += 1
        continue
    if build in buildToMeta:
        previous = buildToMeta[build]
        raise RuntimeError(
            f"Duplicate KMOS OSBuild {build}: "
            f"existing iOS {previous.get('version')} vs iOS {version.strip()}"
        )
    buildToMeta[build] = {
        "version": version.strip(),
        "darwin": darwin,
        "xnu": xnu,
        "kernel_version": kernel_version,
    }
    kmos.append((sortv, build))

for family, spec in baseband_families.items():
    for build in spec["builds"]:
        if build not in buildToMeta:
            raise RuntimeError(
                f"iphone_baseband_db.json: family {family!r} references unknown IOSBuild {build}"
            )

# ---- devices from KMDevices (iPhone only), aggregate ALL region rows per id ----
# Each identifier has multiple rows (one per region/anumber). We keep the first
# row's name + OS range (identical across rows for a given identifier) and
# preserve each board (internal_name) -> regulatory A-number (anumber) relation.
order = []
agg = {}
for ident, board, anum, gen, dosv, mosv in cur.execute(
        "SELECT identifier, internal_name, anumber, generation, defaultOSV, maxOSV "
        "FROM KMDevices WHERE identifier LIKE 'iPhone%'"):
    if not ident or not mosv:
        continue
    if ident not in agg:
        agg[ident] = {"name": (gen or "").strip(), "dosv": dosv, "mosv": mosv,
                      "variants": {}, "nums": set()}
        order.append(ident)
    e = agg[ident]
    b = (board or "").strip()
    a = (anum or "").strip()
    if b:
        variant_numbers = e["variants"].setdefault(b, set())
        if a:
            variant_numbers.add(a)
    if a:
        e["nums"].add(a)

deviceToBuilds = {}
models = []
missing_hardware = sorted(set(agg).difference(hardware_models))
if missing_hardware:
    raise RuntimeError("P0 hardware catalog missing KMDevices models: " + ", ".join(missing_hardware))
all_regulatory_numbers = set().union(*(entry["nums"] for entry in agg.values())) if agg else set()
orphan_cellular = sorted(set(cellular_records).difference(all_regulatory_numbers))
if orphan_cellular:
    raise RuntimeError("P0 cellular catalog contains unknown A-numbers: " + ", ".join(orphan_cellular))
orphan_baseband = sorted(set(baseband_records).difference(all_regulatory_numbers))
if orphan_baseband:
    raise RuntimeError("P1 baseband catalog contains unknown A-numbers: " + ", ".join(orphan_baseband))

regulatory_owners = {}
for ident, entry in agg.items():
    for number in entry["nums"]:
        regulatory_owners.setdefault(number, set()).add(ident)
duplicate_regulatory_owners = {
    number: sorted(owners)
    for number, owners in regulatory_owners.items()
    if len(owners) > 1
}
if duplicate_regulatory_owners:
    details = "; ".join(
        f"{number} -> {','.join(owners)}"
        for number, owners in sorted(duplicate_regulatory_owners.items())
    )
    raise RuntimeError("KMDevices regulatory A-number has multiple ProductType owners: " + details)

for number, spec in baseband_records.items():
    owners = regulatory_owners.get(number, set())
    expected_owner = spec.get("productType")
    if owners != {expected_owner}:
        raise RuntimeError(
            f"iphone_baseband_db.json: {number} productType={expected_owner!r} "
            f"does not match unique KMDevices owner(s)={sorted(owners)!r}"
        )
    if spec.get("known") is True:
        cell = cellular_records.get(number)
        if not isinstance(cell, dict) or cell.get("known") is not True or cell.get("enabled") is not True:
            raise RuntimeError(
                f"iphone_baseband_db.json: {number} known=true requires cellular known=true enabled=true"
            )

for ident in sorted(agg):
    e = agg[ident]
    dosv, mosv = e["dosv"], e["mosv"]
    builds = sorted({b for (sv, b) in kmos if (not dosv or sv >= dosv) and sv <= mosv})
    name = re.sub(r"\s+", " ", e["name"]).strip()
    model = {"productType": ident, "name": name, "maxIOS": sortver_to_ios(mosv)}
    if dosv:
        model["minIOS"] = sortver_to_ios(dosv)
    variants = []
    for board in sorted(e["variants"]):
        variant_numbers = sorted(e["variants"][board])
        if not variant_numbers:
            raise RuntimeError(f"P0 KMDevices variant {ident}/{board} has no A-number relation")
        variant = {"boardID": board, "hwModel": board, "regulatoryModelNumbers": variant_numbers}
        variants.append(variant)
    if not variants:
        raise RuntimeError(f"P0 KMDevices model {ident} has no hardware variant")
    model["variants"] = variants
    nums = sorted(e["nums"])
    if nums:
        model["regulatoryModelNumbers"] = nums
        regional_cellular = {
            number: cellular_records[number]
            for number in nums
            if number in cellular_records
        }
        if regional_cellular:
            model["cellularByRegulatoryModelNumber"] = regional_cellular

        regional_baseband = {}
        for number in nums:
            spec = baseband_records.get(number)
            if not isinstance(spec, dict):
                continue
            published = {"known": bool(spec.get("known"))}
            if published["known"]:
                family = spec["basebandFamily"]
                family_builds = baseband_families[family]["builds"]
                missing_firmware = [build for build in builds if build not in family_builds]
                if missing_firmware:
                    raise RuntimeError(
                        f"P1 baseband {number}/{family} is incomplete for {ident}; "
                        f"missing supported IOSBuild entries: {', '.join(missing_firmware)}"
                    )
                published["basebandFamily"] = family
                published["builds"] = {
                    build: family_builds[build]
                    for build in builds
                }
            regional_baseband[number] = published
        if regional_baseband:
            model["basebandByRegulatoryModelNumber"] = regional_baseband

    hardware = hardware_models.get(ident)
    if isinstance(hardware, dict):
        for key, value in hardware.items():
            if key != "name":
                model[key] = value
    models.append(model)
    if builds:
        deviceToBuilds[ident] = builds

build_db = {
    "schemaVersion": 1,
    "databaseVersion": "ios-db-from-IOS.db",
    "buildToMeta": buildToMeta,
    "deviceToBuilds": deviceToBuilds,
}
model_db = {
    "schemaVersion": 1,
    "databaseVersion": "ios-db-from-IOS.db",
    "hardwareCatalogVersion": hardware_root.get("databaseVersion", "unknown"),
    "cellularCatalogVersion": cellular_root.get("databaseVersion", "unknown"),
    "basebandCatalogVersion": baseband_root.get("databaseVersion", "unknown"),
    "models": models,
}

os.makedirs(DATA, exist_ok=True)
with open(os.path.join(DATA, "ios_build_db.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(build_db, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
with open(os.path.join(DATA, "iphone_model_db.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(model_db, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")

print(f"builds={len(buildToMeta)} skipped={skipped} models={len(models)} deviceToBuilds={len(deviceToBuilds)}")
i103 = deviceToBuilds.get("iPhone10,3", [])
print(f"iPhone10,3: builds={len(i103)} has19E258={'19E258' in i103}")
print("19E258 meta:", json.dumps(buildToMeta.get("19E258"), ensure_ascii=False))
m103 = next((m for m in models if m["productType"] == "iPhone10,3"), None)
print("iPhone10,3 model:", json.dumps(m103, ensure_ascii=False))
m106 = next((m for m in models if m["productType"] == "iPhone10,6"), None)
print("iPhone10,6 model:", json.dumps(m106, ensure_ascii=False))

dashboard_models = {"iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2"}
missing_dashboard_models = sorted(dashboard_models.difference(deviceToBuilds))
if missing_dashboard_models:
    print("WARNING: dashboard models missing from IOS.db/deviceToBuilds: " + ", ".join(missing_dashboard_models))
    print("         Add KMDevices rows plus KMOS build metadata before enabling these models for coherent fake profiles.")
