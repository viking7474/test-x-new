# TASK-3.8A Review

Implementation commit reviewed: `e55e9d682a4b6d6de480f277f686a81e17b7498b`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-3.8 final status: **COMPLETED**

TASK-3.9 may open: **YES**

## Scope

Authorized implementation diff:

```text
M PXBackupDirectoryPublisher.m
A docs/backup-restore-hardening/reports/TASK-3.8A-REPORT.md
```

All protected production files are byte-identical to baseline `494cae02f042bb0e115fa780f2683e124467fda9`, including:

```text
PXBackupDirectoryPublisher.h
AppDataBackupManager.h/.m
PXBackupPublicationWorkspace.h/.m
PXBackupBundleLock.h/.m
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupManifestV4.h/.m
PXBackupManifestValidator.h/.m
PXBackupManifestWriter.h/.m
Restore source
Backup discovery
UI/controller source
CommandRunner.h/.m
Makefile
Keychain helper/bridge/scripts
```

## Corrective finding closed

TASK-3.8 used a separate destination-absence observation followed by plain `renameat`. That sequence did not make no-overwrite behavior atomic: a competing empty directory could appear after the observation and be replaced by the rename operation.

TASK-3.8A replaces the overwrite-capable operation with the Darwin no-replace primitive:

```c
renameatx_np(sourceParentDescriptor,
             sourceName,
             destinationParentDescriptor,
             destinationName,
             RENAME_EXCL)
```

The operation itself now owns collision exclusion.

## Exact helper contract

Source contains exactly one helper:

```text
PXBackupDirectoryRenameEntryNoReplace
```

It:

- clears the optional errno output;
- rejects invalid descriptors or empty names;
- calls `renameatx_np` at exactly one production site;
- always passes `RENAME_EXCL`;
- retries only `EINTR`;
- returns the final errno without creating an NSError;
- performs no alternate namespace mutation.

Independent static counts:

```text
stdio SDK header imports:          1
no-replace helper definitions:     1
renameatx_np implementation sites: 1
RENAME_EXCL uses:                  1
plain renameat sites:              0
forward helper calls:              1
reverse helper calls:              1
EINTR retry predicates:            1
dlsym sites:                        0
private syscall sites:              0
NSFileManager move/copy/delete:      0
shell/process fallbacks:             0
```

## Forward publication

Forward no-replace failure is mapped as follows:

```text
EEXIST / ENOTEMPTY
  -> PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists

all other errno values
  -> PXBackupDirectoryPublisherErrorPublicationFailed
```

On collision:

- `forwardRenamed` remains false;
- reverse rollback is not entered;
- the partial source remains unchanged;
- the competing destination remains unchanged;
- `published` remains false.

The protected collision types include:

```text
regular file
symlink
FIFO/socket/device
nonempty directory
empty directory
entry created after final precheck
entry removed and recreated between precheck and syscall
```

The empty-directory TOCTOU blocker is therefore closed at the syscall boundary.

## Reverse rollback

Reverse rollback uses the same no-replace helper.

If a competing entry occupies the original partial name at reverse-rename time:

- the final directory remains unchanged;
- the competing partial entry remains unchanged;
- no entry is deleted or replaced;
- the publisher returns the existing `RollbackFailed` error.

Successful reverse rollback retains the accepted TASK-3.8 behavior:

- strict parent sync;
- final name absent;
- original partial name restored to the retained workspace inode;
- `published == NO`;
- original publication error returned.

## No fallback

There is no fallback to:

```text
plain renameat
rename
NSFileManager move/copy/delete
shell mv
copy-then-delete
private syscall numbers
dlsym resolution
```

The project target is iOS 12 and the implementation includes the Darwin SDK surface declaring `renameatx_np` and `RENAME_EXCL`. If that surface is unavailable to the authoritative Apple SDK build, compilation fails rather than silently reducing the publication guarantee.

## TASK-3.8 non-regression

The corrective commit does not alter:

- public 18-code publisher API;
- timestamp/UUID/final-name validation;
- retained parent/workspace authority;
- artifact and manifest readiness checks;
- post-rename final-directory proof;
- manifest digest/validator/equality replay;
- published/unpublished identity validation;
- error privacy;
- manager ordering and successful final paths;
- discovery, Restore, UI or packaging behavior.

## Evidence

Report:

```text
docs/backup-restore-hardening/reports/TASK-3.8A-REPORT.md
```

Independent gates:

```text
git show --check:                 PASS
baseline-to-HEAD diff --check:    PASS
implementation scope:             PASS
protected production diff:        0
explicit scenario rows:         117
new trailing whitespace:          0
new NUL bytes:                    0
```

The report records strict local Objective-C frontend/analyzer success using external Foundation/POSIX and Darwin SDK-surface stubs, plus a deterministic syscall model for forward and reverse races. Full Apple SDK compile/link and target APFS race replay remain pending. Owner continuation is accepted as build-status confirmation, and no production-source evidence contradicts it.

## Conclusion

TASK-3.8A is accepted. The no-overwrite contract is now enforced by the filesystem commit operation rather than inferred from a precheck.

TASK-3.8 and TASK-3.8A are COMPLETED. TASK-3.9 may open. TASK-3.10 and later phases remain locked.
