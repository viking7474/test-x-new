# TASK-1.7 Report — Migrate Main Application-Data Clear

## 1. Task metadata

| Field | Value |
|---|---|
| Task | TASK-1.7 |
| Specification | `docs/backup-restore-hardening/tasks/TASK-1.7-migrate-main-application-data-clear.md` |
| Baseline HEAD | `81de2a7ef28f862f78a7ae55f0d8897066a85f94` |
| Baseline subject | `81de2a7 task-1.6` |
| Allowed production file | `AppDataCleaner.m` |
| Production files changed | `AppDataCleaner.m` only |
| Required report | `docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md` |
| Runtime classification | STATIC REVIEW |
| Suggested state | READY_FOR_REVIEW |

TASK-1.7 migrates only the main ApplicationData component inside the existing legacy Clear flow. It does not add a public typed Clear API, build a five-scope aggregate, migrate extension/App Group/PluginKit/Keychain behavior, alter Backup/Restore/UI, or begin TASK-1.8.

## 2. Required reading

The complete 838-line task specification was read before source modification. The following required sources and governance files were then read or traversed in full:

- `docs/backup-restore-hardening/README.md`
- `docs/backup-restore-hardening/STATUS.md`
- `docs/backup-restore-hardening/DECISIONS.md`
- `docs/backup-restore-hardening/reviews/TASK-1.6-REVIEW.md`
- `docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md`
- `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
- `PXResolvedContainer.h/.m`
- `PXDataContainerResolver.h/.m`
- `PXDestructivePathValidator.h/.m`
- `PXClearRequest.h/.m`
- `PXClearResult.h/.m`
- `CommandRunner.h/.m`
- `AppDataCleaner.h`
- `complete AppDataCleaner.m baseline (6,388 lines)`
- `Makefile`

Accepted decisions D-071 through D-079 require independent root units, no legacy fallback for migrated main selection, canonical validator output as the only mutation authority, one bounded result command per root, post-command proof, canonical path caching, ApplicationData failure propagation and ApplicationData error precedence over simultaneous Keychain failure.

## 3. Initial working tree and HEAD

Initial `git status --short --untracked-files=all`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.6-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.7-migrate-main-application-data-clear.md
```

```text
git rev-parse HEAD: 81de2a7ef28f862f78a7ae55f0d8897066a85f94
git log -1 --oneline: 81de2a7 task-1.6
```

There was no production modification at task start. All initial working-tree entries were coordinator-owned documentation/review/specification changes.

## 4. Allowed-file diff inventory

| File | Action | Scope |
|---|---|---|
| `AppDataCleaner.m` | Modified | Imports, private ApplicationData request/result path, exact resolver/validator root loop, strict wipe/postcondition, completion propagation and canonical cache migration |
| `docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md` | Created | Task evidence and build handoff |
| Any other production file | Unchanged | Protected by checksum and zero diff |

No file was staged, committed, reverted or reformatted. `AppDataCleaner.h` and `Makefile` were not edited.

## 5. Protected checksum comparison

| Protected file | Initial SHA-256 | Final SHA-256 | Equal |
|---|---|---|---|
| `AppDataCleaner.h` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | Yes |
| `PXResolvedContainer.h` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | Yes |
| `PXResolvedContainer.m` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | Yes |
| `PXDataContainerResolver.h` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | Yes |
| `PXDataContainerResolver.m` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | Yes |
| `PXDestructivePathValidator.h` | `542E158A4F04BF50125E0064FBEBF02AC32F1DE07508C3F32058E770F75A3C0A` | `542E158A4F04BF50125E0064FBEBF02AC32F1DE07508C3F32058E770F75A3C0A` | Yes |
| `PXDestructivePathValidator.m` | `F275A60BE5CAB58E5D06DB3DD0987948F5EAB65DDD7E35E35E45927D238877CB` | `F275A60BE5CAB58E5D06DB3DD0987948F5EAB65DDD7E35E35E45927D238877CB` | Yes |
| `PXClearRequest.h` | `D87402EE3720F1723977E4DEB3D78BC1DE87362948DFE585B5ED98F6447AE26B` | `D87402EE3720F1723977E4DEB3D78BC1DE87362948DFE585B5ED98F6447AE26B` | Yes |
| `PXClearRequest.m` | `AFC763AFC3306D422EF67EF3BD28A2A1A5741A64EA6078EE28F56F5D5901C790` | `AFC763AFC3306D422EF67EF3BD28A2A1A5741A64EA6078EE28F56F5D5901C790` | Yes |
| `PXClearResult.h` | `CEDC6E364EBC4BF25ACD8D128938DB114033CA076750D2FADE8E183488B2B592` | `CEDC6E364EBC4BF25ACD8D128938DB114033CA076750D2FADE8E183488B2B592` | Yes |
| `PXClearResult.m` | `0E4BCE039D6CA19F46590822BDFC938763CDDC852BE3045F6ADA98E2FA0C5715` | `0E4BCE039D6CA19F46590822BDFC938763CDDC852BE3045F6ADA98E2FA0C5715` | Yes |
| `CommandRunner.h` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | Yes |
| `CommandRunner.m` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | Yes |
| `AppGroupContainerResolver.h` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | Yes |
| `AppGroupContainerResolver.m` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | Yes |
| `AppDataBackupManager.h` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | Yes |
| `AppDataBackupManager.m` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | Yes |
| `Makefile` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | Yes |

`git diff --exit-code -- <all 18 protected paths>` returned 0 with empty stdout/stderr. The allowed source changed from working-tree SHA-256 `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8` to `4544C460505443929FE986CB914DF8E0DB5B58D5ED8A0D7AC1C6911E074ECACC`.

## 6. Imports, private API and public compatibility

`AppDataCleaner.m` adds exactly these imports:

```objc
#import "PXDataContainerResolver.h"
#import "PXDestructivePathValidator.h"
#import "PXClearRequest.h"
#import "PXClearResult.h"
```

`AppDataCleaner.h` has zero typed request/result references and its checksum is unchanged. The public selectors remain:

```objc
- (void)clearDataForBundleID:(NSString *)bundleID
                  completion:(void (^)(BOOL success, NSError *error))completion;
- (void)completeAppDataWipe:(NSString *)bundleID;
```

The new private selector is declared and implemented exactly once:

```objc
- (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:
    (PXClearRequest *)request;
```

The public `completeAppDataWipe:` compatibility method constructs an ApplicationData-only request, delegates to the private path and logs status/attempted/succeeded/failed counts. No public typed Clear API was added.

## 7. ApplicationData-only request creation

`clearDataForBundleID:completion:` reads deep-clean intent once before background tasks, freezing, Keychain or any destructive operation:

```objc
BOOL deepClean = [self _deepCleanEnabled];
PXClearRequest *applicationDataRequest =
    [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                             scopes:PXClearScopeApplicationData
                                          deepClean:deepClean];
```

The method-body count of `_deepCleanEnabled` is one. `PXClearScopeDefaultMask` occurs zero times in `AppDataCleaner.m`. An invalid runtime bundle identifier/request dispatches completion failure and returns before background task, freeze, Keychain, resolver or mutation setup.

## 8. Exact root order and unit accounting

The private path contains the explicit ordered root sequence:

```objc
@[@(PXResolvedContainerRootRootful),
  @(PXResolvedContainerRootRootless)]
```

| Per-root state | attempted delta | succeeded delta | failed delta | Continue other root |
|---|---:|---:|---:|---|
| resolver returns nil, error nil | 0 | 0 | 0 | Yes |
| resolver error | 1 | 0 | 1 | Yes |
| resolved, initial validator rejects | 1 | 0 | 1 | Yes |
| bounded command fails/truncates | 1 | 0 | 1 | Yes |
| post-command validator/path equality fails | 1 | 0 | 1 | Yes |
| strict postcondition fails | 1 | 0 | 1 | Yes |
| all gates pass | 1 | 1 | 0 | Yes |

A later final read-only cache check can convert an earlier successful unit into a failed unit by decrementing succeeded and incrementing failed without changing attempted. Thus one root success plus one root failure is exactly Failed 2/1/1.

## 9. Exact resolver usage and no-fallback proof

For each ordered root, selection uses only:

```objc
[resolver resolveApplicationDataContainerForIdentifier:request.bundleIdentifier
                                               root:root
                                              error:&resolutionError]
```

The resolver selector appears once inside the two-root loop and therefore executes once for rootful and once for rootless. Inside the private result method, all main-target counts below are zero:

| Forbidden main-target path | Count |
|---|---:|
| `optimized_findDataContainerUUID:inDirectories:` | 0 |
| `optimized_findRootlessDataContainerUUID:inDirectories:` | 0 |
| `findDataContainerUUID:` | 0 |
| `findRootlessDataContainerUUID:` | 0 |
| `findDataContainerUUIDForBundleID:` | 0 |
| company/app-name matcher | 0 |
| prefix/substring identity matcher | 0 |
| raw `dataUUID` main-target variable | 0 |
| raw `rootlessDataUUID` main-target variable | 0 |
| formatted rootful main mutation path | 0 |
| formatted rootless main mutation path | 0 |

Cached root directory listings are retained only for extension discovery and are never passed into main application-data selection.

## 10. Canonical-only mutation and pre-command validation

A resolved object is immediately passed to:

```objc
[validator validatedCanonicalPathForContainer:container error:&validationError]
```

If validation fails, no command is built or run. On success, every main-wipe operation receives only the returned canonical string. The migrated path contains zero references to `container.containerPath`, `container.containerUUID`, raw UUID reconstruction, `completelyWipeContainer:`, `wipeDirectoryContents:` or a void main wipe command.

## 11. Strict shell design and exit status

`PXShellValidatedApplicationDataWipe` shell-quotes the canonical path and uses an explicit status accumulator:

```text
container=<shell-quoted canonical path>
status=0
iterate immediate visible and hidden children only
preserve exactly the two metadata file names
best-effort chflags for each child
required rm failure => status=1
required Documents/Library/tmp mkdir failure => status=1
exit "$status"
```

The script does not remove the container root, rewrite metadata, create marker files, touch `.nomedia`/`.initialized`, run recursive chmod 777, or chown. Required `rm` and `mkdir` operations contain zero `|| true`; the sole best-effort `|| true` belongs to `chflags`, while strict postconditions independently detect residuals.

## 12. Bounded CommandResult mapping

Each validated root executes exactly one command through:

```objc
[self runCommandWithPrivilegesResult:wipeCommand timeoutSec:rmTimeout]
```

The command unit succeeds only when:

```objc
result != nil &&
result.isSucceeded &&
!result.stdoutTruncated &&
!result.stderrTruncated
```

`CommandResult.isSucceeded` already requires zero spawn/runner errors, no timeout, normal exit, no terminating signal and exit code zero. Nil, spawn error, runner error, timeout, signal/abnormal exit, nonzero exit or either truncation therefore maps to `ExecutionFailed`. The command and canonical path are never logged as structured detail/failure state.

## 13. Post-command revalidation

After command success, the same immutable `PXResolvedContainer` is validated again. Success additionally requires a nonempty second canonical path and exact string equality with the pre-command canonical path. A failure or path change produces a failed unit and skips success credit.

## 14. Strict postcondition matrix

| Inspection | Required result | Failure behavior |
|---|---|---|
| container `lstat` | real directory | fail closed |
| top-level enumeration | succeeds | fail closed |
| top-level name | one of two metadata files, Documents, Library, tmp | reject unexpected entry |
| every top-level object `lstat` | succeeds and is not symlink | fail closed |
| metadata entry if present | regular file | reject other type |
| Documents | real non-symlink directory, empty | fail closed |
| Library | real non-symlink directory, empty | fail closed |
| tmp | real non-symlink directory, empty | fail closed |

The postcondition is read-only and contains three `lstat` call sites, explicit symlink checks, two directory enumeration call sites and no mutation.

## 15. Structured component result

The private path returns one final `PXClearComponentResult` for `PXClearScopeApplicationData`:

| Aggregate root outcome | Status | attempted | succeeded | failed | failure | detail |
|---|---|---:|---:|---:|---|---|
| both roots absent, no resolver error | Skipped | 0 | 0 | 0 | nil | exact required skip string |
| every attempted root succeeds | Succeeded | 1 or 2 | attempted | 0 | nil | deterministic root summaries |
| any root fails | Failed | 1 or 2 | 0 or 1 | `attempted - succeeded` | first failure snapshot | deterministic root summaries |

The exact skip detail is:

```text
No exact application-data container exists in either supported root
```

A structural validator checks scope, overflow-safe count partition and status invariants before the result reaches the legacy completion path. If internal construction is nil/invalid, a stable InternalResultFailure component is substituted; the caller independently treats nil/invalid as completion failure.

## 16. Failure domain and deterministic messages

Stable private domain:

```text
PXApplicationDataClear
```

Fixed codes:

| Code | Meaning |
|---:|---|
| 1 | InvalidRequest |
| 2 | ResolutionFailed |
| 3 | ValidationFailed |
| 4 | ExecutionFailed |
| 5 | PostconditionFailed |
| 6 | InternalResultFailure |

The first root failure snapshot is retained while the other root continues. Root summaries may say rootful/rootless and absent/succeeded/failure stage, but contain no canonical path, shell command or mutable resolver/validator `NSError.userInfo`. Underlying diagnostic domain/code values are log-only.

## 17. Legacy completion propagation

| ApplicationData result | Legacy policy |
|---|---|
| Failed | completion `NO` with a newly constructed NSError from the immutable failure snapshot |
| Succeeded | continue existing Keychain/legacy completion policy |
| Skipped | log skip and continue existing Keychain/legacy completion policy |
| nil/structurally invalid | completion `NO` with InternalResultFailure |

When ApplicationData and Keychain both fail, ApplicationData error is returned and Keychain error is separately logged. When only Keychain fails, the prior Keychain callback behavior remains. Verification remains log-only and is not newly mapped to completion success/failure.

## 18. Canonical cache migration

Removed cache ivars:

```text
_wipeCacheDataUUID
_wipeCacheRootlessDataUUID
```

Replacement:

```objc
NSArray<NSString *> *_wipeCacheApplicationDataCanonicalPaths;
```

Every path is copied from validator output, appended in rootful-then-rootless iteration order, and copied as an array. A validated path is cached even if its later command fails, so read-only verification can report residuals. The main final read-only sweep iterates the cache directly. Matching `verifyDataCleared:` also iterates it directly and clears it when the existing wipe cache is consumed. App Group and extension cache schemas are unchanged.

## 19. Verification integration

When `_wipeCacheBundleID` matches, main verification uses canonical cached paths and performs zero UUID reconstruction/fuzzy main discovery. Without a matching cache, standalone `verifyDataCleared:` retains its existing legacy read-only rootful/rootless UUID fallback as explicitly permitted by TASK-1.7. Its final Boolean policy remains unchanged and log-only in the primary flow.

## 20. Redundant and transitive bypass audit

Removed from the reachable main path:

- raw rootful primary wipe;
- raw rootless primary wipe;
- redundant raw `Library/HTTPStorages` wipe;
- main application-data paths from the destructive `finalSweepForContainer:` array;
- the main-container portion of `_internalClearEncryptedData:`.

A split `_internalClearEncryptedDataOutsideMainApplicationContainer:deepClean:` preserves encrypted preference and App Group scans but has zero `Data/Application` literals and zero main UUID resolver calls. The original public/private legacy helper remains unchanged for external callers.

Static recursive call-graph review found 33 methods reachable from the private full path. The only reachable method containing raw Data/Application literals is extension discovery/mutation, whose inputs are extension records. `finalSweepForContainer:` remains reachable only with App Group/extension paths. No reachable helper rediscoveries or mutates the main application-data container after the primary validated wipe.

## 21. Remaining Data/Application literal classification

Final source contains 60 occurrences on 57 lines in 22 method groups. Three conditional base-path lines contain two literals each. Every group was classified:

| Owner | Lines | Classification |
|---|---|---|
| `_completeAppDataWipeForApplicationDataRequest:` | 1386, 1387, 1388 | Read-only root directory listings passed only to extension discovery; never used for main target selection. |
| `_completeAppDataWipeForApplicationDataRequest:` | 1710, 1804 | Legacy extension-container path selection/final sweep. The values come from extension records, not from the main application-data resolver/cache. |
| `findDataContainerUUID:aggressive:` | 2103, 2105, 2119 | Legacy read-only/fuzzy discovery helper outside the migrated private call graph. |
| `findDataContainerUUID:` | 2139, 2143 | Legacy read-only discovery wrapper outside the migrated private call graph. |
| `findRootlessDataContainerUUID:aggressive:` | 2161, 2162, 2164, 2175 | Legacy rootless read-only/fuzzy discovery outside the migrated private call graph. |
| `findRootlessDataContainerUUID:` | 2194, 2199, 2203 | Legacy rootless read-only discovery wrapper outside the migrated private call graph. |
| `verifyDataCleared:` | 3392, 3398 | Standalone no-cache verification fallback only; read-only and not used when the main wipe cache matches. |
| `verifyDataCleared:` | 3431, 3451 | Read-only extension-container verification. |
| `verifyDataCleared:` | 3441, 3442 | Read-only listings for extension discovery when no wipe cache exists. |
| `verifyDataCleared:` | 3497, 3498 | Read-only result filtering/classification. |
| `hasDataToClear:` | 3822, 3831 | Legacy preflight/read-only presence inspection; not a migrated mutation target. |
| `optimized_findDataContainerUUID:inDirectories:` | 3909, 3920 | Dormant/legacy main discovery implementation; zero calls from the migrated private path. |
| `optimized_findRootlessDataContainerUUID:inDirectories:` | 3941, 3950 | Dormant/legacy rootless discovery implementation; zero calls from the migrated private path. |
| `optimized_findExtensionContainers:...` | 4044, 4058 | Read-only extension mapping from exact extension bundle IDs to extension data UUIDs. |
| `performFullCleanup:` | 4094, 4095 | Legacy externally reachable main-data mutation outside the TASK-1.7 main call graph; retained for later quarantine/TASK-1.12. |
| `clearAppCache:` | 4144, 4149 | Legacy externally reachable main-data helper outside the migrated main call graph. |
| `clearAppPreferences:` | 4162, 4167 | Legacy externally reachable main-data helper outside the migrated main call graph. |
| `clearAppCookies:` | 4180, 4185 | Legacy externally reachable main-data helper outside the migrated main call graph. |
| `clearAppWebKitData:` | 4198, 4203 | Legacy externally reachable main-data helper outside the migrated main call graph. |
| `getDataUsage:` | 4287, 4293 | Read-only size/accounting inspection. |
| `_internalClearEncryptedData:` | 4594 | Original legacy helper retained unchanged for external callers; the migrated main flow calls a split non-main helper instead. |
| `findExtensionContainers:` | 4682, 4685, 4709, 4710, 4713 | Legacy read-only extension discovery. |
| `performAggressiveCleanupFor:` | 4983 | Legacy external aggressive path outside the migrated main call graph. |
| `_wipeRelatedDataContainersForBundleIDs:` | 5513, 5514 | Legacy external related-container mutation outside the migrated main call graph. |
| `_wipeDataContainersByIdentifierPrefixOrSubstring:...` | 5626, 5627 | Legacy external fuzzy mutation helper outside the migrated main call graph; retained for later quarantine. |
| `findExtensionDataContainersForBundleID:` | 6015 | Legacy read-only extension data discovery. |

The legacy externally callable fuzzy/raw helpers remain a documented risk but are outside the TASK-1.7 main call graph and outside this task’s authority to remove. Their quarantine is assigned to later work, especially TASK-1.12.

## 22. Extension, App Group, PluginKit and Keychain not-changed proof

| Existing method | Baseline SHA-256 | Final SHA-256 | Equal |
|---|---|---|---|
| `optimized_findExtensionContainers:dataDirs:rootlessDataDirs:bundleDirs:rootlessBundleDirs:` | `2542BF995729FCD01F4CFFF5177F5CA5EAE3E350BFEB3F7DA26708330B134B19` | `2542BF995729FCD01F4CFFF5177F5CA5EAE3E350BFEB3F7DA26708330B134B19` | Yes |
| `_resolvedAppGroupUUIDsFromEntitlements:rootless:` | `A9399EA7BB4DAAABF441302BC36175346C9F72FDC9C17E8EC8F0592BC52C6B7B` | `A9399EA7BB4DAAABF441302BC36175346C9F72FDC9C17E8EC8F0592BC52C6B7B` | Yes |
| `_wipeSelectedKeychainForBundleID:error:` | `B8E613D318CA2C9D53221873C7EC2AF1E14ABCB6EDDB454AE286B976D6A2E4D2` | `B8E613D318CA2C9D53221873C7EC2AF1E14ABCB6EDDB454AE286B976D6A2E4D2` | Yes |
| `clearPluginKitData:` | `C3548AA678443B404CFA72619BA3CA6C0A6EC3435787020287DEAC9BF47A9A6D` | `C3548AA678443B404CFA72619BA3CA6C0A6EC3435787020287DEAC9BF47A9A6D` | Yes |
| `findExtensionContainers:` | `2542BF995729FCD01F4CFFF5177F5CA5EAE3E350BFEB3F7DA26708330B134B19` | `2542BF995729FCD01F4CFFF5177F5CA5EAE3E350BFEB3F7DA26708330B134B19` | Yes |
| `findExtensionDataContainersForBundleID:` | `E74A51FEFF93AE88E326188F9864A0EBDB0981EC76270933F33819851D90B2B1` | `E74A51FEFF93AE88E326188F9864A0EBDB0981EC76270933F33819851D90B2B1` | Yes |
| `clearAppReceiptData:withBundleUUID:` | `85451006C2422605276B7411FFD5D75C7FFE8EA8146EAADDABDADB1C9D716C68` | `85451006C2422605276B7411FFD5D75C7FFE8EA8146EAADDABDADB1C9D716C68` | Yes |

Extension/App Group legacy blocks remain in their prior relative order after main root processing. PluginKit is not migrated. Keychain continues to use its pre-existing BOOL/NSError flow; no Keychain `PXClearComponentResult` is created. Backup, Restore and UI files are protected and unchanged.

## 23. Application-bundle boundary

TASK-1.4 gates remain true:

```text
_MASReceipt tokens: 0
._MASReceipt tokens: 0
rootlessBundlePath full-wipe token: 0
application-bundle/receipt scope added: no
public receipt selector: unchanged logged compatibility no-op
```

Bundle listings and `bundleUUID` remain read-only discovery/compatibility inputs. No bundle path is passed to resolver, validator or deletion code by TASK-1.7.

## 24. Generic helper not-changed proof

| Generic helper | Baseline body SHA-256 | Final body SHA-256 | Equal |
|---|---|---|---|
| `completelyWipeContainer:` | `BC46758CB6830B2851F62FB1892BE18E59C0DED8515DC1812AD975052B7AC2B2` | `BC46758CB6830B2851F62FB1892BE18E59C0DED8515DC1812AD975052B7AC2B2` | Yes |
| `fixPermissionsAndRemovePath:` | `027A2BB00E724E98287B66CD686BD0133C48D4109E933F4A32A63234B80A64AE` | `027A2BB00E724E98287B66CD686BD0133C48D4109E933F4A32A63234B80A64AE` | Yes |
| `fixPermissionsForPath:` | `935295E64A6E260FA7BE55D6ABFF7F6D1099D8DACDFE13080983B1E4BB7132E2` | `935295E64A6E260FA7BE55D6ABFF7F6D1099D8DACDFE13080983B1E4BB7132E2` | Yes |
| `wipeDirectoryContents:keepDirectoryStructure:` | `2E96003EC60B68B09E6D2DD59060C1ADDEE1FFFB69524F876DFB0A91E9DA6C3F` | `2E96003EC60B68B09E6D2DD59060C1ADDEE1FFFB69524F876DFB0A91E9DA6C3F` | Yes |
| `securelyWipeFile:` | `632915879D115E073795CAC55E016C98A48018F2B1DAB1D75907C5F528E99721` | `632915879D115E073795CAC55E016C98A48018F2B1DAB1D75907C5F528E99721` | Yes |
| `clearAppReceiptData:withBundleUUID:` | `85451006C2422605276B7411FFD5D75C7FFE8EA8146EAADDABDADB1C9D716C68` | `85451006C2422605276B7411FFD5D75C7FFE8EA8146EAADDABDADB1C9D716C68` | Yes |

The migrated main component calls none of these helpers for a validated main container.

## 25. Scenario matrix

| # | Scenario | Required/final outcome | Classification |
|---:|---|---|---|
| 1 | Both roots absent | Skipped, attempted/succeeded/failed = 0/0/0; exact required detail; legacy flow continues. | STATIC REVIEW |
| 2 | Rootful exact container only | Succeeded 1/1/0 after validation, command, revalidation and postcondition. | STATIC REVIEW |
| 3 | Rootless exact container only | Succeeded 1/1/0. | STATIC REVIEW |
| 4 | Both roots exact and successful | Succeeded 2/2/0 in rootful-then-rootless processing order. | STATIC REVIEW |
| 5 | Rootful resolver error, rootless absent | Failed 1/0/1; rootless is still inspected and classified absent. | STATIC REVIEW |
| 6 | Rootful absent, rootless resolver error | Failed 1/0/1. | STATIC REVIEW |
| 7 | One root validator rejection | One failed attempted unit; no command/mutation for that root. | STATIC REVIEW |
| 8 | One root success, other validation failure | Failed partial 2/1/1. | STATIC REVIEW |
| 9 | Command returns nil | ExecutionFailed unit. | STATIC REVIEW |
| 10 | Command spawn error | ExecutionFailed; `isSucceeded` is false. | STATIC REVIEW |
| 11 | Command runner error | ExecutionFailed; `isSucceeded` is false. | STATIC REVIEW |
| 12 | Command timeout | ExecutionFailed. | STATIC REVIEW |
| 13 | Signal termination or abnormal exit | ExecutionFailed. | STATIC REVIEW |
| 14 | Nonzero command exit | ExecutionFailed. | STATIC REVIEW |
| 15 | stdout or stderr truncation | ExecutionFailed even if the process otherwise reports success. | STATIC REVIEW |
| 16 | Post-command validator rejects the same container | ValidationFailed unit. | STATIC REVIEW |
| 17 | Post-command canonical path differs | ValidationFailed unit; no success credit. | STATIC REVIEW |
| 18 | Required Documents/Library/tmp missing | PostconditionFailed. | STATIC REVIEW |
| 19 | Required directory is symlink or not a real directory | PostconditionFailed through `lstat`. | STATIC REVIEW |
| 20 | Required directory is nonempty | PostconditionFailed. | STATIC REVIEW |
| 21 | Unexpected top-level item remains | PostconditionFailed. | STATIC REVIEW |
| 22 | Top-level entry inspection error or symlink | PostconditionFailed, fail closed. | STATIC REVIEW |
| 23 | One root command fails, the other succeeds | Both roots processed; Failed partial 2/1/1. | STATIC REVIEW |
| 24 | ApplicationData failure plus Keychain success | Legacy completion NO with newly constructed ApplicationData NSError. | STATIC REVIEW |
| 25 | ApplicationData success plus Keychain failure | Existing Keychain failure callback policy remains. | STATIC REVIEW |
| 26 | Both ApplicationData and Keychain fail | ApplicationData error returned; Keychain failure separately logged. | STATIC REVIEW |
| 27 | ApplicationData skipped plus Keychain success | Skip logged; existing policy completes success. | STATIC REVIEW |
| 28 | Nil or structurally invalid internal component | Legacy completion failure with InternalResultFailure. | STATIC REVIEW |
| 29 | Invalid bundle identifier/request | No background task, freeze, keychain, resolver or destructive work starts; completion failure. | STATIC REVIEW |
| 30 | Public `completeAppDataWipe:` caller | Builds ApplicationData-only request, delegates and logs status/counts; public signature remains void. | STATIC REVIEW |
| 31 | Main verification after wipe | Uses copied canonical paths directly and clears cache when consumed. | STATIC REVIEW |
| 32 | Standalone verification without matching cache | Retains documented legacy read-only UUID fallback. | STATIC REVIEW |
| 33 | Validated root command later fails | Canonical path remains in read-only cache so residuals can be reported. | STATIC REVIEW |
| 34 | Final read-only postcondition regresses after earlier success | Succeeded count is converted to failed count before final component creation. | STATIC REVIEW |
| 35 | Extension discovery and mutation | Legacy behavior retained; directory listings are not used for main target selection. | STATIC REVIEW |
| 36 | App Group clear | Legacy resolver/schema and mutation behavior retained. | STATIC REVIEW |
| 37 | PluginKit clear | Legacy implementation unchanged and not migrated to a component result. | STATIC REVIEW |
| 38 | Keychain clear | Existing BOOL/NSError flow retained; no Keychain component result is introduced. | STATIC REVIEW |
| 39 | Application bundle/receipt behavior | No bundle mutation restored; receipt selector remains compatibility no-op. | STATIC REVIEW |
| 40 | Structured detail/failure privacy | Deterministic root labels/messages only; no canonical path or shell command. | STATIC REVIEW |
| 41 | Required shell `rm` fails | Status accumulator becomes nonzero and command unit fails. | STATIC REVIEW |
| 42 | Required shell `mkdir` fails | Status accumulator becomes nonzero and command unit fails. | STATIC REVIEW |
| 43 | Metadata files exist | Script preserves them; postcondition rejects symlink/non-regular metadata. | STATIC REVIEW |
| 44 | Caller/root ordering differs | Not applicable: root order is fixed rootful then rootless in private code. | STATIC REVIEW |
| 45 | Legacy fuzzy public helper invoked externally | Outside migrated main path and still risky; documented for TASK-1.12 rather than silently rewritten here. | STATIC REVIEW |

No row is labeled runtime PASS. Local iOS/Objective-C compilation and device execution were unavailable.

## 26. Full AppDataCleaner.m diff review

The complete file-specific diff was reviewed in full:

```text
AppDataCleaner.m | 693 ++++++++++++++++++++++++++++++++++++++++++++++---------
1 file changed, 589 insertions(+), 104 deletions(-)
numstat: 589  104  AppDataCleaner.m
full diff lines: 826
full diff SHA-256: 21B02978D0975E59E1B165E595BFE3BA0497EB57D435EDFF1B262532E2FF677D
binary marker: false
hunks: 15
```

Hunk review covered: four imports; private declaration/cache replacement; static failure/script/postcondition helpers; request capture; typed result consumption/completion precedence; public wrapper/private root migration; redundant HTTPStorages and main final-sweep removal; result creation; canonical verification cache; cache clearing; and split non-main encrypted-data helper. No unrelated generic implementation was reformatted.

## 27. Source-token gates

| Gate | Result |
|---|---:|
| required imports | 4 |
| public `clearDataForBundleID:completion:` implementations | 1 |
| public `completeAppDataWipe:` implementations | 1 |
| private result declaration / implementation | 1 / 1 |
| deep-clean reads in main entry | 1 |
| ApplicationData request scope in main entry | 1 |
| `PXClearScopeDefaultMask` | 0 |
| ordered root constants | rootful 1 / rootless 1 |
| resolver selector inside root loop | 1 source call, 2 ordered runtime root iterations |
| validator selector | 2 source call sites: pre and post |
| bounded main wipe call | 1 source call inside root loop |
| legacy main resolver calls in private method | 0 |
| raw main UUID path formats in private method | 0 |
| raw container property mutation | 0 |
| `completelyWipeContainer:` main calls | 0 |
| void main wipe command calls | 0 |
| raw UUID cache ivars | 0 |
| canonical cache references | 5 |
| destructive final sweep canonical-cache references | 0 |
| read-only final canonical-cache loop | 1 |
| redundant raw HTTPStorages wipe in private method | 0 |
| receipt tokens | 0 |
| rootless bundle full-wipe token | 0 |
| structured detail path literals | 0 |
| wipe-command logging | 0 |

## 28. Whitespace, NUL and generated/binary audit

| Item | Baseline | Final |
|---|---:|---:|
| `AppDataCleaner.m` bytes | 328,347 | 357,353 |
| lines | 6,388 | 6,873 |
| SHA-256 | `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8` | `4544C460505443929FE986CB914DF8E0DB5B58D5ED8A0D7AC1C6911E074ECACC` |
| CRLF line endings | 6,388 | 6,873 |
| NUL bytes | 0 | 0 |
| legacy trailing-whitespace lines | 633 | 619 |
| newly added diff lines with trailing whitespace | — | 0 |

Fourteen legacy trailing-whitespace lines disappeared only because their containing baseline lines were replaced/deleted; no unrelated formatting sweep occurred. `git diff --check` returned 0. Its stderr contains only LF-to-CRLF warnings for coordinator-owned documentation files. No temporary patch script, generated file, object, archive, image, database, cache or binary artifact remains.

## 29. Local build and runtime status

`clang` and `make` are unavailable in the current Windows workspace, so no local iOS compile, shell execution against a real container, filesystem race test or Objective-C runtime scenario was performed. GitHub Actions is the authoritative build gate; all scenario rows are static review only.

## 30. Remaining risks

1. **Path-based TOCTOU is reduced, not eliminated.** The validator runs immediately before the command, the same container is revalidated after command success, canonical equality is required and a strict read-only postcondition runs. A shell command still acts on a path over time; a hostile privileged filesystem actor could race between individual operations.
2. **Legacy external Clear helpers remain.** Fuzzy/raw methods such as `performFullCleanup:` and `_wipeDataContainersByIdentifierPrefixOrSubstring:` are no longer reachable from the migrated main path but remain externally callable until later quarantine work, especially TASK-1.12.
3. **Standalone verification retains legacy read-only fallback.** This is explicitly permitted for TASK-1.7 but remains fuzzy/UUID-based inspection outside a matching wipe cache.
4. **Extension/App Group/PluginKit remain legacy.** Their selection/mutation semantics are intentionally deferred to TASK-1.8 and later tasks.
5. **Keychain remains unstructured.** Only error precedence was integrated; Keychain does not yet produce a typed component result.
6. **Device behavior is unverified.** Shell glob/chflags behavior, resolver/validator filesystem assumptions, app relaunch races and postcondition timing require GitHub Actions plus device/runtime validation.

## 31. Acceptance checklist

- [x] Only `AppDataCleaner.m` was modified as production source.
- [x] Required TASK-1.7 report exists.
- [x] All four required imports are in `AppDataCleaner.m` only.
- [x] Public Clear selectors and `AppDataCleaner.h` remain unchanged.
- [x] Main entry captures deep-clean intent exactly once.
- [x] Main entry creates an ApplicationData-only request and never uses the default mask.
- [x] Invalid request stops before destructive work and completes failure.
- [x] Public wrapper delegates and logs the private component result.
- [x] Rootful then rootless order is fixed.
- [x] Absent roots are not attempted; every resolver/validation/execution/postcondition failure is one failed attempted unit.
- [x] Both roots continue independently.
- [x] Main selection uses exact resolver only.
- [x] Main mutation uses canonical validator output only.
- [x] One bounded result command is used per validated root.
- [x] Strict script preserves metadata, recreates only Documents/Library/tmp and propagates required operation failures.
- [x] CommandResult truncation is fail-closed.
- [x] Post-command revalidation and exact canonical equality are required.
- [x] Strict read-only postcondition enforces the complete top-level/directory contract.
- [x] One structured ApplicationData component result is returned.
- [x] Failure domain/codes and first-failure policy are stable.
- [x] Legacy completion consumes the component and gives ApplicationData errors precedence.
- [x] Raw UUID cache state is removed and canonical path cache is copied/consumed.
- [x] Main verification/final sweep use canonical cache directly.
- [x] Raw HTTPStorages and second main legacy mutations are removed from the main path.
- [x] All remaining Data/Application literals are classified.
- [x] Extension/App Group/PluginKit/Keychain implementations remain unmigrated.
- [x] TASK-1.4 bundle/receipt gates remain true.
- [x] Generic helper bodies remain checksum-identical.
- [x] All protected files remain checksum-identical.
- [x] Whitespace/NUL/generated/binary checks pass.
- [x] TASK-1.8 was not started.
- [x] Agent stops after TASK-1.7.
- [ ] GitHub Actions succeeds or owner confirms build — PENDING.
- [ ] Coordinator accepts TASK-1.7 — PENDING.

## 32. Final verification addendum

Final repository identity remained stable:

```text
git rev-parse HEAD: 81de2a7ef28f862f78a7ae55f0d8897066a85f94
git log -1 --oneline: 81de2a7 task-1.6
```

Final `git status --short --untracked-files=all`:

```text
 M AppDataCleaner.m
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reports/TASK-1.7-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-1.6-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.7-migrate-main-application-data-clear.md
```

TASK-1.7-owned paths are only `AppDataCleaner.m` and this report. All other status entries are unchanged coordinator-owned baseline.

Final source verification:

```text
required imports: 4
public clearDataForBundleID implementation: 1
public completeAppDataWipe implementation: 1
private result declaration / implementation: 1 / 1
deep-clean reads in main entry: 1
ApplicationData request scope: 1
PXClearScopeDefaultMask: 0
legacy main resolver calls in private method: 0
raw main path formats in private method: 0
raw container property mutation: 0
generic main wipe calls: 0
bounded main wipe call inside root loop: 1
validator pre/post call sites: 2
raw UUID cache ivars: 0
canonical path cache references: 5
read-only final canonical-cache loop: 1
standalone read-only verify fallback: 1
_MASReceipt / ._MASReceipt tokens: 0 / 0
rootless bundle full-wipe token: 0
protected git diff: exit 0
scenario rows: 45 STATIC REVIEW
git diff --check: exit 0
```

Final task-owned file metadata:

```text
AppDataCleaner.m
bytes: 357353
lines: 6873
SHA-256: 4544C460505443929FE986CB914DF8E0DB5B58D5ED8A0D7AC1C6911E074ECACC
CRLF lines: 6873
NUL bytes: 0
legacy trailing-whitespace lines: 619
newly added diff lines with trailing whitespace: 0

TASK-1.7-REPORT.md
bytes: 40597
lines: 653
NUL bytes: 0
trailing-whitespace lines: 0
type: UTF-8 text
```

The complete `AppDataCleaner.m` diff remains 589 insertions and 104 deletions across 15 reviewed hunks, with SHA-256 `21B02978D0975E59E1B165E595BFE3BA0497EB57D435EDFF1B262532E2FF677D`. The report no-index whitespace check returned the expected difference exit 1 with empty stdout/stderr.

`git diff --check` emitted only LF-to-CRLF warnings for pre-existing coordinator-owned documentation. No temporary generator, generated output or binary artifact remains.

Local Objective-C/iOS compilation and runtime testing were not run because `clang` and `make` are unavailable. No runtime PASS is claimed.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
