# TASK-1.1 — Immutable `PXResolvedContainer`

## Metadata

- Phase: Phase 1 — Clear Data Safety Boundary
- Status: READY
- Dependency: TASK-0.7 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase1(task-1.1): add immutable resolved container value object`

## Objective

Introduce a small immutable Objective-C value object named `PXResolvedContainer` that can carry exact container identity between future resolver, validation and Clear-planning tasks.

TASK-1.1 establishes the data contract only.

It must not:

- resolve any container from disk;
- scan metadata;
- canonicalize or validate filesystem ownership;
- authorize a destructive operation;
- migrate any existing resolver or caller;
- change Clear, Backup, Restore, Keychain or UI behavior.

After this task, the repository has a compileable immutable type that future tasks can use, but no production path consumes it yet.

## Required reading

Agent must read before editing:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-0.7-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-0.7-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `Makefile`
8. `AppDataCleaner.h`
9. `AppDataCleaner.m`
10. `AppGroupContainerResolver.h`
11. `AppGroupContainerResolver.m`
12. every current container UUID/path resolver in `AppDataCleaner.m`
13. every current destructive base path used by Clear code.

The reading is required to understand future compatibility. It does not authorize edits outside the files listed below.

## Allowed files

Create exactly these code files:

- `PXResolvedContainer.h`
- `PXResolvedContainer.m`

Create the required report:

- `docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md`

Do not modify:

- `Makefile` — root `*.m` wildcard already includes the new implementation;
- `AppDataCleaner.h/.m`;
- `AppGroupContainerResolver.h/.m`;
- `CommandRunner.h/.m`;
- `AppDataBackupManager.h/.m`;
- `AppEntitlementsReader.h/.m`;
- `ContainerManager.h/.m`;
- UI files;
- keychain files;
- any task specification, status file, roadmap or decision log.

If compilation requires another code-file change, stop and report the dependency instead of expanding scope.

## Architectural boundary

`PXResolvedContainer` is an immutable identity snapshot.

It is not a destructive-path authorization token.

The object may carry a candidate container path resolved by a later exact resolver, but callers must still pass it through the canonical destructive-path validator introduced in TASK-1.3 before deletion.

Therefore TASK-1.1 must not perform:

- `fileExistsAtPath:` checks;
- `stat`, `lstat`, `realpath`, `readlink` or filesystem traversal;
- symlink resolution;
- ownership or permission checks;
- metadata plist reads;
- base-directory allow-list validation;
- path canonicalization;
- deletion or command execution.

## Supported container kinds

Declare this public enum in `PXResolvedContainer.h`:

```objc
typedef NS_ENUM(NSUInteger, PXResolvedContainerKind) {
    PXResolvedContainerKindApplicationData = 1,
    PXResolvedContainerKindAppGroup = 2,
    PXResolvedContainerKindExtensionData = 3,
    PXResolvedContainerKindPluginKitData = 4,
};
```

Only these four values are valid.

There must not be a valid `Unknown`, `Any` or `ApplicationBundle` value.

Application bundle containers are intentionally not representable by this model because Phase 1 will remove destructive writes to application bundle containers.

Do not add aliases or additional values in TASK-1.1.

## Supported roots

Declare this public enum:

```objc
typedef NS_ENUM(NSUInteger, PXResolvedContainerRoot) {
    PXResolvedContainerRootRootful = 1,
    PXResolvedContainerRootRootless = 2,
};
```

Only these two values are valid.

The enum describes the logical container root selected by the resolver. It does not prove that the path is canonical or safe.

## Public class contract

Declare:

```objc
@interface PXResolvedContainer : NSObject <NSCopying>
```

The public class must expose exactly these readonly properties:

```objc
@property (nonatomic, assign, readonly) PXResolvedContainerKind kind;
@property (nonatomic, assign, readonly) PXResolvedContainerRoot root;
@property (nonatomic, copy, readonly) NSString *requestedIdentifier;
@property (nonatomic, copy, readonly) NSString *metadataIdentifier;
@property (nonatomic, copy, readonly) NSString *containerUUID;
@property (nonatomic, copy, readonly) NSString *containerPath;
```

Meaning:

- `kind`: category of clearable data container;
- `root`: rootful or rootless discovery domain;
- `requestedIdentifier`: exact identifier requested from the future resolver;
- `metadataIdentifier`: exact identifier read from trusted container metadata by the future resolver;
- `containerUUID`: final container directory name;
- `containerPath`: absolute candidate path to the container directory.

For application data or extension data, identifiers are bundle identifiers.

For app groups, identifiers are application-group identifiers.

For PluginKit data, identifiers are the exact metadata identifiers for that container.

TASK-1.1 must not impose prefix conventions such as `group.` or `com.` because exact semantic validation belongs to the future resolver policy.

## Initializer contract

Expose one failable designated initializer:

```objc
- (nullable instancetype)initWithKind:(PXResolvedContainerKind)kind
                                 root:(PXResolvedContainerRoot)root
                  requestedIdentifier:(NSString *)requestedIdentifier
                   metadataIdentifier:(NSString *)metadataIdentifier
                        containerUUID:(NSString *)containerUUID
                        containerPath:(NSString *)containerPath NS_DESIGNATED_INITIALIZER;
```

Disable generic construction:

```objc
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
```

Do not add a mutable builder, default initializer or convenience initializer in TASK-1.1.

Do not throw exceptions for invalid values. Return `nil`.

## Required initializer validation

The initializer must return `nil` unless every condition below is true.

### Enum validation

`kind` is exactly one of:

- `PXResolvedContainerKindApplicationData`;
- `PXResolvedContainerKindAppGroup`;
- `PXResolvedContainerKindExtensionData`;
- `PXResolvedContainerKindPluginKitData`.

`root` is exactly one of:

- `PXResolvedContainerRootRootful`;
- `PXResolvedContainerRootRootless`.

Do not accept zero, negative-cast values or future unknown enum values.

### Runtime type validation

Each string input must be an `NSString` at runtime:

- `requestedIdentifier`;
- `metadataIdentifier`;
- `containerUUID`;
- `containerPath`.

Although nullability annotations declare them nonnull, runtime validation must also reject `nil` and non-string values.

### Non-empty validation

All four strings must have length greater than zero.

Do not trim or normalize before checking.

Whitespace-only identifiers are invalid and must return `nil`.

A helper may use `whitespaceAndNewlineCharacterSet` only to determine whether an identifier contains any non-whitespace character. It must still store the original exact string when valid.

`containerUUID` and `containerPath` must not be trimmed or rewritten.

### Embedded NUL validation

Reject any string containing Unicode code point U+0000.

Do not rely on C-string truncation or `UTF8String` behavior to detect this.

The implementation may create a one-character NSString containing `unichar 0` and search for it.

### Exact metadata identity

Require:

```objc
[requestedIdentifier isEqualToString:metadataIdentifier]
```

The comparison is case-sensitive and byte/NSString exact.

Prefix, suffix, substring, case-insensitive or fuzzy matching is forbidden.

A `PXResolvedContainer` must never represent an approximate match.

### UUID validation

`containerUUID` must:

- contain no `/`;
- not equal `.` or `..`;
- parse successfully through `[[NSUUID alloc] initWithUUIDString:containerUUID]`.

Do not rewrite the UUID casing or textual representation. Store the original exact string after validation.

### Candidate path validation

`containerPath` must:

- begin with exactly `/`;
- not equal `/`;
- not end with `/`;
- contain no embedded NUL;
- contain no path component equal to `.` or `..`;
- have `lastPathComponent` exactly equal to `containerUUID`.

Reject paths containing an empty interior component represented by `//`.

Do not call:

- `stringByStandardizingPath`;
- `stringByResolvingSymlinksInPath`;
- `realpath`;
- `fileSystemRepresentation` for normalization.

The initializer performs only lexical consistency checks. TASK-1.3 will perform canonical destructive-path validation.

### No base-path policy in TASK-1.1

Do not validate that the candidate path starts with one of the known rootful/rootless container bases in this task.

Do not couple `kind` or `root` to a concrete path prefix yet.

That mapping belongs to TASK-1.3, where symlinks, aliases and canonical roots can be handled as one safety policy.

## Immutability requirements

The object must be immutable after successful initialization.

Required:

1. Public properties are `readonly`.
2. Every input string is copied during initialization.
3. The implementation must not expose public or private mutation methods.
4. Do not redeclare properties as `readwrite` in a class extension.
5. Do not use setters during initialization.
6. Store state in private ivars and implement readonly getters or synthesize directly to those ivars.
7. Do not return mutable internal storage.
8. Do not conform to `NSMutableCopying`.

It is acceptable to declare private ivars in the public class declaration under `@private` if that is the simplest compile-safe approach for the target Objective-C runtime.

## Subclassing policy

Mark the class as subclassing-restricted when supported by this toolchain:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXResolvedContainer : NSObject <NSCopying>
```

If the target compiler rejects this attribute, do not silently remove it. Record the compile error in the report and stop for review.

Do not create subclasses.

## Copying contract

Implement:

```objc
- (id)copyWithZone:(NSZone *)zone;
```

Because the object is immutable, return `self`.

Under ARC, do not manually retain or autorelease.

The returned object must be pointer-identical to the receiver.

## Equality and hash contract

Implement value equality.

Two objects are equal only when all fields are equal:

- `kind`;
- `root`;
- `requestedIdentifier`;
- `metadataIdentifier`;
- `containerUUID`;
- `containerPath`.

Requirements:

- pointer identity returns `YES` immediately;
- non-`PXResolvedContainer` objects return `NO`;
- `hash` uses the same field set as `isEqual:`;
- equal objects must have equal hashes;
- do not use filesystem state in equality or hash;
- do not use object addresses as the only hash source.

Do not implement ordering or comparison APIs.

## Description policy

A custom `description` is optional.

If implemented, it must be concise and must not perform filesystem access. It may include kind/root/identifier/UUID/path because these values already exist in process memory.

Do not add JSON, dictionary or archive serialization.

## Explicitly forbidden additions

Do not add:

- `NSSecureCoding` or `NSCoding`;
- dictionary conversion;
- JSON conversion;
- mutable properties;
- `setValue:forKey:` overrides;
- resolver methods;
- metadata plist parsing;
- file existence checks;
- canonical path checks;
- allow-list base paths;
- deletion eligibility flags;
- `isSafeToDelete` or similar authorization methods;
- command execution;
- logging from the initializer;
- global caches or singletons;
- imports into existing production files;
- unit-test-only production branches.

## Existing-code compatibility

No existing production file may import or instantiate `PXResolvedContainer` in TASK-1.1.

Static search after implementation must show that the class name appears only in:

- `PXResolvedContainer.h`;
- `PXResolvedContainer.m`;
- TASK-1.1 documentation/report.

The new implementation is compiled automatically because the Makefile uses:

```make
ProjectX_FILES = $(wildcard *.m) $(wildcard common/*.m)
```

Do not modify the Makefile.

## Resource ownership table required in report

The report must contain a table covering:

| Resource | Owner | Creation | Release/lifetime |
|---|---|---|---|
| requested identifier copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| metadata identifier copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| UUID copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| path copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| temporary validation objects | initializer stack/autorelease pool | during validation | normal ARC/autorelease lifetime |

No raw allocation should be necessary.

## Scenario matrix required in report

The report must statically review every scenario:

| # | Scenario | Expected result |
|---:|---|---|
| 1 | valid application-data/rootful object | object created |
| 2 | valid application-data/rootless object | object created |
| 3 | valid app-group object | object created |
| 4 | valid extension-data object | object created |
| 5 | valid PluginKit-data object | object created |
| 6 | invalid kind zero | nil |
| 7 | invalid future kind | nil |
| 8 | invalid root zero | nil |
| 9 | invalid future root | nil |
| 10 | nil requested identifier | nil |
| 11 | non-string requested identifier through dynamic call | nil |
| 12 | empty requested identifier | nil |
| 13 | whitespace-only requested identifier | nil |
| 14 | metadata identifier differs by one character | nil |
| 15 | metadata identifier differs only by case | nil |
| 16 | prefix-only metadata match | nil |
| 17 | identifier contains embedded NUL | nil |
| 18 | invalid UUID text | nil |
| 19 | UUID contains slash | nil |
| 20 | UUID is `.` or `..` | nil |
| 21 | valid lowercase UUID text | object created and original text preserved |
| 22 | relative container path | nil |
| 23 | root path `/` | nil |
| 24 | trailing-slash path | nil |
| 25 | path contains `//` | nil |
| 26 | path contains `.` component | nil |
| 27 | path contains `..` component | nil |
| 28 | path last component differs from UUID | nil |
| 29 | path contains embedded NUL | nil |
| 30 | mutable input string changed after initialization | object values remain unchanged |
| 31 | `copy` called | returns same object pointer |
| 32 | two independently created equal objects | `isEqual:` YES and hashes equal |
| 33 | one field differs | `isEqual:` NO |
| 34 | compare with unrelated object | NO |
| 35 | path points to missing filesystem object | model may still initialize; no filesystem access |
| 36 | candidate path has wrong base for root/kind but passes lexical checks | model may initialize; TASK-1.3 owns base policy |

Do not claim runtime execution unless it was actually performed.

## Verification requirements

Agent must perform and report:

1. initial `git status --short`;
2. baseline checksums for:
   - `Makefile`;
   - `AppDataCleaner.h`;
   - `AppDataCleaner.m`;
   - `AppGroupContainerResolver.h`;
   - `AppGroupContainerResolver.m`;
   - `CommandRunner.h`;
   - `CommandRunner.m`;
3. final checksums proving those files are unchanged;
4. full content review of both new source files;
5. search proving no existing production file references `PXResolvedContainer`;
6. search proving no setters/readwrite properties exist;
7. search proving `init` and `new` are unavailable;
8. search proving no filesystem or process API is used;
9. search proving no `ApplicationBundle` enum exists;
10. search proving no fuzzy/prefix identifier match exists;
11. search proving exact identifier equality validation exists;
12. search proving copy of every input string;
13. search proving `copyWithZone:`, `isEqual:` and `hash` exist;
14. search proving no `NSCoding`, `NSSecureCoding` or serialization API exists;
15. `git diff --check`;
16. full diff review;
17. diff stat review;
18. generated/binary file audit.

Suggested source gate examples:

```text
PXResolvedContainer class declarations: 1
PXResolvedContainer implementations: 1
public readwrite properties: 0
setter methods: 0
fileExistsAtPath: 0
realpath: 0
stringByResolvingSymlinksInPath: 0
posix_spawn: 0
system(: 0
popen(: 0
ApplicationBundle enum: 0
```

## Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md
```

The report must include:

1. task metadata;
2. initial working-tree state;
3. files created;
4. exact enum declarations;
5. exact property declarations;
6. exact initializer signature;
7. all validation rules;
8. immutability implementation;
9. private ivar strategy;
10. embedded-NUL strategy;
11. UUID validation strategy;
12. lexical path validation strategy;
13. exact identifier invariant;
14. copying contract;
15. equality/hash contract;
16. why the object is not deletion authorization;
17. why application bundle is excluded;
18. protected-file checksum table;
19. resource ownership table;
20. scenario matrix;
21. verification commands and results;
22. full diff review;
23. remaining risks;
24. GitHub Actions handoff.

End with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Acceptance checklist

- [ ] Only `PXResolvedContainer.h`, `PXResolvedContainer.m` and the required report are task-owned changes.
- [ ] Required enums exist with exact values.
- [ ] No unknown/any/application-bundle kind exists.
- [ ] Class conforms to `NSCopying` only.
- [ ] Class is subclassing-restricted.
- [ ] All six public properties are readonly.
- [ ] No readwrite redeclaration or mutation method exists.
- [ ] Generic `init` and `new` are unavailable.
- [ ] Failable designated initializer exists exactly once.
- [ ] Invalid enum values return nil.
- [ ] Invalid string types and empty values return nil.
- [ ] Whitespace-only identifiers return nil.
- [ ] Embedded NUL is rejected.
- [ ] Requested and metadata identifiers must match exactly.
- [ ] UUID is syntactically valid and stored unchanged.
- [ ] Candidate path passes required lexical checks.
- [ ] Path last component must equal UUID exactly.
- [ ] All strings are copied.
- [ ] No filesystem access or canonicalization occurs.
- [ ] No base-path allow-list is implemented yet.
- [ ] `copyWithZone:` returns self.
- [ ] Value equality and matching hash are implemented.
- [ ] No serialization support is added.
- [ ] No existing production caller imports or instantiates the class.
- [ ] Makefile is unchanged.
- [ ] Clear/Backup/Restore/Keychain/UI behavior is unchanged.
- [ ] Protected files are byte-for-byte unchanged.
- [ ] `git diff --check` passes.
- [ ] Report is complete.
- [ ] GitHub Actions is recorded as PENDING.
- [ ] Agent stops after TASK-1.1.

## Stop condition

After creating the two source files and report:

- propose `READY_FOR_REVIEW`;
- stop;
- do not implement TASK-1.2;
- do not edit existing resolvers;
- do not import the new class into `AppDataCleaner`;
- do not create a destructive-path validator;
- do not change any Clear operation.

## Gate after TASK-1.1

After agent completion:

1. coordinator reviews source and report;
2. project owner runs GitHub Actions;
3. TASK-1.1 becomes `COMPLETED` only after both pass;
4. TASK-1.2 may then be specified to add an exact data-container resolver;
5. TASK-1.3 remains locked until the resolver contract is accepted.
