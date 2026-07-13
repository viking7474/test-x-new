# TASK-1.5 — Typed PXClearRequest

## Metadata

- Phase: 1 — Clear Data Safety Boundary
- Status: READY
- Dependency: TASK-1.4 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md`
- Allowed production files: `PXClearRequest.h`, `PXClearRequest.m`
- Suggested commit: `phase1(task-1.5): add immutable clear request`

## Objective

Introduce one immutable request value object that records:

- the exact application bundle identifier;
- the explicitly requested Clear component scopes;
- whether deep-clean behavior was requested.

TASK-1.5 is model-only. It does not execute Clear, resolve containers, validate paths, import into `AppDataCleaner`, or change any existing behavior.

## Required reading

Before implementation, read:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.4-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.4-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `PXResolvedContainer.h/.m`
8. `PXDataContainerResolver.h/.m`
9. `PXDestructivePathValidator.h/.m`
10. `AppDataCleaner.h`
11. the complete `AppDataCleaner.m`
12. `Makefile`

## Authorized changes

Create exactly:

```text
PXClearRequest.h
PXClearRequest.m
docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md
```

Do not modify any existing production source file.

## Public scope contract

Declare exactly this option set:

```objc
typedef NS_OPTIONS(NSUInteger, PXClearScope) {
    PXClearScopeApplicationData = 1UL << 0,
    PXClearScopeExtensionData   = 1UL << 1,
    PXClearScopeAppGroups       = 1UL << 2,
    PXClearScopePluginKitData   = 1UL << 3,
    PXClearScopeKeychain        = 1UL << 4,
};
```

Export exactly these masks:

```objc
FOUNDATION_EXPORT const PXClearScope PXClearScopeKnownMask;
FOUNDATION_EXPORT const PXClearScope PXClearScopeDefaultMask;
```

Both constants must be defined as the exact union of all five declared bits:

```objc
PXClearScopeApplicationData |
PXClearScopeExtensionData |
PXClearScopeAppGroups |
PXClearScopePluginKitData |
PXClearScopeKeychain
```

No other scope is allowed in TASK-1.5.

In particular, do not add scopes for:

- application bundle or receipt mutation;
- system-wide residual cleanup;
- UI refresh;
- process termination;
- Backup or Restore;
- arbitrary paths;
- unknown/custom/vendor bits.

Application bundles are intentionally read-only and must not be representable as a Clear scope.

## Public class contract

The header must declare:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXClearRequest : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, assign, readonly) PXClearScope scopes;
@property (nonatomic, assign, readonly, getter=isDeepClean) BOOL deepClean;

- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                         deepClean:(BOOL)deepClean
    NS_DESIGNATED_INITIALIZER;

+ (nullable instancetype)defaultRequestForBundleIdentifier:(NSString *)bundleIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
```

Do not expose any additional public property, initializer, builder, mutation method, serialization method, path, UUID, resolver, validator, result, timeout, command or callback field.

## Bundle identifier validation

The designated initializer must return `nil` unless the runtime input is a valid `NSString` satisfying every rule below.

Required:

- non-nil runtime `NSString`;
- length greater than zero;
- contains at least one non-whitespace/newline character;
- contains no Unicode U+0000;
- contains no `/`;
- contains no `\`;
- contains no `*`;
- does not begin with `.`;
- does not end with `.`;
- does not contain `..`;
- contains only ASCII letters, ASCII digits, `-`, and `.`;
- every dot-separated component is nonempty.

Preservation rules:

- do not trim;
- do not lowercase or uppercase;
- do not Unicode-normalize;
- do not rewrite separators;
- do not prepend an organization prefix;
- store the accepted value exactly as supplied using copy semantics.

Whitespace inside an otherwise non-whitespace identifier is naturally rejected by the allowed-character rule.

Do not require a fixed number of dot components. Existing identifiers with one valid component remain representable.

## Scope validation

The initializer must return `nil` when:

```objc
scopes == 0
```

or when any unknown bit is set:

```objc
(scopes & ~PXClearScopeKnownMask) != 0
```

Valid subsets of the known mask are accepted. A request does not have to include all default scopes.

Do not silently:

- remove unknown bits;
- add missing bits;
- replace zero with the default mask;
- infer scopes from the bundle identifier;
- merge user defaults or global settings.

## Deep-clean value

`deepClean` is copied as the exact boolean value supplied by the caller.

TASK-1.5 does not define or execute deep-clean behavior. The field only records intent for future orchestration.

The factory method must create a request using:

```objc
scopes = PXClearScopeDefaultMask
deepClean = NO
```

It must delegate to the designated initializer and return `nil` for an invalid bundle identifier.

## Immutability

Implementation requirements:

- use private ivars;
- assign all ivars directly inside the initializer;
- copy `bundleIdentifier` before storing;
- expose only readonly properties;
- do not redeclare properties as `readwrite` privately;
- add no setter;
- add no mutable collection;
- add no mutation method;
- do not conform to `NSMutableCopying`;
- do not use a singleton or cache.

Implement:

```objc
- (id)copyWithZone:(NSZone *)zone;
```

Because the object is immutable, return `self`.

## Equality and hash

Implement value equality using all request state:

- exact class compatibility;
- `bundleIdentifier` exact string equality;
- exact `scopes` value;
- exact `deepClean` value.

Implement `hash` from all three fields so equal objects always have equal hashes.

Do not use pointer identity as the only equality rule.

## Forbidden behavior

The two new production files must not:

- import `AppDataCleaner.h`;
- import resolver or validator headers;
- access the filesystem;
- inspect application bundles;
- read metadata plists;
- execute commands or processes;
- delete, create, rename, chmod, chown or write files;
- access Keychain APIs;
- access UIKit;
- dispatch asynchronous work;
- read `NSUserDefaults`;
- read environment variables;
- generate or store arbitrary paths;
- start TASK-1.6 result modeling;
- invoke any existing Clear method.

Forbidden tokens/APIs include:

```text
AppDataCleaner
PXResolvedContainer
PXDataContainerResolver
PXDestructivePathValidator
NSFileManager
fileExistsAtPath
contentsOfDirectory
removeItemAtPath
createDirectoryAtPath
CommandRunner
NSTask
posix_spawn
system(
popen(
SecItem
UIKit
UIApplication
NSUserDefaults
dispatch_async
dispatch_sync
```

The only non-project import should be Foundation.

## No caller integration

After TASK-1.5, existing production source outside `PXClearRequest.h/.m` must contain zero references to:

```text
PXClearRequest
PXClearScope
PXClearScopeKnownMask
PXClearScopeDefaultMask
defaultRequestForBundleIdentifier:
```

Do not import or instantiate the request from `AppDataCleaner` or UI code.

## Makefile

Do not modify `Makefile`.

The existing root-level source wildcard is expected to compile `PXClearRequest.m` automatically. Report the exact Makefile evidence used to reach that conclusion.

## Baseline and protected files

Record initial:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -1 --oneline
```

Record SHA-256 before and after for:

- `AppDataCleaner.h/.m`
- `PXResolvedContainer.h/.m`
- `PXDataContainerResolver.h/.m`
- `PXDestructivePathValidator.h/.m`
- `CommandRunner.h/.m`
- `AppGroupContainerResolver.h/.m`
- `AppDataBackupManager.h/.m`
- `Makefile`

TASK-1.4 may still be an uncommitted `AppDataCleaner.m` baseline. If so:

- record it explicitly;
- do not edit, stage, revert or reformat it;
- prove its checksum is unchanged during TASK-1.5;
- review TASK-1.5 through file-specific/no-index diffs.

## Required static scenario matrix

The report must cover at least:

| # | Scenario | Required result |
|---:|---|---|
| 1 | valid identifier + default factory | object with exact default mask and `deepClean == NO` |
| 2 | valid identifier + one scope | accepted |
| 3 | valid identifier + arbitrary known subset | accepted unchanged |
| 4 | all five known scopes | accepted |
| 5 | `deepClean == YES` | accepted and preserved |
| 6 | nil/non-string identifier | nil |
| 7 | empty identifier | nil |
| 8 | whitespace-only identifier | nil |
| 9 | embedded U+0000 | nil |
| 10 | slash or backslash | nil |
| 11 | wildcard | nil |
| 12 | leading/trailing dot | nil |
| 13 | repeated dot | nil |
| 14 | unsupported character such as space, underscore or colon | nil |
| 15 | uppercase valid ASCII identifier | accepted and preserved |
| 16 | zero scopes | nil |
| 17 | one unknown bit | nil |
| 18 | known plus unknown bits | nil |
| 19 | factory receives invalid identifier | nil |
| 20 | copy | same object identity |
| 21 | equal values in separate instances | `isEqual:` true and hashes equal |
| 22 | different identifier | not equal |
| 23 | different scopes | not equal |
| 24 | different deep-clean value | not equal |
| 25 | application-bundle scope requested | impossible; no such bit exists |
| 26 | request executes Clear | impossible; no integration or behavior API |

Runtime tests are optional if the target toolchain is unavailable, but the report must distinguish runtime PASS from static review.

## Required source gates

Verify and report:

```text
PXClearRequest interface: 1
PXClearRequest implementation: 1
public properties: exactly 3
designated initializer declaration: 1
designated initializer implementation: 1
default factory declaration: 1
default factory implementation: 1
scope enum single-bit entries: exactly 5
known-mask declaration/definition: 1/1
default-mask declaration/definition: 1/1
application-bundle scope: 0
public setters: 0
readwrite redeclarations: 0
NSMutableCopying: 0
filesystem/process/deletion/keychain/UIKit references: 0
existing production references outside new files: 0
```

Also prove:

- zero and unknown scopes fail;
- bundle identifier is not normalized;
- factory uses the exact default mask and `NO` deep-clean;
- equality/hash include all state.

## Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.5-REPORT.md
```

Include:

1. task metadata and scope;
2. required reading;
3. initial working tree and HEAD;
4. file inventory;
5. exact public API;
6. scope and mask contract;
7. bundle identifier validation matrix;
8. scope validation;
9. deep-clean preservation;
10. default factory behavior;
11. immutability and private ivar strategy;
12. copy contract;
13. equality/hash contract;
14. forbidden-behavior proof;
15. no-caller-integration proof;
16. protected checksums;
17. source-token gates;
18. scenario matrix;
19. full diff/stat review;
20. whitespace, NUL, generated and binary audit;
21. remaining risks.

End exactly with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Stop condition

Stop after TASK-1.5.

Do not:

- implement TASK-1.6;
- create `PXClearResult`;
- import `PXClearRequest` into existing production code;
- change the legacy Clear API;
- migrate any destructive caller;
- modify Clear completion semantics.

## Gate after TASK-1.5

TASK-1.6 may be specified only after:

1. the TASK-1.5 report is complete;
2. source and diff review pass;
3. protected files remain unchanged;
4. GitHub Actions succeeds or the project owner explicitly confirms the build;
5. coordinator creates an accepted TASK-1.5 review.
