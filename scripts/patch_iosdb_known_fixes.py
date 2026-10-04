#!/usr/bin/env python3
"""Apply narrowly-scoped, verified IOS.db integrity fixes.

Dry-run by default. Pass --apply to modify layout/Library/IOS.db.

Current guarded fixes:
1. iOS 18.3.1 OSBuild: 22C152 -> 22D72.
2. iPhone14,5 regional A-number: erroneous A2626 -> A2631.
"""
from __future__ import annotations

import argparse
import os
import sqlite3
from typing import Callable

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_DB = os.path.join(ROOT, "layout", "Library", "IOS.db")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    conn = sqlite3.connect(IOS_DB)
    conn.row_factory = sqlite3.Row
    operations: list[tuple[str, Callable[[], None]]] = []

    try:
        # ---- KMOS: iOS 18.3.1 unique build ----
        rows = conn.execute(
            "SELECT rowid, version, OSBuild, sortVersion, kernelversion, kernelversiontime "
            "FROM KMOS WHERE version='18.3.1' AND sortVersion='018.003.001'"
        ).fetchall()
        if len(rows) != 1:
            raise RuntimeError(f"expected exactly one iOS 18.3.1 row, got {len(rows)}")
        row = rows[0]

        if row["OSBuild"] == "22D72":
            print("KEEP iOS 18.3.1 OSBuild=22D72")
        elif row["OSBuild"] == "22C152":
            if row["kernelversion"] != "24.3.0":
                raise RuntimeError(
                    f"unexpected iOS 18.3.1 Darwin {row['kernelversion']!r}; refusing partial fix"
                )
            if "xnu-11215.82.4~20" not in (row["kernelversiontime"] or ""):
                raise RuntimeError(
                    "unexpected iOS 18.3.1 XNU; refusing partial fix: "
                    f"{row['kernelversiontime']!r}"
                )
            rowid = int(row["rowid"])
            print(
                f"{'APPLY' if args.apply else 'DRY RUN'} "
                "iOS 18.3.1: OSBuild 22C152 -> 22D72"
            )
            operations.append((
                "ios18.3.1-build",
                lambda rowid=rowid: conn.execute(
                    "UPDATE KMOS SET OSBuild='22D72' WHERE rowid=?", (rowid,)
                ),
            ))
        else:
            raise RuntimeError(
                f"unexpected iOS 18.3.1 OSBuild {row['OSBuild']!r}; manual reconciliation required"
            )

        # ---- KMDevices: iPhone 13 vs iPhone 13 mini A-number ----
        mini_rows = conn.execute(
            "SELECT rowid, identifier, internal_name, anumber, generation "
            "FROM KMDevices WHERE identifier='iPhone14,4' AND anumber='A2626'"
        ).fetchall()
        if len(mini_rows) != 1:
            raise RuntimeError(
                f"expected iPhone14,4/A2626 to exist exactly once, got {len(mini_rows)}"
            )

        phone_rows = conn.execute(
            "SELECT rowid, identifier, internal_name, anumber, generation "
            "FROM KMDevices WHERE identifier='iPhone14,5' AND anumber IN ('A2626','A2631') "
            "ORDER BY anumber"
        ).fetchall()

        a2626 = [r for r in phone_rows if r["anumber"] == "A2626"]
        a2631 = [r for r in phone_rows if r["anumber"] == "A2631"]
        if len(a2631) == 1 and not a2626:
            print("KEEP iPhone14,5 regulatory model A2631")
        elif len(a2626) == 1 and not a2631:
            bad = a2626[0]
            if bad["internal_name"] != "D17AP" or bad["generation"] != "iPhone 13":
                raise RuntimeError(
                    "unexpected iPhone14,5/A2626 row; refusing automatic A-number correction: "
                    f"board={bad['internal_name']!r} generation={bad['generation']!r}"
                )
            rowid = int(bad["rowid"])
            print(
                f"{'APPLY' if args.apply else 'DRY RUN'} "
                "iPhone14,5: regulatory model A2626 -> A2631"
            )
            operations.append((
                "iphone13-anumber",
                lambda rowid=rowid: conn.execute(
                    "UPDATE KMDevices SET anumber='A2631' WHERE rowid=?", (rowid,)
                ),
            ))
        else:
            raise RuntimeError(
                "iPhone14,5 A2626/A2631 source state is ambiguous; manual reconciliation required"
            )

        if args.apply and operations:
            with conn:
                for _, operation in operations:
                    operation()

        # ---- post-state invariants, checked for apply and already-fixed DBs ----
        if args.apply or not operations:
            duplicate_builds = conn.execute(
                "SELECT OSBuild, COUNT(*) AS c FROM KMOS "
                "WHERE OSBuild IS NOT NULL AND OSBuild<>'' "
                "GROUP BY OSBuild HAVING COUNT(*) > 1"
            ).fetchall()
            if duplicate_builds:
                raise RuntimeError(
                    "duplicate OSBuild remains: "
                    + ", ".join(f"{r['OSBuild']} x{r['c']}" for r in duplicate_builds)
                )

            duplicate_a_numbers = conn.execute(
                "SELECT anumber, COUNT(DISTINCT identifier) AS c "
                "FROM KMDevices WHERE anumber IS NOT NULL AND anumber<>'' "
                "GROUP BY anumber HAVING COUNT(DISTINCT identifier) > 1"
            ).fetchall()
            if duplicate_a_numbers:
                raise RuntimeError(
                    "regulatory A-number has multiple ProductType owners: "
                    + ", ".join(f"{r['anumber']} x{r['c']}" for r in duplicate_a_numbers)
                )

            print("INTEGRITY PASS: OSBuilds and regulatory A-number ownership are unique.")
        elif operations:
            print("Dry run only. Re-run with --apply after reviewing the plan.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
