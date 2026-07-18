# TASK-1.10 Review

## Verdict

```text
Task: TASK-1.10
Baseline: 0bb2e354715e00f20c4df95719e900ae5e8e1673
Implementation commit reviewed: 2579c76a8716761b88bf99f7d77b14f4ddb1171e
Coordinator packaging commit at review time: 7b277bfd2579e53f0015b89ef36b43440688590b
Build gate: PASSED — accepted from project-owner continuation; no CI artifact is stored in this workspace
Production source review: ACCEPTED
Final status: COMPLETED
Next gate: TASK-1.11
```

TASK-1.10 is accepted. Full Clear now produces one truthful five-scope result in which Keychain is planned once, executed as explicit pass units, and participates in deterministic callback failure precedence instead of remaining detached BOOL state.

## Scope reviewed

Production changes:

- `AppDataCleaner.m`
- `WeaponXKeychainBridge/Tweak.m`
- `KeychainHelper/backup_helper.m`
- `KeychainGroupsViewController.m`
- `ProjectXViewController.m`

Task evidence:

- `docs/backup-restore-hardening/tasks/TASK-1.10-integrate-keychain-clear-result.md`
- `docs/backup-restore-hardening/reports/TASK-1.10-REPORT.md`

The implementation commit changes exactly the five allowed production files plus the required report. Protected Clear models, resolvers, validator, command runner, App Group resolver, Backup manager, Keychain helper library and Makefile remain unchanged.

## Accepted implementation

### Separate four-scope data and five-scope full requests

The accepted internal data mask remains exactly:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
```

Full Clear adds exactly one Keychain scope and constructs the final aggregate in canonical order:

1. ApplicationData
2. ExtensionData
3. AppGroups
4. PluginKitData
5. Keychain

`completeAppDataWipe:` remains the four-scope data-only compatibility operation and performs no Keychain execution.

### Immutable request-scoped Keychain plan

`PXKeychainClearPlan` snapshots before the first pass:

- bundle identifier;
- per-app enable state;
- saved selection object semantics;
- exact signed authorized groups;
- signed application identifier;
- system-app classification;
- captured system policy;
- planned pass count;
- skip or planning-failure state.

The two execution passes do not reread settings, policy or entitlements. Plan construction does not persist defaults, so the initial pass cannot change the meaning of the final pass.

### Exact signed authorization and explicit empty selection

Keychain authorization is derived only from signed:

```text
keychain-access-groups
application-identifier
```

Accepted values are exact, validated, deduplicated and sorted without trimming or normalization. A selected group must be an exact member of the signed authorized set; malformed or unauthorized selections fail closed.

Saved-object presence is authoritative:

```text
object absent  -> default to all signed authorized groups for this request only
NSArray @[]    -> explicit empty selection, Skipped 0/0/0
NSArray values -> exact validated selection
wrong type     -> planning failure
```

The UI preserves this distinction. Reopening an explicit empty selection remains empty, and the Clear confirmation reports zero selected groups rather than silently restoring all groups.

### Pass accounting

The result model correctly treats pass invocations as units:

```text
non-system app: initial pass + final pass = 2 attempted units
system app: one bridge pass = 1 attempted unit
disabled / empty / no authorized groups = Skipped 0/0/0
planning/configuration/authorization error = Failed 1/0/1
```

For non-system apps, the final pass still runs after an initial failure. Partial outcomes therefore remain observable as `Failed 2/1/1`; two failures produce `Failed 2/0/2`; two successes produce `Succeeded 2/2/0`.

### Bounded non-system execution

The non-system path now invokes both tools through direct bounded execution:

```text
ldid:   60 seconds, 1 MiB per stream
helper: 120 seconds, 1 MiB per stream
```

Success requires a non-nil successful `CommandResult` and non-truncated stdout/stderr. Shell command-string signing/wipe execution is absent. Each pass uses a unique PID-plus-UUID temporary workspace and removes temporary files/directories in `@finally`.

Persisted diagnostics contain only non-sensitive status/counter fields; raw output, command text and group values are not stored.

### Truthful helper and bridge outcomes

`backup_helper` wipe now emits one machine-readable non-sensitive summary. It exits nonzero when:

- the wipe result is nil;
- any item failed; or
- any warning exists.

Zero matching items remain a successful completed wipe when no failure or warning occurred.

The system bridge now counts every selected-group × supported-class operation. `errSecSuccess` and `errSecItemNotFound` count as succeeded; other statuses count as failed. The response includes exact request identity and an attempted/succeeded/failed partition. The cleaner rejects stale, malformed, partial or internally inconsistent responses.

The former unconditional wipe `ok = YES` path is absent.

### Final result and callback policy

Callback outcome is derived only from the final five-scope `PXClearResult`. Failure precedence is:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
Keychain
```

Lower-priority simultaneous failures remain logged. Keychain `Skipped` is not a callback failure. Detached `keychainOK1`, `keychainOK2`, `keychainFailed`, detached Keychain errors and callback use of `allRequestedScopesSucceeded` are absent.

### Main-flow bypass audit

The five-scope main flow does not call legacy aggressive Keychain APIs, extension Keychain cleanup, service/account substring deletion paths or `_wipeSelectedKeychainForBundleID:error:`. The legacy wrapper remains available for compatibility and maps skip/success/failure without participating in the typed full result.

## Independent verification

The following gates passed:

```text
git show --check --oneline 2579c76
git diff 0bb2e35..2579c76 --check
protected production diff: clean
exact changed-file scope: clean
```

Method-boundary checks confirmed:

```text
PXMigratedDataClearScopes declarations: 1
PXMigratedFullClearScopes declarations: 1
PXClearScopeDefaultMask references in AppDataCleaner: 0
main legacy Keychain wrapper calls: 0
main detached Keychain callback variables: 0
main allRequestedScopesSucceeded references: 0
main forbidden Keychain bypass calls: 0
completeAppDataWipe Keychain execution references: 0
exact executor direct bounded calls: 2
exact executor unbounded runAndCapture calls: 0
plan full-entitlement reads: 1
plan enabled-setting reads: 1
plan selected-object reads: 1
plan system-policy reads: 1
plan defaults writes: 0
receipt tokens: 0
```

The implementation diff introduces no trailing whitespace. The reviewed production files and report contain no NUL bytes. Several large legacy source files retain historical trailing whitespace outside this commit; cumulative and commit-local `--check` gates are clean.

## Build and runtime evidence

The task report correctly states that the Windows workspace cannot run the Objective-C/Theos build. Project-owner continuation is treated as the build-gate acceptance used by this workflow, but no GitHub Actions log or compiled artifact is present locally for independent inspection.

Device-only scenarios remain pending, including:

- system-app bridge loading and launch behavior;
- injected Security.framework failure statuses;
- timeout/truncation fault injection;
- filesystem failure and temporary-workspace cleanup paths;
- same-bundle concurrent Clear serialization.

These runtime risks do not block source acceptance because the required planning, execution, accounting, aggregate and callback contracts are present and fail closed.
