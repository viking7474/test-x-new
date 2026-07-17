# TASK-6.2 REPORT — Remove Ambiguous Public Clear Aliases

## 1. Result

**STATIC IMPLEMENTATION PASS.** Exactly 32 ambiguous alias declarations were removed from `AppDataCleaner.h` and relocated, unchanged, into the existing anonymous class extension in `AppDataCleaner.m`. All 32 Objective-C implementations, selector spellings, return types, argument counts, behavior mappings, runtime symbols and the entire protected behavior suffix remain byte-identical.

No TASK-6.3 work was started. No push was performed.

## 2. User authority

The user supplied TASK-6.2, confirmed TASK-6.1 as PASSED/COMPLETED, and explicitly authorized implementation despite the absent TASK-6.1 review file.

## 3. TASK-6.1 review-file status

`docs/backup-restore-hardening/reviews/TASK-6.1-REVIEW.md` does not exist. The task authority explicitly makes this absence non-blocking for TASK-6.2.

## 4. Baseline

- Required and actual HEAD: `8aff2f8b985fd4b226ce566ca40daa11d58091b3`
- `8aff2f8 phase6(task-6.1): reduce destructive public API surface`

## 5. Working-tree preservation

- `docs/backup-restore-hardening/DECISIONS.md` — `601194d5abfa2fade0e0a6c63a213c733618799bbfae0972ccdd641a0975bbe6` — PRESERVED / NOT STAGED
- `docs/backup-restore-hardening/README.md` — `8a09213977c03f946a206c46cdd28c27a718b0dba017d3c7f7e425e6d0403172` — PRESERVED / NOT STAGED
- `docs/backup-restore-hardening/ROADMAP.md` — `ceccb3ddda2ff901d30f06e74d7102484f0fd2af9281923063e1b6a84371c07e` — PRESERVED / NOT STAGED
- `docs/backup-restore-hardening/STATUS.md` — `1007d679213e55edb01e1671cb607a1ad9daf22d44ee4d9fb554d00d2eeaf82b` — PRESERVED / NOT STAGED
- All pre-existing untracked task/review documents were preserved.

## 6. Exact authorized scope

- `M AppDataCleaner.h`
- `M AppDataCleaner.m`
- `A docs/backup-restore-hardening/reports/TASK-6.2-REPORT.md`

No Makefile, production caller, coordinator document, Backup/Restore source, Keychain source, category, protocol, compatibility module, public header, test source or CI script was modified or added.

## 7. D-114 and D-120 authority

- D-114 keeps `clearDataForBundleID:completion:` as the only approved full five-scope Clear authority and `completeAppDataWipe:` as the accepted four-scope data-only compatibility authority.
- D-120 assigns public declaration removal and alias reduction to Phase 6 while preserving implementation symbols and runtime ABI.

## 8. Public source API versus runtime ABI

| Property | Result |
|---|---|
| Public source declarations | removed for exact 32 aliases |
| Private compile declarations | one each |
| Objective-C implementations | one each |
| Runtime selector spellings | unchanged |
| Existing binary ABI | statically retained |
| Runtime execution | DEVICE PENDING |

## 9. Public declaration inventory

| Metric | Count |
|---|---:|
| TASK-6.1 baseline public instance methods | 56 |
| TASK-6.2 declarations removed | 32 |
| Final public instance methods | 24 |

## 10. Exact 32-alias inventory and behavior groups

| Group | Count | Target behavior |
|---|---:|---|
| Data-only four-scope redirect | 19 | `completeAppDataWipe:` |
| Quarantined-target redirect | 4 | existing TASK-1.12 no-op selectors |
| System-log redirect | 5 | `clearSystemLogs:` |
| Other direct mutator | 4 | existing exact target |
| Total | 32 | unchanged |

### 10.1 Data-only four-scope aliases

- `performSecondaryCleanup:` → `completeAppDataWipe:`
- `clearAppData:` → `completeAppDataWipe:`
- `clearSQLiteDatabases:` → `completeAppDataWipe:`
- `clearDeviceDatabase:` → `completeAppDataWipe:`
- `clearNetworkConfigurations:` → `completeAppDataWipe:`
- `clearCarrierData:` → `completeAppDataWipe:`
- `clearNetworkData:` → `completeAppDataWipe:`
- `clearDNSCache:` → `completeAppDataWipe:`
- `clearBluetoothData:` → `completeAppDataWipe:`
- `clearPushNotificationData:` → `completeAppDataWipe:`
- `clearGameData:` → `completeAppDataWipe:`
- `clearTemporaryFiles:` → `completeAppDataWipe:`
- `clearBinaryPlists:` → `completeAppDataWipe:`
- `clearJailbreakDetectionLogs:` → `completeAppDataWipe:`
- `clearSpotlightData:` → `completeAppDataWipe:`
- `clearSiriData:` → `completeAppDataWipe:`
- `clearURLCache:` → `completeAppDataWipe:`
- `clearBackgroundAssets:` → `completeAppDataWipe:`
- `clearSharedStorage:` → `completeAppDataWipe:`

### 10.2 Quarantined-target aliases

- `clearSharedContainers:` → `clearAppGroupData:`
- `clearUserDefaults:` → `clearAppPreferences:`
- `clearWebCache:` → `clearAppWebKitData:`
- `clearEncryptedData:` → `_internalClearEncryptedData:`

### 10.3 System-log aliases

- `clearInstallationLogs:` → `clearSystemLogs:`
- `clearCrashReports:` → `clearSystemLogs:`
- `clearDiagnosticData:` → `clearSystemLogs:`
- `clearSystemLoggerData:` → `clearSystemLogs:`
- `clearASLLogs:` → `clearSystemLogs:`

### 10.4 Direct-mutator aliases

- `clearPrivateVarData:` → `cleanRootHideVarData:`
- `clearThumbnailCache:` → `clearThumbnailCaches:`
- `clearPasteboardData:` → `clearClipboard`
- `clearAppStateData:` → `_internalClearAppStateData:`

## 11. Declaration/definition and ABI matrix

| Selector | Public | Private | Definition | Return | Args | Target | Body SHA-256 |
|---|---:|---:|---:|---|---:|---|---|
| `performSecondaryCleanup:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` |
| `clearAppData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` |
| `clearSharedContainers:` | 0 | 1 | 1 | `void` | 1 | `clearAppGroupData:` | `fecd5b82280a36fb78b80a1baec02a82941e976739c9ac3723f223a3f5e5dfe9` |
| `clearUserDefaults:` | 0 | 1 | 1 | `void` | 1 | `clearAppPreferences:` | `e79f4ebc60ab5135cb659902010ada336148e98200dd1100ab43714577b05bfe` |
| `clearSQLiteDatabases:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearPrivateVarData:` | 0 | 1 | 1 | `void` | 1 | `cleanRootHideVarData:` | `3492e1fe3992a3785e23dabd6c07bd882b02bd3745d6e1eb09dd8dbd099b6b79` |
| `clearDeviceDatabase:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearInstallationLogs:` | 0 | 1 | 1 | `void` | 1 | `clearSystemLogs:` | `1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5` |
| `clearNetworkConfigurations:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearCarrierData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearNetworkData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearDNSCache:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearCrashReports:` | 0 | 1 | 1 | `void` | 1 | `clearSystemLogs:` | `1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5` |
| `clearDiagnosticData:` | 0 | 1 | 1 | `void` | 1 | `clearSystemLogs:` | `1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5` |
| `clearBluetoothData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearPushNotificationData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearThumbnailCache:` | 0 | 1 | 1 | `void` | 1 | `clearThumbnailCaches:` | `2bb51c340d63636935ea6590d6a9de3e93e63ea3efbccf6999f444ec1c0aa13d` |
| `clearWebCache:` | 0 | 1 | 1 | `void` | 1 | `clearAppWebKitData:` | `f8db55ea89f28a447b38786a775e4631a08960cee82528e1634ae65e67ff1962` |
| `clearGameData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearTemporaryFiles:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearBinaryPlists:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearEncryptedData:` | 0 | 1 | 1 | `void` | 1 | `_internalClearEncryptedData:` | `6d62eccae75295240630b1107f12e51a02519efee651c2ec0dc90e0946c61bf1` |
| `clearJailbreakDetectionLogs:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearSpotlightData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearSiriData:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearSystemLoggerData:` | 0 | 1 | 1 | `void` | 1 | `clearSystemLogs:` | `1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5` |
| `clearASLLogs:` | 0 | 1 | 1 | `void` | 1 | `clearSystemLogs:` | `1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5` |
| `clearPasteboardData:` | 0 | 1 | 1 | `void` | 1 | `clearClipboard` | `03992335489eed972b0a794c182f0ac1b6ded0c6db0f47f7ca4e21bce4751601` |
| `clearURLCache:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearBackgroundAssets:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearSharedStorage:` | 0 | 1 | 1 | `void` | 1 | `completeAppDataWipe:` | `a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56` |
| `clearAppStateData:` | 0 | 1 | 1 | `void` | 1 | `_internalClearAppStateData:` | `e64673d035f0d5ab67e3e1a7d0702cd6d5316bc140166904668936d188fb1c9a` |

## 12. External and internal caller inventory

- External production calls to the 32 aliases: **0**.
- Actual internal Objective-C message sends to the 32 aliases: **0**.
- The parser excludes declarations, definitions, selector literals, comments and string literals; raw token counts are not used as caller authority.

## 13. Exact public header proof

- Bytes: `2228`.
- SHA-256: `9c68c07115d32f2c57a1027646d6055d21375842a64064d9cfdcaeaeabe30a86`.
- CRLF: `66`; LF-only: `0`; lone CR: `0`; NUL: `0`.
- Final newline absent; trailing `@end ` space preserved.
- Diff shape: exactly 32 deletion lines and zero additions.

## 14. Final retained 24-method public interface

- `clearDataForBundleID:completion:` — exactly one declaration
- `hasDataToClear:` — exactly one declaration
- `completeAppDataWipe:` — exactly one declaration
- `cleanIconStatePlist:` — exactly one declaration
- `cleanSiriAnalyticsDatabase:` — exactly one declaration
- `cleanLaunchServicesDatabase:` — exactly one declaration
- `refreshSystemServices` — exactly one declaration
- `clearAppReceiptData:withBundleUUID:` — exactly one declaration
- `clearSystemLogs:` — exactly one declaration
- `clearICloudData:` — exactly one declaration
- `clearMediaData:` — exactly one declaration
- `clearHealthData:` — exactly one declaration
- `clearSafariData:` — exactly one declaration
- `clearURLCredentialsForBundleID:` — exactly one declaration
- `clearSpotlightIndexes:` — exactly one declaration
- `clearClipboard` — exactly one declaration
- `_internalClearAppStateData:` — exactly one declaration
- `verifyDataCleared:` — exactly one declaration
- `getDataUsage:` — exactly one declaration
- `findDataContainerUUIDForBundleID:` — exactly one declaration
- `findBundleContainerUUIDForBundleID:` — exactly one declaration
- `findGroupContainerUUIDsForBundleID:` — exactly one declaration
- `findExtensionDataContainersForBundleID:` — exactly one declaration
- `hasKeychainItemsForBundleID:` — exactly one declaration

## 15. Private declaration relocation

- Baseline private instance declarations: `32` (`14` original plus `18` TASK-6.1 relocations).
- Added TASK-6.2 declarations: `32`.
- Final private instance declarations: `64`.
- The exact block follows the 18 TASK-6.1 declarations and precedes the first anonymous-extension `@end`.

## 16. Exact source and segment hashes

| Segment | Bytes | SHA-256 |
|---|---:|---|
| Full `AppDataCleaner.m` | 373028 | `6355110ba6398a927d0f7dc1251b5e47f81f79ef47f60cf977795e451cdc916a` |
| Prefix before class extension | 1078 | `1d5b1267fa7664af72739a1054427443332f51b0a68e73681176a15a7a2ae7cb` |
| Complete class extension | 6062 | `b1209549779f3cc39d29a89f63e3151c530978ac2dac969dd5088295f9330899` |
| Entire behavior suffix | 365888 | `62f3f2c91ca16f6346d9cc3d24920186d4862c22469bf1e99a53624bcb38b069` |
| Alias implementation region | 4105 | `775716caf68c274b8b002901751cc513357eda4057f61a7ecc0fae5391946e6b` |

The suffix and alias-region hashes are byte-identical to the TASK-6.1 baseline, proving no method body, implementation ordering, behavior mapping, comment or whitespace after the anonymous extension changed.

## 17. Runtime/ABI preservation and source compatibility change

- All 32 instance-method definitions remain with unchanged selector spellings, one `void` return and one argument.
- Existing binaries compiled against the older header retain static ABI compatibility because the implementations remain.
- New source importing the current header no longer receives declarations for these aliases and must choose an explicit retained authority.
- No replacement macro, category, protocol, private installed header, bridging header or conditional re-exposure was added.

## 18. No deprecation or unavailable attributes

No new `NS_DEPRECATED`, `API_DEPRECATED`, `__attribute__((deprecated))`, `unavailable`, `NS_SWIFT_UNAVAILABLE`, `renamed:` or compiler-warning suppression was added. The canonical choice is declaration removal.

## 19. Behavior-group non-regression

- Exactly 19 aliases still call `completeAppDataWipe:` once and do not add Keychain execution.
- Exactly 4 aliases still terminate at existing quarantined no-op selectors.
- Exactly 5 aliases still call `clearSystemLogs:` once.
- Exactly 4 aliases retain their existing direct-mutator mappings.
- Exact alias-region equality proves all mappings are unchanged.

## 20. TASK-6.1 selector protection

| Selector | Public | Private | Definition |
|---|---:|---:|---:|
| `performFullCleanup:` | 0 | 1 | 1 |
| `performAggressiveCleanupFor:` | 0 | 1 | 1 |
| `completelyWipeContainer:` | 0 | 1 | 1 |
| `securelyWipeFile:` | 0 | 1 | 1 |
| `fixPermissionsAndRemovePath:` | 0 | 1 | 1 |
| `fixPermissionsForPath:` | 0 | 1 | 1 |
| `clearAppCache:` | 0 | 1 | 1 |
| `clearAppPreferences:` | 0 | 1 | 1 |
| `clearAppCookies:` | 0 | 1 | 1 |
| `clearAppWebKitData:` | 0 | 1 | 1 |
| `clearAppGroupData:` | 0 | 1 | 1 |
| `clearPluginKitData:` | 0 | 1 | 1 |
| `_internalClearEncryptedData:` | 0 | 1 | 1 |
| `secureDataWipe:` | 0 | 1 | 1 |
| `clearAppKeychain:` | 0 | 1 | 1 |
| `clearKeychainData:` | 0 | 1 | 1 |
| `clearKeychainItemsForBundleID:` | 0 | 1 | 1 |
| `universalKeychainWipeForBundleID:` | 0 | 1 | 1 |

## 21. TASK-1.12 quarantine protection

- Quarantine shim definitions: `33`.
- Quarantine logger definitions: `1`.
- Logger calls in shim bodies: `33`; exactly one each.
- Logger signature remains `SEL selector`; no path, bundle ID, UUID, group, entitlement, Keychain group, command or profile is logged.
- `securelyWipeFile:` body remains `85` bytes / `54ccc0cca4ca5dd821aa5c167ffe93bba901e2b1d6b57e8f6be9f5bfe2d61c82`, performs no inspection/mutation and returns `NO`.
- The 32 TASK-6.2 aliases were not converted into new quarantine shims.

## 22. Typed Clear and compatibility body hashes

| Body | Bytes | SHA-256 |
|---|---:|---|
| `clearDataForBundleID:completion:` | 15419 | `25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1` |
| `completeAppDataWipe:` | 1182 | `204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644` |
| `clearAppData:` | 46 | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` |
| `performSecondaryCleanup:` | 46 | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` |
| `_wipeMobileSafariSystemStores` | 14098 | `077ed7ea110e0fde1ed40f2fa852803159eaa7f9d1493c34af377ab3408636bc` |

These exact hashes plus the unchanged behavior suffix protect the four-scope/five-scope masks, resolver and validator order, canonical paths, Keychain planning and two-pass accounting, component ordering, callback precedence, watchdog/background-task ownership, one-shot completion and final verification.

## 23. Retained canonical callers

| Authority/query | Production calls |
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

## 24. Protected production and evidence hashes

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
| `docs/backup-restore-hardening/reports/TASK-6.1-REPORT.md` | `4c332a937bf44d125c796842a78564a2d3dd92529132ff73f400a589b4570354` |
| `docs/backup-restore-hardening/reports/TASK-5.1-REPORT.md` | `736d6a38719daf7c9384cca8f728b0ed7078e65f1ba935c5cb32cc34914e4fd6` |
| `docs/backup-restore-hardening/reports/TASK-5.2-REPORT.md` | `b5c76629dbe35ac81fd7081a1195ddeda77cef7fe1d6ce424f5cbdd5ab84202c` |
| `docs/backup-restore-hardening/reports/TASK-5.3-REPORT.md` | `8bf6b4cc86521f9cb0ea8e1a38e9cf6f619fa3e377dd137396fa055b066154a8` |
| `docs/backup-restore-hardening/reports/TASK-5.4-REPORT.md` | `8c40fca455c3e0973d5ef20f770777f2e439e551d0cd195b10c5720f46228e19` |

## 25. Backup/Restore and Makefile protection

`AppDataBackupManager.h/.m`, `AppDataBackupRestoreViewController.h/.m`, `ProjectXViewController.m`, `ProfileManagerViewController.m`, Keychain helper/bridge/scripts, and `Makefile` are byte-identical to their protected baselines. No Backup/Restore behavior or build configuration changed.

## 26. Static source gates

| Gate | Result |
|---|---|
| Public instance declarations | 24 |
| Private extension declarations | 64 |
| TASK-6.2 public/private/definitions | 0 / 32 / 32 |
| TASK-6.1 public/private/definitions | 0 / 18 / 18 |
| External/internal alias calls | 0 / 0 |
| Behavior groups | 19 / 4 / 5 / 4 |
| Expected file hashes | PASS |
| Prefix/extension/suffix | PASS |
| Alias implementation region | PASS |
| 33 shims / 33 logger calls | PASS |
| Balanced delimiters | PASS |
| Comment/string exclusion | PASS |
| Conflict markers / NUL | 0 / 0 |
| New deprecation/unavailable | 0 |
| New category/header/CI guard | 0 |
| Selector rename/removal | 0 / 0 |
| Method-body/caller hunks | 0 / 0 |
| `git diff --check` | PASS |

## 27. Objective-C/toolchain status

- Windows deterministic parsing, body-hash, caller, mapping, delimiter, encoding and diff gates: PASS.
- Apple Clang/Theos `make clean`, `make`, and `make package`: NOT RUN because Apple/Theos is unavailable in this Windows workspace. No compile, link or package PASS is claimed.

## 28. Device/runtime status

- Device/runtime harness unavailable. `instancesRespondToSelector:`, old-binary messaging, mapping behavior, canonical Clear runtime and Backup/Restore runtime checks are DEVICE PENDING.

## 29. Full authorized production diff

```diff
diff --git a/AppDataCleaner.h b/AppDataCleaner.h
index 8452694..c314452 100644
--- a/AppDataCleaner.h
+++ b/AppDataCleaner.h
@@ -15,7 +15,6 @@

 #pragma mark - Comprehensive Cleanup Methods

-- (void)performSecondaryCleanup:(NSString *)bundleID;
 - (void)completeAppDataWipe:(NSString *)bundleID;

 #pragma mark - Enhanced Container Cleaning
@@ -25,64 +24,33 @@
 - (void)refreshSystemServices;

 #pragma mark - Standard App Data Cleaning
-- (void)clearAppData:(NSString *)bundleID;
 - (void)clearAppReceiptData:(NSString *)bundleID withBundleUUID:(NSString *)bundleUUID;

 #pragma mark - System Storage Cleaning
-- (void)clearSharedContainers:(NSString *)bundleID;
-- (void)clearUserDefaults:(NSString *)bundleID;
-- (void)clearSQLiteDatabases:(NSString *)bundleID;

 #pragma mark - Hidden Storage Cleaning
-- (void)clearPrivateVarData:(NSString *)bundleID;
 - (void)clearSystemLogs:(NSString *)bundleID;
-- (void)clearDeviceDatabase:(NSString *)bundleID;
-- (void)clearInstallationLogs:(NSString *)bundleID;

 #pragma mark - Network & Carrier Cleaning
-- (void)clearNetworkConfigurations:(NSString *)bundleID;
-- (void)clearCarrierData:(NSString *)bundleID;
-- (void)clearNetworkData:(NSString *)bundleID;
-- (void)clearDNSCache:(NSString *)bundleID;

 #pragma mark - Additional Storage Cleaning
-- (void)clearCrashReports:(NSString *)bundleID;
-- (void)clearDiagnosticData:(NSString *)bundleID;
 - (void)clearICloudData:(NSString *)bundleID;
-- (void)clearBluetoothData:(NSString *)bundleID;
-- (void)clearPushNotificationData:(NSString *)bundleID;
 - (void)clearMediaData:(NSString *)bundleID;
 - (void)clearHealthData:(NSString *)bundleID;
 - (void)clearSafariData:(NSString *)bundleID;

 #pragma mark - Cache & Residual Cleaning
-- (void)clearThumbnailCache:(NSString *)bundleID;
-- (void)clearWebCache:(NSString *)bundleID;
-- (void)clearGameData:(NSString *)bundleID;
-- (void)clearTemporaryFiles:(NSString *)bundleID;

 #pragma mark - Advanced Cleaning Methods
-- (void)clearBinaryPlists:(NSString *)bundleID;
-- (void)clearEncryptedData:(NSString *)bundleID;
-- (void)clearJailbreakDetectionLogs:(NSString *)bundleID;
 - (void)clearURLCredentialsForBundleID:(NSString *)bundleID;
 - (void)clearSpotlightIndexes:(NSString *)bundleID;

 #pragma mark - System Integration
-- (void)clearSpotlightData:(NSString *)bundleID;
-- (void)clearSiriData:(NSString *)bundleID;
-- (void)clearSystemLoggerData:(NSString *)bundleID;
-- (void)clearASLLogs:(NSString *)bundleID;

 #pragma mark - Data Persistence
 - (void)clearClipboard;
-- (void)clearPasteboardData:(NSString *)bundleID;
-- (void)clearURLCache:(NSString *)bundleID;
-- (void)clearBackgroundAssets:(NSString *)bundleID;

 #pragma mark - State Management
-- (void)clearSharedStorage:(NSString *)bundleID;
-- (void)clearAppStateData:(NSString *)bundleID;
 - (void)_internalClearAppStateData:(NSString *)bundleID;

 #pragma mark - Security Methods
diff --git a/AppDataCleaner.m b/AppDataCleaner.m
index c645983..5cb0c63 100644
--- a/AppDataCleaner.m
+++ b/AppDataCleaner.m
@@ -88,6 +88,39 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
 - (void)clearKeychainData:(NSString *)bundleID;
 - (void)clearKeychainItemsForBundleID:(NSString *)bundleID;
 - (void)universalKeychainWipeForBundleID:(NSString *)bundleID;
+
+- (void)performSecondaryCleanup:(NSString *)bundleID;
+- (void)clearAppData:(NSString *)bundleID;
+- (void)clearSharedContainers:(NSString *)bundleID;
+- (void)clearUserDefaults:(NSString *)bundleID;
+- (void)clearSQLiteDatabases:(NSString *)bundleID;
+- (void)clearPrivateVarData:(NSString *)bundleID;
+- (void)clearDeviceDatabase:(NSString *)bundleID;
+- (void)clearInstallationLogs:(NSString *)bundleID;
+- (void)clearNetworkConfigurations:(NSString *)bundleID;
+- (void)clearCarrierData:(NSString *)bundleID;
+- (void)clearNetworkData:(NSString *)bundleID;
+- (void)clearDNSCache:(NSString *)bundleID;
+- (void)clearCrashReports:(NSString *)bundleID;
+- (void)clearDiagnosticData:(NSString *)bundleID;
+- (void)clearBluetoothData:(NSString *)bundleID;
+- (void)clearPushNotificationData:(NSString *)bundleID;
+- (void)clearThumbnailCache:(NSString *)bundleID;
+- (void)clearWebCache:(NSString *)bundleID;
+- (void)clearGameData:(NSString *)bundleID;
+- (void)clearTemporaryFiles:(NSString *)bundleID;
+- (void)clearBinaryPlists:(NSString *)bundleID;
+- (void)clearEncryptedData:(NSString *)bundleID;
+- (void)clearJailbreakDetectionLogs:(NSString *)bundleID;
+- (void)clearSpotlightData:(NSString *)bundleID;
+- (void)clearSiriData:(NSString *)bundleID;
+- (void)clearSystemLoggerData:(NSString *)bundleID;
+- (void)clearASLLogs:(NSString *)bundleID;
+- (void)clearPasteboardData:(NSString *)bundleID;
+- (void)clearURLCache:(NSString *)bundleID;
+- (void)clearBackgroundAssets:(NSString *)bundleID;
+- (void)clearSharedStorage:(NSString *)bundleID;
+- (void)clearAppStateData:(NSString *)bundleID;
 @end

 @interface PXKeychainClearPlan : NSObject {
```

## 30. Line endings, NUL and control audit

| File | Endings | Final newline | NUL / unintended C0 |
|---|---|---|---|
| `AppDataCleaner.h` | UTF-8 CRLF 66 | absent; trailing `@end ` retained | 0 / 0 |
| `AppDataCleaner.m` | UTF-8 CRLF 7028 | present | 0 / 0 |
| `TASK-6.2-REPORT.md` | UTF-8 LF | present | 0 / 0 |

## 31. Residual binary/source compatibility risks

- New source using the 32 removed declarations will fail to compile until it selects a retained authority; this is intentional.
- Existing binary ABI is statically retained, but device/runtime confirmation remains pending.
- The retained direct operations and query methods are outside this exact alias-removal decision and are not declared safe long-term by this task.
- No Apple, device or GitHub Actions result is fabricated.

## 32. Explicit numbered scenarios

| # | Scenario | Status | Evidence |
|---:|---|---|---|
| 001 | Baseline HEAD | **STATIC PASS** | 8aff2f8b985fd4b226ce566ca40daa11d58091b3 |
| 002 | TASK-6.2 only | **STATIC PASS** | TASK-6.3 not started |
| 003 | Authorized scope | **STATIC PASS** | AppDataCleaner.h; AppDataCleaner.m; TASK-6.2-REPORT.md |
| 004 | User authority | **STATIC PASS** | TASK-6.1 PASSED and COMPLETED |
| 005 | TASK-6.1 review status | **STATIC PASS** | absent and explicitly non-blocking |
| 006 | Coordinator docs | **STATIC PASS** | preserved and not staged |
| 007 | Pre-existing untracked documents | **STATIC PASS** | preserved |
| 008 | Makefile | **STATIC PASS** | unchanged |
| 009 | Caller files | **STATIC PASS** | unchanged |
| 010 | Backup/Restore source | **STATIC PASS** | unchanged |
| 011 | No push | **STATIC PASS** | not performed |
| 012 | Public baseline | **STATIC PASS** | 56 |
| 013 | Public final | **STATIC PASS** | 24 |
| 014 | Private baseline | **STATIC PASS** | 32 |
| 015 | Private final | **STATIC PASS** | 64 |
| 016 | Alias total | **STATIC PASS** | 32 |
| 017 | Data-only alias group | **STATIC PASS** | 19 |
| 018 | Quarantine-target group | **STATIC PASS** | 4 |
| 019 | System-log group | **STATIC PASS** | 5 |
| 020 | Direct-mutator group | **STATIC PASS** | 4 |
| 021 | Alias inventory: performSecondaryCleanup: | **STATIC PASS** | authorized exact selector |
| 022 | Public declaration absence: performSecondaryCleanup: | **STATIC PASS** | 0 |
| 023 | Private declaration: performSecondaryCleanup: | **STATIC PASS** | 1 |
| 024 | Implementation definition: performSecondaryCleanup: | **STATIC PASS** | 1 |
| 025 | Return type: performSecondaryCleanup: | **STATIC PASS** | void |
| 026 | Argument count: performSecondaryCleanup: | **STATIC PASS** | 1 |
| 027 | Selector spelling: performSecondaryCleanup: | **STATIC PASS** | performSecondaryCleanup: |
| 028 | External caller: performSecondaryCleanup: | **STATIC PASS** | 0 |
| 029 | Internal message send: performSecondaryCleanup: | **STATIC PASS** | 0 |
| 030 | Behavior target: performSecondaryCleanup: | **STATIC PASS** | completeAppDataWipe: |
| 031 | Body hash: performSecondaryCleanup: | **STATIC PASS** | b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb |
| 032 | Runtime selector expectation: performSecondaryCleanup: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 033 | New-source visibility: performSecondaryCleanup: | **STATIC PASS** | declaration absent from current public header |
| 034 | Alias inventory: clearAppData: | **STATIC PASS** | authorized exact selector |
| 035 | Public declaration absence: clearAppData: | **STATIC PASS** | 0 |
| 036 | Private declaration: clearAppData: | **STATIC PASS** | 1 |
| 037 | Implementation definition: clearAppData: | **STATIC PASS** | 1 |
| 038 | Return type: clearAppData: | **STATIC PASS** | void |
| 039 | Argument count: clearAppData: | **STATIC PASS** | 1 |
| 040 | Selector spelling: clearAppData: | **STATIC PASS** | clearAppData: |
| 041 | External caller: clearAppData: | **STATIC PASS** | 0 |
| 042 | Internal message send: clearAppData: | **STATIC PASS** | 0 |
| 043 | Behavior target: clearAppData: | **STATIC PASS** | completeAppDataWipe: |
| 044 | Body hash: clearAppData: | **STATIC PASS** | b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb |
| 045 | Runtime selector expectation: clearAppData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 046 | New-source visibility: clearAppData: | **STATIC PASS** | declaration absent from current public header |
| 047 | Alias inventory: clearSharedContainers: | **STATIC PASS** | authorized exact selector |
| 048 | Public declaration absence: clearSharedContainers: | **STATIC PASS** | 0 |
| 049 | Private declaration: clearSharedContainers: | **STATIC PASS** | 1 |
| 050 | Implementation definition: clearSharedContainers: | **STATIC PASS** | 1 |
| 051 | Return type: clearSharedContainers: | **STATIC PASS** | void |
| 052 | Argument count: clearSharedContainers: | **STATIC PASS** | 1 |
| 053 | Selector spelling: clearSharedContainers: | **STATIC PASS** | clearSharedContainers: |
| 054 | External caller: clearSharedContainers: | **STATIC PASS** | 0 |
| 055 | Internal message send: clearSharedContainers: | **STATIC PASS** | 0 |
| 056 | Behavior target: clearSharedContainers: | **STATIC PASS** | clearAppGroupData: |
| 057 | Body hash: clearSharedContainers: | **STATIC PASS** | fecd5b82280a36fb78b80a1baec02a82941e976739c9ac3723f223a3f5e5dfe9 |
| 058 | Runtime selector expectation: clearSharedContainers: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 059 | New-source visibility: clearSharedContainers: | **STATIC PASS** | declaration absent from current public header |
| 060 | Alias inventory: clearUserDefaults: | **STATIC PASS** | authorized exact selector |
| 061 | Public declaration absence: clearUserDefaults: | **STATIC PASS** | 0 |
| 062 | Private declaration: clearUserDefaults: | **STATIC PASS** | 1 |
| 063 | Implementation definition: clearUserDefaults: | **STATIC PASS** | 1 |
| 064 | Return type: clearUserDefaults: | **STATIC PASS** | void |
| 065 | Argument count: clearUserDefaults: | **STATIC PASS** | 1 |
| 066 | Selector spelling: clearUserDefaults: | **STATIC PASS** | clearUserDefaults: |
| 067 | External caller: clearUserDefaults: | **STATIC PASS** | 0 |
| 068 | Internal message send: clearUserDefaults: | **STATIC PASS** | 0 |
| 069 | Behavior target: clearUserDefaults: | **STATIC PASS** | clearAppPreferences: |
| 070 | Body hash: clearUserDefaults: | **STATIC PASS** | e79f4ebc60ab5135cb659902010ada336148e98200dd1100ab43714577b05bfe |
| 071 | Runtime selector expectation: clearUserDefaults: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 072 | New-source visibility: clearUserDefaults: | **STATIC PASS** | declaration absent from current public header |
| 073 | Alias inventory: clearSQLiteDatabases: | **STATIC PASS** | authorized exact selector |
| 074 | Public declaration absence: clearSQLiteDatabases: | **STATIC PASS** | 0 |
| 075 | Private declaration: clearSQLiteDatabases: | **STATIC PASS** | 1 |
| 076 | Implementation definition: clearSQLiteDatabases: | **STATIC PASS** | 1 |
| 077 | Return type: clearSQLiteDatabases: | **STATIC PASS** | void |
| 078 | Argument count: clearSQLiteDatabases: | **STATIC PASS** | 1 |
| 079 | Selector spelling: clearSQLiteDatabases: | **STATIC PASS** | clearSQLiteDatabases: |
| 080 | External caller: clearSQLiteDatabases: | **STATIC PASS** | 0 |
| 081 | Internal message send: clearSQLiteDatabases: | **STATIC PASS** | 0 |
| 082 | Behavior target: clearSQLiteDatabases: | **STATIC PASS** | completeAppDataWipe: |
| 083 | Body hash: clearSQLiteDatabases: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 084 | Runtime selector expectation: clearSQLiteDatabases: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 085 | New-source visibility: clearSQLiteDatabases: | **STATIC PASS** | declaration absent from current public header |
| 086 | Alias inventory: clearPrivateVarData: | **STATIC PASS** | authorized exact selector |
| 087 | Public declaration absence: clearPrivateVarData: | **STATIC PASS** | 0 |
| 088 | Private declaration: clearPrivateVarData: | **STATIC PASS** | 1 |
| 089 | Implementation definition: clearPrivateVarData: | **STATIC PASS** | 1 |
| 090 | Return type: clearPrivateVarData: | **STATIC PASS** | void |
| 091 | Argument count: clearPrivateVarData: | **STATIC PASS** | 1 |
| 092 | Selector spelling: clearPrivateVarData: | **STATIC PASS** | clearPrivateVarData: |
| 093 | External caller: clearPrivateVarData: | **STATIC PASS** | 0 |
| 094 | Internal message send: clearPrivateVarData: | **STATIC PASS** | 0 |
| 095 | Behavior target: clearPrivateVarData: | **STATIC PASS** | cleanRootHideVarData: |
| 096 | Body hash: clearPrivateVarData: | **STATIC PASS** | 3492e1fe3992a3785e23dabd6c07bd882b02bd3745d6e1eb09dd8dbd099b6b79 |
| 097 | Runtime selector expectation: clearPrivateVarData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 098 | New-source visibility: clearPrivateVarData: | **STATIC PASS** | declaration absent from current public header |
| 099 | Alias inventory: clearDeviceDatabase: | **STATIC PASS** | authorized exact selector |
| 100 | Public declaration absence: clearDeviceDatabase: | **STATIC PASS** | 0 |
| 101 | Private declaration: clearDeviceDatabase: | **STATIC PASS** | 1 |
| 102 | Implementation definition: clearDeviceDatabase: | **STATIC PASS** | 1 |
| 103 | Return type: clearDeviceDatabase: | **STATIC PASS** | void |
| 104 | Argument count: clearDeviceDatabase: | **STATIC PASS** | 1 |
| 105 | Selector spelling: clearDeviceDatabase: | **STATIC PASS** | clearDeviceDatabase: |
| 106 | External caller: clearDeviceDatabase: | **STATIC PASS** | 0 |
| 107 | Internal message send: clearDeviceDatabase: | **STATIC PASS** | 0 |
| 108 | Behavior target: clearDeviceDatabase: | **STATIC PASS** | completeAppDataWipe: |
| 109 | Body hash: clearDeviceDatabase: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 110 | Runtime selector expectation: clearDeviceDatabase: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 111 | New-source visibility: clearDeviceDatabase: | **STATIC PASS** | declaration absent from current public header |
| 112 | Alias inventory: clearInstallationLogs: | **STATIC PASS** | authorized exact selector |
| 113 | Public declaration absence: clearInstallationLogs: | **STATIC PASS** | 0 |
| 114 | Private declaration: clearInstallationLogs: | **STATIC PASS** | 1 |
| 115 | Implementation definition: clearInstallationLogs: | **STATIC PASS** | 1 |
| 116 | Return type: clearInstallationLogs: | **STATIC PASS** | void |
| 117 | Argument count: clearInstallationLogs: | **STATIC PASS** | 1 |
| 118 | Selector spelling: clearInstallationLogs: | **STATIC PASS** | clearInstallationLogs: |
| 119 | External caller: clearInstallationLogs: | **STATIC PASS** | 0 |
| 120 | Internal message send: clearInstallationLogs: | **STATIC PASS** | 0 |
| 121 | Behavior target: clearInstallationLogs: | **STATIC PASS** | clearSystemLogs: |
| 122 | Body hash: clearInstallationLogs: | **STATIC PASS** | 1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5 |
| 123 | Runtime selector expectation: clearInstallationLogs: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 124 | New-source visibility: clearInstallationLogs: | **STATIC PASS** | declaration absent from current public header |
| 125 | Alias inventory: clearNetworkConfigurations: | **STATIC PASS** | authorized exact selector |
| 126 | Public declaration absence: clearNetworkConfigurations: | **STATIC PASS** | 0 |
| 127 | Private declaration: clearNetworkConfigurations: | **STATIC PASS** | 1 |
| 128 | Implementation definition: clearNetworkConfigurations: | **STATIC PASS** | 1 |
| 129 | Return type: clearNetworkConfigurations: | **STATIC PASS** | void |
| 130 | Argument count: clearNetworkConfigurations: | **STATIC PASS** | 1 |
| 131 | Selector spelling: clearNetworkConfigurations: | **STATIC PASS** | clearNetworkConfigurations: |
| 132 | External caller: clearNetworkConfigurations: | **STATIC PASS** | 0 |
| 133 | Internal message send: clearNetworkConfigurations: | **STATIC PASS** | 0 |
| 134 | Behavior target: clearNetworkConfigurations: | **STATIC PASS** | completeAppDataWipe: |
| 135 | Body hash: clearNetworkConfigurations: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 136 | Runtime selector expectation: clearNetworkConfigurations: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 137 | New-source visibility: clearNetworkConfigurations: | **STATIC PASS** | declaration absent from current public header |
| 138 | Alias inventory: clearCarrierData: | **STATIC PASS** | authorized exact selector |
| 139 | Public declaration absence: clearCarrierData: | **STATIC PASS** | 0 |
| 140 | Private declaration: clearCarrierData: | **STATIC PASS** | 1 |
| 141 | Implementation definition: clearCarrierData: | **STATIC PASS** | 1 |
| 142 | Return type: clearCarrierData: | **STATIC PASS** | void |
| 143 | Argument count: clearCarrierData: | **STATIC PASS** | 1 |
| 144 | Selector spelling: clearCarrierData: | **STATIC PASS** | clearCarrierData: |
| 145 | External caller: clearCarrierData: | **STATIC PASS** | 0 |
| 146 | Internal message send: clearCarrierData: | **STATIC PASS** | 0 |
| 147 | Behavior target: clearCarrierData: | **STATIC PASS** | completeAppDataWipe: |
| 148 | Body hash: clearCarrierData: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 149 | Runtime selector expectation: clearCarrierData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 150 | New-source visibility: clearCarrierData: | **STATIC PASS** | declaration absent from current public header |
| 151 | Alias inventory: clearNetworkData: | **STATIC PASS** | authorized exact selector |
| 152 | Public declaration absence: clearNetworkData: | **STATIC PASS** | 0 |
| 153 | Private declaration: clearNetworkData: | **STATIC PASS** | 1 |
| 154 | Implementation definition: clearNetworkData: | **STATIC PASS** | 1 |
| 155 | Return type: clearNetworkData: | **STATIC PASS** | void |
| 156 | Argument count: clearNetworkData: | **STATIC PASS** | 1 |
| 157 | Selector spelling: clearNetworkData: | **STATIC PASS** | clearNetworkData: |
| 158 | External caller: clearNetworkData: | **STATIC PASS** | 0 |
| 159 | Internal message send: clearNetworkData: | **STATIC PASS** | 0 |
| 160 | Behavior target: clearNetworkData: | **STATIC PASS** | completeAppDataWipe: |
| 161 | Body hash: clearNetworkData: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 162 | Runtime selector expectation: clearNetworkData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 163 | New-source visibility: clearNetworkData: | **STATIC PASS** | declaration absent from current public header |
| 164 | Alias inventory: clearDNSCache: | **STATIC PASS** | authorized exact selector |
| 165 | Public declaration absence: clearDNSCache: | **STATIC PASS** | 0 |
| 166 | Private declaration: clearDNSCache: | **STATIC PASS** | 1 |
| 167 | Implementation definition: clearDNSCache: | **STATIC PASS** | 1 |
| 168 | Return type: clearDNSCache: | **STATIC PASS** | void |
| 169 | Argument count: clearDNSCache: | **STATIC PASS** | 1 |
| 170 | Selector spelling: clearDNSCache: | **STATIC PASS** | clearDNSCache: |
| 171 | External caller: clearDNSCache: | **STATIC PASS** | 0 |
| 172 | Internal message send: clearDNSCache: | **STATIC PASS** | 0 |
| 173 | Behavior target: clearDNSCache: | **STATIC PASS** | completeAppDataWipe: |
| 174 | Body hash: clearDNSCache: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 175 | Runtime selector expectation: clearDNSCache: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 176 | New-source visibility: clearDNSCache: | **STATIC PASS** | declaration absent from current public header |
| 177 | Alias inventory: clearCrashReports: | **STATIC PASS** | authorized exact selector |
| 178 | Public declaration absence: clearCrashReports: | **STATIC PASS** | 0 |
| 179 | Private declaration: clearCrashReports: | **STATIC PASS** | 1 |
| 180 | Implementation definition: clearCrashReports: | **STATIC PASS** | 1 |
| 181 | Return type: clearCrashReports: | **STATIC PASS** | void |
| 182 | Argument count: clearCrashReports: | **STATIC PASS** | 1 |
| 183 | Selector spelling: clearCrashReports: | **STATIC PASS** | clearCrashReports: |
| 184 | External caller: clearCrashReports: | **STATIC PASS** | 0 |
| 185 | Internal message send: clearCrashReports: | **STATIC PASS** | 0 |
| 186 | Behavior target: clearCrashReports: | **STATIC PASS** | clearSystemLogs: |
| 187 | Body hash: clearCrashReports: | **STATIC PASS** | 1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5 |
| 188 | Runtime selector expectation: clearCrashReports: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 189 | New-source visibility: clearCrashReports: | **STATIC PASS** | declaration absent from current public header |
| 190 | Alias inventory: clearDiagnosticData: | **STATIC PASS** | authorized exact selector |
| 191 | Public declaration absence: clearDiagnosticData: | **STATIC PASS** | 0 |
| 192 | Private declaration: clearDiagnosticData: | **STATIC PASS** | 1 |
| 193 | Implementation definition: clearDiagnosticData: | **STATIC PASS** | 1 |
| 194 | Return type: clearDiagnosticData: | **STATIC PASS** | void |
| 195 | Argument count: clearDiagnosticData: | **STATIC PASS** | 1 |
| 196 | Selector spelling: clearDiagnosticData: | **STATIC PASS** | clearDiagnosticData: |
| 197 | External caller: clearDiagnosticData: | **STATIC PASS** | 0 |
| 198 | Internal message send: clearDiagnosticData: | **STATIC PASS** | 0 |
| 199 | Behavior target: clearDiagnosticData: | **STATIC PASS** | clearSystemLogs: |
| 200 | Body hash: clearDiagnosticData: | **STATIC PASS** | 1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5 |
| 201 | Runtime selector expectation: clearDiagnosticData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 202 | New-source visibility: clearDiagnosticData: | **STATIC PASS** | declaration absent from current public header |
| 203 | Alias inventory: clearBluetoothData: | **STATIC PASS** | authorized exact selector |
| 204 | Public declaration absence: clearBluetoothData: | **STATIC PASS** | 0 |
| 205 | Private declaration: clearBluetoothData: | **STATIC PASS** | 1 |
| 206 | Implementation definition: clearBluetoothData: | **STATIC PASS** | 1 |
| 207 | Return type: clearBluetoothData: | **STATIC PASS** | void |
| 208 | Argument count: clearBluetoothData: | **STATIC PASS** | 1 |
| 209 | Selector spelling: clearBluetoothData: | **STATIC PASS** | clearBluetoothData: |
| 210 | External caller: clearBluetoothData: | **STATIC PASS** | 0 |
| 211 | Internal message send: clearBluetoothData: | **STATIC PASS** | 0 |
| 212 | Behavior target: clearBluetoothData: | **STATIC PASS** | completeAppDataWipe: |
| 213 | Body hash: clearBluetoothData: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 214 | Runtime selector expectation: clearBluetoothData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 215 | New-source visibility: clearBluetoothData: | **STATIC PASS** | declaration absent from current public header |
| 216 | Alias inventory: clearPushNotificationData: | **STATIC PASS** | authorized exact selector |
| 217 | Public declaration absence: clearPushNotificationData: | **STATIC PASS** | 0 |
| 218 | Private declaration: clearPushNotificationData: | **STATIC PASS** | 1 |
| 219 | Implementation definition: clearPushNotificationData: | **STATIC PASS** | 1 |
| 220 | Return type: clearPushNotificationData: | **STATIC PASS** | void |
| 221 | Argument count: clearPushNotificationData: | **STATIC PASS** | 1 |
| 222 | Selector spelling: clearPushNotificationData: | **STATIC PASS** | clearPushNotificationData: |
| 223 | External caller: clearPushNotificationData: | **STATIC PASS** | 0 |
| 224 | Internal message send: clearPushNotificationData: | **STATIC PASS** | 0 |
| 225 | Behavior target: clearPushNotificationData: | **STATIC PASS** | completeAppDataWipe: |
| 226 | Body hash: clearPushNotificationData: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 227 | Runtime selector expectation: clearPushNotificationData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 228 | New-source visibility: clearPushNotificationData: | **STATIC PASS** | declaration absent from current public header |
| 229 | Alias inventory: clearThumbnailCache: | **STATIC PASS** | authorized exact selector |
| 230 | Public declaration absence: clearThumbnailCache: | **STATIC PASS** | 0 |
| 231 | Private declaration: clearThumbnailCache: | **STATIC PASS** | 1 |
| 232 | Implementation definition: clearThumbnailCache: | **STATIC PASS** | 1 |
| 233 | Return type: clearThumbnailCache: | **STATIC PASS** | void |
| 234 | Argument count: clearThumbnailCache: | **STATIC PASS** | 1 |
| 235 | Selector spelling: clearThumbnailCache: | **STATIC PASS** | clearThumbnailCache: |
| 236 | External caller: clearThumbnailCache: | **STATIC PASS** | 0 |
| 237 | Internal message send: clearThumbnailCache: | **STATIC PASS** | 0 |
| 238 | Behavior target: clearThumbnailCache: | **STATIC PASS** | clearThumbnailCaches: |
| 239 | Body hash: clearThumbnailCache: | **STATIC PASS** | 2bb51c340d63636935ea6590d6a9de3e93e63ea3efbccf6999f444ec1c0aa13d |
| 240 | Runtime selector expectation: clearThumbnailCache: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 241 | New-source visibility: clearThumbnailCache: | **STATIC PASS** | declaration absent from current public header |
| 242 | Alias inventory: clearWebCache: | **STATIC PASS** | authorized exact selector |
| 243 | Public declaration absence: clearWebCache: | **STATIC PASS** | 0 |
| 244 | Private declaration: clearWebCache: | **STATIC PASS** | 1 |
| 245 | Implementation definition: clearWebCache: | **STATIC PASS** | 1 |
| 246 | Return type: clearWebCache: | **STATIC PASS** | void |
| 247 | Argument count: clearWebCache: | **STATIC PASS** | 1 |
| 248 | Selector spelling: clearWebCache: | **STATIC PASS** | clearWebCache: |
| 249 | External caller: clearWebCache: | **STATIC PASS** | 0 |
| 250 | Internal message send: clearWebCache: | **STATIC PASS** | 0 |
| 251 | Behavior target: clearWebCache: | **STATIC PASS** | clearAppWebKitData: |
| 252 | Body hash: clearWebCache: | **STATIC PASS** | f8db55ea89f28a447b38786a775e4631a08960cee82528e1634ae65e67ff1962 |
| 253 | Runtime selector expectation: clearWebCache: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 254 | New-source visibility: clearWebCache: | **STATIC PASS** | declaration absent from current public header |
| 255 | Alias inventory: clearGameData: | **STATIC PASS** | authorized exact selector |
| 256 | Public declaration absence: clearGameData: | **STATIC PASS** | 0 |
| 257 | Private declaration: clearGameData: | **STATIC PASS** | 1 |
| 258 | Implementation definition: clearGameData: | **STATIC PASS** | 1 |
| 259 | Return type: clearGameData: | **STATIC PASS** | void |
| 260 | Argument count: clearGameData: | **STATIC PASS** | 1 |
| 261 | Selector spelling: clearGameData: | **STATIC PASS** | clearGameData: |
| 262 | External caller: clearGameData: | **STATIC PASS** | 0 |
| 263 | Internal message send: clearGameData: | **STATIC PASS** | 0 |
| 264 | Behavior target: clearGameData: | **STATIC PASS** | completeAppDataWipe: |
| 265 | Body hash: clearGameData: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 266 | Runtime selector expectation: clearGameData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 267 | New-source visibility: clearGameData: | **STATIC PASS** | declaration absent from current public header |
| 268 | Alias inventory: clearTemporaryFiles: | **STATIC PASS** | authorized exact selector |
| 269 | Public declaration absence: clearTemporaryFiles: | **STATIC PASS** | 0 |
| 270 | Private declaration: clearTemporaryFiles: | **STATIC PASS** | 1 |
| 271 | Implementation definition: clearTemporaryFiles: | **STATIC PASS** | 1 |
| 272 | Return type: clearTemporaryFiles: | **STATIC PASS** | void |
| 273 | Argument count: clearTemporaryFiles: | **STATIC PASS** | 1 |
| 274 | Selector spelling: clearTemporaryFiles: | **STATIC PASS** | clearTemporaryFiles: |
| 275 | External caller: clearTemporaryFiles: | **STATIC PASS** | 0 |
| 276 | Internal message send: clearTemporaryFiles: | **STATIC PASS** | 0 |
| 277 | Behavior target: clearTemporaryFiles: | **STATIC PASS** | completeAppDataWipe: |
| 278 | Body hash: clearTemporaryFiles: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 279 | Runtime selector expectation: clearTemporaryFiles: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 280 | New-source visibility: clearTemporaryFiles: | **STATIC PASS** | declaration absent from current public header |
| 281 | Alias inventory: clearBinaryPlists: | **STATIC PASS** | authorized exact selector |
| 282 | Public declaration absence: clearBinaryPlists: | **STATIC PASS** | 0 |
| 283 | Private declaration: clearBinaryPlists: | **STATIC PASS** | 1 |
| 284 | Implementation definition: clearBinaryPlists: | **STATIC PASS** | 1 |
| 285 | Return type: clearBinaryPlists: | **STATIC PASS** | void |
| 286 | Argument count: clearBinaryPlists: | **STATIC PASS** | 1 |
| 287 | Selector spelling: clearBinaryPlists: | **STATIC PASS** | clearBinaryPlists: |
| 288 | External caller: clearBinaryPlists: | **STATIC PASS** | 0 |
| 289 | Internal message send: clearBinaryPlists: | **STATIC PASS** | 0 |
| 290 | Behavior target: clearBinaryPlists: | **STATIC PASS** | completeAppDataWipe: |
| 291 | Body hash: clearBinaryPlists: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 292 | Runtime selector expectation: clearBinaryPlists: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 293 | New-source visibility: clearBinaryPlists: | **STATIC PASS** | declaration absent from current public header |
| 294 | Alias inventory: clearEncryptedData: | **STATIC PASS** | authorized exact selector |
| 295 | Public declaration absence: clearEncryptedData: | **STATIC PASS** | 0 |
| 296 | Private declaration: clearEncryptedData: | **STATIC PASS** | 1 |
| 297 | Implementation definition: clearEncryptedData: | **STATIC PASS** | 1 |
| 298 | Return type: clearEncryptedData: | **STATIC PASS** | void |
| 299 | Argument count: clearEncryptedData: | **STATIC PASS** | 1 |
| 300 | Selector spelling: clearEncryptedData: | **STATIC PASS** | clearEncryptedData: |
| 301 | External caller: clearEncryptedData: | **STATIC PASS** | 0 |
| 302 | Internal message send: clearEncryptedData: | **STATIC PASS** | 0 |
| 303 | Behavior target: clearEncryptedData: | **STATIC PASS** | _internalClearEncryptedData: |
| 304 | Body hash: clearEncryptedData: | **STATIC PASS** | 6d62eccae75295240630b1107f12e51a02519efee651c2ec0dc90e0946c61bf1 |
| 305 | Runtime selector expectation: clearEncryptedData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 306 | New-source visibility: clearEncryptedData: | **STATIC PASS** | declaration absent from current public header |
| 307 | Alias inventory: clearJailbreakDetectionLogs: | **STATIC PASS** | authorized exact selector |
| 308 | Public declaration absence: clearJailbreakDetectionLogs: | **STATIC PASS** | 0 |
| 309 | Private declaration: clearJailbreakDetectionLogs: | **STATIC PASS** | 1 |
| 310 | Implementation definition: clearJailbreakDetectionLogs: | **STATIC PASS** | 1 |
| 311 | Return type: clearJailbreakDetectionLogs: | **STATIC PASS** | void |
| 312 | Argument count: clearJailbreakDetectionLogs: | **STATIC PASS** | 1 |
| 313 | Selector spelling: clearJailbreakDetectionLogs: | **STATIC PASS** | clearJailbreakDetectionLogs: |
| 314 | External caller: clearJailbreakDetectionLogs: | **STATIC PASS** | 0 |
| 315 | Internal message send: clearJailbreakDetectionLogs: | **STATIC PASS** | 0 |
| 316 | Behavior target: clearJailbreakDetectionLogs: | **STATIC PASS** | completeAppDataWipe: |
| 317 | Body hash: clearJailbreakDetectionLogs: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 318 | Runtime selector expectation: clearJailbreakDetectionLogs: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 319 | New-source visibility: clearJailbreakDetectionLogs: | **STATIC PASS** | declaration absent from current public header |
| 320 | Alias inventory: clearSpotlightData: | **STATIC PASS** | authorized exact selector |
| 321 | Public declaration absence: clearSpotlightData: | **STATIC PASS** | 0 |
| 322 | Private declaration: clearSpotlightData: | **STATIC PASS** | 1 |
| 323 | Implementation definition: clearSpotlightData: | **STATIC PASS** | 1 |
| 324 | Return type: clearSpotlightData: | **STATIC PASS** | void |
| 325 | Argument count: clearSpotlightData: | **STATIC PASS** | 1 |
| 326 | Selector spelling: clearSpotlightData: | **STATIC PASS** | clearSpotlightData: |
| 327 | External caller: clearSpotlightData: | **STATIC PASS** | 0 |
| 328 | Internal message send: clearSpotlightData: | **STATIC PASS** | 0 |
| 329 | Behavior target: clearSpotlightData: | **STATIC PASS** | completeAppDataWipe: |
| 330 | Body hash: clearSpotlightData: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 331 | Runtime selector expectation: clearSpotlightData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 332 | New-source visibility: clearSpotlightData: | **STATIC PASS** | declaration absent from current public header |
| 333 | Alias inventory: clearSiriData: | **STATIC PASS** | authorized exact selector |
| 334 | Public declaration absence: clearSiriData: | **STATIC PASS** | 0 |
| 335 | Private declaration: clearSiriData: | **STATIC PASS** | 1 |
| 336 | Implementation definition: clearSiriData: | **STATIC PASS** | 1 |
| 337 | Return type: clearSiriData: | **STATIC PASS** | void |
| 338 | Argument count: clearSiriData: | **STATIC PASS** | 1 |
| 339 | Selector spelling: clearSiriData: | **STATIC PASS** | clearSiriData: |
| 340 | External caller: clearSiriData: | **STATIC PASS** | 0 |
| 341 | Internal message send: clearSiriData: | **STATIC PASS** | 0 |
| 342 | Behavior target: clearSiriData: | **STATIC PASS** | completeAppDataWipe: |
| 343 | Body hash: clearSiriData: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 344 | Runtime selector expectation: clearSiriData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 345 | New-source visibility: clearSiriData: | **STATIC PASS** | declaration absent from current public header |
| 346 | Alias inventory: clearSystemLoggerData: | **STATIC PASS** | authorized exact selector |
| 347 | Public declaration absence: clearSystemLoggerData: | **STATIC PASS** | 0 |
| 348 | Private declaration: clearSystemLoggerData: | **STATIC PASS** | 1 |
| 349 | Implementation definition: clearSystemLoggerData: | **STATIC PASS** | 1 |
| 350 | Return type: clearSystemLoggerData: | **STATIC PASS** | void |
| 351 | Argument count: clearSystemLoggerData: | **STATIC PASS** | 1 |
| 352 | Selector spelling: clearSystemLoggerData: | **STATIC PASS** | clearSystemLoggerData: |
| 353 | External caller: clearSystemLoggerData: | **STATIC PASS** | 0 |
| 354 | Internal message send: clearSystemLoggerData: | **STATIC PASS** | 0 |
| 355 | Behavior target: clearSystemLoggerData: | **STATIC PASS** | clearSystemLogs: |
| 356 | Body hash: clearSystemLoggerData: | **STATIC PASS** | 1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5 |
| 357 | Runtime selector expectation: clearSystemLoggerData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 358 | New-source visibility: clearSystemLoggerData: | **STATIC PASS** | declaration absent from current public header |
| 359 | Alias inventory: clearASLLogs: | **STATIC PASS** | authorized exact selector |
| 360 | Public declaration absence: clearASLLogs: | **STATIC PASS** | 0 |
| 361 | Private declaration: clearASLLogs: | **STATIC PASS** | 1 |
| 362 | Implementation definition: clearASLLogs: | **STATIC PASS** | 1 |
| 363 | Return type: clearASLLogs: | **STATIC PASS** | void |
| 364 | Argument count: clearASLLogs: | **STATIC PASS** | 1 |
| 365 | Selector spelling: clearASLLogs: | **STATIC PASS** | clearASLLogs: |
| 366 | External caller: clearASLLogs: | **STATIC PASS** | 0 |
| 367 | Internal message send: clearASLLogs: | **STATIC PASS** | 0 |
| 368 | Behavior target: clearASLLogs: | **STATIC PASS** | clearSystemLogs: |
| 369 | Body hash: clearASLLogs: | **STATIC PASS** | 1c1cc8d0c3572cbe663d0fca7f18ede41c1fd036e4bfdb132eaec73a5b7d91d5 |
| 370 | Runtime selector expectation: clearASLLogs: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 371 | New-source visibility: clearASLLogs: | **STATIC PASS** | declaration absent from current public header |
| 372 | Alias inventory: clearPasteboardData: | **STATIC PASS** | authorized exact selector |
| 373 | Public declaration absence: clearPasteboardData: | **STATIC PASS** | 0 |
| 374 | Private declaration: clearPasteboardData: | **STATIC PASS** | 1 |
| 375 | Implementation definition: clearPasteboardData: | **STATIC PASS** | 1 |
| 376 | Return type: clearPasteboardData: | **STATIC PASS** | void |
| 377 | Argument count: clearPasteboardData: | **STATIC PASS** | 1 |
| 378 | Selector spelling: clearPasteboardData: | **STATIC PASS** | clearPasteboardData: |
| 379 | External caller: clearPasteboardData: | **STATIC PASS** | 0 |
| 380 | Internal message send: clearPasteboardData: | **STATIC PASS** | 0 |
| 381 | Behavior target: clearPasteboardData: | **STATIC PASS** | clearClipboard |
| 382 | Body hash: clearPasteboardData: | **STATIC PASS** | 03992335489eed972b0a794c182f0ac1b6ded0c6db0f47f7ca4e21bce4751601 |
| 383 | Runtime selector expectation: clearPasteboardData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 384 | New-source visibility: clearPasteboardData: | **STATIC PASS** | declaration absent from current public header |
| 385 | Alias inventory: clearURLCache: | **STATIC PASS** | authorized exact selector |
| 386 | Public declaration absence: clearURLCache: | **STATIC PASS** | 0 |
| 387 | Private declaration: clearURLCache: | **STATIC PASS** | 1 |
| 388 | Implementation definition: clearURLCache: | **STATIC PASS** | 1 |
| 389 | Return type: clearURLCache: | **STATIC PASS** | void |
| 390 | Argument count: clearURLCache: | **STATIC PASS** | 1 |
| 391 | Selector spelling: clearURLCache: | **STATIC PASS** | clearURLCache: |
| 392 | External caller: clearURLCache: | **STATIC PASS** | 0 |
| 393 | Internal message send: clearURLCache: | **STATIC PASS** | 0 |
| 394 | Behavior target: clearURLCache: | **STATIC PASS** | completeAppDataWipe: |
| 395 | Body hash: clearURLCache: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 396 | Runtime selector expectation: clearURLCache: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 397 | New-source visibility: clearURLCache: | **STATIC PASS** | declaration absent from current public header |
| 398 | Alias inventory: clearBackgroundAssets: | **STATIC PASS** | authorized exact selector |
| 399 | Public declaration absence: clearBackgroundAssets: | **STATIC PASS** | 0 |
| 400 | Private declaration: clearBackgroundAssets: | **STATIC PASS** | 1 |
| 401 | Implementation definition: clearBackgroundAssets: | **STATIC PASS** | 1 |
| 402 | Return type: clearBackgroundAssets: | **STATIC PASS** | void |
| 403 | Argument count: clearBackgroundAssets: | **STATIC PASS** | 1 |
| 404 | Selector spelling: clearBackgroundAssets: | **STATIC PASS** | clearBackgroundAssets: |
| 405 | External caller: clearBackgroundAssets: | **STATIC PASS** | 0 |
| 406 | Internal message send: clearBackgroundAssets: | **STATIC PASS** | 0 |
| 407 | Behavior target: clearBackgroundAssets: | **STATIC PASS** | completeAppDataWipe: |
| 408 | Body hash: clearBackgroundAssets: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 409 | Runtime selector expectation: clearBackgroundAssets: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 410 | New-source visibility: clearBackgroundAssets: | **STATIC PASS** | declaration absent from current public header |
| 411 | Alias inventory: clearSharedStorage: | **STATIC PASS** | authorized exact selector |
| 412 | Public declaration absence: clearSharedStorage: | **STATIC PASS** | 0 |
| 413 | Private declaration: clearSharedStorage: | **STATIC PASS** | 1 |
| 414 | Implementation definition: clearSharedStorage: | **STATIC PASS** | 1 |
| 415 | Return type: clearSharedStorage: | **STATIC PASS** | void |
| 416 | Argument count: clearSharedStorage: | **STATIC PASS** | 1 |
| 417 | Selector spelling: clearSharedStorage: | **STATIC PASS** | clearSharedStorage: |
| 418 | External caller: clearSharedStorage: | **STATIC PASS** | 0 |
| 419 | Internal message send: clearSharedStorage: | **STATIC PASS** | 0 |
| 420 | Behavior target: clearSharedStorage: | **STATIC PASS** | completeAppDataWipe: |
| 421 | Body hash: clearSharedStorage: | **STATIC PASS** | a1475976c857ecd97b8a0121932b5085476fb6d199872be6ec568cd29abd9c56 |
| 422 | Runtime selector expectation: clearSharedStorage: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 423 | New-source visibility: clearSharedStorage: | **STATIC PASS** | declaration absent from current public header |
| 424 | Alias inventory: clearAppStateData: | **STATIC PASS** | authorized exact selector |
| 425 | Public declaration absence: clearAppStateData: | **STATIC PASS** | 0 |
| 426 | Private declaration: clearAppStateData: | **STATIC PASS** | 1 |
| 427 | Implementation definition: clearAppStateData: | **STATIC PASS** | 1 |
| 428 | Return type: clearAppStateData: | **STATIC PASS** | void |
| 429 | Argument count: clearAppStateData: | **STATIC PASS** | 1 |
| 430 | Selector spelling: clearAppStateData: | **STATIC PASS** | clearAppStateData: |
| 431 | External caller: clearAppStateData: | **STATIC PASS** | 0 |
| 432 | Internal message send: clearAppStateData: | **STATIC PASS** | 0 |
| 433 | Behavior target: clearAppStateData: | **STATIC PASS** | _internalClearAppStateData: |
| 434 | Body hash: clearAppStateData: | **STATIC PASS** | e64673d035f0d5ab67e3e1a7d0702cd6d5316bc140166904668936d188fb1c9a |
| 435 | Runtime selector expectation: clearAppStateData: | **DEVICE PENDING** | definition retained; runtime harness unavailable |
| 436 | New-source visibility: clearAppStateData: | **STATIC PASS** | declaration absent from current public header |
| 437 | Retained public selector: clearDataForBundleID:completion: | **STATIC PASS** | exactly one public declaration |
| 438 | Retained source surface: clearDataForBundleID:completion: | **STATIC PASS** | not removed by TASK-6.2 |
| 439 | Retained runtime implementation expectation: clearDataForBundleID:completion: | **STATIC PASS** | behavior suffix unchanged |
| 440 | Retained public selector: hasDataToClear: | **STATIC PASS** | exactly one public declaration |
| 441 | Retained source surface: hasDataToClear: | **STATIC PASS** | not removed by TASK-6.2 |
| 442 | Retained runtime implementation expectation: hasDataToClear: | **STATIC PASS** | behavior suffix unchanged |
| 443 | Retained public selector: completeAppDataWipe: | **STATIC PASS** | exactly one public declaration |
| 444 | Retained source surface: completeAppDataWipe: | **STATIC PASS** | not removed by TASK-6.2 |
| 445 | Retained runtime implementation expectation: completeAppDataWipe: | **STATIC PASS** | behavior suffix unchanged |
| 446 | Retained public selector: cleanIconStatePlist: | **STATIC PASS** | exactly one public declaration |
| 447 | Retained source surface: cleanIconStatePlist: | **STATIC PASS** | not removed by TASK-6.2 |
| 448 | Retained runtime implementation expectation: cleanIconStatePlist: | **STATIC PASS** | behavior suffix unchanged |
| 449 | Retained public selector: cleanSiriAnalyticsDatabase: | **STATIC PASS** | exactly one public declaration |
| 450 | Retained source surface: cleanSiriAnalyticsDatabase: | **STATIC PASS** | not removed by TASK-6.2 |
| 451 | Retained runtime implementation expectation: cleanSiriAnalyticsDatabase: | **STATIC PASS** | behavior suffix unchanged |
| 452 | Retained public selector: cleanLaunchServicesDatabase: | **STATIC PASS** | exactly one public declaration |
| 453 | Retained source surface: cleanLaunchServicesDatabase: | **STATIC PASS** | not removed by TASK-6.2 |
| 454 | Retained runtime implementation expectation: cleanLaunchServicesDatabase: | **STATIC PASS** | behavior suffix unchanged |
| 455 | Retained public selector: refreshSystemServices | **STATIC PASS** | exactly one public declaration |
| 456 | Retained source surface: refreshSystemServices | **STATIC PASS** | not removed by TASK-6.2 |
| 457 | Retained runtime implementation expectation: refreshSystemServices | **STATIC PASS** | behavior suffix unchanged |
| 458 | Retained public selector: clearAppReceiptData:withBundleUUID: | **STATIC PASS** | exactly one public declaration |
| 459 | Retained source surface: clearAppReceiptData:withBundleUUID: | **STATIC PASS** | not removed by TASK-6.2 |
| 460 | Retained runtime implementation expectation: clearAppReceiptData:withBundleUUID: | **STATIC PASS** | behavior suffix unchanged |
| 461 | Retained public selector: clearSystemLogs: | **STATIC PASS** | exactly one public declaration |
| 462 | Retained source surface: clearSystemLogs: | **STATIC PASS** | not removed by TASK-6.2 |
| 463 | Retained runtime implementation expectation: clearSystemLogs: | **STATIC PASS** | behavior suffix unchanged |
| 464 | Retained public selector: clearICloudData: | **STATIC PASS** | exactly one public declaration |
| 465 | Retained source surface: clearICloudData: | **STATIC PASS** | not removed by TASK-6.2 |
| 466 | Retained runtime implementation expectation: clearICloudData: | **STATIC PASS** | behavior suffix unchanged |
| 467 | Retained public selector: clearMediaData: | **STATIC PASS** | exactly one public declaration |
| 468 | Retained source surface: clearMediaData: | **STATIC PASS** | not removed by TASK-6.2 |
| 469 | Retained runtime implementation expectation: clearMediaData: | **STATIC PASS** | behavior suffix unchanged |
| 470 | Retained public selector: clearHealthData: | **STATIC PASS** | exactly one public declaration |
| 471 | Retained source surface: clearHealthData: | **STATIC PASS** | not removed by TASK-6.2 |
| 472 | Retained runtime implementation expectation: clearHealthData: | **STATIC PASS** | behavior suffix unchanged |
| 473 | Retained public selector: clearSafariData: | **STATIC PASS** | exactly one public declaration |
| 474 | Retained source surface: clearSafariData: | **STATIC PASS** | not removed by TASK-6.2 |
| 475 | Retained runtime implementation expectation: clearSafariData: | **STATIC PASS** | behavior suffix unchanged |
| 476 | Retained public selector: clearURLCredentialsForBundleID: | **STATIC PASS** | exactly one public declaration |
| 477 | Retained source surface: clearURLCredentialsForBundleID: | **STATIC PASS** | not removed by TASK-6.2 |
| 478 | Retained runtime implementation expectation: clearURLCredentialsForBundleID: | **STATIC PASS** | behavior suffix unchanged |
| 479 | Retained public selector: clearSpotlightIndexes: | **STATIC PASS** | exactly one public declaration |
| 480 | Retained source surface: clearSpotlightIndexes: | **STATIC PASS** | not removed by TASK-6.2 |
| 481 | Retained runtime implementation expectation: clearSpotlightIndexes: | **STATIC PASS** | behavior suffix unchanged |
| 482 | Retained public selector: clearClipboard | **STATIC PASS** | exactly one public declaration |
| 483 | Retained source surface: clearClipboard | **STATIC PASS** | not removed by TASK-6.2 |
| 484 | Retained runtime implementation expectation: clearClipboard | **STATIC PASS** | behavior suffix unchanged |
| 485 | Retained public selector: _internalClearAppStateData: | **STATIC PASS** | exactly one public declaration |
| 486 | Retained source surface: _internalClearAppStateData: | **STATIC PASS** | not removed by TASK-6.2 |
| 487 | Retained runtime implementation expectation: _internalClearAppStateData: | **STATIC PASS** | behavior suffix unchanged |
| 488 | Retained public selector: verifyDataCleared: | **STATIC PASS** | exactly one public declaration |
| 489 | Retained source surface: verifyDataCleared: | **STATIC PASS** | not removed by TASK-6.2 |
| 490 | Retained runtime implementation expectation: verifyDataCleared: | **STATIC PASS** | behavior suffix unchanged |
| 491 | Retained public selector: getDataUsage: | **STATIC PASS** | exactly one public declaration |
| 492 | Retained source surface: getDataUsage: | **STATIC PASS** | not removed by TASK-6.2 |
| 493 | Retained runtime implementation expectation: getDataUsage: | **STATIC PASS** | behavior suffix unchanged |
| 494 | Retained public selector: findDataContainerUUIDForBundleID: | **STATIC PASS** | exactly one public declaration |
| 495 | Retained source surface: findDataContainerUUIDForBundleID: | **STATIC PASS** | not removed by TASK-6.2 |
| 496 | Retained runtime implementation expectation: findDataContainerUUIDForBundleID: | **STATIC PASS** | behavior suffix unchanged |
| 497 | Retained public selector: findBundleContainerUUIDForBundleID: | **STATIC PASS** | exactly one public declaration |
| 498 | Retained source surface: findBundleContainerUUIDForBundleID: | **STATIC PASS** | not removed by TASK-6.2 |
| 499 | Retained runtime implementation expectation: findBundleContainerUUIDForBundleID: | **STATIC PASS** | behavior suffix unchanged |
| 500 | Retained public selector: findGroupContainerUUIDsForBundleID: | **STATIC PASS** | exactly one public declaration |
| 501 | Retained source surface: findGroupContainerUUIDsForBundleID: | **STATIC PASS** | not removed by TASK-6.2 |
| 502 | Retained runtime implementation expectation: findGroupContainerUUIDsForBundleID: | **STATIC PASS** | behavior suffix unchanged |
| 503 | Retained public selector: findExtensionDataContainersForBundleID: | **STATIC PASS** | exactly one public declaration |
| 504 | Retained source surface: findExtensionDataContainersForBundleID: | **STATIC PASS** | not removed by TASK-6.2 |
| 505 | Retained runtime implementation expectation: findExtensionDataContainersForBundleID: | **STATIC PASS** | behavior suffix unchanged |
| 506 | Retained public selector: hasKeychainItemsForBundleID: | **STATIC PASS** | exactly one public declaration |
| 507 | Retained source surface: hasKeychainItemsForBundleID: | **STATIC PASS** | not removed by TASK-6.2 |
| 508 | Retained runtime implementation expectation: hasKeychainItemsForBundleID: | **STATIC PASS** | behavior suffix unchanged |
| 509 | TASK-6.1 public protection: performFullCleanup: | **STATIC PASS** | 0 |
| 510 | TASK-6.1 private protection: performFullCleanup: | **STATIC PASS** | 1 |
| 511 | TASK-6.1 definition protection: performFullCleanup: | **STATIC PASS** | 1 |
| 512 | TASK-6.1 public protection: performAggressiveCleanupFor: | **STATIC PASS** | 0 |
| 513 | TASK-6.1 private protection: performAggressiveCleanupFor: | **STATIC PASS** | 1 |
| 514 | TASK-6.1 definition protection: performAggressiveCleanupFor: | **STATIC PASS** | 1 |
| 515 | TASK-6.1 public protection: completelyWipeContainer: | **STATIC PASS** | 0 |
| 516 | TASK-6.1 private protection: completelyWipeContainer: | **STATIC PASS** | 1 |
| 517 | TASK-6.1 definition protection: completelyWipeContainer: | **STATIC PASS** | 1 |
| 518 | TASK-6.1 public protection: securelyWipeFile: | **STATIC PASS** | 0 |
| 519 | TASK-6.1 private protection: securelyWipeFile: | **STATIC PASS** | 1 |
| 520 | TASK-6.1 definition protection: securelyWipeFile: | **STATIC PASS** | 1 |
| 521 | TASK-6.1 public protection: fixPermissionsAndRemovePath: | **STATIC PASS** | 0 |
| 522 | TASK-6.1 private protection: fixPermissionsAndRemovePath: | **STATIC PASS** | 1 |
| 523 | TASK-6.1 definition protection: fixPermissionsAndRemovePath: | **STATIC PASS** | 1 |
| 524 | TASK-6.1 public protection: fixPermissionsForPath: | **STATIC PASS** | 0 |
| 525 | TASK-6.1 private protection: fixPermissionsForPath: | **STATIC PASS** | 1 |
| 526 | TASK-6.1 definition protection: fixPermissionsForPath: | **STATIC PASS** | 1 |
| 527 | TASK-6.1 public protection: clearAppCache: | **STATIC PASS** | 0 |
| 528 | TASK-6.1 private protection: clearAppCache: | **STATIC PASS** | 1 |
| 529 | TASK-6.1 definition protection: clearAppCache: | **STATIC PASS** | 1 |
| 530 | TASK-6.1 public protection: clearAppPreferences: | **STATIC PASS** | 0 |
| 531 | TASK-6.1 private protection: clearAppPreferences: | **STATIC PASS** | 1 |
| 532 | TASK-6.1 definition protection: clearAppPreferences: | **STATIC PASS** | 1 |
| 533 | TASK-6.1 public protection: clearAppCookies: | **STATIC PASS** | 0 |
| 534 | TASK-6.1 private protection: clearAppCookies: | **STATIC PASS** | 1 |
| 535 | TASK-6.1 definition protection: clearAppCookies: | **STATIC PASS** | 1 |
| 536 | TASK-6.1 public protection: clearAppWebKitData: | **STATIC PASS** | 0 |
| 537 | TASK-6.1 private protection: clearAppWebKitData: | **STATIC PASS** | 1 |
| 538 | TASK-6.1 definition protection: clearAppWebKitData: | **STATIC PASS** | 1 |
| 539 | TASK-6.1 public protection: clearAppGroupData: | **STATIC PASS** | 0 |
| 540 | TASK-6.1 private protection: clearAppGroupData: | **STATIC PASS** | 1 |
| 541 | TASK-6.1 definition protection: clearAppGroupData: | **STATIC PASS** | 1 |
| 542 | TASK-6.1 public protection: clearPluginKitData: | **STATIC PASS** | 0 |
| 543 | TASK-6.1 private protection: clearPluginKitData: | **STATIC PASS** | 1 |
| 544 | TASK-6.1 definition protection: clearPluginKitData: | **STATIC PASS** | 1 |
| 545 | TASK-6.1 public protection: _internalClearEncryptedData: | **STATIC PASS** | 0 |
| 546 | TASK-6.1 private protection: _internalClearEncryptedData: | **STATIC PASS** | 1 |
| 547 | TASK-6.1 definition protection: _internalClearEncryptedData: | **STATIC PASS** | 1 |
| 548 | TASK-6.1 public protection: secureDataWipe: | **STATIC PASS** | 0 |
| 549 | TASK-6.1 private protection: secureDataWipe: | **STATIC PASS** | 1 |
| 550 | TASK-6.1 definition protection: secureDataWipe: | **STATIC PASS** | 1 |
| 551 | TASK-6.1 public protection: clearAppKeychain: | **STATIC PASS** | 0 |
| 552 | TASK-6.1 private protection: clearAppKeychain: | **STATIC PASS** | 1 |
| 553 | TASK-6.1 definition protection: clearAppKeychain: | **STATIC PASS** | 1 |
| 554 | TASK-6.1 public protection: clearKeychainData: | **STATIC PASS** | 0 |
| 555 | TASK-6.1 private protection: clearKeychainData: | **STATIC PASS** | 1 |
| 556 | TASK-6.1 definition protection: clearKeychainData: | **STATIC PASS** | 1 |
| 557 | TASK-6.1 public protection: clearKeychainItemsForBundleID: | **STATIC PASS** | 0 |
| 558 | TASK-6.1 private protection: clearKeychainItemsForBundleID: | **STATIC PASS** | 1 |
| 559 | TASK-6.1 definition protection: clearKeychainItemsForBundleID: | **STATIC PASS** | 1 |
| 560 | TASK-6.1 public protection: universalKeychainWipeForBundleID: | **STATIC PASS** | 0 |
| 561 | TASK-6.1 private protection: universalKeychainWipeForBundleID: | **STATIC PASS** | 1 |
| 562 | TASK-6.1 definition protection: universalKeychainWipeForBundleID: | **STATIC PASS** | 1 |
| 563 | Quarantine shim body: - (void)finalSweepForContainer:(NSString *)containerPath | **STATIC PASS** | 8bf5998f3e6fb1a8136aaf3f1ba456119949591ab94e9b4f730e724da54a5d31 |
| 564 | Quarantine logger count: - (void)finalSweepForContainer:(NSString *)containerPath | **STATIC PASS** | exactly one selector-only call |
| 565 | Quarantine shim body: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs isRootless:(BOOL)isRootless | **STATIC PASS** | 6036d3ba13ed54f81d117a1f1d18476d7c0534a12c0a9f7f96c26d63cb7e27a7 |
| 566 | Quarantine logger count: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs isRootless:(BOOL)isRootless | **STATIC PASS** | exactly one selector-only call |
| 567 | Quarantine shim body: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs | **STATIC PASS** | 66bdc618861e2e6aaa655e6d6820af19e7404f720326d71aded8ad885e9f3d03 |
| 568 | Quarantine logger count: - (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs | **STATIC PASS** | exactly one selector-only call |
| 569 | Quarantine shim body: - (void)fixPermissionsAndRemovePath:(NSString *)path | **STATIC PASS** | ccd3085b30203aa54692a33d95961d3977a27fa6b48286dbb4e543b951dbed91 |
| 570 | Quarantine logger count: - (void)fixPermissionsAndRemovePath:(NSString *)path | **STATIC PASS** | exactly one selector-only call |
| 571 | Quarantine shim body: - (void)wipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure | **STATIC PASS** | 5afcba9af309591d61aa6cafa30f53837b993c56b1040c321f728b0b04ec3b46 |
| 572 | Quarantine logger count: - (void)wipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure | **STATIC PASS** | exactly one selector-only call |
| 573 | Quarantine shim body: - (BOOL)securelyWipeFile:(NSString *)path | **STATIC PASS** | 54ccc0cca4ca5dd821aa5c167ffe93bba901e2b1d6b57e8f6be9f5bfe2d61c82 |
| 574 | Quarantine logger count: - (BOOL)securelyWipeFile:(NSString *)path | **STATIC PASS** | exactly one selector-only call |
| 575 | Quarantine shim body: - (void)clearKeychainItemsForBundleID:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 576 | Quarantine logger count: - (void)clearKeychainItemsForBundleID:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 577 | Quarantine shim body: - (void)universalKeychainWipeForBundleID:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 578 | Quarantine logger count: - (void)universalKeychainWipeForBundleID:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 579 | Quarantine shim body: - (void)clearPluginKitData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 580 | Quarantine logger count: - (void)clearPluginKitData:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 581 | Quarantine shim body: - (void)fastWipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure timeoutSec:(int)timeoutSec | **STATIC PASS** | a475c6fd241fa8b0a8f98fbe752d7eaf186269633f08fb32b7c7aab9fd10a5b8 |
| 582 | Quarantine logger count: - (void)fastWipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure timeoutSec:(int)timeoutSec | **STATIC PASS** | exactly one selector-only call |
| 583 | Quarantine shim body: - (void)performFullCleanup:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 584 | Quarantine logger count: - (void)performFullCleanup:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 585 | Quarantine shim body: - (void)clearAppCache:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 586 | Quarantine logger count: - (void)clearAppCache:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 587 | Quarantine shim body: - (void)clearAppPreferences:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 588 | Quarantine logger count: - (void)clearAppPreferences:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 589 | Quarantine shim body: - (void)clearAppCookies:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 590 | Quarantine logger count: - (void)clearAppCookies:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 591 | Quarantine shim body: - (void)clearAppWebKitData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 592 | Quarantine logger count: - (void)clearAppWebKitData:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 593 | Quarantine shim body: - (void)clearAppKeychain:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 594 | Quarantine logger count: - (void)clearAppKeychain:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 595 | Quarantine shim body: - (void)clearAppGroupData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 596 | Quarantine logger count: - (void)clearAppGroupData:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 597 | Quarantine shim body: - (void)clearKeychainData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 598 | Quarantine logger count: - (void)clearKeychainData:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 599 | Quarantine shim body: - (void)secureDataWipe:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 600 | Quarantine logger count: - (void)secureDataWipe:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 601 | Quarantine shim body: - (void)wipeWebKitDirectoryContents:(NSString *)path | **STATIC PASS** | ccd3085b30203aa54692a33d95961d3977a27fa6b48286dbb4e543b951dbed91 |
| 602 | Quarantine logger count: - (void)wipeWebKitDirectoryContents:(NSString *)path | **STATIC PASS** | exactly one selector-only call |
| 603 | Quarantine shim body: - (void)_internalClearEncryptedData:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 604 | Quarantine logger count: - (void)_internalClearEncryptedData:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 605 | Quarantine shim body: - (void)clearExtensionContainers:(NSArray *)extensionInfo forApp:(NSString *)bundleID | **STATIC PASS** | 9b019b785e79ddf54ebe4bc127bd73270454978924326a0dc16bd7a338bd653f |
| 606 | Quarantine logger count: - (void)clearExtensionContainers:(NSArray *)extensionInfo forApp:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 607 | Quarantine shim body: - (void)fixPermissionsForPath:(NSString *)path | **STATIC PASS** | ccd3085b30203aa54692a33d95961d3977a27fa6b48286dbb4e543b951dbed91 |
| 608 | Quarantine logger count: - (void)fixPermissionsForPath:(NSString *)path | **STATIC PASS** | exactly one selector-only call |
| 609 | Quarantine shim body: - (void)performAggressiveCleanupFor:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 610 | Quarantine logger count: - (void)performAggressiveCleanupFor:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 611 | Quarantine shim body: - (void)completelyWipeContainer:(NSString *)containerPath | **STATIC PASS** | 8bf5998f3e6fb1a8136aaf3f1ba456119949591ab94e9b4f730e724da54a5d31 |
| 612 | Quarantine logger count: - (void)completelyWipeContainer:(NSString *)containerPath | **STATIC PASS** | exactly one selector-only call |
| 613 | Quarantine shim body: - (void)_wipeRelatedDataContainersForBundleIDs:(NSArray<NSString *> *)bundleIDs | **STATIC PASS** | 2ea3553b6290715ec30c6aa6eca5681fb09840e7eff6d9230be4629fae549fa5 |
| 614 | Quarantine logger count: - (void)_wipeRelatedDataContainersForBundleIDs:(NSArray<NSString *> *)bundleIDs | **STATIC PASS** | exactly one selector-only call |
| 615 | Quarantine shim body: - (void)_wipeRelatedSystemGroupContainersForIdentifiers:(NSArray<NSString *> *)idents | **STATIC PASS** | 878bc17cd0413a43cb04eec8fc6162a314b1420b7f82819df5b720cab765c2f3 |
| 616 | Quarantine logger count: - (void)_wipeRelatedSystemGroupContainersForIdentifiers:(NSArray<NSString *> *)idents | **STATIC PASS** | exactly one selector-only call |
| 617 | Quarantine shim body: - (void)_wipeContainersInBasePaths:(NSArray<NSString *> *)bases                matchingSubstrings:(NSArray<NSString *> *)needles                              tag:(NSString *)tag | **STATIC PASS** | 81a20cb1168f85b995c38b9b2c1f91bb0defffb90b576c4971c13a5945599dcd |
| 618 | Quarantine logger count: - (void)_wipeContainersInBasePaths:(NSArray<NSString *> *)bases                matchingSubstrings:(NSArray<NSString *> *)needles                              tag:(NSString *)tag | **STATIC PASS** | exactly one selector-only call |
| 619 | Quarantine shim body: - (void)_wipeDataContainersByIdentifierPrefixOrSubstring:(NSArray<NSString *> *)prefixes                                               substrings:(NSArray<NSString *> *)substrings                                                     tag:(NSString *)tag | **STATIC PASS** | bcef071facacb4859ca4a07c3781c78597e7ea59fa7a9e676cbca457f79774cf |
| 620 | Quarantine logger count: - (void)_wipeDataContainersByIdentifierPrefixOrSubstring:(NSArray<NSString *> *)prefixes                                               substrings:(NSArray<NSString *> *)substrings                                                     tag:(NSString *)tag | **STATIC PASS** | exactly one selector-only call |
| 621 | Quarantine shim body: - (void)_scrubWebKitStateInSharedContainerBase:(NSString *)base tag:(NSString *)tag | **STATIC PASS** | 97fd923baeac83d2cc53b77680fdb0e2d5977e5d3bb287942296ce945ab19f0d |
| 622 | Quarantine logger count: - (void)_scrubWebKitStateInSharedContainerBase:(NSString *)base tag:(NSString *)tag | **STATIC PASS** | exactly one selector-only call |
| 623 | Quarantine shim body: - (void)cleanAppGroupContainers:(NSString *)bundleID | **STATIC PASS** | 2268650a7380ef2657929dd90ef543a3173ad7a05b063f7b8f77776bdabe65d0 |
| 624 | Quarantine logger count: - (void)cleanAppGroupContainers:(NSString *)bundleID | **STATIC PASS** | exactly one selector-only call |
| 625 | Quarantine shim body: - (void)cleanAppSpecificFilesInSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | 284b45efadf7b00cb3524d7cb5521ed7d31c2360f3aaaf4f390f891edd024569 |
| 626 | Quarantine logger count: - (void)cleanAppSpecificFilesInSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | exactly one selector-only call |
| 627 | Quarantine shim body: - (void)deepCleanSystemSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | 284b45efadf7b00cb3524d7cb5521ed7d31c2360f3aaaf4f390f891edd024569 |
| 628 | Quarantine logger count: - (void)deepCleanSystemSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName | **STATIC PASS** | exactly one selector-only call |
| 629 | Protected hash: AppEntitlementsReader.h | **STATIC PASS** | c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e |
| 630 | Protected hash: AppEntitlementsReader.m | **STATIC PASS** | 0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797 |
| 631 | Protected hash: PXDataContainerResolver.h | **STATIC PASS** | b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30 |
| 632 | Protected hash: PXDataContainerResolver.m | **STATIC PASS** | cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365 |
| 633 | Protected hash: PXDestructivePathValidator.h | **STATIC PASS** | 542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a |
| 634 | Protected hash: PXDestructivePathValidator.m | **STATIC PASS** | f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb |
| 635 | Protected hash: PXClearRequest.h | **STATIC PASS** | d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b |
| 636 | Protected hash: PXClearRequest.m | **STATIC PASS** | afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790 |
| 637 | Protected hash: PXClearResult.h | **STATIC PASS** | cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592 |
| 638 | Protected hash: PXClearResult.m | **STATIC PASS** | 0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715 |
| 639 | Protected hash: CommandRunner.h | **STATIC PASS** | 63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf |
| 640 | Protected hash: CommandRunner.m | **STATIC PASS** | 2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030 |
| 641 | Protected hash: AppGroupContainerResolver.h | **STATIC PASS** | c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97 |
| 642 | Protected hash: AppGroupContainerResolver.m | **STATIC PASS** | 11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1 |
| 643 | Protected hash: AppDataBackupManager.h | **STATIC PASS** | b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75 |
| 644 | Protected hash: AppDataBackupManager.m | **STATIC PASS** | 61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028 |
| 645 | Protected hash: ProjectXViewController.m | **STATIC PASS** | b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162 |
| 646 | Protected hash: ProfileManagerViewController.m | **STATIC PASS** | a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a |
| 647 | Protected hash: AppDataBackupRestoreViewController.h | **STATIC PASS** | b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf |
| 648 | Protected hash: AppDataBackupRestoreViewController.m | **STATIC PASS** | 23c964fac0189119c500665a700fe1fb7dafa77fd63779dccaa9e084cefa26c5 |
| 649 | Protected hash: main.m | **STATIC PASS** | 7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da |
| 650 | Protected hash: Makefile | **STATIC PASS** | b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa |
| 651 | Protected hash: docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md | **STATIC PASS** | a7b2ffe36ba3c6682a4ea160e82486b87243ec4bd614e0f6655dcd17946efb33 |
| 652 | Protected hash: docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md | **STATIC PASS** | 9e9c817976947d06e289559e1bc15d6959f98d713983407c329d48b6935ec565 |
| 653 | Protected hash: docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md | **STATIC PASS** | a668acd27522275a1c5580bb48d99b5a569879a2aa5f953e2289d46913ff5903 |
| 654 | Protected hash: docs/backup-restore-hardening/reports/TASK-6.1-REPORT.md | **STATIC PASS** | 4c332a937bf44d125c796842a78564a2d3dd92529132ff73f400a589b4570354 |
| 655 | Protected hash: docs/backup-restore-hardening/reports/TASK-5.1-REPORT.md | **STATIC PASS** | 736d6a38719daf7c9384cca8f728b0ed7078e65f1ba935c5cb32cc34914e4fd6 |
| 656 | Protected hash: docs/backup-restore-hardening/reports/TASK-5.2-REPORT.md | **STATIC PASS** | b5c76629dbe35ac81fd7081a1195ddeda77cef7fe1d6ce424f5cbdd5ab84202c |
| 657 | Protected hash: docs/backup-restore-hardening/reports/TASK-5.3-REPORT.md | **STATIC PASS** | 8bf6b4cc86521f9cb0ea8e1a38e9cf6f619fa3e377dd137396fa055b066154a8 |
| 658 | Protected hash: docs/backup-restore-hardening/reports/TASK-5.4-REPORT.md | **STATIC PASS** | 8c40fca455c3e0973d5ef20f770777f2e439e551d0cd195b10c5720f46228e19 |
| 659 | Typed/compat body bytes: clearDataForBundleID:completion: | **STATIC PASS** | 15419 |
| 660 | Typed/compat body hash: clearDataForBundleID:completion: | **STATIC PASS** | 25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1 |
| 661 | Typed/compat body bytes: completeAppDataWipe: | **STATIC PASS** | 1182 |
| 662 | Typed/compat body hash: completeAppDataWipe: | **STATIC PASS** | 204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644 |
| 663 | Typed/compat body bytes: clearAppData: | **STATIC PASS** | 46 |
| 664 | Typed/compat body hash: clearAppData: | **STATIC PASS** | b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb |
| 665 | Typed/compat body bytes: performSecondaryCleanup: | **STATIC PASS** | 46 |
| 666 | Typed/compat body hash: performSecondaryCleanup: | **STATIC PASS** | b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb |
| 667 | Typed/compat body bytes: _wipeMobileSafariSystemStores | **STATIC PASS** | 14098 |
| 668 | Typed/compat body hash: _wipeMobileSafariSystemStores | **STATIC PASS** | 077ed7ea110e0fde1ed40f2fa852803159eaa7f9d1493c34af377ab3408636bc |
| 669 | Canonical caller count: clearDataForBundleID: | **STATIC PASS** | 5 |
| 670 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | main.m:537:[cleaner clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 671 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:3924:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 672 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:6446:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 673 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:6632:[[AppDataCleaner sharedManager] clearDataForBundleID:manifestBundleID completion:^(BOOL clearSuccess, NSError *clearError) { |
| 674 | Canonical caller: clearDataForBundleID: | **STATIC PASS** | ProjectXViewController.m:6697:[[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) { |
| 675 | Canonical caller count: hasDataToClear: | **STATIC PASS** | 2 |
| 676 | Canonical caller: hasDataToClear: | **STATIC PASS** | main.m:533:if ([cleaner hasDataToClear:bundleID]) { |
| 677 | Canonical caller: hasDataToClear: | **STATIC PASS** | ProjectXViewController.m:3749:foundData = [[AppDataCleaner sharedManager] hasDataToClear:bundleID]; |
| 678 | Canonical caller count: verifyDataCleared: | **STATIC PASS** | 1 |
| 679 | Canonical caller: verifyDataCleared: | **STATIC PASS** | main.m:545:[cleaner verifyDataCleared:bundleID]; |
| 680 | Canonical caller count: findBundleContainerUUIDForBundleID: | **STATIC PASS** | 1 |
| 681 | Canonical caller: findBundleContainerUUIDForBundleID: | **STATIC PASS** | AppEntitlementsReader.m:201:NSString *bundleUUID = [cleaner findBundleContainerUUIDForBundleID:bundleID]; |
| 682 | Coordinator preservation: docs/backup-restore-hardening/DECISIONS.md | **STATIC PASS** | 601194d5abfa2fade0e0a6c63a213c733618799bbfae0972ccdd641a0975bbe6 |
| 683 | Coordinator preservation: docs/backup-restore-hardening/README.md | **STATIC PASS** | 8a09213977c03f946a206c46cdd28c27a718b0dba017d3c7f7e425e6d0403172 |
| 684 | Coordinator preservation: docs/backup-restore-hardening/ROADMAP.md | **STATIC PASS** | ceccb3ddda2ff901d30f06e74d7102484f0fd2af9281923063e1b6a84371c07e |
| 685 | Coordinator preservation: docs/backup-restore-hardening/STATUS.md | **STATIC PASS** | 1007d679213e55edb01e1671cb607a1ad9daf22d44ee4d9fb554d00d2eeaf82b |
| 686 | Header bytes | **STATIC PASS** | 2228 |
| 687 | Header SHA-256 | **STATIC PASS** | 9c68c07115d32f2c57a1027646d6055d21375842a64064d9cfdcaeaeabe30a86 |
| 688 | Header CRLF | **STATIC PASS** | 66 |
| 689 | Header LF-only | **STATIC PASS** | 0 |
| 690 | Header lone CR | **STATIC PASS** | 0 |
| 691 | Header NUL | **STATIC PASS** | 0 |
| 692 | Header final newline | **STATIC PASS** | absent |
| 693 | Header trailing @end space | **STATIC PASS** | preserved |
| 694 | Source bytes | **STATIC PASS** | 373028 |
| 695 | Source SHA-256 | **STATIC PASS** | 6355110ba6398a927d0f7dc1251b5e47f81f79ef47f60cf977795e451cdc916a |
| 696 | Source CRLF | **STATIC PASS** | 7028 |
| 697 | Source LF-only | **STATIC PASS** | 0 |
| 698 | Source NUL | **STATIC PASS** | 0 |
| 699 | Source final newline | **STATIC PASS** | present |
| 700 | Prefix bytes | **STATIC PASS** | 1078 |
| 701 | Prefix hash | **STATIC PASS** | 1d5b1267fa7664af72739a1054427443332f51b0a68e73681176a15a7a2ae7cb |
| 702 | Extension bytes | **STATIC PASS** | 6062 |
| 703 | Extension hash | **STATIC PASS** | b1209549779f3cc39d29a89f63e3151c530978ac2dac969dd5088295f9330899 |
| 704 | Suffix bytes | **STATIC PASS** | 365888 |
| 705 | Suffix hash | **STATIC PASS** | 62f3f2c91ca16f6346d9cc3d24920186d4862c22469bf1e99a53624bcb38b069 |
| 706 | Alias region bytes | **STATIC PASS** | 4105 |
| 707 | Alias region hash | **STATIC PASS** | 775716caf68c274b8b002901751cc513357eda4057f61a7ecc0fae5391946e6b |
| 708 | Header diff shape | **STATIC PASS** | 0 additions / 32 deletions |
| 709 | Source diff shape | **STATIC PASS** | 33 additions / 0 deletions |
| 710 | Method-body hunks | **STATIC PASS** | 0 |
| 711 | Caller hunks | **STATIC PASS** | 0 |
| 712 | Import hunks | **STATIC PASS** | 0 |
| 713 | Pragma rewrites | **STATIC PASS** | 0 |
| 714 | Comment rewrites | **STATIC PASS** | 0 |
| 715 | Empty-section cleanup | **STATIC PASS** | 0 |
| 716 | New deprecation attributes | **STATIC PASS** | 0 |
| 717 | New unavailable attributes | **STATIC PASS** | 0 |
| 718 | New category | **STATIC PASS** | 0 |
| 719 | New public header | **STATIC PASS** | 0 |
| 720 | New CI guard | **STATIC PASS** | 0 |
| 721 | Selector rename | **STATIC PASS** | 0 |
| 722 | Implementation removal | **STATIC PASS** | 0 |
| 723 | Dynamic runtime forwarding | **STATIC PASS** | 0 |
| 724 | Quarantine shim total | **STATIC PASS** | 33 |
| 725 | Quarantine logger definitions | **STATIC PASS** | 1 |
| 726 | Quarantine logger calls | **STATIC PASS** | 33 |
| 727 | Logger privacy | **STATIC PASS** | SEL selector only |
| 728 | securelyWipeFile result | **STATIC PASS** | return NO |
| 729 | securelyWipeFile inspection | **STATIC PASS** | none added |
| 730 | securelyWipeFile mutation | **STATIC PASS** | none added |
| 731 | Four-scope authority | **STATIC PASS** | completeAppDataWipe body hash unchanged |
| 732 | Five-scope authority | **STATIC PASS** | clearDataForBundleID body hash unchanged |
| 733 | Keychain planning | **STATIC PASS** | protected suffix unchanged |
| 734 | Keychain two-pass accounting | **STATIC PASS** | protected suffix unchanged |
| 735 | Callback precedence | **STATIC PASS** | protected suffix unchanged |
| 736 | One-shot completion | **STATIC PASS** | protected suffix unchanged |
| 737 | Watchdog/background task | **STATIC PASS** | protected suffix unchanged |
| 738 | Final verification | **STATIC PASS** | protected suffix unchanged |
| 739 | Balanced parentheses/brackets/braces | **STATIC PASS** | lexical audit |
| 740 | Comment/string exclusion | **STATIC PASS** | caller parser sanitizes both |
| 741 | Conflict markers | **STATIC PASS** | 0 |
| 742 | C0 controls | **STATIC PASS** | none except tab/newline/CR |
| 743 | git diff --check | **STATIC PASS** | clean |
| 744 | Apple make clean | **NOT RUN** | Theos unavailable on Windows |
| 745 | Apple make | **NOT RUN** | Apple/Theos unavailable on Windows |
| 746 | Apple make package | **NOT RUN** | Apple/Theos unavailable on Windows |
| 747 | arm64 | **NOT RUN** | Apple toolchain unavailable |
| 748 | arm64e | **NOT RUN** | Apple toolchain unavailable |
| 749 | iOS 12 target | **NOT RUN** | Apple toolchain unavailable |
| 750 | instancesRespondToSelector | **DEVICE PENDING** | device/runtime harness unavailable |
| 751 | Old binary ABI messaging | **DEVICE PENDING** | device/runtime harness unavailable |
| 752 | Alias runtime mappings | **DEVICE PENDING** | device/runtime harness unavailable |
| 753 | Canonical Clear runtime | **DEVICE PENDING** | device/runtime harness unavailable |
| 754 | Backup/Restore runtime | **DEVICE PENDING** | device/runtime harness unavailable |
| 755 | TASK-6.2 review | **STATIC PASS** | not created |
| 756 | TASK-6.3 | **STATIC PASS** | not started |
| 757 | Push | **STATIC PASS** | not performed |
| 758 | GitHub Actions | **PENDING** | not run |
| 759 | Suggested state | **READY_FOR_REVIEW** | static gates pass |

Explicit scenario count: **759**

## 33. Commit and push status

- The implementation commit is created only after this report passes final staged gates.
- Push was not performed and is not authorized.

## 34. TASK-6.3 boundary

Stop after the exact three-file TASK-6.2 implementation commit and post-commit evidence. Do not create a TASK-6.2 review, modify coordinator documents, start TASK-6.3 static CI guards, remove implementations, rename selectors, migrate callers, add public API, add tests/fixtures/docs, or push.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
