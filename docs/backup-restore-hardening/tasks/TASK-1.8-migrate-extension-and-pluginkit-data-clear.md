# TASK-1.8 — Migrate ExtensionData and PluginKitData Clear

## Metadata

- Status: READY
- Phase: Phase 1 — Clear Data Safety Boundary
- Dependency: TASK-1.7 accepted and owner build gate completed
- Allowed production files:
  - `PXDataContainerResolver.h`
  - `PXDataContainerResolver.m`
  - `AppDataCleaner.m`
- Required report: `docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md`
- Suggested commit: `phase1(task-1.8): migrate extension and pluginkit data clear`

## Objective

Migrate the ExtensionData and PluginKitData portions of the main Clear flow away from prefix-based metadata discovery, raw UUID path reconstruction, generic permission mutation and void/batched shell execution.

The migrated flow must derive the exact installed extension bundle identifiers from the application bundle using read-only inspection, then resolve each mutable container by exact `MCMMetadataIdentifier`, validate the resolved object immediately, mutate only the canonical validator output, revalidate after execution and publish structured component results.

The target sequence is:

```text
exact installed .appex identifiers
  -> generic exact data-container resolver
  -> canonical destructive-path validator
  -> one bounded strict command per resolved container
  -> post-command validator
  -> strict filesystem postcondition
  -> ExtensionData and PluginKitData component results
```

TASK-1.8 must not migrate App Groups or Keychain results and must not modify application bundle contents.

## Required reading

Read in full before editing:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.7-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md`
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

Audit but do not use for migrated target authorization:

- `optimized_findExtensionContainers:dataDirs:rootlessDataDirs:bundleDirs:rootlessBundleDirs:`
- `findExtensionContainers:`
- `findBundleUUIDForExtension:`
- `findRootlessBundleUUIDForExtension:`
- `clearExtensionContainers:forApp:`
- `clearPluginKitData:`
- `optimized_findBundleContainerUUID:inDirectories:rootlessDirs:`

## Allowed changes

### `PXDataContainerResolver.h/.m`

Add one generic exact resolver API and refactor the existing application-data API to delegate to it without behavior regression.

### `AppDataCleaner.m`

Add exact read-only extension identifier discovery, migrate ExtensionData and PluginKitData container execution, replace raw extension cache state with canonical paths, create structured results and integrate their failures into the existing legacy completion callback.

### Report

Create only:

```text
docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md
```

## Protected files

Do not modify:

- `AppDataCleaner.h`
- `PXResolvedContainer.h/.m`
- `PXDestructivePathValidator.h/.m`
- `PXClearRequest.h/.m`
- `PXClearResult.h/.m`
- `CommandRunner.h/.m`
- `AppGroupContainerResolver.h/.m`
- `AppDataBackupManager.h/.m`
- `Makefile`
- Backup, Restore, UI or Keychain implementation files

## Generic exact data-container resolver

Add this public method to `PXDataContainerResolver`:

```objc
- (nullable PXResolvedContainer *)resolveDataContainerForIdentifier:(NSString *)identifier
                                                               kind:(PXResolvedContainerKind)kind
                                                               root:(PXResolvedContainerRoot)root
                                                              error:(NSError * _Nullable * _Nullable)error;
```

Keep the existing method unchanged in the public header:

```objc
- (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                          root:(PXResolvedContainerRoot)root
                                                                         error:(NSError * _Nullable * _Nullable)error;
```

The existing method must delegate to the generic method with:

```objc
PXResolvedContainerKindApplicationData
```

No existing call site may need modification solely because of the resolver refactor.

### Allowed kinds

The generic resolver accepts exactly:

```text
PXResolvedContainerKindApplicationData
PXResolvedContainerKindExtensionData
PXResolvedContainerKindPluginKitData
```

It rejects:

```text
PXResolvedContainerKindAppGroup
all invalid enum values
```

App Group metadata semantics remain owned by `AppGroupContainerResolver` and later tasks.

### Fixed base mapping

| Kind | Rootful | Rootless |
|---|---|---|
| ApplicationData | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| ExtensionData | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| PluginKitData | `/private/var/mobile/Containers/Data/PluginKitPlugin` | `/containers/Data/PluginKitPlugin` |

Do not:

- accept custom bases;
- scan `/var/mobile/...` as a rootful alias;
- fall back between roots or kinds;
- scan application bundle containers;
- resolve App Groups.

### Generic resolver behavior

Preserve the TASK-1.2 rules:

- clear `*error` at entry;
- validate identifier, kind and root;
- base absent means nil with no error;
- base non-directory or enumeration failure means `EnumerationFailed`;
- enumerate immediate UUID children only;
- deterministic child-name sorting;
- read only `.com.apple.mobile_container_manager.metadata.plist`;
- read only string `MCMMetadataIdentifier`;
- exact case-sensitive `isEqualToString:` matching;
- zero match means nil with no error;
- one match returns a `PXResolvedContainer` with the requested kind;
- two or more exact matches in the selected kind/root fail with `AmbiguousMatch`;
- exact match that cannot construct the value object fails with `InvalidCandidate`.

Do not add error codes.

Error descriptions may become kind-neutral but must not contain directory listings, metadata contents or candidate paths.

### Resolver forbidden logic

The generic resolver must not use:

- `hasPrefix:`;
- `hasSuffix:`;
- `containsString:`;
- lowercase or case-insensitive matching;
- application/company short-name heuristics;
- content scanning;
- first/newest/arbitrary match;
- recursive enumeration;
- application bundle inspection;
- shell/process APIs.

## Exact installed extension identifier discovery

Add a private read-only helper in `AppDataCleaner.m`, recommended shape:

```objc
- (nullable NSArray<NSString *> *)_installedExtensionBundleIdentifiersForApplicationIdentifier:
    (NSString *)bundleIdentifier
    error:(NSError * _Nullable * _Nullable)error;
```

The exact selector name may differ, but there must be one centralized helper with the following contract.

### Fixed read-only application bundle roots

Inspect only:

```text
/var/containers/Bundle/Application
/containers/Bundle/Application
```

Do not inspect `/var/mobile/Containers/Bundle/Application` as an alias in this migrated discovery path.

Application bundles remain read-only. This helper must not invoke the destructive validator because application bundle is deliberately not a `PXResolvedContainerKind`.

### Main app bundle selection

For each fixed root in rootful then rootless order:

1. treat an absent root as no candidate;
2. require the root to be a real directory before enumeration;
3. enumerate immediate UUID-named container directories deterministically;
4. reject symlink container entries;
5. enumerate immediate `.app` children;
6. reject symlink `.app` entries;
7. require `Info.plist` to be a regular non-symlink file;
8. read `CFBundleIdentifier` as an `NSString`;
9. match exactly against the requested application bundle identifier.

Across both roots:

```text
0 exact app bundle matches  -> discovery failure
1 exact app bundle match    -> inspect that app bundle
2+ exact app bundle matches -> ambiguity failure
```

Do not choose the first, newest or rootful-preferred match when more than one exact main app bundle exists.

Do not use `optimized_findBundleContainerUUID:` for migrated extension authorization.

### `.appex` locations

Inspect only real, non-symlink immediate `.appex` directories at:

```text
<MainApp>.app/<Extension>.appex
<MainApp>.app/PlugIns/<Extension>.appex
<MainApp>.app/Plugins/<Extension>.appex
```

Do not recursively search arbitrary descendants.

For each `.appex` candidate:

- require real directory, not symlink;
- require regular non-symlink `Info.plist`;
- require valid string `CFBundleIdentifier`;
- validate the identifier with the same strict bundle-identifier contract as `PXClearRequest`;
- retain the identifier exactly without normalization;
- do not require the extension identifier to have the parent app identifier as a prefix.

The physical containment inside the exact main app bundle is the ownership source. Prefix matching is forbidden.

### Duplicate extension identifier policy

Store identifier-to-canonical-appex-path identity while discovering.

- the same identifier appearing at two different `.appex` paths is an ambiguity failure;
- do not silently deduplicate distinct code locations;
- final identifiers are returned sorted by exact `compare:` order;
- no caller filesystem order may affect result order.

### No extension case

A valid exact main app bundle with no `.appex` entries is a successful discovery returning an empty array.

It is not a discovery error.

## Migrated request and aggregate result

TASK-1.8 upgrades the internal migrated request from ApplicationData-only to exactly:

```objc
PXClearScopeApplicationData |
PXClearScopeExtensionData |
PXClearScopePluginKitData
```

Do not use `PXClearScopeDefaultMask`.

Capture deep-clean once in `clearDataForBundleID:completion:` and use the same value for all three migrated components.

Refactor the private migrated orchestration to return a `PXClearResult`, recommended shape:

```objc
- (PXClearResult *)_completeDataWipeForMigratedRequest:(PXClearRequest *)request;
```

The exact private selector name may differ.

The request must contain exactly the three migrated scope bits above. Reject missing bits, additional bits or invalid request state before destructive work.

The returned aggregate must contain exactly these three component results in canonical scope order:

```text
ApplicationData
ExtensionData
PluginKitData
```

The accepted TASK-1.7 ApplicationData resolver, validator, command, postcondition and root-accounting behavior must remain logically unchanged.

App Group and Keychain continue as legacy compatibility side effects until TASK-1.9 and TASK-1.10. They must not be inserted into the TASK-1.8 request or aggregate.

## ExtensionData and PluginKitData unit order

After exact extension identifier discovery succeeds, process deterministic units in this order:

```text
ExtensionData:
  extension identifiers sorted ascending
    rootful
    rootless

PluginKitData:
  extension identifiers sorted ascending
    rootful
    rootless
```

Each tuple `(scope, extensionIdentifier, root)` is independent.

Do not batch different containers into one shell command.

## Per-unit processing

For ExtensionData use:

```text
kind  = PXResolvedContainerKindExtensionData
scope = PXClearScopeExtensionData
```

For PluginKitData use:

```text
kind  = PXResolvedContainerKindPluginKitData
scope = PXClearScopePluginKitData
```

For each identifier/root tuple:

1. call `resolveDataContainerForIdentifier:kind:root:error:`;
2. nil plus nil error means no container for that tuple and does not count as attempted;
3. resolver error counts as one attempted failed unit;
4. resolved container counts as one attempted unit;
5. validate immediately with `PXDestructivePathValidator`;
6. validation failure counts as one failed unit and performs no mutation;
7. build the strict wipe using only validator-returned canonical path;
8. run one bounded result-returning command;
9. command failure or output truncation counts as one failed unit;
10. validate the same resolved container again;
11. require exact canonical path equality before/after command;
12. run the strict data-container postcondition;
13. only complete success counts as one succeeded unit;
14. continue all remaining identifiers and roots after any failure.

Do not mutate through:

- raw UUID;
- `container.containerPath` after validation;
- `/var/mobile/...` reconstruction;
- `/containers/...` reconstruction;
- `completelyWipeContainer:`;
- `fixPermissionsForPath:`;
- `wipeDirectoryContents:`;
- void command wrappers;
- legacy extension dictionaries.

## Strict wipe and postcondition reuse

The exact TASK-1.7 strict wipe semantics apply to ExtensionData and PluginKitData.

It is acceptable to reuse the existing static TASK-1.7 helper even if its current name contains `ApplicationData`.

Do not weaken or duplicate its behavior.

Required semantics:

- preserve both MCM metadata filenames;
- remove every other immediate child;
- create exactly `Documents`, `Library`, `tmp`;
- no container-root removal;
- no metadata rewrite;
- no marker files;
- no recursive chmod `0777`;
- required remove/mkdir failure must produce nonzero command exit;
- one bounded `CommandResult` per container;
- fail closed on nil result, spawn/runner error, timeout, signal, abnormal/nonzero exit or stdout/stderr truncation;
- post-command validator and exact canonical equality;
- top-level allow-list and empty real required directories.

The ApplicationData use of these helpers must remain unchanged.

## Component result semantics

Use stable private failure domains, recommended:

```text
PXExtensionDataClear
PXPluginKitDataClear
```

Use fixed codes at minimum for:

```text
InvalidRequest
DiscoveryFailed
ResolutionFailed
ValidationFailed
ExecutionFailed
PostconditionFailed
InternalResultFailure
```

Store the first failure snapshot for each component. Continue processing later units.

Structured `detail` and `PXClearFailure.message` must not contain:

- canonical or raw filesystem paths;
- UUIDs;
- shell commands;
- directory listings;
- metadata contents;
- captured stdout/stderr.

### Discovery failure

If exact installed extension discovery fails, produce both:

```text
ExtensionData: Failed, attempted=1, succeeded=0, failed=1
PluginKitData: Failed, attempted=1, succeeded=0, failed=1
```

Each receives its own stable failure snapshot indicating extension identity discovery failed.

Do not scan metadata prefixes as fallback.

### No installed extensions

If exact app bundle discovery succeeds but no `.appex` identifiers exist, both components are Skipped with:

```text
No installed application extensions were discovered
```

Counts are all zero and failure is nil.

### Extensions exist but no matching containers

If extension identifiers exist but a scope has zero exact containers and no resolver error:

ExtensionData detail:

```text
No exact extension-data containers were found
```

PluginKitData detail:

```text
No exact PluginKit data containers were found
```

The component is Skipped with zero counts.

### Succeeded

A component is Succeeded when:

- attempted units > 0;
- every attempted unit succeeds;
- failed count is zero.

### Failed

A component is Failed when any unit fails.

Mixed success is represented using Failed with exact mixed counts.

Examples:

```text
2 attempted, 1 succeeded, 1 failed -> Failed 2/1/1
4 attempted, 3 succeeded, 1 failed -> Failed 4/3/1
```

## Main-flow legacy completion mapping

Consume the returned three-scope `PXClearResult` in `clearDataForBundleID:completion:`.

Failure precedence must be:

```text
1. ApplicationData
2. ExtensionData
3. PluginKitData
4. Keychain
```

The first failed migrated component determines the callback error.

If a lower-precedence migrated component or Keychain also fails, log it without replacing the selected callback error.

Skipped components are not callback failures.

If aggregate creation fails or the aggregate is structurally invalid, return an internal migrated-clear failure.

Do not change:

- one-shot completion protection;
- watchdog behavior;
- freeze/unfreeze behavior;
- main-thread callback dispatch;
- exception mapping;
- background task lifecycle.

## Public compatibility method

Keep:

```objc
- (void)completeAppDataWipe:(NSString *)bundleID;
```

It must construct the same exact three-scope request, delegate to the migrated aggregate path and log per-component status/counts.

It remains `void` and does not expose the typed result publicly.

Do not modify `AppDataCleaner.h`.

## Remove legacy extension mutation from the migrated main path

The migrated main path must no longer use:

```text
optimized_findExtensionContainers:...
findExtensionContainers:
clearExtensionContainers:forApp:
legacy extensionInfo dictionaries
raw dataUUID/rootless/type extension entries
PXShellWipeContainerKeepMetadata for extension containers
batched extension wipe commands
raw extension final-sweep paths
fixPermissionsForPath: for extension containers
```

The legacy methods may remain implemented and externally callable for compatibility, but their reference count from the migrated main orchestration must be zero.

Do not rewrite or harden their bodies during TASK-1.8. Quarantine belongs to TASK-1.12.

## Canonical cache migration

Remove the raw dictionary cache:

```objc
NSArray *_wipeCacheExtensionContainers;
```

Add copied canonical caches:

```objc
NSArray<NSString *> *_wipeCacheExtensionDataCanonicalPaths;
NSArray<NSString *> *_wipeCachePluginKitDataCanonicalPaths;
```

The exact ivar names may differ, but there must be separate typed arrays.

Requirements:

- store only canonical validator-returned paths;
- deterministic identifier/root order;
- no UUID/path reconstruction;
- use directly in `verifyDataCleared:` when wipe cache matches;
- clear both caches when the wipe cache is consumed;
- do not change App Group cache fields in TASK-1.8.

Standalone `verifyDataCleared:` cache-miss behavior may remain legacy read-only inspection, but must be explicitly documented.

## Final read-only verification

After all remaining legacy operations inside the main wipe flow, run the strict read-only postcondition against canonical ExtensionData and PluginKitData cache paths.

A container previously counted successful that fails this final check must be converted to a failed unit for its own component.

A container already failed remains failed and may be logged without double-counting.

Do not perform a destructive final sweep on migrated ExtensionData or PluginKitData paths.

## PluginKit library cleanup is not container authorization

The legacy `clearPluginKitData:` method searches global PlugInKit/MobileContainerManager files by bundle-derived wildcard.

TASK-1.8 does not treat those paths as `PXResolvedContainerKindPluginKitData` and does not call that method from the migrated main flow.

Do not add global `/var/mobile/Library/PlugInKit` files to the PluginKitData component.

PluginKitData in this task means only validated containers under:

```text
/private/var/mobile/Containers/Data/PluginKitPlugin
/containers/Data/PluginKitPlugin
```

## App Group and Keychain boundaries

Do not migrate or structurally report:

- App Group containers;
- extension keychain entries;
- main application Keychain result;
- extension preference plists;
- global PlugInKit databases/files.

Existing App Group cleanup remains legacy until TASK-1.9.

Existing Keychain behavior remains legacy until TASK-1.10.

## ApplicationData non-regression gates

The accepted TASK-1.7 ApplicationData path must retain:

- exact rootful/rootless resolver selection;
- no legacy main resolver fallback;
- canonical-only mutation;
- one bounded command per validated root;
- strict command-result checks;
- post-command validation and canonical equality;
- strict postcondition;
- independent root accounting;
- canonical cache behavior;
- ApplicationData callback-error precedence.

Do not change ApplicationData unit definitions or its stable failure codes/messages except mechanical refactoring required to return the aggregate.

## Application bundle read-only gates

Retain TASK-1.4:

```text
_MASReceipt tokens: 0
._MASReceipt tokens: 0
rootless application-bundle full wipe: 0
public receipt selector: one logged non-mutating no-op
```

The new extension discovery helper must be read-only.

No bundle, `.app`, `.appex`, receipt or Info.plist write is permitted.

## Generic helper boundaries

Do not modify the bodies of:

- `completelyWipeContainer:`
- `fixPermissionsAndRemovePath:`
- `fixPermissionsForPath:`
- `wipeDirectoryContents:keepDirectoryStructure:`
- `securelyWipeFile:`
- `finalSweepForContainer:`

The migrated ExtensionData/PluginKitData path must not call them for container mutation.

## Required source gates

After TASK-1.8 verify:

```text
PXDataContainerResolver generic API declaration: 1
PXDataContainerResolver generic API implementation: 1
legacy application resolver declaration: 1
legacy application resolver implementation: 1
legacy application resolver delegates generic method: yes
resolver accepted kinds: ApplicationData, ExtensionData, PluginKitData only
resolver AppGroup acceptance: 0
generic resolver fuzzy identity tokens: 0

migrated request scope bits: ApplicationData + ExtensionData + PluginKitData exactly
PXClearScopeDefaultMask in AppDataCleaner.m: 0
migrated aggregate components: 3
exact extension discovery helper: 1
prefix-based ownership checks in migrated discovery: 0
optimized_findExtensionContainers calls in migrated main path: 0
legacy extensionInfo mutation path in migrated main path: 0
raw extension UUID path reconstruction in migrated main path: 0
fixPermissionsForPath migrated extension calls: 0
batched migrated extension container command: 0
one bounded result command per resolved container: yes
validator pre/post calls per resolved container: yes

_wipeCacheExtensionContainers: 0
ExtensionData canonical cache: present
PluginKitData canonical cache: present
migrated extension/plugin destructive final sweep: 0

TASK-1.7 legacy main resolver calls in migrated ApplicationData path: 0
TASK-1.7 raw main mutation paths: 0
_MASReceipt / ._MASReceipt: 0 / 0
```

## Scenario matrix

The report must cover at least:

1. exact main app bundle with no extensions;
2. exact main bundle absent;
3. two exact main bundles across fixed roots;
4. main bundle container symlink;
5. `.app` symlink;
6. malformed main `Info.plist`;
7. direct `.appex` child;
8. `PlugIns/*.appex`;
9. `Plugins/*.appex`;
10. `.appex` symlink;
11. malformed extension `Info.plist`;
12. invalid extension identifier;
13. duplicate identifier at two `.appex` paths;
14. extension identifier not prefixed by parent identifier;
15. one ExtensionData rootful container;
16. one ExtensionData rootless container;
17. both ExtensionData roots;
18. ExtensionData resolver ambiguity;
19. ExtensionData validation failure;
20. ExtensionData command timeout/nonzero/truncation;
21. ExtensionData post-validation identity change;
22. ExtensionData postcondition failure;
23. partial ExtensionData success;
24. extension identifiers exist but no ExtensionData containers;
25. one PluginKit rootful container;
26. one PluginKit rootless container;
27. both PluginKit roots;
28. PluginKit resolver ambiguity;
29. PluginKit validation failure;
30. PluginKit command failure;
31. PluginKit postcondition failure;
32. partial PluginKit success;
33. identifiers exist but no PluginKit containers;
34. both migrated components succeed;
35. ExtensionData fails, PluginKit succeeds;
36. ApplicationData and ExtensionData both fail;
37. PluginKit and Keychain both fail;
38. all migrated components skipped except ApplicationData;
39. aggregate construction failure;
40. canonical cache hit verification;
41. standalone verifier cache miss;
42. legacy extension public helper remains externally callable but is not reached by migrated main flow;
43. application bundle remains read-only;
44. App Group behavior remains unchanged;
45. main ApplicationData behavior remains unchanged.

Do not claim runtime PASS for scenarios not executed on device.

## Baseline and protected checksums

Record before editing:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -1 --oneline
```

Expected baseline HEAD:

```text
f98a0f6d9f52cb08f151c29520af6fb6e255616b
```

Record SHA-256 before and after for:

- `AppDataCleaner.h`
- `PXResolvedContainer.h/.m`
- `PXDestructivePathValidator.h/.m`
- `PXClearRequest.h/.m`
- `PXClearResult.h/.m`
- `CommandRunner.h/.m`
- `AppGroupContainerResolver.h/.m`
- `AppDataBackupManager.h/.m`
- `Makefile`

Also record initial/final hashes for the three allowed production files.

## Required report content

`TASK-1.8-REPORT.md` must include:

1. task metadata and baseline;
2. exact allowed-file diff inventory;
3. protected checksums;
4. generic resolver API and delegation proof;
5. kind/root base matrix;
6. exact metadata and ambiguity proof;
7. application bundle read-only discovery algorithm;
8. exact `.appex` containment and duplicate policy;
9. proof no parent-prefix ownership assumption;
10. deterministic identifier/unit order;
11. ExtensionData unit accounting;
12. PluginKitData unit accounting;
13. canonical-only mutation proof;
14. bounded command mapping;
15. post-command validation and postconditions;
16. component result construction;
17. three-scope aggregate construction;
18. legacy completion precedence;
19. canonical cache migration;
20. final read-only verification;
21. legacy extension-path bypass audit;
22. ApplicationData non-regression audit;
23. App Group/Keychain not-migrated proof;
24. application-bundle gate proof;
25. full remaining `Data/Application` and `PluginKitPlugin` literal classification;
26. complete scenario matrix;
27. full source diff/stat review;
28. whitespace, NUL, generated and binary audit;
29. remaining risks.

End with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Verification commands

Run at minimum:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXDataContainerResolver.h PXDataContainerResolver.m AppDataCleaner.m
git diff -- PXDataContainerResolver.h PXDataContainerResolver.m AppDataCleaner.m
git diff --exit-code -- <protected files>
```

Perform explicit source searches for:

- generic resolver declarations and implementations;
- allowed kind switches;
- fixed bases;
- `isEqualToString:` metadata comparison;
- forbidden fuzzy tokens inside the generic resolver;
- exact extension discovery helper;
- all `hasPrefix:bundleID` occurrences and whether they remain outside migrated authorization;
- legacy extension discovery calls from the migrated main path;
- raw UUID/path construction in the migrated path;
- validator and bounded command calls;
- canonical cache references;
- destructive final sweeps;
- receipt tokens;
- App Group/Keychain result references.

## Stop condition

After TASK-1.8:

- do not begin TASK-1.9;
- do not migrate App Groups;
- do not create a Keychain component result;
- do not quarantine legacy public helpers;
- do not modify Backup/Restore/UI;
- do not add application-bundle mutation;
- stop and wait for coordinator review and owner build confirmation.
