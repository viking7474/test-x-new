# TASK-2.6A — Fix Archive Validator Compatibility and Bounded Topology

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `6dd6df3d435fefe03a4098342c7a4ee7b9afe58a`
- Previous task: TASK-2.6 source review CHANGES_REQUESTED
- Next task: TASK-2.7 remains LOCKED

## Objective

Correct five narrow source-contract defects in the TASK-2.6 archive validator without changing its public API, Restore integration, linker configuration or extraction behavior:

1. preserve optional `systemGlobalLibrary` compatibility;
2. ignore syntactically valid non-reserved PAX metadata as required;
3. bound retained implicit-directory topology state;
4. classify POSIX ustar, GNU and legacy tar headers separately;
5. preserve close-on-exec on the duplicated root traversal descriptor.

Do not redesign the gzip/tar parser or implement TASK-2.7.

## Production scope

Modify only:

```text
PXBackupArchiveValidator.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-2.6A-REPORT.md
```

Suggested commit subject:

```text
phase2(task-2.6A): fix archive validator compatibility and bounds
```

Implementation commit may contain only:

```text
PXBackupArchiveValidator.m
docs/backup-restore-hardening/reports/TASK-2.6A-REPORT.md
```

## Protected files

Do not modify:

```text
PXBackupArchiveValidator.h
AppDataBackupManager.h
AppDataBackupManager.m
Makefile
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

# Part 1 — Preserve the TASK-2.6 public and integration contract

`PXBackupArchiveValidator.h` must remain byte-identical.

Preserve exactly:

- the 16 public error codes and numeric values;
- `PXValidatedBackupArchiveSet` properties and lookup method;
- the single public validator selector;
- sorted immutable result behavior;
- error domain and field-path key;
- two-key `NSError.userInfo` policy;
- one Restore call after TASK-2.5 artifact verification;
- exact archive-validator error propagation;
- application-only `-lz`;
- all manager ordering and extraction behavior.

Do not add a public/private bypass, warning mode, new parser API, new result type, user-configurable limit or Restore-plan type.

# Part 2 — Restore optional `systemGlobalLibrary` compatibility

The common schema validator and TASK-2.5 artifact verifier already treat `systemGlobalLibrary` as an optional additive section. TASK-2.6A must preserve that contract.

In `PXArchiveCollectReferences`:

```text
manifest has no systemGlobalLibrary key
  -> valid; collect no system-global archive references

manifest has systemGlobalLibrary == NSNull/non-dictionary
  -> InvalidInput at $.systemGlobalLibrary

present dictionary missing/invalid included
  -> InvalidInput at $.systemGlobalLibrary.included

present dictionary missing/invalid items
  -> InvalidInput at $.systemGlobalLibrary.items

included == NO
  -> collect no item archives

included == YES
  -> collect every items[i].archive in array order
```

When present, keep the existing exact runtime checks. Do not invent defaults inside a malformed present section.

Do not change optional behavior for:

- `profileAppData`;
- `globalSafari`;
- `sharedSystemDB`;
- any TASK-2.1 manifest field.

Do not modify the manifest validator or artifact verifier.

# Part 3 — Restore the frozen unknown-PAX policy

The frozen TASK-2.6 contract requires that syntactically valid, bounded, non-reserved PAX metadata may be ignored.

Keep exact reserved handling:

```text
path
size
linkpath
```

Keep exact sparse rejection:

```text
any key beginning with GNU.sparse
  -> UnsupportedEntryType
```

For every other key that already passed the strict PAX record checks:

- do not reject merely because it is absent from a private allow-list;
- do not retain the value;
- do not log the key or value;
- do not allow it to alter path, size, link type, member type, mode or parser limits;
- continue consuming its declared bytes as metadata and counting them toward metadata/inflation budgets.

The private helper `PXArchivePAXKeyIsInert` may be deleted or reduced, but there must be no semantic allow-list that rejects an otherwise well-formed non-reserved key.

Continue rejecting:

- malformed decimal length;
- record boundary mismatch;
- missing newline;
- missing/invalid equals separator;
- empty or non-printable key;
- NUL anywhere in the record;
- duplicate pending `path`, `size` or `linkpath` overrides;
- global `path`, `size` or `linkpath`;
- invalid UTF-8 in reserved string values;
- negative/overflowing/non-decimal `size`;
- every `GNU.sparse` prefix.

Required examples:

```text
SCHILY.xattr.user.test   -> ignored after structural validation
LIBARCHIVE.xattr.test    -> ignored after structural validation
vendor.example           -> ignored after structural validation
future.key               -> ignored after structural validation
GNU.sparse.map           -> rejected
path                     -> applied under existing rules
size                     -> applied under existing rules
linkpath                 -> parsed under existing rules
```

Update the TASK-2.6A report honestly; do not repeat TASK-2.6's contradictory claim that unknown semantic vendor keys are rejected.

# Part 4 — Bound implicit-directory topology state

The parser currently retains `_implicitDirectories` separately from real member identities. TASK-2.6A must ensure this retained set cannot exceed the existing private logical-member limit:

```objc
PXArchiveMaximumLogicalMembers == 200000
```

Do not add a new limit constant or public configuration.

In `registerNormalizedPath:directory:error:` or an equivalent private boundary:

1. Derive parent prefixes in deterministic shallow-to-deep order.
2. Reject immediately if any existing parent is a regular file, preserving current behavior.
3. Determine the exact set/list of parent prefixes that are not already present in `_implicitDirectories`.
4. Perform overflow-safe count arithmetic before mutating `_implicitDirectories`.
5. If:

```text
current unique implicit count + new unique parent count > 200000
```

fail with:

```text
domain: PXBackupArchiveValidatorErrorDomain
code: PXBackupArchiveValidatorErrorLimitExceeded
field path: current real member .path
```

6. On this failure, add none of the candidate parent prefixes and do not register the real member.
7. On success, add the new parent prefixes and continue existing duplicate/topology registration.

The exact boundary is:

```text
200000 unique implicit directory identities -> allowed
200001 unique implicit directory identities -> rejected
```

Real logical-member count remains independently limited to 200,000. Do not merge the two counters and do not count repeated already-known implicit parents again.

Preserve existing topology outcomes:

- explicit directory after an implicit parent is allowed once;
- duplicate explicit directory is rejected;
- file beneath a declared file is rejected;
- file at a path already used as an implicit directory is rejected;
- directory/file duplicate identity is rejected;
- no partial topology state is retained after any failure.

# Part 5 — Classify tar header formats exactly

Replace the single broad `ustar` Boolean with a private fixed format classification equivalent to:

```objc
typedef NS_ENUM(NSUInteger, PXArchiveTarHeaderFormat) {
    PXArchiveTarHeaderFormatLegacy = 0,
    PXArchiveTarHeaderFormatPOSIXUstar = 1,
    PXArchiveTarHeaderFormatGNU = 2,
};
```

The exact private name may differ, but the semantics must be equivalent.

## Accepted spellings

Legacy:

```text
magic[0...5] all NUL
```

Keep the TASK-2.6 accepted legacy behavior. Required numeric fields and checksum must still be valid.

POSIX ustar:

```text
magic bytes:   "ustar\0"
version bytes: "00"
```

GNU:

```text
magic bytes:   "ustar "
version bytes: " \0"
```

Reject every other nonempty magic/version pair as `InvalidHeader`, including:

- `ustar\0` with non-`00` version;
- `ustar ` with non-` \0` version;
- five-byte `ustar` prefix with arbitrary sixth/version bytes;
- partially empty/mixed magic;
- unrelated nonempty magic.

## Path extraction by format

POSIX ustar only:

- read the 155-byte prefix field at offset 345;
- if nonempty, compose `prefix + "/" + name`;
- if empty, use name.

GNU:

- do not treat bytes 345–499 as a POSIX prefix;
- use the ordinary 100-byte header name unless a pending GNU `L` or PAX `path` override applies.

Legacy:

- use the ordinary 100-byte header name;
- do not use POSIX prefix composition.

Preserve effective override precedence:

```text
PAX path
GNU L path
format-specific header path
```

Do not loosen unsupported real member types, GNU sparse policy, checksum policy or path normalization.

# Part 6 — Preserve close-on-exec during root-descriptor duplication

`PXArchiveOpenRelativeFile` must not begin traversal with a descriptor whose `FD_CLOEXEC` flag was cleared by raw `dup`.

Use one of these equivalent private approaches:

```text
fcntl(rootDescriptor, F_DUPFD_CLOEXEC, ...)
```

or:

```text
dup(rootDescriptor)
then fcntl(F_SETFD, existingFlags | FD_CLOEXEC)
and verify success before traversal
```

Requirements:

- duplicated traversal descriptor has `FD_CLOEXEC` before the first `openat`;
- failure to duplicate, read flags or set flags fails closed with `OpenFailed` at the archive reference field path;
- no descriptor leak on any failure;
- all child directory and final file opens retain existing `O_CLOEXEC` flags;
- do not change no-follow or regular-file policy.

# Part 7 — Preserve all accepted gzip/tar behavior

Do not change behavior outside the five corrections.

Preserve:

- independent backup-root canonicalization;
- verified canonical path equality;
- descriptor-relative no-follow traversal;
- regular compressed-file requirement;
- exact compressed size before parse;
- gzip magic and deflate method checks;
- gzip-only `inflateInit2` mode;
- one gzip member only;
- trailing/concatenated compressed-data rejection;
- compressed SHA-256 from the same descriptor reads;
- `EINTR` retry;
- `inflateEnd` on every initialized path;
- before/after descriptor identity and final path recheck;
- 512-byte streaming tar parser;
- unsigned and historical signed checksum acceptance;
- strict octal and nonnegative GNU base-256 size parsing;
- two-zero-block termination;
- nonzero data-after-end rejection;
- incomplete header/payload/padding rejection;
- PAX and GNU metadata size limits;
- regular-file/directory-only real member types;
- setuid/setgid rejection;
- member path policy;
- duplicate/topology behavior except the new implicit-state bound;
- all fixed size/member/inflation limits;
- immutable sorted summary result;
- stable non-sensitive error contract.

Do not add external fixtures, shell calls, `tar -t`, libarchive, filesystem mutation, staging or extraction to the validator.

# Part 8 — Protected behavior and hashes

The following files must be byte-identical to baseline:

```text
PXBackupArchiveValidator.h
AppDataBackupManager.m
Makefile
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
PXBackupManifestValidator.h
PXBackupManifestValidator.m
```

The report must record before/after SHA-256 for all protected production files.

Because manager and Makefile are protected, all of these remain unchanged:

- archive validator import count;
- archive validator Restore call count;
- archive validation ordering;
- exact error propagation;
- application-only `-lz`;
- extraction method hashes;
- supported manifest versions `{2,3}`;
- bundle mismatch code 304;
- destination failure code 303;
- TASK-2.5 artifact verifier ordering and paths;
- Backup writer and self-check.

# Part 9 — Pure-validator boundary

`PXBackupArchiveValidator.m` may continue importing only:

- its own header;
- `PXBackupArtifactVerifier.h`;
- CommonCrypto;
- zlib;
- required POSIX/C headers.

Forbidden additions remain:

```text
UIKit
AppDataBackupManager
AppDataCleaner
CommandRunner
NSTask
posix_spawn
system
popen
shell/tar invocation
libarchive extraction
Security/Keychain
dispatch
notifications
NSUserDefaults
filesystem mutation
raw-value logging
global mutable state
```

Do not load a whole compressed archive, decompressed tar or regular-file payload into memory.

# Part 10 — Required static gates

## Scope

```text
PXBackupArchiveValidator.m modified
TASK-2.6A-REPORT.md added
all other production diffs = 0
```

## Public/integration non-regression

```text
PXBackupArchiveValidator.h diff = 0
AppDataBackupManager.m diff = 0
Makefile diff = 0
public error enum remains exactly 16
public validator methods remain exactly 1
Restore validator calls remain exactly 1
application -lz remains exactly 1
```

## Optional section

```text
absent systemGlobalLibrary accepted
present invalid systemGlobalLibrary rejected
present included false collects zero archives
present included true collects exact item archives
```

## PAX policy

```text
reserved path/size/linkpath handling retained
GNU.sparse prefix rejection retained
well-formed non-reserved PAX key rejection = 0
well-formed non-reserved values retained in parser state = 0
malformed PAX rejection retained
```

## Topology bounds

```text
implicit-directory maximum uses PXArchiveMaximumLogicalMembers
pre-mutation unique-parent count check present
200000 boundary accepted
200001 rejected with LimitExceeded
partial parent-set mutation on failure = 0
```

## Tar format

```text
private legacy/POSIX/GNU classification present
exact POSIX magic/version check present
exact GNU magic/version check present
POSIX prefix composition only
GNU prefix-area interpretation = 0
malformed version acceptance = 0
```

## Descriptor policy

```text
raw dup without CLOEXEC repair = 0
CLOEXEC-preserving duplication/setup present
openat child O_CLOEXEC retained
all descriptors closed on failure
```

# Part 11 — Scenario matrix

The report must include at least 80 explicit scenario rows, including:

1. version-2-compatible manifest without `systemGlobalLibrary`;
2. version-3 manifest without `systemGlobalLibrary`;
3. present non-dictionary system-global section;
4. present dictionary with invalid included;
5. present dictionary with invalid items;
6. included false and empty items;
7. included true and one item;
8. included true and multiple items in array order;
9. included item missing declaration;
10. included item missing verified path;
11. unknown per-entry `vendor.example` PAX key ignored;
12. unknown global `vendor.example` PAX key ignored;
13. unknown future PAX key with binary non-NUL value ignored;
14. xattr key ignored;
15. ACL key ignored;
16. reserved PAX path still applied;
17. reserved PAX size still applied;
18. reserved PAX linkpath still parsed;
19. global path still rejected;
20. global size still rejected;
21. global linkpath still rejected;
22. GNU.sparse key still rejected;
23. malformed PAX length still rejected;
24. missing PAX newline still rejected;
25. invalid PAX key still rejected;
26. PAX record NUL still rejected;
27. duplicate pending path still rejected;
28. duplicate pending size still rejected;
29. zero implicit parents;
30. repeated known implicit parents do not increase count;
31. one new implicit parent;
32. many new parents added atomically;
33. exactly 200,000 unique implicit parents accepted;
34. 200,001st unique implicit parent rejected;
35. count arithmetic overflow fails closed;
36. parent-limit failure leaves set unchanged;
37. parent-limit failure does not register real member;
38. explicit directory after implicit parent remains accepted;
39. file conflicting with implicit directory remains rejected;
40. child below declared file remains rejected;
41. POSIX `ustar\0` plus `00` accepted;
42. POSIX prefix/name composed;
43. POSIX empty prefix uses name;
44. GNU `ustar ` plus ` \0` accepted;
45. GNU header ignores bytes 345–499 as prefix;
46. GNU pending `L` overrides header name;
47. PAX path overrides GNU `L` conflict remains rejected;
48. legacy empty magic accepted;
49. legacy header ignores prefix region;
50. POSIX magic with wrong version rejected;
51. GNU magic with wrong version rejected;
52. five-byte ustar with arbitrary sixth byte rejected;
53. partial/mixed magic rejected;
54. unrelated magic rejected;
55. checksum behavior unchanged;
56. signed checksum behavior unchanged;
57. base-256 size behavior unchanged;
58. symlink member still rejected;
59. hardlink member still rejected;
60. special files still rejected;
61. duplicate normalized member still rejected;
62. two-zero-block end still required;
63. concatenated gzip still rejected;
64. trailing compressed garbage still rejected;
65. compressed hash still rechecked;
66. final path identity still rechecked;
67. root descriptor close-on-exec duplication succeeds;
68. close-on-exec duplication failure closes nothing extra/leaks nothing;
69. flag-read failure fails closed;
70. flag-set failure closes duplicated descriptor;
71. child directory descriptors remain O_CLOEXEC;
72. final archive descriptor remains O_CLOEXEC;
73. no manager change;
74. no header change;
75. no Makefile change;
76. extraction helper hashes unchanged;
77. no shell or external tar listing;
78. no filesystem mutation;
79. no TASK-2.7 type;
80. report ending and commit scope correct.

Add deterministic error-order, descriptor-cleanup, Unicode, metadata-budget and protected-hash scenarios as needed.

# Part 12 — Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.6A-REPORT.md
```

The report must include:

- baseline and initial status;
- exact two-file commit scope;
- protected SHA-256 before/after;
- each TASK-2.6 review blocker and exact correction;
- optional-section compatibility matrix;
- PAX unknown-key policy and frozen-spec alignment;
- implicit topology-state bound and atomic update proof;
- exact legacy/POSIX/GNU header classification;
- close-on-exec duplication and cleanup proof;
- TASK-2.6 accepted gzip/tar behavior non-regression;
- manager/header/Makefile zero-diff proof;
- extraction helper body hashes;
- full production diff;
- static/forbidden-token counts;
- at least 80 explicit scenarios;
- whitespace/CRLF/NUL/generated-artifact audit;
- build status and remaining runtime risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 13 — Verification

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXBackupArchiveValidator.m
git diff -- PXBackupArchiveValidator.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 6dd6df3d435fefe03a4098342c7a4ee7b9afe58a..HEAD --check
git diff --name-status 6dd6df3d435fefe03a4098342c7a4ee7b9afe58a..HEAD
```

Stop after TASK-2.6A.

Do not implement TASK-2.7.
