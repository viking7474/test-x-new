# TASK-2.6 Review — Archive-Entry Safety Validator

Implementation commit reviewed: `6dd6df3d435fefe03a4098342c7a4ee7b9afe58a`

Production source review: **CHANGES_REQUESTED**

Final status: **CHANGES_REQUESTED**

## Scope

The implementation commit contains exactly:

```text
M AppDataBackupManager.m
M Makefile
A PXBackupArchiveValidator.h
A PXBackupArchiveValidator.m
A docs/backup-restore-hardening/reports/TASK-2.6-REPORT.md
```

Protected production files are unchanged. `git show --check` and the cumulative baseline diff check pass.

## Accepted parts

The following parts match the intended TASK-2.6 boundary and do not need redesign:

- the exact public header with 16 error codes;
- immutable `PXValidatedBackupArchiveSet` summary maps;
- one application-only `-lz` linker addition;
- one Restore integration call after TASK-2.5 artifact verification;
- archive validation before warnings, debug, `CommandRunner`, tar discovery, process kill, staging, extraction and mutation;
- exact non-nil archive-validator error propagation;
- descriptor-relative archive opening with `openat` and `O_NOFOLLOW`;
- streaming zlib inflate and compressed-byte CommonCrypto SHA-256;
- compressed size, digest, descriptor identity and final path identity rechecks;
- two-zero-block tar termination and rejection of nonzero decompressed bytes after the terminator;
- regular-file/directory-only real member policy;
- absolute/traversal/backslash/control/oversized path rejection;
- duplicate and file-parent topology checks;
- fixed archive/member/path/metadata/inflation limits;
- PAX `path`, `size` and `linkpath` parsing;
- bounded GNU `L` and `K` parsing;
- extraction helper bodies remaining byte-identical;
- TASK-2.1 through TASK-2.5 accepted manager body hashes remaining unchanged.

The report contains 230 static scenarios and honestly states that no local Objective-C/Theos, target-device or archive-fixture runtime pass was performed.

## Blocking finding 1 — optional `systemGlobalLibrary` became required

The accepted schema validator treats `systemGlobalLibrary` as optional:

```objc
id systemGlobalLibrary = manifest[@"systemGlobalLibrary"];
if (systemGlobalLibrary &&
    !PXManifestValidateSystemGlobalLibrary(systemGlobalLibrary, error)) {
    return NO;
}
```

TASK-2.5 follows the same compatibility policy and only consumes that section when present.

TASK-2.6 instead requires the section unconditionally:

```objc
id systemObject = manifest[@"systemGlobalLibrary"];
if (![systemObject isKindOfClass:[NSDictionary class]]) {
    return ...;
}
```

A structurally accepted version-2 or version-3 manifest without this additive section therefore passes the common manifest and artifact boundaries, then fails archive validation. This narrows accepted manifest compatibility outside the task contract.

Required correction:

- absent section: skip it;
- present section: validate its existing dictionary/Boolean/items shape;
- present with `included == NO`: collect no references;
- present with `included == YES`: collect item archives in array order.

## Blocking finding 2 — well-formed unknown PAX metadata is rejected

The task specification requires:

```text
unknown well-formed metadata keys, including bounded xattr/ACL keys, may be ignored
unknown safe PAX key ignored
```

The implementation uses a private allow-list and rejects every other non-reserved key:

```objc
if (!reserved && !PXArchivePAXKeyIsInert(key)) {
    return ... InvalidExtendedHeader;
}
```

The report also changes the required scenario to rejection. That is a direct implementation/report contradiction with the frozen task specification and can reject valid producer metadata that has no path, size, link or sparse semantics.

Required correction:

- continue handling `path`, `size` and `linkpath` exactly;
- continue rejecting every `GNU.sparse` prefix;
- ignore any other syntactically valid, bounded non-reserved key/value record without retaining its value;
- continue rejecting malformed length, key, separator, NUL and UTF-8-sensitive reserved values.

## Blocking finding 3 — implicit topology state is not bounded

The parser retains every unique implicit parent path:

```objc
NSMutableSet<NSString *> *_implicitDirectories;
...
[_implicitDirectories addObject:parent];
```

The logical real-member limit does not bound this set. One long member path can create many retained parent strings, and many distinct deep paths can make topology memory grow far beyond the 200,000-member boundary. This violates the specification's bounded parser-state requirement.

Required correction:

- use the existing private `PXArchiveMaximumLogicalMembers` value as the maximum number of unique implicit-directory identities;
- compute which parent identities are new before mutating the set;
- overflow/count-check before adding any of them;
- fail with `PXBackupArchiveValidatorErrorLimitExceeded` at the real member `.path` field;
- leave topology state unchanged on that failure;
- add no public or configurable limit.

## Blocking finding 4 — GNU and POSIX tar headers are not classified separately

The format helper currently returns one `ustar` Boolean for both:

```text
POSIX: magic `ustar\0`, version `00`
GNU:   magic `ustar `, version ` \0`
```

It does not validate the exact version pair. `headerPathFromBlock:ustar:` then treats bytes 345–499 as the POSIX prefix for both formats. In the old GNU header layout that region is extension state, not the POSIX prefix field.

Independent fixture inspection confirmed GNU tar 1.35 emits `ustar ` plus ` \0`, while POSIX ustar emits `ustar\0` plus `00`.

Required correction:

- classify exact legacy, POSIX ustar and GNU header spellings with a private enum/state;
- reject malformed nonempty magic/version combinations;
- compose `prefix/name` only for POSIX ustar;
- use the ordinary header name, or pending GNU `L`, for GNU format;
- keep accepted legacy empty-magic behavior unchanged.

## Blocking finding 5 — duplicated traversal descriptor loses close-on-exec

`PXArchiveOpenRelativeFile` starts traversal with:

```objc
int currentDescriptor = dup(rootDescriptor);
```

A descriptor produced by `dup` does not retain `FD_CLOEXEC`. The task requires traversal descriptors to remain close-on-exec.

Required correction:

- duplicate the root descriptor using a close-on-exec-capable operation, or immediately set and verify `FD_CLOEXEC` with `fcntl`;
- fail closed if the close-on-exec duplication/setup fails;
- preserve all existing descriptor cleanup paths.

## Non-regression evidence

Independent body-hash comparison confirms no change to:

- `PXBackupManifestVersionIsSupported`;
- `PXResolveExactRestoreApplicationDataTarget`;
- `readManifestAtBackupDirectory:error:`;
- `createBackupForBundleID:appName:options:completion:`;
- `_tarExtract:archive:toDir:`;
- `_tarExtractDataArchive:archive:toDir:warnings:`.

Static evidence also confirms:

```text
archive validator public error codes: 16
archive validator Restore calls: 1
application -lz occurrences: 1
other-target -lz additions: 0
CommandRunner/shell/tar listing in validator: 0
filesystem mutation in validator: 0
whole-file archive loading: 0
new validator trailing whitespace: 0
new validator NUL bytes: 0
report scenarios: 230
```

`AppDataBackupManager.m` and `Makefile` retain pre-existing trailing-whitespace lines, but the implementation commit and cumulative diff checks are clean.

## Build gate

Project-owner continuation may confirm that the owner build succeeded, but build success cannot override the source-contract blockers above. No GitHub Actions artifact, target-device log or generated malicious/compatibility archive fixture is stored in this workspace.

## Required follow-up

TASK-2.7 remains locked.

Open corrective TASK-2.6A with production scope limited to `PXBackupArchiveValidator.m`. The corrective task must restore optional-section compatibility, the frozen PAX policy, bounded implicit topology state, exact GNU/POSIX header classification and close-on-exec descriptor duplication without changing the accepted public API, manager integration, Makefile or extraction behavior.
