# TASK-2.12 — Transactional App Group Commit and Rollback

## Status

```text
READY
```

## Baseline

```text
9790a22ebee3b617a6fdd6cab0e0bba6b61dc45d
```

Accepted prerequisites:

```text
TASK-2.9   — exact App Group target planning and validated staging
TASK-2.11  — transactional main-data commit and rollback
TASK-2.11A — pre-recovery proof and strict durability correction
```

TASK-2.13 and later tasks remain locked.

## Objective

Replace the accepted App Group mutation sequence:

```text
for each physical target:
    stage all equivalent sources
    revalidate target models
    wipe target
    tar/cp clone validated stage
```

with one bounded multi-target transaction that:

1. stages and validates every physical App Group target before any App Group target mutation;
2. binds every exact target, independent lock and validated stage descriptor;
3. proves every target/stage pair is same-filesystem before stale recovery or new mutation;
4. acquires all target locks in deterministic order;
5. recovers one prior incomplete App Group batch safely;
6. writes one durable leader decision journal for the complete target set;
7. quarantines all original target namespaces descriptor-relatively;
8. installs all validated staged namespaces descriptor-relatively;
9. commits the whole App Group batch with one durable decision point;
10. rolls back every affected physical target if any pre-commit step fails;
11. recovers interrupted committed, rolled-back or in-progress batches;
12. never reports App Group success while only a subset of the physical targets is accepted.

This task covers App Group physical targets only. It does not make main data, profile AppData, global Safari, system-global, shared DB, Preferences or Keychain one global transaction.

## Authorized production scope

Create:

```text
PXAppGroupRestoreTransaction.h
PXAppGroupRestoreTransaction.m
```

Modify:

```text
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.12-REPORT.md
```

Implementation commit may contain only those three production files plus the report.

## Protected accepted source

The following must remain byte-identical:

```text
PXMainDataRestoreTransaction.h
PXMainDataRestoreTransaction.m
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
PXBackupManifestValidator.h
PXBackupManifestValidator.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
PXDataContainerResolver.h
PXDataContainerResolver.m
AppDataBackupManager.h
Makefile
```

UI, Backup and Keychain sources are protected.

# Part 1 — Exact public API

Create `PXAppGroupRestoreTransaction.h` with:

```objc
FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTransactionErrorDomain;
FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTransactionErrorFieldPathKey;
```

Export exactly these 15 stable error codes:

```text
InvalidInput = 1
TargetValidationFailed = 2
FilesystemInspectionFailed = 3
LockFailed = 4
CrossDeviceBoundary = 5
EntryLimitExceeded = 6
JournalCreationFailed = 7
JournalInvalid = 8
QuarantineFailed = 9
CommitFailed = 10
RollbackFailed = 11
CleanupFailed = 12
FilesystemChanged = 13
InconsistentBatch = 14
RecoveryFailed = 15
```

Create one non-subclassable public class:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTransaction : NSObject

@property (nonatomic, assign, readonly, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readonly) BOOL rollbackPerformed;
@property (nonatomic, assign, readonly) BOOL rollbackComplete;
@property (nonatomic, assign, readonly) NSUInteger recoveredStaleBatchCount;
@property (nonatomic, assign, readonly) NSUInteger targetCount;

+ (nullable instancetype)transactionForTargets:(NSArray<PXAppGroupRestoreTarget *> *)targets
                               validatedStages:(NSArray<PXValidatedMainDataStage *> *)validatedStages
                                         error:(NSError * _Nullable * _Nullable)error;

- (BOOL)commitWithCleanupWarning:(NSError * _Nullable * _Nullable)cleanupWarning
                           error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
```

No other public factory, initializer, raw canonical-path argument, group-ID argument, manifest argument, shell API, staging API or transaction-control method is allowed.

The two input arrays are parallel and preserve `PXAppGroupRestoreTargetPlan.targets` order. The implementation must reject count mismatch rather than guessing a mapping.

# Part 2 — Public object boundary

The transaction object must:

- retain exact immutable `PXAppGroupRestoreTarget` objects;
- retain exact immutable `PXValidatedMainDataStage` objects;
- copy both input arrays;
- expose no mutable collection;
- expose no descriptor, canonical path, journal contents, workspace name or group identifier;
- be one-shot;
- keep public state read-only;
- close every retained descriptor in `dealloc`;
- never perform an implicit successful commit from `dealloc`.

A failed or abandoned object may attempt rollback only when a prepared transaction exists and durable committed state has not been reached.

# Part 3 — Error privacy

Clear `*error` and `*cleanupWarning` at API entry.

Every transaction-domain error must contain only:

```text
NSLocalizedDescriptionKey
PXAppGroupRestoreTransactionErrorFieldPathKey
```

Do not expose:

- group identifiers;
- canonical paths;
- stage paths;
- UUIDs;
- target indexes;
- archive names;
- inode/device values;
- journal contents;
- batch UUID;
- nested resolver/validator errors;
- errno text;
- shell output.

Use stable field paths such as:

```text
$
$.targets
$.target
$.stage
$.locks
$.recovery
$.journal
$.transaction.quarantine
$.transaction.commit
$.transaction.rollback
$.transaction.cleanup
```

# Part 4 — Fixed limits

Use exact private limits:

```text
maximum physical targets:              256
maximum top-level entries per target:  100000
maximum aggregate top-level entries:   500000
maximum cleanup entries per workspace: 500000
maximum cleanup depth:                 2048
maximum component bytes:               255
maximum leader journal bytes:          128 MiB
maximum stale batch IDs:               1
maximum workspace entries:             4
```

All count and byte arithmetic must be overflow-safe before allocation or append.

Boundaries must be explicit in the report.

# Part 5 — Deterministic target and lock order

The factory receives targets and stages in Restore-plan order. Preserve that order as commit order.

For lock acquisition:

1. derive each target's exact canonical UTF-8 bytes without lossy conversion;
2. reject invalid, empty or duplicate canonical paths defensively;
3. sort lock records by exact UTF-8 byte order;
4. acquire locks in that deterministic order;
5. retain Restore-plan order separately for quarantine/install/rollback reporting semantics.

Reject two target objects that resolve to the same physical target device/inode even if their strings differ. `PXAppGroupRestoreTargetPlan` should already collapse them; the transaction must defend the invariant.

# Part 6 — Exact target-model authority

For every target:

- require runtime `PXAppGroupRestoreTarget`;
- require nonempty `containerModels`;
- require nonempty canonical path;
- require nonempty `groupIdentifiers`;
- require runtime `PXValidatedMainDataStage` with nonempty data path and 64-character tree digest;
- call `PXDestructivePathValidator` for every retained model;
- require every validator output exact-equal the target's stored canonical path;
- do not select one model as a weaker authority;
- do not replace the stored canonical path with a later output;
- do not read manifest path/UUID fields;
- do not invoke legacy aggregate App Group resolution.

A model validation error or mismatch fails with `TargetValidationFailed` before stale recovery or new transaction mutation.

# Part 7 — Target, lock and stage descriptor proof

For every target, before stale recovery:

1. open target directory with `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`;
2. bind path and target descriptor by `lstat`/`fstat` device+inode;
3. open an independent lock descriptor with the same flags;
4. bind lock path and descriptor;
5. `fstat` target and lock;
6. require both directories;
7. require exact target/lock device and inode equality;
8. acquire `flock(LOCK_EX|LOCK_NB)` in deterministic lock order;
9. revalidate all target models;
10. repeat target/lock path, device, inode and type proof;
11. open stage directory no-follow/CLOEXEC;
12. bind stage path and descriptor;
13. `fstat` stage and require directory;
14. require stage device equals target device;
15. repeat target/lock/stage path and retained identity proof immediately before recovery.

All target/lock/stage pairs for the complete batch must pass before the first stale-recovery mutation.

On any failure:

- close all stages opened so far;
- close all target descriptors;
- close all lock descriptors, releasing acquired locks;
- perform zero stale recovery;
- create no transaction workspace;
- publish no new journal.

# Part 8 — Strict synchronization

Every file or directory synchronization helper must:

- retry only when `errno == EINTR`;
- return success only when the synchronization primitive returns success;
- fail closed for `EINVAL`, `ENOTSUP`, `EOPNOTSUPP`, `ENOSYS` and all other errors.

Do not use:

- `sync()`;
- shell `sync`;
- helper process;
- unsupported-error-as-success behavior.

The leader journal file must be completely written and synchronized before atomic publication. Every journal rename must be followed by successful leader-workspace directory synchronization.

Target, original, new and stage directories must be synchronized at their required state transitions.

# Part 9 — Reserved App Group transaction namespace

Reserve top-level target names beginning with:

```text
.weaponx-app-group-restore-
```

A staged App Group root entry using that prefix must be rejected.

One batch UUID is shared by every participant workspace. Workspace names must encode:

```text
prefix + batch UUID + deterministic lock-order ordinal
```

The exact encoding must be strict, bounded and parseable without path normalization.

For each target create one private workspace inside that target with mode `0700`.

Every participant workspace contains:

```text
original/
new/
```

The ordinal-zero leader workspace may additionally contain:

```text
batch.plist
batch.tmp
```

No other entry is allowed.

`original/` and `new/` must be mode `0700`, no-follow directories on the target filesystem.

# Part 10 — Container metadata preservation

Independently reject staged root entries:

```text
.com.apple.mobile_container_manager.metadata.plist
.com.apple.containermanagerd.metadata.plist
```

If such files exist in the current App Group target, they must remain in place and must not appear in original-entry quarantine lists.

They must not be replaced, removed, chowned through a retained transaction workspace or represented as mutable transaction entries.

# Part 11 — Leader journal contract

The ordinal-zero target is the leader. Leader selection is the first target in deterministic canonical UTF-8 lock order, not caller-controlled.

Before the first original entry move, publish one bounded binary property-list leader journal containing:

```text
version
batch identifier
phase
participant count
participants[]
```

Each participant record must include at least:

```text
lock-order ordinal
Restore-plan order index
exact ordered groupIdentifiers
workspace name as raw bytes
target device
target inode
originalEntries[]
stagedEntries[]
```

Each entry identity must include:

```text
raw name bytes
device
inode
file type
```

Do not include an authoritative destination path. Any optional diagnostic path string in the private journal has zero open/mutation authority and is not required.

Participant and entry arrays must be deterministic, duplicate-free, bounded and structurally validated on read.

Exact phases:

```text
prepared
quarantined
installed
committed
rolling-back
rolled-back
```

No additional phase is allowed.

Journal publication:

1. remove only a safe stale `batch.tmp` inside the retained leader workspace;
2. open `batch.tmp` with `O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`, mode `0600`;
3. verify regular file, single link and same filesystem;
4. complete bounded write;
5. strict file synchronization;
6. close successfully;
7. atomic `renameat` to `batch.plist`;
8. strict leader-workspace directory synchronization.

A committed result is forbidden before durable `committed` publication.

# Part 12 — Pre-transaction stale batch discovery

After every new target, lock and new stage has passed complete pre-recovery proof, scan every target descriptor for the reserved prefix.

Rules:

- zero stale batch IDs: continue;
- one stale batch ID: recover or clean it;
- more than one batch ID across the target set: fail closed;
- duplicate participant ordinals: fail closed;
- malformed reserved name: fail closed;
- symlink/non-directory workspace: fail closed;
- workspace on another device: fail closed.

Recovery must not trust journal path strings. Current exact target objects, current model validation and retained target descriptors remain authority.

# Part 13 — Stale batch journal-to-current-plan binding

When a leader journal exists, require the journal participant set to exact-match the current transaction target set:

- same participant count;
- same deterministic lock-order ordinals;
- same Restore-plan order indexes;
- same exact ordered group identifier arrays;
- same target device/inode identities;
- exact workspace names;
- no duplicate participant identity.

If the stale batch cannot be mapped exactly to all current targets, fail closed and preserve recovery evidence. Do not recover a guessed subset.

After recovery, repeat for every target:

- all model validations;
- target path/descriptor identity;
- lock path/descriptor identity;
- direct target/lock equality;
- stage path/descriptor identity;
- stage/target same-device equality.

Collect new original/staged entry snapshots only after all post-recovery proofs pass.

# Part 14 — No-journal stale workspace policy

If no published leader journal exists:

- all detected participant workspaces must belong to one parseable batch ID;
- `original/` and `new/` must exist as exact no-follow directories or the workspace may be an already-empty partial-creation directory;
- every recovery directory must be empty;
- leader `batch.tmp`, when present, must be a bounded single-link regular file;
- no other entry is allowed.

Only this proven pre-mutation state may be cleaned.

If any original/new recovery data exists without a valid leader journal, fail closed and preserve all workspaces.

# Part 15 — Stale phase recovery

For `committed`:

- the durable batch decision is commit;
- never roll back;
- require every target namespace exact-match its journaled staged entries;
- finish participant cleanup;
- missing already-cleaned nonleader workspace is allowed only when its target namespace exactly matches staged entries;
- remove leader journal/workspace last.

For `rolled-back`:

- require every target namespace exact-match original entries;
- finish cleanup;
- missing already-cleaned participant workspace is allowed only when the exact original namespace is proven.

For `prepared`, `quarantined`, `installed` or `rolling-back`:

- require all participant workspaces and recovery directories;
- perform the same idempotent whole-batch rollback;
- publish `rolled-back` durably in the leader;
- then cleanup.

If leader journal is missing/corrupt while recovery data exists, or if rollback cannot prove the complete original batch namespace, return failure and preserve evidence.

# Part 16 — Complete snapshot before mutation

After stale recovery and post-recovery proof, collect for every target:

- exact current top-level original entry identities, excluding container metadata and reserved transaction names;
- exact staged top-level entry identities, rejecting metadata and reserved names.

Enforce per-target and aggregate limits before creating any new transaction workspace.

Require exact stage snapshot stability again immediately before workspace creation.

# Part 17 — New batch workspace preparation

Create all participant workspaces before publishing `prepared`.

If any workspace creation or identity proof fails:

- cleanup every newly created empty workspace best effort;
- perform zero original-entry move;
- return failure.

After all workspaces and original/new directories exist:

- strict-sync each participant workspace;
- strict-sync each target directory;
- publish the complete `prepared` leader journal.

No target original entry may move before `prepared` is durable.

# Part 18 — Whole-batch quarantine

Commit order is Restore-plan target order.

For every target:

1. identity-check each planned original entry in target;
2. require same-name destination absent in that target's `original/`;
3. move with descriptor-relative `renameat`;
4. verify identity in `original/` after move.

After all targets:

- strict-sync every target and every original directory;
- require each operational target namespace is empty except preserved metadata and reserved workspace;
- require every original directory exactly matches its journal list;
- publish durable `quarantined` in leader.

A failure at any point triggers whole-batch rollback.

# Part 19 — Whole-batch install

For every target in Restore-plan order:

1. identity-check each staged entry in its retained stage descriptor;
2. require same-name destination absent in target;
3. move with descriptor-relative `renameat`;
4. verify identity in target after move.

After all targets:

- strict-sync every target and every stage directory;
- require every target operational namespace exactly matches its staged journal identities;
- require every stage top-level namespace is empty;
- publish durable `installed` in leader.

Do not use tar-pipe, `cp`, `_wipeDirectoryContents:` or archive extraction for App Group commit.

# Part 20 — Final authority and durable commit decision

Immediately before durable commit:

- revalidate every model for every target;
- require exact stored canonical paths;
- repeat target/lock path and retained identity checks;
- repeat direct target/lock equality;
- repeat target namespace equality with staged entries;
- require all locks still held;
- require all stage namespaces empty.

Then publish leader phase `committed` durably.

Only after successful publication:

```text
committed = YES
```

The leader `committed` phase is the single batch decision point. Participant cleanup state must never override that decision.

# Part 21 — Whole-batch rollback

Any failure after durable `prepared` and before durable `committed` must attempt rollback across all targets.

Rollback order:

1. publish `rolling-back` when possible;
2. iterate targets in reverse Restore-plan order;
3. move installed staged entries from target to that participant's `new/`, using journaled identity;
4. restore quarantined original entries from `original/` to target;
5. synchronize every target, original and new directory;
6. require every target operational namespace exactly matches its original journal entries;
7. publish durable `rolled-back` in leader;
8. set `rollbackPerformed = YES` and `rollbackComplete = YES`;
9. cleanup all participant workspaces.

Same-name old/new entries must be distinguished by device/inode/type, not name alone.

An original entry still in target during partial quarantine must not be treated as an installed staged entry.

If any target cannot be proven and restored:

- return `RollbackFailed`;
- set `rollbackComplete = NO`;
- preserve the leader journal and every participant workspace;
- never report success;
- do not cleanup evidence.

# Part 22 — Cleanup order

Cleanup must be descriptor-relative, no-follow, bounded, same-filesystem and idempotent.

For a committed or rolled-back batch:

1. remove contents of every participant `original/` and `new/` post-order;
2. remove those directories;
3. remove already-cleaned nonleader participant workspaces;
4. retain leader journal while any participant cleanup remains incomplete;
5. remove leader `batch.tmp`;
6. remove leader `batch.plist`;
7. sync leader workspace;
8. remove leader workspace last;
9. sync leader target directory.

Nested mount/device changes fail cleanup.

After durable commit, cleanup failure is a warning and must not cause rollback. Recovery evidence remains root-owned.

# Part 23 — Transaction factory postconditions

A successful factory returns an object only after:

- every target/model is accepted;
- every target and lock descriptor is exact-bound;
- all locks are acquired;
- every stage is exact-bound;
- all target/stage pairs are same-filesystem;
- stale recovery completed safely;
- all post-recovery proofs passed;
- deterministic original/staged snapshots were collected;
- all limits passed.

The factory must not create a new batch workspace or journal. New workspace creation belongs to `commitWithCleanupWarning:error:` after one more complete revalidation.

# Part 24 — Manager staging restructuring

Add exactly one import:

```objc
#import "PXAppGroupRestoreTransaction.h"
```

Preserve App Group source staging and equivalence semantics from TASK-2.9, but restructure the manager so it stages **all physical targets** before any App Group target mutation.

Maintain parallel arrays in exact target-plan order:

```text
retained App Group staging workspaces
retained PXValidatedMainDataStage objects
```

For every physical target:

- validate all archive summaries;
- stage every planned source;
- require source equivalence for shared physical targets;
- retain only the first equivalent workspace/stage;
- cleanup duplicate equivalent workspaces;
- append the retained workspace/stage only after the complete target source set is accepted.

If any later target staging fails, cleanup every retained workspace from all earlier targets before return.

No App Group target revalidation, wipe, tar/cp clone or chown may occur inside the staging loop.

# Part 25 — Manager transaction integration

After all physical target stages are accepted:

1. require workspace/stage count exact-equals target count;
2. call `transactionForTargets:validatedStages:error:` exactly once;
3. on factory failure, cleanup every retained staging workspace;
4. call `commitWithCleanupWarning:error:` exactly once;
5. on commit failure, cleanup every retained staging workspace;
6. record only generic rollback/completion counts in debug output;
7. on success, cleanup every retained staging workspace;
8. if transaction cleanup warning exists, add exactly:

```text
App Group transaction cleanup failed; ownership correction was skipped
```

9. only when no transaction cleanup warning exists, perform current recursive `chown -R mobile:mobile` once per canonical physical target;
10. if staging cleanup fails after accepted transaction, add existing generic warning:

```text
App Group staging cleanup failed
```

Do not expose target paths, group IDs, journal names or transaction errors in warnings/debug output.

# Part 26 — Manager error mapping

Preserve existing manager codes:

Target validation/authority failure:

```text
domain: PXBackupErrorDomain
code: 319
description: Exact App Group restore target could not be revalidated safely
```

All other App Group transaction prepare/commit/rollback failures:

```text
domain: PXBackupErrorDomain
code: 310
description: Failed to commit validated App Group stages transactionally
```

Staging extraction and staged-tree failures keep their accepted behavior.

A transaction-domain nested error must not be copied into the public manager error description.

# Part 27 — Remove legacy App Group mutation boundary

Inside Restore, remove App Group uses of:

```text
_wipeDirectoryContents:target.canonicalPath
appGroupTarPipeCloneExit
appGroupCpCloneExit
tar-pipe clone from retainedGroupStage.dataPath
cp -a retainedGroupStage.dataPath into target
per-target clone failure after wipe
```

After TASK-2.12:

```text
App Group wipe calls:                 0
App Group tar-pipe clone calls:       0
App Group cp clone calls:             0
App Group direct stage-to-shell use:  0
App Group transaction factory calls:  1
App Group transaction commit calls:   1
```

Archive extraction into private staging remains unchanged.

# Part 28 — Preserve high-level component order

Keep:

```text
main ApplicationData transaction
profile AppData
Global Safari
App Group batch transaction
system-global
shared-system DB
Preferences
Keychain
```

TASK-2.12 does not roll back main/profile/Safari if App Group transaction fails. It guarantees only that the App Group physical-target set is committed or rolled back as one batch.

# Part 29 — Preserve accepted source and behavior

Do not modify:

- main-data transaction implementation;
- main-data staging implementation;
- App Group target planner;
- optional destination/file staging;
- immutable Restore plan;
- manifest/artifact/archive validators;
- exact resolver/path validator;
- Backup/UI/Keychain behavior;
- tar archive extraction behavior;
- optional component mutation behavior;
- structured `PXRestoreResult`.

Do not implement TASK-2.13 or TASK-2.14.

# Part 30 — Pure transaction source boundary

`PXAppGroupRestoreTransaction.m` may import only:

```objc
#import "PXAppGroupRestoreTransaction.h"
#import "PXAppGroupRestoreTargetPlan.h"
#import "PXMainDataStaging.h"
#import "PXResolvedContainer.h"
#import "PXDestructivePathValidator.h"
#import <Foundation/Foundation.h>
```

and required CoreFoundation/POSIX headers.

Forbidden:

```text
UIKit
AppDataBackupManager
CommandRunner
NSTask
posix_spawn
system
popen
shell commands
tar/cp/rm invocation
dispatch
NSUserDefaults
Security/Keychain
filesystem copy APIs
archive extraction
raw-value logging
global mutable state
```

All mutation must use retained descriptors and POSIX descriptor-relative operations.

# Part 31 — Required non-regression hashes

Record before/after hashes for at least:

```text
PXMainDataRestoreTransaction.h/.m
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXOptionalRestoreStaging.h/.m
PXRestorePlan.h/.m
PXBackupArchiveValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXDestructivePathValidator.h/.m
PXDataContainerResolver.h/.m
AppDataBackupManager.h
Makefile
```

Record before/after body hashes for manager methods/helpers whose behavior must remain unchanged outside the App Group block, including:

```text
_tarExtract:archive:toDir:
main transaction integration
profile AppData restore block
Global Safari restore block
system-global restore block
shared-system DB restore block
Preferences restore block
Keychain restore block
```

# Part 32 — Static gates

Scope:

```text
PXAppGroupRestoreTransaction.h added
PXAppGroupRestoreTransaction.m added
AppDataBackupManager.m modified
TASK-2.12-REPORT.md added
all other production diffs = 0
```

Public API:

```text
error domain exports = 1
field-path exports = 1
error codes = 15
public transaction classes = 1
public factories = 1
public commit methods = 1
public readwrite properties = 0
subclassing restricted = 1
```

Preflight:

```text
target/model validation for every target
lock order deterministic
all target/lock direct identities before recovery
all stages open before recovery
all target/stage same-device proofs before recovery
recovery after complete batch proof
post-recovery proof for every target/stage
entry snapshots after recovery
```

Durability:

```text
strict fsync EINTR retry
EINVAL-as-success = 0
ENOTSUP-as-success = 0
EOPNOTSUPP-as-success = 0
ENOSYS-as-success = 0
leader journal file sync retained
leader directory sync retained
```

Manager:

```text
all physical targets staged before factory
transaction factory calls = 1
transaction commit calls = 1
App Group wipe calls = 0
App Group tar-pipe clone markers = 0
App Group cp clone markers = 0
direct validated stage path in App Group shell clone = 0
cleanup-all-prior-stages on staging failure = present
transaction cleanup warning exact = 1
chown gated by cleanup warning = present
```

# Part 33 — Scenario matrix

The report must contain at least **210 explicit scenarios**, including:

1. zero target rejection;
2. target/stage count mismatch;
3. one target success;
4. 256 targets boundary;
5. 257 targets rejection;
6. invalid target object;
7. invalid stage object;
8. duplicate canonical path;
9. duplicate physical inode under distinct path;
10. invalid UTF-8 canonical path;
11. empty model list;
12. one model mismatch;
13. multiple model validation success;
14. validator error privacy;
15. deterministic lock ordering;
16. opposite caller order yields same lock order;
17. target open failure;
18. target symlink;
19. target fstat failure;
20. lock open failure;
21. target/lock inode mismatch;
22. lock contention;
23. stage open failure;
24. stage symlink;
25. stage fstat failure;
26. cross-device stage;
27. later target cross-device failure closes earlier locks;
28. complete batch proof before recovery;
29. zero mutation on every pre-recovery failure;
30. one stale batch detection;
31. multiple stale batch IDs;
32. malformed reserved name;
33. duplicate participant ordinal;
34. stale target-set mismatch;
35. stale group-ID mismatch;
36. stale target identity mismatch;
37. no-journal empty workspaces cleanup;
38. no-journal recovery data rejection;
39. corrupt leader journal;
40. oversized leader journal;
41. invalid journal numeric value;
42. duplicate journal participant;
43. duplicate journal entry;
44. reserved journal entry;
45. metadata journal entry;
46. committed stale cleanup;
47. rolled-back stale cleanup;
48. prepared stale rollback;
49. quarantined stale rollback;
50. installed stale rollback;
51. rolling-back stale continuation;
52. committed missing cleaned participant workspace;
53. committed missing workspace with namespace mismatch;
54. rolled-back missing cleaned workspace;
55. post-recovery target replacement;
56. post-recovery lock replacement;
57. post-recovery stage replacement;
58. post-recovery cross-device change;
59. aggregate entry limit exact boundary;
60. aggregate entry limit overflow;
61. workspace creation first target failure;
62. workspace creation later target failure cleanup;
63. prepared journal file creation;
64. partial journal write;
65. journal file fsync EINTR retry;
66. journal file fsync failure;
67. directory fsync EINVAL failure;
68. directory fsync ENOTSUP failure;
69. prepared durable before first move;
70. partial first-target quarantine rollback;
71. partial later-target quarantine rollback;
72. all-target quarantine namespace proof;
73. original directory mismatch;
74. quarantine target sync failure;
75. quarantine journal publish failure;
76. partial first-target install rollback;
77. partial later-target install rollback;
78. all-target install namespace proof;
79. stage nonempty after install;
80. install target sync failure;
81. installed journal publish failure;
82. final one-model validation failure;
83. final target/lock mismatch;
84. final namespace mismatch;
85. committed journal publish failure rollback;
86. durable committed decision success;
87. no rollback after committed cleanup failure;
88. same-name old/new identity separation;
89. original remains during partial quarantine;
90. staged entry already in new directory;
91. rollback reverse target order;
92. rollback original restore failure;
93. rollback exact namespace mismatch;
94. rolled-back journal failure preserves evidence;
95. rollback cleanup failure warning;
96. committed cleanup nonleader first;
97. leader journal removed last;
98. nested mount cleanup rejection;
99. cleanup entry limit;
100. cleanup depth limit;
101. manager stages one target;
102. manager stages all targets before transaction;
103. manager later staging failure cleans prior workspaces;
104. shared-target equivalent source acceptance;
105. shared-target conflicting source rejection;
106. duplicate stage cleanup failure;
107. transaction factory failure cleanup;
108. transaction commit failure cleanup;
109. rollback debug contains no raw values;
110. manager code 319 mapping;
111. manager code 310 mapping;
112. exact cleanup warning;
113. chown after clean transaction;
114. chown skipped with retained recovery workspace;
115. staging cleanup warning after success;
116. zero App Group wipe calls;
117. zero App Group tar clone;
118. zero App Group cp clone;
119. main transaction byte-identical;
120. optional staging byte-identical;
121. component order retained;
122. TASK-2.13 absent;
123. TASK-2.14 absent.

Add race, crash-phase, descriptor-close, journal corruption, cleanup and compilation scenarios until the total reaches at least 210.

# Part 34 — Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.12-REPORT.md
```

The report must include:

- baseline and exact scope;
- protected hashes;
- exact public API and 15-code enum;
- deterministic lock/leader selection;
- target/model authority proof;
- complete-batch stage/same-filesystem proof before recovery;
- stale batch discovery and current-plan binding;
- no-journal policy;
- leader journal schema and phase table;
- one durable batch decision proof;
- metadata/reserved-name proof;
- aggregate limits;
- whole-batch quarantine/install sequence;
- rollback matrix across multiple targets;
- same-name identity proof;
- cleanup ordering and leader-last proof;
- strict synchronization behavior;
- manager all-stage-before-transaction restructuring;
- manager error/warning mapping;
- zero wipe/tar/cp App Group mutation proof;
- TASK-2.11/2.11A non-regression;
- TASK-2.13/2.14 boundaries;
- complete source diff;
- static/forbidden counts;
- at least 210 explicit scenarios;
- whitespace/CRLF/NUL audit;
- build status and target-device risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 35 — Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 9790a22ebee3b617a6fdd6cab0e0bba6b61dc45d..HEAD --check
git diff --name-status 9790a22ebee3b617a6fdd6cab0e0bba6b61dc45d..HEAD
git status --short --untracked-files=all
```

Implementation commit must contain only:

```text
PXAppGroupRestoreTransaction.h
PXAppGroupRestoreTransaction.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.12-REPORT.md
```

Suggested commit subject:

```text
phase2(task-2.12): add transactional app group commit
```

# Stop condition

Stop after TASK-2.12 implementation, report and implementation commit.

Do not implement TASK-2.13 or TASK-2.14.
