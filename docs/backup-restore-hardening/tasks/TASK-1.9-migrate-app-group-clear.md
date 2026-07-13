# TASK-1.9 — Migrate App Group Clear

- Status: READY
- Phase: Phase 1 — Clear Data Safety Boundary
- Allowed production files:
  - `AppGroupContainerResolver.h`
  - `AppGroupContainerResolver.m`
  - `AppDataCleaner.m`
- Required report: `docs/backup-restore-hardening/reports/TASK-1.9-REPORT.md`
- Baseline HEAD: `6f74381ea0cf1e7172ff399bc0fac511ac358089`
- Next task: TASK-1.10 remains LOCKED

## Objective

Migrate the AppGroups portion of the main Clear flow away from mutable legacy resolver objects, UUID/path reconstruction, fuzzy ownership checks, batched void commands and destructive final sweeps.

The migrated flow must:

1. derive exact App Group identifiers only from the target application's signed entitlements;
2. resolve one group identifier and one root at a time through a typed exact App Group resolver;
3. represent the selected candidate as `PXResolvedContainerKindAppGroup`;
4. immediately validate it with `PXDestructivePathValidator`;
5. mutate only the canonical path returned by the validator;
6. execute one bounded strict command per unique physical container;
7. revalidate every authorized identity associated with that physical container;
8. enforce the strict postcondition;
9. publish a truthful `PXClearScopeAppGroups` component result;
10. expand the internal migrated aggregate from three scopes to four scopes.

ApplicationData, ExtensionData and PluginKitData behavior accepted through TASK-1.8A must not regress.

## Required reading

Before editing, read:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.8-REVIEW.md`
5. `docs/backup-restore-hardening/reviews/TASK-1.8A-REVIEW.md`
6. `docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md`
7. `docs/backup-restore-hardening/reports/TASK-1.8A-REPORT.md`
8. `PXResolvedContainer.h/.m`
9. `PXDestructivePathValidator.h/.m`
10. `PXClearRequest.h/.m`
11. `PXClearResult.h/.m`
12. `AppGroupContainerResolver.h/.m`
13. `AppEntitlementsReader.h/.m`
14. the complete `AppDataCleaner.m`
15. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`

## Scope boundary

### Allowed production changes

Only:

```text
AppGroupContainerResolver.h
AppGroupContainerResolver.m
AppDataCleaner.m
```

### Protected production files

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
AppDataBackupManager.h
AppDataBackupManager.m
Makefile
```

Do not modify Backup, Restore, UI or Keychain implementation files.

The existing legacy App Group resolver API is used by Backup and Restore. It must remain source-compatible.

## Part 1 — Typed exact App Group resolver

Extend `AppGroupContainerResolver.h` to import:

```objc
#import "PXResolvedContainer.h"
```

Add one error domain and a closed error enum:

```objc
FOUNDATION_EXPORT NSString * const PXAppGroupContainerResolverErrorDomain;

typedef NS_ENUM(NSInteger, PXAppGroupContainerResolverErrorCode) {
    PXAppGroupContainerResolverErrorInvalidInput = 1,
    PXAppGroupContainerResolverErrorEnumerationFailed = 2,
    PXAppGroupContainerResolverErrorAmbiguousMatch = 3,
    PXAppGroupContainerResolverErrorInvalidCandidate = 4,
    PXAppGroupContainerResolverErrorMetadataInvalid = 5,
};
```

Add one typed method:

```objc
- (nullable PXResolvedContainer *)resolveAppGroupContainerForGroupIdentifier:
    (NSString *)groupIdentifier
    root:(PXResolvedContainerRoot)root
    error:(NSError * _Nullable * _Nullable)error;
```

Keep unchanged:

```objc
- (NSArray<AppGroupContainerInfo *> *)resolveGroupContainersForGroupIDs:
    (NSArray<NSString *> *)groupIDs;
```

Do not remove or change the properties of `AppGroupContainerInfo` in TASK-1.9. Backup/Restore migration is outside scope.

Do not add batch typed APIs, cache APIs, custom-base APIs or singleton APIs.

## Part 2 — Typed resolver input contract

At entry:

```objc
if (error != NULL) {
    *error = nil;
}
```

`groupIdentifier` must:

- be an `NSString` at runtime;
- be nonempty;
- contain at least one character outside `whitespaceAndNewlineCharacterSet`;
- contain no Unicode U+0000.

Do not impose a bundle-ID syntax whitelist.

Do not trim, lowercase, uppercase, normalize or rewrite accepted input.

Accept only:

```text
PXResolvedContainerRootRootful
PXResolvedContainerRootRootless
```

Invalid identifier or root returns `nil` with `PXAppGroupContainerResolverErrorInvalidInput`.

## Part 3 — Fixed root mapping

Use exactly:

| Root | Raw base path |
|---|---|
| Rootful | `/private/var/mobile/Containers/Shared/AppGroup` |
| Rootless | `/containers/Shared/AppGroup` |

Do not scan:

```text
/var/mobile/Containers/Shared/AppGroup
```

as an additional rootful alias.

Do not accept a caller-supplied base. Do not fallback between roots.

## Part 4 — Exact App Group metadata resolution

For the selected root:

1. absent base returns `nil` with no error;
2. base existing as a non-directory returns `EnumerationFailed`;
3. enumeration failure returns `EnumerationFailed`;
4. enumerate immediate children only;
5. keep only valid non-hidden UUID names;
6. sort child names with exact `compare:`;
7. require each candidate to be a real non-symlink directory using `lstat`;
8. inspect only `.com.apple.mobile_container_manager.metadata.plist`;
9. require the metadata path to be a regular non-symlink file;
10. require the plist root to be `NSDictionary`.

Read only:

```text
MCMMetadataIdentifier
```

Supported metadata forms:

### String form

A string candidate matches only when:

```objc
[(NSString *)liveIdentifier isEqualToString:groupIdentifier]
```

The string must satisfy the same nonempty/non-whitespace/no-U+0000 identifier contract.

### Array form

For an array:

- only string elements can match;
- non-string elements are not matches;
- count exact case-sensitive occurrences of `groupIdentifier`;
- zero exact occurrences means this candidate does not match;
- one exact occurrence means this candidate matches;
- more than one exact occurrence returns `MetadataInvalid` and stops resolution.

Do not use `containsObject:` as the only policy because duplicate exact occurrences must be detected.

Unsupported metadata value types do not match.

Do not use:

- `hasPrefix:`;
- `hasSuffix:`;
- `containsString:`;
- company or short-name matching;
- case-insensitive comparison;
- content scanning;
- first/newest/arbitrary candidate selection.

## Part 5 — Typed result construction and ambiguity

For one exact matched candidate, construct:

```objc
[[PXResolvedContainer alloc]
    initWithKind:PXResolvedContainerKindAppGroup
            root:root
 requestedIdentifier:groupIdentifier
  metadataIdentifier:groupIdentifier
       containerUUID:uuid
       containerPath:rawCandidatePath];
```

For array metadata, the model's `metadataIdentifier` is the exact requested identifier that occurred once in the array. The live validator will revalidate the array form.

Outcomes:

```text
0 exact candidates -> nil, no error
1 exact candidate  -> typed PXResolvedContainer
2+ exact candidates -> AmbiguousMatch
model creation failure -> InvalidCandidate
```

Do not return `AppGroupContainerInfo` from the new typed method.

## Part 6 — Exact entitlement group identifiers

Add one centralized private helper in `AppDataCleaner.m`, recommended shape:

```objc
- (nullable NSArray<NSString *> *)_exactApplicationGroupIdentifiersForBundleIdentifier:
    (NSString *)bundleIdentifier
    error:(NSError * _Nullable * _Nullable)error;
```

Use `AppEntitlementsReader fullEntitlementsForBundleID:error:` once per migrated clear request.

The source of App Group identity is limited to the signed entitlement keys:

```text
com.apple.security.application-groups
application-groups
```

Rules:

1. Entitlement extraction failure returns `nil` plus an error.
2. If neither key exists, return an empty array with no error.
3. If a present key is not an `NSArray`, fail closed.
4. Every array element must be a runtime `NSString` satisfying nonempty/non-whitespace/no-U+0000.
5. Any invalid element fails the whole AppGroups discovery.
6. Combine identifiers from both keys.
7. Exact duplicate identifiers across or within the entitlement arrays are deduplicated as the same signed identity.
8. Return exact strings sorted using `compare:`.
9. Do not trim or normalize identifiers.

Do not derive App Group identifiers from:

- application bundle identifier prefixes;
- company or short name;
- files inside group containers;
- existing group metadata scans;
- `findAppGroupUUIDs:`;
- `findRootlessAppGroupUUIDs:`;
- `findGroupContainerUUIDsForBundleID:`;
- `_resolvedAppGroupUUIDsFromEntitlements:rootless:`.

The helper must not mutate application bundles or containers.

## Part 7 — Four-scope migrated request and aggregate

Change the exact internal migrated scope mask to:

```objc
PXClearScopeApplicationData |
PXClearScopeExtensionData |
PXClearScopeAppGroups |
PXClearScopePluginKitData
```

Do not use `PXClearScopeDefaultMask`.

Both:

```objc
clearDataForBundleID:completion:
completeAppDataWipe:
```

must create this same exact four-scope request.

The aggregate must contain exactly four components in canonical scope order:

1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData

Update structural validation accordingly.

Do not add Keychain to the typed request/result in TASK-1.9.

## Part 8 — Remove App Group work from ApplicationData component

`_completeAppDataWipeForApplicationDataRequest:` must become ApplicationData-only.

Remove from that method:

- `_resolvedAppGroupUUIDsFromEntitlements:` calls;
- `groupUUIDs` and `rootlessGroupUUIDs` state;
- group-based timeout calculations;
- `_wipeCacheGroupUUIDs` and `_wipeCacheRootlessGroupUUIDs` writes;
- `groupWipeParts` construction;
- raw rootful/rootless group path reconstruction;
- `PXShellWipeContainerKeepMetadata` group fragments;
- batched group command execution;
- “group containers wiped successfully” unconditional success logging;
- group paths in `finalSweepPaths`;
- `finalSweepForContainer:` calls for App Group targets.

ApplicationData unit counts and failures must reflect only rootful/rootless ApplicationData containers.

Do not change the accepted ApplicationData resolver, validator, command, postvalidation or postcondition policy.

## Part 9 — AppGroups planning model and alias collapse

Create one internal AppGroups component path.

Deterministic resolution order:

```text
group identifiers sorted ascending
  rootful
  rootless
```

For every `(groupIdentifier, root)` tuple:

1. call `resolveAppGroupContainerForGroupIdentifier:root:error:`;
2. `nil` plus no error means absent and does not count as attempted;
3. resolver error is one failed attempted unit;
4. a resolved model must be validated immediately with `PXDestructivePathValidator`;
5. validation failure is one failed attempted unit;
6. successful validation produces a canonical path and an authorized model identity.

Before mutation, build a deterministic unique physical-container plan keyed by the exact canonical path.

App Group metadata may map multiple entitled group identifiers to the same physical container. Therefore:

- the first canonical-path occurrence creates one physical container plan entry;
- a later exact identity resolving and validating to the same canonical path is attached as an alias identity;
- it does not create a second command or second attempted physical-container unit;
- do not treat this valid alias case as ambiguity;
- retain all associated `PXResolvedContainer` models for post-command identity revalidation.

Attempted-unit accounting is:

```text
resolver/validation failed tuples
+
unique physical containers entering execution
```

Do not count an exact alias attached to an existing physical plan as another attempted unit.

Do not deduplicate by UUID string alone. Deduplicate only after canonical validation using the full canonical path.

## Part 10 — AppGroups mutation boundary

For each unique physical App Group container plan entry:

1. use only the canonical validator output;
2. build the existing strict validated data-container wipe command;
3. run exactly one bounded `CommandResult` command;
4. command failure is one failed unit;
5. after command success, revalidate every associated `PXResolvedContainer` identity;
6. every revalidation must return the same exact canonical path;
7. run the strict data-container postcondition once;
8. only then count the physical unit as succeeded.

Continue all remaining plan entries after any failure.

Command success requires:

- non-nil result;
- no spawn error;
- no runner error;
- not timed out;
- normal exit;
- exit code zero;
- no terminating signal;
- stdout not truncated;
- stderr not truncated.

Reuse the accepted strict wipe and postcondition helpers from TASK-1.7/TASK-1.8. Do not weaken or duplicate their behavior.

Do not use for migrated App Groups:

- raw UUID paths;
- `container.containerPath` after validation;
- `/var/mobile/Containers/Shared/AppGroup/%@` reconstruction;
- `/containers/Shared/AppGroup/%@` reconstruction;
- `PXShellWipeContainerKeepMetadata`;
- `runBatchedCommandsWithPrivileges:`;
- void command wrappers;
- `completelyWipeContainer:`;
- `fixPermissionsForPath:`;
- `wipeDirectoryContents:`;
- `finalSweepForContainer:`;
- recursive `chmod 0777` or `chflags` helpers.

## Part 11 — AppGroups component result

Use a stable private failure domain:

```text
PXAppGroupsClear
```

Use fixed private failure codes covering at least:

```text
InvalidRequest
EntitlementDiscoveryFailed
ResolutionFailed
ValidationFailed
ExecutionFailed
PostconditionFailed
InternalResultFailure
```

Keep the first failure snapshot while continuing remaining units.

Do not place paths, UUIDs, commands, metadata contents, directory listings, stdout or stderr in structured detail/failure messages.

### No declared App Groups

Return `Skipped`, counts `0/0/0`, no failure and exact detail:

```text
No application-group identifiers were declared by the app
```

### Declared identifiers but no exact containers

Return `Skipped`, counts `0/0/0`, no failure and exact detail:

```text
No exact App Group containers were found
```

### Success

```text
attempted > 0
succeeded == attempted
failed == 0
status == Succeeded
failure == nil
```

### Failure or partial success

Any failed unit makes status `Failed`.

Counts must retain exact partition semantics:

```text
failed == attempted - succeeded
```

A successful physical container and one resolver error is a valid partial failure result.

## Part 12 — Final read-only App Group verification

Track:

- canonical paths of all validated physical App Group containers;
- the subset that completed initial command/postvalidation/postcondition successfully.

After remaining legacy non-AppGroup work:

- run the strict postcondition read-only on each canonical App Group path;
- if a previously successful physical unit now fails, decrement succeeded and increment failed without changing attempted;
- if an already failed unit still fails, log only and do not double-count;
- do not perform another destructive App Group sweep.

The final component returned in the four-scope aggregate must reflect this final read-only verification.

## Part 13 — Canonical App Group cache

Remove:

```objc
NSArray *_wipeCacheGroupUUIDs;
NSArray *_wipeCacheRootlessGroupUUIDs;
```

Add:

```objc
NSArray<NSString *> *_wipeCacheAppGroupCanonicalPaths;
```

Requirements:

- store only validator-returned canonical paths;
- preserve deterministic first-seen physical-plan order;
- copy before storing;
- never reconstruct from UUID;
- cache-hit `verifyDataCleared:` uses these paths directly;
- clear the cache when consumed.

On cache miss, legacy App Group inspection may remain read-only for standalone verifier compatibility and must be reported.

## Part 14 — Remove App Group mutation bypasses from migrated main flow

Audit every helper reachable after the typed AppGroups component.

The migrated main Clear path must not subsequently mutate App Group containers through:

- `_resolvedAppGroupUUIDsFromEntitlements:rootless:`;
- `findAppGroupUUIDs:` or aggressive variants;
- `findRootlessAppGroupUUIDs:`;
- `findGroupContainerUUIDsForBundleID:`;
- `optimized_findAppGroupUUIDs:`;
- `clearAppGroupContainers:withGroupUUIDs:isRootless:`;
- `clearAppGroupData:`;
- `cleanAppGroupContainers:`;
- `_internalClearEncryptedDataOutsideMainApplicationContainer:` App Group deep scan;
- `finalSweepForContainer:` group paths;
- MobileSafari fuzzy AppGroup scans or structure-based AppGroup scrubs.

Required specific changes:

1. Remove the App Group deep-scan block from `_internalClearEncryptedDataOutsideMainApplicationContainer:deepClean:` while preserving preference-path cleanup outside containers.
2. In `_wipeMobileSafariSystemStores`, remove or bypass only the operations whose base is `Shared/AppGroup`:
   - substring-based `_wipeContainersInBasePaths:` AppGroup call;
   - structure-based `_scrubWebKitStateInSharedContainerBase:` AppGroup rootful call;
   - structure-based `_scrubWebKitStateInSharedContainerBase:` AppGroup rootless call.
3. Preserve MobileSafari global Safari/WebKit/Cookie and SystemGroup behavior; SystemGroup migration is not TASK-1.9.

Legacy public/private App Group helpers may remain for external compatibility, but the migrated main flow must not call them.

Do not rewrite their implementations unless required by the two explicit bypass removals above.

## Part 15 — Callback failure precedence

Consume the four-scope aggregate using this exact precedence:

```text
1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData
5. Keychain
```

The first failed migrated component determines callback `NSError`.

Lower-precedence migrated failures and Keychain failures must still be logged.

Skipped AppGroups is not a callback failure.

Aggregate nil, missing component, wrong scope mask or structural invalidity returns an internal migrated-clear error.

Do not change one-shot completion, watchdog, freeze/unfreeze, background-task or main-thread callback mechanics.

## Part 16 — Compatibility requirements

Keep public selectors unchanged:

```objc
- (void)clearDataForBundleID:(NSString *)bundleID
                  completion:(void (^)(BOOL success, NSError *error))completion;

- (void)completeAppDataWipe:(NSString *)bundleID;
```

`completeAppDataWipe:` must create the same exact four-scope request and log all four component outcomes.

Keep the legacy App Group resolver method source-compatible for Backup/Restore:

```objc
- (NSArray<AppGroupContainerInfo *> *)resolveGroupContainersForGroupIDs:
    (NSArray<NSString *> *)groupIDs;
```

Do not modify `AppDataBackupManager.m` in this task.

## Part 17 — Out of scope

Do not:

- migrate Keychain into `PXClearResult`;
- modify extension Keychain or preference cleanup;
- migrate SystemGroup containers;
- modify Backup or Restore;
- remove legacy App Group APIs;
- redesign `AppGroupContainerInfo`;
- add application-bundle writes;
- modify generic destructive helper bodies except the explicitly required AppGroup bypass removal in `_wipeMobileSafariSystemStores`;
- begin TASK-1.10.

## Part 18 — Required static gates

After implementation, verify:

```text
new typed App Group resolver method declaration: 1
new typed App Group resolver method implementation: 1
legacy resolveGroupContainersForGroupIDs declaration: 1
legacy resolveGroupContainersForGroupIDs implementation: 1
AppGroup typed result kind: PXResolvedContainerKindAppGroup
rootful raw base spelling: /private/var/mobile/Containers/Shared/AppGroup
rootless raw base spelling: /containers/Shared/AppGroup
rootful /var/mobile alias inside typed resolver: 0
fuzzy authorization tokens inside typed resolver: 0
PXMigratedDataClearScopes includes AppGroups: 1
four aggregate components: exactly 4
callback precedence order: ApplicationData, ExtensionData, AppGroups, PluginKitData
_wipeCacheGroupUUIDs references: 0
_wipeCacheRootlessGroupUUIDs references: 0
_wipeCacheAppGroupCanonicalPaths: present
migrated AppGroup batched command references: 0
migrated AppGroup raw UUID path reconstruction: 0
migrated AppGroup finalSweepForContainer calls: 0
main-flow AppGroup deep encrypted scan: 0
MobileSafari Shared/AppGroup fuzzy wipe calls: 0
MobileSafari Shared/AppGroup structure scrub calls: 0
TASK-1.4 receipt tokens: 0
```

Audit every remaining `Shared/AppGroup` occurrence in `AppDataCleaner.m` and classify:

- migrated typed resolver/mutation;
- cache-hit read-only verification;
- standalone read-only compatibility;
- unreachable legacy compatibility mutation;
- SystemGroup/non-AppGroup unrelated behavior.

No remaining Shared/AppGroup mutation may be reachable from the migrated main Clear flow except through the canonical typed AppGroups component.

## Part 19 — Scenario matrix

Report static/runtime evidence for at least:

1. invalid group identifier input;
2. invalid root;
3. missing rootful base;
4. missing rootless base;
5. base non-directory;
6. enumeration failure;
7. metadata string exact match;
8. metadata string mismatch;
9. metadata array exact occurrence once;
10. metadata array zero occurrence;
11. metadata array duplicate exact occurrence;
12. non-string array members;
13. two exact physical containers in one root;
14. model construction failure;
15. entitlement extraction error;
16. neither entitlement key present;
17. malformed entitlement key type;
18. invalid entitlement element;
19. duplicate exact identifier in entitlement arrays;
20. one rootful App Group container;
21. one rootless App Group container;
22. same group ID in both roots;
23. two group IDs mapping to one physical container;
24. resolver error plus another successful physical container;
25. validator failure;
26. command failure;
27. output truncation;
28. post-command identity change;
29. postcondition failure;
30. final read-only postcondition regression;
31. no exact containers for declared identifiers;
32. all AppGroups succeed;
33. partial AppGroups success;
34. ApplicationData and AppGroups both fail;
35. AppGroups and PluginKitData both fail;
36. AppGroups failure plus Keychain failure;
37. no AppGroups with all other migrated components successful;
38. standalone verifier cache miss remains read-only;
39. MobileSafari no longer performs fuzzy AppGroup mutation after typed component;
40. legacy Backup/Restore resolver call remains source-compatible.

## Part 20 — Baseline and report requirements

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
SHA-256 of every protected file
```

Expected HEAD:

```text
6f74381ea0cf1e7172ff399bc0fac511ac358089
```

The current coordinator files may be uncommitted. Treat them as protected baseline; do not stage, revert, format or rewrite them unless explicitly listed as the agent report.

The report must include:

1. baseline and exact files changed;
2. typed resolver public API and error mapping;
3. legacy API compatibility proof;
4. root and metadata matrix;
5. string/array exact occurrence policy;
6. entitlement identity extraction;
7. deterministic order and alias collapse;
8. unit accounting formula;
9. canonical-only mutation proof;
10. bounded command mapping;
11. post-command identity revalidation for all aliases;
12. strict postcondition and final read-only verification;
13. four-scope aggregate;
14. callback failure precedence;
15. ApplicationData group-work removal;
16. canonical cache migration;
17. main-flow bypass audit;
18. MobileSafari AppGroup bypass removal;
19. protected checksums;
20. complete source diff/stat;
21. whitespace/NUL/generated/binary audit;
22. scenario matrix;
23. remaining risks.

Required commands:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- AppGroupContainerResolver.h AppGroupContainerResolver.m AppDataCleaner.m
git diff -- AppGroupContainerResolver.h AppGroupContainerResolver.m AppDataCleaner.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
```

The report must end with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

Stop after TASK-1.9.

Do not implement TASK-1.10.
