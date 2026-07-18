# TASK-3.9A — Make Cleanup Removal Race-Safe

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Type: Corrective
- Baseline: `aa47468a1bb6944aa3ad304e24a74483f16944c3`
- Blocks: TASK-3.9 completion, TASK-3.10

## Objective

Correct two blockers found in the TASK-3.9 source review:

1. check-then-`unlinkat` removal can delete an unproven replacement entry;
2. AppDataBackupManager has 32 actual failure-funnel calls although the exact contract requires 33.

The corrective must atomically capture each exact retained entry under a private quarantine name before destructive unlink/rmdir, and restore the exact 33-call funnel inventory.

Read first:

```text
docs/backup-restore-hardening/reviews/TASK-3.9-REVIEW.md
docs/backup-restore-hardening/tasks/TASK-3.9-centralize-backup-failure-cleanup.md
```

## Authorized production scope

Only modify:

```text
PXBackupFailureCleanup.m
AppDataBackupManager.m
```

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.9A-REPORT.md
```

Implementation commit must contain exactly:

```text
M PXBackupFailureCleanup.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.9A-REPORT.md
```

## Protected files

Do not modify:

```text
PXBackupFailureCleanup.h
AppDataBackupManager.h
PXBackupPublicationWorkspace.h/.m
PXBackupBundleLock.h/.m
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupManifestV4.h/.m
PXBackupManifestValidator.h/.m
PXBackupManifestWriter.h/.m
PXBackupDirectoryPublisher.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXRestorePlan.h/.m
Restore transaction/staging/resolver source
CommandRunner.h/.m
Makefile
UI/controller source
Keychain helper/bridge/scripts
Backup discovery
coordinator task/review/status/roadmap/decision/README files
```

Record SHA-256 before and after for all protected production files.

# Part 1 — Preserve the TASK-3.9 public contract

`PXBackupFailureCleanup.h` must remain byte-identical.

Preserve:

```text
error exports:                 2
error codes:                  16
cleanup classes:               1
readonly properties:           6
public factories:              1
public cleanup methods:        1
public disarm methods:         1
public validation methods:     1
public descriptor properties:  0
```

Do not add a public quarantine API, path-deletion API, retry API or arbitrary cleanup control.

# Part 2 — Private quarantine namespace

Add a file-local exact prefix:

```text
.weaponx-cleanup-quarantine-
```

Exact generated name:

```text
.weaponx-cleanup-quarantine-<32 lowercase hexadecimal characters>
```

Generation:

- exactly 16 random bytes;
- `arc4random_buf` from the Darwin SDK surface;
- lowercase hexadecimal encoding;
- exact safe single component;
- maximum 255 bytes;
- maximum 16 collision attempts for each capture operation.

Do not expose or log the generated name.

Do not use timestamps, PIDs, counters, bundle IDs, paths or predictable process state as the suffix.

# Part 3 — One atomic no-replace move helper

Create exactly one file-local helper containing the sole `renameatx_np` call site in `PXBackupFailureCleanup.m`.

Equivalent contract:

```c
static BOOL PXBackupFailureCleanupMoveNoReplace(
    int sourceParentDescriptor,
    const char *sourceName,
    int destinationParentDescriptor,
    const char *destinationName,
    int *failureErrnoOut);
```

The helper must:

- clear `failureErrnoOut`;
- validate descriptors and nonempty names;
- call:

```c
renameatx_np(sourceParentDescriptor,
             sourceName,
             destinationParentDescriptor,
             destinationName,
             RENAME_EXCL)
```

- retry only `EINTR`;
- preserve final errno;
- perform no other namespace mutation;
- create no NSError.

Required static counts:

```text
renameatx_np implementation sites: 1
RENAME_EXCL uses:                  1
plain renameat sites:              0
move helper definitions:           1
```

Use the official Darwin SDK declaration/header. Do not use `dlsym`, private syscall numbers or an overwrite-capable fallback.

# Part 4 — Atomic capture helper

Create one file-local capture helper that:

1. generates a quarantine component;
2. atomically moves `sourceName` to quarantine with the no-replace helper;
3. retries only a quarantine destination collision (`EEXIST` or `ENOTEMPTY`) with a fresh random name, maximum 16 attempts;
4. proves the original source name is absent;
5. proves the quarantine namespace maps to the exact retained descriptor identity;
6. returns the quarantine component only after exact proof.

The capture helper must accept:

- source parent descriptor;
- source name;
- retained source descriptor;
- retained source identity;
- required source type;
- workspace device;
- optional root-mode requirement.

It must reject:

- source missing before capture;
- source replacement;
- wrong type;
- symlink;
- cross-device entry;
- setid entry;
- link-count mismatch for regular files;
- descriptor without CLOEXEC;
- quarantine collision exhaustion;
- original name still present after successful rename;
- quarantine identity mismatch.

## Capture mismatch rollback

If the no-replace move succeeds but the quarantined entry does not match the retained source identity:

1. prove original name is absent;
2. attempt no-replace move from quarantine back to original;
3. strict-sync the containing parent;
4. verify quarantine absent;
5. verify original namespace is present;
6. return `EntryChanged` without deleting either entry.

If exact rollback cannot be completed:

- return `CleanupIncomplete` when the cleanup operation has already removed an entry;
- otherwise return `EntryChanged` or `RemovalFailed` according to the failed stage;
- preserve both namespace entries/evidence;
- do not use overwrite-capable rename;
- do not unlink the quarantined mismatch.

# Part 5 — Regular-file removal

Replace direct original-name `unlinkat(parentFD, name, 0)` with:

```text
observe + open exact retained file
atomic capture original name -> random quarantine name
prove quarantined namespace == retained file descriptor
unlinkat(parentFD, quarantineName, 0)
verify quarantine absent
verify retained descriptor link count == 0
strict-sync parent
count one removed entry
```

Required properties before capture:

- regular file;
- same workspace filesystem;
- no setuid/setgid;
- `st_nlink == 1`;
- stable device/inode/type/mode/link-count/size/mtime/ctime;
- no-follow namespace/descriptor equality;
- FD_CLOEXEC.

A replacement occurring at the original name immediately before the commit operation must be moved to quarantine, detected as a mismatch and restored, never unlinked.

Do not increment `removedEntries` until:

- quarantine unlink succeeded;
- quarantine is absent;
- retained descriptor reports `st_nlink == 0`.

# Part 6 — Subdirectory removal

After the existing recursive emptying, empty rescan and strict sync:

1. retain/open exact child directory descriptor;
2. atomically capture original child name to random quarantine name;
3. prove quarantine namespace is the exact retained empty directory;
4. rescan retained directory and require empty;
5. `unlinkat(parentFD, quarantineName, AT_REMOVEDIR)`;
6. verify quarantine absent;
7. strict-sync containing parent;
8. count one removed entry.

If an empty replacement directory appears at the original name before capture:

- it must not be removed;
- mismatch rollback must restore it to the original name where possible;
- cleanup returns a bounded error.

If the exact retained directory is repopulated after capture, rmdir must fail or the empty rescan must fail; preserve evidence.

# Part 7 — Root partial-workspace removal

Apply the same atomic capture protocol to the current root partial workspace:

```text
<bundle parent>/.weaponx-backup-partial-*
    ->
<bundle parent>/.weaponx-cleanup-quarantine-<32hex>
```

Before capture preserve all existing proofs:

- workspace tree empty;
- workspace strict-sync;
- retained lock valid;
- parent identity valid;
- original partial namespace == retained workspace descriptor;
- root mode exactly 0700;
- same filesystem.

After capture:

- original partial name absent;
- quarantine namespace exact retained workspace inode;
- retained workspace still empty and mode 0700;
- remove quarantine with `AT_REMOVEDIR`;
- verify quarantine absent;
- strict-sync bundle parent;
- only then set `cleaned = YES` and close descriptors.

If a replacement appears at the original partial name before capture, do not delete it.

# Part 8 — Factory empty-workspace cleanup

`PXBackupFailureCleanupRemoveExactEmptyWorkspace` must also use atomic quarantine capture.

Factory setup failure after authority establishment:

- capture exact empty workspace to quarantine;
- verify exact retained identity;
- remove exact quarantined empty directory;
- strict-sync parent;
- return original setup error if successful.

Any capture, mismatch rollback, rmdir or durability failure returns existing:

```text
PXBackupFailureCleanupErrorFactoryCleanupFailed
```

Preserve evidence and do not recursively delete.

# Part 9 — Quarantine cleanup invariants

On successful cleanup:

```text
original names absent
all quarantine names absent
workspace removed
parent synced
cleaned == YES
```

On failed cleanup:

- do not scan unrelated siblings;
- do not delete final timestamp/UUID directories;
- preserve any quarantined evidence whose exact safe removal cannot be proven;
- report `CleanupIncomplete` when prior verified removals occurred;
- never hide failure by deleting a mismatch.

No quarantine name may be accepted as an ordinary output artifact or final backup name.

TASK-3.10 will own prior-process quarantine/stale recovery. TASK-3.9A handles only names created by the current cleanup call.

# Part 10 — Restore exact 33 funnel call sites

In `AppDataBackupManager.m`, replace the merged initial stage:

```text
initialFailureCleanupIdentityError
initialWorkspaceIdentityError
initialCleanupStageError
one funnel call
```

with two sequential exact branches:

1. failure-cleanup identity validation failure -> one `completeBackupFailure` call and return;
2. workspace identity validation failure -> one separate `completeBackupFailure` call and return.

Preserve ordering:

```text
cleanup object factory
cleanup identity validation
workspace identity validation
artifact writer factory
```

Required manager counts:

```text
failure-funnel definitions:             1
actual failure-funnel calls:           33
cleanupWithError manager call sites:    1
disarm manager call sites:              1
post-workspace direct failure delivery: 0
```

Do not count the block definition as a call.

Preserve exact NSError objects and main-queue completion behavior.

# Part 11 — Preserve TASK-3.9 semantics

Do not change:

- public cleanup header;
- error-code numbering;
- factory placement;
- retained parent/workspace/lock authority;
- traversal limits 64 / 16384 / 255 / 4096 / 8 MiB;
- one fdopendir/readdir traversal implementation;
- symlink/special-file/hard-link/setid/cross-device rejection;
- partial cleanup error precedence;
- published-state detection;
- final-directory preservation;
- success-path disarm;
- no cleanup in dealloc;
- original operation error when cleanup succeeds;
- cleanup error when cleanup fails;
- fallback manager errors 108 and 109.

# Part 12 — Phase-3 non-regression

Preserve exact counts:

```text
bundle lock factory / validations:        1 / 4
workspace factory / validations:          1 / 3
artifact writer factory / validations:    1 / 3
manifest writer factory / validations:    1 / 3
manifest writer writes:                   1
publisher factory / validations / publish:1 / 3 / 1
policy constructions:                     8
artifact writes:                          8
failure-policy calls:                     8
policy audit calls:                       1
v4 builder calls:                         1
manager validator calls:                  1
publisher renameatx_np sites:             1
publisher plain renameat sites:           0
```

All TASK-3.1 through TASK-3.8A infrastructure must remain byte-identical.

Do not change:

- public Backup selector;
- timestamp/UUID/final name;
- warning text/order;
- Preferences semantics;
- Keychain behavior;
- manifest v4;
- successful final paths;
- Restore;
- discovery;
- UI;
- Makefile.

# Part 13 — Forbidden scope

Do not implement:

- stale partial scanning;
- age thresholds;
- prior-process quarantine cleanup;
- rollback-failed final recovery;
- discovery validation;
- quarantine markers/indexes;
- TASK-3.10;
- Phase 4 or later work.

# Static gates

Required scope:

```text
M PXBackupFailureCleanup.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.9A-REPORT.md
```

Required cleanup source counts:

```text
private quarantine prefix definitions: 1
16-byte random suffix generation:      1
no-replace move helper definitions:    1
renameatx_np sites:                    1
RENAME_EXCL uses:                      1
plain renameat sites:                  0
original-name regular unlink sites:    0
original-name directory rmdir sites:   0
quarantine regular unlink sites:       1
quarantine directory rmdir sites:      audited helper usage
NSFileManager deletion sites:          0
shell/process deletion sites:          0
```

Required manager counts:

```text
failure-funnel definitions: 1
failure-funnel calls:      33
cleanupWithError sites:     1
disarm sites:               1
```

# Test and fault matrix

Use an external temporary harness where required. At minimum cover:

- regular file normal capture/delete;
- regular file replacement immediately before capture;
- symlink replacement before capture;
- hard-link replacement before capture;
- quarantine collision retries 0, 1 and 16;
- capture succeeds but identity mismatches;
- mismatch rollback succeeds;
- mismatch rollback destination collision;
- quarantine unlink failure;
- retained descriptor nlink remains nonzero;
- subdirectory normal capture/rmdir;
- empty directory replacement before capture;
- exact directory repopulated after capture;
- root partial normal capture/rmdir;
- root replacement before capture;
- factory empty cleanup success/failure;
- strict parent fsync failures;
- removed-entry count timing;
- CleanupIncomplete precedence;
- exact 33 manager funnel calls;
- valid success/disarm path unchanged.

Use `@try/@catch` around public Objective-C entry points in malformed input tests. No exception may escape.

# Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.9A-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected hashes;
3. TASK-3.9 review blockers;
4. check-to-unlink race explanation;
5. private quarantine-name contract;
6. Darwin SDK declaration proof;
7. one no-replace helper/one syscall site;
8. random generation and collision bounds;
9. atomic capture protocol;
10. mismatch rollback protocol;
11. regular-file removal proof;
12. subdirectory removal proof;
13. root workspace removal proof;
14. factory cleanup proof;
15. quarantine failure/evidence preservation;
16. removed-entry count timing;
17. strict durability;
18. exact 33-call manager inventory;
19. error precedence/exactly-once completion;
20. public header byte identity;
21. TASK-3.1 through TASK-3.8A byte identity;
22. Restore/discovery/UI/Makefile zero diff;
23. full authorized diff;
24. static gate table;
25. at least 140 explicit scenario rows;
26. whitespace/CRLF/NUL audit;
27. build status and remaining runtime risks.

Report ending must be exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff aa47468a1bb6944aa3ad304e24a74483f16944c3..HEAD --check
git diff --name-status aa47468a1bb6944aa3ad304e24a74483f16944c3..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase3(task-3.9A): make cleanup removal race safe
```

Stop after TASK-3.9A. Do not implement TASK-3.10 or any later task.
