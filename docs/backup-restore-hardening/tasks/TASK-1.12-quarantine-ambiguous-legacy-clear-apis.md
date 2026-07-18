# TASK-1.12 — Quarantine Ambiguous Legacy Clear APIs

- Status: READY
- Phase: Phase 1 — Clear Data Safety Boundary
- Depends on: TASK-1.11 accepted
- Build owner: Project owner via GitHub Actions
- Next phase: Phase 2 remains LOCKED

## Objective

Close Phase 1 by making the documented raw-path, raw-UUID, fuzzy-identity and detached-Keychain compatibility entry points non-mutating.

The accepted destructive path is now the typed orchestration rooted at:

```objc
- (void)clearDataForBundleID:(NSString *)bundleID
                 completion:(void (^)(BOOL success, NSError *error))completion;
```

The accepted data-only compatibility path is:

```objc
- (void)completeAppDataWipe:(NSString *)bundleID;
```

Those paths use exact typed requests/results, exact resolvers, canonical validation, bounded execution and structured component accounting.

Legacy methods that accept arbitrary paths, reconstruct paths from UUIDs, select containers by prefix/substring/structure, or execute Keychain work outside the immutable full-Clear plan cannot provide equivalent authorization or result evidence. TASK-1.12 must preserve their selectors for ABI compatibility but turn the exact quarantine set below into truthful non-mutating shims.

This task does **not** shrink `AppDataCleaner.h`. Public API surface reduction and formal deprecation/removal remain Phase 6 work.

---

## Required baseline

Expected baseline HEAD:

```text
17d76c02e049b40bf84a161d76e90ec02b9485bf
```

Accepted TASK-1.11 review:

```text
docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
```

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Stop and report if production HEAD is not the expected baseline or a descendant containing TASK-1.11 unchanged.

Coordinator-owned documentation may already be modified or untracked. Do not rewrite, stage, delete or format coordinator files.

---

## Allowed production changes

Only:

```text
AppDataCleaner.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md
```

The implementation commit may contain only those two files.

---

## Protected files

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

Do not modify task specifications, reviews, status, roadmap or decision logs.

---

## Required reading

Read before implementation:

1. `docs/backup-restore-hardening/STATUS.md`
2. `docs/backup-restore-hardening/ROADMAP.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md`, especially remaining legacy paths
6. `docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md`
7. `docs/backup-restore-hardening/reports/TASK-1.9-REPORT.md`
8. `docs/backup-restore-hardening/reports/TASK-1.10-REPORT.md`
9. the complete `AppDataCleaner.m`
10. `AppDataCleaner.h`

---

# Part 1 — Quarantine contract

A quarantined selector must:

1. keep the same Objective-C selector and return type;
2. not throw;
3. not inspect the filesystem;
4. not resolve or validate a container;
5. not construct a path;
6. not execute a command or process;
7. not delete, create, rename, copy, write or truncate anything;
8. not access Security/Keychain APIs;
9. not kill, launch, freeze or foreground an application;
10. not read or write `NSUserDefaults`;
11. not dispatch asynchronous work;
12. not call another Clear method;
13. log at most one concise selector-only quarantine message;
14. not log a raw path, bundle identifier, UUID, group identifier, command or entitlement value;
15. return normally.

For `void` methods, quarantine means log-only no-op.

For `securelyWipeFile:`, quarantine means:

```text
return NO
```

It must never return `YES`, because no deletion was attempted or proven.

Do not use input validity, path absence or file existence to manufacture a successful result.

---

# Part 2 — Shared quarantine logger

Add one private file-local helper, or an equivalent implementation, with this semantic contract:

```objc
static void PXLogQuarantinedLegacyClearSelector(SEL selector);
```

It may use only Foundation string/selector formatting and logging.

Expected message meaning:

```text
Legacy Clear selector is quarantined; use the typed Clear entry point.
```

The log may include `NSStringFromSelector(selector)`.

It must not include method arguments or derived values.

Do not persist the event. Do not write a marker/default/file.

---

# Part 3 — Public and ABI-visible quarantine set

Keep every existing declaration in `AppDataCleaner.h` unchanged. Keep exactly one implementation definition for every selector below.

Replace each method body with the quarantine contract.

## 3.1 Broad orchestration aliases

```objc
- (void)performFullCleanup:(NSString *)bundleID;
- (void)performAggressiveCleanupFor:(NSString *)bundleID;
```

These methods currently combine raw UUID reconstruction, heuristic deletion, detached Keychain work and unstructured system cleanup. They must no longer perform any work.

Do not redirect them to `clearDataForBundleID:completion:` or `completeAppDataWipe:`. Silent semantic redirection would still hide result/callback ownership from the caller.

## 3.2 Raw-path mutation APIs

```objc
- (void)completelyWipeContainer:(NSString *)containerPath;
- (BOOL)securelyWipeFile:(NSString *)path;
- (void)fixPermissionsAndRemovePath:(NSString *)path;
- (void)fixPermissionsForPath:(NSString *)path;
```

Requirements:

- no `fileExistsAtPath:`;
- no directory enumeration;
- no `removeItemAtPath:`;
- no shell fallback;
- no quoting;
- no mode/flag mutation;
- no recursive call;
- `securelyWipeFile:` returns `NO` unconditionally after the selector-only log.

## 3.3 Legacy component aliases with raw/fuzzy behavior

Quarantine these public methods:

```objc
- (void)clearAppCache:(NSString *)bundleID;
- (void)clearAppPreferences:(NSString *)bundleID;
- (void)clearAppCookies:(NSString *)bundleID;
- (void)clearAppWebKitData:(NSString *)bundleID;
- (void)clearAppGroupData:(NSString *)bundleID;
- (void)clearPluginKitData:(NSString *)bundleID;
- (void)_internalClearEncryptedData:(NSString *)bundleID;
- (void)secureDataWipe:(NSString *)bundleID;
```

These selectors currently depend on raw UUID reconstruction, wildcard path deletion, recursive discovery or generic raw-path helpers. They must not delegate to any replacement method.

Do not quarantine:

```objc
- (void)clearAppData:(NSString *)bundleID;
- (void)performSecondaryCleanup:(NSString *)bundleID;
```

Those two existing aliases delegate only to the accepted data-only `completeAppDataWipe:` path and must remain unchanged in this task.

## 3.4 Detached Keychain aliases

Quarantine:

```objc
- (void)clearAppKeychain:(NSString *)bundleID;
- (void)clearKeychainData:(NSString *)bundleID;
- (void)clearKeychainItemsForBundleID:(NSString *)bundleID;
- (void)universalKeychainWipeForBundleID:(NSString *)bundleID;
```

They must contain zero references to:

```text
_wipeSelectedKeychainForBundleID
SecItem
security delete-
KeychainBackupHelper
WeaponXKeychainBridge
NSUserDefaults
keychain-access-groups
application-identifier
```

Only full typed Clear owns the immutable Keychain plan, pass accounting and final component result.

Compatibility aliases such as `clearSharedContainers:` or `clearUserDefaults:` that delegate to a quarantined selector may remain unchanged; their target now performs no mutation. Do not expand this task into a full alias-removal exercise.

---

# Part 4 — Internal raw-path helper quarantine set

Replace each body below with a selector-only non-mutating shim.

```objc
- (void)wipeDirectoryContents:(NSString *)path
       keepDirectoryStructure:(BOOL)keepStructure;

- (void)fastWipeDirectoryContents:(NSString *)path
           keepDirectoryStructure:(BOOL)keepStructure
                       timeoutSec:(int)timeoutSec;

- (void)finalSweepForContainer:(NSString *)containerPath;

- (void)wipeWebKitDirectoryContents:(NSString *)path;
```

Use `(void)` casts for unused scalar/object arguments where needed.

These bodies must contain zero:

```text
NSFileManager
fileExistsAtPath
contentsOfDirectoryAtPath
enumeratorAtPath
PXShellQuote
PXShellFinalSweep
runCommand
CommandRunner
removeItem
rm -rf
find
mkdir
write
create
chmod
chown
chflags
touch
```

`PXShellFinalSweep` will become unused. Remove its complete static function definition in this task. Do not replace it with another raw-path shell fragment.

Do not remove or change the accepted `PXShellValidatedApplicationDataWipe` function.

---

# Part 5 — Raw UUID and legacy extension/group mutation quarantine

Quarantine these methods:

```objc
- (void)clearAppGroupContainers:(NSString *)bundleID
                withGroupUUIDs:(NSArray *)groupUUIDs
                    isRootless:(BOOL)isRootless;

- (void)clearAppGroupContainers:(NSString *)bundleID
                withGroupUUIDs:(NSArray *)groupUUIDs;

- (void)clearExtensionContainers:(NSArray *)extensionInfo
                          forApp:(NSString *)bundleID;

- (void)cleanAppGroupContainers:(NSString *)bundleID;
```

They must no longer:

- reconstruct rootful/rootless paths from UUIDs;
- read MCM metadata;
- select groups by bundle/company substring;
- call generic wipe helpers;
- create compatibility directories;
- wipe extension Keychain entries;
- delete extension preferences or databases.

Do not replace their behavior with the typed resolver/validator path. Typed component execution is owned only by the accepted aggregate methods.

---

# Part 6 — Fuzzy and structure-based container mutation quarantine

Quarantine each exact method:

```objc
- (void)_wipeRelatedDataContainersForBundleIDs:(NSArray<NSString *> *)bundleIDs;

- (void)_wipeRelatedSystemGroupContainersForIdentifiers:(NSArray<NSString *> *)idents;

- (void)_wipeContainersInBasePaths:(NSArray<NSString *> *)bases
               matchingSubstrings:(NSArray<NSString *> *)needles
                               tag:(NSString *)tag;

- (void)_wipeDataContainersByIdentifierPrefixOrSubstring:(NSArray<NSString *> *)prefixes
                                               substrings:(NSArray<NSString *> *)substrings
                                                      tag:(NSString *)tag;

- (void)_scrubWebKitStateInSharedContainerBase:(NSString *)base
                                           tag:(NSString *)tag;

- (void)cleanAppSpecificFilesInSharedContainer:(NSString *)containerPath
                                      bundleID:(NSString *)bundleID
                                       appName:(NSString *)appName
                                   companyName:(NSString *)companyName;

- (void)deepCleanSystemSharedContainer:(NSString *)containerPath
                              bundleID:(NSString *)bundleID
                               appName:(NSString *)appName
                           companyName:(NSString *)companyName;
```

These methods currently authorize mutation through one or more unsafe signals:

```text
hasPrefix
containsString
lowercase substring match
company-name inference
filesystem structure
hard-coded UUID special cases
file-name similarity
raw base path supplied by caller
```

After TASK-1.12, their bodies must contain no scan, metadata read, SQLite write, shell command or deletion.

Do not create an allow-list exception for Safari, WebKit, File Provider, Maps or any vendor name.

The existing `_wipeMobileSafariSystemStores` method may keep its fixed, explicit global Safari store operations. Calls from that method into the quarantined fuzzy helpers may remain; they will only log and return. Do not rewrite `_wipeMobileSafariSystemStores` in this task.

---

# Part 7 — Typed Clear must remain byte-identical

Do not modify the bodies of:

```text
PXShellValidatedApplicationDataWipe
PXApplicationDataCommandResultSucceeded
PXApplicationDataPostconditionIsValid
_completeAppDataWipeForApplicationDataRequest:
_completeDataWipeForMigratedRequest:
_clearExactDataContainerComponentForIdentifiers:...
_clearExactAppGroupsComponentForIdentifiers:...
_keychainClearPlanForBundleIdentifier:
_executeKeychainWipeForBundleIdentifier:...
_keychainComponentForPlan:passResults:
clearDataForBundleID:completion:
completeAppDataWipe:
```

Record exact before/after SHA-256 body hashes for all of them.

All hashes must be identical.

The following must remain exact:

```text
PXMigratedDataClearScopes = ApplicationData | ExtensionData | AppGroups | PluginKitData
PXMigratedFullClearScopes = data scopes | Keychain
full aggregate component count = 5
completeAppDataWipe: contains no Keychain execution
callback precedence = ApplicationData -> ExtensionData -> AppGroups -> PluginKitData -> Keychain
```

The typed flow may still invoke methods that now become quarantine shims through legacy residual-cleanup call chains. This is intentional: those unstructured side effects must become no-ops without changing typed request/result accounting or callback behavior.

Do not add a new component, skipped result, warning field or callback error for the omitted legacy side effects.

---

# Part 8 — Public compatibility and Phase 6 boundary

`AppDataCleaner.h` must remain byte-identical.

Do not:

- remove declarations;
- add `deprecated`, `unavailable` or availability attributes;
- rename selectors;
- change return types;
- add a new public typed API;
- add a new protocol;
- expose quarantine state;
- throw exceptions from legacy selectors.

Source/API surface reduction belongs to Phase 6:

```text
TASK-6.1 — Reduce destructive public API surface
TASK-6.2 — Deprecate or remove ambiguous aliases
```

TASK-1.12 only makes the exact compatibility methods non-mutating.

---

# Part 9 — No replacement destructive route

Do not replace quarantined behavior with:

- direct Foundation deletion;
- a new private deletion helper;
- a daemon/helper request;
- a notification transport;
- a shell command;
- `CommandRunner`;
- a typed resolver invocation;
- a validator invocation;
- a path allow-list local to the shim;
- a service/account/filename heuristic;
- a delayed asynchronous deletion;
- a marker that another process consumes;
- a call to `clearDataForBundleID:completion:`;
- a call to `completeAppDataWipe:`.

A quarantine shim must not move the destructive operation elsewhere.

---

# Part 10 — Exact method-boundary gates

For every quarantined `void` method, the body may contain only:

```text
unused-argument casts
one PXLogQuarantinedLegacyClearSelector(_cmd) call
return, if stylistically needed
```

For `securelyWipeFile:`, the body may contain only:

```text
unused-argument cast
one PXLogQuarantinedLegacyClearSelector(_cmd) call
return NO
```

Within the combined quarantine-set bodies, all counts below must be zero:

```text
NSFileManager
fileExistsAtPath
contentsOfDirectoryAtPath
enumeratorAtPath
dictionaryWithContentsOfFile
MCMMetadataIdentifier
PXDataContainerResolver
AppGroupContainerResolver
PXDestructivePathValidator
PXShellQuote
CommandRunner
runCommand
runExecutable
removeItem
createDirectory
writeToFile
moveItem
copyItem
unlink
rmdir
rm -rf
find
mkdir
sqlite3
SecItem
security delete-
_wipeSelectedKeychainForBundleID
PXKill
killall
UIApplication
NSUserDefaults
dispatch_async
dispatch_apply
sleep
hasPrefix
containsString
lowercaseString
```

Raw argument values must not appear in log formatting.

---

# Part 11 — Required full-file and compatibility gates

After implementation:

```text
PXShellFinalSweep definitions: 0
PXShellFinalSweep references: 0
quarantine logger definitions: 1
quarantine logger calls: exactly one per quarantined method definition
securelyWipeFile definitions: 1
securelyWipeFile return YES in body: 0
securelyWipeFile return NO in body: 1
```

Public selector declarations in `AppDataCleaner.h` remain exactly as baseline.

Definitions remain exactly once for at least:

```text
performFullCleanup:
performAggressiveCleanupFor:
completelyWipeContainer:
securelyWipeFile:
fixPermissionsAndRemovePath:
fixPermissionsForPath:
clearAppCache:
clearAppPreferences:
clearAppCookies:
clearAppWebKitData:
clearAppKeychain:
clearAppGroupData:
clearKeychainData:
clearPluginKitData:
_internalClearEncryptedData:
secureDataWipe:
clearKeychainItemsForBundleID:
universalKeychainWipeForBundleID:
```

Typed-path gates:

```text
PXMigratedDataClearScopes declaration: 1
PXMigratedFullClearScopes declaration: 1
PXClearScopeDefaultMask references in migrated orchestration: 0
receipt tokens: 0
main legacy Keychain wrapper calls: 0
completeAppDataWipe Keychain calls: 0
full aggregate component count: 5
```

TASK-1.11 permission/marker gates must remain:

```text
chmod -R: 0
find -exec chmod: 0
chown -R: 0
chflags -R: exactly 1 and only in PXShellValidatedApplicationDataWipe
active shell touch: 0
.nomedia: 0
.initialized: 0
AssistantServices target: 0
Keychain temporary 0700: 1
Keychain helper 0755: 1
```

---

# Part 12 — Protected-file and source-scope verification

Run:

```text
git diff --exit-code -- \
  AppDataCleaner.h \
  AppEntitlementsReader.h AppEntitlementsReader.m \
  PXResolvedContainer.h PXResolvedContainer.m \
  PXDataContainerResolver.h PXDataContainerResolver.m \
  PXDestructivePathValidator.h PXDestructivePathValidator.m \
  PXClearRequest.h PXClearRequest.m \
  PXClearResult.h PXClearResult.m \
  CommandRunner.h CommandRunner.m \
  AppGroupContainerResolver.h AppGroupContainerResolver.m \
  AppDataBackupManager.h AppDataBackupManager.m \
  KeychainGroupsViewController.m ProjectXViewController.m \
  WeaponXKeychainBridge/Tweak.m \
  KeychainHelper/backup_helper.m \
  KeychainHelper/KeychainBackupHelper.h \
  KeychainHelper/KeychainBackupHelper.m \
  Makefile
```

Expected exit code:

```text
0
```

No source file except `AppDataCleaner.m` may differ from the baseline because of this task.

---

# Part 13 — Required scenario matrix

Report at least these scenarios honestly as `STATIC PASS`, `STATIC COVERAGE / DEVICE PENDING`, or `DEVICE PASS/FAIL`:

1. `performFullCleanup:` valid bundle identifier;
2. `performFullCleanup:` invalid/nil input;
3. `performAggressiveCleanupFor:` valid bundle identifier;
4. `completelyWipeContainer:` arbitrary absolute path;
5. `completelyWipeContainer:` application-bundle path;
6. `completelyWipeContainer:` canonical data-container path;
7. `securelyWipeFile:` existing file;
8. `securelyWipeFile:` existing directory;
9. `securelyWipeFile:` absent path;
10. `securelyWipeFile:` returns `NO` in every case;
11. `fixPermissionsAndRemovePath:` existing path;
12. `fixPermissionsForPath:` existing path;
13. `wipeDirectoryContents:` with keep structure true;
14. fast wipe with keep structure false;
15. final sweep with canonical path;
16. WebKit wipe with existing tree;
17. public cache clear alias;
18. public preferences clear alias;
19. public cookies clear alias;
20. public WebKit clear alias;
21. public App Group clear alias;
22. public PluginKit clear alias;
23. legacy encrypted-data alias;
24. secure-data wipe alias;
25. detached app Keychain alias;
26. detached Keychain data alias;
27. aggressive Keychain-items alias;
28. universal Keychain alias;
29. raw rootful group UUID input;
30. raw rootless group UUID input;
31. raw extension dictionary input;
32. group company-name substring match;
33. related data-container prefix match;
34. related data-container substring match;
35. SystemGroup substring match;
36. arbitrary base-path substring scan;
37. structure-based WebKit shared-container detection;
38. app-specific filename substring detection;
39. hard-coded shared-container UUID case;
40. Safari exact fixed global-store cleanup remains outside quarantined helper bodies;
41. typed ApplicationData body hash unchanged;
42. typed ExtensionData/PluginKitData body hash unchanged;
43. typed AppGroups body hash unchanged;
44. Keychain plan/execution/accounting body hashes unchanged;
45. final five-scope aggregate unchanged;
46. callback precedence unchanged;
47. completeAppDataWipe remains data-only;
48. AppDataCleaner.h byte-identical;
49. Backup/Restore files unchanged;
50. TASK-1.11 permission/marker gates remain satisfied;
51. no raw input value is written to quarantine logs;
52. no replacement command/helper/daemon transport is added;
53. report and source contain no NUL bytes;
54. cumulative diff whitespace checks pass.

Do not claim runtime evidence that was not executed.

---

# Part 14 — Required report contents

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md
```

The report must include:

1. baseline HEAD and initial status;
2. exact production file scope;
3. protected-file SHA-256 before/after;
4. exact typed-method body hashes before/after;
5. the full quarantine selector inventory;
6. declaration and definition counts;
7. the shared logger contract;
8. proof that no raw argument is logged;
9. proof that `securelyWipeFile:` always returns `NO`;
10. method-boundary forbidden-token counts;
11. proof that detached Keychain aliases contain no Keychain operation;
12. proof that fuzzy/raw UUID methods contain no scan/mutation;
13. proof that `PXShellFinalSweep` was removed;
14. five-scope and callback non-regression;
15. TASK-1.11 permission/marker non-regression;
16. exact external caller inventory for the quarantine selector names;
17. protected-file diff result;
18. whitespace, CRLF and NUL audit;
19. the complete scenario matrix;
20. build status and remaining device risks;
21. focused diff excerpts only, not the entire multi-thousand-line file.

The report must end exactly with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

---

# Part 15 — Verification commands

Before commit:

```text
git status --short --untracked-files=all
git diff --check
git diff --stat -- AppDataCleaner.m
git diff -- AppDataCleaner.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 17d76c02e049b40bf84a161d76e90ec02b9485bf..HEAD --check
git diff --name-status 17d76c02e049b40bf84a161d76e90ec02b9485bf..HEAD
```

Implementation commit must contain only:

```text
AppDataCleaner.m
docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md
```

---

# Acceptance checklist

- [ ] Baseline is correct.
- [ ] Only `AppDataCleaner.m` changes in production.
- [ ] Report is created at the required path.
- [ ] `AppDataCleaner.h` is byte-identical.
- [ ] One selector-only quarantine logger exists.
- [ ] Every exact quarantine selector remains implemented.
- [ ] Every quarantined void selector is non-mutating.
- [ ] `securelyWipeFile:` returns `NO` and performs no inspection/mutation.
- [ ] Raw-path helper bodies contain no filesystem or process operation.
- [ ] Raw UUID/group/extension bodies contain no reconstruction or mutation.
- [ ] Fuzzy prefix/substring/structure methods contain no scan or mutation.
- [ ] Detached Keychain aliases perform no Keychain operation.
- [ ] `PXShellFinalSweep` is removed.
- [ ] No replacement destructive route is added.
- [ ] Typed Clear bodies are byte-identical.
- [ ] Four-scope and five-scope masks remain exact.
- [ ] Callback precedence remains exact.
- [ ] `completeAppDataWipe:` remains data-only.
- [ ] TASK-1.11 permission/marker gates remain satisfied.
- [ ] Backup/Restore, UI, resolvers, validator, models and Makefile remain unchanged.
- [ ] Protected diff passes.
- [ ] `git diff --check` passes.
- [ ] NUL and whitespace audits pass.
- [ ] GitHub Actions succeeds or owner confirms build.
- [ ] Coordinator review accepts the task.

Stop after TASK-1.12.

Do not begin Phase 2.

Do not implement TASK-2.1.
