# TASK-1.11 — Remove Unsafe Permission and Marker-File Behavior

- Status: READY
- Phase: Phase 1 — Clear Data Safety Boundary
- Depends on: TASK-1.10 accepted
- Build owner: Project owner via GitHub Actions
- Next task: TASK-1.12 remains LOCKED

## Objective

Remove the remaining unsafe recursive permission/flag rewriting and marker/timestamp mutation owned by `AppDataCleaner.m` without redesigning legacy deletion APIs or changing the accepted typed five-scope Clear orchestration.

The current file still contains compatibility helpers that can:

- recursively set arbitrary caller-supplied trees to mode `0777`;
- recursively clear immutable/system/hidden flags before deletion;
- recursively change ownership of recreated fixed directories;
- create `.nomedia` and `.initialized` marker files after a wipe;
- copy a database timestamp onto a system framework executable;
- perform permission preparation before legacy WebKit/container deletion.

TASK-1.11 removes those permission/marker side effects. It does not yet remove or quarantine the broad public Clear APIs that expose raw-path or heuristic deletion. API quarantine belongs exclusively to TASK-1.12.

---

## Required baseline

Expected repository HEAD when TASK-1.11 is opened:

```text
7b277bfd2579e53f0015b89ef36b43440688590b
```

The accepted TASK-1.10 production commit is:

```text
2579c76a8716761b88bf99f7d77b14f4ddb1171e
```

If HEAD differs, record the actual HEAD and explain why before changing source. Do not silently rebase, reset or amend prior task commits.

At task start, record:

```bash
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

---

## Allowed production changes

Only this production file may change:

```text
AppDataCleaner.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-1.11-REPORT.md
```

Do not modify:

```text
AppDataCleaner.h
AppEntitlementsReader.h
AppEntitlementsReader.m
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
KeychainGroupsViewController.m
ProjectXViewController.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper/backup_helper.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
Makefile
```

Do not modify task specifications, reviews, status, roadmap or decision logs. Coordinator files are not agent-owned.

---

## Required reading

Read before implementation:

1. `docs/backup-restore-hardening/STATUS.md`
2. `docs/backup-restore-hardening/ROADMAP.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md`
5. `docs/backup-restore-hardening/tasks/TASK-1.7-migrate-main-application-data-clear.md`
6. `docs/backup-restore-hardening/tasks/TASK-1.8-migrate-extension-and-pluginkit-data-clear.md`
7. `docs/backup-restore-hardening/tasks/TASK-1.9-migrate-app-group-clear.md`
8. `docs/backup-restore-hardening/tasks/TASK-1.10-integrate-keychain-clear-result.md`
9. the complete `AppDataCleaner.m`
10. `AppDataCleaner.h`

Full-file review is mandatory because the permission helpers are public or shared by many legacy call paths.

---

# Part 1 — Safety boundary of this task

TASK-1.11 removes only permission, flag, marker and timestamp-preparation behavior.

It does not claim that the remaining broad deletion helpers are safe target-selection APIs. Specifically, this task does not approve:

```text
completelyWipeContainer:
fixPermissionsAndRemovePath:
wipeDirectoryContents:keepDirectoryStructure:
fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:
finalSweepForContainer:
wipeWebKitDirectoryContents:
performFullCleanup:
performAggressiveCleanupFor:
```

for use by new callers.

Existing selectors remain implemented for source/ABI compatibility. TASK-1.12 will decide how ambiguous legacy Clear APIs are quarantined.

Do not add a new public API, new validator bypass, new resolver or new raw-path deletion entry point.

---

# Part 2 — Definition of forbidden unsafe behavior

After TASK-1.11, `AppDataCleaner.m` must contain no general recursive permission or ownership rewrite such as:

```text
chmod -R ...
find ... -exec chmod ...
chown -R ...
```

No generic compatibility helper may recursively clear filesystem flags before deletion.

The only allowed remaining recursive `chflags` occurrence is the already accepted best-effort child preparation inside:

```text
PXShellValidatedApplicationDataWipe
```

That helper receives only a canonical path returned by `PXDestructivePathValidator`, skips both MCM metadata files and applies the flag operation only to each immediate non-metadata child selected by the accepted strict script.

Do not copy this exception into any legacy helper. Do not broaden it. Do not change its command, ordering, result policy or postcondition behavior.

---

# Part 3 — Preserve accepted narrow permission operations

The following narrow operations are not the unsafe behavior targeted by this task and must remain unchanged:

## TASK-1.10 Keychain temporary workspace

```objc
attributes:@{NSFilePosixPermissions: @0700}
```

for the unique temporary directory.

## TASK-1.10 copied helper executable

```objc
chmod(workingHelper.fileSystemRepresentation, 0755);
```

This is a non-recursive mode change on the task-owned temporary helper copy required before direct execution.

## Existing fixed temporary plist copies

Non-recursive mode `0644` changes on task-owned `/var/tmp` copies used by dormant icon-state compatibility methods may remain. Do not expand or migrate those methods in TASK-1.11.

Do not alter Keychain planning, direct execution, bridge behavior, temporary cleanup or five-scope accounting.

---

# Part 4 — Protect the accepted typed Clear path

The following accepted production behavior must remain byte-for-byte or semantically unchanged, except for unrelated line-number movement:

```text
PXShellValidatedApplicationDataWipe
PXApplicationDataCommandResultSucceeded
PXApplicationDataPostconditionIsValid
_completeDataWipeForMigratedRequest:
_clearExactDataContainerComponentForIdentifiers:kind:scope:timeoutSec:canonicalPaths:successfulCanonicalPaths:
_clearExactAppGroupsComponentForIdentifiers:timeoutSec:canonicalPaths:successfulCanonicalPaths:
_keychainClearPlanForBundleIdentifier:
_executeKeychainWipeForBundleIdentifier:selectedGroups:applicationIdentifier:systemApplication:error:
_keychainComponentForPlan:passResults:
clearDataForBundleID:completion:
completeAppDataWipe:
```

Record method/function body hashes before and after for at least:

```text
PXShellValidatedApplicationDataWipe
_completeDataWipeForMigratedRequest:
_keychainClearPlanForBundleIdentifier:
_executeKeychainWipeForBundleIdentifier:selectedGroups:applicationIdentifier:systemApplication:error:
clearDataForBundleID:completion:
```

They must be equal.

Do not change:

- the four-scope data mask;
- the five-scope full mask;
- component order;
- result counts or statuses;
- Keychain pass count;
- callback precedence;
- one-shot completion;
- watchdog/background-task/freeze behavior;
- canonical caches;
- resolver/validator policy;
- strict typed component scripts or postconditions.

---

# Part 5 — Make `PXShellFinalSweep` deletion-only

The current `PXShellFinalSweep` performs:

```text
recursive chflags
recursive chmod 0777
find-based deletion
```

Remove the permission and flag prefixes.

The helper may retain only its existing prune-aware deletion expression and quoting behavior. It must not:

- call `chmod`, `chown` or `chflags`;
- create files or directories;
- touch metadata or markers;
- rewrite the path;
- add a validator or claim target authorization;
- change timeout policy in `finalSweepForContainer:`.

`finalSweepForContainer:` must remain source-compatible and delegate only to the deletion-only shell fragment.

TASK-1.12 remains responsible for quarantining this raw-path destructive API.

---

# Part 6 — Harden `fixPermissionsAndRemovePath:`

Keep the public selector unchanged:

```objc
- (void)fixPermissionsAndRemovePath:(NSString *)path;
```

Despite its historical name, its implementation must no longer change permissions, ownership or flags.

Required behavior:

1. retain the current absent-path early return;
2. remove the recursive `chmod 0777` command;
3. remove the recursive `chflags` command;
4. attempt the existing `NSFileManager removeItemAtPath:error:` deletion;
5. if Foundation removal fails, retain one bounded quoted `rm -rf` compatibility fallback;
6. do not create a marker, directory or replacement file;
7. do not normalize or expand the path;
8. do not add wildcard matching;
9. update logs/comments so they no longer claim permissions are being fixed.

The method remains an ambiguous raw-path deletion API and is not approved for new callers. Quarantine is TASK-1.12.

---

# Part 7 — Convert `fixPermissionsForPath:` to a non-mutating compatibility shim

Keep the public selector unchanged:

```objc
- (void)fixPermissionsForPath:(NSString *)path;
```

Its implementation must perform no permission, ownership, flag, creation or deletion operation.

Allowed behavior:

- validate that the object is an `NSString` and is nonempty;
- optionally perform a read-only existence check;
- log one concise message that recursive permission mutation is intentionally skipped;
- return normally.

Forbidden inside this method:

```text
runCommandWithPrivileges
CommandRunner
chmod
chown
chflags
setAttributes
NSFilePosixPermissions
removeItemAtPath
createDirectoryAtPath
writeToFile
createFileAtPath
```

Do not remove the selector from `AppDataCleaner.h` in this task.

---

# Part 8 — Remove permission preparation from `fastWipeDirectoryContents:...`

Keep the selector and current deletion branch behavior.

Remove:

```text
recursive chflags
recursive chmod 0777
```

The command passed to `runCommandWithPrivileges:timeoutSec:` must be only the existing `wipePart` expression selected by `keepStructure`.

Do not:

- change `keepStructure` metadata pruning;
- change timeout fallback;
- add marker creation;
- add a new target validator;
- make this helper part of the typed component path.

---

# Part 9 — Remove WebKit recursive chmod preparation

In:

```objc
- (void)wipeWebKitDirectoryContents:(NSString *)path;
```

remove the initial recursive `chmod 777` command and its misleading numbered comment.

Preserve the remaining compatibility behavior:

- existing presence check;
- deletion command;
- WebsiteData child cleanup;
- recreation of the existing WebKit subdirectories;
- current logging.

Do not add `chown`, `chflags`, marker files or replacement permission changes.

---

# Part 10 — Remove permission rewrite from aggressive cleanup

In:

```objc
- (void)performAggressiveCleanupFor:(NSString *)bundleID;
```

remove only the recursive:

```text
chmod -R 755 <container>/Library
```

and its permission-fixing comment.

Do not otherwise redesign this public legacy method in TASK-1.11. Its heuristic/raw-path deletion and Keychain compatibility behavior remain for TASK-1.12 quarantine review.

The migrated five-scope main Clear path must continue to have zero calls to `performAggressiveCleanupFor:`.

---

# Part 11 — Remove permission and marker behavior from `completelyWipeContainer:`

Keep the public selector unchanged:

```objc
- (void)completelyWipeContainer:(NSString *)containerPath;
```

Remove all of the following from its shell script:

```text
chmod -R 777 <container>
find <container> -type d -exec chmod 777
chmod 755 on recreated Documents/Library/Caches/Preferences/tmp
touch Documents/.nomedia
touch Library/Preferences/.initialized
```

Retain only the existing compatibility deletion/recreation operations:

- preserve the two MCM metadata filename patterns;
- remove non-metadata files;
- delete empty non-metadata directories;
- recreate the same existing directory structure;
- use the same quoted input and timeout selection.

Do not add substitute marker files, xattrs, timestamps, empty sentinels, metadata rewrites or permission commands.

Update comments/logs so they no longer describe chmod or marker steps.

This task does not validate or authorize `containerPath`. The method remains legacy and must not be called by the typed component flow. TASK-1.12 will quarantine its ambiguous public behavior.

---

# Part 12 — Remove the SiriAnalytics system-framework timestamp write

In:

```objc
- (void)cleanSiriAnalyticsDatabase:(NSString *)bundleID;
```

remove the command that copies the database timestamp onto:

```text
/System/Library/PrivateFrameworks/AssistantServices.framework/AssistantServices
```

Remove the related comment claiming it is needed for verification.

Preserve the existing SQLite delete/VACUUM behavior unchanged.

After TASK-1.11:

```text
touch -r references in AppDataCleaner.m: 0
AssistantServices.framework/AssistantServices references in AppDataCleaner.m: 0
```

Do not replace this with `utimes`, `setAttributes`, `NSFileModificationDate`, `touch`, copy, rename or any other timestamp mutation.

---

# Part 13 — Remove recursive ownership changes on recreated fixed directories

Two current fixed-path workflows recreate an empty directory and then use recursive ownership repair:

```text
/var/mobile/Library/Mail
MobileSafari recreated WebKit directory
```

Replace each exact:

```text
chown -R mobile:mobile <recreated-directory>
```

with a non-recursive ownership operation on the recreated directory itself:

```text
chown mobile:mobile <recreated-directory>
```

Requirements:

- preserve the same fixed directory target;
- preserve ordering after `mkdir`;
- do not apply ownership to descendants;
- do not introduce `chmod` or `chflags`;
- do not change Mail quarantine, Accounts3 or Safari/SystemGroup behavior;
- do not change Backup/Restore ownership code in `AppDataBackupManager.m`.

The directory is newly recreated by the same command sequence, so recursive traversal is unnecessary.

---

# Part 14 — Preserve the one accepted canonical `chflags` operation

After all changes, the only `chflags -R` occurrence in `AppDataCleaner.m` must be inside `PXShellValidatedApplicationDataWipe`.

It must remain exactly associated with the immediate child variable selected after:

```text
skip .com.apple.mobile_container_manager.metadata.plist
skip .com.apple.containermanagerd.metadata.plist
```

No other method or helper may contain:

```text
chflags -R
nouchg
noschg
nohidden
```

Do not remove this accepted strict-script operation in TASK-1.11 because doing so would change TASK-1.7/TASK-1.8/TASK-1.9 execution behavior and requires a separate device-backed decision.

---

# Part 15 — Marker and touch audit

After implementation, `AppDataCleaner.m` must contain zero active shell or Foundation behavior that creates the legacy markers:

```text
.nomedia
.initialized
```

It must also contain zero active shell `touch` commands.

Do not substitute:

- `.cleaned`;
- `.cleared`;
- `.reset`;
- `.projectx`;
- `.weaponx`;
- zero-byte sentinel files;
- timestamp copying;
- hidden marker directories;
- xattr markers;
- NSUserDefaults markers representing filesystem completion.

Existing report/log files and the TASK-1.10 diagnostic dictionary are not marker files and must not be changed.

---

# Part 16 — Main Clear reachability requirements

The typed main Clear path must remain unchanged.

After TASK-1.11 it must still use:

```text
five-scope request
immutable Keychain plan
initial Keychain pass
four-scope canonical data aggregate
final Keychain pass when planned
five-scope final PXClearResult
component-ordered callback failure precedence
```

The main path must continue to have zero calls to:

```text
finalSweepForContainer:
fixPermissionsForPath:
completelyWipeContainer:
fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:
wipeWebKitDirectoryContents:
performAggressiveCleanupFor:
performFullCleanup:
```

`removeCrashLogsForBundleID:` may continue calling `fixPermissionsAndRemovePath:` because that helper will no longer mutate permissions or flags. Do not change crash-log selection semantics in TASK-1.11.

Do not convert broad verification into a completion failure.

---

# Part 17 — Compatibility requirements

Keep all public selectors and signatures in `AppDataCleaner.h` unchanged.

In particular preserve:

```objc
- (void)completelyWipeContainer:(NSString *)containerPath;
- (void)performAggressiveCleanupFor:(NSString *)bundleID;
- (void)fixPermissionsAndRemovePath:(NSString *)path;
- (void)fixPermissionsForPath:(NSString *)path;
```

Do not remove method implementations or make callers fail to link.

Compatibility in TASK-1.11 means:

- deletion-oriented methods may still attempt their existing deletions;
- permission-only compatibility method becomes a log-only no-op;
- no caller receives a new return type;
- no public header changes;
- no new exception is thrown;
- no UI is changed.

TASK-1.12 will handle API quarantine, deprecation, caller replacement or no-op policy for ambiguous destructive entry points.

---

# Part 18 — Out of scope

Do not:

- begin TASK-1.12;
- remove or quarantine public Clear APIs;
- change `AppDataCleaner.h`;
- modify Backup or Restore;
- modify `AppDataBackupManager.m` ownership restoration;
- redesign target identity or raw-path validation;
- add a new `PXResolvedContainerKind`;
- change resolver or validator behavior;
- change the accepted strict typed wipe script;
- change data-component result semantics;
- change Keychain planning/execution/result logic;
- change callback precedence;
- modify extension or App Group migration;
- change MobileMail account database policy;
- change MobileSafari global-store or SystemGroup selection policy;
- migrate legacy command wrappers to new APIs;
- replace void compatibility methods with structured results;
- remove all narrow non-recursive permission operations from the application;
- edit files outside the allowed scope.

---

# Part 19 — Required static gates

Run exact full-file and method-boundary audits.

Expected `AppDataCleaner.m` full-file outcomes:

```text
chmod -R occurrences: 0
find ... -exec chmod occurrences: 0
chown -R occurrences: 0
chflags -R occurrences: exactly 1
chflags -R location: PXShellValidatedApplicationDataWipe only
active shell touch occurrences: 0
.nomedia occurrences: 0
.initialized occurrences: 0
AssistantServices.framework/AssistantServices occurrences: 0
TASK-1.10 NSFilePosixPermissions @0700: preserved
TASK-1.10 chmod(workingHelper..., 0755): preserved
TASK-1.4 receipt tokens: 0
PXClearScopeDefaultMask references in main migration: 0
```

Expected method-boundary outcomes:

```text
PXShellFinalSweep chmod/chown/chflags/touch: 0
finalSweepForContainer permission/marker operations: 0
fixPermissionsAndRemovePath chmod/chown/chflags/setAttributes: 0
fixPermissionsAndRemovePath removal behavior: retained
fixPermissionsForPath command/mutation operations: 0
fastWipeDirectoryContents chmod/chown/chflags/touch: 0
wipeWebKitDirectoryContents chmod/chown/chflags/touch: 0
performAggressiveCleanupFor chmod/chown/chflags/touch: 0
completelyWipeContainer chmod/chown/chflags/touch/marker: 0
cleanSiriAnalyticsDatabase touch/timestamp/system-framework write: 0
```

Expected typed-path outcomes:

```text
PXMigratedDataClearScopes: exact four scopes
PXMigratedFullClearScopes: exact five scopes
full aggregate components: 5
completeAppDataWipe Keychain execution calls: 0
main legacy Keychain wrapper calls: 0
main permission-helper calls listed in Part 16: 0
PXShellValidatedApplicationDataWipe body hash: unchanged
_completeDataWipeForMigratedRequest body hash: unchanged
_keychainClearPlanForBundleIdentifier body hash: unchanged
_executeKeychainWipe... body hash: unchanged
clearDataForBundleID:completion: body hash: unchanged
```

Audit every remaining `chmod`, `chown`, `chflags`, `NSFilePosixPermissions`, `setAttributes` and `touch` occurrence in `AppDataCleaner.m` and classify it as:

- accepted canonical strict-child preparation;
- accepted narrow temporary workspace/helper mode;
- accepted narrow temporary-file mode;
- accepted non-recursive ownership of a newly recreated fixed directory;
- unrelated dormant compatibility behavior;
- removed unsafe behavior.

No remaining occurrence may be an arbitrary-path recursive permission rewrite or marker/timestamp disguise.

---

# Part 20 — Scenario matrix

Report static and, where available, runtime evidence for at least these scenarios:

1. invalid/empty path passed to `fixPermissionsForPath:`;
2. existing path passed to `fixPermissionsForPath:`;
3. absent path passed to `fixPermissionsAndRemovePath:`;
4. Foundation deletion succeeds in `fixPermissionsAndRemovePath:`;
5. Foundation deletion fails and bounded quoted `rm -rf` fallback runs;
6. `fixPermissionsAndRemovePath:` performs no chmod;
7. `fixPermissionsAndRemovePath:` performs no chflags;
8. final sweep receives an absent path;
9. final sweep deletion command contains no permission prefix;
10. fast wipe with `keepStructure = YES`;
11. fast wipe with `keepStructure = NO`;
12. fast wipe contains no permission/flag preparation;
13. WebKit directory absent;
14. WebKit directory present and deletion proceeds without chmod;
15. aggressive cleanup no longer chmods Library;
16. `completelyWipeContainer:` target absent;
17. `completelyWipeContainer:` target present;
18. MCM metadata filenames remain excluded from deletion;
19. required compatibility directories are still recreated;
20. `.nomedia` is not created;
21. `.initialized` is not created;
22. no substitute marker is created;
23. SiriAnalytics SQLite work remains;
24. SiriAnalytics system-framework timestamp command is absent;
25. MobileMail recreated directory receives non-recursive ownership only;
26. MobileSafari recreated WebKit directory receives non-recursive ownership only;
27. no recursive chown remains;
28. no recursive chmod remains;
29. exactly one recursive chflags remains;
30. the remaining chflags is inside the accepted canonical strict script;
31. TASK-1.10 temporary directory remains mode 0700;
32. TASK-1.10 temporary helper remains mode 0755;
33. Keychain initial/final pass accounting is unchanged;
34. final five-scope aggregate is unchanged;
35. callback precedence is unchanged;
36. ApplicationData strict command body is unchanged;
37. ExtensionData/PluginKitData strict command reuse is unchanged;
38. AppGroups strict command reuse is unchanged;
39. `completeAppDataWipe:` remains four-scope/data-only;
40. public selectors remain declared and implemented;
41. Backup/Restore files are unchanged;
42. protected-file diff is empty;
43. receipt tokens remain absent;
44. cumulative diff whitespace check passes;
45. no NUL bytes are introduced.

Use `STATIC PASS`, `STATIC COVERAGE / DEVICE PENDING` and `DEVICE PASS/FAIL` honestly. Do not claim device runtime evidence that was not executed.

---

# Part 21 — Required report contents

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.11-REPORT.md
```

The report must include:

1. baseline HEAD and working-tree status;
2. exact production file changed;
3. diff stat;
4. protected-file checksums before and after;
5. accepted typed-path body hashes before and after;
6. complete permission/ownership/flag/touch inventory before and after;
7. `PXShellFinalSweep` change evidence;
8. `fixPermissionsAndRemovePath:` evidence;
9. `fixPermissionsForPath:` no-op evidence;
10. fast-wipe evidence;
11. WebKit evidence;
12. aggressive-cleanup evidence;
13. `completelyWipeContainer:` permission/marker evidence;
14. SiriAnalytics timestamp-write removal evidence;
15. fixed-directory non-recursive ownership evidence;
16. marker/substitute-marker audit;
17. main Clear reachability audit;
18. public selector compatibility proof;
19. static gate table;
20. scenario matrix;
21. build status;
22. remaining risks;
23. final diff and commit evidence.

Do not paste the entire multi-thousand-line `AppDataCleaner.m` diff into the report. Include focused excerpts and command outputs sufficient for review.

The report must end exactly with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

---

# Part 22 — Required verification commands

Before implementation:

```bash
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

After implementation:

```bash
git status --short --untracked-files=all
git diff --check
git diff --stat -- AppDataCleaner.m
git diff -- AppDataCleaner.m
git diff --exit-code -- AppDataCleaner.h AppEntitlementsReader.h AppEntitlementsReader.m PXResolvedContainer.h PXResolvedContainer.m PXDataContainerResolver.h PXDataContainerResolver.m PXDestructivePathValidator.h PXDestructivePathValidator.m PXClearRequest.h PXClearRequest.m PXClearResult.h PXClearResult.m CommandRunner.h CommandRunner.m AppGroupContainerResolver.h AppGroupContainerResolver.m AppDataBackupManager.h AppDataBackupManager.m KeychainGroupsViewController.m ProjectXViewController.m WeaponXKeychainBridge/Tweak.m KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.h KeychainHelper/KeychainBackupHelper.m Makefile
```

Run full-file token counts and method-boundary extraction rather than relying only on broad grep totals.

After commit:

```bash
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 7b277bfd2579e53f0015b89ef36b43440688590b..HEAD --check
git diff --name-status 7b277bfd2579e53f0015b89ef36b43440688590b..HEAD
```

The implementation commit must contain only:

```text
AppDataCleaner.m
docs/backup-restore-hardening/reports/TASK-1.11-REPORT.md
```

---

# Stop condition

Stop after TASK-1.11.

Do not implement TASK-1.12.

Do not remove or quarantine legacy public selectors in this task.
