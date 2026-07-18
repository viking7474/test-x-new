# TASK-3.10 - Harden Backup Discovery and Stale Partial Cleanup

- Status: READY
- Phase: 3 - Atomic Backup Publication
- Baseline: `aa01f73b761682f3142c10b03ad5ff792331e68e`
- Depends on: accepted TASK-3.1 through TASK-3.9A
- Next phase: Phase 4 remains locked until TASK-3.10 review and build confirmation

## Objective

Close Phase 3 by adding two independent authorities:

1. descriptor-relative, manifest-validated discovery of published Backup directories across the current profile root and the legacy global root;
2. bounded, race-safe cleanup of stale reserved partial/quarantine workspaces under the exact current per-bundle lock before a new Backup operation begins.

A published Backup directory must never become a stale-cleanup target. Discovery must never expose a partial, quarantine, symlinked, malformed, unsupported or bundle-mismatched Backup merely because a file named `manifest.plist` exists.

TASK-3.10 does not change Restore behavior, UI presentation, Keychain behavior or public manager signatures.

## Authorized production scope

Create:

```text
PXBackupDirectoryDiscovery.h
PXBackupDirectoryDiscovery.m
PXBackupStaleWorkspaceCleanup.h
PXBackupStaleWorkspaceCleanup.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.10-REPORT.md
```

The implementation commit must contain exactly these six files.

## Protected files

Do not modify:

```text
AppDataBackupManager.h
PXBackupFailureCleanup.h
PXBackupFailureCleanup.m
PXBackupPublicationWorkspace.h
PXBackupPublicationWorkspace.m
PXBackupBundleLock.h
PXBackupBundleLock.m
PXBackupArtifactPolicy.h
PXBackupArtifactPolicy.m
PXBackupArtifactWriter.h
PXBackupArtifactWriter.m
PXBackupManifestV4.h
PXBackupManifestV4.m
PXBackupManifestValidator.h
PXBackupManifestValidator.m
PXBackupManifestWriter.h
PXBackupManifestWriter.m
PXBackupDirectoryPublisher.h
PXBackupDirectoryPublisher.m
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
PXBackupArchiveValidator.h
PXBackupArchiveValidator.m
PXRestorePlan.h
PXRestorePlan.m
all Restore transaction/staging/resolver source
CommandRunner.h
CommandRunner.m
Makefile
UI/controller source
Keychain helper/bridge/script source
coordinator task/review/status/roadmap/decision/README files
```

The accepted TASK-3.9A live-operation cleanup implementation must remain byte-identical. TASK-3.10 owns recovery of prior-process reserved entries through a separate class.

## Baseline evidence

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file.

# Part A - Published Backup discovery

## Public discovery API

Create exact exports:

```objc
FOUNDATION_EXPORT NSErrorDomain const PXBackupDirectoryDiscoveryErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupDirectoryDiscoveryErrorFieldPathKey;
```

Create exactly 16 error codes without gaps:

```text
PXBackupDirectoryDiscoveryErrorInvalidInput = 1
PXBackupDirectoryDiscoveryErrorLimitExceeded = 2
PXBackupDirectoryDiscoveryErrorRootInspectionFailed = 3
PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid = 4
PXBackupDirectoryDiscoveryErrorTraversalFailed = 5
PXBackupDirectoryDiscoveryErrorEntryChanged = 6
PXBackupDirectoryDiscoveryErrorFilesystemChanged = 7
PXBackupDirectoryDiscoveryErrorManifestOpenFailed = 8
PXBackupDirectoryDiscoveryErrorManifestReadFailed = 9
PXBackupDirectoryDiscoveryErrorManifestParseFailed = 10
PXBackupDirectoryDiscoveryErrorManifestInvalid = 11
PXBackupDirectoryDiscoveryErrorUnsupportedManifestVersion = 12
PXBackupDirectoryDiscoveryErrorBundleIdentifierMismatch = 13
PXBackupDirectoryDiscoveryErrorPublishedNameMismatch = 14
PXBackupDirectoryDiscoveryErrorDuplicateBackup = 15
PXBackupDirectoryDiscoveryErrorInternalInvariantFailed = 16
```

Create one subclassing-restricted utility class:

```objc
PXBackupDirectoryDiscovery
```

Exact class method:

```objc
+ (nullable NSArray<NSString *> *)discoverBackupDirectoriesAtBackupRoots:
    (NSArray<NSString *> *)backupRoots
    bundleIdentifier:(NSString *)bundleIdentifier
    error:(NSError * _Nullable * _Nullable)error;
```

`init` and `new` are unavailable.

No instance properties, mutation API, cleanup API, descriptor API, marker API or Restore API.

## Pure discovery boundary

`PXBackupDirectoryDiscovery.m` may import only:

```objc
#import "PXBackupDirectoryDiscovery.h"
#import "PXBackupManifestValidator.h"
```

and Foundation/POSIX/C headers needed for bounded read-only traversal.

It must not import or call:

```text
AppDataBackupManager
PXBackupBundleLock
PXBackupFailureCleanup
PXBackupStaleWorkspaceCleanup
CommandRunner
UIKit
Security/Keychain
NSUserDefaults
shell/process APIs
dispatch
filesystem mutation APIs
```

Forbidden mutation calls include:

```text
mkdir/mkdirat
unlink/unlinkat
rename/renameat/renameatx_np
removeItemAtPath/removeItemAtURL
write/pwrite
chmod/fchmod
chown/fchown
```

Discovery is read-only.

## Discovery fixed limits

```text
maximum backup roots:                 8
maximum root path UTF-8 bytes:     4096
maximum bundle/component bytes:     255
maximum entries per bundle root:  16384
maximum aggregate scanned entries:32768
maximum manifest bytes:       128 MiB
manifest read buffer:            64 KiB
maximum accepted Backup records:  4096
```

All counters and arithmetic must be overflow-safe.

## Discovery input contract

Require:

- `backupRoots` is an array with 1 through 8 entries;
- every entry is a runtime `NSString`;
- every root is an absolute, nonempty, lossless UTF-8 path no longer than 4096 bytes;
- no root contains embedded NUL;
- `bundleIdentifier` is a safe exact single component no longer than 255 UTF-8 bytes;
- no slash, backslash, NUL or control character;
- not `.` or `..`;
- exact UTF-8 round trip;
- no trimming, normalization, lowercasing, percent decoding or tilde expansion.

Clear `*error` at method entry.

## Root and bundle traversal

For each root in caller order:

1. If the root does not exist, continue without error.
2. `lstat` the final root component.
3. Reject an existing symlink, non-directory or setid root as a systemic discovery error.
4. Open root with `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`.
5. Prove path/descriptor device-inode-type equality and `FD_CLOEXEC`.
6. Inspect the bundle component with `fstatat(..., AT_SYMLINK_NOFOLLOW)`.
7. If the bundle directory is absent, continue.
8. Reject symlink, wrong type, setid or cross-filesystem bundle directory.
9. Open with `openat(..., O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)`.
10. Prove namespace/descriptor equality and `FD_CLOEXEC`.

Do not create a missing root or bundle directory.

If two lexical roots resolve to the same physical root/bundle directory, scan that physical bundle directory only once. Preserve first-root precedence.

## Descriptor-relative enumeration

Use exactly one reusable enumeration implementation based on:

```text
F_DUPFD_CLOEXEC
fdopendir
readdir
```

Require exact `readdir` errno handling.

For every direct child:

- validate safe raw component bytes;
- enforce scan limits before storing the name;
- sort candidate raw names deterministically before inspection;
- use only `fstatat/openat` relative to retained descriptors.

Do not use:

```text
NSFileManager contentsOfDirectoryAtPath
fileExistsAtPath
absolute child traversal
realpath child traversal
string-based recursive enumeration
```

## Reserved and hidden namespace exclusion

Never return or inspect as a published candidate:

```text
.weaponx-backup.lock
any name beginning .weaponx-backup-partial-
any name beginning .weaponx-cleanup-quarantine-
any other dot-prefixed name
```

This exclusion applies to both exact and malformed reserved names and to both current and legacy roots.

A reserved entry is not a discovery error. Discovery simply does not expose it.

## Published candidate directory proof

A non-hidden candidate is considered only when it is:

- an exact safe single component;
- a no-follow directory;
- not setuid/setgid;
- on the same filesystem as its bundle directory;
- opened `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`;
- exact namespace/descriptor device-inode-type match;
- stable through manifest inspection;
- `FD_CLOEXEC` protected.

A file, symlink, special object or changed candidate is skipped, not returned.

## Manifest proof

Open exact child:

```text
manifest.plist
```

through the retained candidate descriptor with:

```text
O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
```

Require:

- regular file;
- `st_nlink == 1`;
- no setuid/setgid;
- same filesystem as candidate and bundle directory;
- namespace/descriptor identity equality;
- `FD_CLOEXEC`;
- size from 1 byte through 128 MiB;
- stable device/inode/type/mode/link-count/size/mtime/ctime before and after read.

Read with a 64-KiB buffer:

- retry only `EINTR`;
- reject early EOF;
- reject extra bytes;
- never use unbounded `dictionaryWithContentsOfFile:` or whole-path reads.

Parse as a property list and require a dictionary root.

Call `PXBackupManifestValidator` exactly once per parsed candidate manifest.

Require exact supported version:

```text
2
3
4
```

Unknown positive versions are skipped even though the generic validator may accept their graph.

Require manifest `bundleID` to equal the requested bundle identifier exactly.

## V4 published-name binding

For a v4 manifest, additionally require:

```text
candidate directory mode: 0700
manifest file mode:        0600
publication.protocol:      atomic-directory-v1
publication.contentState:  complete
```

Require runtime strings:

```text
timestamp
backupID
```

The final directory name must equal exactly:

```text
<timestamp>-<backupID>
```

Timestamp must satisfy exact TASK-3.8 format:

```text
yyyyMMdd-HHmmss
15 ASCII bytes
UTC strict formatter round trip
```

Backup ID must be the canonical lowercase UUID already required by v4.

No trimming, case repair or alternate name is permitted.

A valid v4 manifest under a mismatching final name is skipped.

## Legacy v2/v3 compatibility

For manifest versions 2 and 3:

- retain existing validated component shapes;
- require exact bundle identifier;
- require a safe non-hidden candidate directory;
- do not require a v4 UUID suffix;
- do not require v4 directory/file modes;
- do not mutate or rewrite the manifest;
- do not require publication metadata that v2/v3 do not contain.

The directory name does not become legacy manifest authority. A validated v2/v3 Backup may retain its historical safe directory name.

## Candidate acceptance and deduplication

Before accepting a path:

1. revalidate candidate namespace/descriptor identity;
2. revalidate manifest namespace/descriptor identity and stable metadata;
3. require the candidate path string equals `root/bundleIdentifier/candidateName` exactly;
4. ensure no previously accepted record has the same candidate device/inode.

Physical aliases are returned once using first-root precedence.

Two physically distinct directories with the same final component may both be returned.

Do not expose manifest dictionaries or descriptors through the public API.

## Discovery sorting

Return paths sorted newest-first by `lastPathComponent` using exact binary/string comparison compatible with the existing manager behavior.

For equal final components, use the complete path as a deterministic secondary key.

# Part B - Stale reserved workspace cleanup

## Public stale-cleanup API

Create exact exports:

```objc
FOUNDATION_EXPORT NSErrorDomain const PXBackupStaleWorkspaceCleanupErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupStaleWorkspaceCleanupErrorFieldPathKey;
```

Create exactly 18 error codes:

```text
PXBackupStaleWorkspaceCleanupErrorInvalidInput = 1
PXBackupStaleWorkspaceCleanupErrorLockValidationFailed = 2
PXBackupStaleWorkspaceCleanupErrorParentInspectionFailed = 3
PXBackupStaleWorkspaceCleanupErrorTraversalFailed = 4
PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid = 5
PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry = 6
PXBackupStaleWorkspaceCleanupErrorEntryChanged = 7
PXBackupStaleWorkspaceCleanupErrorLimitExceeded = 8
PXBackupStaleWorkspaceCleanupErrorQuarantineFailed = 9
PXBackupStaleWorkspaceCleanupErrorRollbackFailed = 10
PXBackupStaleWorkspaceCleanupErrorRemovalFailed = 11
PXBackupStaleWorkspaceCleanupErrorDurabilityFailed = 12
PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete = 13
PXBackupStaleWorkspaceCleanupErrorFilesystemChanged = 14
PXBackupStaleWorkspaceCleanupErrorAlreadyPerformed = 15
PXBackupStaleWorkspaceCleanupErrorPublishedEntryDetected = 16
PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed = 17
PXBackupStaleWorkspaceCleanupErrorMissingError = 18
```

Create one subclassing-restricted class:

```objc
PXBackupStaleWorkspaceCleanup
```

Readonly properties:

```text
canonicalBundleDirectoryPath
cleanupAttempted
cleanedWorkspaceCount
removedEntryCount
```

Exact factory:

```objc
+ (nullable instancetype)cleanupForBundleLock:(PXBackupBundleLock *)bundleLock
                                        error:(NSError * _Nullable * _Nullable)error;
```

Exact methods:

```objc
- (BOOL)removeStaleWorkspacesWithError:(NSError * _Nullable * _Nullable)error;
- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;
```

`init/new` unavailable.

No arbitrary path, age threshold, published-directory deletion, legacy-root cleanup, marker, recovery index or public descriptor API.

## Pure stale-cleaner boundary

`PXBackupStaleWorkspaceCleanup.m` may import only:

```objc
#import "PXBackupStaleWorkspaceCleanup.h"
#import "PXBackupBundleLock.h"
```

and Foundation/POSIX/C/Darwin SDK headers needed for bounded cleanup.

It must not import or call:

```text
AppDataBackupManager
PXBackupFailureCleanup
PXBackupPublicationWorkspace
PXBackupDirectoryPublisher
PXBackupDirectoryDiscovery
CommandRunner
UIKit
Security/Keychain
NSUserDefaults
shell/process APIs
dispatch
NSFileManager deletion
```

The implementation must contain its own audited prior-process cleanup authority and must not alter TASK-3.9A source.

## Why an entry is stale

TASK-3.10 must not use wall-clock age, mtime, ctime, boot time or process IDs as stale authority.

A direct child is stale only when all are true:

1. the cleaner holds the exact validated per-bundle `PXBackupBundleLock`;
2. the cleaner is bound to the lock's canonical bundle-directory descriptor;
3. manager invokes cleanup before creating the current operation's workspace;
4. the direct-child name is an exact reserved partial or cleanup-quarantine name;
5. the entry satisfies exact no-follow directory safety proof.

The exclusive per-bundle lock, not elapsed time, proves no compliant current Backup operation owns a reserved workspace in that canonical bundle directory.

## Exact stale top-level names

Recognize only:

```text
.weaponx-backup-partial-<6 ASCII alphanumeric characters>
.weaponx-cleanup-quarantine-<32 lowercase hexadecimal characters>
```

The partial syntax corresponds to the accepted TASK-3.1 `mkdtemp` template.

A direct child beginning with either reserved prefix but not matching its exact syntax is malformed evidence:

- fail closed;
- preserve it;
- do not start a new Backup operation.

Never classify as stale:

```text
.weaponx-backup.lock
published timestamp/UUID directories
legacy published Backup directories
nonreserved hidden entries
nonreserved files/directories
```

## Stale-cleanup fixed limits

```text
maximum stale top-level candidates:       256
maximum traversal depth:                   64
maximum aggregate visited entries:      16384
maximum component bytes:                  255
maximum accumulated component bytes:   8 MiB
maximum quarantine collision attempts:     16
quarantine random bytes:                    16
```

All counters and additions must be overflow-safe.

## Cleaner factory authority

The factory must:

1. clear `*error`;
2. require exact `PXBackupBundleLock` runtime class;
3. validate lock ownership;
4. obtain exact canonical bundle-directory path and bundle identifier from the lock;
5. validate the path as absolute lossless UTF-8 no longer than 4096 bytes;
6. `lstat` the final bundle-directory component;
7. reject symlink, non-directory or setid directory;
8. open `O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`;
9. prove path/descriptor identity and `FD_CLOEXEC`;
10. require the directory's device agrees with the retained lock domain;
11. validate lock ownership again;
12. retain lock, descriptor, canonical path and exact identity.

Factory performs no enumeration or mutation.

## Deterministic preflight

`removeStaleWorkspacesWithError:` is one-shot.

Before the first mutation:

1. validate cleaner identity and bundle lock;
2. enumerate the retained bundle directory descriptor-relatively;
3. enforce all aggregate limits;
4. classify every direct child;
5. reject malformed reserved-prefix names;
6. inspect every exact stale candidate no-follow;
7. require every candidate is a directory, mode exactly `0700`, no setid and same filesystem;
8. open every candidate no-follow/CLOEXEC and prove namespace/descriptor identity;
9. collect exact candidate names;
10. sort candidates by raw UTF-8 bytes.

Unsafe or malformed top-level reserved evidence fails before any stale candidate is deleted.

Nonreserved entries and published directories are ignored, not deleted.

## Descriptor-relative recursive cleanup

For each exact stale candidate, use bounded post-order traversal with:

```text
F_DUPFD_CLOEXEC
fdopendir
readdir with exact errno handling
fstatat(..., AT_SYMLINK_NOFOLLOW)
openat(..., O_NOFOLLOW|O_CLOEXEC)
namespace/descriptor identity equality
same-filesystem proof
strict directory fsync
```

Inside an already-proven stale candidate, accept only:

```text
single-link regular files without setid bits
ordinary directories without setid bits
```

Reject and preserve:

```text
symlinks
FIFO/socket/device objects
cross-filesystem entries
hard-linked files
setid entries
invalid/oversized names
changed identities
```

Unlike live TASK-3.9A traversal, nested pre-existing `.weaponx-cleanup-quarantine-*` names are ordinary stale-tree entries and may be processed when their current identities are proven. This permits recovery after a process dies during an earlier cleanup.

Do not construct absolute child paths or use recursive path APIs.

## Race-safe quarantine protocol

Use exact private prefix:

```text
.weaponx-cleanup-quarantine-
```

Every destructive removal must first atomically capture the current source entry to a fresh sibling quarantine name containing 32 lowercase hex characters from exactly 16 random bytes.

Create exactly one file-local no-replace helper containing the sole stale-cleaner syscall site:

```c
renameatx_np(sourceParentDescriptor,
             sourceName,
             destinationParentDescriptor,
             destinationName,
             RENAME_EXCL)
```

Requirements:

```text
renameatx_np implementation sites: 1
RENAME_EXCL uses:                  1
plain renameat sites:              0
dlsym/private syscall sites:       0
fallback rename sites:             0
```

Retry syscall only for `EINTR`.

Retry destination-name generation only for `EEXIST` or `ENOTEMPTY`, up to 16 attempts.

## Capture mismatch rollback

After capture:

- require source name absent;
- require quarantine namespace equals retained descriptor identity and expected type/device/safety state.

If capture moved an unexpected replacement:

1. never unlink/rmdir the quarantine;
2. require original name absent;
3. move quarantine back to original using the same no-replace helper;
4. strict-sync parent;
5. prove quarantine absent and original present;
6. return `EntryChanged`.

If rollback collides or cannot be proved:

- preserve both namespaces/evidence;
- return `RollbackFailed` or `CleanupIncomplete`;
- never overwrite or delete the unproven entry.

## File and directory deletion

Regular file accepted order:

```text
observe/open/stable proof
atomic source -> quarantine capture
exact quarantine/descriptor proof
unlinkat(quarantineName, 0)
quarantine absent proof
retained descriptor nlink == 0
strict parent fsync
removedEntryCount increment
```

Directory accepted order:

```text
recursive child cleanup
empty rescan
strict child sync
stable directory proof
atomic source -> quarantine capture
exact quarantine/descriptor proof
empty rescan after capture
unlinkat(quarantineName, AT_REMOVEDIR)
quarantine absent proof
strict parent fsync
removedEntryCount increment
```

No externally observed original name may be passed to destructive unlink/rmdir.

## Top-level stale workspace deletion

A top-level partial or prior quarantine workspace is itself captured to a fresh private quarantine name before root removal.

Before root capture, require:

- lock ownership valid;
- bundle parent identity valid;
- candidate descriptor identity valid;
- exact root mode `0700`;
- same filesystem;
- recursively emptied candidate;
- empty rescan;
- strict candidate sync.

After exact capture and identity proof:

```text
unlinkat(bundleFD, quarantineName, AT_REMOVEDIR)
quarantine absent proof
original stale name absent proof
strict bundle-directory fsync
cleanedWorkspaceCount increment
removedEntryCount increment
```

A new entry appearing at the original stale name after capture is preserved and causes cleanup failure; it is not deleted.

If the process dies after top-level capture, the next TASK-3.10 run recognizes the resulting exact top-level quarantine name as stale.

## Cleanup result and validation

`removeStaleWorkspacesWithError:` succeeds only when:

- every preflighted stale candidate was completely and durably removed;
- no exact or malformed reserved partial/quarantine direct child remains;
- lock ownership remains valid;
- retained bundle-directory identity remains valid;
- all counters are consistent.

After success:

```text
cleanupAttempted == YES
cleanedWorkspaceCount == exact removed top-level candidates
removedEntryCount == exact files/directories removed, including roots
```

`validateIdentityWithError:` must support both pre-cleanup and successful post-cleanup states. It must reject a failed/partially mutated state as `CleanupIncomplete` or `AlreadyPerformed` as appropriate and must never retry cleanup implicitly.

Cleanup errors expose only generic descriptions and field paths. Do not include raw paths, names, bundle identifiers, inode/device values, counts, errno text or nested errors.

# Part C - Manager integration

## Imports

Add exactly once:

```objc
#import "PXBackupDirectoryDiscovery.h"
#import "PXBackupStaleWorkspaceCleanup.h"
```

## Create-Backup stale cleanup ordering

In `createBackupForBundleID:appName:options:completion:` retain the existing order through:

```text
background queue
active profile read
one _backupRoot read
bundle-lock factory
initial bundle-lock ownership validation
```

Immediately after the existing initial bundle-lock validation and before all of the following:

```text
tar discovery
source-container resolution
timestamp generation
backup UUID generation
workspace factory
output/debug creation
process kill
artifact producers
```

perform:

1. create `PXBackupStaleWorkspaceCleanup` exactly once from the retained bundle lock;
2. retain it with `objc_precise_lifetime` through final stale validation;
3. validate it once immediately after factory;
4. call `removeStaleWorkspacesWithError:` exactly once;
5. validate it once after successful cleanup;
6. propagate exact factory/validation/cleanup NSError on the main queue with nil result;
7. only then continue existing Backup creation.

No stale-cleanup failure creates the current partial workspace or calls TASK-3.9 live cleanup.

Do not add a warning-and-continue path.

Required manager counts:

```text
stale-cleanup factory calls:       1
stale-cleanup validations:         2
stale-cleanup execution calls:     1
```

The existing manager bundle-lock validation count must remain 4. The stale cleaner performs its own internal lock checks without adding manager-level lock-validation calls.

## Discovery integration

Replace the body of:

```objc
-listBackupDirectoriesForBundleID:
```

with one call to `PXBackupDirectoryDiscovery`.

Manager must:

1. keep the existing invalid/empty bundle-ID return `@[]`;
2. read `_backupRoot` exactly once;
3. compute the existing legacy global `Backups` root;
4. pass current root first and legacy root second only when lexically distinct;
5. call discovery exactly once;
6. return discovered paths when nonnil;
7. return `@[]` on systemic discovery failure because the public selector has no error channel.

Do not log raw paths or add UI warnings.

Remove from this method:

```text
NSFileManager defaultManager
fileExistsAtPath
contentsOfDirectoryAtPath
string-based manifest existence checks
manual sorting
manual current/legacy loops
```

Sorting and physical deduplication belong to discovery.

## Read-manifest and Restore boundary

Keep byte-identical:

```text
-readManifestAtBackupDirectory:error:
-restoreBackupAtDirectory:bundleID:appName:completion:
```

TASK-3.10 hardens what the list API exposes. Existing Restore-time manifest/artifact/archive/plan/transaction validation remains the authority when a selected path is later restored.

# Non-regression

Keep exact accepted counts and behavior for the Backup creation pipeline after stale cleanup:

```text
bundle-lock factory/manager validations:       1 / 4
workspace factory/validations:                 1 / 3
live failure-cleanup factory/validation:       retained
failure-funnel actual invocations:             33
live cleanupWithError call sites:               1
live cleanup disarm call sites:                 1
artifact-writer factory/validations:           1 / 3
manifest-writer factory/validations/writes:    1 / 3 / 1
directory-publisher factory/validations/publish:1 / 3 / 1
policy constructions:                           8
artifact writes:                                8
failure-policy calls:                           8
policy-audit calls:                             1
v4 builder calls:                               1
manager v4 validator calls:                     1
publisher renameatx_np sites:                   1
live cleanup renameatx_np sites:                1
```

Keep unchanged:

```text
public Backup/Restore/list/read-manifest selectors
UTC timestamp format
backup UUID generation
final name format
manifest v4
artifact and manifest durability
publication no-replace behavior
success result paths
warning strings and order
Preferences semantics
Keychain semantics
Restore versions 2/3/4
UI
Makefile
```

## Forbidden scope

Do not implement:

```text
publication marker or index database
age-based retention policy
automatic deletion of published Backups
retention count/size limits
legacy-root mutation
rollback-failed final-directory recovery
Restore mutation changes
UI warnings or cleanup controls
Phase 4 Keychain changes
Phase 5 or Phase 6 work
```

TASK-3.10 completes only Phase 3 discovery/stale-workspace boundaries.

# Static gates

Expected implementation diff:

```text
A PXBackupDirectoryDiscovery.h
A PXBackupDirectoryDiscovery.m
A PXBackupStaleWorkspaceCleanup.h
A PXBackupStaleWorkspaceCleanup.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.10-REPORT.md
```

All other production diff must be zero.

Discovery API:

```text
error codes:                      16
utility classes:                   1
public class methods:              1
public instance methods:           0
public properties:                 0
filesystem mutation sites:         0
NSFileManager enumeration sites:   0
```

Discovery implementation:

```text
fdopendir traversal implementation: 1
readdir implementation sites:       1
manifest validator calls:           1 per candidate path
supported versions:                 2, 3, 4
reserved prefixes excluded:         2
v4 final-name/manifest binding:      required
legacy v2/v3 compatibility:         retained
```

Stale-cleanup API:

```text
error codes:                      18
classes:                           1
readonly properties:               4
factories:                          1
cleanup methods:                    1
identity methods:                   1
public descriptor/path-delete API:  0
```

Stale implementation:

```text
partial prefix recognizers:              1
cleanup-quarantine prefix recognizers:   1
arc4random_buf sites:                    1
renameatx_np sites:                      1
RENAME_EXCL uses:                        1
plain renameat sites:                    0
original-name destructive unlink sites: 0
NSFileManager deletion sites:            0
shell/process sites:                     0
age/mtime stale decisions:               0
published-directory deletion sites:      0
```

Manager:

```text
discovery class-method calls:       1
manual discovery loops:             0
list-method NSFileManager calls:     0
stale-cleanup factory calls:         1
stale-cleanup validations:           2
stale-cleanup execution calls:       1
_backupRoot calls in create Backup:  1
manager lock validations:            4
failure-funnel invocations:         33
```

# Test matrix

At minimum cover:

## Discovery

- current root missing;
- legacy root missing;
- both roots absent;
- current and legacy lexical aliases to one physical root;
- bundle directory missing;
- root/bundle symlink or wrong type;
- readdir failure;
- entry-count boundaries;
- partial/quarantine/other hidden names skipped;
- reserved regular file/symlink skipped from discovery;
- valid v2, v3 and v4 manifests;
- unknown version skipped;
- malformed plist skipped;
- manifest symlink, special type, hard link, oversize, truncation and growth;
- validator failure;
- bundle-ID mismatch;
- v4 timestamp mismatch;
- v4 backup-ID/final-name mismatch;
- v4 directory/manifest mode mismatch;
- physically duplicate candidate through roots;
- two distinct candidates with same basename;
- newest-first deterministic sorting;
- candidate replacement during read/revalidation.

## Stale cleanup

- no stale entries;
- one/multiple exact partial directories;
- one/multiple exact top-level quarantine directories;
- mixed partial and quarantine entries;
- malformed reserved suffixes;
- reserved symlink/file/FIFO/socket/device;
- root mode mismatch;
- cross-filesystem candidate;
- nested ordinary files/directories;
- nested prior quarantine names;
- depth/entry/name-byte limits;
- hard-link/setid/special nested entries;
- source replacement before capture;
- quarantine collision attempts 0/1/15/16;
- mismatch rollback success and collision failure;
- unlink/rmdir/fsync failures;
- process-interruption model after child capture;
- process-interruption model after top-level capture;
- candidate repopulation after capture;
- published directory remains untouched;
- lock loss before/during/final validation;
- partial successful cleanup followed by unsafe evidence;
- exact counters and one-shot behavior.

## Manager

- stale cleanup precedes tar/source/timestamp/workspace/kill;
- stale failure returns exact error on main queue;
- stale success with zero candidates preserves normal Backup;
- discovery current-only, legacy-only and combined roots;
- public list error fallback returns empty array;
- Restore/readManifest body hashes unchanged;
- TASK-3.1 through TASK-3.9A protected hashes unchanged.

# Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.10-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 table;
3. old path-based discovery inventory;
4. discovery API and 16-code enum;
5. root/bundle descriptor authority;
6. reserved/hidden exclusion;
7. bounded manifest read and stability proof;
8. validator and exact supported-version proof;
9. v4 final-name binding;
10. legacy v2/v3 compatibility;
11. physical deduplication and sorting;
12. stale-cleanup API and 18-code enum;
13. lock-not-age stale authority;
14. exact reserved-name grammar;
15. deterministic preflight;
16. bounded recursive traversal;
17. nested prior-quarantine recovery;
18. one no-replace helper and random-name proof;
19. capture mismatch rollback;
20. file/directory/root removal proof;
21. unsafe evidence preservation;
22. no published/legacy-root deletion;
23. manager create ordering;
24. manager list integration;
25. exact lock/funnel/writer/publisher counts;
26. Restore/readManifest byte identity;
27. Phase-3 non-regression;
28. full authorized diff;
29. static gate table;
30. at least 260 explicit scenario rows;
31. whitespace/CRLF/NUL audit;
32. build status and remaining device risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

Run and record:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff aa01f73b761682f3142c10b03ad5ff792331e68e..HEAD --check
git diff --name-status aa01f73b761682f3142c10b03ad5ff792331e68e..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase3(task-3.10): harden backup discovery and stale cleanup
```

Stop after TASK-3.10. Do not implement Phase 4 or any later task.
