#!/usr/bin/env python3
"""Phase 10 release regression, privacy and package gates."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MATRIX_PATH = ROOT / "tests/phase10/release_matrix.json"
PHASE_TESTS = [
    "scripts/test_phase2_validator_static.py",
    "scripts/test_phase3_hooks_static.py",
    "scripts/test_phase4_lockdown_safety_static.py",
    "scripts/test_phase5_lockdown_software_model_static.py",
    "scripts/test_phase6_lockdown_device_identity_static.py",
    "scripts/test_phase7_lockdown_soc_cellular_static.py",
    "scripts/test_phase8_clear_modes_static.py",
    "scripts/test_phase9_web_cellular_backup_static.py",
    "scripts/test_phase10_release_hardening_static.py",
]
EXTENDED_PYTHON_TESTS = [
    "scripts/test_device_spec_p1_1.py",
    "scripts/test_device_spec_p1_2.py",
    "scripts/test_device_spec_p1_3.py",
    "scripts/test_device_profile_webgl_p2.py",
    "scripts/test_thread_safety_cleanup_p3.py",
    "scripts/test_jailbreak_bypass_cleanup_lifecycle.py",
    "scripts/test_jailbreak_bypass_dyld_compatibility.py",
    "scripts/test_jailbreak_bypass_matcher_hardening.py",
    "scripts/test_jailbreak_bypass_p2.py",
]
NODE_TESTS = [
    "scripts/test_canvas_fingerprint_protection.js",
    "scripts/test_web_spoof_p1.js",
    "scripts/test_webgl_profile_p2.js",
]
FORBIDDEN_PACKAGE_TOKENS = [
    b"PXLockdownResearchSafety",
    b"PXLockdownSoftwareModelProvider",
    b"PXLockdownDeviceIdentityProvider",
    b"PXLockdownSoCCellularProvider",
    b"lockdownResearchEnabled",
    b"lockdownResearchBundleAllowlist",
    b"INTERNAL_SECURITY_RESEARCH=1",
    b"AAA_TestCtor",
    b"weaponx_ctor",
    b"com.example.fixture",
    b"353918123456786",
]


def fail(message: str) -> None:
    raise RuntimeError(message)


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def git_commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return "unknown"


def write_report(path: str | None, report: dict) -> None:
    if not path:
        return
    destination = Path(path)
    if not destination.is_absolute():
        destination = ROOT / destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate_matrix() -> dict:
    matrix = json.loads(MATRIX_PATH.read_text(encoding="utf-8"))
    if set(matrix) != {"schemaVersion", "cases"} or matrix["schemaVersion"] != 1:
        fail("release matrix schema is invalid")
    cases = matrix["cases"]
    if not isinstance(cases, list) or len(cases) < 12:
        fail("release matrix must contain at least 12 cases")
    required = {"id", "model", "family", "iosVersion", "build", "cellular", "generation"}
    ids, generations, majors, families, cellular_modes = set(), set(), set(), set(), set()
    for case in cases:
        if not isinstance(case, dict) or set(case) != required:
            fail("release matrix case has an inexact field set")
        if case["id"] in ids or case["generation"] in generations:
            fail("release matrix IDs and generations must be unique")
        if not re.fullmatch(r"(?:iPhone|iPad)\d+,\d+", case["model"]):
            fail(f"invalid model fixture: {case['model']}")
        if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", case["iosVersion"]):
            fail(f"invalid iOS fixture: {case['iosVersion']}")
        if not re.fullmatch(r"\d+[A-Z]\d+[a-z]?", case["build"]):
            fail(f"invalid build fixture: {case['build']}")
        if case["family"] not in {"iPhone", "iPad"} or not case["model"].startswith(case["family"]):
            fail("fixture family/model mismatch")
        if type(case["cellular"]) is not bool or type(case["generation"]) is not int or case["generation"] < 1:
            fail("fixture capability/generation type is invalid")
        ids.add(case["id"]); generations.add(case["generation"])
        majors.add(int(case["iosVersion"].split(".")[0])); families.add(case["family"])
        cellular_modes.add(case["cellular"])
    if not set(range(12, 18)).issubset(majors):
        fail("release matrix must span every supported iOS major from 12 through 17")
    if families != {"iPhone", "iPad"} or cellular_modes != {False, True}:
        fail("release matrix must cover iPhone/iPad and cellular/Wi-Fi-only")
    return {"caseCount": len(cases), "iosMajors": sorted(majors), "families": sorted(families)}


def audit_source() -> dict:
    makefile = read("Makefile")
    workflow = read(".github/workflows/build-ios-arm.yml")
    safety = read("research/PXLockdownResearchSafety.m")
    provenance = read("common/PXBackupProvenance.m")
    envelope = read("common/PXBackupAuthenticatedEnvelope.m")
    if "INTERNAL_SECURITY_RESEARCH ?= 0" not in makefile:
        fail("Research must default off")
    if "$(wildcard research/*.m)" in makefile:
        fail("Research source wildcard is forbidden")
    if "release-package:" not in makefile or "FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0" not in makefile:
        fail("Makefile release target does not force production flags")
    required_workflow = [
        "python3 scripts/release_hardening.py regression",
        "python3 scripts/release_hardening.py package",
        "FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0",
        "release-hardening-report.json",
    ]
    missing = [token for token in required_workflow if token not in workflow]
    if missing:
        fail(f"CI release hardening is incomplete: {missing}")
    if '@"value": @"<redacted>"' not in safety or "sensitiveValue" not in safety:
        fail("Lockdown audit event is not explicitly redacted")
    for source in (ROOT / "research").glob("*.[mh]"):
        value = source.read_text(encoding="utf-8")
        if any(token in value for token in ("NSLog(", "PXLog(", "PXDBLog(")):
            fail(f"Research provider must not log runtime values: {source.name}")
    if '@"keyMaterialStored": @NO' not in provenance:
        fail("backup provenance does not declare external-only key material")
    representation = envelope.split("NSDictionary *representation = @{", 1)[-1].split("};", 1)[0]
    if "externalKey" in representation or "plaintext" in representation:
        fail("backup envelope serializes key material or plaintext")
    matrix = validate_matrix()
    return {"status": "pass", "matrix": matrix, "commit": git_commit()}


def run_one(command: list[str], timeout: float) -> dict:
    started = time.perf_counter()
    try:
        completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        fail(f"timeout after {timeout:.0f}s: {' '.join(command)}")
    elapsed = time.perf_counter() - started
    if completed.returncode != 0:
        output = (completed.stdout + "\n" + completed.stderr)[-4000:]
        fail(f"crash/non-zero ({completed.returncode}) in {' '.join(command)}\n{output}")
    return {"command": command, "seconds": round(elapsed, 6)}


def run_regression(iterations: int, suite_timeout: float, iteration_budget: float) -> dict:
    source_result = audit_source()
    python = sys.executable
    commands = [[python, path] for path in PHASE_TESTS + EXTENDED_PYTHON_TESTS]
    node = shutil.which("node")
    if node:
        commands.extend([[node, path] for path in NODE_TESTS])
    runs = []
    for iteration in range(1, iterations + 1):
        started = time.perf_counter()
        results = [run_one(command, suite_timeout) for command in commands]
        elapsed = time.perf_counter() - started
        if elapsed > iteration_budget:
            fail(f"iteration {iteration} exceeded {iteration_budget:.0f}s performance budget ({elapsed:.3f}s)")
        runs.append({"iteration": iteration, "seconds": round(elapsed, 6), "suites": results})
    hardening = run_one([python, "scripts/audit_backup_restore_hardening.py"], suite_timeout)
    all_seconds = [suite["seconds"] for run in runs for suite in run["suites"]]
    report = {
        "phase": 10,
        "status": "pass",
        "commit": git_commit(),
        "matrix": source_result["matrix"],
        "iterations": runs,
        "backupRestoreAudit": hardening,
        "performance": {
            "suiteTimeoutSeconds": suite_timeout,
            "iterationBudgetSeconds": iteration_budget,
            "maxSuiteSeconds": max(all_seconds, default=0),
            "medianSuiteSeconds": statistics.median(all_seconds) if all_seconds else 0,
        },
    }
    return report


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract_artifact(artifact: Path, destination: Path) -> None:
    if artifact.is_dir():
        shutil.copytree(artifact, destination, dirs_exist_ok=True)
        return
    if artifact.suffix != ".deb":
        fail("package audit requires an extracted directory or .deb artifact")
    dpkg = shutil.which("dpkg-deb")
    if not dpkg:
        fail("dpkg-deb is required to audit a .deb release artifact")
    completed = subprocess.run([dpkg, "-x", str(artifact), str(destination)], text=True, capture_output=True)
    if completed.returncode != 0:
        fail(f"could not extract release artifact: {completed.stderr.strip()}")


def audit_package(artifact_name: str) -> dict:
    artifact = Path(artifact_name)
    if not artifact.is_absolute():
        artifact = ROOT / artifact
    if not artifact.exists():
        fail(f"release artifact does not exist: {artifact}")
    findings = []
    scanned_files = 0
    with tempfile.TemporaryDirectory(prefix="px-release-audit-") as temporary:
        extracted = Path(temporary) / "root"
        extracted.mkdir()
        extract_artifact(artifact, extracted)
        for path in extracted.rglob("*"):
            if not path.is_file() or path.is_symlink():
                continue
            scanned_files += 1
            relative = str(path.relative_to(extracted)).encode("utf-8", "replace")
            data = path.read_bytes()
            for token in FORBIDDEN_PACKAGE_TOKENS:
                if token in relative or token in data:
                    findings.append({"file": relative.decode("utf-8", "replace"), "token": token.decode("ascii")})
    if findings:
        fail(f"release package contains forbidden Research/test/private content: {findings[:10]}")
    return {
        "phase": 10,
        "status": "pass",
        "commit": git_commit(),
        "artifact": str(artifact),
        "artifactSHA256": sha256_file(artifact) if artifact.is_file() else None,
        "filesScanned": scanned_files,
        "forbiddenTokens": len(FORBIDDEN_PACKAGE_TOKENS),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    source = sub.add_parser("source")
    source.add_argument("--report")
    regression = sub.add_parser("regression")
    regression.add_argument("--iterations", type=int, default=2)
    regression.add_argument("--suite-timeout", type=float, default=120.0)
    regression.add_argument("--iteration-budget", type=float, default=300.0)
    regression.add_argument("--report")
    package = sub.add_parser("package")
    package.add_argument("--artifact", required=True)
    package.add_argument("--report")
    args = parser.parse_args()
    try:
        if args.command == "source":
            report = audit_source()
        elif args.command == "regression":
            if args.iterations < 2 or args.iterations > 10:
                fail("regression iterations must be between 2 and 10")
            if args.suite_timeout <= 0 or args.iteration_budget <= 0:
                fail("regression timeout and performance budget must be positive")
            report = run_regression(args.iterations, args.suite_timeout, args.iteration_budget)
        else:
            report = audit_package(args.artifact)
        write_report(args.report, report)
        print(f"Phase-10 {args.command} hardening: PASS")
        return 0
    except (RuntimeError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Phase-10 {args.command} hardening: FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
