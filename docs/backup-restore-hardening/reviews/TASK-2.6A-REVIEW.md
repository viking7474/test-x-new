# TASK-2.6A Review — Archive Validator Compatibility and Bounds

Implementation commit reviewed: `2bb8473bd16ac097ae03d0e83e42b28987af1495`

Production source review: **ACCEPTED**

Final status: **COMPLETED**

TASK-2.6 final status after corrective review: **COMPLETED**

## Scope

The corrective implementation commit contains exactly:

```text
M PXBackupArchiveValidator.m
A docs/backup-restore-hardening/reports/TASK-2.6A-REPORT.md
```

`PXBackupArchiveValidator.h`, `AppDataBackupManager.m`, `Makefile`, the TASK-2.5 artifact verifier, manifest validator, container resolver/validator, extraction helpers, UI and all other production files are unchanged.

## Corrective finding closure

### 1. Optional `systemGlobalLibrary`

The archive-reference collector now skips `systemGlobalLibrary` when the key is absent. When present, the existing dictionary, exact Boolean, items-array and item-reference validation remains fail-closed.

Accepted outcomes:

```text
absent                                  -> accepted; zero system-global references
present non-dictionary                  -> InvalidInput at $.systemGlobalLibrary
invalid included                        -> InvalidInput at $.systemGlobalLibrary.included
invalid items                           -> InvalidInput at $.systemGlobalLibrary.items
included == NO                          -> zero item references
included == YES                         -> items collected in array order
```

This restores compatibility with the common manifest validator and TASK-2.5, both of which treat the section as optional additive schema.

### 2. Unknown well-formed PAX metadata

The private semantic allow-list and its unknown-key rejection branch were removed.

The parser still:

- rejects malformed record framing, invalid keys and NUL;
- rejects all `GNU.sparse*` keys;
- handles `path`, `size` and `linkpath` with their existing reserved semantics;
- rejects global identity/size/link overrides;
- rejects duplicate pending reserved overrides.

Every other structurally valid non-reserved record is consumed and ignored without decoding or retaining its value and without granting path, size, type, mode or limit authority.

### 3. Bounded implicit topology

Before adding derived parent paths, the parser now:

1. derives parent identities shallow-to-deep;
2. checks existing regular-file parent conflicts;
3. collects only new implicit parents;
4. performs overflow-safe count preflight;
5. requires `existing + new <= 200000`;
6. adds parents only after the full check succeeds.

The `200000` boundary is accepted and the `200001`st unique implicit directory fails with `LimitExceeded` at the current member `.path`. A failed check leaves topology state unchanged.

### 4. Exact tar format classification

The broad ustar Boolean was replaced with private fixed classification:

```text
Legacy       magic = six NUL bytes
POSIX ustar  magic = "ustar\0", version = "00"
GNU          magic = "ustar ",  version = space + NUL
```

Every other nonempty magic/version spelling is rejected.

Only POSIX ustar reads bytes `345..499` as the prefix field. GNU and legacy headers use the ordinary 100-byte name unless a valid PAX/GNU-long-name override is pending.

### 5. Close-on-exec traversal descriptor

The duplicate root descriptor is now immediately secured with `F_GETFD` / `F_SETFD(... | FD_CLOEXEC)` and then verified with a second `F_GETFD` before the first `openat`.

Every duplicate, flag-read, flag-write or verification failure closes the descriptor and returns the stable `OpenFailed` error. Child and final descriptors continue using `O_CLOEXEC`.

## Preserved TASK-2.6 contract

The corrective diff does not alter:

- public header or exact 16-code enum;
- immutable archive result API;
- archive-reference deterministic name ordering;
- backup-root canonicalization;
- descriptor-relative `openat` / `O_NOFOLLOW` traversal;
- compressed regular-file requirement;
- exact compressed size and lowercase SHA-256 checks;
- gzip-only zlib streaming;
- one-member/no-trailing-data policy;
- before/after compressed-file identity checks;
- tar checksum, numeric and two-zero-block termination policy;
- PAX reserved override semantics;
- GNU `L` / `K` support;
- regular-file/directory-only real member policy;
- member path normalization and duplicate/file-parent topology rules;
- fixed decompression/member/metadata limits;
- pure no-shell/no-mutation validator boundary;
- Restore integration and exact archive-validator NSError propagation;
- extraction helper bodies;
- application-only `-lz` linkage.

## Independent gates

```text
git show --check: PASS
cumulative diff --check: PASS
corrective production scope: PASS
protected production diff: PASS
optional systemGlobalLibrary guard: 1
old unconditional required section: 0
PAX semantic allow-list helper: 0
unknown-PAX rejection text: 0
GNU.sparse rejection: retained
implicit-parent preflight arrays: present
implicit-parent fixed limit: 200000
partial parent insertion before limit check: 0
private tar formats: Legacy/POSIX/GNU
POSIX exact magic/version checks: 1
GNU exact magic/version checks: 1
POSIX-only prefix-field reads: 1
FD_CLOEXEC set and verify: present
pure-boundary forbidden tokens: 0
report scenarios: 101
new trailing whitespace: 0
new NUL bytes: 0
```

## Build gate

Project-owner continuation is accepted as confirmation that the owner build gate passed. The workspace does not contain a GitHub Actions artifact, target-device log or generated archive-fixture run, so Darwin `fcntl`, maximum-bound allocation and producer-fixture behavior were not independently reproduced by the coordinator.

## Final decision

TASK-2.6A is accepted. Its five corrective findings are closed, therefore TASK-2.6 is also completed and TASK-2.7 may be unlocked.

TASK-2.7 must build an immutable semantic Restore plan from the already accepted manifest, destination, artifact and archive snapshots. It must not redesign staging, extract content, commit targets or implement rollback.
