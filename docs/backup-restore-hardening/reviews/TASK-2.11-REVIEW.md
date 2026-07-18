# TASK-2.11 Coordinator Review

Implementation commit reviewed: `e38db4081e849ed80b10e7fafaac70f2a4943646`

Baseline: `96f93882876c59fdb0ded5feb98456be7daf5ec6`

Production source review: **CHANGES_REQUESTED**

Final status: **CHANGES_REQUESTED**

Build gate: **PASSED by project-owner continuation; no CI artifact is stored in this workspace**

## Scope review

The implementation commit contains exactly the authorized production scope plus report:

```text
M AppDataBackupManager.m
A PXMainDataRestoreTransaction.h
A PXMainDataRestoreTransaction.m
A docs/backup-restore-hardening/reports/TASK-2.11-REPORT.md
```

Protected accepted source from TASK-2.8 through TASK-2.10 is unchanged. Commit and cumulative whitespace checks pass.

## Accepted portions

The implementation correctly introduces:

- the exact 12-code public error enum;
- one non-subclassable public transaction object;
- readonly committed/rollback/recovery state;
- exact typed ApplicationData model and canonical-path authority;
- no-follow target and stage descriptors;
- one-shot commit semantics;
- a reserved private transaction namespace;
- deterministic raw-byte top-level entry identities;
- bounded binary-property-list journals;
- prepared, quarantined, installed, committed, rolling-back and rolled-back phases;
- descriptor-relative same-filesystem `renameat` quarantine and install;
- container metadata preservation;
- identity-disambiguated same-name rollback;
- bounded no-follow cleanup;
- stale transaction recovery and multiple-stale fail-closed behavior;
- removal of the main `_wipeDirectoryContents:` call;
- removal of main tar-pipe and `cp` clone authority;
- manager-side full stage revalidation immediately before transaction preparation;
- manager error mapping to existing code `317`;
- cleanup-warning behavior that prevents recursive ownership correction across a retained recovery workspace.

Independent static evidence:

```text
public error codes:                    12
public factory methods:                1
public commit methods:                 1
public readwrite properties:           0
main wipe calls:                       0
main tar-pipe clone markers:           0
main cp clone markers:                 0
transaction factory calls in Restore: 1
transaction commit calls in Restore:  1
protected production diff:             0
git show --check:                      PASS
cumulative diff --check:              PASS
```

These accepted portions remain protected in TASK-2.11A.

# Blocking findings

## Blocker 1 — stale recovery can mutate the target before same-filesystem proof

The required contract is:

```text
open and bind target
open and bind validated stage
require stage.st_dev == target.st_dev
only then permit any target mutation
```

Current factory order in `PXMainDataRestoreTransaction.m` is:

```text
line 1858: PXMainDataRestoreRecoverStaleTransactions(...)
line 1883: open validated stage
line 1906: compare targetStat.st_dev and stageStat.st_dev
```

Stale recovery is not read-only. Depending on journal phase it may:

- move installed staged entries from the target into `new/`;
- restore quarantined originals into the target;
- delete committed/rolled-back transaction data;
- remove a stale transaction workspace.

Therefore a cross-device or replaced stage can fail only **after** stale recovery has already renamed or deleted target entries. This contradicts the TASK-2.11 requirement that cross-device failure occur before target mutation.

The report also states that same-filesystem proof precedes the transaction mutation boundary, but the actual source places stale recovery first.

Required correction:

1. Open and bind the validated stage before recovery.
2. Obtain target and stage `fstat` snapshots.
3. Require exact same-device equality before calling stale recovery.
4. Recheck stage identity and same-device equality after recovery and before collecting the new transaction snapshot.
5. Any stage open, identity or cross-device failure must perform zero stale-recovery action.

## Blocker 2 — the recovery lock is not proven to protect the target descriptor before recovery

The source opens two target descriptors:

```text
targetDescriptor
lockDescriptor
```

Before stale recovery, it verifies each descriptor against the path at different moments, then acquires `flock` on `lockDescriptor`. It does not directly require:

```text
lock.st_dev == target.st_dev
lock.st_ino == target.st_ino
both are directories
```

until the later `revalidatePreparedStateWithError:` path, after factory-time recovery has already completed.

A destination replacement race between the two opens can therefore produce:

```text
targetDescriptor -> inode A
lockDescriptor   -> inode B
flock protects B
stale recovery mutates A
```

The later path checks do not make the earlier recovery serialized.

Required correction:

- `fstat` both descriptors before recovery;
- require directory type and exact device/inode equality;
- acquire and retain the nonblocking lock only for that exact identity;
- revalidate path/model and direct target/lock equality before recovery;
- repeat direct equality after recovery and before returning the transaction object.

No recovery or cleanup mutation may run while the lock is bound to a different inode.

## Blocker 3 — unsupported directory synchronization is treated as durable success

Current helper:

```objc
static BOOL PXMainDataRestoreSyncDirectory(int descriptor) {
    if (fsync(descriptor) == 0) {
        return YES;
    }
    return errno == EINVAL || errno == ENOTSUP;
}
```

TASK-2.11 depends on durable ordering for:

- journal publication;
- quarantine directory moves;
- install directory moves;
- rollback restoration;
- committed/rolled-back phase publication;
- cleanup ordering.

Returning success for `EINVAL` or `ENOTSUP` means no successful durability primitive occurred. The API can expose `committed = YES` after a phase rename whose containing directory was never synchronized.

A crash can then leave a journal phase or namespace transition absent despite the caller having received success. That violates:

```text
never return success before durable committed state exists
```

Required correction:

- retry `fsync` only for `EINTR`;
- return success only after an actual successful synchronization primitive;
- do not translate `EINVAL`, `ENOTSUP` or any other unsupported result into success;
- if a stronger Darwin synchronization primitive is used, its successful return must be explicit and guarded at compile time;
- unsupported synchronization must fail closed and follow the existing rollback/recovery path.

## Report discrepancy

`TASK-2.11-REPORT.md` claims:

```text
stale transaction recovery
-> same-filesystem proof
```

and separately claims that same-filesystem proof occurs before the mutation boundary. The first ordering is the actual source ordering, but it does not satisfy the second claim because stale recovery itself mutates the target.

The corrective report must explicitly distinguish:

```text
pre-recovery proof
post-recovery proof
new-transaction mutation
```

## Non-blocking observations

- The implementation report does not embed the final commit hash because the report is included in that commit. The coordinator records the final hash; this is not a source blocker.
- `AppDataBackupManager.m` retains 17 legacy trailing-whitespace lines, but TASK-2.11 adds none and both Git checks pass.
- Target-device interruption and filesystem fault-injection tests are still required after corrective source acceptance.

## Required corrective task

TASK-2.11A must be limited to:

```text
PXMainDataRestoreTransaction.m
docs/backup-restore-hardening/reports/TASK-2.11A-REPORT.md
```

It must not alter:

- the public header;
- manager integration;
- journal schema or public enum;
- accepted commit/rollback identity model;
- App Group or optional behavior;
- transaction scope beyond the three blockers above.

## Coordinator conclusion

TASK-2.11 is not accepted yet. Its transaction architecture is retained, but pre-recovery source/lock proof and real directory durability are mandatory before the transaction can be considered fail-closed.

TASK-2.12 remains locked.
