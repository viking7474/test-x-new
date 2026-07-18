# TASK-2.6 — Add Archive-Entry Safety Validator

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `2a00a93e2127872845cc4e673c8929236d098c13`
- Previous task: TASK-2.5 source review ACCEPTED
- Next task: TASK-2.7 remains LOCKED

## Objective

Add one common, streaming, in-process validator for every `tar.gz` artifact that Restore will extract.

TASK-2.5 proves that an artifact file is the exact regular file declared by the manifest. TASK-2.6 must prove that the compressed archive member stream is safe before any external `tar` executable is selected or any extraction begins.

The validator must reject:

- absolute member paths;
- `.` or `..` traversal components after the allowed archive-root marker;
- invalid UTF-8 and control-character paths;
- duplicate normalized member paths;
- file-versus-directory topology conflicts;
- symbolic links;
- hard links;
- devices, FIFOs, sockets, sparse/unknown member types;
- malformed tar headers or checksums;
- malformed PAX/GNU metadata;
- unsupported compression or concatenated/trailing gzip data;
- member-count, path-length, metadata-size and expansion-limit abuse;
- compressed-file identity/content changes while validation is running.

The validator must not extract files, create staging directories, invoke `tar -t`, invoke a helper process, or alter transactional behavior.

## Production scope

Create:

```text
PXBackupArchiveValidator.h
PXBackupArchiveValidator.m
```

Modify:

```text
AppDataBackupManager.m
Makefile
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-2.6-REPORT.md
```

Suggested commit subject:

```text
phase2(task-2.6): add archive entry safety validator
```

Implementation commit may contain only:

```text
PXBackupArchiveValidator.h
PXBackupArchiveValidator.m
AppDataBackupManager.m
Makefile
docs/backup-restore-hardening/reports/TASK-2.6-REPORT.md
```

## Protected production files

Do not modify:

```text
AppDataBackupManager.h
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
PXBackupManifestValidator.h
PXBackupManifestValidator.m
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
AppDataCleaner.h
AppDataCleaner.m
AppEntitlementsReader.h
AppEntitlementsReader.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
PXClearRequest.h
PXClearRequest.m
PXClearResult.h
PXClearResult.m
CommandRunner.h
CommandRunner.m
AppDataBackupRestoreViewController.m
ProfileManagerViewController.m
ProjectXViewController.m
KeychainGroupsViewController.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper/backup_helper.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
```

Do not edit task specifications, reviews, `STATUS.md`, `ROADMAP.md`, `DECISIONS.md` or `README.md`.

## Baseline evidence

Before modifying source, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Record SHA-256 before/after for every protected production file.

# Part 1 — Exact public API

Create `PXBackupArchiveValidator.h` with this exact public surface:

```objc
#import <Foundation/Foundation.h>

@class PXVerifiedBackupArtifactSet;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const
    PXBackupArchiveValidatorErrorDomain;

FOUNDATION_EXPORT NSString * const
    PXBackupArchiveValidatorErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXBackupArchiveValidatorErrorCode) {
    PXBackupArchiveValidatorErrorInvalidInput = 1,
    PXBackupArchiveValidatorErrorMissingArchive = 2,
    PXBackupArchiveValidatorErrorOpenFailed = 3,
    PXBackupArchiveValidatorErrorReadFailed = 4,
    PXBackupArchiveValidatorErrorUnsupportedCompression = 5,
    PXBackupArchiveValidatorErrorTruncatedArchive = 6,
    PXBackupArchiveValidatorErrorInvalidHeader = 7,
    PXBackupArchiveValidatorErrorUnsafeEntryPath = 8,
    PXBackupArchiveValidatorErrorDuplicateEntry = 9,
    PXBackupArchiveValidatorErrorUnsupportedEntryType = 10,
    PXBackupArchiveValidatorErrorInvalidExtendedHeader = 11,
    PXBackupArchiveValidatorErrorLimitExceeded = 12,
    PXBackupArchiveValidatorErrorSizeMismatch = 13,
    PXBackupArchiveValidatorErrorDigestMismatch = 14,
    PXBackupArchiveValidatorErrorFilesystemChanged = 15,
    PXBackupArchiveValidatorErrorInconsistentManifest = 16,
};

__attribute__((objc_subclassing_restricted))
@interface PXValidatedBackupArchiveSet : NSObject <NSCopying>

@property (nonatomic, copy, readonly)
    NSArray<NSString *> *archiveNames;

@property (nonatomic, copy, readonly)
    NSDictionary<NSString *, NSNumber *> *memberCountsByArchiveName;

@property (nonatomic, copy, readonly)
    NSDictionary<NSString *, NSNumber *> *regularFileBytesByArchiveName;

- (BOOL)containsArchiveName:(NSString *)archiveName;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXBackupArchiveValidator : NSObject

+ (nullable PXValidatedBackupArchiveSet *)validatedArchivesForManifest:(NSDictionary *)manifest
                                                       backupDirectory:(NSString *)backupDirectory
                                                     verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
                                                                 error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```

Do not add:

- an extraction method;
- an external tar-path argument;
- a warning-only mode;
- a bypass flag;
- an arbitrary archive-path API;
- a mutable result;
- a public limit configuration object;
- a Restore-plan type.

# Part 2 — Immutable result

`PXValidatedBackupArchiveSet` must:

- copy all initializer input;
- expose archive names sorted with exact `compare:` ordering;
- expose immutable name-to-count maps;
- return `NO` for nil, non-string, empty or unknown lookup values;
- return `self` from `copyWithZone:`;
- contain no file descriptor, callback, mutable collection, archive member name, lazy parser or cache.

Count values must use nonnegative `NSNumber` values created from overflow-checked unsigned counts.

# Part 3 — Error contract

Clear `*error` at public entry.

Success:

```text
result != nil
error == nil
```

Failure:

```text
result == nil
error domain == PXBackupArchiveValidatorErrorDomain
error code == one of the exact 16 public codes
```

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupArchiveValidatorErrorFieldPathKey
```

Stable field paths include:

```text
$
$.data.archive
$.artifacts[2].name
$.artifacts[2].members[17]
$.artifacts[2].members[17].path
$.artifacts[2].members[17].type
```

Do not expose in an error or log:

- archive name value;
- archive absolute path;
- backup directory;
- member path or link target;
- expected or actual size;
- expected or actual digest;
- UID/GID/mode;
- PAX value;
- zlib message;
- errno text;
- raw tar header bytes;
- bundle ID, group ID or manifest excerpt.

Return the first failure according to the deterministic order defined below.

# Part 4 — Input and archive-reference collection

The public method must require runtime-valid:

- manifest `NSDictionary`;
- nonempty, non-whitespace, NUL-free backup-directory `NSString`;
- non-nil `PXVerifiedBackupArtifactSet` instance;
- manifest `artifacts` array;
- every consumed operational section in its TASK-2.1 validated runtime category.

Collect only artifacts that Restore will extract as tar archives, in this operational order:

1. `data.archive`;
2. every `appGroups[i].archive` in array order;
3. `profileAppData.archive` when included;
4. `globalSafari.archive` when included;
5. every `systemGlobalLibrary.items[i].archive` when included.

Do not parse as tar:

- preferences artifact;
- Keychain artifact;
- shared-system-DB artifact;
- an unreferenced declaration merely because its name ends in `.tar.gz`;
- arbitrary artifacts selected by filename extension.

Each archive reference must:

- be a safe relative artifact name under the TASK-2.5 policy;
- exact-match one manifest artifact declaration;
- have a nonempty path in `verifiedArtifacts` for the same exact name;
- appear at most once in the archive-reference set.

A reference that is missing from the verified set or declarations fails closed. Do not reconstruct a path from `backupDirectory` as a fallback.

# Part 5 — Declaration metadata and deterministic order

Build an internal exact-name declaration map from `manifest.artifacts`, retaining:

- original declaration index;
- exact name;
- exact expected compressed size;
- exact expected lowercase SHA-256.

Do not read `artifact.path`.

After operational references are collected:

1. sort referenced archive records by exact archive name;
2. validate archives in that sorted order;
3. validate physical tar headers in stream order;
4. report the first physical-header failure.

The field path for archive-content failures must use the original artifact declaration index and the physical real-header index. Metadata pseudo-headers may have their own physical index but must not be exposed by raw name.

# Part 6 — Safe backup-root and archive opening

The archive validator must independently re-establish the selected backup-root boundary. It must not trust an absolute path string from the verified set as sufficient proof.

Required root behavior:

- selected backup-directory final component exists;
- final component is a real directory and not a symlink;
- `realpath` succeeds;
- raw-opened and canonical-opened directory descriptors refer to the same device/inode;
- normal ancestor aliases such as `/var -> /private/var` remain permitted;
- root descriptors are opened with `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`.

For each archive:

- require the verified-set path to equal exact `canonicalRoot + "/" + archiveName`;
- walk parent components from the canonical root descriptor with `openat`, `O_DIRECTORY`, `O_NOFOLLOW` and `O_CLOEXEC`;
- open the final archive with `openat`, `O_RDONLY`, `O_NONBLOCK`, `O_NOFOLLOW` and `O_CLOEXEC`;
- require `fstat` regular-file type;
- compare exact compressed size with the manifest declaration before decompression;
- close every descriptor on every path.

Reject parent symlinks, final symlinks, non-directory parents, directories, devices, sockets, FIFOs and descriptor failures.

# Part 7 — Streaming gzip implementation

`PXBackupArchiveValidator.m` must parse in-process with zlib.

Allowed imports:

```objc
#import "PXBackupArchiveValidator.h"
#import "PXBackupArtifactVerifier.h"
#import <CommonCrypto/CommonDigest.h>
#include <zlib.h>
```

Required POSIX/C headers may also be included.

Use a custom descriptor-read plus `inflate` loop. Do not use `gzopen` on an absolute path.

Required gzip policy:

- require gzip magic `1f 8b`;
- require deflate compression method;
- initialize zlib in gzip-only mode, not generic zlib-stream mode;
- stream compressed bytes from the safely opened descriptor;
- update compressed-file SHA-256 from the same bytes read from the descriptor;
- retry `EINTR`;
- never load the whole compressed or decompressed archive into memory;
- require one complete gzip member;
- reject concatenated gzip members;
- reject trailing compressed bytes or garbage after stream end;
- reject EOF before `Z_STREAM_END`;
- reject zlib data/dictionary/state errors with a stable generic error;
- always call `inflateEnd` after successful initialization.

Do not expose `z_stream.msg`.

# Part 8 — Compressed-file stability and identity

Before streaming, capture `fstat` identity.

After complete gzip/tar validation:

- `fstat` the same descriptor again;
- require unchanged device, inode, regular-file type, compressed size, mtime and ctime;
- require the number of compressed bytes read to equal the exact declared compressed size;
- require the computed compressed SHA-256 to exact-match the manifest declaration;
- `lstat` the canonical archive path and require it still points to the same non-symlink regular-file device/inode.

Do not compare atime.

Failures map to:

- compressed size mismatch -> `SizeMismatch`;
- compressed digest mismatch -> `DigestMismatch`;
- identity/time/path replacement -> `FilesystemChanged`.

This is a validation snapshot. Do not claim it prevents replacement after the method returns.

# Part 9 — Tar block parser

Parse the decompressed stream as 512-byte tar records.

Required behavior:

- verify every non-zero header checksum;
- accept unsigned or historical signed-byte checksum calculation when it matches exactly;
- parse standard octal numeric fields with strict overflow checks;
- support nonnegative GNU base-256 size representation;
- reject negative or overflowing numeric fields;
- support POSIX ustar name plus prefix composition;
- permit legacy empty magic only when all required fields and checksum are valid;
- recognize GNU and POSIX ustar magic spellings produced by current GNU/BSD tar variants;
- require two consecutive all-zero blocks to terminate the archive;
- after termination, permit only additional decompressed zero bytes/blocks until gzip end;
- reject non-zero data after the end marker;
- reject incomplete header, payload or padding;
- do not require ordinary file padding bytes themselves to be zero.

A stream that ends without two zero blocks is `TruncatedArchive`.

# Part 10 — Supported metadata pseudo-members

The validator may consume these non-logical metadata header types:

```text
x  POSIX per-entry PAX header
g  POSIX global PAX header
L  GNU long pathname
K  GNU long link pathname
```

They do not count as logical members but do count toward physical-header and metadata limits.

## PAX records

Parse PAX payload as exact length-prefixed records:

```text
<decimal-length><space><key>=<value>\n
```

Require:

- decimal length has no sign;
- length is nonzero and fits the payload;
- each record ends exactly at its declared byte count;
- key is nonempty printable ASCII excluding `=` and control characters;
- no NUL in a record;
- all payload bytes are consumed by valid records.

Per-entry PAX may override:

```text
path
size
linkpath
```

Rules:

- `path` must be valid UTF-8 and pass the exact member-path policy;
- `size` must be a nonnegative decimal uint64 and controls the following real member payload length;
- `linkpath` may be parsed, but any following link entry is still rejected;
- duplicate `path`, `size` or `linkpath` overrides across pending metadata fail;
- any key beginning with `GNU.sparse` fails as unsupported sparse semantics;
- unknown well-formed metadata keys, including bounded xattr/ACL keys, may be ignored.

Global PAX headers:

- may carry inert well-formed metadata;
- must reject `path`, `size`, `linkpath` and any `GNU.sparse` key;
- must not create a pending member path or size override.

## GNU long names

`L` and `K` payloads:

- must fit the metadata limit;
- may end in NUL and/or newline terminators;
- must not contain an interior NUL;
- must decode as UTF-8;
- `L` supplies the next real member path;
- `K` supplies a pending link target, but the next link entry remains unsupported;
- pending metadata left at archive end is invalid.

A pending link target attached to a non-link real entry is `InvalidExtendedHeader`.

# Part 11 — Effective member-path policy

Determine the effective member path in this precedence order:

1. per-entry PAX `path`;
2. GNU `L` long name;
3. ustar `prefix/name` or legacy header name.

Do not silently accept two different override sources for the same next member.

Decode the effective path as UTF-8 without normalization or case folding.

Allow the archive writer's root marker:

```text
.
./
```

only when the real member type is directory. It normalizes to one internal root marker.

For other members:

- remove repeated leading `./` root-marker components only;
- allow one trailing slash only for a directory and remove it for identity comparison;
- reject an absolute leading `/`;
- reject backslash;
- reject empty components;
- reject remaining `.` components;
- reject `..` components;
- reject doubled slash;
- reject NUL;
- reject invalid UTF-8;
- reject ASCII control characters `0x01` through `0x1f` and `0x7f`;
- require each UTF-8 component length <= 255 bytes;
- require normalized full UTF-8 path length <= 4096 bytes;
- preserve exact Unicode bytes/case for identity;
- do not percent-decode, standardize, precompose, decompose or resolve against a filesystem.

# Part 12 — Allowed real member types

Allow only:

```text
NUL or '0'  regular file
'5'         directory
```

Reject every other real type, including:

```text
'1' hard link
'2' symbolic link
'3' character device
'4' block device
'6' FIFO
'7' contiguous file
'S' GNU sparse
'D' GNU dump directory
unknown/vendor member types
```

Do not attempt to make links safe by validating their target. Links are not part of the accepted Restore archive model in TASK-2.6.

Directory members must have effective size zero.

Regular-file members may have size zero.

Reject setuid or setgid mode bits on any real member. Do not rewrite modes.

# Part 13 — Duplicate and topology policy

Maintain exact normalized member identity for every real member.

Reject:

- duplicate normalized path;
- root marker duplicate;
- one path declared as both file and directory;
- a regular file whose path was already used as an implicit parent;
- a child beneath an already declared regular-file path;
- a directory entry that conflicts with an existing regular-file identity.

Implicit parent directories do not require explicit directory entries.

A later explicit directory entry for an already used implicit directory is allowed only if that exact normalized directory path has not already appeared as a real member.

Do not choose first/last entry and do not overwrite duplicate state.

# Part 14 — Fixed resource limits

Use private fixed constants. Do not expose user-configurable limits in this task.

Exact limits:

```text
maximum referenced archive count:              10,000
maximum physical tar headers per archive:      400,000
maximum logical real members per archive:      200,000
maximum logical real members across Restore:   500,000
maximum effective path UTF-8 bytes:             4,096
maximum component UTF-8 bytes:                    255
maximum one PAX/GNU metadata payload:        1 MiB
maximum metadata payload total per archive: 16 MiB
maximum one regular-file logical size:       64 GiB
minimum inflated-stream budget:               1 GiB
inflation multiplier over compressed size:    4,096
absolute inflated-stream budget per archive: 128 GiB
absolute inflated-stream budget across call: 256 GiB
```

Per-archive inflated budget:

```text
min(128 GiB, max(1 GiB, compressedSize * 4096))
```

Compute all multiplication and addition with overflow checks.

Track every decompressed byte, including headers, payload and padding. Exceeding the dynamic or absolute budget fails immediately with `LimitExceeded`.

Track the sum of effective regular-file logical sizes and require it not to exceed the same per-archive inflated budget.

Metadata pseudo-member payloads count toward inflated bytes and metadata totals but not logical member count or regular-file bytes.

# Part 15 — Streaming memory boundary

The implementation may retain:

- fixed zlib input/output buffers;
- one 512-byte tar header block;
- bounded parser state;
- normalized path/type sets up to the member limit;
- one PAX or GNU metadata payload up to 1 MiB;
- immutable result summary maps.

It must not:

- load the compressed archive into `NSData`;
- load regular-file payloads into memory;
- retain all raw headers;
- retain all member payloads;
- create a temporary decompressed tar file;
- create a staging directory;
- write any filesystem object.

Regular-file payload bytes must be streamed and discarded after accounting.

# Part 16 — Pure validator boundary

`PXBackupArchiveValidator.m` may import only:

- its own header;
- `PXBackupArtifactVerifier.h`;
- CommonCrypto;
- zlib;
- required POSIX/C headers.

Forbidden:

```text
UIKit
AppDataBackupManager
AppDataCleaner
CommandRunner
NSTask
posix_spawn
system
popen
shell command construction
tar executable invocation
libarchive extraction APIs
Security/Keychain
notifications
dispatch
NSUserDefaults
filesystem mutation
NSUserDefaults/global cache
raw-value logging
```

No global mutable state or parser cache.

# Part 17 — Makefile integration

Modify only the existing application linker line to add zlib:

```text
ProjectX_LDFLAGS ... -lsqlite3 -lz
```

Requirements:

- exactly one `-lz` for the application target;
- do not add `-lz` to tweak/helper targets;
- do not alter SDK target, architectures, wildcard source list, frameworks, signing or package rules;
- no vendored zlib source or binary.

# Part 18 — Restore integration and ordering

Add exactly one import to `AppDataBackupManager.m`:

```objc
#import "PXBackupArchiveValidator.h"
```

In `restoreBackupAtDirectory:bundleID:appName:completion:`, required order becomes:

1. existing public parameter guard;
2. common manifest read/schema/version gate;
3. exact requested bundle-ID gate;
4. TASK-2.4 exact destination resolution/validation;
5. TASK-2.5 common artifact verification;
6. TASK-2.6 archive-entry validation;
7. archive failure callback and return;
8. warnings allocation, `NSFileManager`, `CommandRunner`, debug state, tar discovery and all remaining work.

Call archive validation exactly once:

```objc
NSError *archiveError = nil;
PXValidatedBackupArchiveSet *validatedArchives =
    [PXBackupArchiveValidator validatedArchivesForManifest:manifest
                                           backupDirectory:backupDir
                                         verifiedArtifacts:verifiedArtifacts
                                                     error:&archiveError];
```

If nil:

- propagate the exact non-nil validator `NSError`;
- complete once on the main queue;
- result nil;
- return immediately.

A generic archive-validator-domain impossible-state error is allowed only if the validator unexpectedly returns nil without an error.

Archive validation must precede:

- warnings allocation;
- debug file construction/write;
- `CommandRunner` acquisition;
- tar executable discovery;
- process kill;
- profile lookup;
- App Group entitlement/destination work;
- extraction;
- staging creation;
- every target mutation.

# Part 19 — Retain validated archive snapshot

Keep the returned `PXValidatedBackupArchiveSet` alive for the Restore operation.

Do not rebuild or re-run the archive validator later in this task.

The existing extraction methods may continue receiving canonical artifact paths from `PXVerifiedBackupArtifactSet`. TASK-2.6 does not replace them with descriptors.

Do not claim that the archive result is an immutable Restore plan. TASK-2.7 owns plan construction.

# Part 20 — Preserve extraction behavior

Do not modify the bodies or behavior of:

```text
_tarExtract:archive:toDir:
_tarExtractDataArchive:archive:toDir:warnings:
_directoryHasRestoredContent:
```

Do not change:

- tar executable preference order;
- `--xattrs`/`--acls` fallback behavior;
- the main-data staging directory;
- the current `Cannot open: File exists` compatibility handling;
- clone/cp fallback;
- ownership correction;
- App Group destination resolution;
- profile/global/system destination behavior;
- preferences, Keychain or shared-DB copy behavior.

Only add the archive-entry preflight gate.

# Part 21 — TASK-2.1 through TASK-2.5 non-regression

Preserve exact behavior of:

- manifest schema validation;
- supported versions `{2,3}`;
- validator error propagation;
- unsupported code 201;
- exact requested bundle comparison and code 304;
- exact canonical destination helper and code 303;
- retained destination model/canonical path;
- pre-mutation destination revalidation;
- common artifact verifier API and source;
- artifact verification ordering;
- verified artifact paths for all Restore sources;
- Backup writer manifestVersion `@3`;
- Backup artifact self-check;
- recorded source path/UUID metadata.

Required body hashes before/after for at least:

```text
PXBackupManifestVersionIsSupported
PXResolveExactRestoreApplicationDataTarget
readManifestAtBackupDirectory:error:
createBackupForBundleID:appName:options:completion:
_tarExtract:archive:toDir:
_tarExtractDataArchive:archive:toDir:warnings:
```

All must be equal.

# Part 22 — TASK-2.7 and later boundaries

Do not:

- create `PXRestorePlan`;
- normalize all component destinations into one plan;
- change staging architecture;
- validate extracted staging contents;
- commit or roll back target state;
- quarantine target directories transactionally;
- add structured Restore component results;
- modify UI;
- modify Backup publication;
- add malicious fixtures to production source.

These remain TASK-2.7 through TASK-2.14 and Phase 3/6.

# Part 23 — Final static gates

## Scope

```text
PXBackupArchiveValidator.h added
PXBackupArchiveValidator.m added
AppDataBackupManager.m modified
Makefile modified
all other production diffs = 0
```

## Public API

```text
error domain exports = 1
field-path exports = 1
error enum values = exactly 16
validated result classes = 1
validator classes = 1
public validator methods = 1
public extraction methods = 0
```

## Pure validator

```text
AppDataBackupManager imports = 0
CommandRunner references = 0
shell/process calls = 0
tar executable calls = 0
filesystem mutation = 0
whole-file NSData loading = 0
zlib inflate streaming present
CommonCrypto compressed digest present
openat/O_NOFOLLOW traversal present
fstat before/after present
lstat final-path recheck present
artifact.path reads = 0
raw-value logging = 0
```

## Archive policy

```text
allowed real member types = regular and directory only
symlink acceptance = 0
hardlink acceptance = 0
special-file acceptance = 0
absolute/member traversal acceptance = 0
duplicate normalized member acceptance = 0
PAX x/g support present
GNU L/K bounded parsing present
GNU sparse acceptance = 0
two-zero-block termination required
concatenated gzip acceptance = 0
trailing gzip garbage acceptance = 0
fixed limits present exactly
```

## Restore integration

```text
archive validator import in manager = 1
archive validator calls in Restore = 1
archive validator calls in Backup = 0
archive validation follows artifact verification
archive validation precedes warnings/runner/debug/tar/kill/staging/extraction/mutation
exact archive NSError propagation present
external tar listing added = 0
extraction helper body changes = 0
```

## Makefile

```text
application -lz occurrences = 1
other-target -lz additions = 0
wildcard source behavior unchanged
```

# Part 24 — Scenario matrix

The report must include at least 140 explicit scenario rows, including:

1. valid GNU-generated gzip ustar archive;
2. valid BSD-generated gzip PAX archive;
3. valid empty directory archive;
4. valid zero-byte regular file;
5. valid nested UTF-8 paths;
6. valid `./` root directory marker;
7. repeated leading `./` root markers normalized;
8. valid PAX path override;
9. valid PAX size override;
10. valid bounded xattr/ACL PAX keys;
11. valid GNU long name;
12. invalid gzip magic;
13. unsupported compression method;
14. truncated gzip stream;
15. concatenated gzip members;
16. trailing compressed garbage;
17. zlib data error;
18. archive compressed size changed;
19. archive compressed hash changed;
20. archive inode changed during parse;
21. archive mtime changed;
22. archive ctime changed;
23. final archive path replaced;
24. parent symlink after artifact verification;
25. final archive symlink;
26. final archive FIFO;
27. final archive directory;
28. missing verified-set archive;
29. verified path not canonical-root/name;
30. malformed header checksum;
31. signed historical checksum accepted;
32. invalid octal size;
33. negative base-256 size;
34. overflowing size;
35. one zero block only;
36. no end marker;
37. nonzero data after end marker;
38. incomplete payload;
39. incomplete padding;
40. absolute member path;
41. internal `..` traversal;
42. internal `.` component;
43. doubled slash;
44. backslash;
45. invalid UTF-8;
46. path control character;
47. component over 255 bytes;
48. full path over 4096 bytes;
49. regular member trailing slash;
50. root marker regular file;
51. root marker directory;
52. duplicate root marker;
53. duplicate normalized path;
54. file then child path;
55. child then file parent;
56. implicit directory then explicit directory;
57. duplicate explicit directory;
58. regular file accepted;
59. directory accepted;
60. symlink rejected;
61. hardlink rejected;
62. character device rejected;
63. block device rejected;
64. FIFO member rejected;
65. contiguous member rejected;
66. GNU sparse rejected;
67. unknown type rejected;
68. setuid member rejected;
69. setgid member rejected;
70. nonzero directory size rejected;
71. malformed PAX length;
72. PAX record missing newline;
73. PAX record missing equals;
74. PAX empty key;
75. PAX NUL;
76. PAX invalid path UTF-8;
77. PAX negative size;
78. PAX size overflow;
79. duplicate PAX path override;
80. duplicate PAX size override;
81. global PAX path rejected;
82. global PAX size rejected;
83. GNU.sparse PAX rejected;
84. unknown safe PAX key ignored;
85. over-1-MiB metadata header;
86. over-16-MiB metadata total;
87. GNU long-name internal NUL;
88. GNU long-name invalid UTF-8;
89. GNU long-link before hardlink rejected;
90. pending metadata at archive end;
91. conflicting PAX and GNU path overrides;
92. 200,000 logical members boundary;
93. 200,001 logical members rejected;
94. physical-header boundary;
95. total-Restore member boundary;
96. single-file 64-GiB boundary;
97. single-file over 64 GiB;
98. inflation multiplier boundary;
99. per-archive 128-GiB cap;
100. total-call 256-GiB cap;
101. arithmetic overflow;
102. regular payload streamed/discarded;
103. no whole-file NSData;
104. descriptor cleanup on root failure;
105. descriptor cleanup on metadata failure;
106. `inflateEnd` on every initialized path;
107. archive references collected by component semantics, not extension;
108. preferences not parsed as tar;
109. Keychain not parsed as tar;
110. shared DB not parsed as tar;
111. unreferenced `.tar.gz` not parsed;
112. data archive parsed;
113. App Group archives parsed;
114. profile archive parsed only when included;
115. global Safari parsed only when included;
116. system-global archives parsed when included;
117. archive validation sorted by exact name;
118. member failure uses physical order;
119. error contains no member name;
120. error contains no archive path;
121. exact validator error propagation;
122. impossible nil-error fallback;
123. validation before warnings;
124. validation before CommandRunner;
125. validation before tar discovery;
126. validation before process kill;
127. validation before staging creation;
128. validation before extraction;
129. validation before mutation;
130. no `tar -t` command;
131. no libarchive extraction;
132. extraction methods byte-identical;
133. TASK-2.5 verifier files unchanged;
134. TASK-2.4 destination helper unchanged;
135. exact bundle gate unchanged;
136. version policy unchanged;
137. Backup writer unchanged;
138. `-lz` added once to application only;
139. no UI change;
140. TASK-2.7 remains unimplemented.

Add deterministic ordering, legacy v2/v3 combinations, Unicode, PAX stacking, failure cleanup and protected-file cases as needed.

# Part 25 — Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.6-REPORT.md
```

The report must include:

- baseline and initial status;
- exact implementation scope;
- protected SHA-256 before/after;
- public API and exact 16-code enum;
- immutable result proof;
- archive-reference inventory;
- deterministic archive/header ordering;
- root/openat/no-follow proof;
- gzip streaming and compressed-hash proof;
- tar checksum/numeric/end-marker proof;
- effective path policy;
- real member type policy;
- PAX/GNU metadata policy;
- duplicate/topology policy;
- exact private limits and overflow handling;
- compressed-file before/after identity proof;
- Restore ordering and exact NSError propagation;
- extraction helper body hashes;
- TASK-2.1 through TASK-2.5 non-regression;
- Makefile `-lz` proof;
- TASK-2.7 boundary;
- complete production diff;
- static/forbidden token counts;
- at least 140 explicit scenario rows;
- whitespace/CRLF/NUL/generated-artifact audit;
- build status and remaining runtime risks.

Do not paste large binary fixtures or generated archives into the report.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 26 — Verification

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXBackupArchiveValidator.h PXBackupArchiveValidator.m AppDataBackupManager.m Makefile
git diff -- PXBackupArchiveValidator.h PXBackupArchiveValidator.m AppDataBackupManager.m Makefile
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 2a00a93e2127872845cc4e673c8929236d098c13..HEAD --check
git diff --name-status 2a00a93e2127872845cc4e673c8929236d098c13..HEAD
```

Stop after TASK-2.6.

Do not implement TASK-2.7.
