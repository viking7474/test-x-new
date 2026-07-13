# TASK-1.2 Report — Exact Application-Data Container Resolver

## 1. Task metadata

- Task: `TASK-1.2-exact-application-data-container-resolver`
- Phase: Phase 1 — Clear Data Safety Boundary
- Workspace: `C:\Users\VanVan\Documents\github\test-x`
- Branch observed at task execution: `newok`
- Scope: introduce a standalone, exact, root-specific application-data container resolver.
- Production files allowed: create `PXDataContainerResolver.h` and `PXDataContainerResolver.m` only.
- Required report: `docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md`.
- Local Objective-C build: NOT RUN; `clang` and `make` were not available in the workspace environment.
- Runtime target scenarios: NOT RUN.
- Scenario evidence classification: `STATIC REVIEW` only.

TASK-1.2 does not migrate any existing caller and does not authorize deletion. TASK-1.3 remains out of scope.

## 2. Initial working-tree state

Initial `git status --short` before creating TASK-1.2 files:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? PXResolvedContainer.h
?? PXResolvedContainer.m
?? docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-0.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.1-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.1-immutable-resolved-container.md
?? docs/backup-restore-hardening/tasks/TASK-1.2-exact-application-data-container-resolver.md
```

The modified/untracked documentation and TASK-1.1 artifacts above were present before TASK-1.2. They were treated as coordinator-owned baseline state and were not edited, staged, reverted or formatted by this task.

The TASK-1.2 targets did not exist at baseline:

```text
PXDataContainerResolver.h=False
PXDataContainerResolver.m=False
docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md=False
```

Baseline diff for all protected production files returned exit code `0`.

## 3. Required reading completed

The following files were read before creating TASK-1.2 production files:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.1-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `docs/backup-restore-hardening/tasks/TASK-1.2-exact-application-data-container-resolver.md`
8. `PXResolvedContainer.h`
9. `PXResolvedContainer.m`
10. `Makefile`
11. `AppDataCleaner.h`
12. complete `AppDataCleaner.m`
13. `AppGroupContainerResolver.h`
14. complete `AppGroupContainerResolver.m`
15. complete `AppDataBackupManager.m`

The reading confirmed that TASK-1.2 must remain a standalone resolver contract. Existing Clear and Backup/Restore resolution paths remain unchanged.

## 4. Files created

Task-owned files:

```text
PXDataContainerResolver.h
PXDataContainerResolver.m
docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md
```

No existing production file was modified.

## 5. Public header contract

`PXDataContainerResolver.h` imports the accepted immutable model directly:

```objc
#import "PXResolvedContainer.h"
```

The error domain is exported:

```objc
FOUNDATION_EXPORT NSString * const PXDataContainerResolverErrorDomain;
```

The error enum has exactly four values:

```objc
typedef NS_ENUM(NSInteger, PXDataContainerResolverErrorCode) {
    PXDataContainerResolverErrorInvalidInput = 1,
    PXDataContainerResolverErrorEnumerationFailed = 2,
    PXDataContainerResolverErrorAmbiguousMatch = 3,
    PXDataContainerResolverErrorInvalidCandidate = 4,
};
```

The resolver is subclassing-restricted and exposes one resolution method:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXDataContainerResolver : NSObject

- (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                          root:(PXResolvedContainerRoot)root
                                                                         error:(NSError * _Nullable * _Nullable)error;

@end
```

The API has no custom base-path argument, no batch API, no asynchronous API and no deletion-related method.

## 6. Error domain and code contract

The implementation defines the exported domain once:

```objc
NSString * const PXDataContainerResolverErrorDomain = @"PXDataContainerResolverErrorDomain";
```

At method entry, the resolver clears a supplied error pointer:

```objc
if (error != NULL) {
    *error = nil;
}
```

Error mapping:

| Condition | Return | Error |
|---|---|---|
| invalid identifier runtime type | `nil` | `PXDataContainerResolverErrorInvalidInput` |
| nil/empty/whitespace-only/NUL identifier | `nil` | `PXDataContainerResolverErrorInvalidInput` |
| invalid root enum | `nil` | `PXDataContainerResolverErrorInvalidInput` |
| selected base absent | `nil` | none |
| selected base exists but is not a directory | `nil` | `PXDataContainerResolverErrorEnumerationFailed` |
| immediate-child enumeration fails | `nil` | `PXDataContainerResolverErrorEnumerationFailed` |
| no valid exact metadata match | `nil` | none |
| exactly one valid exact match | resolved object | none |
| second valid exact match in selected root | `nil` | `PXDataContainerResolverErrorAmbiguousMatch` |
| exact metadata match cannot construct the accepted value object | `nil` | `PXDataContainerResolverErrorInvalidCandidate` |

Error descriptions are concise and do not contain metadata content, command output or directory listings.

## 7. Identifier and root validation

Identifier validation is performed before filesystem access.

Required runtime checks implemented:

- value must be an `NSString` at runtime;
- length must be greater than zero;
- at least one character must be outside `whitespaceAndNewlineCharacterSet`;
- Unicode U+0000 must not be present.

The resolver does not trim, lowercase, standardize or otherwise rewrite a valid identifier.

Root validation accepts only:

```objc
PXResolvedContainerRootRootful
PXResolvedContainerRootRootless
```

Zero, negative-cast values and future unknown enum values fail with `InvalidInput`.

## 8. Embedded-NUL detection

U+0000 detection remains in NSString space:

```objc
unichar nulCharacter = 0;
NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
return [value rangeOfString:nulString].location != NSNotFound;
```

The resolver does not use `UTF8String`, C-string length or truncation behavior to detect NUL.

The helper is applied to:

- requested identifier;
- metadata identifier;
- directory entry names.

## 9. Fixed root mapping

The implementation contains exactly two fixed application-data bases:

| Root enum | Selected base |
|---|---|
| `PXResolvedContainerRootRootful` | `/private/var/mobile/Containers/Data/Application` |
| `PXResolvedContainerRootRootless` | `/containers/Data/Application` |

One method call selects exactly one base through a root switch.

The implementation does not:

- scan both roots in one call;
- scan `/var/mobile/Containers/Data/Application` as an alias;
- scan `/private/var/containers/Data/Application`;
- fall back to a different base;
- accept a custom base from a caller.

## 10. Base and enumeration policy

Resolution is synchronous, sequential and local to the method call.

Base handling:

```objc
BOOL baseIsDirectory = NO;
if (![fileManager fileExistsAtPath:basePath isDirectory:&baseIsDirectory]) {
    return nil;
}
if (!baseIsDirectory) {
    // EnumerationFailed
}
```

This preserves the required distinction:

- missing selected base: no match, no error;
- existing non-directory base: enumeration failure.

Immediate children are loaded only with:

```objc
contentsOfDirectoryAtPath:error:
```

There is no recursion. Runtime-string entries are collected and then sorted deterministically with:

```objc
[childNames sortUsingSelector:@selector(compare:)];
```

The result scan is a normal sequential `for` loop. There is no `dispatch_apply`, background queue or shared mutable result.

## 11. Directory-entry filtering

An immediate child is considered only when all of the following are true:

- runtime type is `NSString`;
- name is nonempty;
- name is not `.`;
- name is not `..`;
- name does not begin with `.`;
- name contains no `/`;
- name contains no U+0000;
- name parses with `[[NSUUID alloc] initWithUUIDString:...]`;
- the candidate path exists and is a directory.

The single `hasPrefix:` call in the new implementation is:

```objc
[entry hasPrefix:@"."]
```

It is solely the allowed hidden-directory filter. It is not applied to either requested or metadata identifiers.

The UUID string is retained exactly as returned by directory enumeration. It is not replaced with `UUIDString`, uppercased or reformatted.

## 12. Metadata filename and key policy

For an eligible candidate directory, the resolver reads only:

```text
.com.apple.mobile_container_manager.metadata.plist
```

The implementation does not reference or fall back to:

```text
.com.apple.containermanagerd.metadata.plist
```

The plist must load as an `NSDictionary`. The resolver reads only:

```text
MCMMetadataIdentifier
```

The metadata identifier must:

- be an `NSString` at runtime;
- be nonempty;
- contain at least one non-whitespace/newline character;
- contain no U+0000.

Malformed plists, absent keys, non-string values and invalid metadata identifiers are skipped as non-matches.

No filename scan, container-content scan, app-name heuristic, company-name heuristic or extension-prefix heuristic exists in the new resolver.

## 13. Exact equality proof

The sole requested-to-metadata match is:

```objc
if (![metadataIdentifier isEqualToString:identifier]) {
    continue;
}
```

Source gates confirm:

```text
exact metadata equality: 1
containsString:: 0
lowercaseString: 0
case-insensitive matching: 0
identifier prefix/suffix matching: 0
```

The implementation therefore rejects:

- case-only differences;
- prefix-only matches;
- suffix-only matches;
- substring matches;
- company/app short-name similarities.

The exact strings are passed unchanged into `PXResolvedContainer`.

## 14. Candidate construction

A matched candidate is constructed exactly once with the accepted value-object initializer:

```objc
PXResolvedContainer *candidate = [[PXResolvedContainer alloc]
    initWithKind:PXResolvedContainerKindApplicationData
            root:root
 requestedIdentifier:identifier
  metadataIdentifier:metadataIdentifier
       containerUUID:containerUUID
       containerPath:containerPath];
```

TASK-1.2 constructs only `PXResolvedContainerKindApplicationData`.

No AppGroup, ExtensionData, PluginKitData or application-bundle kind is constructed.

If this initializer returns `nil` after an exact metadata match, resolution stops immediately and returns `PXDataContainerResolverErrorInvalidCandidate`. The exact match is not silently discarded.

## 15. Ambiguity handling

The resolver retains at most one local candidate during the sequential scan.

- zero valid exact candidates: return `nil`, no error;
- one valid exact candidate: return that object, no error;
- second valid exact candidate: return `nil` with `AmbiguousMatch`.

Sorting is used only for deterministic traversal. It is not used to select a winner.

The implementation does not choose:

- first exact match as a final answer when another exact match exists;
- newest directory;
- lexically smallest/largest UUID;
- arbitrary enumeration order.

## 16. No-match semantics

The following are normal no-match outcomes and leave `*error == nil`:

- selected base does not exist;
- selected base is an empty directory;
- candidate metadata file is absent;
- metadata plist is malformed;
- `MCMMetadataIdentifier` is missing;
- metadata identifier has the wrong type or invalid content;
- metadata identifier differs from the requested identifier;
- every directory entry is hidden, malformed, non-UUID or not a directory.

This separates absence of a matching container from invalid input, enumeration failure, ambiguity and invalid exact candidates.

## 17. Proof no fuzzy resolver logic exists

Static source-token results for the two new files:

```text
containsString:: 0
lowercaseString: 0
caseInsensitive: 0
metadata identifier hasPrefix: matching: 0
metadata identifier hasSuffix: matching: 0
company-name heuristic: 0
app short-name heuristic: 0
filename/content scan: 0
extension-prefix matching: 0
```

The only `hasPrefix:` token is the explicitly allowed hidden-entry test `[entry hasPrefix:@"."]`.

## 18. Existing resolver audit and unchanged proof

The required legacy resolvers were audited but not modified.

| Selector | Baseline line | Normalized method SHA-256 | Existing behavior observed |
|---|---:|---|---|
| `findDataContainerUUID:aggressive:` | 1725 | `EB25F47D6A827B15F76FAD78A828038A74A907224C70C6790103DE2CD95DFD39` | exact then fuzzy metadata/content scan, first match |
| `findDataContainerUUID:` | 1762 | `B94E04F47C12182B6F037C50C042E8484F946B8205A4670D0E2BB6A7BBDD5AD7` | delegates to aggressive path; legacy code remains |
| `findRootlessDataContainerUUID:aggressive:` | 1784 | `0E9868BAA6333CB336CCFF25808AF2AF3EC5021C35EAB7FE62C19D7506DEB800` | exact then fuzzy metadata/content scan, first match |
| `findRootlessDataContainerUUID:` | 1817 | `664CFADE0AF80957224054C4EF485ECC5B130A56A803C2C9DD77F6D8EA09B647` | delegates to aggressive path; legacy code remains |
| `optimized_findDataContainerUUID:inDirectories:` | 3522 | `F55C07FF2CF25CA9BEDAE6E4ABC4A638506E981F95E89621336FB5D88C02B2C6` | concurrent fuzzy scan with shared result |
| `optimized_findRootlessDataContainerUUID:inDirectories:` | 3554 | `16574A6D0C384526B80E8395DDC0EFB0A198E8E87BC1136A172C643B2D853FE8` | concurrent fuzzy scan with shared result |
| `findDataContainerUUIDForBundleID:` | 5100 | `22DBCB772242B8CC5E9C221407E539A2C5A2E4149C90FB3EEB0D38F3FAA88515` | aliases existing resolver |

`AppDataCleaner.m` is a protected file and its final SHA-256 equals baseline, proving these methods are byte-for-byte unchanged as part of the file.

`AppDataBackupManager.m` was also audited. It currently prefers LaunchServices and uses its own multi-base metadata fallback. It was not imported into, migrated to or otherwise changed by TASK-1.2.

## 19. Proof no existing caller changed

A static search across existing production source files, excluding the two new resolver files, returned:

```text
PXDataContainerResolver existing production references: 0
```

Therefore no existing file imports, instantiates or invokes the new resolver.

Consequences:

- Clear behavior is unchanged;
- Backup behavior is unchanged;
- Restore behavior is unchanged;
- Keychain behavior is unchanged;
- UI behavior is unchanged;
- no resolver result reaches a deletion path.

## 20. Proof no process, command, deletion or permission API exists

Static gates for the two new source files:

```text
CommandRunner: 0
NSTask: 0
posix_spawn: 0
system(: 0
popen(: 0
shell token: 0
dispatch_apply: 0
removeItemAtPath:: 0
file deletion APIs: 0
chmod: 0
chown: 0
permission-changing APIs: 0
```

The resolver uses `NSFileManager` only for base/candidate directory checks and immediate-child enumeration.

## 21. No canonical or destructive-path authorization

The source contains none of the following:

```text
realpath: 0
readlink: 0
stringByStandardizingPath: 0
stringByResolvingSymlinksInPath: 0
isSafeToDelete: 0
canDelete: 0
ownership validation: 0
mount validation: 0
```

The returned path is a candidate identity path only. It is not proof of canonical location, ownership, mount safety, symlink safety or deletion eligibility.

TASK-1.3 remains responsible for the destructive-path safety boundary.

## 22. Resource ownership table

| Resource | Owner | Creation | Release/lifetime |
|---|---|---|---|
| error object | caller through optional error pointer | only on explicit failure outcome | normal ARC lifetime |
| selected fixed-base string | static process storage | Objective-C string constant | process lifetime |
| raw child-name array | resolver invocation | `contentsOfDirectoryAtPath:error:` | normal ARC/autorelease lifetime |
| filtered/sorted mutable child-name array | resolver invocation | local `NSMutableArray` | normal ARC/autorelease lifetime |
| candidate path string | resolver invocation, then copied by model on success | `stringByAppendingPathComponent:` | local ARC lifetime; model owns copy |
| metadata path string | resolver invocation | `stringByAppendingPathComponent:` | local ARC lifetime |
| metadata dictionary | resolver invocation | `dictionaryWithContentsOfFile:` | normal ARC/autorelease lifetime |
| temporary `NSUUID` parser object | directory-entry validation | `initWithUUIDString:` | normal ARC lifetime |
| first resolved candidate | resolver invocation; returned to caller if unique | `PXResolvedContainer` designated initializer | ARC; caller receives object |
| requested identifier/model fields | `PXResolvedContainer` | copied by accepted model initializer | model lifetime under ARC |

No raw allocation, file descriptor, process, dispatch queue, cache or singleton is introduced.

## 23. Protected-file checksums

All protected files were hashed before implementation and again after implementation.

| Protected file | Initial SHA-256 | Final SHA-256 | Unchanged |
|---|---|---|---|
| `PXResolvedContainer.h` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | YES |
| `PXResolvedContainer.m` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | YES |
| `Makefile` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | YES |
| `AppDataCleaner.h` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | YES |
| `AppDataCleaner.m` | `DBDF6E21A70679DCB5D1FCEB9A47D994788E12386CF244F71CBE55160372F87D` | `DBDF6E21A70679DCB5D1FCEB9A47D994788E12386CF244F71CBE55160372F87D` | YES |
| `AppGroupContainerResolver.h` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | YES |
| `AppGroupContainerResolver.m` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | YES |
| `AppDataBackupManager.h` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | YES |
| `AppDataBackupManager.m` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | YES |
| `CommandRunner.h` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | YES |
| `CommandRunner.m` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | YES |

Protected-file diff exit code: `0`.

## 24. Required source-token gates

Final static counts for `PXDataContainerResolver.h/.m`:

```text
PXDataContainerResolver interface: 1
PXDataContainerResolver implementation: 1
resolveApplicationDataContainerForIdentifier declaration: 1
resolveApplicationDataContainerForIdentifier implementation: 1
PXDataContainerResolverErrorDomain declaration: 1
PXDataContainerResolverErrorDomain definition: 1
PXResolvedContainer header import: 1
objc_subclassing_restricted: 1
PXResolvedContainerKindApplicationData construction: 1
rootful fixed base: 1
rootless fixed base: 1
forbidden /var/mobile root alias: 0
MCMMetadataIdentifier: 1
mobile_container_manager metadata filename: 1
containermanagerd fallback filename: 0
exact requested/metadata isEqualToString: 1
error pointer clear at entry: 1
compare: deterministic sort: 1
containsString:: 0
lowercaseString: 0
case-insensitive matching: 0
identifier prefix/suffix matching: 0
CommandRunner: 0
NSTask: 0
posix_spawn: 0
system(: 0
popen(: 0
dispatch_apply: 0
file deletion APIs: 0
permission-changing APIs: 0
canonicalization APIs: 0
```

The only source `hasPrefix:` count is `1`, for `[entry hasPrefix:@"."]`.

## 25. Scenario matrix

No compiled iOS target or runtime fixture was available. Every row below is classified as `STATIC REVIEW` and is not claimed as runtime PASS.

| # | Scenario | Required outcome | Evidence | Status |
|---:|---|---|---|---|
| 1 | valid exact rootful match | rootful application-data object | root switch selects private rootful base; exact metadata constructs ApplicationData model | STATIC REVIEW |
| 2 | valid exact rootless match | rootless application-data object | root switch selects `/containers` base; exact metadata constructs model with rootless enum | STATIC REVIEW |
| 3 | selected base absent | nil, no error | failed base existence check returns directly after entry error clear | STATIC REVIEW |
| 4 | selected base exists but is file | enumeration error | existing base with `baseIsDirectory == NO` maps to EnumerationFailed | STATIC REVIEW |
| 5 | enumeration fails | enumeration error | nil/non-array result or nonnil enumeration error maps to EnumerationFailed | STATIC REVIEW |
| 6 | nil identifier | invalid-input error | runtime NSString validation rejects nil | STATIC REVIEW |
| 7 | dynamic non-string identifier | invalid-input error | `isKindOfClass:[NSString class]` rejects dynamic non-string | STATIC REVIEW |
| 8 | empty identifier | invalid-input error | identifier length must be greater than zero | STATIC REVIEW |
| 9 | whitespace-only identifier | invalid-input error | inverted whitespace/newline character-set search must find a character | STATIC REVIEW |
| 10 | identifier contains U+0000 | invalid-input error | NSString U+0000 helper rejects it | STATIC REVIEW |
| 11 | invalid root enum | invalid-input error | only two accepted root values pass | STATIC REVIEW |
| 12 | no metadata file | candidate skipped | dictionary load is non-dictionary/nil and scan continues | STATIC REVIEW |
| 13 | malformed metadata plist | candidate skipped | metadata must load as NSDictionary | STATIC REVIEW |
| 14 | metadata key missing | candidate skipped | nil key value fails metadata identifier validation | STATIC REVIEW |
| 15 | metadata identifier non-string | candidate skipped | shared runtime NSString validation rejects it | STATIC REVIEW |
| 16 | metadata exact match | candidate considered | single exact `isEqualToString:` gate reaches model construction | STATIC REVIEW |
| 17 | metadata differs by case | no match | exact case-sensitive equality fails | STATIC REVIEW |
| 18 | metadata prefix-only match | no match | no prefix matching exists; exact equality fails | STATIC REVIEW |
| 19 | metadata substring match | no match | no substring matching exists; exact equality fails | STATIC REVIEW |
| 20 | hidden directory entry | skipped | allowed `[entry hasPrefix:@"."]` filter | STATIC REVIEW |
| 21 | non-UUID directory entry | skipped | `NSUUID initWithUUIDString:` must succeed | STATIC REVIEW |
| 22 | UUID entry is not directory | skipped | candidate `fileExistsAtPath:isDirectory:` must report directory | STATIC REVIEW |
| 23 | exact match produces invalid value object | invalid-candidate error | nil model result immediately maps to InvalidCandidate | STATIC REVIEW |
| 24 | two exact matches in one root | ambiguous-match error, no object | second valid candidate immediately maps to AmbiguousMatch | STATIC REVIEW |
| 25 | one rootful and one rootless match via separate calls | each call can return its own object | each call selects one root only; no cross-root deduplication | STATIC REVIEW |
| 26 | metadata exists only under containermanagerd filename | no match | fallback filename is absent from source | STATIC REVIEW |
| 27 | candidate is symlink to directory | may resolve lexically; TASK-1.3 decides safety | NSFileManager directory check may follow link; no canonical authorization exists | STATIC REVIEW |
| 28 | caller requests custom base | impossible | public API exposes only identifier/root/error | STATIC REVIEW |
| 29 | existing fuzzy resolver source | byte-for-byte unchanged | protected AppDataCleaner checksum and method hashes unchanged | STATIC REVIEW |
| 30 | successful object used for deletion | impossible in TASK-1.2 | existing production references are zero; no deletion method exists | STATIC REVIEW |

## 26. Verification commands and results

Verification categories completed:

1. initial `git status --short`;
2. baseline SHA-256 for all protected files;
3. full required-reading review;
4. exact legacy resolver body audit;
5. full content review of both new source files;
6. exact public-contract counts;
7. fixed-root and metadata literal counts;
8. exact-equality and no-fuzzy token gates;
9. process/deletion/permission/canonicalization token gates;
10. existing-production reference search;
11. final protected checksums;
12. protected-file diff;
13. `git diff --check`;
14. untracked new-file whitespace checks;
15. full no-index diff review for each new file;
16. diff-stat review;
17. generated/binary audit;
18. final working-tree review.

Toolchain availability:

```text
clang=missing
make=missing
```

Therefore no local Objective-C compile or device runtime test is claimed.

## 27. Full diff and diff-stat review

The complete contents of both source files were reviewed after creation.

Source diff summary:

```text
PXDataContainerResolver.h: 25 inserted lines
PXDataContainerResolver.m: 179 inserted lines
```

The source diff contains only:

- the exported error contract;
- the subclassing-restricted resolver interface;
- fixed-root constants;
- input/entry validation helpers;
- synchronous sequential enumeration;
- exact metadata matching;
- immutable candidate construction;
- explicit error mapping.

It contains no modification hunk for any existing file.

The report is a new Markdown file only. Final no-index diff/stat and whitespace results are recorded in the final verification output below.

## 28. Generated and binary audit

Task-created files are plain-text Objective-C header/implementation and Markdown.

Audit result:

```text
generated files: 0
binary files: 0
NUL bytes in task-created artifacts: 0
```

No object files, archives, build directories, generated source, images or packaged artifacts were created.

## 29. Acceptance checklist

- [x] Only two new production files and the required report are task-owned changes.
- [x] Public resolver/error contract matches the specification.
- [x] Resolver is root-specific.
- [x] Fixed rootful/rootless bases are exact.
- [x] Only immediate UUID-named directories are considered.
- [x] Only the exact mobile-container-manager metadata filename is read.
- [x] Only string `MCMMetadataIdentifier` is accepted.
- [x] Matching is exact and case-sensitive.
- [x] No fuzzy, prefix, substring or content heuristic exists.
- [x] Successful result kind is always application data.
- [x] Zero matches is not an error.
- [x] Multiple exact matches fail closed as ambiguous.
- [x] Invalid exact candidate fails closed.
- [x] No shell, command runner or process API is used.
- [x] No canonical/destructive path validator is implemented.
- [x] No deletion or permission operation is implemented.
- [x] No existing resolver or caller is changed.
- [x] Protected files remain unchanged.
- [x] Makefile remains unchanged.
- [x] `git diff --check` and new-file whitespace checks pass.
- [x] Full diff and generated/binary audit are complete.
- [x] GitHub Actions is recorded as PENDING.
- [x] Agent stops after TASK-1.2.

## 30. Remaining risks

1. No local Apple Objective-C/Foundation toolchain was available, so compile compatibility must be confirmed by project-owner GitHub Actions.
2. `fileExistsAtPath:isDirectory:` may treat a symlink to a directory as a directory. TASK-1.2 intentionally does not canonicalize or authorize this path; TASK-1.3 must enforce destructive-path safety.
3. The resolver reads container metadata synchronously. This is required by the contract; future callers must choose an appropriate calling context when migration is separately authorized.
4. An inaccessible selected base may be indistinguishable from an absent base at the initial existence check. Enumeration failures after a visible directory are mapped explicitly. Runtime behavior should be observed on supported jailbreak layouts.
5. Duplicate exact metadata identifiers deliberately make resolution unavailable through `AmbiguousMatch`; operational remediation belongs outside this value-resolution contract.
6. Existing fuzzy Clear and multi-base Backup/Restore resolvers remain active because caller migration is explicitly forbidden in TASK-1.2.

## 31. GitHub Actions handoff

Project-owner CI should verify:

- Foundation/Objective-C compilation of both new root-level files;
- support for `objc_subclassing_restricted` in the configured compiler;
- root wildcard inclusion without Makefile modification;
- warning policy for `NSDictionary dictionaryWithContentsOfFile:` and nullability annotations;
- behavior on representative rootful/rootless fixtures;
- ambiguity and invalid-candidate error paths;
- no accidental caller integration.

TASK-1.3 was not started.

No existing resolver was migrated or modified.

No resolver result was connected to deletion.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
