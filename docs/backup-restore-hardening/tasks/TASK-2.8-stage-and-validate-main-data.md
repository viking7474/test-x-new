# TASK-2.8 — Stage and Validate Main Application Data

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `d9ab9013b5d637ceb71695003bbc7153ac78151c`
- Previous task: TASK-2.7 source review ACCEPTED
- Next task: TASK-2.9 remains LOCKED

## Objective

Replace the current predictable and weakly validated main-data staging flow with one private unique workspace and one descriptor-relative staged-tree validation boundary.

Today Restore:

- uses `/tmp/weaponx_restore_<pid>`;
- removes and recreates that predictable path through `NSFileManager`;
- may convert a nonzero tar result into success merely because some content exists;
- does not reject symlinks, hard links, devices, FIFOs, sockets, mount crossings or container metadata replacement in the extracted tree;
- does not compare extracted regular-file bytes with the accepted archive summary;
- can kill the target process before it knows the main staged tree is valid;
- cleans staging inconsistently on failure paths.

TASK-2.8 must create a private unique staging workspace, extract the main archive into it, validate the resulting filesystem tree before process termination or target mutation, and use only the validated stage as the main clone source.

This task does not add transactional target commit or rollback. The existing wipe/clone behavior remains after successful staging validation. TASK-2.11 still owns transactional main-data commit and rollback.

## Production scope

Create:

```text
PXMainDataStaging.h
PXMainDataStaging.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-2.8-REPORT.md
```

Suggested commit subject:

```text
phase2(task-2.8): stage and validate main data
```

Implementation commit may contain only:

```text
PXMainDataStaging.h
PXMainDataStaging.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.8-REPORT.md
```

## Protected production files

Do not modify:

```text
AppDataBackupManager.h
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
```

Do not edit coordinator task/review/status/roadmap/decisions/README files.

The existing `ProjectX_FILES = $(wildcard *.m) ...` rule automatically includes the new implementation. `Makefile` must remain byte-identical.

## Baseline evidence

Before modifying source, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Record SHA-256 before/after for every protected production file.

# Part 1 — Exact public API

Create `PXMainDataStaging.h` with this exact public surface:

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXMainDataStagingErrorDomain;
FOUNDATION_EXPORT NSString * const PXMainDataStagingErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXMainDataStagingErrorCode) {
    PXMainDataStagingErrorInvalidInput = 1,
    PXMainDataStagingErrorWorkspaceCreationFailed = 2,
    PXMainDataStagingErrorWorkspaceIdentityChanged = 3,
    PXMainDataStagingErrorWorkspaceNotEmpty = 4,
    PXMainDataStagingErrorEnumerationFailed = 5,
    PXMainDataStagingErrorUnsafeEntryPath = 6,
    PXMainDataStagingErrorUnsupportedEntryType = 7,
    PXMainDataStagingErrorHardLinkRejected = 8,
    PXMainDataStagingErrorForbiddenContainerMetadata = 9,
    PXMainDataStagingErrorLimitExceeded = 10,
    PXMainDataStagingErrorReadFailed = 11,
    PXMainDataStagingErrorFilesystemChanged = 12,
    PXMainDataStagingErrorSizeMismatch = 13,
    PXMainDataStagingErrorCleanupFailed = 14,
};

__attribute__((objc_subclassing_restricted))
@interface PXValidatedMainDataStage : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *workspaceRootPath;
@property (nonatomic, copy, readonly) NSString *dataPath;
@property (nonatomic, assign, readonly) NSUInteger entryCount;
@property (nonatomic, assign, readonly) NSUInteger regularFileCount;
@property (nonatomic, assign, readonly) NSUInteger directoryCount;
@property (nonatomic, assign, readonly) unsigned long long regularFileBytes;
@property (nonatomic, copy, readonly) NSString *treeSHA256;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXMainDataStagingWorkspace : NSObject

@property (nonatomic, copy, readonly) NSString *rootPath;
@property (nonatomic, copy, readonly) NSString *dataPath;

+ (nullable instancetype)createWorkspaceWithError:(NSError * _Nullable * _Nullable)error;

- (BOOL)validateEmptyDataDirectoryWithError:(NSError * _Nullable * _Nullable)error;

- (nullable PXValidatedMainDataStage *)validatedStageWithExpectedLogicalMemberCount:(NSUInteger)logicalMemberCount
                                                           expectedRegularFileBytes:(unsigned long long)regularFileBytes
                                                                               error:(NSError * _Nullable * _Nullable)error;

- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```

Do not add:

- extraction or tar execution methods;
- arbitrary workspace-parent arguments;
- caller-selected staging paths;
- warning/bypass flags;
- target-container arguments;
- commit/rollback methods;
- mutable public state;
- generic dictionary results;
- App Group or optional-component staging APIs.

# Part 2 — Error contract

Every public method that accepts `NSError **` must clear `*error` at entry.

Success:

```text
create -> non-nil workspace, nil error
empty validation -> YES, nil error
stage validation -> non-nil immutable result, nil error
cleanup -> YES, nil error
```

Failure:

```text
object/result == nil or BOOL == NO
error domain == PXMainDataStagingErrorDomain
error code == one of the exact 14 codes
```

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXMainDataStagingErrorFieldPathKey
```

Stable field paths include:

```text
$
$.workspace
$.data
$.data.entries[0]
$.data.entries[125].path
$.data.regularFileBytes
```

Entry indexes must follow the deterministic validation order defined below.

Do not expose in errors or logs:

- workspace/root/data path;
- file or directory name;
- relative path;
- device/inode;
- expected or actual size;
- content digest;
- bundle ID;
- archive name/path;
- errno text;
- nested arbitrary error.

# Part 3 — Workspace object and lifetime

`PXMainDataStagingWorkspace` is a lifecycle object, not an immutable plan object.

It must privately retain the descriptors and identities needed to prove ownership of:

```text
fixed staging parent
unique workspace root
workspace data directory
```

Public path properties are copied strings. No descriptor may be publicly exposed.

Required lifecycle:

```text
create
validate empty
external extraction by manager
validate staged tree
manager consumes validated stage
explicit cleanup
```

`cleanupWithError:` must be idempotent:

- first successful cleanup returns YES;
- later cleanup calls return YES and nil error;
- validation after successful cleanup fails as InvalidInput or WorkspaceIdentityChanged;
- deallocation closes every remaining descriptor and performs a best-effort safe cleanup attempt;
- deallocation must never follow a symlink or delete an unrelated replacement path.

The workspace object is not `NSCopying` and must not contain callbacks, a command runner or an extraction process.

# Part 4 — Fixed staging parent and unique root

Use the fixed real staging parent:

```text
/private/var/tmp
```

Do not derive the parent from:

- manifest data;
- environment variables;
- bundle ID;
- backup directory;
- `NSTemporaryDirectory()`;
- caller input.

Creation must:

1. `lstat` the fixed parent and require a real directory, not a symlink.
2. Open it with `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`.
3. Use `mkdtemp` with a fixed non-sensitive template equivalent to:

   ```text
   /private/var/tmp/weaponx_restore_main.XXXXXX
   ```

4. Require the generated basename to remain one direct child of the fixed parent.
5. `lstat` and open the new root with no-follow directory flags.
6. Require root mode `0700`; call `fchmod` and verify when needed.
7. Create exactly one child named `data` through `mkdirat` with mode `0700`.
8. Open `data` with `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`.
9. Require parent/root/data descriptor identities to be stable and root/data to be on the same device.
10. Retain the fixed parent descriptor, unique root basename, root descriptor, data descriptor and exact initial identities.

Do not use a predictable PID-only path.

Forbidden staging templates include:

```text
/tmp/weaponx_restore_<pid>
/private/var/tmp/weaponx_restore_<pid>
backupDir/staging
bundleID-based staging paths
```

Creation failure must close all acquired descriptors and remove only the partially created exact workspace through safe parent-relative operations.

# Part 5 — Workspace identity checks

Before empty validation, tree validation and cleanup, require:

- retained descriptors are valid;
- root and data descriptor types remain directories;
- root and data descriptor device/inode identities match their creation snapshots;
- `fstatat`/`lstat` of the retained parent-relative root basename identifies the same non-symlink directory;
- `fstatat` of root-relative `data` identifies the same non-symlink directory;
- root and data remain on the original device;
- setuid/setgid bits are not present on root or data.

Any substitution, symlink, mount/device change or identity mismatch fails closed with `WorkspaceIdentityChanged`.

Do not replace stored paths or descriptor identities after a mismatch.

# Part 6 — Empty-directory gate before extraction

`validateEmptyDataDirectoryWithError:` must run before external tar extraction.

Require:

- workspace identity checks pass;
- workspace root contains exactly one child named `data`;
- `data` contains no child other than `.` and `..`;
- enumeration is descriptor-relative;
- directory identities and timestamps remain stable across enumeration;
- all duplicated enumeration descriptors have `FD_CLOEXEC` before `fdopendir`.

Unexpected root entries or any data entry fail `WorkspaceNotEmpty`.

Do not delete unexpected entries in this method.

# Part 7 — Accepted archive-summary input

The stage validator receives the main archive summary already retained by `PXRestorePlan.validatedArchives`.

Manager must obtain exact values for:

```text
restorePlan.dataArchiveName
restorePlan.validatedArchives.memberCountsByArchiveName[dataArchiveName]
restorePlan.validatedArchives.regularFileBytesByArchiveName[dataArchiveName]
```

The summary values must be runtime `NSNumber` objects representing nonnegative integral values safely representable by the public method argument types.

Missing or invalid summary values are an impossible snapshot inconsistency and must fail with a generic `PXMainDataStagingErrorInvalidInput` before workspace creation.

Do not reread the manifest, archive or backup directory to derive these values.

# Part 8 — Deterministic descriptor-relative tree traversal

`validatedStageWithExpectedLogicalMemberCount:expectedRegularFileBytes:error:` must:

- recheck workspace identity;
- start from the retained data directory descriptor;
- never traverse from the public path string;
- use `fstatat(..., AT_SYMLINK_NOFOLLOW)` before opening an entry;
- open child directories with `openat` plus `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`;
- open regular files with `openat` plus `O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC`;
- use iterative or bounded heap traversal, not unbounded recursive call depth;
- close every descriptor and directory stream on every path;
- process each directory's entries in strict raw UTF-8 byte lexicographic order;
- assign one monotonically increasing global entry index in pre-order.

`readdir` names must be converted from exact bytes with strict UTF-8 validation. Do not use lossy conversion.

Do not use `NSFileManager` enumeration as the proof boundary.

# Part 9 — Staged path policy

For every staged entry, require:

- strict valid UTF-8 filename bytes;
- component length between 1 and 255 UTF-8 bytes;
- full relative path length no more than 4096 UTF-8 bytes;
- no NUL;
- no ASCII control characters;
- no backslash;
- no component `.` or `..`;
- no path normalization, case folding, percent decoding or Unicode normalization.

A filesystem entry cannot contain `/`, but relative path construction must remain separator-safe and overflow-safe.

Path failure uses `UnsafeEntryPath` and a stable indexed field path without including the actual value.

# Part 10 — Allowed filesystem types

Allow only:

```text
regular file
directory
```

Reject:

```text
symbolic link
hard-linked regular file
FIFO
socket
character device
block device
unknown type
mount/device crossing
setuid entry
setgid entry
```

Rules:

- any symlink or special type -> `UnsupportedEntryType`;
- regular file with `st_nlink != 1` -> `HardLinkRejected`;
- child with `st_dev` different from the staged data root -> `UnsupportedEntryType`;
- setuid/setgid bit on a file or directory -> `UnsupportedEntryType`.

Do not follow links to decide whether their targets are safe.

# Part 11 — Protect target container identity metadata

The main data archive writer excludes the target container's identity metadata. The staged tree must not be allowed to reintroduce or overwrite it.

Reject either exact root-level staged entry:

```text
.com.apple.mobile_container_manager.metadata.plist
.com.apple.containermanagerd.metadata.plist
```

The comparison is exact and case-sensitive. Do not trim or normalize.

Failure uses:

```text
PXMainDataStagingErrorForbiddenContainerMetadata
```

This check applies only at the staged data root. Do not broadly reject unrelated nested filenames.

# Part 12 — Fixed resource limits

Use fixed private limits:

```text
archive logical-member maximum accepted from summary: 200000
maximum derived implicit directories: 200000
maximum staged entries: 400000
maximum UTF-8 path bytes: 4096
maximum UTF-8 component bytes: 255
maximum traversal depth: 2048
maximum cleanup entries: 500000
streaming read buffer: bounded fixed size
```

Derive the per-stage entry ceiling overflow-safely:

```text
if expectedLogicalMemberCount == 0:
    maximum staged entries == 0
else:
    min(400000, expectedLogicalMemberCount + 200000)
```

Require:

```text
regularFileCount <= expectedLogicalMemberCount
entryCount <= derived staged-entry ceiling
```

Boundary outcomes:

```text
expected logical members 0 + empty stage       -> accepted
expected logical members 0 + one staged entry  -> rejected
400000 staged entries                           -> accepted only when derived ceiling allows
400001 staged entries                           -> LimitExceeded
depth 2048                                      -> accepted
depth 2049                                      -> LimitExceeded
```

All count, depth, path-length and byte-sum arithmetic must be overflow-safe before allocation or append.

Do not expose configurable limits.

# Part 13 — Exact regular-file byte accounting

For every regular file:

1. Open descriptor-relatively without following links.
2. `fstat` before reading.
3. Require regular type, same device and `st_nlink == 1`.
4. Add `st_size` to the running total with overflow checks.
5. Stream the complete content, retrying `EINTR`.
6. Require bytes read exactly equal the stable file size.
7. `fstat` after reading.
8. Require unchanged device, inode, type, link count, size, mtime and ctime.

Do not compare atime.

After complete traversal:

```text
actual regularFileBytes == expectedRegularFileBytes
```

Expected zero must be compared exactly.

Mismatch uses `SizeMismatch` at:

```text
$.data.regularFileBytes
```

Read errors use `ReadFailed`; identity changes use `FilesystemChanged`.

# Part 14 — Directory stability

For every opened directory, including staged data root:

- capture `fstat` before enumeration;
- require directory type and original device;
- enumerate deterministically;
- capture `fstat` after enumeration;
- require unchanged device, inode, type, mtime and ctime.

A directory changing during validation fails `FilesystemChanged`.

Do not compare atime or ordinary directory link count.

# Part 15 — Deterministic staged-tree digest

Compute one lowercase SHA-256 tree digest while traversing.

Use CommonCrypto streaming SHA-256 and a fixed private domain prefix:

```text
PXMainDataStageTreeV1\0
```

For each entry in deterministic pre-order, hash a fixed binary representation containing:

```text
type byte: 'D' or 'F'
relative UTF-8 path byte length as unsigned 32-bit big-endian
exact relative UTF-8 path bytes
permission/mode bits masked to 07777 as unsigned 32-bit big-endian
regular-file size as unsigned 64-bit big-endian, or zero for directory
regular-file content bytes for files
```

Do not include:

- absolute workspace path;
- device/inode;
- timestamps;
- uid/gid;
- atime;
- xattr/ACL bytes.

The digest is a deterministic staged snapshot for later transaction tasks. TASK-2.8 does not compare it with the tar digest and does not implement rollback.

`PXValidatedMainDataStage.treeSHA256` must be exactly 64 lowercase hex characters.

# Part 16 — Immutable validated-stage result

On successful validation, return one immutable `PXValidatedMainDataStage` containing copied:

```text
workspaceRootPath
dataPath
entryCount
regularFileCount
directoryCount
regularFileBytes
treeSHA256
```

The result must:

- be subclassing-restricted;
- expose readonly properties only;
- copy strings;
- return `self` from `copyWithZone:`;
- prohibit ordinary `init` and `new`;
- contain no descriptor, workspace cleanup callback, parser or mutable collection.

The result proves one validation snapshot. It does not authorize a target destination and does not guarantee the stage cannot change after validation.

# Part 17 — Safe descriptor-relative cleanup

`cleanupWithError:` must never call recursive path-based deletion on an unverified public path.

Required cleanup behavior:

1. If already cleaned, return YES.
2. Verify retained parent/root/data identities as far as still possible.
3. Traverse workspace contents descriptor-relatively.
4. Use `fstatat(..., AT_SYMLINK_NOFOLLOW)`.
5. For directories, open with no-follow and recursively/iteratively clean their contents.
6. For non-directories, use `unlinkat` without following links.
7. Remove directories with `unlinkat(..., AT_REMOVEDIR)`.
8. Remove the unique workspace root through the retained fixed-parent descriptor and exact generated basename.
9. Never traverse a symlink or mount crossing.
10. Enforce the fixed 500,000 cleanup-entry limit.
11. Close every retained descriptor exactly once.
12. Mark the object cleaned only after the owned root has been removed or proven already absent without replacement.

If cleanup cannot finish safely:

- close descriptors that no longer provide safe ownership;
- return `CleanupFailed`;
- do not attempt `NSFileManager removeItemAtPath:` or shell `rm -rf` fallback.

Cleanup errors must not reveal names or paths.

# Part 18 — Staging implementation boundary

`PXMainDataStaging.m` may import only:

```objc
#import "PXMainDataStaging.h"
#import <CommonCrypto/CommonDigest.h>
```

and required POSIX/C headers.

Allowed because this is a staging component:

```text
mkdtemp
open/openat
mkdirat
fchmod/fcntl
fstat/fstatat/lstat
fdopendir/readdir/closedir
read
unlinkat
realpath when needed for fixed-parent proof
```

Forbidden:

```text
UIKit
AppDataBackupManager
PXRestorePlan
PXBackupArtifactVerifier
PXBackupArchiveValidator
AppDataCleaner
CommandRunner
NSTask
posix_spawn/system/popen
external tar/bsdtar invocation
Security/Keychain
NSUserDefaults
notifications/dispatch
shell construction
logging raw values
global mutable state
caller-selected roots
filesystem writes outside the owned unique workspace
```

Do not load regular files wholly into `NSData`.

# Part 19 — Restore integration

Add exactly one import to `AppDataBackupManager.m`:

```objc
#import "PXMainDataStaging.h"
```

Keep the accepted TASK-2.7 plan call and post-plan authority boundary.

The main staging flow must use:

```text
restorePlan.dataArchivePath
restorePlan.dataArchiveName
restorePlan.validatedArchives summary maps
```

Do not reread:

```text
manifest
verifiedArtifacts local
validatedArchives local
backupDir + archive name
```

Required sequence after plan success:

1. Existing warnings, manager helpers, debug setup and tar discovery may occur.
2. Resolve any read-only warning/profile/App Group semantic inputs needed before process termination.
3. Obtain accepted main archive member-count and regular-byte summaries from `restorePlan.validatedArchives`.
4. Create one `PXMainDataStagingWorkspace`.
5. Validate the empty data directory.
6. Extract `restorePlan.dataArchivePath` into `workspace.dataPath` using the existing external tar helper.
7. Require extraction exit code zero.
8. Validate the complete staged tree with the accepted summary values.
9. Only after successful staged-tree validation may Restore kill the target process.
10. Revalidate the ApplicationData target model/path as already required.
11. Wipe the target.
12. Clone from `validatedStage.dataPath` only.
13. Cleanup the workspace after success or on every failure path.

The stage validator must run before:

```text
first _killRelatedProcessesForBundleID: call in Restore
main target pre-mutation revalidation
main target wipe
main tar-pipe clone
main cp fallback
main target chown
all optional-component mutation
```

Debug-file writes and staging-workspace writes are not target mutation and may precede staged-tree validation.

# Part 20 — Remove predictable staging behavior

Remove from Restore:

```objc
[NSString stringWithFormat:@"/tmp/weaponx_restore_%d", getpid()]
[stagingRoot stringByAppendingPathComponent:@"data"]
[fm removeItemAtPath:stagingRoot error:nil]
[fm createDirectoryAtPath:stagingData ...]
```

After TASK-2.8:

```text
predictable weaponx_restore_<pid> staging path: 0
manager path-based recursive staging cleanup: 0
manager direct staging directory creation: 0
```

The manager may read `workspace.dataPath` only for the external extraction call. After validation, clone source must be `validatedStage.dataPath`.

# Part 21 — Extraction must be fail-closed

The current `_tarExtractDataArchive:archive:toDir:warnings:` helper must no longer convert a nonzero extraction result into success because some staged content exists.

Required behavior:

```text
return the actual result of _tarExtract:archive:toDir:
nonzero remains nonzero
partial content never converts failure to success
```

The `warnings` parameter may remain for compatibility but must not authorize continuation. Mark it unused when necessary.

Remove or leave unused the weak `_directoryHasRestoredContent:` helper, but after TASK-2.8:

```text
_directoryHasRestoredContent calls from Restore/extraction: 0
"Cannot open: File exists" success conversion: 0
partial-stage continuation warning: 0
```

Existing `_tarExtract:` behavior may retain its xattr/ACL first attempt and plain fallback. If both fail, TASK-2.8 must fail with existing manager code 316 after safe workspace cleanup.

# Part 22 — Failure and cleanup precedence

After workspace creation, every return path before normal workspace cleanup must call `cleanupWithError:` exactly once or through one idempotent cleanup helper.

Required cases:

```text
empty validation failure
extraction failure
stage validation failure
main target revalidation failure
tar-pipe plus cp clone failure
successful main clone
```

Primary failure precedence:

- workspace creation/empty/stage-validation error:
  - propagate exact non-nil staging `NSError`;
- extraction failure:
  - keep existing manager code 316;
- target revalidation failure:
  - keep manager code 303;
- clone failure:
  - keep manager code 317.

A cleanup failure before target mutation must not replace a more specific primary failure.

A cleanup failure after successful main clone cannot safely turn the already-mutated Restore into an ordinary failure. Add one generic warning:

```text
Main-data staging cleanup failed
```

Do not include the staging path or cleanup nested error.

# Part 23 — Main source and target ordering

The main-data operational order must become:

```text
accepted PXRestorePlan
tar executable selected
private unique workspace created
workspace proven empty
main archive extracted with zero exit
staged tree validated
first target-process kill
ApplicationData target revalidated
main target wiped
validated staged tree cloned
main target ownership correction
workspace cleanup
```

No target process kill, target wipe or optional-component mutation may occur when staged validation fails.

# Part 24 — Non-regression boundaries

Keep unchanged:

- public Restore signature;
- manifest/schema/version gate;
- exact bundle-ID gate and code 304;
- exact main destination planning and code 303;
- artifact verifier;
- archive validator including TASK-2.6A fixes;
- immutable `PXRestorePlan` API/source;
- post-plan manifest/artifact/archive local authority counts at zero;
- tar executable preference list;
- existing manager codes 316 and 317;
- main target pre-mutation `PXDestructivePathValidator` revalidation;
- tar-pipe then cp fallback clone policy;
- main target ownership correction;
- App Group destination behavior;
- profile/global/system/shared DB/Preferences/Keychain behavior;
- `PXRestoreResult`;
- Backup behavior;
- UI.

Intentional TASK-2.8 behavior changes are limited to:

- unique private workspace;
- fail-closed extraction;
- staged-tree validation;
- process kill delayed until staging validation succeeds;
- safe deterministic cleanup.

# Part 25 — TASK-2.9 and later boundaries

Do not:

- stage or validate App Groups;
- change `resolveGroupContainersForGroupIDs:`;
- stage profile AppData, global Safari, system-global data, shared DB, Preferences or Keychain;
- quarantine the current main target;
- create a transaction journal;
- commit by rename/swap;
- implement target rollback;
- retain target backup copies;
- add structured component results;
- change UI;
- change Backup publication.

TASK-2.9 owns App Group staging.
TASK-2.10 owns optional-component staging.
TASK-2.11 owns transactional main-data commit and rollback.

# Part 26 — Non-regression body hashes

Record before/after body hashes for at least:

```text
PXBackupManifestVersionIsSupported
PXResolveExactRestoreApplicationDataTarget
readManifestAtBackupDirectory:error:
createBackupForBundleID:appName:options:completion:
PXRestorePlan planForManifest:...
PXBackupArtifactVerifier verifiedArtifactsForManifest:...
PXBackupArchiveValidator validatedArchivesForManifest:...
_tarExtract:archive:toDir:
```

All must remain equal.

`_tarExtractDataArchive:archive:toDir:warnings:` is intentionally changed only to remove partial-failure success conversion.

Also prove zero diff for all protected source files.

# Part 27 — Final static gates

## Scope

```text
PXMainDataStaging.h added
PXMainDataStaging.m added
AppDataBackupManager.m modified
report added
all other production diffs = 0
```

## Public API

```text
error-domain exports = 1
field-path exports = 1
error codes = exactly 14
validated-stage classes = exactly 1
workspace classes = exactly 1
workspace creation methods = exactly 1
empty-validation methods = exactly 1
stage-validation methods = exactly 1
cleanup methods = exactly 1
public mutable setters = 0
```

## Workspace safety

```text
fixed parent /private/var/tmp = 1
mkdtemp = 1
PID-only template = 0
O_NOFOLLOW present
O_CLOEXEC present
mkdirat data = 1
root/data mode 0700 verification present
retained parent/root/data descriptors present
identity checks before empty/validate/cleanup present
```

## Tree validation

```text
descriptor-relative traversal present
fstatat AT_SYMLINK_NOFOLLOW present
regular/directory only policy present
hard-link rejection present
mount/device-crossing rejection present
setuid/setgid rejection present
forbidden container metadata names = exactly 2
deterministic UTF-8 byte ordering present
entry maximum = 400000
cleanup maximum = 500000
depth maximum = 2048
path maximum = 4096
component maximum = 255
exact regular-byte comparison present
streaming CommonCrypto tree SHA-256 present
whole-file NSData loading = 0
```

## Manager integration

```text
PXMainDataStaging import = 1
workspace creation calls in Restore = 1
empty validation calls = 1
stage validation calls = 1
predictable weaponx_restore_<pid> path = 0
manager staging removeItemAtPath = 0
manager staging createDirectoryAtPath = 0
validatedStage.dataPath clone authority present
workspace.dataPath used only for extraction
first Restore process kill follows stage validation
stage validation precedes target revalidation/wipe
all workspace failure paths cleanup
```

## Fail-closed extraction

```text
Cannot open/File exists success conversion = 0
_directoryHasRestoredContent extraction calls = 0
partial-stage continuation warning = 0
nonzero extraction remains manager code 316
clone failure remains manager code 317
```

## Accepted boundaries

```text
PXRestorePlan files diff = 0
artifact/archive validator files diff = 0
Makefile diff = 0
post-plan direct manifest reads = 0
post-plan verifiedArtifacts local lookups = 0
post-plan validatedArchives local lookups = 0
App Group staging additions = 0
transaction/rollback additions = 0
```

# Part 28 — Scenario matrix

Report must include at least 150 explicit scenario rows, including:

1. fixed parent exists as real directory;
2. fixed parent missing;
3. fixed parent final symlink;
4. fixed parent non-directory;
5. parent open failure;
6. mkdtemp success;
7. mkdtemp collision retry handled by libc;
8. mkdtemp failure cleanup;
9. generated root mode 0700;
10. root fchmod failure;
11. root identity mismatch;
12. data mkdirat success;
13. data already exists unexpectedly;
14. data open no-follow;
15. data identity mismatch;
16. root/data device mismatch;
17. root contains only data;
18. root has unexpected sibling;
19. data empty accepted;
20. data nonempty rejected;
21. enumeration descriptor CLOEXEC;
22. empty validation clears prior error;
23. ordinary regular file accepted;
24. ordinary directory accepted;
25. nested valid tree accepted;
26. symlink file rejected;
27. symlink directory rejected;
28. hard-linked regular file rejected;
29. FIFO rejected;
30. socket rejected;
31. character device rejected;
32. block device rejected;
33. unknown type rejected;
34. mount/device crossing rejected;
35. setuid regular file rejected;
36. setgid regular file rejected;
37. setuid directory rejected;
38. invalid UTF-8 component rejected;
39. ASCII control component rejected;
40. backslash component rejected;
41. component 255 bytes accepted;
42. component 256 bytes rejected;
43. full path 4096 bytes accepted;
44. full path 4097 bytes rejected;
45. depth 2048 accepted;
46. depth 2049 rejected;
47. root mobile-container metadata rejected;
48. root containermanagerd metadata rejected;
49. case-different metadata name not broadened;
50. nested same metadata filename not broadly rejected;
51. expected zero bytes and empty stage accepted;
52. expected zero bytes and zero-byte file handled;
53. expected nonzero bytes exact accepted;
54. actual fewer bytes rejected;
55. actual more bytes rejected;
56. byte-sum overflow rejected;
57. regular file count <= logical count accepted;
58. regular file count > logical count rejected;
59. logical count zero and empty accepted;
60. logical count zero and directory rejected;
61. derived implicit-directory allowance;
62. 400000 entry boundary accepted when allowed;
63. 400001 entry rejected;
64. entry-count overflow rejected;
65. file read retries EINTR;
66. non-EINTR read failure;
67. short read against stable size rejected;
68. file device changes during read;
69. file inode changes during read;
70. file type changes during read;
71. file size changes during read;
72. file mtime changes during read;
73. file ctime changes during read;
74. file link count changes during read;
75. atime-only change ignored;
76. directory changes during enumeration;
77. directory atime-only change ignored;
78. deterministic sibling byte ordering;
79. deterministic pre-order indexing;
80. digest domain prefix included;
81. digest includes type;
82. digest includes path length/path bytes;
83. digest includes mode;
84. digest includes file size;
85. digest includes file contents;
86. digest omits absolute staging path;
87. digest lowercase 64 hex;
88. identical tree gives identical digest;
89. content change changes digest;
90. path change changes digest;
91. validated result copies paths;
92. validated result counts files/directories;
93. validated result copyWithZone returns self;
94. workspace not copyable;
95. cleanup empty workspace;
96. cleanup populated workspace;
97. cleanup symlink without following;
98. cleanup special file without opening;
99. cleanup nested directories;
100. cleanup entry limit 500000;
101. cleanup limit exceeded fails safely;
102. cleanup root replacement mismatch;
103. cleanup data replacement mismatch;
104. cleanup idempotent second call;
105. cleanup closes descriptors;
106. dealloc best-effort cleanup;
107. cleanup never rm -rf;
108. cleanup never NSFileManager recursive delete;
109. plan summary member count present;
110. plan summary byte count present;
111. invalid summary fails before workspace creation;
112. main archive source from plan;
113. workspace data path used for extraction;
114. validated-stage data path used for clone;
115. predictable PID staging path removed;
116. manager direct staging mkdir removed;
117. manager direct staging remove removed;
118. extraction zero exit continues;
119. extraction nonzero fails 316;
120. partial content plus nonzero still fails;
121. old File-exists continuation removed;
122. workspace cleanup on empty validation failure;
123. workspace cleanup on extraction failure;
124. workspace cleanup on stage validation failure;
125. workspace cleanup on target revalidation failure;
126. workspace cleanup on clone failure;
127. workspace cleanup on successful clone;
128. pre-mutation cleanup failure preserves primary error;
129. post-clone cleanup failure becomes generic warning;
130. stage validation precedes first process kill;
131. stage validation precedes target validator;
132. stage validation precedes target wipe;
133. stage validation precedes tar-pipe clone;
134. stage validation precedes cp fallback;
135. stage validation precedes target chown;
136. stage failure performs no optional-component mutation;
137. target revalidation code 303 preserved;
138. clone code 317 preserved;
139. tar preference list unchanged;
140. tar xattr/ACL fallback retained;
141. main target wipe semantics unchanged;
142. main target chown unchanged;
143. plan source unchanged;
144. archive validator unchanged;
145. artifact verifier unchanged;
146. Makefile unchanged;
147. App Group behavior unchanged;
148. optional-component behavior unchanged;
149. no main transaction or rollback;
150. TASK-2.9 remains unimplemented.

Add error-userInfo, descriptor cleanup, Unicode, boundary and failure-injection scenarios as needed.

# Part 29 — Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.8-REPORT.md
```

Report must include:

- baseline and exact scope;
- protected SHA-256 before/after;
- exact public API and 14-code enum;
- workspace creation/identity proof;
- fixed parent and unique-template proof;
- empty-directory proof;
- descriptor-relative traversal proof;
- staged path/type/hard-link/mount policy;
- forbidden container metadata proof;
- fixed limits and overflow proof;
- exact regular-byte accounting;
- deterministic digest specification;
- immutable validated-result proof;
- cleanup ownership and idempotence proof;
- accepted archive-summary integration;
- manager ordering proof;
- extraction fail-closed proof;
- all cleanup-path inventory;
- post-plan authority non-regression;
- TASK-2.1 through TASK-2.7 non-regression;
- TASK-2.9/TASK-2.11 boundaries;
- complete production diff;
- static/forbidden counts;
- at least 150 explicit scenarios;
- whitespace/CRLF/NUL/generated-artifact audit;
- build status and remaining runtime risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 30 — Verification

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXMainDataStaging.h PXMainDataStaging.m AppDataBackupManager.m
git diff -- PXMainDataStaging.h PXMainDataStaging.m AppDataBackupManager.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff d9ab9013b5d637ceb71695003bbc7153ac78151c..HEAD --check
git diff --name-status d9ab9013b5d637ceb71695003bbc7153ac78151c..HEAD
```

Stop after TASK-2.8.

Do not implement TASK-2.9 or TASK-2.11.
