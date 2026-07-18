# TASK-3.3 Review — Common Verified Backup Artifact Writer

Implementation commit reviewed: `849b2825c0cffc60db33f11ac769f35aae6c78e3`

Baseline: `dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-3.4 may open: **YES**

## Scope

```text
M AppDataBackupManager.m
A PXBackupArtifactWriter.h
A PXBackupArtifactWriter.m
A docs/backup-restore-hardening/reports/TASK-3.3-REPORT.md
```

No production file outside the authorized scope changed.

## Build status

Owner continuation is accepted as build confirmation. The report records strict Objective-C frontend and analyzer passes. This workspace has no linked Theos/iOS artifact or target-device fault-injection fixture; GitHub Actions remains pending.

## Public API

```text
error codes:                     16
producer block typedefs:          1
verified artifact classes:        1
writer classes:                   1
writer factories:                 1
artifact methods:                 1
identity validation methods:      1
public readwrite properties:      0
public descriptor properties:     0
```

Exact temporary protocol:

```text
prefix:   .weaponx-artifact-partial-
template: .weaponx-artifact-partial-XXXXXX
payload:  payload
```

## Verified artifact record

`PXVerifiedBackupArtifact` is immutable, subclassing-restricted and `NSCopying`.

Its manifest representation contains exactly:

```text
name   = relativePath
path   = filePath
size   = exact unsigned size
sha256 = 64 lowercase SHA-256
```

`copyWithZone:` returns self. Equality/hash use relative path, final path, size and digest.

The record is created only after producer success, stable streaming verification, strict durability, descriptor-relative rename, final namespace proof, temporary cleanup and final writer validation.

## Writer safety

The writer binds the accepted TASK-3.1 workspace with no-follow/CLOEXEC descriptors and retained device/inode/type identity. It validates the workspace before and after binding and retains the workspace object throughout its lifetime.

Relative path limits:

```text
artifacts:       4096
path bytes:      4096
component bytes:  255
depth:             32
file size:       64 GiB
buffer:          64 KiB
```

It rejects unsafe components, reserved names, exact duplicates, ancestor/descendant conflicts and Unicode-normalized aliases.

Parent traversal is descriptor-relative with `fstatat`, `mkdirat` and `openat`; newly created parents are `0700`, no-follow, same-device and CLOEXEC.

Each artifact attempt uses exactly one `mkdtemp`. The producer receives only `<temp>/payload` and is called exactly once synchronously.

Payload acceptance requires:

```text
regular file
st_nlink == 1
no setuid/setgid
same filesystem
mode 0600
size <= 64 GiB
stable dev/inode/type/mode/nlink/size/mtime/ctime
complete 64 KiB streaming SHA-256 read
strict fsync success
```

Finalization uses exactly one:

```text
renameat(tempFD, "payload", parentFD, finalName)
```

The final name must be absent. Final identity, parent durability, temporary removal, second parent sync and final writer identity are proven before record acceptance.

Failure cleanup removes only exact retained identities and preserves substituted or unexpected evidence. It never recursively deletes the TASK-3.1 workspace.

## Manager migration

```text
writer factory calls:         1
writer validations:           3
semantic writer sites:        8
legacy SHA/info helpers:       0
post-hoc verification loop:   0
```

The eight migrated producer sites are:

```text
data
App Groups
profile AppData
global Safari
Preferences
Keychain
system-global
shared DB
```

No producer receives a final artifact path. Preferences/shared-DB copy commands require zero exit and no longer contain `|| true`.

Manifest mappings are appended only after verified-record success.

Verified record order is:

```text
data
App Groups
profile AppData
global Safari
system-global
shared DB
Preferences
Keychain
```

`artifacts`, `artifactCount`, overflow-safe `totalSize`, `archiveChecksum` and component archive names derive only from verified records.

## Preserved boundary

TASK-3.3 intentionally leaves Preferences inclusion option-based. TASK-3.4 must derive Preferences inclusion and `GlobalPreferences` included/excluded option reporting from the verified Preferences record while keeping manifest v3 valid.

TASK-3.5 still owns formal required/optional policy. TASK-3.6 through TASK-3.10 remain locked.

## Independent gates

```text
git show --check:                    PASS
baseline diff --check:               PASS
protected production diff:           0
TASK-3.1 source diff:                 0
TASK-3.2 source diff:                 0
mkdtemp sites:                        1
renameat sites:                       1
whole-file reads:                     0
writer shell/process calls:           0
unsupported-sync success branches:    0
semantic writer sites:                8
legacy helper tokens:                 0
final Backup publication:             0
Restore body:                 unchanged
discovery body:               unchanged
timestamp body:               unchanged
report scenarios:                    340
new trailing whitespace:              0
new NUL bytes:                        0
```

## Decision

TASK-3.3 is accepted and complete.

TASK-3.4 baseline:

```text
849b2825c0cffc60db33f11ac769f35aae6c78e3
```
