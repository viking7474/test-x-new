# TASK-2.4 — Remove Recorded Path and UUID Restore Destination Fallbacks

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `1c5eda02e91c5705e7798ef2414475f3aebfcef2`
- Previous task: TASK-2.3 accepted
- Next task: TASK-2.5 remains LOCKED

## Objective

Stop treating backup-recorded destination information as Restore authority.

A manifest describes backup source history. These fields must not choose the current destructive destination:

```text
$.data.containerPath
$.data.uuid
$.sourceDataContainerPath
$.sourceDataContainerUUID
```

Restore must instead resolve the currently installed requested application's ApplicationData container through the existing exact typed resolver and canonical destructive-path validator.

TASK-2.4 establishes a single exact canonical destination before operational Restore setup and revalidates that same identity immediately before the first target mutation.

This task does not change artifact verification, archive inspection, restore planning, staging semantics, transaction/rollback behavior or structured restore results.

---

# Part 1 — Exact production scope

Only this production file may change:

```text
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.4-REPORT.md
```

Do not modify:

```text
AppDataBackupManager.h
PXBackupManifestValidator.h
PXBackupManifestValidator.m
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
AppDataCleaner.h
AppDataCleaner.m
AppEntitlementsReader.h
AppEntitlementsReader.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
PXClearRequest.h
PXClearRequest.m
PXClearResult.h
PXClearResult.m
CommandRunner.h
CommandRunner.m
AppDataBackupRestoreViewController.m
ProfileManagerViewController.m
ProjectXViewController.m
KeychainGroupsViewController.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper files
Makefile
```

Do not modify coordinator task/review/status/roadmap/decision/README files.

---

# Part 2 — Preserve TASK-2.1 through TASK-2.3

Keep byte/semantic behavior unchanged for:

- `PXBackupManifestVersionIsSupported`;
- `readManifestAtBackupDirectory:error:`;
- exact supported versions `{2, 3}`;
- validator-error propagation;
- unsupported-version manager code `201`;
- exact case-sensitive manifest/requested bundle comparison;
- bundle mismatch manager code `304`;
- mismatch generic description;
- early mismatch ordering;
- Backup writer manifest version `3`.

Restore error precedence before destination resolution remains:

```text
invalid public parameters -> manager code 300
manifest read failure -> manager code 200
manifest structural failure -> exact validator NSError
unsupported version -> manager code 201
bundle mismatch -> manager code 304
```

TASK-2.4 destination failure follows those gates.

---

# Part 3 — Imports

Add exactly one import for each existing typed safety contract:

```objc
#import "PXDataContainerResolver.h"
#import "PXDestructivePathValidator.h"
```

Do not import these headers into `AppDataBackupManager.h` or UI/controller files.

Do not add a new production file or public API.

---

# Part 4 — Private exact destination helper

Add one file-local private helper with semantics equivalent to:

```objc
static BOOL PXResolveExactRestoreApplicationDataTarget(
    NSString *bundleID,
    PXResolvedContainer * _Nullable * _Nullable containerOut,
    NSString * _Nullable * _Nullable canonicalPathOut,
    NSError * _Nullable * _Nullable error);
```

The exact spelling may differ, but the helper must:

1. clear all non-null out parameters at entry;
2. reject invalid input fail-closed;
3. instantiate `PXDataContainerResolver`;
4. instantiate `PXDestructivePathValidator`;
5. process roots in deterministic order:
   - `PXResolvedContainerRootRootful`;
   - `PXResolvedContainerRootRootless`;
6. call `resolveApplicationDataContainerForIdentifier:root:error:` exactly once per root;
7. treat `nil` with no resolver error as an absent root match;
8. treat any resolver error as total destination-resolution failure;
9. validate every resolved model immediately with `validatedCanonicalPathForContainer:error:`;
10. treat any validator error or nil canonical path as total failure;
11. group accepted models by exact canonical path;
12. accept only one unique canonical physical path;
13. return one retained immutable model plus its validator-returned canonical path;
14. never return a raw candidate path.

If two root models validate to the same exact canonical path, they represent one physical target. Retain the first model in rootful-then-rootless order and return the single canonical path.

If two or more distinct canonical paths remain, fail closed as ambiguous.

Do not select first/newest/arbitrary distinct targets.

---

# Part 5 — Destination failure contract

All exact destination-resolution failures in this task use the existing private manager domain:

```text
PXBackupErrorDomain
```

Use existing Restore destination code:

```text
303
```

Use this exact generic description:

```text
Exact application data container could not be resolved safely
```

The error must not contain:

- bundle ID;
- LaunchServices path;
- manifest path;
- manifest UUID;
- candidate path;
- canonical path;
- container UUID;
- resolver nested error;
- validator nested error;
- metadata value;
- filesystem excerpt.

The same generic manager error may represent:

- no exact match;
- resolver failure;
- validator failure;
- multiple distinct canonical targets;
- pre-mutation revalidation failure;
- canonical path identity change.

Do not expose raw resolver or validator errors through the public Restore completion in TASK-2.4.

---

# Part 6 — Early Restore destination preflight

In:

```objc
restoreBackupAtDirectory:bundleID:appName:completion:
```

Required high-level order:

1. existing public parameter guard;
2. common manifest read/schema/version gate;
3. exact requested bundle-ID gate;
4. exact typed destination resolution and canonical validation;
5. destination failure callback and return when needed;
6. only then allocate warnings/file manager/runner and continue the existing flow.

The exact destination helper must run before:

- `NSMutableArray` warnings allocation;
- Restore `NSFileManager` acquisition;
- `CommandRunner` acquisition;
- debug path construction;
- debug file writes;
- `PXResolvePathsForBundleID` debug lookup;
- tar discovery;
- target process kill;
- active profile lookup;
- artifact verification;
- archive existence checks;
- staging directory creation;
- extraction;
- any target mutation.

Destination failure must not be masked by `tar not found`, missing archive or later environment failures.

The completion must be dispatched once on the main queue with:

```text
result = nil
error = non-nil manager code 303
```

---

# Part 7 — Canonical target state

After successful preflight, retain:

```text
PXResolvedContainer *dataContainerModel
NSString *dataContainerPath
NSString *dataUUID
```

Rules:

- `dataContainerPath` is exactly the validator-returned canonical path;
- `dataUUID` comes from `dataContainerModel.containerUUID`;
- no later code may overwrite either value from LaunchServices, metadata scan, manifest path or manifest UUID;
- every main ApplicationData Restore operation uses this canonical `dataContainerPath`;
- in-app Keychain Restore receives this canonical `dataContainerPath`;
- post-restore verification uses this canonical path.

Do not reconstruct the path from UUID after validation.

---

# Part 8 — Remove manifest destination authority

Inside Restore, remove all destination-selection reads and behavior based on:

```objc
manifest[@"data"][@"containerPath"]
manifest[@"data"][@"uuid"]
manifest[@"sourceDataContainerPath"]
manifest[@"sourceDataContainerUUID"]
```

Remove:

```text
manifestDataUUID
Using manifest containerPath for restore (fallback)
Using manifest UUID for restore (fallback)
```

Remove any loop that appends a manifest UUID to candidate base directories.

Remove the old failure description containing:

```text
bundleID=
lsPath=
manifestUUID=
```

After TASK-2.4, manifest-recorded path/UUID values may still be parsed structurally by `PXBackupManifestValidator`, displayed by diagnostic tooling or emitted by Backup, but they have zero authority over Restore destination selection.

Do not make these manifest fields optional in the schema validator.

Do not remove them from Backup writer output.

---

# Part 9 — Remove legacy Restore target selection

Within `restoreBackupAtDirectory:bundleID:appName:completion:` destination selection, remove direct use of:

```text
PXDataContainerPathFromLaunchServices(bundleID)
PXFindDataContainerUUIDByMetadata(...)
raw base-path arrays
fileExistsAtPath checks used to authorize a destination
first-match metadata scan
```

Important compatibility boundary:

- `PXDataContainerPathFromLaunchServices` remains available for Backup and read-only debug helpers;
- `PXFindDataContainerUUIDByMetadata` remains available for current Backup behavior;
- do not delete or redesign those helpers globally;
- only their Restore destination-authority use becomes zero.

LaunchServices may remain in read-only debug snapshots after the exact canonical destination has already been selected. It must not override or authorize the selected destination.

---

# Part 10 — Ambiguity and root policy

Process rootful before rootless.

Required outcomes:

```text
rootful absent, rootless absent -> fail 303
rootful exact only -> accept rootful canonical path
rootless exact only -> accept rootless canonical path
rootful resolver error -> fail 303 even if rootless might match
rootless resolver error -> fail 303 even if rootful matched
rootful validator failure -> fail 303
rootless validator failure -> fail 303
same canonical path from both roots -> one physical target, accept once
distinct canonical paths from both roots -> fail 303 ambiguous
multiple exact matches within one root -> resolver error -> fail 303
```

Failing on a root error prevents an unreadable root from hiding a second exact target.

Do not use LaunchServices to break a distinct-canonical-path ambiguity.

Do not select based on manifest UUID equality.

---

# Part 11 — Pre-mutation identity revalidation

Immediately before the first destructive operation on the main ApplicationData destination:

```objc
[self _wipeDirectoryContents:dataContainerPath];
```

revalidate the retained `dataContainerModel` using a new or retained `PXDestructivePathValidator`.

Require:

1. revalidation returns a nonempty canonical path;
2. no validator error;
3. returned canonical path is exactly equal to the preflight `dataContainerPath`.

If any requirement fails:

- do not call `_wipeDirectoryContents:`;
- do not run tar-pipe clone;
- do not run `cp -a` clone;
- do not run recursive ownership mutation;
- remove the task-created staging root best effort;
- complete on main queue with manager code `303` and the generic destination error;
- return.

Do not silently replace `dataContainerPath` with a changed revalidation result.

This revalidation does not replace TASK-2.7 immutable planning or later transaction work. It only preserves the destination identity through the current staging interval.

---

# Part 12 — Canonical-path-only main data mutation

After successful revalidation, the following must consume only the retained canonical path:

- pre-wipe debug inspection;
- `_wipeDirectoryContents:`;
- tar-pipe destination `-C`;
- `cp -a` fallback destination;
- ownership correction target;
- in-app Keychain bridge container path;
- post-restore debug inspection;
- metadata and Library postcondition checks.

No raw resolver candidate, LaunchServices path, manifest path or reconstructed UUID path may reach these operations.

Do not change the existing wipe/clone/ownership behavior in this task beyond destination provenance.

---

# Part 13 — Preserve Backup behavior

Do not change Backup-side container selection or manifest emission in TASK-2.4.

Keep:

```text
Backup LaunchServices preference
Backup metadata scan fallback
manifestVersion @3
data.uuid writer field
data.containerPath writer field
sourceDataContainerUUID writer field
sourceDataContainerPath writer field
```

TASK-2.4 changes Restore destination authority only.

Do not migrate Backup to the typed resolver in this task.

---

# Part 14 — Preserve App Group and optional Restore behavior

Do not change:

- entitlement reading;
- legacy App Group resolver behavior;
- App Group archive matching;
- preferences Restore;
- Keychain Restore policy;
- profile app data Restore;
- global Safari Restore;
- system global library Restore;
- shared system DB Restore;
- process relaunch behavior;
- result warnings.

App Group destination hardening and transactional staging remain later Phase 2 tasks.

---

# Part 15 — Preserve TASK-2.5 and later boundaries

Do not:

- add a common artifact verifier;
- change artifact required/optional policy;
- change size/hash behavior;
- inspect tar entries;
- reject archive traversal entries;
- create `PXRestorePlan`;
- redesign staging;
- add rollback;
- add structured Restore result;
- change Backup publication.

These remain TASK-2.5 through TASK-2.14 and Phase 3.

---

# Part 16 — Error precedence after TASK-2.4

Required precedence:

```text
300 invalid public parameters
200 manifest read failure
validator NSError structural failure
201 unsupported manifest version
304 manifest/requested bundle mismatch
303 exact destination resolution/validation failure
301 tar unavailable
305 data archive missing
existing later artifact/staging/clone errors
```

A destination failure must occur before tar lookup and must not be replaced by code `301`.

A malformed, unsupported or mismatched manifest must still fail before destination resolution.

---

# Part 17 — Required static gates

Production scope:

```text
AppDataBackupManager.m diff only
AppDataBackupManager.h diff = 0
resolver/validator source diff = 0
UI/controller diff = 0
Makefile diff = 0
```

Imports:

```text
PXDataContainerResolver import in AppDataBackupManager.m = 1
PXDestructivePathValidator import in AppDataBackupManager.m = 1
```

Private helper:

```text
exact destination helper definitions = 1
rootful resolver calls in helper = 1
rootless resolver calls in helper = 1
validator calls in initial helper = one per resolved model
unique canonical-path ambiguity check present
raw path return from helper = 0
```

Restore method:

```text
common manifest reader calls = 1
exact bundle comparison = 1
exact destination helper calls = 1
Restore direct LaunchServices target-authority calls = 0
Restore direct PXFindDataContainerUUIDByMetadata calls = 0
Restore raw destination base arrays = 0
Restore manifest data.containerPath destination reads = 0
Restore manifest data.uuid destination reads = 0
manifestDataUUID token = 0
manifest containerPath fallback warning = 0
manifest UUID fallback warning = 0
sensitive old code-303 detail tokens = 0
```

Canonical provenance:

```text
dataContainerPath assigned from validator canonical output only
dataUUID assigned from retained model only
path reconstructed from UUID after validation = 0
pre-mutation revalidation calls = 1
revalidation exact canonical equality check = 1
wipe before revalidation = 0
```

Ordering:

```text
manifest read before bundle comparison
bundle comparison before destination helper
destination helper before warnings allocation
destination helper before runner/debug/tar/kill
destination helper before artifact verification/extraction
pre-mutation revalidation immediately before first main-target wipe
```

Non-regression:

```text
supported versions remain 2 and 3
unsupported code 201 retained
bundle mismatch code 304 retained
Backup writer manifestVersion @3 retained
Backup recorded path/UUID fields retained
artifact logic unchanged
archive logic unchanged
App Group/Keychain/optional Restore unchanged
```

---

# Part 18 — Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.4-REPORT.md
```

The report must include:

1. baseline and initial status;
2. exact production scope;
3. protected file hashes before/after;
4. TASK-2.1 to TASK-2.3 non-regression;
5. exact destination helper contract;
6. rootful/rootless deterministic policy;
7. resolver and validator call counts;
8. zero/one/multiple canonical-target behavior;
9. generic manager code `303` policy;
10. no-sensitive-error proof;
11. proof manifest path/UUID destination reads are zero;
12. proof old fallback warnings are zero;
13. proof Backup still emits recorded fields;
14. early ordering proof;
15. pre-mutation revalidation proof;
16. canonical-path-only mutation proof;
17. preserved Backup behavior;
18. preserved App Group/Keychain/optional behavior;
19. TASK-2.5 and later boundary proof;
20. complete source diff;
21. static token/count table;
22. whitespace/CRLF/NUL/generated audit;
23. build status and runtime risks;
24. at least 75 honest scenarios from this specification.

Report scenarios must cover at least:

- rootful only;
- rootless only;
- neither root;
- same canonical alias;
- distinct canonical ambiguity;
- resolver error in each root;
- validator error in each root;
- multiple exact candidates in one root;
- manifest containerPath pointing to unrelated existing directory;
- manifest UUID pointing to unrelated existing container;
- manifest recorded path matching current path but still ignored;
- LaunchServices path matching canonical target;
- LaunchServices path differing from canonical target;
- changed filesystem identity before mutation;
- changed canonical path before mutation;
- staging cleanup on revalidation failure;
- no wipe on revalidation failure;
- exact bundle mismatch remains earlier;
- unsupported version remains earlier;
- tar missing remains later;
- Backup writer non-regression.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

---

# Part 19 — Verification commands

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- AppDataBackupManager.m
git diff -- AppDataBackupManager.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 1c5eda02e91c5705e7798ef2414475f3aebfcef2..HEAD --check
git diff --name-status 1c5eda02e91c5705e7798ef2414475f3aebfcef2..HEAD
```

The implementation commit may contain only:

```text
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.4-REPORT.md
```

---

# Stop condition

Stop after TASK-2.4.

Do not implement TASK-2.5.

Do not change artifact verification, archive-entry safety, Restore planning, staging architecture, transaction/rollback or structured result behavior.
