# TASK-1.1 Report — Immutable `PXResolvedContainer`

## 1. Task metadata

- Task: `TASK-1.1-immutable-resolved-container`
- Phase: Phase 1 — Clear Data Safety Boundary
- Workspace: `C:\Users\VanVan\Documents\github\test-x`
- Implementation scope: immutable Objective-C value object only
- Build integration: existing root `*.m` Makefile wildcard
- Local Objective-C build: NOT RUN; `clang` and `make` are not installed in this workspace
- Runtime scenarios: NOT RUN; every scenario below is marked `STATIC REVIEW`
- Suggested status: `READY_FOR_REVIEW`

TASK-1.1 introduces only an immutable exact-identity snapshot. It does not resolve containers, authorize deletion, validate canonical filesystem paths or migrate an existing caller.

## 2. Initial working-tree state

Initial `git status --short` before creating TASK-1.1 files:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-0.7-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.1-immutable-resolved-container.md
```

These documentation, review and task-specification changes were present at baseline and are coordinator-owned. TASK-1.1 did not edit, revert or stage them.

Before implementation:

```text
PXResolvedContainer.h: absent
PXResolvedContainer.m: absent
docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md: absent
```

The initial source search found references to `PXResolvedContainer` only in backup/restore-hardening documentation. No existing production source referenced the class.

## 3. Files created

TASK-1.1 created exactly:

```text
PXResolvedContainer.h
PXResolvedContainer.m
docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md
```

No existing production file was modified.

The Makefile was not changed. Its existing rule remains authoritative:

```make
ProjectX_FILES = $(wildcard *.m) $(wildcard common/*.m)
```

Therefore `PXResolvedContainer.m` is automatically included in the root source wildcard.

## 4. Exact enum declarations

`PXResolvedContainer.h` declares exactly:

```objc
typedef NS_ENUM(NSUInteger, PXResolvedContainerKind) {
    PXResolvedContainerKindApplicationData = 1,
    PXResolvedContainerKindAppGroup = 2,
    PXResolvedContainerKindExtensionData = 3,
    PXResolvedContainerKindPluginKitData = 4,
};

typedef NS_ENUM(NSUInteger, PXResolvedContainerRoot) {
    PXResolvedContainerRootRootful = 1,
    PXResolvedContainerRootRootless = 2,
};
```

Source-gate counts:

```text
PXResolvedContainerKind declarations: 1
PXResolvedContainerRoot declarations: 1
ApplicationData value: 1
AppGroup value: 1
ExtensionData value: 1
PluginKitData value: 1
Rootful value: 1
Rootless value: 1
ApplicationBundle: 0
Unknown: 0
KindAny: 0
```

No alias, future placeholder or additional enum kind was added.

## 5. Exact class and property contract

The class declaration is subclassing-restricted and conforms only to `NSCopying` beyond `NSObject`:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXResolvedContainer : NSObject <NSCopying>
```

The six public properties are exactly:

```objc
@property (nonatomic, assign, readonly) PXResolvedContainerKind kind;
@property (nonatomic, assign, readonly) PXResolvedContainerRoot root;
@property (nonatomic, copy, readonly) NSString *requestedIdentifier;
@property (nonatomic, copy, readonly) NSString *metadataIdentifier;
@property (nonatomic, copy, readonly) NSString *containerUUID;
@property (nonatomic, copy, readonly) NSString *containerPath;
```

Source-gate counts:

```text
PXResolvedContainer class declarations: 1
PXResolvedContainer implementations: 1
objc_subclassing_restricted attributes: 1
public readonly properties: 6
public readwrite properties: 0
setter methods: 0
NSMutableCopying conformances: 0
```

## 6. Exact initializer signature

The header exposes one failable designated initializer:

```objc
- (nullable instancetype)initWithKind:(PXResolvedContainerKind)kind
                                 root:(PXResolvedContainerRoot)root
                  requestedIdentifier:(NSString *)requestedIdentifier
                   metadataIdentifier:(NSString *)metadataIdentifier
                        containerUUID:(NSString *)containerUUID
                        containerPath:(NSString *)containerPath NS_DESIGNATED_INITIALIZER;
```

Generic construction is disabled:

```objc
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
```

Verification counts:

```text
NS_DESIGNATED_INITIALIZER declarations: 1
initWithKind implementations: 1
init unavailable declarations: 1
new unavailable declarations: 1
convenience initializers: 0
builders: 0
```

Invalid values return `nil`; the initializer does not throw or log.

## 7. Validation matrix

| Input/condition | Validation | Failure result | Rewrite before storage |
|---|---|---|---|
| `kind` | Exact switch over values 1–4 | `nil` | none |
| `root` | Exact switch over values 1–2 | `nil` | none |
| requested identifier type | Runtime `NSString` check | `nil` | none |
| metadata identifier type | Runtime `NSString` check | `nil` | none |
| UUID type | Runtime `NSString` check | `nil` | none |
| path type | Runtime `NSString` check | `nil` | none |
| any empty string | `length == 0` | `nil` | none |
| requested identifier whitespace-only | no non-whitespace character | `nil` | none |
| metadata identifier whitespace-only | no non-whitespace character | `nil` | none |
| U+0000 in any string | NSString-space NUL search | `nil` | none |
| identifier mismatch | exact `isEqualToString:` | `nil` | none |
| UUID contains `/` | lexical range check | `nil` | none |
| UUID is `.` or `..` | exact equality check | `nil` | none |
| UUID syntax invalid | `NSUUID initWithUUIDString:` returns nil | `nil` | none |
| path relative | does not start with `/` | `nil` | none |
| path is `/` | exact root-path check | `nil` | none |
| path ends in `/` | suffix check | `nil` | none |
| path contains `//` | lexical range check | `nil` | none |
| path contains `.` or `..` component | component equality check | `nil` | none |
| last component differs from UUID | exact `lastPathComponent` equality | `nil` | none |
| path base does not correspond to kind/root | deliberately not checked | model may initialize | none |
| filesystem object absent | deliberately not checked | model may initialize | none |

All four string values are copied only after every validation succeeds. No valid value is trimmed, normalized, case-converted, standardized or otherwise rewritten before storage.

## 8. Immutability implementation

Immutability is enforced by the following structure:

1. all six public properties are `readonly`;
2. no class extension redeclares a property as `readwrite`;
3. no setter or mutation method exists;
4. state is assigned directly to private ivars in the successful initializer;
5. each string is copied with `copy`;
6. no setter is used during initialization;
7. no mutable collection or mutable builder is stored;
8. the class does not conform to `NSMutableCopying`;
9. `copyWithZone:` returns the same immutable object.

The implementation has exactly four input-copy expressions:

```objc
_requestedIdentifier = [requestedIdentifier copy];
_metadataIdentifier = [metadataIdentifier copy];
_containerUUID = [containerUUID copy];
_containerPath = [containerPath copy];
```

A caller that passes an `NSMutableString` cannot mutate the successfully stored value by changing its original object afterward.

## 9. Private ivar strategy

For compile safety with the target Objective-C runtime, private ivars are declared inside the public class declaration under `@private`:

```objc
@private
    PXResolvedContainerKind _kind;
    PXResolvedContainerRoot _root;
    NSString *_requestedIdentifier;
    NSString *_metadataIdentifier;
    NSString *_containerUUID;
    NSString *_containerPath;
```

Readonly properties are synthesized directly to these ivars. There is no private readwrite property redeclaration and no setter implementation.

## 10. Embedded-NUL strategy

NUL validation stays entirely in `NSString`/Unicode space:

```objc
static BOOL PXStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}
```

The helper is applied independently to:

- `requestedIdentifier`;
- `metadataIdentifier`;
- `containerUUID`;
- `containerPath`.

This does not call `UTF8String`, `fileSystemRepresentation`, C-string APIs or any truncating conversion. Source counts for `UTF8String` and `fileSystemRepresentation` are both zero.

## 11. UUID validation strategy

The UUID is accepted only when all conditions hold:

1. it is a runtime `NSString`;
2. it is nonempty;
3. it contains no U+0000;
4. it contains no `/`;
5. it is neither `.` nor `..`;
6. `[[NSUUID alloc] initWithUUIDString:containerUUID]` succeeds.

The parser is used only as a validity check. The implementation stores `[containerUUID copy]`, not `NSUUID.UUIDString`, so lowercase, uppercase and original textual representation remain unchanged.

## 12. Lexical path validation strategy

Candidate path validation is lexical only:

```text
absolute leading slash required
root path `/` rejected
trailing slash rejected
`//` rejected
`.` component rejected
`..` component rejected
embedded U+0000 rejected
lastPathComponent must equal containerUUID exactly
```

The implementation uses `componentsSeparatedByString:@"/"` to inspect literal components and `lastPathComponent` for the required final-component equality.

Forbidden canonical/filesystem APIs are absent:

```text
fileExistsAtPath: 0
stat(: 0
lstat(: 0
realpath: 0
readlink: 0
stringByStandardizingPath: 0
stringByResolvingSymlinksInPath: 0
fileSystemRepresentation: 0
contentsOfDirectoryAtPath: 0
dictionaryWithContentsOfFile: 0
```

No rootful/rootless base allow-list and no kind-to-base mapping is present. TASK-1.3 remains responsible for canonical filesystem and destructive-path validation.

## 13. Exact identifier invariant

The object can represent only an exact requested/metadata identity:

```objc
if (![requestedIdentifier isEqualToString:metadataIdentifier]) {
    return nil;
}
```

The comparison is case-sensitive. Searches over the two new files found:

```text
exact requested/metadata isEqualToString: 1
containsString: 0
caseInsensitive: 0
localizedCaseInsensitive: 0
identifier hasPrefix matching: 0
identifier hasSuffix matching: 0
```

`hasPrefix:` and `hasSuffix:` are used only for required path lexical checks, never for identifier matching.

## 14. Copying contract

The class implements:

```objc
- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}
```

Because the object is immutable, copying returns the pointer-identical receiver. There is no manual retain, release or autorelease operation.

## 15. Equality and hash contract

`isEqual:` applies:

1. immediate `YES` for pointer identity;
2. `NO` for objects outside `PXResolvedContainer`;
3. exact comparison of all six fields:
   - `kind`;
   - `root`;
   - `requestedIdentifier`;
   - `metadataIdentifier`;
   - `containerUUID`;
   - `containerPath`.

`hash` combines the same six fields with a 31-based accumulator. Therefore independently initialized objects with all equal fields produce equal hashes, while any field difference participates in both equality and hash calculation.

Neither equality nor hash accesses filesystem state or uses object address as its only input.

## 16. Why this object is not deletion authorization

`PXResolvedContainer` proves only that its in-memory fields satisfy the TASK-1.1 identity and lexical consistency contract. It does not prove:

- that the candidate exists;
- that the path is canonical;
- that the path belongs to an allowed container base;
- that no symlink or mount alias redirects the path;
- that metadata came from a trusted filesystem location;
- that ownership and permissions are safe;
- that deletion is authorized.

No method such as `isSafeToDelete`, deletion-eligibility flag, resolver or command execution API exists. Future destructive callers must still pass candidates through the TASK-1.3 canonical safety boundary.

## 17. Why application bundle is excluded

The only supported kinds are application data, app group, extension data and PluginKit data. Application bundle containers are intentionally not representable because Phase 1 plans to remove destructive writes to application bundle locations rather than legitimize them through a new identity model.

The source contains zero `ApplicationBundle`, `Unknown` or `Any` enum values.

## 18. Existing resolver and Clear-base compatibility audit

### Existing container UUID/path resolvers read before implementation

The following existing resolution families were reviewed and left unchanged:

| Resolver family | Existing methods reviewed | TASK-1.1 action |
|---|---|---|
| entitlement app-group resolution | `_resolvedAppGroupUUIDsFromEntitlements:rootless:` | none |
| legacy bundle/data resolution | `findBundleUUID:`, `findDataContainerUUID:aggressive:`, `findDataContainerUUID:`, `findRootlessDataContainerUUID:aggressive:`, `findRootlessDataContainerUUID:` | none |
| legacy app-group resolution | `findAppGroupUUIDs:aggressive:`, `findAppGroupUUIDs:`, `findRootlessAppGroupUUIDs:` | none |
| optimized data/bundle/group resolution | `optimized_findDataContainerUUID:inDirectories:`, `optimized_findRootlessDataContainerUUID:inDirectories:`, `optimized_findAppGroupUUIDs:inDirectories:`, `optimized_findBundleContainerUUID:inDirectories:rootlessDirs:` | none |
| optimized extension resolution | `optimized_findExtensionContainers:dataDirs:rootlessDataDirs:bundleDirs:rootlessBundleDirs:` | none |
| extension and PluginKit resolution | `findExtensionContainers:`, `findBundleUUIDForExtension:`, `findRootlessBundleUUIDForExtension:` | none |
| compatibility aliases | `findDataContainerUUIDForBundleID:`, `findBundleContainerUUIDForBundleID:`, `findGroupContainerUUIDsForBundleID:`, `findExtensionDataContainersForBundleID:` | none |
| separate app-group resolver | `AppGroupContainerResolver` and `AppGroupContainerInfo` | none |

No resolver imports or instantiates `PXResolvedContainer` in this task.

### Existing destructive base-path families reviewed

The current Clear code contains rootful/rootless path families including:

```text
/var/mobile/Containers/Data/Application
/containers/Data/Application
/var/mobile/Containers/Shared/AppGroup
/containers/Shared/AppGroup
/var/mobile/Containers/Data/PluginKitPlugin
/containers/Data/PluginKitPlugin
/var/containers/Bundle/Application
/var/mobile/Containers/Bundle/Application
/containers/Bundle/Application
/var/mobile/Containers/Shared/SystemGroup
/containers/Shared/SystemGroup
```

This audit did not add any of these paths to `PXResolvedContainer`. No base-prefix check is appropriate in TASK-1.1. Bundle paths are deliberately outside the enum contract, and canonical allow-list handling remains deferred to TASK-1.3.

## 19. Protected-file checksum table

| Protected file | Initial SHA-256 | Final SHA-256 | Unchanged |
|---|---|---|---|
| `Makefile` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | yes |
| `AppDataCleaner.h` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | yes |
| `AppDataCleaner.m` | `DBDF6E21A70679DCB5D1FCEB9A47D994788E12386CF244F71CBE55160372F87D` | `DBDF6E21A70679DCB5D1FCEB9A47D994788E12386CF244F71CBE55160372F87D` | yes |
| `AppGroupContainerResolver.h` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | yes |
| `AppGroupContainerResolver.m` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | yes |
| `CommandRunner.h` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | yes |
| `CommandRunner.m` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | yes |

`git diff --exit-code` over all seven protected files returned exit code `0`.

## 20. Resource ownership table

| Resource | Owner | Creation | Release/lifetime |
|---|---|---|---|
| requested identifier copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| metadata identifier copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| UUID copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| path copy | `PXResolvedContainer` | successful initializer | object lifetime under ARC |
| temporary validation objects | initializer stack/autorelease pool | during validation | normal ARC/autorelease lifetime |

No raw allocation, file descriptor, process, lock, cache or singleton is introduced.

## 21. Scenario matrix

No compiled target was available. Every row is a source-level `STATIC REVIEW`, not a runtime PASS claim.

| # | Scenario | Expected result | Review | Static evidence |
|---:|---|---|---|---|
| 1 | valid application-data/rootful object | object created | STATIC REVIEW | kind 1 and root 1 accepted; valid exact strings copied |
| 2 | valid application-data/rootless object | object created | STATIC REVIEW | kind 1 and root 2 accepted |
| 3 | valid app-group object | object created | STATIC REVIEW | kind 2 accepted with no identifier-prefix policy |
| 4 | valid extension-data object | object created | STATIC REVIEW | kind 3 accepted |
| 5 | valid PluginKit-data object | object created | STATIC REVIEW | kind 4 accepted |
| 6 | invalid kind zero | nil | STATIC REVIEW | kind switch has no zero case |
| 7 | invalid future kind | nil | STATIC REVIEW | only four explicit switch cases return YES |
| 8 | invalid root zero | nil | STATIC REVIEW | root switch has no zero case |
| 9 | invalid future root | nil | STATIC REVIEW | only two explicit switch cases return YES |
| 10 | nil requested identifier | nil | STATIC REVIEW | runtime `isKindOfClass:` check fails for nil |
| 11 | non-string requested identifier through dynamic call | nil | STATIC REVIEW | runtime type check requires `NSString` |
| 12 | empty requested identifier | nil | STATIC REVIEW | `length == 0` guard |
| 13 | whitespace-only requested identifier | nil | STATIC REVIEW | inverted whitespace-set search finds no content |
| 14 | metadata identifier differs by one character | nil | STATIC REVIEW | exact `isEqualToString:` fails |
| 15 | metadata identifier differs only by case | nil | STATIC REVIEW | exact case-sensitive equality fails |
| 16 | prefix-only metadata match | nil | STATIC REVIEW | no prefix/fuzzy matcher; exact equality required |
| 17 | identifier contains embedded NUL | nil | STATIC REVIEW | U+0000 NSString search covers both identifiers |
| 18 | invalid UUID text | nil | STATIC REVIEW | `NSUUID initWithUUIDString:` returns nil |
| 19 | UUID contains slash | nil | STATIC REVIEW | lexical slash range check |
| 20 | UUID is `.` or `..` | nil | STATIC REVIEW | exact dot-component checks |
| 21 | valid lowercase UUID text | object created and original text preserved | STATIC REVIEW | parser validates; original input is copied, not reformatted |
| 22 | relative container path | nil | STATIC REVIEW | leading `/` required |
| 23 | root path `/` | nil | STATIC REVIEW | exact root-path rejection |
| 24 | trailing-slash path | nil | STATIC REVIEW | trailing `/` rejected |
| 25 | path contains `//` | nil | STATIC REVIEW | lexical `//` range check |
| 26 | path contains `.` component | nil | STATIC REVIEW | literal component equality rejection |
| 27 | path contains `..` component | nil | STATIC REVIEW | literal component equality rejection |
| 28 | path last component differs from UUID | nil | STATIC REVIEW | exact `lastPathComponent` equality required |
| 29 | path contains embedded NUL | nil | STATIC REVIEW | U+0000 NSString search covers path |
| 30 | mutable input string changed after initialization | object values remain unchanged | STATIC REVIEW | all four successful inputs are copied |
| 31 | `copy` called | returns same object pointer | STATIC REVIEW | `copyWithZone:` returns `self` |
| 32 | two independently created equal objects | `isEqual:` YES and hashes equal | STATIC REVIEW | equality and hash use identical six-field set |
| 33 | one field differs | `isEqual:` NO | STATIC REVIEW | every field participates in equality |
| 34 | compare with unrelated object | NO | STATIC REVIEW | class check rejects unrelated objects |
| 35 | path points to missing filesystem object | model may still initialize; no filesystem access | STATIC REVIEW | no filesystem API exists |
| 36 | candidate path has wrong base for root/kind but passes lexical checks | model may initialize; TASK-1.3 owns base policy | STATIC REVIEW | no base allow-list or kind/root prefix coupling exists |

## 22. Verification commands and results

### Required source gates

```text
PXResolvedContainer class declarations: 1
PXResolvedContainer implementations: 1
kind enum declarations: 1
root enum declarations: 1
subclass restricted: 1
NSCopying conformance: 1
public readonly properties: 6
public readwrite properties: 0
setter methods: 0
private ivar marker: 1
designated initializer declarations: 1
designated initializer implementations: 1
init unavailable: 1
new unavailable: 1
string copies: 4
exact identifier equality: 1
copyWithZone: 1
isEqual: 1
hash: 1
```

### Forbidden-source gates

```text
ApplicationBundle: 0
Unknown: 0
KindAny: 0
NSMutableCopying: 0
NSCoding: 0
NSSecureCoding: 0
encodeWithCoder: 0
initWithCoder: 0
JSON: 0
dictionaryRepresentation: 0
setValue:forKey:: 0
containsString: 0
caseInsensitive: 0
identifier prefix/suffix matching: 0
fileExistsAtPath:: 0
stat(: 0
lstat(: 0
realpath: 0
readlink: 0
stringByStandardizingPath: 0
stringByResolvingSymlinksInPath: 0
fileSystemRepresentation: 0
contentsOfDirectoryAtPath: 0
dictionaryWithContentsOfFile: 0
posix_spawn: 0
system(: 0
popen(: 0
CommandRunner: 0
NSLog: 0
dispatch_once: 0
sharedInstance: 0
isSafeToDelete: 0
```

### Existing-production reference gate

Search over all existing `.h`, `.m`, `.mm`, `.xm`, `.c`, `.cc` and `.cpp` files, excluding the two new source files:

```text
existing_production_references=0
```

Within production source, the class name appears only in the two new source files. All other repository matches are backup/restore-hardening documentation, including coordinator status/decisions, the TASK-1.1 specification and this report. It was not imported or instantiated by existing production code.

### Protected-file gate

```text
git diff --exit-code -- Makefile AppDataCleaner.h AppDataCleaner.m AppGroupContainerResolver.h AppGroupContainerResolver.m CommandRunner.h CommandRunner.m
exit: 0
```

### Format checks

```text
git diff --check
exit: 0
```

Because the three TASK-1.1 files are untracked, normal `git diff --check` does not include them. They were separately decoded as UTF-8 and scanned line-by-line:

```text
PXResolvedContainer.h trailing-whitespace lines: 0
PXResolvedContainer.m trailing-whitespace lines: 0
TASK-1.1-REPORT.md trailing-whitespace lines: checked at final verification
```

`git diff --no-index --check` emitted no whitespace-error diagnostic for either source file. Its exit code was `1`, which is expected for a nonempty no-index comparison against an empty source.

### Toolchain

```text
clang=missing
make=missing
```

No local Objective-C/iOS compile or runtime test is claimed. The project-owner GitHub Actions workflow remains the build gate.

## 23. Full diff and diff-stat review

Both new source files were reviewed in full after creation.

New-file metadata before final report verification:

```text
PXResolvedContainer.h
  47 lines
  1,691 bytes
  SHA-256 6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718

PXResolvedContainer.m
  158 lines
  5,304 bytes
  SHA-256 A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB

Combined code diff stat
  2 new text files
  205 inserted lines
  0 deleted lines from existing production files
```

Full review confirmed that the code diff contains only:

- exact enum declarations;
- subclass-restricted immutable class declaration;
- six readonly properties and private ivars;
- one failable designated initializer and validation helpers;
- direct ivar copies;
- `copyWithZone:`;
- full-field `isEqual:` and `hash`.

It contains no resolver, metadata parser, filesystem access, command execution, serialization, deletion decision, base allow-list or existing-production import.

### Generated/binary audit

```text
new binary files: 0
new generated files: 0
PXResolvedContainer.h NUL bytes: 0
PXResolvedContainer.m NUL bytes: 0
report NUL bytes: checked at final verification
```

All task-owned artifacts are plain UTF-8 text.

## 24. Acceptance checklist

- [x] Only `PXResolvedContainer.h`, `PXResolvedContainer.m` and the required report are task-owned changes.
- [x] Required enums exist with exact values.
- [x] No unknown/any/application-bundle kind exists.
- [x] Class conforms to `NSCopying` only.
- [x] Class is subclassing-restricted.
- [x] All six public properties are readonly.
- [x] No readwrite redeclaration or mutation method exists.
- [x] Generic `init` and `new` are unavailable.
- [x] Failable designated initializer exists exactly once.
- [x] Invalid enum values return nil.
- [x] Invalid string types and empty values return nil.
- [x] Whitespace-only identifiers return nil.
- [x] Embedded NUL is rejected.
- [x] Requested and metadata identifiers must match exactly.
- [x] UUID is syntactically valid and stored unchanged.
- [x] Candidate path passes required lexical checks.
- [x] Path last component must equal UUID exactly.
- [x] All strings are copied.
- [x] No filesystem access or canonicalization occurs.
- [x] No base-path allow-list is implemented yet.
- [x] `copyWithZone:` returns self.
- [x] Value equality and matching hash are implemented.
- [x] No serialization support is added.
- [x] No existing production caller imports or instantiates the class.
- [x] Makefile is unchanged.
- [x] Clear/Backup/Restore/Keychain/UI behavior is unchanged.
- [x] Protected files are byte-for-byte unchanged.
- [x] `git diff --check` passes.
- [x] Report is complete.
- [x] GitHub Actions is recorded as PENDING.
- [x] Agent stops after TASK-1.1.

## 25. Remaining risks

1. The local Windows workspace lacks the Objective-C/iOS toolchain, so compiler acceptance of `objc_subclassing_restricted`, target-runtime ivar layout and Foundation API availability must be confirmed by GitHub Actions.
2. Lexical path validation intentionally does not detect symlinks, aliases, mounts, ownership, permissions or canonical base escapes. This is a deliberate TASK-1.3 responsibility.
3. `NSUUID` syntax acceptance follows the target Foundation implementation. The original accepted UUID text is preserved, but runtime behavior still requires build/device verification.
4. The object is not yet consumed. Exact resolver integration belongs to separately specified TASK-1.2 work after review acceptance.
5. Existing Clear resolvers and destructive paths remain unchanged and retain their pre-existing behavior and risks.

## 26. GitHub Actions handoff

The project owner should run the existing GitHub Actions iOS build and verify:

- `PXResolvedContainer.m` is included by the root wildcard;
- the subclassing-restricted attribute is accepted by the target compiler;
- there are no designated-initializer, nullability, property-synthesis or ARC warnings promoted to errors;
- no existing production behavior changes.

No TASK-1.2 implementation, resolver migration, AppDataCleaner import, canonical path validator or Clear change was performed.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
