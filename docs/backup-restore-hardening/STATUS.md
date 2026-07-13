# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 0 — Reliable Command Execution
Current task: TASK-0.6 — Bound Output Query Helper and Remove NSTask Deadlock
Task file: docs/backup-restore-hardening/tasks/TASK-0.6-bounded-output-query-helper.md
Expected report: docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-0.7 remains LOCKED
Phase 1: TASK-1.1 remains LOCKED
```

## Gate Rules

TASK-0.6 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `reports/TASK-0.6-REPORT.md`.
- [ ] Code diff is limited to `AppDataCleaner.m`.
- [ ] Existing `runCommandAndGetOutput:` selector remains source-compatible.
- [ ] Private timed overload is added in `.m` only.
- [ ] Default output-query timeout is 60 seconds.
- [ ] Execution delegates to `runCommandWithPrivilegesResult:timeoutSec:`.
- [ ] No duplicate spawn/pipe/deadline implementation is added.
- [ ] Invalid or incomplete execution maps to the legacy `@"error"` sentinel.
- [ ] Normal non-zero exit is not treated as error solely because of exit code.
- [ ] stdout/stderr merge and trimming follow the task contract.
- [ ] `PXWaitForProcessExit` uses bounded per-probe execution and does not interpret `@"error"` as process exit.
- [ ] `NSTask`, `NSPipe`, `waitUntilExit` and `readDataToEndOfFile` are removed from `AppDataCleaner.m`.
- [ ] Existing command strings and caller business decisions remain unchanged.
- [ ] Direct find helpers remain unchanged for TASK-0.7.
- [ ] `AppDataCleaner.h` and `CommandRunner.h/.m` remain unchanged.
- [ ] `git diff --check` passes.
- [ ] GitHub Actions succeeds.
- [ ] Coordinator review accepts the task.

## Task History

| Task | Status | Agent report | Build | Review |
|---|---|---|---|---|
| TASK-0.1 | COMPLETED | `reports/TASK-0.1-REPORT.md` | PASSED | `reviews/TASK-0.1-REVIEW.md` — ACCEPTED |
| TASK-0.2 | COMPLETED | `reports/TASK-0.2-REPORT.md` | PASSED | `reviews/TASK-0.2-REVIEW.md` — ACCEPTED |
| TASK-0.3 | COMPLETED | `reports/TASK-0.3-REPORT.md` | COMPLETED/PASSED reported by owner | `reviews/TASK-0.3-REVIEW.md` — ACCEPTED |
| TASK-0.4 | COMPLETED | `reports/TASK-0.4-REPORT.md` | COMPLETED/PASSED reported by owner | `reviews/TASK-0.4-REVIEW.md` — ACCEPTED |
| TASK-0.5 | COMPLETED | `reports/TASK-0.5-REPORT.md` | COMPLETED/PASSED reported by owner | `reviews/TASK-0.5-REVIEW.md` — ACCEPTED |
| TASK-0.6 | READY | Not created | Not run | Not reviewed |
| TASK-0.7 | LOCKED | Not created | Not run | Not reviewed |

## Why Phase 0 Was Extended

TASK-0.5 inventory found three remaining local process-execution paths in `AppDataCleaner.m`:

1. `runCommandAndGetOutput:` uses `NSTask`, waits before draining a shared pipe, has no timeout and can deadlock.
2. `findPathsMatchingPattern:` uses direct blocking/unbounded `posix_spawn` capture.
3. `findPathsUnderRoot:directories:namePatterns:` uses direct blocking/unbounded `posix_spawn` capture.

They are split into two small build-gated tasks:

```text
TASK-0.6 — NSTask output-query compatibility migration
TASK-0.7 — direct find helper migration
```

## Blocked Work

The following work is not yet authorized:

- TASK-0.7 implementation.
- TASK-1.1 — Introduce immutable `PXResolvedContainer`.
- All later Phase 1 tasks.
- All Backup, Restore, Keychain and UI phases.

Agent must stop after TASK-0.6.
