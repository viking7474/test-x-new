# TASK-2.14 — Add Structured Restore Result

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `9d046a406a5a346cab2a66d3fc27c71d702b9321`
- Previous tasks: TASK-2.13 and TASK-2.13A source review ACCEPTED
- Next phase: Phase 3 remains LOCKED

## Objective

Replace the existing mutable warnings-only `PXRestoreResult` with one immutable structured snapshot that truthfully records every known Restore component, planned unit counts, durable commit outcomes, rollback outcomes, warnings, and failures.

Preserve the existing public Restore selector and completion block type:

```objc
- (void)restoreBackupAtDirectory:(NSString *)backupDir
                         bundleID:(NSString *)bundleID
                          appName:(nullable NSString *)appName
                       completion:(void (^)(PXRestoreResult *_Nullable result,
                                            NSError *_Nullable error))completion;
```

Existing callers must continue to compile and may continue to read:

```objc
result.warnings
```

This task does not change UI presentation. Phase 5 remains responsible for displaying component and rollback state.

The result must not claim whole-Restore atomicity. Main data, profile data, Safari, App Groups, system-global items, shared databases, Preferences, and Keychain remain distinct domains in the accepted Restore order.

---

# Authorized production scope

Create:

```text
PXRestoreResult.h
PXRestoreResult.m
```

Modify:

```text
AppDataBackupManager.h
AppDataBackupManager.m
```

Create the report:

```text
docs/backup-restore-hardening/reports/TASK-2.14-REPORT.md
```

The implementation commit may contain only:

```text
PXRestoreResult.h
PXRestoreResult.m
AppDataBackupManager.h
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.14-REPORT.md
```

Do not modify:

- `PXMainDataRestoreTransaction.h/.m`;
- `PXAppGroupRestoreTransaction.h/.m`;
- `PXOptionalRestoreTransaction.h/.m`;
- `PXMainDataStaging.h/.m`;
- `PXAppGroupRestoreTargetPlan.h/.m`;
- `PXOptionalRestoreStaging.h/.m`;
- `PXRestorePlan.h/.m`;
- manifest/artifact/archive validators;
- resolved-container or destructive-path sources;
- `CommandRunner.h/.m`;
- `Makefile`;
- Backup implementation behavior;
- UI/controller files;
- Keychain helper, bridge, script, or protocol files;
- coordinator task/review/status/roadmap/decision/README files.

`Makefile` already compiles root-level `*.m` through a wildcard. Do not edit it merely to add `PXRestoreResult.m`.

---

# Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file, especially all three accepted transaction implementations and all staging/plan/validator sources.

---

# Part 1 — Move the result model to dedicated files

`AppDataBackupManager.h` currently declares:

```objc
@interface PXRestoreResult : NSObject
@property (nonatomic, copy) NSArray<NSString *> *warnings;
@end
```

and `AppDataBackupManager.m` contains an empty implementation.

Remove that declaration and implementation.

`AppDataBackupManager.h` must import exactly once:

```objc
#import "PXRestoreResult.h"
```

The new header must expose the complete structured model so existing callers importing only `AppDataBackupManager.h` still see `PXRestoreResult` and its `warnings` property.

There must be exactly one production declaration and one production implementation for each new public class.

---

# Part 2 — Exact Restore component set

In `PXRestoreResult.h`, define an `NS_OPTIONS(NSUInteger, PXRestoreComponent)` closed bit set with exactly eight component bits:

```text
PXRestoreComponentApplicationData
PXRestoreComponentProfileAppData
PXRestoreComponentGlobalSafari
PXRestoreComponentAppGroups
PXRestoreComponentSystemGlobal
PXRestoreComponentSharedSystemDatabases
PXRestoreComponentPreferences
PXRestoreComponentKeychain
```

Use deterministic bit values `1 << 0` through `1 << 7` in the order above.

Define:

```text
PXRestoreComponentAll
```

as the exact union of all eight known bits.

Reject zero as an individual component and reject unknown bits.

Canonical component order is exactly:

1. ApplicationData;
2. ProfileAppData;
3. GlobalSafari;
4. AppGroups;
5. SystemGlobal;
6. SharedSystemDatabases;
7. Preferences;
8. Keychain.

Do not add preflight, manifest, artifact, archive, debug, ownership, process-kill, post-verification, or “other” pseudo-components.

---

# Part 3 — Exact component status set

Define exactly four final statuses:

```text
PXRestoreComponentStatusSkipped
PXRestoreComponentStatusNotAttempted
PXRestoreComponentStatusSucceeded
PXRestoreComponentStatusFailed
```

Semantics:

## Skipped

The component was not requested by the accepted immutable Restore plan/current-device target plan.

- planned units: 0;
- committed units: 0;
- no failure;
- rollback not performed;
- no component warning.

## NotAttempted

The component was requested, but an earlier hard failure stopped Restore before this component began.

- planned units: greater than zero;
- committed units: 0;
- no component failure;
- rollback not performed.

This is not equivalent to Skipped.

## Succeeded

Every planned unit in the component reached its accepted durable success boundary.

- planned units: greater than zero;
- committed units: exactly planned units;
- no failure;
- rollback not performed;
- warnings may be present for cleanup, ownership correction, or post-verification.

## Failed

The component did not reach its accepted success boundary.

- planned units: greater than zero;
- committed units: 0;
- one immutable failure snapshot is required;
- rollback status may be not performed, completed, or incomplete;
- warnings may be present.

Do not add Pending or Running state. Every published result is final and immutable.

---

# Part 4 — Exact rollback status set

Define exactly three rollback statuses:

```text
PXRestoreRollbackStatusNotPerformed
PXRestoreRollbackStatusCompleted
PXRestoreRollbackStatusIncomplete
```

Semantics:

- `NotPerformed`: no rollback ran. This includes skipped/not-attempted/successful components, staging or factory failure before mutation, and Keychain because it has no filesystem transaction rollback contract.
- `Completed`: the component transaction reported `rollbackPerformed == YES` and `rollbackComplete == YES`.
- `Incomplete`: rollback was performed or required but did not complete safely. This includes `rollbackPerformed == YES && rollbackComplete == NO`.

Only a Failed component may publish Completed or Incomplete.

Do not infer rollback from an error description or error code. Use the retained typed transaction object flags.

---

# Part 5 — Immutable failure snapshot

Create subclassing-restricted `PXRestoreFailure : NSObject <NSCopying>`.

Readonly properties:

```objc
@property (nonatomic, copy, readonly) NSString *domain;
@property (nonatomic, assign, readonly) NSInteger code;
@property (nonatomic, copy, readonly) NSString *message;
```

Designated initializer:

```objc
- (nullable instancetype)initWithDomain:(NSString *)domain
                                   code:(NSInteger)code
                                message:(NSString *)message
    NS_DESIGNATED_INITIALIZER;
```

Unavailable:

```objc
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
```

Requirements:

- domain and message must be runtime `NSString` objects;
- values must be nonempty and contain no U+0000;
- domain maximum UTF-8 length: 255 bytes;
- message maximum UTF-8 length: 4096 bytes;
- copy input values;
- no `NSError`, `userInfo`, path, inode, device, digest, journal, transaction object, or mutable graph retained;
- `copyWithZone:` returns self;
- equality/hash use domain, code, and message.

For hard manager failures, snapshot the exact `NSError` passed to completion:

```text
domain = error.domain
code = error.code
message = error.localizedDescription
```

Do not copy arbitrary `NSError.userInfo` into the result.

---

# Part 6 — Immutable component result

Create subclassing-restricted `PXRestoreComponentResult : NSObject <NSCopying>`.

Readonly properties:

```objc
@property (nonatomic, assign, readonly) PXRestoreComponent component;
@property (nonatomic, assign, readonly) PXRestoreComponentStatus status;
@property (nonatomic, assign, readonly) NSUInteger plannedUnitCount;
@property (nonatomic, assign, readonly) NSUInteger committedUnitCount;
@property (nonatomic, assign, readonly) PXRestoreRollbackStatus rollbackStatus;
@property (nonatomic, copy, readonly) NSArray<NSString *> *warnings;
@property (nonatomic, copy, nullable, readonly) PXRestoreFailure *failure;
```

Designated initializer:

```objc
- (nullable instancetype)initWithComponent:(PXRestoreComponent)component
                                    status:(PXRestoreComponentStatus)status
                          plannedUnitCount:(NSUInteger)plannedUnitCount
                        committedUnitCount:(NSUInteger)committedUnitCount
                            rollbackStatus:(PXRestoreRollbackStatus)rollbackStatus
                                  warnings:(NSArray<NSString *> *)warnings
                                   failure:(nullable PXRestoreFailure *)failure
    NS_DESIGNATED_INITIALIZER;
```

Unavailable default init/new.

Fixed per-component planned-unit maximum:

```text
4096
```

Exact invariants:

### Skipped

```text
plannedUnitCount == 0
committedUnitCount == 0
rollbackStatus == NotPerformed
warnings.count == 0
failure == nil
```

### NotAttempted

```text
1 <= plannedUnitCount <= 4096
committedUnitCount == 0
rollbackStatus == NotPerformed
failure == nil
```

### Succeeded

```text
1 <= plannedUnitCount <= 4096
committedUnitCount == plannedUnitCount
rollbackStatus == NotPerformed
failure == nil
```

### Failed

```text
1 <= plannedUnitCount <= 4096
committedUnitCount == 0
failure != nil
rollbackStatus is one of the three exact known values
```

Warnings:

- runtime array;
- at most 4096 warnings;
- every warning is a nonempty `NSString`;
- no U+0000;
- maximum 4096 UTF-8 bytes each;
- preserve exact caller order and duplicate strings;
- deep-copy the array and strings;
- do not trim, normalize, sort, or deduplicate.

`copyWithZone:` returns self. Equality/hash use every property.

---

# Part 7 — Immutable aggregate PXRestoreResult

Create subclassing-restricted `PXRestoreResult : NSObject <NSCopying>`.

Readonly properties:

```objc
@property (nonatomic, assign, readonly) PXRestoreComponent requestedComponents;
@property (nonatomic, copy, readonly) NSArray<PXRestoreComponentResult *> *componentResults;
@property (nonatomic, assign, readonly) PXRestoreComponent succeededComponents;
@property (nonatomic, assign, readonly) PXRestoreComponent skippedComponents;
@property (nonatomic, assign, readonly) PXRestoreComponent notAttemptedComponents;
@property (nonatomic, assign, readonly) PXRestoreComponent failedComponents;
@property (nonatomic, copy, readonly) NSArray<NSString *> *warnings;
@property (nonatomic, assign, readonly) BOOL hasWarnings;
@property (nonatomic, assign, readonly) BOOL hasFailures;
@property (nonatomic, assign, readonly) BOOL hasIncompleteRollback;
@property (nonatomic, assign, readonly) BOOL allRequestedComponentsSucceeded;
```

The existing `warnings` property name and array type must remain available to all current callers, but it becomes readonly and immutable.

Designated initializer:

```objc
- (nullable instancetype)initWithRequestedComponents:(PXRestoreComponent)requestedComponents
                                    componentResults:(NSArray<PXRestoreComponentResult *> *)componentResults
                                            warnings:(NSArray<NSString *> *)warnings
    NS_DESIGNATED_INITIALIZER;
```

Lookup:

```objc
- (nullable PXRestoreComponentResult *)componentResultForComponent:(PXRestoreComponent)component;
```

Unavailable default init/new.

Aggregate invariants:

1. `requestedComponents` contains only known bits.
2. ApplicationData is always requested.
3. `componentResults` contains exactly eight objects.
4. Every known component appears exactly once.
5. No duplicate, missing, zero, multi-bit, or unknown component value.
6. Store results in canonical component order regardless of caller array order.
7. Skipped results are exactly the known components absent from `requestedComponents`.
8. NotAttempted, Succeeded, and Failed results are exactly requested components.
9. The four aggregate masks are pairwise disjoint.
10. Their union equals `PXRestoreComponentAll`.
11. `requestedComponents == succeededComponents | notAttemptedComponents | failedComponents`.
12. `skippedComponents == PXRestoreComponentAll & ~requestedComponents`.
13. `hasWarnings == warnings.count > 0`.
14. `hasFailures == failedComponents != 0`.
15. `hasIncompleteRollback` is true iff any component has rollback status Incomplete.
16. `allRequestedComponentsSucceeded == succeededComponents == requestedComponents`.

The aggregate `warnings` array uses the same validation/copy/order rules as component warnings and preserves the exact legacy public warning order.

Do not derive or reorder aggregate warnings by concatenating component arrays. Manager supplies the exact legacy ordered warning array explicitly.

`copyWithZone:` returns self. Equality/hash use every stored value.

---

# Part 8 — Pure result-model boundary

`PXRestoreResult.m` may import only:

```objc
#import "PXRestoreResult.h"
```

Foundation is available through the header.

The result model must not import or reference:

- `AppDataBackupManager`;
- Restore plans;
- staging workspaces;
- transaction objects;
- filesystem APIs;
- process APIs;
- `CommandRunner`;
- UI frameworks;
- Keychain frameworks;
- user defaults;
- notifications;
- dispatch queues;
- manifest dictionaries.

It is a pure immutable value-model implementation.

---

# Part 9 — Requested component and planned-unit calculation

After these existing gates succeed:

1. manifest/schema/version;
2. exact bundle identity;
3. exact ApplicationData target;
4. artifact verification;
5. archive validation;
6. immutable Restore plan;
7. tar discovery;
8. signed App Group entitlement read;
9. immutable App Group target plan;
10. optional destination plan;

but before main archive summary/staging, construct the structured result accumulator.

Precompute one immutable `effectiveSystemGlobalItems` array using the existing exact Safari duplicate rule:

```text
bundleID == com.apple.mobilesafari
subdirectory == Safari
restorePlan.includesGlobalSafari == YES
```

That exact duplicate remains excluded from the system-global transaction and from system-global planned-unit count.

Requested mask and planned units:

```text
ApplicationData:          always requested, 1 unit
ProfileAppData:           requested iff includesProfileAppData, 1 unit
GlobalSafari:             requested iff includesGlobalSafari, 1 unit
AppGroups:                requested iff appGroupTargetPlan.targets.count > 0,
                          units = exact physical target count
SystemGlobal:             requested iff effectiveSystemGlobalItems.count > 0,
                          units = effective item count
SharedSystemDatabases:    requested iff sharedDatabaseItems.count > 0,
                          units = item count
Preferences:              requested iff includesPreferences, 1 unit
Keychain:                 requested iff includesKeychain, 1 unit
```

Every planned count must be from accepted immutable plan/current-device target-plan state and must be between 1 and 4096.

Do not use manifest raw arrays, recorded paths, recorded UUIDs, filesystem enumeration count, successful staging count, or mutable loop progress as planned-unit authority.

Use `effectiveSystemGlobalItems` for both result planning and the existing system-global staging/transaction loop. Do not duplicate the skip test later with independent semantics.

If accumulator/result planning cannot be constructed from accepted plan state, fail before main staging with:

```text
domain: PXBackupErrorDomain
code: 321
description: Structured Restore result could not be constructed
result: nil
error: nonnil
```

Do not expose component counts or plan values in that error.

---

# Part 10 — Result availability boundary

Before the structured result accumulator exists, preserve current completion behavior:

```text
result == nil
error != nil
```

This applies to:

- invalid public parameters;
- manifest/schema/version failure;
- bundle mismatch;
- exact main target failure;
- artifact failure;
- archive failure;
- Restore-plan failure;
- tar missing;
- signed App Group entitlement failure;
- App Group target-plan failure;
- optional destination-plan failure;
- structured-result planning failure code 321.

After the accumulator exists, every hard failure must publish:

```text
result != nil
error != nil
```

The result must include:

- all previously committed component results;
- the current Failed component;
- all later requested components as NotAttempted;
- all absent components as Skipped;
- exact warnings accumulated before failure.

Do not return `nil` result on any post-boundary hard failure.

Do not change the exact `NSError` domain, code, localized description, precedence, or main-queue delivery currently used by the manager.

---

# Part 11 — Failure attribution

Attribute every post-boundary hard failure to exactly one component:

## ApplicationData

From accepted main archive summary validation through:

- main workspace creation;
- empty validation;
- extraction;
- stage validation;
- pre-mutation target revalidation;
- pre-commit stage equivalence;
- main transaction factory;
- main transaction commit.

## ProfileAppData

Every failure inside the included profile branch.

## GlobalSafari

Every failure inside the included global Safari branch.

## AppGroups

Every failure from App Group archive summary/staging/equivalence through App Group transaction factory and commit.

## SystemGlobal

Every failure while staging, destination revalidating, building, or committing the effective system-global batch.

## SharedSystemDatabases

Every failure while staging, destination revalidating, building, or committing the shared-database batch.

## Preferences

Every failure in Preferences staging, destination revalidation, item/factory, or transaction commit.

## Keychain

- Keychain staging failure is a hard component failure and returns result plus the existing error.
- Keychain helper/bridge execution failure remains warning-only for the legacy completion error, but the Keychain component status becomes Failed.

No hard post-boundary failure may be attributed to more than one component.

---

# Part 12 — Success timing and commit counts

Mark a component Succeeded only after its accepted success boundary:

## ApplicationData

After durable main transaction commit and existing main transaction/staging cleanup-warning collection.

## ProfileAppData

After durable optional transaction commit and existing cleanup-warning collection.

## GlobalSafari

After durable optional transaction commit and existing cleanup-warning collection.

## AppGroups

After durable App Group batch commit and existing transaction/staging cleanup-warning collection.

## SystemGlobal

After durable optional batch commit and existing cleanup-warning collection.

## SharedSystemDatabases

After durable optional batch commit and existing cleanup-warning collection.

## Preferences

After durable optional file transaction commit and existing cleanup-warning collection.

## Keychain

After helper/bridge execution returns success and staging cleanup warning collection completes.

Succeeded committed-unit count must equal planned-unit count.

Do not count staged, extracted, validated, quarantined, installed-but-not-durably-committed, rolled-back, ownership-corrected, or debug-verified units as committed.

---

# Part 13 — Rollback mapping

For each typed transaction commit failure:

```text
rollbackPerformed == NO
  -> PXRestoreRollbackStatusNotPerformed

rollbackPerformed == YES && rollbackComplete == YES
  -> PXRestoreRollbackStatusCompleted

rollbackPerformed == YES && rollbackComplete == NO
  -> PXRestoreRollbackStatusIncomplete
```

Apply this mapping to:

- main transaction;
- profile transaction;
- global Safari transaction;
- App Group batch transaction;
- system-global optional transaction;
- shared-database optional transaction;
- Preferences optional transaction.

Transaction factory/staging/destination failure uses NotPerformed.

Keychain always uses NotPerformed because TASK-2.13 explicitly excludes it from filesystem rollback.

Do not infer that a component succeeded because rollback completed. A rolled-back component is Failed with committed units zero.

---

# Part 14 — Exact warnings compatibility

Preserve every existing aggregate warning string and its current append order exactly.

This includes:

```text
Backup manifest contains ... warning(s); review manifest before relying on full fidelity restore
Backup profileId ... != active profileId ...
Main-data transaction cleanup failed; ownership correction was skipped
Main-data staging cleanup failed
Optional transaction cleanup failed
Optional-directory staging cleanup failed
App Group transaction cleanup failed; ownership correction was skipped
App Group staging cleanup failed
Optional-file staging cleanup failed
Restored shared system DBs (this may affect multiple apps)
Keychain restore failed (continuing)
Post-restore verification: data container metadata plist is missing
Post-restore verification: Library directory missing after restore
```

Do not rewrite punctuation, capitalization, spacing, or ordering.

Component-warning attribution:

- manifest warning count and profile-ID mismatch remain aggregate-only operation warnings;
- main transaction/staging and post-verification warnings also attach to ApplicationData;
- profile transaction/staging warnings attach to ProfileAppData;
- Safari transaction/staging warnings attach to GlobalSafari;
- App Group transaction/staging warnings attach to AppGroups;
- system-global transaction/staging warnings attach to SystemGlobal;
- shared transaction/staging/informational warnings attach to SharedSystemDatabases;
- Preferences transaction/staging warnings attach to Preferences;
- all warnings appended by Keychain helper/bridge execution plus explicit Keychain failure and Keychain staging cleanup warning attach to Keychain.

Because Keychain helper methods append directly to the aggregate mutable warnings array, snapshot the array count before Keychain execution and attach the exact appended suffix to the Keychain component without reordering or deduplication.

Do not add nested transaction/staging errors as new warnings.

---

# Part 15 — Keychain warning-only compatibility

Preserve existing Keychain execution behavior:

- staged input source;
- selected groups;
- method;
- in-app decision;
- overwrite behavior;
- helper/bridge invocation;
- warning-only execution failure;
- staging cleanup;
- debug behavior.

When execution returns `ok == NO`:

1. Keep appending exactly:

   ```text
   Keychain restore failed (continuing)
   ```

2. Publish Keychain component as Failed.
3. Use a synthetic immutable failure snapshot:

   ```text
   domain: PXBackupErrorDomain
   code: 322
   message: Keychain restore failed
   rollback: NotPerformed
   committedUnitCount: 0
   ```

4. Continue Restore.
5. Final completion error remains `nil` unless a later existing hard failure occurs.

This task does not convert Keychain helper failure into a hard manager error and does not claim per-item rollback or exact partial Keychain counts.

If Keychain staging itself fails, use the exact existing hard `NSError`, mark Keychain Failed, publish the structured result, and return.

---

# Part 16 — Post-restore verification

Preserve current post-restore checks and warning-only behavior.

The two existing warnings:

```text
Post-restore verification: data container metadata plist is missing
Post-restore verification: Library directory missing after restore
```

remain in their existing aggregate order at the end of Restore and also attach to ApplicationData.

They do not change ApplicationData from Succeeded to Failed because current behavior treats them as warnings after durable main commit.

Do not add new postcondition failures in TASK-2.14.

---

# Part 17 — Completion semantics

Preserve the public selector and block signature byte-for-byte except for nullability formatting required by the imported result header.

Completion rules:

## Invalid public parameters

Preserve current synchronous completion behavior.

## Async pre-result-boundary hard failure

```text
result == nil
error != nil
main queue
exactly once
```

## Async post-result-boundary hard failure

```text
result != nil
error != nil
main queue
exactly once
```

## Completed Restore with all requested components succeeded

```text
result != nil
error == nil
allRequestedComponentsSucceeded == YES
```

## Completed Restore with Keychain warning-only failure

```text
result != nil
error == nil
hasFailures == YES
failedComponents includes Keychain
allRequestedComponentsSucceeded == NO
notAttemptedComponents == 0
```

Do not add a second callback or progress callback.

Do not dispatch completion from transaction classes or result-model code.

---

# Part 18 — Existing caller compatibility

Production UI/controller diff must remain zero:

```text
AppDataBackupRestoreViewController.m
ProjectXViewController.m
all other UI/controller files
```

These current expressions must still compile:

```objc
PXRestoreResult *result
result.warnings.count
for (NSString *warning in result.warnings)
```

Do not change alert titles, messages, RRS flow, automatic respring behavior, manifest-restored markers, or caller error handling. Phase 5 owns UI interpretation of structured component and rollback states.

The result may now be nonnil together with a nonnil error. Existing callers that ignore the result on error remain source-compatible.

---

# Part 19 — Preserve accepted Restore execution

Do not change:

- manifest/schema/version handling;
- exact requested-bundle gate;
- destination resolution or canonical validation;
- artifact verification;
- archive validation;
- immutable Restore plan;
- tar preference;
- debug file behavior;
- first process-kill timing;
- source staging;
- transaction prepare/commit/rollback behavior;
- stale recovery;
- cleanup semantics;
- ownership/chmod behavior;
- optional destination authority;
- component order;
- Keychain helper behavior;
- post-restore process kill;
- Backup behavior.

High-level order remains exactly:

```text
ApplicationData
ProfileAppData
GlobalSafari
AppGroups
SystemGlobal
SharedSystemDatabases
Preferences
Keychain
post-restore verification
```

TASK-2.14 observes and records outcomes. It does not redesign those operations.

---

# Part 20 — Failure/result consistency

For every post-boundary hard failure:

- the returned `NSError` and failed component `PXRestoreFailure` must have equal domain, code, and localized message;
- exactly one component is Failed for the current hard failure;
- prior durable components remain Succeeded;
- later requested components remain NotAttempted;
- absent components remain Skipped;
- committed-unit count is never inferred from staging progress;
- a completed rollback does not erase the failure;
- an incomplete rollback sets `hasIncompleteRollback == YES`;
- aggregate warning order is preserved up to the failure point.

If a prior warning-only Keychain failure exists and a later hard failure were ever added in future code, the result may contain more than one failed component. Current TASK-2.14 flow has no hard component after Keychain.

---

# Part 21 — Static acceptance gates

Required production diff:

```text
A PXRestoreResult.h
A PXRestoreResult.m
M AppDataBackupManager.h
M AppDataBackupManager.m
A TASK-2.14-REPORT.md
```

All other production diff: zero.

## Public result model

```text
component bits:                         8
all-mask:                               1
component statuses:                    4
rollback statuses:                     3
public result classes:                 3
public readwrite properties:           0
default init/new availability:         0
subclassing-restricted classes:        3
NSCopying classes:                     3
```

## Model placement

```text
PXRestoreResult declaration in AppDataBackupManager.h: 0
PXRestoreResult implementation in AppDataBackupManager.m: 0
PXRestoreResult.h import in manager header:             1
PXRestoreResult model implementations in new .m:        3
```

## Restore method

```text
public selector changes:                       0
pre-boundary nil-result error behavior:        retained
post-boundary nil-result hard completions:     0
post-boundary result+error completions:         all hard branches
success result construction:                   1
synthetic Keychain failure code 322:           1
structured-result construction error code 321: 1
```

## Component accounting

```text
known component results in every result:       8
ApplicationData planned units:                 1
physical App Group target count authority:     1
effective system-global item array:            1
shared DB plan count authority:                1
Keychain warning-only Failed mapping:          1
```

## Rollback

Typed rollback flag mapping must be present for all seven transactional component domains and absent for Keychain.

## Warning compatibility

Every exact baseline aggregate warning literal must retain the same occurrence count and text.

## Forbidden changes

```text
UI/controller diff:                    0
transaction source diff:               0
staging source diff:                   0
plan/validator/resolver diff:          0
Makefile diff:                         0
Backup flow change:                    0
Phase 3 implementation:                0
Keychain helper/bridge/script diff:    0
```

---

# Part 22 — Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.14-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected before/after SHA-256 inventory;
3. old mutable result inventory;
4. exact eight-component enum;
5. exact four statuses;
6. exact three rollback statuses;
7. `PXRestoreFailure` invariants;
8. `PXRestoreComponentResult` invariant matrix;
9. aggregate exact-coverage and mask proof;
10. immutable copy/equality/hash proof;
11. pure model-source boundary;
12. requested-mask and planned-unit derivation table;
13. effective Safari/system-global duplicate proof;
14. result availability boundary;
15. every pre-boundary completion inventory;
16. every post-boundary hard completion inventory;
17. component failure-attribution table;
18. component success-boundary table;
19. seven-domain rollback mapping table;
20. Keychain warning-only structured failure proof;
21. aggregate/component warning attribution and exact-order proof;
22. post-verification warning behavior;
23. existing caller compatibility;
24. no UI change proof;
25. no execution-order or transaction behavior change proof;
26. exact completion-thread/count proof;
27. code 321 and code 322 contracts;
28. full authorized source diff;
29. static/forbidden-token gate table;
30. at least 220 explicit scenarios;
31. whitespace/CRLF/NUL audit;
32. build status and remaining runtime risks.

Scenarios must cover at least:

- every model initializer invalid combination;
- unknown bits/statuses/rollback values;
- duplicate/missing/canonical-order components;
- skipped/not-attempted distinction;
- warning validation and duplicate preservation;
- every pre-boundary failure;
- every component staging/factory/commit failure;
- rollback not performed/completed/incomplete for each transaction domain;
- cleanup warning after durable success;
- Keychain helper failure with nil completion error;
- Keychain staging hard failure;
- success with all components;
- success with absent optional components;
- result plus error compatibility;
- UI zero diff;
- transaction/staging/plan byte identity;
- completion exactly once/main queue;
- result construction failure before mutation;
- no whole-Restore atomicity claim.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

---

# Post-commit gates

Run and record:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 9d046a406a5a346cab2a66d3fc27c71d702b9321..HEAD --check
git diff --name-status 9d046a406a5a346cab2a66d3fc27c71d702b9321..HEAD
git status --short --untracked-files=all
```

Run the strongest available Objective-C compile gate. GitHub Actions/Theos is the authoritative build gate.

Suggested commit:

```text
phase2(task-2.14): add structured restore result
```

Stop after TASK-2.14 implementation, report, and implementation commit.

Do not begin Phase 3, Phase 4, Phase 5, or Phase 6.
