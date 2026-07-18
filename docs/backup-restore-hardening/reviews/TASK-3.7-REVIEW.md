# TASK-3.7 Review

Implementation commit reviewed: `bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-3.8 may open: **YES**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
A PXBackupManifestWriter.h
A PXBackupManifestWriter.m
A docs/backup-restore-hardening/reports/TASK-3.7-REPORT.md
```

No protected production file changed.

## Public contract

`PXBackupManifestWriter.h` exports exactly four constants, sixteen error codes and one subclassing-restricted writer class. The class has six readonly properties, one factory, one write method and one identity-validation method. It exposes no descriptor, cleanup, rename, overwrite or durability-bypass API.

## Workspace authority

The factory requires the exact TASK-3.1 workspace class, validates it twice, opens the workspace no-follow/CLOEXEC, proves path/fd device-inode-type identity and exact mode `0700`, requires `manifest.plist` absent, rejects existing `.weaponx-manifest-partial-*` children and retains its own workspace descriptor.

## Temporary manifest protocol

The writer creates one temporary direct child named:

```text
.weaponx-manifest-partial-<32 lowercase hexadecimal characters>
```

The suffix comes from sixteen random bytes. Creation uses descriptor-relative `openat` with `O_RDWR|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`, mode `0600`, at most sixteen collision retries and no path-based fallback.

The temporary file must be regular, single-link, same-filesystem, size zero, exact mode `0600`, namespace/fd identical and CLOEXEC.

## Serialization, write and durability

Only the immutable TASK-3.6 v4 representation is serialized, using `NSPropertyListBinaryFormat_v1_0`. The serialized payload must be nonempty and no larger than 128 MiB.

The write loop is bounded, retries only `EINTR`, rejects zero progress and requires the exact byte count. File and workspace `fsync` are strict; unsupported or failed synchronization is not treated as success.

## Pre-rename proof

Before publication, the retained temporary descriptor is sought to zero and read exactly with a 64-KiB buffer. The reader rejects early EOF and extra bytes, computes lowercase SHA-256 and proves device/inode/type/mode/link-count/size/mtime/ctime stability.

The temporary payload is parsed immutably, passed through `PXBackupManifestValidator`, deep-equaled with the immutable v4 representation and checked against the snapshot backup ID, artifact count, total size and ApplicationData checksum.

## Atomic file publication

Immediately before finalization, workspace identity, temporary binding and final-name absence are reproved. Exactly one descriptor-relative `renameat` changes the owned temporary inode into `manifest.plist` inside the private partial workspace.

After rename, the writer proves exact final namespace identity, strict-syncs the manifest and workspace, independently opens the final file with `O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC`, and retains that final descriptor.

## Post-rename proof

The independently opened final descriptor is reread, rehashed, reparsed and independently validated. Its digest must equal the pre-rename digest and its parsed graph must deep-equal the accepted v4 snapshot with exact aggregate properties.

Only after all proofs does the writer set:

```text
manifestWritten
manifestSize
manifestSHA256
manifestRepresentation
manifestPath
```

## Retained identity and cleanup

Successful writers retain the exact final manifest descriptor. `validateIdentityWithError:` reproves the workspace/final namespace binding, no-follow regular-file contract, exact size and digest, parsed validator result and retained representation equality.

Pre-rename failure removes only the exact retained temporary inode. Post-rename failure removes only the exact retained final inode. Cleanup is descriptor-relative, bounded and strict-syncs the workspace. Identity ambiguity preserves evidence and reports `CleanupFailed`; there is no recursive workspace deletion.

## Manager integration

The manager creates the manifest writer once after the TASK-3.3 artifact writer and before policy construction/output side effects. It validates the writer three times, writes exactly once and keeps it alive with precise lifetime through result construction.

Manifest failure is now a hard Backup failure returning nil result plus the exact writer error on the main queue.

Removed authorities:

```text
[manifest writeToFile:manifestPath atomically:YES]
Failed to write manifest
shell chmod 600 manifest.plist
```

`PXBackupResult.manifestPath` now comes from `manifestWriter.manifestPath`.

## Non-regression

Preserved counts:

```text
bundle-lock factory:             1
bundle-lock validations:         4
workspace factory:               1
workspace validations:           3
artifact-writer factory:         1
artifact-writer validations:     3
artifact policy constructions:   8
artifact writer call sites:      8
failure-policy calls:            8
policy audit calls:              1
v4 builder calls:                1
manager pre-write validator:     1
whole-directory publication:     0
```

TASK-3.1 through TASK-3.6A source, Restore, discovery, UI, Makefile, CommandRunner and Keychain helper/bridge sources are unchanged.

## Independent gates

```text
git show --check:                    PASS
baseline-to-HEAD diff --check:       PASS
public exports:                       4
error codes:                         16
manifest-writer factory calls:        1
manager writer validations:           3
manager write calls:                  1
writer validator calls:               3
snapshot-match call sites:            3
temporary openat sites:                1
manifest renameat sites:               1
legacy manager manifest writes:        0
legacy write-failure warnings:         0
manifest shell chmod sites:            0
whole-file/path writer APIs:           0
writer process/shell APIs:             0
report scenario rows:                372
new trailing whitespace:               0
new NUL bytes:                         0
```

The report records strict Objective-C frontend/analyzer success. Full Theos/iOS linking, target-filesystem durability and target-device fault replay remain pending; owner continuation is accepted as the build-status signal and no source evidence contradicts it.

## Verdict

TASK-3.7 is **COMPLETED**. TASK-3.8 may proceed.
