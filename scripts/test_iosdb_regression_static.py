#!/usr/bin/env python3
"""Static regression proof for the versioned iOS database fix.

Replicates the runtime coherence + dependency validation logic from
  common/PXVersionedIOSDatabase.m  (PXIOSDBValidateCoherentRoots)
  common/PXIdentityDependencyValidator.m (PXValidateIdentityDependencies)
  common/IOSBuildDB.m (randomMetaForDevice candidate filter)
against the generated data/ios_build_db.json + data/iphone_model_db.json,
for the CPU Dash profile D06 (iPhone X / iPhone10,3 / 15.4.1 / 19E258 / D221AP).
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("  FAIL:", msg)
    else:
        print("  ok  :", msg)


build_root = json.load(open(os.path.join(DATA, "ios_build_db.json"), encoding="utf-8"))
model_root = json.load(open(os.path.join(DATA, "iphone_model_db.json"), encoding="utf-8"))

btm = build_root.get("buildToMeta")
dtb = build_root.get("deviceToBuilds")
models = model_root.get("models")

print("== schemaVersion / structure ==")
check(build_root.get("schemaVersion") == 1, "ios_build_db schemaVersion == 1")
check(model_root.get("schemaVersion") == 1, "iphone_model_db schemaVersion == 1")
check(isinstance(btm, dict) and btm, "buildToMeta present & non-empty")
check(isinstance(dtb, dict) and dtb, "deviceToBuilds present & non-empty")
check(isinstance(models, list) and models, "models present & non-empty")

# ---- PXIOSDBValidateCoherentRoots ----
print("== coherent roots ==")
productTypes = set()
coherent = True
for m in models:
    if not isinstance(m, dict):
        coherent = False; break
    pt = m.get("productType")
    if not (isinstance(pt, str) and pt.startswith("iPhone")) or pt in productTypes:
        coherent = False; break
    productTypes.add(pt)
check(coherent, "models rows valid & unique productType (prefix iPhone)")

dangling = []
for pt, builds in dtb.items():
    if not (isinstance(builds, list) and builds) or pt not in productTypes:
        dangling.append(f"device {pt}: empty builds or unknown productType")
        continue
    for b in builds:
        meta = btm.get(b) if isinstance(b, str) else None
        if not (isinstance(meta, dict) and all(isinstance(meta.get(k), str)
                for k in ("version", "darwin", "xnu", "kernel_version"))):
            dangling.append(f"device {pt}: dangling/malformed build {b}")
check(not dangling, "deviceToBuilds references resolve to complete meta")
for d in dangling[:10]:
    print("     -", d)

# ---- IOSBuildDB kernel guardrail for every meta ----
print("== kernel guardrail (IOSBuildDB) ==")
bad_kernel = []
for b, meta in btm.items():
    darwin, xnu, kern = meta.get("darwin"), meta.get("xnu"), meta.get("kernel_version")
    if f"Darwin Kernel Version {darwin}" not in kern or f"xnu-{xnu}" not in kern:
        bad_kernel.append(b)
check(not bad_kernel, "every meta.kernel_version contains darwin+xnu needles")
check(btm.get("22D72", {}).get("version") == "18.3.1",
      "iOS 18.3.1 resolves to unique build 22D72")

iphone15_expectations = {
    "iPhone15,4": "D37AP",
    "iPhone15,5": "D38AP",
    "iPhone16,1": "D83AP",
    "iPhone16,2": "D84AP",
}
for product_type, board in iphone15_expectations.items():
    row = next((m for m in models if m.get("productType") == product_type), {})
    builds = dtb.get(product_type, [])
    check(bool(row), f"{product_type} present in canonical model DB")
    check(row.get("minIOS") == "17.0.0", f"{product_type} minIOS == 17.0.0")
    check(row.get("variants") and row["variants"][0].get("boardID") == board,
          f"{product_type} uses board {board}")
    check("21A329" not in builds and "21A350" in builds,
          f"{product_type} excludes unrelated 21A329 and includes verified iPhone-15 build 21A350")
    check("22D72" in builds, f"{product_type} includes iOS 18.3.1 build 22D72")
    check(all(int(re.match(r"\d+", btm[b]["version"]).group(0)) >= 17 for b in builds),
          f"{product_type} has no pre-iOS-17 builds")

# ---- Simulate IdentifierManager filling profile D06 from the DB ----
print("== dependency validation for profile D06 (iPhone10,3) ==")
PT = "iPhone10,3"
BUILD = "19E258"
check(PT in productTypes, f"{PT} present in models")
check(BUILD in btm, f"{BUILD} present in buildToMeta")
check(BUILD in dtb.get(PT, []), f"{BUILD} listed in deviceToBuilds[{PT}]")

meta = btm.get(BUILD, {})
model = next((m for m in models if m.get("productType") == PT), {})
# IdentifierManager copies meta fields verbatim into device_ids.plist and picks a
# hardware variant via PXPickHardwareVariantFromModelSpec (variants[] first, then
# the flat boardID/hwModel fallback).
variants = model.get("variants") if isinstance(model.get("variants"), list) else []
picked = variants[0] if variants else {}
boardID = picked.get("boardID") or model.get("boardID")
hwModel = picked.get("hwModel") or model.get("hwModel")
profile = {
    "DeviceModel": PT,
    "IOSVersion": meta.get("version"),
    "IOSBuild": BUILD,
    "Darwin": meta.get("darwin"),
    "XNU": meta.get("xnu"),
    "KernelVersion": meta.get("kernel_version"),
    "BoardID": boardID,
    "HwModel": hwModel,
}
print("  profile:", json.dumps(profile, ensure_ascii=False))

# Assert the expected D06 target values are what the DB yields.
# iPhone10,3 (iPhone X global) board is D22AP per the authoritative IOS.db
# (D221AP is iPhone10,6). The reader picks this from models[].variants[].
check(profile["IOSVersion"] == "15.4.1", "IOSVersion resolves to 15.4.1")
check(profile["Darwin"] == "21.4.0", "Darwin resolves to 21.4.0")
check(profile["XNU"] == "8020.102.3~1", "XNU resolves to 8020.102.3~1")
check(profile["BoardID"] == "D22AP" and profile["HwModel"] == "D22AP", "Board/HwModel == D22AP")
check(isinstance(model.get("regulatoryModelNumbers"), list) and model.get("regulatoryModelNumbers"),
      "iPhone10,3 has regulatory A-number data")


def variant_matches(model, boardID, hwModel):
    variants = model.get("variants")
    if isinstance(variants, list) and variants:
        for r in variants:
            if not isinstance(r, dict):
                continue
            bm = (boardID is None) or (boardID == r.get("boardID"))
            hm = (hwModel is None) or (hwModel == r.get("hwModel"))
            if bm and hm:
                return True
        return False
    bm = (boardID is None) or (boardID == model.get("boardID"))
    hm = (hwModel is None) or (hwModel == model.get("hwModel"))
    return bm and hm


# Replica of PXValidateIdentityDependencies (DB-related issues only).
issues = {}
software_keys = ["IOSVersion", "IOSBuild", "Darwin", "XNU", "KernelVersion"]
software_present = sum(1 for k in software_keys if (profile.get(k) or "").strip())
if software_present and software_present != len(software_keys):
    issues["softwareTuple"] = "incomplete-version-build-kernel-tuple"
elif software_present == len(software_keys):
    meta2 = btm.get(profile["IOSBuild"])
    if not meta2:
        issues["IOSBuild"] = "build-not-in-versioned-database"
    else:
        for pk, mk in (("IOSVersion", "version"), ("Darwin", "darwin"), ("XNU", "xnu"), ("KernelVersion", "kernel_version")):
            if (profile.get(pk) or "").strip() != (meta2.get(mk) or "").strip():
                issues[pk] = f"does-not-match-build-{mk}"
        kern = (profile.get("KernelVersion") or "")
        if f"Darwin Kernel Version {profile.get('Darwin','')}" not in kern or f"xnu-{profile.get('XNU','')}" not in kern:
            issues["KernelVersion"] = "kernel-banner-does-not-contain-darwin-xnu"

model_lookup = {m["productType"]: m for m in models}
if profile["DeviceModel"] and profile["DeviceModel"] not in model_lookup:
    issues["DeviceModel"] = "model-not-in-versioned-database"
if profile["DeviceModel"] and software_present == len(software_keys):
    allowed = dtb.get(profile["DeviceModel"], [])
    if profile["IOSBuild"] not in allowed:
        issues["modelBuild"] = "build-not-supported-by-model"
mdl = model_lookup.get(profile["DeviceModel"])
if mdl and (profile.get("BoardID") or profile.get("HwModel")):
    if not variant_matches(mdl, profile.get("BoardID"), profile.get("HwModel")):
        issues["hardwareVariant"] = "board-or-hwmodel-does-not-match-product-type"

print("  validator issues:", json.dumps(issues, ensure_ascii=False))
check(not issues, "PXValidateIdentityDependencies -> valid (no DB issues)")

# ---- IOSBuildDB.randomMetaForDevice candidate range check ----
print("== randomMetaForDevice candidate range (min 13.0 max 16.7.9) ==")


def ver_tuple(v):
    return tuple(int(x) for x in re.findall(r"\d+", v))


def in_range(v, lo, hi):
    return ver_tuple(lo) <= ver_tuple(v) <= ver_tuple(hi)


cands = []
for b in dtb.get(PT, []):
    mv = btm[b]["version"]
    if in_range(mv, "13.0", model.get("maxIOS", "0")):
        cands.append(b)
check(BUILD in cands, f"{BUILD} is a selectable candidate for {PT} within [13.0..{model.get('maxIOS')}]")
print(f"  candidate builds for {PT}: {len(cands)}")

# ---- Dashboard Reset Data must preserve the same atomic software tuple ----
print("== dashboard iOS tuple publication ==")
view_controller = open(os.path.join(ROOT, "TLinkIOSViewController.m"), encoding="utf-8").read()
check('#import "IOSBuildDB.h"' in view_controller,
      "dashboard uses IOSBuildDB instead of a standalone IOSVersion string")
check('randomMetaForDevice:iosProductType' in view_controller and
      'preview[@"IOSBuild"] = build;' in view_controller and
      'preview[@"Darwin"] = darwin;' in view_controller and
      'preview[@"XNU"] = xnu;' in view_controller and
      'preview[@"KernelVersion"] = kernel;' in view_controller,
      "fake preview publishes version/build/darwin/xnu/kernel as one tuple")
apply_tail = view_controller.split('applyFakePreviewToCurrentProfile:', 1)[1]
check('@"IOSVersion", @"IOSBuild", @"Darwin", @"XNU", @"KernelVersion"' in apply_tail,
      "Reset Data writes the complete iOS tuple into device_ids.plist")
check('Refusing partial iOS override' in apply_tail and
      'return NO;' in apply_tail and
      'GenerationCounter' in apply_tail,
      "Reset Data fails closed on partial/mismatched tuple overrides")
check('coherentChoices' in view_controller and
      'Excluding incompatible fake model' in view_controller and
      'No coherent model/iOS candidates' in view_controller,
      "Dashboard filters random models by actual IOSBuildDB compatibility")
check('randomizeStorageCapacityForDeviceModel:model' in apply_tail,
      "final storage capacity is regenerated from the committed model")
check('availableVersions' in view_controller,
      "Dashboard iOS range UI is sourced from IOSBuildDB instead of a stale hard-coded list")

builder = open(os.path.join(ROOT, "scripts", "build_ios_db.py"), encoding="utf-8").read()
versioned_db = open(os.path.join(ROOT, "common", "PXVersionedIOSDatabase.m"), encoding="utf-8").read()
check('model["minIOS"] = sortver_to_ios(dosv)' in builder and
      'os.path.dirname(os.path.dirname(os.path.abspath(__file__)))' in builder,
      "iOS DB generator publishes minIOS and is workspace-relative")
check('modelsByProductType' in versioned_db and
      'model/version mapping outside the model iOS range' in versioned_db,
      "versioned DB rejects deviceToBuilds entries outside model min/max iOS")

print()
if failures:
    print(f"RESULT: FAILED ({len(failures)} check(s))")
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
