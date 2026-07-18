# TASK-3.3 — Add Common Verified Backup Artifact Writer

- Status: READY
- Phase: Phase 3 — Atomic Backup Publication
- Baseline: `dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b`
- Suggested commit: `phase3(task-3.3): add common verified artifact writer`

## Objective

Replace Backup's path-based, post-hoc artifact metadata helpers with one common artifact writer that owns temporary producer output, descriptor-relative verification, stable streaming SHA-256, strict durability, and exact final artifact publication inside the accepted TASK-3.1 partial workspace.

Only artifacts finalized successfully by this writer may enter the manifest `artifacts` array or component manifest mappings.

TASK-3.3 does **not** define the final required/optional artifact policy, does not change Preferences inclusion semantics, does not change the manifest schema, and does not publish the completed Backup directory.

## Accepted foundation

The following are already accepted and must remain intact:

- TASK-3.1 private `.weaponx-backup-partial-XXXXXX` workspace;
- TASK-3.2 persistent per-bundle `.weaponx-backup.lock` serialization;
- three workspace identity validations;
- four lock ownership validations;
- manifest schema version 3;
- current component order and current component-specific failure/warning behavior;
- Restore hardening from Phase 2.

## Authorized production scope

Only these production files may be added or modified:

```text
PXBackupArtifactWriter.h
PXBackupArtifactWriter.m
AppDataBackupManager.m
```

The required report is:

```text
docs/backup-restore-hardening/reports/TASK-3.3-REPORT.md
```

The implementation commit may contain only:

```text
A PXBackupArtifactWriter.h
A PXBackupArtifactWriter.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.3-REPORT.md
```

## Protected production files

Do not modify:

```text
AppDataBackupManager.h
PXBackupBundleLock.h
PXBackupBundleLock.m
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
PXRestoreResult.h
PXRestoreResult.m
PXMainDataRestoreTransaction.h
PXMainDataRestoreTransaction.m
PXAppGroupRestoreTransaction.h
PXAppGroupRestoreTransaction.m
PXOptionalRestoreTransaction.h
PXOptionalRestoreTransaction.m
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
AppEntitlementsReader.h
AppEntitlementsReader.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
CommandRunner.h
CommandRunner.m
Makefile
all UI/controller files
all Keychain helper/bridge/script files
```

Do not modify coordinator task, review, status, roadmap, decisions, or README files.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file.

# Public API

Create `PXBackupArtifactWriter.h`.

The header may import Foundation and forward-declare `PXBackupPublicationWorkspace`.

Export exactly:

```objc
FOUNDATION_EXPORT NSErrorDomain const PXBackupArtifactWriterErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupArtifactWriterErrorFieldPathKey;
FOUNDATION_EXPORT NSString * const PXBackupArtifactTemporaryDirectoryPrefix;
```

The exact temporary prefix is:

```text
.weaponx-artifact-partial-
```

Define exactly sixteen error codes:

```objc
typedef NS_ERROR_ENUM(PXBackupArtifactWriterErrorDomain,
                      PXBackupArtifactWriterErrorCode) {
    PXBackupArtifactWriterErrorInvalidInput = 1,
    PXBackupArtifactWriterErrorWorkspaceValidationFailed = 2,
    PXBackupArtifactWriterErrorWorkspaceInspectionFailed = 3,
    PXBackupArtifactWriterErrorParentCreationFailed = 4,
    PXBackupArtifactWriterErrorParentInvalid = 5,
    PXBackupArtifactWriterErrorDuplicateArtifact = 6,
    PXBackupArtifactWriterErrorTemporaryCreationFailed = 7,
    PXBackupArtifactWriterErrorProducerFailed = 8,
    PXBackupArtifactWriterErrorOutputMissing = 9,
    PXBackupArtifactWriterErrorOutputInvalid = 10,
    PXBackupArtifactWriterErrorReadFailed = 11,
    PXBackupArtifactWriterErrorFilesystemChanged = 12,
    PXBackupArtifactWriterErrorLimitExceeded = 13,
    PXBackupArtifactWriterErrorDurabilityFailed = 14,
    PXBackupArtifactWriterErrorFinalizationFailed = 15,
    PXBackupArtifactWriterErrorCleanupFailed = 16,
};
```

Define the exact producer type:

```objc
typedef BOOL (^PXBackupArtifactProducer)(NSString *temporaryOutputPath);
```

The producer is synchronous. Returning means all producer-owned writes and child processes have completed.

## Immutable verified artifact

Create a subclassing-restricted `NSCopying` class:

```objc
PXVerifiedBackupArtifact
```

Readonly properties:

```objc
relativePath
filePath
size
sha256
manifestRepresentation
```

Exact types:

```objc
@property (nonatomic, copy, readonly) NSString *relativePath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, readonly) unsigned long long size;
@property (nonatomic, copy, readonly) NSString *sha256;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *manifestRepresentation;
```

The manifest representation must contain exactly:

```text
name
path
size
sha256
```

with values:

```text
name   = relativePath
path   = filePath
size   = NSNumber exact unsigned size
sha256 = 64 lowercase hexadecimal SHA-256
```

Requirements:

- immutable copied values;
- `copyWithZone:` returns `self`;
- equality and hash use all four semantic fields;
- no mutable dictionary exposure;
- `init` and `new` unavailable;
- no public initializer;
- no raw descriptor exposure.

## Writer class

Create a subclassing-restricted class:

```objc
PXBackupArtifactWriter
```

Readonly properties:

```objc
workspacePath
artifactCount
```

Factory:

```objc
+ (nullable instancetype)writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
                                      error:(NSError **)error;
```

Artifact method:

```objc
- (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
                                                          producer:(PXBackupArtifactProducer)producer
                                                             error:(NSError **)error;
```

Identity method:

```objc
- (BOOL)validateIdentityWithError:(NSError **)error;
```

`init` and `new` are unavailable.

Do not expose:

- workspace descriptor;
- parent descriptor;
- temporary directory path outside the producer call;
- finalization control;
- rename control;
- cleanup control;
- manifest mutation;
- required/optional policy;
- shell/process API.

# Pure writer boundary

`PXBackupArtifactWriter.m` may import only:

```objc
#import "PXBackupArtifactWriter.h"
#import "PXBackupPublicationWorkspace.h"
```

plus CommonCrypto and POSIX/C headers required by the implementation.

The writer itself must not import or call:

- `AppDataBackupManager`;
- `CommandRunner`;
- UIKit;
- Security/Keychain helpers;
- `NSUserDefaults`;
- `NSTask`;
- `system`, `popen`, or `posix_spawn`;
- tar/archive commands;
- manifest validators;
- artifact-policy code;
- logging functions;
- global mutable state;
- dispatch queues.

Executing the supplied synchronous producer block is allowed. The producer belongs to the manager and may call existing producer mechanisms.

# Fixed limits

Use exact private limits:

```text
maximum artifacts per writer:           4096
maximum relative path UTF-8 bytes:      4096
maximum component UTF-8 bytes:           255
maximum relative path depth:              32
maximum verified artifact size:          64 GiB
stream buffer:                            64 KiB
temporary workspace entries:               1 operational payload
failure cleanup entry limit:                8
```

All arithmetic must be overflow-safe.

# Relative-path contract

`relativePath` must be:

- runtime `NSString`;
- nonempty;
- lossless UTF-8;
- at most 4096 bytes;
- relative, never beginning with `/`;
- not ending with `/`;
- no empty component;
- no `.` or `..` component;
- no NUL, control character, or backslash;
- every component at most 255 UTF-8 bytes;
- depth at most 32;
- byte-for-byte UTF-8 round-trip stable.

Do not trim, lowercase, normalize, percent-decode, tilde-expand, or canonicalize caller text.

Reject any component equal to:

```text
.weaponx-backup.lock
manifest.plist
```

Reject any component beginning with:

```text
.weaponx-backup-partial-
.weaponx-artifact-partial-
```

The writer must reject:

- duplicate exact artifact paths;
- a file path that conflicts with an earlier artifact parent;
- a nested artifact beneath an earlier artifact file;
- a path that aliases another accepted path through normalization tricks.

Writer state preserves accepted artifact order.

# Workspace binding

The factory must:

1. clear `*error`;
2. require exact `PXBackupPublicationWorkspace` runtime class;
3. call `validateIdentityWithError:` on the workspace;
4. require an absolute, lossless UTF-8 workspace path within 4096 bytes;
5. `lstat` the workspace path;
6. reject symlink or non-directory;
7. open with `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`;
8. `fstat` and require directory type, mode `0700`, and `FD_CLOEXEC`;
9. call workspace identity validation again;
10. repeat path/descriptor identity proof;
11. retain the workspace object, descriptor, path, and initial device/inode/type identity.

A path replacement between workspace validation and writer open must fail closed.

The writer does not own or close descriptors inside the TASK-3.1 workspace object. It owns only its independent descriptor.

# Writer identity validation

`validateIdentityWithError:` must:

- clear `*error`;
- require retained workspace object and owned descriptor;
- call the workspace object's identity validation;
- `fstat` the owned workspace descriptor;
- require exact retained device/inode/type identity;
- require directory type and mode `0700`;
- require `FD_CLOEXEC`;
- `lstat` workspace path and reject symlink;
- require path identity equals owned descriptor and retained identity;
- never require the workspace to remain empty after Backup output begins;
- never replace retained state with new observations.

# Parent traversal and creation

For each artifact, traverse the relative parent components descriptor-relatively from the retained workspace descriptor.

For each parent component:

1. inspect with `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
2. if absent, create with `mkdirat` mode `0700`;
3. reject symlink or non-directory;
4. reject setuid/setgid;
5. open with `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`;
6. require namespace/descriptor device-inode-type equality;
7. require same device as the writer workspace;
8. require `FD_CLOEXEC`;
9. if newly created, force and verify exact mode `0700`;
10. retain descriptor and identity through artifact finalization.

Do not use:

- `NSFileManager` recursive directory creation;
- shell `mkdir`;
- path-based parent authority;
- `realpath` traversal of the relative artifact path.

# Temporary producer directory

Create one unique direct child under the retained final parent.

Exact template:

```text
.weaponx-artifact-partial-XXXXXX
```

Requirements:

- use `mkdtemp` exactly once per artifact attempt;
- verify the generated name starts with the exact temporary prefix;
- verify it is one safe component;
- require direct-child relationship to the retained parent;
- `lstat`, `fstatat`, `openat`, and `fstat` exact identity;
- mode exact `0700`;
- same device as final parent and writer workspace;
- `FD_CLOEXEC`;
- initially empty.

The sole producer output path is:

```text
<temporary directory>/payload
```

`payload` must not exist before the producer is invoked.

Call the producer exactly once.

Do not precreate `payload`, because existing tar, copy, helper, and in-app producers may choose their own creation semantics.

# Producer result

If the producer returns `NO`:

- classify as `PXBackupArtifactWriterErrorProducerFailed`;
- do not publish a final artifact;
- perform bounded safe temporary cleanup;
- preserve unexpected or identity-changed evidence rather than deleting it blindly.

If the producer returns `YES`, require exactly one operational entry named:

```text
payload
```

Reject any extra entry, nested temporary control object, symlink, or unexpected name.

Producer success alone is never artifact success.

# Payload verification

Open `payload` descriptor-relatively from the retained temporary directory with:

```text
O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
```

Require:

- namespace and descriptor identify the same object;
- regular file;
- `st_nlink == 1`;
- no setuid/setgid;
- same device as parent/workspace;
- nonnegative size;
- size at most 64 GiB;
- `FD_CLOEXEC`.

Force and verify exact mode:

```text
0600
```

Before streaming, retain:

- device;
- inode;
- file type/mode;
- link count;
- size;
- mtime;
- ctime.

Stream the complete file using the fixed 64 KiB buffer:

- retry `read` only on `EINTR`;
- update CommonCrypto SHA-256 incrementally;
- count bytes overflow-safely;
- require streamed bytes exactly equal retained size;
- do not load the complete file into `NSData`.

After streaming:

- `fstat` again;
- require all retained stability fields unchanged;
- require exact size and link count;
- require 64 lowercase hexadecimal SHA-256;
- strict `fsync` of the file, retrying only `EINTR`;
- unsupported or failed synchronization is `DurabilityFailed`.

Do not accept a zero-length digest, missing digest, partial read, or changed file.

Zero-length regular artifacts are allowed if the producer intentionally created one and all verification succeeds. Artifact policy is deferred to TASK-3.5.

# Final name and publication inside the partial workspace

Before final rename:

1. validate writer/workspace identity again;
2. revalidate retained parent descriptor and namespace;
3. revalidate temporary directory identity;
4. revalidate payload descriptor/namespace identity;
5. require final artifact name absent with `fstatat(..., AT_SYMLINK_NOFOLLOW)` returning `ENOENT`.

Publish only with descriptor-relative rename:

```text
renameat(tempDirectoryDescriptor,
         "payload",
         finalParentDescriptor,
         finalComponent)
```

After rename:

- require the final namespace identifies the exact retained payload inode/type;
- require regular, single-linked, mode `0600`;
- require same device;
- strict-sync the final parent directory;
- require temporary directory empty;
- remove temporary directory with `unlinkat(..., AT_REMOVEDIR)`;
- strict-sync the final parent directory again;
- validate writer/workspace identity again.

This rename publishes one artifact only **inside the private partial Backup workspace**. It is not final Backup publication and does not implement TASK-3.8.

Do not overwrite or replace an existing final artifact.

# Failure cleanup

Cleanup must be:

- descriptor-relative;
- no-follow;
- bounded to eight entries;
- same-filesystem;
- identity-checked;
- idempotent for owned temporary state.

Before final rename, cleanup may remove only:

- exact retained `payload` object if safe;
- exact retained empty temporary directory.

Unexpected entries, identity changes, mount crossing, or unbounded content must be preserved and return `CleanupFailed` when cleanup safety cannot be proven.

If a failure occurs after final rename but before the artifact record is accepted:

- attempt to unlink only the exact retained final artifact identity;
- strict-sync the parent after rollback;
- then remove the exact empty temporary directory;
- preserve evidence and return `CleanupFailed` if exact rollback cannot be proven.

Never recursively delete the TASK-3.1 Backup workspace.

# Verified artifact construction

Construct `PXVerifiedBackupArtifact` only after:

- producer success;
- complete stable read;
- SHA-256 completion;
- file sync;
- descriptor-relative final rename;
- final namespace proof;
- parent sync;
- temporary directory cleanup;
- final writer/workspace identity proof.

Then:

- add the exact relative path to the writer's accepted set;
- increment `artifactCount` once;
- return the immutable record;
- leave the finalized artifact in the partial workspace.

Failure returns `nil` and exact writer-domain error.

# Error contract and privacy

Every public method must:

- clear `*error` on entry;
- return nonnil/YES with nil error on success;
- return nil/NO with nonnil exact writer-domain error on failure.

Error `userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupArtifactWriterErrorFieldPathKey
```

Use stable field paths such as:

```text
$
$.workspace
$.artifact
$.artifact.relativePath
$.artifact.parent
$.artifact.temporary
$.artifact.payload
```

Do not include:

- absolute paths;
- relative artifact names;
- bundle identifiers;
- temporary names;
- inode/device values;
- sizes;
- digests;
- errno text;
- producer stderr/stdout;
- nested NSError objects.

# Manager integration

Import exactly once:

```objc
#import "PXBackupArtifactWriter.h"
```

## Writer creation

Inside `createBackupForBundleID:appName:options:completion:`:

1. Preserve TASK-3.2 lock acquisition and initial validation.
2. Preserve TASK-3.1 workspace factory and initial validation.
3. Create one writer immediately after initial workspace validation and before Backup process kill or artifact creation.
4. Propagate exact nonnil writer factory error to the main queue.
5. Validate writer identity immediately after factory success.
6. Retain the writer with `objc_precise_lifetime` through result construction.
7. Validate writer identity immediately before manifest construction/write.
8. Validate writer identity immediately before `PXBackupResult` construction.

Required manager counts:

```text
writer factory calls:                 1
writer identity validations:          3
lock factory calls:                   1
lock ownership validations:           4
workspace factory calls:              1
workspace identity validations:       3
```

Do not move or remove the accepted lock/workspace validation sites.

# Migrate every Backup artifact producer

All manifest artifacts must be produced through the writer.

There must be exactly eight semantic writer call sites:

1. main `data.tar.gz`;
2. App Group archive loop;
3. profile AppData archive;
4. global Safari archive;
5. Preferences plist;
6. Keychain plist;
7. system-global archive loop;
8. shared-system DB file loop.

For each producer:

- pass only the writer-supplied temporary output path to tar/copy/helper/in-app output APIs;
- never pass a final artifact path directly to the producer;
- use the returned record's `filePath` as the final path after success;
- use the returned record's `relativePath` for manifest component mappings;
- add only the returned verified record to the ordered verified-artifact collection.

## Main data archive

Relative path:

```text
data.tar.gz
```

The producer block invokes existing `_tarCreate:fromDir:toArchive:` with the temporary output path.

If tar fails or writer verification/finalization fails:

- keep existing public Backup error domain;
- keep code `105`;
- retain tar stderr behavior when tar itself failed;
- otherwise use generic description:

```text
Failed to create verified data artifact
```

Main data remains a hard failure. TASK-3.5 will centralize policy later.

## App Group archives

Use existing relative mapping:

```text
groups/<sanitized-group-name>.tar.gz
```

Append `groupManifests` only after a verified artifact record exists.

Preserve the exact existing warning on any producer/writer failure:

```text
Failed to archive group <groupID> (<uuid>)
```

Do not add a second writer-specific warning.

## Profile AppData

Relative path:

```text
profile_appdata.tar.gz
```

Set `profileAppDataArchivePath` only from the verified record's `filePath`.

Preserve exact existing warning:

```text
Failed to archive profile appdata; continuing
```

## Global Safari

Relative path:

```text
global_safari.tar.gz
```

Set `globalSafariArchivePath` only from the verified record.

Preserve exact existing warning:

```text
Failed to archive global Safari library; continuing
```

## Preferences

Relative path remains:

```text
preferences/<bundleID>.plist
```

If the source exists, use the writer producer block to perform the existing copy operation to the temporary output path.

The producer must require a zero exit code. Remove `|| true` from the artifact copy command.

Do not add a new warning on copy/writer failure in TASK-3.3; preserve current externally visible warning behavior.

Keep the current `prefsIncluded` option-based manifest behavior unchanged. TASK-3.4 owns deriving inclusion from the verified output.

## Keychain

Relative path:

```text
keychain.plist
```

Inside the producer block:

- call existing helper output with the temporary output path;
- preserve selected groups;
- preserve helper method selection;
- preserve item-count inspection;
- preserve platform-family in-app fallback;
- preserve warnings and debug behavior;
- return `YES` only when the existing Keychain Backup logic succeeds.

After writer success:

- set `keychainBackupPath` from the verified record's `filePath`;
- retain existing `keychainMethod` behavior.

On failure, preserve existing Keychain warnings and set the path to nil. Do not add a second writer-specific warning.

Do not modify Keychain helper/bridge/script code.

## System-global archives

Use existing relative names:

```text
global_library_<sanitized-subdir>.tar.gz
```

Append `systemGlobalManifests` only after verified writer success.

Preserve exact warning:

```text
Failed to archive system global library <subdir>; continuing
```

## Shared-system DB files

Use existing relative paths under:

```text
shared_db/
```

The producer copy command must target the writer temporary output path, require zero exit code, and remove `|| true`.

Append `sharedSystemDBFiles` only after verified writer success.

Preserve current no-per-file-warning behavior and current aggregate warnings.

# Verified artifact collection

Replace path rescan metadata construction with an ordered collection of `PXVerifiedBackupArtifact` objects.

The order must remain equivalent to the current manifest artifact order:

1. data archive;
2. App Group archives in current resolver order;
3. profile AppData when present;
4. global Safari when present;
5. system-global items in current order;
6. shared DB items in current order;
7. Preferences when verified;
8. Keychain when verified.

Construct the manifest `artifacts` array only by reading each record's immutable `manifestRepresentation`.

Calculate:

```text
artifactCount
totalSize
archiveChecksum
```

only from verified records.

`archiveChecksum` remains the verified data artifact SHA-256.

The total-size addition must be overflow-safe. Given the fixed writer limits, reject impossible overflow rather than wrap.

# Remove legacy artifact helpers

After TASK-3.3, remove production definitions and calls for:

```text
PXFileSHA256
PXHexString
PXArtifactInfo
PXVerifyArtifact
```

The post-hoc loop that appended:

```text
Backup artifact verification: ...
```

must be removed.

Only writer-verified records may enter the manifest, so a later path-based warning verifier is no longer authoritative.

All other existing warning text and append order must remain unchanged.

# Preserve current policy boundaries

TASK-3.3 must not centralize or redesign required/optional policy.

Preserve the current component behavior:

```text
main data              hard failure
App Group              warning and continue
profile AppData        warning and continue
global Safari          warning and continue
Preferences            current behavior
Keychain               current warning behavior
system-global          warning and continue
shared DB              current skip/aggregate warning behavior
```

TASK-3.5 owns the formal required/optional policy.

# Preserve Preferences boundary

Do not change:

```objc
BOOL prefsIncluded = (options & PXBackupOptionIncludePreferences) != 0;
```

Do not derive `preferences.included` from writer output in TASK-3.3.

TASK-3.4 owns that correction.

# Preserve manifest and publication boundaries

Do not change:

- `manifestVersion` value `3`;
- manifest field set;
- current direct manifest write semantics;
- manifest validator;
- final Backup directory naming;
- TASK-3.1 partial-path result behavior;
- discovery behavior;
- final Backup publication.

Do not add:

- manifest v4;
- manifest temporary file protocol;
- final directory rename;
- publication marker;
- centralized partial cleanup;
- stale partial cleanup.

# TASK-3.1 and TASK-3.2 non-regression

The following must be byte-identical:

```text
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
PXBackupBundleLock.h
PXBackupBundleLock.m
```

Preserve manager counts:

```text
lock factory calls:                   1
lock ownership validations:           4
workspace factory calls:              1
workspace identity validations:       3
_backupRoot calls:                    1
```

The writer is created only after accepted lock and workspace ownership exist.

# Broader non-regression

Do not change:

- public Backup selector;
- timestamp format;
- tar preference order;
- source-container resolution;
- process-kill ordering outside producer output migration;
- App Group entitlement/resolver behavior;
- profile/Safari/system/shared selection behavior;
- Keychain selection/fallback behavior;
- existing debug file locations;
- `PXBackupResult` public fields;
- Restore implementation;
- UI/controller behavior;
- Makefile.

# Later-task boundaries

Do not implement:

- TASK-3.4 Preferences inclusion derived from verified output;
- TASK-3.5 formal required/optional artifact policy;
- TASK-3.6 manifest schema v4;
- TASK-3.7 atomic manifest write and validation;
- TASK-3.8 final Backup publication rename;
- TASK-3.9 centralized Backup failure cleanup;
- TASK-3.10 stale partial cleanup or broad discovery hardening;
- Phase 4 Keychain policy changes.

# Static acceptance gates

## Scope

```text
A PXBackupArtifactWriter.h
A PXBackupArtifactWriter.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.3-REPORT.md
all other production diff = 0
```

## Public API

```text
error-domain exports:                   1
field-path exports:                     1
temporary-prefix exports:               1
error codes:                           16
public result classes:                  1
public writer classes:                  1
producer typedefs:                      1
writer factories:                       1
artifact-write methods:                 1
identity-validation methods:            1
public readwrite properties:            0
public descriptor properties:           0
NSCopying implementations:              1
```

## Writer implementation

```text
exact temporary prefix: .weaponx-artifact-partial-
exact template:         .weaponx-artifact-partial-XXXXXX
payload name:           payload
mkdtemp semantic sites: 1
renameat publish sites: 1
final overwrite paths:  0
whole-file NSData reads: 0
NSFileManager recursive creation: 0
shell/process calls in writer:     0
artifact file mode:                0600
parent/temp directory mode:        0700
stream buffer:                     64 KiB
file size maximum:                 64 GiB
artifact count maximum:            4096
```

## Manager integration

```text
writer factory calls:                    1
writer identity validations:             3
writeArtifact semantic call sites:       8
legacy PXFileSHA256 definitions/calls:    0
legacy PXHexString definitions/calls:     0
legacy PXArtifactInfo definitions/calls:  0
legacy PXVerifyArtifact definitions/calls:0
post-hoc verification warning loop:       0
verified record collection:               present
manifest artifact dictionaries from records only: yes
producer direct final artifact outputs:   0
preferences copy `|| true`:               0
shared DB copy `|| true`:                 0
manifestVersion 3 retained:               yes
publication rename/move of Backup root:   0
```

## Non-regression

```text
PXBackupPublicationWorkspace diff: 0
PXBackupBundleLock diff:            0
Restore method diff:                0
listBackupDirectories diff:         0
public selector diff:               0
UI diff:                            0
Makefile diff:                      0
Keychain helper/bridge diff:        0
```

# Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.3-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. legacy helper and post-hoc verification inventory;
4. exact public API and sixteen-code enum;
5. immutable record proof;
6. exact manifest representation proof;
7. workspace double-validation and descriptor binding;
8. relative path validation matrix;
9. duplicate/prefix-conflict matrix;
10. descriptor-relative parent creation;
11. exact temporary directory/payload protocol;
12. producer single-call semantics;
13. payload type/nlink/mode/device proof;
14. streaming SHA-256 and stability proof;
15. exact limits and overflow handling;
16. strict file and directory durability;
17. descriptor-relative final rename;
18. rollback/cleanup before and after rename;
19. writer identity validation;
20. error privacy;
21. manager writer creation and three validations;
22. all eight producer migrations;
23. zero direct-final-output proof;
24. verified artifact ordering;
25. artifactCount/totalSize/archiveChecksum derivation;
26. legacy helper removal;
27. warning behavior inventory;
28. explicit Preferences TASK-3.4 boundary;
29. explicit policy TASK-3.5 boundary;
30. manifest v3 and publication non-regression;
31. TASK-3.1/TASK-3.2 byte identity;
32. Restore/UI/Makefile/Keychain-helper zero diff;
33. full authorized source diff;
34. static/forbidden gate table;
35. at least 180 explicit scenario rows;
36. whitespace, CRLF, and NUL audit;
37. build status and remaining runtime risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

Run and record:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b..HEAD --check
git diff --name-status dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b..HEAD
git status --short --untracked-files=all
```

Stop after TASK-3.3.

Do not implement TASK-3.4 or any later task.
