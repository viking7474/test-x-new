# TASK-3.10A Review

Implementation commit reviewed: `02770e21bb1b7c7d691a8ac27c3f0fefabad135b`

Production source review: **ACCEPTED**

TASK-3.10A status: **COMPLETED**

TASK-3.10 final status: **COMPLETED**

Phase 3 final status: **COMPLETED**

TASK-4.1 may open: **YES**

## Scope reviewed

```text
M PXBackupStaleWorkspaceCleanup.m
A docs/backup-restore-hardening/reports/TASK-3.10A-REPORT.md
```

The implementation commit contains exactly the authorized corrective source and report. `PXBackupStaleWorkspaceCleanup.h`, `PXBackupDirectoryDiscovery.h/.m`, `AppDataBackupManager.h/.m` and every previously accepted production file are byte-identical to the TASK-3.10 baseline.

## Corrective blocker 1 closed — raw top-level classification

The retained bundle-directory reader now has two explicit semantic modes behind one shared implementation:

```text
strict recursive names
raw top-level reserved classification
```

Independent static inventory:

```text
fdopendir implementation sites:          1
readdir implementation sites:            1
F_DUPFD_CLOEXEC sites:                    1
shared reader definitions:                1
raw top-level scan lifecycle calls:       3
strict recursive scan calls:              1
raw classifier definitions/calls:       1 / 1
strict recursive validator definitions/calls: 1 / 1
```

The raw top-level branch measures every `d_name` with the fixed 255-byte component bound and accounts every direct child against the aggregate entry and accumulated-name limits. It compares raw bytes against the two ASCII reserved prefixes before any NSString conversion:

```text
.weaponx-backup-partial-
.weaponx-cleanup-quarantine-
```

A name that does not begin either prefix is counted and ignored. It is not converted to NSString or NSData, and it is not passed to `fstatat`, `openat`, `renameatx_np`, `unlinkat` or any other child filesystem operation.

This closes the denial-of-service blocker for unrelated opaque entries such as:

```text
66 6f 6f ff
80 81 82
nonreserved name containing byte 01
255-byte opaque nonreserved component
ordinary file
.cache
published timestamp/UUID directory
```

Exact reserved grammars are checked from raw ASCII bytes:

```text
.weaponx-backup-partial-<6 ASCII alphanumeric>
.weaponx-cleanup-quarantine-<32 lowercase ASCII hex>
```

A reserved-prefix entry with invalid length, uppercase quarantine hex, nonhex suffix, control byte, invalid UTF-8 suffix or trailing byte returns `PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid` before mutation.

Initial preflight, final post-cleanup scan and successful post-cleanup identity validation all use the raw top-level mode. Therefore unrelated opaque entries remain preserved throughout the full lifecycle, while exact or malformed reserved evidence remains authoritative.

## Strict recursive deletion boundary preserved

Inside an already-proven stale workspace, the recursive branch still requires:

- component length from 1 through 255 bytes;
- neither dot nor dot-dot;
- no slash or backslash;
- no C0 control byte or DEL;
- lossless UTF-8 decoding and byte-for-byte round trip;
- bounded depth, visited-entry count and accumulated-name bytes.

An unrepresentable nested entry therefore still fails closed before deletion. The top-level raw-name exception does not broaden recursive destructive authority.

## Corrective blocker 2 closed — rollback error precedence

The implementation adds one file-local selector with three production call sites. The selector applies the exact result matrix:

```text
rollback proved:
  return operation-specific EntryChanged or LimitExceeded

rollback not proved, no prior destructive mutation:
  return RollbackFailed

rollback not proved, prior destructive mutation:
  return CleanupIncomplete
```

Independent inventory:

```text
rollback selector definitions/calls: 1 / 3
active RollbackFailed references:       1
```

The identity-mismatch site uses `EntryChanged` only after the changed entry has been restored and the rollback proof succeeds. Both quarantine-name retention/representation failure sites use `LimitExceeded` only after a proved rollback. A no-replace collision, parent-sync failure, quarantine-absence failure or original-presence proof failure is no longer mislabeled as a safely restored change.

The existing rollback mechanism is unchanged:

- original name must be absent;
- the same `renameatx_np(..., RENAME_EXCL)` helper restores quarantine to original;
- parent sync is strict;
- quarantine absence and original presence are proved;
- no overwrite-capable fallback exists;
- no unlink/rmdir is attempted after an unproved rollback;
- ambiguous namespaces are retained as evidence.

## Destructive cleanup non-regression

```text
renameatx_np implementation sites: 1
RENAME_EXCL uses:                  1
plain renameat sites:              0
arc4random_buf sites:              1
NSFileManager sites:               0
shell/process sites:               0
original-name destructive sites:   0
```

The accepted TASK-3.9A atomic capture-before-delete protocol remains unchanged for regular files, subdirectories and top-level stale roots. Counters still advance only after removal proof and strict parent durability.

## TASK-3.10 foundation non-regression

The following TASK-3.10 work remains byte-identical and accepted:

- read-only descriptor-relative discovery across current and legacy roots;
- exact manifest versions 2, 3 and 4;
- bounded stable manifest reads;
- v4 final-name binding to `<timestamp>-<backupID>`;
- v2/v3 compatibility;
- physical inode deduplication and deterministic sorting;
- manager list migration;
- stale-cleanup factory/execution ordering before current workspace creation;
- current-root-only mutation and legacy-root read-only behavior.

## Phase-3 closure

Phase 3 now provides a closed Backup lifecycle:

```text
private unique partial workspace
nonblocking per-bundle serialization
verified policy-bound artifact writes
manifest v4 with relative artifact authority
atomic durable manifest file publication
atomic no-replace whole-directory publication
centralized current-operation failure cleanup
race-safe quarantine-before-delete
validated read-only discovery
serialized stale partial/quarantine recovery
```

Published Backup directories are never stale-cleanup targets. Current-operation and prior-process cleanup both preserve unproved evidence rather than deleting a changed namespace.

## Build evidence

Owner continuation is accepted as build-status confirmation. The report records strict portable and Apple-stat Objective-C frontend/analyzer passes, a generated raw-byte classifier model and rollback-precedence model. Full Apple SDK/Theos arm64/arm64e linking and target-device APFS concurrent mutation/crash replay were unavailable to the coordinator and remain runtime gates.

No source contradiction remains.

## Independent gates

```text
git show --check:                     PASS
baseline-to-HEAD diff --check:        PASS
implementation scope:                 PASS
protected production diff:            0
public stale-cleanup error codes:     18
readonly public properties:            4
fdopendir / readdir:                 1 / 1
raw top-level lifecycle scans:          3
strict recursive scan calls:            1
active RollbackFailed references:       1
renameatx_np / RENAME_EXCL:           1 / 1
plain renameat:                         0
report scenario rows:                 262
corrective trailing whitespace:         0
corrective NUL bytes:                    0
corrective CRLF sequences:               0
```

## Verdict

TASK-3.10A is accepted. TASK-3.10 and Phase 3 are completed.

TASK-4.1 may open. Later Phase-4 tasks remain locked until TASK-4.1 acceptance.
