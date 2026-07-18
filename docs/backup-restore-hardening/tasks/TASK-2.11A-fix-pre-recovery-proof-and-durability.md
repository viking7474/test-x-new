# TASK-2.11A — Fix Pre-Recovery Proof and Transaction Durability

## Status

```text
READY
```

## Baseline

```text
e38db4081e849ed80b10e7fafaac70f2a4943646
```

TASK-2.11 source review:

```text
CHANGES_REQUESTED
docs/backup-restore-hardening/reviews/TASK-2.11-REVIEW.md
```

Next task:

```text
TASK-2.12 remains LOCKED
```

## Objective

Correct only the three fail-closed blockers found in TASK-2.11:

1. prove the validated stage is bound and on the target filesystem before stale recovery can mutate the target;
2. prove the exclusive lock descriptor protects the exact same target device/inode before stale recovery;
3. require a real successful synchronization result for every directory durability gate.

Do not redesign the accepted transaction architecture.

## Authorized production scope

Modify only:

```text
PXMainDataRestoreTransaction.m
```

Create only:

```text
docs/backup-restore-hardening/reports/TASK-2.11A-REPORT.md
```

Implementation commit must contain exactly those two files.

Suggested commit subject:

```text
phase2(task-2.11A): fix transaction pre-recovery proof and durability
```

## Protected source

The following files must remain byte-identical:

```text
PXMainDataRestoreTransaction.h
AppDataBackupManager.m
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
Makefile
```

Do not modify coordinator-owned task, review, status, roadmap, decision or README files.

## Baseline evidence

Before changing source, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -4 --oneline
git diff --name-status e38db4081e849ed80b10e7fafaac70f2a4943646..HEAD
```

Record SHA-256 before and after for every protected production file.

# Part 1 — Preserve the accepted public contract

Do not change `PXMainDataRestoreTransaction.h`.

The public contract remains:

```text
12 error codes
one non-subclassable class
readonly committed
readonly rollbackPerformed
readonly rollbackComplete
readonly recoveredStaleTransactionCount
one transaction factory
one one-shot commit method
```

Do not add public APIs, flags, callbacks, alternate constructors or test-only methods.

# Part 2 — Exact pre-recovery ordering

Inside:

```objc
+transactionForContainer:canonicalPath:validatedStage:error:
```

establish this order before calling stale recovery:

```text
1. validate public inputs
2. typed destination validation
3. open target descriptor no-follow/CLOEXEC
4. bind target path to target descriptor
5. fstat target descriptor
6. open independent lock descriptor no-follow/CLOEXEC
7. bind lock path to lock descriptor
8. fstat lock descriptor
9. prove target and lock are the same directory identity
10. acquire nonblocking exclusive flock on the proven lock identity
11. revalidate typed destination and both target descriptors
12. open validated stage descriptor no-follow/CLOEXEC
13. bind stage path to stage descriptor
14. fstat stage descriptor
15. require stage and target on the same filesystem
16. recheck target/lock/stage identities
17. only now enumerate or recover stale transactions
18. after recovery, repeat destination, target/lock and stage identity proof
19. repeat same-filesystem proof
20. collect current original and staged entry snapshots
21. construct transaction object
```

No stale recovery function may run before steps 1 through 16 succeed.

# Part 3 — Direct target/lock identity proof

Before stale recovery, require all of the following from direct `fstat` results:

```text
target is directory
lock is directory
target.st_dev == lock.st_dev
target.st_ino == lock.st_ino
```

Do not rely only on two separate path-to-descriptor checks.

The source must retain exact target identity from `targetDescriptor` and prove that `lockDescriptor` refers to that same identity.

Required behavior:

```text
target A + lock A -> allowed

target A + lock B -> fail before recovery
target directory + lock non-directory -> fail before recovery
lock fstat failure -> fail before recovery
flock failure -> fail before recovery
```

Use existing non-sensitive transaction-domain errors.

Do not expose path, inode, device, bundle ID or nested errors.

# Part 4 — Stage proof before stale recovery

Open and inspect the validated stage before stale recovery.

Require:

```text
stage path exact-matches retained descriptor identity
stage descriptor is a directory
stage identity equals its retained pre-recovery snapshot
stage.st_dev == target.st_dev
```

A failure in any of these checks must:

- return nil;
- close every owned descriptor;
- release any acquired lock;
- leave `recoveredStaleTransactionCount` effectively zero;
- perform zero stale transaction rollback;
- perform zero stale transaction cleanup;
- perform zero target rename/unlink/rmdir.

Cross-device failure must remain:

```text
PXMainDataRestoreTransactionErrorCrossDeviceBoundary
```

and must occur before stale recovery.

# Part 5 — Post-recovery proof

After successful stale recovery, repeat all authority checks before collecting new transaction snapshots:

```text
PXDestructivePathValidator exact path equality
canonical path -> target descriptor identity
a canonical path -> lock descriptor identity
target descriptor direct identity unchanged
lock descriptor direct identity unchanged
target == lock device/inode
stage path -> stage descriptor identity
stage descriptor identity unchanged
stage.st_dev == target.st_dev
```

Do not replace stored paths or snapshots with newly discovered values.

If any post-recovery check fails:

- return failure;
- close descriptors;
- do not create a new transaction workspace;
- do not publish a new journal;
- do not collect/commit a new transaction plan.

Stale recovery already completed may remain counted only when all post-recovery proof succeeds and a transaction object is returned.

# Part 6 — Strict directory synchronization

Correct:

```objc
PXMainDataRestoreSyncDirectory
```

Required rules:

1. Retry `fsync` when it fails with `EINTR`.
2. Return `YES` only after an actual synchronization call succeeds.
3. Do not treat these as success:

```text
EINVAL
ENOTSUP
EOPNOTSUPP
ENOSYS
```

4. Any unsupported or failed synchronization returns `NO`.
5. Existing callers must preserve their current error/rollback mapping.
6. Do not silently downgrade durability to warning before durable commit.

A stronger Darwin primitive may be used only when:

- it is compile-time guarded;
- it operates on the same retained descriptor;
- it returns success explicitly;
- ordinary failure still fails closed.

Do not claim durability from a skipped or unsupported operation.

# Part 7 — Journal file synchronization

Keep the existing complete write and file `fsync` contract.

You may introduce a private retry helper so journal-file synchronization also retries only `EINTR`.

Do not:

- skip file sync;
- map unsupported file sync to success;
- use shell `sync`;
- spawn a helper process;
- call global `sync()` as a substitute for descriptor durability.

# Part 8 — Recovery mutation boundary

For static and review purposes, the first possible target mutation in factory-time recovery must be dominated by all of:

```text
exact typed target validation
direct target/lock identity equality
exclusive lock acquisition
stage path/descriptor binding
same-filesystem proof
```

The call graph must not permit:

```text
PXMainDataRestoreRecoverStaleTransactions
```

before those proofs.

No helper called before same-filesystem proof may rename, unlink or remove anything under the target.

# Part 9 — Preserve accepted transaction behavior

Do not alter the accepted behavior for:

- transaction workspace prefix;
- original/new/journal names;
- workspace mode 0700;
- journal mode 0600;
- raw-byte deterministic entry identities;
- journal version or schema;
- six journal phases;
- metadata-file preservation;
- prepared journal before first new-transaction move;
- descriptor-relative `renameat` quarantine/install;
- same-name original/staged identity handling;
- rollback ordering;
- rollback failure evidence preservation;
- committed and rolled-back stale cleanup;
- in-progress stale rollback;
- multiple stale workspace fail-closed behavior;
- entry, cleanup, depth, path and journal limits;
- cleanup original/new before journal;
- one-shot transaction semantics;
- manager error code 317 mapping;
- manager cleanup warning behavior;
- ownership correction boundary.

# Part 10 — No TASK-2.12 work

Do not implement:

- App Group transaction journals;
- App Group rollback;
- multi-target transaction orchestration;
- optional component transactions;
- structured Restore result;
- UI changes;
- Backup changes.

TASK-2.12 remains locked.

# Part 11 — Required static gates

Scope:

```text
PXMainDataRestoreTransaction.m modified
TASK-2.11A-REPORT.md added
all other production diffs = 0
```

Pre-recovery ordering:

```text
target fstat before recovery
lock fstat before recovery
direct target/lock device+inode equality before recovery
flock before recovery
stage open before recovery
stage fstat before recovery
same-device check before recovery
stale recovery after all above
```

Post-recovery:

```text
typed destination revalidation present
direct target/lock equality repeated
stage identity repeated
same-device equality repeated
new entry collection only after post-recovery proof
```

Durability:

```text
fsync retry on EINTR present
EINVAL-as-success = 0
ENOTSUP-as-success = 0
EOPNOTSUPP-as-success = 0
unsupported directory sync success branches = 0
journal file sync retained
transaction directory sync retained
target/original/stage/new directory sync retained
```

Protected behavior:

```text
public header diff = 0
manager diff = 0
journal schema changes = 0
public enum changes = 0
App Group/optional files diff = 0
```

# Part 12 — Scenario matrix

The report must contain at least 70 explicit source/static scenarios, including:

1. target and lock same inode;
2. target and lock distinct inode;
3. target fstat failure;
4. lock fstat failure;
5. lock non-directory;
6. flock contention;
7. stage open failure;
8. stage path replacement;
9. stage non-directory;
10. cross-device stage;
11. all pre-recovery checks pass;
12. cross-device failure causes zero stale recovery calls;
13. stage identity failure causes zero stale recovery calls;
14. lock mismatch causes zero stale recovery calls;
15. one stale committed transaction after proof;
16. one stale rolled-back transaction after proof;
17. one stale prepared transaction after proof;
18. multiple stale transactions;
19. post-recovery target path replacement;
20. post-recovery target descriptor change;
21. post-recovery lock descriptor mismatch;
22. post-recovery stage path replacement;
23. post-recovery stage identity change;
24. post-recovery cross-device mismatch;
25. post-recovery success;
26. directory fsync success;
27. directory fsync interrupted once then success;
28. repeated EINTR then success;
29. directory fsync EINVAL;
30. directory fsync ENOTSUP;
31. directory fsync EOPNOTSUPP;
32. directory fsync hard I/O failure;
33. journal file fsync EINTR then success;
34. journal file fsync failure;
35. prepared journal publication failure;
36. quarantine sync failure triggers rollback;
37. install sync failure triggers rollback;
38. rollback sync failure returns RollbackFailed;
39. committed journal directory sync failure does not expose success;
40. rolled-back journal directory sync failure preserves recovery state;
41. cleanup sync failure after durable commit is warning-only;
42. no public API change;
43. no manager change;
44. no journal schema change;
45. no App Group transaction work;
46. no optional transaction work;
47. exact protected hashes;
48. whitespace check;
49. NUL audit;
50. report ending.

Add race, descriptor-close, error-privacy, cleanup and compilation scenarios until the total is at least 70.

# Part 13 — Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.11A-REPORT.md
```

The report must include:

- baseline and implementation commit;
- exact two-file scope;
- protected SHA-256 table;
- three TASK-2.11 blockers;
- before/after factory ordering table;
- direct target/lock identity proof;
- pre-recovery stage and same-filesystem proof;
- zero-mutation-on-pre-recovery-failure proof;
- post-recovery proof;
- strict directory durability implementation;
- EINTR behavior;
- unsupported-sync failure behavior;
- journal durability non-regression;
- rollback/recovery non-regression;
- full source diff;
- static gate table;
- at least 70 scenarios;
- whitespace/CRLF/NUL audit;
- build result or exact unavailable-toolchain statement;
- remaining target-device risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 14 — Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff e38db4081e849ed80b10e7fafaac70f2a4943646..HEAD --check
git diff --name-status e38db4081e849ed80b10e7fafaac70f2a4943646..HEAD
git status --short --untracked-files=all
```

Implementation commit must contain only:

```text
PXMainDataRestoreTransaction.m
docs/backup-restore-hardening/reports/TASK-2.11A-REPORT.md
```

## Stop condition

Stop after TASK-2.11A.

Do not implement TASK-2.12, TASK-2.13 or TASK-2.14.
