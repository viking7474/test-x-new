# TASK-2.14A Review

Implementation commit reviewed: `0ef0631af3696531251ee4a4dfbfb953e9f2bc81`

Implementation subject: `phase2(task-2.14A): make restore result mutations assertion independent`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-2.14 final status: **COMPLETED**

Phase 2 final status: **COMPLETED**

## Scope review

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-2.14A-REPORT.md
```

No other production source changed. In particular, the following remain byte-identical to baseline `fec59661e8e171fd6404ad0dfc56e3c71e69b34c`:

```text
PXRestoreResult.h
PXRestoreResult.m
AppDataBackupManager.h
PXMainDataRestoreTransaction.h/.m
PXAppGroupRestoreTransaction.h/.m
PXOptionalRestoreTransaction.h/.m
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXOptionalRestoreStaging.h/.m
PXRestorePlan.h/.m
accepted validators/resolvers
CommandRunner.h/.m
Makefile
UI/controller source
Keychain helper/bridge/script source
```

## Corrective finding closure

TASK-2.14 placed ten required accumulator mutations directly inside `NSCAssert` condition expressions. Such conditions may not be evaluated when `NS_BLOCK_ASSERTIONS` is enabled.

TASK-2.14A moves every required mutation into an ordinary Objective-C assignment executed before the diagnostic assertion.

Accepted pattern:

```objc
BOOL applicationResultMarked =
    [resultAccumulator markComponentSucceeded:PXRestoreComponentApplicationData
                                      warnings:componentWarnings];
NSCAssert(applicationResultMarked,
          @"ApplicationData result state must be publishable");
(void)applicationResultMarked;
```

The mutation is evaluated exactly once regardless of assertion configuration. The assertion observes only the already-computed Boolean.

## Exact mutation inventory

Independent production-source counts:

```text
markComponentSucceeded calls:                 8
markComponentFailed calls:                    2
appendWarnings calls:                         1
required accumulator mutations in NSCAssert:  0
required accumulator mutations in NSAssert:   0
```

The eight success transitions are:

1. ApplicationData;
2. ProfileAppData;
3. GlobalSafari;
4. AppGroups;
5. SystemGlobal;
6. SharedSystemDatabases;
7. Preferences;
8. Keychain.

The two failure transitions remain:

1. the common post-boundary hard-failure publisher;
2. the Keychain warning-only failure path.

The one append transition remains the post-restore ApplicationData warning attachment.

## Assertion-independent behavior

With assertions enabled:

- each required mutation executes once;
- the existing diagnostic message checks the returned Boolean;
- model publication behavior is unchanged.

With `NS_BLOCK_ASSERTIONS` enabled:

- each assignment expression remains executable code;
- `(void)variable` prevents assertion-disabled unused-variable warnings;
- all eight durable successes update the result accumulator;
- the Keychain warning-only failure updates the failed mask and synthetic code `322` snapshot;
- post-verification warnings attach to ApplicationData.

The two remaining result assertions are non-mutating:

```text
post-boundary result != nil
final result != nil
```

Both values are constructed before the assertions.

## Structured-result non-regression

The accepted TASK-2.14 result contract remains unchanged:

```text
components:         8
component statuses: 4
rollback statuses:  3
public model classes: 3
public readwrite properties: 0
```

Completion behavior remains:

```text
pre-boundary failure              -> nil result + error
post-boundary hard failure        -> structured result + error
normal completion                 -> structured result + nil error
Keychain helper execution failure -> structured result + nil error + Keychain Failed
```

No requested-mask, planned-unit, failure-attribution, rollback, code `321`, code `322`, or component-order behavior changed.

## Warning compatibility

The Restore method still contains the same 21 warning append expressions in the same sequence as baseline.

No warning text, punctuation, capitalization, occurrence, ordering, or component attribution changed.

## Independent gates

```text
git show --check:                          PASS
baseline-to-HEAD diff --check:             PASS
implementation scope:                      PASS
protected production diff:                 0
markComponentSucceeded calls:              8
markComponentFailed calls:                 2
appendWarnings calls:                      1
assert-owned accumulator mutations:        0
warning append sequence diff:              0
public Restore selector diff:              0
PXRestoreResult model diff:                0
UI/controller diff:                        0
report scenarios:                         76
new trailing whitespace:                   0
new NUL bytes:                             0
```

`AppDataBackupManager.m` retains pre-existing trailing-whitespace lines outside the corrective diff. The implementation commit and cumulative diff checks are clean.

## Build status

The report records strict frontend proof both with assertions enabled and with `NS_BLOCK_ASSERTIONS` defined. The workspace does not contain a linked Apple/Theos artifact or target-device run log, so those cannot be independently reproduced here.

The project owner's continuation is accepted as build-status confirmation because no source evidence contradicts it.

## Decision

**ACCEPTED.** TASK-2.14A closes the assertion-elision defect without widening production scope. TASK-2.14 and Phase 2 are completed.

TASK-3.1 may be specified from baseline `0ef0631af3696531251ee4a4dfbfb953e9f2bc81`.
