# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 1 — Clear Data Safety Boundary
Current task: TASK-1.7 — Migrate Main Application-Data Clear
Task file: docs/backup-restore-hardening/tasks/TASK-1.7-migrate-main-application-data-clear.md
Expected report: docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-1.8 remains LOCKED
```

## Accepted Foundation

### Phase 0 — Reliable Command Execution

Phase 0 is complete. Critical command execution now has:

- structured `CommandResult`;
- bounded stdout/stderr;
- monotonic deadlines;
- spawn-time process groups;
- bounded group termination and reap;
- direct executable/argv support;
- bounded cleaner wrappers;
- bounded direct `find` helpers.

### TASK-1.1 — Immutable resolved identity

`PXResolvedContainer` stores exact immutable container identity and lexical candidate-path state. It does not authorize deletion.

### TASK-1.2 — Exact application-data resolver

`PXDataContainerResolver` resolves application-data containers one root at a time using exact `MCMMetadataIdentifier` equality and fails closed on ambiguity.

### TASK-1.3 — Canonical destructive-path validator

`PXDestructivePathValidator` enforces fixed bases, canonical immediate-child containment, symlink rejection, mount/device boundaries, ownership/mode checks, live metadata identity and final inode rechecks.

### TASK-1.4 — Application bundles read-only

Active writes to application bundle containers were removed. Receipt APIs remain compatibility no-ops and remaining bundle discovery is read-only.

### TASK-1.5 — Typed immutable request

`PXClearRequest` provides:

- exact bundle identifier;
- closed component scope mask;
- explicit deep-clean intent;
- no application-bundle scope;
- immutable value semantics.

### TASK-1.6 — Structured immutable result

`PXClearResult.h/.m` provide:

```text
PXClearFailure
PXClearComponentResult
PXClearResult
```

Component statuses are exactly:

```text
Succeeded
Skipped
Failed
```

The result model enforces:

- one known bit per component;
- overflow-safe unit partitions;
- status-specific invariants;
- Failed plus mixed counts for partial success;
- exact aggregate request-scope coverage;
- canonical component ordering;
- derived success/skip/failure masks;
- immutable copy/equality/hash semantics.

Accepted commit:

```text
81de2a7ef28f862f78a7ae55f0d8897066a85f94 — task-1.6
```

Accepted review:

```text
docs/backup-restore-hardening/reviews/TASK-1.6-REVIEW.md
```

Build:

```text
PASSED — reported by project owner
```

## TASK-1.7 Purpose

The current main Clear flow still selects application-data targets with legacy directory listings and UUID finders, reconstructs raw rootful/rootless paths and executes void command helpers that do not propagate operation failure.

TASK-1.7 migrates only the primary application-data component to:

1. an application-data-only `PXClearRequest` context;
2. exact rootful/rootless resolution;
3. immediate canonical validation;
4. canonical-path-only mutation;
5. one bounded command per root;
6. post-command revalidation and strict postconditions;
7. one `PXClearComponentResult`;
8. legacy completion failure when the primary application-data component fails.

## Unit Policy

The deterministic unit order is:

```text
1. rootful application-data root
2. rootless application-data root
```

A root absent with no resolver error does not count as attempted.

A resolver, validator, command, revalidation or postcondition error counts as one attempted failed unit.

A successful validated wipe counts as one succeeded unit.

One root may succeed while the other fails. Both are processed; the final component status is Failed with mixed counts.

## Result Policy

### Succeeded

At least one exact container exists and every attempted root succeeds.

### Skipped

Both supported roots have no exact container and no resolver error.

Required detail:

```text
No exact application-data container exists in either supported root
```

Skipped is not a legacy completion failure.

### Failed

Any root fails resolution, validation, bounded execution, revalidation or postcondition checking.

The first stable failure snapshot is retained; all root outcomes are summarized without filesystem paths or shell commands.

## Completion Policy

`clearDataForBundleID:completion:` must consume the application-data component result.

```text
ApplicationData Failed  -> legacy completion NO
ApplicationData Success -> preserve existing remaining completion policy
ApplicationData Skipped -> preserve existing remaining completion policy
```

If application-data and Keychain both fail, application-data failure is returned and the Keychain failure is logged.

TASK-1.7 does not otherwise redesign the legacy completion callback.

## Canonical Mutation Boundary

For each root:

```text
exact resolver
  -> pre-command validator
  -> canonical path
  -> one bounded strict wipe command
  -> post-command validator
  -> filesystem postcondition
```

The main path must not mutate using:

- a legacy UUID finder;
- `container.containerPath` after validation;
- reconstructed `/var/mobile` paths;
- raw UUID path formatting;
- generic `completelyWipeContainer:`;
- the void command wrapper.

## Strict Wipe Requirement

The migrated script must preserve MCM metadata, remove every other immediate child, recreate only `Documents`, `Library` and `tmp`, and return nonzero when required removal or recreation fails.

It must not:

- mask required operations with `|| true`;
- recursively set mode `0777`;
- create `.nomedia`, `.initialized` or other marker files;
- replace the container directory;
- modify metadata.

A command result alone is not proof of success. The validator must run again and the postcondition must verify the exact allowed top-level state and empty required directories.

## Canonical Cache Migration

Raw main-container cache fields:

```text
_wipeCacheDataUUID
_wipeCacheRootlessDataUUID
```

must be replaced by copied canonical paths, recommended:

```text
_wipeCacheApplicationDataCanonicalPaths
```

Main verification and final read-only sweep must use these canonical paths directly.

Extension and App Group cache schemas remain unchanged.

## TASK-1.7 Gate Rules

TASK-1.7 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `reports/TASK-1.7-REPORT.md`.
- [ ] Only `AppDataCleaner.m` changes as production source.
- [ ] `AppDataCleaner.h` remains unchanged.
- [ ] Required resolver, validator, request and result imports exist only in `.m`.
- [ ] Main flow constructs an application-data-only request with captured deep-clean intent.
- [ ] Rootful and rootless are processed independently in fixed order.
- [ ] No-match roots do not count as attempted.
- [ ] Resolver/validator/command/postcondition errors count as failed units.
- [ ] Legacy application-data finders do not select the main target.
- [ ] Canonical validator output is the only main mutation path.
- [ ] One bounded result-returning command is used per validated root.
- [ ] Required command operations cannot be masked into unconditional success.
- [ ] Command truncation is treated as failure.
- [ ] Validator runs again after a successful command.
- [ ] Required filesystem postcondition is checked.
- [ ] One structured ApplicationData component result is produced.
- [ ] Partial root success is represented as Failed with mixed counts.
- [ ] Failed application-data result propagates to legacy completion.
- [ ] Skipped application-data result does not fail legacy completion.
- [ ] Raw UUID wipe cache is replaced by canonical path cache.
- [ ] Main verification uses canonical cache paths.
- [ ] Redundant raw HTTPStorages wipe is removed.
- [ ] No later main-path helper bypasses the validated application-data boundary.
- [ ] Extension/PluginKit/App Group behavior is not migrated.
- [ ] Keychain is not converted to a component result.
- [ ] Application-bundle read-only gates remain true.
- [ ] Generic destructive helper implementations remain unchanged.
- [ ] All protected checksums remain unchanged.
- [ ] `git diff --check`, whitespace and NUL checks pass.
- [ ] GitHub Actions succeeds or owner confirms build.
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
| TASK-1.5 | COMPLETED | `reports/TASK-1.5-REPORT.md` | PASSED reported by owner | ACCEPTED |
| TASK-1.6 | COMPLETED | `reports/TASK-1.6-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.6-REVIEW.md` |
| TASK-1.7 | READY | Not created | Not run | Not reviewed |
| TASK-1.8 | LOCKED | Not created | Not run | Not reviewed |

## Working-Tree Baseline

Expected starting point:

```text
HEAD: 81de2a7ef28f862f78a7ae55f0d8897066a85f94
Production working tree: clean
Coordinator documentation: may be modified/untracked
```

Commit coordinator documentation before TASK-1.7 when practical. Otherwise the agent must treat it as protected baseline and isolate the `AppDataCleaner.m` diff.

## Blocked Work

TASK-1.7 does not authorize:

- a public typed Clear API;
- full aggregate results for all scopes;
- extension or PluginKit migration;
- App Group migration;
- Keychain component-result integration;
- application-bundle mutation;
- Backup/Restore/UI changes;
- public legacy API removal;
- generic helper redesign;
- TASK-1.8 or later implementation.

Agent must stop after TASK-1.7.
