# TASK-2.11A Implementation Report

## Baseline and implementation scope

- Required baseline: `e38db4081e849ed80b10e7fafaac70f2a4943646`.
- Baseline HEAD observed before source modification: `e38db4081e849ed80b10e7fafaac70f2a4943646`.
- Implementation commit subject: `phase2(task-2.11A): fix transaction pre-recovery proof and durability`.
- Implementation commit hash: this report is part of that commit, so the authoritative final hash is recorded by the post-commit gate output rather than self-referenced inside the commit.
- Authorized implementation scope: modified `PXMainDataRestoreTransaction.m`; added this report only.
- Coordinator-owned modified/untracked documentation was present before work and was not staged, reverted or rewritten.

Baseline evidence captured before source modification:

```text
$ git rev-parse HEAD
e38db4081e849ed80b10e7fafaac70f2a4943646
$ git log -4 --oneline
e38db40 phase2(task-2.11): add transactional main-data commit
96f9388 phase2(task-2.10): stage and validate optional components
48cb463 phase2(task-2.9): stage and validate app groups
9aaa575 phase2(task-2.8): stage and validate main data
$ git diff --name-status e38db4081e849ed80b10e7fafaac70f2a4943646..HEAD
<empty>
$ git status --short --untracked-files=all
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.9-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.10-stage-and-validate-optional-components.md
?? docs/backup-restore-hardening/tasks/TASK-2.11-transactional-main-data-commit-and-rollback.md
?? docs/backup-restore-hardening/tasks/TASK-2.11A-fix-pre-recovery-proof-and-durability.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.6-add-archive-entry-safety-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.6A-fix-archive-validator-compatibility-and-bounds.md
?? docs/backup-restore-hardening/tasks/TASK-2.7-build-immutable-restore-plan.md
?? docs/backup-restore-hardening/tasks/TASK-2.8-stage-and-validate-main-data.md
?? docs/backup-restore-hardening/tasks/TASK-2.9-stage-and-validate-app-groups.md
```

## Protected SHA-256 evidence

| Protected production file | Before | After | Result |
|---|---|---|---|
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | BYTE-IDENTICAL |
| `AppDataBackupManager.m` | `562e5877f51c63ebd54f618ee11cb6fef8a90015caf665375d62e1ded015548a` | `562e5877f51c63ebd54f618ee11cb6fef8a90015caf665375d62e1ded015548a` | BYTE-IDENTICAL |
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | BYTE-IDENTICAL |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | BYTE-IDENTICAL |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | BYTE-IDENTICAL |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | BYTE-IDENTICAL |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | BYTE-IDENTICAL |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | BYTE-IDENTICAL |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | BYTE-IDENTICAL |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | BYTE-IDENTICAL |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | BYTE-IDENTICAL |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | BYTE-IDENTICAL |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | BYTE-IDENTICAL |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | BYTE-IDENTICAL |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | BYTE-IDENTICAL |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | BYTE-IDENTICAL |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | BYTE-IDENTICAL |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | BYTE-IDENTICAL |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | BYTE-IDENTICAL |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | BYTE-IDENTICAL |

- Target source baseline SHA-256: `5d765d00cb0d46286d2cb00da1df8505ffb07ced6e1fd7f566e467a77f1576b1`.
- Target source corrected SHA-256 before commit: `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5`.
- `git diff --name-status HEAD -- <protected files>` returned empty.

## Three TASK-2.11 blockers corrected

1. **Stage proof before stale recovery:** stage open, path binding, fstat, directory proof, retained identity recheck and same-device proof now dominate the only factory recovery invocation.
2. **Exact lock identity:** target and independent lock descriptors are directly compared by `st_dev` and `st_ino` before `flock`, immediately before recovery and after recovery.
3. **Real directory durability:** descriptor `fsync` retries only `EINTR`; every other failure, including unsupported synchronization, returns failure.

## Factory ordering before and after

| Gate | TASK-2.11 baseline | TASK-2.11A corrected |
|---|---|---|
| Input validation | Before recovery | Before recovery |
| Typed destination validation | Before target open | Before target open |
| Target open/path bind/fstat | Before recovery | Before recovery |
| Independent lock open/path bind | Before recovery | Before recovery |
| Lock fstat | Absent before recovery | Present before recovery |
| Direct target/lock device+inode proof | Absent before recovery | Present before flock and repeated |
| Exclusive nonblocking flock | Before recovery, but inode relationship unproven | After direct identity proof |
| Typed target/target-lock authority revalidation | After stale recovery | Before stage open and recovery |
| Stage open/path bind | After stale recovery | Before stale recovery |
| Stage fstat/directory proof | After stale recovery | Before stale recovery |
| Stage/target same-filesystem proof | After stale recovery | Before stale recovery and repeated |
| Target/lock/stage retained identity recheck | Incomplete | Immediately before recovery |
| Stale recovery | Before stage proof | After every pre-recovery proof |
| Post-recovery typed target proof | Target path only | Typed target + target/lock path proof |
| Post-recovery direct target/lock proof | Absent | Repeated device/inode equality |
| Post-recovery stage proof | Absent | Path, fstat identity and same-device repeated |
| Entry snapshots | After late stage proof | Only after complete post-recovery proof |
| Transaction object construction | After entry snapshots | Unchanged, after post-proof snapshots |

Static ordering script result: `factory_order_monotonic=True`. Baseline script result: `baseline_recovery_before_stage=True`. Corrected recovery invocation is after stage proof and before post-recovery proof/entry collection.

## Direct target/lock identity proof

- Initial target fstat: line 1850.
- Initial lock fstat: line 1872.
- Direct initial device comparison: line 1875.
- Direct initial inode comparison: line 1876.
- Nonblocking exclusive flock: line 1885.
- Both snapshots must be directories and must have equal device/inode before lock acquisition. Fresh fstats are compared with retained snapshots after lock acquisition, before recovery and after recovery.

## Stage-before-recovery and zero-mutation proof

- Stage open begins at line 1922.
- Stage fstat/directory proof is at line 1937.
- Initial same-device proof is at line 1946.
- Pre-recovery retained stage re-fstat is at line 1967.
- The only factory recovery invocation begins at line 1995.
- Static scan of the factory prefix before that invocation found zero `renameat`, `unlinkat`, `AT_REMOVEDIR`, cleanup-transaction or recover-one-transaction calls.
- Target open/fstat, lock open/fstat/mismatch, flock contention, stage open/path/fstat/type/identity and cross-device failures all close every acquired descriptor. Closing the independent lock descriptor releases the flock. No recovery count is externally exposed because no transaction object is returned.

## Post-recovery authority proof

- The typed `PXDestructivePathValidator` equality check is repeated after stale recovery.
- Canonical path binding is repeated for target and lock descriptors; stage path binding is repeated for the retained stage descriptor.
- Fresh target, lock and stage fstats must match their retained pre-recovery snapshots.
- Direct target/lock device and inode equality is repeated; stage device equality with target is repeated.
- Original entry collection starts at line 2050, after all post-recovery gates.
- Any post-recovery proof failure closes all descriptors and returns before transaction object construction; therefore it cannot create a new workspace or publish a new journal.

## Strict directory and journal durability

- `PXMainDataRestoreSyncDescriptor` starts at line 138.
- It calls `fsync(descriptor)` in a loop only while the result is nonzero and `errno == EINTR`; success is exactly `result == 0`.
- There are zero source occurrences of `EINVAL`, `ENOTSUP`, `EOPNOTSUPP` or `ENOSYS`, so unsupported synchronization is never translated into success.
- `PXMainDataRestoreSyncDirectory` delegates to the strict descriptor helper; all existing transaction-directory, target, original, stage and new directory sync call sites remain.
- Journal file synchronization uses the same retry helper at line 856.
- Complete bounded write, file sync, atomic `renameat` publication and transaction-directory sync remain in the same order. Journal schema and six phases are unchanged.

## Journal, rollback, cleanup and recovery non-regression

- Transaction prefix, `original`, `new`, `journal.plist`, `journal.tmp`, modes 0700/0600 and raw-byte identities are unchanged.
- Prepared journal still precedes the first new-transaction quarantine move.
- Descriptor-relative `renameat` quarantine/install, same-name identity-disambiguated rollback, rollback ordering and failure evidence preservation are unchanged.
- Committed/rolled-back stale cleanup, in-progress stale rollback, multiple-stale fail-closed policy and all fixed limits remain unchanged.
- Bounded no-follow cleanup and manager cleanup-warning/ownership boundaries are untouched because no manager or cleanup architecture changes were made.

## Full production source diff

```diff
diff --git a/PXMainDataRestoreTransaction.m b/PXMainDataRestoreTransaction.m
index c7d2e81..6dd2c42 100644
--- a/PXMainDataRestoreTransaction.m
+++ b/PXMainDataRestoreTransaction.m
@@ -135,11 +135,24 @@ static int PXMainDataRestoreDuplicateDescriptor(int descriptor) {
     return duplicate;
 }

+static BOOL PXMainDataRestoreSyncDescriptor(int descriptor) {
+    int result = -1;
+    do {
+        result = fsync(descriptor);
+    } while (result != 0 && errno == EINTR);
+    return result == 0;
+}
+
 static BOOL PXMainDataRestoreSyncDirectory(int descriptor) {
-    if (fsync(descriptor) == 0) {
-        return YES;
-    }
-    return errno == EINVAL || errno == ENOTSUP;
+    return PXMainDataRestoreSyncDescriptor(descriptor);
+}
+
+static BOOL PXMainDataRestoreStatIdentityMatches(const struct stat *expected,
+                                                 const struct stat *actual) {
+    return expected && actual &&
+           expected->st_dev == actual->st_dev &&
+           expected->st_ino == actual->st_ino &&
+           ((expected->st_mode & S_IFMT) == (actual->st_mode & S_IFMT));
 }

 static NSComparisonResult PXMainDataRestoreCompareRawNames(NSData *left, NSData *right) {
@@ -840,7 +853,7 @@ static BOOL PXMainDataRestoreWriteJournal(int transactionDescriptor,
                  PXMainDataRestoreWriteAll(journalDescriptor,
                                            journalData.bytes,
                                            journalData.length) &&
-                 fsync(journalDescriptor) == 0;
+                 PXMainDataRestoreSyncDescriptor(journalDescriptor);
     int closeResult = close(journalDescriptor);
     if (!wrote || closeResult != 0) {
         unlinkat(transactionDescriptor, temporaryName, 0);
@@ -1831,10 +1844,11 @@ static BOOL PXMainDataRestoreRecoverStaleTransactions(int targetDescriptor,
                                            @"$.destination",
                                            @"The exact main-data destination changed before transaction preparation.");
     }
+
     struct stat targetStat;
     memset(&targetStat, 0, sizeof(targetStat));
     if (fstat(targetDescriptor, &targetStat) != 0 || !S_ISDIR(targetStat.st_mode)) {
-        close(targetDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return PXMainDataRestoreFailObject(error,
                                            PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                            @"$.destination",
@@ -1844,75 +1858,194 @@ static BOOL PXMainDataRestoreRecoverStaleTransactions(int targetDescriptor,
     int lockDescriptor = open(canonicalPath.fileSystemRepresentation,
                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
     if (lockDescriptor < 0 ||
-        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor) ||
-        flock(lockDescriptor, LOCK_EX | LOCK_NB) != 0) {
+        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor)) {
         PXMainDataRestoreCloseDescriptor(&lockDescriptor);
-        close(targetDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return PXMainDataRestoreFailObject(error,
                                            PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                            @"$.destination",
-                                           @"Another main-data transaction is already active for this destination.");
+                                           @"The main-data transaction lock could not be bound safely.");
     }

-    NSUInteger recoveredCount = 0;
-    if (!PXMainDataRestoreRecoverStaleTransactions(targetDescriptor,
-                                                   &targetStat,
-                                                   &recoveredCount,
-                                                   error)) {
-        close(lockDescriptor);
-        close(targetDescriptor);
-        return nil;
+    struct stat lockStat;
+    memset(&lockStat, 0, sizeof(lockStat));
+    if (fstat(lockDescriptor, &lockStat) != 0 ||
+        !S_ISDIR(targetStat.st_mode) ||
+        !S_ISDIR(lockStat.st_mode) ||
+        targetStat.st_dev != lockStat.st_dev ||
+        targetStat.st_ino != lockStat.st_ino) {
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
+        return PXMainDataRestoreFailObject(error,
+                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.destination",
+                                           @"The main-data transaction lock does not protect the exact destination.");
+    }
+
+    if (flock(lockDescriptor, LOCK_EX | LOCK_NB) != 0) {
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
+        return PXMainDataRestoreFailObject(error,
+                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.destination",
+                                           @"Another main-data transaction is already active for this destination.");
     }

     validationError = nil;
     validatedPath = [validator validatedCanonicalPathForContainer:container
                                                             error:&validationError];
+    struct stat targetLockedStat;
+    struct stat lockLockedStat;
+    memset(&targetLockedStat, 0, sizeof(targetLockedStat));
+    memset(&lockLockedStat, 0, sizeof(lockLockedStat));
     if (validationError ||
         validatedPath.length == 0 ||
         ![validatedPath isEqualToString:canonicalPath] ||
         !PXMainDataRestorePathMatchesDescriptor(canonicalPath, targetDescriptor) ||
-        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor)) {
-        close(lockDescriptor);
-        close(targetDescriptor);
+        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor) ||
+        fstat(targetDescriptor, &targetLockedStat) != 0 ||
+        fstat(lockDescriptor, &lockLockedStat) != 0 ||
+        !PXMainDataRestoreStatIdentityMatches(&targetStat, &targetLockedStat) ||
+        !PXMainDataRestoreStatIdentityMatches(&lockStat, &lockLockedStat) ||
+        !S_ISDIR(targetLockedStat.st_mode) ||
+        !S_ISDIR(lockLockedStat.st_mode) ||
+        targetLockedStat.st_dev != lockLockedStat.st_dev ||
+        targetLockedStat.st_ino != lockLockedStat.st_ino) {
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return PXMainDataRestoreFailObject(error,
                                            PXMainDataRestoreTransactionErrorDestinationValidationFailed,
                                            @"$.destination",
-                                           @"The exact main-data destination changed during transaction recovery.");
+                                           @"The exact main-data destination changed before recovery preparation.");
     }

     int stageDescriptor = open(validatedStage.dataPath.fileSystemRepresentation,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
     if (stageDescriptor < 0 ||
         !PXMainDataRestorePathMatchesDescriptor(validatedStage.dataPath, stageDescriptor)) {
-        close(lockDescriptor);
-        close(targetDescriptor);
         PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return PXMainDataRestoreFailObject(error,
                                            PXMainDataRestoreTransactionErrorFilesystemChanged,
                                            @"$.stage",
-                                           @"The validated main-data stage changed before transaction preparation.");
+                                           @"The validated main-data stage changed before recovery preparation.");
     }
+
     struct stat stageStat;
     memset(&stageStat, 0, sizeof(stageStat));
     if (fstat(stageDescriptor, &stageStat) != 0 || !S_ISDIR(stageStat.st_mode)) {
-        close(lockDescriptor);
-        close(targetDescriptor);
-        close(stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return PXMainDataRestoreFailObject(error,
                                            PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                            @"$.stage",
                                            @"The validated main-data stage could not be inspected.");
     }
-    if (targetStat.st_dev != stageStat.st_dev) {
-        close(lockDescriptor);
-        close(targetDescriptor);
-        close(stageDescriptor);
+    if (stageStat.st_dev != targetStat.st_dev) {
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return PXMainDataRestoreFailObject(error,
                                            PXMainDataRestoreTransactionErrorCrossDeviceBoundary,
                                            @"$.stage",
                                            @"The validated main-data stage is not on the destination filesystem.");
     }

+    struct stat targetPreRecoveryStat;
+    struct stat lockPreRecoveryStat;
+    struct stat stagePreRecoveryStat;
+    memset(&targetPreRecoveryStat, 0, sizeof(targetPreRecoveryStat));
+    memset(&lockPreRecoveryStat, 0, sizeof(lockPreRecoveryStat));
+    memset(&stagePreRecoveryStat, 0, sizeof(stagePreRecoveryStat));
+    if (!PXMainDataRestorePathMatchesDescriptor(canonicalPath, targetDescriptor) ||
+        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor) ||
+        !PXMainDataRestorePathMatchesDescriptor(validatedStage.dataPath, stageDescriptor) ||
+        fstat(targetDescriptor, &targetPreRecoveryStat) != 0 ||
+        fstat(lockDescriptor, &lockPreRecoveryStat) != 0 ||
+        fstat(stageDescriptor, &stagePreRecoveryStat) != 0 ||
+        !PXMainDataRestoreStatIdentityMatches(&targetStat, &targetPreRecoveryStat) ||
+        !PXMainDataRestoreStatIdentityMatches(&lockStat, &lockPreRecoveryStat) ||
+        !PXMainDataRestoreStatIdentityMatches(&stageStat, &stagePreRecoveryStat) ||
+        !S_ISDIR(targetPreRecoveryStat.st_mode) ||
+        !S_ISDIR(lockPreRecoveryStat.st_mode) ||
+        !S_ISDIR(stagePreRecoveryStat.st_mode) ||
+        targetPreRecoveryStat.st_dev != lockPreRecoveryStat.st_dev ||
+        targetPreRecoveryStat.st_ino != lockPreRecoveryStat.st_ino) {
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
+        return PXMainDataRestoreFailObject(error,
+                                           PXMainDataRestoreTransactionErrorFilesystemChanged,
+                                           @"$.transaction.preflight",
+                                           @"The main-data transaction identity changed before stale recovery.");
+    }
+    if (stagePreRecoveryStat.st_dev != targetPreRecoveryStat.st_dev) {
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
+        return PXMainDataRestoreFailObject(error,
+                                           PXMainDataRestoreTransactionErrorCrossDeviceBoundary,
+                                           @"$.stage",
+                                           @"The validated main-data stage crossed the destination filesystem boundary.");
+    }
+
+    NSUInteger recoveredCount = 0;
+    if (!PXMainDataRestoreRecoverStaleTransactions(targetDescriptor,
+                                                   &targetStat,
+                                                   &recoveredCount,
+                                                   error)) {
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
+        return nil;
+    }
+
+    validationError = nil;
+    validatedPath = [validator validatedCanonicalPathForContainer:container
+                                                            error:&validationError];
+    struct stat targetPostRecoveryStat;
+    struct stat lockPostRecoveryStat;
+    struct stat stagePostRecoveryStat;
+    memset(&targetPostRecoveryStat, 0, sizeof(targetPostRecoveryStat));
+    memset(&lockPostRecoveryStat, 0, sizeof(lockPostRecoveryStat));
+    memset(&stagePostRecoveryStat, 0, sizeof(stagePostRecoveryStat));
+    if (validationError ||
+        validatedPath.length == 0 ||
+        ![validatedPath isEqualToString:canonicalPath] ||
+        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, targetDescriptor) ||
+        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor) ||
+        !PXMainDataRestorePathMatchesDescriptor(validatedStage.dataPath, stageDescriptor) ||
+        fstat(targetDescriptor, &targetPostRecoveryStat) != 0 ||
+        fstat(lockDescriptor, &lockPostRecoveryStat) != 0 ||
+        fstat(stageDescriptor, &stagePostRecoveryStat) != 0 ||
+        !PXMainDataRestoreStatIdentityMatches(&targetStat, &targetPostRecoveryStat) ||
+        !PXMainDataRestoreStatIdentityMatches(&lockStat, &lockPostRecoveryStat) ||
+        !PXMainDataRestoreStatIdentityMatches(&stageStat, &stagePostRecoveryStat) ||
+        !S_ISDIR(targetPostRecoveryStat.st_mode) ||
+        !S_ISDIR(lockPostRecoveryStat.st_mode) ||
+        !S_ISDIR(stagePostRecoveryStat.st_mode) ||
+        targetPostRecoveryStat.st_dev != lockPostRecoveryStat.st_dev ||
+        targetPostRecoveryStat.st_ino != lockPostRecoveryStat.st_ino) {
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
+        return PXMainDataRestoreFailObject(error,
+                                           PXMainDataRestoreTransactionErrorDestinationValidationFailed,
+                                           @"$.transaction.recovery",
+                                           @"The main-data transaction authority changed during stale recovery.");
+    }
+    if (stagePostRecoveryStat.st_dev != targetPostRecoveryStat.st_dev) {
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
+        return PXMainDataRestoreFailObject(error,
+                                           PXMainDataRestoreTransactionErrorCrossDeviceBoundary,
+                                           @"$.stage",
+                                           @"The validated main-data stage crossed the destination filesystem boundary during recovery.");
+    }
+
     NSArray<PXMainDataRestoreEntry *> *originalEntries =
         PXMainDataRestoreCollectEntries(targetDescriptor,
                                         NO,
@@ -1922,9 +2055,9 @@ static BOOL PXMainDataRestoreRecoverStaleTransactions(int targetDescriptor,
                                         error,
                                         @"$.destination.entries");
     if (!originalEntries) {
-        close(lockDescriptor);
-        close(targetDescriptor);
-        close(stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return nil;
     }
     NSArray<PXMainDataRestoreEntry *> *stagedEntries =
@@ -1936,9 +2069,9 @@ static BOOL PXMainDataRestoreRecoverStaleTransactions(int targetDescriptor,
                                         error,
                                         @"$.stage.entries");
     if (!stagedEntries) {
-        close(lockDescriptor);
-        close(targetDescriptor);
-        close(stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
+        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
+        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
         return nil;
     }
```

## Static gate table

| Gate | Evidence | Result |
|---|---|---|
| Target fstat before recovery | line 1850 before recovery line 1995 | PASS |
| Lock fstat before recovery | line 1872 | PASS |
| Direct target/lock equality before recovery | Explicit `st_dev` and `st_ino` comparisons before flock and pre-recovery | PASS |
| Flock before recovery | line 1885 | PASS |
| Stage open/fstat before recovery | lines 1922 / 1937 | PASS |
| Same-device before recovery | line 1946 and repeated pre-recovery | PASS |
| Recovery call ordering | Monotonic ordering script true; one invocation in factory | PASS |
| Post typed validation | Present immediately after successful recovery | PASS |
| Post direct target/lock equality | Explicit post-recovery `st_dev/st_ino` comparisons | PASS |
| Post stage identity/same-device | Retained snapshot and device equality repeated | PASS |
| Entry collection after proof | Both entry collectors follow post-proof | PASS |
| EINTR retry | Strict fsync loop present | PASS |
| Unsupported sync success branches | Zero EINVAL/ENOTSUP/EOPNOTSUPP/ENOSYS occurrences | PASS |
| Journal file sync | Retry helper retained in bounded journal write | PASS |
| Directory sync call sites | 12 existing caller sites retained | PASS |
| Public header diff | Protected SHA and git diff zero | PASS |
| Manager diff | Protected SHA and git diff zero | PASS |
| Other production diff | All protected production files byte-identical | PASS |
| Objective-C frontend | clangFrontendExit=0 | PASS |
| Whitespace | git diff --check empty | PASS |

## Explicit source/static scenario matrix (100 scenarios)

| # | Scenario | Expected/source result | Gate |
|---:|---|---|---|
| 1 | Invalid public input | Fails before descriptor acquisition; zero recovery mutation. | PASS |
| 2 | Typed destination validation failure | Returns destination-validation failure before target open. | PASS |
| 3 | Target open failure | Returns nil; no lock/stage descriptor; zero recovery. | PASS |
| 4 | Target path replacement during bind | Path-to-descriptor check fails before target fstat/recovery. | PASS |
| 5 | Target fstat failure | Closes target; zero recovery. | PASS |
| 6 | Target is not a directory | O_DIRECTORY/fstat directory gate fails before recovery. | PASS |
| 7 | Lock open failure | Closes target and lock; zero recovery. | PASS |
| 8 | Lock path replacement during bind | Lock path-to-descriptor check fails before lock fstat/recovery. | PASS |
| 9 | Lock fstat failure | Closes lock and target; zero recovery. | PASS |
| 10 | Lock descriptor is not a directory | Direct S_ISDIR gate fails before flock/recovery. | PASS |
| 11 | Target and lock same device/inode | Direct equality permits progression to flock. | PASS |
| 12 | Target and lock distinct device | Direct st_dev inequality fails before flock/recovery. | PASS |
| 13 | Target and lock distinct inode | Direct st_ino inequality fails before flock/recovery. | PASS |
| 14 | Nonblocking flock contention | Closes both descriptors, releasing any ownership; zero recovery. | PASS |
| 15 | Typed destination changes after flock | Second typed validation fails before stage open/recovery. | PASS |
| 16 | Target path changes after flock | Target path authority recheck fails before recovery. | PASS |
| 17 | Lock path changes after flock | Lock path authority recheck fails before recovery. | PASS |
| 18 | Target fstat fails after flock | Retained lock closes; zero recovery. | PASS |
| 19 | Lock fstat fails after flock | Retained lock closes; zero recovery. | PASS |
| 20 | Target identity changes after flock | Initial target snapshot mismatch fails before stage/recovery. | PASS |
| 21 | Lock identity changes after flock | Initial lock snapshot mismatch fails before stage/recovery. | PASS |
| 22 | Stage open failure | Closes stage/lock/target; zero recovery. | PASS |
| 23 | Stage path replacement at initial bind | Stage path-to-descriptor check fails before recovery. | PASS |
| 24 | Stage fstat failure | Closes all descriptors; zero recovery. | PASS |
| 25 | Stage is not a directory | Directory gate fails before recovery. | PASS |
| 26 | Initial cross-device stage | Returns CrossDeviceBoundary before recovery. | PASS |
| 27 | Target path changes while stage is opened | Pre-recovery path recheck fails; zero recovery. | PASS |
| 28 | Lock path changes while stage is opened | Pre-recovery path recheck fails; zero recovery. | PASS |
| 29 | Stage path changes after initial fstat | Pre-recovery stage path recheck fails; zero recovery. | PASS |
| 30 | Target re-fstat failure before recovery | Fails before recovery and closes all descriptors. | PASS |
| 31 | Lock re-fstat failure before recovery | Fails before recovery and closes all descriptors. | PASS |
| 32 | Stage re-fstat failure before recovery | Fails before recovery and closes all descriptors. | PASS |
| 33 | Target identity mismatch before recovery | Retained target snapshot proof fails. | PASS |
| 34 | Lock identity mismatch before recovery | Retained lock snapshot proof fails. | PASS |
| 35 | Stage identity mismatch before recovery | Retained stage snapshot proof fails. | PASS |
| 36 | Target/lock direct mismatch immediately before recovery | Direct device/inode comparison fails. | PASS |
| 37 | Target/lock/stage non-directory on pre-recovery recheck | S_ISDIR gates fail. | PASS |
| 38 | Same-filesystem recheck fails before recovery | Returns CrossDeviceBoundary with zero recovery. | PASS |
| 39 | All pre-recovery proofs pass | Only then is stale recovery invoked; mutator scan before call is zero. | PASS |
| 40 | One stale committed transaction | Recovery cleanup runs only after all source/lock proofs. | PASS |
| 41 | One stale rolled-back transaction | Recovery cleanup runs only after all proofs. | PASS |
| 42 | One stale prepared transaction | Idempotent rollback runs under exact lock and same-device proof. | PASS |
| 43 | One stale quarantined transaction | Rollback state machine remains unchanged and proof-dominated. | PASS |
| 44 | One stale installed transaction | Installed entries roll back using journaled identity. | PASS |
| 45 | One stale rolling-back transaction | Recovery resumes existing rollback state. | PASS |
| 46 | Multiple stale workspaces | Existing fail-closed policy remains unchanged. | PASS |
| 47 | Corrupt stale journal with recovery data | Fails closed and preserves evidence. | PASS |
| 48 | Journal-less empty stale workspace | Existing safe pre-mutation cleanup remains after proof. | PASS |
| 49 | Post-recovery typed destination failure | Closes all descriptors; no new transaction object/workspace. | PASS |
| 50 | Post-recovery target path replacement | Fails before entry collection/new journal. | PASS |
| 51 | Post-recovery lock path replacement | Fails before entry collection/new journal. | PASS |
| 52 | Post-recovery stage path replacement | Fails before entry collection/new journal. | PASS |
| 53 | Post-recovery target fstat failure | Fails and closes all descriptors. | PASS |
| 54 | Post-recovery lock fstat failure | Fails and releases lock by closing descriptor. | PASS |
| 55 | Post-recovery stage fstat failure | Fails before entry collection. | PASS |
| 56 | Post-recovery target identity mismatch | Retained target snapshot comparison fails. | PASS |
| 57 | Post-recovery lock identity mismatch | Retained lock snapshot comparison fails. | PASS |
| 58 | Post-recovery stage identity mismatch | Retained stage snapshot comparison fails. | PASS |
| 59 | Post-recovery target/lock direct mismatch | Repeated direct device/inode equality fails. | PASS |
| 60 | Post-recovery cross-device stage | Returns CrossDeviceBoundary before entry collection. | PASS |
| 61 | Post-recovery proof succeeds | Original/staged entry collection occurs afterward. | PASS |
| 62 | Original entry collection fails | Closes stage, lock and target; returns nil. | PASS |
| 63 | Staged entry collection fails | Closes stage, lock and target; returns nil. | PASS |
| 64 | Transaction object returned | Retains exact lock/target/stage descriptors and original snapshots. | PASS |
| 65 | Recovered count visibility | Count is assigned only when post-proof and object construction succeed. | PASS |
| 66 | Directory fsync succeeds | Sync helper returns YES only from result == 0. | PASS |
| 67 | Directory fsync interrupted once then succeeds | Helper retries EINTR and returns YES after actual success. | PASS |
| 68 | Directory fsync repeatedly interrupted then succeeds | Loop continues only while errno is EINTR. | PASS |
| 69 | Directory fsync returns EINVAL | Returns NO; no unsupported-success branch exists. | PASS |
| 70 | Directory fsync returns ENOTSUP | Returns NO. | PASS |
| 71 | Directory fsync returns EOPNOTSUPP | Returns NO. | PASS |
| 72 | Directory fsync returns ENOSYS | Returns NO. | PASS |
| 73 | Directory fsync returns EIO | Returns NO. | PASS |
| 74 | Journal file fsync gets EINTR then succeeds | Journal uses the same EINTR retry helper. | PASS |
| 75 | Journal file fsync hard failure | Journal write is not considered durable. | PASS |
| 76 | Prepared journal publication directory sync failure | Journal creation fails before first new-transaction move. | PASS |
| 77 | Quarantine directory sync failure | Existing operation error path triggers rollback. | PASS |
| 78 | Install target/stage sync failure | Existing operation error path triggers rollback. | PASS |
| 79 | Rollback directory sync failure | Returns RollbackFailed and preserves evidence. | PASS |
| 80 | Committed journal directory sync failure | Committed success is not exposed. | PASS |
| 81 | Rolled-back journal directory sync failure | Recovery state remains available/fail-closed. | PASS |
| 82 | Cleanup sync failure after durable commit | Existing warning-only cleanup boundary remains. | PASS |
| 83 | Public API audit | Header byte hash unchanged; 12-code enum untouched. | PASS |
| 84 | Manager integration audit | AppDataBackupManager.m hash unchanged; code 317 mapping untouched. | PASS |
| 85 | Journal schema audit | Version, keys and six phase strings unchanged. | PASS |
| 86 | App Group transaction audit | No App Group production file changed. | PASS |
| 87 | Optional transaction audit | No optional production file changed. | PASS |
| 88 | Protected hash audit | All 20 protected hashes match before/after. | PASS |
| 89 | Whitespace audit | git diff --check passes. | PASS |
| 90 | NUL and line-ending audit | Source contains zero NUL, zero mixed CRLF/bare-CR. | PASS |
| 91 | Objective-C frontend audit | clang-tidy frontend parse exits 0. | PASS |
| 92 | Error privacy audit | New failures use generic descriptions; no path/device/inode/bundle values exposed. | PASS |
| 93 | No shell/global synchronization | No shell sync, helper process or global sync() added. | PASS |
| 94 | Preflight descriptor close audit | Every pre-recovery failure closes all descriptors acquired so far. | PASS |
| 95 | Lock release audit | Closing lockDescriptor releases flock on every failure path. | PASS |
| 96 | Post-proof mutation boundary | Post-recovery failure cannot create workspace or publish a new journal. | PASS |
| 97 | Metadata preservation audit | Reserved metadata-name policy unchanged. | PASS |
| 98 | Rename transaction audit | Existing descriptor-relative renameat quarantine/install unchanged. | PASS |
| 99 | Same-name rollback audit | Device/inode/type identity disambiguation unchanged. | PASS |
| 100 | Report termination audit | Report ends with the two exact required status lines. | PASS |

## Whitespace, line-ending and NUL audit

- `git diff --check -- PXMainDataRestoreTransaction.m`: PASS, no output.
- Corrected source bytes before commit: 115847; CRLF pairs: 0; bare LF: 2513; bare CR: 0; NUL: 0; final newline: present.
- The working copy is consistently LF. Git emitted only the repository `core.autocrlf` advisory that LF would be replaced by CRLF on a future checkout; there is no mixed-line-ending content in the file.
- Report is generated as UTF-8 LF and audited again before commit.

## Build status and remaining runtime risks

- Full Theos/iOS build was unavailable in this Windows workspace: `THEOS` is empty and `make`, `clang` and `xcrun` are not available on PATH.
- The local LLVM Objective-C frontend parse completed with `clangFrontendExit=0`.
- Remaining target-device risks require GitHub Actions and device fault injection: actual Darwin directory-fsync support on every supported filesystem, crash points around journal publication/rename ordering, flock behavior across processes, and stale-recovery interruption under low-storage/I/O faults.
- No TASK-2.12, TASK-2.13 or TASK-2.14 work was performed.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
