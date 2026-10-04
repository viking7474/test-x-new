#!/usr/bin/env python3
"""Audit authoritative/manual data required by the P0 canonical iPhone profile.

Read-only by default. It never modifies IOS.db or JSON sources.

Usage:
  py scripts/audit_p0_manual_data.py
  py scripts/audit_p0_manual_data.py --json
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
from typing import Any

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_DB = os.path.join(ROOT, "layout", "Library", "IOS.db")
HARDWARE_DB = os.path.join(ROOT, "data", "iphone_hardware_db.json")
CELLULAR_DB = os.path.join(ROOT, "data", "iphone_cellular_db.json")
BASEBAND_DB = os.path.join(ROOT, "data", "iphone_baseband_db.json")

TARGET_MODELS = ("iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2")
REQUIRED_DEVICE_COLUMNS = (
    "identifier",
    "internal_name",
    "anumber",
    "generation",
    "defaultOSV",
    "maxOSV",
)
REQUIRED_KMOS_COLUMNS = (
    "version",
    "OSBuild",
    "sortVersion",
    "kernelversion",
    "kernelversiontime",
)


def columns(conn: sqlite3.Connection, table: str) -> list[dict[str, Any]]:
    return [
        {
            "cid": row[0],
            "name": row[1],
            "type": row[2],
            "notnull": bool(row[3]),
            "default": row[4],
            "pk": bool(row[5]),
        }
        for row in conn.execute(f"PRAGMA table_info({table})")
    ]


def model_rows(conn: sqlite3.Connection, product_type: str) -> list[dict[str, Any]]:
    cur = conn.execute(
        "SELECT identifier, internal_name, anumber, generation, defaultOSV, maxOSV "
        "FROM KMDevices WHERE identifier=? ORDER BY internal_name, anumber",
        (product_type,),
    )
    return [
        {
            "identifier": row[0],
            "internal_name": row[1],
            "anumber": row[2],
            "generation": row[3],
            "defaultOSV": row[4],
            "maxOSV": row[5],
        }
        for row in cur.fetchall()
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = parser.parse_args()

    with open(HARDWARE_DB, "r", encoding="utf-8") as f:
        hardware_root = json.load(f)
    hardware_models = hardware_root.get("models", {})
    with open(CELLULAR_DB, "r", encoding="utf-8") as f:
        cellular_root = json.load(f)
    cellular_records = cellular_root.get("regulatoryModels", {})
    if not isinstance(cellular_records, dict):
        raise RuntimeError("iphone_cellular_db.json: regulatoryModels must be an object")
    with open(BASEBAND_DB, "r", encoding="utf-8") as f:
        baseband_root = json.load(f)
    baseband_families = baseband_root.get("families", {})
    baseband_records = baseband_root.get("regulatoryModels", {})
    if not isinstance(baseband_families, dict) or not isinstance(baseband_records, dict):
        raise RuntimeError("iphone_baseband_db.json: families/regulatoryModels must be objects")

    conn = sqlite3.connect(IOS_DB)
    try:
        device_columns = columns(conn, "KMDevices")
        kmos_columns = columns(conn, "KMOS")
        device_col_names = {c["name"] for c in device_columns}
        kmos_col_names = {c["name"] for c in kmos_columns}

        missing_required_device_columns = [
            c for c in REQUIRED_DEVICE_COLUMNS if c not in device_col_names
        ]
        missing_required_kmos_columns = [
            c for c in REQUIRED_KMOS_COLUMNS if c not in kmos_col_names
        ]

        targets: dict[str, Any] = {}
        for product_type in TARGET_MODELS:
            hw = hardware_models.get(product_type)
            rows = model_rows(conn, product_type)
            targets[product_type] = {
                "hardwareSeedPresent": isinstance(hw, dict),
                "hardwareName": hw.get("name") if isinstance(hw, dict) else None,
                "cpuProfileKey": hw.get("cpuProfileKey") if isinstance(hw, dict) else None,
                "deviceMemoryGB": hw.get("deviceMemoryGB") if isinstance(hw, dict) else None,
                "storageCapacitiesGB": hw.get("storageCapacitiesGB") if isinstance(hw, dict) else None,
                "kmDevicesRows": rows,
                "kmDevicesPresent": bool(rows),
            }

        kmos_summary = conn.execute(
            "SELECT COUNT(*), MIN(sortVersion), MAX(sortVersion) FROM KMOS"
        ).fetchone()
        duplicate_builds = [
            {
                "OSBuild": build,
                "rows": [
                    {
                        "version": r[0],
                        "sortVersion": r[1],
                        "kernelversion": r[2],
                        "kernelversiontime": r[3],
                    }
                    for r in conn.execute(
                        "SELECT version, sortVersion, kernelversion, kernelversiontime "
                        "FROM KMOS WHERE OSBuild=? ORDER BY sortVersion",
                        (build,),
                    ).fetchall()
                ],
            }
            for (build,) in conn.execute(
                "SELECT OSBuild FROM KMOS WHERE OSBuild IS NOT NULL AND OSBuild<>'' "
                "GROUP BY OSBuild HAVING COUNT(*) > 1 ORDER BY OSBuild"
            ).fetchall()
        ]
        ios17_rows = [
            {
                "version": row[0],
                "OSBuild": row[1],
                "sortVersion": row[2],
                "kernelversion": row[3],
                "kernelversiontime": row[4],
            }
            for row in conn.execute(
                "SELECT version, OSBuild, sortVersion, kernelversion, kernelversiontime "
                "FROM KMOS WHERE sortVersion >= '017.000.000' ORDER BY sortVersion, OSBuild"
            ).fetchall()
        ]

        consistency_fields = (
            "CPU", "RAM", "storage", "sc_pixel_size", "sc_pixel_ratio",
            "sc_viewport", "sc_pixel", "simcount",
        )
        all_device_rows = [
            dict(zip(
                ("identifier", "internal_name", "anumber", "generation", "defaultOSV", "maxOSV") + consistency_fields,
                row,
            ))
            for row in conn.execute(
                "SELECT identifier, internal_name, anumber, generation, defaultOSV, maxOSV, "
                "CPU, RAM, storage, sc_pixel_size, sc_pixel_ratio, sc_viewport, sc_pixel, simcount "
                "FROM KMDevices WHERE identifier LIKE 'iPhone%'"
            ).fetchall()
        ]
        rows_by_model: dict[str, list[dict[str, Any]]] = {}
        for row in all_device_rows:
            rows_by_model.setdefault(row["identifier"], []).append(row)

        source_regulatory_numbers = {
            str(row["anumber"])
            for row in all_device_rows
            if row.get("anumber")
        }
        cellular_orphans = sorted(set(cellular_records).difference(source_regulatory_numbers))
        cellular_unknown = sorted(
            key for key, spec in cellular_records.items()
            if not isinstance(spec, dict) or spec.get("known") is not True
        )
        cellular_known = sorted(
            key for key, spec in cellular_records.items()
            if isinstance(spec, dict) and spec.get("known") is True
        )

        baseband_orphans = sorted(set(baseband_records).difference(source_regulatory_numbers))
        baseband_unknown = sorted(
            key for key, spec in baseband_records.items()
            if not isinstance(spec, dict) or spec.get("known") is not True
        )
        baseband_known = sorted(
            key for key, spec in baseband_records.items()
            if isinstance(spec, dict) and spec.get("known") is True
        )
        baseband_issues: dict[str, Any] = {}
        regulatory_owners: dict[str, set[str]] = {}
        for row in all_device_rows:
            number = row.get("anumber")
            if number:
                regulatory_owners.setdefault(str(number), set()).add(str(row["identifier"]))
        duplicate_regulatory_owners = {
            number: sorted(owners)
            for number, owners in sorted(regulatory_owners.items())
            if len(owners) > 1
        }

        for number, spec in sorted(baseband_records.items()):
            if not isinstance(spec, dict) or spec.get("known") is not True:
                continue
            product_type = spec.get("productType")
            family = spec.get("basebandFamily")
            owners = regulatory_owners.get(number, set())
            family_spec = baseband_families.get(family) if isinstance(family, str) else None
            family_builds = family_spec.get("builds", {}) if isinstance(family_spec, dict) else {}
            model_rows_for_type = rows_by_model.get(product_type, [])
            expected_builds: list[str] = []
            if model_rows_for_type:
                default_osv = model_rows_for_type[0].get("defaultOSV")
                max_osv = model_rows_for_type[0].get("maxOSV")
                if default_osv and max_osv:
                    expected_builds = [
                        str(row[0])
                        for row in conn.execute(
                            "SELECT OSBuild FROM KMOS WHERE sortVersion>=? AND sortVersion<=? "
                            "AND OSBuild IS NOT NULL AND OSBuild<>'' ORDER BY sortVersion, OSBuild",
                            (default_osv, max_osv),
                        ).fetchall()
                    ]
            missing_builds = sorted(set(expected_builds).difference(family_builds))
            cellular_spec = cellular_records.get(number)
            issues = {}
            if owners != {product_type}:
                issues["productTypeOwner"] = {
                    "declared": product_type,
                    "iosDB": sorted(owners),
                }
            if not isinstance(family_spec, dict):
                issues["basebandFamily"] = f"unknown family {family!r}"
            if not isinstance(cellular_spec, dict) or cellular_spec.get("known") is not True or cellular_spec.get("enabled") is not True:
                issues["cellular"] = "baseband known=true requires cellular known=true enabled=true"
            if missing_builds:
                issues["missingBuilds"] = missing_builds
            if issues:
                baseband_issues[number] = issues

        model_outliers: dict[str, Any] = {}
        for identifier, rows in sorted(rows_by_model.items()):
            divergent = {}
            for field in consistency_fields:
                values = sorted({str(row[field]) for row in rows if row[field] is not None})
                if len(values) > 1:
                    divergent[field] = values
            if divergent:
                model_outliers[identifier] = {
                    "divergentFields": divergent,
                    "rows": rows,
                }

        hardware_mismatches: dict[str, Any] = {}
        for identifier, rows in sorted(rows_by_model.items()):
            if identifier in model_outliers or not rows:
                continue
            hardware = hardware_models.get(identifier)
            if not isinstance(hardware, dict):
                continue
            source = rows[0]
            screen = hardware.get("screen") if isinstance(hardware.get("screen"), dict) else {}
            try:
                source_storage = [int(part) for part in str(source["storage"] or "").split("+") if part]
            except ValueError:
                source_storage = []
            expected = {
                "CPU": hardware.get("cpuProfileKey"),
                "RAM": hardware.get("deviceMemoryGB"),
                "storage": hardware.get("storageCapacitiesGB"),
                "sc_pixel_size": screen.get("resolution"),
                "sc_pixel_ratio": screen.get("scale"),
                "sc_viewport": screen.get("viewport"),
                "sc_pixel": screen.get("ppi"),
            }
            actual = {
                "CPU": source.get("CPU"),
                "RAM": source.get("RAM"),
                "storage": source_storage,
                "sc_pixel_size": source.get("sc_pixel_size"),
                "sc_pixel_ratio": float(source["sc_pixel_ratio"]) if source.get("sc_pixel_ratio") is not None else None,
                "sc_viewport": source.get("sc_viewport"),
                "sc_pixel": source.get("sc_pixel"),
            }
            mismatches = {
                field: {"iosDB": actual[field], "hardwareDB": expected[field]}
                for field in expected
                if actual[field] != expected[field]
            }
            if mismatches:
                hardware_mismatches[identifier] = mismatches

        recent_devices = [
            {
                "identifier": row[0],
                "internal_name": row[1],
                "anumber": row[2],
                "generation": row[3],
                "defaultOSV": row[4],
                "maxOSV": row[5],
                "CPU": row[6],
                "RAM": row[7],
                "storage": row[8],
                "sc_pixel_size": row[9],
                "sc_pixel_ratio": row[10],
                "sc_viewport": row[11],
                "sc_pixel": row[12],
                "simcount": row[13],
            }
            for row in conn.execute(
                "SELECT identifier, internal_name, anumber, generation, defaultOSV, maxOSV, "
                "CPU, RAM, storage, sc_pixel_size, sc_pixel_ratio, sc_viewport, sc_pixel, simcount "
                "FROM KMDevices WHERE identifier LIKE 'iPhone%' "
                "ORDER BY CAST(substr(identifier,7,instr(substr(identifier,7),',')-1) AS INTEGER) DESC, "
                "CAST(substr(identifier,instr(identifier,',')+1) AS INTEGER) DESC LIMIT 20"
            ).fetchall()
        ]

        report = {
            "iosDB": IOS_DB,
            "hardwareDB": HARDWARE_DB,
            "requiredSchema": {
                "KMDevices": list(REQUIRED_DEVICE_COLUMNS),
                "KMOS": list(REQUIRED_KMOS_COLUMNS),
            },
            "schema": {
                "KMDevices": device_columns,
                "KMOS": kmos_columns,
            },
            "schemaErrors": {
                "KMDevices": missing_required_device_columns,
                "KMOS": missing_required_kmos_columns,
            },
            "targets": targets,
            "kmos": {
                "count": kmos_summary[0],
                "minSortVersion": kmos_summary[1],
                "maxSortVersion": kmos_summary[2],
                "ios17PlusCount": len(ios17_rows),
                "ios17PlusRows": ios17_rows,
                "duplicateBuilds": duplicate_builds,
            },
            "recentIPhoneRows": recent_devices,
            "modelLevelOutliers": model_outliers,
            "hardwareMismatches": hardware_mismatches,
            "cellular": {
                "catalog": CELLULAR_DB,
                "known": cellular_known,
                "unknown": cellular_unknown,
                "orphanRegulatoryNumbers": cellular_orphans,
            },
            "baseband": {
                "catalog": BASEBAND_DB,
                "families": sorted(baseband_families),
                "known": baseband_known,
                "unknown": baseband_unknown,
                "orphanRegulatoryNumbers": baseband_orphans,
                "issues": baseband_issues,
            },
            "duplicateRegulatoryModelOwners": duplicate_regulatory_owners,
        }

        if args.json:
            print(json.dumps(report, ensure_ascii=False, indent=2))
            return

        print("P0 MANUAL DATA AUDIT")
        print("=" * 72)
        print(f"IOS.db: {IOS_DB}")
        print(f"hardware seed: {HARDWARE_DB}")
        print()
        print("KMDevices columns:")
        for c in device_columns:
            flags = []
            if c["pk"]:
                flags.append("PK")
            if c["notnull"]:
                flags.append("NOT NULL")
            suffix = f" [{' '.join(flags)}]" if flags else ""
            print(f"  - {c['name']}: {c['type']}{suffix}")
        print()
        print("KMOS columns:")
        for c in kmos_columns:
            flags = []
            if c["pk"]:
                flags.append("PK")
            if c["notnull"]:
                flags.append("NOT NULL")
            suffix = f" [{' '.join(flags)}]" if flags else ""
            print(f"  - {c['name']}: {c['type']}{suffix}")

        print()
        print("Target iPhone 15-family rows:")
        for product_type, item in targets.items():
            state = "PRESENT" if item["kmDevicesPresent"] else "MISSING"
            print(
                f"  {product_type:10s} {state:7s} "
                f"name={item['hardwareName']!r} cpu={item['cpuProfileKey']!r} "
                f"ram={item['deviceMemoryGB']!r}GB storage={item['storageCapacitiesGB']!r}"
            )
            for row in item["kmDevicesRows"]:
                print(
                    "    "
                    f"board={row['internal_name']} A={row['anumber']} "
                    f"defaultOSV={row['defaultOSV']} maxOSV={row['maxOSV']}"
                )

        print()
        print("Regulatory A-number ownership:")
        if duplicate_regulatory_owners:
            print("  ERROR duplicate ProductType owners:")
            for number, owners in duplicate_regulatory_owners.items():
                print(f"    {number}: {', '.join(owners)}")
        else:
            print("  duplicate ProductType owners: none")

        print()
        print("Regional cellular catalog:")
        print(f"  file: {CELLULAR_DB}")
        print(f"  verified known=true: {len(cellular_known)}")
        print(f"  pending known=false/invalid: {len(cellular_unknown)}")
        if cellular_unknown:
            print("  pending A-numbers: " + ", ".join(cellular_unknown))
        if cellular_orphans:
            print("  ERROR orphan A-numbers: " + ", ".join(cellular_orphans))
        else:
            print("  orphan A-numbers: none")

        print()
        print("Build-specific baseband catalog:")
        print(f"  file: {BASEBAND_DB}")
        print(f"  declared families: {len(baseband_families)}")
        print(f"  verified known=true: {len(baseband_known)}")
        print(f"  pending known=false/invalid: {len(baseband_unknown)}")
        if baseband_unknown:
            print("  pending A-numbers: " + ", ".join(baseband_unknown))
        if baseband_orphans:
            print("  ERROR orphan A-numbers: " + ", ".join(baseband_orphans))
        else:
            print("  orphan A-numbers: none")
        if baseband_issues:
            print("  ERROR known=true coherence issues:")
            for number, issues in baseband_issues.items():
                print(f"    {number}: {issues}")
        else:
            print("  known=true coherence issues: none")

        print()
        print(
            "KMOS: "
            f"rows={report['kmos']['count']} "
            f"range={report['kmos']['minSortVersion']}..{report['kmos']['maxSortVersion']} "
            f"iOS17+ rows={report['kmos']['ios17PlusCount']}"
        )
        if duplicate_builds:
            print("Duplicate OSBuild rows:")
            for item in duplicate_builds:
                print(f"  {item['OSBuild']}:")
                for row in item["rows"]:
                    print(
                        f"    iOS {row['version']} sort={row['sortVersion']} "
                        f"Darwin={row['kernelversion']} kernel={row['kernelversiontime']}"
                    )
        else:
            print("Duplicate OSBuild rows: none")
        if ios17_rows:
            for row in ios17_rows[-12:]:
                print(
                    f"  {row['version']:8s} {row['OSBuild']:8s} "
                    f"{row['sortVersion']:11s} Darwin={row['kernelversion']}"
                )

        print()
        print("Model-level KMDevices outliers (same ProductType, conflicting hardware fields):")
        if not model_outliers:
            print("  none")
        else:
            for identifier, item in model_outliers.items():
                print(f"  {identifier}: {item['divergentFields']}")
                for row in item["rows"]:
                    print(
                        "    "
                        f"board={row['internal_name']!s:8s} A={row['anumber']!s:6s} "
                        f"CPU={row['CPU']!r} RAM={row['RAM']!r} storage={row['storage']!r} "
                        f"pixel={row['sc_pixel_size']!r} ratio={row['sc_pixel_ratio']!r} "
                        f"viewport={row['sc_viewport']!r} ppi={row['sc_pixel']!r} sim={row['simcount']!r}"
                    )

        print()
        print("IOS.db consensus vs iphone_hardware_db mismatches:")
        if not hardware_mismatches:
            print("  none")
        else:
            for identifier, mismatches in hardware_mismatches.items():
                print(f"  {identifier}: {mismatches}")

        print()
        print("Recent KMDevices hardware rows:")
        for row in recent_devices:
            print(
                f"  {row['identifier']:10s} board={row['internal_name']!s:8s} A={row['anumber']!s:6s} "
                f"CPU={row['CPU']!r} RAM={row['RAM']!r} storage={row['storage']!r} "
                f"pixel={row['sc_pixel_size']!r} ratio={row['sc_pixel_ratio']!r} "
                f"viewport={row['sc_viewport']!r} ppi={row['sc_pixel']!r} sim={row['simcount']!r}"
            )

        print()
        print("Manual KMDevices fields required by build_ios_db.py:")
        print("  identifier       e.g. iPhone16,2")
        print("  internal_name    exact Apple board/hw model, e.g. DxxAP -- DO NOT GUESS")
        print("  anumber          regulatory Axxxx for that exact board/region row")
        print("  generation       marketing name")
        print("  defaultOSV       zero-padded sortable release version, e.g. 017.000.000")
        print("  maxOSV           highest supported sortable version represented by your DB")
        print()
        print("Manual KMOS fields required for each new OS build:")
        print("  version, OSBuild, sortVersion, kernelversion, kernelversiontime")
        print("  kernelversiontime must contain an xnu-... token; the generator derives XNU from it.")
        print()
        print("Important:")
        print("  - Add one KMDevices row per real board/A-number relation.")
        print("  - Do not place retail MQ... part numbers in anumber; anumber is Axxxx.")
        print("  - Do not invent kernel/XNU/baseband values.")
        print("  - Re-run build_ios_db.py and all P0 tests after editing IOS.db.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
