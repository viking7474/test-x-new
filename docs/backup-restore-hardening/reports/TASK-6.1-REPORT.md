# TASK-6.1 REPORT — Reduce Destructive Public API Surface

## 1. Result

**STATIC IMPLEMENTATION PASS.** Exactly 18 destructive/quarantined declarations were removed from the public header and relocated into the existing anonymous class extension. All Objective-C implementations and the protected behavior suffix remain byte-identical.

No TASK-6.2 work was started. No push was performed.

## 2. User authority

The user explicitly invoked the repository tool and supplied the TASK-6.1 specification. This authority opens TASK-6.1 only.

## 3. TASK-5.4 review-file status

`docs/backup-restore-hardening/reviews/TASK-5.4-REVIEW.md` does not exist, matching the specification. User authority explicitly makes that absence non-blocking for TASK-6.1.

## 4. Baseline

- Required and actual HEAD: `6174f2e4ff4d297123b109d27fa03dd6f24b066c`
- `6174f2e phase5(task-5.4): confirm advanced backup restore scopes`

## 5. Working-tree preservation

- `docs/backup-restore-hardening/DECISIONS.md` — `601194d5abfa2fade0e0a6c63a213c733618799bbfae0972ccdd641a0975bbe6` — PRESERVED / NOT STAGED
- `docs/backup-restore-hardening/README.md` — `8a09213977c03f946a206c46cdd28c27a718b0dba017d3c7f7e425e6d0403172` — PRESERVED / NOT STAGED
- `docs/backup-restore-hardening/ROADMAP.md` — `ceccb3ddda2ff901d30f06e74d7102484f0fd2af9281923063e1b6a84371c07e` — PRESERVED / NOT STAGED
- `docs/backup-restore-hardening/STATUS.md` — `1007d679213e55edb01e1671cb607a1ad9daf22d44ee4d9fb554d00d2eeaf82b` — PRESERVED / NOT STAGED

## 6. Exact authorized scope

- `M AppDataCleaner.h`
- `M AppDataCleaner.m`
- `A docs/backup-restore-hardening/reports/TASK-6.1-REPORT.md`

No caller, Makefile, coordinator document, review file, Backup/Restore source, Keychain source, category, or production header was modified or added.

## 7. TASK-1.12 accepted quarantine contract

The accepted 33-shim non-mutating compatibility contract remains intact. Only source visibility changed for the exact 18 selectors; runtime definitions remain.

## 8. Public versus runtime API distinction

| Property | Result |
|---|---|
| Public source declarations | removed for exact 18 |
| Private compile declarations | one each |
| Objective-C definitions | one each |
| Runtime selector signatures | unchanged |
| Existing binary ABI | statically retained |
| Runtime execution | DEVICE PENDING |

## 9. Public declaration inventory

| Metric | Count |
|---|---:|
| Baseline public instance methods | 74 |
| Removed | 18 |
| Final public instance methods | 56 |

## 10. Declaration/definition matrix

| Selector | Public | Private | Definition | Return | Args |
|---|---:|---:|---:|---|---:|
| `performFullCleanup:` | 0 | 1 | 1 | `void` | 1 |
| `performAggressiveCleanupFor:` | 0 | 1 | 1 | `void` | 1 |
| `completelyWipeContainer:` | 0 | 1 | 1 | `void` | 1 |
| `securelyWipeFile:` | 0 | 1 | 1 | `BOOL` | 1 |
| `fixPermissionsAndRemovePath:` | 0 | 1 | 1 | `void` | 1 |
| `fixPermissionsForPath:` | 0 | 1 | 1 | `void` | 1 |
| `clearAppCache:` | 0 | 1 | 1 | `void` | 1 |
| `clearAppPreferences:` | 0 | 1 | 1 | `void` | 1 |
| `clearAppCookies:` | 0 | 1 | 1 | `void` | 1 |
| `clearAppWebKitData:` | 0 | 1 | 1 | `void` | 1 |
| `clearAppGroupData:` | 0 | 1 | 1 | `void` | 1 |
| `clearPluginKitData:` | 0 | 1 | 1 | `void` | 1 |
| `_internalClearEncryptedData:` | 0 | 1 | 1 | `void` | 1 |
| `secureDataWipe:` | 0 | 1 | 1 | `void` | 1 |
| `clearAppKeychain:` | 0 | 1 | 1 | `void` | 1 |
| `clearKeychainData:` | 0 | 1 | 1 | `void` | 1 |
| `clearKeychainItemsForBundleID:` | 0 | 1 | 1 | `void` | 1 |
| `universalKeychainWipeForBundleID:` | 0 | 1 | 1 | `void` | 1 |

## 11. Exact header deletion proof

- Bytes `3832`; SHA-256 `e8cd18e33519b27061c763bf6308ec4111aa1ea5d92948e7ce2ce59207edae9e`; CRLF `98`; LF-only `0`; NUL `0`; final newline absent; trailing `@end ` preserved.
- Diff: exactly 18 deletions and zero additions.

## 12. Private relocation and source hash proof

- Full source: `371422` bytes / `de5a4d8e9215faf8a5a64781af6e9ff082c27998c6ceff70c1cfe0d81aa54fee` / CRLF `6995`.
- Prefix: `1078` bytes / `1d5b1267fa7664af72739a1054427443332f51b0a68e73681176a15a7a2ae7cb`.
- Extension: `4456` bytes / `2a9491f030b11e97dca50fcda5ac6bd3122770a761027055b65e8b388164eeda`.
- Suffix: `365888` bytes / `62f3f2c91ca16f6346d9cc3d24920186d4862c22469bf1e99a53624bcb38b069`.
- Source diff is one blank line plus 18 declarations, with no deletion and no changed line after the first class-extension `@end`.

## 13. External caller inventory

All target selectors have zero production callers outside `AppDataCleaner.h/.m`.

| Selector | Calls |
|---|---:|
| `performFullCleanup:` | 0 |
| `performAggressiveCleanupFor:` | 0 |
| `completelyWipeContainer:` | 0 |
| `securelyWipeFile:` | 0 |
| `fixPermissionsAndRemovePath:` | 0 |
| `fixPermissionsForPath:` | 0 |
| `clearAppCache:` | 0 |
| `clearAppPreferences:` | 0 |
| `clearAppCookies:` | 0 |
| `clearAppWebKitData:` | 0 |
| `clearAppGroupData:` | 0 |
| `clearPluginKitData:` | 0 |
| `_internalClearEncryptedData:` | 0 |
| `secureDataWipe:` | 0 |
| `clearAppKeychain:` | 0 |
| `clearKeychainData:` | 0 |
| `clearKeychainItemsForBundleID:` | 0 |
| `universalKeychainWipeForBundleID:` | 0 |

## 14. Internal caller inventory

There are 17 actual Objective-C message sends. The specification’s 18-reference convention counts `securelyWipeFile:` as 13 references (12 sends plus its definition), plus one send for each of five other selectors. No call site changed.

| Selector | Sends | Task inventory |
|---|---:|---:|
| `performFullCleanup:` | 0 | 0 |
| `performAggressiveCleanupFor:` | 0 | 0 |
| `completelyWipeContainer:` | 0 | 0 |
| `securelyWipeFile:` | 12 | 13 |
| `fixPermissionsAndRemovePath:` | 1 | 1 |
| `fixPermissionsForPath:` | 0 | 0 |
| `clearAppCache:` | 0 | 0 |
| `clearAppPreferences:` | 1 | 1 |
| `clearAppCookies:` | 0 | 0 |
| `clearAppWebKitData:` | 1 | 1 |
| `clearAppGroupData:` | 1 | 1 |
| `clearPluginKitData:` | 0 | 0 |
| `_internalClearEncryptedData:` | 1 | 1 |
| `secureDataWipe:` | 0 | 0 |
| `clearAppKeychain:` | 0 | 0 |
| `clearKeychainData:` | 0 | 0 |
| `clearKeychainItemsForBundleID:` | 0 | 0 |
| `universalKeychainWipeForBundleID:` | 0 | 0 |

## 15. ABI and runtime behavior preservation

- Each selector retains one instance-method implementation with unchanged spelling, return type, argument count, and method kind.
- Exact suffix equality proves implementation bodies and behavior were not changed.
- `instancesRespondToSelector:` and old-binary messaging remain DEVICE PENDING because no runtime harness was available.

## 16. 33-shim and logger privacy proof

- Shim definitions `33`; logger definitions `1`; logger calls `33`.
- Every shim invokes `PXLogQuarantinedLegacyClearSelector(_cmd);` once. Logger input remains `SEL` only; no sensitive argument logging was added.

## 17. `securelyWipeFile:` fail-closed proof

- Body SHA-256 `54ccc0cca4ca5dd821aa5c167ffe93bba901e2b1d6b57e8f6be9f5bfe2d61c82`; one logger call; `return NO;` present; no inspection or mutation added.

## 18. Typed Clear and compatibility body hashes

| Body | Bytes | SHA-256 |
|---|---:|---|
| `clearDataForBundleID:completion:` | 15419 | `25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1` |
| `completeAppDataWipe:` | 1182 | `204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644` |
| `clearAppData:` | 46 | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` |
| `performSecondaryCleanup:` | 46 | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` |
| `_wipeMobileSafariSystemStores` | 14098 | `077ed7ea110e0fde1ed40f2fa852803159eaa7f9d1493c34af377ab3408636bc` |

These hashes protect five-scope Clear, four-scope data-only compatibility, resolver/validator order, canonical paths, Keychain plan/two-pass accounting, callback precedence, one-shot completion, watchdog/background-task ownership, and final verification.

## 19. Retained public API and canonical callers

- `+ (instancetype)sharedManager;` — exactly once
- `- (void)clearDataForBundleID:(NSString *)bundleID` — exactly once
- `- (BOOL)hasDataToClear:(NSString *)bundleID;` — exactly once
- `- (void)completeAppDataWipe:(NSString *)bundleID;` — exactly once
- `- (void)performSecondaryCleanup:(NSString *)bundleID;` — exactly once
- `- (void)clearAppData:(NSString *)bundleID;` — exactly once
- `- (BOOL)verifyDataCleared:(NSString *)bundleID;` — exactly once
- `- (NSString *)findBundleContainerUUIDForBundleID:(NSString *)bundleID;` — exactly once

| Canonical method | Calls |
|---|---:|
| `clearDataForBundleID:` | 5 |
| `hasDataToClear:` | 2 |
| `verifyDataCleared:` | 1 |
| `findBundleContainerUUIDForBundleID:` | 1 |
- `clearDataForBundleID:` → `main.m:537:[cleaner clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) {`
- `clearDataForBundleID:` → `ProjectXViewController.m:3924:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) {`
- `clearDataForBundleID:` → `ProjectXViewController.m:6446:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) {`
- `clearDataForBundleID:` → `ProjectXViewController.m:6632:[[AppDataCleaner sharedManager] clearDataForBundleID:manifestBundleID completion:^(BOOL clearSuccess, NSError *clearError) {`
- `clearDataForBundleID:` → `ProjectXViewController.m:6697:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) {`
- `hasDataToClear:` → `main.m:533:if ([cleaner hasDataToClear:bundleID]) {`
- `hasDataToClear:` → `ProjectXViewController.m:3749:foundData = [[AppDataCleaner sharedManager] hasDataToClear:bundleID];`
- `verifyDataCleared:` → `main.m:545:[cleaner verifyDataCleared:bundleID];`
- `findBundleContainerUUIDForBundleID:` → `AppEntitlementsReader.m:201:NSString *bundleUUID = [cleaner findBundleContainerUUIDForBundleID:bundleID];`

## 20. TASK-6.2 boundary

No deprecation/unavailable annotation, alias migration, caller migration, selector rename, implementation deletion, public category/header, compatibility macro, or replacement documentation was introduced. TASK-6.2 was not started.

## 21. Protected hashes

| File | SHA-256 |
|---|---|
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` |
| `AppDataBackupManager.m` | `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028` |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` |
| `AppDataBackupRestoreViewController.m` | `23c964fac0189119c500665a700fe1fb7dafa77fd63779dccaa9e084cefa26c5` |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` |
| `Makefile` | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` |
| `docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md` | `a7b2ffe36ba3c6682a4ea160e82486b87243ec4bd614e0f6655dcd17946efb33` |
| `docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md` | `9e9c817976947d06e289559e1bc15d6959f98d713983407c329d48b6935ec565` |
| `docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md` | `a668acd27522275a1c5580bb48d99b5a569879a2aa5f953e2289d46913ff5903` |
| `docs/backup-restore-hardening/reports/TASK-5.4-REPORT.md` | `8c40fca455c3e0973d5ef20f770777f2e439e551d0cd195b10c5720f46228e19` |

## 22. TASK-5.1–5.4 report protection

| Report | SHA-256 | Result |
|---|---|---|
| `docs/backup-restore-hardening/reports/TASK-5.1-REPORT.md` | `736d6a38719daf7c9384cca8f728b0ed7078e65f1ba935c5cb32cc34914e4fd6` | byte-identical to baseline |
| `docs/backup-restore-hardening/reports/TASK-5.2-REPORT.md` | `b5c76629dbe35ac81fd7081a1195ddeda77cef7fe1d6ce424f5cbdd5ab84202c` | byte-identical to baseline |
| `docs/backup-restore-hardening/reports/TASK-5.3-REPORT.md` | `8bf6b4cc86521f9cb0ea8e1a38e9cf6f619fa3e377dd137396fa055b066154a8` | byte-identical to baseline |
| `docs/backup-restore-hardening/reports/TASK-5.4-REPORT.md` | `8c40fca455c3e0973d5ef20f770777f2e439e551d0cd195b10c5720f46228e19` | byte-identical to baseline |

## 23. Static source gates

| Gate | Result |
|---|---|
| Balanced parentheses/brackets/braces | PASS |
| Header declarations | 56 / target 0 |
| Private declarations | 18 |
| Definitions | 18 |
| External target callers | 0 |
| Internal sends | 17 actual / 18 task convention |
| Expected file hashes | PASS |
| Prefix/extension/suffix | PASS |
| 33 shims / logger calls | PASS |
| Conflict markers / NUL | 0 / 0 |
| C0 controls | none except tab/newline/CR |
| New deprecation/unavailable | 0 |
| New category/header | 0 |
| Selector rename/removal | 0 / 0 |
| git diff --check | PASS |

## 24. Objective-C/toolchain status

- Windows deterministic declaration, definition, caller, body-hash, encoding, and diff gates: PASS.
- Apple Clang/Theos `make clean`, `make`, `make package`: NOT RUN; Apple/Theos is unavailable on this Windows workspace. No Apple PASS is claimed.

## 25. Device/runtime status

- Device/runtime harness unavailable. Selector response, old-binary messaging, shim logging/non-mutation, retained APIs, typed Clear, and Backup/Restore runtime checks are DEVICE PENDING.

## 26. Full authorized production diff

```diff
diff --git a/AppDataCleaner.h b/AppDataCleaner.h
index dc7fac9..8452694 100644
--- a/AppDataCleaner.h
+++ b/AppDataCleaner.h
@@ -15,13 +15,10 @@

 #pragma mark - Comprehensive Cleanup Methods

-- (void)performFullCleanup:(NSString *)bundleID;
 - (void)performSecondaryCleanup:(NSString *)bundleID;
-- (void)performAggressiveCleanupFor:(NSString *)bundleID;
 - (void)completeAppDataWipe:(NSString *)bundleID;

 #pragma mark - Enhanced Container Cleaning
-- (void)completelyWipeContainer:(NSString *)containerPath;
 - (void)cleanIconStatePlist:(NSString *)bundleID;
 - (void)cleanSiriAnalyticsDatabase:(NSString *)bundleID;
 - (void)cleanLaunchServicesDatabase:(NSString *)bundleID;
@@ -29,16 +26,9 @@

 #pragma mark - Standard App Data Cleaning
 - (void)clearAppData:(NSString *)bundleID;
-- (void)clearAppCache:(NSString *)bundleID;
-- (void)clearAppPreferences:(NSString *)bundleID;
-- (void)clearAppCookies:(NSString *)bundleID;
-- (void)clearAppWebKitData:(NSString *)bundleID;
-- (void)clearAppKeychain:(NSString *)bundleID;
-- (void)clearAppGroupData:(NSString *)bundleID;
 - (void)clearAppReceiptData:(NSString *)bundleID withBundleUUID:(NSString *)bundleUUID;

 #pragma mark - System Storage Cleaning
-- (void)clearKeychainData:(NSString *)bundleID;
 - (void)clearSharedContainers:(NSString *)bundleID;
 - (void)clearUserDefaults:(NSString *)bundleID;
 - (void)clearSQLiteDatabases:(NSString *)bundleID;
@@ -75,7 +65,6 @@
 - (void)clearBinaryPlists:(NSString *)bundleID;
 - (void)clearEncryptedData:(NSString *)bundleID;
 - (void)clearJailbreakDetectionLogs:(NSString *)bundleID;
-- (void)clearPluginKitData:(NSString *)bundleID;
 - (void)clearURLCredentialsForBundleID:(NSString *)bundleID;
 - (void)clearSpotlightIndexes:(NSString *)bundleID;

@@ -95,17 +84,10 @@
 - (void)clearSharedStorage:(NSString *)bundleID;
 - (void)clearAppStateData:(NSString *)bundleID;
 - (void)_internalClearAppStateData:(NSString *)bundleID;
-- (void)_internalClearEncryptedData:(NSString *)bundleID;

 #pragma mark - Security Methods
-- (BOOL)securelyWipeFile:(NSString *)path;
-- (void)secureDataWipe:(NSString *)bundleID;
 - (BOOL)verifyDataCleared:(NSString *)bundleID;
 - (NSDictionary *)getDataUsage:(NSString *)bundleID;
-- (void)fixPermissionsAndRemovePath:(NSString *)path;
-- (void)fixPermissionsForPath:(NSString *)path;
-- (void)clearKeychainItemsForBundleID:(NSString *)bundleID;
-- (void)universalKeychainWipeForBundleID:(NSString *)bundleID;

 #pragma mark - Container Discovery Methods
 - (NSString *)findDataContainerUUIDForBundleID:(NSString *)bundleID;
diff --git a/AppDataCleaner.m b/AppDataCleaner.m
index 23f5bc5..c645983 100644
--- a/AppDataCleaner.m
+++ b/AppDataCleaner.m
@@ -69,6 +69,25 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
                                           error:(NSError **)error;
 - (PXClearComponentResult *)_keychainComponentForPlan:(PXKeychainClearPlan *)plan
                                           passResults:(NSArray<NSNumber *> *)passResults;
+
+- (void)performFullCleanup:(NSString *)bundleID;
+- (void)performAggressiveCleanupFor:(NSString *)bundleID;
+- (void)completelyWipeContainer:(NSString *)containerPath;
+- (BOOL)securelyWipeFile:(NSString *)path;
+- (void)fixPermissionsAndRemovePath:(NSString *)path;
+- (void)fixPermissionsForPath:(NSString *)path;
+- (void)clearAppCache:(NSString *)bundleID;
+- (void)clearAppPreferences:(NSString *)bundleID;
+- (void)clearAppCookies:(NSString *)bundleID;
+- (void)clearAppWebKitData:(NSString *)bundleID;
+- (void)clearAppGroupData:(NSString *)bundleID;
+- (void)clearPluginKitData:(NSString *)bundleID;
+- (void)_internalClearEncryptedData:(NSString *)bundleID;
+- (void)secureDataWipe:(NSString *)bundleID;
+- (void)clearAppKeychain:(NSString *)bundleID;
+- (void)clearKeychainData:(NSString *)bundleID;
+- (void)clearKeychainItemsForBundleID:(NSString *)bundleID;
+- (void)universalKeychainWipeForBundleID:(NSString *)bundleID;
 @end

 @interface PXKeychainClearPlan : NSObject {
```

## 27. Line endings and NUL audit

| File | Endings | Final newline | NUL |
|---|---|---|---:|
| `AppDataCleaner.h` | UTF-8 CRLF 98 | absent; `@end ` retained | 0 |
| `AppDataCleaner.m` | UTF-8 CRLF 6995 | present | 0 |
| `TASK-6.1-REPORT.md` | UTF-8 LF | present | 0 |

## 28. Residual compatibility risks

- New source can no longer compile against the 18 removed public declarations; this is intentional.
- Existing binaries can still message retained implementations, but device confirmation is pending.
- Internal legacy sends remain unchanged and continue to reach non-mutating shims.
- No Apple, device, or GitHub Actions result is fabricated.

## 29. Explicit numbered scenarios

| # | Scenario | Status | Evidence |
|---:|---|---|---|
| 001 | Baseline HEAD | **STATIC PASS** | 6174f2e4ff4d297123b109d27fa03dd6f24b066c |
| 002 | TASK-6.1 only | **STATIC PASS** | TASK-6.2 stopped |
| 003 | Authorized scope | **STATIC PASS** | exact three files |
| 004 | Coordinator docs | **STATIC PASS** | not staged |
| 005 | TASK-5.4 review status | **STATIC PASS** | absent and non-blocking |
| 006 | Makefile | **STATIC PASS** | unchanged |
| 007 | Caller files | **STATIC PASS** | unchanged |
| 008 | No push | **STATIC PASS** | not performed |
| 009 | Header count | **STATIC PASS** | 74 -> 56 |
| 010 | Report path | **STATIC PASS** | docs/backup-restore-hardening/reports/TASK-6.1-REPORT.md |
| 011 | Baseline target inventory: performFullCleanup: | **STATIC PASS** | authorized exact selector |
| 012 | Public absence: performFullCleanup: | **STATIC PASS** | count 0 |
| 013 | Private declaration: performFullCleanup: | **STATIC PASS** | count 1 |
| 014 | Implementation definition: performFullCleanup: | **STATIC PASS** | count 1 |
| 015 | Selector spelling: performFullCleanup: | **STATIC PASS** | performFullCleanup: |
| 016 | Return type: performFullCleanup: | **STATIC PASS** | void |
| 017 | Argument count: performFullCleanup: | **STATIC PASS** | 1 |
| 018 | External caller search: performFullCleanup: | **STATIC PASS** | 0 |
| 019 | New-source public visibility: performFullCleanup: | **STATIC PASS** | declaration absent |
| 020 | Runtime selector expectation: performFullCleanup: | **DEVICE PENDING** | definition retained |
| 021 | Baseline target inventory: performAggressiveCleanupFor: | **STATIC PASS** | authorized exact selector |
| 022 | Public absence: performAggressiveCleanupFor: | **STATIC PASS** | count 0 |
| 023 | Private declaration: performAggressiveCleanupFor: | **STATIC PASS** | count 1 |
| 024 | Implementation definition: performAggressiveCleanupFor: | **STATIC PASS** | count 1 |
| 025 | Selector spelling: performAggressiveCleanupFor: | **STATIC PASS** | performAggressiveCleanupFor: |
| 026 | Return type: performAggressiveCleanupFor: | **STATIC PASS** | void |
| 027 | Argument count: performAggressiveCleanupFor: | **STATIC PASS** | 1 |
| 028 | External caller search: performAggressiveCleanupFor: | **STATIC PASS** | 0 |
| 029 | New-source public visibility: performAggressiveCleanupFor: | **STATIC PASS** | declaration absent |
| 030 | Runtime selector expectation: performAggressiveCleanupFor: | **DEVICE PENDING** | definition retained |
| 031 | Baseline target inventory: completelyWipeContainer: | **STATIC PASS** | authorized exact selector |
| 032 | Public absence: completelyWipeContainer: | **STATIC PASS** | count 0 |
| 033 | Private declaration: completelyWipeContainer: | **STATIC PASS** | count 1 |
| 034 | Implementation definition: completelyWipeContainer: | **STATIC PASS** | count 1 |
| 035 | Selector spelling: completelyWipeContainer: | **STATIC PASS** | completelyWipeContainer: |
| 036 | Return type: completelyWipeContainer: | **STATIC PASS** | void |
| 037 | Argument count: completelyWipeContainer: | **STATIC PASS** | 1 |
| 038 | External caller search: completelyWipeContainer: | **STATIC PASS** | 0 |
| 039 | New-source public visibility: completelyWipeContainer: | **STATIC PASS** | declaration absent |
| 040 | Runtime selector expectation: completelyWipeContainer: | **DEVICE PENDING** | definition retained |
| 041 | Baseline target inventory: securelyWipeFile: | **STATIC PASS** | authorized exact selector |
| 042 | Public absence: securelyWipeFile: | **STATIC PASS** | count 0 |
| 043 | Private declaration: securelyWipeFile: | **STATIC PASS** | count 1 |
| 044 | Implementation definition: securelyWipeFile: | **STATIC PASS** | count 1 |
| 045 | Selector spelling: securelyWipeFile: | **STATIC PASS** | securelyWipeFile: |
| 046 | Return type: securelyWipeFile: | **STATIC PASS** | BOOL |
| 047 | Argument count: securelyWipeFile: | **STATIC PASS** | 1 |
| 048 | External caller search: securelyWipeFile: | **STATIC PASS** | 0 |
| 049 | New-source public visibility: securelyWipeFile: | **STATIC PASS** | declaration absent |
| 050 | Runtime selector expectation: securelyWipeFile: | **DEVICE PENDING** | definition retained |
| 051 | Baseline target inventory: fixPermissionsAndRemovePath: | **STATIC PASS** | authorized exact selector |
| 052 | Public absence: fixPermissionsAndRemovePath: | **STATIC PASS** | count 0 |
| 053 | Private declaration: fixPermissionsAndRemovePath: | **STATIC PASS** | count 1 |
| 054 | Implementation definition: fixPermissionsAndRemovePath: | **STATIC PASS** | count 1 |
| 055 | Selector spelling: fixPermissionsAndRemovePath: | **STATIC PASS** | fixPermissionsAndRemovePath: |
| 056 | Return type: fixPermissionsAndRemovePath: | **STATIC PASS** | void |
| 057 | Argument count: fixPermissionsAndRemovePath: | **STATIC PASS** | 1 |
| 058 | External caller search: fixPermissionsAndRemovePath: | **STATIC PASS** | 0 |
| 059 | New-source public visibility: fixPermissionsAndRemovePath: | **STATIC PASS** | declaration absent |
| 060 | Runtime selector expectation: fixPermissionsAndRemovePath: | **DEVICE PENDING** | definition retained |
| 061 | Baseline target inventory: fixPermissionsForPath: | **STATIC PASS** | authorized exact selector |
| 062 | Public absence: fixPermissionsForPath: | **STATIC PASS** | count 0 |
| 063 | Private declaration: fixPermissionsForPath: | **STATIC PASS** | count 1 |
| 064 | Implementation definition: fixPermissionsForPath: | **STATIC PASS** | count 1 |
| 065 | Selector spelling: fixPermissionsForPath: | **STATIC PASS** | fixPermissionsForPath: |
| 066 | Return type: fixPermissionsForPath: | **STATIC PASS** | void |
| 067 | Argument count: fixPermissionsForPath: | **STATIC PASS** | 1 |
| 068 | External caller search: fixPermissionsForPath: | **STATIC PASS** | 0 |
| 069 | New-source public visibility: fixPermissionsForPath: | **STATIC PASS** | declaration absent |
| 070 | Runtime selector expectation: fixPermissionsForPath: | **DEVICE PENDING** | definition retained |
| 071 | Baseline target inventory: clearAppCache: | **STATIC PASS** | authorized exact selector |
| 072 | Public absence: clearAppCache: | **STATIC PASS** | count 0 |
| 073 | Private declaration: clearAppCache: | **STATIC PASS** | count 1 |
| 074 | Implementation definition: clearAppCache: | **STATIC PASS** | count 1 |
| 075 | Selector spelling: clearAppCache: | **STATIC PASS** | clearAppCache: |
| 076 | Return type: clearAppCache: | **STATIC PASS** | void |
| 077 | Argument count: clearAppCache: | **STATIC PASS** | 1 |
| 078 | External caller search: clearAppCache: | **STATIC PASS** | 0 |
| 079 | New-source public visibility: clearAppCache: | **STATIC PASS** | declaration absent |
| 080 | Runtime selector expectation: clearAppCache: | **DEVICE PENDING** | definition retained |
| 081 | Baseline target inventory: clearAppPreferences: | **STATIC PASS** | authorized exact selector |
| 082 | Public absence: clearAppPreferences: | **STATIC PASS** | count 0 |
| 083 | Private declaration: clearAppPreferences: | **STATIC PASS** | count 1 |
| 084 | Implementation definition: clearAppPreferences: | **STATIC PASS** | count 1 |
| 085 | Selector spelling: clearAppPreferences: | **STATIC PASS** | clearAppPreferences: |
| 086 | Return type: clearAppPreferences: | **STATIC PASS** | void |
| 087 | Argument count: clearAppPreferences: | **STATIC PASS** | 1 |
| 088 | External caller search: clearAppPreferences: | **STATIC PASS** | 0 |
| 089 | New-source public visibility: clearAppPreferences: | **STATIC PASS** | declaration absent |
| 090 | Runtime selector expectation: clearAppPreferences: | **DEVICE PENDING** | definition retained |
| 091 | Baseline target inventory: clearAppCookies: | **STATIC PASS** | authorized exact selector |
| 092 | Public absence: clearAppCookies: | **STATIC PASS** | count 0 |
| 093 | Private declaration: clearAppCookies: | **STATIC PASS** | count 1 |
| 094 | Implementation definition: clearAppCookies: | **STATIC PASS** | count 1 |
| 095 | Selector spelling: clearAppCookies: | **STATIC PASS** | clearAppCookies: |
| 096 | Return type: clearAppCookies: | **STATIC PASS** | void |
| 097 | Argument count: clearAppCookies: | **STATIC PASS** | 1 |
| 098 | External caller search: clearAppCookies: | **STATIC PASS** | 0 |
| 099 | New-source public visibility: clearAppCookies: | **STATIC PASS** | declaration absent |
| 100 | Runtime selector expectation: clearAppCookies: | **DEVICE PENDING** | definition retained |
| 101 | Baseline target inventory: clearAppWebKitData: | **STATIC PASS** | authorized exact selector |
| 102 | Public absence: clearAppWebKitData: | **STATIC PASS** | count 0 |
| 103 | Private declaration: clearAppWebKitData: | **STATIC PASS** | count 1 |
| 104 | Implementation definition: clearAppWebKitData: | **STATIC PASS** | count 1 |
| 105 | Selector spelling: clearAppWebKitData: | **STATIC PASS** | clearAppWebKitData: |
| 106 | Return type: clearAppWebKitData: | **STATIC PASS** | void |
| 107 | Argument count: clearAppWebKitData: | **STATIC PASS** | 1 |
| 108 | External caller search: clearAppWebKitData: | **STATIC PASS** | 0 |
| 109 | New-source public visibility: clearAppWebKitData: | **STATIC PASS** | declaration absent |
| 110 | Runtime selector expectation: clearAppWebKitData: | **DEVICE PENDING** | definition retained |
| 111 | Baseline target inventory: clearAppGroupData: | **STATIC PASS** | authorized exact selector |
| 112 | Public absence: clearAppGroupData: | **STATIC PASS** | count 0 |
| 113 | Private declaration: clearAppGroupData: | **STATIC PASS** | count 1 |
| 114 | Implementation definition: clearAppGroupData: | **STATIC PASS** | count 1 |
| 115 | Selector spelling: clearAppGroupData: | **STATIC PASS** | clearAppGroupData: |
| 116 | Return type: clearAppGroupData: | **STATIC PASS** | void |
| 117 | Argument count: clearAppGroupData: | **STATIC PASS** | 1 |
| 118 | External caller search: clearAppGroupData: | **STATIC PASS** | 0 |
| 119 | New-source public visibility: clearAppGroupData: | **STATIC PASS** | declaration absent |
| 120 | Runtime selector expectation: clearAppGroupData: | **DEVICE PENDING** | definition retained |
| 121 | Baseline target inventory: clearPluginKitData: | **STATIC PASS** | authorized exact selector |
| 122 | Public absence: clearPluginKitData: | **STATIC PASS** | count 0 |
| 123 | Private declaration: clearPluginKitData: | **STATIC PASS** | count 1 |
| 124 | Implementation definition: clearPluginKitData: | **STATIC PASS** | count 1 |
| 125 | Selector spelling: clearPluginKitData: | **STATIC PASS** | clearPluginKitData: |
| 126 | Return type: clearPluginKitData: | **STATIC PASS** | void |
| 127 | Argument count: clearPluginKitData: | **STATIC PASS** | 1 |
| 128 | External caller search: clearPluginKitData: | **STATIC PASS** | 0 |
| 129 | New-source public visibility: clearPluginKitData: | **STATIC PASS** | declaration absent |
| 130 | Runtime selector expectation: clearPluginKitData: | **DEVICE PENDING** | definition retained |
| 131 | Baseline target inventory: _internalClearEncryptedData: | **STATIC PASS** | authorized exact selector |
| 132 | Public absence: _internalClearEncryptedData: | **STATIC PASS** | count 0 |
| 133 | Private declaration: _internalClearEncryptedData: | **STATIC PASS** | count 1 |
| 134 | Implementation definition: _internalClearEncryptedData: | **STATIC PASS** | count 1 |
| 135 | Selector spelling: _internalClearEncryptedData: | **STATIC PASS** | _internalClearEncryptedData: |
| 136 | Return type: _internalClearEncryptedData: | **STATIC PASS** | void |
| 137 | Argument count: _internalClearEncryptedData: | **STATIC PASS** | 1 |
| 138 | External caller search: _internalClearEncryptedData: | **STATIC PASS** | 0 |
| 139 | New-source public visibility: _internalClearEncryptedData: | **STATIC PASS** | declaration absent |
| 140 | Runtime selector expectation: _internalClearEncryptedData: | **DEVICE PENDING** | definition retained |
| 141 | Baseline target inventory: secureDataWipe: | **STATIC PASS** | authorized exact selector |
| 142 | Public absence: secureDataWipe: | **STATIC PASS** | count 0 |
| 143 | Private declaration: secureDataWipe: | **STATIC PASS** | count 1 |
| 144 | Implementation definition: secureDataWipe: | **STATIC PASS** | count 1 |
| 145 | Selector spelling: secureDataWipe: | **STATIC PASS** | secureDataWipe: |
| 146 | Return type: secureDataWipe: | **STATIC PASS** | void |
| 147 | Argument count: secureDataWipe: | **STATIC PASS** | 1 |
| 148 | External caller search: secureDataWipe: | **STATIC PASS** | 0 |
| 149 | New-source public visibility: secureDataWipe: | **STATIC PASS** | declaration absent |
| 150 | Runtime selector expectation: secureDataWipe: | **DEVICE PENDING** | definition retained |
| 151 | Baseline target inventory: clearAppKeychain: | **STATIC PASS** | authorized exact selector |
| 152 | Public absence: clearAppKeychain: | **STATIC PASS** | count 0 |
| 153 | Private declaration: clearAppKeychain: | **STATIC PASS** | count 1 |
| 154 | Implementation definition: clearAppKeychain: | **STATIC PASS** | count 1 |
| 155 | Selector spelling: clearAppKeychain: | **STATIC PASS** | clearAppKeychain: |
| 156 | Return type: clearAppKeychain: | **STATIC PASS** | void |
| 157 | Argument count: clearAppKeychain: | **STATIC PASS** | 1 |
| 158 | External caller search: clearAppKeychain: | **STATIC PASS** | 0 |
| 159 | New-source public visibility: clearAppKeychain: | **STATIC PASS** | declaration absent |
| 160 | Runtime selector expectation: clearAppKeychain: | **DEVICE PENDING** | definition retained |
| 161 | Baseline target inventory: clearKeychainData: | **STATIC PASS** | authorized exact selector |
| 162 | Public absence: clearKeychainData: | **STATIC PASS** | count 0 |
| 163 | Private declaration: clearKeychainData: | **STATIC PASS** | count 1 |
| 164 | Implementation definition: clearKeychainData: | **STATIC PASS** | count 1 |
| 165 | Selector spelling: clearKeychainData: | **STATIC PASS** | clearKeychainData: |
| 166 | Return type: clearKeychainData: | **STATIC PASS** | void |
| 167 | Argument count: clearKeychainData: | **STATIC PASS** | 1 |
| 168 | External caller search: clearKeychainData: | **STATIC PASS** | 0 |
| 169 | New-source public visibility: clearKeychainData: | **STATIC PASS** | declaration absent |
| 170 | Runtime selector expectation: clearKeychainData: | **DEVICE PENDING** | definition retained |
| 171 | Baseline target inventory: clearKeychainItemsForBundleID: | **STATIC PASS** | authorized exact selector |
| 172 | Public absence: clearKeychainItemsForBundleID: | **STATIC PASS** | count 0 |
| 173 | Private declaration: clearKeychainItemsForBundleID: | **STATIC PASS** | count 1 |
| 174 | Implementation definition: clearKeychainItemsForBundleID: | **STATIC PASS** | count 1 |
| 175 | Selector spelling: clearKeychainItemsForBundleID: | **STATIC PASS** | clearKeychainItemsForBundleID: |
| 176 | Return type: clearKeychainItemsForBundleID: | **STATIC PASS** | void |
| 177 | Argument count: clearKeychainItemsForBundleID: | **STATIC PASS** | 1 |
| 178 | External caller search: clearKeychainItemsForBundleID: | **STATIC PASS** | 0 |
| 179 | New-source public visibility: clearKeychainItemsForBundleID: | **STATIC PASS** | declaration absent |
| 180 | Runtime selector expectation: clearKeychainItemsForBundleID: | **DEVICE PENDING** | definition retained |
| 181 | Baseline target inventory: universalKeychainWipeForBundleID: | **STATIC PASS** | authorized exact selector |
| 182 | Public absence: universalKeychainWipeForBundleID: | **STATIC PASS** | count 0 |
| 183 | Private declaration: universalKeychainWipeForBundleID: | **STATIC PASS** | count 1 |
| 184 | Implementation definition: universalKeychainWipeForBundleID: | **STATIC PASS** | count 1 |
| 185 | Selector spelling: universalKeychainWipeForBundleID: | **STATIC PASS** | universalKeychainWipeForBundleID: |
| 186 | Return type: universalKeychainWipeForBundleID: | **STATIC PASS** | void |
| 187 | Argument count: universalKeychainWipeForBundleID: | **STATIC PASS** | 1 |
| 188 | External caller search: universalKeychainWipeForBundleID: | **STATIC PASS** | 0 |
| 189 | New-source public visibility: universalKeychainWipeForBundleID: | **STATIC PASS** | declaration absent |
| 190 | Runtime selector expectation: universalKeychainWipeForBundleID: | **DEVICE PENDING** | definition retained |
| 191 | Internal inventory: performFullCleanup: | **STATIC PASS** | sends 0; task 0 |
| 192 | Internal inventory: performAggressiveCleanupFor: | **STATIC PASS** | sends 0; task 0 |
| 193 | Internal inventory: completelyWipeContainer: | **STATIC PASS** | sends 0; task 0 |
| 194 | Internal inventory: securelyWipeFile: | **STATIC PASS** | sends 12; task 13 |
| 195 | Internal inventory: fixPermissionsAndRemovePath: | **STATIC PASS** | sends 1; task 1 |
| 196 | Internal inventory: fixPermissionsForPath: | **STATIC PASS** | sends 0; task 0 |
| 197 | Internal inventory: clearAppCache: | **STATIC PASS** | sends 0; task 0 |
| 198 | Internal inventory: clearAppPreferences: | **STATIC PASS** | sends 1; task 1 |
| 199 | Internal inventory: clearAppCookies: | **STATIC PASS** | sends 0; task 0 |
| 200 | Internal inventory: clearAppWebKitData: | **STATIC PASS** | sends 1; task 1 |
| 201 | Internal inventory: clearAppGroupData: | **STATIC PASS** | sends 1; task 1 |
| 202 | Internal inventory: clearPluginKitData: | **STATIC PASS** | sends 0; task 0 |
| 203 | Internal inventory: _internalClearEncryptedData: | **STATIC PASS** | sends 1; task 1 |
| 204 | Internal inventory: secureDataWipe: | **STATIC PASS** | sends 0; task 0 |
| 205 | Internal inventory: clearAppKeychain: | **STATIC PASS** | sends 0; task 0 |
| 206 | Internal inventory: clearKeychainData: | **STATIC PASS** | sends 0; task 0 |
| 207 | Internal inventory: clearKeychainItemsForBundleID: | **STATIC PASS** | sends 0; task 0 |
| 208 | Internal inventory: universalKeychainWipeForBundleID: | **STATIC PASS** | sends 0; task 0 |
| 209 | Header bytes | **STATIC PASS** | 3832 |
| 210 | Header hash | **STATIC PASS** | e8cd18e33519b27061c763bf6308ec4111aa1ea5d92948e7ce2ce59207edae9e |
| 211 | Header CRLF | **STATIC PASS** | 98 |
| 212 | Header final newline | **STATIC PASS** | absent |
| 213 | Header trailing bytes | **STATIC PASS** | @end  |
| 214 | Source bytes | **STATIC PASS** | 371422 |
| 215 | Source hash | **STATIC PASS** | de5a4d8e9215faf8a5a64781af6e9ff082c27998c6ceff70c1cfe0d81aa54fee |
| 216 | Source CRLF | **STATIC PASS** | 6995 |
| 217 | Prefix hash | **STATIC PASS** | 1d5b1267fa7664af72739a1054427443332f51b0a68e73681176a15a7a2ae7cb |
| 218 | Extension hash | **STATIC PASS** | 2a9491f030b11e97dca50fcda5ac6bd3122770a761027055b65e8b388164eeda |
| 219 | Suffix hash | **STATIC PASS** | 62f3f2c91ca16f6346d9cc3d24920186d4862c22469bf1e99a53624bcb38b069 |
| 220 | Header diff | **STATIC PASS** | 0 additions / 18 deletions |
| 221 | Source diff | **STATIC PASS** | 19 additions / 0 deletions |
| 222 | Method-body hunks | **STATIC PASS** | 0 |
| 223 | Caller hunks | **STATIC PASS** | 0 |
| 224 | Shim definition: - (void)finalSweepForContainer:(NSString *)containerPath | **STATIC PASS** | 8bf5998f3e6fb1a8136aaf3f1ba456119949591ab94e9b4f730e724da54a5d31 |
| 225 | Shim definition: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs isRootless:(BOOL)isRootless | **STATIC PASS** | 6036d3ba13ed54f81d117a1f1d18476d7c0534a12c0a9f7f96c26d63cb7e27a7 |
| 226 | Shim definition: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs | **STATIC PASS** | 66bdc618861e2e6aaa655e6d6820af19e7404f720326d71aded8ad885e9f3d03 |
| 227 | Shim definition: - (void)fixPermissionsAndRemovePath:(NSString *)path | **STATIC PASS** | ccd3085b30203aa54692a33d95961d3977a27fa6b48286dbb4e543b951dbed91 |
| 228 | Shim definition: - (void)wipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure | **STATIC PASS** | 5afcba9af309591d61aa6cafa30f53837b993c56b1040c321f728b0b04ec3b46 |
| 229 | Shim definition: - (BOOL)securelyWipeFile:(NSString *)path | **STATIC PASS** | 54ccc0cca4ca5dd821aa5c167ffe93bba901e2b1d6b57e8f6be9f5bfe2d61c82 |
| 230 | Shim definition: - (void)clearKeychainItemsForBundleID:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 231 | Shim definition: - (void)universalKeychainWipeForBundleID:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 232 | Shim definition: - (void)clearPluginKitData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 233 | Shim definition: - (void)fastWipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure timeoutSec:(int)timeoutSec | **STATIC PASS** | a475c6fd241fa8b0a8f98fbe752d7eaf186269633f08fb32b7c7aab9fd10a5b8 |
| 234 | Shim definition: - (void)performFullCleanup:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 235 | Shim definition: - (void)clearAppCache:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 236 | Shim definition: - (void)clearAppPreferences:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 237 | Shim definition: - (void)clearAppCookies:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 238 | Shim definition: - (void)clearAppWebKitData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 239 | Shim definition: - (void)clearAppKeychain:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 240 | Shim definition: - (void)clearAppGroupData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 241 | Shim definition: - (void)clearKeychainData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 242 | Shim definition: - (void)secureDataWipe:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 243 | Shim definition: - (void)wipeWebKitDirectoryContents:(NSString *)path | **STATIC PASS** | ccd3085b30203aa54692a33d95961d3977a27fa6b48286dbb4e543b951dbed91 |
| 244 | Shim definition: - (void)_internalClearEncryptedData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 245 | Shim definition: - (void)clearExtensionContainers:(NSArray *)extensionInfo forApp:(NSString *)bundleID | **STATIC PASS** | 9b019b785e79ddf54ebe4bc127bd73270454978924326a0dc16bd7a338bd653f |
| 246 | Shim definition: - (void)fixPermissionsForPath:(NSString *)path | **STATIC PASS** | ccd3085b30203aa54692a33d95961d3977a27fa6b48286dbb4e543b951dbed91 |
| 247 | Shim definition: - (void)performAggressiveCleanupFor:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 248 | Shim definition: - (void)completelyWipeContainer:(NSString *)containerPath | **STATIC PASS** | 8bf5998f3e6fb1a8136aaf3f1ba456119949591ab94e9b4f730e724da54a5d31 |
| 249 | Shim definition: - (void)_wipeRelatedDataContainersForBundleIDs:(NSArray<NSString *> *)bundleIDs | **STATIC PASS** | 2ea3553b6290715ec30c6aa6eca5681fb09840e7eff6d9230be4629fae549fa5 |
| 250 | Shim definition: - (void)_wipeRelatedSystemGroupContainersForIdentifiers:(NSArray<NSString *> *)idents | **STATIC PASS** | 878bc17cd0413a43cb04eec8fc6162a314b1420b7f82819df5b720cab765c2f3 |
| 251 | Shim definition: - (void)_wipeContainersInBasePaths:(NSArray<NSString *> *)bases                matchingSubstrings:(NSArray<NSString *> *)needles                              tag:(NSString *)tag | **STATIC PASS** | 81a20cb1168f85b995c38b9b2c1f91bb0defffb90b576c4971c13a5945599dcd |
| 252 | Shim definition: - (void)_wipeDataContainersByIdentifierPrefixOrSubstring:(NSArray<NSString *> *)prefixes                                               substrings:(NSArray<NSString *> *)substrings                                                     tag:(NSString *)tag | **STATIC PASS** | bcef071facacb4859ca4a07c3781c78597e7ea59fa7a9e676cbca457f79774cf |
| 253 | Shim definition: - (void)_scrubWebKitStateInSharedContainerBase:(NSString *)base tag:(NSString *)tag | **STATIC PASS** | 97fd923baeac83d2cc53b77680fdb0e2d5977e5d3bb287942296ce945ab19f0d |
| 254 | Shim definition: - (void)cleanAppGroupContainers:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 255 | Shim definition: - (void)cleanAppSpecificFilesInSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | 284b45efadf7b00cb3524d7cb5521ed7d31c2360f3aaaf4f390f891edd024569 |
| 256 | Shim definition: - (void)deepCleanSystemSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | 284b45efadf7b00cb3524d7cb5521ed7d31c2360f3aaaf4f390f891edd024569 |
| 257 | Shim logger: - (void)finalSweepForContainer:(NSString *)containerPath | **STATIC PASS** | exactly one |
| 258 | Shim logger: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs isRootless:(BOOL)isRootless | **STATIC PASS** | exactly one |
| 259 | Shim logger: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs | **STATIC PASS** | exactly one |
| 260 | Shim logger: - (void)fixPermissionsAndRemovePath:(NSString *)path | **STATIC PASS** | exactly one |
| 261 | Shim logger: - (void)wipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure | **STATIC PASS** | exactly one |
| 262 | Shim logger: - (BOOL)securelyWipeFile:(NSString *)path | **STATIC PASS** | exactly one |
| 263 | Shim logger: - (void)clearKeychainItemsForBundleID:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 264 | Shim logger: - (void)universalKeychainWipeForBundleID:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 265 | Shim logger: - (void)clearPluginKitData:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 266 | Shim logger: - (void)fastWipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure timeoutSec:(int)timeoutSec | **STATIC PASS** | exactly one |
| 267 | Shim logger: - (void)performFullCleanup:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 268 | Shim logger: - (void)clearAppCache:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 269 | Shim logger: - (void)clearAppPreferences:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 270 | Shim logger: - (void)clearAppCookies:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 271 | Shim logger: - (void)clearAppWebKitData:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 272 | Shim logger: - (void)clearAppKeychain:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 273 | Shim logger: - (void)clearAppGroupData:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 274 | Shim logger: - (void)clearKeychainData:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 275 | Shim logger: - (void)secureDataWipe:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 276 | Shim logger: - (void)wipeWebKitDirectoryContents:(NSString *)path | **STATIC PASS** | exactly one |
| 277 | Shim logger: - (void)_internalClearEncryptedData:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 278 | Shim logger: - (void)clearExtensionContainers:(NSArray *)extensionInfo forApp:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 279 | Shim logger: - (void)fixPermissionsForPath:(NSString *)path | **STATIC PASS** | exactly one |
| 280 | Shim logger: - (void)performAggressiveCleanupFor:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 281 | Shim logger: - (void)completelyWipeContainer:(NSString *)containerPath | **STATIC PASS** | exactly one |
| 282 | Shim logger: - (void)_wipeRelatedDataContainersForBundleIDs:(NSArray<NSString *> *)bundleIDs | **STATIC PASS** | exactly one |
| 283 | Shim logger: - (void)_wipeRelatedSystemGroupContainersForIdentifiers:(NSArray<NSString *> *)idents | **STATIC PASS** | exactly one |
| 284 | Shim logger: - (void)_wipeContainersInBasePaths:(NSArray<NSString *> *)bases                matchingSubstrings:(NSArray<NSString *> *)needles                              tag:(NSString *)tag | **STATIC PASS** | exactly one |
| 285 | Shim logger: - (void)_wipeDataContainersByIdentifierPrefixOrSubstring:(NSArray<NSString *> *)prefixes                                               substrings:(NSArray<NSString *> *)substrings                                                     tag:(NSString *)tag | **STATIC PASS** | exactly one |
| 286 | Shim logger: - (void)_scrubWebKitStateInSharedContainerBase:(NSString *)base tag:(NSString *)tag | **STATIC PASS** | exactly one |
| 287 | Shim logger: - (void)cleanAppGroupContainers:(NSString *)bundleID | **STATIC PASS** | exactly one |
| 288 | Shim logger: - (void)cleanAppSpecificFilesInSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | exactly one |
| 289 | Shim logger: - (void)deepCleanSystemSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | exactly one |
| 290 | Shim total | **STATIC PASS** | 33 |
| 291 | Logger definition | **STATIC PASS** | 1 |
| 292 | Logger calls | **STATIC PASS** | 33 |
| 293 | Logger privacy | **STATIC PASS** | SEL only |
| 294 | securelyWipeFile result | **STATIC PASS** | NO |
| 295 | securelyWipeFile inspection | **STATIC PASS** | none |
| 296 | Void shim mutation | **STATIC PASS** | none |
| 297 | Five-scope Clear | **STATIC PASS** | 25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1 |
| 298 | Four-scope data-only | **STATIC PASS** | 204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644 |
| 299 | Keychain plan | **STATIC PASS** | suffix unchanged |
| 300 | Callback precedence | **STATIC PASS** | suffix unchanged |
| 301 | One-shot completion | **STATIC PASS** | suffix unchanged |
| 302 | Final verification | **STATIC PASS** | suffix unchanged |
| 303 | Retained public API: + (instancetype)sharedManager; | **STATIC PASS** | count 1 |
| 304 | Retained public API: - (void)clearDataForBundleID:(NSString *)bundleID | **STATIC PASS** | count 1 |
| 305 | Retained public API: - (BOOL)hasDataToClear:(NSString *)bundleID; | **STATIC PASS** | count 1 |
| 306 | Retained public API: - (void)completeAppDataWipe:(NSString *)bundleID; | **STATIC PASS** | count 1 |
| 307 | Retained public API: - (void)performSecondaryCleanup:(NSString *)bundleID; | **STATIC PASS** | count 1 |
| 308 | Retained public API: - (void)clearAppData:(NSString *)bundleID; | **STATIC PASS** | count 1 |
| 309 | Retained public API: - (BOOL)verifyDataCleared:(NSString *)bundleID; | **STATIC PASS** | count 1 |
| 310 | Retained public API: - (NSString *)findBundleContainerUUIDForBundleID:(NSString *)bundleID; | **STATIC PASS** | count 1 |
| 311 | Canonical caller count: clearDataForBundleID: | **STATIC PASS** | 5 |
| 312 | Canonical caller count: hasDataToClear: | **STATIC PASS** | 2 |
| 313 | Canonical caller count: verifyDataCleared: | **STATIC PASS** | 1 |
| 314 | Canonical caller count: findBundleContainerUUIDForBundleID: | **STATIC PASS** | 1 |
| 315 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | main.m:537:[cleaner clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 316 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:3924:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 317 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:6446:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 318 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:6632:[[AppDataCleaner sharedManager] clearDataForBundleID:manifestBundleID completion:^(BOOL clearSuccess, NSError *clearError) { |
| 319 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:6697:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 320 | Canonical caller: hasDataToClear: | **STATIC PASS** | main.m:533:if ([cleaner hasDataToClear:bundleID]) { |
| 321 | Canonical caller: hasDataToClear: | **STATIC PASS** | ProjectXViewController.m:3749:foundData = [[AppDataCleaner sharedManager] hasDataToClear:bundleID]; |
| 322 | Canonical caller: verifyDataCleared: | **STATIC PASS** | main.m:545:[cleaner verifyDataCleared:bundleID]; |
| 323 | Canonical caller: findBundleContainerUUIDForBundleID: | **STATIC PASS** | AppEntitlementsReader.m:201:NSString *bundleUUID = [cleaner findBundleContainerUUIDForBundleID:bundleID]; |
| 324 | Protected hash: AppEntitlementsReader.h | **STATIC PASS** | c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e |
| 325 | Protected hash: AppEntitlementsReader.m | **STATIC PASS** | 0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797 |
| 326 | Protected hash: PXDataContainerResolver.h | **STATIC PASS** | b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30 |
| 327 | Protected hash: PXDataContainerResolver.m | **STATIC PASS** | cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365 |
| 328 | Protected hash: PXDestructivePathValidator.h | **STATIC PASS** | 542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a |
| 329 | Protected hash: PXDestructivePathValidator.m | **STATIC PASS** | f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb |
| 330 | Protected hash: PXClearRequest.h | **STATIC PASS** | d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b |
| 331 | Protected hash: PXClearRequest.m | **STATIC PASS** | afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790 |
| 332 | Protected hash: PXClearResult.h | **STATIC PASS** | cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592 |
| 333 | Protected hash: PXClearResult.m | **STATIC PASS** | 0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715 |
| 334 | Protected hash: CommandRunner.h | **STATIC PASS** | 63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf |
| 335 | Protected hash: CommandRunner.m | **STATIC PASS** | 2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030 |
| 336 | Protected hash: AppGroupContainerResolver.h | **STATIC PASS** | c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97 |
| 337 | Protected hash: AppGroupContainerResolver.m | **STATIC PASS** | 11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1 |
| 338 | Protected hash: AppDataBackupManager.h | **STATIC PASS** | b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75 |
| 339 | Protected hash: AppDataBackupManager.m | **STATIC PASS** | 61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028 |
| 340 | Protected hash: ProjectXViewController.m | **STATIC PASS** | b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162 |
| 341 | Protected hash: ProfileManagerViewController.m | **STATIC PASS** | a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a |
| 342 | Protected hash: AppDataBackupRestoreViewController.h | **STATIC PASS** | b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf |
| 343 | Protected hash: AppDataBackupRestoreViewController.m | **STATIC PASS** | 23c964fac0189119c500665a700fe1fb7dafa77fd63779dccaa9e084cefa26c5 |
| 344 | Protected hash: main.m | **STATIC PASS** | 7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da |
| 345 | Protected hash: Makefile | **STATIC PASS** | b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa |
| 346 | Protected hash: docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md | **STATIC PASS** | a7b2ffe36ba3c6682a4ea160e82486b87243ec4bd614e0f6655dcd17946efb33 |
| 347 | Protected hash: docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md | **STATIC PASS** | 9e9c817976947d06e289559e1bc15d6959f98d713983407c329d48b6935ec565 |
| 348 | Protected hash: docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md | **STATIC PASS** | a668acd27522275a1c5580bb48d99b5a569879a2aa5f953e2289d46913ff5903 |
| 349 | Protected hash: docs/backup-restore-hardening/reports/TASK-5.4-REPORT.md | **STATIC PASS** | 8c40fca455c3e0973d5ef20f770777f2e439e551d0cd195b10c5720f46228e19 |
| 350 | Phase 5 report: docs/backup-restore-hardening/reports/TASK-5.1-REPORT.md | **STATIC PASS** | 736d6a38719daf7c9384cca8f728b0ed7078e65f1ba935c5cb32cc34914e4fd6 |
| 351 | Phase 5 report: docs/backup-restore-hardening/reports/TASK-5.2-REPORT.md | **STATIC PASS** | b5c76629dbe35ac81fd7081a1195ddeda77cef7fe1d6ce424f5cbdd5ab84202c |
| 352 | Phase 5 report: docs/backup-restore-hardening/reports/TASK-5.3-REPORT.md | **STATIC PASS** | 8bf6b4cc86521f9cb0ea8e1a38e9cf6f619fa3e377dd137396fa055b066154a8 |
| 353 | Phase 5 report: docs/backup-restore-hardening/reports/TASK-5.4-REPORT.md | **STATIC PASS** | 8c40fca455c3e0973d5ef20f770777f2e439e551d0cd195b10c5720f46228e19 |
| 354 | No deprecation | **STATIC PASS** | 0 |
| 355 | No unavailable | **STATIC PASS** | 0 |
| 356 | No public category | **STATIC PASS** | 0 |
| 357 | No public header | **STATIC PASS** | 0 |
| 358 | No selector rename | **STATIC PASS** | 0 |
| 359 | No implementation removal | **STATIC PASS** | 0 |
| 360 | No compatibility macro | **STATIC PASS** | 0 |
| 361 | Balanced parentheses | **STATIC PASS** | lexical audit |
| 362 | Balanced brackets | **STATIC PASS** | lexical audit |
| 363 | Balanced braces | **STATIC PASS** | lexical audit |
| 364 | Conflict markers | **STATIC PASS** | 0 |
| 365 | NUL audit | **STATIC PASS** | 0 |
| 366 | C0 control audit | **STATIC PASS** | none except tab/newline/CR |
| 367 | git diff --check | **STATIC PASS** | clean |
| 368 | Apple clean | **NOT RUN** | Theos unavailable |
| 369 | Apple compile | **NOT RUN** | Theos unavailable |
| 370 | Apple package | **NOT RUN** | Theos unavailable |
| 371 | arm64 | **NOT RUN** | Apple unavailable |
| 372 | arm64e | **NOT RUN** | Apple unavailable |
| 373 | iOS 12 target | **NOT RUN** | Apple unavailable |
| 374 | instancesRespondToSelector | **DEVICE PENDING** | device unavailable |
| 375 | Old binary ABI | **DEVICE PENDING** | device unavailable |
| 376 | Shim runtime logging | **DEVICE PENDING** | device unavailable |
| 377 | Shim runtime non-mutation | **DEVICE PENDING** | device unavailable |
| 378 | Typed Clear runtime | **DEVICE PENDING** | device unavailable |
| 379 | Backup runtime | **DEVICE PENDING** | device unavailable |
| 380 | Restore runtime | **DEVICE PENDING** | device unavailable |
| 381 | Coordinator docs not staged | **STATIC PASS** | preserved |
| 382 | TASK-6.1 review | **STATIC PASS** | not created |
| 383 | TASK-6.2 | **STATIC PASS** | not started |
| 384 | Static CI guards | **STATIC PASS** | not added |
| 385 | Fault injection | **STATIC PASS** | not added |
| 386 | Compatibility docs | **STATIC PASS** | not added |
| 387 | Push | **STATIC PASS** | not performed |
| 388 | GitHub Actions | **PENDING** | not run |
| 389 | Suggested state | **READY_FOR_REVIEW** | static gates pass |

Explicit scenario count: **389**

## 30. Commit and push status

- Implementation commit is created after this report passes final gates.
- Push was not performed and is not authorized.

## 31. Stop boundary

Stop after the exact three-file TASK-6.1 implementation commit and post-commit evidence. Do not create a review, update coordinator docs, start TASK-6.2, add deprecations, migrate aliases, remove implementations, add CI guards/tests/docs, or push.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
