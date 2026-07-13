# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 1 — Clear Data Safety Boundary
Current task: TASK-1.3 — Canonical Destructive Path Validator
Task file: docs/backup-restore-hardening/tasks/TASK-1.3-canonical-destructive-path-validator.md
Expected report: docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-1.4 remains LOCKED
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

## TASK-1.1 Result

TASK-1.1 introduced immutable `PXResolvedContainer` with:

- exact requested/metadata identity;
- explicit data-container kind and root;
- copied readonly string fields;
- UUID and lexical path consistency checks;
- immutable copy/equality/hash semantics;
- no filesystem authorization, resolver or deletion logic.

The model remains an identity snapshot only.

## TASK-1.2 Result

TASK-1.2 introduced standalone `PXDataContainerResolver` with:

- root-specific application-data discovery;
- fixed rootful and rootless bases;
- immediate UUID-directory enumeration;
- exact string `MCMMetadataIdentifier` matching;
- no fuzzy/content/name heuristics;
- explicit invalid-input, enumeration, ambiguity and invalid-candidate errors;
- zero-match as a normal nil/no-error result;
- no caller migration or deletion behavior.

The resolver result remains a candidate. It is not safe to use destructively until TASK-1.3 returns a validated canonical path.

At coordinator review time, the following remain untracked rather than isolated in dedicated commits:

```text
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
TASK-1.1 and TASK-1.2 reports
related coordinator task/review documentation
```

Commit/push TASK-1.1 and TASK-1.2 before beginning TASK-1.3 so validator changes are independently reviewable.

## TASK-1.3 Gate Rules

TASK-1.3 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `reports/TASK-1.3-REPORT.md`.
- [ ] Only `PXDestructivePathValidator.h/.m` are added as production changes.
- [ ] Public validator API and exact error enum match the specification.
- [ ] Success returns a canonical NSString path, not a raw candidate or boolean.
- [ ] All four data-container kinds and both roots map to fixed allow-list bases.
- [ ] Application bundle has no kind/base mapping.
- [ ] Raw candidate must exactly equal fixed base plus UUID.
- [ ] Candidate is inspected with `lstat` before canonicalization.
- [ ] Candidate symlinks and non-directories are rejected.
- [ ] Fixed base, candidate and metadata are canonicalized with POSIX semantics.
- [ ] Canonical candidate is exactly one immediate child of canonical base.
- [ ] Prefix-only containment is not used.
- [ ] Initial and canonical candidate inode/device identities agree.
- [ ] Candidate and canonical base are on the same device.
- [ ] Mobile UID ownership policy is enforced.
- [ ] World-writable base/candidate/metadata modes are rejected.
- [ ] Metadata is a same-device, mobile-owned, non-world-writable regular file and not a symlink.
- [ ] Only `.com.apple.mobile_container_manager.metadata.plist` is accepted.
- [ ] Live metadata exact identity is revalidated.
- [ ] AppGroup string/array exact identity policy is implemented.
- [ ] Candidate and metadata inode/device state is rechecked before return.
- [ ] No raw or partially validated path is returned on failure.
- [ ] No existing caller references the validator.
- [ ] No deletion, permission-changing, shell, process or command API is introduced.
- [ ] `PXResolvedContainer`, resolver, Makefile and all protected source files remain unchanged.
- [ ] Clear, Backup, Restore, Keychain and UI behavior remain unchanged.
- [ ] `git diff --check` and new-file whitespace checks pass.
- [ ] GitHub Actions succeeds.
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
| TASK-1.3 | READY | Not created | Not run | Not reviewed |
| TASK-1.4 | LOCKED | Not created | Not run | Not reviewed |

## Why TASK-1.3 Is Standalone

A `PXResolvedContainer` proves lexical consistency and exact stored identity. `PXDataContainerResolver` proves that one live metadata record matched during discovery. Neither proves that the path is still safe at the time a destructive operation begins.

TASK-1.3 centralizes:

- kind/root fixed-base allow-listing;
- exact raw-path equality;
- symlink rejection;
- canonical immediate-child containment;
- mount/device boundary checks;
- mobile ownership and mode checks;
- metadata-file safety;
- live identity revalidation;
- final inode/device rechecks;
- canonical-path return semantics.

It deliberately does not connect the path to deletion. That keeps safety-boundary correctness separate from the behavior changes planned in TASK-1.4 and later caller migrations.

## Blocked Work

The following work is not authorized during TASK-1.3:

- importing the validator into `AppDataCleaner`;
- using validator output for deletion;
- removing application-bundle writes;
- changing or removing fuzzy legacy resolvers;
- migrating raw UUID/path callers;
- adding typed `PXClearRequest` or `PXClearResult`;
- application-data, extension, app-group or PluginKit Clear migration;
- Backup, Restore, Keychain or UI changes;
- TASK-1.4 or later implementation.

Agent must stop after TASK-1.3.
