#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

def require(condition, message):
    if not condition:
        raise AssertionError(message)

runner = (ROOT / "scripts/release_hardening.py").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/build-ios-arm.yml").read_text(encoding="utf-8")
makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
checklist = (ROOT / "docs/Phase-10-release-checklist.md").read_text(encoding="utf-8")
matrix = json.loads((ROOT / "tests/phase10/release_matrix.json").read_text(encoding="utf-8"))

for token in ("validate_matrix", "run_regression", "audit_package", "FORBIDDEN_PACKAGE_TOKENS",
              "suite_timeout", "iteration_budget", "subprocess.TimeoutExpired", "artifactSHA256"):
    require(token in runner, f"release runner missing contract: {token}")
require(len(matrix["cases"]) >= 12, "release matrix is too small")
require({case["family"] for case in matrix["cases"]} == {"iPhone", "iPad"}, "device families are incomplete")
require({case["cellular"] for case in matrix["cases"]} == {True, False}, "cellular/Wi-Fi matrix is incomplete")
require(set(range(12, 18)).issubset({int(case["iosVersion"].split(".")[0]) for case in matrix["cases"]}),
        "iOS 12-17 coverage is incomplete")
require("release-package:" in makefile and "FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0" in makefile,
        "release Make target does not force safe flags")
for token in ("release_hardening.py regression", "release_hardening.py package", "release-hardening-report.json"):
    require(token in workflow, f"CI missing Phase-10 gate: {token}")
require("A release is **not signed**" in checklist and "Artifact SHA-256" in checklist,
        "release-owner sign-off contract is incomplete")
require("dpkg-deb" in runner and "PXLockdownResearchSafety" in runner and "AAA_TestCtor" in runner,
        "post-package Research/test scan is incomplete")

print("Phase-10 release hardening contracts: PASS")
