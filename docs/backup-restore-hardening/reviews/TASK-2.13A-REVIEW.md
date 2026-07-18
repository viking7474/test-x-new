# TASK-2.13A Review

Implementation commit reviewed: `9d046a406a5a346cab2a66d3fc27c71d702b9321`

Baseline: `08d23dd0a9fa41a39efd5b62680974f23e75fe45`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-2.13 final status: **COMPLETED**

## Scope

The implementation commit contains exactly:

```text
M PXOptionalRestoreTransaction.m
A docs/backup-restore-hardening/reports/TASK-2.13A-REPORT.md
```

No other production file changed. In particular, `PXOptionalRestoreTransaction.h`, `AppDataBackupManager.m`, all accepted main/App Group/staging/plan/validator sources, `CommandRunner`, and `Makefile` are byte-identical to the TASK-2.13 baseline.

## Blocking symbol is closed

TASK-2.13 called `PXOptionalRestoreVerifyDirectoryTree(...)` from two security-critical sites without a production declaration or implementation. TASK-2.13A now provides exactly one prior file-local definition:

```objc
static BOOL PXOptionalRestoreVerifyDirectoryTree(
    int rootDescriptor,
    PXValidatedMainDataStage *expectedStage,
    NSError **error);
```

Independent repository inventory:

```text
semantic call sites:                     2
file-local static definitions:           1
repository production definitions:      1
total production occurrences:           3
external production definitions:        0
```

The retained call sites remain:

1. DirectoryObject replacement preparation.
2. No-journal replacement cleanup proof.

Neither site was removed, bypassed, or converted to unconditional success.

## Input and error contract

The verifier clears the caller error output and rejects invalid descriptors, invalid runtime stage objects, malformed lowercase SHA-256, inconsistent count partitions, count overflow, and an accepted entry count above the fixed 500,000 bound.

Invalid input uses the transaction error domain, `InvalidInput`, and the generic `$.replacement` field path without embedding a path, digest, inode, device, count, errno, or nested error.

## Descriptor ownership and traversal

The caller-owned root descriptor is never closed. Traversal begins from a duplicated descriptor with verified `FD_CLOEXEC`; every owned directory and file descriptor is closed on success and failure.

Traversal is descriptor-relative only:

- `fstatat(..., AT_SYMLINK_NOFOLLOW)` for namespace inspection;
- `openat(..., O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)` for directories;
- `openat(..., O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC)` for files;
- no absolute replacement path;
- no `NSFileManager`, shell, process launch, `realpath`, `nftw`, `fts`, or path-recursive cleanup.

The iterative frame stack is bounded by depth 2,048 and avoids recursive C/Objective-C call-stack traversal.

## Exact TASK-2.8 tree compatibility

The verifier matches the accepted `PXMainDataStaging` tree snapshot contract:

- strict lossless UTF-8 component round trip;
- component byte policy for NUL, controls, DEL, backslash, slash, dot, and dot-dot;
- raw-byte lexical name sorting;
- depth-first pre-order traversal;
- relative path bytes joined with one `/` byte;
- 255-byte component and 4,096-byte relative-path limits;
- regular-file/directory-only topology;
- no hard links, setid entries, symlinks, special files, or mount crossings;
- exact `mode & 07777` digest contribution;
- exact streamed file contents.

The domain prefix is:

```text
PXMainDataStageTreeV1
```

and is hashed with `sizeof(domainPrefix)`, preserving the terminating NUL exactly as TASK-2.8 does.

Each entry uses the same digest layout:

```text
1-byte type ('D' or 'F')
4-byte big-endian relative-path length
relative-path bytes
4-byte big-endian mode & 07777
8-byte big-endian size
regular-file content bytes when applicable
```

The final result must exact-match all five retained fields:

```text
entryCount
regularFileCount
directoryCount
regularFileBytes
treeSHA256
```

The verifier additionally rejects the optional transaction reserved prefix at every depth, as required by TASK-2.13A, and rejects both current-device container metadata filenames at the replacement root.

## Stability and fail-closed behavior

Every directory is identity-bound before enumeration and checked again after enumeration and before frame completion. Every regular file is no-follow opened, namespace/descriptor matched, streamed with `EINTR` retry, and checked for stable device, inode, mode/type, link count, size, modification time, and change time.

Enumeration, open, stat, read, or close failures do not produce success. Overflow, depth, path, and count failures are bounded and fail closed.

## TASK-2.13 non-regression

The corrective commit does not alter:

- the public three-kind/eighteen-error API;
- item or transaction factories;
- destination authority or lock collapse;
- stage and same-filesystem proof;
- journal schema and six phases;
- stale recovery binding;
- quarantine/install/rollback behavior;
- initially-absent restoration semantics;
- cleanup leader-last;
- manager integration;
- component order;
- Keychain exclusion from filesystem rollback.

TASK-2.13 optional transaction domains are therefore accepted as completed through this corrective commit.

## Build and report evidence

The report records a strict Objective-C frontend pass with implicit function declarations treated as errors. The Windows workspace did not provide Apple Clang/Theos object production or `llvm-nm`, so no independent local iOS link artifact exists. Owner continuation is accepted as the project build-status signal; no evidence contradicts it.

Report contract:

```text
explicit scenario rows: 157
git show --check: PASS
baseline-to-HEAD diff --check: PASS
new trailing whitespace: 0
new NUL bytes: 0
```

The report ends exactly with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Verdict

**ACCEPTED.** TASK-2.13A closes the missing production verifier/link boundary without widening production scope. TASK-2.13 and TASK-2.13A are completed, and TASK-2.14 may be specified from baseline `9d046a406a5a346cab2a66d3fc27c71d702b9321`.
