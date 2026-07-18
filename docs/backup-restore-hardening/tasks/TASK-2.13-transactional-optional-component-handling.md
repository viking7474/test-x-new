# TASK-2.13 — Transactional Optional-Component Handling

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `9e83a053c4d4e2e42e0eac0a207467a5df2b3251`
- Previous task: TASK-2.12 source review ACCEPTED
- Next task: TASK-2.14 remains LOCKED

## Objective

Replace the remaining nontransactional filesystem mutations for optional Restore components with journaled, identity-bound, same-filesystem transactions.

TASK-2.13 covers these filesystem transaction domains while preserving the current high-level Restore order:

1. profile AppData — one directory-contents transaction;
2. global Safari — one directory-contents transaction;
3. system-global Library items — one multi-item directory-object transaction;
4. shared-system database files — one multi-item file-object transaction;
5. Preferences — one file-object transaction.

Keychain is intentionally not a filesystem transaction participant. The accepted staged Keychain input, groups, method, in-app decision and warning-only execution behavior remain unchanged. Reversible Keychain item semantics belong to Phase 4.

TASK-2.13 does not create one global transaction across main data, App Groups and optional components. A later transaction domain may fail after an earlier domain was durably committed. The task must report only the atomicity it actually provides.

## Production scope

Create:

```text
PXOptionalRestoreTransaction.h
PXOptionalRestoreTransaction.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-2.13-REPORT.md
```

No other production file may change.

Implementation commit may contain only:

```text
PXOptionalRestoreTransaction.h
PXOptionalRestoreTransaction.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.13-REPORT.md
```

## Protected production files

The following must remain byte-identical:

```text
AppDataBackupManager.h
PXMainDataRestoreTransaction.h
PXMainDataRestoreTransaction.m
PXAppGroupRestoreTransaction.h
PXAppGroupRestoreTransaction.m
PXMainDataStaging.h
PXMainDataStaging.m
PXAppGroupRestoreTargetPlan.h
PXAppGroupRestoreTargetPlan.m
PXOptionalRestoreStaging.h
PXOptionalRestoreStaging.m
PXRestorePlan.h
PXRestorePlan.m
PXBackupManifestValidator.h
PXBackupManifestValidator.m
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
PXBackupArchiveValidator.h
PXBackupArchiveValidator.m
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
CommandRunner.h
CommandRunner.m
Makefile
```

Do not modify UI/controller, Backup, Keychain helper, Keychain bridge, entitlement or resolver source.

Do not stage, revert or rewrite coordinator task/review/status/roadmap/decision files.

# Part 1 — Exact public API

Create `PXOptionalRestoreTransaction.h`.

Export exactly:

```objc
FOUNDATION_EXPORT NSString * const PXOptionalRestoreTransactionErrorDomain;
FOUNDATION_EXPORT NSString * const PXOptionalRestoreTransactionErrorFieldPathKey;
```

Export exactly this closed item-kind enum:

```objc
typedef NS_ENUM(NSInteger, PXOptionalRestoreTransactionItemKind) {
    PXOptionalRestoreTransactionItemKindDirectoryContents = 1,
    PXOptionalRestoreTransactionItemKindDirectoryObject = 2,
    PXOptionalRestoreTransactionItemKindFileObject = 3,
};
```

Export exactly these 18 error codes:

```objc
typedef NS_ENUM(NSInteger, PXOptionalRestoreTransactionErrorCode) {
    PXOptionalRestoreTransactionErrorInvalidInput = 1,
    PXOptionalRestoreTransactionErrorDestinationValidationFailed = 2,
    PXOptionalRestoreTransactionErrorFilesystemInspectionFailed = 3,
    PXOptionalRestoreTransactionErrorLockFailed = 4,
    PXOptionalRestoreTransactionErrorCrossDeviceBoundary = 5,
    PXOptionalRestoreTransactionErrorEntryLimitExceeded = 6,
    PXOptionalRestoreTransactionErrorWorkspaceCreationFailed = 7,
    PXOptionalRestoreTransactionErrorReplacementPreparationFailed = 8,
    PXOptionalRestoreTransactionErrorReplacementMismatch = 9,
    PXOptionalRestoreTransactionErrorJournalCreationFailed = 10,
    PXOptionalRestoreTransactionErrorJournalInvalid = 11,
    PXOptionalRestoreTransactionErrorQuarantineFailed = 12,
    PXOptionalRestoreTransactionErrorCommitFailed = 13,
    PXOptionalRestoreTransactionErrorRollbackFailed = 14,
    PXOptionalRestoreTransactionErrorCleanupFailed = 15,
    PXOptionalRestoreTransactionErrorFilesystemChanged = 16,
    PXOptionalRestoreTransactionErrorInconsistentBatch = 17,
    PXOptionalRestoreTransactionErrorRecoveryFailed = 18,
};
```

Create one immutable, subclassing-restricted item class:

```objc
@interface PXOptionalRestoreTransactionItem : NSObject <NSCopying>
@property (nonatomic, assign, readonly) PXOptionalRestoreTransactionItemKind kind;
@property (nonatomic, copy, readonly) NSString *destinationPath;
@property (nonatomic, strong, nullable, readonly) PXValidatedMainDataStage *validatedDirectoryStage;
@property (nonatomic, strong, nullable, readonly) PXValidatedOptionalFileStage *validatedFileStage;

+ (nullable instancetype)directoryContentsItemWithDestinationPath:(NSString *)destinationPath
                                                   validatedStage:(PXValidatedMainDataStage *)validatedStage
                                                            error:(NSError * _Nullable * _Nullable)error;

+ (nullable instancetype)directoryObjectItemWithDestinationPath:(NSString *)destinationPath
                                                 validatedStage:(PXValidatedMainDataStage *)validatedStage
                                                          error:(NSError * _Nullable * _Nullable)error;

+ (nullable instancetype)fileObjectItemWithDestinationPath:(NSString *)destinationPath
                                            validatedStage:(PXValidatedOptionalFileStage *)validatedStage
                                                     error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
```

Create one subclassing-restricted transaction class:

```objc
@interface PXOptionalRestoreTransaction : NSObject
@property (nonatomic, assign, readonly, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readonly) BOOL rollbackPerformed;
@property (nonatomic, assign, readonly) BOOL rollbackComplete;
@property (nonatomic, assign, readonly) NSUInteger recoveredStaleTransactionCount;
@property (nonatomic, assign, readonly) NSUInteger itemCount;

+ (nullable instancetype)transactionForItems:(NSArray<PXOptionalRestoreTransactionItem *> *)items
                                        error:(NSError * _Nullable * _Nullable)error;

- (BOOL)commitWithCleanupWarning:(NSError * _Nullable * _Nullable)cleanupWarning
                           error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
```

Do not add:

- manifest arguments;
- backup-directory arguments;
- caller-selected workspace names;
- arbitrary operation blocks;
- shell command arguments;
- Keychain operation APIs;
- mutable public properties;
- public recovery/rollback controls;
- alternate factories.

# Part 2 — Immutable item contract

`PXOptionalRestoreTransactionItem` must:

- copy `destinationPath`;
- retain the accepted immutable stage object;
- contain exactly one stage type matching its kind;
- return `self` from `copyWithZone:`;
- reject empty, non-string, NUL-bearing or non-absolute destination paths;
- reject root destination `/`;
- reject trailing slash, doubled slash, `.` or `..` path components;
- reject invalid/lossy UTF-8 conversion;
- reject path length above 4096 UTF-8 bytes;
- reject any component above 255 UTF-8 bytes;
- perform no filesystem mutation during item creation.

The item object is semantic input only. Its raw path string does not by itself authorize mutation; transaction preparation must descriptor-bind the parent/final namespace and compare it with the current destination-plan revalidation performed by the manager.

# Part 3 — Item-kind semantics

## DirectoryContents

Used only for:

```text
profile AppData
global Safari
```

Requirements:

- destination must already exist as a real no-follow directory;
- the destination directory identity is retained and preserved;
- only its operational top-level contents are quarantined/installed;
- transaction workspace is created inside the retained destination directory;
- the destination root itself is never renamed or replaced;
- stage top-level entries are moved descriptor-relatively into the destination;
- rollback restores the original top-level namespace.

This preserves the accepted profile/Safari destination root identity and existing root metadata.

## DirectoryObject

Used only for system-global Library items.

Requirements:

- destination parent must exist as a real no-follow directory;
- final destination may be an existing real directory or absent;
- existing non-directory final objects are rejected;
- transaction workspace is a sibling under the retained parent;
- a private `replacement` directory is prepared under that workspace before durable `prepared`;
- accepted staged top-level entries are moved into `replacement`, leaving the original staging `data` directory present and empty;
- existing destination object is quarantined as one directory object;
- `replacement` is atomically renamed to the destination basename;
- rollback restores the original directory object or exact absence.

Do not use timestamped `.WeaponXTrash` names after this task.

## FileObject

Used only for:

```text
shared-system DB files
Preferences
```

Requirements:

- destination parent must exist as a real no-follow directory;
- final destination may be an existing regular file or absent;
- final symlink, directory, FIFO, socket or device is rejected;
- transaction workspace is a sibling under the retained parent;
- a private regular `replacement` file is created under the workspace;
- bytes are copied from the retained validated file-stage descriptor into `replacement`;
- replacement byte count and lowercase SHA-256 must exact-match the accepted `PXValidatedOptionalFileStage`;
- source and replacement descriptors are fstat-stable before/after copy and verification;
- existing destination file is quarantined as one file object;
- replacement is atomically renamed to the destination basename;
- rollback restores the original file object or exact absence.

The original optional staging payload must remain present so `PXOptionalFileStagingWorkspace` can perform its accepted identity-bound cleanup after transaction completion.

# Part 4 — Transaction domains and honest atomicity

Manager must invoke separate transaction instances in current component order:

```text
profile AppData transaction
Global Safari transaction
App Group batch transaction
system-global batch transaction
shared-system DB batch transaction
Preferences transaction
Keychain execution outside filesystem transaction
```

Atomicity guarantees:

- profile: one-item rollback domain;
- global Safari: one-item rollback domain;
- system-global: all planned non-skipped system-global items commit or roll back as one batch;
- shared-system DB: all planned files commit or roll back as one batch;
- Preferences: one-item rollback domain.

TASK-2.13 does not roll back an earlier domain after a later domain fails. It must not claim whole-Restore atomicity.

# Part 5 — Fixed limits

Use fixed private limits:

```text
maximum items per transaction:               4096
maximum directory top-level entries/item:  200000
maximum aggregate entries/transaction:      500000
maximum staged file bytes:                   64 GiB
maximum path bytes:                            4096
maximum component bytes:                        255
maximum cleanup entries/workspace:           500000
maximum cleanup depth:                         2048
maximum leader journal bytes:               128 MiB
maximum stale transaction IDs:                    1
maximum workspace entries:                        8
stream buffer:                               64 KiB
```

All additions, multiplications, allocations and casts must be overflow-safe.

Boundary behavior must be documented and tested:

```text
4096 items accepted; 4097 rejected
200000 entries accepted; 200001 rejected
500000 aggregate accepted; 500001 rejected
64 GiB file accepted; one byte above rejected before copy
```

# Part 6 — Deterministic ordering and lock collapse

Commit order preserves item array order supplied by the manager.

Lock order uses exact destination UTF-8 byte order.

Authority directories:

- DirectoryContents: destination directory itself;
- DirectoryObject/FileObject: destination parent directory.

Several object items may share one physical parent. The transaction must collapse authority locks by exact parent device/inode and acquire one independent lock descriptor per unique physical authority directory.

Do not attempt to acquire multiple independent `flock` locks on the same parent inode from the same transaction.

For each item before stale recovery:

1. descriptor-bind authority directory;
2. fstat and retain authority identity;
3. bind the exact destination final state;
4. bind independent lock authority;
5. prove lock and authority device/inode equality;
6. acquire all unique authority locks in deterministic path order;
7. repeat destination-plan path/final identity proof;
8. bind the accepted stage descriptor;
9. require stage object and authority directory are same-filesystem;
10. repeat all authority/final/stage identities.

All items and all unique locks must pass before the first stale-recovery mutation.

Any pre-recovery failure must have:

```text
zero workspace creation
zero journal creation
zero destination rename
zero target-content move
zero daemon termination caused by this transaction
all descriptors closed
all locks released
```

# Part 7 — Destination-plan authority in manager

Immediately before constructing each transaction item, manager must call the matching accepted revalidation method:

```text
revalidatedProfileAppDataPathWithError:
revalidatedGlobalSafariPathWithError:
revalidatedSystemGlobalPathForSubdirectory:error:
revalidatedSharedDatabasePathForRelativePath:error:
revalidatedPreferencesPathWithError:
```

The item destination path must be exactly that returned string.

After item creation, manager may not recompute destination paths with:

```text
_profileAppDataPathForBundleID:
_globalSafariLibraryPath
_mobileLibraryBasePath
_preferencesPlistPathForBundleID:
firstExistingPath
manifest paths
recorded UUIDs
```

Transaction source paths must come only from accepted validated stage objects.

# Part 8 — Strict synchronization

Every file/directory synchronization helper must:

- retry only when `errno == EINTR`;
- return success only when the synchronization primitive actually returns success;
- treat `EINVAL`, `ENOTSUP`, `EOPNOTSUPP`, `ENOSYS` and all other errors as failure.

Forbidden:

```text
sync()
shell sync
helper process
unsupported-error-as-success
```

The leader journal file must be completely written and synchronized before atomic publication. Every journal rename must be followed by strict leader-workspace synchronization.

All authority directories, destination directories, replacement/original/new namespaces and stages must be synchronized at required transitions.

# Part 9 — Reserved namespace and workspace layout

Use fixed prefix:

```text
.weaponx-optional-restore-
```

One lowercase batch UUID is shared by every item in one transaction domain. Workspace names encode:

```text
prefix + batch UUID + deterministic item ordinal
```

Names must be strict, bounded and exactly parseable.

Every workspace is mode `0700`, no-follow, same-device with its authority directory and contains only the kind-appropriate fixed entries.

DirectoryContents workspace may contain:

```text
original/
new/
```

DirectoryObject workspace may contain:

```text
original/
replacement/
new/
```

FileObject workspace may contain:

```text
original
replacement
new
```

The deterministic leader workspace may additionally contain:

```text
transaction.plist
transaction.tmp
```

No other entry is allowed.

Any staged directory root entry using the reserved transaction prefix is rejected.

# Part 10 — Leader journal

Leader is the first item in deterministic destination UTF-8 order, not caller-selected.

Before the first destination mutation, publish one bounded binary property-list journal containing:

```text
version
transaction identifier
phase
item count
items[]
```

Each item record must contain:

```text
lock-order ordinal
manager item order
item kind
workspace name raw bytes
authority device/inode
destination basename raw bytes
destination initially existed Boolean
original object identity or original entry identities
replacement/staged object identity or staged entry identities
```

Identity means raw name bytes plus device, inode and file type. File replacement records also include exact byte count and SHA-256.

Journal data must not contain absolute destination or stage paths.

Exact phases:

```text
prepared
quarantined
installed
committed
rolling-back
rolled-back
```

Publication sequence:

1. inspect/remove only a safe stale `transaction.tmp`;
2. open new tmp using `O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`, mode `0600`;
3. verify regular single-link same-device file;
4. complete bounded write;
5. strict file synchronization;
6. close successfully;
7. atomic `renameat` to `transaction.plist`;
8. strict leader-workspace synchronization.

No success before durable `committed`.

# Part 11 — Stale recovery

Stale recovery runs only after every current item, authority, lock, destination state and accepted stage passed complete proof.

Across the complete current item set:

```text
zero stale transaction IDs -> continue
one stale transaction ID -> recover/clean
more than one -> fail closed
duplicate ordinal -> fail closed
malformed reserved name -> fail closed
symlink/wrong-type/cross-device workspace -> fail closed
```

The journal item set must exact-match the current transaction item set:

- same count;
- same deterministic ordinal;
- same manager order;
- same kind;
- same authority device/inode;
- same destination basename;
- same initial-existence contract;
- same workspace names;
- no duplicate item/authority identity.

Do not recover a guessed subset.

No-journal cleanup is allowed only for a proven pre-mutation workspace:

- original/new contain no recovery data;
- replacement may contain only transaction-owned data prepared from the current accepted stage;
- replacement identity/size/digest/tree snapshot must exact-match the current item;
- optional leader tmp is bounded, regular and single-link;
- no unexpected entry exists;
- destination still exact-matches its initial state.

If original/new recovery data exists without a valid journal, fail and preserve all evidence.

Stale phase policy:

- `committed`: never roll back; require exact installed namespace/object and finish cleanup leader-last;
- `rolled-back`: require exact original namespace/object or exact initial absence and finish cleanup;
- `prepared`, `quarantined`, `installed`, `rolling-back`: require every participant workspace and perform idempotent whole-domain rollback;
- missing/corrupt leader journal with recovery data: fail and preserve evidence.

# Part 12 — Replacement preparation

Replacement preparation occurs after complete factory proof and one additional commit-time revalidation, but before durable `prepared` publication.

## DirectoryContents

No separate replacement root is needed. Revalidate the stage top-level identity snapshot immediately before `prepared`. Original and staged top-level entry lists are journaled.

## DirectoryObject

Create private `replacement/` under the retained transaction workspace.

Move every validated stage top-level entry into replacement using descriptor-relative `renameat` after exact source identity checks. The accepted stage root directory remains present and becomes empty.

Require:

- replacement tree top-level identities exact-match the accepted staged tree snapshot;
- deterministic tree digest/count/regular bytes equal `PXValidatedMainDataStage`;
- replacement directory is same-device with authority parent;
- no reserved metadata/transaction entry.

## FileObject

Create private `replacement` regular file with `O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`, mode `0600`.

Copy from the retained validated file-stage descriptor using a fixed 64 KiB buffer.

Require:

- complete read/write with EINTR retry;
- exact accepted byte count;
- exact accepted lowercase SHA-256;
- source fstat stability before/after;
- replacement fstat stability before/after independent digest reread;
- regular single-link same-device replacement;
- no whole-file `NSData` load.

The accepted source staging payload remains in place.

Prepare every item replacement before publishing `prepared`.

# Part 13 — New transaction commit

Before first mutation:

1. collect/snapshot all original and replacement/staged identities;
2. create all workspaces;
3. prepare all replacement objects;
4. synchronize all workspaces, stages and authority directories;
5. publish durable `prepared`.

No original object/entry may move before durable `prepared`.

## Quarantine

Process items in manager order.

DirectoryContents:

- move each original operational top-level entry destination -> workspace/original;
- preserve the transaction workspace itself;
- require destination operational namespace empty;
- require original exact-match journal.

DirectoryObject/FileObject:

- if destination initially existed, identity-check then rename destination basename -> workspace/original;
- if initially absent, require it is still absent;
- require parent destination basename absent after quarantine;
- require original state exact-match journal.

After all items, synchronize all affected directories and publish durable `quarantined`.

## Install

DirectoryContents:

- move every staged top-level entry stage -> destination;
- require destination exact-match staged journal;
- require stage top-level namespace empty.

DirectoryObject/FileObject:

- rename prepared replacement object workspace -> destination basename;
- require destination exact-match replacement identity;
- require replacement namespace absent from workspace.

After all items, synchronize all affected directories and publish durable `installed`.

## Durable commit

Immediately before commit decision:

- repeat every destination-plan-derived authority proof;
- require every unique lock retained;
- require every destination exact-match installed state;
- require every DirectoryContents stage empty;
- require every object replacement moved out of workspace;
- require no unexpected namespace entry.

Publish durable `committed`, then and only then set `committed = YES`.

# Part 14 — Whole-domain rollback

Any failure after durable `prepared` and before durable `committed` must attempt rollback for every item in reverse manager order.

Publish `rolling-back` when possible.

DirectoryContents rollback:

- move installed staged entries destination -> workspace/new using identity, not name alone;
- restore originals workspace/original -> destination;
- prove exact original top-level namespace.

DirectoryObject/FileObject rollback:

- if installed replacement is at destination, move it to workspace/new;
- if replacement is still in workspace, retain it there;
- restore quarantined original object to destination when initially present;
- require destination absent when initially absent;
- prove exact initial destination state.

After full rollback:

- strict-sync all destination/authority/original/new directories;
- publish durable `rolled-back`;
- set `rollbackPerformed = YES` and `rollbackComplete = YES`;
- cleanup all workspaces.

Same-name original/replacement objects must be distinguished by device/inode/type.

Rollback failure must:

```text
return RollbackFailed
rollbackComplete = NO
preserve leader journal
preserve every participant workspace
preserve recovery evidence
never report success
```

# Part 15 — Cleanup

Cleanup must be:

- descriptor-relative;
- no-follow;
- bounded;
- same-filesystem;
- idempotent;
- participant-first;
- leader-journal-last;
- leader-workspace-last.

After durable committed/rolled-back state:

1. remove transaction-owned original/new/replacement contents;
2. remove nonleader workspaces;
3. retain leader journal while any participant cleanup remains incomplete;
4. remove leader tmp;
5. remove leader journal;
6. sync leader workspace;
7. remove leader workspace;
8. sync leader authority directory.

Nested mount/device changes fail cleanup.

Post-commit cleanup failure is a warning and must not roll back durable committed data.

# Part 16 — Manager integration: profile AppData

Preserve current order before global Safari and App Groups.

Flow:

1. stage and validate profile archive using accepted `PXMainDataStagingWorkspace`;
2. revalidate destination through `PXOptionalRestoreDestinationPlan`;
3. create one `DirectoryContents` transaction item;
4. create one transaction;
5. commit transaction;
6. cleanup profile staging workspace;
7. perform existing best-effort recursive mobile ownership correction only after committed state.

Remove from profile Restore flow:

```text
_wipeDirectoryContents:profileDestination
_cloneOptionalDirectoryStageAtPath:... destination:profileDestination
profile tar/cp clone authority
```

Failure mapping remains:

```text
domain: PXBackupErrorDomain
code: 307
description: Failed to restore validated profile AppData stage transactionally
```

# Part 17 — Manager integration: global Safari

Use the same one-item `DirectoryContents` transaction flow.

Remove direct wipe/clone authority.

Failure mapping:

```text
domain: PXBackupErrorDomain
code: 311
description: Failed to restore validated global Safari stage transactionally
```

# Part 18 — Manager integration: system-global batch

Preserve the accepted Safari duplicate skip before batch construction.

Before any system-global destination mutation:

1. stage and validate every non-skipped system-global archive;
2. revalidate every destination;
3. create one `DirectoryObject` item per plan item in Restore-plan order;
4. require item/workspace/stage counts match;
5. create one multi-item transaction;
6. commit once;
7. cleanup all accepted staging workspaces.

Remove:

```text
timestamped WeaponXTrash names
shell mv destination -> trash
shell mkdir destination
per-item direct clone
per-item partial commit
```

A later item failure must roll back all earlier system-global items in that batch.

Failure mapping:

```text
domain: PXBackupErrorDomain
code: 318
description: Failed to restore validated system-global stages transactionally
```

# Part 19 — Manager integration: shared-system DB batch

Before daemon termination:

1. stage every shared DB source;
2. revalidate every destination;
3. create one `FileObject` transaction item per shared DB plan item;
4. construct the transaction successfully.

Only after the transaction object exists may manager stop the related daemons.

Then commit the transaction once.

Remove:

```text
timestamped trash names
shell mv
shell cp
per-file partial commit
```

All shared DB files commit or roll back as one batch.

After durable commit and successful transaction cleanup, preserve existing best-effort final ownership/mode policy:

```text
chown mobile:mobile
chmod 600
```

Failure mapping remains manager code `320` with description:

```text
Failed to restore staged optional files transactionally
```

Daemon restart/refresh behavior remains unchanged.

# Part 20 — Manager integration: Preferences

Flow:

1. stage Preferences source using accepted file workspace;
2. revalidate exact destination;
3. create one `FileObject` item;
4. create and commit one transaction;
5. cleanup file staging workspace;
6. preserve best-effort `chown mobile:mobile`, `chmod 644` and `cfprefsd` refresh after committed state.

Remove direct shell `cp -f` destination authority.

Failure mapping uses code `320` and description:

```text
Failed to restore staged optional file transactionally
```

# Part 21 — Keychain boundary

Do not include Keychain in `PXOptionalRestoreTransaction`.

Preserve exactly:

- staging through `PXOptionalFileStagingWorkspace`;
- helper/bridge input from `validatedStage.filePath`;
- groups and method from `PXRestorePlan`;
- in-app decision;
- overwrite behavior;
- warning-only Keychain execution failure;
- staging cleanup behavior.

Do not modify:

```text
KeychainRestoreHelper
KeychainRestoreBridge
helper scripts/protocol
Security item semantics
```

TASK-2.13 must state explicitly that Keychain execution is not rollback-capable in Phase 2.

# Part 22 — Cleanup warnings and ownership

Use exact transaction cleanup warning:

```text
Optional transaction cleanup failed
```

Use accepted staging warnings:

```text
Optional-directory staging cleanup failed
Optional-file staging cleanup failed
```

Transaction cleanup failure must not replace the primary transaction error.

Staging cleanup runs on:

- item creation failure;
- transaction factory failure;
- transaction commit failure;
- rollback completion;
- successful commit;
- helper completion for Keychain.

Do not place path, bundle ID, profile ID, subdirectory, relative DB path, digest, inode, journal name or nested error into new public manager errors/warnings.

# Part 23 — Pure transaction boundary

`PXOptionalRestoreTransaction.m` may import only:

```objc
#import "PXOptionalRestoreTransaction.h"
#import "PXMainDataStaging.h"
#import "PXOptionalRestoreStaging.h"
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
```

plus required POSIX/CommonCrypto headers.

Forbidden inside the transaction implementation:

```text
UIKit
AppDataBackupManager
CommandRunner
NSTask
posix_spawn
system
popen
shell/tar/cp/mv/rm
archive extraction
NSUserDefaults
dispatch
Security/Keychain
manifest parsing
container resolver
raw-value logging
global mutable state
```

Filesystem operations must be descriptor-relative after initial exact path binding.

# Part 24 — Non-regression

Do not alter:

- public Restore signature;
- manifest/schema/version/bundle gates;
- artifact/archive validation;
- immutable Restore plan;
- main transaction and code 317;
- App Group transaction and codes 310/319;
- tar executable selection;
- stage validators;
- exact optional destination plan;
- high-level component order;
- Keychain warning-only behavior;
- Backup behavior;
- UI behavior.

TASK-2.14 structured result remains locked.

# Part 25 — Static gates

Required production scope:

```text
PXOptionalRestoreTransaction.h added
PXOptionalRestoreTransaction.m added
AppDataBackupManager.m modified
TASK-2.13-REPORT.md added
all other production diff = 0
```

Public API:

```text
error-domain exports = 1
field-path exports = 1
item-kind values = 3
error codes = 18
item classes = 1
transaction classes = 1
item factories = 3
transaction factories = 1
commit methods = 1
public readwrite properties = 0
copyWithZone implementations = 1
subclassing-restricted classes = 2
```

Restore static outcomes:

```text
profile direct wipe = 0
profile direct clone = 0
global Safari direct wipe = 0
global Safari direct clone = 0
system-global WeaponXTrash creation = 0
system-global shell mv = 0
system-global shell mkdir = 0
system-global direct clone = 0
shared DB shell mv = 0
shared DB shell cp = 0
Preferences shell cp = 0
profile transaction factory/commit = 1/1 when included
Safari transaction factory/commit = 1/1 when included
system-global batch factory/commit = 1/1 when nonempty
shared DB batch factory/commit = 1/1 when nonempty
Preferences transaction factory/commit = 1/1 when included
Keychain transaction items = 0
exact cleanup warning = present
```

Durability:

```text
EINVAL-as-success = 0
ENOTSUP-as-success = 0
EOPNOTSUPP-as-success = 0
ENOSYS-as-success = 0
journal file sync present
leader directory sync present
```

# Part 26 — Scenario matrix

Report must contain at least **240 explicit scenarios**, including:

1. invalid item arrays;
2. empty transaction;
3. 4096-item boundary;
4. 4097-item rejection;
5. invalid destination path forms;
6. wrong stage class for each kind;
7. duplicate exact destination;
8. duplicate physical destination through aliases;
9. DirectoryContents missing destination;
10. DirectoryContents final symlink;
11. DirectoryContents wrong type;
12. DirectoryObject existing directory;
13. DirectoryObject absent destination;
14. DirectoryObject existing file conflict;
15. FileObject existing regular file;
16. FileObject absent destination;
17. FileObject final symlink;
18. file/directory collision;
19. ancestor/descendant collision;
20. shared parent lock collapse;
21. deterministic lock ordering;
22. lock contention;
23. target/lock identity race;
24. stage path race;
25. cross-device directory stage;
26. cross-device file stage;
27. complete item-set proof before recovery;
28. zero mutation on pre-recovery failure;
29. one stale transaction;
30. multiple stale IDs;
31. malformed reserved name;
32. stale item-set mismatch;
33. journal wrong kind;
34. journal wrong order;
35. journal wrong authority identity;
36. no-journal empty workspace cleanup;
37. no-journal replacement mismatch;
38. no-journal recovery-data rejection;
39. corrupt/oversized journal;
40. invalid integral field;
41. replacement directory preparation;
42. stage entries moved to replacement;
43. file replacement streaming copy;
44. file digest mismatch;
45. file size mismatch;
46. source change during copy;
47. replacement change during verification;
48. strict prepared durability;
49. quarantine interruption for each kind;
50. install interruption for each kind;
51. same-name original/new identity;
52. initially absent rollback;
53. multi-item reverse rollback;
54. rollback failure evidence preservation;
55. committed stale cleanup;
56. rolled-back stale cleanup;
57. nonleader cleanup interruption;
58. leader-last cleanup;
59. unsupported directory sync;
60. EINTR sync retry;
61. profile transactional success/failure;
62. Safari transactional success/failure;
63. all system items staged before transaction;
64. later system item failure rolls back earlier item;
65. all shared files staged before daemon kill;
66. shared transaction prepare failure before daemon kill;
67. later shared file failure rolls back earlier file;
68. Preferences transactional success/failure;
69. exact code mappings 307/311/318/320;
70. Keychain excluded from transaction;
71. Keychain staged input retained;
72. protected main/App Group transaction hashes;
73. no shell copy/move/wipe authority;
74. cleanup warnings;
75. CRLF/trailing whitespace/NUL audit.

Add race, interruption, resource-limit, descriptor-cleanup, error-privacy and compilation scenarios until total is at least 240.

# Part 27 — Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.13-REPORT.md
```

Report must include:

- baseline and exact scope;
- protected SHA-256 before/after;
- exact API, three kinds and 18-code enum;
- honest transaction-domain matrix;
- Keychain exclusion rationale;
- destination-plan authority proof;
- deterministic lock collapse/order;
- complete item-set proof before recovery;
- same-filesystem proof;
- replacement preparation for all kinds;
- file digest/size/stability proof;
- leader journal schema and phases;
- stale binding/no-journal policy;
- quarantine/install/rollback matrices;
- initially absent target rollback;
- cleanup leader-last proof;
- strict sync behavior;
- manager integration for profile/Safari/system/shared/Preferences;
- zero legacy wipe/mv/mkdir/cp authority;
- exact manager error mapping;
- TASK-2.11A/TASK-2.12 non-regression;
- full authorized source diff;
- static/forbidden-token counts;
- at least 240 explicit scenarios;
- whitespace/CRLF/NUL/generated-file audit;
- build status and target-device risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 28 — Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 9e83a053c4d4e2e42e0eac0a207467a5df2b3251..HEAD --check
git diff --name-status 9e83a053c4d4e2e42e0eac0a207467a5df2b3251..HEAD
git status --short --untracked-files=all
```

Implementation commit must contain only:

```text
PXOptionalRestoreTransaction.h
PXOptionalRestoreTransaction.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.13-REPORT.md
```

Suggested commit subject:

```text
phase2(task-2.13): add transactional optional component handling
```

Stop after TASK-2.13.

Do not implement TASK-2.14 or any Phase 3 task.
