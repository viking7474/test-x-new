#!/usr/bin/env python3
"""Validate/import the human-filled P1 cellular/baseband worksheet.

Dry-run by default. The importer never edits IOS.db or generated JSON directly.
With --apply it updates only:
  data/iphone_cellular_db.json
  data/iphone_baseband_db.json

The exact ProductType/A-number ownership, catalog versions, and required IOSBuild set are verified
against the currently generated canonical databases before any write.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
CELLULAR_PATH = DATA / "iphone_cellular_db.json"
BASEBAND_PATH = DATA / "iphone_baseband_db.json"
MODEL_PATH = DATA / "iphone_model_db.json"
BUILD_PATH = DATA / "ios_build_db.json"

A_NUMBER_RE = re.compile(r"A\d{4}")
TAC_RE = re.compile(r"\d{8}")
MEID_PREFIX_RE = re.compile(r"[0-9A-Fa-f]{6}")
BASEBAND_RE = re.compile(r"[0-9A-Za-z][0-9A-Za-z._-]{0,63}")


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def atomic_write_json(path: Path, payload: Any) -> None:
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def require_bool(record: dict[str, Any], key: str, context: str) -> bool:
    value = record.get(key)
    if not isinstance(value, bool):
        raise RuntimeError(f"{context}: {key} must be boolean")
    return value


def validate_string_list(
    value: Any,
    pattern: re.Pattern[str],
    context: str,
    field: str,
) -> list[str]:
    if not isinstance(value, list) or not value:
        raise RuntimeError(f"{context}: {field} must be a non-empty list")
    result: list[str] = []
    for item in value:
        if not isinstance(item, str) or not pattern.fullmatch(item):
            raise RuntimeError(f"{context}: invalid {field} entry {item!r}")
        normalized = item.upper() if field == "meidPrefixes" else item
        if normalized not in result:
            result.append(normalized)
    return result


def canonical_ownership(model_root: dict[str, Any]) -> dict[str, str]:
    owners: dict[str, str] = {}
    for model in model_root.get("models", []):
        if not isinstance(model, dict):
            continue
        product_type = model.get("productType")
        if not isinstance(product_type, str):
            continue
        for number in model.get("regulatoryModelNumbers", []):
            if not isinstance(number, str):
                continue
            if number in owners and owners[number] != product_type:
                raise RuntimeError(
                    f"canonical model DB has duplicate A-number owner: {number} -> "
                    f"{owners[number]} / {product_type}"
                )
            owners[number] = product_type
    return owners


def validate_database_versions(
    worksheet: dict[str, Any],
    model_root: dict[str, Any],
    cellular_root: dict[str, Any],
    baseband_root: dict[str, Any],
    allow_stale: bool,
) -> None:
    worksheet_versions = worksheet.get("databaseVersions")
    if not isinstance(worksheet_versions, dict):
        raise RuntimeError("worksheet: databaseVersions object is required")

    current_versions = {
        "model": model_root.get("databaseVersion"),
        "hardware": model_root.get("hardwareCatalogVersion"),
        "cellular": cellular_root.get("databaseVersion"),
        "baseband": baseband_root.get("databaseVersion"),
    }
    mismatches = {
        key: (worksheet_versions.get(key), current)
        for key, current in current_versions.items()
        if worksheet_versions.get(key) != current
    }
    if not mismatches:
        return

    details = "; ".join(
        f"{key}: worksheet={old!r} current={current!r}"
        for key, (old, current) in sorted(mismatches.items())
    )
    if not allow_stale:
        raise RuntimeError(
            "worksheet databaseVersions do not match the current catalogs; "
            f"export a new worksheet ({details})"
        )
    print(f"WARNING: accepting stale worksheet due to --allow-stale ({details})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("worksheet", help="worksheet JSON produced by export_p1_manual_template.py")
    parser.add_argument("--apply", action="store_true", help="write validated source catalogs")
    parser.add_argument(
        "--allow-stale",
        action="store_true",
        help="accept mismatched catalog versions (expert recovery only)",
    )
    args = parser.parse_args()

    worksheet_path = Path(args.worksheet)
    if not worksheet_path.is_absolute():
        worksheet_path = ROOT / worksheet_path

    worksheet = load(worksheet_path)
    if worksheet.get("schemaVersion") != 1 or not isinstance(worksheet.get("records"), dict):
        raise RuntimeError("worksheet: expected schemaVersion=1 and records object")

    model_root = load(MODEL_PATH)
    build_root = load(BUILD_PATH)
    cellular_root = load(CELLULAR_PATH)
    baseband_root = load(BASEBAND_PATH)

    validate_database_versions(
        worksheet,
        model_root,
        cellular_root,
        baseband_root,
        args.allow_stale,
    )

    owners = canonical_ownership(model_root)
    device_to_builds = build_root.get("deviceToBuilds", {})
    if not isinstance(device_to_builds, dict):
        raise RuntimeError("ios_build_db.json: deviceToBuilds must be an object")

    current_cellular = cellular_root.get("regulatoryModels", {})
    current_baseband = baseband_root.get("regulatoryModels", {})
    if not isinstance(current_cellular, dict) or not isinstance(current_baseband, dict):
        raise RuntimeError("source cellular/baseband catalogs are malformed")

    next_cellular = dict(current_cellular)
    next_baseband = dict(current_baseband)
    merged_families: dict[str, dict[str, Any]] = {}
    current_families = baseband_root.get("families", {})
    if not isinstance(current_families, dict):
        raise RuntimeError("iphone_baseband_db.json: families must be an object")
    for family, spec in current_families.items():
        if isinstance(family, str) and isinstance(spec, dict):
            merged_families[family] = {
                "builds": dict(spec.get("builds", {})) if isinstance(spec.get("builds"), dict) else {}
            }

    changes: list[str] = []
    records = worksheet["records"]

    for number, record in sorted(records.items()):
        context = f"worksheet {number}"
        if not isinstance(number, str) or not A_NUMBER_RE.fullmatch(number):
            raise RuntimeError(f"worksheet: invalid regulatory key {number!r}")
        if not isinstance(record, dict):
            raise RuntimeError(f"{context}: record must be an object")

        product_type = record.get("productType")
        if not isinstance(product_type, str) or owners.get(number) != product_type:
            raise RuntimeError(
                f"{context}: productType={product_type!r} does not match canonical owner "
                f"{owners.get(number)!r}"
            )

        cell = record.get("cellular")
        baseband = record.get("baseband")
        if not isinstance(cell, dict) or not isinstance(baseband, dict):
            raise RuntimeError(f"{context}: cellular/baseband must be objects")

        cell_known = require_bool(cell, "known", context + " cellular")
        if not cell_known:
            # Preserve verified collection evidence (notably TACs) while keeping
            # runtime publication fail-closed. known=false remains the gate.
            new_cell = {"known": False}
            for key in ("enabled", "physicalSIM", "eSIM", "dualSIM", "cdma"):
                value = cell.get(key)
                if value is not None:
                    if not isinstance(value, bool):
                        raise RuntimeError(f"{context} cellular: {key} must be boolean or null")
                    new_cell[key] = value
            tacs = cell.get("imeiTACs")
            if tacs is not None:
                if not isinstance(tacs, list):
                    raise RuntimeError(f"{context} cellular: imeiTACs must be a list")
                new_cell["imeiTACs"] = (
                    validate_string_list(tacs, TAC_RE, context + " cellular", "imeiTACs")
                    if tacs else []
                )
            prefixes = cell.get("meidPrefixes")
            if prefixes is not None:
                if not isinstance(prefixes, list):
                    raise RuntimeError(f"{context} cellular: meidPrefixes must be a list")
                new_cell["meidPrefixes"] = (
                    validate_string_list(prefixes, MEID_PREFIX_RE, context + " cellular", "meidPrefixes")
                    if prefixes else []
                )
        else:
            enabled = require_bool(cell, "enabled", context + " cellular")
            physical = require_bool(cell, "physicalSIM", context + " cellular")
            esim = require_bool(cell, "eSIM", context + " cellular")
            dual = require_bool(cell, "dualSIM", context + " cellular")
            cdma = require_bool(cell, "cdma", context + " cellular")
            if enabled and not (physical or esim):
                raise RuntimeError(
                    f"{context}: enabled cellular requires physicalSIM=true or eSIM=true"
                )
            if not enabled and (physical or esim or dual or cdma):
                raise RuntimeError(
                    f"{context}: disabled cellular cannot advertise SIM/CDMA capabilities"
                )
            new_cell = {
                "known": True,
                "enabled": enabled,
                "physicalSIM": physical,
                "eSIM": esim,
                "dualSIM": dual,
                "cdma": cdma,
            }
            if enabled:
                new_cell["imeiTACs"] = validate_string_list(
                    cell.get("imeiTACs"), TAC_RE, context + " cellular", "imeiTACs"
                )
            prefixes = cell.get("meidPrefixes")
            if cdma:
                new_cell["meidPrefixes"] = validate_string_list(
                    prefixes, MEID_PREFIX_RE, context + " cellular", "meidPrefixes"
                )
            elif prefixes is not None:
                if prefixes != []:
                    raise RuntimeError(
                        f"{context}: cdma=false requires meidPrefixes to be empty when present"
                    )
                new_cell["meidPrefixes"] = []

        bb_known = require_bool(baseband, "known", context + " baseband")
        if not bb_known:
            new_baseband = {"known": False, "productType": product_type}
        else:
            if not (cell_known and new_cell.get("enabled") is True):
                raise RuntimeError(
                    f"{context}: baseband known=true requires cellular known=true enabled=true"
                )
            family = baseband.get("basebandFamily")
            if not isinstance(family, str) or not family.strip():
                raise RuntimeError(f"{context}: basebandFamily is required")
            family = family.strip()
            required = baseband.get("requiredBuilds")
            if not isinstance(required, dict):
                raise RuntimeError(f"{context}: requiredBuilds must be an object")

            expected_builds = list(device_to_builds.get(product_type, []))
            if set(required) != set(expected_builds):
                missing = sorted(set(expected_builds).difference(required))
                extra = sorted(set(required).difference(expected_builds))
                raise RuntimeError(
                    f"{context}: requiredBuilds must exactly match canonical IOSBuild set; "
                    f"missing={missing} extra={extra}"
                )

            normalized_builds: dict[str, str] = {}
            for build in expected_builds:
                version = required.get(build)
                if not isinstance(version, str) or not BASEBAND_RE.fullmatch(version.strip()):
                    raise RuntimeError(
                        f"{context}: {build} requires verified BasebandVersion, got {version!r}"
                    )
                normalized_builds[build] = version.strip()

            family_entry = merged_families.setdefault(family, {"builds": {}})
            family_builds = family_entry["builds"]
            for build, version in normalized_builds.items():
                previous = family_builds.get(build)
                if previous is not None and previous != version:
                    raise RuntimeError(
                        f"{context}: baseband family {family!r} conflicts for {build}: "
                        f"{previous!r} vs {version!r}"
                    )
                family_builds[build] = version

            new_baseband = {
                "known": True,
                "productType": product_type,
                "basebandFamily": family,
            }

        if next_cellular.get(number) != new_cell:
            changes.append(f"cellular {number}")
            next_cellular[number] = new_cell
        if next_baseband.get(number) != new_baseband:
            changes.append(f"baseband {number}")
            next_baseband[number] = new_baseband

    # Never let a source catalog silently carry A-numbers that no longer have a
    # canonical ProductType owner.
    for source_name, mapping in (
        ("cellular", next_cellular),
        ("baseband", next_baseband),
    ):
        orphan = sorted(set(mapping).difference(owners))
        if orphan:
            raise RuntimeError(f"{source_name} catalog contains orphan A-numbers: {orphan}")

    next_cellular_root = dict(cellular_root)
    next_cellular_root["regulatoryModels"] = {
        key: next_cellular[key] for key in sorted(next_cellular)
    }

    # Keep only families actually referenced by known=true regulatory rows.
    used_families = {
        spec["basebandFamily"]
        for spec in next_baseband.values()
        if isinstance(spec, dict) and spec.get("known") is True and isinstance(spec.get("basebandFamily"), str)
    }
    next_baseband_root = dict(baseband_root)
    next_baseband_root["families"] = {
        family: merged_families[family] for family in sorted(used_families)
    }
    next_baseband_root["regulatoryModels"] = {
        key: next_baseband[key] for key in sorted(next_baseband)
    }

    known_cell = sum(
        1 for spec in next_cellular.values()
        if isinstance(spec, dict) and spec.get("known") is True
    )
    known_baseband = sum(
        1 for spec in next_baseband.values()
        if isinstance(spec, dict) and spec.get("known") is True
    )
    print(f"worksheet: {worksheet_path}")
    print(f"records validated: {len(records)}")
    print(f"known cellular rows after import: {known_cell}")
    print(f"known baseband rows after import: {known_baseband}")
    print(f"changes: {len(changes)}")
    for item in changes:
        print(f"  - {item}")

    if not args.apply:
        print("DRY RUN PASS: source catalogs were not modified.")
        return

    atomic_write_json(CELLULAR_PATH, next_cellular_root)
    atomic_write_json(BASEBAND_PATH, next_baseband_root)
    print(f"APPLY PASS: wrote {CELLULAR_PATH}")
    print(f"APPLY PASS: wrote {BASEBAND_PATH}")
    print("Next: py scripts\\build_ios_db.py")


if __name__ == "__main__":
    main()
