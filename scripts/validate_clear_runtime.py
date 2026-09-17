#!/usr/bin/env python3
"""Validate on-device AppDataCleaner runtime artifacts.

This script does not execute destructive work. It analyzes an exported
AppDataCleaner.log plus the binary-plist files written to PXClearJournal and
turns the existing runtime instrumentation into a reproducible PASS/FAIL gate.

Typical use after copying artifacts from a device:

    python3 scripts/validate_clear_runtime.py \
      --log AppDataCleaner.log \
      --journal-dir PXClearJournal \
      --bundle com.example.app \
      --mode Full \
      --expect-success yes \
      --icloud-option off \
      --safari-option off \
      --mail-option off

Run built-in synthetic coverage with:

    python3 scripts/validate_clear_runtime.py --self-test
"""

from __future__ import annotations

import argparse
import dataclasses
import plistlib
import re
import sys
import tempfile
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


MODES = ("Quick", "Full", "Deep")
COMPONENTS = ("ApplicationData", "ExtensionData", "AppGroups", "PluginKitData", "Keychain")
FULL_SCOPES_MASK = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
POLICY_KEYS = {
    "icloud": "clearICloudData",
    "safari": "clearSafariSharedWebData",
    "mail": "clearMailSharedStore",
}
DRY_RUN_POLICY_KEYS = {
    "icloud": "wouldClearICloudData",
    "safari": "wouldClearSafariSharedWebData",
    "mail": "wouldClearMailSharedStore",
}


@dataclasses.dataclass(frozen=True)
class ComponentResult:
    name: str
    status: str
    attempted: int
    succeeded: int
    failed: int


@dataclasses.dataclass
class ValidationReport:
    checks: List[str] = dataclasses.field(default_factory=list)
    warnings: List[str] = dataclasses.field(default_factory=list)
    errors: List[str] = dataclasses.field(default_factory=list)

    def check(self, condition: bool, message: str) -> None:
        if condition:
            self.checks.append(message)
        else:
            self.errors.append(message)

    def warn(self, condition: bool, message: str) -> None:
        if not condition:
            self.warnings.append(message)

    @property
    def passed(self) -> bool:
        return not self.errors


@dataclasses.dataclass(frozen=True)
class RuntimeExpectation:
    bundle: str
    mode: str
    dry_run: bool
    expect_success: Optional[bool]
    icloud_option: Optional[bool]
    safari_option: Optional[bool]
    mail_option: Optional[bool]
    expect_cancellation: Optional[str]


def parse_on_off(value: str) -> bool:
    normalized = value.strip().lower()
    if normalized in ("on", "yes", "true", "1"):
        return True
    if normalized in ("off", "no", "false", "0"):
        return False
    raise argparse.ArgumentTypeError("expected on/off")


def parse_yes_no_auto(value: str) -> Optional[bool]:
    normalized = value.strip().lower()
    if normalized == "auto":
        return None
    if normalized in ("yes", "true", "1"):
        return True
    if normalized in ("no", "false", "0"):
        return False
    raise argparse.ArgumentTypeError("expected yes/no/auto")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def strip_log_timestamp(line: str) -> str:
    return re.sub(r"^\[\d{2}:\d{2}:\d{2}\]\s*", "", line.rstrip("\r\n"))


def log_messages(text: str) -> List[str]:
    return [strip_log_timestamp(line) for line in text.splitlines()]


def slice_latest_run(messages: Sequence[str], expectation: RuntimeExpectation) -> List[str]:
    if expectation.dry_run:
        marker = f"[AppDataCleaner] DRY-RUN: planning {expectation.mode} clear for {expectation.bundle} (no destructive operations)"
    else:
        marker = f"[AppDataCleaner] === STARTING {expectation.mode} data clearing for {expectation.bundle} ==="

    starts = [index for index, message in enumerate(messages) if message == marker]
    if not starts:
        return []
    start = starts[-1]

    if expectation.dry_run:
        # A dry run is synchronous from the caller's perspective except for callback dispatch;
        # terminate at the next dry-run/destructive start if multiple runs share one log file.
        next_start_patterns = (
            "[AppDataCleaner] DRY-RUN: planning ",
            "[AppDataCleaner] === STARTING ",
        )
    else:
        next_start_patterns = ("[AppDataCleaner] === STARTING ", "[AppDataCleaner] DRY-RUN: planning ")

    end = len(messages)
    for index in range(start + 1, len(messages)):
        if any(messages[index].startswith(prefix) for prefix in next_start_patterns):
            end = index
            break
    return list(messages[start:end])


def parse_components(run: Sequence[str]) -> Dict[str, ComponentResult]:
    pattern = re.compile(
        r"^\[AppDataCleaner\] "
        r"(ApplicationData|ExtensionData|AppGroups|PluginKitData|Keychain) result "
        r"(Succeeded|Skipped|Failed) attempted=(\d+) succeeded=(\d+) failed=(\d+)$"
    )
    components: Dict[str, ComponentResult] = {}
    for message in run:
        match = pattern.match(message)
        if not match:
            continue
        name, status, attempted, succeeded, failed = match.groups()
        components[name] = ComponentResult(
            name=name,
            status=status,
            attempted=int(attempted),
            succeeded=int(succeeded),
            failed=int(failed),
        )
    return components


def metric_lines(run: Sequence[str]) -> List[str]:
    return [message for message in run if message.startswith("[AppDataCleaner][metric] ")]


def find_last_metric(run: Sequence[str], token: str) -> Optional[str]:
    matches = [message for message in metric_lines(run) if token in message]
    return matches[-1] if matches else None


def parse_final_success(run: Sequence[str], mode: str, dry_run: bool) -> Optional[bool]:
    if dry_run:
        pattern = re.compile(rf"^\[AppDataCleaner\]\[metric\] mode={re.escape(mode)} dry_run=1 total_ms=[0-9.]+ success=([01])$")
    else:
        pattern = re.compile(rf"^\[AppDataCleaner\]\[metric\] mode={re.escape(mode)} total_ms=[0-9.]+ success=([01])$")
    values = [int(match.group(1)) for message in run if (match := pattern.match(message))]
    return bool(values[-1]) if values else None


def load_journal_entries(journal_dir: Path) -> List[Mapping[str, object]]:
    entries: List[Mapping[str, object]] = []
    if not journal_dir.exists() or not journal_dir.is_dir():
        return entries
    for path in sorted(journal_dir.glob("*.plist")):
        try:
            with path.open("rb") as handle:
                value = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException, ValueError):
            continue
        if isinstance(value, dict):
            copied = dict(value)
            copied["__path"] = str(path)
            entries.append(copied)
    return entries


def matching_journal_entries(
    entries: Iterable[Mapping[str, object]], expectation: RuntimeExpectation
) -> List[Mapping[str, object]]:
    matched = [
        entry
        for entry in entries
        if entry.get("bundleID") == expectation.bundle
        and entry.get("mode") == expectation.mode
        and bool(entry.get("dryRun")) == expectation.dry_run
    ]
    return sorted(matched, key=lambda entry: float(entry.get("timestamp", 0.0) or 0.0))


def latest_phase(entries: Sequence[Mapping[str, object]], phase: str) -> Optional[Mapping[str, object]]:
    matches = [entry for entry in entries if entry.get("phase") == phase]
    return matches[-1] if matches else None


def validate_journal_entry_shape(
    report: ValidationReport,
    entry: Mapping[str, object],
    phase: str,
) -> None:
    report.check(entry.get("schemaVersion") == 1, f"{phase} journal schemaVersion is 1")
    report.check(entry.get("scopes") == FULL_SCOPES_MASK, f"{phase} journal scopes match five-scope Clear mask")
    report.check(entry.get("phase") == phase, f"journal phase is {phase}")
    timestamp = entry.get("timestamp")
    report.check(isinstance(timestamp, (int, float)) and float(timestamp) > 0.0,
                 f"{phase} journal timestamp is valid")


def expected_policy_map(expectation: RuntimeExpectation) -> Dict[str, bool]:
    result: Dict[str, bool] = {}
    for policy, value in (
        ("icloud", expectation.icloud_option),
        ("safari", expectation.safari_option),
        ("mail", expectation.mail_option),
    ):
        if value is not None:
            result[policy] = value
    return result


def validate_journal(
    report: ValidationReport,
    entries: Sequence[Mapping[str, object]],
    expectation: RuntimeExpectation,
) -> None:
    matched = matching_journal_entries(entries, expectation)
    report.check(bool(matched), "journal contains a matching bundle/mode/dryRun entry")
    if not matched:
        return

    if expectation.dry_run:
        plan = latest_phase(matched, "dry_run_plan")
        commit = latest_phase(matched, "dry_run_commit")
        report.check(plan is not None, "dry-run journal contains dry_run_plan")
        report.check(commit is not None, "dry-run journal contains dry_run_commit")
        if plan is not None:
            validate_journal_entry_shape(report, plan, "dry_run_plan")
        if commit is None:
            return
        validate_journal_entry_shape(report, commit, "dry_run_commit")
        if plan is not None:
            plan_timestamp = float(plan.get("timestamp", 0.0) or 0.0)
            commit_timestamp = float(commit.get("timestamp", 0.0) or 0.0)
            report.check(commit_timestamp >= plan_timestamp,
                         "dry-run commit timestamp is not earlier than plan")
            report.check(commit_timestamp - plan_timestamp <= 120.0,
                         "dry-run plan/commit belong to the same bounded session")
        info = commit.get("info")
        report.check(isinstance(info, dict), "dry-run commit has an info dictionary")
        if not isinstance(info, dict):
            return
        for policy, option_enabled in expected_policy_map(expectation).items():
            key = DRY_RUN_POLICY_KEYS[policy]
            if policy == "icloud":
                expected_effective = option_enabled and expectation.mode in ("Full", "Deep")
            elif policy == "safari":
                expected_effective = (
                    option_enabled
                    and expectation.mode == "Deep"
                    and expectation.bundle == "com.apple.mobilesafari"
                )
            else:
                expected_effective = (
                    option_enabled
                    and expectation.mode == "Deep"
                    and expectation.bundle == "com.apple.mobilemail"
                )
            report.check(
                bool(info.get(key)) == expected_effective,
                f"dry-run journal {key} matches effective expectation {expected_effective}",
            )
        report.check(bool(info.get("wouldRunDeepResidualScan")) == (expectation.mode == "Deep"),
                     "dry-run residual-scan plan matches mode")
    else:
        begin = latest_phase(matched, "begin")
        report.check(begin is not None, "destructive run journal contains begin phase")
        if begin is None:
            return
        validate_journal_entry_shape(report, begin, "begin")
        info = begin.get("info")
        report.check(isinstance(info, dict), "begin journal has an info dictionary")
        if not isinstance(info, dict):
            return
        for policy, expected in expected_policy_map(expectation).items():
            key = POLICY_KEYS[policy]
            report.check(bool(info.get(key)) == expected, f"begin journal {key} matches expected {expected}")
        report.check(bool(info.get("deepClean")) == (expectation.mode == "Deep"),
                     "begin journal deepClean matches mode")


def validate_policy_logs(report: ValidationReport, run: Sequence[str], expectation: RuntimeExpectation) -> None:
    joined = "\n".join(run)

    # The system-Mail release invariant is unconditional for Deep MobileMail.
    if expectation.bundle == "com.apple.mobilemail" and expectation.mode == "Deep":
        report.check(
            "MobileMail: Accounts3 destructive cleanup BLOCKED (shared account ownership policy)" in joined,
            "MobileMail Deep run keeps Accounts3 destructive cleanup BLOCKED",
        )
        report.check(
            "Accounts3 exact cleanup committed rows=" not in joined,
            "MobileMail run does not commit exact Accounts3 destructive SQL",
        )
        if expectation.mail_option is True:
            report.check(
                "Clear Mail Shared Store policy ON; wiping shared MobileMail store/prefs" in joined,
                "Mail shared-store ON marker present",
            )
            report.check(
                ("MobileMail shared-store cleanup committed; detached old store removed" in joined)
                or ("MobileMail shared-store cleanup failed" in joined),
                "Mail shared-store ON path reaches an explicit terminal result",
            )
        elif expectation.mail_option is False:
            report.check(
                "Clear Mail Shared Store policy OFF; shared /var/mobile/Library/Mail preserved" in joined,
                "Mail shared-store OFF marker present",
            )
            report.check(
                "MobileMail shared-store cleanup committed; detached old store removed" not in joined,
                "Mail shared-store OFF run does not commit shared-store cleanup",
            )

    if expectation.bundle == "com.apple.mobilesafari" and expectation.mode == "Deep":
        if expectation.safari_option is True:
            report.check(
                "Clear Safari Shared Web Data policy ON; wiping shared Safari/WebKit stores" in joined,
                "Safari shared-web ON marker present",
            )
            report.check(
                "MobileSafari: shared Accounts3 mutation skipped (exact-ownership policy)" in joined,
                "Safari shared-web path keeps Accounts3 outside policy",
            )
            report.check(
                "MobileSafari shared-store cleanup completed" in joined,
                "Safari shared-web ON path reaches an explicit terminal result",
            )
        elif expectation.safari_option is False:
            report.check(
                "Clear Safari Shared Web Data policy OFF; shared Safari/WebKit stores preserved" in joined,
                "Safari shared-web OFF marker present",
            )
            report.check(
                "MobileSafari shared-store cleanup completed" not in joined,
                "Safari shared-web OFF run does not execute shared-store cleanup",
            )

    if expectation.icloud_option is True and expectation.mode in ("Full", "Deep"):
        report.check(
            "Clearing exact-authorized iCloud/Accounts data" in joined,
            "iCloud option ON reaches exact-authorized policy path",
        )
    elif expectation.icloud_option is False and expectation.mode in ("Full", "Deep"):
        report.check(
            "Clear iCloud Data policy OFF; skipping iCloud/Accounts cleanup" in joined,
            "iCloud option OFF marker present",
        )


def validate_dry_run(report: ValidationReport, run: Sequence[str], expectation: RuntimeExpectation) -> None:
    joined = "\n".join(run)
    report.check(
        f"DRY-RUN: planning {expectation.mode} clear for {expectation.bundle} (no destructive operations)" in joined,
        "dry-run planning marker present",
    )
    report.check(parse_final_success(run, expectation.mode, True) is True, "dry-run success metric present")
    for destructive_marker in (
        "Serialized cleaning started operation=",
        "Step 0: Kill application",
        "Step 1: Planning and running single Keychain pass",
        "Step 3: Clearing exact app state files",
        "Step 4: Running canonical data aggregate",
    ):
        report.check(destructive_marker not in joined, f"dry-run does not execute: {destructive_marker}")


def validate_destructive_run(report: ValidationReport, run: Sequence[str], expectation: RuntimeExpectation) -> None:
    joined = "\n".join(run)
    report.check(bool(run), "log contains the requested destructive run")
    if not run:
        return

    cancellation_pattern = re.compile(
        r"^\[AppDataCleaner\]\[metric\] cancellation reason=([^ ]+) "
        r"operation=([^ ]+) error_domain=([^ ]+) error_code=(-?\d+)$"
    )
    cancellation_matches = [
        match for message in run if (match := cancellation_pattern.match(message))
    ]
    cancellation_reason = cancellation_matches[-1].group(1) if cancellation_matches else None
    cancellation_expected = expectation.expect_cancellation in (
        "deadline",
        "background-expiration",
        "any",
    ) or (expectation.expect_cancellation is None and bool(cancellation_matches))

    report.check(
        f"=== STARTING {expectation.mode} data clearing for {expectation.bundle} ===" in joined,
        "run start marker present",
    )
    report.check("Calling completion handler (success=" in joined, "completion handler marker present")

    completed_seen = f"=== COMPLETED data clearing for {expectation.bundle} ===" in joined
    if cancellation_expected:
        report.warn(completed_seen, "cancelled run stopped before the normal completed marker")
    else:
        report.check(completed_seen, "worker reaches completed marker")

    required_steps = (
        "step=resolve_container",
        "step=kill",
        "step=keychain",
        "step=data_aggregate",
        "step=verification",
    )
    for step in required_steps:
        present = find_last_metric(run, step) is not None
        if cancellation_expected:
            report.warn(present, f"cancelled run stopped before metric {step}")
        else:
            report.check(present, f"metric {step} present")

    verification = find_last_metric(run, "step=verification")
    expected_strategy = "deep_residual_scan" if expectation.mode == "Deep" else "component_manifest"
    if verification is not None:
        report.check(f"strategy={expected_strategy}" in verification, f"verification strategy is {expected_strategy}")
        if expectation.expect_success is True:
            report.check("passed=1" in verification, "successful run passes verification")
    elif not cancellation_expected:
        report.check(False, "verification metric present")

    final_success = parse_final_success(run, expectation.mode, False)
    report.check(final_success is not None, "final total_ms/success metric present")
    if expectation.expect_success is not None and final_success is not None:
        report.check(
            final_success == expectation.expect_success,
            f"final success={int(expectation.expect_success)} matches expectation",
        )
    if cancellation_expected and final_success is not None:
        report.check(final_success is False, "cancelled run completes with success=0")

    components = parse_components(run)
    for component_name in COMPONENTS:
        if cancellation_expected:
            report.warn(component_name in components, f"cancelled run stopped before component result: {component_name}")
        else:
            report.check(component_name in components, f"component result present: {component_name}")
    for component in components.values():
        report.check(
            component.failed == component.attempted - component.succeeded,
            f"component accounting balances: {component.name}",
        )
        if component.status == "Succeeded":
            report.check(
                component.attempted > 0 and component.failed == 0 and component.succeeded == component.attempted,
                f"Succeeded accounting valid: {component.name}",
            )
        elif component.status == "Skipped":
            report.check(
                component.attempted == component.succeeded == component.failed == 0,
                f"Skipped accounting valid: {component.name}",
            )
        elif component.status == "Failed":
            report.check(
                component.attempted > 0 and component.failed > 0,
                f"Failed accounting valid: {component.name}",
            )

    watchdog_seen = (
        "timeout_fallback event=watchdog" in joined
        or "WATCHDOG: cancellation requested" in joined
    )
    if cancellation_expected:
        report.check(bool(cancellation_matches), "cancellation metric present")
        if expectation.expect_cancellation in ("deadline", "background-expiration"):
            report.check(
                cancellation_reason == expectation.expect_cancellation,
                f"cancellation reason is {expectation.expect_cancellation}",
            )
        if expectation.expect_cancellation == "deadline":
            report.check(watchdog_seen, "deadline cancellation includes watchdog evidence")
        elif expectation.expect_cancellation == "background-expiration":
            report.check(not watchdog_seen, "background-expiration cancellation is not mislabeled as watchdog")
    elif expectation.expect_cancellation == "none":
        report.check(not cancellation_matches, "normal run has no cancellation metric")
        report.check(not watchdog_seen, "normal run has no watchdog cancellation")

    if expectation.expect_success is True:
        report.check(
            all(component.status != "Failed" for component in components.values()),
            "successful run has no failed component",
        )
        report.check("EXCEPTION:" not in joined, "successful run has no exception marker")

    # Cancellation can occur before a policy branch is reached. The immutable journal
    # still validates the requested policy snapshot; terminal policy markers are required
    # only for non-cancelled runs.
    if not cancellation_expected:
        validate_policy_logs(report, run, expectation)


def validate_runtime(
    log_path: Path,
    journal_dir: Path,
    expectation: RuntimeExpectation,
) -> ValidationReport:
    report = ValidationReport()
    report.check(log_path.exists() and log_path.is_file(), "log file exists")
    report.check(journal_dir.exists() and journal_dir.is_dir(), "journal directory exists")
    if not report.passed:
        return report

    messages = log_messages(read_text(log_path))
    run = slice_latest_run(messages, expectation)
    report.check(bool(run), "log contains a matching bundle/mode run")
    if run:
        if expectation.dry_run:
            validate_dry_run(report, run, expectation)
        else:
            validate_destructive_run(report, run, expectation)

    entries = load_journal_entries(journal_dir)
    validate_journal(report, entries, expectation)
    return report


def print_report(report: ValidationReport) -> None:
    for message in report.checks:
        print(f"PASS: {message}")
    for message in report.warnings:
        print(f"WARN: {message}")
    for message in report.errors:
        print(f"FAIL: {message}")
    print(
        f"Clear runtime validation: {'PASS' if report.passed else 'FAIL'} "
        f"({len(report.checks)} pass, {len(report.warnings)} warn, {len(report.errors)} fail)"
    )


def write_plist(path: Path, value: Mapping[str, object]) -> None:
    with path.open("wb") as handle:
        plistlib.dump(dict(value), handle, fmt=plistlib.FMT_BINARY)


def synthetic_success_log(bundle: str, mode: str) -> str:
    strategy = "deep_residual_scan" if mode == "Deep" else "component_manifest"
    lines = [
        "=== AppDataCleaner Log Started ===",
        f"[12:00:00] [AppDataCleaner] === STARTING {mode} data clearing for {bundle} ===",
        f"[12:00:00] [AppDataCleaner] Serialized cleaning started operation=op-1 bundle={bundle}",
        "[12:00:00] [AppDataCleaner][metric] step=resolve_container duration_ms=2 found=1",
        f"[12:00:00] [AppDataCleaner] Step 0: Kill application (mode={mode})...",
        "[12:00:00] [AppDataCleaner][metric] step=kill duration_ms=10",
        "[12:00:00] [AppDataCleaner] Step 1: Planning and running single Keychain pass...",
        "[12:00:00] [AppDataCleaner][metric] step=keychain duration_ms=3 passes=0",
        "[12:00:00] [AppDataCleaner] Step 3: Clearing exact app state files...",
        "[12:00:00] [AppDataCleaner] Step 4: Running canonical data aggregate...",
        "[12:00:00] [AppDataCleaner] Clear iCloud Data policy OFF; skipping iCloud/Accounts cleanup",
        "[12:00:00] [AppDataCleaner][metric] step=data_aggregate duration_ms=20",
        f"[12:00:00] [AppDataCleaner][metric] step=verification duration_ms=1 strategy={strategy} passed=1",
        "[12:00:00] [AppDataCleaner] ApplicationData result Succeeded attempted=2 succeeded=2 failed=0",
        "[12:00:00] [AppDataCleaner] ExtensionData result Skipped attempted=0 succeeded=0 failed=0",
        "[12:00:00] [AppDataCleaner] AppGroups result Skipped attempted=0 succeeded=0 failed=0",
        "[12:00:00] [AppDataCleaner] PluginKitData result Skipped attempted=0 succeeded=0 failed=0",
        "[12:00:00] [AppDataCleaner] Keychain result Skipped attempted=0 succeeded=0 failed=0",
        f"[12:00:00] [AppDataCleaner] === COMPLETED data clearing for {bundle} ===",
        f"[12:00:00] [AppDataCleaner][metric] mode={mode} total_ms=50 success=1",
        f"[12:00:00] [AppDataCleaner][metric] mode={mode} resolve_container_ms=2 sqlite_ms=0 shell_processes=1 paths_scanned=2 timeout_fallback_count=0 first_attempt_success=1 first_attempt_success_pct=100.0",
        "[12:00:00] [AppDataCleaner] Calling completion handler (success=1)",
    ]
    return "\n".join(lines) + "\n"


def run_self_test() -> int:
    failures: List[str] = []
    with tempfile.TemporaryDirectory(prefix="px-clear-runtime-") as temp:
        root = Path(temp)
        journal = root / "PXClearJournal"
        journal.mkdir()
        log = root / "AppDataCleaner.log"
        bundle = "com.example.runtime"

        log.write_text(synthetic_success_log(bundle, "Full"), encoding="utf-8")
        write_plist(
            journal / "begin.plist",
            {
                "schemaVersion": 1,
                "bundleID": bundle,
                "mode": "Full",
                "scopes": 31,
                "dryRun": False,
                "phase": "begin",
                "timestamp": 1.0,
                "info": {
                    "deepClean": False,
                    "clearICloudData": False,
                    "clearSafariSharedWebData": False,
                    "clearMailSharedStore": False,
                },
            },
        )
        expectation = RuntimeExpectation(
            bundle=bundle,
            mode="Full",
            dry_run=False,
            expect_success=True,
            icloud_option=False,
            safari_option=False,
            mail_option=False,
            expect_cancellation="none",
        )
        report = validate_runtime(log, journal, expectation)
        if not report.passed:
            failures.append("synthetic Full success should pass: " + "; ".join(report.errors))

        # Policy mismatch must fail.
        mismatch = dataclasses.replace(expectation, icloud_option=True)
        mismatch_report = validate_runtime(log, journal, mismatch)
        if mismatch_report.passed:
            failures.append("journal policy mismatch should fail")

        # Dry-run must reject destructive-step evidence and validate plan/commit journal.
        dry_log = root / "dry.log"
        dry_log.write_text(
            "\n".join(
                [
                    "=== AppDataCleaner Log Started ===",
                    f"[13:00:00] [AppDataCleaner] DRY-RUN: planning Deep clear for {bundle} (no destructive operations)",
                    "[13:00:00] [AppDataCleaner][metric] mode=Deep dry_run=1 total_ms=2 success=1",
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        write_plist(
            journal / "dry-plan.plist",
            {
                "schemaVersion": 1,
                "bundleID": bundle,
                "mode": "Deep",
                "scopes": 31,
                "dryRun": True,
                "phase": "dry_run_plan",
                "timestamp": 2.0,
                "info": {"deepClean": True},
            },
        )
        write_plist(
            journal / "dry-commit.plist",
            {
                "schemaVersion": 1,
                "bundleID": bundle,
                "mode": "Deep",
                "scopes": 31,
                "dryRun": True,
                "phase": "dry_run_commit",
                "timestamp": 3.0,
                "info": {
                    "mode": "Deep",
                    "scopes": 31,
                    "wouldKillApp": True,
                    "wouldClearKeychain": True,
                    "wouldClearURLCredentials": False,
                    "wouldRunDataAggregate": True,
                    "wouldClearICloudData": False,
                    "wouldClearSafariSharedWebData": False,
                    "wouldClearMailSharedStore": False,
                    "wouldRunDeepResidualScan": True,
                },
            },
        )
        dry_expectation = RuntimeExpectation(
            bundle=bundle,
            mode="Deep",
            dry_run=True,
            expect_success=True,
            icloud_option=False,
            safari_option=False,
            mail_option=False,
            expect_cancellation="none",
        )
        dry_report = validate_runtime(dry_log, journal, dry_expectation)
        if not dry_report.passed:
            failures.append("synthetic dry-run should pass: " + "; ".join(dry_report.errors))

        # A stale dry-run commit from another session must not be paired with the plan.
        stale_commit_path = journal / "dry-commit.plist"
        with stale_commit_path.open("rb") as handle:
            stale_commit = plistlib.load(handle)
        stale_commit["timestamp"] = 500.0
        write_plist(stale_commit_path, stale_commit)
        stale_report = validate_runtime(dry_log, journal, dry_expectation)
        if stale_report.passed:
            failures.append("stale dry-run plan/commit pairing should fail")
        stale_commit["timestamp"] = 3.0
        write_plist(stale_commit_path, stale_commit)

        # A completed non-cancelled component failure is a valid expected-failure run.
        failure_log = root / "failure.log"
        failure_text = synthetic_success_log(bundle, "Full")
        failure_text = failure_text.replace(
            "ApplicationData result Succeeded attempted=2 succeeded=2 failed=0",
            "ApplicationData result Failed attempted=2 succeeded=1 failed=1",
        )
        failure_text = failure_text.replace("mode=Full total_ms=50 success=1", "mode=Full total_ms=50 success=0")
        failure_text = failure_text.replace("Calling completion handler (success=1)", "Calling completion handler (success=0)")
        failure_log.write_text(failure_text, encoding="utf-8")
        failure_expectation = dataclasses.replace(expectation, expect_success=False)
        failure_report = validate_runtime(failure_log, journal, failure_expectation)
        if not failure_report.passed:
            failures.append("synthetic completed failure should pass expected-failure validation: " + "; ".join(failure_report.errors))

        # Deadline cancellation may stop before verification/components but must still
        # produce watchdog evidence, final success=0, and the cancellation reason metric.
        cancel_log = root / "deadline.log"
        cancel_log.write_text(
            "\n".join(
                [
                    "=== AppDataCleaner Log Started ===",
                    f"[14:00:00] [AppDataCleaner] === STARTING Full data clearing for {bundle} ===",
                    f"[14:00:00] [AppDataCleaner] Serialized cleaning started operation=op-deadline bundle={bundle}",
                    "[14:00:00] [AppDataCleaner][metric] step=resolve_container duration_ms=2 found=1",
                    "[14:00:00] [AppDataCleaner] Step 0: Kill application (mode=Full)...",
                    "[14:00:00] [AppDataCleaner][metric] step=kill duration_ms=10",
                    "[14:05:00] [AppDataCleaner][metric] timeout_fallback event=watchdog timeout_sec=300 operation=op-deadline",
                    "[14:05:00] [AppDataCleaner] WATCHDOG: cancellation requested after 300 seconds; waiting for worker quiescence",
                    "[14:05:01] [AppDataCleaner][metric] mode=Full total_ms=301000 success=0",
                    "[14:05:01] [AppDataCleaner][metric] mode=Full resolve_container_ms=2 sqlite_ms=0 shell_processes=1 paths_scanned=2 timeout_fallback_count=1 first_attempt_success=0 first_attempt_success_pct=50.0",
                    "[14:05:01] [AppDataCleaner][metric] cancellation reason=deadline operation=op-deadline error_domain=PXClearOperation error_code=2",
                    "[14:05:01] [AppDataCleaner] Calling completion handler (success=0)",
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        cancel_expectation = dataclasses.replace(
            expectation,
            expect_success=False,
            expect_cancellation="deadline",
        )
        cancel_report = validate_runtime(cancel_log, journal, cancel_expectation)
        if not cancel_report.passed:
            failures.append("synthetic deadline cancellation should pass: " + "; ".join(cancel_report.errors))

        # MobileMail Deep must fail validation if the release BLOCKED marker is absent.
        mail_bundle = "com.apple.mobilemail"
        mail_log = root / "mail.log"
        mail_log.write_text(synthetic_success_log(mail_bundle, "Deep"), encoding="utf-8")
        write_plist(
            journal / "mail-begin.plist",
            {
                "schemaVersion": 1,
                "bundleID": mail_bundle,
                "mode": "Deep",
                "scopes": 31,
                "dryRun": False,
                "phase": "begin",
                "timestamp": 4.0,
                "info": {
                    "deepClean": True,
                    "clearICloudData": False,
                    "clearSafariSharedWebData": False,
                    "clearMailSharedStore": False,
                },
            },
        )
        mail_expectation = RuntimeExpectation(
            bundle=mail_bundle,
            mode="Deep",
            dry_run=False,
            expect_success=True,
            icloud_option=False,
            safari_option=False,
            mail_option=False,
            expect_cancellation="none",
        )
        mail_report = validate_runtime(mail_log, journal, mail_expectation)
        if mail_report.passed:
            failures.append("MobileMail Deep without Accounts3 BLOCKED marker should fail")

    if failures:
        for failure in failures:
            print(f"SELF-TEST FAIL: {failure}")
        print(f"Clear runtime validator self-test: FAIL ({len(failures)} failure(s))")
        return 1
    print("Clear runtime validator self-test: PASS")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run synthetic validator coverage")
    parser.add_argument("--log", type=Path, help="exported AppDataCleaner.log")
    parser.add_argument("--journal-dir", type=Path, help="exported PXClearJournal directory")
    parser.add_argument("--bundle", help="target bundle identifier")
    parser.add_argument("--mode", choices=MODES, help="expected Clear mode")
    parser.add_argument("--dry-run", action="store_true", help="validate a dry-run instead of destructive Clear")
    parser.add_argument("--expect-success", type=parse_yes_no_auto, default=None, metavar="yes|no|auto",
                        help="expected final result; auto only checks that a final metric exists")
    parser.add_argument("--icloud-option", type=parse_on_off, metavar="on|off")
    parser.add_argument("--safari-option", type=parse_on_off, metavar="on|off")
    parser.add_argument("--mail-option", type=parse_on_off, metavar="on|off")
    parser.add_argument(
        "--expect-cancellation",
        choices=("none", "deadline", "background-expiration", "any", "auto"),
        default="none",
        help="expected cancellation reason; auto accepts either cancelled or non-cancelled completion",
    )
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.self_test:
        return run_self_test()

    missing = [name for name in ("log", "journal_dir", "bundle", "mode") if getattr(args, name) is None]
    if missing:
        parser.error("missing required runtime arguments: " + ", ".join("--" + name.replace("_", "-") for name in missing))

    expectation = RuntimeExpectation(
        bundle=args.bundle,
        mode=args.mode,
        dry_run=args.dry_run,
        expect_success=args.expect_success,
        icloud_option=args.icloud_option,
        safari_option=args.safari_option,
        mail_option=args.mail_option,
        expect_cancellation=(None if args.expect_cancellation == "auto" else args.expect_cancellation),
    )
    report = validate_runtime(args.log, args.journal_dir, expectation)
    print_report(report)
    return 0 if report.passed else 1


if __name__ == "__main__":
    sys.exit(main())
