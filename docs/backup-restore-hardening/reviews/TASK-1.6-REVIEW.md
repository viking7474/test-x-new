# TASK-1.6 Review — Structured Clear Result

## Decision

**ACCEPTED**

TASK-1.6 is accepted as the immutable structured-result contract for later Clear migration.

## Reviewed baseline

```text
Commit: 81de2a7ef28f862f78a7ae55f0d8897066a85f94
Subject: task-1.6
Production additions:
  PXClearResult.h
  PXClearResult.m
Report:
  docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md
```

The commit also contains coordinator documentation and the TASK-1.5 review/specification baseline. No pre-existing production source was modified.

## Contract review

The public status model contains exactly:

```text
PXClearComponentStatusSucceeded = 1
PXClearComponentStatusSkipped   = 2
PXClearComponentStatusFailed    = 3
```

No pending, running, partial, unknown, cancelled or alias state exists.

The three immutable classes are present:

```text
PXClearFailure
PXClearComponentResult
PXClearResult
```

All classes are subclassing-restricted, conform only to `NSCopying`, expose readonly state, use private ivars and have unavailable `init`/`new`.

## Failure snapshot

`PXClearFailure` stores only copied and validated:

```text
domain
code
message
```

It does not retain `NSError`, `userInfo`, mutable dictionaries, paths or stack traces.

Domain and message reject invalid runtime types, empty/whitespace-only strings and embedded U+0000 without normalizing accepted input.

## Component result invariants

A component scope must be exactly one known `PXClearScope` bit:

```text
scope != 0
(scope & ~PXClearScopeKnownMask) == 0
(scope & (scope - 1)) == 0
```

Unit counts use the overflow-safe partition:

```text
succeededUnitCount <= attemptedUnitCount
failedUnitCount == attemptedUnitCount - succeededUnitCount
```

The implementation does not use unchecked `succeeded + failed` validation.

Status-specific rules match the specification:

- Succeeded: at least one attempted unit, all units succeeded, no failure snapshot.
- Skipped: zero units, no failure snapshot and a required detail.
- Failed: at least one attempted unit, at least one failed unit and a required failure snapshot.
- Partial success is represented by Failed with both successful and failed counts greater than zero.

## Aggregate invariants

`PXClearResult` requires:

- a runtime `PXClearRequest`;
- a nonempty runtime array;
- runtime component-result elements;
- no duplicate component scope;
- no unrequested scope;
- no missing requested scope;
- exact union equality with `request.scopes`.

Components are stored in fixed numeric scope order rather than caller order.

Succeeded, skipped and failed masks are derived internally, are pairwise disjoint and cover exactly the request mask.

Predicate semantics are exact:

```text
hasFailures == (failedScopes != 0)
allRequestedScopesSucceeded == (succeededScopes == request.scopes)
```

A skipped component is not a failure but prevents all-requested-scopes success.

`componentResultForScope:` rejects zero, multiple bits, unknown bits and valid known bits absent from the request.

## Value semantics

Each class:

- copies object/string/array inputs;
- has no setter or private readwrite redeclaration;
- returns `self` from `copyWithZone:`;
- implements equality and hash over all semantic public state.

Aggregate equality uses the request and canonical component array.

## Safety and scope

Source audit found no filesystem, command, resolver, validator, deletion, Keychain, UI, async or Clear execution behavior in the new model.

Existing production references outside `PXClearResult.h/.m` are zero for the result classes, status type and aggregate lookup/predicate symbols.

Protected source checksums remained unchanged. `git show --check 81de2a7`, current `git diff --check`, source trailing-whitespace checks and NUL audits passed.

## Build gate

```text
Build: PASSED — reported by project owner
Report GitHub Actions field: PENDING
```

The report correctly does not claim a local Objective-C runtime pass.

## Remaining boundary

TASK-1.6 defines immutable final-state semantics only. It does not decide how an aggregate maps to the legacy `BOOL` completion callback and does not authorize any destructive operation.

TASK-1.7 may now migrate only the primary application-data component. Extension/PluginKit, App Group and Keychain result integration remain locked.
