# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 1 — Clear Data Safety Boundary
Current task: TASK-1.10 — Integrate Keychain Clear Result Correctly
Task file: docs/backup-restore-hardening/tasks/TASK-1.10-integrate-keychain-clear-result.md
Expected report: docs/backup-restore-hardening/reports/TASK-1.10-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-1.11 remains LOCKED
```

## Accepted foundation

### Phase 0 — Reliable Command Execution

Completed outcomes:

- structured `CommandResult`;
- bounded stdout/stderr capture;
- monotonic deadlines;
- spawn-time process groups;
- bounded process-group termination and reap;
- direct executable/argv support;
- bounded `AppDataCleaner` command wrappers;
- bounded direct `find` helpers.

### TASK-1.1 through TASK-1.6 — Safety contracts

Accepted infrastructure:

- immutable exact `PXResolvedContainer` identity;
- root-specific exact data-container resolution;
- canonical destructive-path validation;
- application-bundle containers are read-only;
- immutable typed `PXClearRequest`;
- immutable structured `PXClearResult`.

### TASK-1.7 — ApplicationData

Rootful and rootless ApplicationData use:

```text
exact resolver
  -> canonical validator
  -> one bounded strict command
  -> post-command validator
  -> strict postcondition
  -> structured component result
```

### TASK-1.8 and TASK-1.8A — ExtensionData and PluginKitData

Accepted outcomes:

- installed extension identifiers come from exact contained `.appex` bundles;
- ExtensionData and PluginKitData use exact metadata resolution;
- generic resolver compatibility with TASK-1.2 is preserved;
- raw extension UUID caches are replaced by canonical paths;
- callback precedence is deterministic.

### TASK-1.9 — AppGroups

Accepted commit:

```text
0bb2e354715e00f20c4df95719e900ae5e8e1673
```

Accepted review:

```text
docs/backup-restore-hardening/reviews/TASK-1.9-REVIEW.md
```

Build:

```text
PASSED — reported by project owner
```

Accepted AppGroups boundary:

```text
signed application-group entitlements
  -> root-specific exact typed resolver
  -> canonical validator
  -> unique physical-container plan
  -> one bounded strict command per canonical path
  -> every alias identity revalidated
  -> strict postcondition
  -> structured AppGroups component
```

The internal data aggregate now contains exactly:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
```

App Group mutation through legacy fuzzy resolvers, raw UUID reconstruction, deep encrypted scans, final sweeps and MobileSafari Shared/AppGroup fallbacks is no longer reachable from the migrated main Clear path.

## TASK-1.10 purpose

Keychain is the final approved `PXClearScope` still outside the structured full Clear result.

Current main Clear behavior is split across two loose calls:

```text
initial _wipeSelectedKeychainForBundleID
four-scope data aggregate
final _wipeSelectedKeychainForBundleID
separate BOOL/error callback branch
```

This causes ambiguity and false success because:

- disabled and succeeded both return `YES`;
- explicit empty selection is replaced with all groups;
- settings and entitlements can be reread differently between passes;
- selected groups are not exact-checked against signed authorization;
- non-system helper execution is unbounded;
- helper warnings can still exit zero;
- the system bridge always reports success after wipe requests;
- callback outcome is not derived from one final `PXClearResult`.

TASK-1.10 must create a truthful Keychain component and one final five-scope aggregate.

## Full Clear result boundary

`clearDataForBundleID:completion:` must use:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
Keychain
```

The existing four-scope data operation remains separate and unchanged.

`completeAppDataWipe:` remains data-only and must not gain Keychain side effects.

## Keychain plan policy

One immutable request-scoped plan captures:

- enable flag;
- exact selected setting object;
- signed exact authorized groups;
- signed application identifier when required;
- system-app transport policy;
- planned pass count.

The plan is created once and reused by every pass.

Identity authorization comes only from signed:

```text
keychain-access-groups
application-identifier
```

Selected groups must be an exact subset of the signed set.

No hard-coded vendor groups, bundle-prefix inference, service/account matching or existing item inspection may authorize the typed flow.

## Empty selection policy

```text
saved setting absent -> default to all signed authorized groups
saved NSArray         -> exact selection, including empty
saved malformed value -> planning failure
```

An explicit empty array produces:

```text
Keychain Skipped 0/0/0
No keychain access groups are selected
```

It must not silently become all groups.

## Pass accounting

### Non-system application

```text
initial pass
final pass
```

Both passes use the same plan. The final pass still runs after an initial failure.

### System application

```text
one bridge pass
```

The current intentional second-pass skip is preserved and does not count as a unit.

### Outcomes

```text
disabled / empty / no authorized groups -> Skipped 0/0/0
planning failure                         -> Failed 1/0/1
non-system full success                  -> Succeeded 2/2/0
non-system partial failure               -> Failed 2/1/1
non-system total failure                 -> Failed 2/0/2
system success                           -> Succeeded 1/1/0
system failure                           -> Failed 1/0/1
```

## Execution evidence

Non-system signing and helper wipe must use bounded direct executable/argv calls.

The helper wipe action must return nonzero when:

- `itemsFailed > 0`; or
- warnings are present.

The system bridge must report:

```text
attempted
succeeded
failed
ok
```

and may set `ok` only for a complete failure-free partition.

AppDataCleaner must reject stale, malformed or partial bridge responses.

## Callback policy

After TASK-1.10, callback failure precedence is:

```text
1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData
5. Keychain
```

The final five-scope result is the only component-based callback source.

Skipped components are not callback failures. Therefore callback success is based on absence of failed components, not `allRequestedScopesSucceeded`.

## TASK-1.10 gate rules

TASK-1.10 may move to `COMPLETED` only when all conditions are met:

- [ ] Agent creates `reports/TASK-1.10-REPORT.md`.
- [ ] Only the five allowed production files change.
- [ ] Four-scope data mask remains exact and unchanged.
- [ ] Five-scope full mask is added exactly.
- [ ] Full Clear request contains all five scopes.
- [ ] `completeAppDataWipe:` remains four-scope and data-only.
- [ ] One immutable Keychain plan is captured before the initial pass.
- [ ] Settings and entitlements are not reread between passes.
- [ ] Signed exact groups are the only typed authorization.
- [ ] Selected groups are an exact subset of signed authorization.
- [ ] Explicit empty selection remains empty and produces Skipped.
- [ ] Malformed/unauthorized configuration fails closed.
- [ ] System policy denial remains failure when Keychain was requested.
- [ ] Non-system uses two exact pass units.
- [ ] System uses one exact bridge pass unit.
- [ ] Planning, success, partial and total failure counts are exact.
- [ ] Non-system ldid and helper execution are bounded and direct.
- [ ] Temporary artifacts are cleaned on every path.
- [ ] Raw stdout/stderr/group values are not persisted.
- [ ] `backup_helper` exits nonzero for warnings or failed items.
- [ ] System bridge reports real operation counts.
- [ ] AppDataCleaner validates full bridge response identity and partition.
- [ ] KeychainGroups UI preserves an explicit empty selection.
- [ ] Clear confirmation preserves an explicit empty selection.
- [ ] Final aggregate contains exactly five components.
- [ ] Callback error comes only from final aggregate precedence.
- [ ] Separate `keychainOK1/keychainOK2/keychainFailed` callback logic is removed.
- [ ] Extension Keychain, Backup and Restore remain out of scope.
- [ ] Protected files remain unchanged.
- [ ] `git diff --check`, whitespace and NUL gates pass.
- [ ] GitHub Actions succeeds or owner confirms build.
- [ ] Coordinator review accepts the task.

## Task history

| Task | Status | Report | Build | Review |
|---|---|---|---|---|
| TASK-0.1 through TASK-0.7 | COMPLETED | Present | PASSED | ACCEPTED |
| TASK-1.1 through TASK-1.6 | COMPLETED | Present | PASSED reported by owner | ACCEPTED |
| TASK-1.7 | COMPLETED | `reports/TASK-1.7-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.7-REVIEW.md` |
| TASK-1.8 | COMPLETED | `reports/TASK-1.8-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.8-REVIEW.md` plus corrective acceptance |
| TASK-1.8A | COMPLETED | `reports/TASK-1.8A-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.8A-REVIEW.md` |
| TASK-1.9 | COMPLETED | `reports/TASK-1.9-REPORT.md` | PASSED reported by owner | `reviews/TASK-1.9-REVIEW.md` |
| TASK-1.10 | READY | Not created | Not run | Not reviewed |
| TASK-1.11 | LOCKED | Not created | Not run | Not reviewed |

## Working-tree baseline

At TASK-1.10 opening:

```text
HEAD: 0bb2e354715e00f20c4df95719e900ae5e8e1673
TASK-1.9 build: PASSED reported by owner
```

Coordinator-owned uncommitted files may include:

```text
docs/backup-restore-hardening/DECISIONS.md
docs/backup-restore-hardening/README.md
docs/backup-restore-hardening/ROADMAP.md
docs/backup-restore-hardening/STATUS.md
docs/backup-restore-hardening/reviews/TASK-1.8-REVIEW.md
docs/backup-restore-hardening/reviews/TASK-1.8A-REVIEW.md
docs/backup-restore-hardening/reviews/TASK-1.9-REVIEW.md
docs/backup-restore-hardening/tasks/TASK-1.8A-restore-resolver-contract-and-report-gates.md
docs/backup-restore-hardening/tasks/TASK-1.9-migrate-app-group-clear.md
docs/backup-restore-hardening/tasks/TASK-1.10-integrate-keychain-clear-result.md
```

The agent must treat these as protected coordinator baseline and must not rewrite task specifications or reviews.

## Blocked work

TASK-1.10 does not authorize:

- TASK-1.11 permission/marker cleanup;
- legacy aggressive Keychain API quarantine;
- extension Keychain migration;
- Backup/Restore Keychain migration;
- public Clear API changes;
- application-bundle writes;
- data-container/App Group resolver changes;
- UI layout redesign;
- broad vendor/service/account Keychain matching.

Agent must stop after TASK-1.10.
