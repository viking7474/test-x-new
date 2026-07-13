# TASK-1.10 REPORT — Integrate Keychain Clear Result

## 1. Scope and baseline

- Baseline HEAD: `0bb2e354715e00f20c4df95719e900ae5e8e1673`
- Expected baseline: `0bb2e354715e00f20c4df95719e900ae5e8e1673`
- Scope stopped after TASK-1.10; TASK-1.11 was not started.
- Production files changed:
  - `AppDataCleaner.m`
  - `WeaponXKeychainBridge/Tweak.m`
  - `KeychainHelper/backup_helper.m`
  - `KeychainGroupsViewController.m`
  - `ProjectXViewController.m`
  - `docs/backup-restore-hardening/reports/TASK-1.10-REPORT.md` (required report)

Initial `git status --short --untracked-files=all`:
```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.8A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.9-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.10-integrate-keychain-clear-result.md
?? docs/backup-restore-hardening/tasks/TASK-1.8A-restore-resolver-contract-and-report-gates.md
?? docs/backup-restore-hardening/tasks/TASK-1.9-migrate-app-group-clear.md
```
Pre-existing coordinator/status/review/task artifacts above were not edited, staged, reverted or formatted by TASK-1.10.

## 2. Protected SHA-256 before/after

| Protected file | Before | After | Result |
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
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | MATCH |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | MATCH |
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | MATCH |
| `AppDataBackupManager.m` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | MATCH |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | MATCH |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | MATCH |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | MATCH |

`git diff --exit-code -- <protected files>` returned 0 before commit.

## 3. Four-scope data aggregate remains isolated

`PXMigratedDataClearScopes` remains exactly ApplicationData, ExtensionData, AppGroups and PluginKitData. `_completeDataWipeForMigratedRequest:` still builds only those four canonical components. `completeAppDataWipe:` still creates a four-scope request, logs those components and performs no Keychain pass.

## 4. Five-scope full Clear result

`PXMigratedFullClearScopes` adds only Keychain. `clearDataForBundleID:completion:` creates the original five-scope request plus a derived four-scope request with the same exact bundle identifier and captured `deepClean`. The final `PXClearResult` covers, in canonical order: ApplicationData, ExtensionData, AppGroups, PluginKitData, Keychain.

Separate structural validators enforce four-component data results and five-component full results. Keychain execution is not placed inside the data aggregate.

## 5. Immutable Keychain plan

`PXKeychainClearPlan` copies bundle identifier, enabled state, system-app flag, captured system policy, validated selected groups, signed authorized groups, signed application identifier, planned pass count and skip/planning-failure state. The plan is constructed after the target kill and before the initial pass. Neither pass rereads defaults, policy or entitlements.

- Enabled default and saved selection object: one read each.
- System policy: one read for enabled system apps.
- `fullEntitlementsForBundleID:error:`: one call when enabled.
- No defaults are rewritten during plan construction or running Clear.

## 6. Signed authorization and saved selection

Authorization uses only exact `keychain-access-groups` elements and exact `application-identifier`. All values use runtime type/empty/whitespace/NUL/comma/edge-whitespace validation, exact deduplication and `compare:` sorting. No trimming, lowercase conversion, bundle-prefix authorization, vendor group hard-coding or service/account/label matching is used.

Saved-object presence is authoritative: absent defaults to all signed groups without persistence; an NSArray is explicit even when empty; wrong type or invalid/unauthorized element fails closed. Non-system execution requires a valid signed application identifier and never substitutes the bundle identifier.

## 7. System policy and pass accounting

- Enabled system app + global policy OFF: Failed 1/0/1, no bridge request.
- Enabled system app + policy ON: exactly one bridge pass; success 1/1/0 or failure 1/0/1.
- Non-system: exactly two passes using the same immutable plan. The final pass runs even after initial failure.
- Planning/configuration/authorization failure: Failed 1/0/1; data aggregate still runs.
- Disabled, explicit empty, or no authorized groups: Skipped 0/0/0 with exact required detail.

## 8. Keychain component and callback

Stable private domain: `PXKeychainClear`. Fixed codes cover InvalidRequest, ConfigurationFailed, AuthorizationFailed, InitialPassFailed, FinalPassFailed and InternalResultFailure. Success/failure details are exactly the requested non-sensitive strings. First failure is retained while remaining planned work continues.

The callback is derived only from the final five-scope result. Failed-component precedence is ApplicationData → ExtensionData → AppGroups → PluginKitData → Keychain. Lower-priority failures are still logged. Skipped is not failure. Detached Keychain BOOL callback state and `allRequestedScopesSucceeded` are absent.

## 9. Exact execution and bounded direct commands

The private exact execution method receives bundle identifier, exact selected groups, signed application identifier, system-app flag and error pointer. It clears `*error` at entry, performs one pass, reads no settings or entitlements and rewrites no groups.

- ldid: resolved absolute executable, arguments `-S<entitlementsPath>` and working helper, 60 seconds, 1 MiB per stream.
- helper: copied/resigned absolute working helper, `--action wipe --groups <CSV>`, 120 seconds, 1 MiB per stream.
- Both require non-nil result, `isSucceeded`, and no stdout/stderr truncation.
- Each pass uses a PID + UUID temporary directory and removes helper, entitlement plist and directory in `@finally`.
- Persisted diagnostic contains only non-sensitive status/counter fields.

## 10. Truthful helper and bridge

`backup_helper` wipe now emits the machine-readable non-sensitive summary and exits 2 for nil result, any failed item or any warning. Zero matching items remain success when failed/warnings are zero. Backup/Restore/List behavior and `KeychainBackupHelper` are unchanged.

The bridge keeps GenericPassword and InternetPassword. Every group × class is attempted. Success and item-not-found count as succeeded; every other OSStatus counts as failed. Wipe responses include exact bundle/action/nonce plus ok/attempted/succeeded/failed. Restore overwrite retains the compatibility void wrapper; Backup/Restore response contracts were not changed.

AppDataCleaner accepts a bridge response only after exact nonce, bundle and action checks; exact boolean YES; nonnegative integer counts; attempted > 0; and a complete successful partition. Request, response, response temporary file and log are removed on all return/exception paths.

## 11. UI empty-selection behavior

`KeychainGroupsViewController` distinguishes absence from an NSArray, intersects saved values with current signed groups, preserves explicit empty selection, warns and selects none for malformed saved objects, and saves `@[]` unchanged. Layout and notification remain unchanged.

`ProjectXViewController` defaults/persists all signed groups only when the saved object is absent, preserves any saved NSArray including empty, maps malformed objects to zero groups, displays `0 selected`, does not auto-enable Keychain, and retains the existing system-policy UI behavior.

## 12. Main order and bypass audit

Main high-level order is: kill target; plan + initial pass; URL credentials; app state; freeze; four-scope data aggregate; in-memory cookies; planned final pass; sync; log-only broad verification; five-scope aggregate; callback.

| Main-flow Keychain occurrence | Classification |
|---|---|
| `_keychainClearPlanForBundleIdentifier:` | Full-operation plan construction |
| First `_executeKeychainWipe...` | Initial pass |
| Second `_executeKeychainWipe...` | Final pass for non-system plans only |
| `_keychainComponentForPlan:` | Typed Keychain component construction |
| `fullComponents addObject:keychainComponent` | Final five-scope aggregate |
| `hasKeychainItemsForBundleID:` in `verifyDataCleared:` | Read-only/log-only broad verification; cannot rewrite component |
| `_wipeSelectedKeychainForBundleID:` and older helpers elsewhere | Unreachable legacy compatibility from migrated main |

Migrated main contains no `clearKeychainItemsForBundleID:`, `universalKeychainWipeForBundleID:`, `clearAppKeychain:`, `clearKeychainData:`, security delete compatibility path or extension-Keychain helper call.

## 13. Out-of-scope non-regression

No protected public Clear model, resolver, validator, CommandRunner, App Group, Backup manager, KeychainBackupHelper or Makefile file changed. Backup/Restore/List branches remain outside the TASK-1.10 result. Extension Keychain was not migrated. No generic permission/marker helper or data-component safety behavior was changed.

## 14. Required static gates

| Gate | Result | Evidence |
|---|---|---|
| PXMigratedDataClearScopes | PASS | Exact ApplicationData | ExtensionData | AppGroups | PluginKitData. |
| PXMigratedFullClearScopes | PASS | Exact four data scopes plus Keychain; no PXClearScopeDefaultMask. |
| Data aggregate component count | PASS | Four-scope validator requires 4 and `_completeDataWipeForMigratedRequest:` constructs four data components. |
| Full aggregate component count | PASS | Five-scope validator requires 5; one Keychain component is appended. |
| completeAppDataWipe Keychain calls | PASS | Zero; it remains four-scope/data-only. |
| Main legacy wrapper calls | PASS | Zero `_wipeSelectedKeychainForBundleID:` calls inside `clearDataForBundleID:completion:`. |
| Detached callback booleans | PASS | No keychainOK1/keychainOK2/keychainFailed/keychainError1/keychainError2. |
| Callback precedence | PASS | ApplicationData, ExtensionData, AppGroups, PluginKitData, Keychain. |
| allRequestedScopesSucceeded callback | PASS | Zero references in migrated main. |
| Immutable-plan setting reads | PASS | Enabled, selected object and system policy are each read once; entitlements once when enabled. |
| Empty selection fallback | PASS | Explicit empty array maps to exact Skipped detail and never falls back to all. |
| Unauthorized selected group | PASS | Exact membership failure returns AuthorizationFailed; no silent drop. |
| Unbounded sign/wipe | PASS | Zero runAndCapture calls in exact execution method. |
| Direct ldid/helper paths | PASS | One bounded direct invocation path each. |
| Helper warnings | PASS | warnings.count > 0 exits 2. |
| Bridge truthfulness | PASS | No unconditional ok YES; attempted/succeeded/failed are present and partitioned. |
| Bridge response acceptance | PASS | Nonce/bundle/action/boolean/count/partition checks all required. |
| Persisted raw output | PASS | No stdout/stderr/group values or command text in DataCleaningKeychainResult. |
| Receipt tokens | PASS | Zero `_MASReceipt` tokens. |

Automated method-boundary gate summary: **28/28 PASS**.

## 15. Scenario matrix (60)

`STATIC PASS` means the exact source branch/validator/accounting contract was verified. `DEVICE PENDING` means the branch is statically covered but requires an iOS device/fault injection for runtime proof.

| # | Scenario | Evidence status | Evidence / expected result |
|---:|---|---|---|
| 1 | Invalid full Clear request | STATIC PASS | Full/data request construction failure returns a main-thread Invalid full Clear request error before work. |
| 2 | Keychain wipe setting absent/default OFF | STATIC PASS | Absent enabled object yields immutable disabled plan and exact disabled skip detail. |
| 3 | Keychain wipe explicitly OFF | STATIC PASS | False enabled value follows the same Skipped 0/0/0 branch. |
| 4 | Enabled with no saved selected-groups object | STATIC PASS | selectedObject == nil defaults selected groups to the exact sorted signed authorized set without persistence. |
| 5 | Enabled with saved nonempty selected array | STATIC PASS | Array is fully validated, exact-deduplicated, sorted and subset-checked. |
| 6 | Enabled with saved empty array | STATIC PASS | Object presence is preserved; exact No keychain access groups are selected skip. |
| 7 | Saved selected-groups object has wrong type | STATIC PASS | ConfigurationFailed planning result; no execution. |
| 8 | Saved array contains non-string element | STATIC PASS | PXKeychainExactStringIsValid rejects and planning fails closed. |
| 9 | Saved group is whitespace-only | STATIC PASS | Non-whitespace requirement rejects it. |
| 10 | Saved group contains U+0000 | STATIC PASS | Explicit NUL search rejects it. |
| 11 | Saved group contains comma | STATIC PASS | Comma is rejected before CSV construction. |
| 12 | Saved group has leading/trailing whitespace | STATIC PASS | Exact trim comparison rejects it without normalization. |
| 13 | Entitlement extraction failure | STATIC PASS | Non-nil extraction error maps to ConfigurationFailed 1/0/1. |
| 14 | Entitlements root wrong type/nil | STATIC PASS | Only NSDictionary root is accepted. |
| 15 | keychain-access-groups absent | STATIC PASS | Absent key is treated as an empty signed group array; valid application-identifier may still authorize its exact group. |
| 16 | keychain-access-groups wrong type | STATIC PASS | AuthorizationFailed. |
| 17 | keychain-access-groups invalid element | STATIC PASS | Every runtime element is validated; any invalid element fails the plan. |
| 18 | application-identifier valid | STATIC PASS | Exact valid string is captured and added to the signed authorized set. |
| 19 | application-identifier absent for non-system helper | STATIC PASS | AuthorizationFailed before direct helper execution. |
| 20 | Duplicate exact signed groups | STATIC PASS | NSMutableSet exact dedup followed by compare: sorting. |
| 21 | Selected group exact authorized member | STATIC PASS | Exact NSSet membership permits the plan. |
| 22 | Selected group not authorized | STATIC PASS | AuthorizationFailed; no silent drop. |
| 23 | No signed authorized groups | STATIC PASS | Absent/empty selection maps to exact no-authorized-groups Skipped 0/0/0; nonempty saved selection fails authorization. |
| 24 | System app with global policy OFF | STATIC PASS | ConfigurationFailed 1/0/1; no bridge pass. |
| 25 | System app with policy ON and bridge success | STATIC COVERAGE / DEVICE PENDING | Plan schedules one pass; strict response produces Succeeded 1/1/0. Device injection/runtime remains pending. |
| 26 | System bridge malformed request groups | STATIC PASS | Empty/wrong-type/invalid group array produces ok NO and zero counts. |
| 27 | System bridge one SecItemDelete failure | STATIC COVERAGE / DEVICE PENDING | Failure increments failed and makes ok false; device OSStatus injection pending. |
| 28 | System bridge all items not found | STATIC COVERAGE / DEVICE PENDING | errSecItemNotFound counts as succeeded for every group × class operation. |
| 29 | System bridge response nonce mismatch | STATIC PASS | Exact nonce mismatch rejected. |
| 30 | System bridge response bundle mismatch | STATIC PASS | Exact bundle mismatch rejected. |
| 31 | System bridge response action mismatch | STATIC PASS | Only action == wipe accepted. |
| 32 | System bridge response missing counts | STATIC PASS | All three nonnegative integer count fields are mandatory. |
| 33 | System bridge count partition invalid | STATIC PASS | Rejects attempted 0, succeeded > attempted, failed != attempted-succeeded, failed != 0 or succeeded != attempted. |
| 34 | Non-system ldid not found | STATIC COVERAGE / DEVICE PENDING | ConfigurationFailed before temp execution; filesystem runtime pending. |
| 35 | Non-system helper not found | STATIC COVERAGE / DEVICE PENDING | ConfigurationFailed before copy; filesystem runtime pending. |
| 36 | Non-system helper copy failure | STATIC COVERAGE / DEVICE PENDING | Fail closed and finally cleanup; permission/fault injection pending. |
| 37 | Entitlement plist generation/write failure | STATIC COVERAGE / DEVICE PENDING | Serialization/write failure returns ConfigurationFailed and finally cleanup. |
| 38 | Direct ldid timeout/failure/truncation | STATIC COVERAGE / DEVICE PENDING | 60 s, 1 MiB, result/isSucceeded/no-truncation all required. |
| 39 | Direct helper timeout/failure/truncation | STATIC COVERAGE / DEVICE PENDING | 120 s, 1 MiB, result/isSucceeded/no-truncation all required. |
| 40 | Helper warnings with zero item count | STATIC COVERAGE / DEVICE PENDING | Warnings count causes exit 2 even with processed/succeeded/failed all zero. |
| 41 | Non-system initial fails, final succeeds | STATIC PASS | Both passes run; component Failed 2/1/1 with first InitialPassFailed. |
| 42 | Non-system initial succeeds, final fails | STATIC PASS | Component Failed 2/1/1 with FinalPassFailed. |
| 43 | Both non-system passes fail | STATIC PASS | Component Failed 2/0/2; first failure retained. |
| 44 | Both non-system passes succeed | STATIC PASS | Exact success detail and Succeeded 2/2/0. |
| 45 | System app performs exactly one pass | STATIC PASS | plannedPassCount is 1 and final-pass condition is count == 2. |
| 46 | Disabled Keychain creates Skipped 0/0/0 | STATIC PASS | Exact disabled detail accepted by structural validator. |
| 47 | Empty selection creates Skipped 0/0/0 | STATIC PASS | Exact no-selection detail accepted by structural validator. |
| 48 | Planning failure creates Failed 1/0/1 and data still runs | STATIC PASS | Planning failure component is synthetic one unit; main proceeds unconditionally to four-scope aggregate. |
| 49 | ApplicationData plus Keychain failure precedence | STATIC PASS | ApplicationData precedes Keychain in final result traversal; all failures still logged. |
| 50 | AppGroups plus Keychain failure precedence | STATIC PASS | AppGroups precedes Keychain. |
| 51 | Only Keychain fails | STATIC PASS | First/only failed component produces PXKeychainClear callback NSError. |
| 52 | Keychain skipped while data has no failures | STATIC PASS | Skipped is not callback failure; safeCompletion YES. |
| 53 | Final aggregate wrong/missing Keychain component | STATIC PASS | Five-scope structural validator rejects count/order/scope mismatch. |
| 54 | completeAppDataWipe remains four-scope/data-only | STATIC PASS | Creates PXMigratedDataClearScopes request and never executes Keychain. |
| 55 | KeychainGroups UI reopens explicit empty as empty | STATIC PASS | Saved NSArray is honored even at count zero; selected set remains empty. |
| 56 | Clear confirmation preserves explicit empty | STATIC PASS | Saved NSArray, including @[], is used directly and displays 0 selected. |
| 57 | Temporary helper directory cleanup after success | STATIC COVERAGE / DEVICE PENDING | @finally removes helper, entitlement plist and unique temp directory. |
| 58 | Temporary helper directory cleanup after failure | STATIC COVERAGE / DEVICE PENDING | Same @finally executes for returns and exceptions. |
| 59 | Stored diagnostic has no stdout/stderr/group values | STATIC PASS | Only success, exitCode, timedOut, truncation flags and groupCount are stored. |
| 60 | Legacy _wipeSelectedKeychainForBundleID mapping | STATIC PASS | Skipped -> YES, exact execution success -> YES, planning/execution failure -> NO. |

## 16. Required verification

- `git rev-parse HEAD`: baseline matched before editing.
- `git diff --check`: PASS before report generation.
- `git diff --exit-code -- <protected files>`: PASS.
- Lexical delimiter audits: PASS for all five production files.
- NUL audit: zero NUL bytes in all five production files.
- Local Objective-C/Theos build: **not run** because this Windows workspace has no `clang`, `make`, or `xcrun`. GitHub Actions/device build remains the compilation/runtime gate.

Production diff stat:
```text
 AppDataCleaner.m               | 1395 ++++++++++++++++++++++++++++------------
 KeychainGroupsViewController.m |   26 +-
 KeychainHelper/backup_helper.m |   22 +-
 ProjectXViewController.m       |   34 +-
 WeaponXKeychainBridge/Tweak.m  |   89 ++-
 5 files changed, 1100 insertions(+), 466 deletions(-)
```

Production numstat:
```text
977	418	AppDataCleaner.m
17	9	KeychainGroupsViewController.m
18	4	KeychainHelper/backup_helper.m
16	18	ProjectXViewController.m
72	17	WeaponXKeychainBridge/Tweak.m
```

## 17. Whitespace, NUL, binary and generated-artifact audit

| File | Bytes | NUL | CRLF | Bare LF | Trailing-whitespace lines (current) | Binary |
|---|---:|---:|---:|---:|---:|---|
| `AppDataCleaner.m` | 455229 | 0 | 8563 | 0 | 598 | No |
| `WeaponXKeychainBridge/Tweak.m` | 21970 | 0 | 497 | 0 | 2 | No |
| `KeychainHelper/backup_helper.m` | 14129 | 0 | 323 | 0 | 25 | No |
| `KeychainGroupsViewController.m` | 10227 | 0 | 225 | 0 | 0 | No |
| `ProjectXViewController.m` | 372278 | 0 | 7148 | 0 | 715 | No |

`git diff --check` is authoritative for changed-line whitespace and passed. No generated binary, object, archive, package or temporary TASK-1.10 audit file is included in the task commit.

## 18. Remaining risks

- iOS device execution, Security.framework OSStatus fault injection, target-app bridge injection and launch behavior remain runtime-pending.
- The system bridge now registers for `com.apple.*` bundle identifiers as required for the system one-pass transport; device testing must confirm the installed substrate filter loads it only in intended targets.
- The bridge request filename remains the established per-bundle fixed path; same-bundle concurrent Clear operations are assumed serialized by the UI/workflow.
- Direct command semantics rely on the protected CommandRunner contract and need CI/device confirmation.

## 19. Complete production source diff

```diff
diff --git a/AppDataCleaner.m b/AppDataCleaner.m
index ce01d8b..a5dc357 100644
--- a/AppDataCleaner.m
+++ b/AppDataCleaner.m
@@ -8,6 +8,7 @@
 #import <sys/stat.h>
 #import <signal.h>
 #import <math.h>
+#import <string.h>
 #import <sqlite3.h>
 #import <notify.h>

@@ -30,6 +31,8 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
 // Add SearchableIndex framework if available
 #import <CoreSpotlight/CoreSpotlight.h>

+@class PXKeychainClearPlan;
+
 @interface AppDataCleaner ()
 - (NSString *)runCommandAndGetOutput:(NSString *)command
                           timeoutSec:(NSTimeInterval)timeoutSec;
@@ -58,6 +61,93 @@ static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
                                                            successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths;
 - (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID
                                                          deepClean:(BOOL)deepClean;
+- (PXKeychainClearPlan *)_keychainClearPlanForBundleIdentifier:(NSString *)bundleIdentifier;
+- (BOOL)_executeKeychainWipeForBundleIdentifier:(NSString *)bundleIdentifier
+                                  selectedGroups:(NSArray<NSString *> *)selectedGroups
+                           applicationIdentifier:(NSString *)applicationIdentifier
+                              systemApplication:(BOOL)systemApplication
+                                          error:(NSError **)error;
+- (PXClearComponentResult *)_keychainComponentForPlan:(PXKeychainClearPlan *)plan
+                                          passResults:(NSArray<NSNumber *> *)passResults;
+@end
+
+@interface PXKeychainClearPlan : NSObject {
+@private
+    NSString *_bundleIdentifier;
+    BOOL _enabled;
+    BOOL _systemApplication;
+    BOOL _systemPolicyAllowed;
+    NSArray<NSString *> *_selectedGroups;
+    NSArray<NSString *> *_authorizedGroups;
+    NSString *_applicationIdentifier;
+    NSUInteger _plannedPassCount;
+    NSString *_skipDetail;
+    NSInteger _planningFailureCode;
+    NSString *_planningFailureMessage;
+}
+@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
+@property (nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
+@property (nonatomic, assign, readonly, getter=isSystemApplication) BOOL systemApplication;
+@property (nonatomic, assign, readonly, getter=isSystemPolicyAllowed) BOOL systemPolicyAllowed;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *selectedGroups;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *authorizedGroups;
+@property (nonatomic, copy, readonly) NSString *applicationIdentifier;
+@property (nonatomic, assign, readonly) NSUInteger plannedPassCount;
+@property (nonatomic, copy, readonly) NSString *skipDetail;
+@property (nonatomic, assign, readonly) NSInteger planningFailureCode;
+@property (nonatomic, copy, readonly) NSString *planningFailureMessage;
+- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
+                                 enabled:(BOOL)enabled
+                       systemApplication:(BOOL)systemApplication
+                     systemPolicyAllowed:(BOOL)systemPolicyAllowed
+                          selectedGroups:(NSArray<NSString *> *)selectedGroups
+                        authorizedGroups:(NSArray<NSString *> *)authorizedGroups
+                   applicationIdentifier:(NSString *)applicationIdentifier
+                        plannedPassCount:(NSUInteger)plannedPassCount
+                              skipDetail:(NSString *)skipDetail
+                     planningFailureCode:(NSInteger)planningFailureCode
+                  planningFailureMessage:(NSString *)planningFailureMessage;
+@end
+
+@implementation PXKeychainClearPlan
+@synthesize bundleIdentifier = _bundleIdentifier;
+@synthesize enabled = _enabled;
+@synthesize systemApplication = _systemApplication;
+@synthesize systemPolicyAllowed = _systemPolicyAllowed;
+@synthesize selectedGroups = _selectedGroups;
+@synthesize authorizedGroups = _authorizedGroups;
+@synthesize applicationIdentifier = _applicationIdentifier;
+@synthesize plannedPassCount = _plannedPassCount;
+@synthesize skipDetail = _skipDetail;
+@synthesize planningFailureCode = _planningFailureCode;
+@synthesize planningFailureMessage = _planningFailureMessage;
+- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
+                                 enabled:(BOOL)enabled
+                       systemApplication:(BOOL)systemApplication
+                     systemPolicyAllowed:(BOOL)systemPolicyAllowed
+                          selectedGroups:(NSArray<NSString *> *)selectedGroups
+                        authorizedGroups:(NSArray<NSString *> *)authorizedGroups
+                   applicationIdentifier:(NSString *)applicationIdentifier
+                        plannedPassCount:(NSUInteger)plannedPassCount
+                              skipDetail:(NSString *)skipDetail
+                     planningFailureCode:(NSInteger)planningFailureCode
+                  planningFailureMessage:(NSString *)planningFailureMessage {
+    self = [super init];
+    if (self) {
+        _bundleIdentifier = [bundleIdentifier copy] ?: @"";
+        _enabled = enabled;
+        _systemApplication = systemApplication;
+        _systemPolicyAllowed = systemPolicyAllowed;
+        _selectedGroups = [selectedGroups copy] ?: @[];
+        _authorizedGroups = [authorizedGroups copy] ?: @[];
+        _applicationIdentifier = [applicationIdentifier copy];
+        _plannedPassCount = plannedPassCount;
+        _skipDetail = [skipDetail copy];
+        _planningFailureCode = planningFailureCode;
+        _planningFailureMessage = [planningFailureMessage copy];
+    }
+    return self;
+}
 @end

 @implementation AppDataCleaner {
@@ -686,6 +776,29 @@ static const PXClearScope PXMigratedDataClearScopes =
     PXClearScopeAppGroups |
     PXClearScopePluginKitData;

+static const PXClearScope PXMigratedFullClearScopes =
+    PXClearScopeApplicationData |
+    PXClearScopeExtensionData |
+    PXClearScopeAppGroups |
+    PXClearScopePluginKitData |
+    PXClearScopeKeychain;
+
+typedef NS_ENUM(NSInteger, PXKeychainClearFailureCode) {
+    PXKeychainClearFailureCodeInvalidRequest = 1,
+    PXKeychainClearFailureCodeConfigurationFailed = 2,
+    PXKeychainClearFailureCodeAuthorizationFailed = 3,
+    PXKeychainClearFailureCodeInitialPassFailed = 4,
+    PXKeychainClearFailureCodeFinalPassFailed = 5,
+    PXKeychainClearFailureCodeInternalResultFailure = 6,
+};
+
+static NSString * const PXKeychainClearFailureDomain = @"PXKeychainClear";
+static NSString * const PXKeychainDisabledDetail = @"Keychain wipe is disabled for this app";
+static NSString * const PXKeychainNoSelectionDetail = @"No keychain access groups are selected";
+static NSString * const PXKeychainNoAuthorizedGroupsDetail = @"No authorized keychain access groups were discovered";
+static NSString * const PXKeychainSuccessDetail = @"All planned keychain wipe passes succeeded";
+static NSString * const PXKeychainFailureDetail = @"One or more keychain wipe passes failed";
+
 typedef NS_ENUM(NSInteger, PXExactDataClearFailureCode) {
     PXExactDataClearFailureCodeInvalidRequest = 1,
     PXExactDataClearFailureCodeDiscoveryFailed = 2,
@@ -696,6 +809,93 @@ typedef NS_ENUM(NSInteger, PXExactDataClearFailureCode) {
     PXExactDataClearFailureCodeInternalResultFailure = 7,
 };

+static BOOL PXKeychainExactStringIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    NSString *string = (NSString *)value;
+    if (string.length == 0 || [string rangeOfString:@","].location != NSNotFound) return NO;
+    unichar nulCharacter = 0;
+    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
+    if ([string rangeOfString:nulString].location != NSNotFound) return NO;
+    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    if ([string rangeOfCharacterFromSet:[whitespace invertedSet]].location == NSNotFound) return NO;
+    NSString *trimmed = [string stringByTrimmingCharactersInSet:whitespace];
+    return [trimmed isEqualToString:string];
+}
+
+static PXClearFailure *PXKeychainFailure(PXKeychainClearFailureCode code, NSString *message) {
+    return [[PXClearFailure alloc] initWithDomain:PXKeychainClearFailureDomain
+                                            code:code
+                                         message:message ?: @"Keychain clear failed"];
+}
+
+static void PXAssignKeychainNSError(NSError **error,
+                                    PXKeychainClearFailureCode code,
+                                    NSString *message) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXKeychainClearFailureDomain
+                                 code:code
+                             userInfo:@{NSLocalizedDescriptionKey: message ?: @"Keychain clear failed"}];
+}
+
+static BOOL PXBoundedCommandSucceeded(CommandResult *result) {
+    return [result isKindOfClass:[CommandResult class]] &&
+           result.isSucceeded &&
+           !result.stdoutTruncated &&
+           !result.stderrTruncated;
+}
+
+static BOOL PXNumberIsBooleanTrue(id value) {
+    if (![value isKindOfClass:[NSNumber class]]) return NO;
+    CFTypeRef cfValue = (__bridge CFTypeRef)value;
+    return CFGetTypeID(cfValue) == CFBooleanGetTypeID() && [(NSNumber *)value boolValue];
+}
+
+static BOOL PXReadNonnegativeInteger(id value, NSUInteger *outValue) {
+    if (![value isKindOfClass:[NSNumber class]]) return NO;
+    CFTypeRef cfValue = (__bridge CFTypeRef)value;
+    if (CFGetTypeID(cfValue) == CFBooleanGetTypeID()) return NO;
+    const char *type = [(NSNumber *)value objCType];
+    if (!type || !strchr("cCsSiIlLqQ", type[0])) return NO;
+    long long signedValue = [(NSNumber *)value longLongValue];
+    if (signedValue < 0) return NO;
+    unsigned long long unsignedValue = [(NSNumber *)value unsignedLongLongValue];
+    if (unsignedValue > (unsigned long long)NSUIntegerMax) return NO;
+    if (outValue) *outValue = (NSUInteger)unsignedValue;
+    return YES;
+}
+
+static BOOL PXKeychainBridgeResponseIsValid(id value,
+                                            NSString *bundleIdentifier,
+                                            NSString *nonce) {
+    if (![value isKindOfClass:[NSDictionary class]] ||
+        ![bundleIdentifier isKindOfClass:[NSString class]] ||
+        ![nonce isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSDictionary *response = (NSDictionary *)value;
+    if (![response[@"nonce"] isKindOfClass:[NSString class]] ||
+        ![response[@"nonce"] isEqualToString:nonce] ||
+        ![response[@"bundleID"] isKindOfClass:[NSString class]] ||
+        ![response[@"bundleID"] isEqualToString:bundleIdentifier] ||
+        ![response[@"action"] isKindOfClass:[NSString class]] ||
+        ![response[@"action"] isEqualToString:@"wipe"] ||
+        !PXNumberIsBooleanTrue(response[@"ok"])) {
+        return NO;
+    }
+    NSUInteger attempted = 0, succeeded = 0, failed = 0;
+    if (!PXReadNonnegativeInteger(response[@"attempted"], &attempted) ||
+        !PXReadNonnegativeInteger(response[@"succeeded"], &succeeded) ||
+        !PXReadNonnegativeInteger(response[@"failed"], &failed) ||
+        attempted == 0 ||
+        succeeded > attempted ||
+        failed != attempted - succeeded ||
+        failed != 0 ||
+        succeeded != attempted) {
+        return NO;
+    }
+    return YES;
+}
+
 typedef NS_ENUM(NSInteger, PXInstalledExtensionDiscoveryErrorCode) {
     PXInstalledExtensionDiscoveryErrorCodeInvalidRequest = 1,
     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed = 2,
@@ -904,6 +1104,7 @@ static NSString *PXMigratedComponentName(PXClearScope scope) {
         case PXClearScopeExtensionData: return @"ExtensionData";
         case PXClearScopeAppGroups: return @"AppGroups";
         case PXClearScopePluginKitData: return @"PluginKitData";
+        case PXClearScopeKeychain: return @"Keychain";
         default: return @"Unknown";
     }
 }
@@ -964,7 +1165,7 @@ static BOOL PXExactDataComponentResultIsStructurallyValid(id value,
     return NO;
 }

-static BOOL PXMigratedClearResultIsStructurallyValid(id value) {
+static BOOL PXMigratedDataClearResultIsStructurallyValid(id value) {
     if (![value isKindOfClass:[PXClearResult class]]) return NO;
     PXClearResult *result = (PXClearResult *)value;
     if (![result.request isKindOfClass:[PXClearRequest class]] ||
@@ -987,6 +1188,64 @@ static BOOL PXMigratedClearResultIsStructurallyValid(id value) {
            PXExactDataComponentResultIsStructurallyValid(pluginKitData, PXClearScopePluginKitData);
 }

+static BOOL PXKeychainComponentResultIsStructurallyValid(id value) {
+    if (![value isKindOfClass:[PXClearComponentResult class]]) return NO;
+    PXClearComponentResult *result = (PXClearComponentResult *)value;
+    if (result.scope != PXClearScopeKeychain ||
+        result.succeededUnitCount > result.attemptedUnitCount ||
+        result.failedUnitCount != result.attemptedUnitCount - result.succeededUnitCount) {
+        return NO;
+    }
+    switch (result.status) {
+        case PXClearComponentStatusSucceeded:
+            return (result.attemptedUnitCount == 1 || result.attemptedUnitCount == 2) &&
+                   result.succeededUnitCount == result.attemptedUnitCount &&
+                   result.failedUnitCount == 0 &&
+                   result.failure == nil &&
+                   [result.detail isEqualToString:PXKeychainSuccessDetail];
+        case PXClearComponentStatusSkipped:
+            return result.attemptedUnitCount == 0 &&
+                   result.succeededUnitCount == 0 &&
+                   result.failedUnitCount == 0 &&
+                   result.failure == nil &&
+                   ([result.detail isEqualToString:PXKeychainDisabledDetail] ||
+                    [result.detail isEqualToString:PXKeychainNoSelectionDetail] ||
+                    [result.detail isEqualToString:PXKeychainNoAuthorizedGroupsDetail]);
+        case PXClearComponentStatusFailed:
+            return (result.attemptedUnitCount == 1 || result.attemptedUnitCount == 2) &&
+                   result.failedUnitCount > 0 &&
+                   [result.failure isKindOfClass:[PXClearFailure class]] &&
+                   [result.failure.domain isEqualToString:PXKeychainClearFailureDomain] &&
+                   [result.detail isEqualToString:PXKeychainFailureDetail];
+    }
+    return NO;
+}
+
+static BOOL PXMigratedFullClearResultIsStructurallyValid(id value) {
+    if (![value isKindOfClass:[PXClearResult class]]) return NO;
+    PXClearResult *result = (PXClearResult *)value;
+    if (![result.request isKindOfClass:[PXClearRequest class]] ||
+        result.request.scopes != PXMigratedFullClearScopes ||
+        result.componentResults.count != 5) {
+        return NO;
+    }
+    PXClearComponentResult *applicationData = result.componentResults[0];
+    PXClearComponentResult *extensionData = result.componentResults[1];
+    PXClearComponentResult *appGroups = result.componentResults[2];
+    PXClearComponentResult *pluginKitData = result.componentResults[3];
+    PXClearComponentResult *keychain = result.componentResults[4];
+    return applicationData.scope == PXClearScopeApplicationData &&
+           extensionData.scope == PXClearScopeExtensionData &&
+           appGroups.scope == PXClearScopeAppGroups &&
+           pluginKitData.scope == PXClearScopePluginKitData &&
+           keychain.scope == PXClearScopeKeychain &&
+           PXApplicationDataComponentResultIsStructurallyValid(applicationData) &&
+           PXExactDataComponentResultIsStructurallyValid(extensionData, PXClearScopeExtensionData) &&
+           PXAppGroupsComponentResultIsStructurallyValid(appGroups) &&
+           PXExactDataComponentResultIsStructurallyValid(pluginKitData, PXClearScopePluginKitData) &&
+           PXKeychainComponentResultIsStructurallyValid(keychain);
+}
+
 static NSError *PXMigratedInternalError(NSString *message) {
     return [NSError errorWithDomain:PXMigratedDataClearFailureDomain
                                code:PXExactDataClearFailureCodeInternalResultFailure
@@ -1159,181 +1418,359 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

 #pragma mark - Keychain Wipe Settings

-- (BOOL)_isKeychainWipeEnabledForBundleID:(NSString *)bundleID {
-    if (!bundleID.length) return NO;
-    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
-    NSString *key = PXKeychainWipeEnabledKey(bundleID);
-    if ([defaults objectForKey:key] == nil) {
-        // Default OFF (safer): keychain wipe can log you out and may not be restorable for some apps.
-        return NO;
+- (PXKeychainClearPlan *)_keychainClearPlanForBundleIdentifier:(NSString *)bundleIdentifier {
+    BOOL systemApplication = [bundleIdentifier hasPrefix:@"com.apple."];
+    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:NO
+                                                  systemApplication:systemApplication
+                                                systemPolicyAllowed:NO
+                                                     selectedGroups:@[]
+                                                   authorizedGroups:@[]
+                                              applicationIdentifier:nil
+                                                   plannedPassCount:0
+                                                         skipDetail:nil
+                                                planningFailureCode:PXKeychainClearFailureCodeInvalidRequest
+                                             planningFailureMessage:@"Invalid Keychain clear request"];
     }
-    return [defaults boolForKey:key];
-}

-- (NSArray<NSString *> *)_selectedKeychainGroupsForBundleID:(NSString *)bundleID
-                                                     error:(NSError **)error {
-    if (!bundleID.length) return @[];
     NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
-    id saved = [defaults objectForKey:PXKeychainWipeGroupsKey(bundleID)];
-    if ([saved isKindOfClass:[NSArray class]] && [(NSArray *)saved count] > 0) {
-        NSMutableArray<NSString *> *out = [NSMutableArray array];
-        for (id v in (NSArray *)saved) {
-            if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) {
-                [out addObject:(NSString *)v];
-            }
-        }
-        return out;
+    id enabledObject = [defaults objectForKey:PXKeychainWipeEnabledKey(bundleIdentifier)];
+    id selectedObject = [defaults objectForKey:PXKeychainWipeGroupsKey(bundleIdentifier)];
+    BOOL enabled = [enabledObject respondsToSelector:@selector(boolValue)] && [enabledObject boolValue];
+    if (!enabled) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:NO
+                                                  systemApplication:systemApplication
+                                                systemPolicyAllowed:YES
+                                                     selectedGroups:@[]
+                                                   authorizedGroups:@[]
+                                              applicationIdentifier:nil
+                                                   plannedPassCount:0
+                                                         skipDetail:PXKeychainDisabledDetail
+                                                planningFailureCode:0
+                                             planningFailureMessage:nil];
+    }
+
+    BOOL systemPolicyAllowed = YES;
+    if (systemApplication) {
+        NSUserDefaults *securityDefaults =
+            [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
+        id policyObject = [securityDefaults objectForKey:@"allowSystemKeychainWipeEnabled"];
+        systemPolicyAllowed = [policyObject respondsToSelector:@selector(boolValue)] &&
+                              [policyObject boolValue];
     }

-    // Default selection: ALL groups from entitlements.
     AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
-    NSError *entErr = nil;
-    NSArray<NSString *> *groups = [reader keychainAccessGroupsForBundleID:bundleID error:&entErr];
-    if (groups.count > 0) {
-        [defaults setObject:groups forKey:PXKeychainWipeGroupsKey(bundleID)];
-        // Keep wipe disabled by default; user can enable explicitly in UI.
-        [defaults setBool:NO forKey:PXKeychainWipeEnabledKey(bundleID)];
-        [defaults synchronize];
-        return groups;
-    }
-
-    if (error) {
-        *error = entErr ?: [NSError errorWithDomain:@"AppDataCleaner"
-                                               code:100
-                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to read keychain-access-groups for this app"}];
-    }
-    return @[];
-}
-
-- (BOOL)_wipeSelectedKeychainForBundleID:(NSString *)bundleID
-                                   error:(NSError **)error {
-    if (!bundleID.length) return YES;
-    if (![self _isKeychainWipeEnabledForBundleID:bundleID]) {
-        [self logMessage:@"[AppDataCleaner] Keychain wipe disabled for %@", bundleID];
-        return YES;
+    NSError *entitlementsError = nil;
+    id entitlementsObject = [reader fullEntitlementsForBundleID:bundleIdentifier
+                                                          error:&entitlementsError];
+    if (entitlementsError || ![entitlementsObject isKindOfClass:[NSDictionary class]]) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:YES
+                                                  systemApplication:systemApplication
+                                                systemPolicyAllowed:systemPolicyAllowed
+                                                     selectedGroups:@[]
+                                                   authorizedGroups:@[]
+                                              applicationIdentifier:nil
+                                                   plannedPassCount:0
+                                                         skipDetail:nil
+                                                planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
+                                             planningFailureMessage:@"Signed Keychain authorization could not be read"];
+    }
+
+    NSDictionary *entitlements = (NSDictionary *)entitlementsObject;
+    NSMutableSet<NSString *> *authorizedSet = [NSMutableSet set];
+    id signedGroupsObject = entitlements[@"keychain-access-groups"];
+    if (signedGroupsObject && ![signedGroupsObject isKindOfClass:[NSArray class]]) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:YES
+                                                  systemApplication:systemApplication
+                                                systemPolicyAllowed:systemPolicyAllowed
+                                                     selectedGroups:@[]
+                                                   authorizedGroups:@[]
+                                              applicationIdentifier:nil
+                                                   plannedPassCount:0
+                                                         skipDetail:nil
+                                                planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
+                                             planningFailureMessage:@"Signed Keychain authorization is malformed"];
+    }
+    for (id groupObject in (NSArray *)(signedGroupsObject ?: @[])) {
+        if (!PXKeychainExactStringIsValid(groupObject)) {
+            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                                enabled:YES
+                                                      systemApplication:systemApplication
+                                                    systemPolicyAllowed:systemPolicyAllowed
+                                                         selectedGroups:@[]
+                                                       authorizedGroups:@[]
+                                                  applicationIdentifier:nil
+                                                       plannedPassCount:0
+                                                             skipDetail:nil
+                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
+                                                 planningFailureMessage:@"Signed Keychain authorization is malformed"];
+        }
+        [authorizedSet addObject:(NSString *)groupObject];
+    }
+
+    NSString *applicationIdentifier = nil;
+    id applicationIdentifierObject = entitlements[@"application-identifier"];
+    if (applicationIdentifierObject) {
+        if (!PXKeychainExactStringIsValid(applicationIdentifierObject)) {
+            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                                enabled:YES
+                                                      systemApplication:systemApplication
+                                                    systemPolicyAllowed:systemPolicyAllowed
+                                                         selectedGroups:@[]
+                                                       authorizedGroups:@[]
+                                                  applicationIdentifier:nil
+                                                       plannedPassCount:0
+                                                             skipDetail:nil
+                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
+                                                 planningFailureMessage:@"Signed Keychain authorization is malformed"];
+        }
+        applicationIdentifier = (NSString *)applicationIdentifierObject;
+        [authorizedSet addObject:applicationIdentifier];
+    }
+
+    NSArray<NSString *> *authorizedGroups =
+        [[authorizedSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
+
+    NSArray<NSString *> *selectedGroups = nil;
+    BOOL selectedObjectWasExplicit = selectedObject != nil;
+    if (!selectedObjectWasExplicit) {
+        selectedGroups = authorizedGroups;
+    } else if (![selectedObject isKindOfClass:[NSArray class]]) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:YES
+                                                  systemApplication:systemApplication
+                                                systemPolicyAllowed:systemPolicyAllowed
+                                                     selectedGroups:@[]
+                                                   authorizedGroups:authorizedGroups
+                                              applicationIdentifier:applicationIdentifier
+                                                   plannedPassCount:0
+                                                         skipDetail:nil
+                                                planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
+                                             planningFailureMessage:@"Saved Keychain selection is malformed"];
+    } else {
+        NSMutableSet<NSString *> *selectedSet = [NSMutableSet set];
+        for (id selectedObjectValue in (NSArray *)selectedObject) {
+            if (!PXKeychainExactStringIsValid(selectedObjectValue)) {
+                return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                                    enabled:YES
+                                                          systemApplication:systemApplication
+                                                        systemPolicyAllowed:systemPolicyAllowed
+                                                             selectedGroups:@[]
+                                                           authorizedGroups:authorizedGroups
+                                                      applicationIdentifier:applicationIdentifier
+                                                           plannedPassCount:0
+                                                                 skipDetail:nil
+                                                        planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
+                                                     planningFailureMessage:@"Saved Keychain selection is malformed"];
+            }
+            [selectedSet addObject:(NSString *)selectedObjectValue];
+        }
+        selectedGroups = [[selectedSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
+    }
+
+    if (systemApplication && !systemPolicyAllowed) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:YES
+                                                  systemApplication:YES
+                                                systemPolicyAllowed:NO
+                                                     selectedGroups:selectedGroups ?: @[]
+                                                   authorizedGroups:authorizedGroups
+                                              applicationIdentifier:applicationIdentifier
+                                                   plannedPassCount:0
+                                                         skipDetail:nil
+                                                planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
+                                             planningFailureMessage:@"System Keychain wipe policy denied the request"];
+    }
+
+    if (authorizedGroups.count == 0) {
+        if (selectedObjectWasExplicit && selectedGroups.count > 0) {
+            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                                enabled:YES
+                                                      systemApplication:systemApplication
+                                                    systemPolicyAllowed:systemPolicyAllowed
+                                                         selectedGroups:selectedGroups
+                                                       authorizedGroups:@[]
+                                                  applicationIdentifier:applicationIdentifier
+                                                       plannedPassCount:0
+                                                             skipDetail:nil
+                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
+                                                 planningFailureMessage:@"Saved Keychain selection is not authorized"];
+        }
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:YES
+                                                  systemApplication:systemApplication
+                                                systemPolicyAllowed:systemPolicyAllowed
+                                                     selectedGroups:@[]
+                                                   authorizedGroups:@[]
+                                              applicationIdentifier:applicationIdentifier
+                                                   plannedPassCount:0
+                                                         skipDetail:PXKeychainNoAuthorizedGroupsDetail
+                                                planningFailureCode:0
+                                             planningFailureMessage:nil];
+    }
+
+    if (selectedObjectWasExplicit && selectedGroups.count == 0) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:YES
+                                                  systemApplication:systemApplication
+                                                systemPolicyAllowed:systemPolicyAllowed
+                                                     selectedGroups:@[]
+                                                   authorizedGroups:authorizedGroups
+                                              applicationIdentifier:applicationIdentifier
+                                                   plannedPassCount:0
+                                                         skipDetail:PXKeychainNoSelectionDetail
+                                                planningFailureCode:0
+                                             planningFailureMessage:nil];
+    }
+
+    NSSet<NSString *> *authorizedMembership = [NSSet setWithArray:authorizedGroups];
+    for (NSString *selectedGroup in selectedGroups) {
+        if (![authorizedMembership containsObject:selectedGroup]) {
+            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                                enabled:YES
+                                                      systemApplication:systemApplication
+                                                    systemPolicyAllowed:systemPolicyAllowed
+                                                         selectedGroups:selectedGroups
+                                                       authorizedGroups:authorizedGroups
+                                                  applicationIdentifier:applicationIdentifier
+                                                       plannedPassCount:0
+                                                             skipDetail:nil
+                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
+                                                 planningFailureMessage:@"Saved Keychain selection is not authorized"];
+        }
+    }
+
+    if (!systemApplication && !PXKeychainExactStringIsValid(applicationIdentifier)) {
+        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                            enabled:YES
+                                                  systemApplication:NO
+                                                systemPolicyAllowed:YES
+                                                     selectedGroups:selectedGroups
+                                                   authorizedGroups:authorizedGroups
+                                              applicationIdentifier:nil
+                                                   plannedPassCount:0
+                                                         skipDetail:nil
+                                                planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
+                                             planningFailureMessage:@"Signed application identifier is required"];
+    }
+
+    return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
+                                                        enabled:YES
+                                              systemApplication:systemApplication
+                                            systemPolicyAllowed:systemPolicyAllowed
+                                                 selectedGroups:selectedGroups
+                                               authorizedGroups:authorizedGroups
+                                          applicationIdentifier:applicationIdentifier
+                                               plannedPassCount:(systemApplication ? 1u : 2u)
+                                                     skipDetail:nil
+                                            planningFailureCode:0
+                                         planningFailureMessage:nil];
+}
+
+- (BOOL)_executeKeychainWipeForBundleIdentifier:(NSString *)bundleIdentifier
+                                  selectedGroups:(NSArray<NSString *> *)selectedGroups
+                           applicationIdentifier:(NSString *)applicationIdentifier
+                              systemApplication:(BOOL)systemApplication
+                                          error:(NSError **)error {
+    if (error) *error = nil;
+    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier) ||
+        ![selectedGroups isKindOfClass:[NSArray class]] ||
+        selectedGroups.count == 0) {
+        PXAssignKeychainNSError(error,
+                                PXKeychainClearFailureCodeInvalidRequest,
+                                @"Invalid Keychain execution request");
+        return NO;
     }
-
-    NSError *groupsErr = nil;
-    NSArray<NSString *> *groups = [self _selectedKeychainGroupsForBundleID:bundleID error:&groupsErr];
-    if (groups.count == 0) {
-        // User may have selected none, or we couldn't resolve entitlements.
-        if (groupsErr) {
-            if (error) *error = groupsErr;
+    for (id group in selectedGroups) {
+        if (!PXKeychainExactStringIsValid(group)) {
+            PXAssignKeychainNSError(error,
+                                    PXKeychainClearFailureCodeInvalidRequest,
+                                    @"Invalid Keychain execution request");
             return NO;
         }
-        [self logMessage:@"[AppDataCleaner] Keychain wipe enabled but 0 groups selected for %@ (skipping)", bundleID];
-        return YES;
+    }
+    if (!systemApplication && !PXKeychainExactStringIsValid(applicationIdentifier)) {
+        PXAssignKeychainNSError(error,
+                                PXKeychainClearFailureCodeAuthorizationFailed,
+                                @"Signed application identifier is required");
+        return NO;
     }

-    BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
-    if (isSystemApp) {
-        NSUserDefaults *sec = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
-        BOOL allow = [sec boolForKey:@"allowSystemKeychainWipeEnabled"];
-        if (!allow) {
-            if (error) {
-                *error = [NSError errorWithDomain:@"AppDataCleaner"
-                                             code:101
-                                         userInfo:@{NSLocalizedDescriptionKey: @"System keychain wipe is disabled (enable in Security tab)"}];
-            }
-            return NO;
-        }
-        [self logMessage:@"[AppDataCleaner] System keychain wipe enabled for %@", bundleID];
-
-        // Use in-app bridge to wipe keychain groups (helper resign is unreliable for system apps).
-        NSString *safeBundle = [[bundleID componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"_"];
-        NSString *reqPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_request_%@.plist", safeBundle];
-        NSString *respPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_response_%@.plist", safeBundle];
-        NSString *logPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_bridge_%@.log", safeBundle];
+    if (systemApplication) {
+        NSString *safeBundle = [[bundleIdentifier componentsSeparatedByCharactersInSet:
+            [[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"_"];
         NSString *nonce = [[NSUUID UUID] UUIDString];
-
-        [[NSFileManager defaultManager] removeItemAtPath:reqPath error:nil];
-        [[NSFileManager defaultManager] removeItemAtPath:respPath error:nil];
-
-        NSDictionary *req = @{
-            @"action": @"wipe",
-            @"bundleID": bundleID,
-            @"groups": groups,
-            @"nonce": nonce,
-            @"respPath": respPath,
-            @"logPath": logPath,
-            @"bridgeOnly": @YES,
-        };
-
-        [self logMessage:@"[AppDataCleaner] System keychain wipe via bridge: nonce=%@", nonce];
-        [self logMessage:@"[AppDataCleaner] System keychain wipe via bridge: request=%@", reqPath];
-        [self logMessage:@"[AppDataCleaner] System keychain wipe via bridge: response=%@", respPath];
-        [self logMessage:@"[AppDataCleaner] System keychain wipe via bridge: log=%@", logPath];
-        if (![req writeToFile:reqPath atomically:YES]) {
-            if (error) {
-                *error = [NSError errorWithDomain:@"AppDataCleaner" code:105 userInfo:@{NSLocalizedDescriptionKey: @"Failed to write keychain bridge request"}];
-            }
-            return NO;
-        }
-
-        // Notify bridge and launch app
-        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
-                                            (__bridge CFStringRef)[NSString stringWithFormat:@"com.hydra.weaponx.keychain.req.%@", safeBundle],
-                                            NULL, NULL, true);
-        Class wsCls = NSClassFromString(@"LSApplicationWorkspace");
-        BOOL opened = NO;
-        if (wsCls) {
-            id ws = [wsCls performSelector:@selector(defaultWorkspace)];
-            if (ws && [ws respondsToSelector:@selector(openApplicationWithBundleID:)]) {
-                opened = ((BOOL (*)(id, SEL, id))objc_msgSend)(ws, @selector(openApplicationWithBundleID:), bundleID);
-
-                // Immediately bring ProjectX back to foreground (best-effort).
-                NSString *selfBundle = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
-                if (selfBundle.length) {
-                    ((BOOL (*)(id, SEL, id))objc_msgSend)(ws, @selector(openApplicationWithBundleID:), selfBundle);
-                }
+        NSString *requestPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_request_%@.plist", safeBundle];
+        NSString *responsePath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_response_%@_%@.plist", safeBundle, nonce];
+        NSString *logPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_bridge_%@_%@.log", safeBundle, nonce];
+        NSFileManager *fileManager = [NSFileManager defaultManager];
+        BOOL success = NO;
+        @try {
+            [fileManager removeItemAtPath:requestPath error:nil];
+            [fileManager removeItemAtPath:responsePath error:nil];
+            NSDictionary *request = @{
+                @"action": @"wipe",
+                @"bundleID": bundleIdentifier,
+                @"groups": selectedGroups,
+                @"nonce": nonce,
+                @"respPath": responsePath,
+                @"logPath": logPath,
+                @"bridgeOnly": @YES,
+            };
+            if (![request writeToFile:requestPath atomically:YES]) {
+                PXAssignKeychainNSError(error,
+                                        PXKeychainClearFailureCodeConfigurationFailed,
+                                        @"Keychain bridge request could not be created");
+                return NO;
             }
-        }

-        NSTimeInterval waitSec = opened ? 30.0 : 6.0;
-        NSDictionary *resp = PXWaitForKeychainBridgeResponse(safeBundle, respPath, nonce, waitSec);
-
-        // Kill app after bridge (may be SIGSTOP'd)
-        PXKillAppProcessBestEffort(self, bundleID);
-
-        // If it failed, include bridge log snippet for debugging.
-        if (![resp isKindOfClass:[NSDictionary class]] || ![resp[@"ok"] respondsToSelector:@selector(boolValue)] || ![resp[@"ok"] boolValue]) {
-            NSString *bridgeLog = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
-            if (bridgeLog.length) {
-                NSString *snippet = bridgeLog;
-                if (snippet.length > 600) {
-                    snippet = [snippet substringFromIndex:(snippet.length - 600)];
+            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
+                (__bridge CFStringRef)[NSString stringWithFormat:@"com.hydra.weaponx.keychain.req.%@", safeBundle],
+                NULL, NULL, true);
+            Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
+            BOOL opened = NO;
+            if (workspaceClass) {
+                id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
+                if (workspace && [workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
+                    opened = ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace,
+                                                                  @selector(openApplicationWithBundleID:),
+                                                                  bundleIdentifier);
+                    NSString *selfBundle = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
+                    if (selfBundle.length) {
+                        ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace,
+                                                             @selector(openApplicationWithBundleID:),
+                                                             selfBundle);
+                    }
                 }
-                [self logMessage:@"[AppDataCleaner] System keychain bridge log (tail): %@", snippet];
-            }
-        }
-
-        if (![resp isKindOfClass:[NSDictionary class]] || ![resp[@"ok"] respondsToSelector:@selector(boolValue)] || ![resp[@"ok"] boolValue]) {
-            NSString *msg = [resp[@"error"] isKindOfClass:[NSString class]] ? resp[@"error"] : @"System keychain wipe timed out";
-            if (error) {
-                *error = [NSError errorWithDomain:@"AppDataCleaner" code:106 userInfo:@{NSLocalizedDescriptionKey: msg}];
             }
+            NSDictionary *response = PXWaitForKeychainBridgeResponse(safeBundle,
+                                                                      responsePath,
+                                                                      nonce,
+                                                                      opened ? 30.0 : 6.0);
+            PXKillAppProcessBestEffort(self, bundleIdentifier);
+            success = PXKeychainBridgeResponseIsValid(response, bundleIdentifier, nonce);
+            if (!success) {
+                PXAssignKeychainNSError(error,
+                                        PXKeychainClearFailureCodeInternalResultFailure,
+                                        @"Keychain bridge returned incomplete execution evidence");
+            }
+            return success;
+        } @catch (__unused NSException *exception) {
+            PXAssignKeychainNSError(error,
+                                    PXKeychainClearFailureCodeInternalResultFailure,
+                                    @"Keychain bridge execution failed");
             return NO;
+        } @finally {
+            PXKillAppProcessBestEffort(self, bundleIdentifier);
+            [fileManager removeItemAtPath:requestPath error:nil];
+            [fileManager removeItemAtPath:responsePath error:nil];
+            [fileManager removeItemAtPath:[responsePath stringByAppendingString:@".tmp"] error:nil];
+            [fileManager removeItemAtPath:logPath error:nil];
         }
-
-        [self logMessage:@"[AppDataCleaner] System keychain wipe succeeded for %@", bundleID];
-
-        [[NSFileManager defaultManager] removeItemAtPath:reqPath error:nil];
-        [[NSFileManager defaultManager] removeItemAtPath:respPath error:nil];
-        return YES;
-    }
-
-    AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
-    NSError *entErr = nil;
-    NSDictionary *fullEnt = [reader fullEntitlementsForBundleID:bundleID error:&entErr];
-    NSString *appIdentifier = nil;
-    if ([fullEnt isKindOfClass:[NSDictionary class]]) {
-        id v = fullEnt[@"application-identifier"];
-        if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) {
-            appIdentifier = (NSString *)v;
-        }
-    }
-    if (!appIdentifier.length) {
-        appIdentifier = bundleID;
     }

     CommandRunner *runner = [CommandRunner shared];
@@ -1343,125 +1780,239 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         @"/private/preboot/jb/usr/bin/ldid",
         @"/bin/ldid"
     ]];
-    if (!ldidPath.length) {
-        if (error) {
-            *error = [NSError errorWithDomain:@"AppDataCleaner"
-                                         code:102
-                                     userInfo:@{NSLocalizedDescriptionKey: @"ldid not found (required for keychain wipe)"}];
-        }
+    if (!ldidPath.length || ![ldidPath hasPrefix:@"/"]) {
+        PXAssignKeychainNSError(error,
+                                PXKeychainClearFailureCodeConfigurationFailed,
+                                @"Keychain signing tool is unavailable");
         return NO;
     }
-
     NSString *helperPath = [runner firstExistingPath:@[
         @"/Library/WeaponX/backup_helper",
         @"/var/jb/Library/WeaponX/backup_helper",
         @"/private/var/jb/Library/WeaponX/backup_helper"
     ]];
-    if (!helperPath.length) {
-        if (error) {
-            *error = [NSError errorWithDomain:@"AppDataCleaner"
-                                         code:103
-                                     userInfo:@{NSLocalizedDescriptionKey: @"backup_helper not found (WeaponX not installed?)"}];
-        }
+    if (!helperPath.length || ![helperPath hasPrefix:@"/"]) {
+        PXAssignKeychainNSError(error,
+                                PXKeychainClearFailureCodeConfigurationFailed,
+                                @"Keychain helper is unavailable");
         return NO;
     }

-    // Create temp dir
-    NSString *tmpDir = [NSString stringWithFormat:@"/tmp/keychain_wipe_%d", getpid()];
-    [_fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
-    NSString *workingHelper = [tmpDir stringByAppendingPathComponent:@"backup_helper"];
-    NSString *entPath = [tmpDir stringByAppendingPathComponent:@"helper_ent.plist"];
-
-    // Copy helper
-    [_fileManager removeItemAtPath:workingHelper error:nil];
-    NSError *copyErr = nil;
-    if (![_fileManager copyItemAtPath:helperPath toPath:workingHelper error:&copyErr]) {
-        if (error) {
-            *error = [NSError errorWithDomain:@"AppDataCleaner"
-                                         code:104
-                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to copy backup_helper: %@", copyErr.localizedDescription ?: @"unknown"]}];
+    NSString *temporaryDirectory = [NSString stringWithFormat:@"/tmp/keychain_wipe_%d_%@",
+                                    getpid(), [[NSUUID UUID] UUIDString]];
+    NSString *workingHelper = [temporaryDirectory stringByAppendingPathComponent:@"backup_helper"];
+    NSString *entitlementsPath = [temporaryDirectory stringByAppendingPathComponent:@"helper_ent.plist"];
+    NSFileManager *fileManager = [NSFileManager defaultManager];
+    BOOL success = NO;
+    @try {
+        NSError *directoryError = nil;
+        if (![fileManager createDirectoryAtPath:temporaryDirectory
+                    withIntermediateDirectories:NO
+                                     attributes:@{NSFilePosixPermissions: @0700}
+                                          error:&directoryError]) {
+            PXAssignKeychainNSError(error,
+                                    PXKeychainClearFailureCodeConfigurationFailed,
+                                    @"Temporary Keychain workspace could not be created");
+            return NO;
         }
-        return NO;
-    }
-    chmod([workingHelper fileSystemRepresentation], 0755);
-
-    // Write entitlements for the helper (scoped to selected groups)
-    NSDictionary *helperEnt = @{
-        @"platform-application": @YES,
-        @"application-identifier": appIdentifier,
-        @"com.apple.private.security.no-sandbox": @YES,
-        @"com.apple.private.security.no-container": @YES,
-        @"com.apple.private.security.container-required": @NO,
-        @"com.apple.keystore.access-keychain-keys": @YES,
-        @"com.apple.keystore.device": @YES,
-        @"keychain-access-groups": groups,
-    };
-    NSError *plistErr = nil;
-    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:helperEnt
-                                                                   format:NSPropertyListXMLFormat_v1_0
-                                                                  options:0
-                                                                    error:&plistErr];
-    if (!plistData.length || plistErr) {
-        if (error) {
-            *error = plistErr ?: [NSError errorWithDomain:@"AppDataCleaner"
-                                                    code:105
-                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to build helper entitlements"}];
+        NSError *copyError = nil;
+        if (![fileManager copyItemAtPath:helperPath toPath:workingHelper error:&copyError]) {
+            PXAssignKeychainNSError(error,
+                                    PXKeychainClearFailureCodeConfigurationFailed,
+                                    @"Keychain helper could not be prepared");
+            return NO;
         }
-        return NO;
-    }
-    if (![plistData writeToFile:entPath atomically:YES]) {
-        if (error) {
-            *error = [NSError errorWithDomain:@"AppDataCleaner"
-                                         code:106
-                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to write helper entitlements file"}];
+        chmod(workingHelper.fileSystemRepresentation, 0755);
+
+        NSDictionary *helperEntitlements = @{
+            @"platform-application": @YES,
+            @"application-identifier": applicationIdentifier,
+            @"com.apple.private.security.no-sandbox": @YES,
+            @"com.apple.private.security.no-container": @YES,
+            @"com.apple.private.security.container-required": @NO,
+            @"com.apple.keystore.access-keychain-keys": @YES,
+            @"com.apple.keystore.device": @YES,
+            @"keychain-access-groups": selectedGroups,
+        };
+        NSError *serializationError = nil;
+        NSData *entitlementsData = [NSPropertyListSerialization dataWithPropertyList:helperEntitlements
+                                                                               format:NSPropertyListXMLFormat_v1_0
+                                                                              options:0
+                                                                                error:&serializationError];
+        NSError *writeError = nil;
+        if (!entitlementsData.length || serializationError ||
+            ![entitlementsData writeToFile:entitlementsPath
+                                   options:NSDataWritingAtomic
+                                     error:&writeError]) {
+            PXAssignKeychainNSError(error,
+                                    PXKeychainClearFailureCodeConfigurationFailed,
+                                    @"Keychain helper authorization could not be prepared");
+            return NO;
         }
-        return NO;
-    }

-    // Resign
-    NSString *signCmd = [NSString stringWithFormat:@"%@ -S%@ %@",
-                         PXShellQuote(ldidPath),
-                         PXShellQuote(entPath),
-                         PXShellQuote(workingHelper)];
-    CommandResult *signRes = [runner runAndCapture:signCmd];
-    if (signRes.exitCode != 0) {
-        if (error) {
-            NSString *msg = signRes.stderrString.length ? signRes.stderrString : @"ldid failed";
-            *error = [NSError errorWithDomain:@"AppDataCleaner"
-                                         code:107
-                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to resign helper: %@", msg]}];
+        CommandResult *signResult = [runner runExecutableAndCapture:ldidPath
+                                                           arguments:@[
+                                                               [@"-S" stringByAppendingString:entitlementsPath],
+                                                               workingHelper
+                                                           ]
+                                                          timeoutSec:60.0
+                                                      maxOutputBytes:1024 * 1024];
+        if (!PXBoundedCommandSucceeded(signResult)) {
+            PXAssignKeychainNSError(error,
+                                    PXKeychainClearFailureCodeInitialPassFailed,
+                                    @"Keychain helper signing failed");
+            return NO;
         }
+
+        NSString *groupsCSV = [selectedGroups componentsJoinedByString:@","];
+        CommandResult *wipeResult = [runner runExecutableAndCapture:workingHelper
+                                                           arguments:@[
+                                                               @"--action", @"wipe",
+                                                               @"--groups", groupsCSV
+                                                           ]
+                                                          timeoutSec:120.0
+                                                      maxOutputBytes:1024 * 1024];
+        success = PXBoundedCommandSucceeded(wipeResult);
+        NSDictionary *diagnostic = @{
+            @"success": @(success),
+            @"exitCode": @(wipeResult ? wipeResult.exitCode : -1),
+            @"timedOut": @(wipeResult ? wipeResult.timedOut : NO),
+            @"stdoutTruncated": @(wipeResult ? wipeResult.stdoutTruncated : NO),
+            @"stderrTruncated": @(wipeResult ? wipeResult.stderrTruncated : NO),
+            @"groupCount": @(selectedGroups.count),
+        };
+        [[NSUserDefaults standardUserDefaults] setObject:diagnostic
+                                                  forKey:[NSString stringWithFormat:@"DataCleaningKeychainResult_%@",
+                                                                                     bundleIdentifier]];
+        [[NSUserDefaults standardUserDefaults] synchronize];
+        if (!success) {
+            PXAssignKeychainNSError(error,
+                                    PXKeychainClearFailureCodeInitialPassFailed,
+                                    @"Keychain helper execution failed");
+        }
+        return success;
+    } @catch (__unused NSException *exception) {
+        PXAssignKeychainNSError(error,
+                                PXKeychainClearFailureCodeInternalResultFailure,
+                                @"Keychain helper execution failed");
         return NO;
+    } @finally {
+        [fileManager removeItemAtPath:workingHelper error:nil];
+        [fileManager removeItemAtPath:entitlementsPath error:nil];
+        [fileManager removeItemAtPath:temporaryDirectory error:nil];
+    }
+}
+
+- (PXClearComponentResult *)_keychainComponentForPlan:(PXKeychainClearPlan *)plan
+                                          passResults:(NSArray<NSNumber *> *)passResults {
+    if (![plan isKindOfClass:[PXKeychainClearPlan class]] ||
+        ![passResults isKindOfClass:[NSArray class]]) {
+        PXClearFailure *failure = PXKeychainFailure(PXKeychainClearFailureCodeInternalResultFailure,
+                                                    @"Keychain result construction failed");
+        return [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
+                                                     status:PXClearComponentStatusFailed
+                                         attemptedUnitCount:1
+                                         succeededUnitCount:0
+                                            failedUnitCount:1
+                                                     detail:PXKeychainFailureDetail
+                                                    failure:failure];
+    }
+    if (plan.planningFailureCode != 0) {
+        PXClearFailure *failure = PXKeychainFailure((PXKeychainClearFailureCode)plan.planningFailureCode,
+                                                    plan.planningFailureMessage ?: @"Keychain planning failed");
+        PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
+                                                                                status:PXClearComponentStatusFailed
+                                                                    attemptedUnitCount:1
+                                                                    succeededUnitCount:0
+                                                                       failedUnitCount:1
+                                                                                detail:PXKeychainFailureDetail
+                                                                               failure:failure];
+        return PXKeychainComponentResultIsStructurallyValid(result) ? result : nil;
+    }
+    if (plan.skipDetail.length) {
+        PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
+                                                                                status:PXClearComponentStatusSkipped
+                                                                    attemptedUnitCount:0
+                                                                    succeededUnitCount:0
+                                                                       failedUnitCount:0
+                                                                                detail:plan.skipDetail
+                                                                               failure:nil];
+        return PXKeychainComponentResultIsStructurallyValid(result) ? result : nil;
+    }
+    if ((plan.plannedPassCount != 1 && plan.plannedPassCount != 2) ||
+        passResults.count != plan.plannedPassCount) {
+        PXClearFailure *failure = PXKeychainFailure(PXKeychainClearFailureCodeInternalResultFailure,
+                                                    @"Keychain execution accounting is incomplete");
+        PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
+                                                                                status:PXClearComponentStatusFailed
+                                                                    attemptedUnitCount:1
+                                                                    succeededUnitCount:0
+                                                                       failedUnitCount:1
+                                                                                detail:PXKeychainFailureDetail
+                                                                               failure:failure];
+        return PXKeychainComponentResultIsStructurallyValid(result) ? result : nil;
+    }
+
+    NSUInteger succeeded = 0;
+    PXClearFailure *firstFailure = nil;
+    for (NSUInteger index = 0; index < passResults.count; index++) {
+        BOOL passSucceeded = [passResults[index] respondsToSelector:@selector(boolValue)] &&
+                             [passResults[index] boolValue];
+        if (passSucceeded) {
+            succeeded++;
+        } else if (!firstFailure) {
+            PXKeychainClearFailureCode code = index == 0
+                ? PXKeychainClearFailureCodeInitialPassFailed
+                : PXKeychainClearFailureCodeFinalPassFailed;
+            firstFailure = PXKeychainFailure(code,
+                index == 0 ? @"Initial keychain wipe pass failed" : @"Final keychain wipe pass failed");
+        }
+    }
+    NSUInteger failed = plan.plannedPassCount - succeeded;
+    PXClearComponentResult *result = [[PXClearComponentResult alloc]
+        initWithScope:PXClearScopeKeychain
+               status:(failed == 0 ? PXClearComponentStatusSucceeded : PXClearComponentStatusFailed)
+   attemptedUnitCount:plan.plannedPassCount
+   succeededUnitCount:succeeded
+      failedUnitCount:failed
+               detail:(failed == 0 ? PXKeychainSuccessDetail : PXKeychainFailureDetail)
+              failure:firstFailure];
+    if (!PXKeychainComponentResultIsStructurallyValid(result)) {
+        PXClearFailure *failure = PXKeychainFailure(PXKeychainClearFailureCodeInternalResultFailure,
+                                                    @"Keychain result construction failed");
+        return [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
+                                                     status:PXClearComponentStatusFailed
+                                         attemptedUnitCount:1
+                                         succeededUnitCount:0
+                                            failedUnitCount:1
+                                                     detail:PXKeychainFailureDetail
+                                                    failure:failure];
     }
+    return result;
+}

-    NSString *groupsCSV = [groups componentsJoinedByString:@","];
-    NSString *wipeCmd = [NSString stringWithFormat:@"%@ --action wipe --groups %@",
-                         PXShellQuote(workingHelper),
-                         PXShellQuote(groupsCSV)];
-    [self logMessage:@"[AppDataCleaner] Keychain wipe via helper for %@ (groups=%lu)", bundleID, (unsigned long)groups.count];
-    CommandResult *wipeRes = [runner runAndCapture:wipeCmd];
-
-    NSDictionary *report = @{
-        @"bundleID": bundleID,
-        @"groups": groups,
-        @"exitCode": @(wipeRes.exitCode),
-        @"stdout": wipeRes.stdoutString ?: @"",
-        @"stderr": wipeRes.stderrString ?: @"",
-    };
-    [[NSUserDefaults standardUserDefaults] setObject:report forKey:[NSString stringWithFormat:@"DataCleaningKeychainResult_%@", bundleID]];
-    [[NSUserDefaults standardUserDefaults] synchronize];
-
-    if (wipeRes.exitCode != 0) {
-        if (error) {
-            NSString *msg = wipeRes.stderrString.length ? wipeRes.stderrString : @"Keychain wipe failed";
-            *error = [NSError errorWithDomain:@"AppDataCleaner"
-                                         code:108
-                                     userInfo:@{NSLocalizedDescriptionKey: msg}];
-        }
+- (BOOL)_wipeSelectedKeychainForBundleID:(NSString *)bundleID
+                                   error:(NSError **)error {
+    if (error) *error = nil;
+    PXKeychainClearPlan *plan = [self _keychainClearPlanForBundleIdentifier:bundleID];
+    if (![plan isKindOfClass:[PXKeychainClearPlan class]]) {
+        PXAssignKeychainNSError(error,
+                                PXKeychainClearFailureCodeInternalResultFailure,
+                                @"Keychain plan construction failed");
         return NO;
     }
-
-    return YES;
+    if (plan.skipDetail.length) return YES;
+    if (plan.planningFailureCode != 0) {
+        PXAssignKeychainNSError(error,
+                                (PXKeychainClearFailureCode)plan.planningFailureCode,
+                                plan.planningFailureMessage ?: @"Keychain planning failed");
+        return NO;
+    }
+    return [self _executeKeychainWipeForBundleIdentifier:plan.bundleIdentifier
+                                          selectedGroups:plan.selectedGroups
+                                   applicationIdentifier:plan.applicationIdentifier
+                                      systemApplication:plan.systemApplication
+                                                  error:error];
 }

 #pragma mark - Exact Installed Extension Discovery
@@ -2326,7 +2877,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                                  appGroupsResult,
                                  pluginKitResult
                              ]];
-    return PXMigratedClearResultIsStructurallyValid(aggregate) ? aggregate : nil;
+    return PXMigratedDataClearResultIsStructurallyValid(aggregate) ? aggregate : nil;
 }

 #pragma mark - Main Public Methods
@@ -2335,60 +2886,46 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     [self logMessage:@"[AppDataCleaner] === STARTING data clearing for %@ ===", bundleID];

     BOOL deepClean = [self _deepCleanEnabled];
-    PXClearRequest *migratedRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
-                                                                                scopes:PXMigratedDataClearScopes
-                                                                             deepClean:deepClean];
-    if (!migratedRequest) {
-        NSError *requestError = PXMigratedInternalError(@"Invalid migrated data-clear request");
+    PXClearRequest *fullRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
+                                                                            scopes:PXMigratedFullClearScopes
+                                                                         deepClean:deepClean];
+    PXClearRequest *dataRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
+                                                                            scopes:PXMigratedDataClearScopes
+                                                                         deepClean:deepClean];
+    if (!fullRequest || !dataRequest) {
+        NSError *requestError = PXMigratedInternalError(@"Invalid full Clear request");
         dispatch_async(dispatch_get_main_queue(), ^{
             if (completion) completion(NO, requestError);
         });
         return;
     }
-
-    // Use __block to track if completion was called
+
     __block BOOL completionCalled = NO;
     __block dispatch_semaphore_t completionLock = dispatch_semaphore_create(1);
-
-    // Freeze/unfreeze around destructive wipes to prevent relaunch mid-clean.
     FreezeManager *freezer = [FreezeManager sharedManager];
     __block BOOL wasFrozen = [freezer isApplicationFrozen:bundleID];
     __block BOOL frozeForThisClear = NO;
-
-    // Capture self for logging in blocks
     __weak typeof(self) weakSelf = self;
-
-    // Keep ProjectX running even if another app is launched (e.g., system keychain wipe via bridge).
     __block UIBackgroundTaskIdentifier bgTask = UIBackgroundTaskInvalid;
     dispatch_async(dispatch_get_main_queue(), ^{
-        bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"AppDataCleaner" expirationHandler:^{
-            // Best-effort: allow watchdog to handle timeout.
-        }];
+        bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"AppDataCleaner"
+                                                              expirationHandler:^{}];
     });
-
-    // Cancelable watchdog (avoid false timeout after success)
     __block dispatch_source_t watchdogTimer = nil;
-
-    // Helper block to safely call completion only once
+
     void (^safeCompletion)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
         dispatch_semaphore_wait(completionLock, DISPATCH_TIME_FOREVER);
         if (!completionCalled) {
             completionCalled = YES;
             dispatch_semaphore_signal(completionLock);
-
-            // Unfreeze only if we froze it in this operation.
             if (frozeForThisClear) {
-                @try {
-                    [freezer unfreezeApplication:bundleID];
-                } @catch (__unused NSException *e) {
-                }
+                @try { [freezer unfreezeApplication:bundleID]; }
+                @catch (__unused NSException *exception) {}
             }
-
             if (watchdogTimer) {
                 dispatch_source_cancel(watchdogTimer);
                 watchdogTimer = nil;
             }
-
             if (bgTask != UIBackgroundTaskInvalid) {
                 UIBackgroundTaskIdentifier taskToEnd = bgTask;
                 bgTask = UIBackgroundTaskInvalid;
@@ -2396,12 +2933,9 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                     [[UIApplication sharedApplication] endBackgroundTask:taskToEnd];
                 });
             }
-
             [weakSelf logMessage:@"[AppDataCleaner] Calling completion handler (success=%d)", success];
             dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) {
-                    completion(success, error);
-                }
+                if (completion) completion(success, error);
             });
         } else {
             dispatch_semaphore_signal(completionLock);
@@ -2409,173 +2943,198 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     };

     BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
-    // Deep Clean and system apps can legitimately take a long time.
-    // Avoid failing early while still making progress.
     int timeoutSec = (deepClean || isSystemApp) ? (30 * 60) : 120;
-
-    // Run watchdog on a global queue so it isn't delayed by UI activity.
-    watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
-    dispatch_source_set_timer(watchdogTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeoutSec * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 1 * NSEC_PER_SEC);
+    watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
+        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
+    dispatch_source_set_timer(watchdogTimer,
+                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeoutSec * NSEC_PER_SEC),
+                              DISPATCH_TIME_FOREVER,
+                              1 * NSEC_PER_SEC);
     dispatch_source_set_event_handler(watchdogTimer, ^{
         dispatch_semaphore_wait(completionLock, DISPATCH_TIME_FOREVER);
         BOOL alreadyCompleted = completionCalled;
         dispatch_semaphore_signal(completionLock);
-        if (alreadyCompleted) {
-            return;
-        }
+        if (alreadyCompleted) return;
         [weakSelf logMessage:@"[AppDataCleaner] WATCHDOG: %d second timeout reached", timeoutSec];
-        NSError *timeoutError = [NSError errorWithDomain:@"AppDataCleaner"
-                                                   code:-100
-                                               userInfo:@{NSLocalizedDescriptionKey: @"Clear Data timed out"}];
-        safeCompletion(NO, timeoutError);
+        safeCompletion(NO, [NSError errorWithDomain:@"AppDataCleaner"
+                                               code:-100
+                                           userInfo:@{NSLocalizedDescriptionKey: @"Clear Data timed out"}]);
     });
     dispatch_resume(watchdogTimer);
-
-    // Dispatch the cleaning process to background queue
+
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
         @autoreleasepool {
             __strong typeof(weakSelf) strongSelf = weakSelf;
             [strongSelf logMessage:@"[AppDataCleaner] Background cleaning started for %@", bundleID];
-
             @try {
-                 // Step 0: Force Kill Application to release file locks
-                 [strongSelf logMessage:@"[AppDataCleaner] Step 0: Kill application..."];
-
+                [strongSelf logMessage:@"[AppDataCleaner] Step 0: Kill application..."];
                 [strongSelf logMessage:@"[AppDataCleaner] Deep Clean (verify scan) = %@", deepClean ? @"ON" : @"OFF"];
-
-                // Kill by executable name (no shell) to release file locks.
                 PXKillAppProcessBestEffort(strongSelf, bundleID);
+                [NSThread sleepForTimeInterval:0.5];
+                if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
+                    [strongSelf logMessage:@"[AppDataCleaner] MobileSafari: stopping WebKit/Safari helper processes..."];
+                    PXStopSafariDaemonsBestEffort(strongSelf);
+                }
+
+                [strongSelf logMessage:@"[AppDataCleaner] Step 1: Planning and running initial Keychain pass..."];
+                PXKeychainClearPlan *keychainPlan =
+                    [strongSelf _keychainClearPlanForBundleIdentifier:fullRequest.bundleIdentifier];
+                NSMutableArray<NSNumber *> *keychainPassResults = [NSMutableArray array];
+                if (keychainPlan.planningFailureCode == 0 &&
+                    keychainPlan.skipDetail.length == 0 &&
+                    keychainPlan.plannedPassCount > 0) {
+                    NSError *initialPassError = nil;
+                    BOOL initialPassSucceeded = [strongSelf
+                        _executeKeychainWipeForBundleIdentifier:keychainPlan.bundleIdentifier
+                                                selectedGroups:keychainPlan.selectedGroups
+                                         applicationIdentifier:keychainPlan.applicationIdentifier
+                                            systemApplication:keychainPlan.systemApplication
+                                                        error:&initialPassError];
+                    [keychainPassResults addObject:@(initialPassSucceeded)];
+                    if (!initialPassSucceeded) {
+                        [strongSelf logMessage:@"[AppDataCleaner] Initial Keychain pass failed (%@:%ld)",
+                            initialPassError.domain ?: PXKeychainClearFailureDomain,
+                            (long)initialPassError.code];
+                    }
+                }

-                [NSThread sleepForTimeInterval:0.5]; // Wait for process to die
-
-                 // Safari: also stop WebKit helper processes to fully release cookie/session DBs.
-                 if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
-                     [strongSelf logMessage:@"[AppDataCleaner] MobileSafari: stopping WebKit/Safari helper processes..."];
-                     PXStopSafariDaemonsBestEffort(strongSelf);
-                 }
-
-                 // Step 1: Clear keychain FIRST (most important for login data)
-                 [strongSelf logMessage:@"[AppDataCleaner] Step 1: Clearing keychain (selected groups)..."];
-                NSError *keychainError1 = nil;
-                BOOL keychainOK1 = [strongSelf _wipeSelectedKeychainForBundleID:bundleID error:&keychainError1];
-
-                // Step 2: Clear URL credentials (session tokens)
                 [strongSelf logMessage:@"[AppDataCleaner] Step 2: Clearing URL credentials..."];
                 [strongSelf clearURLCredentialsForBundleID:bundleID];
-
-                // Step 3: Clear app state data (login sessions)
                 [strongSelf logMessage:@"[AppDataCleaner] Step 3: Clearing app state data..."];
                 [strongSelf _internalClearAppStateData:bundleID];

-                 // Freeze now (after any in-app keychain bridge launch) to prevent relaunch mid-wipe.
-                 if (!wasFrozen) {
-                     [strongSelf logMessage:@"[AppDataCleaner] Freezing app launch to prevent relaunch during wipe..."];
-                     @try {
-                         [freezer freezeApplication:bundleID];
-                     } @catch (__unused NSException *e) {
-                     }
-                     frozeForThisClear = [freezer isApplicationFrozen:bundleID];
-                 }
-
-                 // Step 4: Run and consume the exact four-scope migrated aggregate.
-                 [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running migrated ApplicationData/ExtensionData/AppGroups/PluginKitData clear..."];
-                 PXClearResult *migratedResult =
-                     [strongSelf _completeDataWipeForMigratedRequest:migratedRequest];
-                 NSError *migratedClearError = nil;
-                 if (!PXMigratedClearResultIsStructurallyValid(migratedResult)) {
-                     migratedClearError = PXMigratedInternalError(@"Migrated data clear returned an invalid aggregate result");
-                     [strongSelf logMessage:@"[AppDataCleaner] Migrated aggregate is nil, incomplete, or structurally invalid"];
-                 } else {
-                     NSArray<NSNumber *> *failurePrecedence = @[
-                         @(PXClearScopeApplicationData),
-                         @(PXClearScopeExtensionData),
-                         @(PXClearScopeAppGroups),
-                         @(PXClearScopePluginKitData)
-                     ];
-                     for (NSNumber *scopeNumber in failurePrecedence) {
-                         PXClearScope scope = (PXClearScope)scopeNumber.unsignedIntegerValue;
-                         PXClearComponentResult *component = [migratedResult componentResultForScope:scope];
-                         NSString *componentName = PXMigratedComponentName(scope);
-                         [strongSelf logMessage:@"[AppDataCleaner] %@ result %@ attempted=%lu succeeded=%lu failed=%lu",
-                               componentName,
-                               PXApplicationDataStatusName(component.status),
-                               (unsigned long)component.attemptedUnitCount,
-                               (unsigned long)component.succeededUnitCount,
-                               (unsigned long)component.failedUnitCount];
-                         if (component.status == PXClearComponentStatusFailed) {
-                             NSError *componentError = PXMigratedNSErrorForFailure(component.failure);
-                             [strongSelf logMessage:@"[AppDataCleaner] %@ failed (%@:%ld)",
-                                   componentName,
-                                   componentError.domain,
-                                   (long)componentError.code];
-                             if (!migratedClearError) {
-                                 migratedClearError = componentError;
-                             }
-                         }
-                     }
-                 }
-
-                // Step 5: Clear HTTP cookie storage in memory
+                if (!wasFrozen) {
+                    [strongSelf logMessage:@"[AppDataCleaner] Freezing app launch to prevent relaunch during wipe..."];
+                    @try { [freezer freezeApplication:bundleID]; }
+                    @catch (__unused NSException *exception) {}
+                    frozeForThisClear = [freezer isApplicationFrozen:bundleID];
+                }
+
+                [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running four-scope data aggregate..."];
+                PXClearResult *dataResult = [strongSelf _completeDataWipeForMigratedRequest:dataRequest];
+                NSArray<PXClearComponentResult *> *dataComponents = nil;
+                if (PXMigratedDataClearResultIsStructurallyValid(dataResult)) {
+                    dataComponents = dataResult.componentResults;
+                } else {
+                    [strongSelf logMessage:@"[AppDataCleaner] Four-scope data aggregate is structurally invalid"];
+                    dataComponents = @[
+                        PXApplicationDataFailedComponent(
+                            PXApplicationDataClearFailureCodeInternalResultFailure,
+                            @"ApplicationData aggregate result was invalid"),
+                        PXExactDataFailedComponent(
+                            PXClearScopeExtensionData,
+                            PXExactDataClearFailureCodeInternalResultFailure,
+                            @"ExtensionData aggregate result was invalid"),
+                        PXAppGroupsFailedComponent(
+                            PXAppGroupsClearFailureCodeInternalResultFailure,
+                            @"AppGroups aggregate result was invalid"),
+                        PXExactDataFailedComponent(
+                            PXClearScopePluginKitData,
+                            PXExactDataClearFailureCodeInternalResultFailure,
+                            @"PluginKitData aggregate result was invalid")
+                    ];
+                }
+
                 [strongSelf logMessage:@"[AppDataCleaner] Step 5: Clearing HTTP cookies from memory..."];
                 NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                 NSArray *allCookies = [[cookieStorage cookies] copy];
-                for (NSHTTPCookie *cookie in allCookies) {
-                    [cookieStorage deleteCookie:cookie];
+                for (NSHTTPCookie *cookie in allCookies) [cookieStorage deleteCookie:cookie];
+                [strongSelf logMessage:@"[AppDataCleaner] Cleared %lu cookies from memory",
+                    (unsigned long)allCookies.count];
+
+                [strongSelf logMessage:@"[AppDataCleaner] Step 6: Running planned final Keychain pass..."];
+                if (keychainPlan.planningFailureCode == 0 &&
+                    keychainPlan.skipDetail.length == 0 &&
+                    keychainPlan.plannedPassCount == 2) {
+                    NSError *finalPassError = nil;
+                    BOOL finalPassSucceeded = [strongSelf
+                        _executeKeychainWipeForBundleIdentifier:keychainPlan.bundleIdentifier
+                                                selectedGroups:keychainPlan.selectedGroups
+                                         applicationIdentifier:keychainPlan.applicationIdentifier
+                                            systemApplication:keychainPlan.systemApplication
+                                                        error:&finalPassError];
+                    [keychainPassResults addObject:@(finalPassSucceeded)];
+                    if (!finalPassSucceeded) {
+                        [strongSelf logMessage:@"[AppDataCleaner] Final Keychain pass failed (%@:%ld)",
+                            finalPassError.domain ?: PXKeychainClearFailureDomain,
+                            (long)finalPassError.code];
+                    }
                 }
-                [strongSelf logMessage:@"[AppDataCleaner] Cleared %lu cookies from memory", (unsigned long)allCookies.count];
-
-                // Step 6: Clear keychain AGAIN to catch any recreated items
-                [strongSelf logMessage:@"[AppDataCleaner] Step 6: Final keychain cleanup (selected groups)..."];
-                NSError *keychainError2 = nil;
-                BOOL keychainOK2 = YES;
-                // System keychain wipe requires launching the app; do it once per run to avoid long UX.
-                if ([bundleID hasPrefix:@"com.apple."]) {
-                    [strongSelf logMessage:@"[AppDataCleaner] Skipping second keychain wipe for system app %@", bundleID];
-                } else {
-                    keychainOK2 = [strongSelf _wipeSelectedKeychainForBundleID:bundleID error:&keychainError2];
+
+                PXClearComponentResult *keychainComponent =
+                    [strongSelf _keychainComponentForPlan:keychainPlan passResults:keychainPassResults];
+                if (!PXKeychainComponentResultIsStructurallyValid(keychainComponent)) {
+                    PXClearFailure *failure = PXKeychainFailure(
+                        PXKeychainClearFailureCodeInternalResultFailure,
+                        @"Keychain component result was invalid");
+                    keychainComponent = [[PXClearComponentResult alloc]
+                        initWithScope:PXClearScopeKeychain
+                               status:PXClearComponentStatusFailed
+                   attemptedUnitCount:1
+                   succeededUnitCount:0
+                      failedUnitCount:1
+                               detail:PXKeychainFailureDetail
+                              failure:failure];
                 }
-
-                // Step 7: Sync filesystem
+
                 [strongSelf logMessage:@"[AppDataCleaner] Step 7: Syncing filesystem..."];
                 sync();
-
-                // Step 8: Verification is log-only for now; the existing verifier is intentionally broad
-                // and can report system-created directories that do not indicate account leakage.
                 [strongSelf logMessage:@"[AppDataCleaner] Step 8: Verifying clear result (log-only)..."];
                 BOOL clearVerified = [strongSelf verifyDataCleared:bundleID];
                 if (!clearVerified) {
-                    [strongSelf logMessage:@"[AppDataCleaner] WARNING: Clear verification found residual data; review log before switching accounts"];
+                    [strongSelf logMessage:@"[AppDataCleaner] WARNING: broad verification found residual data"];
                 }
-
-                [strongSelf logMessage:@"[AppDataCleaner] === COMPLETED data clearing for %@ ===", bundleID];
-                BOOL keychainFailed = !keychainOK1 || !keychainOK2;
-                NSError *keychainError = keychainError2 ?: keychainError1;
-                if (keychainFailed) {
-                    [strongSelf logMessage:@"[AppDataCleaner] Keychain failed: %@",
-                          keychainError.localizedDescription ?: @"unknown keychain error"];
+
+                NSMutableArray<PXClearComponentResult *> *fullComponents =
+                    [NSMutableArray arrayWithArray:dataComponents ?: @[]];
+                [fullComponents addObject:keychainComponent];
+                PXClearResult *fullResult = [[PXClearResult alloc] initWithRequest:fullRequest
+                                                                  componentResults:fullComponents];
+                if (!PXMigratedFullClearResultIsStructurallyValid(fullResult)) {
+                    [strongSelf logMessage:@"[AppDataCleaner] Final five-scope aggregate is structurally invalid"];
+                    safeCompletion(NO, PXMigratedInternalError(@"Full Clear returned an invalid aggregate result"));
+                    return;
                 }
-                if (migratedClearError) {
-                    if (keychainFailed) {
-                        [strongSelf logMessage:@"[AppDataCleaner] Migrated component failure has callback precedence over Keychain"];
+
+                NSError *callbackError = nil;
+                NSArray<NSNumber *> *failurePrecedence = @[
+                    @(PXClearScopeApplicationData),
+                    @(PXClearScopeExtensionData),
+                    @(PXClearScopeAppGroups),
+                    @(PXClearScopePluginKitData),
+                    @(PXClearScopeKeychain)
+                ];
+                for (NSNumber *scopeNumber in failurePrecedence) {
+                    PXClearScope scope = (PXClearScope)scopeNumber.unsignedIntegerValue;
+                    PXClearComponentResult *component = [fullResult componentResultForScope:scope];
+                    [strongSelf logMessage:@"[AppDataCleaner] %@ result %@ attempted=%lu succeeded=%lu failed=%lu",
+                        PXMigratedComponentName(scope),
+                        PXApplicationDataStatusName(component.status),
+                        (unsigned long)component.attemptedUnitCount,
+                        (unsigned long)component.succeededUnitCount,
+                        (unsigned long)component.failedUnitCount];
+                    if (component.status == PXClearComponentStatusFailed) {
+                        NSError *componentError = PXMigratedNSErrorForFailure(component.failure);
+                        [strongSelf logMessage:@"[AppDataCleaner] %@ failed (%@:%ld)",
+                            PXMigratedComponentName(scope),
+                            componentError.domain,
+                            (long)componentError.code];
+                        if (!callbackError) callbackError = componentError;
                     }
-                    safeCompletion(NO, migratedClearError);
-                } else if (keychainFailed) {
-                    safeCompletion(NO, keychainError ?: [NSError errorWithDomain:@"AppDataCleaner"
-                                                                            code:-2
-                                                                        userInfo:@{NSLocalizedDescriptionKey: @"Keychain wipe failed"}]);
-                } else {
-                    safeCompletion(YES, nil);
                 }
-
+
+                [strongSelf logMessage:@"[AppDataCleaner] === COMPLETED data clearing for %@ ===", bundleID];
+                safeCompletion(callbackError == nil, callbackError);
             } @catch (NSException *exception) {
                 [strongSelf logMessage:@"[AppDataCleaner] EXCEPTION: %@", exception];
-                safeCompletion(NO, [NSError errorWithDomain:@"AppDataCleaner"
-                                                      code:-1
-                                                  userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown error"}]);
+                safeCompletion(NO, [NSError errorWithDomain:@"AppDataCleaner"
+                                                      code:-1
+                                                  userInfo:@{NSLocalizedDescriptionKey:
+                                                                 exception.reason ?: @"Unknown error"}]);
             }
         }
     });
-
+
     [self logMessage:@"[AppDataCleaner] clearDataForBundleID returned immediately"];
 }

@@ -2587,7 +3146,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                                                                         scopes:PXMigratedDataClearScopes
                                                                      deepClean:deepClean];
     PXClearResult *result = request ? [self _completeDataWipeForMigratedRequest:request] : nil;
-    if (!PXMigratedClearResultIsStructurallyValid(result)) {
+    if (!PXMigratedDataClearResultIsStructurallyValid(result)) {
         [self logMessage:@"[AppDataCleaner] completeAppDataWipe produced an invalid migrated aggregate"];
         return;
     }
diff --git a/KeychainGroupsViewController.m b/KeychainGroupsViewController.m
index 540241b..bda83a8 100644
--- a/KeychainGroupsViewController.m
+++ b/KeychainGroupsViewController.m
@@ -111,12 +111,17 @@ static NSString * const PXKeychainGroupsSavedNotification = @"com.hydra.projectx
     NSError *err = nil;
     AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
     NSArray<NSString *> *groups = [reader keychainAccessGroupsForBundleID:self.bundleID error:&err];
+    id savedObject = [self.defaults objectForKey:PXKeychainWipeGroupsKey(self.bundleID)];
     if (!groups.count) {
         self.groups = @[];
         self.filteredGroups = self.groups;
         [self.selected removeAllObjects];
-        self.footerLabel.text = err ? [NSString stringWithFormat:@"Failed to read entitlements: %@", err.localizedDescription]
-                               : @"No keychain-access-groups found for this app.";
+        if (savedObject != nil && ![savedObject isKindOfClass:[NSArray class]]) {
+            self.footerLabel.text = @"Saved Keychain group selection is invalid. Select groups and save again.";
+        } else {
+            self.footerLabel.text = err ? [NSString stringWithFormat:@"Failed to read entitlements: %@", err.localizedDescription]
+                                   : @"No keychain-access-groups found for this app.";
+        }
         self.navigationItem.rightBarButtonItem.enabled = NO;
         [self.tableView reloadData];
         return;
@@ -126,16 +131,19 @@ static NSString * const PXKeychainGroupsSavedNotification = @"com.hydra.projectx
     self.filteredGroups = self.groups;
     self.navigationItem.rightBarButtonItem.enabled = YES;

-    // Default selection: ALL groups.
-    NSArray *saved = [self.defaults objectForKey:PXKeychainWipeGroupsKey(self.bundleID)];
-    if ([saved isKindOfClass:[NSArray class]] && [(NSArray *)saved count] > 0) {
-        for (id v in (NSArray *)saved) {
-            if ([v isKindOfClass:[NSString class]]) {
-                [self.selected addObject:(NSString *)v];
+    [self.selected removeAllObjects];
+    if (savedObject == nil) {
+        [self.selected addObjectsFromArray:self.groups];
+    } else if ([savedObject isKindOfClass:[NSArray class]]) {
+        NSSet<NSString *> *currentGroupSet = [NSSet setWithArray:self.groups];
+        for (id value in (NSArray *)savedObject) {
+            if ([value isKindOfClass:[NSString class]] &&
+                [currentGroupSet containsObject:(NSString *)value]) {
+                [self.selected addObject:(NSString *)value];
             }
         }
     } else {
-        [self.selected addObjectsFromArray:self.groups];
+        self.footerLabel.text = @"Saved Keychain group selection is invalid. Select groups and save again.";
     }
     [self.tableView reloadData];
 }
diff --git a/KeychainHelper/backup_helper.m b/KeychainHelper/backup_helper.m
index ba164a1..234684d 100644
--- a/KeychainHelper/backup_helper.m
+++ b/KeychainHelper/backup_helper.m
@@ -248,18 +248,32 @@ int main(int argc, const char *argv[]) {
                                                                itemClasses:PXKeychainItemClassAll
                                                                      error:&error];

+                NSUInteger processed = result ? result.itemsProcessed : 0;
+                NSUInteger succeeded = result ? result.itemsSucceeded : 0;
+                NSUInteger failed = result ? result.itemsFailed : 0;
+                NSUInteger warningCount = result ? result.warnings.count : 0;
+                fprintf(stdout,
+                        "PXKEYCHAIN_WIPE_RESULT processed=%lu succeeded=%lu failed=%lu warnings=%lu\n",
+                        (unsigned long)processed,
+                        (unsigned long)succeeded,
+                        (unsigned long)failed,
+                        (unsigned long)warningCount);
+
                 if (!result) {
                     logError(@"Wipe failed: %@", error.localizedDescription);
                     return 2;
                 }
-
-                logSuccess(@"Wipe complete: %lu items deleted",
-                          (unsigned long)result.itemsSucceeded);
-
+
                 for (id warningObj in result.warnings) {
                     NSString *warning = PXSafeString(warningObj);
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
+                if (result.itemsFailed > 0 || result.warnings.count > 0) {
+                    return 2;
+                }
+
+                logSuccess(@"Wipe complete: %lu items deleted",
+                          (unsigned long)result.itemsSucceeded);
                 break;
             }

diff --git a/ProjectXViewController.m b/ProjectXViewController.m
index 38c11a6..48d970a 100644
--- a/ProjectXViewController.m
+++ b/ProjectXViewController.m
@@ -3837,27 +3837,22 @@ static void PXWriteSubstrateFilterPlists(void) {
         keychainEnabled = [defaults boolForKey:enabledKey];
     }

-    NSArray<NSString *> *selectedGroups = nil;
+    NSArray<NSString *> *selectedGroups = @[];
     id savedGroups = [defaults objectForKey:groupsKey];
-    if ([savedGroups isKindOfClass:[NSArray class]]) {
-        selectedGroups = (NSArray<NSString *> *)savedGroups;
-    }
-
-    // Default: select ALL groups from entitlements if not present.
-    if (!selectedGroups.count) {
+    if (savedGroups == nil) {
         NSError *err = nil;
         AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
-        NSArray<NSString *> *entGroups = [reader keychainAccessGroupsForBundleID:bundleID error:&err];
-        if (entGroups.count > 0) {
-            selectedGroups = entGroups;
-            [defaults setObject:entGroups forKey:groupsKey];
-            // Do not auto-enable keychain wipe.
-            [defaults setBool:NO forKey:enabledKey];
+        NSArray<NSString *> *entitlementGroups =
+            [reader keychainAccessGroupsForBundleID:bundleID error:&err];
+        selectedGroups = entitlementGroups.count > 0 ? entitlementGroups : @[];
+        if (entitlementGroups.count > 0) {
+            [defaults setObject:entitlementGroups forKey:groupsKey];
             [defaults synchronize];
-            keychainEnabled = NO;
-        } else {
-            selectedGroups = @[];
         }
+    } else if ([savedGroups isKindOfClass:[NSArray class]]) {
+        selectedGroups = (NSArray<NSString *> *)savedGroups;
+    } else {
+        selectedGroups = @[];
     }

      if (isSystemApp && !allowSystemKeychainWipe) {
@@ -3868,7 +3863,9 @@ static void PXWriteSubstrateFilterPlists(void) {
      }

      NSString *keychainState = keychainEnabled ? @"ON" : ((isSystemApp && !allowSystemKeychainWipe) ? @"OFF (Not supported)" : @"OFF");
-     NSString *groupsLine = (isSystemApp && !allowSystemKeychainWipe) ? @"N/A" : (selectedGroups.count > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)selectedGroups.count] : @"Unavailable");
+     NSString *groupsLine = (isSystemApp && !allowSystemKeychainWipe)
+         ? @"N/A"
+         : [NSString stringWithFormat:@"%lu selected", (unsigned long)selectedGroups.count];

     NSString *msg = [NSString stringWithFormat:@"Are you sure you want to clear all data for this app? This will remove %@.%@\n\nKeychain Wipe: %@ (may log you out)\nKeychain Groups: %@\n\nThis action cannot be undone.",
                      dataSizeStr ?: @"", dataDetailsStr ?: @"", keychainState, groupsLine];
@@ -3892,7 +3889,8 @@ static void PXWriteSubstrateFilterPlists(void) {
         }];
         [alert addAction:toggleAction];

-        NSString *groupsTitle = selectedGroups.count > 0 ? [NSString stringWithFormat:@"Keychain Groups (%lu)…", (unsigned long)selectedGroups.count] : @"Keychain Groups…";
+        NSString *groupsTitle = [NSString stringWithFormat:@"Keychain Groups (%lu)…",
+                                   (unsigned long)selectedGroups.count];
         UIAlertAction *groupsAction = [UIAlertAction actionWithTitle:groupsTitle
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(__unused UIAlertAction *action) {
diff --git a/WeaponXKeychainBridge/Tweak.m b/WeaponXKeychainBridge/Tweak.m
index fb5e388..8aca47f 100644
--- a/WeaponXKeychainBridge/Tweak.m
+++ b/WeaponXKeychainBridge/Tweak.m
@@ -189,27 +189,73 @@ static NSSet<NSString *> *WXExcludedRestoreKeys(void) {
     return s;
 }

-static void WXWipe(NSArray<NSString *> *groups, NSString *logPath) {
+static BOOL WXWipeGroupIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    NSString *group = (NSString *)value;
+    if (group.length == 0 || [group rangeOfString:@","].location != NSNotFound) return NO;
+    unichar nulCharacter = 0;
+    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
+    if ([group rangeOfString:nulString].location != NSNotFound) return NO;
+    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    if ([group rangeOfCharacterFromSet:[whitespace invertedSet]].location == NSNotFound) return NO;
+    return [[group stringByTrimmingCharactersInSet:whitespace] isEqualToString:group];
+}
+
+static NSArray<NSString *> *WXValidatedWipeGroups(id value) {
+    if (![value isKindOfClass:[NSArray class]] || [(NSArray *)value count] == 0) return nil;
+    NSMutableArray<NSString *> *groups = [NSMutableArray array];
+    for (id group in (NSArray *)value) {
+        if (!WXWipeGroupIsValid(group)) return nil;
+        [groups addObject:(NSString *)group];
+    }
+    return [groups copy];
+}
+
+static NSDictionary *WXWipeResult(NSArray<NSString *> *groups, NSString *logPath) {
+    NSArray<NSString *> *validatedGroups = WXValidatedWipeGroups(groups);
+    if (!validatedGroups) {
+        return @{ @"ok": @NO,
+                  @"attempted": @0,
+                  @"succeeded": @0,
+                  @"failed": @0 };
+    }
+
     NSArray<NSString *> *classNames = @[ @"GenericPassword", @"InternetPassword" ];
-    for (NSString *group in groups) {
-        if (![group isKindOfClass:[NSString class]] || !group.length) continue;
+    NSUInteger attempted = 0;
+    NSUInteger succeeded = 0;
+    NSUInteger failed = 0;
+    for (NSString *group in validatedGroups) {
         for (NSString *className in classNames) {
             CFTypeRef secClass = WXSecClassFromName(className);
             if (!secClass) continue;
-            NSMutableDictionary *q = [@{
+            attempted++;
+            NSMutableDictionary *query = [@{
                 (__bridge id)kSecClass: (__bridge id)secClass,
                 (__bridge id)kSecAttrAccessGroup: group,
                 (__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,
             } mutableCopy];
             if (@available(iOS 9.0, *)) {
-                q[(__bridge id)kSecUseAuthenticationUI] = (__bridge id)kSecUseAuthenticationUIFail;
+                query[(__bridge id)kSecUseAuthenticationUI] = (__bridge id)kSecUseAuthenticationUIFail;
             }
-            OSStatus st = SecItemDelete((__bridge CFDictionaryRef)q);
-            if (st != errSecSuccess && st != errSecItemNotFound) {
-                WXAppendLog(logPath, [NSString stringWithFormat:@"wipe group=%@ class=%@ error=%@", group, className, WXSecError(st)]);
+            OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
+            if (status == errSecSuccess || status == errSecItemNotFound) {
+                succeeded++;
+            } else {
+                failed++;
+                WXAppendLog(logPath,
+                    [NSString stringWithFormat:@"wipe class=%@ status=%d", className, (int)status]);
             }
         }
     }
+    BOOL ok = attempted > 0 && failed == 0 && succeeded == attempted;
+    return @{ @"ok": @(ok),
+              @"attempted": @(attempted),
+              @"succeeded": @(succeeded),
+              @"failed": @(failed) };
+}
+
+static void WXWipe(NSArray<NSString *> *groups, NSString *logPath) {
+    (void)WXWipeResult(groups, logPath);
 }

 static NSDictionary *WXRestoreFromImport(NSDictionary *importPlist, NSArray<NSString *> *allowedGroups, BOOL overwrite, NSString *logPath) {
@@ -313,13 +359,15 @@ static void WXProcessRequestForCurrentApp(void) {
         NSString *action = req[@"action"];
         NSString *nonce = req[@"nonce"];
         NSString *reqBundle = req[@"bundleID"];
-        NSArray *groups = req[@"groups"];
+        id groupsObject = req[@"groups"];
+        NSArray *groups = [groupsObject isKindOfClass:[NSArray class]] ? groupsObject : @[];
         NSString *respPath = req[@"respPath"];
         NSString *logPath = req[@"logPath"];
+        BOOL responsePathWasValid = WXIsTmpPath(respPath);
+        BOOL logPathWasValid = WXIsTmpPath(logPath);

         if (![reqBundle isKindOfClass:[NSString class]] || ![reqBundle isEqualToString:bundleID]) return;
         if (![nonce isKindOfClass:[NSString class]] || !nonce.length) return;
-        if (![groups isKindOfClass:[NSArray class]]) groups = @[];
         if (![action isKindOfClass:[NSString class]]) action = @"";

         if (!WXIsTmpPath(respPath)) respPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_response_%@.plist", safe];
@@ -379,9 +427,20 @@ static void WXProcessRequestForCurrentApp(void) {
                 WXAppendLog(logPath, [NSString stringWithFormat:@"restore ok=%d", ok]);
             }
         } else if ([action isEqualToString:@"wipe"]) {
-            // Keychain wipe in app context (group-scoped)
-            WXWipe((NSArray *)groups, logPath);
-            resp[@"ok"] = @YES;
+            NSArray<NSString *> *validatedGroups = WXValidatedWipeGroups(groupsObject);
+            if (!responsePathWasValid || !logPathWasValid || !validatedGroups) {
+                resp[@"ok"] = @NO;
+                resp[@"attempted"] = @0;
+                resp[@"succeeded"] = @0;
+                resp[@"failed"] = @0;
+                resp[@"error"] = @"invalid wipe request";
+            } else {
+                NSDictionary *wipeResult = WXWipeResult(validatedGroups, logPath);
+                resp[@"ok"] = wipeResult[@"ok"] ?: @NO;
+                resp[@"attempted"] = wipeResult[@"attempted"] ?: @0;
+                resp[@"succeeded"] = wipeResult[@"succeeded"] ?: @0;
+                resp[@"failed"] = wipeResult[@"failed"] ?: @0;
+            }
         } else {
             resp[@"ok"] = @NO;
             resp[@"error"] = @"unknown action";
@@ -419,10 +478,6 @@ __attribute__((constructor)) static void WXKeychainBridgeInit(void) {
         NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
         PXFileDebugAIDA64Log("[KeychainBridge.ctor] bundle=%s", bundleID.UTF8String ?: "<nil>");
         if (!bundleID.length) return;
-        if ([bundleID hasPrefix:@"com.apple."]) {
-            PXFileDebugAIDA64Log("[KeychainBridge.ctor] skip system bundle=%s", bundleID.UTF8String ?: "<nil>");
-            return;
-        }
         NSString *safe = WXSafeBundle(bundleID);

         NSString *notifyName = [NSString stringWithFormat:@"com.hydra.weaponx.keychain.req.%@", safe];
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
