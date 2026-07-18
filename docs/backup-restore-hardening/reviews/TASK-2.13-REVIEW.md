# TASK-2.13 Review

Implementation commit reviewed: `08d23dd0a9fa41a39efd5b62680974f23e75fe45`

Baseline: `9e83a053c4d4e2e42e0eac0a207467a5df2b3251`

Production source review: **CHANGES_REQUESTED**

Final status: **CHANGES_REQUESTED**

Corrective task: `TASK-2.13A-fix-missing-directory-tree-verifier.md`

## Scope reviewed

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXOptionalRestoreTransaction.h
A PXOptionalRestoreTransaction.m
A docs/backup-restore-hardening/reports/TASK-2.13-REPORT.md
```

Protected production files are unchanged.

`git show --check` and the cumulative baseline diff check both pass.

## Accepted architecture

The optional transaction architecture is otherwise aligned with the TASK-2.13 contract:

- exactly three public item kinds;
- exactly eighteen public error codes;
- immutable `PXOptionalRestoreTransactionItem`;
- one transaction factory and one one-shot commit method;
- descriptor-bound destination authority;
- physical authority-directory lock collapse;
- deterministic item and authority ordering;
- complete current item/lock/stage proof before stale recovery;
- strict synchronization with no unsupported-error-as-success branch;
- one leader journal with the required six phases;
- domain-scoped rollback rather than false whole-Restore atomicity;
- exact initial-absence rollback for directory/file objects;
- leader-last cleanup;
- profile AppData, global Safari, system-global, shared DB and Preferences manager migration;
- Keychain remains outside filesystem transaction and continues to receive only staged input;
- accepted main and App Group transaction files remain byte-identical.

Manager static review confirms that the Restore path no longer uses the legacy optional mutation authority:

```text
profile direct wipe:       0
Safari direct wipe:        0
WeaponXTrash:              0
optional shell mv:         0
optional shell mkdir:      0
optional shell cp authority: 0
```

## Blocking finding

### `PXOptionalRestoreVerifyDirectoryTree` has call sites but no implementation

`PXOptionalRestoreTransaction.m` calls:

```objc
PXOptionalRestoreVerifyDirectoryTree(...)
```

at two locations:

```text
line 2316 — DirectoryObject replacement preparation
line 2866 — no-journal replacement verification
```

Independent repository-wide search found no declaration or definition in any production source or header.

Static count:

```text
PXOptionalRestoreVerifyDirectoryTree call sites:   2
file-local definitions:                            0
repository production definitions:                 0
```

A prefix call-graph scan found no other missing private `PXOptionalRestore*` function. The only unresolved private function is `PXOptionalRestoreVerifyDirectoryTree`.

This is a release blocker for two reasons:

1. a strict Objective-C frontend should reject the undeclared function call;
2. even if a permissive frontend accepts an implicit external declaration, the final link has no symbol implementation to resolve.

The report states that a temporary-stub frontend parse returned exit 0, but no real Theos/iOS link was run. That parse result cannot prove the missing symbol is linkable.

## Security consequence

The missing function is not only a build detail. It is the required proof that a prepared `DirectoryObject` replacement still exact-matches the accepted `PXValidatedMainDataStage` before publication or no-journal cleanup.

Without a real implementation, the code cannot prove:

- deterministic replacement-tree digest;
- exact entry/file/directory counts;
- exact regular-file byte count;
- no symlink, hard link, device, FIFO or socket;
- no mount crossing;
- no setuid/setgid entry;
- no forbidden container metadata;
- no reserved optional transaction prefix;
- path/depth/resource limits;
- descriptor and file stability during traversal.

## Required correction

TASK-2.13A must add one file-local implementation with exact semantics equivalent to:

```objc
static BOOL PXOptionalRestoreVerifyDirectoryTree(
    int rootDescriptor,
    PXValidatedMainDataStage *expectedStage,
    NSError **error);
```

The verifier must reproduce the exact deterministic staged-tree format owned by `PXMainDataStaging`:

```text
domain prefix: "PXMainDataStageTreeV1" including terminating NUL
entry type:    one byte D or F
path length:   uint32 big-endian
path bytes:    exact UTF-8 relative path bytes
mode:          uint32 big-endian of mode & 07777
size:          uint64 big-endian
file content:  raw bytes immediately after a file header
```

It must compare all accepted snapshot fields:

```text
entryCount
regularFileCount
directoryCount
regularFileBytes
treeSHA256
```

No public API, manager integration or accepted transaction state machine may change.

## Independent gates

```text
public item kinds:                    3
public error codes:                  18
public item factories:                3
transaction factories:                1
commit methods:                       1
public readwrite properties:          0
protected production diff:            0
pure transaction forbidden tokens:    0
report explicit scenarios:          340+
new-file trailing whitespace:         0
new-file NUL bytes:                   0
missing verifier calls:               2
missing verifier definitions:         0
```

`AppDataBackupManager.m` retains 17 pre-existing trailing-whitespace lines; TASK-2.13 does not add new trailing whitespace.

## Build gate

Project-owner continuation is accepted as a build-status signal, but it does not override the independently proven unresolved production symbol. No GitHub Actions artifact or linked Theos binary is present in the workspace for replay.

## Decision

TASK-2.13 is not accepted.

TASK-2.14 remains locked.

Open the narrow one-file corrective task TASK-2.13A.