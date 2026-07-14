# TASK-2.11 Implementation Report

## Status

```text
READY_FOR_REVIEW
```

Baseline:

```text
96f93882876c59fdb0ded5feb98456be7daf5ec6
```

Implementation commit:

```text
Assigned by the Git commit containing this report; record from git rev-parse HEAD.
```

A report cannot embed the hash of the same commit that contains it without changing that hash. The coordinator/final response records the resulting commit ID.

## Exact implementation scope

```text
AppDataBackupManager.m
PXMainDataRestoreTransaction.h
PXMainDataRestoreTransaction.m
docs/backup-restore-hardening/reports/TASK-2.11-REPORT.md
```

No accepted main-staging, App Group planning/staging, optional staging, Restore-plan, archive/artifact validation, destructive-path validation or container-resolution source changed.

## Public contract audit

`PXMainDataRestoreTransaction.h` exports:

```text
PXMainDataRestoreTransactionErrorDomain
PXMainDataRestoreTransactionErrorFieldPathKey
```

Stable error enum count:

```text
12
```

Codes:

```text
1  InvalidInput
2  DestinationValidationFailed
3  FilesystemInspectionFailed
4  CrossDeviceBoundary
5  EntryLimitExceeded
6  JournalCreationFailed
7  JournalInvalid
8  QuarantineFailed
9  CommitFailed
10 RollbackFailed
11 CleanupFailed
12 FilesystemChanged
```

Public class gates:

```text
objc_subclassing_restricted = 1
public readwrite properties = 0
factory count = 1
one-shot commit method count = 1
```

Readonly state:

```text
committed
rollbackPerformed
rollbackComplete
recoveredStaleTransactionCount
```

## Manager authority flow

Before TASK-2.11:

```text
accepted archive
-> private validated main stage
-> terminate target process
-> exact destination revalidation
-> wipe target contents
-> tar/cp clone stage into target
-> recursive ownership correction
```

After TASK-2.11:

```text
accepted archive
-> private validated main stage
-> terminate target process
-> exact destination revalidation
-> full staged-tree revalidation and digest equivalence
-> typed transaction factory
-> exclusive target lock
-> stale transaction recovery
-> same-filesystem proof
-> durable prepared journal
-> rename current entries to quarantine
-> rename validated staged entries into target
-> exact final namespace proof
-> durable committed journal
-> bounded cleanup
```

Static manager evidence:

```text
transaction factory uses = 1
main _wipeDirectoryContents:dataContainerPath uses = 0
main tarPipeCloneExit uses = 0
main cpCloneExit uses = 0
preCommitValidatedStage references = 4
```

App Group tar/cp behavior remains outside this task and unchanged.

## Destination and concurrency authority

The transaction accepts only:

- one retained `PXResolvedContainer` whose kind is `ApplicationData`;
- the exact canonical path already accepted by Restore;
- one retained `PXValidatedMainDataStage`.

The exact typed path is validated before preparation, after stale recovery, immediately before mutation and before durable commit. The target path, target mutation descriptor and independent lock descriptor must resolve to the same device/inode.

An exclusive nonblocking `flock` is held on a dedicated target descriptor so directory-enumeration duplicates cannot release or alter the transaction lock. Multiple active main-data transactions against the same target fail before mutation.

## Same-filesystem proof

The validated stage and target are opened with directory, no-follow and close-on-exec flags. Before the transaction workspace or first quarantine move:

```text
stage.st_dev == target.st_dev
```

is required. There is no cross-device copy fallback. Every data state transition uses descriptor-relative `renameat`.

## Reserved workspace and metadata boundary

Reserved target namespace:

```text
.weaponx-main-restore-<uuid>
```

Workspace mode is forced to `0700`; journal files are forced to `0600`.

Allowed workspace entries:

```text
original/
new/
journal.plist
journal.tmp
```

Current-device container metadata is never quarantined or replaced:

```text
.com.apple.mobile_container_manager.metadata.plist
.com.apple.containermanagerd.metadata.plist
```

The staged tree independently rejects both metadata names and the transaction prefix.

## Journal schema

The bounded binary property-list journal contains:

```text
version
transactionName (raw bytes)
targetDevice
targetInode
phase
originalEntries[]
stagedEntries[]
```

Every entry contains:

```text
raw name bytes
device
inode
file type
```

Numeric fields reject booleans, floating-point values and negative signed values. Lists reject duplicate, metadata and reserved names and are sorted by raw name bytes.

Journal publication sequence:

```text
open journal.tmp with O_EXCL|O_NOFOLLOW
-> complete bounded write
-> fsync file
-> renameat journal.tmp -> journal.plist
-> synchronize transaction directory
```

Phases:

| Phase | Durable meaning | Recovery action |
|---|---|---|
| `prepared` | complete plan exists; mutation may not have started | idempotent rollback |
| `quarantined` | planned originals moved to `original/` | idempotent rollback |
| `installed` | staged namespace installed but not accepted | idempotent rollback |
| `committed` | final namespace accepted | finish cleanup only |
| `rolling-back` | rollback was started | continue rollback |
| `rolled-back` | original namespace restored | finish cleanup only |

Success is exposed only after durable `committed` publication.

## Commit sequence and exact namespace gates

```text
1. publish prepared
2. move each planned target entry -> original/
3. sync target + original/
4. prove target operational namespace is empty
5. prove original/ exactly matches the journal
6. publish quarantined
7. move each planned staged entry -> target
8. sync target + stage
9. prove target exactly matches staged journal identities
10. prove stage top-level namespace is empty
11. publish installed
12. revalidate typed target + independent lock identity
13. prove target still exactly matches staged journal identities
14. publish committed
15. expose committed=YES
16. cleanup old/new data before journal and workspace removal
```

Unexpected concurrent target entries therefore cannot be silently retained while reporting success.

## Rollback matrix

| Failure point | Target state before rollback | Required result |
|---|---|---|
| before first quarantine move | all originals still in target | accept originals by identity; clean transaction |
| mid-quarantine | originals split between target and `original/` | restore moved originals; retain originals already in target |
| after quarantine | originals all in `original/` | restore all originals |
| mid-install | staged entries split between target and stage | move installed staged entries to `new/`; restore originals |
| after install / before committed | staged namespace in target | move staged entries to `new/`; restore originals |
| mid-rollback | entries split across target, `original/`, `new/` | continue idempotently from journal identities |
| rollback journal failure | original namespace may be restored but not durably recorded | return `RollbackFailed`; preserve workspace |
| exact original namespace mismatch | unknown or concurrent entry exists | return `RollbackFailed`; preserve workspace |

A small state model exercised all five valid interruption positions for two original entries and two staged entries, including one shared name:

```text
rollbackIdentityScenarios = 5
sameNameCollision = PASS
finalOriginalNamespace = PASS
```

Same-name collision rule:

```text
old A and new A are distinguished by device/inode/type, not by name alone.
```

An old `A` still in target during partial quarantine is never mistaken for installed staged `A`.

## Interrupted transaction recovery

| Stale state | Action |
|---|---|
| `committed` | bounded cleanup only |
| `rolled-back` | bounded cleanup only |
| any earlier valid phase | idempotent rollback, publish rolled-back, cleanup |
| no journal; empty `original/`/`new/` and optional bounded regular `journal.tmp` | safe pre-mutation cleanup |
| no journal; workspace already empty after journal removal | remove empty workspace |
| missing/corrupt journal with recovery data | fail closed; preserve evidence |
| workspace on another filesystem | fail closed |
| more than one stale workspace | fail closed for manual recovery |

The no-journal empty-workspace case covers both a crash before the prepared journal and a crash after journal deletion but before final workspace removal.

## Cleanup safety

Cleanup is:

```text
descriptor-relative
no-follow
post-order
entry bounded: 500000
depth bounded: 2048
same-filesystem only
restricted to the retained transaction workspace
```

Nested directory device changes are rejected so cleanup cannot descend through a mount boundary. `original/` and `new/` are removed before journal files; the workspace is removed last.

After durable commit, cleanup failure is returned as a warning and the journal remains recoverable. The manager skips recursive ownership correction while a private journal/quarantine workspace remains, preventing `chown -R` from exposing it to the mobile user.

## Static and syntax gates

```text
git diff --check
PASS

protected accepted source git diff
PASS (exit 0)

Objective-C frontend syntax parse
PASS (clang-tidy/Clang 12 frontend, exit 0)
```

The frontend parse used temporary local Foundation/POSIX declarations only to parse the new implementation on this Windows host. It is not a substitute for an iOS SDK/Theos build.

## Build result

A target build was not available in this workspace environment:

```text
THEOS = unset
make = missing
clang = missing
xcrun = missing
```

`Makefile` includes all root `*.m` files through `ProjectX_FILES = $(wildcard *.m)`, so the new implementation is in the normal app build graph.

Required owner gate:

```text
Run the normal GitHub Actions/Theos arm64 + arm64e build.
```

## Target-device tests still required

- normal nonempty restore;
- empty-stage restore;
- same-name old/new top-level entry;
- forced failure after each quarantine/install move;
- process kill at every journal phase;
- stale committed cleanup;
- stale rolling-back recovery;
- corrupt/missing journal with recovery data;
- cross-device stage rejection;
- concurrent Restore rejection;
- cleanup failure warning and subsequent recovery;
- nested mount cleanup rejection;
- metadata-file preservation;
- app launch and ownership verification after successful cleanup.

## Conclusion

TASK-2.11 removes the irreversible main-data wipe/clone boundary. Main ApplicationData commit is now a journaled same-filesystem rename transaction with exact typed destination authority, exclusive serialization, identity-disambiguated rollback, stale recovery and bounded no-follow cleanup. TASK-2.12 remains locked pending coordinator review and owner build confirmation.
