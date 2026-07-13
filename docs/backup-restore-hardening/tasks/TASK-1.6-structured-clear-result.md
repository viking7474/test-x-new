# TASK-1.6 — Structured `PXClearResult`

## Metadata

- Status: READY
- Phase: Phase 1 — Clear Data Safety Boundary
- Dependency: TASK-1.5 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md`
- Allowed production files: `PXClearResult.h`, `PXClearResult.m`
- Suggested commit: `phase1(task-1.6): add structured clear result`

## Objective

Introduce immutable structured output models for future Clear orchestration.

TASK-1.6 defines:

1. an immutable failure snapshot;
2. an immutable per-scope component outcome;
3. an immutable aggregate result covering every requested scope exactly once.

This task is contract-only. It must not execute Clear, import the result into existing callers, map the result to legacy completion callbacks, resolve containers, validate paths or mutate files.

## Required reading

Before changing source, read:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.5-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `PXClearRequest.h`
8. `PXClearRequest.m`
9. `PXResolvedContainer.h/.m`
10. `PXDataContainerResolver.h/.m`
11. `PXDestructivePathValidator.h/.m`
12. `AppDataCleaner.h`
13. the complete `AppDataCleaner.m`
14. `Makefile`

## Allowed changes

Create only:

```text
PXClearResult.h
PXClearResult.m
docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md
```

Do not modify any existing production source file.

Do not modify `Makefile`; root-level `*.m` wildcard inclusion already covers `PXClearResult.m`.

## Public header contract

`PXClearResult.h` must import:

```objc
#import <Foundation/Foundation.h>
#import "PXClearRequest.h"
```

Wrap declarations in `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`.

### Component status

Declare exactly:

```objc
typedef NS_ENUM(NSUInteger, PXClearComponentStatus) {
    PXClearComponentStatusSucceeded = 1,
    PXClearComponentStatusSkipped = 2,
    PXClearComponentStatusFailed = 3,
};
```

Do not add:

- pending;
- running;
- cancelled;
- partial;
- unknown;
- not-requested;
- application-bundle-specific status;
- aliases.

A partially successful component is represented as `PXClearComponentStatusFailed` with both successful and failed unit counts greater than zero.

## `PXClearFailure`

Declare exactly one immutable failure snapshot class:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXClearFailure : NSObject <NSCopying> {
@private
    NSString *_domain;
    NSInteger _code;
    NSString *_message;
}

@property (nonatomic, copy, readonly) NSString *domain;
@property (nonatomic, assign, readonly) NSInteger code;
@property (nonatomic, copy, readonly) NSString *message;

- (nullable instancetype)initWithDomain:(NSString *)domain
                                   code:(NSInteger)code
                                message:(NSString *)message
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
```

Do not expose `NSError`, `userInfo`, stack traces, filesystem paths or mutable dictionaries.

### Failure validation

`domain` and `message` must:

- be runtime `NSString` instances;
- be nonempty;
- contain at least one non-whitespace/newline character;
- contain no U+0000;
- be copied exactly without trim, normalization or rewriting.

`code` may be any `NSInteger`, including zero or negative values.

`copyWithZone:` returns `self`.

Equality and hash use all three fields.

## `PXClearComponentResult`

Declare exactly:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXClearComponentResult : NSObject <NSCopying> {
@private
    PXClearScope _scope;
    PXClearComponentStatus _status;
    NSUInteger _attemptedUnitCount;
    NSUInteger _succeededUnitCount;
    NSUInteger _failedUnitCount;
    NSString *_detail;
    PXClearFailure *_failure;
}

@property (nonatomic, assign, readonly) PXClearScope scope;
@property (nonatomic, assign, readonly) PXClearComponentStatus status;
@property (nonatomic, assign, readonly) NSUInteger attemptedUnitCount;
@property (nonatomic, assign, readonly) NSUInteger succeededUnitCount;
@property (nonatomic, assign, readonly) NSUInteger failedUnitCount;
@property (nonatomic, copy, readonly, nullable) NSString *detail;
@property (nonatomic, copy, readonly, nullable) PXClearFailure *failure;

- (nullable instancetype)initWithScope:(PXClearScope)scope
                                status:(PXClearComponentStatus)status
                    attemptedUnitCount:(NSUInteger)attemptedUnitCount
                    succeededUnitCount:(NSUInteger)succeededUnitCount
                       failedUnitCount:(NSUInteger)failedUnitCount
                                detail:(nullable NSString *)detail
                               failure:(nullable PXClearFailure *)failure
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
```

No convenience factories, setters, mutable builder or additional public state are permitted in TASK-1.6.

### Scope validation

A component scope must be exactly one known `PXClearScope` bit.

The implementation must require all of:

```objc
scope != 0
(scope & ~PXClearScopeKnownMask) == 0
(scope & (scope - 1)) == 0
```

Reject:

- zero;
- multiple known bits;
- unknown bits;
- known plus unknown bits.

### Status validation

Only the three declared enum values are valid.

### Count partition invariant

Counts must satisfy:

```text
succeededUnitCount <= attemptedUnitCount
failedUnitCount == attemptedUnitCount - succeededUnitCount
```

Use subtraction after the upper-bound check rather than unchecked addition, so overflow cannot make an invalid partition appear valid.

A unit is a logical component-owned operation or target. TASK-1.6 does not define filesystem-specific unit meaning; migration tasks must document their count policy.

### Detail validation

`detail` may be nil.

When non-nil, it must:

- be a runtime `NSString`;
- be nonempty;
- contain at least one non-whitespace/newline character;
- contain no U+0000;
- be copied exactly without trim or normalization.

### Failure object validation

When non-nil, `failure` must be a runtime `PXClearFailure` instance.

Do not accept arbitrary `NSError`, dictionary or object values.

### Status-specific invariants

#### Succeeded

For `PXClearComponentStatusSucceeded` require:

```text
attemptedUnitCount > 0
succeededUnitCount == attemptedUnitCount
failedUnitCount == 0
failure == nil
```

`detail` is optional.

#### Skipped

For `PXClearComponentStatusSkipped` require:

```text
attemptedUnitCount == 0
succeededUnitCount == 0
failedUnitCount == 0
failure == nil
detail != nil
```

A skipped component must include a nonempty validated detail explaining why no unit was attempted.

#### Failed

For `PXClearComponentStatusFailed` require:

```text
attemptedUnitCount > 0
failedUnitCount > 0
failure != nil
```

The general count partition invariant still applies. `succeededUnitCount` may be zero or greater than zero.

Therefore partial success is represented as:

```text
status = Failed
succeededUnitCount > 0
failedUnitCount > 0
```

`detail` is optional because the failure snapshot already contains a message.

### Component immutability and value semantics

- use only private ivars;
- assign ivars directly in the initializer;
- copy `detail` and `failure`;
- do not redeclare public properties as `readwrite`;
- do not add setters or mutation methods;
- do not conform to `NSMutableCopying`;
- `copyWithZone:` returns `self`;
- equality and hash use every public field.

## `PXClearResult`

Declare exactly:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXClearResult : NSObject <NSCopying> {
@private
    PXClearRequest *_request;
    NSArray<PXClearComponentResult *> *_componentResults;
    PXClearScope _succeededScopes;
    PXClearScope _skippedScopes;
    PXClearScope _failedScopes;
}

@property (nonatomic, copy, readonly) PXClearRequest *request;
@property (nonatomic, copy, readonly) NSArray<PXClearComponentResult *> *componentResults;
@property (nonatomic, assign, readonly) PXClearScope succeededScopes;
@property (nonatomic, assign, readonly) PXClearScope skippedScopes;
@property (nonatomic, assign, readonly) PXClearScope failedScopes;
@property (nonatomic, assign, readonly) BOOL hasFailures;
@property (nonatomic, assign, readonly) BOOL allRequestedScopesSucceeded;

- (nullable instancetype)initWithRequest:(PXClearRequest *)request
                        componentResults:(NSArray<PXClearComponentResult *> *)componentResults
    NS_DESIGNATED_INITIALIZER;

- (nullable PXClearComponentResult *)componentResultForScope:(PXClearScope)scope;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
```

Do not add an ambiguous `success` property. The two permitted predicates have exact meanings defined below.

### Aggregate input validation

`request` must be a runtime `PXClearRequest` instance.

`componentResults` must be a runtime `NSArray` and must not be empty.

Every element must be a runtime `PXClearComponentResult` instance.

For every component result:

- its scope must be included in `request.scopes`;
- its scope must not duplicate another result;
- its status determines exactly one derived mask.

The union of all component scopes must equal `request.scopes` exactly.

This means the aggregate contains exactly one result for every requested scope and no result for an unrequested scope.

Reject:

- missing requested scope;
- duplicate scope;
- unrequested scope;
- nil/non-array input;
- empty result array;
- non-component element.

### Canonical component ordering

Store `componentResults` sorted by numeric `scope` ascending.

Do not preserve caller order as semantic state.

The canonical order is:

```text
ApplicationData
ExtensionData
AppGroups
PluginKitData
Keychain
```

This ensures equality and hash are independent of input array ordering.

### Derived masks

During initialization derive:

- `succeededScopes` from components with status `Succeeded`;
- `skippedScopes` from components with status `Skipped`;
- `failedScopes` from components with status `Failed`.

The masks must be disjoint and their union must equal `request.scopes`.

Do not accept derived masks from callers.

### Predicate semantics

`hasFailures` means exactly:

```objc
failedScopes != 0
```

`allRequestedScopesSucceeded` means exactly:

```objc
succeededScopes == request.scopes
```

A skipped component:

- does not set `hasFailures`;
- prevents `allRequestedScopesSucceeded` from being true.

TASK-1.6 must not decide how these predicates map to the existing `BOOL success` completion callback. That policy belongs to migration/orchestration tasks.

### Scope lookup

`componentResultForScope:` returns the matching component result only when the input is exactly one known bit.

Return nil for:

- zero;
- multiple bits;
- unknown bits;
- a valid known bit not requested by this result.

The method must not mutate or rebuild the aggregate.

### Aggregate immutability and value semantics

- copy the request;
- copy the canonical array;
- rely only on immutable component elements;
- use private ivars;
- no setter, builder or mutation method;
- no private `readwrite` redeclaration;
- no `NSMutableCopying`;
- `copyWithZone:` returns `self`;
- equality and hash use `request` and canonical `componentResults`;
- derived masks/predicates must agree with those values.

## Forbidden behavior in the two new source files

Do not use or reference:

- `AppDataCleaner`;
- `PXResolvedContainer`;
- `PXDataContainerResolver`;
- `PXDestructivePathValidator`;
- `NSFileManager`;
- filesystem paths, UUIDs or metadata plist logic;
- `CommandRunner`;
- `NSTask`, `posix_spawn`, `system`, `popen` or shell commands;
- deletion, chmod, chown, rename or write APIs;
- Keychain/Security APIs;
- UIKit;
- `NSUserDefaults`;
- dispatch queues, locks, semaphores or async callbacks;
- timestamps or durations;
- logging buffers or stdout/stderr;
- `NSError` or `userInfo` as stored public state;
- JSON, plist, coding or serialization;
- mutable collections in public state;
- application-bundle or receipt outcome types.

Foundation collection and string APIs required for validation, sorting, copying and equality are allowed.

## No caller integration

Do not import, instantiate or reference `PXClearFailure`, `PXClearComponentResult`, `PXClearResult` or `PXClearComponentStatus` in any existing production source.

After TASK-1.6, existing production references outside `PXClearResult.h/.m` must be zero for:

```text
PXClearFailure
PXClearComponentResult
PXClearResult
PXClearComponentStatus
componentResultForScope:
allRequestedScopesSucceeded
```

Do not change:

- `AppDataCleaner.h/.m`;
- legacy completion callbacks;
- `PXClearRequest.h/.m`;
- resolver or validator files;
- application-bundle behavior;
- Backup, Restore, Keychain or UI;
- command-runner code.

## Baseline and protected files

Record initial:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -1 --oneline
```

Record SHA-256 before and after for:

- `PXClearRequest.h`
- `PXClearRequest.m`
- `PXResolvedContainer.h`
- `PXResolvedContainer.m`
- `PXDataContainerResolver.h`
- `PXDataContainerResolver.m`
- `PXDestructivePathValidator.h`
- `PXDestructivePathValidator.m`
- `AppDataCleaner.h`
- `AppDataCleaner.m`
- `CommandRunner.h`
- `CommandRunner.m`
- `AppGroupContainerResolver.h`
- `AppGroupContainerResolver.m`
- `AppDataBackupManager.h`
- `AppDataBackupManager.m`
- `Makefile`

All protected checksums must remain unchanged.

Commit `24cde1e` contains accumulated prior-task artifacts. Treat it as the baseline and do not rewrite or reformat prior files.

## Required report contents

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md
```

The report must include:

1. task metadata and baseline HEAD;
2. initial/final working-tree state;
3. allowed-file and protected-file audit;
4. exact public API for all three classes;
5. status enum proof;
6. failure validation and value semantics;
7. single-bit scope proof;
8. count-partition proof with overflow-safe reasoning;
9. status-specific invariant matrix;
10. partial-success representation;
11. detail/failure validation;
12. aggregate exact-coverage and duplicate rejection;
13. canonical ordering proof;
14. derived-mask proof;
15. exact predicate semantics;
16. scope lookup behavior;
17. copy/equality/hash strategy for all classes;
18. resource ownership table;
19. forbidden-token audit;
20. existing-production reference search;
21. protected checksum comparison;
22. scenario matrix;
23. complete source diff and diff-stat review;
24. whitespace, NUL, generated and binary audit;
25. remaining risks.

## Scenario matrix

At minimum cover:

1. valid failure snapshot;
2. invalid failure domain/message runtime type;
3. empty/whitespace/NUL failure strings;
4. any integer failure code;
5. succeeded single-scope component;
6. skipped component with detail;
7. failed component with all units failed;
8. failed component with partial success;
9. zero/multiple/unknown component scope;
10. invalid enum status;
11. invalid count partition;
12. succeeded status with zero attempts;
13. succeeded status with failure object;
14. skipped status without detail;
15. skipped status with nonzero counts;
16. failed status without failure snapshot;
17. failed status with zero failures;
18. mutable input strings changed after construction;
19. aggregate with all requested scopes succeeded;
20. aggregate with skipped scope and no failed scope;
21. aggregate with one failed scope;
22. aggregate with partial failed component;
23. aggregate missing a requested scope;
24. aggregate containing an unrequested scope;
25. aggregate duplicate scope;
26. aggregate supplied in reverse order;
27. lookup requested scope;
28. lookup unrequested/invalid scope;
29. copy/equality/hash for all classes;
30. existing Clear API remains unchanged.

All scenarios are static unless the project build/runtime environment actually executes them. Do not claim runtime PASS without evidence.

## Verification commands and gates

Run and record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXClearResult.h PXClearResult.m
git diff -- PXClearResult.h PXClearResult.m
```

For untracked new files, use no-index checks or an equivalent independent whitespace review.

Verify counts/tokens for:

- exactly one `PXClearComponentStatus` enum;
- exactly three status entries;
- exactly one interface/implementation for each of the three classes;
- no `readwrite`;
- no setter methods;
- no `NSMutableCopying`;
- no `NSError` stored/public contract;
- no prohibited subsystem references;
- zero existing-production references;
- no generated or binary files;
- no NUL bytes;
- zero trailing whitespace in new files/report.

## Acceptance checklist

- [ ] Only `PXClearResult.h/.m` are added as production source.
- [ ] Required report exists.
- [ ] Existing production source is unchanged.
- [ ] Status enum contains exactly Succeeded, Skipped and Failed.
- [ ] Failure snapshot is immutable and validated.
- [ ] Component scope is exactly one known bit.
- [ ] Count partition is overflow-safe.
- [ ] Status-specific invariants are enforced.
- [ ] Partial success is represented as Failed plus mixed counts.
- [ ] Aggregate covers every requested scope exactly once.
- [ ] Duplicate and unrequested scopes are rejected.
- [ ] Component array is stored in canonical scope order.
- [ ] Derived masks are disjoint and cover request scopes.
- [ ] Predicate semantics match the specification.
- [ ] Lookup method accepts only one known requested bit.
- [ ] All classes are immutable and have value semantics.
- [ ] No caller integration or behavior migration is added.
- [ ] Protected checksums remain unchanged.
- [ ] Whitespace/NUL/generated-artifact checks pass.
- [ ] GitHub Actions succeeds or owner explicitly confirms build.
- [ ] Agent stops after TASK-1.6.

## Required report ending

End the report with exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Stop condition

Stop after TASK-1.6.

Do not:

- implement TASK-1.7;
- import the result into `AppDataCleaner`;
- add a new Clear API;
- map result predicates to legacy completion success;
- resolve or validate containers;
- mutate files;
- change Keychain behavior.

TASK-1.7 may be specified only after TASK-1.6 source review, build gate and accepted coordinator review.
