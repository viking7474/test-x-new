# TASK-2.6A Report — Archive Validator Compatibility and Bounds

## 1. Baseline and exact scope

- Required baseline and observed pre-commit HEAD: `6dd6df3d435fefe03a4098342c7a4ee7b9afe58a`.
- TASK-2.6 owner build was reported successful, but source review was `CHANGES_REQUESTED`.
- Corrective production scope is exactly `PXBackupArchiveValidator.m`.
- The only additional artifact is `docs/backup-restore-hardening/reports/TASK-2.6A-REPORT.md`.
- Implementation commit must contain exactly the validator implementation and this report.
- TASK-2.7 remains locked and was not implemented.

Baseline commands:

```text
$ git status --short --untracked-files=all
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.6-add-archive-entry-safety-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.6A-fix-archive-validator-compatibility-and-bounds.md
$ git rev-parse HEAD
6dd6df3d435fefe03a4098342c7a4ee7b9afe58a
$ git log -3 --oneline
6dd6df3 phase2(task-2.6): add archive entry safety validator
2a00a93 phase2(task-2.5): add common artifact verifier
c1d9067 phase2(task-2.4): remove recorded destination fallbacks
```

## 2. Five TASK-2.6 review blockers and corrections

| # | Review blocker | TASK-2.6A correction |
|---:|---|---|
| 1 | `systemGlobalLibrary` was unconditionally required. | Absent key is accepted; present value keeps exact dictionary/Boolean/items validation and conditional item collection. |
| 2 | Unknown well-formed non-reserved PAX metadata was rejected by a private allow-list. | Allow-list and rejection branch were removed; only reserved keys are retained, while other structurally valid records are consumed and ignored. |
| 3 | `_implicitDirectories` could grow independently without a fixed identity bound. | New unique parents are collected first, overflow/count checked against the existing 200,000 logical-member constant, then added atomically. |
| 4 | Legacy/POSIX/GNU tar headers shared a broad Boolean and GNU bytes 345–499 were treated as POSIX prefix. | Added exact private Legacy/POSIXUstar/GNU classification; only POSIX reads prefix offset 345. |
| 5 | Raw `dup` cleared close-on-exec on the root traversal descriptor. | `F_GETFD`/`F_SETFD`/`F_GETFD` sets and verifies `FD_CLOEXEC` before first `openat`, with close-and-fail paths. |

## 3. Optional system-global compatibility matrix

| Manifest state | Result | Error field / collection |
|---|---|---|
| Key absent | Valid | No system-global references |
| Present `NSNull` or non-dictionary | InvalidInput | `$.systemGlobalLibrary` |
| Present dictionary with missing/invalid `included` | InvalidInput | `$.systemGlobalLibrary.included` |
| Present dictionary with missing/invalid `items` | InvalidInput | `$.systemGlobalLibrary.items` |
| `included == NO` | Valid | Validate items shape; collect none |
| `included == YES` | Valid if entries resolve | Collect `items[i].archive` in array order |

The main-data, App Group, profile-app-data and global-Safari collector prefix is byte-identical to TASK-2.6. The deterministic exact archive-name sort suffix is also byte-identical.

## 4. Frozen unknown-PAX policy proof

- Reserved `path`, `size`, and `linkpath` handling remains exact.
- Every `GNU.sparse` prefix still fails as `UnsupportedEntryType`.
- Strict length, record boundary, newline, equals, printable-key and record-wide NUL checks are unchanged.
- The private `PXArchivePAXKeyIsInert` helper and semantic rejection text are absent.
- `valueData` is materialized only inside the non-global reserved branch.
- Unknown values are not decoded, retained, logged, or allowed to modify path, size, mode, type or limits.
- Unknown records still consume declared bytes and remain covered by metadata and inflated-byte budgets.

## 5. Implicit topology bound and atomic update

Parent prefixes are derived shallow-to-deep into a local candidate list. Existing regular-parent conflict and full-path implicit-directory/file conflict checks run before mutation. Only parents not already in `_implicitDirectories` enter `newParents`.

```text
newParentCount <= NSUIntegerMax - implicitCount
implicitCount + newParentCount <= PXArchiveMaximumLogicalMembers (200000)
```

Failure uses `PXBackupArchiveValidatorErrorLimitExceeded` at the current real member `.path`. The only parent add occurs after both checks, and real-member registration follows that add. Therefore limit failure retains no partial parent state and registers no real member.

| Boundary | Result |
|---|---|
| 0 + 0 | Accept |
| 199999 + 1 | Accept at 200000 |
| 200000 + 0 repeated known parents | Accept |
| 200000 + 1 | Reject |
| 0 + 200001 | Reject |
| `NSUInteger` addition overflow | Reject |

## 6. Exact tar format matrix

| Format | Magic bytes | Version bytes | Prefix 345–499 authority | Result |
|---|---|---|---|---|
| Legacy | six NUL bytes | Not used for classification | None | Accept |
| POSIX ustar | `ustar\0` | `00` | Prefix + `/` + name when nonempty | Accept |
| GNU | `ustar ` | space + NUL | None | Accept |
| POSIX spelling, wrong version | `ustar\0` | not `00` | None | Reject |
| GNU spelling, wrong version | `ustar ` | not space+NUL | None | Reject |
| Other nonempty/mixed magic | Other | Any | None | Reject |

Effective path precedence remains `PAX path`, then GNU `L`, then the format-specific header path. `block + 345` occurs exactly once and is inside the POSIX-only branch; GNU and Legacy use only the ordinary 100-byte name.

## 7. CLOEXEC setup and cleanup

```text
dup(rootDescriptor)
F_GETFD
F_SETFD(existingFlags | FD_CLOEXEC)
F_GETFD verification
first parent openat
```

Any duplicate, flag-read, flag-set, or verification failure returns `OpenFailed`. Every failure after ownership closes the duplicate. Existing child directory and final archive `O_CLOEXEC | O_NOFOLLOW` flags remain unchanged.

## 8. Accepted TASK-2.6 non-regression

- Backup-root canonicalization and raw/canonical identity checks remain byte-identical.
- Verified canonical path equality remains byte-identical.
- Gzip-only zlib streaming, one-member/trailing rejection, EINTR retry and `inflateEnd` behavior remain byte-identical.
- Same-descriptor CommonCrypto SHA-256, compressed size and descriptor/path identity rechecks remain byte-identical.
- 512-byte tar streaming, strict octal/base-256 parsing and signed/unsigned checksums remain unchanged.
- Two-zero-block termination, nonzero-after-end and incomplete region rejection remain unchanged.
- Metadata limits, path policy, member-type policy, setuid/setgid rejection and fixed inflation/member limits remain unchanged.
- Immutable sorted result and two-key non-sensitive NSError policy remain unchanged.

Byte-identical helper bodies include `PXArchiveOpenCanonicalBackupRoot`, `PXArchiveInflateChunk`, `PXArchiveReadRetry`, `PXArchiveValidateOne`, `PXArchiveParseOctal`, `PXArchiveParseSizeField`, `PXArchiveHeaderChecksumIsValid`, `PXArchiveNormalizeMemberPath`, `PXArchiveBuildDeclarations`, and `PXArchiveAddReference`.

## 9. Protected manager/header/Makefile and extraction hashes

- `PXBackupArchiveValidator.h` diff: 0; public enum remains exactly 16 and public selector remains exactly one.
- `AppDataBackupManager.m` diff: 0; Restore call remains exactly one, ordered before warnings/debug/runner/tar/kill, with exact NSError propagation.
- `Makefile` diff: 0; application `-lz` remains exactly one.

| Protected body | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `PXBackupManifestVersionIsSupported` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | Byte-identical |
| `PXResolveExactRestoreApplicationDataTarget` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | Byte-identical |
| `readManifestAtBackupDirectory:error:` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | Byte-identical |
| `createBackupForBundleID:appName:options:completion:` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | Byte-identical |
| `_tarExtract:archive:toDir:` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | Byte-identical |
| `_tarExtractDataArchive:archive:toDir:warnings:` | `892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881` | `892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881` | Byte-identical |
| `_directoryHasRestoredContent:` | `0d34259591c943a606e3bb0517841b1e09239409d3daee47d294566a85484472` | `0d34259591c943a606e3bb0517841b1e09239409d3daee47d294566a85484472` | Byte-identical |

## 10. Protected working-tree SHA-256 before and after

| Protected production file | Before | After |
|---|---|---|
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` |
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` |
| `AppDataBackupManager.m` | `4a54f2ae3c690ca4f2bbcd414e4837b4a4e208222ff46b2e16b20f18086e83c4` | `4a54f2ae3c690ca4f2bbcd414e4837b4a4e208222ff46b2e16b20f18086e83c4` |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` |
| `PXBackupManifestValidator.m` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` |

Protected files checked: **34**; all SHA values match and all baseline Git diffs are zero.

## 11. Validator source hashes

| Snapshot | SHA-256 | Bytes | Lines |
|---|---|---:|---:|
| TASK-2.6 baseline | `61a4ba64f04af717d56286ce99bb0ab315f2e770b8415a73229f3177bc557252` | 87669 | 2148 |
| TASK-2.6A working source | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | 2171 |

## 12. Static and forbidden-token counts

Machine source gate result: **193/193 PASS**.

| Token/gate | Count |
|---|---:|
| `PXArchivePAXKeyIsInert` | 0 |
| `unknown semantic rejection text` | 0 |
| `GNU.sparse prefix checks` | 1 |
| `non-reserved rejection branches` | 0 |
| `private tar format enums` | 1 |
| `POSIX exact magic checks` | 1 |
| `GNU exact magic checks` | 1 |
| `POSIX prefix-field reads` | 1 |
| `raw dup calls` | 1 |
| `F_GETFD calls` | 2 |
| `F_SETFD calls` | 1 |
| `FD_CLOEXEC mentions` | 2 |
| `newParents atomic add calls` | 1 |
| `implicit limit checks` | 1 |
| `forbidden UIKit` | 0 |
| `forbidden AppDataBackupManager` | 0 |
| `forbidden AppDataCleaner` | 0 |
| `forbidden CommandRunner` | 0 |
| `forbidden NSTask` | 0 |
| `forbidden posix_spawn` | 0 |
| `forbidden system(` | 0 |
| `forbidden popen(` | 0 |
| `forbidden tar -t` | 0 |
| `forbidden bsdtar` | 0 |
| `forbidden libarchive` | 0 |
| `forbidden dispatch_` | 0 |
| `forbidden NSUserDefaults` | 0 |
| `forbidden Security` | 0 |
| `forbidden SecItem` | 0 |
| `forbidden NSNotification` | 0 |
| `forbidden writeToFile` | 0 |
| `forbidden removeItemAtPath` | 0 |
| `forbidden createDirectoryAtPath` | 0 |
| `forbidden moveItemAtPath` | 0 |
| `forbidden copyItemAtPath` | 0 |
| `forbidden NSLog` | 0 |

## 13. Scenario matrix

These are explicit source/static expected outcomes. They do not claim generated archive-fixture or target-device execution.

Scenario count: **101**.

| # | Scenario | Expected | Evidence |
|---:|---|---|---|
| 1 | Version-2-compatible manifest without systemGlobalLibrary | Accept | Absent key bypasses the present-section validation block and collects zero system-global references. |
| 2 | Version-3 manifest without systemGlobalLibrary | Accept | The same optional additive compatibility rule applies independent of supported manifest version. |
| 3 | Present non-dictionary system-global section | Reject InvalidInput | Exact field path is $.systemGlobalLibrary. |
| 4 | Present dictionary with invalid included | Reject InvalidInput | Exact field path is $.systemGlobalLibrary.included. |
| 5 | Present dictionary with invalid items | Reject InvalidInput | Exact field path is $.systemGlobalLibrary.items. |
| 6 | Included false with empty items | Accept, collect zero | Items shape is validated, then collection is skipped. |
| 7 | Included true with one item | Collect one | The single items[0].archive is passed to the existing reference boundary. |
| 8 | Included true with multiple items | Collect in array order | The indexed loop walks array order before final deterministic archive-name sort. |
| 9 | Included item missing artifact declaration | Reject MissingArchive | Existing PXArchiveAddReference declaration lookup remains unchanged. |
| 10 | Included item missing verified path | Reject MissingArchive | Existing verified-set exact lookup remains unchanged. |
| 11 | Unknown per-entry vendor.example PAX key | Ignore | Structurally valid non-reserved records reach offset advance without state assignment. |
| 12 | Unknown global vendor.example PAX key | Ignore | Global handling rejects only reserved path/size/linkpath. |
| 13 | Unknown future PAX key with binary non-NUL value | Ignore | Unknown value bytes are not decoded or retained after structural checks. |
| 14 | SCHILY.xattr.user.test key | Ignore | No semantic allow-list remains. |
| 15 | SCHILY.acl.access key | Ignore | Well-formed non-reserved ACL metadata is consumed and discarded. |
| 16 | Reserved PAX path | Apply | Existing UTF-8 decode and pending path override logic is retained. |
| 17 | Reserved PAX size | Apply | Existing decimal uint64 parsing and pending size override logic is retained. |
| 18 | Reserved PAX linkpath | Parse pending | Existing UTF-8 decode and pending linkpath logic is retained. |
| 19 | Global PAX path | Reject | Global reserved identity override remains forbidden. |
| 20 | Global PAX size | Reject | Global reserved size override remains forbidden. |
| 21 | Global PAX linkpath | Reject | Global reserved link identity override remains forbidden. |
| 22 | GNU.sparse.map key | Reject UnsupportedEntryType | Every GNU.sparse prefix remains rejected before reserved handling. |
| 23 | Malformed PAX decimal length | Reject InvalidExtendedHeader | Strict decimal and overflow checks remain unchanged. |
| 24 | PAX record missing newline | Reject InvalidExtendedHeader | Declared record must end with newline. |
| 25 | Invalid PAX key bytes | Reject InvalidExtendedHeader | Key remains printable ASCII excluding equals. |
| 26 | PAX record containing NUL | Reject InvalidExtendedHeader | The complete declared record is scanned for NUL. |
| 27 | Duplicate pending path | Reject InvalidExtendedHeader | Existing known/pending override checks remain. |
| 28 | Duplicate pending size | Reject InvalidExtendedHeader | Existing local and cross-header pending checks remain. |
| 29 | Member with zero implicit parents | Accept | Candidate parent list is empty and no limit count is consumed. |
| 30 | Repeated already-known implicit parents | Accept without count increase | Only parents absent from _implicitDirectories enter newParents. |
| 31 | One new implicit parent | Accept | One candidate is counted then committed after all checks. |
| 32 | Many new parents below limit | Add atomically | All candidate prefixes are built before one addObjectsFromArray operation. |
| 33 | Exactly 200000 unique implicit parents | Accept boundary | Sum uses <= existing PXArchiveMaximumLogicalMembers. |
| 34 | 200001st unique implicit parent | Reject LimitExceeded | Sum greater than 200000 fails at current member .path. |
| 35 | Implicit parent count arithmetic overflow | Reject LimitExceeded | newParentCount > NSUIntegerMax - implicitCount is checked first. |
| 36 | Parent-limit failure state | No parent mutation | The only addObjectsFromArray call occurs after overflow/limit checks. |
| 37 | Parent-limit failure real member | Not registered | _realTypesByPath assignment occurs after successful parent commit. |
| 38 | Explicit directory after implicit parent | Accept once | Directory at an implicit identity is allowed when no real entry exists. |
| 39 | Regular file conflicting with implicit directory | Reject DuplicateEntry | Existing full-path implicit conflict check remains before parent commit. |
| 40 | Child below declared regular file | Reject DuplicateEntry | Regular-parent conflict is checked while deriving parents. |
| 41 | POSIX ustar magic/version | Accept | Exact magic ustar\0 and version 00 classify POSIXUstar. |
| 42 | POSIX nonempty prefix/name | Compose prefix/name | Offset 345 is read only in POSIXUstar branch. |
| 43 | POSIX empty prefix | Use ordinary name | No slash is added when prefix payload is empty. |
| 44 | GNU magic/version | Accept | Exact magic ustar-space and version space-NUL classify GNU. |
| 45 | GNU header prefix-area bytes | Ignore as prefix | GNU does not enter the POSIX prefix branch. |
| 46 | GNU pending L pathname | Override header name | Existing PAX then GNU-L then header precedence remains. |
| 47 | PAX path conflicting with GNU L | Reject conflict | Existing pending override conflict checks remain unchanged. |
| 48 | Legacy all-zero magic | Accept | Six zero magic bytes classify Legacy. |
| 49 | Legacy bytes 345-499 | Ignore as prefix | Legacy uses the ordinary 100-byte name only. |
| 50 | POSIX magic with wrong version | Reject InvalidHeader | Exact version 00 is mandatory. |
| 51 | GNU magic with wrong version | Reject InvalidHeader | Exact version space-NUL is mandatory. |
| 52 | Five-byte ustar plus arbitrary sixth byte | Reject InvalidHeader | Classifier compares all six magic bytes. |
| 53 | Partially empty or mixed magic | Reject InvalidHeader | Only six-zero Legacy or exact POSIX/GNU spellings pass. |
| 54 | Unrelated nonempty magic | Reject InvalidHeader | Classifier falls through to NO. |
| 55 | Unsigned tar checksum | Preserved | PXArchiveHeaderChecksumIsValid body is byte-identical. |
| 56 | Historical signed checksum | Preserved | Signed checksum acceptance body is byte-identical. |
| 57 | GNU base-256 size | Preserved | PXArchiveParseSizeField body is byte-identical. |
| 58 | Symbolic-link member | Reject | Real-member allow-list remains regular/directory only. |
| 59 | Hard-link member | Reject | Unsupported type policy is unchanged. |
| 60 | Device/FIFO/other special member | Reject | Unsupported type policy is unchanged. |
| 61 | Duplicate normalized member | Reject | Existing real identity map check remains. |
| 62 | Tar without two-zero-block end | Reject | End-marker behavior remains unchanged. |
| 63 | Concatenated gzip member | Reject | Inflate and compressed-count helpers are byte-identical. |
| 64 | Trailing compressed garbage | Reject | Single-member and exact byte-count behavior is unchanged. |
| 65 | Compressed SHA-256 mismatch | Reject | Same-descriptor CommonCrypto hash path is byte-identical. |
| 66 | Final canonical path identity mismatch | Reject | Final lstat device/inode check is byte-identical. |
| 67 | Root descriptor CLOEXEC setup succeeds | Traverse | dup is followed by get/set/get verification before first openat. |
| 68 | dup failure | Reject OpenFailed without leak | No descriptor is owned when dup returns negative. |
| 69 | Initial F_GETFD failure | Reject and close duplicate | Combined setup branch closes currentDescriptor. |
| 70 | F_SETFD failure | Reject and close duplicate | Combined setup branch closes currentDescriptor. |
| 71 | Verification F_GETFD failure | Reject and close duplicate | Second setup branch closes currentDescriptor. |
| 72 | Child directory descriptors | Remain O_CLOEXEC | Existing child openat flags are unchanged. |
| 73 | Final archive descriptor | Remain O_CLOEXEC | Existing final openat flags are unchanged. |
| 74 | Manager source | Zero diff | Protected baseline diff is zero and SHA before/after matches. |
| 75 | Public validator header | Zero diff | 16-code API remains byte-identical. |
| 76 | Makefile | Zero diff | Application-only -lz remains exactly as TASK-2.6. |
| 77 | Extraction helper bodies | Byte-identical | Recorded manager body hashes match baseline. |
| 78 | Shell or external tar listing | Absent | Forbidden token counts remain zero. |
| 79 | Filesystem mutation in validator | Absent | Mutation API token counts remain zero. |
| 80 | TASK-2.7 Restore-plan/transaction type | Absent | No later-phase type or rollback API was introduced. |
| 81 | Report ending and commit scope | Exact | Report has exact two-line tail; implementation staging is restricted to two files. |
| 82 | systemGlobalLibrary set to NSNull | Reject InvalidInput | Non-nil non-dictionary takes exact section error path. |
| 83 | Present system section missing included | Reject InvalidInput | Exact Boolean check sees nil and fails included field path. |
| 84 | Present system section included false but items missing | Reject InvalidInput | Items shape remains mandatory when section is present. |
| 85 | Included system item is non-dictionary | Reject InvalidInput | Existing exact indexed entry validation remains. |
| 86 | Duplicate archive referenced by system and another section | Reject later reference | Existing seen-name set remains unchanged. |
| 87 | profileAppData behavior | Unchanged | Collector prefix before systemGlobalLibrary is byte-identical to baseline. |
| 88 | globalSafari behavior | Unchanged | Collector prefix before systemGlobalLibrary is byte-identical to baseline. |
| 89 | Unknown PAX value with invalid UTF-8 but no NUL | Ignore | Only reserved string values are UTF-8 decoded. |
| 90 | Unknown PAX value containing NUL | Reject | Record-wide NUL rejection remains structural. |
| 91 | Reserved path with invalid UTF-8 | Reject | Reserved string decode remains strict. |
| 92 | PAX metadata payload above 1 MiB | Reject LimitExceeded | Existing metadata payload limit remains. |
| 93 | PAX metadata total above 16 MiB | Reject LimitExceeded | Existing metadata aggregate limit remains. |
| 94 | Implicit count 199999 plus one new parent | Accept | Exact arithmetic reaches 200000. |
| 95 | Implicit count 200000 plus zero new parents | Accept | Repeated known prefixes do not increase retained state. |
| 96 | POSIX composed path invalid UTF-8 | Reject UnsafeEntryPath | Existing path UTF-8 boundary receives composed bytes. |
| 97 | GNU ordinary header name invalid UTF-8 | Reject UnsafeEntryPath | GNU uses ordinary name and existing strict path decode. |
| 98 | Legacy arbitrary version bytes with zero magic | Accept Legacy | Frozen classification is defined by six zero magic bytes. |
| 99 | CLOEXEC verification reports flag absent | Reject and close | Verified flags must include FD_CLOEXEC before traversal. |
| 100 | First openat execution ordering | After CLOEXEC verification | Source positions prove get/set/get precede loop/openat. |
| 101 | Protected SHA and exact two-file commit scope | Pass static gate | All protected after hashes equal recorded before hashes; only validator/report will be staged. |

## 14. Full production source diff

```diff
diff --git a/PXBackupArchiveValidator.m b/PXBackupArchiveValidator.m
index 67e291c..3d05dfa 100644
--- a/PXBackupArchiveValidator.m
+++ b/PXBackupArchiveValidator.m
@@ -33,6 +33,12 @@ static const uint64_t PXArchiveMaximumInflatedBudget = UINT64_C(128) << 30;
 static const uint64_t PXArchiveMaximumRestoreInflatedBytes = UINT64_C(256) << 30;
 static const size_t PXTarBlockSize = 512;

+typedef NS_ENUM(NSUInteger, PXArchiveTarHeaderFormat) {
+    PXArchiveTarHeaderFormatLegacy = 0,
+    PXArchiveTarHeaderFormatPOSIXUstar = 1,
+    PXArchiveTarHeaderFormatGNU = 2,
+};
+
 @interface PXValidatedBackupArchiveSet ()
 @property (nonatomic, copy, readwrite) NSArray<NSString *> *archiveNames;
 @property (nonatomic, copy, readwrite)
@@ -438,6 +444,25 @@ static BOOL PXArchiveOpenRelativeFile(int rootDescriptor,
                              fieldPath,
                              @"The archive root descriptor could not be duplicated.");
     }
+    int descriptorFlags = fcntl(currentDescriptor, F_GETFD);
+    if (descriptorFlags < 0 ||
+        fcntl(currentDescriptor,
+              F_SETFD,
+              descriptorFlags | FD_CLOEXEC) < 0) {
+        close(currentDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             fieldPath,
+                             @"The archive root descriptor could not be secured.");
+    }
+    int verifiedFlags = fcntl(currentDescriptor, F_GETFD);
+    if (verifiedFlags < 0 || (verifiedFlags & FD_CLOEXEC) == 0) {
+        close(currentDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             fieldPath,
+                             @"The archive root descriptor close-on-exec state is invalid.");
+    }

     for (NSUInteger index = 0; index + 1 < components.count; index++) {
         const char *component = [components[index] fileSystemRepresentation];
@@ -600,27 +625,38 @@ static BOOL PXArchiveHeaderChecksumIsValid(const unsigned char *block) {
            (signedSum >= 0 && stored == (uint64_t)signedSum);
 }

-static BOOL PXArchiveMagicIsSupported(const unsigned char *block, BOOL *isUstar) {
+static BOOL PXArchiveClassifyHeaderFormat(const unsigned char *block,
+                                          PXArchiveTarHeaderFormat *formatOut) {
     const unsigned char *magic = block + 257;
-    BOOL empty = YES;
+    const unsigned char *version = block + 263;
+    BOOL legacy = YES;
     for (size_t index = 0; index < 6; index++) {
         if (magic[index] != 0) {
-            empty = NO;
+            legacy = NO;
             break;
         }
     }
-    if (empty) {
-        if (isUstar) {
-            *isUstar = NO;
+    if (legacy) {
+        if (formatOut) {
+            *formatOut = PXArchiveTarHeaderFormatLegacy;
         }
         return YES;
     }
-    BOOL ustar = memcmp(magic, "ustar", 5) == 0 &&
-                 (magic[5] == 0 || magic[5] == ' ');
-    if (isUstar) {
-        *isUstar = ustar;
+    if (memcmp(magic, "ustar\0", 6) == 0 &&
+        version[0] == '0' && version[1] == '0') {
+        if (formatOut) {
+            *formatOut = PXArchiveTarHeaderFormatPOSIXUstar;
+        }
+        return YES;
     }
-    return ustar;
+    if (memcmp(magic, "ustar ", 6) == 0 &&
+        version[0] == ' ' && version[1] == 0) {
+        if (formatOut) {
+            *formatOut = PXArchiveTarHeaderFormatGNU;
+        }
+        return YES;
+    }
+    return NO;
 }

 static BOOL PXArchiveDecimalUInt64(const unsigned char *bytes,
@@ -653,29 +689,6 @@ static NSString *PXArchiveStringFromUTF8Data(NSData *data) {
     return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 }

-static BOOL PXArchivePAXKeyIsInert(NSString *key) {
-    if ([key isEqualToString:@"mtime"] ||
-        [key isEqualToString:@"atime"] ||
-        [key isEqualToString:@"ctime"] ||
-        [key isEqualToString:@"uid"] ||
-        [key isEqualToString:@"gid"] ||
-        [key isEqualToString:@"uname"] ||
-        [key isEqualToString:@"gname"] ||
-        [key isEqualToString:@"comment"] ||
-        [key isEqualToString:@"charset"] ||
-        [key isEqualToString:@"hdrcharset"]) {
-        return YES;
-    }
-    return ([key hasPrefix:@"SCHILY.xattr."] &&
-            key.length > [@"SCHILY.xattr." length]) ||
-           ([key hasPrefix:@"LIBARCHIVE.xattr."] &&
-            key.length > [@"LIBARCHIVE.xattr." length]) ||
-           ([key hasPrefix:@"SCHILY.acl."] &&
-            key.length > [@"SCHILY.acl." length]) ||
-           ([key hasPrefix:@"RHT.security."] &&
-            key.length > [@"RHT.security." length]);
-}
-
 static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                                               BOOL directory,
                                               BOOL *rootMarker,
@@ -955,9 +968,6 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                                  fieldPath,
                                  @"A PAX record key is invalid.");
         }
-        NSData *valueData = [NSData dataWithBytes:bytes + equalsIndex + 1
-                                           length:(recordEnd - 1) - (equalsIndex + 1)];
-
         if ([key hasPrefix:@"GNU.sparse"]) {
             return PXArchiveFail(error,
                                  PXBackupArchiveValidatorErrorUnsupportedEntryType,
@@ -973,12 +983,6 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                                  fieldPath,
                                  @"Global PAX metadata may not override member identity.");
         }
-        if (!reserved && !PXArchivePAXKeyIsInert(key)) {
-            return PXArchiveFail(error,
-                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
-                                 fieldPath,
-                                 @"A PAX metadata key has unsupported semantics.");
-        }
         if (!global && reserved) {
             if (known[key] != nil) {
                 return PXArchiveFail(error,
@@ -986,6 +990,8 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                                      fieldPath,
                                      @"A PAX override is duplicated.");
             }
+            NSData *valueData = [NSData dataWithBytes:bytes + equalsIndex + 1
+                                               length:(recordEnd - 1) - (equalsIndex + 1)];
             if ([key isEqualToString:@"size"]) {
                 uint64_t sizeValue = 0;
                 if (!PXArchiveDecimalUInt64(valueData.bytes,
@@ -1129,11 +1135,11 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,
 }

 - (NSString *)headerPathFromBlock:(const unsigned char *)block
-                           ustar:(BOOL)ustar
+                          format:(PXArchiveTarHeaderFormat)format
                            error:(NSError **)error {
     NSData *nameData = PXArchiveBytesUntilNUL(block, 100);
     NSMutableData *combined = [NSMutableData data];
-    if (ustar) {
+    if (format == PXArchiveTarHeaderFormatPOSIXUstar) {
         NSData *prefixData = PXArchiveBytesUntilNUL(block + 345, 155);
         if (prefixData.length > 0) {
             [combined appendData:prefixData];
@@ -1166,17 +1172,20 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,

     if (![path isEqualToString:@"."]) {
         NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
-        NSMutableArray<NSString *> *parents = [NSMutableArray array];
+        NSMutableArray<NSString *> *parentComponents = [NSMutableArray array];
+        NSMutableArray<NSString *> *newParents = [NSMutableArray array];
         for (NSUInteger index = 0; index + 1 < components.count; index++) {
-            [parents addObject:components[index]];
-            NSString *parent = [parents componentsJoinedByString:@"/"];
+            [parentComponents addObject:components[index]];
+            NSString *parent = [parentComponents componentsJoinedByString:@"/"];
             if ([_regularPaths containsObject:parent]) {
                 return PXArchiveFail(error,
                                      PXBackupArchiveValidatorErrorDuplicateEntry,
                                      fieldPath,
                                      @"An archive member is nested beneath a regular file.");
             }
-            [_implicitDirectories addObject:parent];
+            if (![_implicitDirectories containsObject:parent]) {
+                [newParents addObject:parent];
+            }
         }
         if (!directory && [_implicitDirectories containsObject:path]) {
             return PXArchiveFail(error,
@@ -1184,6 +1193,16 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                                  fieldPath,
                                  @"A regular file conflicts with an existing parent path.");
         }
+        NSUInteger implicitCount = _implicitDirectories.count;
+        NSUInteger newParentCount = newParents.count;
+        if (newParentCount > NSUIntegerMax - implicitCount ||
+            implicitCount + newParentCount > PXArchiveMaximumLogicalMembers) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorLimitExceeded,
+                                 fieldPath,
+                                 @"The archive implicit-directory limit was exceeded.");
+        }
+        [_implicitDirectories addObjectsFromArray:newParents];
     }

     _realTypesByPath[path] = directory ? @"d" : @"f";
@@ -1230,8 +1249,8 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                              headerPath,
                              @"An archive header checksum is invalid.");
     }
-    BOOL ustar = NO;
-    if (!PXArchiveMagicIsSupported(block, &ustar)) {
+    PXArchiveTarHeaderFormat format = PXArchiveTarHeaderFormatLegacy;
+    if (!PXArchiveClassifyHeaderFormat(block, &format)) {
         return PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorInvalidHeader,
                              headerPath,
@@ -1305,7 +1324,9 @@ static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                              @"Set-user-ID and set-group-ID archive modes are unsupported.");
     }

-    NSString *headerMemberPath = [self headerPathFromBlock:block ustar:ustar error:error];
+    NSString *headerMemberPath = [self headerPathFromBlock:block
+                                                      format:format
+                                                       error:error];
     if (!headerMemberPath) {
         return NO;
     }
@@ -2015,47 +2036,49 @@ static BOOL PXArchiveCollectReferences(NSDictionary *manifest,
     }

     id systemObject = manifest[@"systemGlobalLibrary"];
-    if (![systemObject isKindOfClass:[NSDictionary class]]) {
-        return PXArchiveFail(error,
-                             PXBackupArchiveValidatorErrorInvalidInput,
-                             @"$.systemGlobalLibrary",
-                             @"The system-global archive section is invalid.");
-    }
-    NSDictionary *system = (NSDictionary *)systemObject;
-    BOOL systemIncluded = NO;
-    if (!PXArchiveExactBoolean(system[@"included"], &systemIncluded)) {
-        return PXArchiveFail(error,
-                             PXBackupArchiveValidatorErrorInvalidInput,
-                             @"$.systemGlobalLibrary.included",
-                             @"The system-global inclusion flag is invalid.");
-    }
-    id itemsObject = system[@"items"];
-    if (![itemsObject isKindOfClass:[NSArray class]]) {
-        return PXArchiveFail(error,
-                             PXBackupArchiveValidatorErrorInvalidInput,
-                             @"$.systemGlobalLibrary.items",
-                             @"The system-global archive items are invalid.");
-    }
-    if (systemIncluded) {
-        NSArray *items = (NSArray *)itemsObject;
-        for (NSUInteger index = 0; index < items.count; index++) {
-            NSString *entryPath = PXArchiveIndexedPath(@"$.systemGlobalLibrary.items", index);
-            id entryObject = items[index];
-            if (![entryObject isKindOfClass:[NSDictionary class]] ||
-                !PXArchiveAddReference(((NSDictionary *)entryObject)[@"archive"],
-                                       PXArchiveFieldPath(entryPath, @"archive"),
-                                       declarations,
-                                       verifiedArtifacts,
-                                       seen,
-                                       references,
-                                       error)) {
-                if (![entryObject isKindOfClass:[NSDictionary class]] && error && !*error) {
-                    PXArchiveFail(error,
-                                  PXBackupArchiveValidatorErrorInvalidInput,
-                                  entryPath,
-                                  @"A system-global archive entry is invalid.");
+    if (systemObject != nil) {
+        if (![systemObject isKindOfClass:[NSDictionary class]]) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 @"$.systemGlobalLibrary",
+                                 @"The system-global archive section is invalid.");
+        }
+        NSDictionary *system = (NSDictionary *)systemObject;
+        BOOL systemIncluded = NO;
+        if (!PXArchiveExactBoolean(system[@"included"], &systemIncluded)) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 @"$.systemGlobalLibrary.included",
+                                 @"The system-global inclusion flag is invalid.");
+        }
+        id itemsObject = system[@"items"];
+        if (![itemsObject isKindOfClass:[NSArray class]]) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 @"$.systemGlobalLibrary.items",
+                                 @"The system-global archive items are invalid.");
+        }
+        if (systemIncluded) {
+            NSArray *items = (NSArray *)itemsObject;
+            for (NSUInteger index = 0; index < items.count; index++) {
+                NSString *entryPath = PXArchiveIndexedPath(@"$.systemGlobalLibrary.items", index);
+                id entryObject = items[index];
+                if (![entryObject isKindOfClass:[NSDictionary class]] ||
+                    !PXArchiveAddReference(((NSDictionary *)entryObject)[@"archive"],
+                                           PXArchiveFieldPath(entryPath, @"archive"),
+                                           declarations,
+                                           verifiedArtifacts,
+                                           seen,
+                                           references,
+                                           error)) {
+                    if (![entryObject isKindOfClass:[NSDictionary class]] && error && !*error) {
+                        PXArchiveFail(error,
+                                      PXBackupArchiveValidatorErrorInvalidInput,
+                                      entryPath,
+                                      @"A system-global archive entry is invalid.");
+                    }
+                    return NO;
                 }
-                return NO;
             }
         }
     }
```

## 15. Whitespace, line-ending, NUL and generated-artifact audit

- `git diff --check`: PASS.
- Modified validator uses LF, contains zero NUL bytes and has zero trailing-whitespace lines.
- Report uses LF, contains zero NUL bytes and is generated with no trailing whitespace.
- No compiled object, binary, tar fixture, decompressed archive, cache or staging artifact is added.
- Temporary verification/report scripts will be removed before staging and are not implementation artifacts.

## 16. Build status and remaining runtime risks

- Baseline TASK-2.6 was reported built by the project owner.
- TASK-2.6A was not compiled locally because this Windows workspace has no `clang`, `clang-cl`, `make`, or `xcrun`.
- No GitHub Actions, target-device, generated GNU/POSIX/legacy fixture, maximum topology allocation, forced `fcntl` failure, or concurrent filesystem-race pass is claimed.
- Device/toolchain validation remains necessary for Darwin `fcntl`/`FD_CLOEXEC`, producer compatibility and maximum-bound memory/performance behavior.
- TASK-2.7 planning/transaction work remains intentionally absent.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
