#!/usr/bin/env python3
"""Export a human-fillable worksheet for P1 regional cellular/baseband data.

This script is read-only. It derives ProductType/A-number ownership and the exact
supported IOSBuild list from the generated canonical databases.

Usage:
  py scripts/export_p1_manual_template.py
  py scripts/export_p1_manual_template.py --output p1_manual_template.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", help="write worksheet JSON to this path instead of stdout")
    args = parser.parse_args()

    model_root = load("iphone_model_db.json")
    build_root = load("ios_build_db.json")
    cellular_root = load("iphone_cellular_db.json")
    baseband_root = load("iphone_baseband_db.json")

    models = {m["productType"]: m for m in model_root.get("models", [])}
    device_to_builds = build_root.get("deviceToBuilds", {})
    cell_records = cellular_root.get("regulatoryModels", {})
    baseband_records = baseband_root.get("regulatoryModels", {})
    baseband_families = baseband_root.get("families", {})

    records = {}
    for product_type, model in sorted(models.items()):
        regional_numbers = model.get("regulatoryModelNumbers", [])
        for number in regional_numbers:
            if number not in cell_records and number not in baseband_records:
                continue
            existing_cell = cell_records.get(number, {"known": False})
            existing_baseband = baseband_records.get(
                number, {"known": False, "productType": product_type}
            )
            builds = device_to_builds.get(product_type, [])
            existing_family = existing_baseband.get("basebandFamily")
            family_record = baseband_families.get(existing_family, {}) if isinstance(existing_family, str) else {}
            family_builds = family_record.get("builds", {}) if isinstance(family_record, dict) else {}
            if not isinstance(family_builds, dict):
                family_builds = {}
            records[number] = {
                "productType": product_type,
                "modelName": model.get("name"),
                "cellular": {
                    "known": bool(existing_cell.get("known", False)),
                    "enabled": existing_cell.get("enabled"),
                    "physicalSIM": existing_cell.get("physicalSIM"),
                    "eSIM": existing_cell.get("eSIM"),
                    "dualSIM": existing_cell.get("dualSIM"),
                    "cdma": existing_cell.get("cdma"),
                    "imeiTACs": existing_cell.get("imeiTACs", []),
                    "meidPrefixes": existing_cell.get("meidPrefixes", []),
                },
                "baseband": {
                    "known": bool(existing_baseband.get("known", False)),
                    "basebandFamily": existing_baseband.get("basebandFamily", ""),
                    "requiredBuilds": {
                        build: family_builds.get(build, "") for build in builds
                    },
                },
            }

    worksheet = {
        "schemaVersion": 1,
        "purpose": "manual P1 regional cellular/baseband worksheet",
        "instructions": [
            "Do not change known=true until every required field is verified.",
            "IMEI TAC entries must be exact 8-digit TACs for this regulatory A-number.",
            "MEID prefixes are required only for a verified cdma=true row.",
            "For baseband known=true, fill every requiredBuilds value for the ProductType.",
            "Do not edit generated iphone_model_db.json/ios_build_db.json by hand.",
        ],
        "databaseVersions": {
            "model": model_root.get("databaseVersion"),
            "hardware": model_root.get("hardwareCatalogVersion"),
            "cellular": cellular_root.get("databaseVersion"),
            "baseband": baseband_root.get("databaseVersion"),
        },
        "records": records,
    }

    text = json.dumps(worksheet, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        output = Path(args.output)
        if not output.is_absolute():
            output = ROOT / output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text, encoding="utf-8", newline="\n")
        print(f"wrote {len(records)} regional records to {output}")
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
