# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 1 — Clear Data Safety Boundary
Current task: TASK-1.6 — Structured PXClearResult
Task file: docs/backup-restore-hardening/tasks/TASK-1.6-structured-clear-result.md
Expected report: docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-1.7 remains LOCKED
```

## Accepted Foundation

### Phase 0 — Reliable Command Execution

Completed outcomes:

- structured `CommandResult`;
- bounded stdout/stderr capture;
- monotonic deadlines;
- spawn-time process groups;
- bounded process-group termination and reap;
- direct executable/argv API;
- bounded `AppDataCleaner` compatibility wrappers;
- bounded direct `find` helpers;
- no local `NSTask`, pipe-capture, `posix_spawn` or blocking `waitpid` engine remains in `AppDataCleaner.m`.

### TASK-1.1 — Immutable resolved identity

`PXResolvedContainer` provides immutable exact container identity and lexical candidate-path invariants. It is not deletion authorization.

### TASK-1.2 — Exact application-data resolver

`PXDataContainerResolver` resolves one root at a time using exact `MCMMetadataIdentifier` matching and fails closed on ambiguity.

### TASK-1.3 — Canonical destructive-path validator

`PXDestructivePathValidator` provides fixed-base authorization, canonical containment, symlink/mount/ownership checks, live metadata revalidation and final device/inode rechecks.

### TASK-1.4 — Application bundles are read-only

`AppDataCleaner` no longer:

- wipes rootless application-bundle contents;
- deletes or recreates app receipts;
- deletes extension receipts;
- retains the dormant private receipt-wipe implementation.

The public receipt selector remains as a logged compatibility no-op. Remaining application-bundle references are read-only discovery or inspection.

### TASK-1.5 — Typed immutable request

`PXClearRequest` provides:

- exact validated bundle identifier;
- closed five-bit component scope mask;
- explicit deep-clean intent;
- immutable copy/equality/hash semantics;
- no application-bundle or receipt scope;
- no caller integration.

Accepted review:

```text
docs/backup-restore-hardening/reviews/TASK-1.5-REVIEW.md
```

Accepted commit:

```text
24cde1e — task 1.5
```

The commit contains accumulated prior-task artifacts, so future tasks should return to one commit per task.

## TASK-1.6 Purpose

TASK-1.6 introduces immutable structured output for future Clear orchestration.

The contract contains three classes in `PXClearResult.h/.m`:

1. `PXClearFailure` — stable domain/code/message snapshot;
2. `PXClearComponentResult` — one final outcome for one requested scope;
3. `PXClearResult` — aggregate covering every requested scope exactly once.

No existing Clear caller is changed in this task.

## TASK-1.6 Status Model

Allowed component statuses are exactly:

```text
Succeeded
Skipped
Failed
```

There is no pending, running, unknown, cancelled or partial status.

Partial success is represented by:

```text
status = Failed
succeededUnitCount > 0
failedUnitCount > 0
```

## TASK-1.6 Aggregate Model

The aggregate must:

- contain exactly one component result for every bit in `request.scopes`;
- contain no unrequested component;
- reject duplicates and missing scopes;
- store components in numeric scope order;
- derive `succeededScopes`, `skippedScopes` and `failedScopes` internally;
- expose `hasFailures` and `allRequestedScopesSucceeded` with exact, non-overlapping meanings.

A skipped component is not a failure, but it prevents all requested scopes from being classified as succeeded.

TASK-1.6 does not map these predicates to the legacy `BOOL success` completion callback.

## TASK-1.6 Gate Rules

TASK-1.6 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `PXClearResult.h` and `PXClearResult.m`.
- [ ] Agent creates `reports/TASK-1.6-REPORT.md`.
- [ ] Existing production source remains unchanged.
- [ ] Header imports `PXClearRequest.h` and Foundation only.
- [ ] Component status enum contains exactly three approved values.
- [ ] `PXClearFailure` stores only validated domain/code/message.
- [ ] `PXClearComponentResult` accepts exactly one known scope bit.
- [ ] Count partition is checked without overflow-prone addition.
- [ ] Succeeded/Skipped/Failed invariants match the task specification.
- [ ] Skipped components require a detail.
- [ ] Failed components require a failure snapshot and at least one failed unit.
- [ ] Partial success uses Failed plus mixed counts.
- [ ] Aggregate covers request scopes exactly once.
- [ ] Missing, duplicate and unrequested scopes are rejected.
- [ ] Component storage order is canonical by scope.
- [ ] Derived masks are disjoint and cover the request mask.
- [ ] `hasFailures` means `failedScopes != 0`.
- [ ] `allRequestedScopesSucceeded` means `succeededScopes == request.scopes`.
- [ ] Scope lookup accepts only one known requested bit.
- [ ] All three classes are immutable, subclassing-restricted and value-semantic.
- [ ] No `NSError`/`userInfo` is stored as public result state.
- [ ] No filesystem, command, resolver, validator, keychain, UI or Clear execution behavior exists.
- [ ] No existing production caller references the new result model.
- [ ] Protected checksums remain unchanged.
- [ ] `git diff --check`, new-file whitespace and NUL checks pass.
- [ ] GitHub Actions succeeds or project owner explicitly confirms build.
- [ ] Coordinator review accepts the task.

## Task History

| Task | Status | Report | Build | Review |
|---|---|---|---|---|
| TASK-0.1 | COMPLETED | `reports/TASK-0.1-REPORT.md` | PASSED | ACCEPTED |
| TASK-0.2 | COMPLETED | `reports/TASK-0.2-REPORT.md` | PASSED | ACCEPTED |
| TASK-0.3 | COMPLETED | `reports/TASK-0.3-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.4 | COMPLETED | `reports/TASK-0.4-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.5 | COMPLETED | `reports/TASK-0.5-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.6 | COMPLETED | `reports/TASK-0.6-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-0.7 | COMPLETED | `reports/TASK-0.7-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.1 | COMPLETED | `reports/TASK-1.1-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.2 | COMPLETED | `reports/TASK-1.2-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.3 | COMPLETED | `reports/TASK-1.3-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.4 | COMPLETED | `reports/TASK-1.4-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.5 | COMPLETED | `reports/TASK-1.5-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.5-REVIEW.md` |
| TASK-1.6 | READY | Not created | Not run | Not reviewed |
| TASK-1.7 | LOCKED | Not created | Not run | Not reviewed |

## Migration Sequence

```text
TASK-1.5 — immutable typed request
TASK-1.6 — immutable structured result
TASK-1.7 — migrate main application-data Clear
TASK-1.8 — migrate extension and PluginKit data Clear
TASK-1.9 — migrate App Group Clear
TASK-1.10 — integrate Keychain result
TASK-1.11 — remove unsafe permission and marker behavior
TASK-1.12 — quarantine ambiguous legacy Clear APIs
```

Request and result contracts must be accepted before destructive caller migration begins.

## Working-Tree Baseline

At the opening of TASK-1.6:

```text
HEAD: 24cde1e978ca914d49cd1ae6427085cc3e3389c1
Working tree: clean before coordinator documentation updates
```

TASK-1.6 must treat the complete commit as protected baseline and create only its two new production files plus its report.

## Blocked Work

The following work is not authorized during TASK-1.6:

- importing the result into `AppDataCleaner`;
- adding or changing a Clear API;
- mapping structured result predicates to legacy completion success;
- resolving or validating containers;
- deleting, writing, renaming, chmod/chown or executing commands;
- changing Keychain behavior;
- changing Backup, Restore or UI;
- editing `PXClearRequest`;
- starting TASK-1.7 or later work.

Agent must stop after TASK-1.6.
