# TASK-3.8 Review

Implementation commit reviewed: `494cae02f042bb0e115fa780f2683e124467fda9`

Production source review: **CHANGES_REQUESTED**

Parent task status: **CHANGES_REQUESTED**

TASK-3.9 may proceed: **NO**

## Scope reviewed

```text
M AppDataBackupManager.m
A PXBackupDirectoryPublisher.h
A PXBackupDirectoryPublisher.m
A docs/backup-restore-hardening/reports/TASK-3.8-REPORT.md
```

The implementation commit contains only the four authorized files. `git show --check` and baseline-to-HEAD `git diff --check` pass. No protected Phase-0 through Phase-3 production source changed.

Owner continuation is accepted as build-status confirmation. The repository does not contain a linked Theos/iOS artifact or target-filesystem race fixture that the coordinator can replay independently.

## Accepted implementation areas

The following TASK-3.8 work is structurally correct and should be retained by the corrective task:

- exact 18-code public error enum;
- one subclassing-restricted publisher with seven readonly properties;
- strict UTC timestamp and canonical lowercase UUID validation;
- final name `<timestamp>-<backup UUID>`;
- retained parent and workspace descriptors;
- exact parent/workspace device-inode-type authority;
- lock/workspace/writer readiness validation;
- one file-local rename helper shared by forward publication and reverse rollback;
- strict workspace and parent synchronization;
- independently opened final directory and manifest descriptors;
- exact final manifest size, SHA-256, validator and deep-snapshot replay;
- acceptance only after post-rename proof;
- reverse rollback to the original partial name on post-rename failure;
- successful result paths sourced only from the directory publisher;
- zero discovery, Restore, UI, Makefile or earlier Phase-3 source diff.

Static evidence:

```text
publisher error codes:          18
readonly properties:             7
publisher factories:             1
publisher validations:           3
publisher publish calls:         1
forward helper calls:            1
reverse helper calls:            1
plain renameat call sites:        1
atomic no-replace rename sites:   0
partial successful result paths:  0
published successful paths:       1
report scenario rows:           312
```

## Blocking finding: final-name collision is not atomically excluded

The implementation checks that the destination name is absent immediately before publication, then executes plain `renameat`:

```objc
if (!PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes)) {
    ...
}

PXBackupDirectoryRenameEntry(
    _parentDescriptor,
    workspaceNameBytes,
    _parentDescriptor,
    publishedNameBytes);
```

The helper contains:

```objc
renameat(sourceParentDescriptor,
         sourceName,
         destinationParentDescriptor,
         destinationName);
```

This does not implement the specified no-overwrite contract.

There is a time-of-check/time-of-use interval between the final absence proof and the rename syscall. If another actor creates an empty destination directory during that interval, plain directory `renameat` may replace that empty directory. The post-rename identity checks then observe the retained workspace inode at the final name and can accept publication. The competing directory has already been removed by the rename operation.

Consequences:

```text
FinalDirectoryAlreadyExists contract: not guaranteed at commit point
no-overwrite contract:                not guaranteed
competing empty directory:             may be replaced
report claim “there is no overwrite”:  unsupported
```

The UUID suffix makes accidental collision unlikely, but uniqueness probability is not a filesystem no-clobber authority. The code explicitly treats the parent namespace as untrusted and must therefore close the race at the rename syscall itself.

The same issue applies to reverse rollback. After proving that the original partial name is absent, plain `renameat` can replace a competing empty directory created at the original partial name before the reverse syscall. Rollback must preserve evidence rather than overwrite a competing entry.

## Required correction

Open corrective TASK-3.8A with production scope limited to:

```text
PXBackupDirectoryPublisher.m
```

The corrective task must:

- replace plain `renameat` with Darwin atomic no-replace rename semantics;
- use the same no-replace helper for forward and reverse operations;
- retry only `EINTR`;
- map forward destination collision to `FinalDirectoryAlreadyExists`;
- map reverse destination collision to `RollbackFailed`;
- never fall back to plain overwrite-capable `renameat`;
- preserve the exact public header, manager integration, result paths, manifest replay and rollback state machine;
- add deterministic race/collision proof covering regular files, symlinks, nonempty directories and empty directories appearing at the destination immediately before the syscall.

## Independent gates

```text
implementation scope:              PASS
git show --check:                  PASS
baseline diff --check:             PASS
protected production diff:          0
public API shape:                   PASS
final naming:                       PASS
retained descriptor authority:      PASS
manifest replay:                    PASS
reverse rollback structure:         PASS
atomic no-replace forward rename:    FAIL
atomic no-replace reverse rename:    FAIL
report no-overwrite claim:           FAIL
```

## Verdict

TASK-3.8 is **CHANGES_REQUESTED**.

TASK-3.8A must be accepted before TASK-3.8 can become COMPLETED. TASK-3.9 remains locked.
