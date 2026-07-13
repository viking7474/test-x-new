# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 1 — Clear Data Safety Boundary
Current task: TASK-1.5 — Typed PXClearRequest
Task file: docs/backup-restore-hardening/tasks/TASK-1.5-typed-clear-request.md
Expected report: docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-1.6 remains LOCKED
```

## Phase 0 Result

Phase 0 — Reliable Command Execution is complete.

Accepted outcomes:

- structured `CommandResult` contract;
- bounded stdout/stderr capture;
- monotonic deadlines;
- spawn-time process groups;
- bounded group termination and reap;
- direct executable/argv API;
- bounded cleaner compatibility wrapper;
- bounded output-query helper;
- bounded direct `find` helpers;
- no local `NSTask`, `posix_spawn`, pipe-capture or blocking `waitpid` engine remains in `AppDataCleaner.m`.

## Phase 1 Accepted Results

### TASK-1.1

Immutable `PXResolvedContainer` provides exact identity, kind/root, copied readonly values, UUID/path consistency, and immutable value semantics. It does not authorize deletion.

### TASK-1.2

Standalone `PXDataContainerResolver` provides root-specific application-data discovery, exact `MCMMetadataIdentifier` matching, deterministic enumeration and ambiguity failure. It does not migrate callers.

### TASK-1.3

Standalone `PXDestructivePathValidator` provides fixed-base authorization, POSIX canonicalization, symlink/mount/ownership checks, live metadata revalidation, final filesystem identity checks and canonical-path return semantics. It is not yet connected to Clear.

### TASK-1.4

Application bundle containers are now read-only for in-file `AppDataCleaner` Clear behavior:

- rootless bundle content wipe removed;
- application receipt deletion/recreation removed;
- extension receipt deletion removed;
- dormant private receipt mutation removed;
- public receipt selector retained as a logged compatibility no-op;
- read-only bundle discovery and inspection preserved.

Accepted review:

```text
docs/backup-restore-hardening/reviews/TASK-1.4-REVIEW.md
```

## TASK-1.5 Purpose

TASK-1.5 introduces immutable typed input for future Clear orchestration.

The request records:

- exact bundle identifier;
- requested component scopes;
- requested deep-clean intent.

It does not execute Clear, resolve containers, validate paths, import into `AppDataCleaner`, alter completion behavior or create structured results.

## TASK-1.5 Scope Model

Allowed scope bits are exactly:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
Keychain
```

There is deliberately no scope for application-bundle or receipt mutation.

The default mask is the exact union of all five known bits. Custom valid subsets are allowed; zero and unknown bits fail closed.

## TASK-1.5 Gate Rules

TASK-1.5 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `reports/TASK-1.5-REPORT.md`.
- [ ] Only `PXClearRequest.h/.m` are added as production code.
- [ ] Public scope option set contains exactly five approved bits.
- [ ] Known/default masks equal the exact union of all approved bits.
- [ ] No application-bundle scope exists.
- [ ] Public class, properties, initializer and default factory match the specification.
- [ ] Bundle identifier validation is strict, exact and non-normalizing.
- [ ] Scope mask rejects zero and unknown bits.
- [ ] Valid known subsets are preserved unchanged.
- [ ] Deep-clean value is preserved exactly.
- [ ] Default factory uses the default mask and `deepClean == NO`.
- [ ] Public properties are readonly and copied/assigned as specified.
- [ ] The object is immutable and subclassing-restricted.
- [ ] `copyWithZone:` returns `self`.
- [ ] Equality and hash use identifier, scopes and deep-clean value.
- [ ] No resolver, validator, command, filesystem, deletion, keychain or UI behavior is added.
- [ ] No existing production caller references `PXClearRequest` or `PXClearScope`.
- [ ] Makefile and protected existing source files remain unchanged.
- [ ] `git diff --check` and new-file whitespace checks pass.
- [ ] GitHub Actions succeeds or the project owner explicitly confirms the build.
- [ ] Coordinator review accepts the task.

## Task History

| Task | Status | Agent report | Build | Review |
|---|---|---|---|---|
| TASK-0.1 | COMPLETED | `reports/TASK-0.1-REPORT.md` | PASSED | `reviews/TASK-0.1-REVIEW.md` — ACCEPTED |
| TASK-0.2 | COMPLETED | `reports/TASK-0.2-REPORT.md` | PASSED | `reviews/TASK-0.2-REVIEW.md` — ACCEPTED |
| TASK-0.3 | COMPLETED | `reports/TASK-0.3-REPORT.md` | PASSED reported by owner | `reviews/TASK-0.3-REVIEW.md` — ACCEPTED |
| TASK-0.4 | COMPLETED | `reports/TASK-0.4-REPORT.md` | PASSED reported by owner | `reviews/TASK-0.4-REVIEW.md` — ACCEPTED |
| TASK-0.5 | COMPLETED | `reports/TASK-0.5-REPORT.md` | PASSED reported by owner | `reviews/TASK-0.5-REVIEW.md` — ACCEPTED |
| TASK-0.6 | COMPLETED | `reports/TASK-0.6-REPORT.md` | PASSED reported by owner | `reviews/TASK-0.6-REVIEW.md` — ACCEPTED |
| TASK-0.7 | COMPLETED | `reports/TASK-0.7-REPORT.md` | PASSED reported by owner | `reviews/TASK-0.7-REVIEW.md` — ACCEPTED |
| TASK-1.1 | COMPLETED | `reports/TASK-1.1-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.1-REVIEW.md` — ACCEPTED |
| TASK-1.2 | COMPLETED | `reports/TASK-1.2-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.2-REVIEW.md` — ACCEPTED |
| TASK-1.3 | COMPLETED | `reports/TASK-1.3-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.3-REVIEW.md` — ACCEPTED |
| TASK-1.4 | COMPLETED | `reports/TASK-1.4-REPORT.md` | accepted through owner continuation | `reviews/TASK-1.4-REVIEW.md` — ACCEPTED |
| TASK-1.5 | READY | Not created | Not run | Not reviewed |
| TASK-1.6 | LOCKED | Not created | Not run | Not reviewed |

## Why TASK-1.5 Is Standalone

The current Clear API combines one bundle identifier with many implicit component choices and a global deep-clean setting. Before migrating behavior, the program needs an immutable request object that makes the intended scope explicit.

The sequence remains:

```text
TASK-1.4 — remove application-bundle writes
TASK-1.5 — immutable typed request
TASK-1.6 — structured result object
TASK-1.7 — migrate main application-data Clear
TASK-1.8 — migrate extension/PluginKit Clear
TASK-1.9 — migrate App Group Clear
TASK-1.10 — integrate keychain result
```

Keeping TASK-1.5 model-only allows validation, scope-mask, copy and equality semantics to be reviewed independently from destructive behavior.

## Current Working-Tree Note

At coordinator review time:

```text
HEAD: a2f5de8df684fe07f5adbf12c2513d6b223fd6d2
AppDataCleaner.m: modified by accepted TASK-1.4
PXDestructivePathValidator.h/.m: untracked TASK-1.3 baseline
TASK-1.4 report/review/specification: uncommitted
```

Commit/push TASK-1.3 and TASK-1.4 before beginning TASK-1.5 so the model-only diff is independently reviewable.

If TASK-1.5 starts before those commits, the agent must treat every existing modified/untracked file as protected baseline and prove its checksum remains unchanged.

## Blocked Work

The following work is not authorized during TASK-1.5:

- importing `PXClearRequest` into `AppDataCleaner` or UI code;
- changing `clearDataForBundleID:completion:`;
- resolving or validating containers;
- invoking `PXDataContainerResolver` or `PXDestructivePathValidator`;
- deleting or mutating files;
- changing Keychain behavior;
- adding `PXClearResult`;
- changing Backup or Restore;
- TASK-1.6 or later implementation.

Agent must stop after TASK-1.5.
