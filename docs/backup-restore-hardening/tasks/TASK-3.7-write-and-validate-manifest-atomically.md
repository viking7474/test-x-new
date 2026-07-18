# TASK-3.7 — Write and Validate Manifest Atomically

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Baseline: `3a7d3f8fe8a98747fe6c823167250e43b8159e9f`
- Parent acceptance: TASK-3.6 and TASK-3.6A are COMPLETED
- Next task: TASK-3.8 remains LOCKED

## Objective

Replace the current best-effort path-based manifest write with one descriptor-bound, strictly durable and independently validated manifest publication protocol inside the private TASK-3.1 workspace.

A successful TASK-3.7 Backup must have exactly one accepted `manifest.plist` that:

1. was serialized from the accepted immutable `PXBackupManifestV4` snapshot;
2. was written to a private same-directory temporary file;
3. was fully written and strictly synchronized;
4. was parsed, structurally validated and exact-equality checked before publication;
5. was atomically renamed to `manifest.plist`;
6. was reopened no-follow, identity-proved, reread, revalidated and exact-equality checked after publication;
7. remains bound to a retained descriptor until Backup result construction.

TASK-3.7 publishes only the manifest file **inside the still-private partial workspace**. It does not rename the Backup workspace into its final timestamp-visible directory. Whole-directory publication remains TASK-3.8.

## Authorized scope

Create:

```text
PXBackupManifestWriter.h
PXBackupManifestWriter.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.7-REPORT.md
```

The implementation commit may contain only these four files.

## Protected files

Do not modify:

```text
AppDataBackupManager.h
PXBackupManifestV4.h/.m
PXBackupManifestValidator.h/.m
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupBundleLock.h/.m
PXBackupPublicationWorkspace.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXRestorePlan.h/.m
all Restore transaction/staging/resolver files
CommandRunner.h/.m
Makefile
UI/controller files
Backup discovery implementation
Keychain helper/bridge/script files
coordinator task/review/status/roadmap/decision/README files
```

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

Create `PXBackupManifestWriter.h`.

Export exactly:

```objc
PXBackupManifestWriterErrorDomain
PXBackupManifestWriterErrorFieldPathKey
PXBackupManifestFinalFileName
PXBackupManifestTemporaryFilePrefix
```

Exact values:

```text
final file name: manifest.plist
temporary prefix: .weaponx-manifest-partial-
```

Define exactly sixteen error codes without gaps or aliases:

```objc
PXBackupManifestWriterErrorInvalidInput = 1
PXBackupManifestWriterErrorWorkspaceValidationFailed = 2
PXBackupManifestWriterErrorWorkspaceInspectionFailed = 3
PXBackupManifestWriterErrorManifestAlreadyWritten = 4
PXBackupManifestWriterErrorFinalManifestAlreadyExists = 5
PXBackupManifestWriterErrorSerializationFailed = 6
PXBackupManifestWriterErrorLimitExceeded = 7
PXBackupManifestWriterErrorTemporaryCreationFailed = 8
PXBackupManifestWriterErrorWriteFailed = 9
PXBackupManifestWriterErrorDurabilityFailed = 10
PXBackupManifestWriterErrorReadBackFailed = 11
PXBackupManifestWriterErrorValidationFailed = 12
PXBackupManifestWriterErrorSnapshotMismatch = 13
PXBackupManifestWriterErrorFilesystemChanged = 14
PXBackupManifestWriterErrorFinalizationFailed = 15
PXBackupManifestWriterErrorCleanupFailed = 16
```

Create one subclassing-restricted class:

```objc
PXBackupManifestWriter
```

Readonly properties:

```objc
@property (nonatomic, copy, readonly) NSString *workspacePath;
@property (nonatomic, copy, readonly) NSString *manifestPath;
@property (nonatomic, readonly, getter=isManifestWritten) BOOL manifestWritten;
@property (nonatomic, readonly) unsigned long long manifestSize;
@property (nonatomic, copy, readonly, nullable) NSString *manifestSHA256;
@property (nonatomic, copy, readonly, nullable)
    NSDictionary<NSString *, id> *manifestRepresentation;
```

Exact factory:

```objc
+ (nullable instancetype)
    writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
                  error:(NSError * _Nullable * _Nullable)error;
```

Exact write method:

```objc
- (BOOL)writeManifestSnapshot:(PXBackupManifestV4 *)manifestSnapshot
                        error:(NSError * _Nullable * _Nullable)error;
```

Exact validation method:

```objc
- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;
```

`init` and `new` unavailable.

Do not expose:

- descriptors;
- raw temporary names;
- rename control;
- cleanup control;
- alternate final names;
- alternate plist formats;
- overwrite control;
- durability bypass;
- validator bypass;
- final Backup publication.

# Pure writer boundary

`PXBackupManifestWriter.m` may import only:

```objc
#import "PXBackupManifestWriter.h"
#import "PXBackupPublicationWorkspace.h"
#import "PXBackupManifestV4.h"
#import "PXBackupManifestValidator.h"
```

plus Foundation, CommonCrypto and POSIX/C headers required by the implementation.

It must not import or call:

- `AppDataBackupManager`;
- `CommandRunner`;
- UIKit;
- Security or Keychain helper code;
- NSUserDefaults;
- NSTask;
- `system`, `popen`, `posix_spawn` or shell commands;
- tar/archive producers;
- dispatch;
- logging of raw paths or manifest contents;
- global mutable state.

# Fixed limits

Use exact fixed limits:

```text
maximum serialized manifest size: 128 MiB
stream/read-back buffer:           64 KiB
temporary-name random bytes:       16
temporary-name creation attempts:  16
maximum owned temporary entries:    1
maximum cleanup entries:             2
```

All arithmetic must be overflow-safe.

Zero-byte manifest data is invalid.

# Workspace binding

The factory must:

1. clear `*error` when nonnull;
2. require exact runtime `PXBackupPublicationWorkspace`;
3. call `validateIdentityWithError:` on the workspace;
4. inspect `workspace.workspacePath` without following a final symlink;
5. open the workspace using `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`;
6. require a real directory with exact mode `0700`;
7. verify `FD_CLOEXEC`;
8. call workspace identity validation again;
9. require path namespace and writer descriptor to bind the same device/inode/type;
10. retain the workspace object, owned workspace descriptor and initial identity;
11. require `manifest.plist` to be absent via `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
12. require no direct child whose name starts with `.weaponx-manifest-partial-`;
13. return a valid writer with `manifestWritten == NO`.

The factory must not create a manifest or temporary file.

The writer does not own or close descriptors retained internally by `PXBackupPublicationWorkspace`.

# Temporary filename protocol

For each write attempt, generate a direct-child name:

```text
.weaponx-manifest-partial-<32 lowercase hexadecimal characters>
```

The suffix comes from exactly 16 random bytes generated with a system random primitive such as `arc4random_buf`.

Create descriptor-relatively with:

```text
openat(
  workspaceDescriptor,
  temporaryName,
  O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
  0600
)
```

Rules:

- retry only when `openat` fails with `EEXIST`;
- maximum 16 attempts;
- no timestamp/PID-only name;
- no absolute path creation authority;
- no `mktemp`;
- no predictable counter;
- exact regular file;
- exact mode `0600`;
- `st_nlink == 1`;
- same filesystem as workspace;
- namespace stat equals descriptor stat;
- `FD_CLOEXEC` required;
- file initially size zero.

Only one owned temporary manifest file may exist at a time.

# Serialization

`writeManifestSnapshot:error:` must:

1. clear `*error`;
2. require exact runtime `PXBackupManifestV4`;
3. reject a second write attempt with `ManifestAlreadyWritten`;
4. validate writer/workspace identity before serialization;
5. require final `manifest.plist` still absent;
6. serialize only `manifestSnapshot.manifestRepresentation`;
7. use exact binary property-list format:

```objc
NSPropertyListBinaryFormat_v1_0
```

8. reject serialization exceptions or errors;
9. require serialized bytes from 1 through 128 MiB;
10. never mutate or patch the representation;
11. never serialize `PXBackupManifestV4` object internals outside its representation.

The serialized byte buffer may exist as one bounded `NSData` because the manifest has a hard 128-MiB maximum. Artifact files remain streaming-only under TASK-3.3.

# Full write

Write the serialized data to the temporary descriptor using bounded full-write logic:

- retry `write` only on `EINTR`;
- reject zero-progress write;
- require exact byte count;
- reject arithmetic overflow;
- do not call global `sync`;
- do not fall back to shell tools.

After writing:

- `fstat` temporary descriptor;
- require retained device/inode/type/nlink/mode;
- require exact serialized size;
- require namespace/descriptor identity;
- require same filesystem;
- require unchanged workspace identity.

# Strict durability

Strict synchronization means success only when the syscall returns zero.

Retry only `EINTR`.

Treat these as failure, not success:

```text
EINVAL
ENOTSUP
EOPNOTSUPP
ENOSYS
```

Required pre-publication durability:

1. strict `fsync` temporary manifest descriptor;
2. strict workspace-directory `fsync` after temporary creation/write state is established if required by the implementation protocol;
3. no unsupported-as-success branch.

Do not use `fcntl(F_FULLFSYNC)` as a replacement for required `fsync`. It may be an additional best-effort step only if ordinary `fsync` still succeeds, but the preferred implementation is exact strict `fsync` only.

# Pre-rename read-back

Before publishing the final name:

1. seek temporary descriptor to offset zero;
2. read exactly the retained size with a 64-KiB buffer or bounded exact buffer logic;
3. retry `read` only on `EINTR`;
4. reject early EOF or extra bytes;
5. compute lowercase SHA-256 over exact serialized bytes;
6. `fstat` after read;
7. require stable device/inode/type/mode/nlink/size/mtime/ctime;
8. parse the bytes using `NSPropertyListSerialization`;
9. require one immutable `NSDictionary` root;
10. call `PXBackupManifestValidator validateManifestObject:error:` exactly once for this pre-rename read-back;
11. require exact deep equality with `manifestSnapshot.manifestRepresentation`;
12. require the parsed `backupID` exact-equal `manifestSnapshot.backupIdentifier`;
13. require the parsed `artifactCount`, `totalSize` and `archiveChecksum` exact-match the snapshot properties.

Any failure occurs before final rename and must remove only the exact retained temporary file when safe.

# Atomic finalization

Immediately before rename:

- validate workspace object and writer descriptor identity;
- revalidate temporary namespace/descriptor identity;
- require final `manifest.plist` absent;
- require no identity or metadata change.

Publish with exactly one:

```text
renameat(
  workspaceDescriptor,
  temporaryName,
  workspaceDescriptor,
  "manifest.plist"
)
```

No overwrite is permitted.

After rename:

1. prove `manifest.plist` namespace is the exact retained temporary inode;
2. require regular file, `st_nlink == 1`, mode `0600` and same filesystem;
3. strict `fsync` the manifest file descriptor;
4. strict `fsync` the workspace directory;
5. open `manifest.plist` independently with `O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC`;
6. prove independent descriptor and namespace bind the same retained inode;
7. verify `FD_CLOEXEC`;
8. close the old temporary descriptor only after the final descriptor is retained successfully.

The final manifest is atomically visible under its final name only after a complete validated temporary file exists.

# Post-rename read-back

Using the retained final descriptor:

1. read the entire bounded manifest again;
2. recompute exact lowercase SHA-256;
3. require digest equals the pre-rename digest;
4. require before/after stat stability;
5. parse as a property-list dictionary;
6. call `PXBackupManifestValidator validateManifestObject:error:` exactly once for the post-rename read-back;
7. require exact deep equality with the immutable v4 snapshot;
8. require exact snapshot aggregate properties;
9. revalidate workspace and final namespace identity.

Only after all post-rename checks pass may the writer set:

```text
manifestWritten = YES
manifestSize = exact serialized byte count
manifestSHA256 = exact lowercase digest
manifestRepresentation = exact immutable v4 representation
manifestPath = workspacePath/manifest.plist
```

State mutation occurs exactly once and only after complete acceptance.

# Identity validation after success

`validateIdentityWithError:` must clear error and verify:

- internal manifest-written state is coherent;
- retained workspace object remains valid;
- workspace descriptor identity unchanged;
- final manifest descriptor identity unchanged;
- final `manifest.plist` path is not a symlink;
- namespace and descriptor match exact retained device/inode/type;
- regular file, mode `0600`, `st_nlink == 1`;
- exact retained size;
- stable mtime and ctime;
- same filesystem as workspace;
- `FD_CLOEXEC` remains set;
- no owned temporary manifest name remains;
- bounded reread SHA-256 equals retained digest;
- parsed dictionary passes `PXBackupManifestValidator`;
- parsed dictionary exact-equals retained manifest representation.

Before a successful write, validation may return YES only when:

- the workspace is still valid;
- `manifest.plist` remains absent;
- no temporary manifest namespace entry exists;
- internal state remains unwritten.

Validation must not reopen a replaced file and adopt its identity.

# Failure cleanup

Cleanup must be descriptor-relative, no-follow, bounded and identity checked.

## Before rename

Remove only:

- the exact retained temporary regular file;

then strictly sync the workspace directory.

If the temporary name points to a different inode/type/link state, preserve evidence and return `CleanupFailed`.

## After rename

If failure occurs after final rename but before writer acceptance:

- remove only `manifest.plist` if it is still the exact retained manifest inode;
- strictly sync workspace directory;
- remove no unrelated entry;
- preserve evidence if identity cannot be proved.

No recursive workspace cleanup is allowed.

TASK-3.9 remains responsible for centralized cleanup of the entire failed Backup workspace.

# Error privacy

Every public method clears `*error` at entry.

Error `userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupManifestWriterErrorFieldPathKey
```

Do not expose:

- workspace path;
- manifest path;
- temporary filename;
- bundle ID;
- backup ID;
- artifact names;
- manifest contents;
- digest;
- size;
- inode/device;
- errno text;
- nested error;
- stdout/stderr.

Use generic descriptions.

# Manager integration

Import exactly once:

```objc
#import "PXBackupManifestWriter.h"
```

## Factory placement

Create the manifest writer exactly once:

- after TASK-3.3 artifact writer factory and initial artifact-writer validation;
- before TASK-3.5 policy construction;
- before output directories;
- before debug files;
- before process termination;
- before artifact producers.

Immediately validate the manifest writer once after factory success.

Propagate exact factory/validation error on the main queue with nil result.

Retain the writer through result construction using `objc_precise_lifetime` or equivalent.

## Pre-write ordering

Keep the accepted TASK-3.6 manager validation of `manifestSnapshot.manifestRepresentation` exactly once before writer invocation.

Before writing the manifest, retain existing gates and order:

```text
TASK-3.5 artifact policy audit
TASK-3.6 v4 builder
TASK-3.6 manager validator call
pre-manifest artifact-writer validation
pre-manifest workspace validation
pre-manifest bundle-lock validation
manifest-writer identity validation
```

Then call:

```objc
[manifestWriter writeManifestSnapshot:manifestSnapshot error:&error]
```

exactly once.

Manifest write failure becomes a hard Backup failure:

```text
result: nil
error: exact PXBackupManifestWriter error
completion queue: main
completion count: exactly once
```

Do not append a warning and continue.

Remove exact legacy behavior:

```text
[manifest writeToFile:manifestPath atomically:YES]
Failed to write manifest
shell chmod 600 for manifest.plist
```

No direct manager path write to `manifest.plist` remains.

## Post-write ordering

After successful writer publication:

- validate manifest writer once more before result construction;
- retain existing final workspace validation;
- retain existing final bundle-lock validation;
- retain existing final artifact-writer validation;
- use `manifestWriter.manifestPath` for `PXBackupResult.manifestPath`;
- keep `PXBackupResult.backupDirectory` equal to the private partial workspace path for TASK-3.7.

Required manager counts after TASK-3.7:

```text
manifest writer factory calls:        1
manifest writer identity validations: 3
manifest write calls:                 1
manager v4 builder calls:             1
manager pre-write validator calls:    1
legacy writeToFile manifest calls:    0
manifest shell chmod calls:           0
Failed to write manifest warnings:    0
```

Preserve:

```text
lock factory calls:             1
lock validations:               4
workspace factory calls:        1
workspace validations:          3
artifact writer factory calls:  1
artifact writer validations:    3
policy constructions:           8
policy-aware artifact writes:   8
failure-policy helper calls:     8
policy audit calls:              1
```

# Debug behavior

Debug output must not become manifest authority.

The existing debug command that lists `manifest.plist` may be moved after successful manifest publication so it observes the accepted final file. It remains best-effort debug-only behavior.

Do not parse, validate or accept the manifest through shell debug output.

# Manifest protocol invariants

After TASK-3.7:

```text
manifest final filename:             manifest.plist
manifest format:                     binary plist v1.0
manifest mode:                       0600
manifest link count:                 1
manifest size limit:                 128 MiB
manifest digest:                     SHA-256 lowercase
pre-rename validator calls:          1 inside writer
post-rename validator calls:         1 inside writer
manager pre-write validator calls:   1
atomic finalization:                 one renameat
strict file fsync:                   required
strict workspace fsync:              required
final overwrite:                     forbidden
warning-and-continue on write error: forbidden
```

# TASK-3.6 and TASK-3.6A non-regression

Keep byte-identical:

```text
PXBackupManifestV4.h/.m
PXBackupManifestValidator.h/.m
```

Preserve:

- exact 23 builder input keys;
- exact 33 v4 root keys;
- relative artifact `path == name`;
- persisted policy strings;
- exact reference coverage;
- canonical artifact order;
- one required ApplicationData first;
- backup UUID;
- excluded Preferences empty locator;
- factual options;
- malformed-v4 exception safety;
- v2/v3 compatibility;
- unknown positive-version manager code 201;
- manager code 107 fallback.

# Earlier Phase-3 non-regression

Keep byte-identical:

```text
PXBackupPublicationWorkspace.h/.m
PXBackupBundleLock.h/.m
PXBackupArtifactWriter.h/.m
PXBackupArtifactPolicy.h/.m
```

Do not change:

- partial workspace prefix or `mkdtemp` protocol;
- per-bundle lock behavior;
- artifact temporary protocol;
- artifact streaming SHA-256;
- artifact `renameat` finalization;
- artifact policy matrix;
- Preferences request/inclusion semantics;
- Backup component producers or ordering;
- warning text/order except removal of obsolete `Failed to write manifest` warning path;
- Restore behavior;
- Backup discovery;
- UI;
- Makefile;
- Keychain helper behavior.

# Later-task boundaries

Do not implement:

- TASK-3.8 final Backup directory rename/publication;
- final timestamp/backup-ID visible directory naming;
- destination collision policy;
- parent-directory publication fsync;
- TASK-3.9 whole-workspace cleanup;
- TASK-3.10 stale partial cleanup or discovery changes;
- publication marker files;
- manifest schema v5;
- Restore changes;
- UI changes.

# Static gates

Required implementation scope:

```text
A PXBackupManifestWriter.h
A PXBackupManifestWriter.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.7-REPORT.md
```

All other production diff must be zero.

Public API counts:

```text
exported constants:                  4
error codes:                        16
writer classes:                      1
writer factories:                    1
write methods:                       1
identity validation methods:         1
public descriptor properties:        0
public cleanup methods:               0
public rename methods:                0
```

Writer counts:

```text
final filename constants:            1
manifest temp prefix constants:       1
openat O_EXCL temp creation sites:    1
renameat finalization sites:          1
binary plist format sites:            1
pre-rename validator calls:           1
post-rename validator calls:          1
file fsync success-bypass branches:   0
workspace fsync success-bypass:       0
shell/process calls:                  0
whole-workspace recursive cleanup:    0
final overwrite paths:                0
```

Manager counts:

```text
manifest writer factory:              1
manifest writer validations:          3
manifest writer write calls:          1
v4 factory calls:                     1
manager validator calls:              1
writeToFile manifest calls:           0
manifest chmod shell calls:           0
Failed to write manifest warning:     0
final Backup directory rename:        0
```

# Fault and scenario matrix

Report at least 220 explicit scenario rows covering:

- invalid workspace object;
- workspace symlink/replacement;
- final manifest already present;
- temporary-prefix stale entry;
- random-name collision and retry limit;
- temp symlink/hard-link/type substitution;
- wrong mode and link count;
- serialization exception/error;
- zero and over-limit bytes;
- partial/zero-progress write;
- each strict fsync failure;
- pre-read early EOF/extra bytes;
- pre-read mutation;
- malformed plist;
- pre-rename validator rejection;
- pre-rename snapshot mismatch;
- final-name race;
- rename failure;
- final namespace substitution;
- final descriptor mismatch;
- post-read mutation;
- post-read validator rejection;
- post-read equality/checksum mismatch;
- cleanup success and cleanup evidence preservation;
- second-write rejection;
- validation before and after write;
- manager factory/write/final-validation failure;
- exact completion queue/count;
- valid v4 success;
- v2/v3 source non-regression;
- TASK-3.1 through TASK-3.6A source non-regression;
- no TASK-3.8 behavior.

# Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.7-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before and after;
3. old best-effort write inventory;
4. exact public API and sixteen errors;
5. pure writer boundary;
6. workspace binding;
7. temporary filename generation;
8. descriptor-relative creation;
9. binary-plist serialization and limits;
10. exact full-write proof;
11. strict durability proof;
12. pre-rename read-back, parse, validator and equality proof;
13. atomic `renameat` proof;
14. final descriptor and namespace proof;
15. post-rename read-back and validation proof;
16. retained digest/size/representation proof;
17. identity-validation proof;
18. pre/post-rename cleanup matrix;
19. evidence preservation;
20. error privacy;
21. manager factory/write/final gate ordering;
22. hard-failure completion contract;
23. obsolete warning/path-write/chmod removal;
24. TASK-3.6/3.6A non-regression;
25. TASK-3.1–3.5 non-regression;
26. TASK-3.8/3.9/3.10 boundaries;
27. full authorized source diff;
28. static gate table;
29. at least 220 explicit scenario rows;
30. whitespace/CRLF/NUL audit;
31. build status and remaining runtime risks.

Report ending must be exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 3a7d3f8fe8a98747fe6c823167250e43b8159e9f..HEAD --check
git diff --name-status 3a7d3f8fe8a98747fe6c823167250e43b8159e9f..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase3(task-3.7): write and validate manifest atomically
```

Stop after TASK-3.7.

Do not implement TASK-3.8 or any later task.
