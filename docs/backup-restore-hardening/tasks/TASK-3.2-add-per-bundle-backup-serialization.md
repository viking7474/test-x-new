# TASK-3.2 — Add Per-Bundle Backup Serialization

- Status: READY
- Phase: Phase 3 — Atomic Backup Publication
- Baseline: `2db8d448f1e89e74979a64f38e48ae3304ab353e`
- Depends on: TASK-3.1 accepted
- Next task: TASK-3.3 remains LOCKED

## Objective

Prevent two Backup operations from mutating or reading the same bundle Backup domain concurrently.

Each Backup run must acquire one kernel-backed exclusive lock for the exact canonical per-bundle Backup directory before operational Backup work begins. The lock remains held through workspace creation, archive generation, manifest writing, final identity validation, and `PXBackupResult` construction.

Serialization is scoped to the exact canonical pair:

```text
canonical backup root
+ exact bundle identifier
```

Different bundle directories may proceed concurrently. The same physical per-bundle directory reached through root aliases must serialize through the same lock file and inode.

This task does not publish a Backup, change artifact writing, change manifest schema, or clean stale partial workspaces.

## Review inputs

Read before implementation:

```text
docs/backup-restore-hardening/reviews/TASK-3.1-REVIEW.md
docs/backup-restore-hardening/tasks/TASK-3.1-create-unique-partial-transaction-directory.md
```

## Allowed production scope

Only create or modify:

```text
PXBackupBundleLock.h
PXBackupBundleLock.m
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.2-REPORT.md
```

Implementation commit may contain only:

```text
A PXBackupBundleLock.h
A PXBackupBundleLock.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.2-REPORT.md
```

## Protected files

Do not modify:

```text
AppDataBackupManager.h
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
PXRestoreResult.h
PXRestoreResult.m
PXMainDataRestoreTransaction.h/.m
PXAppGroupRestoreTransaction.h/.m
PXOptionalRestoreTransaction.h/.m
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXOptionalRestoreStaging.h/.m
PXRestorePlan.h/.m
PXBackupManifestValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
CommandRunner.h/.m
Makefile
all UI/controller files
all Keychain helper/bridge/script files
coordinator task/review/status/roadmap/decision/README files
```

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file.

## Exact public API

Create `PXBackupBundleLock.h`.

Exports:

```objc
FOUNDATION_EXPORT NSErrorDomain const PXBackupBundleLockErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupBundleLockErrorFieldPathKey;
FOUNDATION_EXPORT NSString * const PXBackupBundleLockFileName;
```

The lock file name must be exactly:

```text
.weaponx-backup.lock
```

Define exactly eleven error codes:

```objc
PXBackupBundleLockErrorInvalidInput = 1,
PXBackupBundleLockErrorRootCreationFailed = 2,
PXBackupBundleLockErrorRootInspectionFailed = 3,
PXBackupBundleLockErrorUnsafeRoot = 4,
PXBackupBundleLockErrorBundleDirectoryCreationFailed = 5,
PXBackupBundleLockErrorBundleDirectoryInvalid = 6,
PXBackupBundleLockErrorLockFileOpenFailed = 7,
PXBackupBundleLockErrorLockFileInvalid = 8,
PXBackupBundleLockErrorLockUnavailable = 9,
PXBackupBundleLockErrorFilesystemChanged = 10,
PXBackupBundleLockErrorLimitExceeded = 11,
```

Create one subclassing-restricted class:

```objc
PXBackupBundleLock
```

Readonly copied properties:

```objc
canonicalBackupRootPath
canonicalBundleDirectoryPath
bundleIdentifier
lockFileName
```

One public factory:

```objc
+ (nullable instancetype)acquireLockAtBackupRoot:(NSString *)backupRoot
                                bundleIdentifier:(NSString *)bundleIdentifier
                                           error:(NSError **)error;
```

One public validation method:

```objc
- (BOOL)validateOwnershipWithError:(NSError **)error;
```

`init` and `new` must be unavailable.

Do not expose:

- descriptors;
- lock path;
- unlock/release controls;
- waiting controls;
- timeout controls;
- workspace creation;
- publication;
- manifest or artifact API.

## Pure lock implementation boundary

`PXBackupBundleLock.m` may import only:

```objc
#import "PXBackupBundleLock.h"
```

plus required POSIX/C headers.

Forbidden:

- `AppDataBackupManager`;
- `PXBackupPublicationWorkspace`;
- `CommandRunner`;
- UIKit;
- Security/Keychain;
- `NSUserDefaults`;
- shell or helper process;
- `NSTask`;
- `system`, `popen`, `posix_spawn`;
- tar/archive APIs;
- manifest parsing/writing;
- dispatch;
- logging raw paths or identifiers;
- global mutable state;
- in-memory-only locks;
- lock-file unlink cleanup;
- partial workspace cleanup;
- publication rename.

## Input validation

Use the same input authority boundary as TASK-3.1.

### Backup root

Require:

- runtime `NSString`;
- nonempty;
- absolute path;
- no U+0000;
- lossless UTF-8;
- at most 4096 UTF-8 bytes.

Do not trim, lowercase, Unicode-normalize, percent-decode, standardize, resolve tilde, or accept a relative root.

### Bundle identifier

Require:

- runtime `NSString`;
- nonempty;
- contains non-whitespace text;
- no U+0000;
- no ASCII control or DEL;
- no slash or backslash;
- not `.` or `..`;
- lossless UTF-8;
- at most 255 UTF-8 bytes.

Do not trim, lowercase, normalize, prefix-match, suffix-match, or otherwise rewrite the identifier.

## Backup-root proof

The lock factory may create missing root path components, matching TASK-3.1 compatibility.

After creation:

1. Inspect requested final component with `lstat`.
2. Reject final symbolic link.
3. Require a directory.
4. Reject setuid/setgid.
5. Resolve `realpath`.
6. Convert canonical bytes losslessly to UTF-8.
7. Open canonical root with:

```text
O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
```

8. `fstat` the descriptor.
9. Verify `FD_CLOEXEC`.
10. Require requested-final, canonical-path, and descriptor device/inode/type identity equality.
11. If the final root was created by this call, secure and verify mode `0700`.

Normal ancestor aliases such as `/var -> /private/var` remain allowed after exact canonical identity proof.

## Per-bundle directory proof

Using the retained root descriptor:

1. Inspect exact bundle component with:

```text
fstatat(..., AT_SYMLINK_NOFOLLOW)
```

2. If absent, create with:

```text
mkdirat(..., 0700)
```

3. Reject symbolic link or wrong type.
4. Reject setuid/setgid.
5. Open with:

```text
O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
```

6. Require namespace and descriptor identity equality.
7. Require same device as the canonical root.
8. Verify `FD_CLOEXEC`.
9. If newly created, secure and verify mode `0700`.
10. Build canonical bundle path only from canonical root plus exact bundle identifier.
11. Require canonical bundle path identity to match the retained descriptor.

Do not remove the root or bundle directory on factory failure.

## Lock file policy

The exact lock file is a direct child of the retained per-bundle directory:

```text
.weaponx-backup.lock
```

Open descriptor-relatively with semantics equivalent to:

```text
O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC
mode 0600
```

An `O_EXCL` create-then-open race-safe sequence is also allowed.

Requirements:

- no absolute lock-path open authority;
- final lock object must be a regular file;
- final lock object must not be a symbolic link;
- `st_nlink == 1`;
- same device as the per-bundle directory;
- namespace `fstatat(..., AT_SYMLINK_NOFOLLOW)` identity exact-matches descriptor `fstat`;
- exact mode `0600` after `fchmod` and reinspection;
- `FD_CLOEXEC` verified;
- lock file contains no required metadata;
- do not truncate, write owner PID, write bundle ID, or store path text;
- do not unlink the lock file on success, failure, or deallocation.

A persistent empty lock file is expected. Kernel lock ownership, not lock-file contents, is authoritative.

## Lock acquisition

Acquire exactly one exclusive nonblocking lock:

```text
flock(lockDescriptor, LOCK_EX | LOCK_NB)
```

Retry only when interrupted by `EINTR`.

Policy:

```text
success                         -> retain exclusive lock
EWOULDBLOCK or EAGAIN           -> LockUnavailable
any other flock failure         -> LockFileOpenFailed
```

Do not:

- block indefinitely;
- sleep/retry on contention;
- use a configurable timeout;
- downgrade to a shared lock;
- fall back to an in-memory lock;
- continue without the lock.

After acquiring the lock, repeat root, bundle, and lock namespace/descriptor identity proof before returning the object.

## Lock ownership and lifecycle

The returned object owns:

- canonical root descriptor;
- per-bundle directory descriptor;
- lock-file descriptor;
- exclusive flock state.

The object must retain exact initial identities.

`dealloc` must:

1. best-effort `flock(lockDescriptor, LOCK_UN)` with `EINTR` handling;
2. close lock descriptor;
3. close bundle descriptor;
4. close root descriptor.

Closing the lock descriptor must release the kernel lock even if explicit unlock fails.

Do not expose early unlock.

## Ownership validation

`validateOwnershipWithError:` must:

- clear `*error`;
- require internal locked state;
- `fstat` root, bundle, and lock descriptors;
- require retained device/inode/type identity equality;
- require root and bundle are directories;
- require lock is regular, single-linked, exact mode `0600`;
- require same-filesystem relationships;
- verify all `FD_CLOEXEC` flags;
- `lstat` canonical root and bundle paths;
- inspect lock namespace with retained bundle descriptor and `AT_SYMLINK_NOFOLLOW`;
- reject path replacement, lock-file replacement, symlink replacement, unlink/recreate, wrong type, or mode/link-count change;
- return exact retained canonical strings;
- not reacquire a lost lock and call that validation success;
- not update retained identities from observations.

There is no portable query that substitutes for retaining the original locked descriptor. The invariant is that the class never closes or unlocks it before deallocation.

## Error privacy

All errors use:

```text
PXBackupBundleLockErrorDomain
```

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupBundleLockErrorFieldPathKey
```

Allowed field paths:

```text
$.backupRoot
$.bundleIdentifier
$.bundleDirectory
$.lock
```

Do not expose:

- backup-root value;
- bundle identifier value;
- canonical path;
- lock-file path;
- device/inode;
- PID;
- errno text;
- nested errors;
- raw namespace names.

Descriptions must be generic and stable.

## Factory failure

On any factory failure:

- release flock if acquired;
- close every owned descriptor;
- leave the persistent lock file in place;
- do not unlink a lock file;
- do not remove bundle directory;
- do not remove backup root;
- do not create a partial workspace;
- return `nil` and a nonnil lock-domain error.

## Serialization semantics

### Same physical bundle directory

Two operations resolving to the same physical canonical per-bundle directory and same lock-file inode must not run operational Backup work concurrently.

One operation acquires the lock. A contender receives `PXBackupBundleLockErrorLockUnavailable` before workspace creation or process kill.

### Root aliases

Lexically different roots that canonicalize to the same physical root and exact same bundle directory must serialize through the same persistent lock file.

### Different bundles

Different exact bundle identifiers under the same root use different lock files and may run concurrently.

### Different canonical roots

The same bundle identifier under physically distinct backup roots is a distinct serialization domain. This task does not introduce a global cross-profile lock.

### Process crash

Kernel descriptor closure releases flock. The persistent lock file remains and is reused by the next operation.

Do not treat file existence as a stale lock.

## Manager integration

Import exactly once in `AppDataBackupManager.m`:

```objc
#import "PXBackupBundleLock.h"
```

Inside `createBackupForBundleID:appName:options:completion:`:

1. Keep the existing public parameter guard.
2. Enter the existing background queue.
3. Read active profile ID as today.
4. Read `_backupRoot` exactly once and retain it.
5. Acquire one `PXBackupBundleLock` before:
   - tar discovery;
   - source-container resolution;
   - timestamp generation;
   - TASK-3.1 workspace creation;
   - debug file creation;
   - groups/preferences directory creation;
   - process kill;
   - any archive or copied output;
   - manifest write.
6. On lock failure, dispatch exact lock error to main queue and return.
7. Validate lock ownership immediately after factory success.
8. Retain the lock with `objc_precise_lifetime` or equivalent through final result construction.
9. Reuse the same retained `backupRoot` for TASK-3.1 workspace factory.
10. Validate lock ownership immediately before workspace factory.
11. Validate lock ownership immediately before manifest write.
12. Validate lock ownership immediately before `PXBackupResult` construction.
13. Any validation failure returns `nil result + exact lock error` on main queue.

Expected manager counts:

```text
_backupRoot calls in Backup method:          1
lock factory calls:                          1
lock ownership validations:                  4
workspace factory calls:                     1
workspace identity validations:              3
```

The lock must still be held while all TASK-3.1 workspace descriptors are alive and Backup output is being written.

## Contention behavior

Contention is a hard Backup failure, not a warning.

Do not add a new manager-domain error code. Propagate the exact lock-domain error.

No workspace may be created for the contender.

No app or daemon may be killed for the contender.

No output file may be created for the contender.

## Preserve TASK-3.1

Keep byte-identical:

```text
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
```

Keep unchanged:

- exact partial prefix;
- `mkdtemp` workspace creation;
- workspace mode and identity checks;
- three workspace manager revalidation sites;
- partial discovery exclusion;
- temporary success path returned to explicit callers;
- zero final publication rename;
- no centralized partial cleanup.

The persistent lock file is a sibling of partial workspaces under the per-bundle directory. It must not be placed inside a partial workspace.

## Preserve Backup behavior

Other than serialization acquisition and lock validation, keep unchanged:

- public Backup selector;
- profile ID behavior;
- tar preference and errors;
- source-container resolution;
- timestamp format and manifest timestamp;
- process-kill timing relative to archive creation;
- debug files and contents;
- data archive;
- App Group behavior;
- profile/Safari behavior;
- Preferences behavior;
- Keychain behavior;
- system-global/shared DB behavior;
- artifact metadata;
- warning text/order;
- manifest version 3 and field set;
- manifest write semantics;
- `PXBackupResult` fields;
- Restore implementation;
- UI behavior.

## Discovery behavior

Do not change `listBackupDirectoriesForBundleID:` in TASK-3.2.

The persistent lock file is not a directory and is naturally ignored by existing discovery. TASK-3.1 partial-prefix skips remain byte-identical.

Do not add lock-file cleanup or discovery special cases.

## Later-task boundaries

Do not implement:

- TASK-3.3 common verified artifact writer;
- TASK-3.4 Preferences inclusion policy;
- TASK-3.5 required/optional artifact policy;
- TASK-3.6 manifest v4;
- TASK-3.7 atomic manifest protocol;
- TASK-3.8 final atomic publication;
- TASK-3.9 centralized failure cleanup;
- TASK-3.10 stale partial cleanup/discovery hardening;
- Phase 4 Keychain redesign;
- Phase 5 UI result presentation;
- Phase 6 legacy quarantine.

Do not publish or rename a partial workspace.

## Static gates

Required production scope:

```text
A PXBackupBundleLock.h
A PXBackupBundleLock.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.2-REPORT.md
all other production diff = 0
```

Public API:

```text
error-domain exports:                   1
field-path exports:                     1
lock-name exports:                      1
error codes:                           11
subclassing-restricted classes:         1
public factories:                       1
public validation methods:              1
public unlock methods:                  0
public descriptor properties:           0
public readwrite properties:            0
```

Lock implementation:

```text
lock file name exact: .weaponx-backup.lock
flock exclusive nonblocking sites:      1
blocking flock sites:                   0
sleep/retry on contention:              0
lock-file unlink sites:                 0
lock-file writes/truncation:            0
shell/process calls:                    0
publication rename sites:               0
```

Manager:

```text
_backupRoot calls in Backup:             1
lock factory calls:                      1
lock ownership validations:              4
workspace factory calls:                 1
workspace identity validations:          3
lock before tar discovery:              yes
lock before source resolution:          yes
lock before workspace:                  yes
lock before first process kill:         yes
exact lock-error propagation:           yes
```

Protected behavior:

```text
PXBackupPublicationWorkspace diff:       0
Restore method diff:                     0
listBackupDirectories diff:              0
public selector diff:                    0
manifestVersion 3 retained:              yes
publication rename/move:                 0
UI diff:                                 0
Makefile diff:                           0
```

## Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.2-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. exact public API and eleven-code enum;
4. input validation matrices;
5. backup-root descriptor proof;
6. per-bundle mkdirat/openat proof;
7. exact persistent lock-file policy;
8. regular-file, link-count, mode, and same-device proof;
9. no-follow/CLOEXEC proof;
10. namespace/descriptor identity proof;
11. exact nonblocking flock behavior;
12. contention matrix;
13. root-alias serialization proof;
14. different-bundle concurrency proof;
15. process-crash release behavior;
16. lock lifecycle and dealloc proof;
17. validation method proof;
18. error privacy;
19. factory-failure descriptor/lock cleanup;
20. manager ordering before tar/source/workspace/kill;
21. four manager lock validations;
22. precise-lifetime proof;
23. TASK-3.1 byte-identity and non-regression;
24. warning/manifest/artifact non-regression;
25. Restore/UI zero diff;
26. later-task boundaries;
27. full authorized production diff;
28. static and forbidden gate table;
29. at least 130 explicit scenario rows;
30. whitespace, CRLF, NUL, generated-file audit;
31. build status and remaining runtime risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 2db8d448f1e89e74979a64f38e48ae3304ab353e..HEAD --check
git diff --name-status 2db8d448f1e89e74979a64f38e48ae3304ab353e..HEAD
git status --short --untracked-files=all
```

Suggested commit subject:

```text
phase3(task-3.2): add per-bundle backup serialization
```

## Stop condition

Stop after TASK-3.2 source, report, and implementation commit.

Do not implement TASK-3.3 or any later task.
