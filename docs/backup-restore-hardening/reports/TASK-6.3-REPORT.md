# TASK-6.3 REPORT ? Add Static CI Regression Guards

## 1. Result

**STATIC IMPLEMENTATION PASS.** A Python 3.9+ standard-library-only audit tool now protects the accepted Clear, Backup, Restore, Keychain, public/private API, quarantine, alias, permission, manifest, UI and workflow contracts. The workflow runs parser self-tests before the repository audit and runs both before dependency installation or Theos/build work.

No production implementation was modified. No TASK-6.4 work was started. No push was performed.

## 2. User authority

The user supplied TASK-6.3, confirmed TASK-6.2 as AUDIT PASS/COMPLETED and explicitly authorized implementation despite the absent TASK-6.2 review file.

## 3. TASK-6.2 review-file status

`docs/backup-restore-hardening/reviews/TASK-6.2-REVIEW.md` does not exist. The task authority explicitly makes this absence non-blocking for TASK-6.3.

## 4. Baseline

- Required and actual baseline HEAD: `c83584ee6d1ee50ff63202b5c86883fa2d009598`.
- `c83584e phase6(task-6.2): remove ambiguous public aliases`.

## 5. Working-tree preservation

- `docs/backup-restore-hardening/DECISIONS.md` ? `601194d5abfa2fade0e0a6c63a213c733618799bbfae0972ccdd641a0975bbe6` ? PRESERVED / NOT STAGED.
- `docs/backup-restore-hardening/README.md` ? `8a09213977c03f946a206c46cdd28c27a718b0dba017d3c7f7e425e6d0403172` ? PRESERVED / NOT STAGED.
- `docs/backup-restore-hardening/ROADMAP.md` ? `ceccb3ddda2ff901d30f06e74d7102484f0fd2af9281923063e1b6a84371c07e` ? PRESERVED / NOT STAGED.
- `docs/backup-restore-hardening/STATUS.md` ? `1007d679213e55edb01e1671cb607a1ad9daf22d44ee4d9fb554d00d2eeaf82b` ? PRESERVED / NOT STAGED.
- All pre-existing untracked task/review documents were preserved.

## 6. Exact authorized scope

- `A scripts/audit_backup_restore_hardening.py`
- `M .github/workflows/build-ios-arm.yml`
- `A docs/backup-restore-hardening/reports/TASK-6.3-REPORT.md`

No production source, Makefile, Keychain helper, Backup/Restore implementation, fixture, dependency file, test framework or caller was modified.

## 7. Guard architecture

- Strict byte-first source reader with existence, file-kind, NUL, strict UTF-8 and conflict-marker enforcement.
- Length- and newline-preserving lexical masker for C/Objective-C comments, Objective-C strings, C strings and character literals.
- Balanced Objective-C method parser supporting multiline signatures, one-line bodies, nested scopes, Objective-C blocks, dictionary/array literals and braces inside masked channels.
- Bounded C-function, enum, assignment, initializer-array, shell readonly-integer and workflow block extraction.
- Deterministic `GuardCollector` with stable unique IDs and sorted violations.
- In-memory mutation harness; no repository file is rewritten by self-tests.

## 8. CLI and exit codes

| Invocation | Result | Exit |
|---|---|---:|
| `python3 scripts/audit_backup_restore_hardening.py` | `backup_restore_hardening audit: PASS (1699/1699)` | 0 |
| `python3 scripts/audit_backup_restore_hardening.py --self-test` | `backup_restore_hardening self-test: PASS (49/49)` | 0 |
| unknown option | concise usage error on stderr | 2 |
| positional argument | concise usage error on stderr | 2 |
| expected policy violation | deterministic FAIL summary and stable guard diagnostics | 1 |
| reader/parser/internal failure | concise deterministic internal error, no traceback by default | 2 |

No absolute path, timestamp, hostname or randomized ordering is emitted.

## 9. Dependency audit

- Imports: `__future__`, `collections`, `dataclasses`, `pathlib`, `re`, `sys`, `typing`.
- Python standard library only: PASS.
- Network, subprocess, shell execution, git commands, PyYAML, clang tooling and Apple SDK dependency: absent.
- Production full-file hashes are not CI policy. Protected hashes below are implementation evidence only.

## 10. Reader and encoding contract

Every required/audited file is read as bytes before strict UTF-8 decoding. NUL and merge-conflict markers fail closed. C/Objective-C files enter the lexical/parser channel; workflow, shell and Makefile retain byte/UTF-8 checks without being misparsed as C syntax. Empty tracked source placeholders are readable files and are not treated as missing.

## 11. Lexical masker and parser self-tests

- Parser/lexical tests: **25/25 PASS**.
- P01: line comment masking ? PASS.
- P02: block comment masking ? PASS.
- P03: Objective-C string masking ? PASS.
- P04: C string masking ? PASS.
- P05: character literal masking ? PASS.
- P06: escaped quote handling ? PASS.
- P07: escaped backslash handling ? PASS.
- P08: length preservation ? PASS.
- P09: newline preservation ? PASS.
- P10: unterminated comment failure ? PASS.
- P11: unterminated string failure ? PASS.
- P12: unterminated character failure ? PASS.
- P13: multiline declaration ? PASS.
- P14: multiline definition ? PASS.
- P15: one-line definition ? PASS.
- P16: nested C braces ? PASS.
- P17: Objective-C block braces ? PASS.
- P18: dictionary literal braces ? PASS.
- P19: comment braces ? PASS.
- P20: string braces ? PASS.
- P21: declaration-versus-definition ? PASS.
- P22: duplicate selector detection ? PASS.
- P23: class-extension boundary ? PASS.
- P24: Objective-C message selector extraction ? PASS.
- P25: unbalanced body failure ? PASS.

## 12. Negative mutation self-tests

- In-memory negative mutations: **24/24 PASS**.
- Each mutation starts from the loaded source map, changes memory only and asserts the exact expected guard ID fails.
- N01: reintroduce TASK-6.1 selector in public header ? expected guard detected.
- N02: reintroduce TASK-6.2 alias in public header ? expected guard detected.
- N03: remove private declaration ? expected guard detected.
- N04: remove runtime implementation ? expected guard detected.
- N05: add external direct alias call ? expected guard detected.
- N06: add NSSelectorFromString removed-selector reference ? expected guard detected.
- N07: add filesystem mutation to quarantine shim ? expected guard detected.
- N08: change securelyWipeFile: to return YES ? expected guard detected.
- N09: add raw bundle identifier logging ? expected guard detected.
- N10: redirect alias to wrong target ? expected guard detected.
- N11: add second alias message send ? expected guard detected.
- N12: add Keychain to data-only mask ? expected guard detected.
- N13: remove Keychain from full mask ? expected guard detected.
- N14: change failure precedence ? expected guard detected.
- N15: add chmod -R ? expected guard detected.
- N16: add active marker touch ? expected guard detected.
- N17: allow manager manifest version 5 ? expected guard detected.
- N18: change V4 digest algorithm ? expected guard detected.
- N19: change shell exit code ? expected guard detected.
- N20: add SecItemDelete to Restore ? expected guard detected.
- N21: change Restore title ? expected guard detected.
- N22: remove Component Results header ? expected guard detected.
- N23: remove whole-manifest equality ? expected guard detected.
- N24: remove workflow repository-audit command ? expected guard detected.

## 13. Guard count and groups

| Group | Guards | Result |
|---|---:|---|
| `ALS` | 132 | PASS |
| `API` | 229 | PASS |
| `CLR` | 13 | PASS |
| `ENV` | 1097 | PASS |
| `KEY` | 8 | PASS |
| `MAN` | 9 | PASS |
| `PERM` | 14 | PASS |
| `QTN` | 174 | PASS |
| `UI` | 19 | PASS |
| `WF` | 4 | PASS |
| **Total** | **1699** | **PASS** |

- Minimum repository guards: 450; actual: 1699.
- Minimum self-tests: 42; actual: 49.
- Duplicate guard IDs: 0.

## 14. Public API exact-set result

- `AppDataCleaner.h`: exactly one class method, `sharedManager`.
- Exactly 24 public instance selectors, no missing, unexpected, duplicate or method-kind change.

- `clearDataForBundleID:completion:` ? exactly one public instance declaration.
- `hasDataToClear:` ? exactly one public instance declaration.
- `completeAppDataWipe:` ? exactly one public instance declaration.
- `cleanIconStatePlist:` ? exactly one public instance declaration.
- `cleanSiriAnalyticsDatabase:` ? exactly one public instance declaration.
- `cleanLaunchServicesDatabase:` ? exactly one public instance declaration.
- `refreshSystemServices` ? exactly one public instance declaration.
- `clearAppReceiptData:withBundleUUID:` ? exactly one public instance declaration.
- `clearSystemLogs:` ? exactly one public instance declaration.
- `clearICloudData:` ? exactly one public instance declaration.
- `clearMediaData:` ? exactly one public instance declaration.
- `clearHealthData:` ? exactly one public instance declaration.
- `clearSafariData:` ? exactly one public instance declaration.
- `clearURLCredentialsForBundleID:` ? exactly one public instance declaration.
- `clearSpotlightIndexes:` ? exactly one public instance declaration.
- `clearClipboard` ? exactly one public instance declaration.
- `_internalClearAppStateData:` ? exactly one public instance declaration.
- `verifyDataCleared:` ? exactly one public instance declaration.
- `getDataUsage:` ? exactly one public instance declaration.
- `findDataContainerUUIDForBundleID:` ? exactly one public instance declaration.
- `findBundleContainerUUIDForBundleID:` ? exactly one public instance declaration.
- `findGroupContainerUUIDsForBundleID:` ? exactly one public instance declaration.
- `findExtensionDataContainersForBundleID:` ? exactly one public instance declaration.
- `hasKeychainItemsForBundleID:` ? exactly one public instance declaration.

## 15. Fifty-selector source-visibility and ABI matrix

| Selector | Public | Private extension | Implementation | External reference |
|---|---:|---:|---:|---:|
| `performFullCleanup:` | 0 | 1 | 1 | 0 |
| `performAggressiveCleanupFor:` | 0 | 1 | 1 | 0 |
| `completelyWipeContainer:` | 0 | 1 | 1 | 0 |
| `securelyWipeFile:` | 0 | 1 | 1 | 0 |
| `fixPermissionsAndRemovePath:` | 0 | 1 | 1 | 0 |
| `fixPermissionsForPath:` | 0 | 1 | 1 | 0 |
| `clearAppCache:` | 0 | 1 | 1 | 0 |
| `clearAppPreferences:` | 0 | 1 | 1 | 0 |
| `clearAppCookies:` | 0 | 1 | 1 | 0 |
| `clearAppWebKitData:` | 0 | 1 | 1 | 0 |
| `clearAppGroupData:` | 0 | 1 | 1 | 0 |
| `clearPluginKitData:` | 0 | 1 | 1 | 0 |
| `_internalClearEncryptedData:` | 0 | 1 | 1 | 0 |
| `secureDataWipe:` | 0 | 1 | 1 | 0 |
| `clearAppKeychain:` | 0 | 1 | 1 | 0 |
| `clearKeychainData:` | 0 | 1 | 1 | 0 |
| `clearKeychainItemsForBundleID:` | 0 | 1 | 1 | 0 |
| `universalKeychainWipeForBundleID:` | 0 | 1 | 1 | 0 |
| `performSecondaryCleanup:` | 0 | 1 | 1 | 0 |
| `clearAppData:` | 0 | 1 | 1 | 0 |
| `clearSharedContainers:` | 0 | 1 | 1 | 0 |
| `clearUserDefaults:` | 0 | 1 | 1 | 0 |
| `clearSQLiteDatabases:` | 0 | 1 | 1 | 0 |
| `clearPrivateVarData:` | 0 | 1 | 1 | 0 |
| `clearDeviceDatabase:` | 0 | 1 | 1 | 0 |
| `clearInstallationLogs:` | 0 | 1 | 1 | 0 |
| `clearNetworkConfigurations:` | 0 | 1 | 1 | 0 |
| `clearCarrierData:` | 0 | 1 | 1 | 0 |
| `clearNetworkData:` | 0 | 1 | 1 | 0 |
| `clearDNSCache:` | 0 | 1 | 1 | 0 |
| `clearCrashReports:` | 0 | 1 | 1 | 0 |
| `clearDiagnosticData:` | 0 | 1 | 1 | 0 |
| `clearBluetoothData:` | 0 | 1 | 1 | 0 |
| `clearPushNotificationData:` | 0 | 1 | 1 | 0 |
| `clearThumbnailCache:` | 0 | 1 | 1 | 0 |
| `clearWebCache:` | 0 | 1 | 1 | 0 |
| `clearGameData:` | 0 | 1 | 1 | 0 |
| `clearTemporaryFiles:` | 0 | 1 | 1 | 0 |
| `clearBinaryPlists:` | 0 | 1 | 1 | 0 |
| `clearEncryptedData:` | 0 | 1 | 1 | 0 |
| `clearJailbreakDetectionLogs:` | 0 | 1 | 1 | 0 |
| `clearSpotlightData:` | 0 | 1 | 1 | 0 |
| `clearSiriData:` | 0 | 1 | 1 | 0 |
| `clearSystemLoggerData:` | 0 | 1 | 1 | 0 |
| `clearASLLogs:` | 0 | 1 | 1 | 0 |
| `clearPasteboardData:` | 0 | 1 | 1 | 0 |
| `clearURLCache:` | 0 | 1 | 1 | 0 |
| `clearBackgroundAssets:` | 0 | 1 | 1 | 0 |
| `clearSharedStorage:` | 0 | 1 | 1 | 0 |
| `clearAppStateData:` | 0 | 1 | 1 | 0 |

The checker also rejects dynamic re-exposure/reference through selector literals and runtime lookup strings in external production source.

## 16. Quarantine matrix

| Selector | Definition | Exact fail-closed body | Selector-only logger |
|---|---:|---:|---:|
| `performFullCleanup:` | 1 | PASS | 1 |
| `performAggressiveCleanupFor:` | 1 | PASS | 1 |
| `completelyWipeContainer:` | 1 | PASS | 1 |
| `securelyWipeFile:` | 1 | PASS | 1 |
| `fixPermissionsAndRemovePath:` | 1 | PASS | 1 |
| `fixPermissionsForPath:` | 1 | PASS | 1 |
| `clearAppCache:` | 1 | PASS | 1 |
| `clearAppPreferences:` | 1 | PASS | 1 |
| `clearAppCookies:` | 1 | PASS | 1 |
| `clearAppWebKitData:` | 1 | PASS | 1 |
| `clearAppGroupData:` | 1 | PASS | 1 |
| `clearPluginKitData:` | 1 | PASS | 1 |
| `_internalClearEncryptedData:` | 1 | PASS | 1 |
| `secureDataWipe:` | 1 | PASS | 1 |
| `clearAppKeychain:` | 1 | PASS | 1 |
| `clearKeychainData:` | 1 | PASS | 1 |
| `clearKeychainItemsForBundleID:` | 1 | PASS | 1 |
| `universalKeychainWipeForBundleID:` | 1 | PASS | 1 |
| `wipeDirectoryContents:keepDirectoryStructure:` | 1 | PASS | 1 |
| `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:` | 1 | PASS | 1 |
| `finalSweepForContainer:` | 1 | PASS | 1 |
| `wipeWebKitDirectoryContents:` | 1 | PASS | 1 |
| `clearAppGroupContainers:withGroupUUIDs:isRootless:` | 1 | PASS | 1 |
| `clearAppGroupContainers:withGroupUUIDs:` | 1 | PASS | 1 |
| `clearExtensionContainers:forApp:` | 1 | PASS | 1 |
| `cleanAppGroupContainers:` | 1 | PASS | 1 |
| `_wipeRelatedDataContainersForBundleIDs:` | 1 | PASS | 1 |
| `_wipeRelatedSystemGroupContainersForIdentifiers:` | 1 | PASS | 1 |
| `_wipeContainersInBasePaths:matchingSubstrings:tag:` | 1 | PASS | 1 |
| `_wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag:` | 1 | PASS | 1 |
| `_scrubWebKitStateInSharedContainerBase:tag:` | 1 | PASS | 1 |
| `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:` | 1 | PASS | 1 |
| `deepCleanSystemSharedContainer:bundleID:appName:companyName:` | 1 | PASS | 1 |

- Exact quarantine selector count: 33.
- Logger definition count: 1; parameter: `SEL selector`; one `NSLog`; one `NSStringFromSelector(selector)`.
- Logger privacy tokens and filesystem/process/Security/Clear/dispatch/defaults/lifecycle APIs: absent.
- `securelyWipeFile:` casts `path` unused, logs `_cmd` once, returns `NO` once and never returns `YES`.

## 17. Alias mapping matrix

| Alias | Target | Single self-send |
|---|---|---:|
| `performSecondaryCleanup:` | `completeAppDataWipe:` | PASS |
| `clearAppData:` | `completeAppDataWipe:` | PASS |
| `clearSQLiteDatabases:` | `completeAppDataWipe:` | PASS |
| `clearDeviceDatabase:` | `completeAppDataWipe:` | PASS |
| `clearNetworkConfigurations:` | `completeAppDataWipe:` | PASS |
| `clearCarrierData:` | `completeAppDataWipe:` | PASS |
| `clearNetworkData:` | `completeAppDataWipe:` | PASS |
| `clearDNSCache:` | `completeAppDataWipe:` | PASS |
| `clearBluetoothData:` | `completeAppDataWipe:` | PASS |
| `clearPushNotificationData:` | `completeAppDataWipe:` | PASS |
| `clearGameData:` | `completeAppDataWipe:` | PASS |
| `clearTemporaryFiles:` | `completeAppDataWipe:` | PASS |
| `clearBinaryPlists:` | `completeAppDataWipe:` | PASS |
| `clearJailbreakDetectionLogs:` | `completeAppDataWipe:` | PASS |
| `clearSpotlightData:` | `completeAppDataWipe:` | PASS |
| `clearSiriData:` | `completeAppDataWipe:` | PASS |
| `clearURLCache:` | `completeAppDataWipe:` | PASS |
| `clearBackgroundAssets:` | `completeAppDataWipe:` | PASS |
| `clearSharedStorage:` | `completeAppDataWipe:` | PASS |
| `clearSharedContainers:` | `clearAppGroupData:` | PASS |
| `clearUserDefaults:` | `clearAppPreferences:` | PASS |
| `clearWebCache:` | `clearAppWebKitData:` | PASS |
| `clearEncryptedData:` | `_internalClearEncryptedData:` | PASS |
| `clearInstallationLogs:` | `clearSystemLogs:` | PASS |
| `clearCrashReports:` | `clearSystemLogs:` | PASS |
| `clearDiagnosticData:` | `clearSystemLogs:` | PASS |
| `clearSystemLoggerData:` | `clearSystemLogs:` | PASS |
| `clearASLLogs:` | `clearSystemLogs:` | PASS |
| `clearPrivateVarData:` | `cleanRootHideVarData:` | PASS |
| `clearThumbnailCache:` | `clearThumbnailCaches:` | PASS |
| `clearPasteboardData:` | `clearClipboard` | PASS |
| `clearAppStateData:` | `_internalClearAppStateData:` | PASS |

- Data-only aliases: 19; quarantine-target aliases: 4; system-log aliases: 5; direct-mutator aliases: 4.
- Every body contains exactly one self message send and no control flow, logging, dispatch, return fabrication, filesystem or Security operation.

## 18. Clear enum, masks and typed routes

- `PXClearScope`: exact five values, bits 0 through 4, no sixth scope and no alias value.
- `PXClearScopeKnownMask` and `PXClearScopeDefaultMask`: exact five-scope set.
- `PXMigratedDataClearScopes`: exact four data scopes and no Keychain.
- `PXMigratedFullClearScopes`: exact five-scope set.
- `clearDataForBundleID:completion:`: full request, four-scope result, Keychain plan/component, Keychain append and final `PXClearResult` in accepted order.
- Failure precedence: ApplicationData, ExtensionData, AppGroups, PluginKitData, Keychain.
- `completeAppDataWipe:`: data mask only, no Keychain planning and no removed-selector route.

## 19. Permission, marker and receipt results

- Recursive `chmod`: 0; `find ... -exec chmod`: 0.
- Recursive `chflags`: exactly 1 and only inside `PXShellValidatedApplicationDataWipe`.
- Active `.nomedia` / `.initialized` marker touch, `PXShellFinalSweep` and AssistantServices destructive target: 0.
- `clearAppReceiptData:withBundleUUID:` remains read-only, casts `bundleUUID` unused, logs ?Skipping receipt mutation? and performs no mutation/shell/permission operation.

### 19.1 Authority-aware `chown -R` reconciliation

The TASK-6.3 text requests a global `chown -R` count of zero, but its protected `AppDataBackupManager.m` baseline hash contains five accepted transactional Restore ownership corrections introduced and retained by later Phase 2 decisions. Production modification is forbidden in this task. The checker therefore enforces:

- recursive `chown` outside `AppDataBackupManager.m`: **0**;
- accepted transactional Restore ownership corrections in `AppDataBackupManager.m`: **exactly 5**;
- any addition, removal or relocation outside that bounded baseline fails.

This reconciliation is explicit review evidence, not a silent weakening. A future authority decision may replace those five operations, but TASK-6.3 does not alter production behavior.

## 20. Manifest results

- Operational manager versions: `{2,3,4}`.
- Discovery versions: `{2,3,4}`.
- UI confirmation inspection range: `2...5` inclusive; intentionally distinct.
- V4 constants: version 4, schema identifier `com.hydra.projectx.backup-manifest`, revision 2, digest `sha256`, publication `atomic-directory-v1`, content state `complete`.

## 21. Keychain results

- Objective-C and shell exit-code dictionaries match exact values 0, 10, 20, 21, 30, 40, 50, 60, 61, 62, 63, 64, 65.
- `SecItemDelete` count across Keychain helper Objective-C paths: exactly 1, solely in explicit wipe.
- Restore path retains `SecItemAdd`, exact identity construction, unique persistent-reference lookup, update-attribute construction and `SecItemUpdate`.
- Restore methods, helper dispatch and manager path contain no `SecItemDelete`.
- Wrapper help retains `--overwrite`, ?update one exact existing item in place? and ?never delete?.

## 22. Backup and Restore presentation results

- Backup outcomes: 1 Successful, 2 CompletedWithWarnings, 3 Failed; exact three titles and precedence preserved.
- Restore outcomes: six exact values/titles; incomplete rollback precedes completed rollback, rollback precedes generic error, component failures precede warning success.
- Backup callback presents exactly once and uses `result.backupDirectory` only for valid success/warning results.
- Restore callback appends component results before aggregate warnings, presents exactly once and uses `copyPath:nil`.
- Required `Component Results:` header retained.

## 23. Advanced-scope confirmation results

- Seven exact advanced-scope bits, exact presentation order and exact display names are guarded.
- Exact Backup/Restore confirmation titles/action labels are guarded.
- Backup uses default action style; Restore uses destructive action style.
- Shared/sensitive, cross-app/system-service and irreversible Restore warning semantics remain present.
- Exact CFBoolean validation is required; generic `boolValue` alone cannot satisfy the guard.

## 24. Manifest confirmation binding and ordering

The checker requires selected manifest read, scope validation, immutable snapshot, confirmation, destructive-action re-read, current-scope validation, whole-manifest equality, scope equality, processing alert and Restore call in that exact structural order. Both equality checks must precede processing and Restore.

## 25. Workflow integration

The exact audit step is immediately after Checkout and before Install build dependencies:

```yaml
      - name: Audit backup/restore hardening invariants
        run: |
          python3 scripts/audit_backup_restore_hardening.py --self-test
          python3 scripts/audit_backup_restore_hardening.py
```

- No `continue-on-error`, `|| true`, allow-failure or conditional skip.
- Self-test precedes repository audit.
- Both precede Homebrew, Theos, SDK and build work.

## 26. Workflow exact evidence

- Baseline: 4548 bytes / SHA-256 `43814c1ab1f47aee5dd88864aefc2068de5f91f23ce24df96394647958c5706e` / 114 CRLF.
- Final: 4757 bytes / SHA-256 `71066d8f0a92133d45827715139ab8e499a67e8fc441dbc0ac23e9282cd09d37` / 119 CRLF.
- LF-only: 0; NUL: 0; final newline present; unrelated workflow bytes unchanged.

## 27. Determinism proof

- Self-test run 1/run 2: exit 0/0, stdout byte-identical, stderr byte-identical.
- Repository audit run 1/run 2: exit 0/0, stdout byte-identical, stderr byte-identical.
- Guard count and ordering identical across runs.
- No filesystem mtime, absolute root, timestamp, host or randomized order appears in output.

## 28. Protected production hashes

| File | SHA-256 | Result |
|---|---|---|
| `AppDataCleaner.h` | `9c68c07115d32f2c57a1027646d6055d21375842a64064d9cfdcaeaeabe30a86` | PASS |
| `AppDataCleaner.m` | `6355110ba6398a927d0f7dc1251b5e47f81f79ef47f60cf977795e451cdc916a` | PASS |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | PASS |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | PASS |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | PASS |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | PASS |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | PASS |
| `AppDataBackupManager.m` | `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028` | PASS |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | PASS |
| `PXBackupManifestV4.m` | `4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037` | PASS |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | PASS |
| `PXBackupManifestValidator.m` | `8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b` | PASS |
| `PXBackupDirectoryDiscovery.h` | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | PASS |
| `PXBackupDirectoryDiscovery.m` | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | PASS |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | PASS |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | PASS |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | PASS |
| `AppDataBackupRestoreViewController.m` | `23c964fac0189119c500665a700fe1fb7dafa77fd63779dccaa9e084cefa26c5` | PASS |
| `KeychainHelper/PXKeychainHelperExitCode.h` | `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a` | PASS |
| `KeychainHelper/PXKeychainHelperResult.h` | `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3` | PASS |
| `KeychainHelper/PXKeychainHelperResult.m` | `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5` | PASS |
| `KeychainHelper/KeychainBackupHelper.h` | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | PASS |
| `KeychainHelper/KeychainBackupHelper.m` | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | PASS |
| `KeychainHelper/backup_helper.m` | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | PASS |
| `scripts/keychain_backup.sh` | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | PASS |
| `Makefile` | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` | PASS |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | PASS |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | PASS |
| `docs/backup-restore-hardening/reports/TASK-6.2-REPORT.md` | `44f5fc54dbafebaa0ea79f1cd4247043f0fdcb4f249ce5328cb7c19671b371c1` | PASS |

Protected hashes matched: **29/29**.

## 29. Script evidence

- Bytes: `94957`.
- SHA-256: `19e1ea53fad0668256d45bb31e0323cda4133af92c39b0c7bad584dc9ac0c745`.
- Lines / LF: `1680` / `1680`; CRLF: `0`.
- UTF-8 LF only, no BOM, no NUL, final newline present.
- File mode target: 100644; workflow invokes through `python3`.

## 30. Local command outputs

```text
python -m py_compile scripts/audit_backup_restore_hardening.py
PASS

python scripts/audit_backup_restore_hardening.py --self-test
backup_restore_hardening self-test: PASS (49/49)

python scripts/audit_backup_restore_hardening.py
backup_restore_hardening audit: PASS (1699/1699)
```

## 31. Full authorized diff shape

- New audit script: one UTF-8 LF file, 1680 lines before report creation, standard-library-only implementation.
- Workflow: exact five-line CRLF insertion after Checkout; no other workflow hunk.
- New report: this UTF-8 LF evidence file.
- Production source diff: none.

## 32. Encoding, NUL and controls

| File | Encoding/endings | BOM | NUL | Final newline |
|---|---|---:|---:|---:|
| `scripts/audit_backup_restore_hardening.py` | UTF-8 LF | 0 | 0 | present |
| `.github/workflows/build-ios-arm.yml` | UTF-8 CRLF | 0 | 0 | present |
| `TASK-6.3-REPORT.md` | UTF-8 LF | 0 | 0 | present |

## 33. Static guard limitations

The static audit does not replace Objective-C compilation, archive-fixture execution, transaction fault injection, device/runtime testing or branch-protection enforcement. It checks exact source-level contracts and parser-recognized structures only.

## 34. Build and runtime status

- Python static audit: PASS locally.
- GitHub workflow execution: PENDING.
- Apple/Theos compile, link and package: NOT RUN / not claimed in this Windows workspace.
- Device/runtime tests: NOT RUN / not required / not claimed.

## 35. Explicit numbered scenarios

| # | Scenario | Status | Evidence |
|---:|---|---|---|
| 0001 | Baseline HEAD | **STATIC PASS** | c83584ee6d1ee50ff63202b5c86883fa2d009598 |
| 0002 | Exact authorized scope | **STATIC PASS** | script; workflow; report |
| 0003 | Coordinator docs | **STATIC PASS** | preserved/not staged |
| 0004 | Pre-existing untracked files | **STATIC PASS** | preserved |
| 0005 | No production source modification | **STATIC PASS** | protected hashes |
| 0006 | TASK-6.4 boundary | **STATIC PASS** | not started |
| 0007 | No push | **STATIC PASS** | not performed |
| 0008 | Strict UTF-8 reader | **STATIC PASS** | byte-first |
| 0009 | NUL rejection | **STATIC PASS** | reader contract |
| 0010 | Conflict marker rejection | **STATIC PASS** | reader contract |
| 0011 | Lexical length preservation | **STATIC PASS** | parser test |
| 0012 | Lexical newline preservation | **STATIC PASS** | parser test |
| 0013 | Balanced method extraction | **STATIC PASS** | parser test |
| 0014 | Malformed input fail-closed | **STATIC PASS** | parser test |
| 0015 | Guard floor | **STATIC PASS** | 1699 >= 450 |
| 0016 | Self-test floor | **STATIC PASS** | 49 >= 42 |
| 0017 | Duplicate guard IDs | **STATIC PASS** | 0 |
| 0018 | Deterministic self-test | **STATIC PASS** | two byte-identical runs |
| 0019 | Deterministic audit | **STATIC PASS** | two byte-identical runs |
| 0020 | Workflow insertion | **STATIC PASS** | exact hash |
| 0021 | GitHub Actions | **PENDING** | remote execution not run |
| 0022 | Apple build | **NOT RUN** | Apple/Theos unavailable |
| 0023 | Device runtime | **NOT RUN** | not required |
| 0024 | chown specification reconciliation | **STATIC PASS** | zero outside manager; exact five accepted Restore routes |
| 0025 | Parser self-test: line comment masking | **STATIC PASS** | PASS |
| 0026 | Parser self-test: block comment masking | **STATIC PASS** | PASS |
| 0027 | Parser self-test: Objective-C string masking | **STATIC PASS** | PASS |
| 0028 | Parser self-test: C string masking | **STATIC PASS** | PASS |
| 0029 | Parser self-test: character literal masking | **STATIC PASS** | PASS |
| 0030 | Parser self-test: escaped quote handling | **STATIC PASS** | PASS |
| 0031 | Parser self-test: escaped backslash handling | **STATIC PASS** | PASS |
| 0032 | Parser self-test: length preservation | **STATIC PASS** | PASS |
| 0033 | Parser self-test: newline preservation | **STATIC PASS** | PASS |
| 0034 | Parser self-test: unterminated comment failure | **STATIC PASS** | PASS |
| 0035 | Parser self-test: unterminated string failure | **STATIC PASS** | PASS |
| 0036 | Parser self-test: unterminated character failure | **STATIC PASS** | PASS |
| 0037 | Parser self-test: multiline declaration | **STATIC PASS** | PASS |
| 0038 | Parser self-test: multiline definition | **STATIC PASS** | PASS |
| 0039 | Parser self-test: one-line definition | **STATIC PASS** | PASS |
| 0040 | Parser self-test: nested C braces | **STATIC PASS** | PASS |
| 0041 | Parser self-test: Objective-C block braces | **STATIC PASS** | PASS |
| 0042 | Parser self-test: dictionary literal braces | **STATIC PASS** | PASS |
| 0043 | Parser self-test: comment braces | **STATIC PASS** | PASS |
| 0044 | Parser self-test: string braces | **STATIC PASS** | PASS |
| 0045 | Parser self-test: declaration-versus-definition | **STATIC PASS** | PASS |
| 0046 | Parser self-test: duplicate selector detection | **STATIC PASS** | PASS |
| 0047 | Parser self-test: class-extension boundary | **STATIC PASS** | PASS |
| 0048 | Parser self-test: Objective-C message selector extraction | **STATIC PASS** | PASS |
| 0049 | Parser self-test: unbalanced body failure | **STATIC PASS** | PASS |
| 0050 | Negative mutation: reintroduce TASK-6.1 selector in public header | **STATIC PASS** | expected stable guard ID triggered |
| 0051 | Negative mutation: reintroduce TASK-6.2 alias in public header | **STATIC PASS** | expected stable guard ID triggered |
| 0052 | Negative mutation: remove private declaration | **STATIC PASS** | expected stable guard ID triggered |
| 0053 | Negative mutation: remove runtime implementation | **STATIC PASS** | expected stable guard ID triggered |
| 0054 | Negative mutation: add external direct alias call | **STATIC PASS** | expected stable guard ID triggered |
| 0055 | Negative mutation: add NSSelectorFromString removed-selector reference | **STATIC PASS** | expected stable guard ID triggered |
| 0056 | Negative mutation: add filesystem mutation to quarantine shim | **STATIC PASS** | expected stable guard ID triggered |
| 0057 | Negative mutation: change securelyWipeFile: to return YES | **STATIC PASS** | expected stable guard ID triggered |
| 0058 | Negative mutation: add raw bundle identifier logging | **STATIC PASS** | expected stable guard ID triggered |
| 0059 | Negative mutation: redirect alias to wrong target | **STATIC PASS** | expected stable guard ID triggered |
| 0060 | Negative mutation: add second alias message send | **STATIC PASS** | expected stable guard ID triggered |
| 0061 | Negative mutation: add Keychain to data-only mask | **STATIC PASS** | expected stable guard ID triggered |
| 0062 | Negative mutation: remove Keychain from full mask | **STATIC PASS** | expected stable guard ID triggered |
| 0063 | Negative mutation: change failure precedence | **STATIC PASS** | expected stable guard ID triggered |
| 0064 | Negative mutation: add chmod -R | **STATIC PASS** | expected stable guard ID triggered |
| 0065 | Negative mutation: add active marker touch | **STATIC PASS** | expected stable guard ID triggered |
| 0066 | Negative mutation: allow manager manifest version 5 | **STATIC PASS** | expected stable guard ID triggered |
| 0067 | Negative mutation: change V4 digest algorithm | **STATIC PASS** | expected stable guard ID triggered |
| 0068 | Negative mutation: change shell exit code | **STATIC PASS** | expected stable guard ID triggered |
| 0069 | Negative mutation: add SecItemDelete to Restore | **STATIC PASS** | expected stable guard ID triggered |
| 0070 | Negative mutation: change Restore title | **STATIC PASS** | expected stable guard ID triggered |
| 0071 | Negative mutation: remove Component Results header | **STATIC PASS** | expected stable guard ID triggered |
| 0072 | Negative mutation: remove whole-manifest equality | **STATIC PASS** | expected stable guard ID triggered |
| 0073 | Negative mutation: remove workflow repository-audit command | **STATIC PASS** | expected stable guard ID triggered |
| 0074 | Exact retained public selector: clearDataForBundleID:completion: | **STATIC PASS** | one instance declaration |
| 0075 | Exact retained public selector: hasDataToClear: | **STATIC PASS** | one instance declaration |
| 0076 | Exact retained public selector: completeAppDataWipe: | **STATIC PASS** | one instance declaration |
| 0077 | Exact retained public selector: cleanIconStatePlist: | **STATIC PASS** | one instance declaration |
| 0078 | Exact retained public selector: cleanSiriAnalyticsDatabase: | **STATIC PASS** | one instance declaration |
| 0079 | Exact retained public selector: cleanLaunchServicesDatabase: | **STATIC PASS** | one instance declaration |
| 0080 | Exact retained public selector: refreshSystemServices | **STATIC PASS** | one instance declaration |
| 0081 | Exact retained public selector: clearAppReceiptData:withBundleUUID: | **STATIC PASS** | one instance declaration |
| 0082 | Exact retained public selector: clearSystemLogs: | **STATIC PASS** | one instance declaration |
| 0083 | Exact retained public selector: clearICloudData: | **STATIC PASS** | one instance declaration |
| 0084 | Exact retained public selector: clearMediaData: | **STATIC PASS** | one instance declaration |
| 0085 | Exact retained public selector: clearHealthData: | **STATIC PASS** | one instance declaration |
| 0086 | Exact retained public selector: clearSafariData: | **STATIC PASS** | one instance declaration |
| 0087 | Exact retained public selector: clearURLCredentialsForBundleID: | **STATIC PASS** | one instance declaration |
| 0088 | Exact retained public selector: clearSpotlightIndexes: | **STATIC PASS** | one instance declaration |
| 0089 | Exact retained public selector: clearClipboard | **STATIC PASS** | one instance declaration |
| 0090 | Exact retained public selector: _internalClearAppStateData: | **STATIC PASS** | one instance declaration |
| 0091 | Exact retained public selector: verifyDataCleared: | **STATIC PASS** | one instance declaration |
| 0092 | Exact retained public selector: getDataUsage: | **STATIC PASS** | one instance declaration |
| 0093 | Exact retained public selector: findDataContainerUUIDForBundleID: | **STATIC PASS** | one instance declaration |
| 0094 | Exact retained public selector: findBundleContainerUUIDForBundleID: | **STATIC PASS** | one instance declaration |
| 0095 | Exact retained public selector: findGroupContainerUUIDsForBundleID: | **STATIC PASS** | one instance declaration |
| 0096 | Exact retained public selector: findExtensionDataContainersForBundleID: | **STATIC PASS** | one instance declaration |
| 0097 | Exact retained public selector: hasKeychainItemsForBundleID: | **STATIC PASS** | one instance declaration |
| 0098 | Removed selector public absence: performFullCleanup: | **STATIC PASS** | 0 |
| 0099 | Removed selector private declaration: performFullCleanup: | **STATIC PASS** | 1 |
| 0100 | Removed selector runtime implementation: performFullCleanup: | **STATIC PASS** | 1 |
| 0101 | Removed selector external reference: performFullCleanup: | **STATIC PASS** | 0 |
| 0102 | Removed selector public absence: performAggressiveCleanupFor: | **STATIC PASS** | 0 |
| 0103 | Removed selector private declaration: performAggressiveCleanupFor: | **STATIC PASS** | 1 |
| 0104 | Removed selector runtime implementation: performAggressiveCleanupFor: | **STATIC PASS** | 1 |
| 0105 | Removed selector external reference: performAggressiveCleanupFor: | **STATIC PASS** | 0 |
| 0106 | Removed selector public absence: completelyWipeContainer: | **STATIC PASS** | 0 |
| 0107 | Removed selector private declaration: completelyWipeContainer: | **STATIC PASS** | 1 |
| 0108 | Removed selector runtime implementation: completelyWipeContainer: | **STATIC PASS** | 1 |
| 0109 | Removed selector external reference: completelyWipeContainer: | **STATIC PASS** | 0 |
| 0110 | Removed selector public absence: securelyWipeFile: | **STATIC PASS** | 0 |
| 0111 | Removed selector private declaration: securelyWipeFile: | **STATIC PASS** | 1 |
| 0112 | Removed selector runtime implementation: securelyWipeFile: | **STATIC PASS** | 1 |
| 0113 | Removed selector external reference: securelyWipeFile: | **STATIC PASS** | 0 |
| 0114 | Removed selector public absence: fixPermissionsAndRemovePath: | **STATIC PASS** | 0 |
| 0115 | Removed selector private declaration: fixPermissionsAndRemovePath: | **STATIC PASS** | 1 |
| 0116 | Removed selector runtime implementation: fixPermissionsAndRemovePath: | **STATIC PASS** | 1 |
| 0117 | Removed selector external reference: fixPermissionsAndRemovePath: | **STATIC PASS** | 0 |
| 0118 | Removed selector public absence: fixPermissionsForPath: | **STATIC PASS** | 0 |
| 0119 | Removed selector private declaration: fixPermissionsForPath: | **STATIC PASS** | 1 |
| 0120 | Removed selector runtime implementation: fixPermissionsForPath: | **STATIC PASS** | 1 |
| 0121 | Removed selector external reference: fixPermissionsForPath: | **STATIC PASS** | 0 |
| 0122 | Removed selector public absence: clearAppCache: | **STATIC PASS** | 0 |
| 0123 | Removed selector private declaration: clearAppCache: | **STATIC PASS** | 1 |
| 0124 | Removed selector runtime implementation: clearAppCache: | **STATIC PASS** | 1 |
| 0125 | Removed selector external reference: clearAppCache: | **STATIC PASS** | 0 |
| 0126 | Removed selector public absence: clearAppPreferences: | **STATIC PASS** | 0 |
| 0127 | Removed selector private declaration: clearAppPreferences: | **STATIC PASS** | 1 |
| 0128 | Removed selector runtime implementation: clearAppPreferences: | **STATIC PASS** | 1 |
| 0129 | Removed selector external reference: clearAppPreferences: | **STATIC PASS** | 0 |
| 0130 | Removed selector public absence: clearAppCookies: | **STATIC PASS** | 0 |
| 0131 | Removed selector private declaration: clearAppCookies: | **STATIC PASS** | 1 |
| 0132 | Removed selector runtime implementation: clearAppCookies: | **STATIC PASS** | 1 |
| 0133 | Removed selector external reference: clearAppCookies: | **STATIC PASS** | 0 |
| 0134 | Removed selector public absence: clearAppWebKitData: | **STATIC PASS** | 0 |
| 0135 | Removed selector private declaration: clearAppWebKitData: | **STATIC PASS** | 1 |
| 0136 | Removed selector runtime implementation: clearAppWebKitData: | **STATIC PASS** | 1 |
| 0137 | Removed selector external reference: clearAppWebKitData: | **STATIC PASS** | 0 |
| 0138 | Removed selector public absence: clearAppGroupData: | **STATIC PASS** | 0 |
| 0139 | Removed selector private declaration: clearAppGroupData: | **STATIC PASS** | 1 |
| 0140 | Removed selector runtime implementation: clearAppGroupData: | **STATIC PASS** | 1 |
| 0141 | Removed selector external reference: clearAppGroupData: | **STATIC PASS** | 0 |
| 0142 | Removed selector public absence: clearPluginKitData: | **STATIC PASS** | 0 |
| 0143 | Removed selector private declaration: clearPluginKitData: | **STATIC PASS** | 1 |
| 0144 | Removed selector runtime implementation: clearPluginKitData: | **STATIC PASS** | 1 |
| 0145 | Removed selector external reference: clearPluginKitData: | **STATIC PASS** | 0 |
| 0146 | Removed selector public absence: _internalClearEncryptedData: | **STATIC PASS** | 0 |
| 0147 | Removed selector private declaration: _internalClearEncryptedData: | **STATIC PASS** | 1 |
| 0148 | Removed selector runtime implementation: _internalClearEncryptedData: | **STATIC PASS** | 1 |
| 0149 | Removed selector external reference: _internalClearEncryptedData: | **STATIC PASS** | 0 |
| 0150 | Removed selector public absence: secureDataWipe: | **STATIC PASS** | 0 |
| 0151 | Removed selector private declaration: secureDataWipe: | **STATIC PASS** | 1 |
| 0152 | Removed selector runtime implementation: secureDataWipe: | **STATIC PASS** | 1 |
| 0153 | Removed selector external reference: secureDataWipe: | **STATIC PASS** | 0 |
| 0154 | Removed selector public absence: clearAppKeychain: | **STATIC PASS** | 0 |
| 0155 | Removed selector private declaration: clearAppKeychain: | **STATIC PASS** | 1 |
| 0156 | Removed selector runtime implementation: clearAppKeychain: | **STATIC PASS** | 1 |
| 0157 | Removed selector external reference: clearAppKeychain: | **STATIC PASS** | 0 |
| 0158 | Removed selector public absence: clearKeychainData: | **STATIC PASS** | 0 |
| 0159 | Removed selector private declaration: clearKeychainData: | **STATIC PASS** | 1 |
| 0160 | Removed selector runtime implementation: clearKeychainData: | **STATIC PASS** | 1 |
| 0161 | Removed selector external reference: clearKeychainData: | **STATIC PASS** | 0 |
| 0162 | Removed selector public absence: clearKeychainItemsForBundleID: | **STATIC PASS** | 0 |
| 0163 | Removed selector private declaration: clearKeychainItemsForBundleID: | **STATIC PASS** | 1 |
| 0164 | Removed selector runtime implementation: clearKeychainItemsForBundleID: | **STATIC PASS** | 1 |
| 0165 | Removed selector external reference: clearKeychainItemsForBundleID: | **STATIC PASS** | 0 |
| 0166 | Removed selector public absence: universalKeychainWipeForBundleID: | **STATIC PASS** | 0 |
| 0167 | Removed selector private declaration: universalKeychainWipeForBundleID: | **STATIC PASS** | 1 |
| 0168 | Removed selector runtime implementation: universalKeychainWipeForBundleID: | **STATIC PASS** | 1 |
| 0169 | Removed selector external reference: universalKeychainWipeForBundleID: | **STATIC PASS** | 0 |
| 0170 | Removed selector public absence: performSecondaryCleanup: | **STATIC PASS** | 0 |
| 0171 | Removed selector private declaration: performSecondaryCleanup: | **STATIC PASS** | 1 |
| 0172 | Removed selector runtime implementation: performSecondaryCleanup: | **STATIC PASS** | 1 |
| 0173 | Removed selector external reference: performSecondaryCleanup: | **STATIC PASS** | 0 |
| 0174 | Removed selector public absence: clearAppData: | **STATIC PASS** | 0 |
| 0175 | Removed selector private declaration: clearAppData: | **STATIC PASS** | 1 |
| 0176 | Removed selector runtime implementation: clearAppData: | **STATIC PASS** | 1 |
| 0177 | Removed selector external reference: clearAppData: | **STATIC PASS** | 0 |
| 0178 | Removed selector public absence: clearSharedContainers: | **STATIC PASS** | 0 |
| 0179 | Removed selector private declaration: clearSharedContainers: | **STATIC PASS** | 1 |
| 0180 | Removed selector runtime implementation: clearSharedContainers: | **STATIC PASS** | 1 |
| 0181 | Removed selector external reference: clearSharedContainers: | **STATIC PASS** | 0 |
| 0182 | Removed selector public absence: clearUserDefaults: | **STATIC PASS** | 0 |
| 0183 | Removed selector private declaration: clearUserDefaults: | **STATIC PASS** | 1 |
| 0184 | Removed selector runtime implementation: clearUserDefaults: | **STATIC PASS** | 1 |
| 0185 | Removed selector external reference: clearUserDefaults: | **STATIC PASS** | 0 |
| 0186 | Removed selector public absence: clearSQLiteDatabases: | **STATIC PASS** | 0 |
| 0187 | Removed selector private declaration: clearSQLiteDatabases: | **STATIC PASS** | 1 |
| 0188 | Removed selector runtime implementation: clearSQLiteDatabases: | **STATIC PASS** | 1 |
| 0189 | Removed selector external reference: clearSQLiteDatabases: | **STATIC PASS** | 0 |
| 0190 | Removed selector public absence: clearPrivateVarData: | **STATIC PASS** | 0 |
| 0191 | Removed selector private declaration: clearPrivateVarData: | **STATIC PASS** | 1 |
| 0192 | Removed selector runtime implementation: clearPrivateVarData: | **STATIC PASS** | 1 |
| 0193 | Removed selector external reference: clearPrivateVarData: | **STATIC PASS** | 0 |
| 0194 | Removed selector public absence: clearDeviceDatabase: | **STATIC PASS** | 0 |
| 0195 | Removed selector private declaration: clearDeviceDatabase: | **STATIC PASS** | 1 |
| 0196 | Removed selector runtime implementation: clearDeviceDatabase: | **STATIC PASS** | 1 |
| 0197 | Removed selector external reference: clearDeviceDatabase: | **STATIC PASS** | 0 |
| 0198 | Removed selector public absence: clearInstallationLogs: | **STATIC PASS** | 0 |
| 0199 | Removed selector private declaration: clearInstallationLogs: | **STATIC PASS** | 1 |
| 0200 | Removed selector runtime implementation: clearInstallationLogs: | **STATIC PASS** | 1 |
| 0201 | Removed selector external reference: clearInstallationLogs: | **STATIC PASS** | 0 |
| 0202 | Removed selector public absence: clearNetworkConfigurations: | **STATIC PASS** | 0 |
| 0203 | Removed selector private declaration: clearNetworkConfigurations: | **STATIC PASS** | 1 |
| 0204 | Removed selector runtime implementation: clearNetworkConfigurations: | **STATIC PASS** | 1 |
| 0205 | Removed selector external reference: clearNetworkConfigurations: | **STATIC PASS** | 0 |
| 0206 | Removed selector public absence: clearCarrierData: | **STATIC PASS** | 0 |
| 0207 | Removed selector private declaration: clearCarrierData: | **STATIC PASS** | 1 |
| 0208 | Removed selector runtime implementation: clearCarrierData: | **STATIC PASS** | 1 |
| 0209 | Removed selector external reference: clearCarrierData: | **STATIC PASS** | 0 |
| 0210 | Removed selector public absence: clearNetworkData: | **STATIC PASS** | 0 |
| 0211 | Removed selector private declaration: clearNetworkData: | **STATIC PASS** | 1 |
| 0212 | Removed selector runtime implementation: clearNetworkData: | **STATIC PASS** | 1 |
| 0213 | Removed selector external reference: clearNetworkData: | **STATIC PASS** | 0 |
| 0214 | Removed selector public absence: clearDNSCache: | **STATIC PASS** | 0 |
| 0215 | Removed selector private declaration: clearDNSCache: | **STATIC PASS** | 1 |
| 0216 | Removed selector runtime implementation: clearDNSCache: | **STATIC PASS** | 1 |
| 0217 | Removed selector external reference: clearDNSCache: | **STATIC PASS** | 0 |
| 0218 | Removed selector public absence: clearCrashReports: | **STATIC PASS** | 0 |
| 0219 | Removed selector private declaration: clearCrashReports: | **STATIC PASS** | 1 |
| 0220 | Removed selector runtime implementation: clearCrashReports: | **STATIC PASS** | 1 |
| 0221 | Removed selector external reference: clearCrashReports: | **STATIC PASS** | 0 |
| 0222 | Removed selector public absence: clearDiagnosticData: | **STATIC PASS** | 0 |
| 0223 | Removed selector private declaration: clearDiagnosticData: | **STATIC PASS** | 1 |
| 0224 | Removed selector runtime implementation: clearDiagnosticData: | **STATIC PASS** | 1 |
| 0225 | Removed selector external reference: clearDiagnosticData: | **STATIC PASS** | 0 |
| 0226 | Removed selector public absence: clearBluetoothData: | **STATIC PASS** | 0 |
| 0227 | Removed selector private declaration: clearBluetoothData: | **STATIC PASS** | 1 |
| 0228 | Removed selector runtime implementation: clearBluetoothData: | **STATIC PASS** | 1 |
| 0229 | Removed selector external reference: clearBluetoothData: | **STATIC PASS** | 0 |
| 0230 | Removed selector public absence: clearPushNotificationData: | **STATIC PASS** | 0 |
| 0231 | Removed selector private declaration: clearPushNotificationData: | **STATIC PASS** | 1 |
| 0232 | Removed selector runtime implementation: clearPushNotificationData: | **STATIC PASS** | 1 |
| 0233 | Removed selector external reference: clearPushNotificationData: | **STATIC PASS** | 0 |
| 0234 | Removed selector public absence: clearThumbnailCache: | **STATIC PASS** | 0 |
| 0235 | Removed selector private declaration: clearThumbnailCache: | **STATIC PASS** | 1 |
| 0236 | Removed selector runtime implementation: clearThumbnailCache: | **STATIC PASS** | 1 |
| 0237 | Removed selector external reference: clearThumbnailCache: | **STATIC PASS** | 0 |
| 0238 | Removed selector public absence: clearWebCache: | **STATIC PASS** | 0 |
| 0239 | Removed selector private declaration: clearWebCache: | **STATIC PASS** | 1 |
| 0240 | Removed selector runtime implementation: clearWebCache: | **STATIC PASS** | 1 |
| 0241 | Removed selector external reference: clearWebCache: | **STATIC PASS** | 0 |
| 0242 | Removed selector public absence: clearGameData: | **STATIC PASS** | 0 |
| 0243 | Removed selector private declaration: clearGameData: | **STATIC PASS** | 1 |
| 0244 | Removed selector runtime implementation: clearGameData: | **STATIC PASS** | 1 |
| 0245 | Removed selector external reference: clearGameData: | **STATIC PASS** | 0 |
| 0246 | Removed selector public absence: clearTemporaryFiles: | **STATIC PASS** | 0 |
| 0247 | Removed selector private declaration: clearTemporaryFiles: | **STATIC PASS** | 1 |
| 0248 | Removed selector runtime implementation: clearTemporaryFiles: | **STATIC PASS** | 1 |
| 0249 | Removed selector external reference: clearTemporaryFiles: | **STATIC PASS** | 0 |
| 0250 | Removed selector public absence: clearBinaryPlists: | **STATIC PASS** | 0 |
| 0251 | Removed selector private declaration: clearBinaryPlists: | **STATIC PASS** | 1 |
| 0252 | Removed selector runtime implementation: clearBinaryPlists: | **STATIC PASS** | 1 |
| 0253 | Removed selector external reference: clearBinaryPlists: | **STATIC PASS** | 0 |
| 0254 | Removed selector public absence: clearEncryptedData: | **STATIC PASS** | 0 |
| 0255 | Removed selector private declaration: clearEncryptedData: | **STATIC PASS** | 1 |
| 0256 | Removed selector runtime implementation: clearEncryptedData: | **STATIC PASS** | 1 |
| 0257 | Removed selector external reference: clearEncryptedData: | **STATIC PASS** | 0 |
| 0258 | Removed selector public absence: clearJailbreakDetectionLogs: | **STATIC PASS** | 0 |
| 0259 | Removed selector private declaration: clearJailbreakDetectionLogs: | **STATIC PASS** | 1 |
| 0260 | Removed selector runtime implementation: clearJailbreakDetectionLogs: | **STATIC PASS** | 1 |
| 0261 | Removed selector external reference: clearJailbreakDetectionLogs: | **STATIC PASS** | 0 |
| 0262 | Removed selector public absence: clearSpotlightData: | **STATIC PASS** | 0 |
| 0263 | Removed selector private declaration: clearSpotlightData: | **STATIC PASS** | 1 |
| 0264 | Removed selector runtime implementation: clearSpotlightData: | **STATIC PASS** | 1 |
| 0265 | Removed selector external reference: clearSpotlightData: | **STATIC PASS** | 0 |
| 0266 | Removed selector public absence: clearSiriData: | **STATIC PASS** | 0 |
| 0267 | Removed selector private declaration: clearSiriData: | **STATIC PASS** | 1 |
| 0268 | Removed selector runtime implementation: clearSiriData: | **STATIC PASS** | 1 |
| 0269 | Removed selector external reference: clearSiriData: | **STATIC PASS** | 0 |
| 0270 | Removed selector public absence: clearSystemLoggerData: | **STATIC PASS** | 0 |
| 0271 | Removed selector private declaration: clearSystemLoggerData: | **STATIC PASS** | 1 |
| 0272 | Removed selector runtime implementation: clearSystemLoggerData: | **STATIC PASS** | 1 |
| 0273 | Removed selector external reference: clearSystemLoggerData: | **STATIC PASS** | 0 |
| 0274 | Removed selector public absence: clearASLLogs: | **STATIC PASS** | 0 |
| 0275 | Removed selector private declaration: clearASLLogs: | **STATIC PASS** | 1 |
| 0276 | Removed selector runtime implementation: clearASLLogs: | **STATIC PASS** | 1 |
| 0277 | Removed selector external reference: clearASLLogs: | **STATIC PASS** | 0 |
| 0278 | Removed selector public absence: clearPasteboardData: | **STATIC PASS** | 0 |
| 0279 | Removed selector private declaration: clearPasteboardData: | **STATIC PASS** | 1 |
| 0280 | Removed selector runtime implementation: clearPasteboardData: | **STATIC PASS** | 1 |
| 0281 | Removed selector external reference: clearPasteboardData: | **STATIC PASS** | 0 |
| 0282 | Removed selector public absence: clearURLCache: | **STATIC PASS** | 0 |
| 0283 | Removed selector private declaration: clearURLCache: | **STATIC PASS** | 1 |
| 0284 | Removed selector runtime implementation: clearURLCache: | **STATIC PASS** | 1 |
| 0285 | Removed selector external reference: clearURLCache: | **STATIC PASS** | 0 |
| 0286 | Removed selector public absence: clearBackgroundAssets: | **STATIC PASS** | 0 |
| 0287 | Removed selector private declaration: clearBackgroundAssets: | **STATIC PASS** | 1 |
| 0288 | Removed selector runtime implementation: clearBackgroundAssets: | **STATIC PASS** | 1 |
| 0289 | Removed selector external reference: clearBackgroundAssets: | **STATIC PASS** | 0 |
| 0290 | Removed selector public absence: clearSharedStorage: | **STATIC PASS** | 0 |
| 0291 | Removed selector private declaration: clearSharedStorage: | **STATIC PASS** | 1 |
| 0292 | Removed selector runtime implementation: clearSharedStorage: | **STATIC PASS** | 1 |
| 0293 | Removed selector external reference: clearSharedStorage: | **STATIC PASS** | 0 |
| 0294 | Removed selector public absence: clearAppStateData: | **STATIC PASS** | 0 |
| 0295 | Removed selector private declaration: clearAppStateData: | **STATIC PASS** | 1 |
| 0296 | Removed selector runtime implementation: clearAppStateData: | **STATIC PASS** | 1 |
| 0297 | Removed selector external reference: clearAppStateData: | **STATIC PASS** | 0 |
| 0298 | Quarantine definition: performFullCleanup: | **STATIC PASS** | 1 |
| 0299 | Quarantine body shape: performFullCleanup: | **STATIC PASS** | exact fail-closed shape |
| 0300 | Quarantine selector-only log: performFullCleanup: | **STATIC PASS** | 1 |
| 0301 | Quarantine definition: performAggressiveCleanupFor: | **STATIC PASS** | 1 |
| 0302 | Quarantine body shape: performAggressiveCleanupFor: | **STATIC PASS** | exact fail-closed shape |
| 0303 | Quarantine selector-only log: performAggressiveCleanupFor: | **STATIC PASS** | 1 |
| 0304 | Quarantine definition: completelyWipeContainer: | **STATIC PASS** | 1 |
| 0305 | Quarantine body shape: completelyWipeContainer: | **STATIC PASS** | exact fail-closed shape |
| 0306 | Quarantine selector-only log: completelyWipeContainer: | **STATIC PASS** | 1 |
| 0307 | Quarantine definition: securelyWipeFile: | **STATIC PASS** | 1 |
| 0308 | Quarantine body shape: securelyWipeFile: | **STATIC PASS** | exact fail-closed shape |
| 0309 | Quarantine selector-only log: securelyWipeFile: | **STATIC PASS** | 1 |
| 0310 | Quarantine definition: fixPermissionsAndRemovePath: | **STATIC PASS** | 1 |
| 0311 | Quarantine body shape: fixPermissionsAndRemovePath: | **STATIC PASS** | exact fail-closed shape |
| 0312 | Quarantine selector-only log: fixPermissionsAndRemovePath: | **STATIC PASS** | 1 |
| 0313 | Quarantine definition: fixPermissionsForPath: | **STATIC PASS** | 1 |
| 0314 | Quarantine body shape: fixPermissionsForPath: | **STATIC PASS** | exact fail-closed shape |
| 0315 | Quarantine selector-only log: fixPermissionsForPath: | **STATIC PASS** | 1 |
| 0316 | Quarantine definition: clearAppCache: | **STATIC PASS** | 1 |
| 0317 | Quarantine body shape: clearAppCache: | **STATIC PASS** | exact fail-closed shape |
| 0318 | Quarantine selector-only log: clearAppCache: | **STATIC PASS** | 1 |
| 0319 | Quarantine definition: clearAppPreferences: | **STATIC PASS** | 1 |
| 0320 | Quarantine body shape: clearAppPreferences: | **STATIC PASS** | exact fail-closed shape |
| 0321 | Quarantine selector-only log: clearAppPreferences: | **STATIC PASS** | 1 |
| 0322 | Quarantine definition: clearAppCookies: | **STATIC PASS** | 1 |
| 0323 | Quarantine body shape: clearAppCookies: | **STATIC PASS** | exact fail-closed shape |
| 0324 | Quarantine selector-only log: clearAppCookies: | **STATIC PASS** | 1 |
| 0325 | Quarantine definition: clearAppWebKitData: | **STATIC PASS** | 1 |
| 0326 | Quarantine body shape: clearAppWebKitData: | **STATIC PASS** | exact fail-closed shape |
| 0327 | Quarantine selector-only log: clearAppWebKitData: | **STATIC PASS** | 1 |
| 0328 | Quarantine definition: clearAppGroupData: | **STATIC PASS** | 1 |
| 0329 | Quarantine body shape: clearAppGroupData: | **STATIC PASS** | exact fail-closed shape |
| 0330 | Quarantine selector-only log: clearAppGroupData: | **STATIC PASS** | 1 |
| 0331 | Quarantine definition: clearPluginKitData: | **STATIC PASS** | 1 |
| 0332 | Quarantine body shape: clearPluginKitData: | **STATIC PASS** | exact fail-closed shape |
| 0333 | Quarantine selector-only log: clearPluginKitData: | **STATIC PASS** | 1 |
| 0334 | Quarantine definition: _internalClearEncryptedData: | **STATIC PASS** | 1 |
| 0335 | Quarantine body shape: _internalClearEncryptedData: | **STATIC PASS** | exact fail-closed shape |
| 0336 | Quarantine selector-only log: _internalClearEncryptedData: | **STATIC PASS** | 1 |
| 0337 | Quarantine definition: secureDataWipe: | **STATIC PASS** | 1 |
| 0338 | Quarantine body shape: secureDataWipe: | **STATIC PASS** | exact fail-closed shape |
| 0339 | Quarantine selector-only log: secureDataWipe: | **STATIC PASS** | 1 |
| 0340 | Quarantine definition: clearAppKeychain: | **STATIC PASS** | 1 |
| 0341 | Quarantine body shape: clearAppKeychain: | **STATIC PASS** | exact fail-closed shape |
| 0342 | Quarantine selector-only log: clearAppKeychain: | **STATIC PASS** | 1 |
| 0343 | Quarantine definition: clearKeychainData: | **STATIC PASS** | 1 |
| 0344 | Quarantine body shape: clearKeychainData: | **STATIC PASS** | exact fail-closed shape |
| 0345 | Quarantine selector-only log: clearKeychainData: | **STATIC PASS** | 1 |
| 0346 | Quarantine definition: clearKeychainItemsForBundleID: | **STATIC PASS** | 1 |
| 0347 | Quarantine body shape: clearKeychainItemsForBundleID: | **STATIC PASS** | exact fail-closed shape |
| 0348 | Quarantine selector-only log: clearKeychainItemsForBundleID: | **STATIC PASS** | 1 |
| 0349 | Quarantine definition: universalKeychainWipeForBundleID: | **STATIC PASS** | 1 |
| 0350 | Quarantine body shape: universalKeychainWipeForBundleID: | **STATIC PASS** | exact fail-closed shape |
| 0351 | Quarantine selector-only log: universalKeychainWipeForBundleID: | **STATIC PASS** | 1 |
| 0352 | Quarantine definition: wipeDirectoryContents:keepDirectoryStructure: | **STATIC PASS** | 1 |
| 0353 | Quarantine body shape: wipeDirectoryContents:keepDirectoryStructure: | **STATIC PASS** | exact fail-closed shape |
| 0354 | Quarantine selector-only log: wipeDirectoryContents:keepDirectoryStructure: | **STATIC PASS** | 1 |
| 0355 | Quarantine definition: fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec: | **STATIC PASS** | 1 |
| 0356 | Quarantine body shape: fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec: | **STATIC PASS** | exact fail-closed shape |
| 0357 | Quarantine selector-only log: fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec: | **STATIC PASS** | 1 |
| 0358 | Quarantine definition: finalSweepForContainer: | **STATIC PASS** | 1 |
| 0359 | Quarantine body shape: finalSweepForContainer: | **STATIC PASS** | exact fail-closed shape |
| 0360 | Quarantine selector-only log: finalSweepForContainer: | **STATIC PASS** | 1 |
| 0361 | Quarantine definition: wipeWebKitDirectoryContents: | **STATIC PASS** | 1 |
| 0362 | Quarantine body shape: wipeWebKitDirectoryContents: | **STATIC PASS** | exact fail-closed shape |
| 0363 | Quarantine selector-only log: wipeWebKitDirectoryContents: | **STATIC PASS** | 1 |
| 0364 | Quarantine definition: clearAppGroupContainers:withGroupUUIDs:isRootless: | **STATIC PASS** | 1 |
| 0365 | Quarantine body shape: clearAppGroupContainers:withGroupUUIDs:isRootless: | **STATIC PASS** | exact fail-closed shape |
| 0366 | Quarantine selector-only log: clearAppGroupContainers:withGroupUUIDs:isRootless: | **STATIC PASS** | 1 |
| 0367 | Quarantine definition: clearAppGroupContainers:withGroupUUIDs: | **STATIC PASS** | 1 |
| 0368 | Quarantine body shape: clearAppGroupContainers:withGroupUUIDs: | **STATIC PASS** | exact fail-closed shape |
| 0369 | Quarantine selector-only log: clearAppGroupContainers:withGroupUUIDs: | **STATIC PASS** | 1 |
| 0370 | Quarantine definition: clearExtensionContainers:forApp: | **STATIC PASS** | 1 |
| 0371 | Quarantine body shape: clearExtensionContainers:forApp: | **STATIC PASS** | exact fail-closed shape |
| 0372 | Quarantine selector-only log: clearExtensionContainers:forApp: | **STATIC PASS** | 1 |
| 0373 | Quarantine definition: cleanAppGroupContainers: | **STATIC PASS** | 1 |
| 0374 | Quarantine body shape: cleanAppGroupContainers: | **STATIC PASS** | exact fail-closed shape |
| 0375 | Quarantine selector-only log: cleanAppGroupContainers: | **STATIC PASS** | 1 |
| 0376 | Quarantine definition: _wipeRelatedDataContainersForBundleIDs: | **STATIC PASS** | 1 |
| 0377 | Quarantine body shape: _wipeRelatedDataContainersForBundleIDs: | **STATIC PASS** | exact fail-closed shape |
| 0378 | Quarantine selector-only log: _wipeRelatedDataContainersForBundleIDs: | **STATIC PASS** | 1 |
| 0379 | Quarantine definition: _wipeRelatedSystemGroupContainersForIdentifiers: | **STATIC PASS** | 1 |
| 0380 | Quarantine body shape: _wipeRelatedSystemGroupContainersForIdentifiers: | **STATIC PASS** | exact fail-closed shape |
| 0381 | Quarantine selector-only log: _wipeRelatedSystemGroupContainersForIdentifiers: | **STATIC PASS** | 1 |
| 0382 | Quarantine definition: _wipeContainersInBasePaths:matchingSubstrings:tag: | **STATIC PASS** | 1 |
| 0383 | Quarantine body shape: _wipeContainersInBasePaths:matchingSubstrings:tag: | **STATIC PASS** | exact fail-closed shape |
| 0384 | Quarantine selector-only log: _wipeContainersInBasePaths:matchingSubstrings:tag: | **STATIC PASS** | 1 |
| 0385 | Quarantine definition: _wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag: | **STATIC PASS** | 1 |
| 0386 | Quarantine body shape: _wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag: | **STATIC PASS** | exact fail-closed shape |
| 0387 | Quarantine selector-only log: _wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag: | **STATIC PASS** | 1 |
| 0388 | Quarantine definition: _scrubWebKitStateInSharedContainerBase:tag: | **STATIC PASS** | 1 |
| 0389 | Quarantine body shape: _scrubWebKitStateInSharedContainerBase:tag: | **STATIC PASS** | exact fail-closed shape |
| 0390 | Quarantine selector-only log: _scrubWebKitStateInSharedContainerBase:tag: | **STATIC PASS** | 1 |
| 0391 | Quarantine definition: cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName: | **STATIC PASS** | 1 |
| 0392 | Quarantine body shape: cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName: | **STATIC PASS** | exact fail-closed shape |
| 0393 | Quarantine selector-only log: cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName: | **STATIC PASS** | 1 |
| 0394 | Quarantine definition: deepCleanSystemSharedContainer:bundleID:appName:companyName: | **STATIC PASS** | 1 |
| 0395 | Quarantine body shape: deepCleanSystemSharedContainer:bundleID:appName:companyName: | **STATIC PASS** | exact fail-closed shape |
| 0396 | Quarantine selector-only log: deepCleanSystemSharedContainer:bundleID:appName:companyName: | **STATIC PASS** | 1 |
| 0397 | Alias mapping: performSecondaryCleanup: | **STATIC PASS** | completeAppDataWipe: |
| 0398 | Alias single-send shape: performSecondaryCleanup: | **STATIC PASS** | exactly one self message |
| 0399 | Alias mapping: clearAppData: | **STATIC PASS** | completeAppDataWipe: |
| 0400 | Alias single-send shape: clearAppData: | **STATIC PASS** | exactly one self message |
| 0401 | Alias mapping: clearSQLiteDatabases: | **STATIC PASS** | completeAppDataWipe: |
| 0402 | Alias single-send shape: clearSQLiteDatabases: | **STATIC PASS** | exactly one self message |
| 0403 | Alias mapping: clearDeviceDatabase: | **STATIC PASS** | completeAppDataWipe: |
| 0404 | Alias single-send shape: clearDeviceDatabase: | **STATIC PASS** | exactly one self message |
| 0405 | Alias mapping: clearNetworkConfigurations: | **STATIC PASS** | completeAppDataWipe: |
| 0406 | Alias single-send shape: clearNetworkConfigurations: | **STATIC PASS** | exactly one self message |
| 0407 | Alias mapping: clearCarrierData: | **STATIC PASS** | completeAppDataWipe: |
| 0408 | Alias single-send shape: clearCarrierData: | **STATIC PASS** | exactly one self message |
| 0409 | Alias mapping: clearNetworkData: | **STATIC PASS** | completeAppDataWipe: |
| 0410 | Alias single-send shape: clearNetworkData: | **STATIC PASS** | exactly one self message |
| 0411 | Alias mapping: clearDNSCache: | **STATIC PASS** | completeAppDataWipe: |
| 0412 | Alias single-send shape: clearDNSCache: | **STATIC PASS** | exactly one self message |
| 0413 | Alias mapping: clearBluetoothData: | **STATIC PASS** | completeAppDataWipe: |
| 0414 | Alias single-send shape: clearBluetoothData: | **STATIC PASS** | exactly one self message |
| 0415 | Alias mapping: clearPushNotificationData: | **STATIC PASS** | completeAppDataWipe: |
| 0416 | Alias single-send shape: clearPushNotificationData: | **STATIC PASS** | exactly one self message |
| 0417 | Alias mapping: clearGameData: | **STATIC PASS** | completeAppDataWipe: |
| 0418 | Alias single-send shape: clearGameData: | **STATIC PASS** | exactly one self message |
| 0419 | Alias mapping: clearTemporaryFiles: | **STATIC PASS** | completeAppDataWipe: |
| 0420 | Alias single-send shape: clearTemporaryFiles: | **STATIC PASS** | exactly one self message |
| 0421 | Alias mapping: clearBinaryPlists: | **STATIC PASS** | completeAppDataWipe: |
| 0422 | Alias single-send shape: clearBinaryPlists: | **STATIC PASS** | exactly one self message |
| 0423 | Alias mapping: clearJailbreakDetectionLogs: | **STATIC PASS** | completeAppDataWipe: |
| 0424 | Alias single-send shape: clearJailbreakDetectionLogs: | **STATIC PASS** | exactly one self message |
| 0425 | Alias mapping: clearSpotlightData: | **STATIC PASS** | completeAppDataWipe: |
| 0426 | Alias single-send shape: clearSpotlightData: | **STATIC PASS** | exactly one self message |
| 0427 | Alias mapping: clearSiriData: | **STATIC PASS** | completeAppDataWipe: |
| 0428 | Alias single-send shape: clearSiriData: | **STATIC PASS** | exactly one self message |
| 0429 | Alias mapping: clearURLCache: | **STATIC PASS** | completeAppDataWipe: |
| 0430 | Alias single-send shape: clearURLCache: | **STATIC PASS** | exactly one self message |
| 0431 | Alias mapping: clearBackgroundAssets: | **STATIC PASS** | completeAppDataWipe: |
| 0432 | Alias single-send shape: clearBackgroundAssets: | **STATIC PASS** | exactly one self message |
| 0433 | Alias mapping: clearSharedStorage: | **STATIC PASS** | completeAppDataWipe: |
| 0434 | Alias single-send shape: clearSharedStorage: | **STATIC PASS** | exactly one self message |
| 0435 | Alias mapping: clearSharedContainers: | **STATIC PASS** | clearAppGroupData: |
| 0436 | Alias single-send shape: clearSharedContainers: | **STATIC PASS** | exactly one self message |
| 0437 | Alias mapping: clearUserDefaults: | **STATIC PASS** | clearAppPreferences: |
| 0438 | Alias single-send shape: clearUserDefaults: | **STATIC PASS** | exactly one self message |
| 0439 | Alias mapping: clearWebCache: | **STATIC PASS** | clearAppWebKitData: |
| 0440 | Alias single-send shape: clearWebCache: | **STATIC PASS** | exactly one self message |
| 0441 | Alias mapping: clearEncryptedData: | **STATIC PASS** | _internalClearEncryptedData: |
| 0442 | Alias single-send shape: clearEncryptedData: | **STATIC PASS** | exactly one self message |
| 0443 | Alias mapping: clearInstallationLogs: | **STATIC PASS** | clearSystemLogs: |
| 0444 | Alias single-send shape: clearInstallationLogs: | **STATIC PASS** | exactly one self message |
| 0445 | Alias mapping: clearCrashReports: | **STATIC PASS** | clearSystemLogs: |
| 0446 | Alias single-send shape: clearCrashReports: | **STATIC PASS** | exactly one self message |
| 0447 | Alias mapping: clearDiagnosticData: | **STATIC PASS** | clearSystemLogs: |
| 0448 | Alias single-send shape: clearDiagnosticData: | **STATIC PASS** | exactly one self message |
| 0449 | Alias mapping: clearSystemLoggerData: | **STATIC PASS** | clearSystemLogs: |
| 0450 | Alias single-send shape: clearSystemLoggerData: | **STATIC PASS** | exactly one self message |
| 0451 | Alias mapping: clearASLLogs: | **STATIC PASS** | clearSystemLogs: |
| 0452 | Alias single-send shape: clearASLLogs: | **STATIC PASS** | exactly one self message |
| 0453 | Alias mapping: clearPrivateVarData: | **STATIC PASS** | cleanRootHideVarData: |
| 0454 | Alias single-send shape: clearPrivateVarData: | **STATIC PASS** | exactly one self message |
| 0455 | Alias mapping: clearThumbnailCache: | **STATIC PASS** | clearThumbnailCaches: |
| 0456 | Alias single-send shape: clearThumbnailCache: | **STATIC PASS** | exactly one self message |
| 0457 | Alias mapping: clearPasteboardData: | **STATIC PASS** | clearClipboard |
| 0458 | Alias single-send shape: clearPasteboardData: | **STATIC PASS** | exactly one self message |
| 0459 | Alias mapping: clearAppStateData: | **STATIC PASS** | _internalClearAppStateData: |
| 0460 | Alias single-send shape: clearAppStateData: | **STATIC PASS** | exactly one self message |
| 0461 | Protected hash: AppDataCleaner.h | **STATIC PASS** | 9c68c07115d32f2c57a1027646d6055d21375842a64064d9cfdcaeaeabe30a86 |
| 0462 | Protected hash: AppDataCleaner.m | **STATIC PASS** | 6355110ba6398a927d0f7dc1251b5e47f81f79ef47f60cf977795e451cdc916a |
| 0463 | Protected hash: PXClearRequest.h | **STATIC PASS** | d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b |
| 0464 | Protected hash: PXClearRequest.m | **STATIC PASS** | afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790 |
| 0465 | Protected hash: PXClearResult.h | **STATIC PASS** | cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592 |
| 0466 | Protected hash: PXClearResult.m | **STATIC PASS** | 0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715 |
| 0467 | Protected hash: AppDataBackupManager.h | **STATIC PASS** | b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75 |
| 0468 | Protected hash: AppDataBackupManager.m | **STATIC PASS** | 61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028 |
| 0469 | Protected hash: PXBackupManifestV4.h | **STATIC PASS** | 4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054 |
| 0470 | Protected hash: PXBackupManifestV4.m | **STATIC PASS** | 4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037 |
| 0471 | Protected hash: PXBackupManifestValidator.h | **STATIC PASS** | 6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836 |
| 0472 | Protected hash: PXBackupManifestValidator.m | **STATIC PASS** | 8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b |
| 0473 | Protected hash: PXBackupDirectoryDiscovery.h | **STATIC PASS** | da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2 |
| 0474 | Protected hash: PXBackupDirectoryDiscovery.m | **STATIC PASS** | f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5 |
| 0475 | Protected hash: PXRestoreResult.h | **STATIC PASS** | cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d |
| 0476 | Protected hash: PXRestoreResult.m | **STATIC PASS** | c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb |
| 0477 | Protected hash: AppDataBackupRestoreViewController.h | **STATIC PASS** | b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf |
| 0478 | Protected hash: AppDataBackupRestoreViewController.m | **STATIC PASS** | 23c964fac0189119c500665a700fe1fb7dafa77fd63779dccaa9e084cefa26c5 |
| 0479 | Protected hash: KeychainHelper/PXKeychainHelperExitCode.h | **STATIC PASS** | a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a |
| 0480 | Protected hash: KeychainHelper/PXKeychainHelperResult.h | **STATIC PASS** | 4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3 |
| 0481 | Protected hash: KeychainHelper/PXKeychainHelperResult.m | **STATIC PASS** | 1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5 |
| 0482 | Protected hash: KeychainHelper/KeychainBackupHelper.h | **STATIC PASS** | 7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c |
| 0483 | Protected hash: KeychainHelper/KeychainBackupHelper.m | **STATIC PASS** | 324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2 |
| 0484 | Protected hash: KeychainHelper/backup_helper.m | **STATIC PASS** | 897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7 |
| 0485 | Protected hash: scripts/keychain_backup.sh | **STATIC PASS** | 46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12 |
| 0486 | Protected hash: Makefile | **STATIC PASS** | b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa |
| 0487 | Protected hash: ProjectXViewController.m | **STATIC PASS** | b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162 |
| 0488 | Protected hash: main.m | **STATIC PASS** | 7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da |
| 0489 | Protected hash: docs/backup-restore-hardening/reports/TASK-6.2-REPORT.md | **STATIC PASS** | 44f5fc54dbafebaa0ea79f1cd4247043f0fdcb4f249ce5328cb7c19671b371c1 |
| 0490 | Guard group ALS | **STATIC PASS** | 132 PASS |
| 0491 | Guard group API | **STATIC PASS** | 229 PASS |
| 0492 | Guard group CLR | **STATIC PASS** | 13 PASS |
| 0493 | Guard group ENV | **STATIC PASS** | 1097 PASS |
| 0494 | Guard group KEY | **STATIC PASS** | 8 PASS |
| 0495 | Guard group MAN | **STATIC PASS** | 9 PASS |
| 0496 | Guard group PERM | **STATIC PASS** | 14 PASS |
| 0497 | Guard group QTN | **STATIC PASS** | 174 PASS |
| 0498 | Guard group UI | **STATIC PASS** | 19 PASS |
| 0499 | Guard group WF | **STATIC PASS** | 4 PASS |
| 0500 | Repository guard BRH-ALS-DEFINITION-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0501 | Repository guard BRH-ALS-DEFINITION-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0502 | Repository guard BRH-ALS-DEFINITION-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0503 | Repository guard BRH-ALS-DEFINITION-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0504 | Repository guard BRH-ALS-DEFINITION-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0505 | Repository guard BRH-ALS-DEFINITION-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0506 | Repository guard BRH-ALS-DEFINITION-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0507 | Repository guard BRH-ALS-DEFINITION-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0508 | Repository guard BRH-ALS-DEFINITION-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0509 | Repository guard BRH-ALS-DEFINITION-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0510 | Repository guard BRH-ALS-DEFINITION-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0511 | Repository guard BRH-ALS-DEFINITION-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0512 | Repository guard BRH-ALS-DEFINITION-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0513 | Repository guard BRH-ALS-DEFINITION-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0514 | Repository guard BRH-ALS-DEFINITION-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0515 | Repository guard BRH-ALS-DEFINITION-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0516 | Repository guard BRH-ALS-DEFINITION-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0517 | Repository guard BRH-ALS-DEFINITION-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0518 | Repository guard BRH-ALS-DEFINITION-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0519 | Repository guard BRH-ALS-DEFINITION-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0520 | Repository guard BRH-ALS-DEFINITION-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0521 | Repository guard BRH-ALS-DEFINITION-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0522 | Repository guard BRH-ALS-DEFINITION-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0523 | Repository guard BRH-ALS-DEFINITION-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0524 | Repository guard BRH-ALS-DEFINITION-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0525 | Repository guard BRH-ALS-DEFINITION-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0526 | Repository guard BRH-ALS-DEFINITION-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0527 | Repository guard BRH-ALS-DEFINITION-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0528 | Repository guard BRH-ALS-DEFINITION-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0529 | Repository guard BRH-ALS-DEFINITION-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0530 | Repository guard BRH-ALS-DEFINITION-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0531 | Repository guard BRH-ALS-DEFINITION-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0532 | Repository guard BRH-ALS-GROUP-DATA | **STATIC PASS** | PASS |
| 0533 | Repository guard BRH-ALS-GROUP-DIRECT | **STATIC PASS** | PASS |
| 0534 | Repository guard BRH-ALS-GROUP-LOGS | **STATIC PASS** | PASS |
| 0535 | Repository guard BRH-ALS-GROUP-QUARANTINE | **STATIC PASS** | PASS |
| 0536 | Repository guard BRH-ALS-MAP-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0537 | Repository guard BRH-ALS-MAP-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0538 | Repository guard BRH-ALS-MAP-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0539 | Repository guard BRH-ALS-MAP-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0540 | Repository guard BRH-ALS-MAP-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0541 | Repository guard BRH-ALS-MAP-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0542 | Repository guard BRH-ALS-MAP-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0543 | Repository guard BRH-ALS-MAP-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0544 | Repository guard BRH-ALS-MAP-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0545 | Repository guard BRH-ALS-MAP-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0546 | Repository guard BRH-ALS-MAP-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0547 | Repository guard BRH-ALS-MAP-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0548 | Repository guard BRH-ALS-MAP-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0549 | Repository guard BRH-ALS-MAP-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0550 | Repository guard BRH-ALS-MAP-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0551 | Repository guard BRH-ALS-MAP-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0552 | Repository guard BRH-ALS-MAP-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0553 | Repository guard BRH-ALS-MAP-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0554 | Repository guard BRH-ALS-MAP-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0555 | Repository guard BRH-ALS-MAP-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0556 | Repository guard BRH-ALS-MAP-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0557 | Repository guard BRH-ALS-MAP-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0558 | Repository guard BRH-ALS-MAP-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0559 | Repository guard BRH-ALS-MAP-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0560 | Repository guard BRH-ALS-MAP-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0561 | Repository guard BRH-ALS-MAP-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0562 | Repository guard BRH-ALS-MAP-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0563 | Repository guard BRH-ALS-MAP-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0564 | Repository guard BRH-ALS-MAP-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0565 | Repository guard BRH-ALS-MAP-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0566 | Repository guard BRH-ALS-MAP-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0567 | Repository guard BRH-ALS-MAP-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0568 | Repository guard BRH-ALS-SHAPE-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0569 | Repository guard BRH-ALS-SHAPE-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0570 | Repository guard BRH-ALS-SHAPE-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0571 | Repository guard BRH-ALS-SHAPE-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0572 | Repository guard BRH-ALS-SHAPE-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0573 | Repository guard BRH-ALS-SHAPE-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0574 | Repository guard BRH-ALS-SHAPE-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0575 | Repository guard BRH-ALS-SHAPE-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0576 | Repository guard BRH-ALS-SHAPE-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0577 | Repository guard BRH-ALS-SHAPE-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0578 | Repository guard BRH-ALS-SHAPE-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0579 | Repository guard BRH-ALS-SHAPE-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0580 | Repository guard BRH-ALS-SHAPE-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0581 | Repository guard BRH-ALS-SHAPE-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0582 | Repository guard BRH-ALS-SHAPE-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0583 | Repository guard BRH-ALS-SHAPE-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0584 | Repository guard BRH-ALS-SHAPE-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0585 | Repository guard BRH-ALS-SHAPE-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0586 | Repository guard BRH-ALS-SHAPE-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0587 | Repository guard BRH-ALS-SHAPE-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0588 | Repository guard BRH-ALS-SHAPE-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0589 | Repository guard BRH-ALS-SHAPE-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0590 | Repository guard BRH-ALS-SHAPE-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0591 | Repository guard BRH-ALS-SHAPE-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0592 | Repository guard BRH-ALS-SHAPE-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0593 | Repository guard BRH-ALS-SHAPE-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0594 | Repository guard BRH-ALS-SHAPE-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0595 | Repository guard BRH-ALS-SHAPE-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0596 | Repository guard BRH-ALS-SHAPE-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0597 | Repository guard BRH-ALS-SHAPE-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0598 | Repository guard BRH-ALS-SHAPE-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0599 | Repository guard BRH-ALS-SHAPE-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0600 | Repository guard BRH-ALS-SINGLE-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0601 | Repository guard BRH-ALS-SINGLE-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0602 | Repository guard BRH-ALS-SINGLE-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0603 | Repository guard BRH-ALS-SINGLE-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0604 | Repository guard BRH-ALS-SINGLE-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0605 | Repository guard BRH-ALS-SINGLE-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0606 | Repository guard BRH-ALS-SINGLE-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0607 | Repository guard BRH-ALS-SINGLE-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0608 | Repository guard BRH-ALS-SINGLE-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0609 | Repository guard BRH-ALS-SINGLE-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0610 | Repository guard BRH-ALS-SINGLE-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0611 | Repository guard BRH-ALS-SINGLE-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0612 | Repository guard BRH-ALS-SINGLE-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0613 | Repository guard BRH-ALS-SINGLE-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0614 | Repository guard BRH-ALS-SINGLE-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0615 | Repository guard BRH-ALS-SINGLE-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0616 | Repository guard BRH-ALS-SINGLE-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0617 | Repository guard BRH-ALS-SINGLE-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0618 | Repository guard BRH-ALS-SINGLE-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0619 | Repository guard BRH-ALS-SINGLE-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0620 | Repository guard BRH-ALS-SINGLE-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0621 | Repository guard BRH-ALS-SINGLE-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0622 | Repository guard BRH-ALS-SINGLE-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0623 | Repository guard BRH-ALS-SINGLE-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0624 | Repository guard BRH-ALS-SINGLE-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0625 | Repository guard BRH-ALS-SINGLE-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0626 | Repository guard BRH-ALS-SINGLE-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0627 | Repository guard BRH-ALS-SINGLE-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0628 | Repository guard BRH-ALS-SINGLE-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0629 | Repository guard BRH-ALS-SINGLE-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0630 | Repository guard BRH-ALS-SINGLE-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0631 | Repository guard BRH-ALS-SINGLE-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0632 | Repository guard BRH-API-PUBLIC-CLASS-COUNT | **STATIC PASS** | PASS |
| 0633 | Repository guard BRH-API-PUBLIC-CLASS-EXACT | **STATIC PASS** | PASS |
| 0634 | Repository guard BRH-API-PUBLIC-CLASS-SHAREDMANAGER | **STATIC PASS** | PASS |
| 0635 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEANICONSTATEPLIST | **STATIC PASS** | PASS |
| 0636 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEANLAUNCHSERVICESDATABASE | **STATIC PASS** | PASS |
| 0637 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEANSIRIANALYTICSDATABASE | **STATIC PASS** | PASS |
| 0638 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARAPPRECEIPTDATA-WITHBUNDLEUUID | **STATIC PASS** | PASS |
| 0639 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARCLIPBOARD | **STATIC PASS** | PASS |
| 0640 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARDATAFORBUNDLEID-COMPLETION | **STATIC PASS** | PASS |
| 0641 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARHEALTHDATA | **STATIC PASS** | PASS |
| 0642 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARICLOUDDATA | **STATIC PASS** | PASS |
| 0643 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARMEDIADATA | **STATIC PASS** | PASS |
| 0644 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARSAFARIDATA | **STATIC PASS** | PASS |
| 0645 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARSPOTLIGHTINDEXES | **STATIC PASS** | PASS |
| 0646 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARSYSTEMLOGS | **STATIC PASS** | PASS |
| 0647 | Repository guard BRH-API-PUBLIC-INSTANCE-CLEARURLCREDENTIALSFORBUNDLEID | **STATIC PASS** | PASS |
| 0648 | Repository guard BRH-API-PUBLIC-INSTANCE-COMPLETEAPPDATAWIPE | **STATIC PASS** | PASS |
| 0649 | Repository guard BRH-API-PUBLIC-INSTANCE-COUNT | **STATIC PASS** | PASS |
| 0650 | Repository guard BRH-API-PUBLIC-INSTANCE-EXACT | **STATIC PASS** | PASS |
| 0651 | Repository guard BRH-API-PUBLIC-INSTANCE-FINDBUNDLECONTAINERUUIDFORBUNDLEID | **STATIC PASS** | PASS |
| 0652 | Repository guard BRH-API-PUBLIC-INSTANCE-FINDDATACONTAINERUUIDFORBUNDLEID | **STATIC PASS** | PASS |
| 0653 | Repository guard BRH-API-PUBLIC-INSTANCE-FINDEXTENSIONDATACONTAINERSFORBUNDLEID | **STATIC PASS** | PASS |
| 0654 | Repository guard BRH-API-PUBLIC-INSTANCE-FINDGROUPCONTAINERUUIDSFORBUNDLEID | **STATIC PASS** | PASS |
| 0655 | Repository guard BRH-API-PUBLIC-INSTANCE-GETDATAUSAGE | **STATIC PASS** | PASS |
| 0656 | Repository guard BRH-API-PUBLIC-INSTANCE-HASDATATOCLEAR | **STATIC PASS** | PASS |
| 0657 | Repository guard BRH-API-PUBLIC-INSTANCE-HASKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 0658 | Repository guard BRH-API-PUBLIC-INSTANCE-INTERNALCLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0659 | Repository guard BRH-API-PUBLIC-INSTANCE-REFRESHSYSTEMSERVICES | **STATIC PASS** | PASS |
| 0660 | Repository guard BRH-API-PUBLIC-INSTANCE-VERIFYDATACLEARED | **STATIC PASS** | PASS |
| 0661 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 0662 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 0663 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0664 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 0665 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 0666 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 0667 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0668 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 0669 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0670 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0671 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0672 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0673 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0674 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0675 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0676 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0677 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0678 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0679 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0680 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0681 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0682 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 0683 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 0684 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0685 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0686 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0687 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 0688 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0689 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0690 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0691 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0692 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0693 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0694 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0695 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0696 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0697 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0698 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0699 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0700 | Repository guard BRH-API-REMOVED-EXTERNAL-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0701 | Repository guard BRH-API-REMOVED-EXTERNAL-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 0702 | Repository guard BRH-API-REMOVED-EXTERNAL-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 0703 | Repository guard BRH-API-REMOVED-EXTERNAL-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 0704 | Repository guard BRH-API-REMOVED-EXTERNAL-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0705 | Repository guard BRH-API-REMOVED-EXTERNAL-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 0706 | Repository guard BRH-API-REMOVED-EXTERNAL-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 0707 | Repository guard BRH-API-REMOVED-EXTERNAL-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0708 | Repository guard BRH-API-REMOVED-EXTERNAL-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 0709 | Repository guard BRH-API-REMOVED-EXTERNAL-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 0710 | Repository guard BRH-API-REMOVED-EXTERNAL-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 0711 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 0712 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 0713 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0714 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 0715 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 0716 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 0717 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0718 | Repository guard BRH-API-REMOVED-IMPL-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 0719 | Repository guard BRH-API-REMOVED-IMPL-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0720 | Repository guard BRH-API-REMOVED-IMPL-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0721 | Repository guard BRH-API-REMOVED-IMPL-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0722 | Repository guard BRH-API-REMOVED-IMPL-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0723 | Repository guard BRH-API-REMOVED-IMPL-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0724 | Repository guard BRH-API-REMOVED-IMPL-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0725 | Repository guard BRH-API-REMOVED-IMPL-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0726 | Repository guard BRH-API-REMOVED-IMPL-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0727 | Repository guard BRH-API-REMOVED-IMPL-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0728 | Repository guard BRH-API-REMOVED-IMPL-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0729 | Repository guard BRH-API-REMOVED-IMPL-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0730 | Repository guard BRH-API-REMOVED-IMPL-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0731 | Repository guard BRH-API-REMOVED-IMPL-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0732 | Repository guard BRH-API-REMOVED-IMPL-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 0733 | Repository guard BRH-API-REMOVED-IMPL-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 0734 | Repository guard BRH-API-REMOVED-IMPL-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0735 | Repository guard BRH-API-REMOVED-IMPL-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0736 | Repository guard BRH-API-REMOVED-IMPL-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0737 | Repository guard BRH-API-REMOVED-IMPL-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 0738 | Repository guard BRH-API-REMOVED-IMPL-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0739 | Repository guard BRH-API-REMOVED-IMPL-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0740 | Repository guard BRH-API-REMOVED-IMPL-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0741 | Repository guard BRH-API-REMOVED-IMPL-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0742 | Repository guard BRH-API-REMOVED-IMPL-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0743 | Repository guard BRH-API-REMOVED-IMPL-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0744 | Repository guard BRH-API-REMOVED-IMPL-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0745 | Repository guard BRH-API-REMOVED-IMPL-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0746 | Repository guard BRH-API-REMOVED-IMPL-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0747 | Repository guard BRH-API-REMOVED-IMPL-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0748 | Repository guard BRH-API-REMOVED-IMPL-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0749 | Repository guard BRH-API-REMOVED-IMPL-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0750 | Repository guard BRH-API-REMOVED-IMPL-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0751 | Repository guard BRH-API-REMOVED-IMPL-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 0752 | Repository guard BRH-API-REMOVED-IMPL-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 0753 | Repository guard BRH-API-REMOVED-IMPL-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 0754 | Repository guard BRH-API-REMOVED-IMPL-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0755 | Repository guard BRH-API-REMOVED-IMPL-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 0756 | Repository guard BRH-API-REMOVED-IMPL-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 0757 | Repository guard BRH-API-REMOVED-IMPL-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0758 | Repository guard BRH-API-REMOVED-IMPL-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 0759 | Repository guard BRH-API-REMOVED-IMPL-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 0760 | Repository guard BRH-API-REMOVED-IMPL-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 0761 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 0762 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 0763 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0764 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 0765 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 0766 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 0767 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0768 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 0769 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0770 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0771 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0772 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0773 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0774 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0775 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0776 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0777 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0778 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0779 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0780 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0781 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0782 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 0783 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 0784 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0785 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0786 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0787 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 0788 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0789 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0790 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0791 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0792 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0793 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0794 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0795 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0796 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0797 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0798 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0799 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0800 | Repository guard BRH-API-REMOVED-PRIVATE-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0801 | Repository guard BRH-API-REMOVED-PRIVATE-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 0802 | Repository guard BRH-API-REMOVED-PRIVATE-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 0803 | Repository guard BRH-API-REMOVED-PRIVATE-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 0804 | Repository guard BRH-API-REMOVED-PRIVATE-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0805 | Repository guard BRH-API-REMOVED-PRIVATE-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 0806 | Repository guard BRH-API-REMOVED-PRIVATE-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 0807 | Repository guard BRH-API-REMOVED-PRIVATE-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0808 | Repository guard BRH-API-REMOVED-PRIVATE-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 0809 | Repository guard BRH-API-REMOVED-PRIVATE-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 0810 | Repository guard BRH-API-REMOVED-PRIVATE-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 0811 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 0812 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 0813 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPDATA | **STATIC PASS** | PASS |
| 0814 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 0815 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 0816 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 0817 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPSTATEDATA | **STATIC PASS** | PASS |
| 0818 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 0819 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARASLLOGS | **STATIC PASS** | PASS |
| 0820 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARBACKGROUNDASSETS | **STATIC PASS** | PASS |
| 0821 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARBINARYPLISTS | **STATIC PASS** | PASS |
| 0822 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARBLUETOOTHDATA | **STATIC PASS** | PASS |
| 0823 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARCARRIERDATA | **STATIC PASS** | PASS |
| 0824 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARCRASHREPORTS | **STATIC PASS** | PASS |
| 0825 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARDEVICEDATABASE | **STATIC PASS** | PASS |
| 0826 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARDIAGNOSTICDATA | **STATIC PASS** | PASS |
| 0827 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARDNSCACHE | **STATIC PASS** | PASS |
| 0828 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0829 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARGAMEDATA | **STATIC PASS** | PASS |
| 0830 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARINSTALLATIONLOGS | **STATIC PASS** | PASS |
| 0831 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARJAILBREAKDETECTIONLOGS | **STATIC PASS** | PASS |
| 0832 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 0833 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 0834 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARNETWORKCONFIGURATIONS | **STATIC PASS** | PASS |
| 0835 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARNETWORKDATA | **STATIC PASS** | PASS |
| 0836 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARPASTEBOARDDATA | **STATIC PASS** | PASS |
| 0837 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 0838 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARPRIVATEVARDATA | **STATIC PASS** | PASS |
| 0839 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARPUSHNOTIFICATIONDATA | **STATIC PASS** | PASS |
| 0840 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARSHAREDCONTAINERS | **STATIC PASS** | PASS |
| 0841 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARSHAREDSTORAGE | **STATIC PASS** | PASS |
| 0842 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARSIRIDATA | **STATIC PASS** | PASS |
| 0843 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARSPOTLIGHTDATA | **STATIC PASS** | PASS |
| 0844 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARSQLITEDATABASES | **STATIC PASS** | PASS |
| 0845 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARSYSTEMLOGGERDATA | **STATIC PASS** | PASS |
| 0846 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARTEMPORARYFILES | **STATIC PASS** | PASS |
| 0847 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARTHUMBNAILCACHE | **STATIC PASS** | PASS |
| 0848 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARURLCACHE | **STATIC PASS** | PASS |
| 0849 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARUSERDEFAULTS | **STATIC PASS** | PASS |
| 0850 | Repository guard BRH-API-REMOVED-PUBLIC-CLEARWEBCACHE | **STATIC PASS** | PASS |
| 0851 | Repository guard BRH-API-REMOVED-PUBLIC-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 0852 | Repository guard BRH-API-REMOVED-PUBLIC-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 0853 | Repository guard BRH-API-REMOVED-PUBLIC-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 0854 | Repository guard BRH-API-REMOVED-PUBLIC-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0855 | Repository guard BRH-API-REMOVED-PUBLIC-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 0856 | Repository guard BRH-API-REMOVED-PUBLIC-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 0857 | Repository guard BRH-API-REMOVED-PUBLIC-PERFORMSECONDARYCLEANUP | **STATIC PASS** | PASS |
| 0858 | Repository guard BRH-API-REMOVED-PUBLIC-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 0859 | Repository guard BRH-API-REMOVED-PUBLIC-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 0860 | Repository guard BRH-API-REMOVED-PUBLIC-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 0861 | Repository guard BRH-CLR-DATA-DEFINITION | **STATIC PASS** | PASS |
| 0862 | Repository guard BRH-CLR-DATA-MASK | **STATIC PASS** | PASS |
| 0863 | Repository guard BRH-CLR-DATA-NO-KEYCHAIN | **STATIC PASS** | PASS |
| 0864 | Repository guard BRH-CLR-DATA-NO-REMOVED | **STATIC PASS** | PASS |
| 0865 | Repository guard BRH-CLR-DATA-ROUTE | **STATIC PASS** | PASS |
| 0866 | Repository guard BRH-CLR-DEFAULT-MASK | **STATIC PASS** | PASS |
| 0867 | Repository guard BRH-CLR-FAILURE-PRECEDENCE | **STATIC PASS** | PASS |
| 0868 | Repository guard BRH-CLR-FULL-DEFINITION | **STATIC PASS** | PASS |
| 0869 | Repository guard BRH-CLR-FULL-MASK | **STATIC PASS** | PASS |
| 0870 | Repository guard BRH-CLR-FULL-NO-REMOVED | **STATIC PASS** | PASS |
| 0871 | Repository guard BRH-CLR-FULL-ROUTE | **STATIC PASS** | PASS |
| 0872 | Repository guard BRH-CLR-KNOWN-MASK | **STATIC PASS** | PASS |
| 0873 | Repository guard BRH-CLR-SCOPE-ENUM | **STATIC PASS** | PASS |
| 0874 | Repository guard BRH-ENV-GUARD-FLOOR | **STATIC PASS** | PASS |
| 0875 | Repository guard BRH-KEY-DELETE-COUNT | **STATIC PASS** | PASS |
| 0876 | Repository guard BRH-KEY-DELETE-WIPE-ONLY | **STATIC PASS** | PASS |
| 0877 | Repository guard BRH-KEY-EXIT-ENUM | **STATIC PASS** | PASS |
| 0878 | Repository guard BRH-KEY-EXIT-PARITY | **STATIC PASS** | PASS |
| 0879 | Repository guard BRH-KEY-RESTORE-NO-DELETE | **STATIC PASS** | PASS |
| 0880 | Repository guard BRH-KEY-RESTORE-PROCESS | **STATIC PASS** | PASS |
| 0881 | Repository guard BRH-KEY-RESTORE-UPDATE | **STATIC PASS** | PASS |
| 0882 | Repository guard BRH-KEY-WRAPPER-OVERWRITE | **STATIC PASS** | PASS |
| 0883 | Repository guard BRH-MAN-DISCOVERY-VERSIONS | **STATIC PASS** | PASS |
| 0884 | Repository guard BRH-MAN-MANAGER-VERSIONS | **STATIC PASS** | PASS |
| 0885 | Repository guard BRH-MAN-UI-VERSION-RANGE | **STATIC PASS** | PASS |
| 0886 | Repository guard BRH-MAN-V4-CONTENT | **STATIC PASS** | PASS |
| 0887 | Repository guard BRH-MAN-V4-DIGEST | **STATIC PASS** | PASS |
| 0888 | Repository guard BRH-MAN-V4-PUBLICATION | **STATIC PASS** | PASS |
| 0889 | Repository guard BRH-MAN-V4-PXBACKUPMANIFESTV4SCHEMAREVISION | **STATIC PASS** | PASS |
| 0890 | Repository guard BRH-MAN-V4-PXBACKUPMANIFESTV4VERSION | **STATIC PASS** | PASS |
| 0891 | Repository guard BRH-MAN-V4-SCHEMA | **STATIC PASS** | PASS |
| 0892 | Repository guard BRH-PERM-ASSISTANT-SERVICES | **STATIC PASS** | PASS |
| 0893 | Repository guard BRH-PERM-CHFLAGS-COUNT | **STATIC PASS** | PASS |
| 0894 | Repository guard BRH-PERM-CHFLAGS-ROUTE | **STATIC PASS** | PASS |
| 0895 | Repository guard BRH-PERM-CHMOD-RECURSIVE | **STATIC PASS** | PASS |
| 0896 | Repository guard BRH-PERM-CHOWN-RECURSIVE-CLEAR | **STATIC PASS** | PASS |
| 0897 | Repository guard BRH-PERM-FINAL-SWEEP | **STATIC PASS** | PASS |
| 0898 | Repository guard BRH-PERM-FIND-CHMOD | **STATIC PASS** | PASS |
| 0899 | Repository guard BRH-PERM-MARKER-INITIALIZED | **STATIC PASS** | PASS |
| 0900 | Repository guard BRH-PERM-MARKER-NOMEDIA | **STATIC PASS** | PASS |
| 0901 | Repository guard BRH-PERM-MARKER-TOUCH | **STATIC PASS** | PASS |
| 0902 | Repository guard BRH-PERM-RECEIPT-DEFINITION | **STATIC PASS** | PASS |
| 0903 | Repository guard BRH-PERM-RECEIPT-NO-MUTATION | **STATIC PASS** | PASS |
| 0904 | Repository guard BRH-PERM-RECEIPT-READONLY | **STATIC PASS** | PASS |
| 0905 | Repository guard BRH-PERM-RESTORE-CHOWN-BOUNDED | **STATIC PASS** | PASS |
| 0906 | Repository guard BRH-QTN-ARGS-CLEANAPPGROUPCONTAINERS | **STATIC PASS** | PASS |
| 0907 | Repository guard BRH-QTN-ARGS-CLEANAPPSPECIFICFILESINSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 0908 | Repository guard BRH-QTN-ARGS-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 0909 | Repository guard BRH-QTN-ARGS-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 0910 | Repository guard BRH-QTN-ARGS-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS | **STATIC PASS** | PASS |
| 0911 | Repository guard BRH-QTN-ARGS-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS-ISROOTLESS | **STATIC PASS** | PASS |
| 0912 | Repository guard BRH-QTN-ARGS-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 0913 | Repository guard BRH-QTN-ARGS-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 0914 | Repository guard BRH-QTN-ARGS-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 0915 | Repository guard BRH-QTN-ARGS-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 0916 | Repository guard BRH-QTN-ARGS-CLEAREXTENSIONCONTAINERS-FORAPP | **STATIC PASS** | PASS |
| 0917 | Repository guard BRH-QTN-ARGS-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 0918 | Repository guard BRH-QTN-ARGS-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 0919 | Repository guard BRH-QTN-ARGS-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 0920 | Repository guard BRH-QTN-ARGS-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 0921 | Repository guard BRH-QTN-ARGS-DEEPCLEANSYSTEMSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 0922 | Repository guard BRH-QTN-ARGS-FASTWIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE-TIMEOUTSEC | **STATIC PASS** | PASS |
| 0923 | Repository guard BRH-QTN-ARGS-FINALSWEEPFORCONTAINER | **STATIC PASS** | PASS |
| 0924 | Repository guard BRH-QTN-ARGS-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 0925 | Repository guard BRH-QTN-ARGS-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 0926 | Repository guard BRH-QTN-ARGS-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0927 | Repository guard BRH-QTN-ARGS-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 0928 | Repository guard BRH-QTN-ARGS-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 0929 | Repository guard BRH-QTN-ARGS-SCRUBWEBKITSTATEINSHAREDCONTAINERBASE-TAG | **STATIC PASS** | PASS |
| 0930 | Repository guard BRH-QTN-ARGS-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 0931 | Repository guard BRH-QTN-ARGS-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 0932 | Repository guard BRH-QTN-ARGS-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 0933 | Repository guard BRH-QTN-ARGS-WIPECONTAINERSINBASEPATHS-MATCHINGSUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 0934 | Repository guard BRH-QTN-ARGS-WIPEDATACONTAINERSBYIDENTIFIERPREFIXORSUBSTRING-SUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 0935 | Repository guard BRH-QTN-ARGS-WIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE | **STATIC PASS** | PASS |
| 0936 | Repository guard BRH-QTN-ARGS-WIPERELATEDDATACONTAINERSFORBUNDLEIDS | **STATIC PASS** | PASS |
| 0937 | Repository guard BRH-QTN-ARGS-WIPERELATEDSYSTEMGROUPCONTAINERSFORIDENTIFIERS | **STATIC PASS** | PASS |
| 0938 | Repository guard BRH-QTN-ARGS-WIPEWEBKITDIRECTORYCONTENTS | **STATIC PASS** | PASS |
| 0939 | Repository guard BRH-QTN-DEFINITION-CLEANAPPGROUPCONTAINERS | **STATIC PASS** | PASS |
| 0940 | Repository guard BRH-QTN-DEFINITION-CLEANAPPSPECIFICFILESINSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 0941 | Repository guard BRH-QTN-DEFINITION-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 0942 | Repository guard BRH-QTN-DEFINITION-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 0943 | Repository guard BRH-QTN-DEFINITION-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS | **STATIC PASS** | PASS |
| 0944 | Repository guard BRH-QTN-DEFINITION-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS-ISROOTLESS | **STATIC PASS** | PASS |
| 0945 | Repository guard BRH-QTN-DEFINITION-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 0946 | Repository guard BRH-QTN-DEFINITION-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 0947 | Repository guard BRH-QTN-DEFINITION-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 0948 | Repository guard BRH-QTN-DEFINITION-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 0949 | Repository guard BRH-QTN-DEFINITION-CLEAREXTENSIONCONTAINERS-FORAPP | **STATIC PASS** | PASS |
| 0950 | Repository guard BRH-QTN-DEFINITION-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 0951 | Repository guard BRH-QTN-DEFINITION-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 0952 | Repository guard BRH-QTN-DEFINITION-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 0953 | Repository guard BRH-QTN-DEFINITION-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 0954 | Repository guard BRH-QTN-DEFINITION-DEEPCLEANSYSTEMSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 0955 | Repository guard BRH-QTN-DEFINITION-FASTWIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE-TIMEOUTSEC | **STATIC PASS** | PASS |
| 0956 | Repository guard BRH-QTN-DEFINITION-FINALSWEEPFORCONTAINER | **STATIC PASS** | PASS |
| 0957 | Repository guard BRH-QTN-DEFINITION-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 0958 | Repository guard BRH-QTN-DEFINITION-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 0959 | Repository guard BRH-QTN-DEFINITION-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 0960 | Repository guard BRH-QTN-DEFINITION-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 0961 | Repository guard BRH-QTN-DEFINITION-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 0962 | Repository guard BRH-QTN-DEFINITION-SCRUBWEBKITSTATEINSHAREDCONTAINERBASE-TAG | **STATIC PASS** | PASS |
| 0963 | Repository guard BRH-QTN-DEFINITION-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 0964 | Repository guard BRH-QTN-DEFINITION-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 0965 | Repository guard BRH-QTN-DEFINITION-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 0966 | Repository guard BRH-QTN-DEFINITION-WIPECONTAINERSINBASEPATHS-MATCHINGSUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 0967 | Repository guard BRH-QTN-DEFINITION-WIPEDATACONTAINERSBYIDENTIFIERPREFIXORSUBSTRING-SUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 0968 | Repository guard BRH-QTN-DEFINITION-WIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE | **STATIC PASS** | PASS |
| 0969 | Repository guard BRH-QTN-DEFINITION-WIPERELATEDDATACONTAINERSFORBUNDLEIDS | **STATIC PASS** | PASS |
| 0970 | Repository guard BRH-QTN-DEFINITION-WIPERELATEDSYSTEMGROUPCONTAINERSFORIDENTIFIERS | **STATIC PASS** | PASS |
| 0971 | Repository guard BRH-QTN-DEFINITION-WIPEWEBKITDIRECTORYCONTENTS | **STATIC PASS** | PASS |
| 0972 | Repository guard BRH-QTN-FORBIDDEN-APPGROUPCONTAINERRESOLVER | **STATIC PASS** | PASS |
| 0973 | Repository guard BRH-QTN-FORBIDDEN-CLEARDATAFORBUNDLEID | **STATIC PASS** | PASS |
| 0974 | Repository guard BRH-QTN-FORBIDDEN-COMMANDRUNNER | **STATIC PASS** | PASS |
| 0975 | Repository guard BRH-QTN-FORBIDDEN-COMPLETEAPPDATAWIPE | **STATIC PASS** | PASS |
| 0976 | Repository guard BRH-QTN-FORBIDDEN-CONTAINSSTRING | **STATIC PASS** | PASS |
| 0977 | Repository guard BRH-QTN-FORBIDDEN-CONTENTSOFDIRECTORYATPATH | **STATIC PASS** | PASS |
| 0978 | Repository guard BRH-QTN-FORBIDDEN-COPYITEM | **STATIC PASS** | PASS |
| 0979 | Repository guard BRH-QTN-FORBIDDEN-CREATEDIRECTORY | **STATIC PASS** | PASS |
| 0980 | Repository guard BRH-QTN-FORBIDDEN-DICTIONARYWITHCONTENTSOFFILE | **STATIC PASS** | PASS |
| 0981 | Repository guard BRH-QTN-FORBIDDEN-DISPATCH-APPLY | **STATIC PASS** | PASS |
| 0982 | Repository guard BRH-QTN-FORBIDDEN-DISPATCH-ASYNC | **STATIC PASS** | PASS |
| 0983 | Repository guard BRH-QTN-FORBIDDEN-ENUMERATORATPATH | **STATIC PASS** | PASS |
| 0984 | Repository guard BRH-QTN-FORBIDDEN-FILEEXISTSATPATH | **STATIC PASS** | PASS |
| 0985 | Repository guard BRH-QTN-FORBIDDEN-HASPREFIX | **STATIC PASS** | PASS |
| 0986 | Repository guard BRH-QTN-FORBIDDEN-KILLALL | **STATIC PASS** | PASS |
| 0987 | Repository guard BRH-QTN-FORBIDDEN-LOWERCASESTRING | **STATIC PASS** | PASS |
| 0988 | Repository guard BRH-QTN-FORBIDDEN-MCMMETADATAIDENTIFIER | **STATIC PASS** | PASS |
| 0989 | Repository guard BRH-QTN-FORBIDDEN-MOVEITEM | **STATIC PASS** | PASS |
| 0990 | Repository guard BRH-QTN-FORBIDDEN-NSFILEMANAGER | **STATIC PASS** | PASS |
| 0991 | Repository guard BRH-QTN-FORBIDDEN-NSUSERDEFAULTS | **STATIC PASS** | PASS |
| 0992 | Repository guard BRH-QTN-FORBIDDEN-PXDATACONTAINERRESOLVER | **STATIC PASS** | PASS |
| 0993 | Repository guard BRH-QTN-FORBIDDEN-PXDESTRUCTIVEPATHVALIDATOR | **STATIC PASS** | PASS |
| 0994 | Repository guard BRH-QTN-FORBIDDEN-PXKILL | **STATIC PASS** | PASS |
| 0995 | Repository guard BRH-QTN-FORBIDDEN-PXSHELLQUOTE | **STATIC PASS** | PASS |
| 0996 | Repository guard BRH-QTN-FORBIDDEN-REMOVEITEM | **STATIC PASS** | PASS |
| 0997 | Repository guard BRH-QTN-FORBIDDEN-RMDIR | **STATIC PASS** | PASS |
| 0998 | Repository guard BRH-QTN-FORBIDDEN-RUNCOMMAND | **STATIC PASS** | PASS |
| 0999 | Repository guard BRH-QTN-FORBIDDEN-RUNEXECUTABLE | **STATIC PASS** | PASS |
| 1000 | Repository guard BRH-QTN-FORBIDDEN-SECITEM | **STATIC PASS** | PASS |
| 1001 | Repository guard BRH-QTN-FORBIDDEN-SLEEP | **STATIC PASS** | PASS |
| 1002 | Repository guard BRH-QTN-FORBIDDEN-SQLITE3 | **STATIC PASS** | PASS |
| 1003 | Repository guard BRH-QTN-FORBIDDEN-UIAPPLICATION | **STATIC PASS** | PASS |
| 1004 | Repository guard BRH-QTN-FORBIDDEN-UNLINK | **STATIC PASS** | PASS |
| 1005 | Repository guard BRH-QTN-FORBIDDEN-WIPESELECTEDKEYCHAINFORBUNDLEID | **STATIC PASS** | PASS |
| 1006 | Repository guard BRH-QTN-FORBIDDEN-WRITETOFILE | **STATIC PASS** | PASS |
| 1007 | Repository guard BRH-QTN-LOGGER-CLEANAPPGROUPCONTAINERS | **STATIC PASS** | PASS |
| 1008 | Repository guard BRH-QTN-LOGGER-CLEANAPPSPECIFICFILESINSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 1009 | Repository guard BRH-QTN-LOGGER-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 1010 | Repository guard BRH-QTN-LOGGER-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 1011 | Repository guard BRH-QTN-LOGGER-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS | **STATIC PASS** | PASS |
| 1012 | Repository guard BRH-QTN-LOGGER-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS-ISROOTLESS | **STATIC PASS** | PASS |
| 1013 | Repository guard BRH-QTN-LOGGER-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 1014 | Repository guard BRH-QTN-LOGGER-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 1015 | Repository guard BRH-QTN-LOGGER-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 1016 | Repository guard BRH-QTN-LOGGER-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 1017 | Repository guard BRH-QTN-LOGGER-CLEAREXTENSIONCONTAINERS-FORAPP | **STATIC PASS** | PASS |
| 1018 | Repository guard BRH-QTN-LOGGER-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 1019 | Repository guard BRH-QTN-LOGGER-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 1020 | Repository guard BRH-QTN-LOGGER-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 1021 | Repository guard BRH-QTN-LOGGER-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 1022 | Repository guard BRH-QTN-LOGGER-DEEPCLEANSYSTEMSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 1023 | Repository guard BRH-QTN-LOGGER-DEFINITION | **STATIC PASS** | PASS |
| 1024 | Repository guard BRH-QTN-LOGGER-FASTWIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE-TIMEOUTSEC | **STATIC PASS** | PASS |
| 1025 | Repository guard BRH-QTN-LOGGER-FINALSWEEPFORCONTAINER | **STATIC PASS** | PASS |
| 1026 | Repository guard BRH-QTN-LOGGER-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 1027 | Repository guard BRH-QTN-LOGGER-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 1028 | Repository guard BRH-QTN-LOGGER-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 1029 | Repository guard BRH-QTN-LOGGER-NSLOG | **STATIC PASS** | PASS |
| 1030 | Repository guard BRH-QTN-LOGGER-PARAMETER | **STATIC PASS** | PASS |
| 1031 | Repository guard BRH-QTN-LOGGER-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 1032 | Repository guard BRH-QTN-LOGGER-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 1033 | Repository guard BRH-QTN-LOGGER-PRIVACY | **STATIC PASS** | PASS |
| 1034 | Repository guard BRH-QTN-LOGGER-SCRUBWEBKITSTATEINSHAREDCONTAINERBASE-TAG | **STATIC PASS** | PASS |
| 1035 | Repository guard BRH-QTN-LOGGER-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 1036 | Repository guard BRH-QTN-LOGGER-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 1037 | Repository guard BRH-QTN-LOGGER-SELECTOR | **STATIC PASS** | PASS |
| 1038 | Repository guard BRH-QTN-LOGGER-SIDE-EFFECTS | **STATIC PASS** | PASS |
| 1039 | Repository guard BRH-QTN-LOGGER-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 1040 | Repository guard BRH-QTN-LOGGER-WIPECONTAINERSINBASEPATHS-MATCHINGSUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 1041 | Repository guard BRH-QTN-LOGGER-WIPEDATACONTAINERSBYIDENTIFIERPREFIXORSUBSTRING-SUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 1042 | Repository guard BRH-QTN-LOGGER-WIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE | **STATIC PASS** | PASS |
| 1043 | Repository guard BRH-QTN-LOGGER-WIPERELATEDDATACONTAINERSFORBUNDLEIDS | **STATIC PASS** | PASS |
| 1044 | Repository guard BRH-QTN-LOGGER-WIPERELATEDSYSTEMGROUPCONTAINERSFORIDENTIFIERS | **STATIC PASS** | PASS |
| 1045 | Repository guard BRH-QTN-LOGGER-WIPEWEBKITDIRECTORYCONTENTS | **STATIC PASS** | PASS |
| 1046 | Repository guard BRH-QTN-SECURE-RETURN | **STATIC PASS** | PASS |
| 1047 | Repository guard BRH-QTN-SHAPE-CLEANAPPGROUPCONTAINERS | **STATIC PASS** | PASS |
| 1048 | Repository guard BRH-QTN-SHAPE-CLEANAPPSPECIFICFILESINSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 1049 | Repository guard BRH-QTN-SHAPE-CLEARAPPCACHE | **STATIC PASS** | PASS |
| 1050 | Repository guard BRH-QTN-SHAPE-CLEARAPPCOOKIES | **STATIC PASS** | PASS |
| 1051 | Repository guard BRH-QTN-SHAPE-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS | **STATIC PASS** | PASS |
| 1052 | Repository guard BRH-QTN-SHAPE-CLEARAPPGROUPCONTAINERS-WITHGROUPUUIDS-ISROOTLESS | **STATIC PASS** | PASS |
| 1053 | Repository guard BRH-QTN-SHAPE-CLEARAPPGROUPDATA | **STATIC PASS** | PASS |
| 1054 | Repository guard BRH-QTN-SHAPE-CLEARAPPKEYCHAIN | **STATIC PASS** | PASS |
| 1055 | Repository guard BRH-QTN-SHAPE-CLEARAPPPREFERENCES | **STATIC PASS** | PASS |
| 1056 | Repository guard BRH-QTN-SHAPE-CLEARAPPWEBKITDATA | **STATIC PASS** | PASS |
| 1057 | Repository guard BRH-QTN-SHAPE-CLEAREXTENSIONCONTAINERS-FORAPP | **STATIC PASS** | PASS |
| 1058 | Repository guard BRH-QTN-SHAPE-CLEARKEYCHAINDATA | **STATIC PASS** | PASS |
| 1059 | Repository guard BRH-QTN-SHAPE-CLEARKEYCHAINITEMSFORBUNDLEID | **STATIC PASS** | PASS |
| 1060 | Repository guard BRH-QTN-SHAPE-CLEARPLUGINKITDATA | **STATIC PASS** | PASS |
| 1061 | Repository guard BRH-QTN-SHAPE-COMPLETELYWIPECONTAINER | **STATIC PASS** | PASS |
| 1062 | Repository guard BRH-QTN-SHAPE-DEEPCLEANSYSTEMSHAREDCONTAINER-BUNDLEID-APPNAME-COMPANYNAME | **STATIC PASS** | PASS |
| 1063 | Repository guard BRH-QTN-SHAPE-FASTWIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE-TIMEOUTSEC | **STATIC PASS** | PASS |
| 1064 | Repository guard BRH-QTN-SHAPE-FINALSWEEPFORCONTAINER | **STATIC PASS** | PASS |
| 1065 | Repository guard BRH-QTN-SHAPE-FIXPERMISSIONSANDREMOVEPATH | **STATIC PASS** | PASS |
| 1066 | Repository guard BRH-QTN-SHAPE-FIXPERMISSIONSFORPATH | **STATIC PASS** | PASS |
| 1067 | Repository guard BRH-QTN-SHAPE-INTERNALCLEARENCRYPTEDDATA | **STATIC PASS** | PASS |
| 1068 | Repository guard BRH-QTN-SHAPE-PERFORMAGGRESSIVECLEANUPFOR | **STATIC PASS** | PASS |
| 1069 | Repository guard BRH-QTN-SHAPE-PERFORMFULLCLEANUP | **STATIC PASS** | PASS |
| 1070 | Repository guard BRH-QTN-SHAPE-SCRUBWEBKITSTATEINSHAREDCONTAINERBASE-TAG | **STATIC PASS** | PASS |
| 1071 | Repository guard BRH-QTN-SHAPE-SECUREDATAWIPE | **STATIC PASS** | PASS |
| 1072 | Repository guard BRH-QTN-SHAPE-SECURELYWIPEFILE | **STATIC PASS** | PASS |
| 1073 | Repository guard BRH-QTN-SHAPE-UNIVERSALKEYCHAINWIPEFORBUNDLEID | **STATIC PASS** | PASS |
| 1074 | Repository guard BRH-QTN-SHAPE-WIPECONTAINERSINBASEPATHS-MATCHINGSUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 1075 | Repository guard BRH-QTN-SHAPE-WIPEDATACONTAINERSBYIDENTIFIERPREFIXORSUBSTRING-SUBSTRINGS-TAG | **STATIC PASS** | PASS |
| 1076 | Repository guard BRH-QTN-SHAPE-WIPEDIRECTORYCONTENTS-KEEPDIRECTORYSTRUCTURE | **STATIC PASS** | PASS |
| 1077 | Repository guard BRH-QTN-SHAPE-WIPERELATEDDATACONTAINERSFORBUNDLEIDS | **STATIC PASS** | PASS |
| 1078 | Repository guard BRH-QTN-SHAPE-WIPERELATEDSYSTEMGROUPCONTAINERSFORIDENTIFIERS | **STATIC PASS** | PASS |
| 1079 | Repository guard BRH-QTN-SHAPE-WIPEWEBKITDIRECTORYCONTENTS | **STATIC PASS** | PASS |
| 1080 | Repository guard BRH-UI-ADVANCED-NAMES | **STATIC PASS** | PASS |
| 1081 | Repository guard BRH-UI-ADVANCED-ORDER | **STATIC PASS** | PASS |
| 1082 | Repository guard BRH-UI-ADVANCED-SCOPES | **STATIC PASS** | PASS |
| 1083 | Repository guard BRH-UI-BACKUP-CALLBACK | **STATIC PASS** | PASS |
| 1084 | Repository guard BRH-UI-BACKUP-OUTCOMES | **STATIC PASS** | PASS |
| 1085 | Repository guard BRH-UI-BACKUP-PRECEDENCE | **STATIC PASS** | PASS |
| 1086 | Repository guard BRH-UI-BACKUP-TITLES | **STATIC PASS** | PASS |
| 1087 | Repository guard BRH-UI-CFBOOLEAN | **STATIC PASS** | PASS |
| 1088 | Repository guard BRH-UI-COMPONENT-HEADER | **STATIC PASS** | PASS |
| 1089 | Repository guard BRH-UI-CONFIRMATION-STYLES | **STATIC PASS** | PASS |
| 1090 | Repository guard BRH-UI-CONFIRMATION-TEXT | **STATIC PASS** | PASS |
| 1091 | Repository guard BRH-UI-CONFIRMATION-WARNINGS | **STATIC PASS** | PASS |
| 1092 | Repository guard BRH-UI-MANIFEST-EQUALITY | **STATIC PASS** | PASS |
| 1093 | Repository guard BRH-UI-MANIFEST-ORDER | **STATIC PASS** | PASS |
| 1094 | Repository guard BRH-UI-RESTORE-CALLBACK | **STATIC PASS** | PASS |
| 1095 | Repository guard BRH-UI-RESTORE-OUTCOMES | **STATIC PASS** | PASS |
| 1096 | Repository guard BRH-UI-RESTORE-PRECEDENCE | **STATIC PASS** | PASS |
| 1097 | Repository guard BRH-UI-RESTORE-TITLES | **STATIC PASS** | PASS |
| 1098 | Repository guard BRH-UI-SCOPE-EQUALITY | **STATIC PASS** | PASS |
| 1099 | Repository guard BRH-WF-AUDIT-BLOCK | **STATIC PASS** | PASS |
| 1100 | Repository guard BRH-WF-AUDIT-COMMANDS | **STATIC PASS** | PASS |
| 1101 | Repository guard BRH-WF-AUDIT-ORDER | **STATIC PASS** | PASS |
| 1102 | Repository guard BRH-WF-NO-BYPASS | **STATIC PASS** | PASS |

Explicit scenario count: **1102**

## 36. Commit and push status

- The implementation commit is created only after this report passes final staged gates.
- Push was not performed and is not authorized.

## 37. TASK-6.4 boundary

Stop after the exact three-file TASK-6.3 implementation commit and post-commit evidence. Do not create a TASK-6.3 review, update coordinator documents, add malicious archive fixtures, add transaction fault injection, change production source, redesign the workflow, add dependencies, change branch protection, start TASK-6.4 or push.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
