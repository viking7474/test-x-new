# TASK-1.3 Agent Report — Canonical Destructive Path Validator

## 1. Task metadata and scope

| Field | Value |
|---|---|
| Task | `TASK-1.3` |
| Task specification | `docs/backup-restore-hardening/tasks/TASK-1.3-canonical-destructive-path-validator.md` |
| Workspace | `C:\Users\VanVan\Documents\github\test-x` |
| Branch | `newok` |
| Production scope | Create `PXDestructivePathValidator.h/.m` only |
| Documentation scope | Create this report only |
| Existing production files modified | None |
| Caller migration | None |
| Destructive operation added | None |
| Local Objective-C build | Not run; `clang` and `make` are unavailable in the workspace |
| Runtime validation | Not run; every scenario is classified `STATIC REVIEW` |

TASK-1.3 creates a standalone validator that converts an immutable `PXResolvedContainer` discovery result into a canonical path only after fixed-base authorization, POSIX filesystem inspection, live metadata identity revalidation, and final filesystem identity checks.

The validator does not authorize or perform deletion. It is not imported or instantiated by any existing production source in this task.

Explicitly out of scope and not performed:

- TASK-1.4;
- importing the validator into `AppDataCleaner`;
- migrating Clear Data, Backup, Restore, Keychain, or UI;
- using a validated path for deletion;
- removing application-bundle writes;
- creating `PXClearRequest` or `PXClearResult`;
- modifying current fuzzy resolvers;
- modifying existing App Group or Backup metadata helpers.

## 2. Required reading completed

The following files were read before implementation:

- `docs/backup-restore-hardening/README.md`
- `docs/backup-restore-hardening/STATUS.md`
- `docs/backup-restore-hardening/DECISIONS.md`
- `docs/backup-restore-hardening/reviews/TASK-1.1-REVIEW.md`
- `docs/backup-restore-hardening/reviews/TASK-1.2-REVIEW.md`
- `docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md`
- `docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md`
- `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
- `PXResolvedContainer.h`
- `PXResolvedContainer.m`
- `PXDataContainerResolver.h`
- `PXDataContainerResolver.m`
- `Makefile`
- `AppDataCleaner.h`
- the complete `AppDataCleaner.m`
- `AppGroupContainerResolver.h`
- `AppGroupContainerResolver.m`
- metadata-validation-related sections of `AppDataBackupManager.m`

The audit established these boundaries:

1. `PXResolvedContainer` is an immutable lexical snapshot and intentionally does not authorize destructive use.
2. `PXDataContainerResolver` performs exact root-specific discovery but intentionally does not canonicalize or authorize a path.
3. legacy `AppDataCleaner` resolvers remain fuzzy or first-match in several paths and must remain unchanged in TASK-1.3.
4. `AppGroupContainerResolver` accepts metadata string/array values but does not enforce the TASK-1.3 duplicate-exact-entry policy.
5. `AppDataBackupManager` contains independent multi-base and LaunchServices fallback behavior and must not be reused or changed by this validator task.

## 3. Initial working-tree baseline

Initial `git status --short`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? PXDataContainerResolver.h
?? PXDataContainerResolver.m
?? PXResolvedContainer.h
?? PXResolvedContainer.m
?? docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md
?? docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-0.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.2-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.1-immutable-resolved-container.md
?? docs/backup-restore-hardening/tasks/TASK-1.2-exact-application-data-container-resolver.md
?? docs/backup-restore-hardening/tasks/TASK-1.3-canonical-destructive-path-validator.md
```

The modified documentation and untracked TASK-1.1/TASK-1.2 production files were treated as coordinator-owned baseline. They were not edited, staged, reverted, formatted, or claimed as TASK-1.3 changes.

Repository-state transition observed during final verification:

```text
HEAD=a2f5de8 (newok, origin/newok) t?sk 1.2
final protected tracked diff: clean
final working-tree entries: TASK-1.3 files only
```

By final verification, the earlier TASK-1.1/TASK-1.2 baseline files were tracked and clean at `a2f5de8`. No TASK-1.3 workflow command invoked `git add`, `git commit`, `git reset`, `git checkout`, staging, or reversion. Initial-to-final SHA-256 equality independently proves their contents were not changed by TASK-1.3.

At baseline, all three TASK-1.3 target files were absent:

```text
PXDestructivePathValidator.h=False
PXDestructivePathValidator.m=False
docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md=False
```

## 4. Files created

Exactly these task-owned files were created:

```text
PXDestructivePathValidator.h
PXDestructivePathValidator.m
docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md
```

No existing production file was changed.

## 5. Public API and exact error enum

The header imports the immutable model directly:

```objc
#import "PXResolvedContainer.h"
```

Public error domain:

```objc
FOUNDATION_EXPORT NSString * const PXDestructivePathValidatorErrorDomain;
```

Exact error enum:

```objc
typedef NS_ENUM(NSInteger, PXDestructivePathValidatorErrorCode) {
    PXDestructivePathValidatorErrorInvalidInput = 1,
    PXDestructivePathValidatorErrorCandidatePathMismatch = 2,
    PXDestructivePathValidatorErrorFilesystemInspectionFailed = 3,
    PXDestructivePathValidatorErrorSymlinkRejected = 4,
    PXDestructivePathValidatorErrorCanonicalizationFailed = 5,
    PXDestructivePathValidatorErrorCanonicalBaseViolation = 6,
    PXDestructivePathValidatorErrorCrossDeviceBoundary = 7,
    PXDestructivePathValidatorErrorOwnershipOrModeViolation = 8,
    PXDestructivePathValidatorErrorMetadataInvalid = 9,
    PXDestructivePathValidatorErrorIdentityMismatch = 10,
    PXDestructivePathValidatorErrorFilesystemChanged = 11,
};
```

Exact class and sole public method:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXDestructivePathValidator : NSObject

- (nullable NSString *)validatedCanonicalPathForContainer:(PXResolvedContainer *)container
                                                    error:(NSError * _Nullable * _Nullable)error;

@end
```

There are no additional public methods, aliases, convenience methods, configuration objects, custom-base parameters, or extra error codes.

## 6. Success and failure contract

At method entry:

```objc
if (error != NULL) {
    *error = nil;
}
```

Success behavior:

- returns a new immutable `NSString` initialized from `canonicalCandidate`;
- never returns the raw model path merely because it was lexically accepted;
- leaves the supplied error pointer nil;
- returns only after both final filesystem identity rechecks;
- the returned canonical path has no trailing slash.

Failure behavior:

- returns nil;
- sets one validator-domain error when an error pointer is supplied;
- never returns a partially checked path;
- does not downgrade a failed safety check to a no-match result;
- error descriptions are concise and contain no metadata contents or directory listings;
- captured POSIX failures may be attached through `NSUnderlyingErrorKey` using `NSPOSIXErrorDomain`.

## 7. Error mapping

| Error code | Implemented conditions |
|---|---|
| `InvalidInput` | non-`PXResolvedContainer`; invalid kind/root; non-string or invalid fields; unequal model identifiers; invalid UUID; U+0000; failed TASK-1.1 lexical invariants |
| `CandidatePathMismatch` | raw model path differs by any character from fixed allowed base plus exact UUID |
| `FilesystemInspectionFailed` | NULL filesystem representation; initial candidate inspection failure/non-directory; canonical stat failure/non-directory; unresolved `mobile` account |
| `SymlinkRejected` | initial raw candidate is a symlink; initial metadata object is a symlink |
| `CanonicalizationFailed` | base, candidate, or metadata `realpath` failure; canonical C path cannot be converted losslessly to `NSString` |
| `CanonicalBaseViolation` | canonical candidate is not exactly one immediate child of canonical base; canonical metadata filename/parent is not exact |
| `CrossDeviceBoundary` | candidate device differs from canonical base device; metadata device differs from candidate device |
| `OwnershipOrModeViolation` | candidate owner is not `mobile`; candidate/base is world-writable as prohibited; metadata owner/mode is invalid |
| `MetadataInvalid` | missing/non-regular/malformed metadata; missing or invalid key/type/content; duplicate exact App Group array occurrence |
| `IdentityMismatch` | valid live metadata does not exactly equal model identifiers; App Group array has zero exact occurrences |
| `FilesystemChanged` | initial raw candidate identity differs from canonical stat; final candidate or metadata object fails type/symlink/device/inode recheck |

Path-to-C conversion failure remains `FilesystemInspectionFailed`, including conversion attempted near a later phase. A failed final POSIX `lstat` or changed final object is `FilesystemChanged`.

## 8. Fixed kind/root base matrix

| Kind | Rootful base | Rootless base |
|---|---|---|
| `ApplicationData` | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| `ExtensionData` | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| `AppGroup` | `/private/var/mobile/Containers/Shared/AppGroup` | `/containers/Shared/AppGroup` |
| `PluginKitData` | `/private/var/mobile/Containers/Data/PluginKitPlugin` | `/containers/Data/PluginKitPlugin` |

The source contains exactly six fixed base literals, one for each distinct path.

The implementation has:

- no application-bundle mapping;
- no `/var/mobile/...` rootful alias;
- no `/private/var/containers/...` fallback;
- no custom base input;
- no fallback base scan;
- no cross-root scan.

## 9. Input validation

Validation occurs before filesystem authorization.

The implementation requires:

- runtime object is `PXResolvedContainer`;
- kind is one of `ApplicationData`, `AppGroup`, `ExtensionData`, or `PluginKitData`;
- root is exactly `Rootful` or `Rootless`;
- all four string properties are runtime `NSString` objects;
- all four string properties are nonempty;
- both identifiers contain at least one non-whitespace/newline character;
- all string properties reject U+0000 where applicable;
- requested and metadata identifiers are exactly equal through `isEqualToString:`;
- UUID has no slash and is neither `.` nor `..`;
- UUID parses through `NSUUID`;
- container path is absolute, non-root, has no trailing slash, no duplicate separator, no `.`/`..` component, and has exact UUID as its final component.

The code does not trim, lowercase, uppercase, normalize, standardize, resolve symlinks through Foundation, or rewrite any model field.

## 10. Exact raw candidate-path equality

The only expected raw path is built from the fixed mapping:

```objc
NSString *expectedRawPath = [allowedBase stringByAppendingPathComponent:containerUUID];
```

Authorization requires exact equality:

```objc
if (![containerPath isEqualToString:expectedRawPath]) {
    // CandidatePathMismatch
}
```

Therefore all of these fail before POSIX canonicalization:

- `/var/mobile/...` alias;
- wrong kind base;
- wrong root base;
- sibling UUID;
- nested extra component;
- trailing separator;
- raw symlink alias path;
- any case or character difference.

## 11. POSIX path conversion

Every path passed to POSIX APIs uses `fileSystemRepresentation` while its owning `NSString` remains alive.

Properties of the implementation:

- no borrowed C pointer is stored in an object, global, collection, or asynchronous block;
- pointers are used immediately for one POSIX phase;
- a NULL representation fails closed as `FilesystemInspectionFailed`;
- `errno` is captured immediately after each failing `lstat`, `stat`, or `realpath` call;
- POSIX errors are optionally attached as `NSUnderlyingErrorKey`;
- canonical C strings are converted with `initWithBytes:length:encoding:` and no lossy conversion.

## 12. Initial raw candidate lstat policy

The first filesystem operation on the exact raw candidate is `lstat`.

Required checks:

1. exact raw candidate has a valid filesystem representation;
2. `lstat` succeeds;
3. `S_ISLNK` is false;
4. `S_ISDIR` is true.

Mappings:

- failed inspection or non-directory: `FilesystemInspectionFailed`;
- symlink: `SymlinkRejected`.

The initial `struct stat` snapshot is retained on the stack for later device/inode comparison.

## 13. Canonicalization policy

Three independent `realpath` calls are present:

1. fixed allowed base;
2. exact raw candidate;
3. exact metadata path under canonical candidate.

Each uses a separate `PATH_MAX` stack buffer. No heap-allocated `realpath` result exists, so there is no `free` ownership path.

Failures map to `CanonicalizationFailed`. Conversion of a successful canonical C buffer to `NSString` must be complete and non-lossy.

## 14. Canonical immediate-child containment proof

After base and candidate canonicalization, the validator requires:

1. canonical base is absolute and non-root;
2. canonical candidate is absolute and non-root;
3. neither accepted canonical path ends with a slash;
4. canonical candidate is not equal to canonical base;
5. canonical candidate last component equals exact model UUID;
6. deleting exactly the last component of canonical candidate equals canonical base exactly.

The decisive containment relation is:

```objc
[canonicalCandidateParent isEqualToString:canonicalBase]
```

No raw prefix authorization exists. Source counts show:

```text
hasPrefix:: 0
```

This rejects prefix collisions such as `/base2`, descendants deeper than one component, and candidates whose canonical parent escapes the fixed canonical base.

## 15. Canonical stat and device/inode consistency

The implementation makes exactly two canonical `stat` calls:

- canonical base;
- canonical candidate.

Both must exist and be directories.

The canonical candidate must retain the exact initial raw-candidate identity:

```text
canonicalCandidate.st_dev == initialCandidate.st_dev
canonicalCandidate.st_ino == initialCandidate.st_ino
```

A mismatch maps to `FilesystemChanged`.

The canonical candidate must also share the canonical base device:

```text
canonicalCandidate.st_dev == canonicalBase.st_dev
```

A mismatch maps to `CrossDeviceBoundary`, rejecting a separate mount at the child location.

## 16. Mobile ownership and mode policy

The implementation resolves the `mobile` account deterministically with:

```c
getpwnam_r("mobile", ...)
```

It uses a fixed 16,384-byte stack buffer and never falls back to current process UID, root UID, or a hard-coded numeric UID.

If lookup fails or returns no user, validation fails as `FilesystemInspectionFailed`.

Authorization requires:

- canonical candidate `st_uid` equals resolved mobile UID;
- candidate mode has `S_IWOTH` clear;
- canonical base mode has `S_IWOTH` clear.

A failure maps to `OwnershipOrModeViolation`.

`st_gid` is present in the captured POSIX snapshots but is intentionally not compared or used as an authorization criterion because TASK-1.3 permits rootful/rootless group assignment differences.

No ownership or mode mutation is performed.

## 17. Metadata-file safety

The only metadata path is constructed under canonical candidate:

```text
<canonical candidate>/.com.apple.mobile_container_manager.metadata.plist
```

There is no `.com.apple.containermanagerd.metadata.plist` fallback.

Before reading, initial metadata `lstat` requires:

- successful inspection;
- non-symlink;
- regular file;
- same `st_dev` as canonical candidate;
- owner equal to resolved mobile UID;
- not world-writable.

Mappings:

- missing or non-regular: `MetadataInvalid`;
- symlink: `SymlinkRejected`;
- different device: `CrossDeviceBoundary`;
- invalid owner/mode: `OwnershipOrModeViolation`.

The metadata path is then canonicalized independently. Authorization requires:

- last component equals the one permitted metadata filename exactly;
- canonical metadata parent equals canonical candidate exactly.

A failed `realpath` maps to `CanonicalizationFailed`; an escaped or renamed canonical location maps to `CanonicalBaseViolation`.

## 18. Live metadata identity policy

Metadata is read only after path, type, ownership, mode, device, and canonical-parent checks.

The implementation reads only:

```text
MCMMetadataIdentifier
```

No filename scan, content scan, company-name heuristic, short-name heuristic, extension-prefix logic, case folding, or normalized comparison exists.

### ApplicationData, ExtensionData, PluginKitData

For these kinds:

- live value must be a valid runtime `NSString`;
- it must be nonempty, non-whitespace-only, and contain no U+0000;
- it must exactly equal `requestedIdentifier`;
- it must exactly equal `metadataIdentifier`.

Invalid shape/content maps to `MetadataInvalid`. A valid but different identity maps to `IdentityMismatch`.

### AppGroup string behavior

A live string follows the same valid-string and exact-two-identifier requirements.

### AppGroup array behavior

For a live array:

- only runtime string elements can satisfy identity;
- non-string elements are ignored and never treated as matches;
- exact case-sensitive equality against requested identifier is counted;
- zero exact occurrences maps to `IdentityMismatch`;
- more than one exact occurrence maps to `MetadataInvalid`;
- exactly one occurrence must also equal model metadata identifier.

This explicitly closes the duplicate-exact-entry ambiguity not enforced by the legacy App Group helper.

## 19. Final TOCTOU recheck

After live metadata identity succeeds, the validator performs two final `lstat` calls:

1. exact raw candidate path;
2. exact canonical metadata path.

Final candidate requirements:

- still exists;
- is not a symlink;
- is still a directory;
- `st_dev` and `st_ino` equal the initial candidate snapshot.

Final metadata requirements:

- still exists;
- is not a symlink;
- is still a regular file;
- `st_dev` and `st_ino` equal the initial metadata snapshot.

A failed or changed final object maps to `FilesystemChanged`.

Ordering evidence from the final source:

```text
255 initial candidate lstat
288 allowed-base realpath
315 candidate realpath
355 canonical-base stat
381 canonical-candidate stat
442 initial metadata lstat
490 metadata realpath
517 metadata dictionary read
615 final raw-candidate lstat
643 final canonical-metadata lstat
661 canonical NSString return
```

The return occurs only after both final identity rechecks.

## 20. Why the canonical return value matters

The validated result is the canonical candidate string, not the model's raw candidate path. Future destructive callers must use this returned canonical value rather than reconstructing or reusing a lexical alias.

TASK-1.3 does not connect such a caller. A future destructive caller must invoke validation immediately before use because validation reduces but does not eliminate TOCTOU after return.

## 21. Proof of no caller migration

Search across existing production source extensions, excluding the two new validator files:

```text
PXDestructivePathValidator references: 0
validatedCanonicalPathForContainer references: 0
```

Therefore:

- no existing source imports the validator;
- no existing source instantiates it;
- no existing source calls its method;
- no Clear, Backup, Restore, Keychain, UI, resolver, or deletion path changed;
- successful output cannot reach deletion in TASK-1.3.

## 22. Proof of no deletion, permission, process, or concurrency API

Counts in the two new source files:

```text
CommandRunner: 0
NSTask: 0
posix_spawn: 0
system(: 0
popen(: 0
dispatch_apply: 0
dispatch_async: 0
dispatch_sync: 0
dispatch_once: 0
removeItemAtPath:: 0
unlink(: 0
rmdir(: 0
remove(: 0
chmod(: 0
chown(: 0
fchmod(: 0
fchown(: 0
```

The implementation has no background queue, shared mutable state, singleton, cache, shell command, command output, deletion eligibility method, or permission mutation.

## 23. Resource ownership table

| Resource | Ownership/lifetime | Release behavior |
|---|---|---|
| `PXResolvedContainer` input | caller-owned Objective-C object; strongly referenced for synchronous method duration | ARC |
| model string locals | Objective-C references while method is active | ARC |
| returned canonical string | new immutable `NSString` initialized from canonical candidate | ARC return semantics |
| `NSError` and userInfo | Objective-C objects created only on failure | ARC |
| three `PATH_MAX` canonical buffers | stack | automatic at scope exit |
| `struct stat` snapshots | stack | automatic at scope exit |
| passwd lookup buffer | fixed 16,384-byte stack buffer | automatic at helper return |
| `struct passwd *result` | pointer into caller-supplied lookup buffer | never retained beyond helper call |
| `fileSystemRepresentation` pointers | borrowed from live owning `NSString` | used immediately; never retained or freed |
| metadata dictionary/array/string values | Objective-C objects loaded synchronously | ARC |
| file descriptors | none opened directly | not applicable |
| heap-allocated canonical buffers | none | not applicable |
| subprocesses/queues/cache | none | not applicable |

No explicit `malloc`, `calloc`, `realloc`, or `free` ownership path is introduced.

## 24. Protected-file checksums

TASK-1.1 and TASK-1.2 files were untracked baseline. Checksum equality, rather than tracked diff alone, proves they were not changed.

| Protected file | Initial SHA-256 | Final SHA-256 | Unchanged |
|---|---|---|---|
| `PXResolvedContainer.h` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | `6BA935CB659EBDC5FDB8A96B13DD9F1450ACB2E284267AC82E8890287A686718` | Yes |
| `PXResolvedContainer.m` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | `A782089C0605F8D7803FFB53F746A585AFB85F3FFBC9ED111F00575D77ADA8FB` | Yes |
| `PXDataContainerResolver.h` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | `D8A24BCCC9953FFF83CCF96F177BA33DAD1497EA62CEC7D17B78CFB8F2DED885` | Yes |
| `PXDataContainerResolver.m` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | `06B2DADA542DFB344DD36B1449A5B6B8FDD52874BA6AD8693CEDA2229EE39F30` | Yes |
| `Makefile` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | `22FB8F6E6095132F1AA6FACDB9C7A9995BF96DB47005DF31B82061C0A98C940F` | Yes |
| `AppDataCleaner.h` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | `B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E` | Yes |
| `AppDataCleaner.m` | `DBDF6E21A70679DCB5D1FCEB9A47D994788E12386CF244F71CBE55160372F87D` | `DBDF6E21A70679DCB5D1FCEB9A47D994788E12386CF244F71CBE55160372F87D` | Yes |
| `AppGroupContainerResolver.h` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | `4F2A95CAE8F5C0DF5262F81B46061BFD45EAFBCDEADB0CA87C95F50BA3F32FCC` | Yes |
| `AppGroupContainerResolver.m` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | `FACF3865907F031B0FFE870BFE5494AF418DB1EE0EDEC838F1AF5E50D579002A` | Yes |
| `AppDataBackupManager.h` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | `21B2A8DA95E155FF910CFEF0F489211C02A58E1A2B7486DA253871BEADC82D03` | Yes |
| `AppDataBackupManager.m` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | `C40F4204D96D77211921320F8C43C889FE92D1714358BA37CA4713D2F43D6636` | Yes |
| `CommandRunner.h` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | `63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF` | Yes |
| `CommandRunner.m` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | `2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030` | Yes |

Protected tracked diff result:

```text
git diff --exit-code -- <protected files>: exit 0
```

## 25. Source-token gates

### Public contract

```text
PXDestructivePathValidator interface: 1
PXDestructivePathValidator implementation: 1
validatedCanonicalPathForContainer declaration: 1
validatedCanonicalPathForContainer implementation: 1
error-domain declaration: 1
error-domain definition: 1
PXResolvedContainer header import: 1
objc_subclassing_restricted: 1
public methods in header: 1
error enum entries: 11
entry error clear: 1
canonical return statement: 1
```

### POSIX and path gates

```text
lstat calls: 4
realpath calls: 3
stat calls excluding lstat: 2
fileSystemRepresentation uses: 9
getpwnam_r calls: 1
PATH_MAX stack buffers: 3
raw hasPrefix containment authorization: 0
```

The four `lstat` calls are initial candidate, initial metadata, final candidate, and final metadata. The three `realpath` calls are fixed base, raw candidate, and metadata. The two `stat` calls are canonical base and canonical candidate.

### Fixed base literals

```text
/private/var/mobile/Containers/Data/Application: 1
/containers/Data/Application: 1
/private/var/mobile/Containers/Shared/AppGroup: 1
/containers/Shared/AppGroup: 1
/private/var/mobile/Containers/Data/PluginKitPlugin: 1
/containers/Data/PluginKitPlugin: 1
/var/mobile rootful alias literal: 0
application-bundle base literal: 0
custom-base API/token: 0
```

### Metadata and exact identity

```text
MCMMetadataIdentifier literal: 1
mobile-container-manager metadata filename: 1
containermanagerd fallback filename: 0
isEqualToString:requestedIdentifier comparisons: 3
isEqualToString:metadataIdentifier comparisons: 4
containsString:: 0
hasPrefix:: 0
hasSuffix:: 0
lowercaseString: 0
uppercaseString: 0
case-insensitive comparison: 0
trimming/standardizing/Foundation symlink resolution: 0
```

### Forbidden operation gates

```text
CommandRunner: 0
NSTask: 0
posix_spawn: 0
system(: 0
popen(: 0
dispatch_apply: 0
dispatch_async: 0
dispatch_sync: 0
dispatch_once: 0
removeItemAtPath:: 0
unlink(: 0
rmdir(: 0
remove(: 0
chmod(: 0
chown(: 0
fchmod(: 0
fchown(: 0
PXClearRequest: 0
PXClearResult: 0
```

### Existing production references

```text
PXDestructivePathValidator: 0
validatedCanonicalPathForContainer: 0
```

## 26. Complete static scenario matrix

No compiled iOS target was available. Every row is therefore classified `STATIC REVIEW`, not runtime PASS.

| # | Scenario | Required outcome | Evidence | Result |
|---:|---|---|---|---|
| 1 | valid rootful ApplicationData | canonical path | fixed rootful application-data mapping, exact raw equality, full validation, canonical return | STATIC REVIEW |
| 2 | valid rootless ApplicationData | canonical path | fixed rootless application-data mapping and same validation flow | STATIC REVIEW |
| 3 | valid rootful ExtensionData | canonical path | ExtensionData shares only the permitted application-data base | STATIC REVIEW |
| 4 | valid rootless ExtensionData | canonical path | rootless ExtensionData fixed mapping | STATIC REVIEW |
| 5 | valid rootful AppGroup with string metadata | canonical path | AppGroup base plus exact valid string branch | STATIC REVIEW |
| 6 | valid AppGroup with array metadata and one exact occurrence | canonical path | exact occurrence count equals one and matches both model identifiers | STATIC REVIEW |
| 7 | valid rootful PluginKitData | canonical path | fixed PluginKit rootful base and non-AppGroup exact metadata branch | STATIC REVIEW |
| 8 | nil/non-model input | InvalidInput | runtime class guard | STATIC REVIEW |
| 9 | invalid kind/root cast | InvalidInput | explicit enum allow-list checks | STATIC REVIEW |
| 10 | model identifiers no longer equal | InvalidInput | exact model identifier equality before filesystem work | STATIC REVIEW |
| 11 | raw candidate uses `/var/mobile` alias | CandidatePathMismatch | expected raw path uses only `/private/var/mobile/...` | STATIC REVIEW |
| 12 | raw candidate belongs to wrong kind base | CandidatePathMismatch | kind/root fixed base builds exact expected path | STATIC REVIEW |
| 13 | raw candidate has extra nested component | CandidatePathMismatch | exact expected path equality | STATIC REVIEW |
| 14 | candidate missing | FilesystemInspectionFailed | initial exact raw candidate lstat failure mapping | STATIC REVIEW |
| 15 | candidate is regular file | FilesystemInspectionFailed | initial `S_ISDIR` requirement | STATIC REVIEW |
| 16 | candidate is symlink to directory | SymlinkRejected | initial lstat and `S_ISLNK` check before realpath | STATIC REVIEW |
| 17 | base realpath fails | CanonicalizationFailed | independent base realpath mapping | STATIC REVIEW |
| 18 | candidate realpath fails | CanonicalizationFailed | independent raw candidate realpath mapping | STATIC REVIEW |
| 19 | canonical candidate parent differs from canonical base | CanonicalBaseViolation | exact parent equality | STATIC REVIEW |
| 20 | prefix collision such as `/base2` | CanonicalBaseViolation | no prefix authorization; exact parent relation required | STATIC REVIEW |
| 21 | canonical last component differs from UUID | CanonicalBaseViolation | exact last-component equality | STATIC REVIEW |
| 22 | raw lstat and canonical stat inode differ | FilesystemChanged | initial/canonical device+inode comparison | STATIC REVIEW |
| 23 | candidate is separate mount/device | CrossDeviceBoundary | candidate/base `st_dev` equality | STATIC REVIEW |
| 24 | mobile account lookup fails | FilesystemInspectionFailed | deterministic lookup failure mapping | STATIC REVIEW |
| 25 | candidate owner is not mobile | OwnershipOrModeViolation | candidate `st_uid` exact check | STATIC REVIEW |
| 26 | candidate is world-writable | OwnershipOrModeViolation | candidate `S_IWOTH` rejection | STATIC REVIEW |
| 27 | canonical base is world-writable | OwnershipOrModeViolation | base `S_IWOTH` rejection | STATIC REVIEW |
| 28 | metadata missing | MetadataInvalid | initial metadata lstat failure mapping | STATIC REVIEW |
| 29 | metadata is directory/non-regular | MetadataInvalid | `S_ISREG` requirement | STATIC REVIEW |
| 30 | metadata is symlink | SymlinkRejected | metadata lstat symlink check | STATIC REVIEW |
| 31 | metadata is separate device | CrossDeviceBoundary | metadata/candidate `st_dev` equality | STATIC REVIEW |
| 32 | metadata owner/mode invalid | OwnershipOrModeViolation | mobile owner and no world-write checks | STATIC REVIEW |
| 33 | metadata canonical parent escapes candidate | CanonicalBaseViolation | exact canonical metadata parent equality | STATIC REVIEW |
| 34 | malformed plist | MetadataInvalid | dictionary type validation | STATIC REVIEW |
| 35 | identifier missing or non-string for ApplicationData | MetadataInvalid | valid runtime string requirement | STATIC REVIEW |
| 36 | metadata differs only by case | IdentityMismatch | exact case-sensitive equality only | STATIC REVIEW |
| 37 | metadata prefix-only match | IdentityMismatch | no prefix/fuzzy matching | STATIC REVIEW |
| 38 | AppGroup array has zero exact occurrence | IdentityMismatch | exact occurrence count zero branch | STATIC REVIEW |
| 39 | AppGroup array has two exact occurrences | MetadataInvalid | duplicate exact occurrence branch | STATIC REVIEW |
| 40 | candidate replaced during metadata read | FilesystemChanged | final raw candidate lstat identity comparison | STATIC REVIEW |
| 41 | metadata replaced during read | FilesystemChanged | final canonical metadata lstat identity comparison | STATIC REVIEW |
| 42 | successful result | canonical candidate, not raw alias | immutable string initialized from canonical candidate after final checks | STATIC REVIEW |
| 43 | validator result used for deletion | impossible in TASK-1.3 | zero existing production references and no deletion API | STATIC REVIEW |
| 44 | application bundle candidate | impossible; no kind/base mapping | only four model data-container kinds are allowed | STATIC REVIEW |

## 27. Acceptance checklist

- [x] Only `PXDestructivePathValidator.h/.m` are created as production changes.
- [x] Public API and exact error enum match the specification.
- [x] Validator returns canonical NSString path, not BOOL or raw candidate.
- [x] All four data-container kinds and both roots map to fixed bases.
- [x] Application bundle has no mapping.
- [x] Raw candidate path must exactly equal fixed base plus UUID.
- [x] Candidate lstat rejects symlink and non-directory.
- [x] Base, candidate, and metadata are canonicalized with POSIX semantics.
- [x] Canonical candidate parent equals canonical base exactly.
- [x] Prefix-only containment is not used.
- [x] Candidate stays on the canonical base device.
- [x] Initial and canonical candidate inode/device identities agree.
- [x] Mobile UID ownership policy is enforced.
- [x] Base, candidate, and metadata world-writable modes are rejected as specified.
- [x] Metadata is a non-symlink regular file on the candidate device.
- [x] Only mobile-container-manager metadata filename is accepted.
- [x] Live metadata exact identity is revalidated.
- [x] AppGroup string/array exact policy is implemented.
- [x] Final candidate and metadata inode/device rechecks occur before return.
- [x] No partial or raw path is returned on failure.
- [x] No existing caller references the validator.
- [x] No deletion, permission change, shell, or process API is added.
- [x] Protected files remain unchanged.
- [x] `git diff --check` and new-file whitespace checks pass.
- [x] Report and audits are complete.
- [x] GitHub Actions remains PENDING in the agent report.
- [x] Agent stops after TASK-1.3.

## 28. Verification results

### Source review

The complete header and complete 664-line implementation were reviewed after creation.

A lexical delimiter scanner that ignores strings, character literals, and comments reported:

```text
state=code
unclosed=[]
errors=[]
```

### Whitespace and diff checks

Final verification records:

```text
git diff --check: PASS
protected git diff --exit-code: PASS
new-file trailing whitespace: 0
new-file NUL bytes: 0
no-index diff --check diagnostics: none
```

For untracked files, `git diff --no-index --check NUL <file>` returns exit 1 because content differs from an empty file; empty stdout/stderr proves no whitespace diagnostic. Direct trailing-whitespace scanning is also zero.

### Toolchain

```text
clang=missing
make=missing
```

No Objective-C/iOS build or runtime scenario is claimed.

## 29. Full diff and diff-stat review

Because all TASK-1.3 files are new and untracked, each was reviewed through a full `git diff --no-index NUL <file>` representation.

Measured source stats:

```text
PXDestructivePathValidator.h | 31 insertions
PXDestructivePathValidator.m | 664 insertions
```

Report stat after creation:

```text
docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md | 876 insertions
```

Full review confirmed that task-owned content is limited to:

- exact public validator/error contract;
- private fixed base constants and validation helpers;
- synchronous POSIX inspection and metadata revalidation;
- this report.

No existing-file hunk exists.

## 30. Generated, binary, and NUL-byte audit

Task-owned file types:

```text
.h
.m
.md
```

Audit result:

```text
generated/binary task files: 0
NUL bytes in task files: 0
object/archive/library/executable/image/PDF artifacts: 0
```

No build output, cache, archive, binary, image, plist fixture, or generated project file was created.

## 31. Remaining risks

1. Final identity rechecks reduce but do not eliminate TOCTOU after the validator returns. A future destructive caller must validate immediately before use.
2. Device/inode rechecks do not detect in-place metadata-content mutation that preserves the same inode. TASK-1.3 follows the required identity policy and does not introduce descriptor-bound parsing.
3. Trusted fixed base components may themselves be system aliases; the task explicitly canonicalizes the fixed base and compares exact canonical parent identity rather than rejecting trusted base aliases.
4. The fixed 16,384-byte `getpwnam_r` buffer fails closed on `ERANGE`; there is no current-UID fallback.
5. Ownership expectations must be validated on representative rootful and rootless devices because no compiled target was available locally.
6. Existing resolvers and callers remain unmodified. Their current fuzzy, first-match, alias, or fallback behavior is not made safe merely by creating this unused validator.
7. App Group array handling is statically reviewed but not exercised against real device metadata.
8. The validator returns an authorized canonical path but does not itself establish deletion eligibility, perform deletion, or retain an open descriptor across caller use.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
