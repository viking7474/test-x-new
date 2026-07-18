# TASK-3.10A - Fix Top-Level Name Classification and Rollback Errors

- Status: READY
- Phase: 3 - Atomic Backup Publication
- Baseline: `5e70a8ff5572dd343c8a16eb566277ab662e307f`
- Depends on: TASK-3.10 implementation and `docs/backup-restore-hardening/reviews/TASK-3.10-REVIEW.md`
- Build owner: Project owner through GitHub Actions / Theos

## Objective

Correct exactly two stale-cleanup defects found during TASK-3.10 source review:

1. top-level nonreserved direct children must be ignored even when their raw names are not valid UTF-8 or contain control bytes;
2. a capture mismatch or post-capture retention failure whose no-replace rollback cannot be proved must return `RollbackFailed` before any prior destructive mutation, or `CleanupIncomplete` after prior destructive mutation.

Do not redesign discovery, manager integration or the accepted stale-cleanup removal protocol.

## Authorized production scope

Modify exactly:

```text
PXBackupStaleWorkspaceCleanup.m
```

Create exactly:

```text
docs/backup-restore-hardening/reports/TASK-3.10A-REPORT.md
```

The implementation commit must contain exactly those two files.

## Protected files

The following must remain byte-identical to baseline:

```text
PXBackupDirectoryDiscovery.h
PXBackupDirectoryDiscovery.m
PXBackupStaleWorkspaceCleanup.h
AppDataBackupManager.h
AppDataBackupManager.m
PXBackupFailureCleanup.h
PXBackupFailureCleanup.m
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
PXBackupBundleLock.h
PXBackupBundleLock.m
PXBackupArtifactPolicy.h
PXBackupArtifactPolicy.m
PXBackupArtifactWriter.h
PXBackupArtifactWriter.m
PXBackupManifestV4.h
PXBackupManifestV4.m
PXBackupManifestValidator.h
PXBackupManifestValidator.m
PXBackupManifestWriter.h
PXBackupManifestWriter.m
PXBackupDirectoryPublisher.h
PXBackupDirectoryPublisher.m
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
PXBackupArchiveValidator.h
PXBackupArchiveValidator.m
PXRestorePlan.h
PXRestorePlan.m
CommandRunner.h
CommandRunner.m
Makefile
```

Also protect all Restore transaction/staging/resolver sources, UI/controllers, Keychain helper/bridge/scripts and coordinator-owned documentation.

Do not stage, revert, delete, format or rewrite coordinator-owned modified/untracked files.

## Required baseline evidence

Record before editing:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```

Read in full:

```text
docs/backup-restore-hardening/reviews/TASK-3.10-REVIEW.md
docs/backup-restore-hardening/tasks/TASK-3.10-harden-backup-discovery-and-stale-partial-cleanup.md
```

Record SHA-256 and byte size before/after for every protected production file listed above.

# Part A - Raw Top-Level Classification

## Current defect

The common directory reader validates every collected name by decoding it as lossless UTF-8 and rejecting control bytes.

That behavior is correct for recursive contents inside a proven stale workspace because those names may become deletion targets.

It is incorrect for direct children of the retained bundle directory. A direct child that does not begin either reserved stale prefix is outside mutation authority and must be ignored regardless of whether its raw bytes form a valid NSString.

Current failing paths include:

```text
initial top-level preflight scan
successful post-cleanup final scan
post-cleanup validateIdentityWithError scan
```

## Required semantic separation

Preserve exactly one reusable:

```text
fdopendir site
readdir site
F_DUPFD_CLOEXEC site
```

The implementation may extend the existing common reader with an internal scan mode or equivalent private parameters. Do not duplicate enumeration into a second readdir implementation.

Support exactly two semantic modes.

### Mode 1 - strict recursive deletion names

Used only while traversing contents inside an exact, proven stale workspace.

Preserve current behavior:

- name length from 1 through 255 bytes;
- reject dot and dot-dot;
- reject slash, backslash, NUL/control bytes;
- require valid lossless UTF-8 round trip;
- count every visited entry and accumulated name byte;
- return `UnsafeReservedEntry` or another existing exact bounded traversal error on unsafe names;
- never delete or follow an unrepresentable entry.

Do not weaken this mode.

### Mode 2 - raw top-level reserved classification

Used only for direct children of `_bundleDescriptor` during:

```text
initial preflight
final post-cleanup scan
post-cleanup validateIdentityWithError scan
```

For each non-dot raw `d_name`:

1. Determine raw length without reading beyond `NAME_MAX`/the existing 255-byte bound.
2. Enforce aggregate entry and accumulated-name-byte limits for every direct child, including nonreserved children.
3. Compare raw bytes against the two ASCII prefixes before any NSString conversion:

```text
.weaponx-backup-partial-
.weaponx-cleanup-quarantine-
```

4. If neither prefix matches, classify as nonreserved and ignore it.
5. Do not require a nonreserved name to be valid UTF-8.
6. Do not reject a nonreserved name merely because it contains a control byte.
7. Do not open, stat, normalize, log, rename, unlink or rmdir a nonreserved name.
8. If a reserved prefix matches, preserve the raw bytes as bounded `NSData` and classify exact vs malformed using raw ASCII grammar.
9. Exact reserved names may proceed to the existing no-follow candidate preflight.
10. Malformed reserved-prefix names must fail closed with `PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid` before any mutation.

## Exact reserved grammar

Preserve:

```text
.weaponx-backup-partial-<6 ASCII alphanumeric>
.weaponx-cleanup-quarantine-<32 lowercase ASCII hex>
```

Malformed reserved names include:

- suffix too short or too long;
- non-alphanumeric partial suffix;
- uppercase quarantine hex;
- non-hex quarantine suffix;
- control byte after a reserved prefix;
- non-UTF-8 byte after a reserved prefix;
- extra trailing bytes after an otherwise exact name.

These must fail with `ReservedNameInvalid`, not be ignored.

## Nonreserved opaque examples

All of the following are outside cleanup authority and must not block Backup when they do not start a reserved prefix:

```text
66 6f 6f ff
80 81 82
6e 6f 6e 72 65 73 65 72 76 65 64 01
ordinary-file
.cache
published timestamp/UUID directory
```

The implementation must preserve them byte-for-byte and return success when no stale candidate or malformed reserved entry otherwise prevents success.

## Final validation

After cleanup and in successful post-cleanup `validateIdentityWithError:`:

- scan the bundle directory in raw top-level mode;
- fail if any exact or malformed reserved partial/quarantine prefix remains;
- ignore every nonreserved raw name;
- retain lock and bundle-directory identity validation;
- do not reopen or inspect published/nonreserved entries.

## Top-level classification fixed limits

Preserve:

```text
maximum top-level exact candidates: 256
maximum aggregate visited entries:  16384
maximum component bytes:              255
maximum accumulated name bytes:     8 MiB
```

All additions and comparisons must be overflow-safe.

# Part B - Exact Rollback Error Mapping

## Current defect

The capture helper correctly preserves evidence when no-replace rollback fails, but it maps a failed first rollback to `EntryChanged` or `LimitExceeded` instead of the required `RollbackFailed`.

`PXBackupStaleWorkspaceCleanupErrorRollbackFailed` currently has zero production references.

## Required precedence

Whenever a successful atomic capture later requires rollback, use exactly this precedence.

### Identity mismatch

```text
rollback proved:
    PXBackupStaleWorkspaceCleanupErrorEntryChanged

rollback not proved and priorDestructiveMutation == NO:
    PXBackupStaleWorkspaceCleanupErrorRollbackFailed

rollback not proved and priorDestructiveMutation == YES:
    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
```

### Quarantine-name retention/representation failure

For the bounded `strlen`/retained-name allocation paths after an exact capture:

```text
rollback proved:
    PXBackupStaleWorkspaceCleanupErrorLimitExceeded

rollback not proved and priorDestructiveMutation == NO:
    PXBackupStaleWorkspaceCleanupErrorRollbackFailed

rollback not proved and priorDestructiveMutation == YES:
    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
```

The implementation may add one small file-local helper that selects the error code from:

```text
rollbackSucceeded
priorDestructiveMutation
operationSpecificCode
```

No public API change is permitted.

## Evidence preservation

Preserve exactly:

- same no-replace move helper for rollback;
- original-name absence requirement;
- no overwrite-capable fallback;
- strict parent fsync after rollback move;
- quarantine absence proof;
- original namespace presence proof;
- no unlink/rmdir of an unproven quarantine entry;
- both namespaces/evidence preserved on rollback collision or unprovable state.

## Do not broaden error remapping

Do not redesign or globally reassign:

```text
QuarantineFailed
RemovalFailed
DurabilityFailed
PublishedEntryDetected
EntryChanged
CleanupIncomplete
```

Only correct the three post-capture rollback decision sites identified in the TASK-3.10 review, plus a small shared internal selector if used.

# Part C - Required Static Gates

## Public API

```text
PXBackupStaleWorkspaceCleanup.h diff: 0
public error codes:                   18
readonly properties:                  4
factories:                             1
cleanup methods:                       1
identity methods:                      1
```

## Enumeration

```text
fdopendir implementation sites: 1
readdir implementation sites:   1
F_DUPFD_CLOEXEC sites:           1
```

No second top-level enumeration implementation is allowed.

Required semantic call paths:

```text
recursive strict scan mode:            1 reusable path
initial raw top-level scan mode:        1 call
final raw top-level scan mode:          1 call
post-cleanup validation raw scan mode:  1 call
```

## Raw-name behavior

Static/model evidence must prove:

```text
nonreserved raw names are not passed to NSString decoding
nonreserved raw names are not passed to openat/fstatat/rename/unlink/rmdir
reserved-prefix detection occurs on raw bytes
malformed reserved raw names fail ReservedNameInvalid
recursive deletion names still require strict lossless UTF-8
```

## Rollback behavior

```text
PXBackupStaleWorkspaceCleanupErrorRollbackFailed production references: >= 1
failed rollback before prior mutation: RollbackFailed
failed rollback after prior mutation:  CleanupIncomplete
proved mismatch rollback:              EntryChanged
proved retention-failure rollback:     LimitExceeded
```

## Atomic cleanup preservation

```text
renameatx_np implementation sites: 1
RENAME_EXCL uses:                  1
plain renameat sites:              0
dlsym/private syscall sites:       0
arc4random_buf sites:              1
original-name destructive sites:   0
```

Preserve all file/directory/root capture-before-delete ordering and counters.

## Forbidden additions

Do not add:

- NSFileManager;
- shell/process execution;
- absolute child traversal;
- realpath child mutation;
- age/mtime/ctime/PID stale authority;
- published Backup deletion;
- legacy-root mutation;
- marker/index/retention work;
- Restore/UI/Keychain changes;
- Phase 4 work.

# Part D - Required Tests and Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.10A-REPORT.md
```

The report must include:

1. baseline commit and exact two-file scope;
2. protected file SHA-256 before/after table;
3. review blocker reproduction;
4. common reader before/after architecture;
5. proof that fdopendir/readdir counts remain one;
6. raw top-level prefix classification algorithm;
7. exact reserved ASCII grammar;
8. nonreserved opaque-name ignore proof;
9. malformed reserved raw-name fail-closed proof;
10. recursive strict-name non-regression;
11. final scan and validateIdentity behavior;
12. rollback code-selection table;
13. active `RollbackFailed` source proof;
14. evidence-preservation proof;
15. atomic capture/removal non-regression;
16. manager/discovery/header byte identity;
17. all Phase-3 count/hash non-regression;
18. whitespace/CRLF/NUL audit;
19. build/toolchain status and device risks;
20. explicit scenario matrix.

Include at least 140 explicit numbered scenario rows.

Required scenarios include at minimum:

### Top-level nonreserved raw names

- empty directory;
- ordinary ASCII filename;
- dot-hidden nonreserved name;
- published v2/v3 directory;
- published v4 timestamp/UUID directory;
- raw byte `0xff` after a nonreserved prefix;
- leading raw bytes `0x80 0x81`;
- nonreserved control byte `0x01`;
- maximum 255-byte nonreserved opaque name;
- many opaque names below aggregate limits;
- opaque names at aggregate entry limit;
- opaque name causing accumulated-byte limit overflow;
- nonreserved symlink/file/FIFO/socket/device remains untouched;
- physical published directory remains untouched.

### Malformed reserved raw names

- partial suffix length 0 through 5;
- partial suffix length 7;
- partial suffix punctuation;
- partial suffix control byte;
- partial suffix invalid UTF-8 byte;
- quarantine suffix length 0 through 31;
- quarantine suffix length 33;
- uppercase hex;
- `g` through `z` suffix bytes;
- control byte after quarantine prefix;
- invalid UTF-8 after quarantine prefix;
- exact reserved name followed by extra byte;
- malformed reserved name mixed with valid stale candidates fails before mutation.

### Recursive strict names

- invalid UTF-8 nested file;
- control-byte nested file;
- invalid UTF-8 nested directory;
- special nested entry;
- strict recursive scan preserves evidence and fails closed.

### Rollback mapping

- identity mismatch rollback succeeds before mutation -> EntryChanged;
- identity mismatch rollback collision before mutation -> RollbackFailed;
- identity mismatch rollback unprovable before mutation -> RollbackFailed;
- identity mismatch rollback collision after earlier removal -> CleanupIncomplete;
- identity mismatch rollback unprovable after earlier removal -> CleanupIncomplete;
- retained quarantine-name allocation failure with successful rollback -> LimitExceeded;
- retained-name failure with failed rollback before mutation -> RollbackFailed;
- retained-name failure with failed rollback after mutation -> CleanupIncomplete;
- original name recreated before rollback;
- rollback rename EINTR then success;
- rollback parent fsync failure;
- rollback quarantine absence proof failure;
- rollback original-presence proof failure;
- no overwrite fallback;
- no unlink/rmdir after failed rollback.

### Non-regression

- exact partial cleanup;
- exact prior quarantine cleanup;
- multiple sorted candidates;
- nested prior quarantine recovery;
- regular-file removal ordering;
- subdirectory removal ordering;
- root removal ordering;
- count increments after durability only;
- no stale entries success;
- one-shot cleanup;
- final lock/path validation;
- `PXBackupDirectoryDiscovery` byte identity;
- `AppDataBackupManager.m` byte identity;
- `PXBackupStaleWorkspaceCleanup.h` byte identity;
- protected TASK-3.1 through TASK-3.9A byte identity.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part E - Completion Gates

Run and record after implementation:

```text
git diff --check
git status --short --untracked-files=all
git diff --name-status 5e70a8ff5572dd343c8a16eb566277ab662e307f..HEAD
git diff 5e70a8ff5572dd343c8a16eb566277ab662e307f..HEAD --check
git show --check --oneline HEAD
git show --stat --oneline HEAD
```

Expected implementation commit manifest:

```text
M PXBackupStaleWorkspaceCleanup.m
A docs/backup-restore-hardening/reports/TASK-3.10A-REPORT.md
```

Suggested commit:

```text
phase3(task-3.10A): fix stale name classification and rollback errors
```

Stop after TASK-3.10A.

Do not implement Phase 4 or any later task.
