# TASK-2.14 Review — Structured Restore Result

Implementation commit reviewed: `fec59661e8e171fd6404ad0dfc56e3c71e69b34c`

Implementation subject: `phase2(task-2.14): add structured restore result`

Production source review: **CHANGES_REQUESTED**

Final status: **CHANGES_REQUESTED**

TASK-2.14A required: **YES**

Phase 3 status: **LOCKED**

## Scope

The implementation commit contains exactly the expected files:

```text
M AppDataBackupManager.h
M AppDataBackupManager.m
A PXRestoreResult.h
A PXRestoreResult.m
A docs/backup-restore-hardening/reports/TASK-2.14-REPORT.md
```

No protected transaction, staging, plan, validator, resolver, runner, Makefile, UI/controller, Backup helper, or Keychain helper/bridge/script source changed.

`git show --check` and the cumulative baseline-to-HEAD whitespace check pass.

## Accepted implementation areas

The public value model is structurally correct:

```text
component bits:                 8
component statuses:             4
rollback statuses:              3
subclassing-restricted classes: 3
NSCopying classes:              3
public readwrite properties:    0
model implementations:          3
```

The model provides:

- exact canonical component order;
- exact requested/succeeded/skipped/not-attempted/failed mask partitioning;
- immutable failure snapshots rather than retained `NSError` objects;
- bounded strings, warnings, and planned-unit counts;
- exact status/rollback/failure invariants;
- canonical eight-result coverage;
- immutable copy/equality/hash behavior;
- compatible readonly `result.warnings` access for existing callers.

Manager integration also correctly introduces:

- the result-planning boundary after accepted Restore, App Group, and optional destination plans;
- exact requested masks and planned-unit counts;
- one effective system-global item array preserving the existing Safari duplicate rule;
- post-boundary `result + error` publication through one helper;
- typed rollback mapping from retained transaction state;
- component-specific warning attribution;
- Keychain warning-only completion with synthetic component failure code 322;
- post-verification warning attachment to ApplicationData;
- zero UI/controller diff and unchanged public Restore selector.

The existing Restore warning append sequence remains exactly 21 expressions in the same order.

## Blocking finding — accumulator mutations occur only inside assertions

Ten required accumulator mutations are passed directly as the condition expression of `NSCAssert(...)`:

```text
markComponentSucceeded calls inside NSCAssert: 8
markComponentFailed calls inside NSCAssert:    1
appendWarnings calls inside NSCAssert:         1
```

Affected result state includes:

1. ApplicationData success.
2. ProfileAppData success.
3. GlobalSafari success.
4. AppGroups success.
5. SystemGlobal success.
6. SharedSystemDatabases success.
7. Preferences success.
8. Keychain success.
9. Keychain warning-only failure.
10. ApplicationData post-verification warning attachment.

Representative source:

```objc
NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentApplicationData
                                               warnings:...],
          @"ApplicationData result state must be publishable");
```

Under a build where `NS_BLOCK_ASSERTIONS` disables Foundation assertions, the condition expression is not a reliable execution boundary. The method call can be compiled out together with the assertion.

The production consequences are severe:

- durably committed components remain `NotAttempted`;
- `committedUnitCount` remains zero;
- Keychain helper failure is not recorded as `Failed`;
- synthetic Keychain code 322 is absent from the final result;
- post-verification warnings remain aggregate-only instead of being attached to ApplicationData;
- normal completion can publish a result whose component states do not describe the Restore that actually ran.

This violates the central TASK-2.14 contract independently of whether the current debug configuration happens to keep assertions enabled. Structured result correctness cannot depend on build-mode assertion evaluation.

## Required correction

Every accumulator mutation must be evaluated unconditionally and exactly once before any diagnostic assertion.

Acceptable pattern:

```objc
BOOL stateUpdated =
    [resultAccumulator markComponentSucceeded:component warnings:componentWarnings];
NSCAssert(stateUpdated, @"Result state must be publishable");
(void)stateUpdated;
```

An equivalent private helper is acceptable only when Objective-C argument evaluation invokes the accumulator mutation before entering the helper, and the helper does not hide the mutation inside another assertion macro.

The correction must prove identical behavior with and without:

```text
NS_BLOCK_ASSERTIONS
```

The two non-mutating assertions checking a previously constructed `result`/`out` may remain because they do not own required state transitions, although the report must distinguish them from the ten mutation sites.

## Non-blocking observations

`AppDataBackupManager.m` retains 17 pre-existing trailing-whitespace lines. No new trailing whitespace was introduced by the implementation commit.

The report contains 300-plus explicit scenarios and ends with the required status lines. It does not identify the assertion-elision risk.

No full Theos/iOS linked artifact or target-device result is present in the coordinator workspace. Owner continuation is accepted as build-status context, but it cannot override a source-level release-mode semantic defect.

## Repository gates

```text
git show --check:                       PASS
baseline-to-HEAD diff --check:          PASS
exact implementation scope:             PASS
protected production diff:              PASS
warning sequence equality:              PASS
model structural gates:                 PASS
post-boundary nil-result branches:       PASS except code-321 planning branch
assert-owned accumulator mutations:      10 — BLOCKER
report scenarios:                        300+
new source/report NUL bytes:             0
```

## Verdict

TASK-2.14 is not accepted.

Open narrow corrective TASK-2.14A from baseline `fec59661e8e171fd6404ad0dfc56e3c71e69b34c`.

TASK-2.14A may modify only `AppDataBackupManager.m` plus its report. The result model, public header, transaction/staging/planning source, warning text/order, UI compatibility, Keychain execution semantics, and Phase 3 boundary remain unchanged.

Phase 3 stays locked until TASK-2.14A passes source review and TASK-2.14 is consequently completed.
