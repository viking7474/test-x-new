# TASK-2.11A Coordinator Review

Implementation commit reviewed: `9790a22ebee3b617a6fdd6cab0e0bba6b61dc45d`

Baseline: `e38db4081e849ed80b10e7fafaac70f2a4943646`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-2.11 final status after corrective work: **COMPLETED**

## Build gate

```text
PASSED — accepted from project-owner continuation
```

The repository does not contain a GitHub Actions artifact, compiled package or target-device fault-injection log for independent coordinator replay. The owner continuation is accepted as the build signal; device crash/fault tests remain a release gate.

## Exact scope

The corrective commit contains exactly:

```text
M PXMainDataRestoreTransaction.m
A docs/backup-restore-hardening/reports/TASK-2.11A-REPORT.md
```

The following remain byte-identical to the TASK-2.11 baseline:

```text
PXMainDataRestoreTransaction.h
AppDataBackupManager.h
AppDataBackupManager.m
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXOptionalRestoreStaging.h/.m
PXRestorePlan.h/.m
PXBackupArchiveValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXDestructivePathValidator.h/.m
PXDataContainerResolver.h/.m
Makefile
```

## Corrective blocker closure

### 1. Stale recovery is now after stage and same-filesystem proof

Factory ordering now binds and proves:

```text
typed destination
target descriptor + fstat
lock descriptor + fstat
direct target/lock device+inode equality
exclusive flock
post-lock target/lock authority
stage descriptor + fstat
stage device == target device
pre-recovery target/lock/stage identity recheck
```

Only then does it call:

```objc
PXMainDataRestoreRecoverStaleTransactions(...)
```

A cross-device, replaced or invalid stage therefore fails with zero stale-recovery mutation.

### 2. The lock directly protects the target descriptor

Before `flock`, the implementation requires:

```text
targetStat.st_dev == lockStat.st_dev
targetStat.st_ino == lockStat.st_ino
```

The same direct equality is repeated after lock acquisition, immediately before recovery and after recovery. Independent path comparisons are retained as additional checks rather than used as a substitute for descriptor identity.

### 3. Unsupported directory synchronization is fail-closed

The old behavior:

```objc
return errno == EINVAL || errno == ENOTSUP;
```

is gone.

`PXMainDataRestoreSyncDescriptor` now retries only `EINTR` and succeeds only when `fsync` returns zero. `EINVAL`, `ENOTSUP`, `EOPNOTSUPP`, `ENOSYS` and all other errors remain failures. The same strict helper is used for the journal file.

## Post-recovery proof

After stale recovery the factory repeats:

- exact typed destination validation;
- canonical path to target descriptor binding;
- canonical path to lock descriptor binding;
- stage path to stage descriptor binding;
- target, lock and stage retained device/inode/type identity;
- direct target/lock device and inode equality;
- stage/target same-device equality.

Original and staged entry snapshots are collected only after all post-recovery checks pass.

## Zero-mutation preflight failures

The following failures occur before stale recovery:

```text
target open/fstat failure
lock open/fstat failure
target/lock mismatch
flock contention
stage open/path/fstat failure
stage non-directory
cross-device stage
pre-recovery target/lock/stage race
```

Every such branch closes all acquired descriptors; closing the lock descriptor releases the advisory lock.

## TASK-2.11 non-regression

The corrective commit retains:

- exact 12-code public API;
- six journal phases;
- private reserved workspace namespace;
- container metadata preservation;
- durable prepared journal before first new-transaction move;
- descriptor-relative `renameat` quarantine/install;
- identity-disambiguated same-name rollback;
- stale transaction state machine;
- multiple-stale-workspace fail-closed policy;
- rollback evidence preservation;
- bounded no-follow journal-last cleanup;
- manager code `317` mapping and cleanup-warning ownership boundary;
- zero main-data wipe/tar/cp clone behavior.

## Independent gates

```text
git show --check:                         PASS
baseline-to-HEAD diff --check:            PASS
corrective production scope:              PASS
protected production diff:                PASS
public header diff:                       0
manager diff:                             0
recovery calls:                           1
stage open before recovery:               PASS
same-device proof before recovery:        PASS
direct target/lock equality before:       PASS
direct target/lock equality after:        PASS
post-recovery stage identity proof:        PASS
EINVAL-as-success branches:               0
ENOTSUP-as-success branches:              0
EOPNOTSUPP-as-success branches:            0
ENOSYS-as-success branches:                0
journal file strict sync:                 retained
report explicit scenarios:                100
new trailing whitespace:                  0
new NUL bytes:                            0
```

`AppDataBackupManager.m` retains legacy trailing whitespace outside the corrective diff. TASK-2.11A adds no production whitespace defect.

## Residual runtime boundary

Acceptance does not substitute for target-device fault injection. Release testing still needs process termination around every journal phase, filesystem sync failure injection, stale recovery interruption, low-storage behavior, lock contention, cross-device rejection and cleanup recovery.

## Coordinator conclusion

TASK-2.11A closes all three TASK-2.11 source-review blockers. Main ApplicationData Restore now proves target, lock and stage authority before any stale recovery mutation and treats unsupported durability primitives as failure. TASK-2.11 is therefore completed and TASK-2.12 may open for transactional App Group commit and rollback.
