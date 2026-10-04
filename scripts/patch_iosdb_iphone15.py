#!/usr/bin/env python3
"""Safely add the iPhone 15 family to layout/Library/IOS.db.

The migration is deterministic and transaction-backed. By default it performs a
read-only dry run. Pass --apply to update IOS.db.

Authoritative inputs:
- ProductType / board config / regulatory A-numbers are encoded explicitly below.
- Model-level RAM/display/storage/CPU values are read from data/iphone_hardware_db.json.
- defaultOSV is iOS 17.0 for the iPhone 15 family.
- maxOSV is derived from the highest KMOS.sortVersion already present in IOS.db.

This script deliberately leaves sale_country, battery, bootrom and other unused
legacy columns untouched/NULL rather than inventing data.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
from datetime import datetime
from typing import Any

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_DB = os.path.join(ROOT, "layout", "Library", "IOS.db")
HARDWARE_DB = os.path.join(ROOT, "data", "iphone_hardware_db.json")

TARGETS: dict[str, dict[str, Any]] = {
    "iPhone15,4": {
        "name": "iPhone 15",
        "board": "D37AP",
        "anumbers": ["A2846", "A3089", "A3090", "A3092"],
    },
    "iPhone15,5": {
        "name": "iPhone 15 Plus",
        "board": "D38AP",
        "anumbers": ["A2847", "A3093", "A3094", "A3096"],
    },
    "iPhone16,1": {
        "name": "iPhone 15 Pro",
        "board": "D83AP",
        "anumbers": ["A2848", "A3101", "A3102", "A3104"],
    },
    "iPhone16,2": {
        "name": "iPhone 15 Pro Max",
        "board": "D84AP",
        "anumbers": ["A2849", "A3105", "A3106", "A3108"],
    },
}

DEFAULT_OSV = "017.000.000"

WRITE_COLUMNS = (
    "generation",
    "anumber",
    "identifier",
    "internal_name",
    "defaultOSV",
    "maxOSV",
    "CPU",
    "RAM",
    "storage",
    "sc_pixel_size",
    "sc_pixel_ratio",
    "sc_viewport",
    "sc_pixel",
    "simcount",
)


def storage_text(capacities: list[Any]) -> str:
    values = []
    for value in capacities:
        ivalue = int(value)
        if ivalue <= 0:
            raise ValueError(f"invalid storage capacity: {value!r}")
        values.append(str(ivalue))
    if not values:
        raise ValueError("empty storage capacities")
    return "+".join(values)


def row_values(
    product_type: str,
    target: dict[str, Any],
    anumber: str,
    hardware: dict[str, Any],
    max_osv: str,
) -> dict[str, Any]:
    screen = hardware.get("screen") if isinstance(hardware.get("screen"), dict) else {}
    resolution = screen.get("resolution")
    viewport = screen.get("viewport")
    scale = screen.get("scale")
    ppi = screen.get("ppi")
    if not all([resolution, viewport, scale, ppi]):
        raise RuntimeError(f"{product_type}: incomplete display seed")
    if target["name"] != hardware.get("name"):
        raise RuntimeError(
            f"{product_type}: target name {target['name']!r} != hardware seed {hardware.get('name')!r}"
        )

    return {
        "generation": target["name"],
        "anumber": anumber,
        "identifier": product_type,
        "internal_name": target["board"],
        "defaultOSV": DEFAULT_OSV,
        "maxOSV": max_osv,
        "CPU": hardware.get("cpuProfileKey"),
        "RAM": hardware.get("deviceMemoryGB"),
        "storage": storage_text(hardware.get("storageCapacitiesGB") or []),
        "sc_pixel_size": resolution,
        "sc_pixel_ratio": f"{float(scale):.1f}",
        "sc_viewport": viewport,
        "sc_pixel": int(ppi),
        # This is the existing IOS.db convention for iPhone 13/14-era models:
        # total advertised SIM identities, not physical tray count.
        "simcount": 2,
    }


def fetch_exact(conn: sqlite3.Connection, product_type: str, anumber: str) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT rowid, * FROM KMDevices WHERE identifier=? AND anumber=?",
        (product_type, anumber),
    ).fetchall()


def diff_row(existing: sqlite3.Row, desired: dict[str, Any]) -> dict[str, tuple[Any, Any]]:
    changes = {}
    for key, new_value in desired.items():
        old_value = existing[key]
        if str(old_value) != str(new_value):
            changes[key] = (old_value, new_value)
    return changes


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="update IOS.db")
    parser.add_argument(
        "--backup",
        action="store_true",
        help="when applying, also create a timestamped IOS.db backup next to the database",
    )
    args = parser.parse_args()

    with open(HARDWARE_DB, "r", encoding="utf-8") as f:
        hardware_root = json.load(f)
    hardware_models = hardware_root.get("models", {})

    conn = sqlite3.connect(IOS_DB)
    conn.row_factory = sqlite3.Row
    try:
        table_columns = {row["name"] for row in conn.execute("PRAGMA table_info(KMDevices)")}
        missing_columns = [c for c in WRITE_COLUMNS if c not in table_columns]
        if missing_columns:
            raise RuntimeError("KMDevices missing required columns: " + ", ".join(missing_columns))

        max_osv_row = conn.execute("SELECT MAX(sortVersion) AS v FROM KMOS").fetchone()
        max_osv = max_osv_row["v"] if max_osv_row else None
        if not max_osv or max_osv < DEFAULT_OSV:
            raise RuntimeError(f"KMOS does not cover iOS 17+: max sortVersion={max_osv!r}")

        # Known source-data defect: A2846 is an iPhone 15 A-number but the current
        # DB incorrectly assigns it to iPhone14,7. Refuse to proceed if a
        # different unexpected owner exists.
        a2846_rows = conn.execute(
            "SELECT rowid, identifier, internal_name, generation, CPU, sc_pixel_size "
            "FROM KMDevices WHERE anumber='A2846'"
        ).fetchall()
        if len(a2846_rows) > 1:
            raise RuntimeError("A2846 has multiple source rows; manual reconciliation required")
        if a2846_rows and a2846_rows[0]["identifier"] not in ("iPhone14,7", "iPhone15,4"):
            raise RuntimeError(
                "A2846 belongs to unexpected identifier "
                f"{a2846_rows[0]['identifier']!r}; refusing automatic migration"
            )

        operations: list[tuple[str, str, dict[str, Any], int | None]] = []
        for product_type, target in TARGETS.items():
            hardware = hardware_models.get(product_type)
            if not isinstance(hardware, dict):
                raise RuntimeError(f"{product_type}: missing hardware seed")
            for anumber in target["anumbers"]:
                desired = row_values(product_type, target, anumber, hardware, max_osv)
                exact = fetch_exact(conn, product_type, anumber)
                if len(exact) > 1:
                    raise RuntimeError(f"{product_type}/{anumber}: duplicate exact rows")
                if exact:
                    changes = diff_row(exact[0], desired)
                    if changes:
                        operations.append(("update", f"{product_type}/{anumber}", desired, exact[0]["rowid"]))
                    else:
                        operations.append(("keep", f"{product_type}/{anumber}", desired, exact[0]["rowid"]))
                    continue

                same_a = conn.execute(
                    "SELECT rowid, identifier, anumber FROM KMDevices WHERE anumber=?",
                    (anumber,),
                ).fetchall()
                if same_a:
                    if anumber == "A2846" and len(same_a) == 1 and same_a[0]["identifier"] == "iPhone14,7":
                        operations.append(("move", f"{product_type}/{anumber}", desired, same_a[0]["rowid"]))
                    else:
                        owners = ", ".join(str(row["identifier"]) for row in same_a)
                        raise RuntimeError(f"{anumber}: already owned by {owners}; manual reconciliation required")
                else:
                    operations.append(("insert", f"{product_type}/{anumber}", desired, None))

        print(f"IOS.db: {IOS_DB}")
        print(f"KMOS maxOSV: {max_osv}")
        print(f"mode: {'APPLY' if args.apply else 'DRY RUN'}")
        print()
        for action, key, desired, rowid in operations:
            print(
                f"{action.upper():6s} {key:22s} board={desired['internal_name']} "
                f"CPU={desired['CPU']} RAM={desired['RAM']} storage={desired['storage']} "
                f"display={desired['sc_pixel_size']}@{desired['sc_pixel_ratio']} ppi={desired['sc_pixel']}"
            )

        if not args.apply:
            print()
            print("Dry run only. Re-run with --apply after reviewing the plan.")
            return

        if args.backup:
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            backup_path = IOS_DB + f".pre-iphone15-{stamp}.bak"
            conn.close()
            shutil.copy2(IOS_DB, backup_path)
            print(f"backup: {backup_path}")
            conn = sqlite3.connect(IOS_DB)
            conn.row_factory = sqlite3.Row

        placeholders = ", ".join("?" for _ in WRITE_COLUMNS)
        insert_sql = (
            f"INSERT INTO KMDevices ({', '.join(WRITE_COLUMNS)}) "
            f"VALUES ({placeholders})"
        )
        set_clause = ", ".join(f"{column}=?" for column in WRITE_COLUMNS)
        update_sql = f"UPDATE KMDevices SET {set_clause} WHERE rowid=?"

        with conn:
            for action, key, desired, rowid in operations:
                values = [desired[column] for column in WRITE_COLUMNS]
                if action in ("update", "move"):
                    conn.execute(update_sql, values + [rowid])
                elif action == "insert":
                    conn.execute(insert_sql, values)
                elif action == "keep":
                    pass
                else:
                    raise AssertionError(action)

        # Post-commit invariants.
        for product_type, target in TARGETS.items():
            rows = conn.execute(
                "SELECT internal_name, anumber, generation, defaultOSV, maxOSV, CPU, RAM, storage, "
                "sc_pixel_size, sc_pixel_ratio, sc_viewport, sc_pixel, simcount "
                "FROM KMDevices WHERE identifier=? ORDER BY anumber",
                (product_type,),
            ).fetchall()
            got = {row["anumber"] for row in rows}
            expected = set(target["anumbers"])
            if got != expected:
                raise RuntimeError(
                    f"post-apply {product_type}: expected A-numbers {sorted(expected)}, got {sorted(got)}"
                )
            if {row["internal_name"] for row in rows} != {target["board"]}:
                raise RuntimeError(f"post-apply {product_type}: board mismatch")

        wrong_a2846 = conn.execute(
            "SELECT COUNT(*) FROM KMDevices WHERE identifier='iPhone14,7' AND anumber='A2846'"
        ).fetchone()[0]
        if wrong_a2846:
            raise RuntimeError("post-apply: stale iPhone14,7/A2846 row remains")

        print()
        print("APPLY PASS: iPhone 15-family KMDevices rows are coherent.")
    finally:
        try:
            conn.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
