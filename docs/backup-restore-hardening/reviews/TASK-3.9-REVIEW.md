# TASK-3.9 Review

Implementation commit reviewed: `aa47468a1bb6944aa3ad304e24a74483f16944c3`

Production source review: **CHANGES_REQUESTED**

TASK-3.9 status: **CHANGES_REQUESTED**

Corrective task: **TASK-3.9A READY**

TASK-3.10 may open: **NO**

## Scope reviewed

```text
M AppDataBackupManager.m
A PXBackupFailureCleanup.h
A PXBackupFailureCleanup.m
A docs/backup-restore-hardening/reports/TASK-3.9-REPORT.md
```

The implementation scope is authorized and no protected production file changed.

## Accepted structure

The implementation correctly establishes most of the operation-cleanup architecture:

```text
public cleanup error codes:          16
readonly public properties:           6
public factories:                     1
public cleanup methods:               1
public disarm methods:                1
public identity methods:              1
fdopendir sites:                      1
readdir sites:                        1
NSFileManager deletion sites:         0
shell/process deletion sites:         0
cleanupWithError manager sites:       1
disarm manager sites:                 1
report scenario rows:               281
```

The cleanup object is created immediately after workspace creation and before writer factories, output creation, debug output, process kill and producers. It retains the exact parent/workspace descriptors and identities, validates the bundle lock, uses bounded descriptor-relative traversal, rejects symlinks/special files/hard links/setid/cross-device entries, performs post-order directory processing and never deletes a final timestamp/UUID directory.

The manager has one failure funnel and preserves the original operation NSError when cleanup succeeds. Cleanup errors take precedence when cleanup fails. Successful publication is explicitly disarmed before result construction.

## Blocking finding 1 — final unlink commit is still replacement-race unsafe

The task contract requires:

```text
A replacement race must fail closed rather than unlink an unproven entry.
```

Current regular-file removal performs:

```text
fstatat no-follow
openat no-follow
fstat descriptor
immediate namespace/descriptor revalidation
unlinkat(parentFD, name, 0)
post-unlink retained-descriptor proof
```

The final namespace proof and `unlinkat` are separate filesystem operations. A concurrent actor can rename the proven file away and put a different regular file at the same name after the final `fstatat` but before `unlinkat`.

In that interleaving:

```text
unlinkat deletes the replacement entry
retained original descriptor remains linked elsewhere
post-check detects failure only after the unproven entry was deleted
```

The source confirms this ordering:

```text
PXBackupFailureCleanup.m:449-454  final namespace/descriptor proof
PXBackupFailureCleanup.m:473      unlinkat(parentDescriptor, name, 0)
PXBackupFailureCleanup.m:482      removedEntries increment
PXBackupFailureCleanup.m:484-488  post-unlink retained descriptor proof
```

The same check-to-unlink gap exists for:

```text
subdirectory removal
root workspace removal
factory empty-workspace cleanup
```

A replacement empty directory can be removed by `unlinkat(..., AT_REMOVEDIR)` before the implementation notices that the retained original directory was moved elsewhere.

This contradicts the report's replacement-race claim and the task requirement to preserve changed/unproven entries.

## Required correction

Deletion must capture the exact current namespace entry before destructive unlink.

The corrective implementation must:

1. Generate an unpredictable same-parent quarantine component.
2. Atomically move source name to quarantine name using `renameatx_np(..., RENAME_EXCL)`.
3. Prove the quarantined namespace is the exact retained descriptor identity.
4. If identity differs, no-replace rollback the quarantined entry to the original name and return a cleanup error without deleting it.
5. Only unlink/rmdir the proven quarantined identity.
6. Verify quarantine absence, retained descriptor unlink state and strict parent durability.

This protocol must cover regular files, subdirectories, the root partial workspace and factory empty-workspace cleanup. Plain check-then-unlink at an externally visible original name is not sufficient.

## Blocking finding 2 — exact failure-funnel call count is false

The TASK-3.9 static contract requires:

```text
failure-funnel definitions: 1
failure-funnel calls:      33
cleanupWithError sites:     1
```

Current source has 33 textual `completeBackupFailure(` occurrences only when the block definition is counted. Actual call sites are **32**.

The two baseline initial failures:

```text
failureCleanup validateIdentity failure
publicationWorkspace validateIdentity failure
```

were merged into one `initialCleanupStageError` branch and one funnel call.

Independent count:

```text
funnel definitions: 1
actual funnel calls: 32
report claim:        33
```

The runtime behavior is reasonable, but it does not meet the exact audited-call contract and makes the report's static table inaccurate.

The corrective must restore separate branches and separate funnel calls while keeping the same ordering and error identities.

## Other reviewed properties

The following remain acceptable and must be preserved by TASK-3.9A:

- exact public header and 16-code enum;
- factory placement immediately after workspace creation;
- parent/workspace/lock retained authority;
- limits 64 / 16384 / 255 / 4096 / 8 MiB;
- one fdopendir/readdir traversal implementation;
- no absolute child paths or path-recursive deletion;
- unsafe-entry rejection;
- partial cleanup reported as CleanupIncomplete;
- root workspace mode 0700;
- published-state detection and final-directory preservation;
- one cleanupWithError manager site;
- exact operation-error/cleanup-error precedence;
- main-queue exactly-once completion model;
- explicit success-path disarm;
- no dealloc deletion;
- TASK-3.1 through TASK-3.8A byte identity;
- Restore, discovery, UI and Makefile zero diff.

## Build evidence

Owner continuation is accepted as build-status confirmation. The report records local strict frontend/analyzer and deterministic state-model passes. Full Apple SDK/Theos linking and target-device APFS race replay were not available to the coordinator.

The source contradiction above is independent of build success and blocks acceptance.

## Independent gates

```text
git show --check:                 PASS
baseline diff --check:            PASS
implementation scope:             PASS
protected production diff:        0
public error codes:              16
fdopendir / readdir:            1 / 1
cleanupWithError manager sites:   1
actual failure-funnel calls:     32  FAIL
atomic quarantine rename sites:   0  FAIL
check-then-unlink removal sites:   4  FAIL
report scenario rows:           281
new cleanup trailing whitespace:  0
new cleanup NUL bytes:             0
```

## Verdict

TASK-3.9 remains open. TASK-3.9A must make destructive removal identity-safe at the commit boundary and restore the exact 33-call funnel contract.

TASK-3.10 remains locked.
