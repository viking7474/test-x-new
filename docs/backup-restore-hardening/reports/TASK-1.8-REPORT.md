# TASK-1.8 Report — Migrate ExtensionData and PluginKitData Clear

## 1. Scope and baseline

- Task: `TASK-1.8-migrate-extension-and-pluginkit-data-clear`
- Baseline HEAD: `f98a0f6d9f52cb08f151c29520af6fb6e255616b`
- Baseline subject: `TASK-1.7 harden application-data clear handoff`
- Production files allowed and changed:
  - `PXDataContainerResolver.h`
  - `PXDataContainerResolver.m`
  - `AppDataCleaner.m`
- Required report created: `docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md`
- TASK-1.9 was not started.

Initial `git status --short --untracked-files=all` captured before production edits:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.7-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.8-migrate-extension-and-pluginkit-data-clear.md
```

The documentation changes shown above pre-existed TASK-1.8 source work and were not modified by this task.

## 2. Protected-file checksums and immutability proof

To avoid Windows checkout CRLF ambiguity, the protected baseline table records SHA-256 over the exact bytes returned by `git show HEAD:<file>`. Each current protected file was normalized from CRLF to LF for comparison and matched the baseline digest. `git diff --exit-code -- <protected files>` returned exit code `0`.

| Protected file | Baseline SHA-256 | Current canonical result |
|---|---|---|
| `AppDataCleaner.h` | `c280c5543ab87f9672f8bbccb44ccb42fd65533032e5a6beed81802e4ac4d685` | MATCH |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | MATCH |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | MATCH |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | MATCH |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | MATCH |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | MATCH |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | MATCH |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | MATCH |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | MATCH |
| `CommandRunner.h` | `22a4c402455f7ae92b89efc5d832dca1ba5b090b8207cbfc439050e83c6d5e82` | MATCH |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | MATCH |
| `AppGroupContainerResolver.h` | `757f98cf1e31d82b887b6060989c1d2ed7f91d99f7f30a74c7ee2452b80ba234` | MATCH |
| `AppGroupContainerResolver.m` | `d3f4b1ebd8b2d2c784914c6b2a47fc91aa7cac532401fe837b3c55b55dcaab99` | MATCH |
| `AppDataBackupManager.h` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | MATCH |
| `AppDataBackupManager.m` | `5cdf5cbd50137d3ba9f3c03bb1f78e957ab9f2f33d338cb5a496a829ca96ddda` | MATCH |
| `Makefile` | `6b1e3cae55f2f32c5ccf35dd722b3f651d427e596efc5ae7d66b0e282ed36b2a` | MATCH |

Protected files not changed:

- `AppDataCleaner.h`
- `PXResolvedContainer.h/.m`
- `PXDestructivePathValidator.h/.m`
- `PXClearRequest.h/.m`
- `PXClearResult.h/.m`
- `CommandRunner.h/.m`
- `AppGroupContainerResolver.h/.m`
- `AppDataBackupManager.h/.m`
- `Makefile`
- Backup, Restore, UI and Keychain implementation files

## 3. Generic exact data-container resolver

### Public API and delegation

`PXDataContainerResolver` now exposes:

```objc
- (nullable PXResolvedContainer *)resolveDataContainerForIdentifier:(NSString *)identifier
                                                               kind:(PXResolvedContainerKind)kind
                                                               root:(PXResolvedContainerRoot)root
                                                              error:(NSError * _Nullable * _Nullable)error;
```

The existing `resolveApplicationDataContainerForIdentifier:root:error:` API remains public and delegates directly to the generic API using `PXResolvedContainerKindApplicationData`.

### Public identifier-input contract after TASK-1.8A

The public generic resolver and the existing ApplicationData compatibility selector preserve the accepted TASK-1.2 input contract. An identifier is accepted at the public resolver validation boundary when it:

- is an `NSString` at runtime;
- has length greater than zero;
- contains at least one character outside `whitespaceAndNewlineCharacterSet`;
- contains no Unicode U+0000.

The public resolver does **not** impose bundle-identifier syntax. Underscores, Unicode, internal or surrounding whitespace, leading/trailing dots, consecutive dots, slash, backslash and wildcard characters are not rejected solely for syntax. Accepted values are retained exactly and are not trimmed, lowercased, uppercased, normalized or rewritten. Acceptance only means the value proceeds to exact metadata resolution; it does not imply a matching container exists or that `PXResolvedContainer` construction will succeed.

### Allowed kind/root matrix

| Requested kind | Rootful base | Rootless base | Allowed |
|---|---|---|---|
| ApplicationData | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` | Yes |
| ExtensionData | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` | Yes |
| PluginKitData | `/private/var/mobile/Containers/Data/PluginKitPlugin` | `/containers/Data/PluginKitPlugin` | Yes |
| AppGroup | none | none | No |
| Invalid kind/root | none | none | No |

No custom base, root fallback, kind fallback, `/var/mobile` alias scan, application-bundle inspection or App Group resolution was added to the resolver.

### Exact metadata proof

The generic resolver:

- clears `*error` at entry;
- treats an absent fixed base as `nil` with no error;
- maps a non-directory base or enumeration failure to existing `EnumerationFailed`;
- deterministically sorts immediate children;
- admits only immediate UUID-named real non-symlink directories;
- reads only `.com.apple.mobile_container_manager.metadata.plist` when it is a regular non-symlink file;
- accepts only a string `MCMMetadataIdentifier`;
- compares using exact case-sensitive `isEqualToString:`;
- returns `nil` with no error for zero matches;
- returns the requested kind for one exact match;
- returns existing `AmbiguousMatch` for multiple exact matches;
- returns existing `InvalidCandidate` when a matched value object cannot be constructed.

No resolver error code was added. Static audit confirmed zero uses in the resolver of `hasPrefix:`, `hasSuffix:`, `containsString:`, `lowercaseString`, case-insensitive comparison, recursive enumeration, or process/shell APIs.

## 4. Exact read-only installed extension discovery

A single private helper in `AppDataCleaner.m` performs exact extension identifier discovery.

### Main application discovery

- Root order is exactly `/var/containers/Bundle/Application`, then `/containers/Bundle/Application`.
- `/var/mobile/Containers/Bundle/Application` is not used by migrated discovery.
- Missing root means no candidate.
- Immediate UUID directories are sorted using `compare:` and must be real non-symlink directories.
- Immediate `.app` children are sorted, real directories and non-symlinks.
- `Info.plist` must be a regular non-symlink file.
- `CFBundleIdentifier` must be an `NSString` and must exactly equal the requested application identifier.
- Zero exact main-app matches is a discovery failure.
- Multiple exact main-app matches across both roots is an ambiguity failure.
- No `optimized_findBundleContainerUUID:`, root preference, newest/first selection or fuzzy matching is used.

### `.appex` inspection and duplicate policy

Only these immediate locations are inspected:

1. `<App>.app/<Extension>.appex`
2. `<App>.app/PlugIns/<Extension>.appex`
3. `<App>.app/Plugins/<Extension>.appex`

Every `.appex` must be a real non-symlink directory with a regular non-symlink `Info.plist` and a strict `PXClearRequest`-compatible `CFBundleIdentifier`. Identifiers are retained verbatim and sorted using `compare:`.

This private `.appex` policy is intentionally stricter than the permissive public resolver contract. `PXStrictBundleIdentifierIsValid` remains private to `AppDataCleaner.m`, mirrors the `PXClearRequest` bundle-identifier syntax boundary, and is used before extension identifiers enter migrated orchestration. TASK-1.8A changes only the public resolver validator and does not modify or relax private installed-extension validation.

A repeated identifier at two distinct `.appex` paths is an ambiguity failure. The helper does not silently deduplicate and does not select one path. There is deliberately no requirement that an extension identifier begin with the parent application identifier; no parent-prefix ownership heuristic exists in the helper.

A valid exact application bundle with no `.appex` returns an empty array, not an error. Application bundles and extension bundles are read-only throughout discovery.

## 5. Exact migrated request and aggregate

Both `clearDataForBundleID:completion:` and public compatibility method `completeAppDataWipe:` create the exact scope mask:

```objc
PXClearScopeApplicationData |
PXClearScopeExtensionData |
PXClearScopePluginKitData
```

`PXClearScopeDefaultMask` is not used. `clearDataForBundleID:completion:` captures deep-clean once and passes it into the request.

Private `_completeDataWipeForMigratedRequest:` returns a `PXClearResult` containing exactly three canonical component results:

1. ApplicationData
2. ExtensionData
3. PluginKitData

AppGroups and Keychain are not request scopes and are not aggregate components.

## 6. Deterministic unit execution

For both ExtensionData and PluginKitData, order is:

1. exact installed extension identifiers sorted ascending;
2. rootful tuple;
3. rootless tuple.

| Component | Kind | Scope |
|---|---|---|
| ExtensionData | `PXResolvedContainerKindExtensionData` | `PXClearScopeExtensionData` |
| PluginKitData | `PXResolvedContainerKindPluginKitData` | `PXClearScopePluginKitData` |

For every identifier/root tuple:

- `resolveDataContainerForIdentifier:kind:root:error:` is called;
- `nil` plus `nil` error is absent and not attempted;
- resolver error is one attempted failed unit;
- a resolved container is one attempted unit;
- validation immediately uses `PXDestructivePathValidator`;
- only the validator-returned canonical path enters mutation;
- one independent bounded `CommandResult` command is run for that container;
- nil/spawn/runner/timeout/signal/abnormal/nonzero/truncation all fail via the existing strict result gate;
- the same `PXResolvedContainer` is validated again after the command;
- the pre/post canonical strings must be exactly equal;
- the existing TASK-1.7 strict data-container postcondition is reused;
- success is counted only after all gates pass;
- processing continues after every failure.

There is no batching of extension containers. Migrated units do not mutate using raw UUIDs, reconstructed paths, `container.containerPath` after validation, legacy extension dictionaries, void wrappers, `completelyWipeContainer:`, `fixPermissionsForPath:` or `wipeDirectoryContents:`.

## 7. Strict wipe and postcondition reuse

The exact TASK-1.7 helpers are reused rather than duplicated or weakened:

- `PXShellValidatedApplicationDataWipe`
- `PXApplicationDataCommandResultSucceeded`
- `PXApplicationDataPostconditionIsValid`

The wipe preserves the two MCM metadata filenames, removes every other immediate child, recreates exactly `Documents`, `Library` and `tmp`, does not remove the container root, does not rewrite metadata, creates no marker files and performs no recursive `chmod 0777`. Required remove/mkdir failures propagate through a nonzero exit.

The strict postcondition enforces the top-level allow-list and requires `Documents`, `Library` and `tmp` to be real non-symlink empty directories.

## 8. Component accounting and failure snapshots

Stable private failure domains:

- `PXExtensionDataClear`
- `PXPluginKitDataClear`

Fixed private failure codes:

1. InvalidRequest
2. DiscoveryFailed
3. ResolutionFailed
4. ValidationFailed
5. ExecutionFailed
6. PostconditionFailed
7. InternalResultFailure

Each component retains its own first failure snapshot while continuing subsequent units. Detail/failure strings contain only stable component/root-stage descriptions and do not include paths, UUIDs, shell commands, directory listings, metadata, stdout or stderr.

Exact discovery failure produces independent ExtensionData and PluginKitData results with `Failed 1/0/1`.

Exact skip details are:

- no installed extensions: `No installed application extensions were discovered`
- no ExtensionData container: `No exact extension-data containers were found`
- no PluginKitData container: `No exact PluginKit data containers were found`

Succeeded requires `attempted > 0`, `succeeded == attempted`, `failed == 0`. Any failed unit produces Failed while preserving mixed counts.

## 9. Callback failure precedence

`clearDataForBundleID:completion:` consumes the three-scope aggregate in this exact failure precedence:

1. ApplicationData
2. ExtensionData
3. PluginKitData
4. Keychain

The first failed migrated component determines the callback `NSError`. Lower-priority migrated failures and Keychain failures are still logged but cannot replace it. Skipped is not a callback failure. A nil, incomplete or structurally invalid aggregate becomes an internal migrated-clear failure.

The existing one-shot `safeCompletion`, watchdog, freeze/unfreeze, background task, main-thread callback and exception mapping remain in place.

## 10. Canonical cache migration and final verification

Removed:

```objc
NSArray *_wipeCacheExtensionContainers;
```

Added separate copied canonical arrays:

```objc
NSArray<NSString *> *_wipeCacheExtensionDataCanonicalPaths;
NSArray<NSString *> *_wipeCachePluginKitDataCanonicalPaths;
```

Only validator-returned canonical paths are stored, in deterministic identifier/root order. Cache-hit `verifyDataCleared:` consumes these paths directly and clears both arrays after use. App Group cache fields were not changed.

After remaining legacy ApplicationData operations, ExtensionData and PluginKitData run a final read-only strict postcondition over canonical paths. A previously successful unit that now fails decrements succeeded and increments failed without changing attempted. An already-failed unit that still fails is logged without double-counting.

Cache-miss standalone verification intentionally retains legacy read-only extension inspection for compatibility; it never supplies a migrated mutation path.

## 11. Legacy bypass and PluginKit boundary audit

Reference audit of the migrated aggregate, exact unit processor and migrated ApplicationData path produced zero references to:

- `optimized_findExtensionContainers:...`
- `findExtensionContainers:`
- `clearExtensionContainers:forApp:`
- legacy extension dictionaries
- raw `dataUUID`/rootless/type entries
- batched extension `PXShellWipeContainerKeepMetadata`
- raw extension final-sweep paths
- extension `fixPermissionsForPath:` calls
- legacy `clearPluginKitData:`

Legacy method implementations remain for external compatibility and were not hardened in TASK-1.8.

PluginKitData mutation is restricted to validated containers beneath:

- `/private/var/mobile/Containers/Data/PluginKitPlugin`
- `/containers/Data/PluginKitPlugin`

The global legacy paths `/var/mobile/Library/PlugInKit` and `/var/mobile/Library/MobileContainerManager/PluginKitPlugin` are not treated as PluginKitData containers and are unreachable from the migrated aggregate.

## 12. ApplicationData non-regression and out-of-scope boundaries

ApplicationData retains TASK-1.7 semantics:

- exact resolver;
- independent rootful/rootless units;
- canonical validator before mutation;
- canonical-only mutation;
- one bounded result command per root;
- same-object post-command validation;
- exact canonical equality;
- strict postcondition;
- exact unit accounting and first-failure propagation;
- final read-only postcondition reconciliation.

TASK-1.8 does not migrate App Groups, main Keychain result, extension Keychain, extension preference plists or global PlugInKit databases/files. Generic helper bodies named by the specification were not changed.

TASK-1.4 bundle protections remain:

- `_MASReceipt` literal count: 0
- `._MASReceipt` literal count: 0
- no rootless application-bundle full wipe
- public receipt selector remains a logged non-mutating no-op

## 13. Bundle read-only proof

Migrated bundle discovery calls only `lstat`, `contentsOfDirectoryAtPath:` and `dictionaryWithContentsOfFile:` against the two allowed roots and immediate app/appex locations. No command, remove, mkdir, chmod, write, move or mutation helper receives an application-bundle path from migrated discovery.

## 14. Literal classification

| Literal/path family | Classification |
|---|---|
| `/private/var/mobile/Containers/Data/Application` | Canonical rootful ApplicationData/ExtensionData resolver and validator base |
| `/containers/Data/Application` | Canonical rootless ApplicationData/ExtensionData resolver and validator base; legacy verifier cache-miss reads may also reference it |
| `/private/var/mobile/Containers/Data/PluginKitPlugin` | Canonical rootful PluginKitData resolver/validator base |
| `/containers/Data/PluginKitPlugin` | Canonical rootless PluginKitData resolver/validator base |
| `/var/containers/Bundle/Application` | Exact migrated read-only rootful bundle discovery |
| `/containers/Bundle/Application` | Exact migrated read-only rootless bundle discovery |
| `/var/mobile/Containers/Bundle/Application` | Excluded from migrated discovery; may remain in unrelated legacy compatibility code |
| `/var/mobile/Library/PlugInKit` | Legacy global cleanup only; not a PluginKitData container |
| `/var/mobile/Library/MobileContainerManager/PluginKitPlugin` | Legacy global cleanup only; not a PluginKitData container |

## 15. Scenario matrix

| Scenario | Expected migrated result | Implemented behavior |
|---|---|---|
| Public resolver dynamic non-string, empty, whitespace-only, newline-only or embedded U+0000 | `InvalidInput` before filesystem resolution | TASK-1.2-compatible validator rejects |
| Public resolver `com.example.app`, `com.example_app`, `café.example`, ` com.example.app `, `.com.example`, or `com..example` | Proceed unchanged to exact resolution | No syntax whitelist or normalization |
| Public resolver invalid kind, AppGroup kind or invalid root | `InvalidInput` | Allowed-kind/root gates remain unchanged |
| Invalid request identifier/scope | Internal/InvalidRequest failure | Request or private entry rejects it |
| Both bundle roots absent or zero exact main app | Discovery failure | Both extension components Failed 1/0/1 |
| Multiple exact main app matches | Discovery ambiguity | Both extension components Failed 1/0/1 |
| Valid main app, no `.appex` | Both components Skipped 0/0/0 | Exact no-installed-extensions detail |
| Invalid/symlink `.appex` or Info.plist | Discovery failure | No mutation; both components Failed 1/0/1 |
| Same extension ID at two paths | Discovery ambiguity | No deduplication or arbitrary choice |
| Extension ID does not share parent prefix | Accepted if strict identifier is valid | No prefix ownership check |
| Tuple has no exact container | Not attempted | Continue remaining tuples |
| Resolver ambiguity/error | Attempted failed unit | First failure snapshot retained |
| Pre-validation failure | Attempted failed unit | No command issued |
| Bounded command nil/spawn/timeout/signal/nonzero/truncated | Attempted failed unit | Continue subsequent units |
| Post-validator rejects or canonical path changes | Attempted failed unit | Postcondition not credited |
| Strict postcondition fails | Attempted failed unit | Continue subsequent units |
| Mixed successes and failures | Failed with exact mixed counts | attempted remains stable |
| All attempted units pass | Succeeded | succeeded equals attempted |
| Final read-only check breaks prior success | Success decremented; failure incremented | attempted unchanged |
| Final read-only check fails already-failed unit | Log only | No double-counting |
| Aggregate missing/nil component | Internal migrated failure | Callback fails safely |
| AppData + ExtensionData both fail | ApplicationData callback error | ExtensionData still logged |
| ExtensionData + PluginKitData fail | ExtensionData callback error | PluginKitData still logged |
| Only Keychain fails | Keychain callback error | Migrated skipped/success not failure |
| Cache-hit verification | Direct canonical paths | Both extension caches consumed/cleared |
| Cache-miss verification | Legacy read-only compatibility inspection | Never feeds mutation |
| Global PlugInKit paths exist | Out of PluginKitData scope | Migrated aggregate does not call legacy cleanup |

## 16. Verification results

### Historical TASK-1.8 evidence and review correction

The original TASK-1.8 working-tree `git diff --check` captured before its commit returned exit code `0`, but that command did not include the subsequently added report as a committed diff. The coordinator review correctly found trailing whitespace in the committed `TASK-1.8-REPORT.md`. TASK-1.8A therefore removes all report trailing spaces/tabs and restores the TASK-1.2 resolver input contract.

### Corrective cumulative gates

The following gates are required and are executed for the corrective commit:

```text
git show --check --oneline HEAD
git diff f98a0f6d9f52cb08f151c29520af6fb6e255616b..HEAD --check
```

Corrective result recorded for handoff:

```text
git show --check --oneline HEAD: PASS
git diff f98a0f6d9f52cb08f151c29520af6fb6e255616b..HEAD --check: PASS
TASK-1.8-REPORT trailing-whitespace lines: 0
```

The corrective report `TASK-1.8A-REPORT.md` contains the complete command outputs, protected checksum comparison, source-gate audit and exact corrective diff/stat.

### Static contract and syntax audits

- Public resolver validation matches TASK-1.2: runtime string, nonempty, non-whitespace and no U+0000.
- Public resolver syntax whitelist references: zero.
- `PXResolverCharacterIsAllowed` references: zero.
- Generic resolver allowed kinds remain exactly ApplicationData, ExtensionData and PluginKitData.
- AppGroup acceptance remains zero.
- Existing ApplicationData selector delegates exactly once using `PXResolvedContainerKindApplicationData`.
- Generic resolver fuzzy authorization tokens remain zero.
- Private strict `.appex` identifier validation remains unchanged in `AppDataCleaner.m`.
- Migrated-flow orchestration, callback precedence, caches, strict wipe and application-bundle discovery remain unchanged.

### Whitespace, NUL and generated-file audit

| File | Bytes | NUL count | Line-ending note |
|---|---:|---:|---|
| `PXDataContainerResolver.h` | 1290 | 0 | Protected and unchanged |
| `PXDataContainerResolver.m` | 8332 | 0 | Corrective production file |
| `AppDataCleaner.m` | 398663 | 0 | Protected and unchanged in TASK-1.8A |
| `TASK-1.8-REPORT.md` | regenerated at corrective handoff | 0 | Trailing-whitespace lines: 0 |

- `git diff --check`: pass before the corrective commit.
- Post-commit cumulative and commit-local whitespace gates: pass.
- No NUL bytes were introduced.
- No temporary `.task18a*` file remains at final handoff.
- No generated source, build output or binary artifact was added.

### Local build limitation

This corrective task changes only resolver input validation and report evidence. The Windows workspace still lacks the iOS/Theos compiler toolchain, so local Objective-C compilation was not run. GitHub Actions remains the build authority.

## 17. Remaining risks

- Runtime behavior still depends on actual iOS container metadata, ownership/mode and mount topology and must be exercised on representative rootful and rootless devices.
- A device-level test should cover duplicate bundle roots, duplicate `.appex` identifiers, resolver ambiguity, command truncation/timeout and post-command filesystem replacement.
- Legacy standalone verifier cache-miss inspection remains heuristic and read-only by explicit scope decision; it is not part of migrated mutation.
- Local compilation was unavailable in this workspace; GitHub Actions must validate Objective-C compilation and integration.

## 18. Full cumulative source diff after TASK-1.8A

```diff
diff --git a/AppDataCleaner.m b/AppDataCleaner.m
index 93e2610..dbb790b 100644
--- a/AppDataCleaner.m
+++ b/AppDataCleaner.m
@@ -34,7 +34,19 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
 - (NSString *)runCommandAndGetOutput:(NSString *)command
                           timeoutSec:(NSTimeInterval)timeoutSec;
 - (NSArray<NSString *> *)runBoundedFindWithArguments:(NSArray<NSString *> *)arguments;
+- (PXClearResult *)_completeDataWipeForMigratedRequest:(PXClearRequest *)request;
 - (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:(PXClearRequest *)request;
+- (NSArray<NSString *> *)_exactInstalledExtensionIdentifiersForApplicationIdentifier:(NSString *)bundleIdentifier
+                                                                                error:(NSError **)error;
+- (PXClearComponentResult *)_clearExactDataContainerComponentForIdentifiers:(NSArray<NSString *> *)identifiers
+                                                                       kind:(PXResolvedContainerKind)kind
+                                                                      scope:(PXClearScope)scope
+                                                                 timeoutSec:(NSTimeInterval)timeoutSec
+                                                             canonicalPaths:(NSArray<NSString *> **)canonicalPaths
+                                                   successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths;
+- (PXClearComponentResult *)_componentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
+                                                            canonicalPaths:(NSArray<NSString *> *)canonicalPaths
+                                                  successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths;
 - (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID
                                                          deepClean:(BOOL)deepClean;
 @end
@@ -46,7 +58,8 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
     NSArray<NSString *> *_wipeCacheApplicationDataCanonicalPaths;
     NSArray *_wipeCacheGroupUUIDs;
     NSArray *_wipeCacheRootlessGroupUUIDs;
-    NSArray *_wipeCacheExtensionContainers; // array of @{dataUUID, rootless}
+    NSArray<NSString *> *_wipeCacheExtensionDataCanonicalPaths;
+    NSArray<NSString *> *_wipeCachePluginKitDataCanonicalPaths;
 }

 - (BOOL)_sqliteExecAtPath:(NSString *)dbPath sql:(NSString *)sql errorOut:(NSString **)errorOut {
@@ -659,6 +672,211 @@ static NSString *PXApplicationDataStatusName(PXClearComponentStatus status) {
     return @"Invalid";
 }

+static const PXClearScope PXMigratedDataClearScopes =
+    PXClearScopeApplicationData |
+    PXClearScopeExtensionData |
+    PXClearScopePluginKitData;
+
+typedef NS_ENUM(NSInteger, PXExactDataClearFailureCode) {
+    PXExactDataClearFailureCodeInvalidRequest = 1,
+    PXExactDataClearFailureCodeDiscoveryFailed = 2,
+    PXExactDataClearFailureCodeResolutionFailed = 3,
+    PXExactDataClearFailureCodeValidationFailed = 4,
+    PXExactDataClearFailureCodeExecutionFailed = 5,
+    PXExactDataClearFailureCodePostconditionFailed = 6,
+    PXExactDataClearFailureCodeInternalResultFailure = 7,
+};
+
+typedef NS_ENUM(NSInteger, PXInstalledExtensionDiscoveryErrorCode) {
+    PXInstalledExtensionDiscoveryErrorCodeInvalidRequest = 1,
+    PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed = 2,
+    PXInstalledExtensionDiscoveryErrorCodeAmbiguousMatch = 3,
+    PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate = 4,
+};
+
+static NSString * const PXExtensionDataClearFailureDomain = @"PXExtensionDataClear";
+static NSString * const PXPluginKitDataClearFailureDomain = @"PXPluginKitDataClear";
+static NSString * const PXMigratedDataClearFailureDomain = @"PXMigratedDataClear";
+static NSString * const PXInstalledExtensionDiscoveryErrorDomain = @"PXInstalledExtensionDiscovery";
+static NSString * const PXNoInstalledExtensionsDetail = @"No installed application extensions were discovered";
+static NSString * const PXNoExactExtensionDataContainersDetail = @"No exact extension-data containers were found";
+static NSString * const PXNoExactPluginKitDataContainersDetail = @"No exact PluginKit data containers were found";
+
+static BOOL PXStrictBundleIdentifierCharacterIsAllowed(unichar character) {
+    return (character >= (unichar)'A' && character <= (unichar)'Z') ||
+           (character >= (unichar)'a' && character <= (unichar)'z') ||
+           (character >= (unichar)'0' && character <= (unichar)'9') ||
+           character == (unichar)'-' ||
+           character == (unichar)'.';
+}
+
+static BOOL PXStrictBundleIdentifierIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSString *identifier = (NSString *)value;
+    if (identifier.length == 0 ||
+        [identifier characterAtIndex:0] == (unichar)'.' ||
+        [identifier characterAtIndex:(identifier.length - 1)] == (unichar)'.') {
+        return NO;
+    }
+
+    NSUInteger componentLength = 0;
+    for (NSUInteger index = 0; index < identifier.length; index++) {
+        unichar character = [identifier characterAtIndex:index];
+        if (!PXStrictBundleIdentifierCharacterIsAllowed(character)) {
+            return NO;
+        }
+        if (character == (unichar)'.') {
+            if (componentLength == 0) {
+                return NO;
+            }
+            componentLength = 0;
+        } else {
+            componentLength++;
+        }
+    }
+    return componentLength > 0;
+}
+
+static BOOL PXReadOnlyRealDirectoryAtPath(NSString *path) {
+    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
+        return NO;
+    }
+    const char *fileSystemPath = path.fileSystemRepresentation;
+    struct stat pathStat;
+    return fileSystemPath != NULL &&
+           lstat(fileSystemPath, &pathStat) == 0 &&
+           S_ISDIR(pathStat.st_mode) &&
+           !S_ISLNK(pathStat.st_mode);
+}
+
+static BOOL PXReadOnlyRegularNonSymlinkFileAtPath(NSString *path) {
+    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
+        return NO;
+    }
+    const char *fileSystemPath = path.fileSystemRepresentation;
+    struct stat pathStat;
+    return fileSystemPath != NULL &&
+           lstat(fileSystemPath, &pathStat) == 0 &&
+           S_ISREG(pathStat.st_mode) &&
+           !S_ISLNK(pathStat.st_mode);
+}
+
+static void PXInstalledExtensionDiscoveryAssignError(NSError **error,
+                                                      PXInstalledExtensionDiscoveryErrorCode code,
+                                                      NSString *message) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXInstalledExtensionDiscoveryErrorDomain
+                                 code:code
+                             userInfo:@{NSLocalizedDescriptionKey: message ?: @"Installed extension discovery failed"}];
+}
+
+static NSString *PXExactDataFailureDomainForScope(PXClearScope scope) {
+    if (scope == PXClearScopeExtensionData) {
+        return PXExtensionDataClearFailureDomain;
+    }
+    if (scope == PXClearScopePluginKitData) {
+        return PXPluginKitDataClearFailureDomain;
+    }
+    return PXMigratedDataClearFailureDomain;
+}
+
+static NSString *PXExactDataComponentName(PXClearScope scope) {
+    return scope == PXClearScopePluginKitData ? @"PluginKitData" : @"ExtensionData";
+}
+
+static PXClearFailure *PXExactDataFailure(PXClearScope scope,
+                                          PXExactDataClearFailureCode code,
+                                          NSString *message) {
+    return [[PXClearFailure alloc] initWithDomain:PXExactDataFailureDomainForScope(scope)
+                                            code:code
+                                         message:message ?: @"Exact extension data clear failed"];
+}
+
+static PXClearComponentResult *PXExactDataFailedComponent(PXClearScope scope,
+                                                          PXExactDataClearFailureCode code,
+                                                          NSString *message) {
+    PXClearFailure *failure = PXExactDataFailure(scope, code, message);
+    NSString *detail = scope == PXClearScopePluginKitData
+        ? @"PluginKitData clear could not produce a valid component result"
+        : @"ExtensionData clear could not produce a valid component result";
+    return [[PXClearComponentResult alloc] initWithScope:scope
+                                                  status:PXClearComponentStatusFailed
+                                      attemptedUnitCount:1
+                                      succeededUnitCount:0
+                                         failedUnitCount:1
+                                                  detail:detail
+                                                 failure:failure];
+}
+
+static BOOL PXExactDataComponentResultIsStructurallyValid(id value,
+                                                          PXClearScope expectedScope) {
+    if (![value isKindOfClass:[PXClearComponentResult class]]) return NO;
+    PXClearComponentResult *result = (PXClearComponentResult *)value;
+    if (result.scope != expectedScope ||
+        (expectedScope != PXClearScopeExtensionData && expectedScope != PXClearScopePluginKitData) ||
+        result.succeededUnitCount > result.attemptedUnitCount ||
+        result.failedUnitCount != result.attemptedUnitCount - result.succeededUnitCount) {
+        return NO;
+    }
+
+    switch (result.status) {
+        case PXClearComponentStatusSucceeded:
+            return result.attemptedUnitCount > 0 &&
+                   result.succeededUnitCount == result.attemptedUnitCount &&
+                   result.failedUnitCount == 0 &&
+                   result.failure == nil;
+        case PXClearComponentStatusSkipped:
+            return result.attemptedUnitCount == 0 &&
+                   result.succeededUnitCount == 0 &&
+                   result.failedUnitCount == 0 &&
+                   result.failure == nil &&
+                   result.detail != nil;
+        case PXClearComponentStatusFailed:
+            return result.attemptedUnitCount > 0 &&
+                   result.failedUnitCount > 0 &&
+                   [result.failure isKindOfClass:[PXClearFailure class]] &&
+                   [result.failure.domain isEqualToString:PXExactDataFailureDomainForScope(expectedScope)];
+    }
+    return NO;
+}
+
+static BOOL PXMigratedClearResultIsStructurallyValid(id value) {
+    if (![value isKindOfClass:[PXClearResult class]]) return NO;
+    PXClearResult *result = (PXClearResult *)value;
+    if (![result.request isKindOfClass:[PXClearRequest class]] ||
+        result.request.scopes != PXMigratedDataClearScopes ||
+        result.componentResults.count != 3) {
+        return NO;
+    }
+
+    PXClearComponentResult *applicationData = result.componentResults[0];
+    PXClearComponentResult *extensionData = result.componentResults[1];
+    PXClearComponentResult *pluginKitData = result.componentResults[2];
+    return applicationData.scope == PXClearScopeApplicationData &&
+           extensionData.scope == PXClearScopeExtensionData &&
+           pluginKitData.scope == PXClearScopePluginKitData &&
+           PXApplicationDataComponentResultIsStructurallyValid(applicationData) &&
+           PXExactDataComponentResultIsStructurallyValid(extensionData, PXClearScopeExtensionData) &&
+           PXExactDataComponentResultIsStructurallyValid(pluginKitData, PXClearScopePluginKitData);
+}
+
+static NSError *PXMigratedInternalError(NSString *message) {
+    return [NSError errorWithDomain:PXMigratedDataClearFailureDomain
+                               code:PXExactDataClearFailureCodeInternalResultFailure
+                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Migrated data clear returned an invalid internal result"}];
+}
+
+static NSError *PXMigratedNSErrorForFailure(PXClearFailure *failure) {
+    if (![failure isKindOfClass:[PXClearFailure class]]) {
+        return PXMigratedInternalError(@"Migrated data clear returned an invalid component failure");
+    }
+    return [NSError errorWithDomain:failure.domain
+                               code:failure.code
+                           userInfo:@{NSLocalizedDescriptionKey: failure.message}];
+}
+
 /// Shell fragment: wipe container children except MCM metadata, then recreate minimal layout.
 static NSString *PXShellWipeContainerKeepMetadata(NSString *containerPath) {
     if (!containerPath.length) return @"";
@@ -1121,19 +1339,533 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     return YES;
 }

+#pragma mark - Exact Installed Extension Discovery
+
+- (NSArray<NSString *> *)_exactInstalledExtensionIdentifiersForApplicationIdentifier:(NSString *)bundleIdentifier
+                                                                                error:(NSError **)error {
+    if (error) *error = nil;
+    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) {
+        PXInstalledExtensionDiscoveryAssignError(error,
+                                                 PXInstalledExtensionDiscoveryErrorCodeInvalidRequest,
+                                                 @"Invalid application identifier for installed extension discovery");
+        return nil;
+    }
+
+    NSFileManager *fileManager = [NSFileManager defaultManager];
+    NSArray<NSString *> *bundleRoots = @[
+        @"/var/containers/Bundle/Application",
+        @"/containers/Bundle/Application"
+    ];
+    NSMutableArray<NSString *> *matchingApplicationBundles = [NSMutableArray array];
+
+    for (NSString *bundleRoot in bundleRoots) {
+        struct stat rootStat;
+        if (lstat(bundleRoot.fileSystemRepresentation, &rootStat) != 0) {
+            int savedErrno = errno;
+            if (savedErrno == ENOENT || savedErrno == ENOTDIR) {
+                continue;
+            }
+            PXInstalledExtensionDiscoveryAssignError(error,
+                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
+                                                     @"Application bundle root inspection failed");
+            return nil;
+        }
+        if (!S_ISDIR(rootStat.st_mode) || S_ISLNK(rootStat.st_mode)) {
+            PXInstalledExtensionDiscoveryAssignError(error,
+                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
+                                                     @"Application bundle root is not a real directory");
+            return nil;
+        }
+
+        NSError *rootEnumerationError = nil;
+        NSArray<NSString *> *uuidEntries = [fileManager contentsOfDirectoryAtPath:bundleRoot
+                                                                            error:&rootEnumerationError];
+        if (![uuidEntries isKindOfClass:[NSArray class]] || rootEnumerationError) {
+            PXInstalledExtensionDiscoveryAssignError(error,
+                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
+                                                     @"Application bundle root enumeration failed");
+            return nil;
+        }
+        uuidEntries = [uuidEntries sortedArrayUsingSelector:@selector(compare:)];
+
+        for (NSString *uuidEntry in uuidEntries) {
+            if (![uuidEntry isKindOfClass:[NSString class]] || uuidEntry.length == 0 ||
+                [uuidEntry characterAtIndex:0] == (unichar)'.' ||
+                [[NSUUID alloc] initWithUUIDString:uuidEntry] == nil) {
+                continue;
+            }
+            NSString *uuidContainerPath = [bundleRoot stringByAppendingPathComponent:uuidEntry];
+            if (!PXReadOnlyRealDirectoryAtPath(uuidContainerPath)) {
+                continue;
+            }
+
+            NSError *containerEnumerationError = nil;
+            NSArray<NSString *> *appEntries = [fileManager contentsOfDirectoryAtPath:uuidContainerPath
+                                                                               error:&containerEnumerationError];
+            if (![appEntries isKindOfClass:[NSArray class]] || containerEnumerationError) {
+                PXInstalledExtensionDiscoveryAssignError(error,
+                                                         PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
+                                                         @"Application bundle container enumeration failed");
+                return nil;
+            }
+            appEntries = [appEntries sortedArrayUsingSelector:@selector(compare:)];
+
+            for (NSString *appEntry in appEntries) {
+                if (![appEntry isKindOfClass:[NSString class]] ||
+                    ![[appEntry pathExtension] isEqualToString:@"app"]) {
+                    continue;
+                }
+                NSString *appBundlePath = [uuidContainerPath stringByAppendingPathComponent:appEntry];
+                if (!PXReadOnlyRealDirectoryAtPath(appBundlePath)) {
+                    continue;
+                }
+                NSString *infoPath = [appBundlePath stringByAppendingPathComponent:@"Info.plist"];
+                if (!PXReadOnlyRegularNonSymlinkFileAtPath(infoPath)) {
+                    continue;
+                }
+                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
+                id installedIdentifier = [info isKindOfClass:[NSDictionary class]]
+                    ? info[@"CFBundleIdentifier"]
+                    : nil;
+                if ([installedIdentifier isKindOfClass:[NSString class]] &&
+                    [(NSString *)installedIdentifier isEqualToString:bundleIdentifier]) {
+                    [matchingApplicationBundles addObject:[appBundlePath copy]];
+                }
+            }
+        }
+    }
+
+    if (matchingApplicationBundles.count == 0) {
+        PXInstalledExtensionDiscoveryAssignError(error,
+                                                 PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
+                                                 @"No exact installed application bundle match was found");
+        return nil;
+    }
+    if (matchingApplicationBundles.count > 1) {
+        PXInstalledExtensionDiscoveryAssignError(error,
+                                                 PXInstalledExtensionDiscoveryErrorCodeAmbiguousMatch,
+                                                 @"Multiple exact installed application bundle matches were found");
+        return nil;
+    }
+
+    NSString *applicationBundlePath = matchingApplicationBundles.firstObject;
+    NSArray<NSString *> *extensionLocations = @[
+        applicationBundlePath,
+        [applicationBundlePath stringByAppendingPathComponent:@"PlugIns"],
+        [applicationBundlePath stringByAppendingPathComponent:@"Plugins"]
+    ];
+    NSMutableArray<NSString *> *extensionIdentifiers = [NSMutableArray array];
+    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet set];
+
+    for (NSUInteger locationIndex = 0; locationIndex < extensionLocations.count; locationIndex++) {
+        NSString *extensionLocation = extensionLocations[locationIndex];
+        struct stat locationStat;
+        if (lstat(extensionLocation.fileSystemRepresentation, &locationStat) != 0) {
+            int savedErrno = errno;
+            if (locationIndex > 0 && (savedErrno == ENOENT || savedErrno == ENOTDIR)) {
+                continue;
+            }
+            PXInstalledExtensionDiscoveryAssignError(error,
+                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
+                                                     @"Extension bundle location inspection failed");
+            return nil;
+        }
+        if (!S_ISDIR(locationStat.st_mode) || S_ISLNK(locationStat.st_mode)) {
+            PXInstalledExtensionDiscoveryAssignError(error,
+                                                     PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
+                                                     @"Extension bundle location is not a real directory");
+            return nil;
+        }
+
+        NSError *locationEnumerationError = nil;
+        NSArray<NSString *> *extensionEntries = [fileManager contentsOfDirectoryAtPath:extensionLocation
+                                                                                  error:&locationEnumerationError];
+        if (![extensionEntries isKindOfClass:[NSArray class]] || locationEnumerationError) {
+            PXInstalledExtensionDiscoveryAssignError(error,
+                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
+                                                     @"Extension bundle location enumeration failed");
+            return nil;
+        }
+        extensionEntries = [extensionEntries sortedArrayUsingSelector:@selector(compare:)];
+
+        for (NSString *extensionEntry in extensionEntries) {
+            if (![extensionEntry isKindOfClass:[NSString class]] ||
+                ![[extensionEntry pathExtension] isEqualToString:@"appex"]) {
+                continue;
+            }
+            NSString *extensionBundlePath = [extensionLocation stringByAppendingPathComponent:extensionEntry];
+            if (!PXReadOnlyRealDirectoryAtPath(extensionBundlePath)) {
+                PXInstalledExtensionDiscoveryAssignError(error,
+                                                         PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
+                                                         @"An extension bundle is not a real directory");
+                return nil;
+            }
+            NSString *extensionInfoPath = [extensionBundlePath stringByAppendingPathComponent:@"Info.plist"];
+            if (!PXReadOnlyRegularNonSymlinkFileAtPath(extensionInfoPath)) {
+                PXInstalledExtensionDiscoveryAssignError(error,
+                                                         PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
+                                                         @"An extension bundle Info.plist is not a regular file");
+                return nil;
+            }
+            NSDictionary *extensionInfo = [NSDictionary dictionaryWithContentsOfFile:extensionInfoPath];
+            id extensionIdentifier = [extensionInfo isKindOfClass:[NSDictionary class]]
+                ? extensionInfo[@"CFBundleIdentifier"]
+                : nil;
+            if (!PXStrictBundleIdentifierIsValid(extensionIdentifier)) {
+                PXInstalledExtensionDiscoveryAssignError(error,
+                                                         PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
+                                                         @"An extension bundle identifier is invalid");
+                return nil;
+            }
+
+            NSString *exactIdentifier = (NSString *)extensionIdentifier;
+            if ([seenIdentifiers containsObject:exactIdentifier]) {
+                PXInstalledExtensionDiscoveryAssignError(error,
+                                                         PXInstalledExtensionDiscoveryErrorCodeAmbiguousMatch,
+                                                         @"An extension identifier is present in multiple extension bundles");
+                return nil;
+            }
+            [seenIdentifiers addObject:exactIdentifier];
+            [extensionIdentifiers addObject:[exactIdentifier copy]];
+        }
+    }
+
+    return [extensionIdentifiers sortedArrayUsingSelector:@selector(compare:)];
+}
+
+#pragma mark - Exact Extension Data Components
+
+- (PXClearComponentResult *)_clearExactDataContainerComponentForIdentifiers:(NSArray<NSString *> *)identifiers
+                                                                       kind:(PXResolvedContainerKind)kind
+                                                                      scope:(PXClearScope)scope
+                                                                 timeoutSec:(NSTimeInterval)timeoutSec
+                                                             canonicalPaths:(NSArray<NSString *> **)canonicalPaths
+                                                   successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths {
+    if (canonicalPaths) *canonicalPaths = @[];
+    if (successfulCanonicalPaths) *successfulCanonicalPaths = [NSSet set];
+
+    BOOL kindAndScopeMatch =
+        (kind == PXResolvedContainerKindExtensionData && scope == PXClearScopeExtensionData) ||
+        (kind == PXResolvedContainerKindPluginKitData && scope == PXClearScopePluginKitData);
+    if (!kindAndScopeMatch ||
+        ![identifiers isKindOfClass:[NSArray class]] ||
+        timeoutSec <= 0.0) {
+        return PXExactDataFailedComponent(scope,
+                                          PXExactDataClearFailureCodeInvalidRequest,
+                                          @"Invalid exact data-container clear request");
+    }
+    for (id identifier in identifiers) {
+        if (!PXStrictBundleIdentifierIsValid(identifier)) {
+            return PXExactDataFailedComponent(scope,
+                                              PXExactDataClearFailureCodeInvalidRequest,
+                                              @"Invalid exact extension identifier list");
+        }
+    }
+
+    NSArray<NSString *> *sortedIdentifiers = [identifiers sortedArrayUsingSelector:@selector(compare:)];
+    if (sortedIdentifiers.count == 0) {
+        PXClearComponentResult *skipped = [[PXClearComponentResult alloc] initWithScope:scope
+                                                                                 status:PXClearComponentStatusSkipped
+                                                                     attemptedUnitCount:0
+                                                                     succeededUnitCount:0
+                                                                        failedUnitCount:0
+                                                                                 detail:PXNoInstalledExtensionsDetail
+                                                                                failure:nil];
+        return skipped ?: PXExactDataFailedComponent(scope,
+                                                     PXExactDataClearFailureCodeInternalResultFailure,
+                                                     @"Skipped exact data-container result construction failed");
+    }
+
+    PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
+    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
+    NSMutableArray<NSString *> *validatedCanonicalPaths = [NSMutableArray array];
+    NSMutableSet<NSString *> *successfulPaths = [NSMutableSet set];
+    NSUInteger attemptedUnits = 0;
+    NSUInteger succeededUnits = 0;
+    NSUInteger failedUnits = 0;
+    PXClearFailure *firstFailure = nil;
+
+    const PXResolvedContainerRoot roots[] = {
+        PXResolvedContainerRootRootful,
+        PXResolvedContainerRootRootless,
+    };
+    NSArray<NSString *> *rootLabels = @[@"rootful", @"rootless"];
+    NSString *componentName = PXExactDataComponentName(scope);
+
+    for (NSString *identifier in sortedIdentifiers) {
+        for (NSUInteger rootIndex = 0; rootIndex < 2; rootIndex++) {
+            PXResolvedContainerRoot root = roots[rootIndex];
+            NSError *resolutionError = nil;
+            PXResolvedContainer *resolved = [resolver resolveDataContainerForIdentifier:identifier
+                                                                                    kind:kind
+                                                                                    root:root
+                                                                                   error:&resolutionError];
+            if (!resolved) {
+                if (!resolutionError) {
+                    continue;
+                }
+                attemptedUnits++;
+                failedUnits++;
+                if (!firstFailure) {
+                    firstFailure = PXExactDataFailure(scope,
+                                                      PXExactDataClearFailureCodeResolutionFailed,
+                                                      [NSString stringWithFormat:@"%@ exact resolution failed for %@", componentName, rootLabels[rootIndex]]);
+                }
+                continue;
+            }
+
+            attemptedUnits++;
+            NSError *validationError = nil;
+            NSString *canonicalPath = [validator validatedCanonicalPathForContainer:resolved
+                                                                               error:&validationError];
+            if (canonicalPath.length == 0) {
+                failedUnits++;
+                if (!firstFailure) {
+                    firstFailure = PXExactDataFailure(scope,
+                                                      PXExactDataClearFailureCodeValidationFailed,
+                                                      [NSString stringWithFormat:@"%@ validation failed for %@", componentName, rootLabels[rootIndex]]);
+                }
+                continue;
+            }
+            [validatedCanonicalPaths addObject:[canonicalPath copy]];
+
+            NSString *wipeCommand = PXShellValidatedApplicationDataWipe(canonicalPath);
+            CommandResult *commandResult = [self runCommandWithPrivilegesResult:wipeCommand
+                                                                      timeoutSec:timeoutSec];
+            if (!PXApplicationDataCommandResultSucceeded(commandResult)) {
+                failedUnits++;
+                if (!firstFailure) {
+                    firstFailure = PXExactDataFailure(scope,
+                                                      PXExactDataClearFailureCodeExecutionFailed,
+                                                      [NSString stringWithFormat:@"%@ bounded execution failed for %@", componentName, rootLabels[rootIndex]]);
+                }
+                continue;
+            }
+
+            NSError *postValidationError = nil;
+            NSString *postCanonicalPath = [validator validatedCanonicalPathForContainer:resolved
+                                                                                    error:&postValidationError];
+            if (postCanonicalPath.length == 0 || ![postCanonicalPath isEqualToString:canonicalPath]) {
+                failedUnits++;
+                if (!firstFailure) {
+                    firstFailure = PXExactDataFailure(scope,
+                                                      PXExactDataClearFailureCodeValidationFailed,
+                                                      [NSString stringWithFormat:@"%@ post-command validation failed for %@", componentName, rootLabels[rootIndex]]);
+                }
+                continue;
+            }
+
+            NSError *postconditionError = nil;
+            if (!PXApplicationDataPostconditionIsValid(postCanonicalPath, &postconditionError)) {
+                failedUnits++;
+                if (!firstFailure) {
+                    firstFailure = PXExactDataFailure(scope,
+                                                      PXExactDataClearFailureCodePostconditionFailed,
+                                                      [NSString stringWithFormat:@"%@ strict postcondition failed for %@", componentName, rootLabels[rootIndex]]);
+                }
+                continue;
+            }
+
+            succeededUnits++;
+            [successfulPaths addObject:[canonicalPath copy]];
+        }
+    }
+
+    if (canonicalPaths) *canonicalPaths = [validatedCanonicalPaths copy];
+    if (successfulCanonicalPaths) *successfulCanonicalPaths = [successfulPaths copy];
+
+    if (attemptedUnits == 0) {
+        NSString *detail = scope == PXClearScopePluginKitData
+            ? PXNoExactPluginKitDataContainersDetail
+            : PXNoExactExtensionDataContainersDetail;
+        PXClearComponentResult *skipped = [[PXClearComponentResult alloc] initWithScope:scope
+                                                                                 status:PXClearComponentStatusSkipped
+                                                                     attemptedUnitCount:0
+                                                                     succeededUnitCount:0
+                                                                        failedUnitCount:0
+                                                                                 detail:detail
+                                                                                failure:nil];
+        return skipped ?: PXExactDataFailedComponent(scope,
+                                                     PXExactDataClearFailureCodeInternalResultFailure,
+                                                     @"Absent exact data-container result construction failed");
+    }
+
+    PXClearComponentStatus status = failedUnits > 0
+        ? PXClearComponentStatusFailed
+        : PXClearComponentStatusSucceeded;
+    NSString *detail = failedUnits > 0
+        ? [NSString stringWithFormat:@"One or more exact %@ units failed", componentName]
+        : [NSString stringWithFormat:@"All exact %@ units succeeded", componentName];
+    PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:scope
+                                                                            status:status
+                                                                attemptedUnitCount:attemptedUnits
+                                                                succeededUnitCount:succeededUnits
+                                                                   failedUnitCount:failedUnits
+                                                                            detail:detail
+                                                                           failure:firstFailure];
+    if (!PXExactDataComponentResultIsStructurallyValid(result, scope)) {
+        return PXExactDataFailedComponent(scope,
+                                          PXExactDataClearFailureCodeInternalResultFailure,
+                                          @"Exact data-container accounting produced an invalid result");
+    }
+    return result;
+}
+
+- (PXClearComponentResult *)_componentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
+                                                            canonicalPaths:(NSArray<NSString *> *)canonicalPaths
+                                                  successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths {
+    PXClearScope scope = result.scope;
+    if (!PXExactDataComponentResultIsStructurallyValid(result, scope) ||
+        ![canonicalPaths isKindOfClass:[NSArray class]] ||
+        ![successfulCanonicalPaths isKindOfClass:[NSSet class]]) {
+        return PXExactDataFailedComponent(scope,
+                                          PXExactDataClearFailureCodeInternalResultFailure,
+                                          @"Final exact data-container verification received invalid state");
+    }
+    if (result.status == PXClearComponentStatusSkipped || canonicalPaths.count == 0) {
+        return result;
+    }
+
+    NSUInteger succeededUnits = result.succeededUnitCount;
+    NSUInteger failedUnits = result.failedUnitCount;
+    PXClearFailure *firstFailure = result.failure;
+    BOOL changed = NO;
+
+    for (NSString *canonicalPath in canonicalPaths) {
+        NSError *postconditionError = nil;
+        if (PXApplicationDataPostconditionIsValid(canonicalPath, &postconditionError)) {
+            continue;
+        }
+        if ([successfulCanonicalPaths containsObject:canonicalPath]) {
+            if (succeededUnits > 0) succeededUnits--;
+            failedUnits++;
+            changed = YES;
+            if (!firstFailure) {
+                firstFailure = PXExactDataFailure(scope,
+                                                  PXExactDataClearFailureCodePostconditionFailed,
+                                                  [NSString stringWithFormat:@"%@ final strict postcondition failed", PXExactDataComponentName(scope)]);
+            }
+        } else {
+            [self logMessage:@"[AppDataCleaner] %@ final read-only verification remains failed for an already-failed unit",
+                  PXExactDataComponentName(scope)];
+        }
+    }
+
+    if (!changed) {
+        return result;
+    }
+
+    PXClearComponentResult *finalResult = [[PXClearComponentResult alloc] initWithScope:scope
+                                                                                 status:PXClearComponentStatusFailed
+                                                                     attemptedUnitCount:result.attemptedUnitCount
+                                                                     succeededUnitCount:succeededUnits
+                                                                        failedUnitCount:failedUnits
+                                                                                 detail:[NSString stringWithFormat:@"%@ final strict verification failed", PXExactDataComponentName(scope)]
+                                                                                failure:firstFailure];
+    if (!PXExactDataComponentResultIsStructurallyValid(finalResult, scope)) {
+        return PXExactDataFailedComponent(scope,
+                                          PXExactDataClearFailureCodeInternalResultFailure,
+                                          @"Final exact data-container accounting produced an invalid result");
+    }
+    return finalResult;
+}
+
+- (PXClearResult *)_completeDataWipeForMigratedRequest:(PXClearRequest *)request {
+    if (![request isKindOfClass:[PXClearRequest class]] ||
+        request.scopes != PXMigratedDataClearScopes) {
+        return nil;
+    }
+
+    NSError *discoveryError = nil;
+    NSArray<NSString *> *extensionIdentifiers =
+        [self _exactInstalledExtensionIdentifiersForApplicationIdentifier:request.bundleIdentifier
+                                                                     error:&discoveryError];
+
+    PXClearRequest *applicationRequest = [[PXClearRequest alloc] initWithBundleIdentifier:request.bundleIdentifier
+                                                                                   scopes:PXClearScopeApplicationData
+                                                                                deepClean:request.deepClean];
+    PXClearComponentResult *applicationResult = applicationRequest
+        ? [self _completeAppDataWipeForApplicationDataRequest:applicationRequest]
+        : nil;
+    if (!PXApplicationDataComponentResultIsStructurallyValid(applicationResult)) {
+        applicationResult = PXApplicationDataFailedComponent(PXApplicationDataClearFailureCodeInternalResultFailure,
+                                                             @"ApplicationData internal result validation failed");
+    }
+
+    NSArray<NSString *> *extensionCanonicalPaths = @[];
+    NSArray<NSString *> *pluginKitCanonicalPaths = @[];
+    NSSet<NSString *> *successfulExtensionPaths = [NSSet set];
+    NSSet<NSString *> *successfulPluginKitPaths = [NSSet set];
+    PXClearComponentResult *extensionResult = nil;
+    PXClearComponentResult *pluginKitResult = nil;
+
+    if (!extensionIdentifiers && discoveryError) {
+        extensionResult = PXExactDataFailedComponent(PXClearScopeExtensionData,
+                                                     PXExactDataClearFailureCodeDiscoveryFailed,
+                                                     @"Exact installed extension discovery failed");
+        pluginKitResult = PXExactDataFailedComponent(PXClearScopePluginKitData,
+                                                     PXExactDataClearFailureCodeDiscoveryFailed,
+                                                     @"Exact installed extension discovery failed");
+    } else {
+        BOOL isSystemApplication = [request.bundleIdentifier hasPrefix:@"com.apple."];
+        NSTimeInterval timeoutSec = (request.deepClean || isSystemApplication)
+            ? (NSTimeInterval)(15 * 60)
+            : (NSTimeInterval)(5 * 60);
+        extensionResult = [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
+                                                                            kind:PXResolvedContainerKindExtensionData
+                                                                           scope:PXClearScopeExtensionData
+                                                                      timeoutSec:timeoutSec
+                                                                  canonicalPaths:&extensionCanonicalPaths
+                                                        successfulCanonicalPaths:&successfulExtensionPaths];
+        pluginKitResult = [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
+                                                                            kind:PXResolvedContainerKindPluginKitData
+                                                                           scope:PXClearScopePluginKitData
+                                                                      timeoutSec:timeoutSec
+                                                                  canonicalPaths:&pluginKitCanonicalPaths
+                                                        successfulCanonicalPaths:&successfulPluginKitPaths];
+
+        extensionResult = [self _componentByApplyingFinalPostconditionToResult:extensionResult
+                                                                 canonicalPaths:extensionCanonicalPaths
+                                                       successfulCanonicalPaths:successfulExtensionPaths];
+        pluginKitResult = [self _componentByApplyingFinalPostconditionToResult:pluginKitResult
+                                                                 canonicalPaths:pluginKitCanonicalPaths
+                                                       successfulCanonicalPaths:successfulPluginKitPaths];
+    }
+
+    _wipeCacheExtensionDataCanonicalPaths = [extensionCanonicalPaths copy] ?: @[];
+    _wipeCachePluginKitDataCanonicalPaths = [pluginKitCanonicalPaths copy] ?: @[];
+
+    if (!PXExactDataComponentResultIsStructurallyValid(extensionResult, PXClearScopeExtensionData)) {
+        extensionResult = PXExactDataFailedComponent(PXClearScopeExtensionData,
+                                                     PXExactDataClearFailureCodeInternalResultFailure,
+                                                     @"ExtensionData internal result validation failed");
+    }
+    if (!PXExactDataComponentResultIsStructurallyValid(pluginKitResult, PXClearScopePluginKitData)) {
+        pluginKitResult = PXExactDataFailedComponent(PXClearScopePluginKitData,
+                                                     PXExactDataClearFailureCodeInternalResultFailure,
+                                                     @"PluginKitData internal result validation failed");
+    }
+
+    PXClearResult *aggregate = [[PXClearResult alloc] initWithRequest:request
+                                                    componentResults:@[
+                                                        applicationResult,
+                                                        extensionResult,
+                                                        pluginKitResult
+                                                    ]];
+    return PXMigratedClearResultIsStructurallyValid(aggregate) ? aggregate : nil;
+}
+
 #pragma mark - Main Public Methods

 - (void)clearDataForBundleID:(NSString *)bundleID completion:(void (^)(BOOL, NSError *))completion {
     [self logMessage:@"[AppDataCleaner] === STARTING data clearing for %@ ===", bundleID];

     BOOL deepClean = [self _deepCleanEnabled];
-    PXClearRequest *applicationDataRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
-                                                                                       scopes:PXClearScopeApplicationData
-                                                                                    deepClean:deepClean];
-    if (!applicationDataRequest) {
-        NSError *requestError = [NSError errorWithDomain:PXApplicationDataClearFailureDomain
-                                                    code:PXApplicationDataClearFailureCodeInvalidRequest
-                                                userInfo:@{NSLocalizedDescriptionKey: @"Invalid application-data clear request"}];
+    PXClearRequest *migratedRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
+                                                                                scopes:PXMigratedDataClearScopes
+                                                                             deepClean:deepClean];
+    if (!migratedRequest) {
+        NSError *requestError = PXMigratedInternalError(@"Invalid migrated data-clear request");
         dispatch_async(dispatch_get_main_queue(), ^{
             if (completion) completion(NO, requestError);
         });
@@ -1271,26 +2003,43 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                      frozeForThisClear = [freezer isApplicationFrozen:bundleID];
                  }

-                 // Step 4: Run the typed application-data component and consume its result.
-                 [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running typed application-data clear..."];
-                 PXClearComponentResult *applicationDataResult =
-                     [strongSelf _completeAppDataWipeForApplicationDataRequest:applicationDataRequest];
-                 NSError *applicationDataError = nil;
-                 if (!PXApplicationDataComponentResultIsStructurallyValid(applicationDataResult)) {
-                     applicationDataError = [NSError errorWithDomain:PXApplicationDataClearFailureDomain
-                                                               code:PXApplicationDataClearFailureCodeInternalResultFailure
-                                                           userInfo:@{NSLocalizedDescriptionKey: @"Application-data clear returned an invalid internal result"}];
-                     [strongSelf logMessage:@"[AppDataCleaner] ApplicationData result is nil or structurally invalid"];
-                 } else if (applicationDataResult.status == PXClearComponentStatusFailed) {
-                     applicationDataError = PXApplicationDataLegacyErrorForFailure(applicationDataResult.failure);
-                     [strongSelf logMessage:@"[AppDataCleaner] ApplicationData result Failed (%lu/%lu units succeeded)",
-                           (unsigned long)applicationDataResult.succeededUnitCount,
-                           (unsigned long)applicationDataResult.attemptedUnitCount];
-                 } else if (applicationDataResult.status == PXClearComponentStatusSkipped) {
-                     [strongSelf logMessage:@"[AppDataCleaner] ApplicationData result Skipped: %@", applicationDataResult.detail];
+                 // Step 4: Run and consume the exact three-scope migrated aggregate.
+                 [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running migrated ApplicationData/ExtensionData/PluginKitData clear..."];
+                 PXClearResult *migratedResult =
+                     [strongSelf _completeDataWipeForMigratedRequest:migratedRequest];
+                 NSError *migratedClearError = nil;
+                 if (!PXMigratedClearResultIsStructurallyValid(migratedResult)) {
+                     migratedClearError = PXMigratedInternalError(@"Migrated data clear returned an invalid aggregate result");
+                     [strongSelf logMessage:@"[AppDataCleaner] Migrated aggregate is nil, incomplete, or structurally invalid"];
                  } else {
-                     [strongSelf logMessage:@"[AppDataCleaner] ApplicationData result Succeeded (%lu units)",
-                           (unsigned long)applicationDataResult.succeededUnitCount];
+                     NSArray<NSNumber *> *failurePrecedence = @[
+                         @(PXClearScopeApplicationData),
+                         @(PXClearScopeExtensionData),
+                         @(PXClearScopePluginKitData)
+                     ];
+                     for (NSNumber *scopeNumber in failurePrecedence) {
+                         PXClearScope scope = (PXClearScope)scopeNumber.unsignedIntegerValue;
+                         PXClearComponentResult *component = [migratedResult componentResultForScope:scope];
+                         NSString *componentName = scope == PXClearScopeApplicationData
+                             ? @"ApplicationData"
+                             : PXExactDataComponentName(scope);
+                         [strongSelf logMessage:@"[AppDataCleaner] %@ result %@ attempted=%lu succeeded=%lu failed=%lu",
+                               componentName,
+                               PXApplicationDataStatusName(component.status),
+                               (unsigned long)component.attemptedUnitCount,
+                               (unsigned long)component.succeededUnitCount,
+                               (unsigned long)component.failedUnitCount];
+                         if (component.status == PXClearComponentStatusFailed) {
+                             NSError *componentError = PXMigratedNSErrorForFailure(component.failure);
+                             [strongSelf logMessage:@"[AppDataCleaner] %@ failed (%@:%ld)",
+                                   componentName,
+                                   componentError.domain,
+                                   (long)componentError.code];
+                             if (!migratedClearError) {
+                                 migratedClearError = componentError;
+                             }
+                         }
+                     }
                  }

                 // Step 5: Clear HTTP cookie storage in memory
@@ -1328,12 +2077,15 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                 [strongSelf logMessage:@"[AppDataCleaner] === COMPLETED data clearing for %@ ===", bundleID];
                 BOOL keychainFailed = !keychainOK1 || !keychainOK2;
                 NSError *keychainError = keychainError2 ?: keychainError1;
-                if (applicationDataError) {
+                if (keychainFailed) {
+                    [strongSelf logMessage:@"[AppDataCleaner] Keychain failed: %@",
+                          keychainError.localizedDescription ?: @"unknown keychain error"];
+                }
+                if (migratedClearError) {
                     if (keychainFailed) {
-                        [strongSelf logMessage:@"[AppDataCleaner] Keychain also failed; ApplicationData failure has callback precedence: %@",
-                              keychainError.localizedDescription ?: @"unknown keychain error"];
+                        [strongSelf logMessage:@"[AppDataCleaner] Migrated component failure has callback precedence over Keychain"];
                     }
-                    safeCompletion(NO, applicationDataError);
+                    safeCompletion(NO, migratedClearError);
                 } else if (keychainFailed) {
                     safeCompletion(NO, keychainError ?: [NSError errorWithDomain:@"AppDataCleaner"
                                                                             code:-2
@@ -1359,18 +2111,25 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
 - (void)completeAppDataWipe:(NSString *)bundleID {
     BOOL deepClean = [self _deepCleanEnabled];
     PXClearRequest *request = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
-                                                                        scopes:PXClearScopeApplicationData
+                                                                        scopes:PXMigratedDataClearScopes
                                                                      deepClean:deepClean];
-    PXClearComponentResult *result = [self _completeAppDataWipeForApplicationDataRequest:request];
-    if (!PXApplicationDataComponentResultIsStructurallyValid(result)) {
-        [self logMessage:@"[AppDataCleaner] completeAppDataWipe produced an invalid ApplicationData result"];
+    PXClearResult *result = request ? [self _completeDataWipeForMigratedRequest:request] : nil;
+    if (!PXMigratedClearResultIsStructurallyValid(result)) {
+        [self logMessage:@"[AppDataCleaner] completeAppDataWipe produced an invalid migrated aggregate"];
         return;
     }
-    [self logMessage:@"[AppDataCleaner] completeAppDataWipe ApplicationData status=%@ attempted=%lu succeeded=%lu failed=%lu",
-          PXApplicationDataStatusName(result.status),
-          (unsigned long)result.attemptedUnitCount,
-          (unsigned long)result.succeededUnitCount,
-          (unsigned long)result.failedUnitCount];
+
+    for (PXClearComponentResult *component in result.componentResults) {
+        NSString *componentName = component.scope == PXClearScopeApplicationData
+            ? @"ApplicationData"
+            : PXExactDataComponentName(component.scope);
+        [self logMessage:@"[AppDataCleaner] completeAppDataWipe %@ status=%@ attempted=%lu succeeded=%lu failed=%lu",
+              componentName,
+              PXApplicationDataStatusName(component.status),
+              (unsigned long)component.attemptedUnitCount,
+              (unsigned long)component.succeededUnitCount,
+              (unsigned long)component.failedUnitCount];
+    }
 }

 - (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:(PXClearRequest *)request {
@@ -1383,28 +2142,14 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     NSString *bundleID = request.bundleIdentifier;
     [self logMessage:@"[AppDataCleaner] Starting complete wipe for %@", bundleID];

-    // Data/Application listings remain read-only inputs for extension discovery only.
-    NSArray *cachedDataDirs = [self listDirectoriesInPath:@"/var/mobile/Containers/Data/Application"];
-    NSArray *cachedRootlessDataDirs = [self listDirectoriesInPath:@"/containers/Data/Application"];
-    NSArray *cachedBundleDirs = [self listDirectoriesInPath:@"/var/containers/Bundle/Application"];
-    NSArray *cachedRootlessBundleDirs = [self listDirectoriesInPath:@"/containers/Bundle/Application"];
-
     NSArray *groupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO];
     NSArray *rootlessGroupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES];
-    NSString *bundleUUID = [self optimized_findBundleContainerUUID:bundleID
-                                                      inDirectories:cachedBundleDirs
-                                                       rootlessDirs:cachedRootlessBundleDirs];
-    NSArray *extensionContainers = [self optimized_findExtensionContainers:bundleID
-                                                                   dataDirs:cachedDataDirs
-                                                           rootlessDataDirs:cachedRootlessDataDirs
-                                                                 bundleDirs:cachedBundleDirs
-                                                         rootlessBundleDirs:cachedRootlessBundleDirs];

     BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
     int rmTimeout = (request.deepClean || isSystemApp) ? (15 * 60) : (5 * 60);
     int findTimeout = (request.deepClean || isSystemApp) ? (20 * 60) : (8 * 60);
     int batchTimeout = MAX(findTimeout, rmTimeout);
-    if (groupUUIDs.count + rootlessGroupUUIDs.count + extensionContainers.count > 1) {
+    if (groupUUIDs.count + rootlessGroupUUIDs.count > 1) {
         batchTimeout = MIN(30 * 60, findTimeout + (int)(groupUUIDs.count + rootlessGroupUUIDs.count) * 60);
     }

@@ -1531,19 +2276,16 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     _wipeCacheApplicationDataCanonicalPaths = [canonicalApplicationDataPaths copy] ?: @[];
     _wipeCacheGroupUUIDs = [groupUUIDs copy] ?: @[];
     _wipeCacheRootlessGroupUUIDs = [rootlessGroupUUIDs copy] ?: @[];
-    _wipeCacheExtensionContainers = [extensionContainers copy] ?: @[];

-    [self logMessage:@"[AppDataCleaner] ApplicationData roots attempted=%lu succeeded=%lu failed=%lu; Bundle=%@ Groups=%lu RootlessGroups=%lu Extensions=%lu",
+    [self logMessage:@"[AppDataCleaner] ApplicationData roots attempted=%lu succeeded=%lu failed=%lu; Groups=%lu RootlessGroups=%lu",
           (unsigned long)attemptedUnits,
           (unsigned long)succeededUnits,
           (unsigned long)failedUnits,
-          bundleUUID ?: @"nil",
           (unsigned long)groupUUIDs.count,
-          (unsigned long)rootlessGroupUUIDs.count,
-          (unsigned long)extensionContainers.count];
+          (unsigned long)rootlessGroupUUIDs.count];

     // Clear App Store receipt
-    [self clearAppReceiptData:bundleID withBundleUUID:bundleUUID];
+    [self clearAppReceiptData:bundleID withBundleUUID:nil];

     // Process group + rootless group containers in ONE shell (same find/mkdir per path as before).
     NSMutableArray<NSString *> *groupWipeParts = [NSMutableArray array];
@@ -1699,25 +2441,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }
     }

-    // Process extension containers — batched into one shell (same find+mkdir semantics).
-    if (extensionContainers.count > 0) {
-        [self logMessage:@"[AppDataCleaner] Wiping %lu extension containers (batched shell)", (unsigned long)extensionContainers.count];
-        NSMutableArray<NSString *> *extParts = [NSMutableArray array];
-        for (NSDictionary *extInfo in extensionContainers) {
-            NSString *extDataUUID = extInfo[@"dataUUID"];
-            if (extDataUUID) {
-                BOOL rootless = [extInfo[@"rootless"] boolValue];
-                NSString *basePath = rootless ? @"/containers/Data/Application" : @"/var/mobile/Containers/Data/Application";
-                NSString *containerPath = [basePath stringByAppendingPathComponent:extDataUUID];
-                [extParts addObject:PXShellWipeContainerKeepMetadata(containerPath)];
-            }
-        }
-        if (extParts.count > 0) {
-            [self runBatchedCommandsWithPrivileges:extParts timeoutSec:batchTimeout];
-        }
-        [self logMessage:@"[AppDataCleaner] Extension containers wiped"];
-    }
-
     // Clear preferences and cookies only (SAFE paths, no SpringBoard state!) — one shell for all paths.
     [self logMessage:@"[AppDataCleaner] Clearing preferences and cookies (batched shell)"];
     NSString *bEsc = [bundleID stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
@@ -1798,14 +2521,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         NSLog(@"[AppDataCleaner][Detect] Rootless App Group Container: %@", path);
         [finalSweepPaths addObject:path];
     }
-    for (NSDictionary *extInfo in extensionContainers) {
-        NSString *extDataUUID = extInfo[@"dataUUID"];
-        BOOL rootless = [extInfo[@"rootless"] boolValue];
-        NSString *basePath = rootless ? @"/containers/Data/Application" : @"/var/mobile/Containers/Data/Application";
-        NSString *path = [basePath stringByAppendingPathComponent:extDataUUID];
-        NSLog(@"[AppDataCleaner][Detect] Extension Data Container: %@", path);
-        [finalSweepPaths addObject:path];
-    }
     // Recursively remove all non-Apple files from each container (parallelized)
     dispatch_apply(finalSweepPaths.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
         NSString *containerPath = finalSweepPaths[i];
@@ -3424,32 +4139,42 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
     }

-    // 3. Verify extension containers
-    if (!useWipeCache) {
+    // 3. Verify extension and PluginKit data containers.
+    if (useWipeCache) {
+        for (NSString *canonicalPath in (_wipeCacheExtensionDataCanonicalPaths ?: @[])) {
+            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
+        }
+        for (NSString *canonicalPath in (_wipeCachePluginKitDataCanonicalPaths ?: @[])) {
+            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
+        }
+        NSLog(@"[AppDataCleaner] Verify reusing canonical migrated wipe cache for %@", bundleID);
+    } else {
+        // Standalone verifier compatibility: legacy discovery is read-only and never feeds mutation.
         NSArray *extensionDataUUIDs = [self findExtensionDataContainersForBundleID:bundleID];
         for (NSString *extensionUUID in extensionDataUUIDs) {
             NSString *extensionPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", extensionUUID];
             [self verifyClearedPath:extensionPath reportingTo:unclearedPaths seen:verifiedPaths];
         }
-    }

-    NSArray *extensionContainers = nil;
-    if (useWipeCache) {
-        extensionContainers = _wipeCacheExtensionContainers ?: @[];
-        NSLog(@"[AppDataCleaner] Verify reusing wipe discovery cache for %@", bundleID);
-    } else {
         NSArray *dataDirs = [self listDirectoriesInPath:@"/var/mobile/Containers/Data/Application"];
         NSArray *rootlessDataDirs = [self listDirectoriesInPath:@"/containers/Data/Application"];
         NSArray *bundleDirs = [self listDirectoriesInPath:@"/var/containers/Bundle/Application"];
         NSArray *rootlessBundleDirs = [self listDirectoriesInPath:@"/containers/Bundle/Application"];
-        extensionContainers = [self optimized_findExtensionContainers:bundleID dataDirs:dataDirs rootlessDataDirs:rootlessDataDirs bundleDirs:bundleDirs rootlessBundleDirs:rootlessBundleDirs];
-    }
-    for (NSDictionary *extInfo in extensionContainers) {
-        NSString *extDataUUID = extInfo[@"dataUUID"];
-        if (!extDataUUID.length) continue;
-        BOOL rootless = [extInfo[@"rootless"] boolValue];
-        NSString *basePath = rootless ? @"/containers/Data/Application" : @"/var/mobile/Containers/Data/Application";
-        [self verifyClearedPath:[basePath stringByAppendingPathComponent:extDataUUID] reportingTo:unclearedPaths seen:verifiedPaths];
+        NSArray *legacyExtensionContainers = [self optimized_findExtensionContainers:bundleID
+                                                                            dataDirs:dataDirs
+                                                                    rootlessDataDirs:rootlessDataDirs
+                                                                          bundleDirs:bundleDirs
+                                                                  rootlessBundleDirs:rootlessBundleDirs];
+        for (NSDictionary *extInfo in legacyExtensionContainers) {
+            NSString *extDataUUID = extInfo[@"dataUUID"];
+            if (!extDataUUID.length) continue;
+            BOOL rootless = [extInfo[@"rootless"] boolValue];
+            NSString *basePath = rootless ? @"/containers/Data/Application" : @"/var/mobile/Containers/Data/Application";
+            [self verifyClearedPath:[basePath stringByAppendingPathComponent:extDataUUID]
+                       reportingTo:unclearedPaths
+                              seen:verifiedPaths];
+        }
+        [self logMessage:@"[AppDataCleaner] Standalone verification used legacy read-only extension inspection"];
     }

     // 4. Verify system paths. SpringBoard ApplicationState is intentionally not deleted (respring risk).
@@ -3495,7 +4220,9 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         // Skip app container paths that only contain system directories
         if (([path containsString:@"/var/mobile/Containers/Data/Application"] ||
-             [path containsString:@"/containers/Data/Application"]) &&
+             [path containsString:@"/containers/Data/Application"] ||
+             [path containsString:@"/private/var/mobile/Containers/Data/PluginKitPlugin"] ||
+             [path containsString:@"/containers/Data/PluginKitPlugin"]) &&
             ([info containsString:@"StoreKit"] ||
              [info containsString:@"Directory has 0 non-system files"] ||
              [info containsString:@"Directory has 1 non-system files: Documents"] ||
@@ -3525,7 +4252,8 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         _wipeCacheApplicationDataCanonicalPaths = nil;
         _wipeCacheGroupUUIDs = nil;
         _wipeCacheRootlessGroupUUIDs = nil;
-        _wipeCacheExtensionContainers = nil;
+        _wipeCacheExtensionDataCanonicalPaths = nil;
+        _wipeCachePluginKitDataCanonicalPaths = nil;
     }
     return ok;
 }
diff --git a/PXDataContainerResolver.h b/PXDataContainerResolver.h
index a5d726e..9658415 100644
--- a/PXDataContainerResolver.h
+++ b/PXDataContainerResolver.h
@@ -16,6 +16,11 @@ typedef NS_ENUM(NSInteger, PXDataContainerResolverErrorCode) {
 __attribute__((objc_subclassing_restricted))
 @interface PXDataContainerResolver : NSObject

+- (nullable PXResolvedContainer *)resolveDataContainerForIdentifier:(NSString *)identifier
+                                                               kind:(PXResolvedContainerKind)kind
+                                                               root:(PXResolvedContainerRoot)root
+                                                              error:(NSError * _Nullable * _Nullable)error;
+
 - (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                           root:(PXResolvedContainerRoot)root
                                                                          error:(NSError * _Nullable * _Nullable)error;
diff --git a/PXDataContainerResolver.m b/PXDataContainerResolver.m
index 6b026e1..2fb6df3 100644
--- a/PXDataContainerResolver.m
+++ b/PXDataContainerResolver.m
@@ -1,33 +1,21 @@
 #import "PXDataContainerResolver.h"

-NSString * const PXDataContainerResolverErrorDomain = @"PXDataContainerResolverErrorDomain";
-
-static NSString * const PXRootfulApplicationDataBase = @"/private/var/mobile/Containers/Data/Application";
-static NSString * const PXRootlessApplicationDataBase = @"/containers/Data/Application";
-static NSString * const PXContainerMetadataFilename = @".com.apple.mobile_container_manager.metadata.plist";
-static NSString * const PXContainerMetadataIdentifierKey = @"MCMMetadataIdentifier";
-
-static void PXSetDataContainerResolverError(NSError * _Nullable * _Nullable error,
-                                            PXDataContainerResolverErrorCode code,
-                                            NSString *description) {
-    if (error == NULL) {
-        return;
-    }
+#import <sys/stat.h>

-    *error = [NSError errorWithDomain:PXDataContainerResolverErrorDomain
-                                 code:code
-                             userInfo:@{NSLocalizedDescriptionKey: description}];
-}
+NSString * const PXDataContainerResolverErrorDomain = @"PXDataContainerResolverErrorDomain";

-static BOOL PXStringContainsNUL(NSString *value) {
+static BOOL PXResolverStringContainsNUL(NSString *value) {
     unichar nulCharacter = 0;
-    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
+    NSString *nulString =
+        [NSString stringWithCharacters:&nulCharacter length:1];
     return [value rangeOfString:nulString].location != NSNotFound;
 }

-static BOOL PXStringContainsNonWhitespace(NSString *value) {
-    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
-    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location != NSNotFound;
+static BOOL PXResolverStringContainsNonWhitespace(NSString *value) {
+    NSCharacterSet *whitespace =
+        [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
+        != NSNotFound;
 }

 static BOOL PXResolverIdentifierIsValid(id value) {
@@ -37,8 +25,14 @@ static BOOL PXResolverIdentifierIsValid(id value) {

     NSString *identifier = (NSString *)value;
     return identifier.length > 0 &&
-           PXStringContainsNonWhitespace(identifier) &&
-           !PXStringContainsNUL(identifier);
+           PXResolverStringContainsNonWhitespace(identifier) &&
+           !PXResolverStringContainsNUL(identifier);
+}
+
+static BOOL PXResolverKindIsAllowed(PXResolvedContainerKind kind) {
+    return kind == PXResolvedContainerKindApplicationData ||
+           kind == PXResolvedContainerKindExtensionData ||
+           kind == PXResolvedContainerKindPluginKitData;
 }

 static BOOL PXResolverRootIsValid(PXResolvedContainerRoot root) {
@@ -46,134 +40,175 @@ static BOOL PXResolverRootIsValid(PXResolvedContainerRoot root) {
            root == PXResolvedContainerRootRootless;
 }

-static NSString *PXApplicationDataBaseForRoot(PXResolvedContainerRoot root) {
-    switch (root) {
-        case PXResolvedContainerRootRootful:
-            return PXRootfulApplicationDataBase;
-        case PXResolvedContainerRootRootless:
-            return PXRootlessApplicationDataBase;
+static NSString *PXResolverBasePath(PXResolvedContainerKind kind,
+                                    PXResolvedContainerRoot root) {
+    if (!PXResolverKindIsAllowed(kind) || !PXResolverRootIsValid(root)) {
+        return nil;
     }
-    return nil;
+
+    if (kind == PXResolvedContainerKindPluginKitData) {
+        return root == PXResolvedContainerRootRootful
+            ? @"/private/var/mobile/Containers/Data/PluginKitPlugin"
+            : @"/containers/Data/PluginKitPlugin";
+    }
+
+    return root == PXResolvedContainerRootRootful
+        ? @"/private/var/mobile/Containers/Data/Application"
+        : @"/containers/Data/Application";
 }

-static BOOL PXDirectoryEntryIsValid(id value) {
-    if (![value isKindOfClass:[NSString class]]) {
+static void PXResolverAssignError(NSError **error,
+                                  PXDataContainerResolverErrorCode code,
+                                  NSString *message) {
+    if (!error) {
+        return;
+    }
+    *error = [NSError errorWithDomain:PXDataContainerResolverErrorDomain
+                                 code:code
+                             userInfo:@{NSLocalizedDescriptionKey: message ?: @"Data container resolution failed"}];
+}
+
+static BOOL PXResolverImmediateDirectoryIsValid(NSString *path) {
+    const char *fileSystemPath = path.fileSystemRepresentation;
+    if (!fileSystemPath) {
+        return NO;
+    }
+
+    struct stat entryStat;
+    if (lstat(fileSystemPath, &entryStat) != 0) {
         return NO;
     }
+    return S_ISDIR(entryStat.st_mode) && !S_ISLNK(entryStat.st_mode);
+}

-    NSString *entry = (NSString *)value;
-    if (entry.length == 0 ||
-        [entry isEqualToString:@"."] ||
-        [entry isEqualToString:@".."] ||
-        [entry hasPrefix:@"."] ||
-        [entry rangeOfString:@"/"].location != NSNotFound ||
-        PXStringContainsNUL(entry)) {
+static BOOL PXResolverMetadataFileIsValid(NSString *path) {
+    const char *fileSystemPath = path.fileSystemRepresentation;
+    if (!fileSystemPath) {
         return NO;
     }

-    return [[NSUUID alloc] initWithUUIDString:entry] != nil;
+    struct stat entryStat;
+    if (lstat(fileSystemPath, &entryStat) != 0) {
+        return NO;
+    }
+    return S_ISREG(entryStat.st_mode) && !S_ISLNK(entryStat.st_mode);
 }

 @implementation PXDataContainerResolver

-- (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
-                                                                          root:(PXResolvedContainerRoot)root
-                                                                         error:(NSError * _Nullable * _Nullable)error {
-    if (error != NULL) {
+- (PXResolvedContainer *)resolveDataContainerForIdentifier:(NSString *)identifier
+                                                       kind:(PXResolvedContainerKind)kind
+                                                       root:(PXResolvedContainerRoot)root
+                                                      error:(NSError **)error {
+    if (error) {
         *error = nil;
     }

-    if (!PXResolverIdentifierIsValid(identifier) || !PXResolverRootIsValid(root)) {
-        PXSetDataContainerResolverError(error,
-                                        PXDataContainerResolverErrorInvalidInput,
-                                        @"The application identifier or container root is invalid.");
+    if (!PXResolverIdentifierIsValid(identifier) ||
+        !PXResolverKindIsAllowed(kind) ||
+        !PXResolverRootIsValid(root)) {
+        PXResolverAssignError(error,
+                              PXDataContainerResolverErrorInvalidInput,
+                              @"Invalid data container resolution request");
+        return nil;
+    }
+
+    NSString *basePath = PXResolverBasePath(kind, root);
+    if (basePath.length == 0) {
+        PXResolverAssignError(error,
+                              PXDataContainerResolverErrorInvalidInput,
+                              @"Invalid data container resolution request");
         return nil;
     }

-    NSString *basePath = PXApplicationDataBaseForRoot(root);
     NSFileManager *fileManager = [NSFileManager defaultManager];
     BOOL baseIsDirectory = NO;
     if (![fileManager fileExistsAtPath:basePath isDirectory:&baseIsDirectory]) {
         return nil;
     }
     if (!baseIsDirectory) {
-        PXSetDataContainerResolverError(error,
-                                        PXDataContainerResolverErrorEnumerationFailed,
-                                        @"The selected application-data container base is not a directory.");
+        PXResolverAssignError(error,
+                              PXDataContainerResolverErrorEnumerationFailed,
+                              @"Data container root is not a directory");
         return nil;
     }

     NSError *enumerationError = nil;
-    NSArray *rawChildNames = [fileManager contentsOfDirectoryAtPath:basePath
-                                                              error:&enumerationError];
-    if (![rawChildNames isKindOfClass:[NSArray class]] || enumerationError != nil) {
-        PXSetDataContainerResolverError(error,
-                                        PXDataContainerResolverErrorEnumerationFailed,
-                                        @"The selected application-data container base could not be enumerated.");
+    NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:basePath
+                                                                     error:&enumerationError];
+    if (![entries isKindOfClass:[NSArray class]] || enumerationError) {
+        PXResolverAssignError(error,
+                              PXDataContainerResolverErrorEnumerationFailed,
+                              @"Data container root enumeration failed");
         return nil;
     }

-    NSMutableArray<NSString *> *childNames = [NSMutableArray array];
-    for (id rawChildName in rawChildNames) {
-        if ([rawChildName isKindOfClass:[NSString class]]) {
-            [childNames addObject:(NSString *)rawChildName];
-        }
-    }
-    [childNames sortUsingSelector:@selector(compare:)];
+    entries = [entries sortedArrayUsingSelector:@selector(compare:)];
+    NSMutableArray<PXResolvedContainer *> *matches = [NSMutableArray array];

-    PXResolvedContainer *resolvedContainer = nil;
-    for (NSString *containerUUID in childNames) {
-        if (!PXDirectoryEntryIsValid(containerUUID)) {
+    for (NSString *entry in entries) {
+        if (![entry isKindOfClass:[NSString class]] || entry.length == 0 ||
+            [entry characterAtIndex:0] == (unichar)'.' ||
+            [[NSUUID alloc] initWithUUIDString:entry] == nil) {
             continue;
         }

-        NSString *containerPath = [basePath stringByAppendingPathComponent:containerUUID];
-        BOOL candidateIsDirectory = NO;
-        if (![fileManager fileExistsAtPath:containerPath isDirectory:&candidateIsDirectory] ||
-            !candidateIsDirectory) {
+        NSString *containerPath = [basePath stringByAppendingPathComponent:entry];
+        if (!PXResolverImmediateDirectoryIsValid(containerPath)) {
             continue;
         }

-        NSString *metadataPath = [containerPath stringByAppendingPathComponent:PXContainerMetadataFilename];
-        id metadataObject = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
-        if (![metadataObject isKindOfClass:[NSDictionary class]]) {
+        NSString *metadataPath = [containerPath stringByAppendingPathComponent:
+                                  @".com.apple.mobile_container_manager.metadata.plist"];
+        if (!PXResolverMetadataFileIsValid(metadataPath)) {
             continue;
         }

-        id rawMetadataIdentifier = [(NSDictionary *)metadataObject objectForKey:PXContainerMetadataIdentifierKey];
-        if (!PXResolverIdentifierIsValid(rawMetadataIdentifier)) {
+        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
+        if (![metadata isKindOfClass:[NSDictionary class]]) {
             continue;
         }

-        NSString *metadataIdentifier = (NSString *)rawMetadataIdentifier;
-        if (![metadataIdentifier isEqualToString:identifier]) {
+        id metadataIdentifier = metadata[@"MCMMetadataIdentifier"];
+        if (![metadataIdentifier isKindOfClass:[NSString class]] ||
+            ![(NSString *)metadataIdentifier isEqualToString:identifier]) {
             continue;
         }

-        PXResolvedContainer *candidate = [[PXResolvedContainer alloc]
-            initWithKind:PXResolvedContainerKindApplicationData
-                    root:root
-     requestedIdentifier:identifier
-      metadataIdentifier:metadataIdentifier
-           containerUUID:containerUUID
-           containerPath:containerPath];
-        if (candidate == nil) {
-            PXSetDataContainerResolverError(error,
-                                            PXDataContainerResolverErrorInvalidCandidate,
-                                            @"An exact metadata match could not produce a valid resolved container.");
+        PXResolvedContainer *candidate = [[PXResolvedContainer alloc] initWithKind:kind
+                                                                              root:root
+                                                               requestedIdentifier:identifier
+                                                                metadataIdentifier:(NSString *)metadataIdentifier
+                                                                     containerUUID:entry
+                                                                     containerPath:containerPath];
+        if (!candidate) {
+            PXResolverAssignError(error,
+                                  PXDataContainerResolverErrorInvalidCandidate,
+                                  @"Exact data container match could not be represented safely");
             return nil;
         }
+        [matches addObject:candidate];
+    }

-        if (resolvedContainer != nil) {
-            PXSetDataContainerResolverError(error,
-                                            PXDataContainerResolverErrorAmbiguousMatch,
-                                            @"Multiple exact application-data container matches were found.");
-            return nil;
-        }
-        resolvedContainer = candidate;
+    if (matches.count == 0) {
+        return nil;
     }
+    if (matches.count > 1) {
+        PXResolverAssignError(error,
+                              PXDataContainerResolverErrorAmbiguousMatch,
+                              @"Multiple exact data container matches were found");
+        return nil;
+    }
+    return matches.firstObject;
+}

-    return resolvedContainer;
+- (PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
+                                                                  root:(PXResolvedContainerRoot)root
+                                                                 error:(NSError **)error {
+    return [self resolveDataContainerForIdentifier:identifier
+                                              kind:PXResolvedContainerKindApplicationData
+                                              root:root
+                                             error:error];
 }

 @end
```

## 19. Final workspace status

```text
 M AppDataCleaner.m
 M PXDataContainerResolver.h
 M PXDataContainerResolver.m
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reports/TASK-1.8-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-1.7-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.8-migrate-extension-and-pluginkit-data-clear.md
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
