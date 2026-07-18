# TASK-3.8 — Publish Completed Backup Atomically

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Baseline: `bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a`
- Parent foundation: TASK-3.1 through TASK-3.7 are COMPLETED
- Next task: TASK-3.9 remains LOCKED

## Objective

Replace the temporary TASK-3.1 success path with one atomic whole-directory publication from the hidden partial workspace into a stable visible Backup directory.

A successful Backup must transition from:

```text
<backup root>/<bundleID>/.weaponx-backup-partial-XXXXXX
```

to:

```text
<backup root>/<bundleID>/<UTC timestamp>-<lowercase backup UUID>
```

using one same-parent descriptor-relative rename.

The published directory must contain the exact TASK-3.7 accepted manifest and all TASK-3.3 accepted artifacts. `PXBackupResult` must expose only the final published paths.

## Authorized production scope

Create:

```text
PXBackupDirectoryPublisher.h
PXBackupDirectoryPublisher.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.8-REPORT.md
```

The implementation commit may contain only these four files.

## Protected production files

Do not modify:

```text
AppDataBackupManager.h
PXBackupPublicationWorkspace.h/.m
PXBackupBundleLock.h/.m
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupManifestV4.h/.m
PXBackupManifestValidator.h/.m
PXBackupManifestWriter.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXRestorePlan.h/.m
all Restore transaction/staging/resolver files
CommandRunner.h/.m
Makefile
UI/controller files
Keychain helper/bridge/script files
```

Do not modify coordinator task/review/status/roadmap/decision/README files.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -6 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file.

# Public API

Create `PXBackupDirectoryPublisher.h`.

Export exactly:

```objc
PXBackupDirectoryPublisherErrorDomain
PXBackupDirectoryPublisherErrorFieldPathKey
```

Define exactly eighteen error codes without gaps or aliases:

```objc
PXBackupDirectoryPublisherErrorInvalidInput = 1
PXBackupDirectoryPublisherErrorLockValidationFailed = 2
PXBackupDirectoryPublisherErrorWorkspaceValidationFailed = 3
PXBackupDirectoryPublisherErrorParentInspectionFailed = 4
PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed = 5
PXBackupDirectoryPublisherErrorInvalidFinalName = 6
PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists = 7
PXBackupDirectoryPublisherErrorArtifactWriterValidationFailed = 8
PXBackupDirectoryPublisherErrorManifestWriterValidationFailed = 9
PXBackupDirectoryPublisherErrorManifestNotReady = 10
PXBackupDirectoryPublisherErrorFilesystemChanged = 11
PXBackupDirectoryPublisherErrorDurabilityFailed = 12
PXBackupDirectoryPublisherErrorPublicationFailed = 13
PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed = 14
PXBackupDirectoryPublisherErrorManifestReadBackFailed = 15
PXBackupDirectoryPublisherErrorManifestValidationFailed = 16
PXBackupDirectoryPublisherErrorSnapshotMismatch = 17
PXBackupDirectoryPublisherErrorRollbackFailed = 18
```

Create one subclassing-restricted class:

```objc
PXBackupDirectoryPublisher
```

Readonly properties:

```objc
workspacePath
publishedDirectoryPath
publishedDirectoryName
publishedManifestPath
backupIdentifier
timestamp
published
```

Factory:

```objc
+publisherForWorkspace:
              bundleLock:
        backupIdentifier:
                 timestamp:
                     error:
```

Publication method:

```objc
-publishWithArtifactWriter:
               manifestWriter:
                        error:
```

Identity method:

```objc
-validateIdentityWithError:
```

`init` and `new` are unavailable.

Do not expose descriptors, raw inode/device values, rename control, rollback control, cleanup control, publication bypass or discovery APIs.

# Pure publisher boundary

`PXBackupDirectoryPublisher.m` may import only:

```objc
#import "PXBackupDirectoryPublisher.h"
#import "PXBackupPublicationWorkspace.h"
#import "PXBackupBundleLock.h"
#import "PXBackupArtifactWriter.h"
#import "PXBackupManifestWriter.h"
#import "PXBackupManifestValidator.h"
```

and Foundation/CommonCrypto/POSIX/C headers required by the implementation.

Do not import or use:

```text
AppDataBackupManager
CommandRunner
NSTask
system
popen
posix_spawn
UIKit
Security/Keychain
NSUserDefaults
dispatch
NSFileManager path mutation
shell commands
raw path or manifest logging
global mutable state
```

# Final name contract

The final directory name is exactly:

```text
<timestamp>-<backupIdentifier>
```

Example:

```text
20260715-074500-12345678-1234-1234-1234-123456789abc
```

## Timestamp

Require exact `yyyyMMdd-HHmmss` UTC representation:

- runtime `NSString`;
- exactly 15 ASCII bytes;
- digits at every position except index 8;
- `-` at index 8;
- strict non-lenient UTC `NSDateFormatter` parse;
- formatter round-trip output equals input;
- no trim, normalization or repair.

The existing manager `_timestampString` remains the source. Do not change its format, locale or UTC behavior.

## Backup identifier

Require exact canonical lowercase UUID:

```text
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

- exactly 36 ASCII bytes;
- lowercase hexadecimal;
- hyphens at 8, 13, 18 and 23;
- exact `NSUUID` lowercase round trip;
- no trim, lowercase conversion or repair.

## Final component

The derived final name must:

- be one safe path component;
- contain no slash, backslash, NUL or control byte;
- not equal `.` or `..`;
- be at most 255 UTF-8 bytes;
- not start with `.weaponx-backup-partial-`;
- not start with `.weaponx-artifact-partial-`;
- not start with `.weaponx-manifest-partial-`;
- not equal `.weaponx-backup.lock`;
- not equal `manifest.plist`.

The final path must remain within the 4096-byte path bound.

The timestamp prefix preserves existing newest-first lexical discovery sorting. The UUID suffix prevents same-second collisions.

# Factory authority

The factory must clear `error` and require exact runtime instances of:

```text
PXBackupPublicationWorkspace
PXBackupBundleLock
```

Require:

- workspace and lock bundle identifiers are exactly equal;
- workspace and lock canonical bundle-directory paths are exactly equal;
- workspace name starts with `.weaponx-backup-partial-`;
- workspace path is exactly the canonical bundle directory plus workspace name;
- lock ownership validation succeeds;
- workspace identity validation succeeds.

## Parent directory

Using `bundleLock.canonicalBundleDirectoryPath`:

1. require lossless absolute UTF-8 within 4096 bytes;
2. `lstat` and reject symlink;
3. require directory and no setid bits;
4. open `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`;
5. `fstat` and require path/fd device-inode-type equality;
6. verify `FD_CLOEXEC`;
7. retain the parent descriptor and initial identity.

## Workspace directory

Using retained parent descriptor and `workspace.workspaceName`:

1. inspect with `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
2. reject symlink and wrong type;
3. require mode `0700` and no setid bits;
4. open with `openat(..., O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)`;
5. require namespace/fd device-inode-type equality;
6. require same filesystem as parent;
7. require path observation, parent-relative namespace and workspace descriptor all identify the same directory;
8. verify `FD_CLOEXEC`;
9. validate TASK-3.1 workspace again;
10. retain the workspace descriptor and initial identity.

## Final absence

Before returning a publisher:

- inspect final name using retained parent descriptor and `AT_SYMLINK_NOFOLLOW`;
- require exact absence with `ENOENT`;
- any existing file, directory or symlink is `FinalDirectoryAlreadyExists`;
- no overwrite or alternate name fallback.

The factory does not rename, publish, create markers or modify workspace contents.

# Publisher lifecycle

Retain:

- exact workspace object;
- exact bundle-lock object;
- parent descriptor and identity;
- workspace descriptor and identity;
- original partial workspace name/path;
- final directory name/path;
- final manifest path;
- backup ID and timestamp;
- publication state;
- final directory descriptor after success;
- final manifest descriptor after success;
- final directory/manifest identities;
- accepted manifest size, digest and representation after success.

`dealloc` closes owned descriptors only. It does not rename or delete anything.

Publication may be attempted exactly once. A second call fails closed.

# Pre-publication requirements

`publishWithArtifactWriter:manifestWriter:error:` must clear `error` and require exact runtime instances of:

```text
PXBackupArtifactWriter
PXBackupManifestWriter
```

Before any rename, require all of the following:

1. publisher is still unpublished and unused;
2. bundle lock ownership validates;
3. TASK-3.1 workspace validates;
4. publisher parent/workspace retained identities validate;
5. artifact writer validates;
6. manifest writer validates;
7. artifact writer workspace path equals publisher workspace path;
8. manifest writer workspace path equals publisher workspace path;
9. manifest writer reports `manifestWritten == YES`;
10. manifest writer manifest path equals workspace path plus `manifest.plist`;
11. manifest size is from 1 through 128 MiB;
12. manifest SHA-256 is exactly 64 lowercase hexadecimal characters;
13. manifest representation is an immutable dictionary;
14. manifest representation passes `PXBackupManifestValidator`;
15. manifest `manifestVersion == 4`;
16. manifest `backupID` equals publisher backup ID;
17. manifest `timestamp` equals publisher timestamp;
18. manifest publication protocol equals `atomic-directory-v1`;
19. manifest content state equals `complete`;
20. manifest artifact count equals `artifactWriter.artifactCount`;
21. final directory name remains absent;
22. no direct `.weaponx-manifest-partial-*` child exists;
23. strict-sync the workspace descriptor before directory publication.

Do not reconstruct or patch the manifest.

Do not rescan artifact contents path-by-path; TASK-3.3 artifact-writer validation remains artifact authority.

# Atomic whole-directory publication

Immediately before rename:

- validate lock ownership again;
- revalidate parent identity;
- revalidate workspace identity through parent namespace and retained descriptor;
- require final name absent again;
- require original partial name still identifies the exact retained workspace directory.

Use one file-local rename helper containing the only production `renameat` call site.

Forward publication arguments:

```text
parentFD
workspaceName
parentFD
publishedDirectoryName
```

The forward rename must be same-parent and same-filesystem.

No manager rename, `NSFileManager` move, shell `mv`, copy/delete publication or alternate final name is allowed.

# Post-rename proof

After forward rename succeeds and before accepting publication:

1. require original partial name absent;
2. require final namespace identifies the exact retained workspace inode;
3. strict-sync retained workspace directory;
4. strict-sync retained parent directory;
5. independently open final directory with `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`;
6. prove independent final descriptor equals retained workspace descriptor identity;
7. require final directory mode `0700`, same filesystem and CLOEXEC;
8. retain final directory descriptor;
9. open final `manifest.plist` descriptor-relatively using `O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC`;
10. require regular file, mode `0600`, link count one and same filesystem;
11. require exact manifest-writer retained size;
12. read using a 64-KiB buffer;
13. reject early EOF and extra bytes;
14. compute lowercase SHA-256;
15. require digest equals manifest-writer digest;
16. prove before/after file stat stability;
17. parse immutable property list dictionary;
18. pass `PXBackupManifestValidator`;
19. deep-equal manifest-writer retained representation;
20. require exact backup ID, timestamp, artifact count, total size and archive checksum;
21. require final manifest namespace/fd identity;
22. retain final manifest descriptor and identity;
23. revalidate final parent/directory/manifest bindings.

Only after all proofs set:

```text
published = YES
```

The accepted paths are:

```text
publishedDirectoryPath
publishedManifestPath
```

# Reverse rename on post-publication failure

Any failure after the forward rename and before `published = YES` must attempt an exact reverse rename:

```text
parentFD
publishedDirectoryName
parentFD
original partial workspace name
```

Before reverse rename require:

- final name identifies the exact retained workspace inode;
- original partial name is absent;
- retained parent identity remains valid.

After reverse rename require:

- final name absent;
- original partial name identifies the exact retained workspace inode;
- strict parent sync;
- workspace remains mode `0700` and same filesystem.

When reverse rename succeeds:

- return the original publication error;
- keep `published == NO`;
- the directory is hidden again by the existing partial prefix;
- do not recursively delete the workspace.

If reverse rename or its proof fails:

- return `PXBackupDirectoryPublisherErrorRollbackFailed`;
- preserve all evidence;
- do not delete manifest or artifacts;
- TASK-3.9/TASK-3.10 own later cleanup/recovery.

There is no second forward publication attempt.

# Identity validation

`validateIdentityWithError:` supports both states.

## Unpublished state

Require:

- bundle lock ownership valid;
- parent identity valid;
- original workspace path/parent namespace/fd identity valid;
- workspace mode `0700` and same filesystem;
- final name absent;
- publication state properties internally consistent.

## Published state

Do not call TASK-3.1 path-based workspace validation after rename, because the original partial path is intentionally absent.

Require instead:

- bundle lock ownership valid;
- parent identity valid;
- original partial name absent;
- final namespace/fd identity equals retained workspace inode;
- final directory mode `0700`, same filesystem and CLOEXEC;
- final manifest namespace/fd identity valid;
- exact retained size and digest;
- stable read-back;
- immutable parse;
- validator success;
- retained representation equality;
- exact backup ID/timestamp/aggregate fields;
- final paths equal the canonical parent plus final name.

Never adopt replacement identities.

# Error privacy

Public errors may contain only:

```text
NSLocalizedDescriptionKey
PXBackupDirectoryPublisherErrorFieldPathKey
```

Do not include:

- backup root path;
- bundle directory path;
- workspace path/name;
- final path/name;
- bundle identifier;
- backup ID;
- timestamp;
- inode/device values;
- manifest content/digest/size;
- errno text;
- nested errors;
- stdout/stderr.

Descriptions must be generic and bounded.

# Manager integration

Import exactly once:

```objc
#import "PXBackupDirectoryPublisher.h"
```

## Construction

Keep the existing timestamp generation and backup-ID generation exactly once.

After backup ID and canonical policy construction, and before output directories, debug files, process kill or artifact producers:

1. create one publisher from:
   - `publicationWorkspace`;
   - `bundleLock`;
   - `backupIdentifier`;
   - `timestamp`;
2. keep it with `objc_precise_lifetime`;
3. propagate exact factory error on the main queue;
4. validate publisher immediately after factory;
5. do not move existing lock/workspace/artifact/manifest writer gates.

## Publication ordering

After TASK-3.7 manifest write and after the existing final validations of:

```text
manifest writer
workspace
bundle lock
artifact writer
```

perform:

1. pre-publication publisher validation;
2. one `publishWithArtifactWriter:manifestWriter:error:` call;
3. propagate exact publisher error as nil result on main queue;
4. post-publication publisher validation;
5. construct `PXBackupResult`.

Do not call path-based workspace, artifact-writer or manifest-writer validation after the directory rename. Publisher post-publication validation is the final authority.

## Result paths

Replace temporary TASK-3.1 result paths with:

```objc
out.backupDirectory = directoryPublisher.publishedDirectoryPath;
out.manifestPath = directoryPublisher.publishedManifestPath;
```

The successful completion must never return a `.weaponx-backup-partial-*` path.

Immediate RRS/Restore callers continue using the explicit result path, now the final published path.

## Failure contract

Any publisher factory, validation, forward publication, post-publication proof or rollback failure is a hard Backup failure:

```text
result nil
exact publisher NSError
main queue
exactly once
```

Do not append a warning and continue.

# Required manager counts

```text
directory-publisher factory calls:       1
directory-publisher validations:         3
directory-publisher publish calls:       1
bundle-lock factory calls:                1
bundle-lock validations:                  4
workspace factory calls:                  1
workspace validations:                    3
artifact-writer factory calls:            1
artifact-writer validations:              3
manifest-writer factory calls:            1
manifest-writer validations:              3
manifest-writer write calls:              1
policy constructions:                     8
artifact writer calls:                    8
failure-policy calls:                     8
policy audit calls:                       1
v4 builder calls:                         1
manager v4 validator calls:               1
```

Publisher source:

```text
file-local renameat call sites:           1
forward publication helper calls:         1
reverse rollback helper calls:            1
manager directory rename/move calls:      0
successful partial result assignments:    0
successful final result assignments:      2
```

# Discovery and sorting compatibility

Do not modify `listBackupDirectoriesForBundleID:` in TASK-3.8.

Existing behavior already:

- skips `.weaponx-backup-partial-*` entries;
- includes nonpartial directories containing `manifest.plist`;
- sorts by final directory name newest-first.

The `<timestamp>-<UUID>` final name preserves timestamp-first lexical ordering.

Do not add publication markers, indexes, sidecar files or discovery scans.

Discovery validation and stale/indeterminate cleanup remain TASK-3.10.

# Non-regression

Byte-identical:

```text
PXBackupPublicationWorkspace.h/.m
PXBackupBundleLock.h/.m
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupManifestV4.h/.m
PXBackupManifestValidator.h/.m
PXBackupManifestWriter.h/.m
```

Preserve:

- public Backup selector;
- UTC timestamp format;
- backup UUID generation;
- per-bundle nonblocking lock;
- hidden workspace creation;
- all artifact writer guarantees;
- required/optional policy;
- manifest-v4 schema and relative references;
- malformed-v4 exception safety;
- TASK-3.7 binary serialization and manifest durability;
- artifact/component order;
- Preferences semantics;
- Keychain behavior;
- warnings and their order;
- Restore;
- UI;
- Makefile;
- legacy discovery compatibility.

Do not implement:

- TASK-3.9 centralized cleanup for all earlier manager failure paths;
- TASK-3.10 stale partial/indeterminate cleanup or broad discovery hardening;
- publication marker protocol;
- Backup index/database;
- Phase 4 or later work.

# Static gates

Required implementation scope:

```text
A PXBackupDirectoryPublisher.h
A PXBackupDirectoryPublisher.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.8-REPORT.md
```

All other production diff must be zero.

Public API gates:

```text
exports:                         2
error codes:                    18
publisher classes:               1
public factories:                1
public publish methods:          1
public validation methods:       1
readonly properties:             7
public readwrite properties:     0
public descriptor properties:    0
```

Publisher gates:

```text
final-name format:                    <timestamp>-<backupID>
forward same-parent publication:      1
reverse same-parent rollback:         1
renameat implementation sites:        1
NSFileManager move/copy/delete:        0
shell/process calls:                   0
publication markers:                  0
recursive cleanup:                    0
final directory mode:                 0700
final manifest mode:                  0600
manifest read buffer:                 64 KiB
manifest maximum size:                128 MiB
```

Manager gates:

```text
publisher factory:                    1
publisher validations:                3
publisher publish calls:              1
result partial workspace paths:       0
result final directory path:          1
result final manifest path:           1
manager rename/move:                  0
existing lock/workspace/writer counts: retained
discovery method diff:                0
```

# Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.8-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before and after;
3. TASK-3.1 temporary-result inventory;
4. exact API and eighteen errors;
5. UTC timestamp validation;
6. canonical UUID validation;
7. final-name and sorting proof;
8. lock/workspace/parent binding;
9. final-name collision policy;
10. lifecycle and descriptor ownership;
11. artifact/manifest readiness proof;
12. pre-publication validation order;
13. strict pre-rename sync;
14. one same-parent forward rename;
15. parent/final directory durability;
16. independent final-directory open;
17. final manifest read-back/digest/validator/equality;
18. state acceptance ordering;
19. unpublished and published identity validation;
20. reverse-rename rollback;
21. rollback-failure evidence preservation;
22. error privacy;
23. manager construction and publication ordering;
24. final result path proof;
25. immediate RRS compatibility;
26. discovery/sorting compatibility with zero discovery diff;
27. TASK-3.1 through TASK-3.7 non-regression;
28. TASK-3.9/TASK-3.10 boundaries;
29. full authorized source diff;
30. static gate table;
31. at least 240 explicit scenario rows;
32. whitespace/CRLF/NUL audit;
33. build status and remaining runtime risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a..HEAD --check
git diff --name-status bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase3(task-3.8): publish completed backup atomically
```

Stop after TASK-3.8.

Do not implement TASK-3.9, TASK-3.10 or any later task.
