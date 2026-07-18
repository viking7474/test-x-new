# TASK-2.10 — Stage and Validate Optional Restore Components

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `48cb463b9f1bb6b1244237c227fa890f3020071d`
- Previous task: TASK-2.9 source review ACCEPTED
- Next task: TASK-2.11 remains LOCKED

## Objective

Remove direct optional-component Restore from verified backup artifacts into current-device destinations.

TASK-2.10 must provide:

1. one immutable current-device destination plan for all optional components;
2. exact destination validation and immediate revalidation before each optional mutation;
3. secure staging and complete staged-tree validation for every optional tar archive;
4. secure streaming file staging for Preferences, Keychain and shared-system database artifacts;
5. clone/copy authority only from validated staged sources;
6. fail-closed source extraction/copy behavior;
7. cleanup of every owned workspace on every success/failure path.

Optional components in this task are:

```text
profile AppData
global Safari Library
system-global Library items
shared-system database files
Preferences
Keychain input file
```

This task does not add transaction journals, target quarantine design, atomic rename/swap or rollback. TASK-2.11 through TASK-2.13 retain transaction ownership.

## Baseline evidence

Before editing, record:

```powershell
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Required baseline:

```text
48cb463b9f1bb6b1244237c227fa890f3020071d
```

TASK-2.9 implementation and report are already committed. Coordinator-owned uncommitted documentation must not be staged, reverted or rewritten.

## Exact implementation scope

Allowed production files:

```text
PXOptionalRestoreStaging.h
PXOptionalRestoreStaging.m
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.10-REPORT.md
```

The implementation commit may contain only those four paths.

Suggested commit subject:

```text
phase2(task-2.10): stage and validate optional components
```

## Protected files

Do not modify:

```text
AppDataBackupManager.h
PXMainDataStaging.h
PXMainDataStaging.m
PXAppGroupRestoreTargetPlan.h
PXAppGroupRestoreTargetPlan.m
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
AppEntitlementsReader.h
AppEntitlementsReader.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
AppDataCleaner.h
AppDataCleaner.m
CommandRunner.h
CommandRunner.m
Makefile
UI/controller files
Keychain helper/bridge files
common/PXPaths.h
common/PXPaths.m
```

Do not modify coordinator specifications, reviews, `STATUS.md`, `ROADMAP.md`, `DECISIONS.md` or `README.md`.

Record SHA-256 before and after for every protected production file.

# Part 1 — Exact public API

Create `PXOptionalRestoreStaging.h` with this exact public surface:

```objc
#import <Foundation/Foundation.h>

@class PXRestorePlan;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorDomain;
FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXOptionalRestoreStagingErrorCode) {
    PXOptionalRestoreStagingErrorInvalidInput = 1,
    PXOptionalRestoreStagingErrorInvalidDestinationIdentity = 2,
    PXOptionalRestoreStagingErrorMissingDestination = 3,
    PXOptionalRestoreStagingErrorAmbiguousDestination = 4,
    PXOptionalRestoreStagingErrorUnsafeDestination = 5,
    PXOptionalRestoreStagingErrorWorkspaceCreationFailed = 6,
    PXOptionalRestoreStagingErrorSourceOpenFailed = 7,
    PXOptionalRestoreStagingErrorSourceChanged = 8,
    PXOptionalRestoreStagingErrorSourceUnsupported = 9,
    PXOptionalRestoreStagingErrorCopyFailed = 10,
    PXOptionalRestoreStagingErrorStagedFileInvalid = 11,
    PXOptionalRestoreStagingErrorSizeMismatch = 12,
    PXOptionalRestoreStagingErrorDigestMismatch = 13,
    PXOptionalRestoreStagingErrorLimitExceeded = 14,
    PXOptionalRestoreStagingErrorCleanupFailed = 15,
    PXOptionalRestoreStagingErrorInconsistentPlan = 16,
};

__attribute__((objc_subclassing_restricted))
@interface PXValidatedOptionalFileStage : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *workspaceRootPath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) unsigned long long byteCount;
@property (nonatomic, copy, readonly) NSString *sha256;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXOptionalFileStagingWorkspace : NSObject
@property (nonatomic, copy, readonly) NSString *rootPath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, strong, readonly) PXValidatedOptionalFileStage *validatedStage;
+ (nullable instancetype)workspaceByStagingSourceFileAtPath:(NSString *)sourcePath
                                                     error:(NSError * _Nullable * _Nullable)error;
- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXOptionalRestoreDestinationPlan : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *mobileLibraryPath;
@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataPath;
@property (nonatomic, copy, nullable, readonly) NSString *globalSafariPath;
@property (nonatomic, copy, nullable, readonly) NSString *preferencesPath;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *systemGlobalPathsBySubdirectory;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *sharedDatabasePathsByRelativePath;

+ (nullable instancetype)destinationPlanForRestorePlan:(PXRestorePlan *)restorePlan
                                      bundleIdentifier:(NSString *)bundleIdentifier
                               activeProfileIdentifier:(nullable NSString *)profileIdentifier
                                                 error:(NSError * _Nullable * _Nullable)error;

- (nullable NSString *)systemGlobalPathForSubdirectory:(NSString *)subdirectory;
- (nullable NSString *)sharedDatabasePathForRelativePath:(NSString *)relativePath;

- (nullable NSString *)revalidatedProfileAppDataPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedGlobalSafariPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedPreferencesPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedSystemGlobalPathForSubdirectory:(NSString *)subdirectory
                                                             error:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedSharedDatabasePathForRelativePath:(NSString *)relativePath
                                                               error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
```

Do not add:

- mutable public setters;
- public designated initializers;
- manifest arguments;
- backup-directory arguments;
- caller-selected destination roots;
- arbitrary raw destination-plan inputs;
- tar/extraction methods;
- command-runner arguments;
- transaction/rollback APIs;
- warning/bypass flags.

# Part 2 — Public immutability and lifecycle

`PXValidatedOptionalFileStage` and `PXOptionalRestoreDestinationPlan` must:

- be subclassing-restricted;
- expose readonly properties only;
- copy all strings, arrays and dictionaries;
- return `self` from `copyWithZone:`;
- prohibit ordinary `init` and `new`;
- contain no mutable collection after construction.

The validated file stage must not contain descriptors, callbacks, cleanup blocks or mutable buffers.

`PXOptionalFileStagingWorkspace` owns its descriptors and exact unique workspace. It is not `NSCopying`.

Required workspace lifecycle:

```text
secure source open
unique workspace creation
stream source into owned payload
source stability recheck
staged payload stability/digest recheck
immutable validated result
manager consumes staged file
explicit cleanup
```

`cleanupWithError:` must be idempotent. Validation/staging construction failure must close all descriptors and remove only the exact owned workspace.

# Part 3 — Error contract

Clear `*error` at every public entry.

Success:

```text
non-nil object/path
error == nil
```

Failure:

```text
nil object/path or BOOL == NO
error domain == PXOptionalRestoreStagingErrorDomain
error code == one of the exact 16 public codes
```

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXOptionalRestoreStagingErrorFieldPathKey
```

Do not expose:

- bundle ID value;
- profile ID value;
- destination/source/staging path;
- relative path or subdirectory value;
- artifact/archive name;
- expected/actual size;
- digest;
- device/inode;
- errno text;
- nested filesystem error;
- manifest excerpt.

Stable field paths include:

```text
$
$.mobileLibrary
$.profileAppData.destination
$.globalSafari.destination
$.preferences.destination
$.systemGlobalItems[3].destination
$.sharedDatabaseItems[5].destination
$.source
$.workspace
$.payload
```

# Part 4 — Implementation boundary

`PXOptionalRestoreStaging.m` may import only:

```objc
#import "PXOptionalRestoreStaging.h"
#import "PXRestorePlan.h"
#import <CommonCrypto/CommonDigest.h>
```

and required POSIX/C headers.

Allowed:

```text
Foundation immutable collections/string handling
lstat/stat/fstat/fstatat
realpath
open/openat
mkdirat
fchmod/fcntl
read/write/fsync/lseek
fdopendir/readdir/closedir
unlinkat
mkdtemp
CommonCrypto streaming SHA-256
```

Forbidden:

```text
UIKit
AppDataBackupManager
PXMainDataStaging
PXAppGroupRestoreTargetPlan
PXBackupArtifactVerifier
PXBackupArchiveValidator
AppDataCleaner
CommandRunner
NSTask
posix_spawn/system/popen
external tar
shell construction
Security/Keychain
NSUserDefaults
notifications/dispatch
filesystem writes outside the owned optional-file workspace
logging raw values
global mutable state
transaction/rollback
```

The destination planner may inspect current-device filesystem state but may not mutate destination paths.

# Part 5 — Fixed current-device mobile Library authority

The destination planner must derive mobile Library authority only from these fixed candidates, in this order:

```text
/private/var/mobile/Library
/var/mobile/Library
/private/var/jb/var/mobile/Library
/var/jb/var/mobile/Library
```

For every existing candidate:

- `lstat` final component;
- require a real directory, not a final symlink;
- `realpath` the candidate;
- open the canonical directory with no-follow/CLOEXEC flags;
- require path and descriptor device/inode identity;
- retain only the exact canonical path and immutable identity snapshot.

Collapse candidates that resolve to the same exact canonical directory.

Outcomes:

```text
zero unique physical roots -> MissingDestination
one unique physical root -> accepted
two or more distinct physical roots -> AmbiguousDestination
```

Do not use first-existing behavior, `PXMobileLibraryPath`, `_mobileLibraryBasePath`, environment variables, manifest paths or caller-selected roots as authority.

The selected canonical mobile Library path is the only root for global Safari, system-global, shared DB and Preferences destinations.

# Part 6 — Exact component identity inputs

Require exact `restorePlan.bundleIdentifier` equality with the supplied bundle identifier.

The bundle identifier must be safe as one filesystem filename component for Preferences planning:

- runtime NSString;
- nonempty and non-whitespace;
- no NUL/control;
- no slash or backslash;
- not `.` or `..`;
- UTF-8 byte length no more than 255;
- no trim, normalization or case folding.

If profile AppData is included, the active profile identifier must satisfy the same safe-component policy.

If global Safari is included, the bundle identifier must be exact:

```text
com.apple.mobilesafari
```

Otherwise fail `InconsistentPlan`.

Use only accepted semantic fields already retained by `PXRestorePlan`. Do not reread the manifest.

# Part 7 — Profile AppData destination

When excluded:

```text
profileAppDataPath == nil
```

When included, derive exactly:

```text
<canonical mobile Library>/WeaponX/Profiles/<activeProfileIdentifier>/appdata/<bundleIdentifier>
```

Require:

- every existing parent and final component is no-follow;
- final path exists as a real directory;
- exact canonical path remains below the selected mobile Library root;
- no path component is substituted by symlink;
- final directory is on the same device as the selected mobile Library root;
- path and descriptor identity are stable during planning.

Missing profile ID or destination -> `MissingDestination`.

Store an immutable identity snapshot for immediate revalidation.

Do not call `_profileAppDataPathForBundleID:` from Restore for mutation authority after this task.

# Part 8 — Global Safari destination

When excluded:

```text
globalSafariPath == nil
```

When included, derive exactly:

```text
<canonical mobile Library>/Safari
```

Require an existing real directory, no final/intermediate symlink, same device and canonical containment under the selected root.

Store immutable identity state for revalidation.

Do not call `_globalSafariLibraryPath` from Restore for mutation authority after this task.

# Part 9 — System-global directory destinations

For every `restorePlan.systemGlobalItems` entry, derive:

```text
<canonical mobile Library>/<librarySubdirectory>
```

The semantic subdirectory was already lexically validated by TASK-2.7. Validate defensively again without normalization.

Destination may be:

- an existing real directory; or
- absent with the canonical mobile Library root as its exact parent.

Reject existing non-directory, final symlink or device crossing.

Store whether the destination was present or absent and the exact parent/final identity snapshot.

For exact Safari bundle/global Safari overlap:

```text
bundle == com.apple.mobilesafari
subdirectory == Safari
```

preserve existing semantic behavior by excluding that system-global item from mutation planning. Do not create a duplicate destination entry.

Duplicate exact system-global subdirectories or canonical destinations fail `InconsistentPlan`.

# Part 10 — Shared-system DB destinations

For every `restorePlan.sharedDatabaseItems` entry, derive:

```text
<canonical mobile Library>/<libraryRelativePath>
```

Defensively revalidate the safe relative path without normalization.

Require:

- every parent directory already exists;
- every parent is a real no-follow directory;
- every parent remains on the selected mobile Library device;
- final object is either absent or a real regular file;
- final symlink, directory, device, FIFO or socket is rejected;
- exact canonical containment under mobile Library.

Do not create missing parent chains in TASK-2.10. Missing parent -> `MissingDestination`.

Store immutable parent/final identity state for revalidation.

Duplicate exact relative paths or canonical final destinations fail `InconsistentPlan`.

# Part 11 — Preferences destination

When excluded:

```text
preferencesPath == nil
```

When included, derive exactly:

```text
<canonical mobile Library>/Preferences/<bundleIdentifier>.plist
```

Require:

- `Preferences` exists as a real no-follow directory;
- same device and canonical containment;
- final plist is either absent or a real regular file;
- final symlink/special/directory object is rejected.

Store parent/final state for revalidation.

Do not call `_preferencesPlistPathForBundleID:` from Restore for mutation authority after this task.

# Part 12 — Cross-component destination collision policy

Build one exact canonical destination inventory for:

```text
profile AppData
global Safari
system-global items
shared DB items
Preferences
```

Reject:

- duplicate exact destinations;
- file/directory type conflict;
- one mutable destination being an ancestor or descendant of another mutable destination;
- shared DB or Preferences destination inside a directory destination that will be wiped/replaced;
- profile destination overlap with a system-global target;
- any path outside the selected root.

The intentional Safari duplicate described in Part 9 is removed before collision checking.

Collision -> `InconsistentPlan` with a generic field path.

Keychain has no filesystem destination in this task and is not part of collision inventory.

# Part 13 — Fixed optional planning/staging limits

Use private fixed limits:

```text
maximum optional tar-directory items: 1024
maximum optional file items: 4096
maximum total optional items: 4096
maximum staged regular file size: 64 GiB
maximum path bytes: 4096
maximum component bytes: 255
optional-file cleanup entries: 8
streaming buffer: 64 KiB
```

Tar-directory items are:

```text
profile AppData when included
global Safari when included
non-skipped system-global items
```

File items are:

```text
shared DB items
Preferences when included
Keychain when included
```

All count/size/path arithmetic must be overflow-safe.

Boundary:

```text
4096 total accepted
4097 total -> LimitExceeded
64 GiB file accepted
64 GiB + 1 -> LimitExceeded
```

# Part 14 — Destination revalidation methods

Every revalidation method must:

- clear `*error`;
- require the requested semantic key exists in the immutable plan;
- repeat no-follow type/containment/device checks;
- require retained parent/final identity to match the planning snapshot;
- require an absent final object to remain absent;
- require an existing final object to retain exact device/inode/type;
- return the exact stored destination path only;
- never replace stored state with a newly discovered path.

Failure uses `InvalidDestinationIdentity`, `MissingDestination`, `UnsafeDestination` or `InconsistentPlan` as appropriate.

Manager must call the matching revalidation method immediately before each optional destination mutation.

# Part 15 — Secure optional-file staging workspace

`PXOptionalFileStagingWorkspace` must use fixed parent:

```text
/private/var/tmp
```

and `mkdtemp` template equivalent to:

```text
/private/var/tmp/weaponx_restore_optional_file.XXXXXX
```

Creation/staging requirements:

1. Validate/open fixed parent with no-follow/CLOEXEC identity proof.
2. Create unique root through `mkdtemp`.
3. Require/fix root mode `0700`.
4. Create one payload file named exactly `payload` using parent-relative `openat` with `O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC` and mode `0600`.
5. Open source with `O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC`.
6. Require source is a regular file, `st_nlink == 1`, nonnegative size and no setuid/setgid.
7. Require source size <= 64 GiB.
8. Stream-copy with 64 KiB buffer, retrying `EINTR` for read/write.
9. Hash source bytes while copying using CommonCrypto SHA-256.
10. Require exact bytes written equal stable source size.
11. `fsync` payload.
12. `fstat` source before/after and require unchanged device/inode/type/link count/size/mtime/ctime.
13. Rewind/reopen payload descriptor-relatively.
14. Stream-read payload and compute independent SHA-256.
15. Require payload regular type, link count 1, mode 0600, exact size and digest equality.
16. Require root/payload namespace identities remain unchanged.
17. Return immutable validated stage with 64 lowercase digest.

Do not compare atime.

Do not load the complete file into `NSData`.

Do not use shell `cp`, `NSFileManager copyItemAtPath:` or caller-selected workspace roots.

# Part 16 — Optional-file cleanup

Cleanup must:

- be idempotent;
- verify retained parent/root/payload namespace identities;
- unlink `payload` through retained root descriptor;
- remove the exact unique root through retained parent descriptor;
- never follow a symlink;
- never use recursive path deletion or `rm -rf`;
- close all descriptors exactly once;
- mark cleaned only after root removal or safe proof it is already absent without replacement.

Cleanup failure returns `CleanupFailed` without exposing a path.

# Part 17 — Destination-plan ordering in Restore

Add exactly one import:

```objc
#import "PXOptionalRestoreStaging.h"
```

After accepted `PXAppGroupRestoreTargetPlan` construction and after reading the current active profile identifier, but before main workspace creation:

1. Call `destinationPlanForRestorePlan:bundleIdentifier:activeProfileIdentifier:error:` exactly once.
2. Propagate exact non-nil destination-plan error.
3. Generic fallback is allowed only for impossible nil-without-error.
4. Return before main workspace creation, first process kill or mutation on failure.

Read `_activeProfileId` once and reuse it for the existing manifest-profile warning and destination plan.

After destination-plan success, Restore optional mutation must not use these helpers as authority:

```text
_profileAppDataPathForBundleID:
_globalSafariLibraryPath
_mobileLibraryBasePath
_preferencesPlistPathForBundleID:
```

They may remain for Backup or read-only debug/unrelated callers.

# Part 18 — Reusable optional tar-directory staging

For profile AppData, global Safari and every non-skipped system-global item:

1. Obtain archive name/source only from `PXRestorePlan` item properties.
2. Obtain accepted member count and regular-file bytes from `restorePlan.validatedArchives`.
3. Validate summary numbers with the existing exact helper.
4. Create one `PXMainDataStagingWorkspace`.
5. Validate empty data directory.
6. Extract archive into `workspace.dataPath` using existing `_tarExtract:`.
7. Require zero extraction exit.
8. Validate staged tree with accepted summary.
9. Use only `PXValidatedMainDataStage.dataPath` as clone source.
10. Revalidate exact destination through `PXOptionalRestoreDestinationPlan` immediately before mutation.
11. Cleanup workspace on every path.

Do not modify `PXMainDataStaging.h/.m`.

The existing root-level container-metadata rejection remains applicable to these staged trees.

# Part 19 — Profile AppData integration

Replace direct archive extraction into profile destination.

Required order:

```text
stage archive
validate tree
revalidate profile destination
wipe exact destination once
clone from validated stage
chown
cleanup workspace
```

Use current tar-pipe/cp clone policy used for accepted directory stages.

Extraction or complete clone failure retains manager code `307` with generic description:

```text
Failed to restore validated profile AppData stage
```

Destination failure propagates exact optional-destination error.

Do not use codes 308/309 for path/source discovery after destination plan and restore plan have succeeded.

Post-clone cleanup failure adds:

```text
Optional-directory staging cleanup failed
```

# Part 20 — Global Safari integration

Replace direct archive extraction into global Safari destination.

Required order:

```text
stage archive
validate tree
revalidate global Safari destination
wipe exact destination once
clone from validated stage
chown
cleanup workspace
```

Extraction or complete clone failure retains manager code `311` with generic description:

```text
Failed to restore validated global Safari stage
```

Do not use codes 312/313 after destination-plan and restore-plan success.

Cleanup warning is the same generic optional-directory warning.

# Part 21 — System-global directory integration

For each destination-plan system-global item in restore-plan order:

1. Stage and validate the archive before any mutation of that item.
2. Revalidate exact destination state.
3. Preserve the existing high-level quarantine behavior as a TASK-2.13 boundary:
   - if destination existed at planning/revalidation, move it to the timestamped trash path;
   - create one exact new destination directory;
   - do not use `mkdir -p`.
4. Check move and mkdir command results; do not use `|| true` to mask failure.
5. Clone only from validated stage.
6. Chown after clone success.
7. Cleanup workspace.

Extraction, move, mkdir or complete clone failure retains manager code `318` with generic description:

```text
Failed to restore validated system-global stage
```

TASK-2.10 does not implement rollback from the existing trash path. TASK-2.13 owns transactional advanced-component handling.

# Part 22 — Shared-system DB file staging

Before stopping any shared-system daemons:

1. Create one `PXOptionalFileStagingWorkspace` for every shared DB plan item.
2. Retain each immutable validated file stage and workspace in plan order.
3. Revalidate every shared DB destination.
4. If any staging/revalidation fails, cleanup all created workspaces and return before daemon termination or file mutation.

Only after all shared DB files are staged and all destinations revalidated may Restore stop daemons.

For each item:

- source must be `validatedStage.filePath`;
- parent directories must already exist from destination planning;
- remove legacy `mkdir -p` behavior;
- preserve existing destination quarantine rename as TASK-2.13 boundary;
- check rename result when a destination exists;
- copy staged payload without `|| true`;
- require copy command exit zero;
- retain current chown/chmod behavior after copy success.

Complete rename/copy failure returns:

```text
domain: PXBackupErrorDomain
code: 320
description: Failed to restore staged optional file
```

Cleanup every workspace on success/failure. Post-copy cleanup failure adds:

```text
Optional-file staging cleanup failed
```

A later file may still fail after an earlier file commits. TASK-2.13 retains multi-file rollback responsibility.

# Part 23 — Preferences file staging

When included:

1. Stage `restorePlan.preferencesSourcePath` through `PXOptionalFileStagingWorkspace`.
2. Revalidate exact Preferences destination.
3. Copy only from `validatedStage.filePath`.
4. Remove `|| true`; require copy exit zero.
5. Preserve chown/chmod and `cfprefsd` refresh after copy success.
6. Cleanup workspace.

Do not warn-and-skip a missing source after accepted Restore plan.

Copy failure uses manager code `320` and the same generic description.

# Part 24 — Keychain input staging

When Keychain is included:

1. Stage `restorePlan.keychainSourcePath` through `PXOptionalFileStagingWorkspace`.
2. Pass only `validatedStage.filePath` to either Keychain Restore method.
3. Preserve exact plan-frozen groups/method/in-app decision.
4. Preserve current warning-only behavior for Keychain execution failure.
5. Cleanup the workspace after helper completion.

Source staging failure is a hard pre-Keychain failure and propagates exact staging error.

Post-helper cleanup failure adds:

```text
Optional-file staging cleanup failed
```

Do not modify Keychain helpers, scripts, bridge protocol, overwrite semantics or group behavior.

# Part 25 — Optional source authority after staging

After each optional source has a validated stage:

```text
profile clone source -> PXValidatedMainDataStage.dataPath
global Safari clone source -> PXValidatedMainDataStage.dataPath
system-global clone source -> PXValidatedMainDataStage.dataPath
shared DB copy source -> PXValidatedOptionalFileStage.filePath
Preferences copy source -> PXValidatedOptionalFileStage.filePath
Keychain input source -> PXValidatedOptionalFileStage.filePath
```

Forbidden operational authority after stage success:

```text
restorePlan.profileAppDataSourcePath directly into target
restorePlan.globalSafariSourcePath directly into target
system-global plan source directly into target
shared DB plan source directly into destination
preferencesSourcePath directly into destination
keychainSourcePath directly into helper
```

Restore plan remains semantic source identity. The validated stage becomes operational byte authority.

# Part 26 — Component ordering

Preserve current high-level component order:

```text
main ApplicationData
profile AppData
global Safari
App Groups
system-global
shared-system DB
Preferences
Keychain
```

Destination-plan construction occurs before main staging/mutation.

Per optional component, staging and destination revalidation must precede that component's mutation.

Shared DB staging/revalidation must precede shared-daemon termination.

TASK-2.10 does not reorder App Groups relative to profile/global Safari.

# Part 27 — Failure and cleanup precedence

For every owned workspace:

- staging/validation error remains primary;
- destination revalidation error remains primary;
- extraction/clone/copy manager error remains primary;
- cleanup failure before mutation must not replace the primary error;
- cleanup failure after successful mutation becomes only the exact generic warning.

All completion callbacks remain main-queue and exactly once.

Do not expose command stderr in new public errors.

# Part 28 — Non-regression

Do not change:

- public Restore signature;
- manifest/schema/version/bundle gates;
- main destination resolver/revalidation;
- artifact/archive validators;
- immutable `PXRestorePlan` API;
- App Group target planner/staging/equivalence/revalidation;
- main staging workspace implementation;
- main clone behavior and codes 303/316/317;
- App Group codes 310/319;
- tar executable preference;
- Keychain warning-only execution failure;
- Backup behavior;
- UI behavior;
- `PXRestoreResult`.

Required byte-identical protected source includes:

```text
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXRestorePlan.h/.m
```

# Part 29 — Transaction boundaries

Do not implement:

- main target quarantine/rollback — TASK-2.11;
- App Group multi-target rollback — TASK-2.12;
- transactional optional-component journal/rollback — TASK-2.13;
- structured component result — TASK-2.14;
- atomic backup publication;
- UI changes.

Existing system-global/shared-DB trash rename behavior may remain but must not be described as complete transaction safety.

# Part 30 — Static gates

## Scope

```text
PXOptionalRestoreStaging.h added
PXOptionalRestoreStaging.m added
AppDataBackupManager.m modified
TASK-2.10-REPORT.md added
all other production diffs = 0
```

## Public API

```text
error-domain exports = 1
field-path exports = 1
error codes = exactly 16
validated-file-stage classes = 1
file-workspace classes = 1
destination-plan classes = 1
destination-plan factories = 1
file-workspace factories = 1
revalidation methods = exactly 5
copyWithZone implementations = 2
public readwrite properties = 0
```

## Destination authority

```text
fixed mobile Library candidates = 4
first-existing selection = 0
recorded manifest destination authority = 0
_profileAppDataPathForBundleID Restore authority = 0
_globalSafariLibraryPath Restore authority = 0
_mobileLibraryBasePath Restore authority = 0
_preferencesPlistPathForBundleID Restore authority = 0
destination-plan factory calls = 1
profile revalidation calls = 1 when included
global Safari revalidation calls = 1 when included
system-global revalidation per item
shared DB revalidation per item
Preferences revalidation = 1 when included
cross-component collision check present
```

## File staging

```text
/private/var/tmp fixed parent = 1
mkdtemp optional-file template = 1
payload name = payload
O_NOFOLLOW present
O_CLOEXEC present
source fstat before/after present
source nlink == 1
payload mode 0600
streaming CommonCrypto SHA-256
payload digest reread/compare
64 GiB limit
path-based recursive cleanup = 0
shell cp inside staging module = 0
```

## Restore

```text
optional destination plan before main workspace
profile archive direct extraction into target = 0
global Safari archive direct extraction into target = 0
system-global archive direct extraction into target = 0
shared DB source from plan directly = 0
Preferences source from plan directly = 0
Keychain source from plan directly = 0
validated directory stages used
validated file stages used
shared DB staging before daemon kill
legacy shared DB mkdir -p = 0
masked optional cp/mv/mkdir with || true = 0
code 320 generic file-copy failure present
exact cleanup warnings present
```

## Protected gates

```text
PXMainDataStaging diff = 0
PXAppGroupRestoreTargetPlan diff = 0
PXRestorePlan diff = 0
validator/resolver diff = 0
Makefile diff = 0
UI diff = 0
Backup semantic diff = 0
```

# Part 31 — Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.10-REPORT.md
```

The report must include:

- baseline and exact scope;
- protected SHA-256 before/after;
- exact public API and 16-code enum;
- immutability/lifecycle proof;
- non-sensitive error contract;
- fixed mobile Library root resolution matrix;
- exact profile/global/system/shared/preferences destination policies;
- absent/existing final-object matrices;
- collision and ancestor/descendant proof;
- destination snapshot/revalidation proof;
- optional planning limits;
- optional-file workspace identity;
- source/payload before-after stability;
- independent source/staged digest proof;
- descriptor-relative cleanup and idempotence;
- destination-plan manager ordering;
- profile/global/system archive-staging integration;
- shared DB all-files-before-daemon-kill proof;
- Preferences and Keychain file-stage proof;
- post-stage zero direct-source authority inventory;
- cleanup path inventory;
- manager code 320 contract;
- TASK-2.1 through TASK-2.9 non-regression;
- TASK-2.11 through TASK-2.14 boundaries;
- complete source diff;
- static/forbidden token counts;
- at least 190 explicit scenario rows;
- whitespace/CRLF/NUL/generated-file audit;
- build status and target-device runtime risks.

Required scenario coverage includes at least:

1. rootful alias candidates collapse to one mobile Library;
2. zero mobile Library roots;
3. distinct rootful/rootless roots ambiguous;
4. final root symlink rejected;
5. bundle identifier safe component;
6. unsafe bundle identifier;
7. profile excluded;
8. profile included without profile ID;
9. profile destination missing;
10. profile destination symlink;
11. profile destination accepted;
12. global Safari excluded;
13. global Safari included for wrong bundle;
14. global Safari destination missing;
15. global Safari accepted;
16. system-global existing directory;
17. system-global absent final;
18. system-global final file conflict;
19. Safari duplicate skipped;
20. shared DB existing file;
21. shared DB absent file with existing parent;
22. shared DB missing parent;
23. shared DB symlink final;
24. Preferences existing file;
25. Preferences absent file;
26. Preferences parent missing;
27. exact destination duplicate;
28. directory/file overlap;
29. ancestor/descendant overlap;
30. 4096 total items accepted;
31. 4097 rejected;
32. destination unchanged revalidation;
33. destination inode replacement;
34. absent destination appears before mutation;
35. source final symlink;
36. source hard link;
37. source FIFO;
38. source setid;
39. zero-byte source;
40. 64 GiB source boundary;
41. 64 GiB + 1 rejection;
42. source changes during copy;
43. short write retry;
44. EINTR read retry;
45. payload mode 0600;
46. payload size mismatch;
47. payload digest mismatch;
48. workspace identity replacement;
49. idempotent cleanup;
50. cleanup symlink substitution;
51. profile archive extraction failure;
52. profile stage validation failure;
53. profile destination revalidation failure;
54. profile clone failure;
55. global Safari equivalents;
56. system-global staging before quarantine;
57. system-global move failure;
58. system-global mkdir failure;
59. system-global clone failure;
60. shared DB all staged before daemon stop;
61. one shared DB staging failure stops before daemon kill;
62. shared DB revalidation failure stops before daemon kill;
63. shared DB copy from staged path;
64. shared DB copy failure code 320;
65. Preferences copy from staged path;
66. Preferences failure code 320;
67. Keychain helper receives staged path;
68. Keychain helper failure remains warning-only;
69. Keychain staging failure is hard failure;
70. cleanup warning after successful mutation;
71. no optional direct archive-to-target extraction;
72. no direct plan-file source after staging;
73. destination plan before main workspace;
74. protected main staging unchanged;
75. protected App Group flow unchanged;
76. transaction tasks remain absent.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 32 — Post-commit gates

After committing:

```powershell
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 48cb463b9f1bb6b1244237c227fa890f3020071d..HEAD --check
git diff --name-status 48cb463b9f1bb6b1244237c227fa890f3020071d..HEAD
git status --short --untracked-files=all
```

Implementation commit must contain only:

```text
PXOptionalRestoreStaging.h
PXOptionalRestoreStaging.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.10-REPORT.md
```

Stop after TASK-2.10.

Do not implement TASK-2.11, TASK-2.12, TASK-2.13 or TASK-2.14.
