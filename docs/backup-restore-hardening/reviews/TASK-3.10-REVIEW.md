# TASK-3.10 Review

Implementation commit reviewed: `5e70a8ff5572dd343c8a16eb566277ab662e307f`

Production source review: **CHANGES_REQUESTED**

TASK-3.10 status: **CHANGES_REQUESTED**

Corrective task: **TASK-3.10A READY**

Phase 3 final status: **OPEN**

Phase 4 may open: **NO**

## Scope reviewed

```text
M AppDataBackupManager.m
A PXBackupDirectoryDiscovery.h
A PXBackupDirectoryDiscovery.m
A PXBackupStaleWorkspaceCleanup.h
A PXBackupStaleWorkspaceCleanup.m
A docs/backup-restore-hardening/reports/TASK-3.10-REPORT.md
```

The implementation scope is authorized. No protected Phase-3, Restore, UI, Keychain, runner or Makefile source changed.

## Accepted discovery implementation

The read-only discovery half is acceptable and must be preserved byte-identically by TASK-3.10A.

Verified structure:

```text
discovery public error codes:       16
public utility classes:              1
public class methods:                1
public properties:                   0
public instance methods:             0
fdopendir sites:                     1
readdir sites:                       1
F_DUPFD_CLOEXEC sites:               1
manifest validator calls/candidate:  1
NSFileManager sites:                 0
path existence sites:                0
mkdir/unlink/rename/write sites:      0
shell/process/dispatch sites:         0
```

The implementation:

- validates one to eight absolute, lossless UTF-8 roots and one safe exact bundle component;
- treats a missing root or missing bundle directory as an empty source;
- rejects existing unsafe roots or bundle directories;
- opens roots and bundle directories with no-follow/CLOEXEC descriptors;
- deduplicates physical bundle directories by device/inode with first-root precedence;
- uses one descriptor-relative enumeration implementation with exact readdir error handling;
- excludes hidden, partial, quarantine and lock namespaces from discovery;
- opens candidate directories and `manifest.plist` descriptor-relatively and no-follow;
- enforces a stable bounded 128 MiB manifest read with a 64 KiB buffer, exact byte count and extra-byte rejection;
- calls `PXBackupManifestValidator` exactly once per parsed candidate;
- accepts only exact versions 2, 3 and 4;
- requires exact manifest bundle identity;
- requires v4 directory mode 0700, manifest mode 0600, complete atomic-directory-v1 publication metadata and exact `<timestamp>-<backupID>` final-name binding;
- preserves validated v2/v3 compatibility without forcing the v4 suffix or publication fields;
- revalidates candidate, manifest, root and bundle-directory identities before returning;
- deduplicates physical backup directories and sorts newest-first with deterministic full-path tie-breaking.

The manager list method reads `_backupRoot` once, supplies current root before the legacy global root, invokes the discovery utility once, removes all old NSFileManager enumeration and returns an empty array on systemic discovery failure because the public selector has no error channel.

## Accepted stale-cleanup architecture

The stale-cleanup public surface and most of the destructive implementation are acceptable:

```text
stale-cleanup public error codes:   18
readonly properties:                 4
public factories:                    1
public cleanup methods:              1
public identity methods:             1
fdopendir / readdir sites:          1 / 1
renameatx_np / RENAME_EXCL sites:   1 / 1
plain renameat sites:                0
private syscall/dlsym sites:         0
arc4random_buf sites:                1
NSFileManager mutation sites:        0
shell/process sites:                 0
```

The factory retains the exact lock, canonical current bundle directory, descriptor and identity. It performs no enumeration or mutation. Cleanup is one-shot, runs under the retained per-bundle lock, recognizes exact partial and top-level quarantine grammars, rejects malformed reserved names, preflights exact candidate roots before mutation, sorts candidates by raw bytes and never selects a published or legacy-root directory.

Recursive cleanup is bounded, descriptor-relative, same-filesystem and post-order. It rejects symlinks, special files, hard-linked regular files, setid entries and changed identities. Nested prior-process quarantine names are processed as ordinary entries inside a proven stale root.

Regular files, subdirectories and root stale workspaces use one no-replace atomic capture helper. Destructive unlink/rmdir targets the generated private quarantine name, never the externally observed original name. Counts increment only after absence/link-state proof and strict parent durability.

The manager creates, validates and executes stale cleanup after initial lock validation and before tar/source/timestamp/workspace/output/process work. Counts are correct:

```text
bundle-lock factory:                    1
manager bundle-lock validations:        4
stale-cleanup factory:                  1
manager stale-cleanup validations:      2
manager stale-cleanup execution calls:  1
```

## Blocking finding 1 — nonreserved opaque top-level names are not ignored

The task contract states:

```text
Nonreserved entries and published directories are ignored, not deleted.
```

This requirement applies to classification of every direct child in the retained bundle directory. A direct child outside the two reserved prefixes is not stale-cleanup authority and therefore must not be required to be valid UTF-8 or otherwise converted into an NSString before it is ignored.

Current source uses the same strict UTF-8/control-name validation for both:

```text
recursive contents inside an authorized stale workspace
and
top-level direct children of the bundle directory
```

Relevant flow:

```text
PXBackupStaleWorkspaceCleanup.m:613
    PXBackupStaleWorkspaceCleanupValidateEntryName(entry->d_name, ...)

PXBackupStaleWorkspaceCleanup.m:618
    invalid name -> UnsafeReservedEntry

PXBackupStaleWorkspaceCleanup.m:1492
    initial top-level bundle scan uses that strict scanner

PXBackupStaleWorkspaceCleanup.m:1752
    final top-level validation uses that strict scanner again
```

`PXBackupStaleWorkspaceCleanupValidateEntryName` requires the raw name bytes to decode and round-trip as UTF-8 and rejects control bytes. Therefore an unrelated nonreserved direct child such as:

```text
raw bytes: 66 6f 6f ff
```

or a nonreserved name containing a control byte causes:

```text
removeStaleWorkspacesWithError -> UnsafeReservedEntry
manager aborts the new Backup
```

The entry is not deleted, but it is also not ignored. This contradicts the exact nonreserved boundary and allows an unrelated opaque filename to deny every future Backup for the bundle.

Inside a proven stale workspace, strict UTF-8/control validation remains correct because recursive deletion needs a safe exact name representation. The defect is specifically the bundle-directory top-level classification path and successful post-cleanup validation path.

## Required correction for top-level classification

TASK-3.10A must preserve one fdopendir/readdir implementation while separating two semantic modes:

```text
top-level bundle-directory classification:
    operate on bounded raw d_name bytes
    count every direct child
    detect the two ASCII reserved prefixes before NSString conversion
    ignore nonreserved names even when opaque/non-UTF8/control-containing
    reject malformed reserved-prefix names
    collect only exact ASCII reserved candidates

recursive stale-tree traversal:
    retain current strict lossless UTF-8/control validation
    fail closed on unsafe names because they would be deletion targets
```

Final post-cleanup validation must likewise scan raw top-level names for either reserved prefix and must not reject unrelated opaque nonreserved names.

No nonreserved entry may be opened, renamed, unlinked, rmdir'd, normalized or logged.

## Blocking finding 2 — failed mismatch rollback reports the wrong error code

The task contract requires:

```text
If rollback collides or cannot be proved:
- preserve both namespaces/evidence;
- return RollbackFailed or CleanupIncomplete;
- never overwrite or delete the unproven entry.
```

The namespace preservation behavior is present, but the error mapping is not.

Current exact-capture mismatch code is:

```text
PXBackupStaleWorkspaceCleanup.m:345-358

rollbackSucceeded = ...
error code =
    CleanupIncomplete when rollback failed after prior mutation
    EntryChanged otherwise
```

When this is the first candidate/first capture and rollback collides or cannot be proved:

```text
priorDestructiveMutation == NO
rollbackSucceeded == NO
returned code == EntryChanged
```

`PXBackupStaleWorkspaceCleanupErrorRollbackFailed` has zero production references. The same incorrect fallback appears in post-capture quarantine-name retention failure paths at lines 362-388: rollback failure without prior destructive mutation returns LimitExceeded rather than RollbackFailed.

The report explicitly claims scenarios 211-215 return `RollbackFailed/CleanupIncomplete`, so the report and source disagree.

## Required correction for rollback errors

TASK-3.10A must use this exact precedence wherever a successful capture must be rolled back:

```text
rollback proved:
    return the operation-specific non-mutating error
    - EntryChanged for identity mismatch
    - LimitExceeded for bounded retention/allocation failure

rollback not proved and prior destructive mutation exists:
    CleanupIncomplete

rollback not proved and no prior destructive mutation exists:
    RollbackFailed
```

`PXBackupStaleWorkspaceCleanupErrorRollbackFailed` must have an active production use. Evidence preservation, no-replace rollback, original/quarantine absence checks and strict parent synchronization must remain unchanged.

TASK-3.10A must not broaden into unrelated error-code remapping.

## Report contradiction

The TASK-3.10 report contains 285 scenario rows and ends correctly, but the following claims are not implemented by production source:

```text
scenario 161-163:
    nonreserved top-level entries are never selected/ignored

scenario 211-215:
    failed rollback returns RollbackFailed/CleanupIncomplete
```

The corrective report must add concrete raw-byte top-level cases and direct code-precedence cases rather than repeating only semantic-model assertions.

## Other reviewed properties to preserve

TASK-3.10A must keep byte-identical:

- `PXBackupDirectoryDiscovery.h/.m`;
- `PXBackupStaleWorkspaceCleanup.h` and its 18-code enum;
- `AppDataBackupManager.m`;
- all TASK-3.1 through TASK-3.9A sources;
- Restore, UI, Keychain, runner and Makefile sources.

It must preserve:

- current-root-only stale mutation;
- legacy-root read-only discovery;
- lock-not-age stale authority;
- exact partial/quarantine top-level grammar;
- malformed reserved-name fail-closed behavior;
- deterministic candidate ordering;
- top-level candidate mode 0700;
- one reusable fdopendir/readdir implementation;
- traversal limits 64 / 16384 / 255 / 8 MiB and top-level candidate limit 256;
- one random generator and one `renameatx_np(..., RENAME_EXCL)` syscall site;
- recursive strict-name validation;
- nested prior-quarantine recovery;
- file/directory/root capture-before-delete ordering;
- no original-name destructive unlink/rmdir;
- exact counters and one-shot state;
- manager lock/stale/workspace/writer/policy/manifest/publisher/funnel counts.

## Build evidence

Owner continuation is accepted as build-status confirmation. The report records portable and Apple-stat-branch strict Objective-C frontend/analyzer passes, manager harness passes and a deterministic semantic model.

Full Theos/Apple SDK arm64/arm64e linking and target-device APFS concurrent mutation/crash replay were unavailable in the coordinator workspace. The two source contradictions above are independent of build success and block Phase-3 acceptance.

## Independent gates

```text
git show --check:                         PASS
baseline diff --check:                    PASS
implementation scope:                     PASS
protected production diff:                0
discovery read-only forbidden mutations:  0
discovery fdopendir / readdir:           1 / 1
stale renameatx_np / RENAME_EXCL:        1 / 1
stale original-name destructive sites:    0
manager stale factory/validate/run:      1 / 2 / 1
manager lock validations:                 4
report scenario rows:                   285
report exact ending:                   PASS
new source/report NUL bytes:               0

nonreserved opaque top-level ignore:    FAIL
RollbackFailed production references:     0  FAIL
failed first rollback error: EntryChanged  FAIL
```

## Verdict

TASK-3.10 remains open. Discovery and manager integration are accepted as a protected foundation, but stale cleanup must distinguish opaque nonreserved top-level names from strict recursive deletion names and must emit the specified rollback-failure error.

TASK-3.10A is required before Phase 3 can close. Phase 4 remains locked.
