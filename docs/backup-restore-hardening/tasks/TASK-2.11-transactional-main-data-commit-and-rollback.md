# TASK-2.11 — Transactional Main-Data Commit and Rollback

## Status

```text
READY_FOR_REVIEW
```

## Baseline

```text
96f93882876c59fdb0ded5feb98456be7daf5ec6
```

Implementation under review:

```text
e38db4081e849ed80b10e7fafaac70f2a4943646
```

TASK-2.10 source review:

```text
ACCEPTED
docs/backup-restore-hardening/reviews/TASK-2.10-REVIEW.md
```

Build owner:

```text
Project owner via GitHub Actions / owner continuation
```

## Objective

Replace the accepted main ApplicationData post-validation sequence:

```text
validated stage
-> wipe target contents
-> tar/cp clone into target
```

with one journaled same-filesystem transaction that:

1. revalidates the exact typed ApplicationData destination;
2. proves the validated stage and destination are on the same filesystem before mutation;
3. creates a private transaction workspace inside the destination container;
4. durably records the complete top-level original/staged entry plan before mutation;
5. quarantines current target entries descriptor-relatively with `renameat`;
6. installs validated staged entries descriptor-relatively with `renameat`;
7. preserves current-device container metadata files;
8. rolls back the original target after any pre-commit failure;
9. recovers or cleans stale transactions left by process interruption;
10. never returns success before a durable committed journal state exists.

## Authorized production scope

Create:

```text
PXMainDataRestoreTransaction.h
PXMainDataRestoreTransaction.m
```

Modify:

```text
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.11-REPORT.md
```

Implementation commit must contain only those three production files plus the report.

## Protected accepted source

The following accepted source must remain byte-identical:

```text
PXMainDataStaging.h
PXMainDataStaging.m
PXAppGroupRestoreTargetPlan.h
PXAppGroupRestoreTargetPlan.m
PXOptionalRestoreStaging.h
PXOptionalRestoreStaging.m
PXRestorePlan.h
PXRestorePlan.m
PXBackupArchiveValidator.h
PXBackupArchiveValidator.m
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
PXDataContainerResolver.h
PXDataContainerResolver.m
```

## Required public API

`PXMainDataRestoreTransaction.h` must export:

```objc
PXMainDataRestoreTransactionErrorDomain
PXMainDataRestoreTransactionErrorFieldPathKey
```

and exactly these stable error categories:

```text
InvalidInput = 1
DestinationValidationFailed = 2
FilesystemInspectionFailed = 3
CrossDeviceBoundary = 4
EntryLimitExceeded = 5
JournalCreationFailed = 6
JournalInvalid = 7
QuarantineFailed = 8
CommitFailed = 9
RollbackFailed = 10
CleanupFailed = 11
FilesystemChanged = 12
```

The public transaction object must be immutable to callers, non-subclassable and expose only:

```text
committed
rollbackPerformed
rollbackComplete
recoveredStaleTransactionCount
```

Required factory authority:

```objc
+transactionForContainer:canonicalPath:validatedStage:error:
```

Required one-shot operation:

```objc
-commitWithCleanupWarning:error:
```

No public raw destination-only initializer is allowed.

## Destination authority

The transaction must accept only:

- one retained `PXResolvedContainer` of kind `PXResolvedContainerKindApplicationData`;
- the exact canonical path already accepted by Restore;
- one retained `PXValidatedMainDataStage` produced by TASK-2.8.

Before opening the transaction and again immediately before mutation, it must:

- call `PXDestructivePathValidator` with the retained model;
- require exact equality with the retained canonical path;
- open the target directory with no-follow and close-on-exec semantics;
- bind the path and descriptor by device/inode identity;
- reject destination replacement or type changes.

Manifest path/UUID values, legacy resolver results and first-existing helpers have zero authority.

## Same-filesystem transaction boundary

The validated stage and target must both be opened as retained no-follow directory descriptors.

Before target mutation, the transaction must require:

```text
stage.st_dev == target.st_dev
```

Cross-device copy fallback is forbidden in TASK-2.11. A cross-device stage must fail before quarantine.

Reason: rollback safety in this task depends on same-filesystem `renameat` semantics rather than copy/delete behavior.

## Reserved transaction namespace

The target container reserves top-level names beginning with:

```text
.weaponx-main-restore-
```

A new transaction must use a unique hidden name in that namespace and mode `0700`.

The workspace must contain only:

```text
original/
new/
journal.plist
journal.tmp   # transient only
```

Any unexpected entry, non-directory workspace, symlink substitution or invalid journal fails closed.

A staged archive entry using the reserved prefix must be rejected.

## Metadata preservation

The following current-device files must never be quarantined or replaced by the stage:

```text
.com.apple.mobile_container_manager.metadata.plist
.com.apple.containermanagerd.metadata.plist
```

TASK-2.8 already rejects them from the validated stage. TASK-2.11 must independently enforce the same boundary.

## Journal contract

Before the first target entry is moved, the transaction must durably publish a bounded binary property-list journal containing:

- journal version;
- exact transaction workspace name;
- target device/inode identity;
- phase;
- deterministic original top-level entry identities;
- deterministic staged top-level entry identities.

Each entry identity must include at least:

```text
raw name bytes
device
inode
file type
```

Journal entry lists must be duplicate-free, bounded and reject metadata/reserved names.

Required phases:

```text
prepared
quarantined
installed
committed
rolling-back
rolled-back
```

Journal publication must use a no-follow exclusive temporary file, complete write, file sync and atomic `renameat` into `journal.plist`.

A successful API result is forbidden until `committed` is durably published.

## Commit sequence

The exact mutation order must be:

```text
1. publish prepared journal
2. move every planned current target entry -> transaction/original
3. synchronize target and original directories
4. publish quarantined journal
5. move every planned validated-stage entry -> target
6. synchronize target and stage directories
7. publish installed journal
8. revalidate exact typed target identity
9. publish committed journal
10. expose committed = YES
11. remove quarantined old data and transaction workspace
```

Top-level entry moves must be descriptor-relative `renameat` operations with source identity checks before and destination identity checks after each move.

The main Restore path must not call `_wipeDirectoryContents:` for ApplicationData and must not use tar-pipe/cp clone for main data after TASK-2.11.

## Rollback sequence

Any failure after the prepared journal and before durable committed state must trigger rollback.

Rollback must be idempotent and perform:

```text
1. publish rolling-back when possible
2. move already-installed staged entries from target -> transaction/new
3. restore quarantined original entries transaction/original -> target
4. synchronize all involved directories
5. publish rolled-back
6. expose rollbackPerformed = YES and rollbackComplete = YES
7. clean transaction data best-effort
```

When a staged entry name equals an original entry name, rollback must distinguish the two by journaled device/inode/type identity. An original entry still present during a partial quarantine must not be mistaken for an installed staged entry.

If rollback cannot prove and restore the original namespace, it must:

- return `RollbackFailed`;
- expose `rollbackComplete = NO`;
- preserve the journal and transaction workspace for later recovery;
- never report Restore success.

## Interrupted-transaction recovery

Before planning a new transaction, the implementation must enumerate the reserved namespace from the retained target descriptor.

For each stale workspace:

- `committed` or `rolled-back`: finish bounded cleanup;
- any earlier valid phase: perform the same idempotent rollback and cleanup;
- no published journal with empty `original/`/`new/`, an optional bounded regular `journal.tmp`, or an already-empty post-cleanup workspace: clean safely;
- missing/corrupt journal with recovery data present: fail closed and preserve evidence;
- more than one stale workspace: fail closed for manual recovery rather than guessing transaction order.

Recovery may not trust path strings inside the journal. The workspace is authoritative only through the target descriptor and journal identity match.

## Cleanup boundary

Cleanup must be:

- descriptor-relative;
- no-follow;
- bounded by fixed entry/depth limits;
- post-order for directories;
- idempotent across partial prior cleanup;
- restricted to the exact retained transaction workspace.

The journal must be removed after `original/` and `new/` so a partial cleanup remains recoverable.

After durable commit, cleanup failure is a warning rather than a false rollback. The committed journal/workspace must remain recoverable on the next run.

## Manager integration

`AppDataBackupManager.m` must:

- keep main staging and staged-tree acceptance unchanged;
- keep first process termination after complete stage acceptance;
- keep the existing exact pre-mutation validator gate and code `303` behavior;
- rerun full staged-tree validation and require equivalence immediately before transaction preparation;
- prepare and execute `PXMainDataRestoreTransaction` after process termination;
- map prepare/commit failure to existing manager error code `317`;
- record rollback state in debug output without raw journal contents;
- add a warning when committed transaction cleanup fails;
- clean the main staging workspace after commit or failed attempt;
- retain ownership correction only after transaction cleanup succeeds, so a private recovery workspace is never recursively transferred to mobile;
- preserve later component order.

The manager must not consume a stage path as shell command source for main commit.

## Compatibility boundaries

TASK-2.11 must preserve:

- manifest/schema/version/bundle gates;
- exact main target planning and code `303` behavior;
- immutable Restore plan;
- artifact/archive validation;
- TASK-2.8 main staging contract;
- TASK-2.9 App Group staged nontransactional behavior;
- TASK-2.10 optional staged nontransactional behavior;
- Keychain warning semantics;
- current high-level Restore component order;
- Backup and UI behavior.

TASK-2.11 does not authorize:

- App Group transaction changes — TASK-2.12;
- optional-component transaction changes — TASK-2.13;
- structured Restore result — TASK-2.14;
- backup publication changes;
- broad transaction abstraction refactors.

## Required evidence

The report must include:

1. baseline and final commit hashes;
2. exact file scope;
3. public API/enum audit;
4. main manager before/after authority flow;
5. journal schema and phase transition table;
6. same-filesystem proof;
7. metadata preservation proof;
8. rollback matrix for failures at every commit phase;
9. stale recovery matrix;
10. same-name original/staged collision proof;
11. cleanup ordering and bounds;
12. static searches proving main wipe/tar/cp removal;
13. protected-source hash comparison;
14. commit and cumulative whitespace checks;
15. build result or exact unavailable-toolchain statement;
16. target-device tests still required.

## Acceptance checklist

- [ ] Exact authorized production scope plus report only.
- [ ] Public API is immutable, non-subclassable and matches the 12-code enum.
- [ ] Exact typed target is revalidated before preparation and mutation.
- [ ] Target and stage are no-follow descriptor-bound.
- [ ] Cross-device boundary fails before mutation.
- [ ] Container metadata is never quarantined or replaced.
- [ ] Reserved transaction namespace is enforced.
- [ ] Complete deterministic journal is durable before first move.
- [ ] Target originals move to `original/` by descriptor-relative `renameat`.
- [ ] Validated staged entries move to target by descriptor-relative `renameat`.
- [ ] Success occurs only after durable `committed` phase.
- [ ] Every pre-commit failure attempts rollback.
- [ ] Same-name original/staged entries are identity-disambiguated.
- [ ] Rollback failure preserves recovery state and returns failure.
- [ ] Stale committed/rolled-back transactions finish cleanup.
- [ ] Stale in-progress transactions roll back idempotently.
- [ ] Empty no-journal pre-mutation workspace is cleaned safely.
- [ ] Cleanup removes data directories before journal.
- [ ] Main `_wipeDirectoryContents:` call is removed.
- [ ] Main tar-pipe and cp clone are removed.
- [ ] App Group and optional mutation paths remain unchanged.
- [ ] Protected accepted source remains byte-identical.
- [ ] `git show --check` and cumulative `git diff --check` pass.
- [ ] Owner build succeeds or is explicitly confirmed.
- [ ] Coordinator review accepts the task.

## Stop condition

Stop after TASK-2.11 implementation, report and implementation commit.

TASK-2.12 and later tasks remain locked.
