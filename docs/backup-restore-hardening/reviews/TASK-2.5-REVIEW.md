# TASK-2.5 Review — Common Backup Artifact Verifier

Implementation commit reviewed: `2a00a93e2127872845cc4e673c8929236d098c13`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXBackupArtifactVerifier.h
A PXBackupArtifactVerifier.m
A docs/backup-restore-hardening/reports/TASK-2.5-REPORT.md
```

Protected production files are unchanged. `Makefile` remains unchanged and its existing root-level `*.m` wildcard includes the new implementation.

## Accepted public contract

`PXBackupArtifactVerifier.h` provides:

- one fixed error domain;
- one fixed field-path key;
- exactly 13 error codes;
- immutable `PXVerifiedBackupArtifactSet`;
- sorted `artifactNames`;
- immutable exact-name to canonical-path mapping;
- `pathForArtifactName:` lookup;
- one verifier entry point.

Both public classes prohibit ordinary initialization. The verified set copies its input mapping and `copyWithZone:` returns `self`.

## Artifact identity and references

The verifier uses `artifact.name` as the only source identity. It contains zero reads of `artifact.path`.

Accepted relative-name policy rejects:

- absolute names;
- leading or trailing slash;
- doubled slash;
- empty components;
- `.` and `..` components;
- NUL;
- empty or whitespace-only names.

Required references are collected in the specified deterministic order from:

1. main data;
2. App Groups;
3. included preferences;
4. included Keychain;
5. included profile app data;
6. included global Safari;
7. included system-global archives;
8. included shared-system DB files.

Every required reference must exact-match one declaration. Duplicate cross-component references fail at the later reference. Unreferenced declarations remain permitted but are still fully verified.

## Filesystem and content verification

The verifier:

- rejects a symlink final backup-directory component;
- canonicalizes the selected backup root;
- compares raw-opened and canonical-opened directory identities;
- walks artifact parent components with descriptor-relative `openat`;
- uses `O_DIRECTORY`, `O_NOFOLLOW` and `O_CLOEXEC`;
- opens final artifacts with `O_NOFOLLOW` and `O_NONBLOCK`;
- requires a regular file through `fstat`;
- compares exact size, including declared zero;
- requires complete lowercase 64-character SHA-256;
- hashes through streaming CommonCrypto reads;
- retries `EINTR`;
- compares device, inode, file type, size, mtime and ctime before/after hashing;
- closes all owned descriptors on success and failure paths.

Errors contain only `NSLocalizedDescriptionKey` and the stable verifier field-path key. Raw artifact names, recorded paths, backup root, canonical paths, hashes, sizes, bundle IDs and errno text are not inserted into errors.

## Aggregate checks

When present:

- `totalSize` must equal both the overflow-checked declared-size sum and actual verified-size sum;
- `archiveChecksum` must be complete lowercase SHA-256 and equal both the declared and actual digest for the artifact referenced by `data.archive`.

Version-2 manifests without optional aggregate fields remain accepted when their declarations and files are otherwise complete.

## Restore integration

Restore calls the verifier exactly once after:

1. common manifest read/schema/version acceptance;
2. exact requested bundle-ID match;
3. exact canonical destination preflight.

Artifact verification precedes warnings allocation, Restore `NSFileManager`/`CommandRunner` setup, debug writes, tar discovery, process kill, extraction and target mutation. Exact non-nil verifier errors are propagated on the main queue; a generic verifier-domain fallback exists only for the impossible nil-without-error state.

All Restore source artifacts now come from `PXVerifiedBackupArtifactSet`:

- main data;
- profile app data;
- global Safari;
- App Groups;
- system-global library archives;
- shared-system DB files;
- preferences;
- Keychain.

Restore no longer constructs operational artifact sources through `backupDir + archive`, hard-coded `data.tar.gz`, sanitized group filenames or recorded absolute artifact paths.

The App Group manifest mapping is resolved before the group destination is inspected or wiped. An installed/resolved group without a manifest archive mapping is warned and skipped without mutation.

## Removed legacy Restore checks

The following Restore-only behavior is gone:

- best-effort `PXVerifyArtifact` warning loop;
- `artByName` reconstruction;
- manual main-data existence check;
- manual main-data size check;
- manual main-data SHA-256 check;
- manager artifact-preflight codes 305, 314 and 315.

Backup's warning-only `PXVerifyArtifact` self-check remains unchanged.

## Non-regression

Independent body-hash comparison confirms no change to:

- `PXBackupManifestVersionIsSupported`;
- `PXResolveExactRestoreApplicationDataTarget`;
- `readManifestAtBackupDirectory:error:`;
- `createBackupForBundleID:appName:options:completion:`.

The exact supported version set `{2,3}`, validator propagation, requested-target code 304, destination code 303, retained destination model, canonical pre-mutation revalidation and Backup manifest version 3 remain intact.

TASK-2.5 intentionally does not inspect tar members, parse archive links, validate extraction topology, build a restore plan, redesign staging or implement transaction/rollback.

## Independent gates

```text
git show --check: PASS
cumulative diff --check: PASS
protected production diff: PASS
artifact verifier error codes: 13
verifier public entry points: 1
artifact.path authority reads: 0
openat calls: 2
O_NOFOLLOW uses: 4
fstat calls: 4
Restore verifier calls: 1
Restore PXVerifyArtifact calls: 0
Restore artByName references: 0
Restore manager codes 305/314/315: 0
Restore verified-path lookups: 8
report scenarios: 141
new-file trailing whitespace: 0
new-file NUL bytes: 0
```

`AppDataBackupManager.m` still contains 18 pre-existing trailing-whitespace lines, but the implementation commit and cumulative baseline checks are clean.

## Build gate

The project-owner continuation is accepted as confirmation that the owner build gate passed. No GitHub Actions artifact or target-device log is stored in this workspace, so compilation and race-fixture behavior were not independently reproduced here.

## Remaining boundary

A verified compressed file can still contain unsafe archive members. TASK-2.6 must inspect the `tar.gz` member stream before any extraction and reject unsafe paths, links, special file types, duplicate topology and bounded-resource violations. It must not redesign staging or transaction behavior.
