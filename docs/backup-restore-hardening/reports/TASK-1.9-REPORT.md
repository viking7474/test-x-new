# TASK-1.9 Report — Migrate App Group Clear

## Metadata

```text
Task ID: TASK-1.9
Task title: Migrate App Group Clear
Task specification: docs/backup-restore-hardening/tasks/TASK-1.9-migrate-app-group-clear.md
Baseline HEAD: 6f74381ea0cf1e7172ff399bc0fac511ac358089
Commit hash: created by this task; final HEAD is reported after commit
```

## 1. Baseline and exact files changed

Initial `git status --short --untracked-files=all`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.8A-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.9-migrate-app-group-clear.md
```

The coordinator files above pre-existed TASK-1.9 and were not staged, reverted, formatted or modified by this task.

| File | Change |
|---|---|
| `AppGroupContainerResolver.h` | Added typed resolver public contract while preserving legacy API/model |
| `AppGroupContainerResolver.m` | Added exact typed App Group resolver |
| `AppDataCleaner.m` | Added exact entitlement discovery, canonical physical plan, four-scope aggregate, cache and bypass removal |
| `docs/backup-restore-hardening/reports/TASK-1.9-REPORT.md` | Created this report |

No TASK-1.10 work was performed.

## 2. Typed resolver public API and error mapping

`AppGroupContainerResolver.h` imports `PXResolvedContainer.h`, exports `PXAppGroupContainerResolverErrorDomain`, declares the five required error codes and adds exactly one typed selector. The selector clears `*error` at entry.

| Outcome | Return/error |
|---|---|
| Invalid dynamic identifier or root | nil / InvalidInput |
| Fixed base absent | nil / no error |
| Base non-directory or enumeration failure | nil / EnumerationFailed |
| No exact match | nil / no error |
| One exact match | AppGroup `PXResolvedContainer` |
| Multiple physical matches in one root | nil / AmbiguousMatch |
| Value-object construction failure | nil / InvalidCandidate |
| Duplicate exact identity in one metadata array | nil / MetadataInvalid |

Input validation is permissive: runtime `NSString`, nonempty, at least one non-whitespace/newline character and no U+0000. It performs no bundle-ID syntax whitelist, trimming, normalization or case conversion.

## 3. Legacy API compatibility proof

`AppGroupContainerInfo` and `resolveGroupContainersForGroupIDs:` remain declared and implemented exactly once. No legacy property or selector was removed or redesigned. `AppDataBackupManager` is protected and unchanged, so its legacy resolver call remains source-compatible.

## 4. Root and metadata matrix

| Root | Fixed typed base | Fallback/alias |
|---|---|---|
| Rootful | `/private/var/mobile/Containers/Shared/AppGroup` | none |
| Rootless | `/containers/Shared/AppGroup` | none |

The typed resolver enumerates immediate UUID children in exact `compare:` order, requires real non-symlink candidate directories and metadata files, and reads only `.com.apple.mobile_container_manager.metadata.plist` / `MCMMetadataIdentifier`. It contains no shell/process/destructive operation.

## 5. String and array exact-occurrence policy

- String metadata must satisfy the permissive string validity contract and match with case-sensitive `isEqualToString:`.
- Array metadata counts only exact `NSString` occurrences. Non-string elements are ignored as non-matches.
- Zero exact occurrences skip the candidate; one exact occurrence matches; more than one returns MetadataInvalid.
- The policy does not use `containsObject:` as the typed authorization decision and contains no fuzzy/case-insensitive token.

## 6. Exact entitlement identity extraction

`_exactApplicationGroupIdentifiersForBundleIdentifier:error:` calls `fullEntitlementsForBundleID:error:` exactly once per migrated request. It reads only `com.apple.security.application-groups` and `application-groups`. Missing keys produce an empty successful list; a present non-array value or any invalid element fails the whole discovery. Valid exact strings are combined, exactly deduplicated and sorted with `compare:` without rewriting.

## 7. Deterministic order and alias collapse

Tuple order is sorted group identifier, then rootful, then rootless. Each resolved model is validated before entering a plan keyed by exact validator-returned canonical path. A second valid identity mapping to the same canonical path is attached to that plan entry as an alias model. It does not create a second command and does not add another physical attempted unit.

## 8. Unit accounting formula

```text
attempted = resolver-error tuples
          + validation-error tuples
          + unique canonical physical containers entering execution
failed    = attempted - succeeded
```

The first failure snapshot is retained while all remaining tuples/physical units continue.

## 9. Canonical-only mutation proof

The migrated AppGroups method contains zero Shared/AppGroup literals, UUID reconstruction, raw `containerPath`, `PXShellWipeContainerKeepMetadata`, batching, void command wrappers, `completelyWipeContainer:`, `fixPermissionsForPath:`, `wipeDirectoryContents:`, `finalSweepForContainer:`, chmod or chflags. The only mutation input is the copied canonical validator output.

## 10. Bounded command/result mapping

Each unique canonical path invokes exactly one `runCommandWithPrivilegesResult:timeoutSec:` using the existing strict validated-container wipe. The existing command-result gate rejects nil result, runner/spawn error, timeout, signal/abnormal exit, nonzero exit and stdout/stderr truncation. A failed physical unit does not stop later units.

## 11. Post-command identity revalidation for every alias

After a successful command, every `PXResolvedContainer` model attached to the canonical path is passed through `PXDestructivePathValidator` again. Every returned path must exactly equal the pre-command canonical path. A single alias failure fails the one physical unit.

## 12. Strict postcondition and final read-only verification

The strict top-level data-container postcondition runs once per physical unit after all alias models revalidate. After remaining non-AppGroup legacy work and component execution, all validated canonical App Group paths receive a final read-only strict check. A prior success that regresses is moved from succeeded to failed; an already-failed path is logged without double-counting. No second destructive sweep exists.

## 13. Exact four-scope aggregate

`PXMigratedDataClearScopes` is exactly ApplicationData | ExtensionData | AppGroups | PluginKitData. Both public clear entry points construct that same request. The aggregate contains exactly four components in canonical order: ApplicationData, ExtensionData, AppGroups, PluginKitData. Keychain remains outside the typed aggregate.

## 14. Callback failure precedence

The exact precedence array is ApplicationData, ExtensionData, AppGroups, PluginKitData, followed by existing Keychain handling. The first failed migrated component selects callback `NSError`; lower-priority failures remain logged. Skipped AppGroups is not a callback failure.

## 15. ApplicationData group-work removal

The ApplicationData component now has zero group UUID resolution, group timeout math, group cache writes, reconstructed AppGroup paths, group wipe fragments/batches, group success logs or AppGroup final sweeps. Its exact resolver, validator, bounded command, accounting and postcondition logic remain unchanged.

## 16. Canonical cache migration

Removed `_wipeCacheGroupUUIDs` and `_wipeCacheRootlessGroupUUIDs`; both have zero references. `_wipeCacheAppGroupCanonicalPaths` stores a copied deterministic list of validator-returned physical paths. Cache-hit `verifyDataCleared:` consumes those paths directly and clears the cache. Cache-miss compatibility remains explicitly read-only.

## 17. Main-flow bypass audit

| Occurrence family | Classification | Reachability/result |
|---|---|---|
| `_resolvedAppGroupUUIDsFromEntitlements:rootless:` | Standalone read-only compatibility | Not called by migrated aggregate/ApplicationData; used only by cache-miss/read-only compatibility paths. |
| `clearAppGroupContainers:withGroupUUIDs:isRootless:` | Unreachable legacy compatibility mutation | Implementation retained; zero migrated-main references. |
| `findAppGroupUUIDs:*`, `findRootlessAppGroupUUIDs:` | Standalone read-only compatibility | Legacy metadata discovery only; not mutation authorization for migrated main. |
| `verifyDataCleared:` cache hit | Canonical read-only verification | Consumes `_wipeCacheAppGroupCanonicalPaths` directly; no UUID reconstruction. |
| `verifyDataCleared:` cache miss | Standalone read-only compatibility | May reconstruct legacy paths only for inspection; explicitly logged and never feeds mutation. |
| `hasDataToClear:` / `getDataUsage:` | Read-only compatibility | Inspection/accounting only. |
| `optimized_findAppGroupUUIDs:` | Unreachable legacy read-only compatibility | Not used for migrated authorization. |
| `clearAppGroupData:` | Unreachable legacy compatibility mutation | Retained API/body, zero migrated-main references. |
| `_internalClearEncryptedData:` | Unreachable legacy compatibility mutation | Main migrated path calls OutsideMain variant, whose AppGroup scan is removed. |
| `cleanAppGroupContainers:` | Unreachable legacy compatibility mutation | Retained but zero migrated-main references. |
| `AppGroupContainerResolver` typed roots | Migrated typed resolution | Only `/private/var/.../Shared/AppGroup` and `/containers/.../Shared/AppGroup`. |
| `AppGroupContainerResolver` legacy roots | Legacy read-only compatibility | Preserves Backup/Restore source compatibility. |

The migrated ApplicationData method, OutsideMain encrypted cleanup method and typed AppGroups execution method each contain zero legacy AppGroup authorization/mutation calls. No remaining Shared/AppGroup mutation is reachable from migrated main Clear except through the canonical typed AppGroups component.

## 18. MobileSafari AppGroup bypass removal

`_wipeMobileSafariSystemStores` contains zero `Shared/AppGroup` references after TASK-1.9. The AppGroup `_wipeContainersInBasePaths` call and both AppGroup `_scrubWebKitStateInSharedContainerBase` calls were removed. Global Safari/WebKit/Cookie work and four SystemGroup references remain.

## 19. Protected checksums

| Protected file | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | MATCH |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | MATCH |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | MATCH |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | MATCH |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | MATCH |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | MATCH |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | MATCH |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | MATCH |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | MATCH |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | MATCH |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | MATCH |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | MATCH |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | MATCH |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | MATCH |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | MATCH |
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | MATCH |
| `AppDataBackupManager.m` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | MATCH |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | MATCH |

`git diff --exit-code -- <protected files>` returned exit code 0.

## 20. Required commands and source-gate results

```text
git rev-parse HEAD
6f74381ea0cf1e7172ff399bc0fac511ac358089

git diff --check
PASS — exit 0

git diff --exit-code -- <protected files>
PASS — exit 0
```

Final source gates:

```text
typed resolver declaration/implementation: 1 / 1
legacy resolver declaration/implementation: 1 / 1
typed result kind: PXResolvedContainerKindAppGroup
typed rootful/rootless mapping: 1 / 1
typed rootful /var alias: 0
typed resolver fuzzy authorization: 0
four migrated scopes: exact
four aggregate components: exact
_wipeCacheGroupUUIDs: 0
_wipeCacheRootlessGroupUUIDs: 0
_wipeCacheAppGroupCanonicalPaths: present
migrated group batching: 0
migrated raw UUID path reconstruction: 0
migrated group final sweep: 0
main-flow group encrypted scan: 0
MobileSafari fuzzy Shared/AppGroup wipe: 0
MobileSafari Shared/AppGroup scrub: 0
receipt tokens: 0
```

## 21. Complete source diff/stat

```text
 AppDataCleaner.m            | 727 ++++++++++++++++++++++++++++++++++----------
 AppGroupContainerResolver.h |  16 +
 AppGroupContainerResolver.m | 201 ++++++++++++
 3 files changed, 782 insertions(+), 162 deletions(-)
```

Numeric text-only diff audit:

```text
565	162	AppDataCleaner.m
16	0	AppGroupContainerResolver.h
201	0	AppGroupContainerResolver.m
```

Complete source diff follows. Trailing spaces/tabs in historical context/deleted lines were removed only from this report rendering so the report itself remains whitespace-clean; the actual source diff was reviewed with Git.

```diff
diff --git a/AppDataCleaner.m b/AppDataCleaner.m
index dbb790b..ce01d8b 100644
--- a/AppDataCleaner.m
+++ b/AppDataCleaner.m
@@ -38,6 +38,8 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
 - (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:(PXClearRequest *)request;
 - (NSArray<NSString *> *)_exactInstalledExtensionIdentifiersForApplicationIdentifier:(NSString *)bundleIdentifier
                                                                                 error:(NSError **)error;
+- (NSArray<NSString *> *)_exactApplicationGroupIdentifiersForBundleIdentifier:(NSString *)bundleIdentifier
+                                                                         error:(NSError **)error;
 - (PXClearComponentResult *)_clearExactDataContainerComponentForIdentifiers:(NSArray<NSString *> *)identifiers
                                                                        kind:(PXResolvedContainerKind)kind
                                                                       scope:(PXClearScope)scope
@@ -47,6 +49,13 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
 - (PXClearComponentResult *)_componentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
                                                             canonicalPaths:(NSArray<NSString *> *)canonicalPaths
                                                   successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths;
+- (PXClearComponentResult *)_clearExactAppGroupsComponentForIdentifiers:(NSArray<NSString *> *)identifiers
+                                                              timeoutSec:(NSTimeInterval)timeoutSec
+                                                          canonicalPaths:(NSArray<NSString *> **)canonicalPaths
+                                                successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths;
+- (PXClearComponentResult *)_appGroupsComponentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
+                                                                     canonicalPaths:(NSArray<NSString *> *)canonicalPaths
+                                                           successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths;
 - (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID
                                                          deepClean:(BOOL)deepClean;
 @end
@@ -56,8 +65,7 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
     // Per-wipe discovery cache: main application-data paths remain canonical validator outputs.
     NSString *_wipeCacheBundleID;
     NSArray<NSString *> *_wipeCacheApplicationDataCanonicalPaths;
-    NSArray *_wipeCacheGroupUUIDs;
-    NSArray *_wipeCacheRootlessGroupUUIDs;
+    NSArray<NSString *> *_wipeCacheAppGroupCanonicalPaths;
     NSArray<NSString *> *_wipeCacheExtensionDataCanonicalPaths;
     NSArray<NSString *> *_wipeCachePluginKitDataCanonicalPaths;
 }
@@ -675,6 +683,7 @@ static NSString *PXApplicationDataStatusName(PXClearComponentStatus status) {
 static const PXClearScope PXMigratedDataClearScopes =
     PXClearScopeApplicationData |
     PXClearScopeExtensionData |
+    PXClearScopeAppGroups |
     PXClearScopePluginKitData;

 typedef NS_ENUM(NSInteger, PXExactDataClearFailureCode) {
@@ -701,6 +710,109 @@ static NSString * const PXInstalledExtensionDiscoveryErrorDomain = @"PXInstalled
 static NSString * const PXNoInstalledExtensionsDetail = @"No installed application extensions were discovered";
 static NSString * const PXNoExactExtensionDataContainersDetail = @"No exact extension-data containers were found";
 static NSString * const PXNoExactPluginKitDataContainersDetail = @"No exact PluginKit data containers were found";
+static NSString * const PXAppGroupsClearFailureDomain = @"PXAppGroupsClear";
+static NSString * const PXAppGroupEntitlementDiscoveryErrorDomain = @"PXAppGroupEntitlementDiscovery";
+static NSString * const PXNoDeclaredAppGroupsDetail = @"No application-group identifiers were declared by the app";
+static NSString * const PXNoExactAppGroupContainersDetail = @"No exact App Group containers were found";
+
+typedef NS_ENUM(NSInteger, PXAppGroupsClearFailureCode) {
+    PXAppGroupsClearFailureCodeInvalidRequest = 1,
+    PXAppGroupsClearFailureCodeEntitlementDiscoveryFailed = 2,
+    PXAppGroupsClearFailureCodeResolutionFailed = 3,
+    PXAppGroupsClearFailureCodeValidationFailed = 4,
+    PXAppGroupsClearFailureCodeExecutionFailed = 5,
+    PXAppGroupsClearFailureCodePostconditionFailed = 6,
+    PXAppGroupsClearFailureCodeInternalResultFailure = 7,
+};
+
+typedef NS_ENUM(NSInteger, PXAppGroupEntitlementDiscoveryErrorCode) {
+    PXAppGroupEntitlementDiscoveryErrorCodeInvalidRequest = 1,
+    PXAppGroupEntitlementDiscoveryErrorCodeExtractionFailed = 2,
+    PXAppGroupEntitlementDiscoveryErrorCodeInvalidStructure = 3,
+};
+
+static BOOL PXAppGroupIdentifierStringContainsNUL(NSString *value) {
+    unichar nulCharacter = 0;
+    NSString *nulString =
+        [NSString stringWithCharacters:&nulCharacter length:1];
+    return [value rangeOfString:nulString].location != NSNotFound;
+}
+
+static BOOL PXAppGroupIdentifierStringContainsNonWhitespace(NSString *value) {
+    NSCharacterSet *whitespace =
+        [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
+        != NSNotFound;
+}
+
+static BOOL PXAppGroupIdentifierIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSString *identifier = (NSString *)value;
+    return identifier.length > 0 &&
+           PXAppGroupIdentifierStringContainsNonWhitespace(identifier) &&
+           !PXAppGroupIdentifierStringContainsNUL(identifier);
+}
+
+static void PXAppGroupEntitlementDiscoveryAssignError(NSError **error,
+                                                       PXAppGroupEntitlementDiscoveryErrorCode code,
+                                                       NSString *message) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXAppGroupEntitlementDiscoveryErrorDomain
+                                 code:code
+                             userInfo:@{NSLocalizedDescriptionKey:
+                                            message ?: @"Application-group entitlement discovery failed"}];
+}
+
+static PXClearFailure *PXAppGroupsFailure(PXAppGroupsClearFailureCode code,
+                                          NSString *message) {
+    return [[PXClearFailure alloc] initWithDomain:PXAppGroupsClearFailureDomain
+                                            code:code
+                                         message:message ?: @"App Groups clear failed"];
+}
+
+static PXClearComponentResult *PXAppGroupsFailedComponent(PXAppGroupsClearFailureCode code,
+                                                          NSString *message) {
+    PXClearFailure *failure = PXAppGroupsFailure(code, message);
+    return [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
+                                                  status:PXClearComponentStatusFailed
+                                      attemptedUnitCount:1
+                                      succeededUnitCount:0
+                                         failedUnitCount:1
+                                                  detail:@"App Groups clear could not produce a valid component result"
+                                                 failure:failure];
+}
+
+static BOOL PXAppGroupsComponentResultIsStructurallyValid(id value) {
+    if (![value isKindOfClass:[PXClearComponentResult class]]) return NO;
+    PXClearComponentResult *result = (PXClearComponentResult *)value;
+    if (result.scope != PXClearScopeAppGroups ||
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
+                   [result.failure.domain isEqualToString:PXAppGroupsClearFailureDomain];
+    }
+    return NO;
+}

 static BOOL PXStrictBundleIdentifierCharacterIsAllowed(unichar character) {
     return (character >= (unichar)'A' && character <= (unichar)'Z') ||
@@ -786,6 +898,16 @@ static NSString *PXExactDataComponentName(PXClearScope scope) {
     return scope == PXClearScopePluginKitData ? @"PluginKitData" : @"ExtensionData";
 }

+static NSString *PXMigratedComponentName(PXClearScope scope) {
+    switch (scope) {
+        case PXClearScopeApplicationData: return @"ApplicationData";
+        case PXClearScopeExtensionData: return @"ExtensionData";
+        case PXClearScopeAppGroups: return @"AppGroups";
+        case PXClearScopePluginKitData: return @"PluginKitData";
+        default: return @"Unknown";
+    }
+}
+
 static PXClearFailure *PXExactDataFailure(PXClearScope scope,
                                           PXExactDataClearFailureCode code,
                                           NSString *message) {
@@ -847,18 +969,21 @@ static BOOL PXMigratedClearResultIsStructurallyValid(id value) {
     PXClearResult *result = (PXClearResult *)value;
     if (![result.request isKindOfClass:[PXClearRequest class]] ||
         result.request.scopes != PXMigratedDataClearScopes ||
-        result.componentResults.count != 3) {
+        result.componentResults.count != 4) {
         return NO;
     }

     PXClearComponentResult *applicationData = result.componentResults[0];
     PXClearComponentResult *extensionData = result.componentResults[1];
-    PXClearComponentResult *pluginKitData = result.componentResults[2];
+    PXClearComponentResult *appGroups = result.componentResults[2];
+    PXClearComponentResult *pluginKitData = result.componentResults[3];
     return applicationData.scope == PXClearScopeApplicationData &&
            extensionData.scope == PXClearScopeExtensionData &&
+           appGroups.scope == PXClearScopeAppGroups &&
            pluginKitData.scope == PXClearScopePluginKitData &&
            PXApplicationDataComponentResultIsStructurallyValid(applicationData) &&
            PXExactDataComponentResultIsStructurallyValid(extensionData, PXClearScopeExtensionData) &&
+           PXAppGroupsComponentResultIsStructurallyValid(appGroups) &&
            PXExactDataComponentResultIsStructurallyValid(pluginKitData, PXClearScopePluginKitData);
 }

@@ -1533,6 +1658,60 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     return [extensionIdentifiers sortedArrayUsingSelector:@selector(compare:)];
 }

+#pragma mark - Exact Application Group Entitlements
+
+- (NSArray<NSString *> *)_exactApplicationGroupIdentifiersForBundleIdentifier:(NSString *)bundleIdentifier
+                                                                         error:(NSError **)error {
+    if (error) *error = nil;
+    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) {
+        PXAppGroupEntitlementDiscoveryAssignError(error,
+                                                  PXAppGroupEntitlementDiscoveryErrorCodeInvalidRequest,
+                                                  @"Invalid application identifier for App Group entitlement discovery");
+        return nil;
+    }
+
+    AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
+    NSError *extractionError = nil;
+    NSDictionary *entitlements = [reader fullEntitlementsForBundleID:bundleIdentifier
+                                                               error:&extractionError];
+    if (extractionError || ![entitlements isKindOfClass:[NSDictionary class]]) {
+        PXAppGroupEntitlementDiscoveryAssignError(error,
+                                                  PXAppGroupEntitlementDiscoveryErrorCodeExtractionFailed,
+                                                  @"Application entitlements could not be extracted");
+        return nil;
+    }
+
+    NSArray<NSString *> *keys = @[
+        @"com.apple.security.application-groups",
+        @"application-groups"
+    ];
+    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
+
+    for (NSString *key in keys) {
+        id declaredValue = [entitlements objectForKey:key];
+        if (!declaredValue) {
+            continue;
+        }
+        if (![declaredValue isKindOfClass:[NSArray class]]) {
+            PXAppGroupEntitlementDiscoveryAssignError(error,
+                                                      PXAppGroupEntitlementDiscoveryErrorCodeInvalidStructure,
+                                                      @"An application-group entitlement has an invalid type");
+            return nil;
+        }
+        for (id element in (NSArray *)declaredValue) {
+            if (!PXAppGroupIdentifierIsValid(element)) {
+                PXAppGroupEntitlementDiscoveryAssignError(error,
+                                                          PXAppGroupEntitlementDiscoveryErrorCodeInvalidStructure,
+                                                          @"An application-group entitlement contains an invalid identifier");
+                return nil;
+            }
+            [identifiers addObject:[(NSString *)element copy]];
+        }
+    }
+
+    return [[identifiers allObjects] sortedArrayUsingSelector:@selector(compare:)];
+}
+
 #pragma mark - Exact Extension Data Components

 - (PXClearComponentResult *)_clearExactDataContainerComponentForIdentifiers:(NSArray<NSString *> *)identifiers
@@ -1770,88 +1949,383 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     return finalResult;
 }

+#pragma mark - Exact App Group Component
+
+- (PXClearComponentResult *)_clearExactAppGroupsComponentForIdentifiers:(NSArray<NSString *> *)identifiers
+                                                              timeoutSec:(NSTimeInterval)timeoutSec
+                                                          canonicalPaths:(NSArray<NSString *> **)canonicalPaths
+                                                successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths {
+    if (canonicalPaths) *canonicalPaths = @[];
+    if (successfulCanonicalPaths) *successfulCanonicalPaths = [NSSet set];
+
+    if (![identifiers isKindOfClass:[NSArray class]] || timeoutSec <= 0.0) {
+        return PXAppGroupsFailedComponent(PXAppGroupsClearFailureCodeInvalidRequest,
+                                          @"Invalid exact App Groups clear request");
+    }
+    for (id identifier in identifiers) {
+        if (!PXAppGroupIdentifierIsValid(identifier)) {
+            return PXAppGroupsFailedComponent(PXAppGroupsClearFailureCodeInvalidRequest,
+                                              @"Invalid exact application-group identifier list");
+        }
+    }
+
+    NSArray<NSString *> *sortedIdentifiers =
+        [identifiers sortedArrayUsingSelector:@selector(compare:)];
+    if (sortedIdentifiers.count == 0) {
+        PXClearComponentResult *skipped =
+            [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
+                                                   status:PXClearComponentStatusSkipped
+                                       attemptedUnitCount:0
+                                       succeededUnitCount:0
+                                          failedUnitCount:0
+                                                   detail:PXNoDeclaredAppGroupsDetail
+                                                  failure:nil];
+        return skipped ?: PXAppGroupsFailedComponent(
+            PXAppGroupsClearFailureCodeInternalResultFailure,
+            @"Skipped App Groups result construction failed");
+    }
+
+    AppGroupContainerResolver *resolver = [[AppGroupContainerResolver alloc] init];
+    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
+    NSMutableDictionary<NSString *, NSMutableArray<PXResolvedContainer *> *> *modelsByPath =
+        [NSMutableDictionary dictionary];
+    NSMutableArray<NSString *> *physicalPathOrder = [NSMutableArray array];
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
+
+    for (NSString *identifier in sortedIdentifiers) {
+        for (NSUInteger rootIndex = 0; rootIndex < 2; rootIndex++) {
+            PXResolvedContainerRoot root = roots[rootIndex];
+            NSError *resolutionError = nil;
+            PXResolvedContainer *resolved =
+                [resolver resolveAppGroupContainerForGroupIdentifier:identifier
+                                                                root:root
+                                                               error:&resolutionError];
+            if (!resolved) {
+                if (!resolutionError) {
+                    continue;
+                }
+                attemptedUnits++;
+                failedUnits++;
+                if (!firstFailure) {
+                    firstFailure = PXAppGroupsFailure(
+                        PXAppGroupsClearFailureCodeResolutionFailed,
+                        [NSString stringWithFormat:@"App Groups exact resolution failed for %@",
+                                                   rootLabels[rootIndex]]);
+                }
+                continue;
+            }
+
+            NSError *validationError = nil;
+            NSString *canonicalPath =
+                [validator validatedCanonicalPathForContainer:resolved error:&validationError];
+            if (canonicalPath.length == 0) {
+                attemptedUnits++;
+                failedUnits++;
+                if (!firstFailure) {
+                    firstFailure = PXAppGroupsFailure(
+                        PXAppGroupsClearFailureCodeValidationFailed,
+                        [NSString stringWithFormat:@"App Groups validation failed for %@",
+                                                   rootLabels[rootIndex]]);
+                }
+                continue;
+            }
+
+            NSMutableArray<PXResolvedContainer *> *models = modelsByPath[canonicalPath];
+            if (!models) {
+                models = [NSMutableArray array];
+                modelsByPath[[canonicalPath copy]] = models;
+                [physicalPathOrder addObject:[canonicalPath copy]];
+            }
+            [models addObject:resolved];
+        }
+    }
+
+    for (NSString *canonicalPath in physicalPathOrder) {
+        attemptedUnits++;
+        NSArray<PXResolvedContainer *> *models = [modelsByPath[canonicalPath] copy];
+        NSString *wipeCommand = PXShellValidatedApplicationDataWipe(canonicalPath);
+        CommandResult *commandResult =
+            [self runCommandWithPrivilegesResult:wipeCommand timeoutSec:timeoutSec];
+        if (!PXApplicationDataCommandResultSucceeded(commandResult)) {
+            failedUnits++;
+            if (!firstFailure) {
+                firstFailure = PXAppGroupsFailure(
+                    PXAppGroupsClearFailureCodeExecutionFailed,
+                    @"App Groups bounded execution failed");
+            }
+            continue;
+        }
+
+        BOOL allModelsStillAuthorizePath = YES;
+        for (PXResolvedContainer *model in models) {
+            NSError *postValidationError = nil;
+            NSString *postCanonicalPath =
+                [validator validatedCanonicalPathForContainer:model error:&postValidationError];
+            if (postCanonicalPath.length == 0 ||
+                ![postCanonicalPath isEqualToString:canonicalPath]) {
+                allModelsStillAuthorizePath = NO;
+                break;
+            }
+        }
+        if (!allModelsStillAuthorizePath) {
+            failedUnits++;
+            if (!firstFailure) {
+                firstFailure = PXAppGroupsFailure(
+                    PXAppGroupsClearFailureCodeValidationFailed,
+                    @"App Groups post-command identity validation failed");
+            }
+            continue;
+        }
+
+        NSError *postconditionError = nil;
+        if (!PXApplicationDataPostconditionIsValid(canonicalPath, &postconditionError)) {
+            failedUnits++;
+            if (!firstFailure) {
+                firstFailure = PXAppGroupsFailure(
+                    PXAppGroupsClearFailureCodePostconditionFailed,
+                    @"App Groups strict postcondition failed");
+            }
+            continue;
+        }
+
+        succeededUnits++;
+        [successfulPaths addObject:[canonicalPath copy]];
+    }
+
+    if (canonicalPaths) *canonicalPaths = [physicalPathOrder copy];
+    if (successfulCanonicalPaths) *successfulCanonicalPaths = [successfulPaths copy];
+
+    if (attemptedUnits == 0) {
+        PXClearComponentResult *skipped =
+            [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
+                                                   status:PXClearComponentStatusSkipped
+                                       attemptedUnitCount:0
+                                       succeededUnitCount:0
+                                          failedUnitCount:0
+                                                   detail:PXNoExactAppGroupContainersDetail
+                                                  failure:nil];
+        return skipped ?: PXAppGroupsFailedComponent(
+            PXAppGroupsClearFailureCodeInternalResultFailure,
+            @"Absent App Groups result construction failed");
+    }
+
+    PXClearComponentStatus status = failedUnits > 0
+        ? PXClearComponentStatusFailed
+        : PXClearComponentStatusSucceeded;
+    NSString *detail = failedUnits > 0
+        ? @"One or more exact App Group physical units failed"
+        : @"All exact App Group physical units succeeded";
+    PXClearComponentResult *result =
+        [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
+                                               status:status
+                                   attemptedUnitCount:attemptedUnits
+                                   succeededUnitCount:succeededUnits
+                                      failedUnitCount:failedUnits
+                                               detail:detail
+                                              failure:firstFailure];
+    if (!PXAppGroupsComponentResultIsStructurallyValid(result)) {
+        return PXAppGroupsFailedComponent(
+            PXAppGroupsClearFailureCodeInternalResultFailure,
+            @"App Groups accounting produced an invalid result");
+    }
+    return result;
+}
+
+- (PXClearComponentResult *)_appGroupsComponentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
+                                                                     canonicalPaths:(NSArray<NSString *> *)canonicalPaths
+                                                           successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths {
+    if (!PXAppGroupsComponentResultIsStructurallyValid(result) ||
+        ![canonicalPaths isKindOfClass:[NSArray class]] ||
+        ![successfulCanonicalPaths isKindOfClass:[NSSet class]]) {
+        return PXAppGroupsFailedComponent(
+            PXAppGroupsClearFailureCodeInternalResultFailure,
+            @"Final App Groups verification received invalid state");
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
+                firstFailure = PXAppGroupsFailure(
+                    PXAppGroupsClearFailureCodePostconditionFailed,
+                    @"App Groups final strict postcondition failed");
+            }
+        } else {
+            [self logMessage:@"[AppDataCleaner] AppGroups final read-only verification remains failed for an already-failed physical unit"];
+        }
+    }
+
+    if (!changed) {
+        return result;
+    }
+
+    PXClearComponentResult *finalResult =
+        [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
+                                               status:PXClearComponentStatusFailed
+                                   attemptedUnitCount:result.attemptedUnitCount
+                                   succeededUnitCount:succeededUnits
+                                      failedUnitCount:failedUnits
+                                               detail:@"App Groups final strict verification failed"
+                                              failure:firstFailure];
+    if (!PXAppGroupsComponentResultIsStructurallyValid(finalResult)) {
+        return PXAppGroupsFailedComponent(
+            PXAppGroupsClearFailureCodeInternalResultFailure,
+            @"Final App Groups accounting produced an invalid result");
+    }
+    return finalResult;
+}
+
 - (PXClearResult *)_completeDataWipeForMigratedRequest:(PXClearRequest *)request {
     if (![request isKindOfClass:[PXClearRequest class]] ||
         request.scopes != PXMigratedDataClearScopes) {
         return nil;
     }

-    NSError *discoveryError = nil;
+    NSError *extensionDiscoveryError = nil;
     NSArray<NSString *> *extensionIdentifiers =
         [self _exactInstalledExtensionIdentifiersForApplicationIdentifier:request.bundleIdentifier
-                                                                     error:&discoveryError];
+                                                                     error:&extensionDiscoveryError];

-    PXClearRequest *applicationRequest = [[PXClearRequest alloc] initWithBundleIdentifier:request.bundleIdentifier
-                                                                                   scopes:PXClearScopeApplicationData
-                                                                                deepClean:request.deepClean];
+    NSError *appGroupDiscoveryError = nil;
+    NSArray<NSString *> *appGroupIdentifiers =
+        [self _exactApplicationGroupIdentifiersForBundleIdentifier:request.bundleIdentifier
+                                                             error:&appGroupDiscoveryError];
+
+    PXClearRequest *applicationRequest =
+        [[PXClearRequest alloc] initWithBundleIdentifier:request.bundleIdentifier
+                                                  scopes:PXClearScopeApplicationData
+                                               deepClean:request.deepClean];
     PXClearComponentResult *applicationResult = applicationRequest
         ? [self _completeAppDataWipeForApplicationDataRequest:applicationRequest]
         : nil;
     if (!PXApplicationDataComponentResultIsStructurallyValid(applicationResult)) {
-        applicationResult = PXApplicationDataFailedComponent(PXApplicationDataClearFailureCodeInternalResultFailure,
-                                                             @"ApplicationData internal result validation failed");
+        applicationResult = PXApplicationDataFailedComponent(
+            PXApplicationDataClearFailureCodeInternalResultFailure,
+            @"ApplicationData internal result validation failed");
     }

+    BOOL isSystemApplication = [request.bundleIdentifier hasPrefix:@"com.apple."];
+    NSTimeInterval timeoutSec = (request.deepClean || isSystemApplication)
+        ? (NSTimeInterval)(15 * 60)
+        : (NSTimeInterval)(5 * 60);
+
     NSArray<NSString *> *extensionCanonicalPaths = @[];
+    NSArray<NSString *> *appGroupCanonicalPaths = @[];
     NSArray<NSString *> *pluginKitCanonicalPaths = @[];
     NSSet<NSString *> *successfulExtensionPaths = [NSSet set];
+    NSSet<NSString *> *successfulAppGroupPaths = [NSSet set];
     NSSet<NSString *> *successfulPluginKitPaths = [NSSet set];
     PXClearComponentResult *extensionResult = nil;
+    PXClearComponentResult *appGroupsResult = nil;
     PXClearComponentResult *pluginKitResult = nil;

-    if (!extensionIdentifiers && discoveryError) {
-        extensionResult = PXExactDataFailedComponent(PXClearScopeExtensionData,
-                                                     PXExactDataClearFailureCodeDiscoveryFailed,
-                                                     @"Exact installed extension discovery failed");
-        pluginKitResult = PXExactDataFailedComponent(PXClearScopePluginKitData,
-                                                     PXExactDataClearFailureCodeDiscoveryFailed,
-                                                     @"Exact installed extension discovery failed");
+    if (!extensionIdentifiers && extensionDiscoveryError) {
+        extensionResult = PXExactDataFailedComponent(
+            PXClearScopeExtensionData,
+            PXExactDataClearFailureCodeDiscoveryFailed,
+            @"Exact installed extension discovery failed");
+        pluginKitResult = PXExactDataFailedComponent(
+            PXClearScopePluginKitData,
+            PXExactDataClearFailureCodeDiscoveryFailed,
+            @"Exact installed extension discovery failed");
     } else {
-        BOOL isSystemApplication = [request.bundleIdentifier hasPrefix:@"com.apple."];
-        NSTimeInterval timeoutSec = (request.deepClean || isSystemApplication)
-            ? (NSTimeInterval)(15 * 60)
-            : (NSTimeInterval)(5 * 60);
-        extensionResult = [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
-                                                                            kind:PXResolvedContainerKindExtensionData
-                                                                           scope:PXClearScopeExtensionData
-                                                                      timeoutSec:timeoutSec
-                                                                  canonicalPaths:&extensionCanonicalPaths
-                                                        successfulCanonicalPaths:&successfulExtensionPaths];
-        pluginKitResult = [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
-                                                                            kind:PXResolvedContainerKindPluginKitData
-                                                                           scope:PXClearScopePluginKitData
-                                                                      timeoutSec:timeoutSec
-                                                                  canonicalPaths:&pluginKitCanonicalPaths
-                                                        successfulCanonicalPaths:&successfulPluginKitPaths];
-
-        extensionResult = [self _componentByApplyingFinalPostconditionToResult:extensionResult
-                                                                 canonicalPaths:extensionCanonicalPaths
-                                                       successfulCanonicalPaths:successfulExtensionPaths];
-        pluginKitResult = [self _componentByApplyingFinalPostconditionToResult:pluginKitResult
-                                                                 canonicalPaths:pluginKitCanonicalPaths
-                                                       successfulCanonicalPaths:successfulPluginKitPaths];
-    }
+        extensionResult =
+            [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
+                                                             kind:PXResolvedContainerKindExtensionData
+                                                            scope:PXClearScopeExtensionData
+                                                       timeoutSec:timeoutSec
+                                                   canonicalPaths:&extensionCanonicalPaths
+                                         successfulCanonicalPaths:&successfulExtensionPaths];
+        pluginKitResult =
+            [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
+                                                             kind:PXResolvedContainerKindPluginKitData
+                                                            scope:PXClearScopePluginKitData
+                                                       timeoutSec:timeoutSec
+                                                   canonicalPaths:&pluginKitCanonicalPaths
+                                         successfulCanonicalPaths:&successfulPluginKitPaths];
+    }
+
+    if (!appGroupIdentifiers && appGroupDiscoveryError) {
+        appGroupsResult = PXAppGroupsFailedComponent(
+            PXAppGroupsClearFailureCodeEntitlementDiscoveryFailed,
+            @"Exact application-group entitlement discovery failed");
+    } else {
+        appGroupsResult =
+            [self _clearExactAppGroupsComponentForIdentifiers:appGroupIdentifiers ?: @[]
+                                                   timeoutSec:timeoutSec
+                                               canonicalPaths:&appGroupCanonicalPaths
+                                     successfulCanonicalPaths:&successfulAppGroupPaths];
+    }
+
+    extensionResult =
+        [self _componentByApplyingFinalPostconditionToResult:extensionResult
+                                              canonicalPaths:extensionCanonicalPaths
+                                    successfulCanonicalPaths:successfulExtensionPaths];
+    pluginKitResult =
+        [self _componentByApplyingFinalPostconditionToResult:pluginKitResult
+                                              canonicalPaths:pluginKitCanonicalPaths
+                                    successfulCanonicalPaths:successfulPluginKitPaths];
+    appGroupsResult =
+        [self _appGroupsComponentByApplyingFinalPostconditionToResult:appGroupsResult
+                                                        canonicalPaths:appGroupCanonicalPaths
+                                              successfulCanonicalPaths:successfulAppGroupPaths];

     _wipeCacheExtensionDataCanonicalPaths = [extensionCanonicalPaths copy] ?: @[];
+    _wipeCacheAppGroupCanonicalPaths = [appGroupCanonicalPaths copy] ?: @[];
     _wipeCachePluginKitDataCanonicalPaths = [pluginKitCanonicalPaths copy] ?: @[];

-    if (!PXExactDataComponentResultIsStructurallyValid(extensionResult, PXClearScopeExtensionData)) {
-        extensionResult = PXExactDataFailedComponent(PXClearScopeExtensionData,
-                                                     PXExactDataClearFailureCodeInternalResultFailure,
-                                                     @"ExtensionData internal result validation failed");
-    }
-    if (!PXExactDataComponentResultIsStructurallyValid(pluginKitResult, PXClearScopePluginKitData)) {
-        pluginKitResult = PXExactDataFailedComponent(PXClearScopePluginKitData,
-                                                     PXExactDataClearFailureCodeInternalResultFailure,
-                                                     @"PluginKitData internal result validation failed");
-    }
-
-    PXClearResult *aggregate = [[PXClearResult alloc] initWithRequest:request
-                                                    componentResults:@[
-                                                        applicationResult,
-                                                        extensionResult,
-                                                        pluginKitResult
-                                                    ]];
+    if (!PXExactDataComponentResultIsStructurallyValid(extensionResult,
+                                                       PXClearScopeExtensionData)) {
+        extensionResult = PXExactDataFailedComponent(
+            PXClearScopeExtensionData,
+            PXExactDataClearFailureCodeInternalResultFailure,
+            @"ExtensionData internal result validation failed");
+    }
+    if (!PXAppGroupsComponentResultIsStructurallyValid(appGroupsResult)) {
+        appGroupsResult = PXAppGroupsFailedComponent(
+            PXAppGroupsClearFailureCodeInternalResultFailure,
+            @"AppGroups internal result validation failed");
+    }
+    if (!PXExactDataComponentResultIsStructurallyValid(pluginKitResult,
+                                                       PXClearScopePluginKitData)) {
+        pluginKitResult = PXExactDataFailedComponent(
+            PXClearScopePluginKitData,
+            PXExactDataClearFailureCodeInternalResultFailure,
+            @"PluginKitData internal result validation failed");
+    }
+
+    PXClearResult *aggregate =
+        [[PXClearResult alloc] initWithRequest:request
+                             componentResults:@[
+                                 applicationResult,
+                                 extensionResult,
+                                 appGroupsResult,
+                                 pluginKitResult
+                             ]];
     return PXMigratedClearResultIsStructurallyValid(aggregate) ? aggregate : nil;
 }

@@ -2003,8 +2477,8 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                      frozeForThisClear = [freezer isApplicationFrozen:bundleID];
                  }

-                 // Step 4: Run and consume the exact three-scope migrated aggregate.
-                 [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running migrated ApplicationData/ExtensionData/PluginKitData clear..."];
+                 // Step 4: Run and consume the exact four-scope migrated aggregate.
+                 [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running migrated ApplicationData/ExtensionData/AppGroups/PluginKitData clear..."];
                  PXClearResult *migratedResult =
                      [strongSelf _completeDataWipeForMigratedRequest:migratedRequest];
                  NSError *migratedClearError = nil;
@@ -2015,14 +2489,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                      NSArray<NSNumber *> *failurePrecedence = @[
                          @(PXClearScopeApplicationData),
                          @(PXClearScopeExtensionData),
+                         @(PXClearScopeAppGroups),
                          @(PXClearScopePluginKitData)
                      ];
                      for (NSNumber *scopeNumber in failurePrecedence) {
                          PXClearScope scope = (PXClearScope)scopeNumber.unsignedIntegerValue;
                          PXClearComponentResult *component = [migratedResult componentResultForScope:scope];
-                         NSString *componentName = scope == PXClearScopeApplicationData
-                             ? @"ApplicationData"
-                             : PXExactDataComponentName(scope);
+                         NSString *componentName = PXMigratedComponentName(scope);
                          [strongSelf logMessage:@"[AppDataCleaner] %@ result %@ attempted=%lu succeeded=%lu failed=%lu",
                                componentName,
                                PXApplicationDataStatusName(component.status),
@@ -2120,9 +2593,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     }

     for (PXClearComponentResult *component in result.componentResults) {
-        NSString *componentName = component.scope == PXClearScopeApplicationData
-            ? @"ApplicationData"
-            : PXExactDataComponentName(component.scope);
+        NSString *componentName = PXMigratedComponentName(component.scope);
         [self logMessage:@"[AppDataCleaner] completeAppDataWipe %@ status=%@ attempted=%lu succeeded=%lu failed=%lu",
               componentName,
               PXApplicationDataStatusName(component.status),
@@ -2142,16 +2613,8 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     NSString *bundleID = request.bundleIdentifier;
     [self logMessage:@"[AppDataCleaner] Starting complete wipe for %@", bundleID];

-    NSArray *groupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO];
-    NSArray *rootlessGroupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES];
-
     BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
     int rmTimeout = (request.deepClean || isSystemApp) ? (15 * 60) : (5 * 60);
-    int findTimeout = (request.deepClean || isSystemApp) ? (20 * 60) : (8 * 60);
-    int batchTimeout = MAX(findTimeout, rmTimeout);
-    if (groupUUIDs.count + rootlessGroupUUIDs.count > 1) {
-        batchTimeout = MIN(30 * 60, findTimeout + (int)(groupUUIDs.count + rootlessGroupUUIDs.count) * 60);
-    }

     PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
     PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
@@ -2274,38 +2737,15 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     // Cache canonical paths in rootful/rootless order; never reconstruct them from UUIDs.
     _wipeCacheBundleID = [bundleID copy];
     _wipeCacheApplicationDataCanonicalPaths = [canonicalApplicationDataPaths copy] ?: @[];
-    _wipeCacheGroupUUIDs = [groupUUIDs copy] ?: @[];
-    _wipeCacheRootlessGroupUUIDs = [rootlessGroupUUIDs copy] ?: @[];

-    [self logMessage:@"[AppDataCleaner] ApplicationData roots attempted=%lu succeeded=%lu failed=%lu; Groups=%lu RootlessGroups=%lu",
+    [self logMessage:@"[AppDataCleaner] ApplicationData roots attempted=%lu succeeded=%lu failed=%lu",
           (unsigned long)attemptedUnits,
           (unsigned long)succeededUnits,
-          (unsigned long)failedUnits,
-          (unsigned long)groupUUIDs.count,
-          (unsigned long)rootlessGroupUUIDs.count];
+          (unsigned long)failedUnits];

     // Clear App Store receipt
     [self clearAppReceiptData:bundleID withBundleUUID:nil];

-    // Process group + rootless group containers in ONE shell (same find/mkdir per path as before).
-    NSMutableArray<NSString *> *groupWipeParts = [NSMutableArray array];
-    [self logMessage:@"[AppDataCleaner] Wiping %lu app group containers (batched shell)", (unsigned long)groupUUIDs.count];
-    for (NSString *groupUUID in groupUUIDs) {
-        NSString *groupPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
-        [self logMessage:@"[AppDataCleaner] Fast wiping group: %@", groupUUID];
-        [groupWipeParts addObject:PXShellWipeContainerKeepMetadata(groupPath)];
-    }
-    for (NSString *groupUUID in rootlessGroupUUIDs) {
-        NSString *groupPath = [NSString stringWithFormat:@"/containers/Shared/AppGroup/%@", groupUUID];
-        [self logMessage:@"[AppDataCleaner] Fast wiping rootless group: %@", groupUUID];
-        [groupWipeParts addObject:PXShellWipeContainerKeepMetadata(groupPath)];
-    }
-    if (groupWipeParts.count > 0) {
-        [self runBatchedCommandsWithPrivileges:groupWipeParts timeoutSec:batchTimeout];
-    }
-
-    [self logMessage:@"[AppDataCleaner] Group containers wiped successfully"];
-
     // Extra cleanup for MobileMail: email/account display is primarily system-scoped (Accounts3 + /var/mobile/Library/Mail).
     if ([bundleID isEqualToString:@"com.apple.mobilemail"]) {
         [self logMessage:@"[AppDataCleaner] MobileMail: wiping /var/mobile/Library/Mail and mail prefs"];
@@ -2508,27 +2948,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

     // NOTE: Universal keychain wipe removed (too broad / can delete unrelated items).

-    // === FINAL SWEEP FOR 100% COVERAGE ===
-    NSLog(@"[AppDataCleaner] Starting final sweep for any remaining traces of %@", bundleID);
-    NSMutableArray *finalSweepPaths = [NSMutableArray array];
-    for (NSString *groupUUID in groupUUIDs) {
-        NSString *path = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
-        NSLog(@"[AppDataCleaner][Detect] App Group Container: %@", path);
-        [finalSweepPaths addObject:path];
-    }
-    for (NSString *groupUUID in rootlessGroupUUIDs) {
-        NSString *path = [NSString stringWithFormat:@"/containers/Shared/AppGroup/%@", groupUUID];
-        NSLog(@"[AppDataCleaner][Detect] Rootless App Group Container: %@", path);
-        [finalSweepPaths addObject:path];
-    }
-    // Recursively remove all non-Apple files from each container (parallelized)
-    dispatch_apply(finalSweepPaths.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
-        NSString *containerPath = finalSweepPaths[i];
-        NSLog(@"[AppDataCleaner][Sweep] Starting sweep for container: %@", containerPath);
-        [self finalSweepForContainer:containerPath];
-        NSLog(@"[AppDataCleaner][Sweep] Finished sweep for container: %@", containerPath);
-    });
-    // Sweep for crash logs and system logs
+    // Sweep for crash logs and system logs.
     [self removeCrashLogsForBundleID:bundleID];

     // Main application-data final sweep is read-only and consumes the canonical path cache directly.
@@ -4116,27 +4536,30 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         [self logMessage:@"[AppDataCleaner] Standalone verification used the legacy read-only application-data fallback"];
     }

-    // 2. Verify group containers (heuristic + entitlement-resolved — same as before when cache miss)
-    NSArray *groupContainerUUIDs = useWipeCache ? (_wipeCacheGroupUUIDs ?: @[]) : [self findGroupContainerUUIDsForBundleID:bundleID];
-    for (NSString *groupUUID in groupContainerUUIDs) {
-        NSString *groupContainerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
-        [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
-    }
-
-    // When cache hit, wipe already used entitlement-resolved groups as primary set — still union heuristic above.
-    // On cache miss, keep dual resolution (findGroup + entitlements) exactly as historical behavior.
-    if (!useWipeCache) {
+    // 2. Main-wipe App Group verification consumes canonical validator outputs directly.
+    if (useWipeCache) {
+        for (NSString *canonicalPath in (_wipeCacheAppGroupCanonicalPaths ?: @[])) {
+            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
+        }
+    } else {
+        // Standalone compatibility remains read-only and cannot authorize mutation.
+        NSArray *groupContainerUUIDs = [self findGroupContainerUUIDsForBundleID:bundleID];
+        for (NSString *groupUUID in groupContainerUUIDs) {
+            NSString *groupContainerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
+            [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
+        }
         NSArray *resolvedGroupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO];
         for (NSString *groupUUID in resolvedGroupUUIDs) {
             NSString *groupContainerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
             [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
         }
-    }
-
-    NSArray *rootlessGroupContainerUUIDs = useWipeCache ? (_wipeCacheRootlessGroupUUIDs ?: @[]) : [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES];
-    for (NSString *groupUUID in rootlessGroupContainerUUIDs) {
-        NSString *groupContainerPath = [NSString stringWithFormat:@"/containers/Shared/AppGroup/%@", groupUUID];
-        [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
+        NSArray *rootlessGroupContainerUUIDs =
+            [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES];
+        for (NSString *groupUUID in rootlessGroupContainerUUIDs) {
+            NSString *groupContainerPath = [NSString stringWithFormat:@"/containers/Shared/AppGroup/%@", groupUUID];
+            [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
+        }
+        [self logMessage:@"[AppDataCleaner] Standalone verification used legacy read-only App Group discovery"];
     }

     // 3. Verify extension and PluginKit data containers.
@@ -4222,7 +4645,9 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         if (([path containsString:@"/var/mobile/Containers/Data/Application"] ||
              [path containsString:@"/containers/Data/Application"] ||
              [path containsString:@"/private/var/mobile/Containers/Data/PluginKitPlugin"] ||
-             [path containsString:@"/containers/Data/PluginKitPlugin"]) &&
+             [path containsString:@"/containers/Data/PluginKitPlugin"] ||
+             [path containsString:@"/private/var/mobile/Containers/Shared/AppGroup"] ||
+             [path containsString:@"/containers/Shared/AppGroup"]) &&
             ([info containsString:@"StoreKit"] ||
              [info containsString:@"Directory has 0 non-system files"] ||
              [info containsString:@"Directory has 1 non-system files: Documents"] ||
@@ -4250,8 +4675,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     if (useWipeCache) {
         _wipeCacheBundleID = nil;
         _wipeCacheApplicationDataCanonicalPaths = nil;
-        _wipeCacheGroupUUIDs = nil;
-        _wipeCacheRootlessGroupUUIDs = nil;
+        _wipeCacheAppGroupCanonicalPaths = nil;
         _wipeCacheExtensionDataCanonicalPaths = nil;
         _wipeCachePluginKitDataCanonicalPaths = nil;
     }
@@ -5259,22 +5683,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         return;
     }

-    // Preserve legacy App Group deep scanning without re-resolving or mutating main application data.
-    NSArray *appGroupUUIDs = [self findAppGroupUUIDs:bundleID];
-    for (NSString *groupUUID in appGroupUUIDs) {
-        NSString *groupPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
-        NSArray *encryptionPatterns = @[
-            @"*.enc*", @"*.encrypted*", @"*.secure*", @"*.token*", @"*Token*",
-            @"*Auth*", @"*auth*", @"*cred*", @"*Cred*", @"*secret*", @"*Secret*"
-        ];
-        NSArray<NSString *> *matches = [self findPathsUnderRoot:groupPath
-                                                    directories:NO
-                                                   namePatterns:encryptionPatterns];
-        for (NSString *path in matches) {
-            NSLog(@"[AppDataCleaner] Wiping encrypted file in group: %@", path);
-            [self securelyWipeFile:path];
-        }
-    }
 }

 - (void)_internalClearEncryptedData:(NSString *)bundleID {
@@ -6718,13 +7126,8 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     [self _wipeContainersInBasePaths:@[@"/var/mobile/Containers/Shared/SystemGroup", @"/containers/Shared/SystemGroup"]
                   matchingSubstrings:@[@"webkit", @"safariviewservice", @"mobilesafari"]
                                 tag:@"MobileSafari(systemgroup)"];
-    [self _wipeContainersInBasePaths:@[@"/var/mobile/Containers/Shared/AppGroup", @"/containers/Shared/AppGroup"]
-                  matchingSubstrings:@[@"webkit", @"safariviewservice", @"mobilesafari"]
-                                tag:@"MobileSafari(appgroup)"];

-    // Final fallback: scrub WebKit/Safari state by filesystem structure inside shared containers.
-    [self _scrubWebKitStateInSharedContainerBase:@"/var/mobile/Containers/Shared/AppGroup" tag:@"MobileSafari(appgroup-scrub)"];
-    [self _scrubWebKitStateInSharedContainerBase:@"/containers/Shared/AppGroup" tag:@"MobileSafari(appgroup-scrub)"];
+    // Final fallback remains limited to SystemGroup containers.
     [self _scrubWebKitStateInSharedContainerBase:@"/var/mobile/Containers/Shared/SystemGroup" tag:@"MobileSafari(systemgroup-scrub)"];
     [self _scrubWebKitStateInSharedContainerBase:@"/containers/Shared/SystemGroup" tag:@"MobileSafari(systemgroup-scrub)"];

diff --git a/AppGroupContainerResolver.h b/AppGroupContainerResolver.h
index 14d1963..95b2505 100644
--- a/AppGroupContainerResolver.h
+++ b/AppGroupContainerResolver.h
@@ -1,7 +1,19 @@
 #import <Foundation/Foundation.h>

+#import "PXResolvedContainer.h"
+
 NS_ASSUME_NONNULL_BEGIN

+FOUNDATION_EXPORT NSString * const PXAppGroupContainerResolverErrorDomain;
+
+typedef NS_ENUM(NSInteger, PXAppGroupContainerResolverErrorCode) {
+    PXAppGroupContainerResolverErrorInvalidInput = 1,
+    PXAppGroupContainerResolverErrorEnumerationFailed = 2,
+    PXAppGroupContainerResolverErrorAmbiguousMatch = 3,
+    PXAppGroupContainerResolverErrorInvalidCandidate = 4,
+    PXAppGroupContainerResolverErrorMetadataInvalid = 5,
+};
+
 @interface AppGroupContainerInfo : NSObject
 @property (nonatomic, copy) NSString *groupID;
 @property (nonatomic, copy) NSString *uuid;
@@ -10,6 +22,10 @@ NS_ASSUME_NONNULL_BEGIN

 @interface AppGroupContainerResolver : NSObject

+- (nullable PXResolvedContainer *)resolveAppGroupContainerForGroupIdentifier:(NSString *)groupIdentifier
+                                                                        root:(PXResolvedContainerRoot)root
+                                                                       error:(NSError * _Nullable * _Nullable)error;
+
 // Maps application group identifiers to AppGroup container UUID/path using exact metadata matches.
 - (NSArray<AppGroupContainerInfo *> *)resolveGroupContainersForGroupIDs:(NSArray<NSString *> *)groupIDs;

diff --git a/AppGroupContainerResolver.m b/AppGroupContainerResolver.m
index 2513870..4cc67ab 100644
--- a/AppGroupContainerResolver.m
+++ b/AppGroupContainerResolver.m
@@ -1,10 +1,211 @@
 #import "AppGroupContainerResolver.h"

+#import <sys/stat.h>
+
+NSString * const PXAppGroupContainerResolverErrorDomain = @"PXAppGroupContainerResolver";
+
+static BOOL PXAppGroupResolverStringContainsNUL(NSString *value) {
+    unichar nulCharacter = 0;
+    NSString *nulString =
+        [NSString stringWithCharacters:&nulCharacter length:1];
+    return [value rangeOfString:nulString].location != NSNotFound;
+}
+
+static BOOL PXAppGroupResolverStringContainsNonWhitespace(NSString *value) {
+    NSCharacterSet *whitespace =
+        [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
+        != NSNotFound;
+}
+
+static BOOL PXAppGroupResolverIdentifierIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+
+    NSString *identifier = (NSString *)value;
+    return identifier.length > 0 &&
+           PXAppGroupResolverStringContainsNonWhitespace(identifier) &&
+           !PXAppGroupResolverStringContainsNUL(identifier);
+}
+
+static BOOL PXAppGroupResolverRootIsValid(PXResolvedContainerRoot root) {
+    return root == PXResolvedContainerRootRootful ||
+           root == PXResolvedContainerRootRootless;
+}
+
+static NSString *PXAppGroupResolverBaseForRoot(PXResolvedContainerRoot root) {
+    if (root == PXResolvedContainerRootRootful) {
+        return @"/private/var/mobile/Containers/Shared/AppGroup";
+    }
+    if (root == PXResolvedContainerRootRootless) {
+        return @"/containers/Shared/AppGroup";
+    }
+    return nil;
+}
+
+static void PXAppGroupResolverAssignError(NSError **error,
+                                          PXAppGroupContainerResolverErrorCode code,
+                                          NSString *message) {
+    if (!error) {
+        return;
+    }
+    *error = [NSError errorWithDomain:PXAppGroupContainerResolverErrorDomain
+                                 code:code
+                             userInfo:@{NSLocalizedDescriptionKey:
+                                            message ?: @"App Group container resolution failed"}];
+}
+
+static BOOL PXAppGroupResolverRealDirectoryAtPath(NSString *path) {
+    const char *fileSystemPath = path.fileSystemRepresentation;
+    if (!fileSystemPath) {
+        return NO;
+    }
+
+    struct stat entryStat;
+    if (lstat(fileSystemPath, &entryStat) != 0) {
+        return NO;
+    }
+    return S_ISDIR(entryStat.st_mode) && !S_ISLNK(entryStat.st_mode);
+}
+
+static BOOL PXAppGroupResolverRegularFileAtPath(NSString *path) {
+    const char *fileSystemPath = path.fileSystemRepresentation;
+    if (!fileSystemPath) {
+        return NO;
+    }
+
+    struct stat entryStat;
+    if (lstat(fileSystemPath, &entryStat) != 0) {
+        return NO;
+    }
+    return S_ISREG(entryStat.st_mode) && !S_ISLNK(entryStat.st_mode);
+}
+
 @implementation AppGroupContainerInfo
 @end

 @implementation AppGroupContainerResolver

+- (PXResolvedContainer *)resolveAppGroupContainerForGroupIdentifier:(NSString *)groupIdentifier
+                                                               root:(PXResolvedContainerRoot)root
+                                                              error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    if (!PXAppGroupResolverIdentifierIsValid(groupIdentifier) ||
+        !PXAppGroupResolverRootIsValid(root)) {
+        PXAppGroupResolverAssignError(error,
+                                      PXAppGroupContainerResolverErrorInvalidInput,
+                                      @"Invalid App Group container resolution request");
+        return nil;
+    }
+
+    NSString *basePath = PXAppGroupResolverBaseForRoot(root);
+    NSFileManager *fileManager = [NSFileManager defaultManager];
+    BOOL baseIsDirectory = NO;
+    if (![fileManager fileExistsAtPath:basePath isDirectory:&baseIsDirectory]) {
+        return nil;
+    }
+    if (!baseIsDirectory) {
+        PXAppGroupResolverAssignError(error,
+                                      PXAppGroupContainerResolverErrorEnumerationFailed,
+                                      @"App Group container root is not a directory");
+        return nil;
+    }
+
+    NSError *enumerationError = nil;
+    NSArray<NSString *> *entries =
+        [fileManager contentsOfDirectoryAtPath:basePath error:&enumerationError];
+    if (![entries isKindOfClass:[NSArray class]] || enumerationError) {
+        PXAppGroupResolverAssignError(error,
+                                      PXAppGroupContainerResolverErrorEnumerationFailed,
+                                      @"App Group container root enumeration failed");
+        return nil;
+    }
+
+    entries = [entries sortedArrayUsingSelector:@selector(compare:)];
+    NSMutableArray<PXResolvedContainer *> *matches = [NSMutableArray array];
+
+    for (NSString *entry in entries) {
+        if (![entry isKindOfClass:[NSString class]] || entry.length == 0 ||
+            [entry characterAtIndex:0] == (unichar)'.' ||
+            [[NSUUID alloc] initWithUUIDString:entry] == nil) {
+            continue;
+        }
+
+        NSString *containerPath = [basePath stringByAppendingPathComponent:entry];
+        if (!PXAppGroupResolverRealDirectoryAtPath(containerPath)) {
+            continue;
+        }
+
+        NSString *metadataPath = [containerPath stringByAppendingPathComponent:
+                                  @".com.apple.mobile_container_manager.metadata.plist"];
+        if (!PXAppGroupResolverRegularFileAtPath(metadataPath)) {
+            continue;
+        }
+
+        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
+        if (![metadata isKindOfClass:[NSDictionary class]]) {
+            continue;
+        }
+
+        id metadataIdentifier = metadata[@"MCMMetadataIdentifier"];
+        BOOL exactMatch = NO;
+        if ([metadataIdentifier isKindOfClass:[NSString class]]) {
+            NSString *metadataString = (NSString *)metadataIdentifier;
+            exactMatch = PXAppGroupResolverIdentifierIsValid(metadataString) &&
+                         [metadataString isEqualToString:groupIdentifier];
+        } else if ([metadataIdentifier isKindOfClass:[NSArray class]]) {
+            NSUInteger exactOccurrenceCount = 0;
+            for (id element in (NSArray *)metadataIdentifier) {
+                if ([element isKindOfClass:[NSString class]] &&
+                    [(NSString *)element isEqualToString:groupIdentifier]) {
+                    exactOccurrenceCount++;
+                }
+            }
+            if (exactOccurrenceCount > 1) {
+                PXAppGroupResolverAssignError(error,
+                                              PXAppGroupContainerResolverErrorMetadataInvalid,
+                                              @"App Group metadata contains duplicate exact identities");
+                return nil;
+            }
+            exactMatch = exactOccurrenceCount == 1;
+        }
+
+        if (!exactMatch) {
+            continue;
+        }
+
+        PXResolvedContainer *candidate =
+            [[PXResolvedContainer alloc] initWithKind:PXResolvedContainerKindAppGroup
+                                                 root:root
+                                  requestedIdentifier:groupIdentifier
+                                   metadataIdentifier:groupIdentifier
+                                        containerUUID:entry
+                                        containerPath:containerPath];
+        if (!candidate) {
+            PXAppGroupResolverAssignError(error,
+                                          PXAppGroupContainerResolverErrorInvalidCandidate,
+                                          @"Exact App Group match could not be represented safely");
+            return nil;
+        }
+        [matches addObject:candidate];
+    }
+
+    if (matches.count == 0) {
+        return nil;
+    }
+    if (matches.count > 1) {
+        PXAppGroupResolverAssignError(error,
+                                      PXAppGroupContainerResolverErrorAmbiguousMatch,
+                                      @"Multiple exact App Group container matches were found");
+        return nil;
+    }
+    return matches.firstObject;
+}
+
 - (NSArray<AppGroupContainerInfo *> *)resolveGroupContainersForGroupIDs:(NSArray<NSString *> *)groupIDs {
     if (!groupIDs.count) {
         return @[];
```

## 22. Whitespace, NUL, generated and binary audit

| File | NUL | Total trailing-whitespace lines | Line-ending state |
|---|---:|---:|---|
| `AppGroupContainerResolver.h` | 0 | 0 | CRLF=34, bare LF=0 |
| `AppGroupContainerResolver.m` | 0 | 0 | CRLF=284, bare LF=0 |
| `AppDataCleaner.m` | 0 | 617 | CRLF=8004, bare LF=0 |

`AppDataCleaner.m` baseline contained 618 historical trailing-whitespace lines; current total is 617 because removed legacy lines included one such line. No new or modified line violates the whitespace gate: `git diff --check` passes. The two resolver files and this report contain zero trailing-whitespace lines. No NUL, generated source, build output or binary marker is present. Temporary `.task19*` audit/generator files are removed before commit.

Local Objective-C/Theos build was not run because this Windows workspace has no `clang` or `make`; GitHub Actions remains the compilation gate.

## 23. Scenario matrix

All rows are STATIC REVIEW unless a device runtime is explicitly supplied later.

| # | Scenario | Static expected/implemented result |
|---:|---|---|
| 1 | Invalid group identifier input | Typed resolver clears error and returns InvalidInput; no filesystem work |
| 2 | Invalid root | InvalidInput |
| 3 | Missing rootful base | nil with no error |
| 4 | Missing rootless base | nil with no error |
| 5 | Base is non-directory | EnumerationFailed |
| 6 | Enumeration failure | EnumerationFailed |
| 7 | Metadata string exact match | Candidate matches by exact case-sensitive equality |
| 8 | Metadata string mismatch | Candidate skipped |
| 9 | Metadata array exact occurrence once | Candidate matches |
| 10 | Metadata array zero occurrence | Candidate skipped |
| 11 | Metadata array duplicate exact occurrence | MetadataInvalid |
| 12 | Non-string array members | Ignored as non-matches |
| 13 | Two exact physical containers in one root | AmbiguousMatch |
| 14 | Model construction failure | InvalidCandidate |
| 15 | Entitlement extraction error | AppGroups Failed 1/0/1, EntitlementDiscoveryFailed |
| 16 | Neither entitlement key present | Empty exact list; AppGroups Skipped 0/0/0 with declared-none detail |
| 17 | Malformed entitlement key type | Whole discovery fails |
| 18 | Invalid entitlement element | Whole discovery fails |
| 19 | Duplicate exact identifier across entitlement arrays | Exact deduplication, one sorted identifier |
| 20 | One rootful App Group container | One physical execution unit |
| 21 | One rootless App Group container | One physical execution unit |
| 22 | Same group ID in both roots | Two physical units unless validator canonical paths are identical |
| 23 | Two group IDs map to one physical container | Alias collapse: one command/attempted physical unit, both models retained |
| 24 | Resolver error plus another successful physical container | Failed tuple counted; remaining physical unit continues |
| 25 | Validator failure | Failed tuple, no command for that tuple |
| 26 | Command failure | Physical unit failed; remaining units continue |
| 27 | Output truncation | Strict command-result gate fails the physical unit |
| 28 | Post-command identity change | Any alias-model mismatch fails the physical unit |
| 29 | Postcondition failure | Physical unit failed |
| 30 | Final read-only postcondition regression | Prior success decremented and failed incremented |
| 31 | Declared identifiers but no exact containers | AppGroups Skipped 0/0/0 with exact no-container detail |
| 32 | All AppGroups succeed | Succeeded; attempted > 0 and succeeded == attempted |
| 33 | Partial AppGroups success | Failed with exact mixed counts |
| 34 | ApplicationData and AppGroups both fail | ApplicationData callback error wins; AppGroups logged |
| 35 | AppGroups and PluginKitData both fail | AppGroups callback error wins; PluginKitData logged |
| 36 | AppGroups failure plus Keychain failure | AppGroups callback error wins; Keychain logged |
| 37 | No AppGroups; other migrated components succeed | Skipped AppGroups is not callback failure |
| 38 | Standalone verifier cache miss | Legacy discovery remains read-only and cannot authorize mutation |
| 39 | MobileSafari after typed component | No Shared/AppGroup fuzzy wipe or structure scrub remains |
| 40 | Legacy Backup/Restore resolver call | Legacy resolveGroupContainersForGroupIDs selector and model remain source-compatible |

## 24. Remaining risks

- Actual rootful/rootless metadata and entitlement layouts require representative device tests.
- Alias-collapse behavior should be exercised with array metadata where two declared identities authorize one physical container.
- Timeout, truncation, post-command identity replacement and final-regression cases require injected/runtime tests.
- Legacy public mutation helpers remain callable for compatibility but are intentionally quarantined from migrated main Clear; later quarantine work must not occur in TASK-1.9.
- GitHub Actions must confirm Objective-C compilation and integration.

## 25. Post-commit handoff

After committing exactly the three production files and this report, run `git show --check --oneline HEAD`. The actual final HEAD and result are recorded in the task response; no source is changed after that gate.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
