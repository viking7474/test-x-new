#!/usr/bin/env python3
"""Behavior tests for P1 worksheet version and cellular consistency guards."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPORTER = ROOT / "scripts" / "export_p1_manual_template.py"
IMPORTER = ROOT / "scripts" / "import_p1_manual_data.py"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def require(condition: bool, message: str, result: subprocess.CompletedProcess[str] | None = None) -> None:
    if condition:
        return
    details = ""
    if result is not None:
        details = f"\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
    raise AssertionError(message + details)


def write(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="p1-import-guards-") as temp_dir:
        temp = Path(temp_dir)
        worksheet_path = temp / "worksheet.json"
        exported = run(str(EXPORTER), "--output", str(worksheet_path))
        require(exported.returncode == 0, "worksheet export failed", exported)

        valid = run(str(IMPORTER), str(worksheet_path))
        require(valid.returncode == 0 and "DRY RUN PASS" in valid.stdout,
                "current worksheet must pass dry-run", valid)

        worksheet = json.loads(worksheet_path.read_text(encoding="utf-8"))
        stale = json.loads(json.dumps(worksheet))
        stale["databaseVersions"]["cellular"] = "stale-test-version"
        stale_path = temp / "stale.json"
        write(stale_path, stale)

        rejected = run(str(IMPORTER), str(stale_path))
        require(rejected.returncode != 0 and "databaseVersions do not match" in rejected.stderr,
                "stale worksheet must fail closed", rejected)

        explicitly_allowed = run(str(IMPORTER), str(stale_path), "--allow-stale")
        require(explicitly_allowed.returncode == 0 and
                "WARNING: accepting stale worksheet" in explicitly_allowed.stdout,
                "--allow-stale must be an explicit, working recovery path", explicitly_allowed)

        inconsistent = json.loads(json.dumps(worksheet))
        number = sorted(inconsistent["records"])[0]
        inconsistent["records"][number]["cellular"] = {
            "known": True,
            "enabled": True,
            "physicalSIM": False,
            "eSIM": False,
            "dualSIM": False,
            "cdma": False,
            "imeiTACs": ["12345678"],
            "meidPrefixes": [],
        }
        inconsistent_path = temp / "inconsistent.json"
        write(inconsistent_path, inconsistent)
        rejected = run(str(IMPORTER), str(inconsistent_path))
        require(rejected.returncode != 0 and
                "enabled cellular requires physicalSIM=true or eSIM=true" in rejected.stderr,
                "authoritative cellular row without a SIM modality must fail", rejected)

    print("P1 worksheet import guard behavior test: PASS")


if __name__ == "__main__":
    main()
