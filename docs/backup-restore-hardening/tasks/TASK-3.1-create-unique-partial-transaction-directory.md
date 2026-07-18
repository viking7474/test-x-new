# TASK-3.1 — Create Unique Partial Backup Transaction Directory

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Baseline: `0ef0631af3696531251ee4a4dfbfb953e9f2bc81`
- Depends on: completed Phase 2, including TASK-2.14A
- Next task: TASK-3.2 remains LOCKED

## Objective

Move all new Backup output away from the timestamp-named directory that discovery treats as a completed backup.

Every Backup run must instead create and use one private, unique, descriptor-bound partial workspace beneath the exact current per-bundle backup parent.

The workspace is not a published backup.

TASK-3.1 establishes only the partial transaction namespace and its identity boundary. It does not serialize concurrent Backup runs, replace artifact writers, change manifest schema, validate publication completeness, atomically publish a final timestamp directory, centralize failure cleanup, or redesign discovery beyond excluding the reserved partial namespace.

## Current unsafe behavior

`createBackupForBundleID:appName:options:completion:` currently computes:

```objc
NSString *backupDir =
    [[[self _backupRoot] stringByAppendingPathComponent:bundleID]
        stringByAppendingPathComponent:timestamp];
```

Artifacts and `manifest.plist` are written directly into that timestamp directory.

`listBackupDirectoriesForBundleID:` scans direct children of the per-bundle directory and considers a child discoverable when it contains `manifest.plist`.

Consequences:

1. a partially written Backup occupies its eventual public namespace;
2. a timestamp collision can merge or overwrite work;
3. a manifest written before all durability/publication work is complete can make an incomplete directory discoverable;
4. multiple writers have no unique private transaction namespace;
5. later atomic publication has no descriptor-bound source workspace to publish.

## Authorized production scope

Only these production files may be created or modified:

```text
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-3.1-REPORT.md
```

Implementation commit may contain only:

```text
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-3.1-REPORT.md
```

## Protected production files

Do not modify:

```text
AppDataBackupManager.h
PXRestoreResult.h/.m
PXMainDataRestoreTransaction.h/.m
PXAppGroupRestoreTransaction.h/.m
PXOptionalRestoreTransaction.h/.m
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXOptionalRestoreStaging.h/.m
PXRestorePlan.h/.m
PXBackupManifestValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
CommandRunner.h/.m
Makefile
all UI/controller files
all Keychain helper/bridge/script files
```

Do not modify coordinator task, review, status, roadmap, decision, or README files.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Record SHA-256 before and after for all protected production files.

## Public API

Create `PXBackupPublicationWorkspace.h`.

Export exactly:

```objc
FOUNDATION_EXPORT NSErrorDomain const PXBackupPublicationWorkspaceErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupPublicationWorkspaceErrorFieldPathKey;
FOUNDATION_EXPORT NSString * const PXBackupPublicationPartialDirectoryPrefix;
```

`PXBackupPublicationPartialDirectoryPrefix` must equal exactly:

```text
.weaponx-backup-partial-
```

Define exactly ten error codes:

```objc
typedef NS_ERROR_ENUM(PXBackupPublicationWorkspaceErrorDomain,
                      PXBackupPublicationWorkspaceErrorCode) {
    PXBackupPublicationWorkspaceErrorInvalidInput = 1,
    PXBackupPublicationWorkspaceErrorRootCreationFailed = 2,
    PXBackupPublicationWorkspaceErrorRootInspectionFailed = 3,
    PXBackupPublicationWorkspaceErrorUnsafeRoot = 4,
    PXBackupPublicationWorkspaceErrorBundleDirectoryCreationFailed = 5,
    PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid = 6,
    PXBackupPublicationWorkspaceErrorWorkspaceCreationFailed = 7,
    PXBackupPublicationWorkspaceErrorWorkspaceInvalid = 8,
    PXBackupPublicationWorkspaceErrorFilesystemChanged = 9,
    PXBackupPublicationWorkspaceErrorLimitExceeded = 10,
};
```

Create one `objc_subclassing_restricted` class:

```objc
@interface PXBackupPublicationWorkspace : NSObject

@property (nonatomic, copy, readonly) NSString *canonicalBackupRootPath;
@property (nonatomic, copy, readonly) NSString *canonicalBundleDirectoryPath;
@property (nonatomic, copy, readonly) NSString *workspacePath;
@property (nonatomic, copy, readonly) NSString *workspaceName;
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;

+ (nullable instancetype)createWorkspaceAtBackupRoot:(NSString *)backupRoot
                                    bundleIdentifier:(NSString *)bundleIdentifier
                                               error:(NSError **)error;

- (BOOL)validateIdentityWithError:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
```

Do not expose:

- raw file descriptors;
- a caller-selected partial prefix;
- a final directory name;
- a publish/rename method;
- a recursive cleanup method;
- a manifest API;
- an artifact writer API;
- a locking API;
- a serialization API.

## Pure workspace boundary

`PXBackupPublicationWorkspace.m` may import only:

```objc
#import "PXBackupPublicationWorkspace.h"
```

and required POSIX/C headers.

Forbidden in the workspace implementation:

- `AppDataBackupManager`;
- `CommandRunner`;
- UIKit;
- Security/Keychain;
- user defaults;
- shell/process APIs;
- `system`, `popen`, `posix_spawn`, `NSTask`;
- tar/archive logic;
- manifest parsing/writing;
- Backup artifact semantics;
- logging raw paths or identifiers;
- global mutable state;
- dispatch queues;
- publication rename;
- recursive stale-workspace cleanup.

## Input validation

### Backup root

`backupRoot` must:

- be a runtime `NSString`;
- be nonempty;
- contain no U+0000;
- be an absolute path;
- encode losslessly as UTF-8;
- be no longer than 4096 UTF-8 bytes.

Do not trim, lowercase, standardize, percent-decode, tilde-expand, or rewrite the caller string as authorization.

Normal ancestor aliases such as `/var -> /private/var` may be accepted after canonicalization.

### Bundle identifier

`bundleIdentifier` must be one safe single path component:

- runtime `NSString`;
- nonempty;
- contain non-whitespace text;
- no U+0000;
- no `/`;
- no `\`;
- not `.` or `..`;
- no ASCII control characters;
- lossless UTF-8;
- at most 255 UTF-8 bytes.

Do not trim, lowercase, Unicode-normalize, or percent-decode it.

The exact identifier string is used as the per-bundle directory name.

## Backup-root creation and binding

The current `_backupRoot` may not yet exist.

The factory may create the requested root path with intermediate directories before canonical proof. Creation must use mode `0700` for newly created final directories where the API permits attributes.

After any creation attempt, require:

1. `lstat` of the requested backup-root final component succeeds;
2. final component is not a symbolic link;
3. final component is a directory;
4. no setuid or setgid bits;
5. `realpath` succeeds;
6. canonical path is absolute, valid UTF-8, and within the 4096-byte limit;
7. canonical final component opens with `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`;
8. `fstat` proves a directory;
9. requested-path `lstat`, canonical-path `lstat`, and opened descriptor identify the same device/inode;
10. the descriptor has `FD_CLOEXEC` set.

Do not treat `fileExistsAtPath:` as final authority.

## Per-bundle directory

Using the retained canonical backup-root descriptor:

1. inspect the exact bundle component with `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
2. if absent, create it using `mkdirat` mode `0700`;
3. if present, require a real directory and reject symlink or wrong type;
4. open it with `openat(..., O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)`;
5. require the namespace stat and descriptor stat to match device/inode/type;
6. require it to remain on the same filesystem as the canonical backup root;
7. reject setuid/setgid mode;
8. verify `FD_CLOEXEC`;
9. derive the canonical bundle-directory path only from the canonical root plus the already validated exact component;
10. verify that path resolves to the retained bundle-directory descriptor identity.

The workspace class retains the backup-root and bundle-directory descriptors until deallocation.

## Unique partial workspace creation

The workspace must be a direct child of the exact per-bundle directory.

Use exactly this template:

```text
.weaponx-backup-partial-XXXXXX
```

Creation requirements:

1. call `mkdtemp` exactly once per factory attempt;
2. call it within the retained canonical bundle-directory path;
3. require the returned basename to start with `PXBackupPublicationPartialDirectoryPrefix`;
4. require the returned basename to be one safe component;
5. require exact mode `0700`; repair with `fchmod` if necessary and then verify;
6. `lstat` the created path and reject symlink/wrong type;
7. open with `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`;
8. `fstat` and require exact device/inode/type equality with the namespace object;
9. require the same device as the bundle-directory descriptor;
10. require `FD_CLOEXEC`;
11. enumerate the workspace and require it to be empty except `.` and `..`;
12. retain the workspace descriptor and identity;
13. return copied immutable path/name/identifier properties.

Do not use a timestamp-only or PID-only partial directory name.

Do not create `manifest.plist`, `groups`, `preferences`, or any artifact in the factory.

## Factory-failure cleanup

If the factory creates a workspace but fails before returning a valid object:

- close every owned descriptor;
- remove the newly created workspace only if it is still the same retained empty directory;
- use descriptor/identity proof before removal;
- do not recursively delete contents;
- preserve an unexpected nonempty or identity-changed directory as evidence;
- do not remove the per-bundle directory or backup root.

After a valid workspace object has been returned, TASK-3.1 does not own full Backup failure cleanup. TASK-3.9 will centralize cleanup and TASK-3.10 will define stale partial discovery/removal.

## Identity revalidation

`validateIdentityWithError:` must:

1. clear `*error` on entry;
2. `fstat` retained root, bundle-directory, and workspace descriptors;
3. require all three remain real directories;
4. require retained device/inode/type identities unchanged;
5. require root → bundle and bundle → workspace same-filesystem relationships unchanged;
6. `lstat` the current canonical paths;
7. reject any path that became a symlink;
8. require path and retained descriptor identities exact-match;
9. require workspace basename still equals `workspaceName` and has the reserved prefix;
10. require root/bundle/workspace descriptors retain `FD_CLOEXEC`;
11. return `YES` only when every proof passes.

It must not require the workspace to remain empty after Backup begins writing artifacts.

It must not replace retained paths or identities with newly observed values.

## Descriptor lifecycle

The object owns exactly its retained descriptors.

Requirements:

- every descriptor is closed exactly once;
- `dealloc` closes retained descriptors;
- factory failure closes all descriptors;
- `validateIdentityWithError:` does not close retained descriptors;
- no descriptor leaks on any error path;
- caller receives no descriptor ownership.

## Error contract

Success:

```text
non-nil workspace
error == nil
```

Failure:

```text
workspace == nil
error != nil
```

`validateIdentityWithError:` failure:

```text
return NO
error != nil
```

Error domain must be `PXBackupPublicationWorkspaceErrorDomain` with one of the ten exact codes.

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupPublicationWorkspaceErrorFieldPathKey
```

Use generic descriptions. Do not expose:

- backup-root path;
- canonical path;
- bundle identifier;
- workspace name/path;
- device/inode;
- errno text;
- nested errors;
- raw directory entries.

Field paths may be only:

```text
$.backupRoot
$.bundleIdentifier
$.bundleDirectory
$.workspace
```

## Manager integration

Import exactly once in `AppDataBackupManager.m`:

```objc
#import "PXBackupPublicationWorkspace.h"
```

Within `createBackupForBundleID:appName:options:completion:`:

1. preserve the public parameter guard;
2. preserve tar discovery and current source-container resolution order;
3. compute the timestamp exactly once as currently;
4. obtain `_backupRoot` exactly once for the workspace factory;
5. create one `PXBackupPublicationWorkspace` before any Backup debug file, artifact directory, process kill, archive, Preferences copy, Keychain output, shared-DB copy, or manifest write;
6. propagate the exact non-nil workspace error on failure;
7. dispatch async failure completion on the main queue exactly once;
8. retain the workspace for the entire Backup operation;
9. assign the local `backupDir` only from `workspace.workspacePath`;
10. derive every existing Backup output path from that `backupDir` exactly as before;
11. call `validateIdentityWithError:` immediately after factory success, before creating `groups` or `preferences`;
12. call it again immediately before writing `manifest.plist`;
13. call it once more immediately before constructing the successful `PXBackupResult`;
14. any identity failure returns `nil result + exact workspace error` before further publication/result work.

Use `objc_precise_lifetime` or an equivalent strong lifetime boundary so the workspace and retained descriptors remain alive through the final identity check and completion-result construction.

## Temporary Phase-3.1 success path

TASK-3.1 does not publish a timestamp directory.

On success:

```text
PXBackupResult.backupDirectory = workspace.workspacePath
PXBackupResult.manifestPath    = workspace.workspacePath/manifest.plist
```

This explicit path remains usable by immediate callers such as RRS flows and explicit Restore.

The returned path is a partial transaction workspace and must not be interpreted as an atomically published backup.

Do not add a new warning or alter UI text in this task.

TASK-3.8 will replace this temporary completion path with an atomically published final directory.

## Remove direct final-directory writing

Inside `createBackupForBundleID:...` remove the direct assignment:

```objc
[[[self _backupRoot] stringByAppendingPathComponent:bundleID]
    stringByAppendingPathComponent:timestamp]
```

After TASK-3.1:

- no timestamp directory is created as the write root;
- no artifact is written directly under a final timestamp child;
- no final-directory rename or move is introduced;
- no publication marker is introduced;
- no completion returns a timestamp path unless the workspace path happens to contain that text as unrelated data, which the fixed template does not.

## Discovery exclusion

Update both current-profile and legacy-global loops in `listBackupDirectoriesForBundleID:`.

Before inspecting a direct child as a possible backup, skip any child whose exact basename starts with:

```objc
PXBackupPublicationPartialDirectoryPrefix
```

Requirements:

- exact case-sensitive prefix;
- no trim, normalization, or fuzzy match;
- skip before manifest lookup;
- apply to both profile and legacy roots;
- do not delete or mutate partial directories;
- do not scan inside partial directories;
- do not change sorting of completed backups;
- do not change validation of ordinary legacy timestamp directories;
- do not redesign discovery beyond this reserved-prefix exclusion.

This exclusion is required even when a partial workspace contains a valid `manifest.plist`.

TASK-3.10 owns full stale partial cleanup and broader discovery hardening.

## Preserve existing Backup behavior

Except for the output root and partial discovery exclusion, preserve:

- public Backup selector;
- timestamp format and manifest timestamp value;
- tar executable preference;
- source-container resolution;
- process-kill timing relative to artifact creation;
- debug content and filenames;
- main data archive creation;
- App Group resolution/archive behavior;
- profile AppData archive behavior;
- global Safari behavior;
- Preferences behavior;
- Keychain behavior;
- system-global behavior;
- shared-system DB behavior;
- artifact metadata generation;
- warning text and append order;
- manifest version `3`;
- manifest field set and values;
- manifest atomic file-write call as currently implemented;
- `PXBackupResult` class and public fields;
- Restore implementation;
- UI/controller behavior.

Do not fix best-effort artifact handling, manifest-write warnings, or unsafe source authority in this task unless explicitly required above.

## Locked later-task boundaries

Do not implement:

### TASK-3.2

- per-bundle lock files;
- `flock`/serialization across Backup runs;
- conflict/queue policy.

### TASK-3.3

- common verified artifact writer;
- descriptor-relative artifact writes;
- hard-fail size/hash verification.

### TASK-3.4

- Preferences inclusion derived from verified output.

### TASK-3.5

- required/optional artifact policy changes.

### TASK-3.6

- manifest schema version `4`.

### TASK-3.7

- new manifest temp/journal protocol;
- common manifest validation before publication.

### TASK-3.8

- rename/move partial workspace to a final directory;
- durable atomic publication;
- final-name collision policy;
- parent-directory synchronization.

### TASK-3.9

- centralized cleanup of every Backup failure path.

### TASK-3.10

- stale partial cleanup;
- age policy;
- recursive stale-workspace deletion;
- discovery validation beyond reserved-prefix skip.

Do not begin Phase 4, Phase 5, or Phase 6.

## Static gates

### Scope

```text
A PXBackupPublicationWorkspace.h
A PXBackupPublicationWorkspace.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.1-REPORT.md
all other production diff = 0
```

### Public API

```text
error-domain exports:                 1
field-path exports:                   1
partial-prefix exports:               1
error codes:                         10
workspace classes:                    1
public factories:                     1
identity-validation methods:          1
public readwrite properties:          0
publish methods:                      0
cleanup methods:                      0
public descriptor properties:         0
```

### Workspace source

```text
mkdtemp calls:                        1
partial template occurrences:         exact controlled set
O_NOFOLLOW present:                   yes
O_CLOEXEC present:                    yes
FD_CLOEXEC verification:              yes
fstatat AT_SYMLINK_NOFOLLOW:           yes
mkdirat bundle directory:             present
workspace empty validation:           present
publication rename/move:              0
shell/process APIs:                   0
manifest/artifact APIs:               0
recursive cleanup APIs:               0
```

### Manager

```text
workspace import:                     1
workspace factory calls in Backup:    1
backupRoot reads for factory:         1
backupDir assignment from workspace:  1
direct timestamp write-root:          0
workspace identity checks:            3
partial-prefix discovery skips:       2
partial-prefix manifest inspections:  0
Backup publication rename/move:       0
manifestVersion @3 writer:             retained
public Backup selector diff:           0
Restore method body diff:              0
warning append sequence diff:          0
UI/controller diff:                    0
```

## Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.1-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. old direct timestamp-directory inventory;
4. exact public API and ten-code enum;
5. input validation matrices;
6. backup-root creation and canonical descriptor proof;
7. per-bundle `mkdirat/openat` proof;
8. exact partial prefix/template proof;
9. `mkdtemp` uniqueness proof;
10. mode `0700` proof;
11. no-follow/CLOEXEC proof;
12. root/bundle/workspace device/inode binding;
13. empty-workspace proof;
14. factory-failure empty cleanup policy;
15. descriptor ownership/close inventory;
16. identity revalidation proof;
17. manager ordering before every Backup write/kill;
18. exact three revalidation sites;
19. all output paths rooted under workspace;
20. temporary success-result path behavior;
21. current and legacy discovery exclusion;
22. zero publication rename/move proof;
23. warning/manfiest/artifact behavior non-regression;
24. exact Restore body and UI zero-diff proof;
25. TASK-3.2 through TASK-3.10 boundaries;
26. full authorized source diff;
27. static/forbidden gate table;
28. at least 120 explicit scenarios;
29. whitespace/CRLF/NUL/generated-file audit;
30. build status and remaining runtime risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 0ef0631af3696531251ee4a4dfbfb953e9f2bc81..HEAD --check
git diff --name-status 0ef0631af3696531251ee4a4dfbfb953e9f2bc81..HEAD
git status --short --untracked-files=all
```

Suggested commit subject:

```text
phase3(task-3.1): create unique partial backup workspace
```

## Stop condition

Stop after TASK-3.1 source, report, and implementation commit.

Do not implement TASK-3.2 or any later task.
