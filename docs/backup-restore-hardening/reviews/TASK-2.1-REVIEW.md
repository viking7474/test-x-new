# TASK-2.1 REVIEW — Standalone Backup Manifest Schema Validator

## Verdict

Implementation commit reviewed: `e15f101cd70cc782274e42e608bce64d4981a578`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

Next task authorized: **TASK-2.2 — Enforce Supported Manifest Versions**

## Scope reviewed

The implementation commit contains exactly:

```text
A PXBackupManifestValidator.h
A PXBackupManifestValidator.m
A docs/backup-restore-hardening/reports/TASK-2.1-REPORT.md
```

No pre-existing production file changed. `Makefile` remained unchanged and the existing top-level `*.m` wildcard will include the new implementation.

## Public contract

The header matches the required contract:

- one exported error domain;
- one exported field-path key;
- exactly six closed error codes;
- one class method, `validateManifestObject:error:`;
- unavailable `init` and `new`;
- subclassing restricted;
- no file-path API, requested-bundle argument, supported-version argument, normalized output or mutable state.

## Error behavior

The implementation clears `*error` at entry. Success returns `YES` with no error. Failure returns `NO` through one centralized helper.

Error `userInfo` contains only:

```text
NSLocalizedDescriptionKey
PXBackupManifestValidatorErrorFieldPathKey
```

Descriptions describe rules without interpolating raw manifest values. Schema field failures use deterministic paths such as `$.manifestVersion`, `$.data.archive` and indexed array paths. Graph-wide failures use `$`.

## Graph-safety boundary

The complete reachable graph is checked before field-specific validation.

Accepted containers:

```text
NSDictionary
NSArray
```

Accepted leaves:

```text
NSString
NSNumber
NSDate
NSData
```

The implementation rejects unsupported leaves, non-string or malformed dictionary keys, cycles, excessive depth, excessive per-container entries and excessive aggregate traversal.

Independent source review confirmed:

- active recursion stack uses pointer identity;
- containers are removed after branch completion, so shared acyclic subobjects are allowed;
- dictionary keys are type-checked, then valid string keys are sorted with `compare:` before descending;
- depth 32 is accepted and depth 33 is rejected;
- 10,000 entries are accepted and 10,001 are rejected;
- 100,000 visited values/keys are accepted and an additional visit is rejected using an overflow-safe remaining-budget comparison.

## Primitive typing

Boolean fields require CFBoolean identity. Numeric substitutes such as ordinary `@0` or `@1` are not accepted merely through `boolValue`.

Integral fields:

- reject CFBoolean;
- accept only one-character integral Objective-C type encodings;
- reject float, double and decimal representations;
- apply nonnegative or positive range rules as appropriate.

`manifestVersion` must be positive and fit in signed `NSInteger`, but there is no supported-version set. Structurally valid values `1`, `2`, `3` and `999` are not rejected solely by TASK-2.1.

## Schema coverage

The validator implements the common v2/v3 operational envelope and validates:

- required root keys in fixed order;
- `data`;
- `applicationGroups`;
- `appGroups`;
- `preferences`;
- `keychain`;
- `profileAppData`;
- `globalSafari`;
- `artifacts`;
- `options`;
- optional v3 metadata;
- `restoreCompatibility`;
- `systemGlobalLibrary`;
- `sharedSystemDB`.

Duplicate detection reports the later occurrence. The required cross-field rules are present for included sections, artifact count, option-set disjointness, restore target/root identity and optional system arrays.

Unknown graph-safe keys remain allowed.

## Isolation review

`PXBackupManifestValidator.m` imports only:

```objc
#import "PXBackupManifestValidator.h"
```

Independent token audit found zero references to filesystem APIs, property-list file loading, command/process execution, Security, defaults, dispatch, Clear models, container resolvers or `AppDataBackupManager`.

No existing production source references the validator. TASK-2.1 therefore remains a standalone contract and does not alter Backup or Restore behavior.

## Independent gates

```text
git show --check --oneline e15f101: PASS
git diff 92b051f..e15f101 --check: PASS
protected production diff: PASS
validateManifestObject declarations: 1
validateManifestObject implementations: 1
error codes: 6
implementation imports: 1
existing production caller references: 0
supported/minimum/maximum version constants: 0
new source trailing-whitespace lines: 0
new source/report NUL bytes: 0
```

## Build gate

Build status: **PASSED — reported by project owner through continuation to the next task**.

The workspace does not contain the GitHub Actions artifact or an iOS/Foundation build output, so the coordinator did not independently reproduce compilation. This does not block acceptance because the owner advanced only after completing TASK-2.1 and the source/static gates are clean.

## Remaining risks

Device tests should still cover actual Foundation class-cluster behavior for CFBoolean, mutable cyclic collections and limit-boundary graphs. Concurrent mutation of an input graph during validation remains outside the standalone contract.

These risks do not justify changing TASK-2.1. Supported-version enforcement and caller integration belong to TASK-2.2.
