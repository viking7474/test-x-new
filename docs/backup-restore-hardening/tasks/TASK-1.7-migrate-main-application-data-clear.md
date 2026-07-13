# TASK-1.7 — Migrate Main Application-Data Clear

- Status: READY
- Phase: Phase 1 — Clear Data Safety Boundary
- Dependency: TASK-1.6 accepted and owner build gate completed
- Allowed production file: `AppDataCleaner.m`
- Required report: `docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md`
- Suggested commit: `phase1(task-1.7): migrate main application data clear`

## Objective

Migrate the primary application-data portion of the current `clearDataForBundleID:completion:` → `completeAppDataWipe:` path from legacy UUID/fuzzy discovery and raw path reconstruction to:

1. immutable typed request context;
2. exact root-specific `PXDataContainerResolver` resolution;
3. immediate `PXDestructivePathValidator` authorization;
4. mutation using only the canonical path returned by the validator;
5. bounded result-returning command execution;
6. strict postcondition verification;
7. a structured `PXClearComponentResult` for `PXClearScopeApplicationData`;
8. failure propagation to the existing legacy completion callback.

This task migrates only the **main application-data component**.

It must not migrate:

- extension data;
- PluginKit data;
- App Group data;
- Keychain result integration;
- application bundles;
- broad legacy public helpers.

## Required reading

Read completely before editing:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.6-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `PXResolvedContainer.h/.m`
8. `PXDataContainerResolver.h/.m`
9. `PXDestructivePathValidator.h/.m`
10. `PXClearRequest.h/.m`
11. `PXClearResult.h/.m`
12. `CommandRunner.h/.m`
13. `AppDataCleaner.h`
14. the complete `AppDataCleaner.m`
15. `Makefile`

Audit all application-data mutations reachable from:

```text
clearDataForBundleID:completion:
  -> completeAppDataWipe:
```

Do not assume that only the first rootful/rootless wipe block is relevant. Review later targeted cleanup, verification, final sweeps and helper calls for paths under application-data roots.

## Allowed changes

Production change:

```text
AppDataCleaner.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md
```

Do not modify:

```text
AppDataCleaner.h
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
PXClearRequest.h/.m
PXClearResult.h/.m
CommandRunner.h/.m
AppGroupContainerResolver.h/.m
AppDataBackupManager.h/.m
Makefile
Backup
Restore
Keychain implementation
UI
```

## Required imports

`AppDataCleaner.m` must import:

```objc
#import "PXDataContainerResolver.h"
#import "PXDestructivePathValidator.h"
#import "PXClearRequest.h"
#import "PXClearResult.h"
```

Do not add these imports to `AppDataCleaner.h`.

## Public API compatibility

The public selector remains unchanged:

```objc
- (void)clearDataForBundleID:(NSString *)bundleID
                 completion:(void (^)(BOOL success, NSError *error))completion;
```

The public compatibility selector also remains unchanged:

```objc
- (void)completeAppDataWipe:(NSString *)bundleID;
```

Do not add a public typed Clear API in TASK-1.7.

Do not change `AppDataCleaner.h`.

## Internal request context

The main legacy entry point must capture deep-clean intent once and construct an immutable request containing only the component migrated by this task:

```objc
PXClearRequest *applicationDataRequest =
    [[PXClearRequest alloc]
        initWithBundleIdentifier:bundleID
                           scopes:PXClearScopeApplicationData
                        deepClean:deepClean];
```

Requirements:

- use the exact `bundleID` received by the public API;
- use the already captured deep-clean boolean, not a second global read;
- scope must be exactly `PXClearScopeApplicationData`;
- do not use `PXClearScopeDefaultMask`;
- request construction failure must stop destructive work and complete with failure;
- no normalization or fallback identifier is allowed.

The public void `completeAppDataWipe:` wrapper may construct the same application-data-only request using the current deep-clean setting, invoke the private result-returning path and log the result. It may not fabricate success.

## Required private result-returning path

Introduce a private result-returning implementation while preserving the public void wrapper.

Recommended contract:

```objc
- (PXClearComponentResult *)
    _completeAppDataWipeForApplicationDataRequest:
        (PXClearRequest *)applicationDataRequest;
```

The exact private selector spelling may differ only if the report explains the reason. Its contract must remain:

- input is a runtime `PXClearRequest`;
- request scope is exactly `PXClearScopeApplicationData`;
- output represents only the application-data component;
- output is never intentionally ignored by `clearDataForBundleID:completion:`;
- existing non-application-data cleanup remains in its existing relative order.

The public wrapper:

```objc
- (void)completeAppDataWipe:(NSString *)bundleID;
```

must delegate to this private result-returning path and log Failed/Skipped/Succeeded status. External compatibility callers remain possible, but the main entry point must consume the result.

## Per-root unit model

Application-data units are root-specific and processed in deterministic order:

```text
1. PXResolvedContainerRootRootful
2. PXResolvedContainerRootRootless
```

Maximum unit count is two.

For each root:

1. call `PXDataContainerResolver` with the exact request bundle identifier and that root;
2. if resolver returns nil with no error, classify the root as absent and do not count an attempted unit;
3. if resolver returns an error, count one attempted failed unit;
4. if resolver returns a container, immediately validate it with `PXDestructivePathValidator`;
5. validation failure counts as one attempted failed unit;
6. validation success produces the only path authorized for mutation;
7. run that root's wipe independently;
8. run post-validation and postcondition checks independently;
9. success counts as one succeeded unit;
10. failure in one root must not prevent the other root from being processed.

Do not batch rootful and rootless into one command. Independent commands are required so the result can attribute one success and one failure correctly.

## No legacy fallback for main application data

Within the migrated primary application-data path, do not call or use results from:

```text
findDataContainerUUID:
findDataContainerUUID:aggressive:
findRootlessDataContainerUUID:
findRootlessDataContainerUUID:aggressive:
optimized_findDataContainerUUID:inDirectories:
optimized_findRootlessDataContainerUUID:inDirectories:
findDataContainerUUIDForBundleID:
```

Do not use:

- company-name matching;
- short app-name matching;
- content scanning;
- prefix, suffix or substring identity matching;
- first-match behavior;
- cached directory order to select the main container;
- raw UUID supplied by a legacy resolver;
- fallback from rootful to rootless or vice versa.

Directory listings may remain where still required for **extension discovery**, which belongs to TASK-1.8. They must not select the main application-data target.

## Canonical path is the only mutation path

After exact resolution:

```objc
NSString *canonicalPath =
    [validator validatedCanonicalPathForContainer:container
                                             error:&validationError];
```

Every mutation for that main application-data unit must use exactly `canonicalPath` or a child derived from it after validation.

Do not mutate using:

```text
container.containerPath
container.containerUUID
/var/mobile/Containers/Data/Application/<UUID>
/private/var/mobile/Containers/Data/Application/<UUID>
/containers/Data/Application/<UUID>
```

when those strings are reconstructed outside the validator result.

No `/var/mobile` alias may be reconstructed for the rootful target.

Validation must occur immediately before command construction and execution. Do not perform debug directory enumeration, size calculation or unrelated work between successful validation and the destructive command.

## Dedicated strict application-data wipe script

Do not use the generic public `completelyWipeContainer:` helper for the migrated main application-data unit.

Do not use the existing void `runCommandWithPrivileges:` wrapper for the migrated wipe.

Add a private/static script builder dedicated to this task, recommended name:

```objc
static NSString *PXShellValidatedApplicationDataWipe(NSString *canonicalPath);
```

The script must:

1. use the existing safe shell-quoting helper;
2. operate only below the validated canonical container path;
3. preserve exactly these metadata files if present:

```text
.com.apple.mobile_container_manager.metadata.plist
.com.apple.containermanagerd.metadata.plist
```

4. remove every other immediate child of the container;
5. recreate only the required top-level directories:

```text
Documents
Library
tmp
```

6. not remove or replace the container directory itself;
7. not write or rewrite metadata;
8. not create marker files such as `.nomedia` or `.initialized`;
9. not recursively set mode `0777` on the container or recreated tree;
10. not use an unconditional final success path.

Permission/chflags preparation may be best-effort, but required remove and recreate operations must contribute to a status accumulator.

The script must finish with a nonzero exit status when a required remove or directory recreation fails.

Forbidden pattern for required operations:

```sh
rm ... || true
mkdir ... || true
```

A final explicit status exit is required, for example conceptually:

```sh
status=0
...
required_operation || status=1
...
exit "$status"
```

Do not add `touch`, marker creation, recursive `chmod 777`, `chown -R` or application-bundle operations.

## Bounded execution and command result

Run one command per validated root through:

```objc
- (CommandResult *)runCommandWithPrivilegesResult:
    (NSString *)command
                                      timeoutSec:
    (NSTimeInterval)timeoutSec;
```

Do not use the void wrapper.

A command unit succeeds only when:

```text
result is non-nil
result.isSucceeded == YES
result.stdoutTruncated == NO
result.stderrTruncated == NO
```

Treat as failure:

- nil result;
- spawn failure;
- runner failure;
- timeout;
- signal termination;
- abnormal exit;
- nonzero exit code;
- stdout truncation;
- stderr truncation.

Log bounded diagnostic fields. Do not include the full command string when it contains a canonical path; use root labels and result fields.

Use the existing timeout policy derived from captured deep-clean intent and existing system-app policy. Do not introduce an unbounded command.

## Post-command revalidation

After a command reports success:

1. call `PXDestructivePathValidator` again with the same `PXResolvedContainer`;
2. require validation success;
3. require the returned canonical path to equal the pre-command canonical path exactly;
4. then evaluate the filesystem postcondition.

Revalidation failure or canonical-path change makes that root a failed unit.

This does not eliminate the path-based shell TOCTOU window, but it must detect candidate/metadata replacement visible after execution and must prevent a command result alone from being treated as sufficient proof.

## Required postcondition

Add a read-only postcondition checker for the migrated container.

Recommended contract:

```objc
static BOOL PXApplicationDataPostconditionIsValid(
    NSString *canonicalPath,
    NSError **error);
```

The exact helper spelling may differ. It must verify without mutation:

- the container still exists;
- it is a directory and not a symlink;
- immediate top-level entries are limited to:

```text
.com.apple.mobile_container_manager.metadata.plist
.com.apple.containermanagerd.metadata.plist
Documents
Library
tmp
```

- `Documents`, `Library` and `tmp` all exist;
- each required directory is a real directory, not a symlink;
- each required directory is empty;
- no unexpected top-level file, directory or symlink remains;
- filesystem inspection errors fail closed.

Do not follow symlinks during this check. Use `lstat` where type identity matters.

The live metadata identity itself remains the responsibility of the second validator call.

## Structured component result

The private path must return exactly one `PXClearComponentResult` with:

```text
scope = PXClearScopeApplicationData
```

### Attempt count

Count a unit when a root:

- produces a resolver error; or
- produces a container that proceeds to validation/execution.

Do not count a root that returns nil with no resolver error.

### Succeeded

Return Succeeded when:

```text
attemptedUnitCount > 0
failedUnitCount == 0
succeededUnitCount == attemptedUnitCount
```

This includes one-root and two-root success.

### Skipped

Return Skipped only when both roots are absent without resolver error:

```text
attemptedUnitCount = 0
succeededUnitCount = 0
failedUnitCount = 0
failure = nil
```

Required detail:

```text
No exact application-data container exists in either supported root
```

No-match is not a legacy completion failure.

### Failed

Return Failed whenever at least one root fails resolution, validation, execution, revalidation or postcondition checking.

Counts must support partial success:

```text
attemptedUnitCount = 1 or 2
failedUnitCount > 0
succeededUnitCount = attemptedUnitCount - failedUnitCount
```

When one root succeeds and one fails, status remains Failed with mixed counts.

## Failure snapshot policy

Do not store raw resolver or validator `NSError` objects in the component result.

Use a stable private failure domain, recommended:

```objc
static NSString * const PXApplicationDataClearFailureDomain =
    @"PXApplicationDataClear";
```

Use fixed private codes for at least:

```text
InvalidRequest
ResolutionFailed
ValidationFailed
ExecutionFailed
PostconditionFailed
InternalResultFailure
```

The component stores the first failure snapshot. Continue processing the other root and summarize all root outcomes in `detail`.

Failure messages and result detail:

- may identify `rootful` or `rootless`;
- must not include canonical filesystem paths;
- must not include shell commands;
- must not include mutable `NSError.userInfo` content;
- must be nonempty and deterministic.

Underlying resolver/validator/runner diagnostics may be logged separately.

## Main legacy completion mapping

`clearDataForBundleID:completion:` must consume the returned application-data component result.

Required policy:

1. Failed application-data result → legacy completion `success = NO`.
2. Succeeded application-data result → continue existing completion policy.
3. Skipped application-data result → continue existing completion policy and log the skip.
4. Nil or structurally invalid internal result → legacy completion failure.

Convert the immutable `PXClearFailure` snapshot to a new `NSError` only at the legacy callback boundary.

When both application-data and existing Keychain logic fail, application-data failure takes precedence as the callback error because the primary destructive component did not complete. Log the Keychain failure as well.

Do not otherwise redesign legacy completion semantics in TASK-1.7.

Do not map `allRequestedScopesSucceeded`; this task emits only one component result and does not construct a full aggregate for all legacy cleanup.

## Main-flow cache migration

Replace raw application-data UUID cache state:

```text
_wipeCacheDataUUID
_wipeCacheRootlessDataUUID
```

with canonical path cache state, recommended:

```objc
NSArray<NSString *> *_wipeCacheApplicationDataCanonicalPaths;
```

Requirements:

- store copied canonical paths obtained from successful validation;
- preserve deterministic rootful-then-rootless order;
- do not reconstruct paths from UUIDs for verification;
- use canonical paths in the main final read-only sweep;
- clear the canonical cache when the existing wipe cache is consumed;
- do not change App Group or extension cache schemas in TASK-1.7.

A validated path may remain in the read-only verification cache even when its command later fails, so verification can report residual content.

## Verification integration

When `verifyDataCleared:` is called from the main wipe and the wipe cache matches the bundle identifier:

- verify the cached canonical application-data paths directly;
- do not reconstruct `/var/mobile` or rootless paths from UUIDs;
- do not rerun fuzzy application-data discovery.

Standalone verification without a matching wipe cache may retain its existing read-only fallback behavior in TASK-1.7. Record this remaining legacy behavior in the report.

Verification remains log-only. Do not change its final Boolean policy in this task.

## Remove redundant/bypass mutations from the main path

After the migrated primary wipe, the main `completeAppDataWipe:` execution must not perform a second main application-data mutation through a legacy UUID/path route.

At minimum, remove the redundant raw-path `Library/HTTPStorages` wipe because the validated full container wipe already removes it.

Audit every helper invoked later by the main `completeAppDataWipe:` body.

If a helper would rediscover and mutate the **main application-data container** using fuzzy identity or raw UUID reconstruction:

- remove that helper call from the main path when its application-data work is redundant; or
- split the main-path call so only non-application-data behavior remains.

Do not rewrite or quarantine the broad public helper implementation unless required to stop a main-path bypass. Public legacy APIs are handled by TASK-1.12.

Extension, PluginKit and App Group mutation blocks must remain for their dedicated migration tasks, even though they are still legacy.

## Method-body source gates

Within the private result-returning main wipe implementation, application-data selection/mutation must have:

```text
optimized_findDataContainerUUID:inDirectories: main-target uses: 0
optimized_findRootlessDataContainerUUID:inDirectories: main-target uses: 0
findDataContainerUUID: main-target uses: 0
findRootlessDataContainerUUID: main-target uses: 0
raw dataUUID main-target variable: 0
raw rootlessDataUUID main-target variable: 0
formatted /var/mobile/.../Data/Application/%@ main-target mutation: 0
formatted /containers/Data/Application/%@ main-target mutation: 0
completelyWipeContainer: main application-data calls: 0
void runCommandWithPrivileges: main application-data calls: 0
```

The following must be present:

```text
PXDataContainerResolver rootful call: 1
PXDataContainerResolver rootless call: 1
PXDestructivePathValidator pre-command validation: one per resolved root
PXDestructivePathValidator post-command revalidation: one per executed-success root
runCommandWithPrivilegesResult: one per validated root
PXClearComponentResult ApplicationData result: exactly one final result
```

Root directory listings retained solely for extension discovery must be separately identified in the report and must not feed main target selection.

## Application bundle boundary

TASK-1.7 must not restore any application-bundle mutation.

Do not add application-bundle or receipt scope, path validation, deletion, receipt clearing or write behavior.

All TASK-1.4 application-bundle gates must remain true:

```text
_MASReceipt tokens in AppDataCleaner.m: 0
._MASReceipt tokens in AppDataCleaner.m: 0
rootless application-bundle full wipe: absent
public receipt selector: compatibility no-op
```

## Generic helpers

Do not modify these generic helper implementations unless the task cannot compile without a declaration-only adjustment:

```text
completelyWipeContainer:
fixPermissionsAndRemovePath:
fixPermissionsForPath:
wipeDirectoryContents:keepDirectoryStructure:
securelyWipeFile:
```

The migrated main application-data path must not call them for the validated container.

TASK-1.11 remains responsible for removing unsafe permission and marker behavior from remaining legacy helpers.

## Out-of-scope work

Do not:

- add a public typed Clear method;
- build a full `PXClearResult` covering all five scopes;
- migrate extension data or PluginKit data;
- migrate App Group data;
- integrate Keychain as a `PXClearComponentResult`;
- alter Backup or Restore;
- change UI;
- change application-bundle behavior;
- remove public legacy methods;
- implement TASK-1.8 or later;
- edit task specification or coordinator review files.

## Protected baseline

Record before changes:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -1 --oneline
```

Expected HEAD:

```text
81de2a7ef28f862f78a7ae55f0d8897066a85f94
```

Record SHA-256 before and after for:

```text
AppDataCleaner.h
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
PXClearRequest.h
PXClearRequest.m
PXClearResult.h
PXClearResult.m
CommandRunner.h
CommandRunner.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
AppDataBackupManager.h
AppDataBackupManager.m
Makefile
```

All must remain unchanged.

## Required scenario matrix

The report must cover at least:

| # | Scenario | Required outcome |
|---:|---|---|
| 1 | both roots absent | Skipped, zero units, legacy flow continues |
| 2 | rootful exact container only | one successful unit |
| 3 | rootless exact container only | one successful unit |
| 4 | both roots exact and successful | two successful units |
| 5 | rootful resolver error, rootless absent | Failed 1/0/1 |
| 6 | rootful absent, rootless resolver error | Failed 1/0/1 |
| 7 | one root validator rejection | failed unit; no mutation for that root |
| 8 | one root success, other validation failure | Failed partial 2/1/1 |
| 9 | command spawn/runner failure | Failed |
| 10 | command timeout | Failed |
| 11 | signal termination | Failed |
| 12 | nonzero exit | Failed |
| 13 | output truncation | Failed |
| 14 | post-command validator failure | Failed |
| 15 | canonical path changes after command | Failed |
| 16 | required directory missing after wipe | Failed |
| 17 | required directory is symlink | Failed |
| 18 | required directory nonempty | Failed |
| 19 | unexpected top-level item remains | Failed |
| 20 | one root command fails, other succeeds | both processed; Failed partial |
| 21 | application-data failure plus Keychain success | legacy completion NO with application-data error |
| 22 | application-data success plus Keychain failure | existing Keychain failure behavior remains |
| 23 | both application-data and Keychain fail | application-data error returned; Keychain failure logged |
| 24 | application-data skipped plus Keychain success | legacy completion continues as success |
| 25 | public completeAppDataWipe caller | wrapper delegates and logs result |
| 26 | main verification after wipe | uses cached canonical paths |
| 27 | standalone verification | existing read-only fallback documented |
| 28 | extension discovery | unchanged legacy behavior |
| 29 | App Group clear | unchanged legacy behavior |
| 30 | application bundle references | remain read-only |
| 31 | invalid bundle identifier/request | no destructive work; legacy completion failure |
| 32 | typed result detail/failure | contains no filesystem path or shell command |

Do not claim runtime PASS without device/runtime evidence.

## Required report sections

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md
```

Include:

1. task metadata;
2. initial status and HEAD;
3. complete allowed-file diff inventory;
4. protected checksums before/after;
5. imports and private API;
6. application-data-only request creation;
7. root order and unit accounting;
8. exact resolver usage;
9. no-legacy-fallback proof;
10. pre-command validator usage;
11. canonical-path-only mutation proof;
12. strict script design and exit-status behavior;
13. bounded command-result mapping;
14. post-command revalidation;
15. postcondition checks;
16. structured component-result construction;
17. failure domain/code/message policy;
18. legacy completion propagation;
19. canonical cache migration;
20. verification integration;
21. redundant/bypass mutation audit;
22. extension/App Group/PluginKit/Keychain not-changed proof;
23. application-bundle gate preservation;
24. generic helper checksum/not-changed proof;
25. complete scenario matrix;
26. full diff/stat review;
27. source-token gates;
28. whitespace, NUL, generated/binary audit;
29. local build/runtime status;
30. remaining risks, including path-based TOCTOU and legacy external APIs.

End exactly with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Verification commands

At minimum run and record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --stat -- AppDataCleaner.m
git diff -- AppDataCleaner.m
git diff --check
git diff --exit-code -- <all protected tracked files>
```

Also run focused searches/counts for:

```text
PXDataContainerResolver
PXDestructivePathValidator
PXClearRequest
PXClearComponentResult
PXClearScopeApplicationData
runCommandWithPrivilegesResult:
runCommandWithPrivileges:
completelyWipeContainer:
optimized_findDataContainerUUID
optimized_findRootlessDataContainerUUID
_wipeCacheDataUUID
_wipeCacheRootlessDataUUID
_wipeCacheApplicationDataCanonicalPaths
Data/Application/%@
_MASReceipt
rootlessBundlePath
```

Audit all remaining application-data root literals in `AppDataCleaner.m` and classify:

- migrated main mutation;
- extension/PluginKit legacy mutation;
- read-only discovery/verification;
- public legacy helper outside the main path.

No remaining main application-data mutation may bypass exact resolve + canonical validation.

## Stop condition

After completing TASK-1.7:

- create the report;
- do not start TASK-1.8;
- do not migrate extension or PluginKit data;
- do not migrate App Groups;
- do not integrate Keychain result;
- do not add a public typed Clear API;
- stop for coordinator review and owner build gate.
