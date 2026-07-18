# TASK-3.8A — Enforce Atomic No-Replace Directory Publication

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Parent task: TASK-3.8
- Baseline: `494cae02f042bb0e115fa780f2683e124467fda9`
- Review: `docs/backup-restore-hardening/reviews/TASK-3.8-REVIEW.md`

## Objective

Correct the TASK-3.8 time-of-check/time-of-use collision gap.

Plain `renameat` may replace an empty destination directory that appears after the final absence check. TASK-3.8A must make both forward publication and reverse rollback atomically no-replace at the filesystem syscall boundary.

After this correction:

```text
forward destination absent:
  partial -> final rename succeeds

forward destination exists at syscall time:
  no source or destination replacement
  FinalDirectoryAlreadyExists

reverse destination absent:
  final -> original partial rename succeeds

reverse destination exists at syscall time:
  no source or destination replacement
  RollbackFailed
  evidence preserved
```

The pre-rename absence checks remain useful diagnostics, but the no-overwrite authority must be the rename operation itself.

## Authorized scope

Production file allowed to change:

```text
PXBackupDirectoryPublisher.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-3.8A-REPORT.md
```

Implementation commit may contain only:

```text
M PXBackupDirectoryPublisher.m
A docs/backup-restore-hardening/reports/TASK-3.8A-REPORT.md
```

## Protected files

Do not modify:

```text
PXBackupDirectoryPublisher.h
AppDataBackupManager.h
AppDataBackupManager.m
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
all Restore transaction/staging/resolver source
CommandRunner.h/.m
Makefile
UI/controller files
Backup discovery
Keychain helper/bridge/script files
coordinator task/review/status/roadmap/decision/README files
```

## Baseline evidence

Record before modification:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -6 --oneline
git diff --check
```

Record SHA-256 before and after for all protected production files.

## Existing blocker

TASK-3.8 currently has one helper containing plain:

```c
renameat(sourceParentDescriptor,
         sourceName,
         destinationParentDescriptor,
         destinationName)
```

The call occurs after a destination-absence check. That check is not atomic with rename.

A competing actor can create an empty destination directory after the check. Plain `renameat` may replace that empty directory. Post-publication inode proof then succeeds because the retained workspace inode is visible under the final name.

The current report statement that there is no overwrite is therefore not established.

## Required Darwin primitive

Use Darwin atomic no-replace rename:

```c
renameatx_np(sourceParentDescriptor,
             sourceName,
             destinationParentDescriptor,
             destinationName,
             RENAME_EXCL)
```

Requirements:

- include the Darwin SDK header that declares `renameatx_np` and `RENAME_EXCL`;
- use the SDK declaration directly;
- do not redeclare the function manually with a potentially incompatible prototype;
- do not use `dlsym`, private syscall numbers or shell/process fallback;
- do not fall back to plain `renameat`;
- do not fall back to `NSFileManager` move/copy/delete;
- do not use marker, reservation-directory or copy/delete publication protocols;
- if the target SDK cannot provide `renameatx_np` and `RENAME_EXCL`, the build must fail rather than silently compile an overwrite-capable fallback.

The repository target remains:

```text
iphone:clang:16.5:12.0
arm64 arm64e
```

No Makefile change is authorized.

## Exact helper

Replace the old helper with one file-local helper equivalent to:

```c
static BOOL PXBackupDirectoryRenameEntryNoReplace(
    int sourceParentDescriptor,
    const char *sourceName,
    int destinationParentDescriptor,
    const char *destinationName,
    int *failureErrnoOut);
```

Behavior:

1. Clear `failureErrnoOut` to zero when supplied.
2. Validate descriptors and names.
3. Call `renameatx_np(..., RENAME_EXCL)`.
4. Retry only when the syscall returns failure with `errno == EINTR`.
5. On success, return YES and leave failure errno zero.
6. On failure, preserve the exact final errno in `failureErrnoOut` and return NO.
7. No internal error-object creation.
8. No namespace mutation other than the successful no-replace rename.

Required implementation counts:

```text
file-local no-replace helper definitions: 1
renameatx_np implementation sites:         1
RENAME_EXCL uses:                          1
plain renameat implementation sites:       0
forward helper calls:                      1
reverse helper calls:                      1
```

Do not duplicate syscall sites to satisfy forward and reverse paths.

## Forward publication mapping

Keep all existing pre-publication checks and exact ordering.

Forward call remains:

```text
source parent:      retained bundle-directory descriptor
source name:        original .weaponx-backup-partial-* name
destination parent: same retained descriptor
destination name:   <timestamp>-<backup UUID>
```

If no-replace rename succeeds:

- continue existing post-rename directory and manifest proof unchanged.

If no-replace rename fails with:

```text
EEXIST
ENOTEMPTY
```

return:

```text
domain: PXBackupDirectoryPublisherErrorDomain
code: PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists
field: $.publication.finalDirectory
description: The final backup directory already exists
```

Requirements:

- source partial workspace remains at the original name;
- destination entry remains byte-for-byte and inode-for-inode unchanged;
- `forwardRenamed` remains NO;
- reverse rollback is not entered;
- `published` remains NO.

Other forward rename failure:

```text
code: PXBackupDirectoryPublisherErrorPublicationFailed
description: The backup directory could not be published atomically
```

Preserve generic error privacy. Do not include raw errno text, names, paths, inode/device values or bundle ID.

## Forward collision matrix

At syscall time, each destination state must fail without replacement:

```text
regular file
symlink
FIFO/socket/device
nonempty directory
empty directory
same-name directory created after final precheck
entry removed and recreated between precheck and syscall
```

The empty-directory case is the corrective blocker and must have explicit evidence.

The source partial directory must remain exact retained workspace identity after every collision failure.

## Reverse rollback mapping

Reverse rollback must use the same atomic no-replace helper.

Reverse call:

```text
source parent:      retained bundle-directory descriptor
source name:        final published name
destination parent: same retained descriptor
destination name:   original partial name
```

If original partial name appears after the rollback precheck but before the reverse syscall:

- no-replace rename must fail;
- the competing partial-name entry must remain unchanged;
- the final-name directory must remain unchanged;
- return `PXBackupDirectoryPublisherErrorRollbackFailed`;
- preserve all evidence;
- do not retry using overwrite-capable rename;
- do not delete either namespace entry.

Any reverse helper failure maps to the existing generic rollback error:

```text
domain: PXBackupDirectoryPublisherErrorDomain
code: PXBackupDirectoryPublisherErrorRollbackFailed
field: $.publication.finalDirectory
description: The failed directory publication could not be rolled back safely
```

On reverse no-replace success, preserve all current proof:

- strict parent fsync;
- final name absent;
- original partial name exact retained workspace identity;
- `published == NO`;
- return the original publication error.

## No-overwrite proof

The report must explicitly distinguish:

```text
precheck:
  diagnostic/race-reduction only

RENAME_EXCL syscall:
  authoritative atomic no-replace commit gate

postcheck:
  identity and durability proof after successful commit
```

Do not claim that UUID uniqueness, per-bundle flock or prechecks alone establish no-overwrite behavior.

## Preserve TASK-3.8 state machine

Do not change:

- public 18-code enum;
- public publisher properties/methods;
- final-name format;
- timestamp or UUID validation;
- retained parent/workspace descriptors;
- factory collision check;
- pre-publication lock/workspace/artifact/manifest validation;
- strict workspace sync before publication;
- final directory open and identity proof;
- final manifest open, digest, validator and equality replay;
- accepted state fields;
- published-state validation;
- result-path behavior;
- reverse rollback ordering except the rename primitive and failure mapping;
- descriptor close order;
- error userInfo shape.

## Preserve manager integration

`AppDataBackupManager.m` must remain byte-identical.

Required existing counts remain:

```text
directory publisher factory:       1
directory publisher validations:   3
directory publisher publish calls: 1

bundle lock factory:               1
bundle lock validations:           4
workspace factory:                 1
workspace validations:             3
artifact writer factory:           1
artifact writer validations:       3
manifest writer factory:           1
manifest writer validations:       3
manifest writer writes:            1
policy constructions:              8
artifact writes:                   8
failure-policy calls:              8
policy audit calls:                1
v4 builder calls:                  1
manager v4 validator calls:        1
```

Successful result still uses:

```objc
out.backupDirectory = directoryPublisher.publishedDirectoryPath;
out.manifestPath = directoryPublisher.publishedManifestPath;
```

## Non-regression

Keep byte-identical:

```text
PXBackupDirectoryPublisher.h
AppDataBackupManager.h/.m
TASK-3.1 workspace source
TASK-3.2 lock source
TASK-3.3/3.5 artifact writer and policy
TASK-3.6/3.6A manifest builder and validator
TASK-3.7 manifest writer
Restore source
Backup discovery
UI/controllers
Makefile
Keychain helper/bridge/scripts
```

No publication marker, index, cleanup sweep or discovery mutation.

## Test and evidence requirements

Use temporary harnesses outside the repository.

### Strict frontend gate

Compile `PXBackupDirectoryPublisher.m` against the same Apple SDK/deployment target used by the project, or the closest available strict Apple frontend gate.

The gate must prove:

```text
renameatx_np declaration resolves
RENAME_EXCL resolves
arm64 frontend: pass
arm64e frontend when available: pass
no implicit declaration
no incompatible function prototype
no unavailable-API error for iOS 12 deployment target
```

If the local Windows workspace cannot execute this gate, report it as pending GitHub Actions rather than inventing success.

### Deterministic syscall model

A temporary model/harness must cover at least:

- success with absent destination;
- `EINTR` then success;
- repeated `EINTR` then collision;
- forward `EEXIST` mapping;
- forward `ENOTEMPTY` mapping;
- forward unrelated errno mapping;
- reverse collision mapping;
- source and destination unchanged on each collision;
- no reverse rollback after failed forward no-replace rename;
- reverse success preserves original error.

### Target-device race replay

Document pending target tests for:

1. Pause after final absence proof.
2. Create empty final destination directory.
3. Resume forward rename.
4. Verify collision failure.
5. Verify destination inode remains unchanged.
6. Verify partial workspace inode remains unchanged.
7. Repeat for regular file and symlink.
8. During rollback, recreate original partial name before reverse syscall.
9. Verify `RollbackFailed` and both entries remain unchanged.

## Static gates

Required scope:

```text
M PXBackupDirectoryPublisher.m
A docs/backup-restore-hardening/reports/TASK-3.8A-REPORT.md
```

All other production diff:

```text
0
```

Required source counts:

```text
renameatx_np implementation sites:       1
RENAME_EXCL tokens:                      1
plain renameat implementation sites:     0
no-replace helper definitions:           1
forward no-replace helper calls:         1
reverse no-replace helper calls:         1
FinalDirectoryAlreadyExists mappings:    retained plus forward race mapping
RollbackFailed mappings:                 retained
NSFileManager move/copy/delete:           0
shell/process calls:                      0
publication markers:                     0
```

Public header diff:

```text
0
```

Manager diff:

```text
0
```

Discovery/Restore/UI/Makefile diff:

```text
0
```

## Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.8A-REPORT.md
```

The report must contain:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. TASK-3.8 TOCTOU blocker explanation;
4. plain `renameat` replacement semantics;
5. exact Darwin declaration/header evidence;
6. one-helper/one-syscall-site proof;
7. `RENAME_EXCL` proof;
8. EINTR and errno preservation;
9. forward error mapping;
10. reverse error mapping;
11. empty-directory collision proof;
12. regular-file/symlink/nonempty-directory collision proof;
13. forward source/destination preservation;
14. reverse source/destination preservation;
15. no fallback proof;
16. existing post-publication proof non-regression;
17. existing rollback state-machine non-regression;
18. public-header and manager byte identity;
19. TASK-3.1 through TASK-3.7 byte identity;
20. static gate table;
21. full authorized diff;
22. at least 90 explicit scenario rows;
23. whitespace/CRLF/NUL audit;
24. build status and remaining runtime risks.

Report ending must be exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Suggested commit

```text
phase3(task-3.8A): make directory publication no-replace
```

## Stop condition

Stop after TASK-3.8A production source, report and implementation commit.

Do not implement TASK-3.9, TASK-3.10 or any later task.
