# TASK-2.14A — Fix Assertion-Elided Structured Result State

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `fec59661e8e171fd6404ad0dfc56e3c71e69b34c`
- Corrects: TASK-2.14
- Review: `docs/backup-restore-hardening/reviews/TASK-2.14-REVIEW.md`
- Next phase: Phase 3 remains LOCKED

## Objective

TASK-2.14 introduced the correct immutable structured Restore result model, but ten required accumulator mutations are executed only as condition expressions inside `NSCAssert(...)`.

Foundation assertions may be disabled by defining `NS_BLOCK_ASSERTIONS`. A required state transition must never depend on assertion evaluation.

TASK-2.14A must make every structured-result accumulator mutation execute unconditionally and exactly once in debug, release, assertion-enabled, and assertion-disabled builds.

This is a narrow manager-only corrective task. It does not redesign the public model or any Restore behavior.

## Production scope

Allowed production file only:

```text
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.14A-REPORT.md
```

Implementation commit may contain only:

```text
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.14A-REPORT.md
```

## Protected files

Do not modify:

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
PXBackupManifestValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
CommandRunner.h/.m
Makefile
all UI/controller files
Backup helper/publication source
Keychain helper/bridge/script/protocol files
coordinator task/review/status/roadmap/decision/README files
```

Record SHA-256 before and after for all protected production files.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

The required baseline is exactly:

```text
fec59661e8e171fd6404ad0dfc56e3c71e69b34c
```

Do not use a later or earlier baseline without stopping.

## Blocker to correct

Current manager source contains ten patterns equivalent to:

```objc
NSCAssert([resultAccumulator mutateState...], @"...");
```

Required affected mutations:

```text
ApplicationData success marker
ProfileAppData success marker
GlobalSafari success marker
AppGroups success marker
SystemGlobal success marker
SharedSystemDatabases success marker
Preferences success marker
Keychain success marker
Keychain warning-only failure marker
ApplicationData post-verification warning attachment
```

When assertions are disabled, these calls must still execute.

## Required source transformation

For every affected site:

1. Evaluate the accumulator mutation outside every assertion macro.
2. Evaluate it exactly once.
3. Store or pass the resulting BOOL through an always-evaluated expression.
4. Use `NSCAssert` only as a diagnostic check on the already evaluated BOOL.
5. Suppress unused-variable warnings safely when assertions are disabled.
6. Preserve the current message text when practical.

Recommended direct form:

```objc
BOOL applicationResultMarked =
    [resultAccumulator markComponentSucceeded:PXRestoreComponentApplicationData
                                      warnings:componentWarnings];
NSCAssert(applicationResultMarked,
          @"ApplicationData result state must be publishable");
(void)applicationResultMarked;
```

Equivalent helper form is allowed only if the mutation occurs in argument evaluation before helper entry:

```objc
static void PXRestoreRequireAccumulatorMutation(BOOL succeeded,
                                                 NSString *reason) {
    NSCAssert(succeeded, @"%@", reason);
    (void)succeeded;
}

PXRestoreRequireAccumulatorMutation(
    [resultAccumulator markComponentSucceeded:...],
    @"...");
```

Forbidden helper form:

```objc
static void PXRestoreMutateOnlyInsideAssert(...) {
    NSCAssert([accumulator mutate...], @"...");
}
```

The final source must contain zero required accumulator mutation expressions directly inside `NSCAssert` or `NSAssert`.

## Exact mutation counts to preserve

After correction, manager source must still contain exactly:

```text
markComponentSucceeded call sites: 8
markComponentFailed call sites:    2
appendWarnings call sites:         1
```

The two `markComponentFailed` calls are:

1. the existing generic post-boundary failure publisher;
2. the Keychain warning-only failure marker.

Do not duplicate any mutation call to satisfy a static gate.

Required direct-in-assert count:

```text
NSCAssert([resultAccumulator ...): 0
NSAssert([resultAccumulator ...):  0
```

## Component behavior to preserve

### ApplicationData

After durable main transaction success and existing cleanup-warning collection:

- status becomes `Succeeded`;
- committed units equal planned units;
- component warnings preserve the exact suffix beginning at `applicationWarningStart`.

Post-verification warnings must be appended to the already succeeded ApplicationData component even when assertions are disabled.

### ProfileAppData

If requested and transactionally committed:

- status becomes `Succeeded`;
- cleanup/staging warnings remain attached;
- mutation runs in assertion-disabled builds.

### GlobalSafari

Same requirements as ProfileAppData.

### AppGroups

After durable batch commit and warning collection:

- status becomes `Succeeded`;
- physical-target planned/committed counts remain unchanged;
- mutation runs in assertion-disabled builds.

### SystemGlobal

After durable optional batch commit and warnings:

- status becomes `Succeeded`;
- exact effective item count remains the unit count;
- mutation runs in assertion-disabled builds.

### SharedSystemDatabases

After durable batch commit, cleanup warnings, and existing informational warning:

- status becomes `Succeeded`;
- all component warnings remain attached in exact order;
- mutation runs in assertion-disabled builds.

### Preferences

After durable file transaction commit and warnings:

- status becomes `Succeeded`;
- mutation runs in assertion-disabled builds.

### Keychain success

When helper/bridge execution returns success:

- Keychain becomes `Succeeded`;
- warning suffix remains attached;
- mutation runs in assertion-disabled builds.

### Keychain warning-only failure

When helper/bridge execution returns failure:

- exact legacy warning remains appended;
- Keychain becomes `Failed`;
- synthetic `PXBackupErrorDomain` code 322 remains attached;
- rollback remains `NotPerformed`;
- completion error remains nil if no later hard failure occurs;
- mutation runs in assertion-disabled builds.

## Assertions that may remain

The following non-mutating diagnostics may remain:

```objc
NSCAssert(result != nil, ...)
NSCAssert(out != nil, ...)
```

They do not own required state transitions because `result` and `out` are constructed before the assertion expression.

Do not move construction of `result` or `out` inside an assertion.

## Release-mode proof

The report must prove assertion-disabled behavior.

Use the strongest available method.

Preferred proof:

1. Compile/preprocess the relevant manager integration with `NS_BLOCK_ASSERTIONS` defined.
2. Show that all eleven accumulator mutation call sites remain in the assertion-disabled source/object:
   - eight success calls;
   - two failure calls;
   - one append call.
3. Show direct-in-assert mutation count is zero.

If a full Objective-C compile is unavailable:

- use an external temporary preprocessing or strict frontend harness outside the repository;
- define `NS_BLOCK_ASSERTIONS`;
- model Foundation's disabled assertion behavior;
- prove each accumulator mutation remains in executable statement/argument position;
- run a static syntax/AST check when available;
- do not commit temporary stubs or harnesses.

A textual claim that the current Makefile uses `DEBUG=1` is not sufficient. The task must be correct for future release/final package builds.

## No behavior redesign

Do not change:

- `PXRestoreResult` enums or model invariants;
- public header placement;
- Restore selector or completion type;
- result-planning boundary;
- requested component mask;
- planned unit counts;
- effective Safari duplicate rule;
- component execution order;
- component success boundaries;
- failure attribution;
- typed rollback mapping;
- warning text, occurrence, or append order;
- code 321 or code 322 contracts;
- Keychain warning-only execution semantics;
- post-verification behavior;
- UI/caller behavior;
- transaction/staging/planning behavior;
- Backup behavior.

## Error and completion contract

Preserve exactly:

```text
pre-boundary failure:
  result nil
  error nonnil

post-boundary hard failure:
  result nonnil
  error nonnil

normal completion:
  result nonnil
  error nil

Keychain warning-only helper failure:
  result nonnil
  error nil
  Keychain Failed
```

Do not add a new public error code.

Do not repurpose code 321 or 322.

## Static gates

Required implementation scope:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-2.14A-REPORT.md
all other production diff = 0
```

Required counts:

```text
markComponentSucceeded calls:                 8
markComponentFailed calls:                    2
appendWarnings calls:                         1
accumulator mutations directly in NSCAssert: 0
accumulator mutations directly in NSAssert:  0
non-mutating result/out assertions:           2 or fewer
```

Required behavior inventory:

```text
ApplicationData success mutation always evaluated
ProfileAppData success mutation always evaluated
GlobalSafari success mutation always evaluated
AppGroups success mutation always evaluated
SystemGlobal success mutation always evaluated
SharedSystemDatabases success mutation always evaluated
Preferences success mutation always evaluated
Keychain success mutation always evaluated
Keychain failure mutation always evaluated
post-verification append mutation always evaluated
```

Required non-regression:

```text
PXRestoreResult.h diff: 0
PXRestoreResult.m diff: 0
AppDataBackupManager.h diff: 0
transaction/staging/plan/validator/resolver diff: 0
UI diff: 0
Makefile diff: 0
Keychain helper/bridge/script diff: 0
warning append sequence diff: 0
public selector diff: 0
```

## Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.14A-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. TASK-2.14 blocker summary;
4. Foundation assertion-elision risk;
5. before/after inventory of ten mutation-in-assert sites;
6. exact always-evaluated pattern used;
7. count proof for eight success, two failure, and one append calls;
8. assertion-enabled behavior proof;
9. `NS_BLOCK_ASSERTIONS` behavior proof;
10. ApplicationData success and post-warning proof;
11. all optional component success proofs;
12. Keychain success and warning-only failure proof;
13. final result mask/committed-unit implications;
14. warning sequence non-regression;
15. error/completion boundary non-regression;
16. result model byte-identity proof;
17. transaction/staging/planning byte-identity proof;
18. UI/Makefile/Keychain helper byte-identity proof;
19. full authorized source diff;
20. static gate table;
21. at least 45 explicit scenarios;
22. whitespace/CRLF/NUL audit;
23. build status and remaining risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff fec59661e8e171fd6404ad0dfc56e3c71e69b34c..HEAD --check
git diff --name-status fec59661e8e171fd6404ad0dfc56e3c71e69b34c..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase2(task-2.14A): make restore result mutations assertion independent
```

Stop after TASK-2.14A.

Do not begin Phase 3, Phase 4, Phase 5, or Phase 6.
