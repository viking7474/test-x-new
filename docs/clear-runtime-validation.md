# AppDataCleaner runtime validation

This is the runtime gate for the Clear hardening work. It is intentionally read-only on the analysis side: the validator only reads artifacts produced by AppDataCleaner after a test run.

## Artifacts to export from the device

After each Clear test, export both:

1. `/var/mobile/Documents/AppDataCleaner.log`
2. The host application's `Library/Application Support/PXClearJournal/` directory.

`PXClearJournal` is created through `NSApplicationSupportDirectory`, so its absolute container UUID is device/install specific. Export the directory from the application that hosts `AppDataCleaner`; do not substitute another application's journal directory.

Keep the log and journal from the same test session together, for example:

```text
runtime-artifacts/
  third-party-full/
    AppDataCleaner.log
    PXClearJournal/
      clear-....plist
  mail-deep-off/
    AppDataCleaner.log
    PXClearJournal/
      clear-....plist
```

The journal files are binary plists. Do not convert them before validation.

### Optional on-device collector

If the repository script is available on the device, or you copy this single script there, use the already-known host app data-container path:

```bash
sh scripts/collect_clear_runtime_artifacts.sh \
  /var/mobile/Containers/Data/Application/KNOWN-HOST-UUID \
  /var/mobile/Documents/clear-runtime-export
```

The collector deliberately does **not** scan container roots or infer ownership. It accepts an explicit host container, refuses symlink/non-regular log or journal entries, and copies only `AppDataCleaner.log` plus regular `*.plist` journal entries. Copy the resulting export directory back to the workstation and point the validator at it.

## Validator

Run from the repository root:

```bash
python3 scripts/validate_clear_runtime.py \
  --log runtime-artifacts/third-party-full/AppDataCleaner.log \
  --journal-dir runtime-artifacts/third-party-full/PXClearJournal \
  --bundle com.example.app \
  --mode Full \
  --expect-success yes \
  --expect-cancellation none \
  --icloud-option off \
  --safari-option off \
  --mail-option off
```

On Windows use `py -3` instead of `python3` if required.

The analyzer validates the latest matching bundle/mode run in the supplied log and the latest matching journal phase. A successful normal run requires the completion path, step metrics, all five component results, balanced attempted/succeeded/failed counters, the expected verification strategy, final success metric and policy snapshot.

## Cancellation tests

Deadline/watchdog cancellation:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log \
  --journal-dir PXClearJournal \
  --bundle com.example.app \
  --mode Full \
  --expect-success no \
  --expect-cancellation deadline \
  --icloud-option off \
  --safari-option off \
  --mail-option off
```

Background-task expiration:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log \
  --journal-dir PXClearJournal \
  --bundle com.example.app \
  --mode Full \
  --expect-success no \
  --expect-cancellation background-expiration \
  --icloud-option off \
  --safari-option off \
  --mail-option off
```

A cancellation is allowed to stop before `COMPLETED`, verification, or all five component result lines. It must still end through `safeCompletion`, emit final `success=0`, and emit the machine-readable cancellation metric. Deadline cancellation additionally requires watchdog evidence.

Use `--expect-cancellation any` when the run must cancel but the source is intentionally nondeterministic. Use `auto` only for exploratory log analysis; release validation should name the expected behavior.

## Dry run

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log \
  --journal-dir PXClearJournal \
  --bundle com.example.app \
  --mode Deep \
  --dry-run \
  --expect-success yes \
  --icloud-option off \
  --safari-option off \
  --mail-option off
```

Dry-run validation requires `dry_run_plan` and `dry_run_commit`, checks the effective `wouldClear...` actions, and rejects evidence that kill/Keychain/app-state/data-aggregate destructive steps ran.

## Required device matrix

Run at least the following before treating the hardening change as runtime-validated:

| Scenario | Target | Mode | Options | Expected |
|---|---|---|---|---|
| Quick baseline | ordinary third-party app | Quick | all OFF | success, component manifest; extended containers skipped |
| Full baseline | ordinary third-party app | Full | all OFF | success, component manifest |
| Deep baseline | ordinary third-party app | Deep | all OFF | success, deep residual scan |
| Rootless/rootful | app with the relevant data root | Full/Deep | all OFF | exact resolved root wiped, strict postcondition passes |
| Extension/App Group | app declaring extensions/groups | Full/Deep | all OFF | exact extension, PluginKit and App Group units accounted |
| Keychain selected groups | app with known signed groups | Full/Deep | Keychain enabled/selected | selected groups cleared and exact list verification passes |
| Safari policy OFF | `com.apple.mobilesafari` | Deep | Safari OFF | shared Safari/WebKit stores preserved |
| Safari policy ON | `com.apple.mobilesafari` | Deep | Safari ON | explicit shared cleanup reaches terminal result; no Accounts3 mutation |
| Mail policy OFF | `com.apple.mobilemail` | Deep | Mail OFF | `/var/mobile/Library/Mail` preserved; Accounts3 BLOCKED marker present |
| Mail policy ON | `com.apple.mobilemail` | Deep | Mail ON | detached Mail store removed/verified; Accounts3 still BLOCKED |
| iCloud policy OFF | non-system app | Full/Deep | iCloud OFF | exact iCloud/Accounts policy skipped |
| iCloud policy ON | non-system app with signed iCloud entitlement | Full/Deep | iCloud ON | only signed direct-child container mapping used; exact non-system Accounts3 semantics applied |
| Watchdog cancellation | controllably slow test | suitable mode | snapshot as configured | final success=0, reason `deadline`, watchdog evidence |
| Background expiration | run app into background-expiration path | suitable mode | snapshot as configured | final success=0, reason `background-expiration`, no watchdog mislabel |

For system targets, **do not use the iCloud option to bypass the dedicated system-cloud block**.

## Safari commands

Policy OFF:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log --journal-dir PXClearJournal \
  --bundle com.apple.mobilesafari --mode Deep \
  --expect-success yes --expect-cancellation none \
  --safari-option off --icloud-option off --mail-option off
```

Policy ON:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log --journal-dir PXClearJournal \
  --bundle com.apple.mobilesafari --mode Deep \
  --expect-success yes --expect-cancellation none \
  --safari-option on --icloud-option off --mail-option off
```

The validator checks that the explicit Safari branch is used. The production policy must continue to exclude `accountsd`, `nsurlsessiond`, `webbookmarksd`, `cfprefsd`, global CFNetwork caches and SafariSafeBrowsing.

## MobileMail commands

Policy OFF:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log --journal-dir PXClearJournal \
  --bundle com.apple.mobilemail --mode Deep \
  --expect-success yes --expect-cancellation none \
  --mail-option off --icloud-option off --safari-option off
```

Policy ON:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log --journal-dir PXClearJournal \
  --bundle com.apple.mobilemail --mode Deep \
  --expect-success yes --expect-cancellation none \
  --mail-option on --icloud-option off --safari-option off
```

For every Deep MobileMail run the validator requires:

```text
MobileMail: Accounts3 destructive cleanup BLOCKED (shared account ownership policy)
```

and rejects evidence of an `Accounts3 exact cleanup committed rows=...` path. The Mail shared-store option does not authorize Accounts3 mutation.

## iCloud commands

Policy OFF:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log --journal-dir PXClearJournal \
  --bundle com.example.icloudapp --mode Full \
  --expect-success yes --expect-cancellation none \
  --icloud-option off --safari-option off --mail-option off
```

Policy ON:

```bash
python3 scripts/validate_clear_runtime.py \
  --log AppDataCleaner.log --journal-dir PXClearJournal \
  --bundle com.example.icloudapp --mode Full \
  --expect-success yes --expect-cancellation none \
  --icloud-option on --safari-option off --mail-option off
```

Use a non-system test app whose signed entitlements are known. If the app has a signed iCloud identifier that the implementation cannot map safely, failure is expected/fail-closed rather than a reason to broaden path matching.

## Interpreting failures

Treat analyzer failures as evidence first, not as a reason to weaken ownership checks. Preserve the log and journal pair and inspect the first failed invariant/component.

Especially do not fix a runtime failure by reintroducing:

- bundle-name substring/prefix ownership;
- wildcard shared-directory deletion;
- arbitrary global daemon/cache mutation;
- fire-and-forget destructive shell execution;
- MobileMail Accounts3 destructive SQL.

If a test is intentionally a negative/failure scenario, pass `--expect-success no`. If it is intentionally a cancellation scenario, also name `--expect-cancellation deadline`, `background-expiration`, or `any`.

## Analyzer self-test

Before analyzing device artifacts:

```bash
python3 scripts/validate_clear_runtime.py --self-test
```

The self-test covers a successful Full run, a completed component failure, a policy mismatch, a Deep dry-run, a deadline cancellation that stops before normal completion, and the MobileMail Accounts3 BLOCKED invariant.
