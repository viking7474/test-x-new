# TASK-1.10 — Integrate Keychain Clear Result Correctly

- Status: READY
- Phase: Phase 1 — Clear Data Safety Boundary
- Baseline commit: `0bb2e354715e00f20c4df95719e900ae5e8e1673`
- Required report: `docs/backup-restore-hardening/reports/TASK-1.10-REPORT.md`
- Suggested commit: `phase1(task-1.10): integrate keychain clear result`

## Objective

Make the existing selected-group Keychain wipe a truthful fifth `PXClearResult` component.

TASK-1.10 must replace the current two loose `BOOL` calls with one immutable request-scoped Keychain plan, explicit per-pass accounting and one final five-scope aggregate.

The task must also close two false-success paths:

1. the non-system helper currently exits zero when per-class deletion warnings exist;
2. the system-app bridge currently reports `ok = YES` even when `SecItemDelete` returns errors.

The task does not broaden Keychain ownership. Only exact selected access groups authorized by the target application's signed entitlements may be passed to the helper or bridge.

## Current problem

The main Clear flow currently performs:

```text
first _wipeSelectedKeychainForBundleID call
  -> four-scope data aggregate
  -> second _wipeSelectedKeychainForBundleID call
  -> separate BOOL/error callback decision
```

This is not a truthful component model because:

- disabled Keychain wipe and successful Keychain wipe both return `YES`;
- an empty saved selection is treated as “not configured” and silently replaced with all groups;
- settings and selected groups are read independently on each pass;
- the first pass can mutate defaults and change the meaning of the second pass;
- selected groups are not checked as an exact subset of signed authorized groups;
- non-system signing and helper execution use unbounded shell execution;
- helper warnings do not make the helper process fail;
- the system bridge ignores `SecItemDelete` errors;
- callback success is decided outside `PXClearResult`.

## Allowed production files

Only these production files may change:

```text
AppDataCleaner.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper/backup_helper.m
KeychainGroupsViewController.m
ProjectXViewController.m
```

The agent must create:

```text
docs/backup-restore-hardening/reports/TASK-1.10-REPORT.md
```

## Protected files

Do not modify:

```text
AppDataCleaner.h
AppEntitlementsReader.h
AppEntitlementsReader.m
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
PXClearRequest.h
PXClearRequest.m
PXClearResult.h
PXClearResult.m
CommandRunner.h
CommandRunner.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
AppDataBackupManager.h
AppDataBackupManager.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
Makefile
```

Do not modify Backup, Restore, application-bundle, data-container resolver, App Group resolver, UI layout or permission-helper behavior.

## Required baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
```

The expected HEAD is:

```text
0bb2e354715e00f20c4df95719e900ae5e8e1673
```

Record SHA-256 values for every protected file before and after implementation.

Coordinator-owned uncommitted documentation files may already exist. Do not stage, revert, rewrite or format them.

---

# Part 1 — Preserve the accepted four-scope data aggregate

Keep the existing data-only scope mask unchanged:

```objc
static const PXClearScope PXMigratedDataClearScopes =
    PXClearScopeApplicationData |
    PXClearScopeExtensionData |
    PXClearScopeAppGroups |
    PXClearScopePluginKitData;
```

`_completeDataWipeForMigratedRequest:` remains a four-scope data operation.

It must still accept exactly `PXMigratedDataClearScopes` and return exactly these four components in canonical order:

1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData

Do not add Keychain execution inside `_completeDataWipeForMigratedRequest:`.

Do not regress any accepted TASK-1.7 through TASK-1.9 resolver, validator, canonical-path, command, postcondition, cache or failure-precedence behavior.

## Compatibility selector remains data-only

Keep:

```objc
- (void)completeAppDataWipe:(NSString *)bundleID;
```

as a data-only compatibility operation.

It must continue to create the exact four-scope data request, run the four-scope data aggregate and log those four components.

Do not make `completeAppDataWipe:` wipe Keychain. Adding Keychain there would be a new public behavior change unrelated to the existing full Clear entry point.

---

# Part 2 — Add the exact five-scope full Clear mask

Add one private full-operation mask:

```objc
static const PXClearScope PXMigratedFullClearScopes =
    PXClearScopeApplicationData |
    PXClearScopeExtensionData |
    PXClearScopeAppGroups |
    PXClearScopePluginKitData |
    PXClearScopeKeychain;
```

Do not use `PXClearScopeDefaultMask`.

`clearDataForBundleID:completion:` must create one full `PXClearRequest` with:

```text
bundleIdentifier = exact bundleID
deepClean = captured once
scopes = PXMigratedFullClearScopes
```

The data operation must receive a derived four-scope `PXClearRequest` with the same exact bundle identifier and deep-clean value.

The full request remains the request stored in the final five-component `PXClearResult`.

## Structural validation

Use separate private structural validation for:

```text
four-scope data result
five-scope full result
```

The final full aggregate must contain exactly one component for every full-request scope, in canonical order:

1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData
5. Keychain

Reject nil, wrong request masks, missing components, duplicate components, wrong order or structurally invalid component results.

Do not add public result properties or modify `PXClearResult`.

---

# Part 3 — Capture one immutable Keychain plan

Create one private request-scoped Keychain plan before the first wipe pass.

The exact private representation may be a private immutable class or another immutable local value, but after construction it must snapshot all of the following:

```text
bundle identifier
whether Keychain wipe is enabled
whether the target is a system application
system-Keychain policy decision
exact selected access groups
exact signed authorized access groups
signed application-identifier when required
planned pass count
skip reason or planning failure
```

The main typed flow must not reread any Keychain setting, entitlement or selected-group list between the initial and final passes.

## Read settings exactly once

Read once:

```text
dataCleanerKeychainWipeEnabled_<bundleID>
dataCleanerKeychainWipeGroups_<bundleID>
```

For a system application with Keychain wipe enabled, also read once:

```text
suite: com.weaponx.securitySettings
key: allowSystemKeychainWipeEnabled
```

Do not mutate these settings while constructing or executing the main Clear plan.

In particular, the main typed path must not automatically write:

```text
enabled = NO
selected groups = all entitlement groups
```

while a Clear operation is already running.

## Disabled policy

When per-app Keychain wipe is disabled:

- do not read signed Keychain groups merely to fabricate work;
- do not invoke the helper or bridge;
- create a Keychain `Skipped` result;
- use exact detail:

```text
Keychain wipe is disabled for this app
```

Counts must be `0/0/0`, with no failure.

---

# Part 4 — Signed Keychain authorization snapshot

When Keychain wipe is enabled, call:

```objc
AppEntitlementsReader fullEntitlementsForBundleID:error:
```

exactly once for the Keychain plan.

Do not use heuristic access groups, bundle-ID prefix guesses, hard-coded vendor groups, service names or existing Keychain contents to authorize deletion.

## Authorized group sources

Build the authorized set only from:

```text
keychain-access-groups
application-identifier
```

Rules:

1. The entitlements root must be `NSDictionary`.
2. An extraction error is a planning failure.
3. If `keychain-access-groups` is present, it must be `NSArray`.
4. Every `keychain-access-groups` element must be a valid exact string.
5. If `application-identifier` is present, it must be a valid exact string.
6. Add valid `application-identifier` to the authorized set to preserve current selected-Keychain behavior.
7. Deduplicate exact strings.
8. Sort exact strings with `compare:`.
9. Do not trim, lowercase, normalize or rewrite.

## Exact Keychain group string validity

A group string must:

- be an `NSString` at runtime;
- be nonempty;
- contain at least one non-whitespace/newline character;
- contain no U+0000;
- contain no comma;
- have no leading or trailing whitespace/newline.

The comma and surrounding-whitespace rules are transport-safety requirements because the non-system helper receives one comma-separated `--groups` argument and its current parser trims surrounding whitespace.

Do not impose a generic bundle-ID syntax whitelist.

Internal Unicode or internal spaces may remain if they pass the exact transport rules.

## Missing application identifier

For a non-system helper execution, a valid signed `application-identifier` is required to construct the helper entitlement snapshot.

If it is missing or invalid, fail planning closed. Do not silently substitute the application bundle identifier.

The system-app bridge executes inside the target app and does not need a synthetic helper `application-identifier`, but its selected groups must still be exact members of the signed authorized set.

---

# Part 5 — Selected-group semantics

The selected setting object must be interpreted by object presence, not by array count.

## No saved object

If no object exists for the selected-groups key:

- default the plan selection to all exact signed authorized groups;
- do not persist that default during the Clear operation.

## Saved array

If the saved object is an `NSArray`:

- it is the explicit selection even when empty;
- validate every element;
- exact-deduplicate it;
- sort with `compare:`;
- require every selected group to be an exact member of the signed authorized set.

An empty saved array means the user selected none. Return Keychain `Skipped` with exact detail:

```text
No keychain access groups are selected
```

Do not replace an empty saved array with all authorized groups.

## Malformed saved object

A non-array saved object is a planning failure.

Any invalid element is a planning failure.

Any selected group that is not in the exact signed authorized set is an authorization failure.

Do not silently drop unauthorized or malformed entries.

## No signed authorized groups

When no exact authorized groups exist and there is no malformed configuration, return Keychain `Skipped` with exact detail:

```text
No authorized keychain access groups were discovered
```

---

# Part 6 — System application policy

A target is treated as a system application using the existing compatibility rule:

```objc
[bundleIdentifier hasPrefix:@"com.apple."]
```

This rule controls execution transport only; it does not authorize groups.

When per-app Keychain wipe is enabled for a system app but:

```text
allowSystemKeychainWipeEnabled == NO
```

return a Keychain planning failure.

Do not convert this policy denial into `Skipped`, because the user requested Keychain deletion and the current behavior reports it as a failure.

No bridge request may be created in this state.

---

# Part 7 — Keychain pass model and unit accounting

One actual Keychain wipe invocation is one component unit.

## Non-system applications

Plan exactly two passes using the same immutable plan:

```text
initial pass: before data-container clearing
final pass: after data clearing and in-memory cookie clearing
```

The final pass must still run when the initial pass fails.

Accounting:

```text
both pass       -> Succeeded 2/2/0
initial fails   -> Failed    2/1/1 when final succeeds
final fails     -> Failed    2/1/1 when initial succeeds
both fail       -> Failed    2/0/2
```

## System applications

Plan exactly one bridge pass before freezing/data clearing.

The existing intentional second-pass skip remains an execution policy and is not a second attempted or skipped unit.

Accounting:

```text
bridge succeeds -> Succeeded 1/1/0
bridge fails    -> Failed    1/0/1
```

Do not launch the system app a second time after the main data operation.

## Planning failures

A malformed configuration, entitlement extraction failure, unauthorized selection, missing required signed application identifier or system-policy denial is represented as one synthetic failed planning unit:

```text
Failed 1/0/1
```

No Keychain wipe invocation occurs, but the remaining data Clear operation must continue.

## Skipped result

Disabled, explicit empty selection or no authorized groups uses:

```text
Skipped 0/0/0
```

Skipped Keychain is not a callback failure.

---

# Part 8 — Keychain component contract

Use private stable failure domain:

```text
PXKeychainClear
```

Use fixed private failure codes covering at least:

```text
InvalidRequest
ConfigurationFailed
AuthorizationFailed
InitialPassFailed
FinalPassFailed
InternalResultFailure
```

Keep the first failure snapshot while continuing any remaining planned pass.

Do not put any of the following in `PXClearFailure.message` or component detail:

- access-group names;
- application identifier;
- helper path;
- temporary path;
- command arguments;
- stdout or stderr;
- bridge nonce;
- OSStatus text;
- Keychain item attributes.

## Success detail

Use exact detail:

```text
All planned keychain wipe passes succeeded
```

## Failure detail

Use exact detail:

```text
One or more keychain wipe passes failed
```

The Keychain component must satisfy the accepted `PXClearComponentResult` partition invariants.

---

# Part 9 — Main flow orchestration

Preserve the current high-level order:

```text
kill target
snapshot/execute initial Keychain pass
clear URL credentials
clear app state
freeze target
run four-scope data aggregate
clear in-memory cookies
execute final Keychain pass when planned
sync
log-only broad verification
build final five-scope aggregate
complete callback
```

The exact Keychain plan must be built once and reused by both passes.

A Keychain planning or pass failure must not stop the four data components from running.

A data-component failure must not suppress a planned final non-system Keychain pass.

## Final aggregate construction

After all planned Keychain passes finish, construct one Keychain component and then one final `PXClearResult` using:

```text
request = original five-scope full request
components = four data components + Keychain component
```

Do not mutate or reuse the four-scope data result as though its request had five scopes.

## Callback policy

The final full result is the only component-based callback source.

Use exact failure precedence:

1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData
5. Keychain

The first failed component selects callback `NSError`. Every lower-priority failure must still be logged.

When no component is `Failed`, callback success is `YES`, even if one or more components are `Skipped`.

Do not use `allRequestedScopesSucceeded` for legacy callback success because accepted disabled/empty Keychain policy is represented as `Skipped`.

Remove main-flow callback decision variables and branches based on:

```text
keychainOK1
keychainOK2
keychainFailed
keychainError1
keychainError2
```

Equivalent temporary execution variables may exist inside a dedicated Keychain component builder, but callback outcome must not be decided outside the final five-scope result.

Preserve:

- one-shot completion protection;
- watchdog behavior;
- background task handling;
- freeze/unfreeze behavior;
- exception mapping;
- main-thread callback dispatch.

---

# Part 10 — Exact execution API in AppDataCleaner

Create a private execution path that receives the immutable plan values explicitly.

Recommended semantic shape:

```objc
- (BOOL)_executeKeychainWipeForBundleIdentifier:(NSString *)bundleIdentifier
                                 selectedGroups:(NSArray<NSString *> *)selectedGroups
                           applicationIdentifier:(nullable NSString *)applicationIdentifier
                              systemApplication:(BOOL)systemApplication
                                          error:(NSError **)error;
```

The exact selector may differ, but it must:

- clear `*error` at entry;
- reject invalid input;
- not read `NSUserDefaults`;
- not read entitlements;
- not change selected groups;
- execute exactly one pass;
- return failure for incomplete, truncated or malformed execution evidence.

The main typed flow must call this exact-snapshot execution path, not `_wipeSelectedKeychainForBundleID:error:`.

## Legacy compatibility wrapper

Keep:

```objc
- (BOOL)_wipeSelectedKeychainForBundleID:(NSString *)bundleID
                                   error:(NSError **)error;
```

for existing private callers.

It may delegate through the new planning/execution infrastructure, but its legacy return mapping must remain:

```text
Skipped policy -> YES
Succeeded pass -> YES
Planning/execution failure -> NO
```

Do not remove existing public compatibility Keychain selectors in TASK-1.10.

The main `clearDataForBundleID:completion:` flow must contain zero calls to `_wipeSelectedKeychainForBundleID:error:` after migration.

---

# Part 11 — Bounded non-system helper execution

The non-system path must stop using unbounded:

```objc
[runner runAndCapture:signCmd]
[runner runAndCapture:wipeCmd]
```

Use `runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:` directly.

## Signing invocation

Executable:

```text
resolved ldid absolute path
```

Arguments:

```objc
@[
    [@"-S" stringByAppendingString:entitlementsPath],
    workingHelperPath
]
```

Do not construct a shell command string.

Use fixed bounded policy:

```text
timeout: 60 seconds
maxOutputBytes: 1 MiB per stream
```

## Wipe invocation

Executable:

```text
copied/resigned working helper absolute path
```

Arguments:

```objc
@[
    @"--action", @"wipe",
    @"--groups", groupsCSV
]
```

Use fixed bounded policy:

```text
timeout: 120 seconds
maxOutputBytes: 1 MiB per stream
```

Execution succeeds only when:

```text
result != nil
result.isSucceeded == YES
stdoutTruncated == NO
stderrTruncated == NO
```

Nil, spawn error, runner error, timeout, abnormal exit, signal, nonzero exit or either truncation is failure.

## Temporary workspace

Use a unique per-pass temporary directory, not only a PID-stable directory reused across calls.

The directory name may include PID plus a random UUID.

Clean request-local helper, entitlement plist and temporary directory on every exit path, including failure and exception paths.

Do not delete unrelated `/tmp` content.

## Diagnostic persistence

Do not persist raw helper stdout, stderr or selected group names in `NSUserDefaults`.

The existing `DataCleaningKeychainResult_<bundleID>` diagnostic entry may remain only if reduced to non-sensitive fields such as:

```text
success
exitCode
timedOut
stdoutTruncated
stderrTruncated
groupCount
```

Do not store command strings or access-group values.

---

# Part 12 — Make backup_helper wipe exit status truthful

Modify only the `wipe` action behavior in:

```text
KeychainHelper/backup_helper.m
```

Do not modify `KeychainBackupHelper.h/.m`.

After:

```objc
[KeychainBackupHelper wipeKeychainForAccessGroups:itemClasses:error:]
```

apply:

```text
nil result -> exit 2
result.itemsFailed > 0 -> exit 2
result.warnings.count > 0 -> exit 2
otherwise -> exit 0
```

A warning is failure evidence for the wipe action because `KeychainBackupHelper` records `SecItemDelete` failures as warnings, including cases where the preliminary item count was zero.

A successful wipe with zero matching items is valid success.

Emit one machine-readable, non-sensitive summary line, for example:

```text
PXKEYCHAIN_WIPE_RESULT processed=<n> succeeded=<n> failed=<n> warnings=<n>
```

Do not print access-group values in the summary.

Keep backup, restore and list behavior unchanged.

Do not change command-line option names or parser behavior in this task.

---

# Part 13 — Make the system bridge response truthful

Modify the wipe path in:

```text
WeaponXKeychainBridge/Tweak.m
```

The current bridge must not call a void wipe and then unconditionally set:

```objc
resp[@"ok"] = @YES;
```

## Result-bearing bridge wipe

Add a private result-bearing wipe helper.

For every valid selected group and each currently supported class:

```text
GenericPassword
InternetPassword
```

perform one `SecItemDelete` operation.

Count:

```text
attempted operations
succeeded operations
failed operations
```

Treat:

```text
errSecSuccess -> succeeded
errSecItemNotFound -> succeeded
all other OSStatus values -> failed
```

Reject an empty or malformed group array before execution.

The response for action `wipe` must contain:

```text
ok
bundleID
action
nonce
attempted
succeeded
failed
```

Require:

```text
attempted > 0
succeeded + failed == attempted
ok == (failed == 0 && succeeded == attempted)
```

The bridge may log per-operation OSStatus diagnostics to its private bridge log, but must not put access-group names or OSStatus details into the `PXClearFailure` later produced by AppDataCleaner.

## Restore compatibility

`WXRestoreFromImport` may continue to use a compatibility void wrapper that ignores the result of its overwrite pre-wipe.

Do not change Backup/Restore response contracts in TASK-1.10.

## Request validation

For wipe requests, require:

- action exact `wipe`;
- request bundle ID exact current bundle ID;
- nonempty nonce;
- nonempty valid group array;
- response/log paths under `/tmp` as currently required.

Do not report success for malformed groups.

---

# Part 14 — Validate bridge response in AppDataCleaner

Strengthen response validation for a system-app wipe.

A response is accepted only when:

```text
nonce exactly matches request nonce
bundleID exactly matches target bundle identifier
action exactly equals wipe
ok is boolean true
attempted, succeeded and failed are numeric nonnegative integers
attempted > 0
succeeded <= attempted
failed == attempted - succeeded
failed == 0
succeeded == attempted
```

Reject stale, malformed or partial responses.

Do not accept `ok = YES` without valid counts.

Do not infer success from bridge log text.

Best-effort cleanup of request and response files must occur on both success and failure.

---

# Part 15 — Preserve explicit empty selection in KeychainGroupsViewController

In `KeychainGroupsViewController.m`, distinguish:

```text
saved object absent
saved object is NSArray, including empty
saved object malformed
```

Rules:

1. Absent saved object: select all currently signed entitlement groups as the initial UI default.
2. Saved `NSArray`: preserve exact saved selection, including an empty array.
3. Intersect saved values with the currently displayed exact entitlement group set so stale unauthorized values are not shown as selected.
4. Malformed saved object: select none and show a non-sensitive configuration warning; do not silently select all.
5. `selectNoneTapped` plus `saveTapped` must persist `@[]` and it must remain empty when the screen is reopened.
6. Keep exact sorted persistence in `saveTapped`.

Do not change table layout, navigation or notification names.

---

# Part 16 — Preserve explicit empty selection in ProjectXViewController

In `ProjectXViewController.m`, update only the Clear confirmation Keychain configuration logic.

Rules:

1. Absent selected-groups object: default to all signed entitlement groups and persist the initial default as existing UI behavior.
2. Saved `NSArray`, including `@[]`: preserve it exactly; do not replace empty with all groups.
3. Malformed saved object: represent zero selected groups; do not silently authorize all groups.
4. Display zero selected groups clearly in the confirmation state.
5. Do not auto-enable Keychain wipe.
6. Preserve existing system-app global policy UI behavior.

Do not change unrelated UI or Clear confirmation layout.

---

# Part 17 — Main-flow Keychain bypass audit

After TASK-1.10, the main `clearDataForBundleID:completion:` flow must perform selected Keychain deletion only through the immutable plan and exact execution path.

It must not call:

```text
clearKeychainItemsForBundleID:
universalKeychainWipeForBundleID:
clearAppKeychain:
clearKeychainData:
security delete-* compatibility commands
extension Keychain helpers
```

Existing compatibility methods may remain for external or legacy callers, but they must not become part of the five-scope main aggregate.

`verifyDataCleared:` Keychain inspection remains log-only and must not rewrite the Keychain component outcome.

Do not migrate extension Keychain deletion in TASK-1.10.

---

# Part 18 — Failure precedence and error conversion

Convert the selected failed `PXClearFailure` to callback `NSError` using the existing stable conversion helper.

Exact precedence:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
Keychain
```

Examples:

- ApplicationData and Keychain fail: ApplicationData error wins.
- AppGroups and Keychain fail: AppGroups error wins.
- Only Keychain fails: Keychain error wins.
- Keychain is skipped and all data components avoid failure: callback succeeds.

Do not expose helper stderr, bridge error text containing identifiers or raw entitlement values in callback `NSError`.

---

# Part 19 — Out of scope

Do not:

- change `PXClearRequest` or `PXClearResult` public contracts;
- add a new public Clear method;
- make `completeAppDataWipe:` wipe Keychain;
- migrate extension Keychain items;
- migrate Backup or Restore Keychain behavior;
- modify `KeychainBackupHelper.h/.m`;
- broaden authorized access groups beyond signed exact groups;
- add hard-coded Facebook, Google, Uber or other vendor groups to the typed flow;
- use service/account/label substring matching in the typed flow;
- modify App Group, ApplicationData, ExtensionData or PluginKitData safety behavior;
- change UI layout;
- start TASK-1.11;
- change generic permission or marker-file helpers.

---

# Part 20 — Required static gates

Verify all of the following after implementation:

```text
PXMigratedDataClearScopes: exact four data scopes
PXMigratedFullClearScopes: exact five scopes
PXClearScopeDefaultMask references in main migration: 0
four-scope data aggregate component count: 4
five-scope full aggregate component count: 5
full aggregate Keychain component count: 1
completeAppDataWipe Keychain execution calls: 0
clearDataForBundleID _wipeSelectedKeychainForBundleID calls: 0
main callback keychainOK1/keychainOK2 variables: 0
main callback keychainFailed branch: 0
callback precedence: ApplicationData, ExtensionData, AppGroups, PluginKitData, Keychain
callback uses allRequestedScopesSucceeded: 0
Keychain plan settings reads: once each
Keychain plan fullEntitlementsForBundleID calls: at most 1 when enabled
selected empty array fallback-to-all: 0
selected unauthorized group silent-drop: 0
non-system unbounded runAndCapture signing/wipe calls: 0
non-system direct ldid invocation: 1 execution path
non-system direct helper invocation: 1 execution path
helper wipe warnings accepted as success: 0
bridge wipe unconditional ok YES: 0
bridge response attempted/succeeded/failed: present
bridge malformed/partial response accepted: 0
raw stdout/stderr persisted in DataCleaningKeychainResult: 0
TASK-1.4 receipt tokens: 0
```

Audit every main-flow Keychain call and classify:

- full-operation plan construction;
- initial pass execution;
- final pass execution;
- Keychain component construction;
- final five-scope aggregate;
- log-only verification;
- unreachable legacy compatibility behavior.

---

# Part 21 — Required scenario matrix

The report must provide static or runtime evidence for at least these scenarios:

1. Invalid full Clear request.
2. Keychain wipe setting absent/default OFF.
3. Keychain wipe explicitly OFF.
4. Enabled with no saved selected-groups object.
5. Enabled with saved nonempty selected array.
6. Enabled with saved empty array.
7. Saved selected-groups object has wrong type.
8. Saved array contains non-string element.
9. Saved group is whitespace-only.
10. Saved group contains U+0000.
11. Saved group contains comma.
12. Saved group has leading/trailing whitespace.
13. Entitlement extraction failure.
14. Entitlements root has wrong type or is nil without valid dictionary.
15. `keychain-access-groups` key absent.
16. `keychain-access-groups` wrong type.
17. `keychain-access-groups` contains invalid element.
18. `application-identifier` valid.
19. `application-identifier` absent for non-system helper.
20. Duplicate exact signed groups.
21. Selected group is exact authorized member.
22. Selected group is not authorized.
23. No signed authorized groups.
24. System app with global system-Keychain policy OFF.
25. System app with policy ON and bridge success.
26. System bridge malformed request groups.
27. System bridge one `SecItemDelete` failure.
28. System bridge all items not found.
29. System bridge response nonce mismatch.
30. System bridge response bundle mismatch.
31. System bridge response action mismatch.
32. System bridge response missing counts.
33. System bridge count partition invalid.
34. Non-system ldid not found.
35. Non-system helper not found.
36. Non-system helper copy failure.
37. Entitlement plist generation/write failure.
38. Direct ldid timeout/failure/truncation.
39. Direct helper timeout/failure/truncation.
40. Helper wipe returns warnings with zero item count.
41. Non-system initial pass fails, final succeeds.
42. Non-system initial succeeds, final fails.
43. Both non-system passes fail.
44. Both non-system passes succeed.
45. System app performs exactly one pass.
46. Disabled Keychain creates Skipped 0/0/0.
47. Empty selection creates Skipped 0/0/0.
48. Planning failure creates Failed 1/0/1 and data components still run.
49. ApplicationData plus Keychain failure precedence.
50. AppGroups plus Keychain failure precedence.
51. Only Keychain fails.
52. Keychain skipped while data components have no failures.
53. Final aggregate wrong/missing Keychain component.
54. `completeAppDataWipe:` remains four-scope and data-only.
55. KeychainGroups UI reopens an explicit empty selection as empty.
56. Clear confirmation preserves explicit empty selection.
57. Temporary helper directory cleanup after success.
58. Temporary helper directory cleanup after failure.
59. Stored diagnostic contains no stdout/stderr/group values.
60. Legacy external `_wipeSelectedKeychainForBundleID:` skipped/success/failure mapping.

---

# Part 22 — Required report contents

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.10-REPORT.md
```

The report must include:

1. baseline HEAD and initial status;
2. exact files changed;
3. protected before/after SHA-256 values;
4. four-scope data mask proof;
5. five-scope full mask proof;
6. full-request/data-request relationship;
7. immutable Keychain plan fields and snapshot timing;
8. setting-read count proof;
9. signed authorization extraction;
10. exact selected-group subset validation;
11. empty-selection semantics;
12. system-policy semantics;
13. initial/final/system pass accounting;
14. Keychain component construction;
15. full aggregate exact coverage/order;
16. callback success and failure precedence;
17. removal of separate Keychain BOOL callback logic;
18. bounded direct ldid invocation;
19. bounded direct helper invocation;
20. temporary artifact cleanup;
21. non-sensitive diagnostic persistence;
22. backup_helper exit-status correction;
23. system bridge operation counts and truthfulness;
24. bridge response validation;
25. KeychainGroups UI empty-selection proof;
26. ProjectX confirmation empty-selection proof;
27. main-flow Keychain bypass audit;
28. proof extension Keychain/Backup/Restore remain out of scope;
29. all required scenarios;
30. full diff/stat for allowed production files;
31. whitespace, NUL, binary and generated-artifact audit;
32. remaining risks.

Required commands before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- AppDataCleaner.m WeaponXKeychainBridge/Tweak.m KeychainHelper/backup_helper.m KeychainGroupsViewController.m ProjectXViewController.m
git diff -- AppDataCleaner.m WeaponXKeychainBridge/Tweak.m KeychainHelper/backup_helper.m KeychainGroupsViewController.m ProjectXViewController.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
```

The report must end with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

Stop after TASK-1.10.

Do not implement TASK-1.11.
