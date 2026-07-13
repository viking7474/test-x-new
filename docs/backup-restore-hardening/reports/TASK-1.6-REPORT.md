# TASK-1.6 Report ? Structured Clear Result

## 1. Task metadata and scope

| Field | Value |
|---|---|
| Task | TASK-1.6 |
| Specification | `docs/backup-restore-hardening/tasks/TASK-1.6-structured-clear-result.md` |
| Baseline HEAD | `24cde1e978ca914d49cd1ae6427085cc3e3389c1` |
| Baseline subject | `24cde1e task 1.5` |
| Production files created | `PXClearResult.h`, `PXClearResult.m` |
| Existing production files modified | None |
| Report | `docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md` |
| Runtime classification | STATIC REVIEW |
| Suggested status | READY_FOR_REVIEW |

TASK-1.6 adds immutable final result contracts only. It does not execute Clear, add a Clear API, alter legacy completion semantics, resolve or validate containers, mutate files, change Keychain behavior, or begin TASK-1.7.

## 2. Required reading

The full 672-line specification was read before source creation. Required baseline content was then read or traversed completely:

- `docs/backup-restore-hardening/README.md`
- `docs/backup-restore-hardening/STATUS.md`
- `docs/backup-restore-hardening/DECISIONS.md`
- `docs/backup-restore-hardening/reviews/TASK-1.5-REVIEW.md`
- `docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md`
- `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
- `PXClearRequest.h/.m`
- `PXResolvedContainer.h/.m`
- `PXDataContainerResolver.h/.m`
- `PXDestructivePathValidator.h/.m`
- `AppDataCleaner.h`
- `complete AppDataCleaner.m (6,388 lines / 328,347 bytes)`
- `Makefile`

Accepted decisions D-063 through D-070 establish immutable final snapshots, the closed three-status model, stable failure values, subtraction-based count partitions, exact canonical aggregate coverage, skipped predicate semantics, no legacy completion mapping, and no caller migration in this task.

## 3. Initial working tree and HEAD

Initial `git status --short --untracked-files=all`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.5-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.6-structured-clear-result.md
```

Repository identity:

```text
git rev-parse HEAD: 24cde1e978ca914d49cd1ae6427085cc3e3389c1
git log -1 --oneline: 24cde1e task 1.5
```

All initial status entries were coordinator-owned documentation/review/task baseline. No production file was modified at task start.

## 4. Allowed-file and Makefile audit

| File | Action |
|---|---|
| `PXClearResult.h` | Created |
| `PXClearResult.m` | Created |
| `docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md` | Created |
| Existing production source | Not modified |
| `Makefile` | Not modified |

The existing Makefile evidence is:

```make
ProjectX_FILES = $(wildcard *.m) $(wildcard common/*.m)
ProjectX_CFLAGS = -fobjc-arc ...
```

Therefore the root-level implementation is included automatically under ARC without a Makefile edit.

## 5. Exact public API

```objc
#import <Foundation/Foundation.h>
#import "PXClearRequest.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PXClearComponentStatus) {
    PXClearComponentStatusSucceeded = 1,
    PXClearComponentStatusSkipped = 2,
    PXClearComponentStatusFailed = 3,
};

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

NS_ASSUME_NONNULL_END
```

The header imports Foundation and `PXClearRequest.h` exactly, and wraps declarations in `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`. No additional public class, property, initializer, factory, builder, serialization API, success alias, callback, timestamp or behavior method is exposed.

## 6. Status enum proof

The enum appears exactly once and has exactly three entries:

| Value | Entry |
|---:|---|
| 1 | `PXClearComponentStatusSucceeded` |
| 2 | `PXClearComponentStatusSkipped` |
| 3 | `PXClearComponentStatusFailed` |

There is no pending, running, cancelled, partial, unknown, not-requested or alias entry. There is no ambiguous `success` or `isSuccessful` property.

## 7. PXClearFailure validation and value semantics

`domain` and `message` each require: runtime `NSString`, length > 0, at least one non-whitespace/newline character, and no U+0000. Accepted input is copied exactly. Source contains no trim, case conversion, normalization or rewriting call.

`code` is assigned directly with no range/sign restriction, so every `NSInteger` value is representable. The model stores only domain, code and message; it does not retain `NSError`, `userInfo`, stack traces, paths or mutable dictionaries.

Copy returns self. Equality requires exact class and compares domain/code/message. Hash folds the same three fields.

## 8. Single-bit scope proof

The shared scope predicate requires all three expressions:

```objc
scope != 0
(scope & ~PXClearScopeKnownMask) == 0
(scope & (scope - 1)) == 0
```

This rejects zero, multiple known bits, unknown bits, and known-plus-unknown combinations. The same predicate is reused by component initialization and aggregate lookup.

## 9. Count partition and overflow reasoning

Validation order is:

```objc
if (succeededUnitCount > attemptedUnitCount ||
    failedUnitCount != attemptedUnitCount - succeededUnitCount) {
    return nil;
}
```

The upper-bound check is evaluated first with short-circuit `||`. Subtraction is therefore performed only when `succeededUnitCount <= attemptedUnitCount`. No unchecked `succeeded + failed` expression exists, so unsigned addition overflow cannot make an invalid partition appear valid.

## 10. Status-specific invariant matrix

| Status | Attempts | Succeeded | Failed | Failure | Detail | Result |
|---|---|---|---|---|---|---|
| Succeeded | `> 0` | `== attempted` | `0` | nil | optional validated string | Accept |
| Succeeded | `0` or mixed/failed counts | any | any | any | any | Reject |
| Succeeded | valid counts | all | 0 | nonnil | any | Reject |
| Skipped | `0` | `0` | `0` | nil | required validated string | Accept |
| Skipped | any nonzero count | any | any | any | any | Reject |
| Skipped | all zero | 0 | 0 | nil | nil/invalid | Reject |
| Failed | `> 0` | `0...attempted-1` | `> 0` | required runtime PXClearFailure | optional validated string | Accept |
| Failed | zero attempts/zero failed units | any | any | any | any | Reject |
| Failed | valid failed partition | any | > 0 | nil/wrong type | any | Reject |

The general exact partition applies before every status-specific rule.

## 11. Partial-success representation

A partially successful component is represented only as:

```text
status = PXClearComponentStatusFailed
succeededUnitCount > 0
failedUnitCount > 0
```

The component contributes its scope to `failedScopes`. There is no Partial enum or separate partial mask.

## 12. Detail and failure validation

`detail` may be nil except for Skipped. A nonnil detail uses the same runtime/nonempty/non-whitespace/NUL validation and is copied without normalization. A nonnil failure must be a runtime `PXClearFailure`; arbitrary errors, dictionaries and objects are rejected.

## 13. Aggregate exact coverage

Aggregate initialization requires a runtime `PXClearRequest`, a runtime nonempty `NSArray`, and only runtime `PXClearComponentResult` elements. Each component scope is checked as one known bit, must be included in the request, and must not already be present in the seen mask.

After iteration:

```objc
seenScopes == request.scopes
```

Therefore missing requested bits, duplicate bits and unrequested bits all fail closed. The aggregate has exactly one final component for every requested scope.

## 14. Canonical component ordering

Caller order is not stored. The implementation walks a fixed scope sequence:

```text
ApplicationData (1)
ExtensionData (2)
AppGroups (4)
PluginKitData (8)
Keychain (16)
```

For each requested scope it locates the validated component and adds it to a new immutable array using `arrayByAddingObject:`. The canonical count is rechecked against input count before storage. No comparator callback or mutable collection is used.

## 15. Derived-mask proof

During the validation pass, each component status contributes its one scope bit to exactly one local mask. Before object creation the implementation explicitly verifies:

- succeeded/skipped disjoint;
- succeeded/failed disjoint;
- skipped/failed disjoint;
- `(succeeded | skipped | failed) == request.scopes`.

The masks are not accepted from callers and are directly assigned only after all checks and canonicalization pass.

## 16. Exact predicate semantics

```objc
- (BOOL)hasFailures {
    return _failedScopes != 0;
}

- (BOOL)allRequestedScopesSucceeded {
    return _succeededScopes == _request.scopes;
}
```

A skipped scope does not set `hasFailures`, but it prevents the succeeded mask from equaling the request mask. No policy maps either predicate to the legacy BOOL completion.

## 17. Scope lookup behavior

`componentResultForScope:` first applies the exact one-known-bit predicate, then requires membership in `_request.scopes`. Invalid or unrequested inputs return nil. A valid requested bit scans the immutable canonical array and returns the matching component without rebuilding or mutating the aggregate.

## 18. Copy, equality and hash

| Class | Copy | Equality fields | Hash fields |
|---|---|---|---|
| `PXClearFailure` | self | domain, code, message | domain, code, message |
| `PXClearComponentResult` | self | scope, status, three counts, detail, failure | same seven fields |
| `PXClearResult` | self | request, canonical component array | request, canonical component array |

Result masks and predicates are deterministic derivatives of request + canonical components, so they are not independent semantic inputs. Canonicalization makes result equality/hash independent of caller array order.

## 19. Resource ownership

| Resource/input | Ownership strategy | Cleanup |
|---|---|---|
| Failure domain/message | `copy` into private ivars | ARC |
| Component detail | `copy` into private ivar | ARC |
| Component failure | `copy`; immutable value returns self | ARC |
| Aggregate request | `copy`; immutable request returns self | ARC |
| Aggregate component array | independently canonicalized then copied | ARC |
| Component elements | immutable values retained by copied array | ARC |
| File descriptors/processes/locks/semaphores/caches | None | Not applicable |

All ivars are private and assigned directly in designated initializers. There are no setters, readwrite redeclarations, mutation methods, mutable builders, singletons or caches.

## 20. Forbidden-token audit

Only these imports exist:

```text
#import <Foundation/Foundation.h>
#import "PXClearRequest.h"
```

| Forbidden token/API | Count in PXClearResult.h/.m |
|---|---:|
| `AppDataCleaner` | 0 |
| `PXResolvedContainer` | 0 |
| `PXDataContainerResolver` | 0 |
| `PXDestructivePathValidator` | 0 |
| `NSFileManager` | 0 |
| `CommandRunner` | 0 |
| `NSTask` | 0 |
| `posix_spawn` | 0 |
| `system(` | 0 |
| `popen(` | 0 |
| `fileExistsAtPath` | 0 |
| `contentsOfDirectory` | 0 |
| `removeItemAtPath` | 0 |
| `createDirectoryAtPath` | 0 |
| `writeToFile` | 0 |
| `chmod` | 0 |
| `chown` | 0 |
| `rename(` | 0 |
| `unlink(` | 0 |
| `rmdir(` | 0 |
| `SecItem` | 0 |
| `Security/Security` | 0 |
| `UIKit` | 0 |
| `UIApplication` | 0 |
| `NSUserDefaults` | 0 |
| `dispatch_` | 0 |
| `pthread_` | 0 |
| `NSLock` | 0 |
| `NSCondition` | 0 |
| `semaphore` | 0 |
| `completion` | 0 |
| `callback` | 0 |
| `NSDate` | 0 |
| `CFAbsoluteTime` | 0 |
| `duration` | 0 |
| `timestamp` | 0 |
| `NSError` | 0 |
| `userInfo` | 0 |
| `NSJSON` | 0 |
| `JSON` | 0 |
| `NSPropertyList` | 0 |
| `plist` | 0 |
| `NSCoding` | 0 |
| `NSSecureCoding` | 0 |
| `encodeWithCoder` | 0 |
| `initWithCoder` | 0 |
| `UUID` | 0 |
| `metadata` | 0 |
| `Bundle/Application` | 0 |
| `Receipt` | 0 |

Additional mutation/normalization counts are zero for `readwrite`, setter methods, `NSMutable`, `NSMutableCopying`, trim, lower/uppercase and Unicode normalization methods. The implementation contains no filesystem path, UUID, metadata, command, deletion/write/permission, Security, UI, defaults, dispatch, lock, semaphore, callback, timestamp/duration, serialization/coding, application-bundle or receipt logic.

## 21. Existing-production reference proof

A search of 188 existing production source files (`.h`, `.m`, `.mm`, `.xm`, `.c`, `.cc`, `.cpp`), excluding the two new result files, returned:

| Symbol | References |
|---|---:|
| `PXClearFailure` | 0 |
| `PXClearComponentResult` | 0 |
| `PXClearResult` | 0 |
| `PXClearComponentStatus` | 0 |
| `componentResultForScope:` | 0 |
| `allRequestedScopesSucceeded` | 0 |

No existing caller imports, instantiates, accepts, returns or queries the result model. `AppDataCleaner`, UI, Backup, Restore, Keychain and legacy completion code are untouched.

## 22. Protected checksum comparison

| Protected file | Initial SHA-256 | Final SHA-256 | Equal |
|---|---|---|---|
| `PXClearRequest.h` | `D87402EE3720F1723977E4DEB3D78BC1DE87362948DFE585B5ED98F6447AE26B` | `D87402EE3720F1723977E4DEB3D78BC1DE87362948DFE585B5ED98F6447AE26B` | Yes |
| `PXClearRequest.m` | `AFC763AFC3306D422EF67EF3BD28A2A1A5741A64EA6078EE28F56F5D5901C790` | `AFC763AFC3306D422EF67EF3BD28A2A1A5741A64EA6078EE28F56F5D5901C790` | Yes |
| `PXResolvedContainer.h` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | Yes |
| `PXResolvedContainer.m` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | Yes |
| `PXDataContainerResolver.h` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | Yes |
| `PXDataContainerResolver.m` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | Yes |
| `PXDestructivePathValidator.h` | `542E158A4F04BF50125E0064FBEBF02AC32F1DE07508C3F32058E770F75A3C0A` | `542E158A4F04BF50125E0064FBEBF02AC32F1DE07508C3F32058E770F75A3C0A` | Yes |
| `PXDestructivePathValidator.m` | `F275A60BE5CAB58E5D06DB3DD0987948F5EAB65DDD7E35E35E45927D238877CB` | `F275A60BE5CAB58E5D06DB3DD0987948F5EAB65DDD7E35E35E45927D238877CB` | Yes |
| `AppDataCleaner.h` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | Yes |
| `AppDataCleaner.m` | `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8` | `4642AE2482AF113E6C68FE89E2DC1FF2D04667E33BE2D2BD80E932F8D4BDC1D8` | Yes |
| `CommandRunner.h` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | Yes |
| `CommandRunner.m` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | Yes |
| `AppGroupContainerResolver.h` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | Yes |
| `AppGroupContainerResolver.m` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | Yes |
| `AppDataBackupManager.h` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | Yes |
| `AppDataBackupManager.m` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | Yes |
| `Makefile` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | Yes |

`git diff --exit-code -- <all protected files>` returned 0 with empty output. This directly proves that `PXClearRequest.h/.m`, `AppDataCleaner.h/.m`, resolver/validator files, CommandRunner, Backup manager and Makefile were not changed.

## 23. Scenario matrix

| # | Scenario | Expected/final result | Evidence | Classification |
|---:|---|---|---|---|
| 1 | Valid failure snapshot | Accepted; domain/code/message preserved. | Both strings pass runtime/nonempty/non-whitespace/NUL checks; code is directly assigned. | STATIC REVIEW |
| 2 | Failure domain/message has non-string runtime type | Rejected with nil. | Required-string helper begins with runtime `NSString` validation. | STATIC REVIEW |
| 3 | Failure string is empty, whitespace-only or contains U+0000 | Rejected with nil. | All three conditions are explicitly checked. | STATIC REVIEW |
| 4 | Failure code is zero, negative or positive | Accepted. | No range or sign validation is applied to `NSInteger code`. | STATIC REVIEW |
| 5 | Mutable domain/message changes after construction | Stored values remain unchanged. | Both inputs are copied before storage. | STATIC REVIEW |
| 6 | Succeeded single-scope component | Accepted when attempts > 0, all attempted units succeeded, zero failed units and nil failure. | General partition and Succeeded-specific invariants both pass. | STATIC REVIEW |
| 7 | Skipped component with validated detail | Accepted with all counts zero and nil failure. | Skipped requires nonnil validated detail. | STATIC REVIEW |
| 8 | Failed component with all units failed | Accepted when attempts > 0, failed > 0 and failure snapshot exists. | Failed-specific invariants permit zero succeeded units. | STATIC REVIEW |
| 9 | Failed component with partial success | Accepted as Failed with both succeeded and failed counts > 0. | No Partial status exists; exact partition permits mixed counts. | STATIC REVIEW |
| 10 | Component scope is zero | Rejected. | Single-bit helper requires `scope != 0`. | STATIC REVIEW |
| 11 | Component scope contains multiple known bits | Rejected. | `scope & (scope - 1)` is nonzero. | STATIC REVIEW |
| 12 | Component scope is an unknown bit | Rejected. | Unknown-mask check fails. | STATIC REVIEW |
| 13 | Component scope mixes known and unknown bits | Rejected. | Unknown-mask check fails before storage. | STATIC REVIEW |
| 14 | Component status is outside 1, 2, 3 | Rejected. | Status helper accepts exactly Succeeded, Skipped and Failed. | STATIC REVIEW |
| 15 | Succeeded units exceed attempted units | Rejected before subtraction. | Upper-bound guard runs before `attempted - succeeded`. | STATIC REVIEW |
| 16 | Failed count does not equal attempted minus succeeded | Rejected. | Exact subtraction partition check fails. | STATIC REVIEW |
| 17 | Overflow-shaped count input | Rejected safely. | No unchecked addition is used; `succeeded > attempted` is evaluated first. | STATIC REVIEW |
| 18 | Succeeded status with zero attempts | Rejected. | Succeeded requires `attemptedUnitCount > 0`. | STATIC REVIEW |
| 19 | Succeeded status with failure snapshot | Rejected. | Succeeded requires `failure == nil`. | STATIC REVIEW |
| 20 | Skipped status without detail | Rejected. | Skipped requires nonnil validated detail. | STATIC REVIEW |
| 21 | Skipped status with nonzero counts | Rejected. | All three counts must be zero. | STATIC REVIEW |
| 22 | Failed status without failure snapshot | Rejected. | Failed requires runtime `PXClearFailure`. | STATIC REVIEW |
| 23 | Failed status with zero failed units | Rejected. | Failed requires `failedUnitCount > 0`. | STATIC REVIEW |
| 24 | Detail is invalid runtime type, empty, whitespace-only or contains NUL | Rejected when nonnil. | Optional-string helper delegates nonnil values to required validation. | STATIC REVIEW |
| 25 | Failure field is arbitrary object instead of PXClearFailure | Rejected. | Runtime class check is explicit. | STATIC REVIEW |
| 26 | Aggregate with all requested scopes succeeded | Accepted; succeeded mask equals request, no failures, all-success predicate true. | Exact coverage and derived-mask checks pass. | STATIC REVIEW |
| 27 | Aggregate with one skipped scope and no failed scope | Accepted; hasFailures false and allRequestedScopesSucceeded false. | Skipped contributes only to skipped mask. | STATIC REVIEW |
| 28 | Aggregate with one failed scope | Accepted; hasFailures true and all-success false. | Failed contributes only to failed mask. | STATIC REVIEW |
| 29 | Aggregate containing a partial failed component | Accepted; that scope is in failedScopes. | Component status, not successful-unit count, determines the derived mask. | STATIC REVIEW |
| 30 | Request wrong runtime type, result input non-array/empty, or non-component element | Rejected. | All aggregate runtime and nonempty checks are explicit. | STATIC REVIEW |
| 31 | Aggregate missing requested scope | Rejected. | Seen-scope union must equal `request.scopes`. | STATIC REVIEW |
| 32 | Aggregate contains unrequested scope | Rejected. | Each component bit must be included in `request.scopes`. | STATIC REVIEW |
| 33 | Aggregate contains duplicate scope | Rejected. | Seen mask detects a repeated single bit. | STATIC REVIEW |
| 34 | Aggregate supplied in reverse order | Accepted and stored in fixed ascending numeric scope order. | Fixed canonical scope sequence rebuilds an immutable array. | STATIC REVIEW |
| 35 | Lookup receives requested known single bit | Returns matching component. | Input passes single-bit/requested checks and canonical array is scanned. | STATIC REVIEW |
| 36 | Lookup receives zero, multiple, unknown or unrequested known bit | Returns nil. | Single-bit and request-membership checks fail closed. | STATIC REVIEW |
| 37 | Caller mutates original component array after aggregate construction | Stored canonical result remains unchanged. | Canonical array is independently built and copied. | STATIC REVIEW |
| 38 | Copy any of the three model objects | Returns the same object identity. | All three `copyWithZone:` implementations return self. | STATIC REVIEW |
| 39 | Two failure snapshots have equal/different public state | Equality/hash reflect domain, code and message. | All three fields participate. | STATIC REVIEW |
| 40 | Two component results have equal/different public state | Equality/hash reflect all seven public fields. | Scope, status, counts, detail and failure participate. | STATIC REVIEW |
| 41 | Two aggregates receive equivalent components in different caller order | Equal and hashes equal after canonicalization. | Result equality/hash use request and canonical component array. | STATIC REVIEW |
| 42 | Existing Clear API and BOOL completion | Unchanged and unmapped. | Existing production references are zero and no caller file changed. | STATIC REVIEW |

All scenario rows are static source/contract review. No runtime PASS is claimed because the local workspace has neither `clang` nor `make`. GitHub Actions remains the authoritative build gate.

## 24. Source gates

| Gate | Result |
|---|---:|
| PXClearComponentStatus enum | 1 |
| status entries | 3 |
| PXClearFailure interface/implementation | 1 / 1 |
| PXClearComponentResult interface/implementation | 1 / 1 |
| PXClearResult interface/implementation | 1 / 1 |
| subclassing-restricted attributes | 3 |
| failure/component/result public properties | 3 / 7 / 7 |
| designated initializer declarations/implementations | 3 / 3 |
| copyWithZone implementations | 3 |
| isEqual implementations | 3 |
| hash implementations | 3 |
| scope single-bit predicate | 1 shared implementation |
| unchecked succeeded + failed expression | 0 |
| subtraction partition expression | 1 |
| readwrite/setters/NSMutableCopying | 0 / 0 / 0 |
| mutable collection tokens | 0 |
| comparator/callback tokens | 0 |
| ambiguous success/isSuccessful property | 0 |
| prohibited subsystem tokens | 0 |
| existing production references | 0 for all required symbols |

## 25. Complete source diff and diff-stat review

The new files are untracked, so complete no-index diffs against `NUL` were used and reviewed in full:

| File | Insertions | No-index diff lines | Full diff SHA-256 |
|---|---:|---:|---|
| `PXClearResult.h` | 97 | 103 | `047869B74C7F7BD7B82145E5981B5F8A87765C444E052331153B68D7C5E5E640` |
| `PXClearResult.m` | 348 | 354 | `F5C7690AF3C0E7DAC8377708F393904B37AA10CEBFDCA4A8F26CCFA765468B76` |
| Total production source | 445 | 457 | ? |

The full diffs contain additions only: exact header contract; validation helpers; three designated initializers; fixed canonical ordering; derived predicates/lookup; and copy/equality/hash. No existing production hunk is part of TASK-1.6 and there is no format-only churn.

`git diff --check` returned 0. Each untracked source was also checked with `git -c core.autocrlf=false diff --no-index --check -- NUL <file>`; the expected difference exit was 1 with empty stdout/stderr, meaning no whitespace diagnostic.

## 26. Whitespace, NUL, generated and binary audit

| File | Bytes | Lines | SHA-256 | Trailing whitespace | NUL bytes | Type |
|---|---:|---:|---|---:|---:|---|
| `PXClearResult.h` | 3,467 | 97 | `CEDC6E364EBC4BF25ACD8D128938DB114033CA076750D2FADE8E183488B2B592` | 0 | 0 | UTF-8 text |
| `PXClearResult.m` | 10,564 | 348 | `0E4BCE039D6CA19F46590822BDFC938763CDDC852BE3045F6ADA98E2FA0C5715` | 0 | 0 | UTF-8 text |

- Both source files use LF line endings.
- Lexical delimiter audit ended in code state with empty delimiter stacks and no errors.
- No build, generated, object, archive, image, database, cache or binary artifact was created.
- Report file metadata is added in the final verification addendum after report creation.

## 27. Safety and not-changed proof

- No destructive behavior was added or changed.
- No container was resolved, canonicalized, validated or deleted.
- No filesystem, process, permission, Keychain, Backup, Restore or UI behavior was touched.
- No failure is swallowed or mapped to success; this task only validates final value snapshots.
- No result predicate is mapped to the legacy BOOL completion callback.
- No new Clear API exists.
- `PXClearRequest.h/.m`, `AppDataCleaner.h/.m`, Makefile and every other protected file remain unchanged.
- TASK-1.7 was not started.

## 28. Remaining risks

1. Local Objective-C compilation/runtime execution is unavailable because `clang` and `make` are absent; GitHub Actions or owner build confirmation is still required.
2. The result model is intentionally unused until a separately specified migration task. It does not yet improve or alter destructive control flow.
3. Unit-count meaning is intentionally component-owned and must be documented by future migration tasks.
4. Legacy BOOL completion policy remains undecided by design; skipped and failed structured states are not mapped here.
5. TASK-1.7 remains locked pending source review, build gate and accepted coordinator review.

## 29. Acceptance checklist

- [x] Only `PXClearResult.h/.m` were added as production source.
- [x] Required TASK-1.6 report exists.
- [x] Existing production source is unchanged.
- [x] Status enum contains exactly Succeeded, Skipped and Failed.
- [x] Failure snapshot is immutable and validated.
- [x] Component scope is exactly one known bit.
- [x] Count partition is overflow-safe.
- [x] Status-specific invariants are enforced.
- [x] Partial success is Failed plus mixed counts.
- [x] Aggregate covers every requested scope exactly once.
- [x] Duplicate and unrequested scopes are rejected.
- [x] Component array is stored in canonical scope order.
- [x] Derived masks are disjoint and cover request scopes.
- [x] Predicate semantics exactly match the specification.
- [x] Lookup accepts only one known requested bit.
- [x] All three classes are immutable and value-semantic.
- [x] No caller integration or behavior migration was added.
- [x] Protected checksums remain unchanged.
- [x] Whitespace/NUL/generated-artifact checks pass.
- [x] No TASK-1.7 implementation exists.
- [x] Agent stops after TASK-1.6.
- [ ] GitHub Actions succeeds or owner confirms build ? PENDING.
- [ ] Coordinator accepts TASK-1.6 ? PENDING.

## 30. Final verification addendum

Final repository identity remained:

```text
git rev-parse HEAD: 24cde1e978ca914d49cd1ae6427085cc3e3389c1
git log -1 --oneline: 24cde1e task 1.5
```

Final `git status --short --untracked-files=all`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? PXClearResult.h
?? PXClearResult.m
?? docs/backup-restore-hardening/reports/TASK-1.6-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-1.5-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.6-structured-clear-result.md
```

Only `PXClearResult.h`, `PXClearResult.m`, and this report are TASK-1.6-owned paths. All other status entries are unchanged coordinator-owned baseline.

Final verification summary:

```text
header imports: 2 exact imports
PXClearComponentStatus enum/entries: 1 / 3
interfaces/implementations: 3 / 3
subclassing-restricted attributes: 3
public properties: 17 (3 failure + 7 component + 7 aggregate)
designated initializer declarations/implementations: 3 / 3
copy/equality/hash implementations: 3 / 3 / 3
lookup declaration/implementation: 1 / 1
readwrite/setters/NSMutableCopying/NSMutable: 0 / 0 / 0 / 0
comparator/callback tokens: 0 / 0
unchecked count addition: 0
subtraction partition expression: 1
forbidden subsystem tokens: 0
existing production references: 0 for all required symbols
protected SHA-256 equality: true
protected git diff: exit 0
scenario rows: 42 STATIC REVIEW
git diff --check: exit 0
source/report NUL bytes: 0
source/report trailing whitespace: 0
generated/binary artifacts: 0
TASK-1.7 artifacts: absent
```

Final task-owned file metadata:

```text
PXClearResult.h
bytes: 3467
lines: 97
SHA-256: CEDC6E364EBC4BF25ACD8D128938DB114033CA076750D2FADE8E183488B2B592

PXClearResult.m
bytes: 10564
lines: 348
SHA-256: 0E4BCE039D6CA19F46590822BDFC938763CDDC852BE3045F6ADA98E2FA0C5715

TASK-1.6-REPORT.md
bytes: 33718
lines: 666
NUL bytes: 0
trailing whitespace lines: 0
type: UTF-8 text
```

`git diff --check` emitted only LF-to-CRLF warnings for pre-existing coordinator-owned documentation. File-specific no-index checks for both source files and this report returned the expected difference exit 1 with empty stdout/stderr, so no whitespace diagnostic was present.

Local Objective-C build and runtime scenarios were not executed because `clang` and `make` are unavailable. No runtime PASS is claimed.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
