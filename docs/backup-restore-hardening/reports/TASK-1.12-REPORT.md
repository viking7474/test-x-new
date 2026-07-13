# TASK-1.12 REPORT — Quarantine Ambiguous Legacy Clear APIs

## 1. Baseline and scope

- Required and actual baseline HEAD: `17d76c02e049b40bf84a161d76e90ec02b9485bf`.
- TASK-1.11 source review status at task start: `ACCEPTED`.
- Production file changed: `AppDataCleaner.m` only.
- Required report created: `docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md`.
- Phase 2 and TASK-2.1 were not started.

Initial `git status --short --untracked-files=all`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
```

These coordinator-owned files were pre-existing and were not rewritten, reverted, formatted, or staged by TASK-1.12.

```text
git rev-parse HEAD
17d76c02e049b40bf84a161d76e90ec02b9485bf

git log -3 --oneline
17d76c0 phase1(task-1.11): remove unsafe permission and marker behavior
7b277bf TASK-1.10
2579c76 phase1(task-1.10): integrate keychain clear result
```

## 2. Production diff scope

Pre-report production diff:

```text
AppDataCleaner.m | 1736 +++---------------------------------------------------
1 file changed, 92 insertions(+), 1644 deletions(-)
```

The implementation commit is constrained to exactly:

```text
AppDataCleaner.m
docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md
```

## 3. Full quarantine selector inventory

### Public broad/raw API (6)

- `performFullCleanup:`
- `performAggressiveCleanupFor:`
- `completelyWipeContainer:`
- `securelyWipeFile:`
- `fixPermissionsAndRemovePath:`
- `fixPermissionsForPath:`

### Raw/fuzzy component alias (8)

- `clearAppCache:`
- `clearAppPreferences:`
- `clearAppCookies:`
- `clearAppWebKitData:`
- `clearAppGroupData:`
- `clearPluginKitData:`
- `_internalClearEncryptedData:`
- `secureDataWipe:`

### Detached Keychain alias (4)

- `clearAppKeychain:`
- `clearKeychainData:`
- `clearKeychainItemsForBundleID:`
- `universalKeychainWipeForBundleID:`

### Raw-path helper (4)

- `wipeDirectoryContents:keepDirectoryStructure:`
- `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:`
- `finalSweepForContainer:`
- `wipeWebKitDirectoryContents:`

### Raw UUID / legacy extension-group helper (4)

- `clearAppGroupContainers:withGroupUUIDs:isRootless:`
- `clearAppGroupContainers:withGroupUUIDs:`
- `clearExtensionContainers:forApp:`
- `cleanAppGroupContainers:`

### Fuzzy/structure-based helper (7)

- `_wipeRelatedDataContainersForBundleIDs:`
- `_wipeRelatedSystemGroupContainersForIdentifiers:`
- `_wipeContainersInBasePaths:matchingSubstrings:tag:`
- `_wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag:`
- `_scrubWebKitStateInSharedContainerBase:tag:`
- `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:`
- `deepCleanSystemSharedContainer:bundleID:appName:companyName:`

Total quarantined selector definitions: **33**.

## 4. Declaration and definition counts

| Selector | Header declaration | Implementation definition | Logger calls in body | Exact shim |
|---|---:|---:|---:|---|
| `performFullCleanup:` | 1 | 1 | 1 | PASS |
| `performAggressiveCleanupFor:` | 1 | 1 | 1 | PASS |
| `completelyWipeContainer:` | 1 | 1 | 1 | PASS |
| `securelyWipeFile:` | 1 | 1 | 1 | PASS |
| `fixPermissionsAndRemovePath:` | 1 | 1 | 1 | PASS |
| `fixPermissionsForPath:` | 1 | 1 | 1 | PASS |
| `clearAppCache:` | 1 | 1 | 1 | PASS |
| `clearAppPreferences:` | 1 | 1 | 1 | PASS |
| `clearAppCookies:` | 1 | 1 | 1 | PASS |
| `clearAppWebKitData:` | 1 | 1 | 1 | PASS |
| `clearAppGroupData:` | 1 | 1 | 1 | PASS |
| `clearPluginKitData:` | 1 | 1 | 1 | PASS |
| `_internalClearEncryptedData:` | 1 | 1 | 1 | PASS |
| `secureDataWipe:` | 1 | 1 | 1 | PASS |
| `clearAppKeychain:` | 1 | 1 | 1 | PASS |
| `clearKeychainData:` | 1 | 1 | 1 | PASS |
| `clearKeychainItemsForBundleID:` | 1 | 1 | 1 | PASS |
| `universalKeychainWipeForBundleID:` | 1 | 1 | 1 | PASS |
| `wipeDirectoryContents:keepDirectoryStructure:` | 0 | 1 | 1 | PASS |
| `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:` | 0 | 1 | 1 | PASS |
| `finalSweepForContainer:` | 0 | 1 | 1 | PASS |
| `wipeWebKitDirectoryContents:` | 0 | 1 | 1 | PASS |
| `clearAppGroupContainers:withGroupUUIDs:isRootless:` | 0 | 1 | 1 | PASS |
| `clearAppGroupContainers:withGroupUUIDs:` | 0 | 1 | 1 | PASS |
| `clearExtensionContainers:forApp:` | 0 | 1 | 1 | PASS |
| `cleanAppGroupContainers:` | 0 | 1 | 1 | PASS |
| `_wipeRelatedDataContainersForBundleIDs:` | 0 | 1 | 1 | PASS |
| `_wipeRelatedSystemGroupContainersForIdentifiers:` | 0 | 1 | 1 | PASS |
| `_wipeContainersInBasePaths:matchingSubstrings:tag:` | 0 | 1 | 1 | PASS |
| `_wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag:` | 0 | 1 | 1 | PASS |
| `_scrubWebKitStateInSharedContainerBase:tag:` | 0 | 1 | 1 | PASS |
| `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:` | 0 | 1 | 1 | PASS |
| `deepCleanSystemSharedContainer:bundleID:appName:companyName:` | 0 | 1 | 1 | PASS |

Public ABI declarations retained: 18. Private/internal selectors without public declarations: 15. Every selector has exactly one implementation definition.

## 5. Shared quarantine logger contract

Exact implementation:

```objc
static void PXLogQuarantinedLegacyClearSelector(SEL selector) {
    NSLog(@"[AppDataCleaner] Legacy Clear selector %@ is quarantined; use clearDataForBundleID:completion:.",
          NSStringFromSelector(selector));
}
```

The logger has exactly one parameter (`SEL selector`), uses `NSStringFromSelector` once, and cannot receive or format a path, bundle identifier, UUID, group identifier, entitlement, Keychain group, command, or target value. It performs no persistence, defaults write, marker creation, filesystem operation, command, dispatch, or Clear call. The typed entry-point name is guidance text only; no shim redirects to it.

Every quarantined method casts each argument unused and invokes `PXLogQuarantinedLegacyClearSelector(_cmd)` exactly once. No raw argument appears in a log formatting expression.

## 6. `securelyWipeFile:` fail-closed proof

```objc
- (BOOL)securelyWipeFile:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return NO;
}
```

The method has no existence check and never returns `YES` for nil, invalid, absent, existing-file, or existing-directory inputs.

## 7. Combined quarantine-body forbidden-token audit

| Forbidden token | Count |
|---|---:|
| `NSFileManager` | 0 |
| `fileExistsAtPath` | 0 |
| `contentsOfDirectoryAtPath` | 0 |
| `enumeratorAtPath` | 0 |
| `dictionaryWithContentsOfFile` | 0 |
| `MCMMetadataIdentifier` | 0 |
| `PXDataContainerResolver` | 0 |
| `AppGroupContainerResolver` | 0 |
| `PXDestructivePathValidator` | 0 |
| `PXShellQuote` | 0 |
| `CommandRunner` | 0 |
| `runCommand` | 0 |
| `runExecutable` | 0 |
| `removeItem` | 0 |
| `createDirectory` | 0 |
| `writeToFile` | 0 |
| `moveItem` | 0 |
| `copyItem` | 0 |
| `unlink` | 0 |
| `rmdir` | 0 |
| `rm -rf` | 0 |
| `find` | 0 |
| `mkdir` | 0 |
| `sqlite3` | 0 |
| `SecItem` | 0 |
| `security delete-` | 0 |
| `_wipeSelectedKeychainForBundleID` | 0 |
| `PXKill` | 0 |
| `killall` | 0 |
| `UIApplication` | 0 |
| `NSUserDefaults` | 0 |
| `dispatch_async` | 0 |
| `dispatch_apply` | 0 |
| `sleep` | 0 |
| `hasPrefix` | 0 |
| `containsString` | 0 |
| `lowercaseString` | 0 |

All required forbidden tokens are zero across the combined 33 method bodies. The bodies contain no filesystem inspection, resolver/validator call, path construction, process execution, deletion/creation/write, Security/Keychain operation, app lifecycle operation, defaults access, dispatch, delay, fuzzy matching, or redirect to an accepted Clear entry point.

## 8. Detached Keychain alias proof

The four detached Keychain aliases are exact non-mutating shims. Their combined bodies contain zero references to `_wipeSelectedKeychainForBundleID`, `SecItem`, `security delete-`, `KeychainBackupHelper`, `WeaponXKeychainBridge`, `NSUserDefaults`, `keychain-access-groups`, or `application-identifier`. Keychain plan construction, initial/final passes, pass accounting, and final component ownership remain exclusively in the byte-identical typed main Clear path.

## 9. Raw-path, raw-UUID, and fuzzy helper proof

- Raw-path helper bodies contain no `NSFileManager`, existence/enumeration API, `PXShellQuote`, command runner, deletion, `find`, `mkdir`, permission operation, marker, or write/create token.
- Raw UUID and legacy extension/group bodies contain no rootful/rootless path construction, MCM metadata read, generic wipe, compatibility directory creation, preference/database deletion, or extension Keychain operation.
- Fuzzy/structure-based bodies contain no `hasPrefix`, `containsString`, `lowercaseString`, company-name comparison, filename similarity, structure inspection, hard-coded container UUID, caller-supplied base traversal, or vendor exception.
- `_wipeMobileSafariSystemStores` body hash is unchanged. Its calls into quarantined fuzzy helpers now terminate in selector-only no-op shims.

## 10. `PXShellFinalSweep` removal

```text
PXShellFinalSweep definitions: 0
PXShellFinalSweep references: 0
```

`PXShellValidatedApplicationDataWipe` was not changed; its body hash remains identical and still owns the sole accepted canonical `chflags -R` operation.

## 11. Protected-file SHA-256 before/after

| Protected file | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | PASS |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | PASS |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | PASS |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | PASS |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | PASS |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | PASS |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | PASS |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | PASS |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | PASS |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | PASS |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | PASS |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | PASS |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | PASS |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | PASS |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | PASS |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | PASS |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | PASS |
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | PASS |
| `AppDataBackupManager.m` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | PASS |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | PASS |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | PASS |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | PASS |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | PASS |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | PASS |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | PASS |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | PASS |

The required protected-file `git diff --exit-code` command returned exit code `0`. `AppDataCleaner.h` is byte-identical; no declaration, return type, selector, protocol, public API, deprecation attribute, or exception behavior was added.

## 12. Typed Clear body hashes before/after

Hash definition: SHA-256 over the exact UTF-8 body from the opening `{` through its matching `}`, preserving the working-tree CRLF bytes.

| Typed function/method | Before SHA-256 | After SHA-256 | Bytes | Result |
|---|---|---|---:|---|
| `PXShellValidatedApplicationDataWipe` | `f98d0de5072a3be6e1bc90bb6e0fb0e67164f326fb63462b86eaed04a4bcdfc4` | `f98d0de5072a3be6e1bc90bb6e0fb0e67164f326fb63462b86eaed04a4bcdfc4` | 981 | PASS |
| `PXApplicationDataCommandResultSucceeded` | `6e4a14b1db210c3d7b16e331b0ffa8bc788a110dea5d4d461d14137fcd9087a0` | `6e4a14b1db210c3d7b16e331b0ffa8bc788a110dea5d4d461d14137fcd9087a0` | 143 | PASS |
| `PXApplicationDataPostconditionIsValid` | `9bcd8389ba32fe6e11e108015577a2f58f043f99776ca98a4a9c440471e1fd1c` | `9bcd8389ba32fe6e11e108015577a2f58f043f99776ca98a4a9c440471e1fd1c` | 4981 | PASS |
| `_completeAppDataWipeForApplicationDataRequest:` | `8361e822a79152af951a79b520e548a0d2410afdb04b6271690dbbc68ae3c95f` | `8361e822a79152af951a79b520e548a0d2410afdb04b6271690dbbc68ae3c95f` | 26120 | PASS |
| `_completeDataWipeForMigratedRequest:` | `c7a13979b9bc07f41ef1b4f447db1016daac00de9b4da3643f6006fa7b647e3d` | `c7a13979b9bc07f41ef1b4f447db1016daac00de9b4da3643f6006fa7b647e3d` | 7170 | PASS |
| `_clearExactDataContainerComponentForIdentifiers:kind:scope:timeoutSec:canonicalPaths:successfulCanonicalPaths:` | `1d3a53c81fda746642ded3778c31b146c5cc087f01f58514f4554ac997912ce1` | `1d3a53c81fda746642ded3778c31b146c5cc087f01f58514f4554ac997912ce1` | 10086 | PASS |
| `_clearExactAppGroupsComponentForIdentifiers:timeoutSec:canonicalPaths:successfulCanonicalPaths:` | `5dc6b97958895037631321b10780aeb15b3ca31ba0f683a8cb5ded036a110a8b` | `5dc6b97958895037631321b10780aeb15b3ca31ba0f683a8cb5ded036a110a8b` | 8743 | PASS |
| `_keychainClearPlanForBundleIdentifier:` | `17b6c36b3dd18a4091e05998d22718c3bd8e0dbde1fb625d88002ff81d5e579f` | `17b6c36b3dd18a4091e05998d22718c3bd8e0dbde1fb625d88002ff81d5e579f` | 17808 | PASS |
| `_executeKeychainWipeForBundleIdentifier:selectedGroups:applicationIdentifier:systemApplication:error:` | `dd639e3701a18d1e15753d9c5fd32eed392682b18e7a83157c85396e5674b2cc` | `dd639e3701a18d1e15753d9c5fd32eed392682b18e7a83157c85396e5674b2cc` | 12578 | PASS |
| `_keychainComponentForPlan:passResults:` | `d552d7f14597e6b9165ecd5ec39e79085ac8e46f20785f6e31272d9f3da465d8` | `d552d7f14597e6b9165ecd5ec39e79085ac8e46f20785f6e31272d9f3da465d8` | 5925 | PASS |
| `clearDataForBundleID:completion:` | `25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1` | `25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1` | 15419 | PASS |
| `completeAppDataWipe:` | `204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644` | `204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644` | 1182 | PASS |

All twelve accepted typed bodies are byte-identical. This preserves resolver/validator usage, exact postconditions, canonical caches, four-scope data execution, immutable Keychain plan, initial/final pass accounting, five-scope final aggregate, callback precedence, one-shot completion, and data-only `completeAppDataWipe:` behavior.

Additional unchanged compatibility/retained bodies:

| Body | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `clearAppData:` | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` | PASS |
| `performSecondaryCleanup:` | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` | `b956a3118a462e7b1ff75076457acd3d2ced5a3c55d92795354cd571205438bb` | PASS |
| `_wipeMobileSafariSystemStores` | `077ed7ea110e0fde1ed40f2fa852803159eaa7f9d1493c34af377ab3408636bc` | `077ed7ea110e0fde1ed40f2fa852803159eaa7f9d1493c34af377ab3408636bc` | PASS |

`clearAppData:` and `performSecondaryCleanup:` each still delegate exactly once to `completeAppDataWipe:`. They were not quarantined.

## 13. Five-scope and callback non-regression

```text
Data mask: ApplicationData | ExtensionData | AppGroups | PluginKitData
Full mask: ApplicationData | ExtensionData | AppGroups | PluginKitData | Keychain
Full aggregate component count: 5
Callback precedence: ApplicationData -> ExtensionData -> AppGroups -> PluginKitData -> Keychain
completeAppDataWipe: four-scope/data-only; Keychain execution calls: 0
```

No component, warning, or failure was added to represent omitted legacy cleanup. Legacy side effects are simply absent.

## 14. TASK-1.11 non-regression

| Gate | Required | Actual | Result |
|---|---:|---:|---|
| `chmod -R` | 0 | 0 | PASS |
| `find -exec chmod` | 0 | 0 | PASS |
| `chown -R` | 0 | 0 | PASS |
| `chflags -R` | 1 | 1 | PASS |
| `active shell touch` | 0 | 0 | PASS |
| `.nomedia` | 0 | 0 | PASS |
| `.initialized` | 0 | 0 | PASS |
| `AssistantServices target` | 0 | 0 | PASS |
| `Keychain temp 0700` | 1 | 1 | PASS |
| `Keychain helper 0755` | 1 | 1 | PASS |
| `receipt tokens` | 0 | 0 | PASS |
| `PXClearScopeDefaultMask` | 0 | 0 | PASS |

The sole `chflags -R` remains inside `PXShellValidatedApplicationDataWipe`; outside that unchanged body the count is zero.

## 15. Exact external caller inventory

Search scope: tracked files plus current untracked task/review documents, excluding `AppDataCleaner.m`, generated audit scripts/JSON, and this report. Production source references were separated from documentation references.

| Selector | ABI declaration outside implementation | Production call sites outside `AppDataCleaner.m` |
|---|---|---:|
| `performFullCleanup:` | `AppDataCleaner.h:18` | 0 |
| `performAggressiveCleanupFor:` | `AppDataCleaner.h:20` | 0 |
| `completelyWipeContainer:` | `AppDataCleaner.h:24` | 0 |
| `securelyWipeFile:` | `AppDataCleaner.h:101` | 0 |
| `fixPermissionsAndRemovePath:` | `AppDataCleaner.h:105` | 0 |
| `fixPermissionsForPath:` | `AppDataCleaner.h:106` | 0 |
| `clearAppCache:` | `AppDataCleaner.h:32` | 0 |
| `clearAppPreferences:` | `AppDataCleaner.h:33` | 0 |
| `clearAppCookies:` | `AppDataCleaner.h:34` | 0 |
| `clearAppWebKitData:` | `AppDataCleaner.h:35` | 0 |
| `clearAppGroupData:` | `AppDataCleaner.h:37` | 0 |
| `clearPluginKitData:` | `AppDataCleaner.h:78` | 0 |
| `_internalClearEncryptedData:` | `AppDataCleaner.h:98` | 0 |
| `secureDataWipe:` | `AppDataCleaner.h:102` | 0 |
| `clearAppKeychain:` | `AppDataCleaner.h:36` | 0 |
| `clearKeychainData:` | `AppDataCleaner.h:41` | 0 |
| `clearKeychainItemsForBundleID:` | `AppDataCleaner.h:107` | 0 |
| `universalKeychainWipeForBundleID:` | `AppDataCleaner.h:108` | 0 |
| `wipeDirectoryContents:keepDirectoryStructure:` | none (private/internal selector) | 0 |
| `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:` | none (private/internal selector) | 0 |
| `finalSweepForContainer:` | none (private/internal selector) | 0 |
| `wipeWebKitDirectoryContents:` | none (private/internal selector) | 0 |
| `clearAppGroupContainers:withGroupUUIDs:isRootless:` | none (private/internal selector) | 0 |
| `clearAppGroupContainers:withGroupUUIDs:` | none (private/internal selector) | 0 |
| `clearExtensionContainers:forApp:` | none (private/internal selector) | 0 |
| `cleanAppGroupContainers:` | none (private/internal selector) | 0 |
| `_wipeRelatedDataContainersForBundleIDs:` | none (private/internal selector) | 0 |
| `_wipeRelatedSystemGroupContainersForIdentifiers:` | none (private/internal selector) | 0 |
| `_wipeContainersInBasePaths:matchingSubstrings:tag:` | none (private/internal selector) | 0 |
| `_wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag:` | none (private/internal selector) | 0 |
| `_scrubWebKitStateInSharedContainerBase:tag:` | none (private/internal selector) | 0 |
| `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:` | none (private/internal selector) | 0 |
| `deepCleanSystemSharedContainer:bundleID:appName:companyName:` | none (private/internal selector) | 0 |

Result: no production call site outside `AppDataCleaner.m` was found for any quarantine selector. The 18 public names remain as protected ABI declarations; the other 15 are private/internal implementations. Historical reports, reviews, status, decisions, and task specifications contain documentary references only and were not modified.

## 16. Static gate summary

```text
Quarantine selectors: 33/33 exact shims
Logger calls: 33, exactly one per shim
Combined forbidden-token counts: 37/37 equal zero
Typed body hashes: 12/12 unchanged
Retained compatibility/Safari body hashes: 3/3 unchanged
PXShellFinalSweep definitions/references: 0/0
Protected diff: exit 0
TASK-1.11 non-regression: PASS
Source NUL bytes: 0
Source CRLF lines: 6976; bare LF lines: 0
Machine gate suite: 184/184 PASS
```

## 17. Scenario matrix

| # | Scenario | Status | Evidence |
|---:|---|---|---|
| 1 | `performFullCleanup:` valid bundle identifier | **STATIC COVERAGE / DEVICE PENDING** | Exact body ignores the argument, logs `_cmd` once, and performs no mutation. |
| 2 | `performFullCleanup:` nil bundle identifier | **STATIC COVERAGE / DEVICE PENDING** | The same argument-independent shim applies; no validation or dereference occurs. |
| 3 | `performAggressiveCleanupFor:` arbitrary bundle identifier | **STATIC COVERAGE / DEVICE PENDING** | Exact non-mutating shim; no kill, resolver, command, or Clear redirect. |
| 4 | `completelyWipeContainer:` canonical-looking path | **STATIC COVERAGE / DEVICE PENDING** | Path is cast unused; no filesystem inspection or deletion. |
| 5 | `completelyWipeContainer:` arbitrary path | **STATIC COVERAGE / DEVICE PENDING** | Path is cast unused; no path construction, validator, or mutation. |
| 6 | `securelyWipeFile:` existing file | **STATIC COVERAGE / DEVICE PENDING** | No existence check or write/delete; selector is logged and `NO` is returned. |
| 7 | `securelyWipeFile:` existing directory | **STATIC COVERAGE / DEVICE PENDING** | No enumeration or recursive work; selector is logged and `NO` is returned. |
| 8 | `securelyWipeFile:` nil path | **STATIC COVERAGE / DEVICE PENDING** | No dereference; selector is logged and `NO` is returned. |
| 9 | `securelyWipeFile:` absent path | **STATIC COVERAGE / DEVICE PENDING** | No false success; selector is logged and `NO` is returned. |
| 10 | `fixPermissionsAndRemovePath:` arbitrary path | **STATIC COVERAGE / DEVICE PENDING** | No permission operation, Foundation removal, or shell fallback remains. |
| 11 | `fixPermissionsForPath:` arbitrary path | **STATIC COVERAGE / DEVICE PENDING** | No read, mutation, command, or argument log remains. |
| 12 | `clearAppCache:` | **STATIC COVERAGE / DEVICE PENDING** | No UUID lookup, path construction, or deletion. |
| 13 | `clearAppPreferences:` | **STATIC COVERAGE / DEVICE PENDING** | No UUID lookup, plist deletion, or compatibility redirect. |
| 14 | `clearAppCookies:` | **STATIC COVERAGE / DEVICE PENDING** | No path lookup or cookie deletion. |
| 15 | `clearAppWebKitData:` | **STATIC COVERAGE / DEVICE PENDING** | No WebKit path construction or cleanup. |
| 16 | `clearAppGroupData:` | **STATIC COVERAGE / DEVICE PENDING** | No App Group discovery, UUID handling, or deletion. |
| 17 | `clearPluginKitData:` | **STATIC COVERAGE / DEVICE PENDING** | No PluginKit scan, metadata read, preference/database deletion, or Keychain work. |
| 18 | `_internalClearEncryptedData:` | **STATIC COVERAGE / DEVICE PENDING** | No fuzzy scan, recursive traversal, secure wipe, or auth-directory work. |
| 19 | `secureDataWipe:` | **STATIC COVERAGE / DEVICE PENDING** | No redirect to `completeAppDataWipe:` or any other Clear method. |
| 20 | `clearAppKeychain:` | **STATIC COVERAGE / DEVICE PENDING** | No detached Keychain operation or typed-result ownership. |
| 21 | `clearKeychainData:` | **STATIC COVERAGE / DEVICE PENDING** | No detached Keychain operation. |
| 22 | `clearKeychainItemsForBundleID:` | **STATIC COVERAGE / DEVICE PENDING** | No `SecItem`, security command, fuzzy match, or wrapper call. |
| 23 | `universalKeychainWipeForBundleID:` | **STATIC COVERAGE / DEVICE PENDING** | No `SecItem`, security command, wildcard pattern, or wrapper call. |
| 24 | `wipeDirectoryContents:keepDirectoryStructure:` | **STATIC COVERAGE / DEVICE PENDING** | No filesystem read/write, deletion, recreation, or command. |
| 25 | `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:` | **STATIC COVERAGE / DEVICE PENDING** | All arguments unused; no quoting, command, timeout work, or deletion. |
| 26 | `finalSweepForContainer:` | **STATIC COVERAGE / DEVICE PENDING** | No existence check, helper call, timeout, or deletion. |
| 27 | `wipeWebKitDirectoryContents:` | **STATIC COVERAGE / DEVICE PENDING** | No WebKit inspection, deletion, or recreation. |
| 28 | `clearAppGroupContainers:withGroupUUIDs:isRootless:` | **STATIC COVERAGE / DEVICE PENDING** | No rootful/rootless path building from raw UUIDs. |
| 29 | `clearAppGroupContainers:withGroupUUIDs:` | **STATIC COVERAGE / DEVICE PENDING** | No delegation to the raw UUID overload. |
| 30 | `clearExtensionContainers:forApp:` | **STATIC COVERAGE / DEVICE PENDING** | No raw extension UUID path, preference/database deletion, or extension Keychain work. |
| 31 | `cleanAppGroupContainers:` | **STATIC COVERAGE / DEVICE PENDING** | No MCM metadata, company-name match, or generic wipe. |
| 32 | `_wipeRelatedDataContainersForBundleIDs:` | **STATIC COVERAGE / DEVICE PENDING** | No container scan, prefix/substring authorization, or deletion. |
| 33 | `_wipeRelatedSystemGroupContainersForIdentifiers:` | **STATIC COVERAGE / DEVICE PENDING** | No SystemGroup scan or fuzzy match. |
| 34 | `_wipeContainersInBasePaths:matchingSubstrings:tag:` | **STATIC COVERAGE / DEVICE PENDING** | Caller-supplied bases and fuzzy needles are unused. |
| 35 | `_wipeDataContainersByIdentifierPrefixOrSubstring:substrings:tag:` | **STATIC COVERAGE / DEVICE PENDING** | Prefix/substring authorization is removed. |
| 36 | `_scrubWebKitStateInSharedContainerBase:tag:` | **STATIC COVERAGE / DEVICE PENDING** | No structure-based WebKit detection or mutation. |
| 37 | `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:` | **STATIC COVERAGE / DEVICE PENDING** | No filename/company similarity scan, database cleanup, or deletion. |
| 38 | `deepCleanSystemSharedContainer:bundleID:appName:companyName:` | **STATIC COVERAGE / DEVICE PENDING** | No hard-coded UUID/vendor/Maps/File Provider exception or mutation. |
| 39 | every quarantine shim logs selector only | **STATIC PASS** | 33/33 bodies contain exactly one `_cmd` logger call. |
| 40 | no quarantine shim logs a raw argument | **STATIC PASS** | Arguments appear only in `(void)` casts; logger accepts only `SEL`. |
| 41 | every quarantine shim is non-mutating | **STATIC PASS** | All 37 forbidden-token counts are zero in the combined bodies. |
| 42 | every quarantine selector has one implementation definition | **STATIC PASS** | 33/33 definition counts equal one. |
| 43 | public declarations remain present | **STATIC PASS** | 18 public declarations remain once; `AppDataCleaner.h` SHA-256 is unchanged. |
| 44 | `PXShellFinalSweep` is absent | **STATIC PASS** | Definition count and reference count are both zero. |
| 45 | `clearAppData:` still delegates to `completeAppDataWipe:` | **STATIC PASS** | Body hash unchanged and exactly one delegation remains. |
| 46 | `performSecondaryCleanup:` still delegates to `completeAppDataWipe:` | **STATIC PASS** | Body hash unchanged and exactly one delegation remains. |
| 47 | `clearDataForBundleID:completion:` body hash unchanged | **STATIC PASS** | Exact before/after SHA-256 values match. |
| 48 | `completeAppDataWipe:` body hash unchanged | **STATIC PASS** | Exact before/after SHA-256 values match. |
| 49 | Keychain plan/pass accounting unchanged | **STATIC PASS** | Keychain plan, execution, component, and main orchestration hashes match. |
| 50 | full aggregate remains five components | **STATIC PASS** | Exact full mask and structural count `5` remain. |
| 51 | callback precedence remains unchanged | **STATIC PASS** | Main body hash is unchanged; component order remains ApplicationData, ExtensionData, AppGroups, PluginKitData, Keychain. |
| 52 | TASK-1.11 permission/marker gates remain green | **STATIC PASS** | All required recursive permission, marker, touch, and narrow-mode counts match. |
| 53 | protected-file diff is empty | **STATIC PASS** | Required protected diff command returned exit code 0. |
| 54 | external caller inventory is recorded | **STATIC PASS** | All 33 names are inventoried; no production call site outside `AppDataCleaner.m` was found. |
| 55 | cumulative diff whitespace check passes | **STATIC PASS** | `git diff --check` passes after report creation. |
| 56 | CRLF audit passes for existing source | **STATIC PASS** | Every LF in `AppDataCleaner.m` is part of CRLF. |
| 57 | report and changed source contain no NUL bytes | **STATIC PASS** | Byte-level audits report zero NUL bytes. |
| 58 | no new public API is added | **STATIC PASS** | Public header is byte-identical and only one private file-local logger was added. |
| 59 | no typed result component is added for omitted legacy cleanup | **STATIC PASS** | Combined shims contain no `PXClearResult`/component/warning/failure token. |
| 60 | no Phase 2 work is present | **STATIC PASS** | Diff is limited to TASK-1.12 quarantine behavior and its report. |

No `DEVICE PASS` is claimed. Runtime invocation and ABI/device behavior remain pending project-owner build and device validation.

## 18. Whitespace, CRLF, and NUL audit

- `git diff --check`: PASS.
- `AppDataCleaner.m`: 370484 bytes, 6976 CRLF line endings, 0 bare LF line endings, 0 NUL bytes.
- `TASK-1.12-REPORT.md`: generated as LF text with trailing whitespace stripped and zero NUL bytes.
- No temporary audit file is included in the implementation commit.

## 19. Build status

Local Objective-C/Theos compilation was not available in this Windows workspace: `clang`, `make`, and `xcrun` were all `NOT_FOUND`. No local build or device-runtime success is claimed. GitHub Actions remains the build owner.

## 20. Remaining runtime risks

- External binaries or callers not present in this repository may still invoke public legacy selectors. ABI is preserved, but those calls now intentionally log and do nothing.
- Callers that previously inferred success from a void legacy method receive no structured result; this task intentionally avoids redirecting them to asynchronous or structured Clear ownership.
- `securelyWipeFile:` now fails closed with `NO`; device testing should confirm no caller incorrectly assumes the historical absent-path success behavior.
- `_wipeMobileSafariSystemStores` remains unchanged, but fuzzy helper calls it makes are now no-ops; device testing should confirm the remaining direct fixed-store behavior is acceptable.
- Phase 2 remains locked until TASK-1.12 review, GitHub Actions, and device validation are complete.

## 21. Final diff and commit evidence

Implementation commit title: `phase1(task-1.12): quarantine ambiguous legacy clear APIs`.

Expected commit manifest:

```text
M AppDataCleaner.m
A docs/backup-restore-hardening/reports/TASK-1.12-REPORT.md
```

The final commit hash is intentionally recorded by the post-commit command output and review handoff rather than embedded in the report itself, because embedding a commit hash inside a file changes that commit hash. Required post-commit commands are run immediately after commit creation.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
