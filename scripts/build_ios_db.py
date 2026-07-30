#!/usr/bin/env python3
"""Convert the embedded legacy layout/Library/IOS.db (SQLite) into the versioned
iOS database JSON files consumed by PXVersionedIOSDatabase (legacy route):
  data/ios_build_db.json    -> {schemaVersion,buildToMeta,deviceToBuilds}
  data/iphone_model_db.json -> {schemaVersion,models:[{productType,maxIOS,boardID,hwModel}]}

boardID/hwModel are mirrored from common/DeviceModelManager.m so the generated
model DB matches exactly what IdentifierManager writes into device_ids.plist.
"""
import sqlite3, json, re, os

ROOT = r"C:\Users\VanVan\Documents\github\test-x"
DB = os.path.join(ROOT, "layout", "Library", "IOS.db")
DATA = os.path.join(ROOT, "data")

# Mirror of the iPhone Board ID / hw.model map in common/DeviceModelManager.m.
BOARD_MAP = {
    "iPhone10,2": ("D211AP", "D211AP"),
    "iPhone10,3": ("D221AP", "D221AP"),
    "iPhone11,8": ("N841AP", "D331AP"),
    "iPhone11,2": ("D321AP", "D321AP"),
    "iPhone11,6": ("D331AP", "D331AP"),
    "iPhone12,1": ("N104AP", "D421AP"),
    "iPhone12,3": ("D431AP", "D431AP"),
    "iPhone12,5": ("D441AP", "D441AP"),
    "iPhone12,8": ("D79AP", "D79AP"),
    "iPhone13,1": ("D52gAP", "D52gAP"),
    "iPhone13,2": ("D53gAP", "D53gAP"),
    "iPhone13,3": ("D53pAP", "D53pAP"),
    "iPhone13,4": ("D54pAP", "D54pAP"),
    "iPhone14,4": ("D16AP", "D16AP"),
    "iPhone14,5": ("D17AP", "D17AP"),
    "iPhone14,2": ("D63AP", "D63AP"),
    "iPhone14,3": ("D64AP", "D64AP"),
    "iPhone14,6": ("D49AP", "D49AP"),
    "iPhone14,7": ("D27AP", "D27AP"),
    "iPhone14,8": ("D28AP", "D28AP"),
    "iPhone15,2": ("D73AP", "D73AP"),
    "iPhone15,3": ("D74AP", "D74AP"),
    "iPhone15,4": ("D37AP", "D37AP"),
    "iPhone15,5": ("D38AP", "D38AP"),
    "iPhone16,1": ("D83AP", "D83AP"),
    "iPhone16,2": ("D84AP", "D84AP"),
}


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

# ---- devices from KMDevices (iPhone only, dedupe by identifier) ----
devices = {}
for ident, dosv, mosv, gen in cur.execute(
        "SELECT identifier, defaultOSV, maxOSV, generation FROM KMDevices WHERE identifier LIKE 'iPhone%'"):
    if not ident or ident in devices or not mosv:
        continue
    devices[ident] = (dosv, mosv, gen)

deviceToBuilds = {}
models = []
for ident in sorted(devices):
    dosv, mosv, gen = devices[ident]
    builds = sorted({b for (sv, b) in kmos if (not dosv or sv >= dosv) and sv <= mosv})
    board, hwm = BOARD_MAP.get(ident, (None, None))
    model = {"productType": ident, "name": gen or "", "maxIOS": sortver_to_ios(mosv)}
    if board:
        model["boardID"] = board
    if hwm:
        model["hwModel"] = hwm
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
