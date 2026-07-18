# TASK-3.2 Review — Per-Bundle Backup Serialization

Implementation commit reviewed: `dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b`

Baseline: `2db8d448f1e89e74979a64f38e48ae3304ab353e`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-3.3 may open: **YES**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXBackupBundleLock.h
A PXBackupBundleLock.m
A docs/backup-restore-hardening/reports/TASK-3.2-REPORT.md
```

No protected production file changed. The TASK-3.1 workspace implementation and discovery exclusion remain byte-identical.

## Build status

The project owner continued after completing TASK-3.2. This is accepted as the owner build-status signal for the coordinator workflow. The Windows workspace contains no linked Theos package, Apple Clang artifact, or target-device concurrency fixture, so the build and runtime behavior could not be reproduced independently here.

No source evidence contradicts the owner continuation.

## Public API

`PXBackupBundleLock.h` exposes exactly:

- `PXBackupBundleLockErrorDomain`;
- `PXBackupBundleLockErrorFieldPathKey`;
- `PXBackupBundleLockFileName`;
- eleven error codes;
- one subclassing-restricted class;
- four copied readonly strings;
- one factory;
- one ownership-validation method;
- unavailable `init` and `new`.

Exact lock filename:

```text
.weaponx-backup.lock
```

No descriptor, raw lock path, unlock, wait, timeout, workspace, manifest, or publication API is public.

## Root and bundle authority

The lock implementation independently establishes the same root and bundle safety boundary accepted in TASK-3.1:

1. Validate absolute lossless UTF-8 Backup root input.
2. Validate exact safe bundle identifier component.
3. Create missing root ancestors when needed.
4. Reject unsafe final root object.
5. Canonicalize with `realpath`.
6. Open canonical root with no-follow and close-on-exec.
7. Bind requested path, canonical path, and descriptor identities.
8. Inspect/create exact bundle child using `fstatat` and `mkdirat`.
9. Open bundle directory descriptor-relatively.
10. Require directory type, no setid bits, same filesystem, namespace/descriptor identity, and `FD_CLOEXEC`.
11. Build the canonical bundle path only from the canonical root plus exact bundle identifier.

No recorded path, manifest path, UUID fallback, or string-only authority is used.

## Persistent lock-file proof

The lock file is opened only under the retained bundle descriptor:

```text
openat(bundleDescriptor,
       ".weaponx-backup.lock",
       O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC,
       0600)
```

The implementation requires:

- regular file type;
- exact mode `0600`;
- link count exactly one;
- same device as the bundle directory;
- namespace and descriptor device/inode/type equality;
- `FD_CLOEXEC`.

The file is not truncated, written, or unlinked. It remains as a persistent empty serialization inode across success, failure, deallocation, and process restart.

## Nonblocking acquisition and contention

The single acquisition helper performs exactly:

```text
flock(lockDescriptor, LOCK_EX | LOCK_NB)
```

It retries only `EINTR`.

Error mapping is exact:

```text
EWOULDBLOCK / EAGAIN -> PXBackupBundleLockErrorLockUnavailable
other flock failure  -> PXBackupBundleLockErrorLockFileOpenFailed
```

There is no blocking wait, sleep, deadline, repeated contention attempt, shared-lock fallback, global in-memory fallback, or unlocked continuation.

After acquisition, the complete root/bundle/lock proof is repeated before the object is returned.

## Retained lock authority

The object retains:

- root descriptor;
- bundle descriptor;
- original locked file descriptor;
- exact initial root/bundle/lock identities;
- internal locked state.

`validateOwnershipWithError:` checks the retained descriptors and namespace again without reacquiring or replacing retained state. The implementation detects root/bundle replacement, lock unlink/recreate, symlink replacement, wrong type, link-count change, mode change, and device/inode change.

The contract correctly relies on retaining the original locked descriptor; no unsupported lock-owner query is invented.

## Lifecycle

Factory failure:

- best-effort unlocks only if acquisition succeeded;
- closes lock, bundle, and root descriptors;
- leaves the persistent lock file in place.

Deallocation order is:

1. best-effort `LOCK_UN`, retrying only `EINTR`;
2. close lock descriptor;
3. close bundle descriptor;
4. close root descriptor.

Closing the descriptor provides the kernel release boundary even if explicit unlock fails. Process termination also releases the flock while preserving the lock file.

## Serialization domains

The physical namespace establishes the intended behavior:

- same canonical root and same exact bundle identifier share one inode and serialize;
- lexical aliases resolving to the same physical root and same bundle share the same lock;
- different bundle directories use different lock files and may proceed concurrently;
- the same bundle under physically distinct Backup roots is a distinct lock domain.

The implementation introduces no global lock and no static mutable lock table.

## Manager ordering

`createBackupForBundleID:appName:options:completion:` now performs:

```text
parameter guard
existing background queue
active profile read
one _backupRoot read
lock factory
initial ownership validation
tar discovery
source-container resolution
timestamp
pre-workspace ownership validation
TASK-3.1 workspace factory
Backup output
pre-manifest ownership validation
manifest write
workspace final identity validation
final lock ownership validation
PXBackupResult construction
```

Independent method-scoped counts:

```text
_backupRoot calls:             1
lock factory calls:            1
lock ownership validations:    4
workspace factory calls:       1
workspace identity checks:     3
manifestVersion 3:             retained
publication rename/move:       0
```

Contention returns nil result plus the exact lock-domain error on the main queue before:

- tar discovery;
- source-container resolution;
- timestamp generation;
- partial workspace creation;
- process termination;
- output creation;
- manifest writing.

The lock variable uses `objc_precise_lifetime` and remains live through final result construction, as required by the specification.

## TASK-3.1 non-regression

SHA-256 comparison from the TASK-3.2 baseline confirms exact byte identity for:

```text
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
```

The following remain unchanged:

- `.weaponx-backup-partial-XXXXXX` workspace creation;
- mode `0700`;
- retained workspace identities;
- three manager workspace validations;
- two discovery exclusions;
- temporary partial-path success result;
- zero final publication rename;
- no partial cleanup policy.

The persistent lock is a sibling under the canonical bundle directory, not a child of the partial workspace.

## Broader non-regression

Independent protected-diff and method-body checks confirm:

- public Backup selector unchanged;
- Restore method unchanged;
- `listBackupDirectoriesForBundleID:` unchanged;
- `_timestampString` unchanged;
- warning and component behavior unchanged;
- manifest schema remains version 3;
- no final publication;
- no artifact writer;
- no required/optional policy;
- no centralized cleanup;
- no stale partial deletion;
- no UI, Keychain helper, CommandRunner, or Makefile changes.

## Static gates

```text
public error codes:                    11
public factories:                       1
public validation methods:              1
flock acquisition sites:                1
exact LOCK_EX | LOCK_NB sites:          1
explicit unlock sites:                  1
O_TRUNC/ftruncate sites:                0
lock-file write sites:                  0
lock-file unlink sites:                 0
shell/process sites in lock source:     0
manager lock factory calls:             1
manager lock validations:               4
TASK-3.1 workspace source diff:          0
Restore method diff:                    0
discovery method diff:                  0
publication rename/move:                0
report scenarios:                     261
git show --check:                    PASS
baseline-to-HEAD diff --check:       PASS
new trailing whitespace:                0
new NUL bytes:                          0
```

## Remaining runtime risks

The remaining risks require the target environment rather than a source correction in TASK-3.2:

- actual Darwin filesystem behavior under concurrent processes;
- process-crash lock release on the deployed kernel/filesystem combination;
- rootful/rootless Backup-root alias behavior on a real device;
- final Theos/Apple Clang compile and link.

These risks do not block source acceptance.

## Decision

TASK-3.2 is accepted and completed.

TASK-3.3 may be specified from baseline:

```text
dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b
```
