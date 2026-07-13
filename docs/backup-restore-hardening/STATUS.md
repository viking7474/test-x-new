# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 0 — Reliable Command Execution
Current task: TASK-0.7 — Bounded Direct Find Helpers
Task file: docs/backup-restore-hardening/tasks/TASK-0.7-bounded-direct-find-helpers.md
Expected report: docs/backup-restore-hardening/reports/TASK-0.7-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-1.1 remains LOCKED
```

## Gate Rules

TASK-0.7 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `reports/TASK-0.7-REPORT.md`.
- [ ] Code diff is limited to `AppDataCleaner.m`.
- [ ] Existing two find selectors and all callers remain unchanged.
- [ ] Both helpers use the shared bounded direct executable/argv API.
- [ ] Executable remains exact `/usr/bin/find`.
- [ ] Timeout is 120 seconds per invocation.
- [ ] Output cap is 4 MiB per stream.
- [ ] No shell is used for find execution.
- [ ] Timeout, signal, runner/spawn failure and truncation return `@[]`.
- [ ] Normal non-zero exit is not rejected solely by exit code.
- [ ] Only stdout is parsed as paths.
- [ ] Existing find expressions, order and duplicate behavior remain unchanged.
- [ ] Manual pipe/spawn/read/wait and C argv ownership are removed.
- [ ] `AppDataCleaner.m` has zero active `posix_spawn` and `waitpid` calls.
- [ ] `AppDataCleaner.h` and `CommandRunner.h/.m` remain unchanged.
- [ ] No Clear, Backup, Restore, Keychain or UI behavior is changed.
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
| TASK-0.6 | COMPLETED | `reports/TASK-0.6-REPORT.md` | COMPLETED/PASSED reported by owner | `reviews/TASK-0.6-REVIEW.md` — ACCEPTED |
| TASK-0.7 | READY | Not created | Not run | Not reviewed |

## Why TASK-0.7 Is Required

TASK-0.6 removed the final `NSTask` execution path, but two direct local process engines still remain in `AppDataCleaner.m`:

1. `findPathsMatchingPattern:`
2. `findPathsUnderRoot:directories:namePatterns:`

Together they still contain:

```text
posix_spawn(: 2
waitpid(: 2
pipe(: 2
blocking raw read loops: 2
```

They have no deadline, no output cap, no process-group timeout cleanup and one helper manually constructs borrowed C argv pointers.

TASK-0.7 migrates both helpers to the accepted direct executable/argv API and finishes local process-execution hardening before destructive path work begins.

## Blocked Work

The following work is not yet authorized:

- TASK-1.1 — Introduce immutable `PXResolvedContainer`.
- All later Phase 1 tasks.
- All Backup, Restore, Keychain and UI phases.
- Any `PXProcessKiller` or keychain command migration.

Agent must stop after TASK-0.7.
