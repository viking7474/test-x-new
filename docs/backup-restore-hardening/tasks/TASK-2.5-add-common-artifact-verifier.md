# TASK-2.5 — Add Common Backup Artifact Verifier

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `c1d9067bab57085f71fb59443e81506c32237e3a`
- Previous task: TASK-2.4 source review ACCEPTED
- Next task: TASK-2.6 remains LOCKED

## Objective

Add one common fail-closed verifier for every file declared by a supported v2/v3 backup manifest and integrate it into Restore before debug output, tar discovery, process termination, extraction or target mutation.

The verifier must prove that each declared artifact:

- uses a safe relative manifest `name`;
- resolves below the selected backup directory without following a symlink;
- is a regular file;
- has the exact declared size, including zero;
- has a complete lowercase SHA-256 matching the manifest;
- remains the same filesystem object throughout verification.

Every artifact referenced by an included Restore section must have an exact declaration in `manifest.artifacts`.

The recorded artifact `path` field is historical source metadata only. It must never locate, authorize or override a Restore source file.

TASK-2.5 does not inspect tar entries, links inside an archive, compression ratios or extracted staging contents. Those remain TASK-2.6 and later.

## Exact production scope

Allowed production files:

```text
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.5-REPORT.md
```

Implementation commit may contain only those files and the report.

## Protected files

Do not modify:

```text
AppDataBackupManager.h
PXBackupManifestValidator.h/.m
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
AppDataCleaner.h/.m
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
PXClearRequest.h/.m
PXClearResult.h/.m
CommandRunner.h/.m
AppDataBackupRestoreViewController.m
ProfileManagerViewController.m
ProjectXViewController.m
KeychainGroupsViewController.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper files
Makefile
```

Do not edit coordinator task/review/status/roadmap/decision/README files. `Makefile` already compiles root-level `.m` files through a wildcard.

# Part 1 — Exact public API

Create `PXBackupArtifactVerifier.h` with this exact public surface:

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const
    PXBackupArtifactVerifierErrorDomain;

FOUNDATION_EXPORT NSString * const
    PXBackupArtifactVerifierErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXBackupArtifactVerifierErrorCode) {
    PXBackupArtifactVerifierErrorInvalidInput = 1,
    PXBackupArtifactVerifierErrorInvalidReference = 2,
    PXBackupArtifactVerifierErrorUnsafeRelativePath = 3,
    PXBackupArtifactVerifierErrorMissingArtifact = 4,
    PXBackupArtifactVerifierErrorFilesystemInspectionFailed = 5,
    PXBackupArtifactVerifierErrorSymlinkRejected = 6,
    PXBackupArtifactVerifierErrorNotRegularFile = 7,
    PXBackupArtifactVerifierErrorSizeMismatch = 8,
    PXBackupArtifactVerifierErrorInvalidDigest = 9,
    PXBackupArtifactVerifierErrorDigestReadFailed = 10,
    PXBackupArtifactVerifierErrorDigestMismatch = 11,
    PXBackupArtifactVerifierErrorFilesystemChanged = 12,
    PXBackupArtifactVerifierErrorInconsistentManifest = 13,
};

__attribute__((objc_subclassing_restricted))
@interface PXVerifiedBackupArtifactSet : NSObject <NSCopying>

@property (nonatomic, copy, readonly)
    NSArray<NSString *> *artifactNames;

@property (nonatomic, copy, readonly)
    NSDictionary<NSString *, NSString *> *canonicalPathsByName;

- (nullable NSString *)pathForArtifactName:(NSString *)artifactName;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXBackupArtifactVerifier : NSObject

+ (nullable PXVerifiedBackupArtifactSet *)verifiedArtifactsForManifest:(NSDictionary *)manifest
                                                       backupDirectory:(NSString *)backupDirectory
                                                                 error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```

Do not add file-path-only APIs, shell/tar APIs, mutable result properties, expected-bundle parameters, public initializers, bypass flags or warning-only modes.

# Part 2 — Immutable result

`PXVerifiedBackupArtifactSet` must:

- copy its dictionary input;
- expose names sorted by exact `compare:` order;
- expose an immutable exact-name to canonical-path dictionary;
- return `nil` for non-string, empty or unknown lookup input;
- return `self` from `copyWithZone:`;
- contain no descriptors, callbacks, mutable collections, logs or lazy verification.

It is a verification snapshot, not proof that a file cannot be replaced after the call.

# Part 3 — Error contract

Clear `*error` at entry.

Success returns a non-nil result and leaves error nil. Failure returns nil with the fixed verifier domain and exactly one of the 13 codes.

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupArtifactVerifierErrorFieldPathKey
```

Stable paths include:

```text
$
$.data.archive
$.artifacts[0].name
$.artifacts[3].size
$.artifacts[3].sha256
$.appGroups[1].archive
$.systemGlobalLibrary.items[2].archive
```

Do not expose artifact names, recorded paths, backup directory, canonical path, digest, sizes, bundle ID, group ID, archive output, errno text or raw manifest values.

Return the first failure according to the deterministic order below.

# Part 4 — Input checks

The verifier receives an already schema-validated manifest but must still fail closed independently.

Require:

- root manifest is `NSDictionary`;
- backup directory is a nonempty, non-whitespace, NUL-free `NSString`;
- `artifacts` is `NSArray`;
- each declaration is `NSDictionary`;
- every consumed field has the expected runtime category.

Do not call `PXBackupManifestValidator`. Do not mutate or normalize input.

# Part 5 — Artifact identity

For every declaration:

```text
name   = relative artifact identity
path   = ignored historical metadata
size   = exact expected bytes
sha256 = exact expected digest
```

The verifier must have zero authority reads of `artifact[@"path"]`.

Never open, compare, canonicalize or fallback to the recorded path. Moved backup directories remain valid because identity is relative to the currently selected directory.

# Part 6 — Safe relative names

A valid name must:

- be a runtime string;
- be nonempty and contain non-whitespace text;
- contain no NUL;
- not begin or end with `/`;
- not contain `//`;
- split into nonempty `/` components;
- contain no component equal to `.` or `..`.

Do not trim, lowercase, standardize, resolve, percent-decode or expand a tilde.

Reject examples:

```text
/data.tar.gz
../data.tar.gz
groups/../data.tar.gz
groups//a.tar.gz
groups/./a.tar.gz
groups/
```

Backslash is an ordinary Unix filename character, not a separator for this contract.

# Part 7 — Required Restore references

Collect references in this exact order:

1. `$.data.archive` always;
2. each `$.appGroups[i].archive` in array order;
3. `$.preferences.archive` when included;
4. `$.keychain.archive` when included;
5. `$.profileAppData.archive` when included;
6. `$.globalSafari.archive` when included;
7. each system-global item archive when included;
8. each shared-system-DB file archive when included.

Each reference must be a safe relative name and exact-match one declaration name.

An exact duplicate reference across operational sections fails at the later reference with `InvalidReference`. A missing declaration fails at that reference with `MissingArtifact`.

Unreferenced declarations are permitted but must still pass full verification.

# Part 8 — Deterministic declaration processing

1. Validate declaration fields in original array order.
2. Reject duplicate exact names at the later index.
3. Retain each original index.
4. Sort valid declarations by exact name using `compare:`.
5. Perform filesystem, size and hash verification in sorted-name order.

Every declaration must be verified.

# Part 9 — Backup-directory boundary

The selected backup directory must exist, be a real directory at its final path component, not itself be a symlink, and canonicalize with `realpath`.

Normal ancestor aliases such as `/var` to `/private/var` may canonicalize. Do not reject them merely because an ancestor above the selected backup directory is an alias.

Returned artifact paths use the canonical backup-root spelling. Containment must be component/boundary aware, never raw prefix-only matching.

# Part 10 — Symlink-safe opening

Preferred implementation:

- open canonical root as a directory descriptor;
- walk parent components with `openat` and `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`;
- open final artifact with `openat` and `O_RDONLY | O_NOFOLLOW | O_CLOEXEC`;
- use `fstat` on the opened descriptor.

Equivalent descriptor-relative logic is acceptable only if it proves the same properties.

Reject symlink parents, symlink final files, non-directory parents, directories, sockets, FIFOs, devices, open/fstat failures and objects outside the canonical root.

`fileExistsAtPath:` or `attributesOfItemAtPath:` alone are not sufficient authorization. Close every descriptor on every path.

# Part 11 — Exact size

`size` must be a nonnegative integral non-CFBoolean `NSNumber` representable for file-size comparison.

Compare it exactly to `st_size`, including zero. Never skip a zero expected size and never coerce arbitrary objects with `respondsToSelector:`.

Mismatch returns `SizeMismatch` at the declaration's `.size` path.

# Part 12 — SHA-256

Every v2/v3 artifact must have a complete digest:

```text
NSString
exactly 64 ASCII characters
only 0-9 and a-f
lowercase
```

Empty, uppercase, short, long, non-hex, whitespace or `sha256:`-prefixed values fail with `InvalidDigest`.

Hash the already opened descriptor using CommonCrypto SHA-256 and a bounded streaming buffer. Retry `EINTR`; any other read failure returns `DigestReadFailed`. Compare exact lowercase output; mismatch returns `DigestMismatch`.

Do not execute shell, `sha256sum`, `openssl`, `NSTask`, `CommandRunner` or a helper process.

# Part 13 — Identity stability

Call `fstat` before and after hashing. Require unchanged device, inode, regular-file type, size, modification timestamp and status-change timestamp. Do not compare access time.

A change returns `FilesystemChanged`. Do not publish a path for a changed artifact.

# Part 14 — Aggregate consistency

When present:

- `artifactCount` remains governed by TASK-2.1 and must not be changed;
- `totalSize` must equal an overflow-checked sum of all declared sizes and actual verified sizes;
- `archiveChecksum` must be a complete lowercase SHA-256 equal to the declared and verified digest of the artifact referenced by `data.archive`.

Empty or mismatching v3 aggregate values fail with `InconsistentManifest`. Version 2 manifests without those optional fields remain valid.

# Part 15 — Pure verifier boundary

`PXBackupArtifactVerifier.m` may import its header, CommonCrypto and required POSIX headers only.

Forbidden:

- UIKit;
- AppDataBackupManager/AppDataCleaner;
- CommandRunner;
- manifest validator;
- container resolvers/validators;
- Security/Keychain;
- notifications/dispatch/defaults;
- shell/process APIs;
- tar/archive libraries;
- mutable global state;
- caches;
- filesystem mutation;
- raw-value logging.

The verifier is read-only.

# Part 16 — Restore integration ordering

Add exactly one import to `AppDataBackupManager.m`:

```objc
#import "PXBackupArtifactVerifier.h"
```

Required Restore preflight order:

1. public parameter guard;
2. common manifest read and schema/version acceptance;
3. exact requested bundle comparison;
4. exact TASK-2.4 ApplicationData destination resolution/validation;
5. common artifact verification;
6. artifact failure callback and return;
7. warnings, `NSFileManager`, `CommandRunner`, debug state and all remaining work.

Call the verifier exactly once and propagate its exact non-nil `NSError`. Use a generic impossible-state verifier error only if it unexpectedly returns nil without an error.

Artifact failure must complete once on the main queue before debug writes, tar lookup, process kill, extraction or mutation.

# Part 17 — Restore must use verified paths

After verifier success, Restore must stop constructing source paths from `backupDir` plus manifest archive values or hard-coded names.

Use `pathForArtifactName:` for:

- main data archive via `manifest.data.archive`;
- App Group archive via the exact manifest `appGroups` entry for that `groupID`;
- preferences via `preferences.archive`;
- Keychain via `keychain.archive`;
- profile app data via `profileAppData.archive`;
- global Safari via `globalSafari.archive`;
- system-global item archives;
- shared-system-DB file archives.

No Restore artifact source may use:

```objc
[backupDir stringByAppendingPathComponent:archive]
```

Manifest reading and debug files are not artifact consumption.

## App Group mapping

Build one exact `groupID -> archive` dictionary from `manifest.appGroups` after verification.

For each entitled resolved group:

1. exact-lookup its group ID;
2. obtain the verified artifact path;
3. if no manifest mapping exists, warn and continue before wiping the group;
4. wipe/extract only when a verified path exists.

Do not use a sanitized computed filename as source authority. Do not redesign App Group destination resolution or transaction behavior.

# Part 18 — Remove duplicate Restore verification

Remove from Restore:

- the best-effort artifact loop;
- `artByName`;
- Restore calls to `PXVerifyArtifact`;
- manual `data.tar.gz` existence check;
- manual data size check;
- manual data SHA-256 check;
- artifact-preflight manager codes `305`, `314`, `315`;
- `Restore artifact verification:` warnings.

`PXVerifyArtifact` may remain for Backup generation's warning-only self-check. Do not migrate Backup publication.

Main data source becomes:

```text
manifest.data.archive
-> exact declaration name
-> verified canonical path
```

Do not hard-code `data.tar.gz` as Restore source, although current v2/v3 writers continue to emit it.

# Part 19 — Preserve accepted boundaries

Do not change:

- TASK-2.1 manifest validator;
- exact supported versions `{2,3}`;
- validator error propagation and code `201`;
- TASK-2.3 exact bundle comparison and code `304`;
- TASK-2.4 exact destination helper, code `303`, retained model/path and pre-mutation revalidation;
- Backup writer version 3;
- Backup-recorded source path/UUID fields.

Required error precedence:

```text
300 invalid parameters
200 manifest read failure
validator error
201 unsupported version
304 bundle mismatch
303 destination failure
artifact verifier error
301 tar missing
later Restore errors
```

# Part 20 — Preserve TASK-2.6 and later

Do not:

- list tar entries;
- invoke tar/bsdtar listing or libarchive;
- inspect archive member paths or links;
- enforce compression ratio, extracted bytes or member count;
- build `PXRestorePlan`;
- redesign staging;
- add transaction/rollback;
- redesign optional-component destinations;
- add structured Restore result;
- change Backup publication.

These remain TASK-2.6 through TASK-2.14 and Phase 3.

# Part 21 — Static acceptance gates

## Scope

```text
PXBackupArtifactVerifier.h added
PXBackupArtifactVerifier.m added
AppDataBackupManager.m modified
protected production diffs = 0
Makefile diff = 0
```

## Public API

```text
error domain declaration/definition = 1/1
field-path key declaration/definition = 1/1
error enum values = exactly 13
result class definition = 1
verifier class definition = 1
public verifier methods = exactly 1
file-path-only public APIs = 0
```

## Verifier safety

```text
recorded artifact path authority = 0
shell/process/CommandRunner calls = 0
filesystem mutation = 0
whole-file NSData loading = 0
safe relative-name validation present
openat/O_NOFOLLOW-equivalent traversal present
regular-file fstat present
zero-inclusive exact size comparison present
64 lowercase hex policy present
streaming SHA-256 present
EINTR handling present
before/after identity comparison present
all descriptors closed
```

## Reference coverage

```text
data reference = 1
appGroups iteration = 1
preferences included reference = 1
keychain included reference = 1
profile included reference = 1
global Safari included reference = 1
system-global iteration = 1
shared-DB iteration = 1
missing declarations fail closed
cross-section duplicate references fail closed
unreferenced declarations still verified
```

## Restore

```text
artifact verifier import = 1
verifier calls in Restore = 1
verifier calls in Backup = 0
verification precedes warnings/runner/debug/tar/kill
exact verifier NSError propagation present
Restore PXVerifyArtifact calls = 0
Restore artByName = 0
Restore artifact warning prefix = 0
manual main data size/hash block = 0
hard-coded Restore data.tar.gz source = 0
Restore artifact backupDir joins = 0
verified lookup for every current component
App Group lookup precedes group wipe
```

## Non-regression

```text
supported versions = {2,3}
exact bundle comparison = 1
exact destination helper = 1
pre-mutation destination revalidation = 1
Backup writer manifestVersion @3 = 1
Backup PXVerifyArtifact behavior retained
archive-entry inspection additions = 0
restore-plan additions = 0
transaction additions = 0
```

# Part 22 — Required scenarios

Report at least 110 explicit scenario rows, including:

1. valid v2 complete hashes;
2. valid v3 aggregate metadata;
3. moved backup with stale absolute recorded paths;
4. absolute artifact name;
5. leading/trailing slash;
6. doubled slash;
7. dot component;
8. dot-dot component;
9. NUL;
10. whitespace-only name;
11. duplicate declaration;
12. duplicate cross-section reference;
13. missing data declaration;
14. missing App Group declaration;
15. missing preferences declaration;
16. missing Keychain declaration;
17. missing profile declaration;
18. missing global Safari declaration;
19. missing system-global declaration;
20. missing shared-DB declaration;
21. valid unreferenced declaration;
22. missing unreferenced declaration;
23. absent backup directory;
24. backup directory final symlink;
25. backup directory not directory;
26. symlink parent under root;
27. final artifact symlink;
28. final directory;
29. FIFO/socket/device;
30. open or fstat failure;
31. expected and actual zero;
32. expected zero actual nonzero;
33. nonzero size mismatch;
34. Boolean/floating/invalid size;
35. empty digest;
36. uppercase digest;
37. short/long/non-hex digest;
38. EINTR read retry;
39. hard read failure;
40. digest mismatch;
41. replacement during verification;
42. size/mtime/ctime change during hashing;
43. totalSize exact/mismatch/overflow;
44. archiveChecksum exact/empty/mismatch;
45. v2 aggregate fields absent;
46. stable field-path error;
47. no raw values in error;
48. sorted immutable result;
49. copy returns self;
50. unknown lookup nil;
51. verification before debug/tar/kill/extraction/mutation;
52. exact verifier error propagation;
53. verified paths for all component types;
54. exact App Group manifest mapping;
55. unbacked installed group is not wiped;
56. old best-effort/manual blocks removed;
57. Backup self-check retained;
58. no archive-entry inspection;
59. no restore plan/transaction;
60. TASK-2.1 through TASK-2.4 non-regression.

Add descriptor cleanup, deterministic ordering, boundary containment and protected-file cases to reach at least 110 rows.

# Part 23 — Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.5-REPORT.md
```

Include:

- baseline and exact scope;
- protected SHA-256 before/after;
- public API/error enum;
- immutable result;
- relative path and recorded-path non-authority;
- reference inventory/order;
- descriptor-relative symlink safety;
- regular-file, size and digest proof;
- before/after identity proof;
- aggregate consistency;
- Restore ordering and exact error propagation;
- verified path inventory for every component;
- App Group pre-wipe lookup;
- old verification removal;
- TASK-2.1 through TASK-2.4 non-regression;
- TASK-2.6 boundary;
- complete source diff and static counts;
- at least 110 scenarios;
- whitespace/CRLF/NUL/generated audit;
- build status and remaining risks.

End exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 24 — Verification and commit

Before editing:

```powershell
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Before commit:

```powershell
git diff --check
git diff --stat -- PXBackupArtifactVerifier.h PXBackupArtifactVerifier.m AppDataBackupManager.m
git diff -- PXBackupArtifactVerifier.h PXBackupArtifactVerifier.m AppDataBackupManager.m
git diff --exit-code -- <protected files>
```

After commit:

```powershell
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff c1d9067bab57085f71fb59443e81506c32237e3a..HEAD --check
git diff --name-status c1d9067bab57085f71fb59443e81506c32237e3a..HEAD
```

Implementation commit only:

```text
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.5-REPORT.md
```

Suggested subject:

```text
phase2(task-2.5): add common artifact verifier
```

Stop after TASK-2.5. Do not implement TASK-2.6.
