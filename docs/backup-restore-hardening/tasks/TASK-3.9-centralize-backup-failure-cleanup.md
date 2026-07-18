# TASK-3.9 - Centralize Backup Failure Cleanup

- Status: READY
- Phase: 3 - Atomic Backup Publication
- Baseline: `e55e9d682a4b6d6de480f277f686a81e17b7498b`
- Depends on: TASK-3.1 through TASK-3.8A accepted
- Next task: TASK-3.10 remains LOCKED

## Objective

Every failure after `PXBackupPublicationWorkspace` has been created must pass through one operation-level cleanup authority before the failure completion is delivered.

TASK-3.9 removes safely owned partial Backup trees, preserves ambiguous evidence, keeps the original operation error when cleanup succeeds, and reports a dedicated cleanup error when cleanup cannot be completed safely.

TASK-3.9 does not scan or clean old workspaces. Stale cleanup and discovery hardening remain TASK-3.10.

## Authorized production scope

Create:

```text
PXBackupFailureCleanup.h
PXBackupFailureCleanup.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.9-REPORT.md
```

The implementation commit may contain only those four files.

## Protected files

Do not modify:

```text
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
all Restore transaction/staging/resolver source
CommandRunner.h/.m
Makefile
UI/controller source
Backup discovery
Keychain helper/bridge/scripts
coordinator task/review/status/roadmap/decision/README files
```

Record SHA-256 before and after for every protected production file.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -6 --oneline
git diff --check
```

Baseline inventory that must be addressed:

```text
failure exits after workspace factory success: 33
post-workspace direct failure completions:       33
operation-level partial-tree cleanup calls:       0
successful published result paths:                1
```

## Public API

Export exactly:

```objc
PXBackupFailureCleanupErrorDomain
PXBackupFailureCleanupErrorFieldPathKey
```

Define exactly sixteen error codes without gaps:

```text
PXBackupFailureCleanupErrorInvalidInput = 1
PXBackupFailureCleanupErrorLockValidationFailed = 2
PXBackupFailureCleanupErrorParentInspectionFailed = 3
PXBackupFailureCleanupErrorWorkspaceInspectionFailed = 4
PXBackupFailureCleanupErrorWorkspaceChanged = 5
PXBackupFailureCleanupErrorUnsafeEntry = 6
PXBackupFailureCleanupErrorEntryChanged = 7
PXBackupFailureCleanupErrorLimitExceeded = 8
PXBackupFailureCleanupErrorTraversalFailed = 9
PXBackupFailureCleanupErrorRemovalFailed = 10
PXBackupFailureCleanupErrorDurabilityFailed = 11
PXBackupFailureCleanupErrorCleanupIncomplete = 12
PXBackupFailureCleanupErrorPublishedStateDetected = 13
PXBackupFailureCleanupErrorAlreadyFinished = 14
PXBackupFailureCleanupErrorDisarmValidationFailed = 15
PXBackupFailureCleanupErrorFactoryCleanupFailed = 16
```

Create one subclassing-restricted class:

```objc
PXBackupFailureCleanup
```

Readonly properties:

```objc
workspacePath
workspaceName
cleanupAttempted
cleaned
disarmed
removedEntryCount
```

Factory:

```objc
+cleanupForWorkspace:
          bundleLock:
               error:
```

Cleanup method:

```objc
-cleanupWithError:
```

Disarm method:

```objc
-disarmAfterPublishedDirectory:
                         error:
```

Identity method:

```objc
-validateIdentityWithError:
```

`init` and `new` are unavailable.

Do not expose:

- descriptors;
- recursive traversal controls;
- paths other than the retained workspace path/name;
- deletion of arbitrary paths;
- stale-cleanup APIs;
- final-directory deletion;
- automatic cleanup in `dealloc`.

## Pure cleanup boundary

`PXBackupFailureCleanup.m` may import only:

```objc
#import "PXBackupFailureCleanup.h"
#import "PXBackupPublicationWorkspace.h"
#import "PXBackupBundleLock.h"
#import "PXBackupDirectoryPublisher.h"
```

and Foundation/POSIX/C headers required for descriptor-relative traversal.

It must not import or call:

```text
AppDataBackupManager
CommandRunner
NSFileManager
UIKit
Security/Keychain
NSUserDefaults
NSTask
system/popen/posix_spawn
shell commands
dispatch
manifest builder/validator
artifact writer
manifest writer
raw path logging
global mutable state
```

## Fixed limits

Use exact fixed bounds:

```text
maximum traversal depth:        64
maximum visited entries:     16384
maximum component bytes:       255
maximum workspace path bytes: 4096
maximum accumulated name bytes: 8 MiB
```

All counters and additions must be overflow-safe.

## Factory placement and authority

Manager must create the cleanup object immediately after successful `PXBackupPublicationWorkspace` factory return and before:

- the existing initial workspace identity validation;
- artifact-writer factory;
- manifest-writer factory;
- policy construction;
- directory-publisher factory;
- output directory creation;
- debug output;
- process kill;
- every artifact producer.

The factory requires exact runtime objects:

```text
PXBackupPublicationWorkspace
PXBackupBundleLock
```

It must require:

- matching bundle identifiers;
- matching canonical bundle-directory paths;
- workspace name with exact `.weaponx-backup-partial-` prefix;
- valid retained bundle lock;
- valid workspace identity;
- canonical parent path no longer than 4096 lossless UTF-8 bytes;
- workspace path exactly `parent/workspaceName`;
- parent directory opened `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`;
- parent path/descriptor device-inode-type equality;
- no parent setuid/setgid bits;
- workspace opened descriptor-relatively under parent;
- workspace exact mode 0700;
- workspace namespace/path/descriptor device-inode-type equality;
- workspace and parent on the same filesystem;
- FD_CLOEXEC on retained descriptors.

The factory retains:

- workspace object;
- bundle-lock object;
- canonical parent path;
- exact workspace path/name;
- parent descriptor and identity;
- workspace descriptor and identity.

No output entry may be created by the cleanup factory.

## Factory failure behavior

The cleanup factory is called while the new workspace is still empty.

If factory setup fails after exact parent/workspace authority has been established:

1. prove the workspace remains the exact retained empty directory;
2. remove it with `unlinkat(parentFD, workspaceName, AT_REMOVEDIR)`;
3. strict-sync the parent;
4. return the original setup error.

If exact empty cleanup cannot be proven or completed:

- return `PXBackupFailureCleanupErrorFactoryCleanupFailed`;
- preserve the directory/evidence;
- do not recursively inspect or delete it;
- do not remove the bundle directory or lock file.

If authority was never established, fail closed and preserve evidence.

## Active identity validation

Before cleanup or disarm, `validateIdentityWithError:` must prove:

- object is neither cleaned nor disarmed;
- cleanup has not already been attempted;
- retained lock still validates;
- parent path/descriptor identity is unchanged;
- original partial name exists under retained parent;
- partial namespace maps to exact retained workspace descriptor;
- workspace remains directory, exact root mode 0700 and same filesystem;
- workspace path still maps to exact descriptor;
- final published namespace is not adopted or inspected as cleanup authority.

The object must never replace retained identities with new observations.

## Tree traversal contract

Cleanup is descriptor-relative from the retained workspace descriptor.

Use:

- `fdopendir` on a duplicated CLOEXEC descriptor;
- `readdir` with exact errno handling;
- safe single-component validation;
- `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
- `openat(..., O_NOFOLLOW|O_CLOEXEC)`;
- namespace/descriptor identity equality;
- post-order directory removal;
- strict parent-directory synchronization.

Do not construct child absolute paths.

Do not use `realpath`, path recursion, `NSFileManager`, shell deletion or process spawning.

### Supported removable entry types

Cleanup may remove only:

```text
regular files
ordinary directories
```

Regular files must be:

- opened `O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC`;
- exact namespace/descriptor identity;
- same filesystem as workspace;
- no setuid/setgid bits;
- `st_nlink == 1`;
- stable across the proof immediately before unlink.

Directories must be:

- opened `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`;
- exact namespace/descriptor identity;
- same filesystem as workspace;
- no setuid/setgid bits;
- recursively emptied within fixed limits;
- revalidated immediately before `unlinkat(..., AT_REMOVEDIR)`.

Subdirectory mode is not required to equal 0700 because baseline manager-created debug/group/preferences directories use best-effort chmod. Root workspace mode remains exactly 0700.

### Unsafe entries

Do not delete or follow:

```text
symlinks
FIFO
socket
device nodes
cross-filesystem directories/files
hard-linked files
entries with setuid/setgid bits
invalid or oversized names
entries whose identity changes during cleanup
```

Encountering any unsafe or changed entry:

- stops cleanup;
- preserves that entry and all unprocessed evidence;
- returns a bounded cleanup error;
- never falls back to path deletion.

## Regular-file removal

For each regular file:

1. `fstatat` no-follow observation;
2. independent `openat` no-follow descriptor;
3. `fstat` and exact identity/type/device/nlink/setid proof;
4. immediate namespace revalidation;
5. `unlinkat(parentFD, name, 0)`;
6. verify namespace absent;
7. verify retained descriptor link count became zero;
8. close descriptor;
9. count exactly one removed entry.

A replacement race must fail closed rather than unlink an unproven entry.

## Directory removal

For each subdirectory:

1. observe no-follow namespace identity;
2. open descriptor-relatively;
3. prove exact binding and same filesystem;
4. recursively process children;
5. rescan and require empty;
6. strict-sync the child directory;
7. revalidate child namespace/descriptor identity;
8. `unlinkat(parentFD, name, AT_REMOVEDIR)`;
9. verify namespace absent;
10. strict-sync the containing parent;
11. count exactly one removed entry.

After all workspace children are removed:

1. rescan workspace and require empty;
2. strict-sync workspace;
3. prove original partial namespace still maps to exact retained workspace;
4. remove root workspace using retained parent descriptor;
5. verify partial name absent;
6. strict-sync retained parent;
7. set `cleaned = YES` only after all proofs pass.

## Cleanup state and failure semantics

`cleanupWithError:`:

- clears the error argument;
- may be attempted only once;
- sets `cleanupAttempted = YES` before traversal begins;
- never runs after successful disarm;
- is synchronous;
- does not dispatch completion;
- does not delete a published final directory;
- does not scan sibling directories;
- does not delete the bundle lock file or bundle directory.

Success:

```text
return YES
error nil
cleaned YES
disarmed NO
partial namespace absent
```

Failure:

```text
return NO
error nonnil
cleaned NO
published/final namespace never deleted
remaining evidence preserved
```

If partial name is absent or no longer maps to the retained workspace, return `PublishedStateDetected` or `WorkspaceChanged`; never search for or delete a final timestamp/UUID directory.

A cleanup may have removed some already-proven entries before a later unsafe entry is encountered. Report this as `CleanupIncomplete`; do not synthesize rollback of already removed entries.

## Disarm contract

`disarmAfterPublishedDirectory:error:` requires exact `PXBackupDirectoryPublisher` runtime class and:

- cleanup not attempted;
- object not already cleaned/disarmed;
- publisher `isPublished == YES`;
- publisher identity validation succeeds;
- publisher workspace path equals cleanup workspace path;
- published directory path is nonempty and differs from workspace path;
- published manifest path is inside the published directory;
- original partial namespace is absent;
- retained lock still validates;
- parent identity remains unchanged.

It must not:

- open or delete the published directory;
- mutate publisher state;
- scan siblings;
- run cleanup.

On success:

```text
disarmed = YES
cleaned = NO
close cleanup-owned workspace and parent descriptors
```

A disarmed object performs no deletion in `dealloc`.

## Error privacy

Public cleanup errors may contain only:

```text
NSLocalizedDescriptionKey
PXBackupFailureCleanupErrorFieldPathKey
```

Do not include:

- backup root;
- bundle ID;
- workspace/final paths or names;
- artifact names;
- inode/device values;
- removed-entry count;
- errno text;
- nested operation errors;
- raw directory contents.

Use stable field paths such as:

```text
$.cleanup
$.cleanup.lock
$.cleanup.parent
$.cleanup.workspace
$.cleanup.entry
$.cleanup.durability
$.cleanup.publication
```

## Manager integration

Import exactly once:

```objc
#import "PXBackupFailureCleanup.h"
```

Create exactly one precise-lifetime cleanup object immediately after workspace factory success.

After the cleanup object is created, define exactly one file-local operation block in `createBackupForBundleID:...` equivalent to:

```objc
void (^completeBackupFailure)(NSError *operationError) = ^(NSError *operationError) {
    NSError *reportedError = operationError ?: <generic manager fallback>;
    NSError *cleanupError = nil;
    if (![failureCleanup cleanupWithError:&cleanupError]) {
        reportedError = cleanupError ?: <generic cleanup fallback>;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(nil, reportedError);
    });
};
```

The exact implementation may use a file-local helper plus one block, but there must be one runtime failure funnel and one cleanup call site.

### Error precedence

If cleanup succeeds:

- preserve the exact original operation NSError object;
- do not wrap or replace it;
- deliver it on the main queue exactly once.

If cleanup fails:

- deliver the exact cleanup NSError;
- do not nest the original operation error;
- preserve unsafe evidence.

If an operation branch unexpectedly supplies nil error, use:

```text
domain: PXBackupErrorDomain
code: 108
description: Backup failed without an error
```

If cleanup returns NO without an error, use:

```text
domain: PXBackupErrorDomain
code: 109
description: Backup failure cleanup failed without an error
```

## Failure funnel coverage

Route all 33 baseline failure exits after workspace factory success through the single failure funnel, including:

1. initial workspace validation;
2. artifact-writer factory/validation;
3. manifest-writer factory/validation;
4. policy construction;
5. directory-publisher factory/validation;
6. output directory creation;
7. required data producer/policy/invariant failures;
8. invalid optional policy dispositions;
9. pre-manifest policy audit;
10. v4 builder failure;
11. manager v4 validator failure;
12. pre-write artifact/workspace/lock/manifest-writer validation;
13. manifest write failure;
14. final writer/workspace/lock/artifact validation;
15. publisher pre-validation;
16. publication failure, including successful reverse rollback;
17. rollback failure/ambiguous publication state;
18. publisher post-publication validation failure.

After the cleanup object exists:

```text
direct post-workspace completion(nil, ...) sites: 0
single cleanupWithError call sites:               1
single failure-funnel definitions:                1
failure-funnel calls:                            33
```

Failures before workspace factory success keep their existing completion behavior.

The cleanup-factory failure path may complete directly because no cleanup object exists; its factory is responsible for exact empty-workspace cleanup when authority permits.

## Success path

After directory publication and the existing post-publication publisher identity validation:

1. call `disarmAfterPublishedDirectory:error:` exactly once;
2. if disarm fails, return the exact disarm error on the main queue without deleting the published directory;
3. only after disarm success construct `PXBackupResult`;
4. keep successful result paths from the directory publisher;
5. deliver success on the main queue exactly once.

Required static counts:

```text
failure cleanup factories:        1
failure cleanup validations:      1
cleanupWithError call sites:      1
disarm calls:                     1
failure-funnel definitions:       1
failure-funnel calls:            33
post-funnel direct failures:       0
successful completion calls:      1
```

## Preserve Phase-3 ordering and counts

Retain:

```text
bundle lock factory/validations:       1 / 4
workspace factory/validations:         1 / 3
artifact writer factory/validations:   1 / 3
manifest writer factory/validations:   1 / 3
manifest writer writes:                1
publisher factory/validations/publish: 1 / 3 / 1
policy constructions:                  8
artifact writes:                       8
failure-policy calls:                  8
policy audit calls:                    1
v4 builder calls:                      1
manager v4 validator calls:            1
publisher no-replace syscall sites:     1
plain publisher renameat sites:         0
```

Do not move process kill or producer ordering earlier.

## Non-regression

Keep byte-identical:

```text
PXBackupPublicationWorkspace.h/.m
PXBackupBundleLock.h/.m
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupManifestV4.h/.m
PXBackupManifestValidator.h/.m
PXBackupManifestWriter.h/.m
PXBackupDirectoryPublisher.h/.m
```

Do not change:

- public Backup selector;
- timestamp/backup UUID/final-name format;
- no-replace publication;
- artifact/component behavior;
- warning text/order;
- Preferences inclusion semantics;
- Keychain behavior;
- manifest schema v4;
- final successful paths;
- Restore;
- discovery;
- UI;
- Makefile.

## Later-task boundaries

Do not implement:

- scanning or deleting stale partial workspaces;
- age thresholds;
- recovery of rollback-failed final directories;
- discovery manifest validation;
- quarantine/index/marker files;
- cleanup of previously crashed processes;
- TASK-3.10;
- Phase 4 or later work.

TASK-3.9 handles only the current live Backup operation and only its exact retained partial workspace.

## Required test evidence

Use a temporary harness outside the repository when full iOS execution is unavailable.

At minimum test:

- empty workspace cleanup;
- nested regular files/directories;
- 64-level depth boundary;
- 16,384-entry boundary;
- accumulated-name-byte overflow;
- regular-file replacement race;
- directory replacement race;
- symlink/FIFO/socket/device rejection;
- cross-device rejection;
- hard-link rejection;
- setid rejection;
- early EOF/readdir error simulation;
- unlink/rmdir/fsync failures;
- partial cleanup followed by unsafe entry;
- published partial-name absence;
- rollback-restored partial cleanup;
- rollback-failed final evidence preservation;
- disarm success;
- disarm mismatch/failure;
- original-error preservation;
- cleanup-error precedence;
- exactly-once main-queue completion model.

## Static gates

Required implementation scope:

```text
A PXBackupFailureCleanup.h
A PXBackupFailureCleanup.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.9-REPORT.md
```

All other production diff must be zero.

Required public counts:

```text
exports:                     2
error codes:                16
cleanup classes:             1
readonly properties:         6
public factories:            1
cleanup methods:             1
disarm methods:              1
identity validation methods: 1
public descriptor properties:0
```

Required cleanup source counts:

```text
NSFileManager tokens:          0
shell/process calls:           0
absolute child-path traversal: 0
symlink following:             0
recursive root deletion APIs:  0
unlinkat sites: bounded/audited
fdopendir traversal:           1
maximum depth:                64
maximum entries:          16384
maximum name bytes:        8 MiB
```

Required manager counts:

```text
cleanup factory:                    1
cleanup validation:                 1
cleanup call site:                  1
disarm call:                        1
failure funnel definition:          1
failure funnel calls:              33
direct post-workspace failures:     0
success completion:                 1
```

## Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.9-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected hashes;
3. inventory of 33 post-workspace failure exits;
4. exact public API and sixteen errors;
5. factory placement and empty-factory-failure cleanup;
6. retained parent/workspace/lock authority;
7. fixed traversal limits;
8. descriptor-relative no-follow traversal;
9. regular-file identity/removal proof;
10. directory post-order removal proof;
11. unsafe-entry matrix;
12. partial-removal/incomplete-cleanup behavior;
13. durability and parent sync;
14. published-state preservation;
15. rollback-restored cleanup;
16. rollback-failed evidence preservation;
17. disarm contract;
18. error privacy;
19. original-error versus cleanup-error precedence;
20. one completion funnel and all 33 call sites;
21. exactly-once completion model;
22. success path and final result non-regression;
23. TASK-3.1 through TASK-3.8A byte identity;
24. Restore/discovery/UI/Makefile zero diff;
25. later-task boundaries;
26. full authorized diff;
27. static gate table;
28. at least 220 explicit scenario rows;
29. whitespace/CRLF/NUL audit;
30. build status and runtime risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff e55e9d682a4b6d6de480f277f686a81e17b7498b..HEAD --check
git diff --name-status e55e9d682a4b6d6de480f277f686a81e17b7498b..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase3(task-3.9): centralize backup failure cleanup
```

Stop after TASK-3.9.

Do not implement TASK-3.10 or any later task.
