# TASK-1.3 — Canonical Destructive Path Validator

## Metadata

- Phase: Phase 1 — Clear Data Safety Boundary
- Status: READY
- Dependency: TASK-1.2 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md`
- Allowed production files: create `PXDestructivePathValidator.h` and `PXDestructivePathValidator.m`
- Suggested commit: `phase1(task-1.3): add canonical destructive path validator`

## Objective

Add one standalone validator that accepts an immutable `PXResolvedContainer`, revalidates it against the live filesystem and returns the canonical container path only when every destructive-path safety invariant passes.

TASK-1.3 creates the safety boundary but does not connect it to any destructive caller.

It must not:

- import the validator into `AppDataCleaner`;
- migrate a Clear, Backup, Restore or Keychain caller;
- execute deletion, chmod, chown or command operations;
- modify a resolver;
- remove application-bundle writes;
- add typed Clear requests/results;
- start TASK-1.4 or later work.

A successful return means the canonical path passed validation at that instant. It is not a permanent authorization token. Future destructive callers must validate immediately before use and must use the returned canonical path rather than `container.containerPath`.

## Required reading

Before editing, read:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-1.1-REVIEW.md`
5. `docs/backup-restore-hardening/reviews/TASK-1.2-REVIEW.md`
6. `docs/backup-restore-hardening/reports/TASK-1.1-REPORT.md`
7. `docs/backup-restore-hardening/reports/TASK-1.2-REPORT.md`
8. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
9. `PXResolvedContainer.h`
10. `PXResolvedContainer.m`
11. `PXDataContainerResolver.h`
12. `PXDataContainerResolver.m`
13. `Makefile`
14. `AppDataCleaner.h`
15. Complete `AppDataCleaner.m`
16. `AppGroupContainerResolver.h`
17. `AppGroupContainerResolver.m`
18. Relevant metadata-validation code in `AppDataBackupManager.m`

Audit existing destructive base paths, but do not modify any existing file.

## Allowed changes

Create only:

```text
PXDestructivePathValidator.h
PXDestructivePathValidator.m
```

Create the required report:

```text
docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md
```

Do not modify:

- `PXResolvedContainer.h/.m`;
- `PXDataContainerResolver.h/.m`;
- `Makefile`;
- `AppDataCleaner.h/.m`;
- `AppGroupContainerResolver.h/.m`;
- `AppDataBackupManager.h/.m`;
- `CommandRunner.h/.m`;
- any existing production source.

The root Makefile wildcard already includes new root-level `.m` files. Do not edit the Makefile.

## Public API

`PXDestructivePathValidator.h` must import:

```objc
#import "PXResolvedContainer.h"
```

Declare exactly one error domain:

```objc
FOUNDATION_EXPORT NSString * const PXDestructivePathValidatorErrorDomain;
```

Declare exactly these error codes:

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

Do not add aliases or additional error codes in TASK-1.3.

Declare the class:

```objc
__attribute__((objc_subclassing_restricted))
@interface PXDestructivePathValidator : NSObject

- (nullable NSString *)validatedCanonicalPathForContainer:(PXResolvedContainer *)container
                                                     error:(NSError * _Nullable * _Nullable)error;

@end
```

Do not expose:

- custom base paths;
- policy flags;
- asynchronous APIs;
- batch validation;
- deletion methods;
- boolean `isSafeToDelete` convenience methods;
- a method returning the raw candidate path.

## Return and error contract

At method entry:

```objc
if (error != NULL) {
    *error = nil;
}
```

Success:

- return a new immutable `NSString` containing the canonical container path;
- leave `*error == nil`;
- returned path must be the canonical candidate path, not `container.containerPath` unless they are already identical;
- returned path must not have a trailing slash;
- return must occur only after final filesystem identity recheck.

Failure:

- return `nil`;
- set one validator-domain error when an error pointer is supplied;
- do not silently downgrade a failed safety check into no match;
- do not return a partially validated path.

Error descriptions must be concise and must not include metadata contents, directory listings or command output. A POSIX failure may be attached as `NSUnderlyingErrorKey` using `NSPOSIXErrorDomain` and the captured `errno` value.

## Fixed kind/root allow-list

Map `kind` and `root` to exactly one lexical base:

| Kind | Rootful base | Rootless base |
|---|---|---|
| `PXResolvedContainerKindApplicationData` | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| `PXResolvedContainerKindExtensionData` | `/private/var/mobile/Containers/Data/Application` | `/containers/Data/Application` |
| `PXResolvedContainerKindAppGroup` | `/private/var/mobile/Containers/Shared/AppGroup` | `/containers/Shared/AppGroup` |
| `PXResolvedContainerKindPluginKitData` | `/private/var/mobile/Containers/Data/PluginKitPlugin` | `/containers/Data/PluginKitPlugin` |

Rules:

- all four accepted `PXResolvedContainerKind` values must be supported;
- both accepted roots must be supported;
- application bundle paths must not be representable;
- no unknown/default base is allowed;
- no `/var/mobile/...` alias may be accepted for rootful input;
- no fallback base is allowed;
- no caller-controlled base is allowed;
- invalid enum state returns `InvalidInput`.

## Input validation

Before filesystem access:

1. `container` must be a runtime `PXResolvedContainer` instance.
2. `kind` and `root` must map to one fixed base.
3. `requestedIdentifier`, `metadataIdentifier`, `containerUUID` and `containerPath` must all be runtime `NSString` values.
4. All four strings must be nonempty.
5. Both identifiers must contain at least one non-whitespace/newline character.
6. None of the four strings may contain Unicode U+0000.
7. `requestedIdentifier` and `metadataIdentifier` must still be exactly equal.
8. `containerUUID` must parse as `NSUUID`, contain no `/`, and not equal `.` or `..`.
9. The candidate path must remain lexically valid under the TASK-1.1 invariants.

Do not trim, lowercase, standardize or rewrite any input before validation.

Invalid input returns:

```text
PXDestructivePathValidatorErrorInvalidInput
```

## Exact raw candidate-path requirement

Construct the expected raw path only as:

```objc
NSString *expectedCandidatePath =
    [allowedBasePath stringByAppendingPathComponent:container.containerUUID];
```

Require:

```objc
[container.containerPath isEqualToString:expectedCandidatePath]
```

Any alias, alternate prefix, extra component or path spelling difference returns:

```text
PXDestructivePathValidatorErrorCandidatePathMismatch
```

Examples that must fail even if they reach the same filesystem object:

- rootful `/var/mobile/Containers/...` instead of `/private/var/mobile/Containers/...`;
- a path under a different kind base;
- an extra nested directory;
- a sibling UUID;
- a path reconstructed from metadata rather than the fixed allow-list;
- a raw path containing an alternate symlink alias.

This lexical check occurs before canonicalization.

## POSIX inspection requirements

Use POSIX filesystem inspection in the validator implementation.

Expected headers may include:

```c
#include <errno.h>
#include <limits.h>
#include <pwd.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
```

Do not use shell commands, `find`, `CommandRunner`, `NSTask`, `posix_spawn`, `system` or `popen`.

### Path conversion

For each path passed to POSIX APIs:

- use `fileSystemRepresentation`;
- reject a NULL representation as `FilesystemInspectionFailed`;
- capture `errno` immediately after a failing POSIX call;
- do not retain borrowed C pointers beyond the owning NSString lifetime.

### Raw candidate `lstat`

Call `lstat` on the exact raw candidate path before `realpath`.

Require:

- call succeeds;
- object is a directory via `S_ISDIR`;
- object is not a symbolic link via `S_ISLNK`.

Mapping:

- failed `lstat` or non-directory: `FilesystemInspectionFailed`;
- symbolic link: `SymlinkRejected`.

Do not allow `stat` alone to hide a candidate symlink.

## Canonicalization

Canonicalize separately:

1. the fixed allowed base path;
2. the exact raw candidate path.

Use `realpath` or an equivalent POSIX canonicalization with identical semantics.

The implementation should prefer fixed stack buffers sized by `PATH_MAX` so no heap ownership is introduced. If heap-allocated `realpath` output is used, every success and early-return path must free it exactly once.

A failure to canonicalize either path returns:

```text
PXDestructivePathValidatorErrorCanonicalizationFailed
```

Convert canonical C paths back into NSString without lossy or partial conversion. Conversion failure also maps to `CanonicalizationFailed`.

## Canonical base containment

After canonicalization, require all of the following:

1. canonical base is an absolute non-root path;
2. canonical candidate is an absolute non-root path;
3. canonical candidate is not equal to canonical base;
4. canonical candidate has no trailing slash;
5. canonical candidate last component equals `containerUUID` exactly;
6. canonical candidate deleting its last path component equals canonical base exactly;
7. canonical candidate is therefore one immediate child of canonical base, not merely a string prefix descendant.

Do not use a raw `hasPrefix:` containment check such as:

```objc
[canonicalCandidate hasPrefix:canonicalBase]
```

Prefix-only checks are forbidden because `/base2` can share the `/base` prefix.

Any violation returns:

```text
PXDestructivePathValidatorErrorCanonicalBaseViolation
```

The fixed base itself may contain trusted system-level alias components. Canonicalize it and compare the candidate's canonical parent to the canonical base. Do not accept a caller-provided alternate raw base.

## Canonical stat and inode consistency

Call `stat` on the canonical base and canonical candidate.

Require:

- both calls succeed;
- both are directories;
- canonical candidate `st_dev` and `st_ino` equal the initial raw-candidate `lstat` values;
- canonical candidate and canonical base are on the same `st_dev`.

Mapping:

- failed stat/non-directory: `FilesystemInspectionFailed`;
- initial lstat identity differs from canonical stat identity: `FilesystemChanged`;
- candidate device differs from base device: `CrossDeviceBoundary`.

The same-device rule rejects a container child replaced by a separate mount point. Do not add an exception or fallback for cross-device candidates in TASK-1.3.

## Ownership and mode policy

Resolve the system `mobile` user UID through `getpwnam_r` or an equivalent deterministic libc lookup. Do not use the current process UID as a fallback. Do not silently assume root ownership is acceptable.

If the `mobile` account cannot be resolved, return:

```text
PXDestructivePathValidatorErrorFilesystemInspectionFailed
```

Require:

- canonical candidate owner UID equals the resolved `mobile` UID;
- canonical candidate is not world-writable (`S_IWOTH` must be clear);
- canonical base is not world-writable.

Failure returns:

```text
PXDestructivePathValidatorErrorOwnershipOrModeViolation
```

Do not change ownership or mode. Do not call `chmod`, `chown`, `fchmod`, `fchown` or shell equivalents.

Group ID is recorded in the report/audit but is not an authorization criterion in TASK-1.3 because existing rootful/rootless layouts may differ in group assignment. Do not add a caller override.

## Metadata-file safety

Construct the metadata path only under the canonical candidate:

```text
<canonical candidate>/.com.apple.mobile_container_manager.metadata.plist
```

Do not use `.com.apple.containermanagerd.metadata.plist` as fallback.

Before reading metadata, call `lstat` on the exact metadata path.

Require:

- `lstat` succeeds;
- metadata object is a regular file via `S_ISREG`;
- metadata object is not a symlink;
- metadata `st_dev` equals candidate `st_dev`;
- metadata owner UID equals the resolved `mobile` UID;
- metadata file is not world-writable.

Mapping:

- missing/non-regular metadata: `MetadataInvalid`;
- metadata symlink: `SymlinkRejected`;
- metadata cross-device: `CrossDeviceBoundary`;
- metadata owner/mode failure: `OwnershipOrModeViolation`.

Canonicalize the metadata path and require:

- canonical metadata filename is exactly `.com.apple.mobile_container_manager.metadata.plist`;
- canonical metadata parent equals canonical candidate exactly.

Violation returns `CanonicalBaseViolation` or `CanonicalizationFailed`, as appropriate.

## Metadata identity revalidation

Read the metadata dictionary only after metadata-path safety checks.

Read only:

```text
MCMMetadataIdentifier
```

Do not inspect filenames, container contents, app short names or company names.

### ApplicationData, ExtensionData and PluginKitData

For these kinds, `MCMMetadataIdentifier` must be a valid runtime `NSString` and must equal both:

```objc
container.requestedIdentifier
container.metadataIdentifier
```

using exact case-sensitive `isEqualToString:`.

### AppGroup

For `PXResolvedContainerKindAppGroup`, `MCMMetadataIdentifier` may be:

- one valid `NSString` equal to the requested identifier; or
- an `NSArray` containing the exact requested identifier exactly once as a valid NSString element.

Rules for an array:

- no fuzzy matching;
- non-string entries do not satisfy identity;
- zero exact occurrences is mismatch;
- more than one exact occurrence is invalid metadata;
- the exact matched value must equal both model identifiers.

Do not use `containsString:`, prefix/suffix tests, case folding or normalized comparisons.

Mapping:

- malformed plist, missing key, invalid type/content or duplicate exact AppGroup entry: `MetadataInvalid`;
- valid metadata whose identifier does not exactly match the model: `IdentityMismatch`.

The validator must not trust only the identifiers stored in `PXResolvedContainer`; it must re-read live metadata.

## Final TOCTOU recheck

After metadata has been read and identity accepted, perform final `lstat` calls on:

1. the exact raw candidate path;
2. the exact canonical metadata path.

Require:

- candidate still exists, is a non-symlink directory, and has the same `st_dev` and `st_ino` as the initial candidate snapshot;
- metadata still exists, is a non-symlink regular file, and has the same `st_dev` and `st_ino` as the initial metadata snapshot.

Any difference returns:

```text
PXDestructivePathValidatorErrorFilesystemChanged
```

Do not return the canonical path before this final recheck.

This reduces, but does not eliminate, TOCTOU after the validator returns. The report must state that future destructive callers must validate immediately before use.

## No caller migration

No existing source may import, instantiate or invoke `PXDestructivePathValidator` in TASK-1.3.

Search existing production source excluding the two new validator files and prove:

```text
PXDestructivePathValidator references: 0
validatedCanonicalPathForContainer references: 0
```

Do not modify:

- application-data resolver callers;
- app-group resolver callers;
- extension/PluginKit cleanup;
- raw UUID/path reconstruction;
- current Clear completion behavior;
- application-bundle deletion behavior.

## Forbidden behavior

TASK-1.3 must not introduce:

- `removeItemAtPath:`;
- `unlink`, `rmdir`, `remove`;
- `rm`, `find -delete` or shell deletion;
- `chmod`, `chown`, `fchmod`, `fchown`;
- `CommandRunner`;
- `NSTask`;
- `posix_spawn`;
- `system`;
- `popen`;
- a command string;
- background queues or `dispatch_apply`;
- caches or singletons;
- custom base-path injection;
- path-prefix-only authorization;
- application-bundle allow-list entries;
- caller integration;
- TASK-1.4 work.

## Baseline and protected-file verification

Before creating the validator files, record:

```text
git status --short
```

Record SHA-256 for:

- `PXResolvedContainer.h`;
- `PXResolvedContainer.m`;
- `PXDataContainerResolver.h`;
- `PXDataContainerResolver.m`;
- `Makefile`;
- `AppDataCleaner.h`;
- `AppDataCleaner.m`;
- `AppGroupContainerResolver.h`;
- `AppGroupContainerResolver.m`;
- `AppDataBackupManager.h`;
- `AppDataBackupManager.m`;
- `CommandRunner.h`;
- `CommandRunner.m`.

At task end:

- hashes must match;
- `git diff --exit-code` over these protected files must succeed;
- do not stage, revert or format coordinator-owned baseline files;
- if TASK-1.1/TASK-1.2 files remain untracked, explicitly record them as baseline and prove they were unchanged.

## Resource ownership audit

The report must document ownership/lifetime for:

- optional `NSError` output;
- borrowed NSString filesystem representations;
- `struct stat` snapshots;
- `passwd` lookup buffer/state;
- canonical path buffers;
- canonical NSString objects;
- metadata dictionary;
- metadata identifier or AppGroup array;
- final returned canonical string.

For every raw buffer or heap allocation, report:

- acquisition;
- owner;
- cleanup on every early return;
- cleanup on success;
- proof of no double free/use-after-free.

Prefer stack canonical buffers to avoid heap ownership.

## Required static scenario matrix

The report must classify each scenario as `STATIC REVIEW` unless actually run on a compiled target:

| # | Scenario | Required outcome |
|---:|---|---|
| 1 | valid rootful ApplicationData | canonical path |
| 2 | valid rootless ApplicationData | canonical path |
| 3 | valid rootful ExtensionData | canonical path |
| 4 | valid rootless ExtensionData | canonical path |
| 5 | valid rootful AppGroup with string metadata | canonical path |
| 6 | valid AppGroup with array metadata and one exact occurrence | canonical path |
| 7 | valid rootful PluginKitData | canonical path |
| 8 | nil/non-model input | InvalidInput |
| 9 | invalid kind/root cast | InvalidInput |
| 10 | model identifiers no longer equal | InvalidInput |
| 11 | raw candidate uses `/var/mobile` alias | CandidatePathMismatch |
| 12 | raw candidate belongs to wrong kind base | CandidatePathMismatch |
| 13 | raw candidate has extra nested component | CandidatePathMismatch |
| 14 | candidate missing | FilesystemInspectionFailed |
| 15 | candidate is regular file | FilesystemInspectionFailed |
| 16 | candidate is symlink to directory | SymlinkRejected |
| 17 | base realpath fails | CanonicalizationFailed |
| 18 | candidate realpath fails | CanonicalizationFailed |
| 19 | canonical candidate parent differs from canonical base | CanonicalBaseViolation |
| 20 | prefix collision such as `/base2` | CanonicalBaseViolation |
| 21 | canonical last component differs from UUID | CanonicalBaseViolation |
| 22 | raw lstat and canonical stat inode differ | FilesystemChanged |
| 23 | candidate is separate mount/device | CrossDeviceBoundary |
| 24 | mobile account lookup fails | FilesystemInspectionFailed |
| 25 | candidate owner is not mobile | OwnershipOrModeViolation |
| 26 | candidate is world-writable | OwnershipOrModeViolation |
| 27 | canonical base is world-writable | OwnershipOrModeViolation |
| 28 | metadata missing | MetadataInvalid |
| 29 | metadata is directory/non-regular | MetadataInvalid |
| 30 | metadata is symlink | SymlinkRejected |
| 31 | metadata is separate device | CrossDeviceBoundary |
| 32 | metadata owner/mode invalid | OwnershipOrModeViolation |
| 33 | metadata canonical parent escapes candidate | CanonicalBaseViolation |
| 34 | malformed plist | MetadataInvalid |
| 35 | identifier missing or non-string for ApplicationData | MetadataInvalid |
| 36 | metadata differs only by case | IdentityMismatch |
| 37 | metadata prefix-only match | IdentityMismatch |
| 38 | AppGroup array has zero exact occurrence | IdentityMismatch |
| 39 | AppGroup array has two exact occurrences | MetadataInvalid |
| 40 | candidate replaced during metadata read | FilesystemChanged |
| 41 | metadata replaced during read | FilesystemChanged |
| 42 | successful result | returned string is canonical candidate, not raw alias |
| 43 | validator result used for deletion | impossible in TASK-1.3; no caller migration |
| 44 | application bundle candidate | impossible; no kind/base mapping |

## Required source gates

The report must provide exact or explained counts for the two new validator files, including:

```text
PXDestructivePathValidator interface: 1
PXDestructivePathValidator implementation: 1
validatedCanonicalPathForContainer declaration: 1
validatedCanonicalPathForContainer implementation: 1
error-domain declaration: 1
error-domain definition: 1
fixed allowed-base literals: expected mapping only
application-bundle base literals: 0
lstat calls: candidate + metadata + final rechecks
realpath calls: base + candidate + metadata
stat calls: canonical base + canonical candidate
MCMMetadataIdentifier literal: 1
mobile-container-manager metadata filename: 1
containermanagerd fallback filename: 0
exact identity comparisons: present
identifier containsString/prefix/suffix/case-fold matching: 0
raw hasPrefix containment authorization: 0
remove/chmod/chown/process APIs: 0
existing production references: 0
```

A `hasPrefix:` call may not be used to authorize canonical containment. Literal prefix checks unrelated to containment must be explained individually.

## Verification

Required final verification:

1. `git status --short`;
2. protected-file checksum comparison;
3. protected-file `git diff --exit-code`;
4. full review of `PXDestructivePathValidator.h/.m`;
5. source-token gate audit;
6. existing-production reference search;
7. `git diff --check` for tracked files;
8. trailing-whitespace checks for untracked validator/report files;
9. no-index diff review of each new source file when untracked;
10. diff-stat review;
11. generated/binary/NUL-byte audit;
12. no local build claim when Apple toolchain is unavailable.

## Required report content

Create:

```text
docs/backup-restore-hardening/reports/TASK-1.3-REPORT.md
```

The report must include:

1. metadata and scope;
2. initial working-tree baseline;
3. files created;
4. public API and error enum;
5. success/failure contract;
6. fixed kind/root base mapping;
7. input validation;
8. exact raw-path equality;
9. POSIX path conversion;
10. initial lstat policy;
11. canonicalization policy;
12. canonical immediate-child containment proof;
13. inode/device consistency;
14. mount boundary policy;
15. mobile ownership and mode policy;
16. metadata-file lstat/canonical policy;
17. metadata identity policy by kind;
18. AppGroup string/array handling;
19. final TOCTOU recheck;
20. why returned canonical path must be used;
21. proof no caller migration;
22. proof no deletion/permission/process API;
23. protected checksums;
24. resource ownership table;
25. source-token gates;
26. scenario matrix;
27. verification results;
28. full diff/stat review;
29. generated/binary audit;
30. remaining risks.

End with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Acceptance checklist

- [ ] Only `PXDestructivePathValidator.h/.m` are created as production changes.
- [ ] Public API and exact error enum match the specification.
- [ ] Validator returns canonical NSString path, not BOOL or raw candidate.
- [ ] All four data-container kinds and both roots map to fixed bases.
- [ ] Application bundle has no mapping.
- [ ] Raw candidate path must exactly equal fixed base + UUID.
- [ ] Candidate lstat rejects symlink and non-directory.
- [ ] Base/candidate/metadata are canonicalized with POSIX semantics.
- [ ] Canonical candidate parent equals canonical base exactly.
- [ ] Prefix-only containment is not used.
- [ ] Candidate stays on the canonical base device.
- [ ] Initial and canonical candidate inode/device identities agree.
- [ ] Mobile UID ownership policy is enforced.
- [ ] Base/candidate/metadata world-writable modes are rejected as specified.
- [ ] Metadata is a non-symlink regular file on the candidate device.
- [ ] Only mobile-container-manager metadata filename is accepted.
- [ ] Live metadata exact identity is revalidated.
- [ ] AppGroup string/array exact policy is implemented.
- [ ] Final candidate and metadata inode/device rechecks occur before return.
- [ ] No partial or raw path is returned on failure.
- [ ] No existing caller references the validator.
- [ ] No deletion, permission change, shell or process API is added.
- [ ] Protected files remain unchanged.
- [ ] `git diff --check` and new-file whitespace checks pass.
- [ ] Report and audits are complete.
- [ ] GitHub Actions remains PENDING in the agent report.
- [ ] Agent stops after TASK-1.3.

## Forbidden next work

After completing TASK-1.3:

- do not implement TASK-1.4;
- do not edit `AppDataCleaner`;
- do not remove application-bundle writes;
- do not add `PXClearRequest` or `PXClearResult`;
- do not migrate application-data, extension, app-group or PluginKit clear paths;
- do not execute deletion based on validator output.

## Gate after TASK-1.3

TASK-1.4 may be specified only after:

1. TASK-1.3 report is complete;
2. source review accepts canonical, symlink, device, ownership/mode and metadata checks;
3. GitHub Actions succeeds;
4. no existing caller integration occurred;
5. coordinator creates an accepted TASK-1.3 review.
