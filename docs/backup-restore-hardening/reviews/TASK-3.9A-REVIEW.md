# TASK-3.9A Review

Implementation commit reviewed: `aa01f73b761682f3142c10b03ad5ff792331e68e`

Production source review: **ACCEPTED**

TASK-3.9A final status: **COMPLETED**

TASK-3.9 final status: **COMPLETED**

TASK-3.10 may open: **YES**

## Scope reviewed

```text
M AppDataBackupManager.m
M PXBackupFailureCleanup.m
A docs/backup-restore-hardening/reports/TASK-3.9A-REPORT.md
```

The implementation commit contains no production file outside the corrective scope. `PXBackupFailureCleanup.h`, the TASK-3.1 through TASK-3.8A infrastructure, Restore source, discovery source, UI, Keychain helpers and Makefile are unchanged.

## Corrective objective

TASK-3.9A had two blockers to close:

1. TASK-3.9 performed final namespace revalidation followed by a separate `unlinkat`, so a replacement could appear in the final check-to-unlink gap and be deleted before the postcondition detected the mismatch.
2. The TASK-3.9 report claimed 33 failure-funnel calls while its source had only 32 invocation sites.

Both blockers are closed by this commit.

## Atomic no-replace capture

`PXBackupFailureCleanup.m` now contains one namespace-move authority:

```c
renameatx_np(sourceParentDescriptor,
             sourceName,
             destinationParentDescriptor,
             destinationName,
             RENAME_EXCL)
```

Independent counts:

```text
renameatx_np implementation sites: 1
RENAME_EXCL uses:                  1
plain renameat sites:              0
dlsym/private syscall sites:       0
overwrite-capable fallbacks:       0
```

The helper retries only `EINTR`, preserves the final errno and performs no alternate namespace mutation.

## Private quarantine namespace

The exact private prefix is:

```text
.weaponx-cleanup-quarantine-
```

Each generated name contains exactly 32 lowercase hexadecimal characters derived from 16 bytes supplied by one `arc4random_buf` site. Destination-name collisions are retried for at most 16 attempts. PID, timestamp, counters, bundle identifiers and paths are not used in the name.

The implementation has one capture-helper definition and four semantic capture call sites:

```text
regular file
subdirectory
factory empty-workspace cleanup
main root-workspace cleanup
```

## Mismatch rollback and evidence preservation

After the no-replace move, capture succeeds only if:

- the original name is absent;
- the quarantine namespace maps to the retained descriptor identity;
- type, filesystem, safety bits and required mode/link constraints remain valid.

If the object moved into quarantine does not equal the retained object, it is never unlinked. When the original name remains absent, the same no-replace helper attempts to restore the quarantine entry to its original name, strict-syncs the parent and proves the quarantine name absent. A rollback collision or unprovable rollback preserves both namespaces as evidence and returns a bounded cleanup error.

This closes the replacement race because destructive unlink/rmdir never targets the externally observed original name.

## Regular-file removal

The accepted order is:

```text
observe/open/stable identity proof
atomic original -> quarantine capture
quarantine/retained-descriptor equality proof
unlink quarantine name
quarantine absence proof
retained descriptor nlink == 0 proof
strict parent fsync
removedEntryCount increment
```

A replacement immediately before capture is moved to quarantine, detected as mismatched and restored or preserved. It is not destructively unlinked.

## Subdirectory removal

After bounded post-order child cleanup, the retained directory is rescanned empty and strict-synced. The original child name is then captured to quarantine, rebound to the retained descriptor, rescanned empty and removed only through the quarantine name. Parent synchronization and absence proof precede the public removal-count increment.

An empty or nonempty replacement at the original name is not an `AT_REMOVEDIR` target.

## Root and factory cleanup

The current partial workspace is removed only after:

- bundle-lock validation;
- parent and workspace identity proof;
- exact root mode `0700`;
- same-filesystem proof;
- empty rescan;
- strict workspace synchronization;
- atomic partial-name-to-quarantine capture;
- exact retained root binding under the quarantine name.

Only the quarantine name is passed to `unlinkat(..., AT_REMOVEDIR)`. The implementation proves both original and quarantine names absent and strict-syncs the parent before setting `cleaned = YES` and closing descriptors.

Factory failure cleanup uses the same capture-before-delete protocol. Failure to capture, prove, remove or synchronize returns `FactoryCleanupFailed` and preserves evidence.

## Original-name deletion audit

```text
quarantined regular-file unlink sites: 1
quarantined directory rmdir sites:     3
original-name unlink/rmdir sites:      0
NSFileManager deletion sites:          0
shell/process deletion sites:          0
```

Pre-existing quarantine-prefix entries encountered during ordinary live traversal are rejected and preserved. Recovery of previous-process quarantine entries remains TASK-3.10.

## Failure funnel

The manager now contains:

```text
failure-funnel definitions:      1
actual invocation sites:        33
cleanupWithError call sites:     1
disarm call sites:               1
initialCleanupStageError tokens: 0
```

The 33 invocation sites consist of 32 normal block calls and one semantically equivalent parenthesized block invocation. The block definition is not counted as a call.

Cleanup-object identity validation and publication-workspace identity validation are separate sequential failure branches. The later artifact-writer factory/initial-validation stage remains mutually exclusive and preserves the exact underlying NSError object.

The common funnel still preserves the original operation NSError after successful cleanup, gives cleanup NSError precedence after incomplete cleanup, uses fallback codes 108/109 only for impossible nil-error states and dispatches completion on the main queue exactly once.

## Non-regression

The following contracts remain unchanged:

```text
public cleanup header and 16 error codes
cleanup factory placement
64-level depth limit
16,384-entry traversal limit
255-byte component limit
4,096-byte workspace-path limit
8-MiB accumulated-name limit
one fdopendir/readdir traversal
unsafe-entry rejection
published-state preservation
success-path disarm
no deletion in dealloc
bundle lock/workspace/artifact/manifest/publisher counts
manifest v4 and final published paths
Preferences and Keychain behavior
Restore and discovery
UI and Makefile
```

## Independent gates

```text
git show --check:                    PASS
baseline-to-HEAD diff --check:       PASS
implementation scope:                PASS
protected production diff:           0
private quarantine prefix:           1
arc4random_buf sites:                 1
atomic no-replace syscall sites:      1
capture call sites:                   4
original-name destructive sites:      0
actual failure-funnel invocations:   33
report numbered scenario rows:      271
new report/source NUL bytes:           0
new report/source trailing spaces:     0
```

The report records strict Objective-C frontend/analyzer checks and a deterministic quarantine model. Full Apple SDK/Theos linking and target-device APFS race/fault replay are not locally available. The owner continuation is accepted as build-status confirmation because no source contradiction remains.

## Final decision

TASK-3.9A is accepted. Its atomic capture protocol closes the TASK-3.9 replacement-race blocker, and the manager now has the required 33 actual failure-funnel invocation sites. TASK-3.9 and TASK-3.9A are completed. TASK-3.10 may open; Phase 4 remains locked until TASK-3.10 acceptance.
