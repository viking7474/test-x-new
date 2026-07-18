# TASK-2.12 Review

Implementation commit reviewed: `9e83a053c4d4e2e42e0eac0a207467a5df2b3251`

Baseline: `9790a22ebee3b617a6fdd6cab0e0bba6b61dc45d`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXAppGroupRestoreTransaction.h
A PXAppGroupRestoreTransaction.m
A docs/backup-restore-hardening/reports/TASK-2.12-REPORT.md
```

No protected production source changed.

## Public contract

`PXAppGroupRestoreTransaction.h` exports:

- one error domain;
- one stable field-path key;
- exactly 15 error codes;
- one subclassing-restricted public class;
- five readonly result properties;
- one factory;
- one one-shot commit method;
- no public readwrite property.

The transaction consumes parallel immutable arrays of accepted physical App Group targets and validated directory stages. It does not accept manifest data, raw group identifiers, archive paths or caller-selected workspace paths.

## Complete batch proof before recovery

The factory:

1. validates all parallel inputs and fixed limits;
2. revalidates every retained target model;
3. assigns deterministic canonical UTF-8 lock ordinals;
4. opens and binds every target descriptor;
5. rejects duplicate physical device/inode targets;
6. opens an independent lock descriptor for every target;
7. proves direct target/lock device and inode equality;
8. acquires every lock in deterministic lock order;
9. revalidates exact target authority after lock acquisition;
10. opens and binds every validated stage;
11. proves every target/stage pair is same-filesystem;
12. repeats target/lock/stage identity proof;
13. only then invokes stale batch recovery.

Any failure before recovery closes all acquired descriptors and releases all locks. No workspace, journal or target mutation is created on those paths.

## Deterministic lock and leader policy

Lock order is exact canonical UTF-8 byte order. Restore-plan order remains the quarantine/install semantic order.

The lock-order ordinal-zero participant is the deterministic leader. Workspace names encode one lowercase UUID and the exact three-digit lock ordinal under the fixed prefix:

```text
.weaponx-app-group-restore-
```

The leader journal is not selected by caller order.

## Leader journal and stale binding

The bounded binary leader journal contains:

- version;
- batch identifier;
- exact phase;
- participant count;
- lock ordinal;
- Restore-plan order;
- exact ordered group identifiers;
- exact workspace name bytes;
- target device/inode;
- original and staged top-level identities.

Journal reading rejects malformed integral values, duplicate ordinal/plan identities, wrong participant counts, wrong group arrays, wrong target identities, wrong workspace names and aggregate entry overflow.

For in-progress phases, every participant workspace and both recovery directories are mandatory. For committed or rolled-back phases, an already-cleaned nonleader workspace is accepted only after the current exact target namespace matches the journal decision.

No-journal cleanup is limited to proven pre-mutation workspaces with empty `original/` and `new/` directories plus an optional bounded safe `batch.tmp` in the leader.

## Transaction semantics

Before the first original move, the transaction:

- revalidates every target/stage namespace;
- creates all participant workspaces;
- synchronizes every workspace and target directory;
- publishes durable `prepared` in the leader.

Quarantine and install run in Restore-plan order with descriptor-relative `renameat` and per-entry device/inode/type verification.

After full quarantine, every target operational namespace is empty except preserved metadata and reserved workspaces, while every `original/` exactly matches the journal.

After full install, every target exactly matches its staged identities and every stage top-level namespace is empty.

The exact phases are:

```text
prepared
quarantined
installed
committed
rolling-back
rolled-back
```

Success is exposed only after strict file synchronization, atomic leader-journal publication and strict leader-workspace synchronization of `committed`.

## Whole-batch rollback

Any failure after durable `prepared` and before durable `committed` attempts rollback across the entire physical-target set in reverse Restore-plan order.

Installed staged entries are moved to `new/`, originals are restored from `original/`, and every target must exact-match its original identity list. Same-name old/new entries are distinguished by device, inode and file type rather than name alone.

Rollback publication or namespace failure preserves all recovery evidence and never reports success.

## Cleanup and ownership boundary

Cleanup is descriptor-relative, no-follow, bounded, same-filesystem and leader-last. Nonleader workspaces are removed before the leader journal. The leader journal remains available whenever participant cleanup is incomplete.

Manager ownership correction is skipped only when transaction cleanup leaves a private recovery workspace, using the exact warning:

```text
App Group transaction cleanup failed; ownership correction was skipped
```

Staging cleanup retains its separate warning:

```text
App Group staging cleanup failed
```

## Manager integration

The manager stages and validates every physical target before constructing the transaction. Shared-target archive equivalence remains required and duplicate equivalent stages are cleaned before transaction preparation.

Static manager results:

```text
transaction factory calls:                  1
transaction commit calls:                   1
App Group direct wipe calls:                0
App Group tar-pipe clone markers:           0
App Group cp clone markers:                 0
direct stage-to-target shell clone:         0
transaction cleanup warning occurrences:   1
staging cleanup warning occurrences:       1
```

Target-authority preparation failures map to manager code 319; other transaction failures map to manager code 310 with generic descriptions.

## Strict durability

All file and directory synchronization retries only `EINTR` and succeeds only when `fsync` returns zero. There is no `EINVAL`, `ENOTSUP`, `EOPNOTSUPP` or `ENOSYS` success fallback.

## Non-regression

Byte-identical protected sources include:

- `PXMainDataRestoreTransaction.h/.m`;
- `PXMainDataStaging.h/.m`;
- `PXAppGroupRestoreTargetPlan.h/.m`;
- `PXOptionalRestoreStaging.h/.m`;
- `PXRestorePlan.h/.m`;
- accepted manifest/artifact/archive validators;
- container resolver and destructive-path validator;
- `AppDataBackupManager.h`;
- `Makefile`.

The accepted main-data transaction from TASK-2.11A is unchanged.

## Independent gates

```text
git show --check:                         PASS
cumulative diff --check:                 PASS
protected production diff:               PASS
public error codes:                       15
subclassing-restricted public classes:    1
public factories:                         1
public commit methods:                    1
public readwrite properties:              0
pure transaction forbidden tokens:        0
unsupported-sync success branches:        0
report explicit scenarios:                272
new-file trailing whitespace:             0
new-file NUL bytes:                       0
```

`AppDataBackupManager.m` retains 17 legacy trailing-whitespace lines, but TASK-2.12 added none and both commit/cumulative whitespace gates pass.

## Build evidence

The owner continued after implementation, which is accepted as the owner build signal for this coordination workflow. No GitHub Actions artifact, device package or target-device fault-injection log is present in the workspace for independent replay.

## Verdict

TASK-2.12 is accepted and completed. TASK-2.13 may open. TASK-2.14 remains locked.
