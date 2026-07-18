# TASK-2.7 Review — Immutable Restore Plan

Implementation commit reviewed: `d9ab9013b5d637ceb71695003bbc7153ac78151c`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXRestorePlan.h
A PXRestorePlan.m
A docs/backup-restore-hardening/reports/TASK-2.7-REPORT.md
```

All protected production files are unchanged. The existing root-level `*.m` wildcard includes `PXRestorePlan.m`, so `Makefile` correctly remains unchanged.

## Accepted public contract

`PXRestorePlan.h` matches the required public surface:

- one fixed error domain;
- one fixed field-path key;
- exactly eight error codes;
- exactly three immutable item classes;
- one immutable `PXRestorePlan` class;
- one public plan factory;
- no public mutable setter or designated initializer;
- no staging, extraction, transaction or rollback API.

All four public classes are subclassing-restricted, expose readonly state, prohibit ordinary `init`/`new`, copy string and collection inputs and return `self` from `copyWithZone:`.

The plan retains the already accepted immutable snapshots:

- `PXResolvedContainer`;
- `PXVerifiedBackupArtifactSet`;
- `PXValidatedBackupArchiveSet`.

It does not retain the manifest dictionary.

## Pure in-memory planning boundary

`PXRestorePlan.m` imports only:

```objc
#import "PXRestorePlan.h"
#import "PXResolvedContainer.h"
#import "PXBackupArtifactVerifier.h"
#import "PXBackupArchiveValidator.h"
```

Independent token inspection found no filesystem, resolver, `CommandRunner`, process, shell, dispatch, Keychain execution, logging or mutation API in the plan source.

The builder consumes only the manifest and the three accepted snapshots supplied by its caller.

## Snapshot consistency

Plan construction fails closed unless:

- requested bundle identity is a nonempty NUL-free string;
- manifest bundle identity exactly matches the requested identity;
- the retained container is an ApplicationData `PXResolvedContainer`;
- its requested and metadata identifiers exactly match the bundle identity;
- its path and UUID are nonempty;
- the supplied canonical path exactly equals the model path;
- verified-artifact and validated-archive snapshots have the required concrete types.

Recorded manifest data path and UUID fields have zero authority in the plan.

## Source and archive authority

Every included component source is resolved through exact lookup in `PXVerifiedBackupArtifactSet`.

The following components also require membership in `PXValidatedBackupArchiveSet`:

- main ApplicationData;
- App Groups;
- profile AppData;
- global Safari;
- system-global Library items.

Preferences, Keychain and shared-system database files correctly use verified-file authority without tar-member validation.

No source is reconstructed from a backup directory or recorded artifact path.

## Semantic component plan

Accepted behavior includes:

- main data is always present and freezes exact model/path/UUID/archive/source;
- `options.includeAppGroups` is read as exact CFBoolean;
- App Group items preserve manifest order and use exact case-sensitive lookup;
- duplicate exact group identities fail at the later occurrence;
- Preferences and Keychain freeze verified source decisions only when included;
- Keychain's existing case-sensitive `platformFamily` substring and exact `in_app` behavior is frozen;
- profile AppData and global Safari recorded destination paths remain non-authoritative;
- absent/excluded additive sections create empty item arrays;
- system-global subdirectories are constrained to one safe UTF-8 component;
- shared-system database destinations are constrained to safe relative UTF-8 paths;
- duplicate exact relative destinations fail at the later occurrence;
- warning count and nonempty profile identifier are copied without retaining warning text.

The total item count across App Groups, system-global items and shared database items is overflow-checked against the fixed 100,000-record maximum before item construction.

## Restore integration

Restore calls the plan factory exactly once after:

1. manifest/schema/version acceptance;
2. exact requested bundle identity;
3. exact canonical ApplicationData destination resolution;
4. artifact-file verification;
5. archive-entry validation.

Plan construction precedes warnings allocation, `NSFileManager`/`CommandRunner`, debug writes, tar discovery, process termination, staging, extraction and target mutation.

Exact non-nil plan errors are propagated on the main queue; the generic plan-domain fallback is limited to the impossible nil-without-error state.

## Post-plan authority

After successful plan construction, the operational remainder of Restore has:

```text
direct manifest[...] reads: 0
direct verifiedArtifacts pathForArtifactName: calls: 0
direct validatedArchives containsArchiveName: calls: 0
```

Operational source decisions now use the plan for:

- main model/path/UUID/source;
- manifest warning count and profile ID;
- App Group inclusion and exact group lookup;
- profile AppData and global Safari sources;
- system-global and shared-database item loops;
- Preferences source;
- Keychain source, groups, method and in-app decision.

Dynamic destination behavior intentionally remains in the manager for App Groups, profile AppData, global Safari, mobile Library, Preferences and Keychain. TASK-2.7 does not claim final destination authorization for those components.

## Non-regression

The implementation preserves:

- supported versions `{2,3}`;
- manifest/schema error propagation;
- exact bundle-ID gate and code 304;
- exact main destination gate and code 303;
- artifact and archive validators;
- tar preference;
- main staging layout and extraction behavior;
- pre-mutation ApplicationData revalidation;
- wipe/clone/cp/chown behavior;
- optional-component ordering;
- warning-only Keychain failure;
- `PXRestoreResult` output.

Independent diff inspection confirms that the accepted manifest/version/destination helpers, Backup writer and extraction helpers were not modified. TASK-2.8 staging hardening remains absent.

## Independent gates

```text
git show --check: PASS
cumulative diff --check: PASS
protected production diff: PASS
error-domain exports: 1
field-path exports: 1
public error codes: 8
public immutable item classes: 3
public plan classes: 1
public plan factories: 1
public readwrite properties: 0
subclassing-restricted classes: 4
copyWithZone implementations: 4
pure-source forbidden tokens: 0
record limit: 100000
plan imports in manager: 1
Restore plan factory calls: 1
post-plan manifest reads: 0
post-plan verified-artifact lookups: 0
post-plan validated-archive lookups: 0
report scenarios: 140
new-file trailing whitespace: 0
new-file NUL bytes: 0
```

`AppDataBackupManager.m` retains 18 pre-existing trailing-whitespace lines. The implementation commit and cumulative baseline checks are clean.

## Build gate

The project-owner continuation is accepted as confirmation that the owner build gate passed. No GitHub Actions artifact or target-device runtime log is stored in this workspace, so compilation and full Restore execution were not independently reproduced here.

## Remaining boundary

The plan freezes semantic authority but current main-data staging remains predictable and weakly validated. TASK-2.8 must create a private unique staging workspace, require fail-closed extraction, validate the staged filesystem tree descriptor-relatively before process termination or target mutation, prohibit staged container metadata replacement, compare exact regular-file bytes with the accepted archive summary and clean the workspace safely. It must not add main-data commit/rollback, which remains TASK-2.11.
