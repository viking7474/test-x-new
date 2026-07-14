# TASK-2.2 REPORT — Enforce Supported Manifest Versions

## 1. Baseline and initial status

- Required baseline: `e15f101cd70cc782274e42e608bce64d4981a578`
- TASK-2.1 source review: `ACCEPTED` (`docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md`).

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
```

```text
e15f101cd70cc782274e42e608bce64d4981a578
e15f101 phase2(task-2.1): add manifest schema validator
92b051f phase1(task-1.12): quarantine ambiguous legacy clear APIs
17d76c0 phase1(task-1.11): remove unsafe permission and marker behavior
```

Coordinator-owned files listed above were not rewritten, reverted, formatted or staged.

## 2. Exact scope

Production modification:

```text
M AppDataBackupManager.m
```

Required report:

```text
A docs/backup-restore-hardening/reports/TASK-2.2-REPORT.md
```

No other production source is changed.

## 3. Protected SHA-256 before and after

| Protected file | Before | After |
|---|---|---|
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` |
| `PXBackupManifestValidator.m` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` |

Protected working-tree diff result: `PASS (exit 0)`.

## 4. Historical writer evidence

Repository history identifies only two writer literals:

```text
01fabe89102e46bdf9b9de0f290ff1f6505ae907 New backup
+            @"manifestVersion": @2,

c0f264e38f4911be0cca0783cd36e4b6ca1b8add test
-            @"manifestVersion": @2,
+            @"manifestVersion": @3,
```

The current writer remains `@"manifestVersion": @3`. No historical writer literal other than `2` or `3` was found in `AppDataBackupManager.m`.

## 5. Exact closed version policy

```objc
static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
    if (![version isKindOfClass:[NSNumber class]]) {
        return NO;
    }

    NSInteger value = version.integerValue;
    return value == 2 || value == 3;
}
```

| Structurally valid version | Policy result |
|---:|---|
| 1 | unsupported |
| 2 | supported |
| 3 | supported |
| 4 | unsupported |
| 999 | unsupported |

There is no minimum, maximum, range, newest-version fallback, warning-and-continue behavior, or public supported-version API.

## 6. Error policy

| Failure class | Domain/code | Behavior |
|---|---|---|
| Manifest read/non-dictionary | `PXBackupErrorDomain`, `200` | Existing generic `Failed to read manifest` error |
| Schema failure | Exact validator domain/code/path/description | Exact `validationError` object assigned without wrapping |
| Structurally valid unsupported version | `PXBackupErrorDomain`, `201` | Generic `Unsupported backup manifest version` |
| Restore impossible nil-error fallback | `PXBackupErrorDomain`, `302` | Used only if read returns nil without an NSError |

The code-201 error does not interpolate the actual version, manifest, bundle ID, directory, path, UUID or archive.

## 7. Public read boundary

Deterministic order in `readManifestAtBackupDirectory:error:`:

1. Clear `*error` when non-null.
2. Form `<backupDir>/manifest.plist`.
3. Read the dictionary exactly once.
4. Return manager code 200 for read/non-dictionary failure.
5. Call `PXBackupManifestValidator` exactly once.
6. Propagate the exact validator NSError on structural failure.
7. Call `PXBackupManifestVersionIsSupported` exactly once.
8. Return manager code 201 for unsupported positive structural versions.
9. Return the original dictionary object unchanged.

No copy, normalization, unknown-key removal, write, bundle matching, artifact inspection, archive inspection or destination authorization occurs in this method.

## 8. Restore integration and ordering

Restore now calls the public read boundary once at the start of its background block. A nil result dispatches completion once to the main queue and returns immediately. The exact non-nil `manifestError` is propagated; code 302 is only the impossible nil-error fallback.

| Existing Restore action | Static position after accepted read |
|---|---:|
| `warnings initialization` | `776 < 1354` |
| `file manager acquisition` | `776 < 1426` |
| `runner acquisition` | `776 < 1487` |
| `debug path initialization` | `776 < 1546` |
| `debug write` | `776 < 1910` |
| `tar discovery` | `776 < 3592` |
| `target kill` | `776 < 4994` |
| `target resolve helper` | `776 < 2280` |
| `launch services lookup` | `776 < 6559` |
| `artifact verification` | `776 < 12036` |
| `archive extraction` | `776 < 14946` |
| `data wipe` | `776 < 16126` |

Restore method-boundary counts:

```text
readManifestAtBackupDirectory calls: 1
direct dictionaryWithContentsOfFile calls: 0
direct PXBackupManifestValidator calls: 0
direct PXBackupManifestVersionIsSupported calls: 0
```

## 9. Malformed versus unsupported

| Input | Error source/result |
|---|---|
| Missing `manifestVersion` | Validator `MissingRequiredField` |
| `@YES` | Validator `InvalidFieldType` |
| `@1.0` | Validator `InvalidFieldType` |
| `@0` | Validator `InvalidFieldValue` |
| Negative integral | Validator `InvalidFieldValue` |
| Structurally valid `1` | Manager code `201` |
| Structurally valid `2` | Accepted |
| Structurally valid `3` | Accepted |
| Structurally valid `4` | Manager code `201` |
| Structurally valid `999` | Manager code `201` |

Schema validation precedes the policy helper, so malformed numeric values are never mislabeled as unsupported versions.

## 10. Boundary non-regression

- Requested bundle mismatch remains warning-only; its block contains no NSError or return.
- LaunchServices target preference remains.
- Metadata scan fallback remains.
- Manifest `data.containerPath` fallback and warning remain.
- Manifest `data.uuid` fallback and warning remain.
- The four existing root base paths remain.
- Backup writer method remains byte-identical after newline normalization and still writes v3.
- Artifact verification and tar extraction helper bodies remain byte-identical after newline normalization.
- App Group, preferences, Keychain, profile, Safari, global-library and shared-DB Restore behavior is unchanged outside entry ordering.
- No TASK-2.3 requested-bundle enforcement, TASK-2.4 fallback removal, TASK-2.5 artifact redesign, TASK-2.6 archive-entry validator, restore plan, staging redesign or transaction model was added.

Critical unchanged normalized body hashes:

| Body | SHA-256 |
|---|---|
| `createBackupForBundleID:` | `1a056d4513dea76d735fe5bd34d48d0addc1409b0c528131f654fc5abe312e13` |
| `PXVerifyArtifact` | `fb254b96522e8183ae76c9fbfb2105d944a3b51b38c9edb27d44159e93632794` |
| `_tarExtract:` | `56cce1465073ce616d67462a54942e7ee4453f96f88cd9ae5e4e08f6a177b998` |
| `_tarExtractDataArchive:` | `20812f4ad4b97bec0872deefe21ed1ec3faf33d46f84e2967a714b0e2bb10d52` |

## 11. Static gates

- Machine-readable gate suite: **70/70 PASS**.

| Gate | Count/result |
|---|---:|
| Validator import in manager | 1 |
| Version helper definitions | 1 |
| Exact supported values | 2 and 3 only |
| Minimum/range policy | 0 |
| Unsupported manager code | 201 present |
| read-boundary validator calls | 1 |
| read-boundary helper calls | 1 |
| Restore public read calls | 1 |
| Restore direct manifest dictionary loads | 0 |
| Restore direct validator/helper calls | 0 |
| UI/controller validator references | 0 |
| AppDataBackupManager.h diff | 0 |
| Validator source diff | 0 |
| Makefile diff | 0 |
| PXRestorePlan additions | 0 |
| Archive-entry validator additions | 0 |

## 12. Complete source diff

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index b1b4230..1eff5ec 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -9,6 +9,7 @@

 #import "AppEntitlementsReader.h"
 #import "AppGroupContainerResolver.h"
+#import "PXBackupManifestValidator.h"
 #import "CommandRunner.h"
 #import "common/PXProcessKiller.h"
 #import "common/PXPaths.h"
@@ -18,6 +19,15 @@

 static NSString * const PXBackupErrorDomain = @"com.hydra.projectx.backup";

+static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
+    if (![version isKindOfClass:[NSNumber class]]) {
+        return NO;
+    }
+
+    NSInteger value = version.integerValue;
+    return value == 2 || value == 3;
+}
+
 @implementation PXBackupResult
 @end

@@ -1098,6 +1108,10 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

 - (NSDictionary *)readManifestAtBackupDirectory:(NSString *)backupDir
                                           error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
     NSString *manifest = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
     NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:manifest];
     if (![dict isKindOfClass:[NSDictionary class]]) {
@@ -1108,6 +1122,25 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }
         return nil;
     }
+
+    NSError *validationError = nil;
+    if (![PXBackupManifestValidator validateManifestObject:dict error:&validationError]) {
+        if (error) {
+            *error = validationError;
+        }
+        return nil;
+    }
+
+    NSNumber *manifestVersion = dict[@"manifestVersion"];
+    if (!PXBackupManifestVersionIsSupported(manifestVersion)) {
+        if (error) {
+            *error = [NSError errorWithDomain:PXBackupErrorDomain
+                                         code:201
+                                     userInfo:@{NSLocalizedDescriptionKey: @"Unsupported backup manifest version"}];
+        }
+        return nil;
+    }
+
     return dict;
 }

@@ -1721,6 +1754,17 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     }

     dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
+        NSError *manifestError = nil;
+        NSDictionary *manifest =
+            [self readManifestAtBackupDirectory:backupDir
+                                              error:&manifestError];
+        if (!manifest) {
+            NSError *err = manifestError ?: [NSError errorWithDomain:PXBackupErrorDomain
+                                                                  code:302
+                                                              userInfo:@{NSLocalizedDescriptionKey: @"Manifest missing or invalid"}];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
         NSMutableArray<NSString *> *warnings = [NSMutableArray array];
         NSFileManager *fm = [NSFileManager defaultManager];
         CommandRunner *runner = [CommandRunner shared];
@@ -1775,15 +1819,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"tarPath=%@", tarPath]);

-        NSString *manifestPath = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
-        NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
-        if (![manifest isKindOfClass:[NSDictionary class]]) {
-            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                               code:302
-                                           userInfo:@{NSLocalizedDescriptionKey: @"Manifest missing or invalid"}];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-            return;
-        }
         if ([manifest[@"warnings"] isKindOfClass:[NSArray class]] && [(NSArray *)manifest[@"warnings"] count] > 0) {
             [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)[(NSArray *)manifest[@"warnings"] count]]];
         }
```

## 13. Scenario matrix

Scenario count: **70**. All rows are static source/contract review cases; no row claims an Objective-C runtime or device execution.

| # | Scenario | Static evidence/result | Status |
|---:|---|---|---|
| 1 | nil/empty backup directory | The existing path append/read fails closed through manager code 200; no new special-case or mutation was added. | PASS |
| 2 | missing manifest file | The single dictionary read returns no dictionary and read boundary returns PXBackupErrorDomain code 200. | PASS |
| 3 | malformed/non-dictionary plist | The runtime NSDictionary check fails before validator/version policy; code 200 is returned. | PASS |
| 4 | structurally invalid root | Validator is called once and its exact NSError is assigned to the caller error pointer. | PASS |
| 5 | missing manifestVersion | Validator runs before version helper, so MissingRequiredField remains a validator error. | PASS |
| 6 | Boolean version | Validator exact numeric rules run first; helper is not reached for @YES. | PASS |
| 7 | floating version | Validator runs before helper and rejects floating numeric representation. | PASS |
| 8 | zero version | Validator InvalidFieldValue occurs before supported-set policy. | PASS |
| 9 | negative version | Validator InvalidFieldValue occurs before supported-set policy. | PASS |
| 10 | structurally valid version 1 | Exact helper expression value == 2 || value == 3 rejects it with manager code 201. | PASS |
| 11 | structurally valid version 2 | Exact helper expression accepts 2. | PASS |
| 12 | structurally valid version 3 | Exact helper expression accepts 3. | PASS |
| 13 | structurally valid version 4 | Exact helper rejects 4 with manager code 201. | PASS |
| 14 | structurally valid version 999 | Exact helper rejects 999 with manager code 201. | PASS |
| 15 | valid v2 common envelope | Validator acceptance followed by exact version helper permits v2. | PASS |
| 16 | valid current v3 manifest | Current writer remains @3 and read boundary permits v3. | PASS |
| 17 | future unknown graph-safe field on v3 | Validator unknown-field policy remains untouched and read returns original dictionary. | PASS |
| 18 | validator error field path preserved | The exact validationError object is assigned without wrapping. | PASS |
| 19 | error pointer pre-populated before success | *error is cleared at method entry and success does not set it again. | PASS |
| 20 | error pointer pre-populated before failure | *error is cleared first, then replaced by code 200, exact validator error, or code 201. | PASS |
| 21 | null error pointer | All manager assignments are guarded; local validationError still supports correct return behavior. | PASS |
| 22 | returned dictionary identity/content unchanged | Method returns dict directly; no mutableCopy, normalization, key removal or write exists in the body. | PASS |
| 23 | unsupported rejected before tar lookup | Restore read call position precedes tarPath discovery. | PASS |
| 24 | unsupported rejected before debug file write | Restore read call precedes debug path initialization and PXDebugHeader/PXDebugAppendLine. | PASS |
| 25 | unsupported rejected before process kill | Restore read call precedes _killRelatedProcessesForBundleID:. | PASS |
| 26 | unsupported rejected before target resolution | Restore read call precedes PXResolvePathsForBundleID, LaunchServices and metadata scan. | PASS |
| 27 | unsupported rejected before artifact verification | Restore read call precedes PXVerifyArtifact. | PASS |
| 28 | unsupported rejected before extraction | Restore read call precedes _tarExtractDataArchive:. | PASS |
| 29 | structural validator error propagated unchanged | Restore propagates manifestError returned by the public read boundary. | PASS |
| 30 | unsupported manager error propagated unchanged | Restore uses manifestError directly; fallback code 302 is only nil-error impossible state. | PASS |
| 31 | completion once on main queue | Preflight failure block contains one main-queue dispatch and one completion call, followed by return. | PASS |
| 32 | v2 proceeds into existing Restore flow | Version 2 passes closed-set helper; all post-acceptance Restore code remains. | PASS |
| 33 | v3 proceeds into existing Restore flow | Version 3 passes closed-set helper; all post-acceptance Restore code remains. | PASS |
| 34 | Restore direct manifest dictionary load removed | Method-boundary count of dictionaryWithContentsOfFile is zero. | PASS |
| 35 | Restore duplicate validator call absent | Method-boundary PXBackupManifestValidator reference count is zero. | PASS |
| 36 | Restore duplicate version policy absent | Method-boundary PXBackupManifestVersionIsSupported reference count is zero. | PASS |
| 37 | bundle mismatch warning-only | Exact warning string remains and mismatch block has no NSError or return. | PASS |
| 38 | matching bundle normal | No new equality rejection was added; warning condition remains mismatch-only. | PASS |
| 39 | manifest containerPath fallback remains | Exact fallback field access and warning string remain. | PASS |
| 40 | manifest UUID fallback remains | Exact manifestDataUUID fallback loop and warning remain. | PASS |
| 41 | LaunchServices path preference remains | Existing LaunchServices lookup and preference comment remain. | PASS |
| 42 | metadata scan fallback remains | PXFindDataContainerUUIDByMetadata loop remains. | PASS |
| 43 | artifact verifier unchanged | PXVerifyArtifact normalized body hash matches baseline. | PASS |
| 44 | archive extraction unchanged | _tarExtract: normalized body hash matches baseline. | PASS |
| 45 | App Group restore unchanged | Only Restore entry/read block changed; downstream group restore diff is zero. | PASS |
| 46 | preferences restore unchanged | Downstream preference restore diff is zero. | PASS |
| 47 | Keychain restore unchanged | Downstream Keychain restore diff is zero. | PASS |
| 48 | optional/global restore unchanged | Profile, Safari, system-global and shared-DB restore code is outside changed hunks. | PASS |
| 49 | Backup writer stays version 3 | createBackupForBundleID: body is byte-identical after newline normalization and contains one @3 writer. | PASS |
| 50 | validator source byte-identical | Protected diff for PXBackupManifestValidator.h/.m is zero. | PASS |
| 51 | manager public header byte-identical | Protected diff and SHA-256 for AppDataBackupManager.h are unchanged. | PASS |
| 52 | UI callers byte-identical | Protected diff is zero and UI/controller validator reference count is zero. | PASS |
| 53 | no TASK-2.3 bundle enforcement | No requested/expected bundle argument was added to validator or read method. | PASS |
| 54 | no TASK-2.4 fallback removal | Both recorded containerPath and UUID fallback paths remain. | PASS |
| 55 | no TASK-2.5 artifact redesign | Artifact verifier body hash is unchanged. | PASS |
| 56 | no TASK-2.6 archive validator | No archive-entry validator/listing token was added. | PASS |
| 57 | no restore plan/staging/transaction redesign | No PXRestorePlan symbol or new Phase-2 planning model exists. | PASS |
| 58 | exact production scope | Only AppDataBackupManager.m is changed in production. | PASS |
| 59 | protected checksums unchanged | All protected SHA-256 values match the baseline capture. | PASS |
| 60 | git diff --check | Pre-report source diff check returns zero. | PASS |
| 61 | cumulative diff check | Baseline-to-working diff check passes and is repeated against HEAD after commit. | PASS |
| 62 | no NUL/generated/binary files | Source NUL count is zero; temporary audit scripts are removed before staging. | PASS |
| 63 | GitHub Actions result honest | No CI run is claimed; required report tail records PENDING. | PASS |
| 64 | validator import count | Exactly one manager import and zero UI/controller imports. | PASS |
| 65 | helper definition count | Exactly one private file-local definition. | PASS |
| 66 | read validator/helper counts | Exactly one validator call and one helper call in read method. | PASS |
| 67 | unsupported error privacy | Code 201 uses one fixed generic description and no formatted/raw value. | PASS |
| 68 | read failure behavior retained | Non-dictionary read continues to use PXBackupErrorDomain code 200 and generic message. | PASS |
| 69 | historical v2/v3 proof | 01fabe8 introduced @2; c0f264e changed @2 to @3; history contains no other writer literal. | PASS |
| 70 | local build honesty | No local Objective-C build is claimed because clang/make/xcrun are unavailable. | PASS |

## 14. Whitespace, line endings, NUL and generated audit

```text
AppDataBackupManager.m bytes: 127022
AppDataBackupManager.m lines: 2418
AppDataBackupManager.m CRLF lines: 2418
AppDataBackupManager.m NUL bytes: 0
Added-line trailing whitespace: 0
git diff --check: PASS
Temporary .task22* audit files: removed before staging
Binary/generated production artifacts: 0
```

## 15. Build status and remaining risks

Local Objective-C/Theos build was not run because the Windows workspace lacks: `clang`, `clang-cl`, `make`, `xcrun`.

Source review and static gates cannot prove runtime Foundation plist loading, NSError object identity as observed by all callers, main-queue callback timing, or device Restore behavior. Device/CI validation should cover valid v2/v3 manifests, malformed versions, unsupported 1/4/999 manifests, and ensure unsupported rejection occurs before any debug file or target-side action.

TASK-2.3 requested-bundle identity enforcement remains out of scope and was not implemented.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
