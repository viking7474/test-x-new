# TASK-2.8 Review — Stage and Validate Main Application Data

Implementation commit reviewed: `9aaa575c7ce0e62aeb155c459879043e1ea5acfb`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

Build evidence: the project owner continued to the next task. No GitHub Actions artifact, compiled package or target-device runtime fixture is stored in this workspace for independent coordinator replay.

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXMainDataStaging.h
A PXMainDataStaging.m
A docs/backup-restore-hardening/reports/TASK-2.8-REPORT.md
```

No protected production file changed. The coordinator worktree contains documentation changes only and no uncommitted production diff.

## Commit hygiene

```text
git show --check: PASS
baseline-to-HEAD diff --check: PASS
new staging files trailing whitespace: 0
new staging files NUL bytes: 0
report trailing whitespace: 0
report NUL bytes: 0
```

`AppDataBackupManager.m` retains 17 legacy trailing-whitespace lines outside the added diff. The task did not add a whitespace error.

## Public API

`PXMainDataStaging.h` matches the frozen surface:

```text
error-domain exports: 1
field-path exports: 1
error codes: exactly 14
validated-stage classes: 1
workspace classes: 1
subclassing-restricted classes: 2
public readwrite properties: 0
validated-stage copyWithZone: 1, returns self
workspace NSCopying conformance: 0
```

The immutable validated result copies workspace/data paths and exposes only counts, exact regular-file bytes and the deterministic tree digest. It retains no descriptor or cleanup callback.

## Workspace creation and identity

The implementation uses the fixed parent and private template:

```text
/private/var/tmp
/private/var/tmp/weaponx_restore_main.XXXXXX
```

Creation uses `mkdtemp`, requires a direct generated child, opens parent/root/data using no-follow directory descriptors, verifies `FD_CLOEXEC`, enforces root/data mode `0700`, creates exactly one `data` child with `mkdirat`, and retains parent/root/data device/inode/type identities.

The predictable legacy path is absent:

```text
/tmp/weaponx_restore_<pid>: 0
weaponx_restore_<pid>: 0
manager staging removeItemAtPath: 0
manager staging createDirectoryAtPath: 0
```

Before empty validation, staged-tree validation and cleanup, retained descriptors and parent-relative namespace entries are matched against the creation snapshots. Root/data replacement, symlink substitution, mount/device change and setuid/setgid state fail closed.

## Empty gate

`validateEmptyDataDirectoryWithError:`:

- verifies workspace identity first;
- enumerates through duplicated close-on-exec descriptors;
- requires root to contain exactly `data`;
- requires `data` to contain no entry;
- compares root/data device, inode, type, mtime and ctime across enumeration;
- does not delete an unexpected entry.

## Staged-tree traversal

The validator starts from the retained data descriptor and uses:

```text
openat
fstatat(..., AT_SYMLINK_NOFOLLOW)
O_DIRECTORY
O_NONBLOCK
O_NOFOLLOW
O_CLOEXEC
fdopendir/readdir
```

Directory names are processed in raw-byte lexicographic order with strict lossless UTF-8 round-trip validation. Traversal is iterative and bounded; every entry receives a deterministic pre-order index.

Accepted types are exactly regular files and directories. It rejects symlinks, hard-linked files, FIFO/socket/device objects, mount/device crossing, unknown types and setuid/setgid entries.

Path policy enforces exact byte/component/depth limits without normalization, case folding or percent decoding.

The two root-level target identity metadata filenames are rejected exactly and case-sensitively.

## Fixed limits

```text
archive logical members: 200000
implicit directories: 200000
staged entries: 400000
cleanup entries: 500000
path bytes: 4096
component bytes: 255
depth: 2048
read buffer: fixed 64 KiB
```

The staged-entry ceiling is derived overflow-safely as zero for an accepted zero-member archive, otherwise `min(400000, logical members + 200000)`.

## Byte accounting and stable file reads

Each regular file is opened descriptor-relatively and checked before/after streaming. The implementation requires stable device, inode, regular type, link count, size, mtime and ctime; atime is ignored. All reads retry `EINTR`, and bytes read must equal the stable `st_size`.

After traversal:

```text
actual staged regular-file bytes == accepted archive regular-file bytes
```

Expected zero is compared exactly.

## Deterministic digest

The digest uses CommonCrypto SHA-256 and the exact domain prefix including its terminating NUL:

```text
PXMainDataStageTreeV1\0
```

Each entry contributes type, big-endian path length, exact relative path bytes, mode masked to `07777`, big-endian size and file content for regular files. Absolute staging path, inode/device, timestamps, ownership and atime are excluded. The result is exactly 64 lowercase hexadecimal characters.

## Safe cleanup

Cleanup is descriptor-relative and bounded. It:

- verifies retained parent/root namespace identity;
- walks with `fstatat(..., AT_SYMLINK_NOFOLLOW)` and no-follow directory opens;
- removes non-directories with `unlinkat`;
- removes directories with `unlinkat(..., AT_REMOVEDIR)`;
- rejects mount/device crossing;
- enforces the 500000-entry and depth limits;
- removes the unique root through the retained fixed-parent descriptor;
- marks cleaned only after the owned root is removed or proven absent;
- returns success on later cleanup calls;
- has no `NSFileManager` recursive-delete or shell fallback.

`dealloc` performs a best-effort safe cleanup and closes all remaining descriptors.

## Restore integration and ordering

The manager imports `PXMainDataStaging.h` exactly once and obtains accepted summary values only from `restorePlan.validatedArchives`.

Observed order:

```text
accepted PXRestorePlan
tar selection
accepted main archive summary
private workspace creation
empty-workspace validation
external extraction with zero exit
staged-tree validation
first target-process kill
ApplicationData target revalidation
main target wipe
clone from validatedStage.dataPath
workspace cleanup
optional-component mutation
```

The first Restore `_killRelatedProcessesForBundleID:` call is after successful stage validation.

The manager uses `workspace.dataPath` only as the external extraction destination and uses `validatedStage.dataPath` as clone authority.

## Fail-closed extraction

`_tarExtractDataArchive:archive:toDir:warnings:` now returns the real `_tarExtract:` result. The weak partial-content success conversion and `_directoryHasRestoredContent:` helper are removed.

```text
Cannot open: File exists continuation: 0
partial-stage warning continuation: 0
nonzero extraction rewritten to zero: 0
```

Extraction failure remains manager code `316`; target revalidation remains `303`; clone failure remains `317`.

## Cleanup paths

After workspace creation, explicit cleanup appears on:

```text
empty validation failure
extraction failure
stage validation failure
target revalidation failure
clone failure
successful clone
```

A pre-mutation cleanup failure does not replace the primary error. Cleanup failure after successful main clone adds only:

```text
Main-data staging cleanup failed
```

## Post-plan authority and non-regression

Operational Restore still has zero post-plan manifest, verifier lookup or archive-membership authority. Main source remains `restorePlan.dataArchivePath`; summary values remain `restorePlan.validatedArchives` values.

Protected accepted sources, `PXRestorePlan`, artifact/archive validators, resolver/path-validator, CommandRunner, Makefile and UI files are unchanged. Backup behavior is unchanged. App Group/optional staging and transaction/rollback remain unimplemented.

## Report

The report contains 170 explicit static/source scenarios and ends exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Remaining runtime risk

No local Objective-C/Theos compiler or target-device fixture is available in the workspace. Device testing remains necessary for Darwin directory enumeration behavior, external tar interactions, namespace-race injection, descriptor exhaustion, maximum-depth/entry cleanup and real clone semantics. These runtime risks do not create a source-contract blocker for TASK-2.8.
