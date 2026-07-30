#!/usr/bin/env python3
"""Convert the embedded legacy layout/Library/IOS.db (SQLite) into the versioned
iOS database JSON files consumed by PXVersionedIOSDatabase (legacy route):
  data/ios_build_db.json    -> {schemaVersion,buildToMeta,deviceToBuilds}
  data/iphone_model_db.json -> {schemaVersion,models:[{productType,name,maxIOS,
                                                       variants,modelNumbers}]}

Board IDs / hw.models and model numbers are sourced directly from the
authoritative KMDevices table (internal_name / anumber) so every iPhone gets
coherent variants + modelNumbers. This matches the reader contract in
common/IdentifierManager.m:
  - PXPickHardwareVariantFromModelSpec reads models[].variants[].{boardID,hwModel}
  - PXPickModelNumberFromModelSpec  reads models[].modelNumbers[]
The previous hardcoded BOARD_MAP mirror is dropped: it was incomplete (missing
boards -> <nil> board/hwModel at runtime) and had wrong entries (e.g. it mapped
iPhone10,3 -> D221AP, which is actually the board for iPhone10,6).
"""
import sqlite3, json, re, os

ROOT = r"C:\Users\VanVan\Documents\github\test-x"
DB = os.path.join(ROOT, "layout", "Library", "IOS.db")
DATA = os.path.join(ROOT, "data")


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
    buildToMeta[build] = {
        "version": version.strip(),
        "darwin": darwin,
        "xnu": xnu,
        "kernel_version": kernel_version,
    }
    kmos.append((sortv, build))

# ---- devices from KMDevices (iPhone only), aggregate ALL region rows per id ----
# Each identifier has multiple rows (one per region/anumber). We keep the first
# row's name + OS range (identical across rows for a given identifier) and
# aggregate the distinct boards (internal_name) and model numbers (anumber).
order = []
agg = {}
for ident, board, anum, gen, dosv, mosv in cur.execute(
        "SELECT identifier, internal_name, anumber, generation, defaultOSV, maxOSV "
        "FROM KMDevices WHERE identifier LIKE 'iPhone%'"):
    if not ident or not mosv:
        continue
    if ident not in agg:
        agg[ident] = {"name": (gen or "").strip(), "dosv": dosv, "mosv": mosv,
                      "boards": set(), "nums": set()}
        order.append(ident)
    e = agg[ident]
    b = (board or "").strip()
    if b:
        e["boards"].add(b)
    a = (anum or "").strip()
    if a:
        e["nums"].add(a)

deviceToBuilds = {}
models = []
for ident in sorted(agg):
    e = agg[ident]
    dosv, mosv = e["dosv"], e["mosv"]
    builds = sorted({b for (sv, b) in kmos if (not dosv or sv >= dosv) and sv <= mosv})
    name = re.sub(r"\s+", " ", e["name"]).strip()
    model = {"productType": ident, "name": name, "maxIOS": sortver_to_ios(mosv)}
    variants = [{"boardID": b, "hwModel": b} for b in sorted(e["boards"])]
    if variants:
        model["variants"] = variants
    nums = sorted(e["nums"])
    if nums:
        model["modelNumbers"] = nums
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
    "models": models,
}

os.makedirs(DATA, exist_ok=True)
with open(os.path.join(DATA, "ios_build_db.json"), "w", encoding="utf-8") as f:
    json.dump(build_db, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
with open(os.path.join(DATA, "iphone_model_db.json"), "w", encoding="utf-8") as f:
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
