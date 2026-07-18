# TASK-2.13A — Fix Missing Optional Directory-Tree Verifier

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `08d23dd0a9fa41a39efd5b62680974f23e75fe45`
- Parent task: TASK-2.13
- Review: `docs/backup-restore-hardening/reviews/TASK-2.13-REVIEW.md`

## Objective

Close the single source/link blocker found during TASK-2.13 review.

`PXOptionalRestoreTransaction.m` currently calls:

```objc
PXOptionalRestoreVerifyDirectoryTree(...)
```

at two production call sites but does not declare or define that function anywhere.

TASK-2.13A must add a complete file-local directory-tree verifier that:

1. compiles and links without an implicit or unresolved external symbol;
2. traverses a prepared optional replacement directory descriptor-relatively;
3. reproduces the exact deterministic digest contract of `PXValidatedMainDataStage`;
4. compares all accepted snapshot counts and bytes;
5. fails closed on unsafe type, path, link, mount, identity or race conditions;
6. preserves all accepted TASK-2.13 public API, manager integration, journal, rollback and cleanup behavior.

This is a narrow corrective task. It is not a redesign of optional transactions.

## Exact implementation scope

Allowed production file:

```text
PXOptionalRestoreTransaction.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.13A-REPORT.md
```

The implementation commit may contain only:

```text
PXOptionalRestoreTransaction.m
docs/backup-restore-hardening/reports/TASK-2.13A-REPORT.md
```

## Protected files

Do not modify:

```text
PXOptionalRestoreTransaction.h
AppDataBackupManager.m
AppDataBackupManager.h
PXMainDataRestoreTransaction.h/.m
PXAppGroupRestoreTransaction.h/.m
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXOptionalRestoreStaging.h/.m
PXRestorePlan.h/.m
PXBackupManifestValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
CommandRunner.h/.m
Makefile
UI/controller files
Backup files
Keychain helper/bridge files
coordinator task/review/status/roadmap/decisions/README files
```

Record SHA-256 before and after for all protected production files.

## Required private function

Add exactly one file-local definition with this signature:

```objc
static BOOL PXOptionalRestoreVerifyDirectoryTree(
    int rootDescriptor,
    PXValidatedMainDataStage *expectedStage,
    NSError **error);
```

Requirements:

- definition count: exactly one;
- declaration without definition is insufficient;
- external/non-static symbol is forbidden;
- both existing call sites must resolve to this function;
- no additional public API;
- no implementation in another translation unit.

Private helper functions/classes may be added inside `PXOptionalRestoreTransaction.m` only when required to implement this verifier safely.

The existing unused `PXOptionalRestoreTreeFrame` and hash helpers may be completed/reused.

## Input contract

On entry:

- clear `*error` when error is non-null;
- require `rootDescriptor >= 0`;
- require `expectedStage` runtime class is `PXValidatedMainDataStage`;
- require `expectedStage.treeSHA256` is exactly 64 lowercase hexadecimal characters;
- require accepted counts are internally valid:
  - `regularFileCount <= entryCount`;
  - `directoryCount <= entryCount`;
  - `regularFileCount + directoryCount == entryCount` with overflow-safe arithmetic;
  - `entryCount <= PXOptionalRestoreMaximumAggregateEntries`;
  - `regularFileBytes` is used as the exact accepted total.

Invalid input must fail with:

```text
domain: PXOptionalRestoreTransactionErrorDomain
code: PXOptionalRestoreTransactionErrorInvalidInput
field path: $.replacement
```

Do not expose path, digest, inode, device or nested error in the public NSError description.

## Descriptor ownership

The verifier does not own the caller's `rootDescriptor`.

It must:

- duplicate or independently open the root descriptor for traversal;
- set/verify close-on-exec on every owned descriptor;
- close every owned descriptor on success and every failure path;
- never close or replace the caller descriptor;
- never use an absolute replacement path;
- never use `NSFileManager`, shell commands, `nftw`, `fts`, `glob`, `realpath` traversal or path-based recursion.

All namespace inspection must be relative to retained descriptors.

## Root binding

Before traversal:

1. `fstat(rootDescriptor)`;
2. require a real directory;
3. require no setuid/setgid bits;
4. retain root device/inode/type/mode and stable directory timestamps required by the implementation;
5. enumerate names deterministically using the existing descriptor-relative directory reader or an equivalent bounded helper.

After complete traversal:

- `fstat(rootDescriptor)` again;
- require root device/inode/type and stable directory state unchanged;
- failure must be fail-closed.

## Deterministic traversal

Traversal order must exactly match the accepted `PXMainDataStaging` digest order:

- depth-first;
- pre-order;
- directory entry names sorted by exact raw byte order;
- no locale collation;
- no case folding;
- no Unicode normalization;
- no filesystem enumeration order authority.

Relative path construction must use exact raw component bytes joined by one `/` byte.

Every component must satisfy:

- nonempty;
- no NUL;
- no `/`;
- not `.`;
- not `..`;
- maximum 255 bytes;
- strict UTF-8 decode and byte-for-byte UTF-8 round trip;
- full relative path maximum 4096 bytes.

Maximum depth:

```text
2048
```

Entry count traversal bound:

```text
PXOptionalRestoreMaximumAggregateEntries = 500000
```

Do not allocate an unbounded recursive call stack. Use an iterative descriptor/frame stack.

## Accepted entry types

Allow only:

```text
regular file
directory
```

Reject:

```text
symlink
hard-linked regular file
FIFO
socket
character device
block device
unknown type
setuid entry
setgid entry
mount/device crossing
```

For every entry:

- inspect with `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
- require entry device equals root device;
- open directories with `openat(..., O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)`;
- open files with `openat(..., O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC)`;
- compare opened descriptor device/inode/type with the no-follow namespace stat.

## Forbidden root-level names

At depth 1, reject exact raw names:

```text
.com.apple.mobile_container_manager.metadata.plist
.com.apple.containermanagerd.metadata.plist
```

Reject any entry at any depth whose component begins with:

```text
.weaponx-optional-restore-
```

The verifier must not skip these names. Presence is a hard failure.

## Directory stability

For every opened directory:

- retain device/inode/type/mode and stable timestamps;
- enumerate exact sorted names;
- before closing/popping the frame, `fstat` again;
- require the directory remained the same stable object;
- require no mount/device crossing.

A directory replacement or mutation race must return failure.

## Regular-file stability and reading

For every regular file:

1. require `st_nlink == 1`;
2. require nonnegative size;
3. open no-follow and close-on-exec;
4. compare namespace stat and descriptor stat;
5. retain before-read stat;
6. emit the exact digest entry header;
7. stream file contents in bounded chunks;
8. retry reads only on `EINTR`;
9. update tree SHA-256 with every file-content byte;
10. count exact bytes with overflow-safe arithmetic;
11. require streamed bytes equal the retained file size;
12. `fstat` after read;
13. require stable device/inode/type/mode/link-count/size/mtime/ctime before and after;
14. close descriptor successfully.

A short read, growth, truncation, identity change or timestamp change must fail.

Do not load a complete file into `NSData`.

## Exact deterministic digest format

The verifier must reproduce the exact binary format used by TASK-2.8 and `PXMainDataStaging`.

Initialize SHA-256 with:

```c
static const unsigned char domainPrefix[] = "PXMainDataStageTreeV1";
CC_SHA256_Update(&context, domainPrefix, sizeof(domainPrefix));
```

`sizeof(domainPrefix)` intentionally includes the terminating NUL byte.

For every entry in deterministic traversal order, append:

```text
1 byte       entry type: ASCII 'D' or 'F'
4 bytes      relative path byte length, unsigned big-endian
N bytes      exact relative UTF-8 path bytes
4 bytes      mode & 07777, unsigned big-endian
8 bytes      size, unsigned big-endian
```

For directories:

```text
type = 'D'
size = 0
no content bytes
```

For regular files:

```text
type = 'F'
size = exact file size
append raw file contents immediately after the header
```

Do not include:

```text
absolute path
workspace path
inode
device
uid/gid
timestamps
ownership
filesystem enumeration order
```

The final digest must be exactly 64 lowercase hexadecimal characters.

## Exact snapshot comparison

After successful traversal, require exact equality with `expectedStage`:

```text
actual entryCount        == expectedStage.entryCount
actual regularFileCount  == expectedStage.regularFileCount
actual directoryCount    == expectedStage.directoryCount
actual regularFileBytes  == expectedStage.regularFileBytes
actual treeSHA256         == expectedStage.treeSHA256
```

All counters must be overflow-safe.

Do not accept only digest equality while ignoring counts/bytes.

Do not accept only top-level identity equality.

Mismatch must use:

```text
domain: PXOptionalRestoreTransactionErrorDomain
code: PXOptionalRestoreTransactionErrorReplacementMismatch
field path: $.replacement
```

Description must remain generic and must not expose actual/expected values.

## Error mapping

Use only existing public error codes.

Recommended exact categories:

```text
invalid function input
  -> InvalidInput

entry/path/depth/count overflow or fixed limit
  -> EntryLimitExceeded

fstat/fstatat/openat/read/enumeration failure
  -> FilesystemInspectionFailed

namespace-to-descriptor mismatch or before/after identity change
  -> FilesystemChanged

unsupported type, link, mount, reserved metadata/prefix
  -> ReplacementMismatch

final count/bytes/digest mismatch
  -> ReplacementMismatch
```

All errors:

- `PXOptionalRestoreTransactionErrorDomain`;
- generic description;
- field path under `$.replacement`;
- no nested error;
- no path, filename, digest, count, inode, device or errno text.

## Existing call-site behavior

Keep both call sites semantically unchanged:

1. `PXOptionalRestorePrepareDirectoryReplacement` must verify the prepared replacement after all staged top-level entries were moved into it and before prepared publication.
2. `PXOptionalRestoreWorkspaceHasNoRecoveryData` must verify a no-journal replacement directory against the current accepted stage before cleanup.

No call site may be removed, bypassed or converted to unconditional success.

Required count after correction:

```text
verifier calls:       2
verifier definitions: 1
```

## Preserve TASK-2.13

Do not change:

- public 3-kind/18-error API;
- item factories;
- transaction factory/commit surface;
- destination authority;
- authority-lock collapse;
- deterministic item/manager order;
- stage binding and same-filesystem proof;
- leader selection;
- journal schema and six phases;
- stale transaction set binding;
- no-journal policy except making the existing verifier real;
- quarantine/install/rollback state machine;
- initially-absent rollback;
- cleanup leader-last;
- manager integration;
- error mapping in `AppDataBackupManager.m`;
- Keychain exclusion;
- high-level Restore ordering.

Do not implement TASK-2.14.

## Source/link proof

The report must prove all of the following:

```text
PXOptionalRestoreVerifyDirectoryTree call sites = 2
file-local definition count = 1
repository-wide production definition count = 1
implicit declaration diagnostics = 0
undefined PXOptionalRestoreVerifyDirectoryTree symbol = 0
```

Run the strongest available build/link gate.

Preferred:

```text
GitHub Actions / Theos build and link
```

When a full build is unavailable locally:

- run a strict Objective-C syntax check with `-Werror=implicit-function-declaration` using temporary external stubs only;
- inspect the produced object or linked target when possible with `nm`/equivalent;
- show that `PXOptionalRestoreVerifyDirectoryTree` is not an undefined symbol;
- state honestly that target-device build/link remains pending if no real Theos artifact exists.

Do not place temporary stubs or scripts in the implementation commit.

## Static gates

Scope:

```text
PXOptionalRestoreTransaction.m modified
TASK-2.13A-REPORT.md added
all other production diffs = 0
```

API/non-regression:

```text
PXOptionalRestoreTransaction.h diff = 0
AppDataBackupManager.m diff = 0
3 item kinds retained
18 error codes retained
3 item factories retained
1 transaction factory retained
1 commit method retained
public readwrite properties = 0
```

Verifier:

```text
static verifier definitions = 1
verifier calls = 2
exact domain prefix including NUL = present
'D' and 'F' entry types = present
big-endian uint32 path/mode = present
big-endian uint64 size = present
strict UTF-8 round trip = present
root metadata rejection = present
optional transaction-prefix rejection = present
no-follow stat/open = present
hard-link rejection = present
same-device rejection = present
setuid/setgid rejection = present
iterative depth bound 2048 = present
path bound 4096 = present
component bound 255 = present
entry bound 500000 = present
exact five-field snapshot comparison = present
whole-file NSData read = 0
path-based recursive traversal = 0
shell/process use = 0
```

Checks:

```text
git show --check --oneline HEAD
git diff 08d23dd0a9fa41a39efd5b62680974f23e75fe45..HEAD --check
git diff --name-status 08d23dd0a9fa41a39efd5b62680974f23e75fe45..HEAD
git status --short --untracked-files=all
```

## Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.13A-REPORT.md
```

The report must include:

- baseline and exact scope;
- protected SHA-256 before/after;
- TASK-2.13 review blocker;
- before/after private-symbol inventory;
- exact verifier signature;
- descriptor ownership and cleanup;
- deterministic traversal order;
- strict UTF-8/path/depth limits;
- accepted/rejected type matrix;
- mount/link/setuid/setgid policy;
- root metadata and reserved-prefix rejection;
- directory stability proof;
- file streaming/stability proof;
- exact `PXMainDataStageTreeV1\0` digest layout;
- exact five-field snapshot comparison;
- no-journal call-site proof;
- replacement-preparation call-site proof;
- compile/link/undefined-symbol evidence;
- TASK-2.13 API, manager, journal, rollback and Keychain non-regression;
- complete authorized source diff;
- static gate table;
- at least 90 explicit scenarios;
- whitespace/CRLF/NUL audit;
- build status and remaining runtime risks.

Required scenario coverage includes:

- empty tree;
- one directory;
- one empty file;
- nested deterministic order;
- non-ASCII strict UTF-8;
- invalid UTF-8;
- NUL/slash/dot/dot-dot component;
- 255/256-byte component;
- 4096/4097-byte path;
- depth 2048/2049;
- 500000/500001 entries;
- symlink;
- hard link;
- FIFO/socket/device;
- mount crossing;
- setuid/setgid;
- forbidden metadata;
- reserved prefix;
- file growth/truncation/replacement;
- directory replacement during traversal;
- count mismatch;
- regular byte mismatch;
- digest mismatch;
- no-journal valid replacement;
- no-journal invalid replacement;
- replacement-preparation validation;
- strict compile with implicit declaration as error;
- no undefined verifier symbol.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Suggested commit

```text
phase2(task-2.13A): implement optional directory tree verifier
```

## Stop condition

Stop after TASK-2.13A source, report and implementation commit.

Do not modify coordinator documents.

Do not implement TASK-2.14 or any Phase 3 task.