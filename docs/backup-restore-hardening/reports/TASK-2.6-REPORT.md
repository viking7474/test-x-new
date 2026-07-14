# TASK-2.6 Report — Archive Entry Safety Validator

## 1. Baseline and exact scope

- Required baseline and observed HEAD: `2a00a93e2127872845cc4e673c8929236d098c13`.
- TASK-2.5 source review was read and recorded as ACCEPTED before implementation.
- Production scope is exactly `PXBackupArchiveValidator.h`, `PXBackupArchiveValidator.m`, `AppDataBackupManager.m`, and `Makefile`.
- This report is the only additional implementation artifact.
- TASK-2.7 planning/transaction work was not implemented.

Initial evidence:

```text
 M AppDataBackupManager.m
 M Makefile
 A PXBackupArchiveValidator.h
 A PXBackupArchiveValidator.m
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? .task26_method_hashes_before.json
?? .task26_report.py
?? .task26_verification.json
?? .task26_verify.py
?? docs/backup-restore-hardening/reports/TASK-2.6-REPORT.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.5-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.6-add-archive-entry-safety-validator.md
2a00a93e2127872845cc4e673c8929236d098c13
2a00a93 phase2(task-2.5): add common artifact verifier
c1d9067 phase2(task-2.4): remove recorded destination fallbacks
1c5eda0 phase2(task-2.3): enforce exact restore bundle identity
```

## 2. Public API and immutable result

- The header declares one error domain, one field-path key, exactly 16 sequential error codes, one immutable result class, and one validator method.
- No extraction API, tar executable argument, warning mode, bypass flag, or Restore-plan API is exposed.
- `PXValidatedBackupArchiveSet` copies both maps, sorts exact archive names with `compare:`, returns `NO` for invalid/unknown lookup, and returns `self` from `copyWithZone:`.
- The result stores only immutable counts; it stores no descriptor, parser callback, mutable collection, or lazy validation state.

Error `userInfo` is centralized and contains only:

```text
NSLocalizedDescriptionKey
PXBackupArchiveValidatorErrorFieldPathKey
```

No archive name value, path, digest, size, bundle/group identifier, errno text, tar output, or manifest excerpt is inserted into errors.

## 3. Archive selection and deterministic ordering

Selected references are collected in operational order from main data, App Groups, included profile app data, included global Safari, and included system-global items. Preferences, Keychain, shared-system DB files, and unreferenced declarations are never selected merely by extension.

Every selected reference must exact-match one declaration and one TASK-2.5 verified path. Duplicate references fail at the later field path. Validation work is then sorted by exact archive name, while declaration indices are retained for stable member error paths.

## 4. Independent root and descriptor policy

- The selected backup root is re-inspected independently of TASK-2.5.
- Trailing separators are removed before final-component `lstat`, so a final symlink cannot be hidden by `/`.
- The raw final root and canonical root are both opened with `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`; device/inode identities must match.
- Ancestor aliases such as `/var -> /private/var` remain allowed.
- Archive parents are walked by `openat` with `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`.
- The final archive uses `O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC` and must be a regular file.
- The verified-set path must exactly equal `canonicalRoot + "/" + archiveName`.
- Root, parent, archive, and inflate resources are closed/finalized on success and failure paths.

## 5. Streaming gzip and compressed identity

- The implementation uses custom descriptor reads and zlib `inflateInit2(16 + MAX_WBITS)`; `gzopen` is absent.
- It requires gzip magic and deflate method, retries `EINTR`, and hashes compressed bytes from the same descriptor reads using CommonCrypto SHA-256.
- A single gzip member is required. Unconsumed bytes, unread trailing bytes, concatenated members, invalid CRC/trailer, and EOF before `Z_STREAM_END` fail closed.
- The inflate loop drains pending output when a 64 KiB output buffer fills exactly at a compressed-chunk boundary.
- `inflateEnd` runs whenever initialization succeeded.
- Before/after `fstat` requires unchanged device, inode, regular type, size, mtime, and ctime; atime is not compared.
- Exact compressed bytes read and digest must equal the declaration. Final canonical-path `lstat` must still identify the same non-symlink regular inode.

## 6. Streaming tar parser

- Decompressed data is consumed as 512-byte tar blocks without a temporary tar file.
- Header checksum accepts exact unsigned or historical signed sums.
- Mode, UID, GID, mtime, checksum, and ordinary size syntax are strict octal; only size additionally supports nonnegative GNU base-256.
- ustar prefix/name and legacy empty-magic headers are supported.
- Two consecutive zero blocks are required. Only decompressed zero bytes may follow the end marker.
- Incomplete header, payload, or padding state fails as truncated.
- Ordinary regular payload is counted and discarded; only bounded metadata payloads are buffered.

## 7. PAX and GNU metadata

- Bounded `x`, `g`, `L`, and `K` metadata are parsed.
- PAX uses strict decimal length prefixes, one space, printable key, equals separator, exact record boundary, and final newline.
- Per-entry `path`, `size`, and `linkpath` overrides are supported; global identity/size overrides are rejected.
- Duplicate pending overrides, PAX/GNU path conflicts, invalid UTF-8, malformed records, GNU sparse keys, and pending metadata at end are rejected.
- Standard inert metadata and bounded xattr/ACL prefixes are allowlisted; unknown semantic vendor keys fail closed rather than silently changing extraction semantics.

## 8. Member paths, types, and topology

- `.` and `./` are accepted only as directory root markers.
- Repeated leading `./` markers are removed; no trimming, case folding, Unicode normalization, percent decoding, or other path standardization occurs.
- Absolute paths, backslashes, doubled slashes, NUL, invalid UTF-8, ASCII controls, dot/dot-dot components, and over-limit path/components are rejected.
- Only regular files (`NUL`/`0`) and directories (`5`) are accepted. Directories require effective size zero; setuid/setgid bits are rejected.
- Duplicate paths/root markers, file-directory conflicts, children below regular files, and later files replacing implicit parents are rejected. Implicit parents do not require explicit directory entries.

## 9. Fixed resource limits and arithmetic

| Limit | Value |
|---|---:|
| Archive references | 10,000 |
| Physical headers per archive | 400,000 |
| Logical members per archive | 200,000 |
| Logical members per Restore | 500,000 |
| Normalized path bytes | 4,096 |
| Component UTF-8 bytes | 255 |
| One metadata payload | 1 MiB |
| Metadata total per archive | 16 MiB |
| One regular file | 64 GiB |
| Dynamic inflated minimum | 1 GiB |
| Dynamic multiplier | compressed size × 4,096 |
| Dynamic inflated maximum/archive | 128 GiB |
| Aggregate inflated maximum/Restore | 256 GiB |

All additions and multiplications that can reach these counters are overflow checked. Every decompressed byte counts toward the inflated budget, and regular logical sizes must fit the same per-archive budget.

## 10. Restore integration and error propagation

The accepted preflight order is now:

```text
public parameter guard
common manifest reader/schema/version
exact requested bundle comparison
TASK-2.4 exact destination helper
TASK-2.5 common artifact verifier
TASK-2.6 archive entry validator
warnings / NSFileManager / CommandRunner / debug / tar / kill / extraction / mutation
```

The validator is called exactly once in Restore and zero times in Backup. Its exact nonnil `NSError` is propagated on the main queue with a nil result and immediate return. The generic archive-validator fallback exists only for the impossible nil-result/nil-error state. `objc_precise_lifetime` keeps the validated archive snapshot alive through the Restore scope.

## 11. Extraction and accepted-contract non-regression

| Body | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `PXBackupManifestVersionIsSupported` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | Byte-identical |
| `PXResolveExactRestoreApplicationDataTarget` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | Byte-identical |
| `readManifestAtBackupDirectory:error:` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | Byte-identical |
| `createBackupForBundleID:appName:options:completion:` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | Byte-identical |
| `_tarExtract:archive:toDir:` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | Byte-identical |
| `_tarExtractDataArchive:archive:toDir:warnings:` | `892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881` | `892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881` | Byte-identical |
| `_directoryHasRestoredContent:` | `0d34259591c943a606e3bb0517841b1e09239409d3daee47d294566a85484472` | `0d34259591c943a606e3bb0517841b1e09239409d3daee47d294566a85484472` | Byte-identical |

This proves no change to tar executable preference, xattr/ACL fallback, staging layout, clone/cp fallback, ownership behavior, destination behavior, Backup writer/publication, schema/version handling, or destination safety contracts.

TASK-2.5 verifier header and implementation are protected and unchanged. `PXRestorePlan`, transaction/rollback, staging redesign, and structured Restore result work remain absent.

## 12. Makefile proof

- Makefile before SHA-256: `6b1e3cae55f2f32c5ccf35dd722b3f651d427e596efc5ae7d66b0e282ed36b2a`.
- Makefile after SHA-256: `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9`.
- The only Makefile edit appends exactly one `-lz` to `ProjectX_LDFLAGS`.
- Source wildcard, frameworks, private frameworks, SDK, architecture, signing, tweak, daemon, helper, and CLI linker settings are unchanged.

## 13. Protected SHA-256 before and after

| Protected file | Before | After |
|---|---|---|
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` |
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

Protected working-tree diff result: **0**.

## 14. Working-tree production file hashes before commit

| File | SHA-256 | Lines |
|---|---|---:|
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 64 |
| `PXBackupArchiveValidator.m` | `61a4ba64f04af717d56286ce99bb0ab315f2e770b8415a73229f3177bc557252` | 2148 |
| `AppDataBackupManager.m` | `4a54f2ae3c690ca4f2bbcd414e4837b4a4e208222ff46b2e16b20f18086e83c4` | 2484 |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | 174 |

## 15. Static gate table

Machine source gate result: **178/178 PASS**.

| Area | Result |
|---|---|
| Exact public API and 16-code enum | PASS |
| Immutable result | PASS |
| Reference selection and ordering | PASS |
| Independent root/openat policy | PASS |
| Streaming gzip and SHA-256 | PASS |
| Tar checksum/numeric/end-marker parser | PASS |
| PAX/GNU metadata and semantic allowlist | PASS |
| Path/type/topology policy | PASS |
| Exact fixed limits and overflow safety | PASS |
| Compressed identity recheck | PASS |
| Pure validator boundary | PASS |
| Restore ordering/error propagation/lifetime | PASS |
| Extraction and TASK-2.1–2.5 non-regression | PASS |
| Exact Makefile `-lz` edit | PASS |
| Protected production diff | PASS |
| NUL/trailing-whitespace/lexical audit | PASS |

## 16. Scenario matrix

These rows are explicit source/static expected outcomes derived from the specification and implementation. They do not claim target-device execution or generated archive-fixture execution.

Scenario count: **230**.

| # | Scenario | Expected | Static evidence |
|---:|---|---|---|
| 1 | Valid gzip ustar main-data archive | Accept | gzip mode, checksum, ustar name and two-zero-block gates are present. |
| 2 | Valid gzip legacy tar header | Accept | Empty magic is accepted as legacy; all numeric/checksum gates still apply. |
| 3 | Valid GNU-generated ustar with ./ paths | Accept | Repeated leading ./ root markers are removed without other normalization. |
| 4 | Valid BSD/PAX archive with bounded xattrs | Accept | x records plus SCHILY/LIBARCHIVE xattr allowlist are supported. |
| 5 | Valid PAX archive with ACL metadata | Accept | Bounded SCHILY.acl.* metadata is inert and accepted. |
| 6 | Valid GNU long pathname L followed by regular file | Accept | L payload becomes one pending path override. |
| 7 | Valid GNU long link K followed by link member | Reject at member type | K is parsed, but link member types remain unsupported by policy. |
| 8 | Valid per-entry PAX path override | Accept when safe | PAX path is UTF-8 decoded and passed through exact member path policy. |
| 9 | Valid per-entry PAX size override | Accept within limits | Decimal size replaces physical header size for payload accounting. |
| 10 | Valid global inert PAX metadata | Accept | Global inert metadata is parsed but does not alter member identity. |
| 11 | Main data archive selected | Parse | $.data.archive is always collected. |
| 12 | Each App Group archive selected in manifest order | Parse | appGroups array is iterated before sorting validation work. |
| 13 | Included profileAppData archive selected | Parse | Exact CFBoolean included gate controls selection. |
| 14 | Excluded profileAppData archive | Do not parse | Optional section is skipped when included is false. |
| 15 | Included globalSafari archive selected | Parse | Exact optional-section reference is collected. |
| 16 | Excluded globalSafari archive | Do not parse | No extension-based fallback exists. |
| 17 | Included system-global item archive selected | Parse | Every included items[i].archive is collected. |
| 18 | Excluded system-global section | Do not parse | Items are not consumed when included is false. |
| 19 | Preferences artifact with .tar.gz-looking name | Do not parse | preferences section is absent from archive reference collector. |
| 20 | Keychain artifact with .tar.gz-looking name | Do not parse | keychain section is absent from archive reference collector. |
| 21 | Shared-system DB artifact | Do not parse | sharedSystemDB is deliberately excluded from tar parser selection. |
| 22 | Unreferenced .tar.gz declaration | Do not parse | Only operational references are parsed. |
| 23 | Duplicate archive reference across sections | Reject | seen-name set fails the later reference with InconsistentManifest. |
| 24 | Missing artifact declaration for archive reference | Reject | MissingArchive is emitted at the stable reference field path. |
| 25 | Verified set missing referenced archive | Reject | Exact verified-set lookup must return a path. |
| 26 | 10,000 archive references | Accept boundary | Reference is added while count is below 10,000. |
| 27 | 10,001 archive references | Reject | Fixed reference limit fails before adding the excess reference. |
| 28 | Archive validation execution ordering | Deterministic | References are sorted by exact archive name before filesystem parsing. |
| 29 | Existing real backup directory | Accept | Final component lstat and descriptor checks require a real directory. |
| 30 | Missing backup directory | Reject | Root inspection/open returns validator-domain OpenFailed. |
| 31 | Backup directory final symlink | Reject | Trailing separators are removed before final-component lstat. |
| 32 | Backup directory regular file | Reject | Root final object must be a directory. |
| 33 | Ancestor alias /var -> /private/var | Accept | No lexical ancestor rejection; raw and canonical descriptors are identity-compared. |
| 34 | Root replaced between lstat and raw open | Reject | raw lstat and opened descriptor device/inode must match. |
| 35 | Root replaced during realpath/canonical open | Reject | raw-opened and canonical-opened identities must match. |
| 36 | Archive parent is a symlink | Reject | Parent walk uses openat O_DIRECTORY|O_NOFOLLOW. |
| 37 | Archive parent is a regular file | Reject | Parent openat requires O_DIRECTORY. |
| 38 | Final archive is a symlink | Reject | Final openat uses O_NOFOLLOW. |
| 39 | Final archive is a directory | Reject | fstat requires S_ISREG. |
| 40 | Final archive is FIFO | Reject without blocking | O_NONBLOCK prevents FIFO-open hang and fstat rejects type. |
| 41 | Final archive is socket/device | Reject | Only regular files pass descriptor inspection. |
| 42 | Archive disappears before open | Reject | MissingArchive is returned without raw path disclosure. |
| 43 | Verified path differs from canonicalRoot/name | Reject | Exact string equality is required before open. |
| 44 | Archive parent changes after TASK-2.5 verification | Reject or open pinned object | TASK-2.6 re-establishes its own descriptor root and nofollow walk. |
| 45 | Descriptor duplication failure | Reject | Root descriptor dup failure closes no unowned descriptor and returns OpenFailed. |
| 46 | Parent open failure midway | Reject and close | Current parent descriptor is closed on every iteration/failure. |
| 47 | Final fstat failure | Reject and close | Final descriptor closes before returning error. |
| 48 | Root descriptor closed after all archives | Close | Public method closes the canonical root on success and failure. |
| 49 | Gzip magic 1f 8b and deflate method | Accept | Prefix bytes are checked before streaming inflate. |
| 50 | Plain tar input | Reject | UnsupportedCompression; generic zlib mode is not used. |
| 51 | Zlib stream without gzip wrapper | Reject | inflateInit2 uses 16 + MAX_WBITS. |
| 52 | Wrong gzip compression method | Reject | Third prefix byte must equal Z_DEFLATED. |
| 53 | EOF before three-byte gzip prefix | Reject | TruncatedArchive is returned. |
| 54 | EINTR during compressed read | Retry | Descriptor read loop retries only EINTR. |
| 55 | Hard compressed read failure | Reject | ReadFailed without errno text in userInfo. |
| 56 | Valid stream ending inside read chunk | Accept | Z_STREAM_END requires no unconsumed bytes. |
| 57 | Concatenated gzip member in same read chunk | Reject | Nonzero avail_in at first Z_STREAM_END is rejected. |
| 58 | Concatenated member beginning in later file bytes | Reject | compressedRead ends below declared size and trailing bytes are rejected. |
| 59 | Trailing compressed garbage | Reject | Exact compressed byte count and single-member checks fail closed. |
| 60 | EOF before Z_STREAM_END | Reject | TruncatedArchive is emitted. |
| 61 | Output buffer exactly full at chunk boundary | Continue safely | Inflate loop drains pending output before requesting another descriptor read. |
| 62 | Z_BUF_ERROR with no input and no output | Wait for next read | Boundary drain returns without false truncation. |
| 63 | Inflate invalid-data status | Reject | Non-Z_OK/non-end status maps to UnsupportedCompression. |
| 64 | Inflate no progress with input remaining | Reject | No-progress guard prevents infinite loops. |
| 65 | Valid gzip CRC/ISIZE | Accept | zlib gzip wrapper validates trailer integrity. |
| 66 | Invalid gzip CRC | Reject | zlib returns an error before tar validation succeeds. |
| 67 | inflateInit2 failure | Reject | Initialization failure is handled without calling inflateEnd. |
| 68 | Failure after successful inflateInit2 | Cleanup | inflateEnd always executes when initialization succeeded. |
| 69 | Whole archive larger than memory | Stream | 64 KiB compressed/decompressed buffers; no whole-file NSData load. |
| 70 | Compressed bytes hashed from same reads | Verify | Every prefix/chunk read updates CommonCrypto context. |
| 71 | Compressed digest mismatch | Reject | DigestMismatch after identity stability checks. |
| 72 | Compressed declared size mismatch at pre-fstat | Reject | Exact st_size comparison includes zero. |
| 73 | Compressed read count exceeds declaration | Reject | Overflow-safe counter fails SizeMismatch. |
| 74 | Compressed read count below declaration after end | Reject | Trailing/single-member invariant fails. |
| 75 | Valid unsigned tar checksum | Accept | Stored checksum equals unsigned byte sum with checksum field as spaces. |
| 76 | Valid historical signed checksum | Accept | Stored checksum may equal nonnegative signed-char sum. |
| 77 | Checksum mismatch | Reject | InvalidHeader at physical member field path. |
| 78 | Octal field with digits and trailing NUL/space | Accept | Strict parser allows only trailing NUL/spaces after digits. |
| 79 | Octal field with leading spaces | Accept | Only spaces may precede the first digit. |
| 80 | Octal field with leading NUL then digits | Reject | Tightened parser does not skip leading NUL. |
| 81 | Octal field containing 8 or 9 | Reject | Only 0-7 digits are accepted. |
| 82 | Octal arithmetic overflow | Reject | Overflow is checked before multiply/add. |
| 83 | Mode field malformed | Reject | Mode is strictly parsed. |
| 84 | UID field malformed | Reject | UID is strictly parsed even though not used for policy. |
| 85 | GID field malformed | Reject | GID is strictly parsed. |
| 86 | mtime field malformed | Reject | mtime is strictly parsed. |
| 87 | Positive GNU base-256 size | Accept | Marker/sign bits and overflow are checked. |
| 88 | Negative GNU base-256 size | Reject | Negative sign bit is rejected. |
| 89 | GNU base-256 overflow beyond uint64 | Reject | Byte accumulation is overflow checked. |
| 90 | Unsupported nonempty tar magic | Reject | Only ustar or legacy empty magic passes. |
| 91 | ustar prefix plus name | Accept | Prefix and name are joined with one slash. |
| 92 | Legacy empty magic header | Accept | Legacy format remains supported with all safety gates. |
| 93 | Incomplete 512-byte header at EOF | Reject | finish detects nonzero headerUsed. |
| 94 | Payload truncated at EOF | Reject | payloadRemaining must reach zero. |
| 95 | Padding truncated at EOF | Reject | paddingRemaining must reach zero. |
| 96 | One zero end block then EOF | Reject | Two consecutive zero blocks are required. |
| 97 | One zero block then nonzero header | Reject | Single zero block may not be interrupted. |
| 98 | Two zero end blocks | Accept end marker | Parser enters afterEnd state. |
| 99 | Zero bytes after end marker | Accept | Post-end decompressed zero bytes are allowed. |
| 100 | Nonzero byte after end marker | Reject | InvalidHeader is returned immediately. |
| 101 | Empty tar with two zero blocks | Accept | Zero logical members is a valid bounded archive. |
| 102 | Strict PAX length record | Accept | Decimal length, space, key=value and final newline are checked. |
| 103 | PAX length contains nondigit | Reject | InvalidExtendedHeader. |
| 104 | PAX record length zero | Reject | Zero-length records are invalid. |
| 105 | PAX record exceeds payload boundary | Reject | recordLength must fit remaining payload. |
| 106 | PAX record missing newline | Reject | Declared final byte must be newline. |
| 107 | PAX record missing equals | Reject | Key/value separator is mandatory. |
| 108 | PAX record contains NUL | Reject | NUL is rejected anywhere in the record. |
| 109 | PAX key contains space/control/non-ASCII | Reject | Key bytes must be printable ASCII excluding equals. |
| 110 | PAX path invalid UTF-8 | Reject | UTF-8 conversion must succeed. |
| 111 | PAX path safe UTF-8 | Apply | Override is validated against member path policy on the real header. |
| 112 | PAX decimal size invalid | Reject | Only nonnegative decimal digits are accepted. |
| 113 | PAX linkpath followed by regular file | Reject | Pending link metadata cannot attach to regular/directory member. |
| 114 | Duplicate path override in one x header | Reject | Reserved key dictionary detects duplicate. |
| 115 | Duplicate size override across x headers | Reject | Pending override state fails closed. |
| 116 | Duplicate linkpath override across metadata | Reject | PAX/GNU pending link states conflict. |
| 117 | Global PAX path override | Reject | Global identity override is forbidden. |
| 118 | Global PAX size override | Reject | Global payload-size override is forbidden. |
| 119 | Global PAX linkpath override | Reject | Global link identity override is forbidden. |
| 120 | PAX GNU.sparse key | Reject | Any GNU.sparse prefix maps to unsupported entry type. |
| 121 | PAX inert mtime/uid/gid/uname/gname | Accept | Standard bounded metadata keys are allowlisted and ignored for identity. |
| 122 | PAX SCHILY.xattr metadata | Accept | Well-formed xattr prefix is allowlisted. |
| 123 | PAX LIBARCHIVE.xattr metadata | Accept | Well-formed libarchive xattr prefix is allowlisted. |
| 124 | PAX SCHILY.acl metadata | Accept | Well-formed ACL prefix is allowlisted. |
| 125 | PAX unknown semantic vendor key | Reject | Nonreserved non-inert keys fail closed. |
| 126 | GNU L long pathname with trailing NUL/newline | Accept | Terminal NUL/newline bytes are stripped within 1 MiB bound. |
| 127 | GNU L empty payload | Reject | Long path must be nonempty. |
| 128 | GNU L interior NUL | Reject | Interior NUL is forbidden. |
| 129 | GNU L invalid UTF-8 | Reject | UTF-8 conversion must succeed. |
| 130 | GNU K long link pathname | Parse pending | Link override is bounded but later member type policy still applies. |
| 131 | PAX path plus GNU L conflict | Reject | Only one pending path override source is permitted. |
| 132 | PAX linkpath plus GNU K conflict | Reject | Only one pending link override source is permitted. |
| 133 | Per-entry metadata at archive end | Reject | Pending state is invalid at the two-block end marker and finish. |
| 134 | One metadata payload larger than 1 MiB | Reject | Fixed payload bound is checked before allocation. |
| 135 | Metadata total larger than 16 MiB | Reject | Overflow-safe per-archive sum is enforced. |
| 136 | Directory root marker . | Accept | Only directory type may normalize to root marker. |
| 137 | Directory root marker ./ | Accept | Repeated leading ./ removal yields root marker. |
| 138 | Regular file root marker . | Reject | Root marker requires directory. |
| 139 | Regular file root marker ./ | Reject | Empty normalized regular path is unsafe. |
| 140 | Repeated leading ././path | Normalize to path | Only repeated root markers are removed. |
| 141 | Leading absolute slash | Reject | Absolute member paths are forbidden. |
| 142 | Backslash in member path | Reject | Backslash is forbidden for archive members. |
| 143 | Doubled slash | Reject | Empty components are forbidden. |
| 144 | Dot component inside path | Reject | No component may equal dot. |
| 145 | Dot-dot component inside path | Reject | No traversal components are allowed. |
| 146 | NUL in member path | Reject | NUL is rejected before normalization. |
| 147 | Invalid UTF-8 header path | Reject | Strict UTF-8 decode is required. |
| 148 | ASCII control 0x01-0x1f | Reject | Control bytes are forbidden. |
| 149 | ASCII DEL 0x7f | Reject | DEL is forbidden. |
| 150 | Directory with one trailing slash | Accept | One trailing slash is removed for directory type. |
| 151 | Regular file with trailing slash | Reject | Regular members must not end with slash. |
| 152 | Component exactly 255 UTF-8 bytes | Accept boundary | Component byte count uses UTF-8 bytes. |
| 153 | Component 256 UTF-8 bytes | Reject | Fixed component limit is 255 bytes. |
| 154 | Normalized path exactly 4096 UTF-8 bytes | Accept boundary | Full path limit is inclusive. |
| 155 | Normalized path 4097 UTF-8 bytes | Reject | Fixed full-path limit is exceeded. |
| 156 | Case-distinct member names | Treat distinct | No case folding occurs. |
| 157 | Canonically equivalent Unicode spellings | Treat distinct | No Unicode normalization occurs. |
| 158 | Percent-encoded traversal text | Treat literal | No percent decoding occurs; literal components still face path rules. |
| 159 | Type NUL regular file size zero | Accept | NUL type is regular and zero length is allowed. |
| 160 | Type 0 regular file | Accept | ASCII zero type is regular. |
| 161 | Type 5 directory size zero | Accept | Directory type is allowed only at effective size zero. |
| 162 | Directory with nonzero size | Reject | InvalidHeader. |
| 163 | Hard link type 1 | Reject | UnsupportedEntryType. |
| 164 | Symbolic link type 2 | Reject | UnsupportedEntryType. |
| 165 | Character device type 3 | Reject | UnsupportedEntryType. |
| 166 | Block device type 4 | Reject | UnsupportedEntryType. |
| 167 | FIFO type 6 | Reject | UnsupportedEntryType. |
| 168 | Contiguous file type 7 | Reject | UnsupportedEntryType. |
| 169 | GNU sparse type S | Reject | UnsupportedEntryType. |
| 170 | GNU dump directory type D | Reject | UnsupportedEntryType. |
| 171 | Unknown/vendor type | Reject | Only regular and directory types are allowed. |
| 172 | Setuid mode bit | Reject | 06000 mask catches setuid. |
| 173 | Setgid mode bit | Reject | 06000 mask catches setgid. |
| 174 | Duplicate normalized regular path | Reject | Exact normalized path map detects duplicate. |
| 175 | Duplicate normalized directory path | Reject | Exact normalized path map detects duplicate. |
| 176 | Duplicate root marker | Reject | Root marker is stored as exact path dot. |
| 177 | File/directory same-path conflict | Reject | Any second real entry at exact path is duplicate. |
| 178 | Regular file then child below it | Reject | Regular parent set is checked for every child parent. |
| 179 | Child then regular file at implicit parent | Reject | Implicit-directory set blocks later file parent. |
| 180 | Child then explicit directory at implicit parent | Accept | Explicit directory can materialize an implicit parent. |
| 181 | Implicit parent without explicit directory entry | Accept | Explicit directory entries are not required. |
| 182 | 400,000 physical headers | Accept boundary | Count is checked before the next header. |
| 183 | 400,001 physical headers | Reject | LimitExceeded. |
| 184 | 200,000 logical members in one archive | Accept boundary | Metadata headers do not consume logical count. |
| 185 | 200,001 logical members in one archive | Reject | LimitExceeded. |
| 186 | 500,000 logical members across Restore | Accept boundary | Shared overflow-safe aggregate counter. |
| 187 | 500,001 logical members across Restore | Reject | LimitExceeded. |
| 188 | One regular file exactly 64 GiB | Accept boundary subject to inflated budget | Single-file limit is inclusive. |
| 189 | One regular file above 64 GiB | Reject | LimitExceeded before payload processing. |
| 190 | CompressedSize * 4096 below 1 GiB | Budget 1 GiB | Dynamic minimum is applied. |
| 191 | CompressedSize * 4096 between bounds | Use product | Overflow-safe multiplication drives budget. |
| 192 | CompressedSize * 4096 above 128 GiB | Budget 128 GiB | Per-archive cap is applied. |
| 193 | Inflated bytes exceed per-archive budget | Reject | Every decompressed byte is counted. |
| 194 | Regular logical sizes exceed same archive budget | Reject | Overflow-safe logical regular byte sum is checked. |
| 195 | Aggregate inflated bytes exactly 256 GiB | Accept boundary | Call-wide cap is inclusive. |
| 196 | Aggregate inflated bytes above 256 GiB | Reject | LimitExceeded across archives. |
| 197 | Archive device changes during parse | Reject | Before/after fstat identity mismatch. |
| 198 | Archive inode changes during parse | Reject | Before/after fstat identity mismatch. |
| 199 | Archive type changes during parse | Reject | Both statuses must remain regular. |
| 200 | Archive size changes during parse | Reject | Before/after exact size mismatch. |
| 201 | Archive mtime changes during parse | Reject | mtime seconds/nanoseconds are compared. |
| 202 | Archive ctime changes during parse | Reject | ctime seconds/nanoseconds are compared. |
| 203 | Archive atime changes during parse | Ignore | atime is deliberately not compared. |
| 204 | Canonical path replaced after descriptor parse | Reject | Final lstat must be non-symlink regular with same device/inode. |
| 205 | Canonical path becomes symlink after parse | Reject | Final lstat rejects symlink. |
| 206 | Exact archive validator NSError | Propagate | Restore assigns archiveError directly when nonnil. |
| 207 | Impossible nil result with nil error | Generic fallback | Fallback uses archive validator domain/code and stable root field path. |
| 208 | Archive failure before warnings allocation | Return early | Ordering gate places archive validator before mutable warnings. |
| 209 | Archive failure before NSFileManager/CommandRunner | Return early | No operational Restore setup occurs. |
| 210 | Archive failure before debug writes | Return early | No debug path construction or write executes. |
| 211 | Archive failure before tar discovery | Return early | External tar availability cannot mask archive safety failure. |
| 212 | Archive failure before process kill | Return early | Target application is not terminated. |
| 213 | Archive failure before App Group work | Return early | Entitlement/resolver work does not start. |
| 214 | Archive failure before staging/extraction | Return early | No staging path or extractor invocation. |
| 215 | Archive failure before mutation | Return early | No wipe/copy/chown occurs. |
| 216 | Validated set lifetime through Restore scope | Retain | objc_precise_lifetime prevents early ARC release. |
| 217 | Application zlib link | Enabled | Exactly one -lz is appended to ProjectX_LDFLAGS. |
| 218 | Tweak/helper linker lines | Unchanged | No other target receives -lz. |
| 219 | Root-level source wildcard | Unchanged | New .m is picked up by existing wildcard. |
| 220 | TASK-2.5 artifact verifier source | Byte/protected unchanged | Protected diff is zero. |
| 221 | Manifest/version helper | Byte-identical | Accepted body hash retained. |
| 222 | Exact destination helper | Byte-identical | TASK-2.4 destination contract retained. |
| 223 | Common manifest reader | Byte-identical | TASK-2.1/2.2 boundary retained. |
| 224 | Backup writer/publication | Byte-identical | No Backup behavior migration. |
| 225 | Main tar extractor | Byte-identical | Tar executable preference and xattr/ACL behavior retained. |
| 226 | Data archive extractor | Byte-identical | Fallback and warnings behavior retained. |
| 227 | Restored-content helper | Byte-identical | Post-extraction semantics retained. |
| 228 | PXRestorePlan | Not added | TASK-2.7 remains locked. |
| 229 | Transaction/rollback | Not added | Later-task boundary remains intact. |
| 230 | Runtime/device fixture claim | Not claimed | Rows are source/static expected outcomes only. |

## 17. Complete production source diff

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index f7fcaae..a4cb304 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -11,6 +11,7 @@
 #import "AppGroupContainerResolver.h"
 #import "PXBackupManifestValidator.h"
 #import "PXBackupArtifactVerifier.h"
+#import "PXBackupArchiveValidator.h"
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
 #import "CommandRunner.h"
@@ -1907,6 +1908,24 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             return;
         }

+        NSError *archiveError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXValidatedBackupArchiveSet *validatedArchives =
+            [PXBackupArchiveValidator validatedArchivesForManifest:manifest
+                                                   backupDirectory:backupDir
+                                                 verifiedArtifacts:verifiedArtifacts
+                                                             error:&archiveError];
+        if (!validatedArchives) {
+            NSError *err = archiveError ?: [NSError errorWithDomain:PXBackupArchiveValidatorErrorDomain
+                                                                code:PXBackupArchiveValidatorErrorInvalidInput
+                                                            userInfo:@{
+                                                                NSLocalizedDescriptionKey: @"Backup archive validation failed",
+                                                                PXBackupArchiveValidatorErrorFieldPathKey: @"$"
+                                                            }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
         NSMutableArray<NSString *> *warnings = [NSMutableArray array];
         NSFileManager *fm = [NSFileManager defaultManager];
         CommandRunner *runner = [CommandRunner shared];
diff --git a/Makefile b/Makefile
index 2f20f7e..4aea055 100644
--- a/Makefile
+++ b/Makefile
@@ -25,7 +25,7 @@ ProjectX_PRIVATE_FRAMEWORKS = FrontBoardServices SpringBoardServices BackBoardSe
 ProjectX_FRAMEWORKS = Foundation MobileCoreServices CoreServices StoreKit IOKit CoreLocation
 # UIKit, Security and CoreLocationUI are weak-linked for iOS 12+ compatibility
 # UIButtonConfiguration and SecTrustCopyCertificateChain are iOS 15+ only
-ProjectX_LDFLAGS = -weak_framework UIKit -weak_framework CoreLocationUI -weak_framework Security -lsqlite3
+ProjectX_LDFLAGS = -weak_framework UIKit -weak_framework CoreLocationUI -weak_framework Security -lsqlite3 -lz
 ProjectX_CODESIGN_FLAGS = -Sent.plist
 ProjectX_CFLAGS = -fobjc-arc -D SUPPORT_IPAD=1 -D ENABLE_STATE_RESTORATION=1 -I./common

diff --git a/PXBackupArchiveValidator.h b/PXBackupArchiveValidator.h
new file mode 100644
index 0000000..0e05429
--- /dev/null
+++ b/PXBackupArchiveValidator.h
@@ -0,0 +1,64 @@
+#import <Foundation/Foundation.h>
+
+@class PXVerifiedBackupArtifactSet;
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSString * const
+    PXBackupArchiveValidatorErrorDomain;
+
+FOUNDATION_EXPORT NSString * const
+    PXBackupArchiveValidatorErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXBackupArchiveValidatorErrorCode) {
+    PXBackupArchiveValidatorErrorInvalidInput = 1,
+    PXBackupArchiveValidatorErrorMissingArchive = 2,
+    PXBackupArchiveValidatorErrorOpenFailed = 3,
+    PXBackupArchiveValidatorErrorReadFailed = 4,
+    PXBackupArchiveValidatorErrorUnsupportedCompression = 5,
+    PXBackupArchiveValidatorErrorTruncatedArchive = 6,
+    PXBackupArchiveValidatorErrorInvalidHeader = 7,
+    PXBackupArchiveValidatorErrorUnsafeEntryPath = 8,
+    PXBackupArchiveValidatorErrorDuplicateEntry = 9,
+    PXBackupArchiveValidatorErrorUnsupportedEntryType = 10,
+    PXBackupArchiveValidatorErrorInvalidExtendedHeader = 11,
+    PXBackupArchiveValidatorErrorLimitExceeded = 12,
+    PXBackupArchiveValidatorErrorSizeMismatch = 13,
+    PXBackupArchiveValidatorErrorDigestMismatch = 14,
+    PXBackupArchiveValidatorErrorFilesystemChanged = 15,
+    PXBackupArchiveValidatorErrorInconsistentManifest = 16,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXValidatedBackupArchiveSet : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly)
+    NSArray<NSString *> *archiveNames;
+
+@property (nonatomic, copy, readonly)
+    NSDictionary<NSString *, NSNumber *> *memberCountsByArchiveName;
+
+@property (nonatomic, copy, readonly)
+    NSDictionary<NSString *, NSNumber *> *regularFileBytesByArchiveName;
+
+- (BOOL)containsArchiveName:(NSString *)archiveName;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupArchiveValidator : NSObject
+
++ (nullable PXValidatedBackupArchiveSet *)validatedArchivesForManifest:(NSDictionary *)manifest
+                                                       backupDirectory:(NSString *)backupDirectory
+                                                     verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
+                                                                 error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXBackupArchiveValidator.m b/PXBackupArchiveValidator.m
new file mode 100644
index 0000000..67e291c
--- /dev/null
+++ b/PXBackupArchiveValidator.m
@@ -0,0 +1,2148 @@
+#import "PXBackupArchiveValidator.h"
+#import "PXBackupArtifactVerifier.h"
+#import <CommonCrypto/CommonDigest.h>
+
+#include <errno.h>
+#include <fcntl.h>
+#include <limits.h>
+#include <stdint.h>
+#include <stdlib.h>
+#include <string.h>
+#include <sys/stat.h>
+#include <sys/types.h>
+#include <unistd.h>
+#include <zlib.h>
+
+NSString * const PXBackupArchiveValidatorErrorDomain =
+    @"PXBackupArchiveValidatorErrorDomain";
+NSString * const PXBackupArchiveValidatorErrorFieldPathKey =
+    @"PXBackupArchiveValidatorErrorFieldPathKey";
+
+static const uint64_t PXArchiveMaximumReferences = UINT64_C(10000);
+static const uint64_t PXArchiveMaximumPhysicalHeaders = UINT64_C(400000);
+static const uint64_t PXArchiveMaximumLogicalMembers = UINT64_C(200000);
+static const uint64_t PXArchiveMaximumRestoreLogicalMembers = UINT64_C(500000);
+static const uint64_t PXArchiveMaximumPathBytes = UINT64_C(4096);
+static const uint64_t PXArchiveMaximumComponentBytes = UINT64_C(255);
+static const uint64_t PXArchiveMaximumMetadataPayload = UINT64_C(1) << 20;
+static const uint64_t PXArchiveMaximumMetadataTotal = UINT64_C(16) << 20;
+static const uint64_t PXArchiveMaximumRegularFileBytes = UINT64_C(64) << 30;
+static const uint64_t PXArchiveMinimumInflatedBudget = UINT64_C(1) << 30;
+static const uint64_t PXArchiveInflationMultiplier = UINT64_C(4096);
+static const uint64_t PXArchiveMaximumInflatedBudget = UINT64_C(128) << 30;
+static const uint64_t PXArchiveMaximumRestoreInflatedBytes = UINT64_C(256) << 30;
+static const size_t PXTarBlockSize = 512;
+
+@interface PXValidatedBackupArchiveSet ()
+@property (nonatomic, copy, readwrite) NSArray<NSString *> *archiveNames;
+@property (nonatomic, copy, readwrite)
+    NSDictionary<NSString *, NSNumber *> *memberCountsByArchiveName;
+@property (nonatomic, copy, readwrite)
+    NSDictionary<NSString *, NSNumber *> *regularFileBytesByArchiveName;
+- (instancetype)initWithMemberCounts:(NSDictionary<NSString *, NSNumber *> *)memberCounts
+                    regularFileBytes:(NSDictionary<NSString *, NSNumber *> *)regularFileBytes;
+@end
+
+@implementation PXValidatedBackupArchiveSet
+
+- (instancetype)initWithMemberCounts:(NSDictionary<NSString *, NSNumber *> *)memberCounts
+                    regularFileBytes:(NSDictionary<NSString *, NSNumber *> *)regularFileBytes {
+    self = [super init];
+    if (self) {
+        _memberCountsByArchiveName = [memberCounts copy];
+        _regularFileBytesByArchiveName = [regularFileBytes copy];
+        _archiveNames = [[_memberCountsByArchiveName allKeys]
+            sortedArrayUsingSelector:@selector(compare:)];
+    }
+    return self;
+}
+
+- (BOOL)containsArchiveName:(NSString *)archiveName {
+    if (![archiveName isKindOfClass:[NSString class]] || archiveName.length == 0) {
+        return NO;
+    }
+    return self.memberCountsByArchiveName[archiveName] != nil;
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
+
+@interface PXArchiveDeclaration : NSObject
+@property (nonatomic, assign) NSUInteger originalIndex;
+@property (nonatomic, copy) NSString *name;
+@property (nonatomic, assign) uint64_t expectedCompressedSize;
+@property (nonatomic, copy) NSString *expectedDigest;
+@end
+
+@implementation PXArchiveDeclaration
+@end
+
+@interface PXArchiveReference : NSObject
+@property (nonatomic, copy) NSString *fieldPath;
+@property (nonatomic, strong) PXArchiveDeclaration *declaration;
+@property (nonatomic, copy) NSString *verifiedPath;
+@end
+
+@implementation PXArchiveReference
+@end
+
+static BOOL PXArchiveFail(NSError **error,
+                          PXBackupArchiveValidatorErrorCode code,
+                          NSString *fieldPath,
+                          NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXBackupArchiveValidatorErrorDomain
+                                     code:code
+                                 userInfo:@{
+                                     NSLocalizedDescriptionKey: description,
+                                     PXBackupArchiveValidatorErrorFieldPathKey: fieldPath
+                                 }];
+    }
+    return NO;
+}
+
+static NSString *PXArchiveIndexedPath(NSString *basePath, NSUInteger index) {
+    return [NSString stringWithFormat:@"%@[%lu]", basePath, (unsigned long)index];
+}
+
+static NSString *PXArchiveFieldPath(NSString *basePath, NSString *field) {
+    return [NSString stringWithFormat:@"%@.%@", basePath, field];
+}
+
+static BOOL PXArchiveStringContainsNUL(NSString *value) {
+    unichar nul = 0;
+    NSString *nulString = [NSString stringWithCharacters:&nul length:1];
+    return [value rangeOfString:nulString].location != NSNotFound;
+}
+
+static BOOL PXArchiveStringContainsNonWhitespace(NSString *value) {
+    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location != NSNotFound;
+}
+
+static BOOL PXArchiveStringInputIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSString *string = (NSString *)value;
+    return string.length > 0 &&
+           PXArchiveStringContainsNonWhitespace(string) &&
+           !PXArchiveStringContainsNUL(string);
+}
+
+static BOOL PXArchiveExactBoolean(id value, BOOL *result) {
+    if (![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
+        return NO;
+    }
+    if (result) {
+        *result = [(NSNumber *)value boolValue];
+    }
+    return YES;
+}
+
+static BOOL PXArchiveNonnegativeIntegralNumber(id value, uint64_t *result) {
+    if (![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
+        return NO;
+    }
+    NSNumber *number = (NSNumber *)value;
+    const char *type = number.objCType;
+    if (!type || type[0] == '\0' || type[1] != '\0') {
+        return NO;
+    }
+    switch (type[0]) {
+        case 'c':
+        case 's':
+        case 'i':
+        case 'l':
+        case 'q': {
+            long long signedValue = number.longLongValue;
+            if (signedValue < 0) {
+                return NO;
+            }
+            if (result) {
+                *result = (uint64_t)signedValue;
+            }
+            return YES;
+        }
+        case 'C':
+        case 'S':
+        case 'I':
+        case 'L':
+        case 'Q':
+            if (result) {
+                *result = number.unsignedLongLongValue;
+            }
+            return YES;
+        default:
+            return NO;
+    }
+}
+
+static BOOL PXArchiveDigestIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSString *digest = (NSString *)value;
+    if (digest.length != CC_SHA256_DIGEST_LENGTH * 2) {
+        return NO;
+    }
+    for (NSUInteger index = 0; index < digest.length; index++) {
+        unichar character = [digest characterAtIndex:index];
+        BOOL digit = character >= (unichar)'0' && character <= (unichar)'9';
+        BOOL lowerHex = character >= (unichar)'a' && character <= (unichar)'f';
+        if (!digit && !lowerHex) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+static BOOL PXArchiveArtifactNameIsSafe(id value) {
+    if (!PXArchiveStringInputIsValid(value)) {
+        return NO;
+    }
+    NSString *name = (NSString *)value;
+    if ([name hasPrefix:@"/"] || [name hasSuffix:@"/"] ||
+        [name rangeOfString:@"//"].location != NSNotFound) {
+        return NO;
+    }
+    NSArray<NSString *> *components = [name componentsSeparatedByString:@"/"];
+    if (components.count == 0) {
+        return NO;
+    }
+    for (NSString *component in components) {
+        if (component.length == 0 ||
+            [component isEqualToString:@"."] ||
+            [component isEqualToString:@".."]) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+static BOOL PXArchiveAddUInt64(uint64_t left, uint64_t right, uint64_t *result) {
+    if (UINT64_MAX - left < right) {
+        return NO;
+    }
+    if (result) {
+        *result = left + right;
+    }
+    return YES;
+}
+
+static BOOL PXArchiveMultiplyUInt64(uint64_t left, uint64_t right, uint64_t *result) {
+    if (left != 0 && right > UINT64_MAX / left) {
+        return NO;
+    }
+    if (result) {
+        *result = left * right;
+    }
+    return YES;
+}
+
+static uint64_t PXArchiveInflatedBudget(uint64_t compressedSize) {
+    uint64_t multiplied = 0;
+    if (!PXArchiveMultiplyUInt64(compressedSize,
+                                 PXArchiveInflationMultiplier,
+                                 &multiplied)) {
+        multiplied = PXArchiveMaximumInflatedBudget;
+    }
+    if (multiplied < PXArchiveMinimumInflatedBudget) {
+        multiplied = PXArchiveMinimumInflatedBudget;
+    }
+    if (multiplied > PXArchiveMaximumInflatedBudget) {
+        multiplied = PXArchiveMaximumInflatedBudget;
+    }
+    return multiplied;
+}
+
+static NSString *PXArchiveHexDigest(const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
+    static const char hex[] = "0123456789abcdef";
+    char output[CC_SHA256_DIGEST_LENGTH * 2 + 1];
+    for (size_t index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
+        output[index * 2] = hex[(digest[index] >> 4) & 0x0f];
+        output[index * 2 + 1] = hex[digest[index] & 0x0f];
+    }
+    output[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
+    return [[NSString alloc] initWithBytes:output
+                                    length:CC_SHA256_DIGEST_LENGTH * 2
+                                  encoding:NSASCIIStringEncoding];
+}
+
+static BOOL PXArchiveStatIdentityEqual(const struct stat *before,
+                                       const struct stat *after) {
+    return before->st_dev == after->st_dev &&
+           before->st_ino == after->st_ino &&
+           S_ISREG(before->st_mode) &&
+           S_ISREG(after->st_mode) &&
+           before->st_size == after->st_size &&
+           before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
+           before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
+           before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
+           before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
+}
+
+static BOOL PXArchiveOpenCanonicalBackupRoot(NSString *backupDirectory,
+                                             NSString **canonicalRootOut,
+                                             int *rootDescriptorOut,
+                                             NSError **error) {
+    if (canonicalRootOut) {
+        *canonicalRootOut = nil;
+    }
+    if (rootDescriptorOut) {
+        *rootDescriptorOut = -1;
+    }
+
+    NSString *inspectionPath = backupDirectory;
+    while (inspectionPath.length > 1 &&
+           [inspectionPath characterAtIndex:inspectionPath.length - 1] == (unichar)'/') {
+        inspectionPath = [inspectionPath substringToIndex:inspectionPath.length - 1];
+    }
+    const char *rawPath = inspectionPath.fileSystemRepresentation;
+    if (!rawPath) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             @"$",
+                             @"The backup directory input is invalid.");
+    }
+
+    struct stat rawStatus;
+    if (lstat(rawPath, &rawStatus) != 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The backup directory could not be inspected.");
+    }
+    if (S_ISLNK(rawStatus.st_mode) || !S_ISDIR(rawStatus.st_mode)) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The backup directory is not a safe directory.");
+    }
+
+    int rawDescriptor = open(rawPath,
+                             O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (rawDescriptor < 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The backup directory could not be opened safely.");
+    }
+
+    struct stat openedRawStatus;
+    if (fstat(rawDescriptor, &openedRawStatus) != 0 ||
+        !S_ISDIR(openedRawStatus.st_mode)) {
+        close(rawDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The backup directory descriptor is invalid.");
+    }
+    if (rawStatus.st_dev != openedRawStatus.st_dev ||
+        rawStatus.st_ino != openedRawStatus.st_ino) {
+        close(rawDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorFilesystemChanged,
+                             @"$",
+                             @"The backup directory changed while being opened.");
+    }
+
+    char canonicalBuffer[PATH_MAX];
+    if (realpath(rawPath, canonicalBuffer) == NULL) {
+        close(rawDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The backup directory could not be canonicalized.");
+    }
+    NSString *canonicalRoot = [[NSString alloc]
+        initWithBytes:canonicalBuffer
+               length:strlen(canonicalBuffer)
+             encoding:NSUTF8StringEncoding];
+    if (canonicalRoot.length == 0) {
+        close(rawDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The canonical backup directory is invalid.");
+    }
+
+    int canonicalDescriptor = open(canonicalBuffer,
+                                   O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (canonicalDescriptor < 0) {
+        close(rawDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The canonical backup directory could not be opened.");
+    }
+    struct stat canonicalStatus;
+    if (fstat(canonicalDescriptor, &canonicalStatus) != 0 ||
+        !S_ISDIR(canonicalStatus.st_mode)) {
+        close(canonicalDescriptor);
+        close(rawDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             @"$",
+                             @"The canonical backup directory descriptor is invalid.");
+    }
+    if (openedRawStatus.st_dev != canonicalStatus.st_dev ||
+        openedRawStatus.st_ino != canonicalStatus.st_ino) {
+        close(canonicalDescriptor);
+        close(rawDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorFilesystemChanged,
+                             @"$",
+                             @"The backup directory identity changed during canonicalization.");
+    }
+    close(rawDescriptor);
+
+    if (canonicalRootOut) {
+        *canonicalRootOut = canonicalRoot;
+    }
+    if (rootDescriptorOut) {
+        *rootDescriptorOut = canonicalDescriptor;
+    } else {
+        close(canonicalDescriptor);
+    }
+    return YES;
+}
+
+static BOOL PXArchiveOpenRelativeFile(int rootDescriptor,
+                                      NSString *archiveName,
+                                      NSString *fieldPath,
+                                      int *fileDescriptorOut,
+                                      struct stat *statusOut,
+                                      NSError **error) {
+    if (fileDescriptorOut) {
+        *fileDescriptorOut = -1;
+    }
+    NSArray<NSString *> *components = [archiveName componentsSeparatedByString:@"/"];
+    if (components.count == 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             fieldPath,
+                             @"The archive reference is invalid.");
+    }
+
+    int currentDescriptor = dup(rootDescriptor);
+    if (currentDescriptor < 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             fieldPath,
+                             @"The archive root descriptor could not be duplicated.");
+    }
+
+    for (NSUInteger index = 0; index + 1 < components.count; index++) {
+        const char *component = [components[index] fileSystemRepresentation];
+        if (!component) {
+            close(currentDescriptor);
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorOpenFailed,
+                                 fieldPath,
+                                 @"An archive parent component is invalid.");
+        }
+        int nextDescriptor = openat(currentDescriptor,
+                                    component,
+                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        close(currentDescriptor);
+        if (nextDescriptor < 0) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorOpenFailed,
+                                 fieldPath,
+                                 @"An archive parent component could not be opened safely.");
+        }
+        currentDescriptor = nextDescriptor;
+    }
+
+    const char *finalComponent = [components.lastObject fileSystemRepresentation];
+    if (!finalComponent) {
+        close(currentDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             fieldPath,
+                             @"The archive filename is invalid.");
+    }
+    int fileDescriptor = openat(currentDescriptor,
+                                finalComponent,
+                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    close(currentDescriptor);
+    if (fileDescriptor < 0) {
+        PXBackupArchiveValidatorErrorCode code =
+            errno == ENOENT
+                ? PXBackupArchiveValidatorErrorMissingArchive
+                : PXBackupArchiveValidatorErrorOpenFailed;
+        return PXArchiveFail(error,
+                             code,
+                             fieldPath,
+                             @"The archive could not be opened safely.");
+    }
+
+    struct stat status;
+    if (fstat(fileDescriptor, &status) != 0 || !S_ISREG(status.st_mode)) {
+        close(fileDescriptor);
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorOpenFailed,
+                             fieldPath,
+                             @"The archive is not a regular file.");
+    }
+
+    if (fileDescriptorOut) {
+        *fileDescriptorOut = fileDescriptor;
+    } else {
+        close(fileDescriptor);
+    }
+    if (statusOut) {
+        *statusOut = status;
+    }
+    return YES;
+}
+
+static NSData *PXArchiveBytesUntilNUL(const unsigned char *bytes, size_t length) {
+    size_t used = 0;
+    while (used < length && bytes[used] != 0) {
+        used++;
+    }
+    return [NSData dataWithBytes:bytes length:used];
+}
+
+static BOOL PXArchiveBlockIsZero(const unsigned char *block) {
+    for (size_t index = 0; index < PXTarBlockSize; index++) {
+        if (block[index] != 0) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+static BOOL PXArchiveParseOctal(const unsigned char *bytes,
+                                size_t length,
+                                uint64_t *result) {
+    size_t index = 0;
+    while (index < length && bytes[index] == ' ') {
+        index++;
+    }
+    BOOL sawDigit = NO;
+    uint64_t value = 0;
+    for (; index < length; index++) {
+        unsigned char byte = bytes[index];
+        if (byte >= '0' && byte <= '7') {
+            sawDigit = YES;
+            if (value > (UINT64_MAX - (uint64_t)(byte - '0')) / 8) {
+                return NO;
+            }
+            value = value * 8 + (uint64_t)(byte - '0');
+            continue;
+        }
+        if (byte == 0 || byte == ' ') {
+            for (size_t tail = index; tail < length; tail++) {
+                if (bytes[tail] != 0 && bytes[tail] != ' ') {
+                    return NO;
+                }
+            }
+            break;
+        }
+        return NO;
+    }
+    if (!sawDigit) {
+        return NO;
+    }
+    if (result) {
+        *result = value;
+    }
+    return YES;
+}
+
+static BOOL PXArchiveParseSizeField(const unsigned char *bytes,
+                                    size_t length,
+                                    uint64_t *result) {
+    if (length == 0) {
+        return NO;
+    }
+    if ((bytes[0] & 0x80) == 0) {
+        return PXArchiveParseOctal(bytes, length, result);
+    }
+    if ((bytes[0] & 0x40) != 0) {
+        return NO;
+    }
+    uint64_t value = (uint64_t)(bytes[0] & 0x3f);
+    for (size_t index = 1; index < length; index++) {
+        if (value > (UINT64_MAX - bytes[index]) / 256) {
+            return NO;
+        }
+        value = value * 256 + bytes[index];
+    }
+    if (result) {
+        *result = value;
+    }
+    return YES;
+}
+
+static BOOL PXArchiveHeaderChecksumIsValid(const unsigned char *block) {
+    uint64_t stored = 0;
+    if (!PXArchiveParseOctal(block + 148, 8, &stored)) {
+        return NO;
+    }
+    uint64_t unsignedSum = 0;
+    int64_t signedSum = 0;
+    for (size_t index = 0; index < PXTarBlockSize; index++) {
+        unsigned char value = (index >= 148 && index < 156) ? (unsigned char)' ' : block[index];
+        unsignedSum += value;
+        signedSum += (int8_t)value;
+    }
+    return stored == unsignedSum ||
+           (signedSum >= 0 && stored == (uint64_t)signedSum);
+}
+
+static BOOL PXArchiveMagicIsSupported(const unsigned char *block, BOOL *isUstar) {
+    const unsigned char *magic = block + 257;
+    BOOL empty = YES;
+    for (size_t index = 0; index < 6; index++) {
+        if (magic[index] != 0) {
+            empty = NO;
+            break;
+        }
+    }
+    if (empty) {
+        if (isUstar) {
+            *isUstar = NO;
+        }
+        return YES;
+    }
+    BOOL ustar = memcmp(magic, "ustar", 5) == 0 &&
+                 (magic[5] == 0 || magic[5] == ' ');
+    if (isUstar) {
+        *isUstar = ustar;
+    }
+    return ustar;
+}
+
+static BOOL PXArchiveDecimalUInt64(const unsigned char *bytes,
+                                   size_t length,
+                                   uint64_t *result) {
+    if (length == 0) {
+        return NO;
+    }
+    uint64_t value = 0;
+    for (size_t index = 0; index < length; index++) {
+        unsigned char byte = bytes[index];
+        if (byte < '0' || byte > '9') {
+            return NO;
+        }
+        if (value > (UINT64_MAX - (uint64_t)(byte - '0')) / 10) {
+            return NO;
+        }
+        value = value * 10 + (uint64_t)(byte - '0');
+    }
+    if (result) {
+        *result = value;
+    }
+    return YES;
+}
+
+static NSString *PXArchiveStringFromUTF8Data(NSData *data) {
+    if (![data isKindOfClass:[NSData class]]) {
+        return nil;
+    }
+    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
+}
+
+static BOOL PXArchivePAXKeyIsInert(NSString *key) {
+    if ([key isEqualToString:@"mtime"] ||
+        [key isEqualToString:@"atime"] ||
+        [key isEqualToString:@"ctime"] ||
+        [key isEqualToString:@"uid"] ||
+        [key isEqualToString:@"gid"] ||
+        [key isEqualToString:@"uname"] ||
+        [key isEqualToString:@"gname"] ||
+        [key isEqualToString:@"comment"] ||
+        [key isEqualToString:@"charset"] ||
+        [key isEqualToString:@"hdrcharset"]) {
+        return YES;
+    }
+    return ([key hasPrefix:@"SCHILY.xattr."] &&
+            key.length > [@"SCHILY.xattr." length]) ||
+           ([key hasPrefix:@"LIBARCHIVE.xattr."] &&
+            key.length > [@"LIBARCHIVE.xattr." length]) ||
+           ([key hasPrefix:@"SCHILY.acl."] &&
+            key.length > [@"SCHILY.acl." length]) ||
+           ([key hasPrefix:@"RHT.security."] &&
+            key.length > [@"RHT.security." length]);
+}
+
+static NSString *PXArchiveNormalizeMemberPath(NSString *input,
+                                              BOOL directory,
+                                              BOOL *rootMarker,
+                                              NSError **error,
+                                              NSString *fieldPath) {
+    if (rootMarker) {
+        *rootMarker = NO;
+    }
+    if (![input isKindOfClass:[NSString class]] || input.length == 0 ||
+        PXArchiveStringContainsNUL(input)) {
+        PXArchiveFail(error,
+                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                      fieldPath,
+                      @"An archive member path is invalid.");
+        return nil;
+    }
+
+    NSData *originalBytes = [input dataUsingEncoding:NSUTF8StringEncoding
+                                allowLossyConversion:NO];
+    if (!originalBytes) {
+        PXArchiveFail(error,
+                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                      fieldPath,
+                      @"An archive member path is not valid UTF-8.");
+        return nil;
+    }
+    const unsigned char *raw = originalBytes.bytes;
+    for (NSUInteger index = 0; index < originalBytes.length; index++) {
+        unsigned char byte = raw[index];
+        if (byte == 0 || (byte >= 1 && byte <= 31) || byte == 127) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                          fieldPath,
+                          @"An archive member path contains a control character.");
+            return nil;
+        }
+    }
+
+    NSString *path = input;
+    if ([path hasPrefix:@"/"] || [path rangeOfString:@"\\"].location != NSNotFound ||
+        [path rangeOfString:@"//"].location != NSNotFound) {
+        PXArchiveFail(error,
+                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                      fieldPath,
+                      @"An archive member path is unsafe.");
+        return nil;
+    }
+
+    while ([path hasPrefix:@"./"]) {
+        path = [path substringFromIndex:2];
+    }
+    if ([path isEqualToString:@"."] || path.length == 0) {
+        if (!directory) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                          fieldPath,
+                          @"The archive root marker must be a directory.");
+            return nil;
+        }
+        if (rootMarker) {
+            *rootMarker = YES;
+        }
+        return @".";
+    }
+
+    if ([path hasSuffix:@"/"]) {
+        if (!directory) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                          fieldPath,
+                          @"A regular archive member must not end with a slash.");
+            return nil;
+        }
+        path = [path substringToIndex:path.length - 1];
+    }
+    if (path.length == 0 || [path hasPrefix:@"/"] ||
+        [path rangeOfString:@"//"].location != NSNotFound) {
+        PXArchiveFail(error,
+                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                      fieldPath,
+                      @"An archive member path is unsafe.");
+        return nil;
+    }
+
+    NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
+    for (NSString *component in components) {
+        if (component.length == 0 ||
+            [component isEqualToString:@"."] ||
+            [component isEqualToString:@".."]) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                          fieldPath,
+                          @"An archive member path contains an unsafe component.");
+            return nil;
+        }
+        NSData *componentBytes = [component dataUsingEncoding:NSUTF8StringEncoding
+                                         allowLossyConversion:NO];
+        if (!componentBytes || componentBytes.length > PXArchiveMaximumComponentBytes) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorLimitExceeded,
+                          fieldPath,
+                          @"An archive member path component exceeds the fixed limit.");
+            return nil;
+        }
+    }
+    NSData *normalizedBytes = [path dataUsingEncoding:NSUTF8StringEncoding
+                                allowLossyConversion:NO];
+    if (!normalizedBytes || normalizedBytes.length > PXArchiveMaximumPathBytes) {
+        PXArchiveFail(error,
+                      PXBackupArchiveValidatorErrorLimitExceeded,
+                      fieldPath,
+                      @"An archive member path exceeds the fixed limit.");
+        return nil;
+    }
+    return path;
+}
+
+@interface PXArchiveTarParser : NSObject {
+    NSUInteger _artifactIndex;
+    uint64_t _archiveBudget;
+    uint64_t *_restoreLogicalMembers;
+    unsigned char _headerBlock[512];
+    size_t _headerUsed;
+    uint64_t _physicalHeaders;
+    uint64_t _logicalMembers;
+    uint64_t _regularFileBytes;
+    uint64_t _metadataTotal;
+    uint64_t _payloadRemaining;
+    uint64_t _paddingRemaining;
+    char _metadataType;
+    uint64_t _currentHeaderIndex;
+    NSMutableData *_metadataPayload;
+    BOOL _metadataNeedsFinalize;
+    NSUInteger _zeroBlockCount;
+    BOOL _afterEnd;
+    NSMutableDictionary<NSString *, NSString *> *_realTypesByPath;
+    NSMutableSet<NSString *> *_implicitDirectories;
+    NSMutableSet<NSString *> *_regularPaths;
+    NSString *_pendingPAXPath;
+    NSNumber *_pendingPAXSize;
+    NSString *_pendingPAXLinkPath;
+    NSString *_pendingGNUPath;
+    NSString *_pendingGNULinkPath;
+    BOOL _hasPendingPerEntryMetadata;
+}
+@property (nonatomic, assign, readonly) uint64_t logicalMembers;
+@property (nonatomic, assign, readonly) uint64_t regularFileBytes;
+- (instancetype)initWithArtifactIndex:(NSUInteger)artifactIndex
+                        archiveBudget:(uint64_t)archiveBudget
+               restoreLogicalMembers:(uint64_t *)restoreLogicalMembers;
+- (BOOL)consumeBytes:(const unsigned char *)bytes
+              length:(size_t)length
+               error:(NSError **)error;
+- (BOOL)finishWithError:(NSError **)error;
+@end
+
+@implementation PXArchiveTarParser
+
+- (instancetype)initWithArtifactIndex:(NSUInteger)artifactIndex
+                        archiveBudget:(uint64_t)archiveBudget
+               restoreLogicalMembers:(uint64_t *)restoreLogicalMembers {
+    self = [super init];
+    if (self) {
+        _artifactIndex = artifactIndex;
+        _archiveBudget = archiveBudget;
+        _restoreLogicalMembers = restoreLogicalMembers;
+        _realTypesByPath = [NSMutableDictionary dictionary];
+        _implicitDirectories = [NSMutableSet set];
+        _regularPaths = [NSMutableSet set];
+    }
+    return self;
+}
+
+- (uint64_t)logicalMembers {
+    return _logicalMembers;
+}
+
+- (uint64_t)regularFileBytes {
+    return _regularFileBytes;
+}
+
+- (NSString *)memberPathForIndex:(uint64_t)index field:(NSString *)field {
+    NSString *base = [NSString stringWithFormat:@"$.artifacts[%lu].members[%llu]",
+                      (unsigned long)_artifactIndex,
+                      (unsigned long long)index];
+    return field.length ? PXArchiveFieldPath(base, field) : base;
+}
+
+- (void)clearPendingMetadata {
+    _pendingPAXPath = nil;
+    _pendingPAXSize = nil;
+    _pendingPAXLinkPath = nil;
+    _pendingGNUPath = nil;
+    _pendingGNULinkPath = nil;
+    _hasPendingPerEntryMetadata = NO;
+}
+
+- (BOOL)parsePAXPayload:(NSData *)payload
+                 global:(BOOL)global
+                  error:(NSError **)error {
+    const unsigned char *bytes = payload.bytes;
+    size_t length = payload.length;
+    size_t offset = 0;
+    NSMutableDictionary<NSString *, id> *known = [NSMutableDictionary dictionary];
+    NSString *fieldPath = [self memberPathForIndex:_currentHeaderIndex field:nil];
+
+    while (offset < length) {
+        size_t recordStart = offset;
+        size_t spaceIndex = offset;
+        while (spaceIndex < length && bytes[spaceIndex] != ' ') {
+            if (bytes[spaceIndex] < '0' || bytes[spaceIndex] > '9') {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     fieldPath,
+                                     @"A PAX record length is invalid.");
+            }
+            spaceIndex++;
+        }
+        if (spaceIndex == recordStart || spaceIndex >= length) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 fieldPath,
+                                 @"A PAX record length is invalid.");
+        }
+        uint64_t recordLength = 0;
+        if (!PXArchiveDecimalUInt64(bytes + recordStart,
+                                    spaceIndex - recordStart,
+                                    &recordLength) ||
+            recordLength == 0 || recordLength > SIZE_MAX ||
+            recordStart > length || recordLength > length - recordStart) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 fieldPath,
+                                 @"A PAX record length is invalid.");
+        }
+        size_t recordEnd = recordStart + (size_t)recordLength;
+        if (recordEnd <= spaceIndex + 2 || bytes[recordEnd - 1] != '\n') {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 fieldPath,
+                                 @"A PAX record terminator is invalid.");
+        }
+        size_t equalsIndex = spaceIndex + 1;
+        while (equalsIndex < recordEnd - 1 && bytes[equalsIndex] != '=') {
+            equalsIndex++;
+        }
+        if (equalsIndex == spaceIndex + 1 || equalsIndex >= recordEnd - 1) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 fieldPath,
+                                 @"A PAX record key/value separator is invalid.");
+        }
+        for (size_t index = recordStart; index < recordEnd; index++) {
+            if (bytes[index] == 0) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     fieldPath,
+                                     @"A PAX record contains a NUL byte.");
+            }
+        }
+        for (size_t index = spaceIndex + 1; index < equalsIndex; index++) {
+            unsigned char byte = bytes[index];
+            if (byte < 0x21 || byte > 0x7e || byte == '=') {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     fieldPath,
+                                     @"A PAX record key is invalid.");
+            }
+        }
+        NSData *keyData = [NSData dataWithBytes:bytes + spaceIndex + 1
+                                         length:equalsIndex - (spaceIndex + 1)];
+        NSString *key = [[NSString alloc] initWithData:keyData
+                                              encoding:NSASCIIStringEncoding];
+        if (key.length == 0) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 fieldPath,
+                                 @"A PAX record key is invalid.");
+        }
+        NSData *valueData = [NSData dataWithBytes:bytes + equalsIndex + 1
+                                           length:(recordEnd - 1) - (equalsIndex + 1)];
+
+        if ([key hasPrefix:@"GNU.sparse"]) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorUnsupportedEntryType,
+                                 fieldPath,
+                                 @"Sparse archive metadata is not supported.");
+        }
+        BOOL reserved = [key isEqualToString:@"path"] ||
+                        [key isEqualToString:@"size"] ||
+                        [key isEqualToString:@"linkpath"];
+        if (global && reserved) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 fieldPath,
+                                 @"Global PAX metadata may not override member identity.");
+        }
+        if (!reserved && !PXArchivePAXKeyIsInert(key)) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 fieldPath,
+                                 @"A PAX metadata key has unsupported semantics.");
+        }
+        if (!global && reserved) {
+            if (known[key] != nil) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     fieldPath,
+                                     @"A PAX override is duplicated.");
+            }
+            if ([key isEqualToString:@"size"]) {
+                uint64_t sizeValue = 0;
+                if (!PXArchiveDecimalUInt64(valueData.bytes,
+                                            valueData.length,
+                                            &sizeValue)) {
+                    return PXArchiveFail(error,
+                                         PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                         fieldPath,
+                                         @"A PAX size override is invalid.");
+                }
+                known[key] = @(sizeValue);
+            } else {
+                NSString *stringValue = PXArchiveStringFromUTF8Data(valueData);
+                if (!stringValue || PXArchiveStringContainsNUL(stringValue)) {
+                    return PXArchiveFail(error,
+                                         PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                         fieldPath,
+                                         @"A PAX string override is invalid UTF-8.");
+                }
+                known[key] = stringValue;
+            }
+        }
+        offset = recordEnd;
+    }
+    if (offset != length) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                             fieldPath,
+                             @"A PAX payload is malformed.");
+    }
+
+    if (!global) {
+        NSString *pathValue = known[@"path"];
+        NSNumber *sizeValue = known[@"size"];
+        NSString *linkValue = known[@"linkpath"];
+        if (pathValue) {
+            if (_pendingPAXPath || _pendingGNUPath) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     fieldPath,
+                                     @"Conflicting archive path overrides are pending.");
+            }
+            _pendingPAXPath = pathValue;
+        }
+        if (sizeValue) {
+            if (_pendingPAXSize) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     fieldPath,
+                                     @"A size override is already pending.");
+            }
+            _pendingPAXSize = sizeValue;
+        }
+        if (linkValue) {
+            if (_pendingPAXLinkPath || _pendingGNULinkPath) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     fieldPath,
+                                     @"A link override is already pending.");
+            }
+            _pendingPAXLinkPath = linkValue;
+        }
+        _hasPendingPerEntryMetadata = YES;
+    }
+    return YES;
+}
+
+- (BOOL)parseGNULongPayload:(NSData *)payload
+                       type:(char)type
+                      error:(NSError **)error {
+    const unsigned char *bytes = payload.bytes;
+    size_t length = payload.length;
+    while (length > 0 && (bytes[length - 1] == 0 || bytes[length - 1] == '\n')) {
+        length--;
+    }
+    if (length == 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                             [self memberPathForIndex:_currentHeaderIndex field:nil],
+                             @"A GNU long-name payload is empty.");
+    }
+    for (size_t index = 0; index < length; index++) {
+        if (bytes[index] == 0) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 [self memberPathForIndex:_currentHeaderIndex field:nil],
+                                 @"A GNU long-name payload contains an interior NUL.");
+        }
+    }
+    NSData *trimmed = [NSData dataWithBytes:bytes length:length];
+    NSString *value = PXArchiveStringFromUTF8Data(trimmed);
+    if (!value) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                             [self memberPathForIndex:_currentHeaderIndex field:nil],
+                             @"A GNU long-name payload is not valid UTF-8.");
+    }
+    if (type == 'L') {
+        if (_pendingGNUPath || _pendingPAXPath) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 [self memberPathForIndex:_currentHeaderIndex field:nil],
+                                 @"Conflicting archive path overrides are pending.");
+        }
+        _pendingGNUPath = value;
+    } else {
+        if (_pendingGNULinkPath || _pendingPAXLinkPath) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                 [self memberPathForIndex:_currentHeaderIndex field:nil],
+                                 @"Conflicting archive link overrides are pending.");
+        }
+        _pendingGNULinkPath = value;
+    }
+    _hasPendingPerEntryMetadata = YES;
+    return YES;
+}
+
+- (BOOL)finalizeMetadataWithError:(NSError **)error {
+    if (!_metadataNeedsFinalize) {
+        return YES;
+    }
+    NSData *payload = [_metadataPayload copy] ?: [NSData data];
+    char type = _metadataType;
+    _metadataPayload = nil;
+    _metadataNeedsFinalize = NO;
+    _metadataType = 0;
+    if (type == 'x') {
+        return [self parsePAXPayload:payload global:NO error:error];
+    }
+    if (type == 'g') {
+        return [self parsePAXPayload:payload global:YES error:error];
+    }
+    if (type == 'L' || type == 'K') {
+        return [self parseGNULongPayload:payload type:type error:error];
+    }
+    return PXArchiveFail(error,
+                         PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                         [self memberPathForIndex:_currentHeaderIndex field:nil],
+                         @"An archive metadata header type is invalid.");
+}
+
+- (NSString *)headerPathFromBlock:(const unsigned char *)block
+                           ustar:(BOOL)ustar
+                           error:(NSError **)error {
+    NSData *nameData = PXArchiveBytesUntilNUL(block, 100);
+    NSMutableData *combined = [NSMutableData data];
+    if (ustar) {
+        NSData *prefixData = PXArchiveBytesUntilNUL(block + 345, 155);
+        if (prefixData.length > 0) {
+            [combined appendData:prefixData];
+            unsigned char slash = '/';
+            [combined appendBytes:&slash length:1];
+        }
+    }
+    [combined appendData:nameData];
+    NSString *path = PXArchiveStringFromUTF8Data(combined);
+    if (!path) {
+        PXArchiveFail(error,
+                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
+                      [self memberPathForIndex:_currentHeaderIndex field:@"path"],
+                      @"An archive header path is not valid UTF-8.");
+        return nil;
+    }
+    return path;
+}
+
+- (BOOL)registerNormalizedPath:(NSString *)path
+                     directory:(BOOL)directory
+                         error:(NSError **)error {
+    NSString *fieldPath = [self memberPathForIndex:_currentHeaderIndex field:@"path"];
+    if (_realTypesByPath[path] != nil) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorDuplicateEntry,
+                             fieldPath,
+                             @"An archive member path is duplicated.");
+    }
+
+    if (![path isEqualToString:@"."]) {
+        NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
+        NSMutableArray<NSString *> *parents = [NSMutableArray array];
+        for (NSUInteger index = 0; index + 1 < components.count; index++) {
+            [parents addObject:components[index]];
+            NSString *parent = [parents componentsJoinedByString:@"/"];
+            if ([_regularPaths containsObject:parent]) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorDuplicateEntry,
+                                     fieldPath,
+                                     @"An archive member is nested beneath a regular file.");
+            }
+            [_implicitDirectories addObject:parent];
+        }
+        if (!directory && [_implicitDirectories containsObject:path]) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorDuplicateEntry,
+                                 fieldPath,
+                                 @"A regular file conflicts with an existing parent path.");
+        }
+    }
+
+    _realTypesByPath[path] = directory ? @"d" : @"f";
+    if (!directory) {
+        [_regularPaths addObject:path];
+    }
+    return YES;
+}
+
+- (BOOL)processHeaderBlock:(const unsigned char *)block error:(NSError **)error {
+    if (PXArchiveBlockIsZero(block)) {
+        _zeroBlockCount++;
+        if (_zeroBlockCount == 2) {
+            if (_hasPendingPerEntryMetadata || _metadataNeedsFinalize) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                                     [self memberPathForIndex:_physicalHeaders field:nil],
+                                     @"Archive metadata is pending at the end marker.");
+            }
+            _afterEnd = YES;
+        }
+        return YES;
+    }
+    if (_zeroBlockCount != 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidHeader,
+                             [self memberPathForIndex:_physicalHeaders field:nil],
+                             @"A single zero block was not followed by the archive end marker.");
+    }
+
+    if (_physicalHeaders >= PXArchiveMaximumPhysicalHeaders) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorLimitExceeded,
+                             [self memberPathForIndex:_physicalHeaders field:nil],
+                             @"The archive physical-header limit was exceeded.");
+    }
+    _currentHeaderIndex = _physicalHeaders;
+    _physicalHeaders++;
+    NSString *headerPath = [self memberPathForIndex:_currentHeaderIndex field:nil];
+
+    if (!PXArchiveHeaderChecksumIsValid(block)) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidHeader,
+                             headerPath,
+                             @"An archive header checksum is invalid.");
+    }
+    BOOL ustar = NO;
+    if (!PXArchiveMagicIsSupported(block, &ustar)) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidHeader,
+                             headerPath,
+                             @"An archive header format is unsupported.");
+    }
+    uint64_t headerSize = 0;
+    uint64_t mode = 0;
+    uint64_t userID = 0;
+    uint64_t groupID = 0;
+    uint64_t modificationTime = 0;
+    if (!PXArchiveParseSizeField(block + 124, 12, &headerSize) ||
+        !PXArchiveParseOctal(block + 100, 8, &mode) ||
+        !PXArchiveParseOctal(block + 108, 8, &userID) ||
+        !PXArchiveParseOctal(block + 116, 8, &groupID) ||
+        !PXArchiveParseOctal(block + 136, 12, &modificationTime)) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidHeader,
+                             headerPath,
+                             @"An archive numeric header field is invalid.");
+    }
+    (void)userID;
+    (void)groupID;
+    (void)modificationTime;
+    char type = (char)block[156];
+
+    if (type == 'x' || type == 'g' || type == 'L' || type == 'K') {
+        if (headerSize > PXArchiveMaximumMetadataPayload) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorLimitExceeded,
+                                 headerPath,
+                                 @"An archive metadata payload exceeds the fixed limit.");
+        }
+        uint64_t metadataTotal = 0;
+        if (!PXArchiveAddUInt64(_metadataTotal, headerSize, &metadataTotal) ||
+            metadataTotal > PXArchiveMaximumMetadataTotal) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorLimitExceeded,
+                                 headerPath,
+                                 @"The archive metadata total exceeds the fixed limit.");
+        }
+        _metadataTotal = metadataTotal;
+        _metadataType = type;
+        _metadataPayload = [NSMutableData dataWithCapacity:(NSUInteger)headerSize];
+        _metadataNeedsFinalize = YES;
+        _payloadRemaining = headerSize;
+        _paddingRemaining = (PXTarBlockSize - (headerSize % PXTarBlockSize)) % PXTarBlockSize;
+        if (_payloadRemaining == 0 && _paddingRemaining == 0) {
+            return [self finalizeMetadataWithError:error];
+        }
+        return YES;
+    }
+
+    BOOL directory = type == '5';
+    BOOL regular = type == 0 || type == '0';
+    if (!regular && !directory) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorUnsupportedEntryType,
+                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
+                             @"An archive member type is unsupported.");
+    }
+    if (_pendingPAXLinkPath || _pendingGNULinkPath) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
+                             @"Link metadata cannot be attached to a regular or directory member.");
+    }
+    if ((mode & UINT64_C(06000)) != 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorUnsupportedEntryType,
+                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
+                             @"Set-user-ID and set-group-ID archive modes are unsupported.");
+    }
+
+    NSString *headerMemberPath = [self headerPathFromBlock:block ustar:ustar error:error];
+    if (!headerMemberPath) {
+        return NO;
+    }
+    NSString *effectivePath = _pendingPAXPath ?: _pendingGNUPath ?: headerMemberPath;
+    BOOL rootMarker = NO;
+    NSString *normalizedPath = PXArchiveNormalizeMemberPath(
+        effectivePath,
+        directory,
+        &rootMarker,
+        error,
+        [self memberPathForIndex:_currentHeaderIndex field:@"path"]);
+    if (!normalizedPath) {
+        return NO;
+    }
+    (void)rootMarker;
+
+    uint64_t effectiveSize = _pendingPAXSize
+        ? _pendingPAXSize.unsignedLongLongValue
+        : headerSize;
+    if (directory && effectiveSize != 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidHeader,
+                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
+                             @"A directory archive member must have zero size.");
+    }
+    if (regular && effectiveSize > PXArchiveMaximumRegularFileBytes) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorLimitExceeded,
+                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
+                             @"A regular archive member exceeds the fixed size limit.");
+    }
+    if (_logicalMembers >= PXArchiveMaximumLogicalMembers ||
+        (_restoreLogicalMembers &&
+         *_restoreLogicalMembers >= PXArchiveMaximumRestoreLogicalMembers)) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorLimitExceeded,
+                             headerPath,
+                             @"The archive logical-member limit was exceeded.");
+    }
+    if (![self registerNormalizedPath:normalizedPath directory:directory error:error]) {
+        return NO;
+    }
+
+    _logicalMembers++;
+    if (_restoreLogicalMembers) {
+        (*_restoreLogicalMembers)++;
+    }
+    if (regular) {
+        uint64_t regularTotal = 0;
+        if (!PXArchiveAddUInt64(_regularFileBytes, effectiveSize, &regularTotal) ||
+            regularTotal > _archiveBudget) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorLimitExceeded,
+                                 headerPath,
+                                 @"The archive regular-file byte total exceeds the fixed budget.");
+        }
+        _regularFileBytes = regularTotal;
+    }
+
+    [self clearPendingMetadata];
+    _payloadRemaining = effectiveSize;
+    _paddingRemaining = (PXTarBlockSize - (effectiveSize % PXTarBlockSize)) % PXTarBlockSize;
+    _metadataNeedsFinalize = NO;
+    _metadataPayload = nil;
+    _metadataType = 0;
+    return YES;
+}
+
+- (BOOL)completePayloadIfNeeded:(NSError **)error {
+    if (_payloadRemaining != 0 || _paddingRemaining != 0) {
+        return YES;
+    }
+    if (_metadataNeedsFinalize) {
+        return [self finalizeMetadataWithError:error];
+    }
+    return YES;
+}
+
+- (BOOL)consumeBytes:(const unsigned char *)bytes
+              length:(size_t)length
+               error:(NSError **)error {
+    size_t offset = 0;
+    while (offset < length) {
+        if (_afterEnd) {
+            for (size_t index = offset; index < length; index++) {
+                if (bytes[index] != 0) {
+                    return PXArchiveFail(error,
+                                         PXBackupArchiveValidatorErrorInvalidHeader,
+                                         [self memberPathForIndex:_physicalHeaders field:nil],
+                                         @"Nonzero decompressed data follows the archive end marker.");
+                }
+            }
+            return YES;
+        }
+
+        if (![self completePayloadIfNeeded:error]) {
+            return NO;
+        }
+        if (_payloadRemaining > 0) {
+            size_t available = length - offset;
+            size_t amount = _payloadRemaining < available
+                ? (size_t)_payloadRemaining
+                : available;
+            if (_metadataNeedsFinalize && amount > 0) {
+                [_metadataPayload appendBytes:bytes + offset length:amount];
+            }
+            _payloadRemaining -= amount;
+            offset += amount;
+            continue;
+        }
+        if (_paddingRemaining > 0) {
+            size_t available = length - offset;
+            size_t amount = _paddingRemaining < available
+                ? (size_t)_paddingRemaining
+                : available;
+            _paddingRemaining -= amount;
+            offset += amount;
+            continue;
+        }
+
+        size_t available = length - offset;
+        size_t needed = PXTarBlockSize - _headerUsed;
+        size_t amount = available < needed ? available : needed;
+        memcpy(_headerBlock + _headerUsed, bytes + offset, amount);
+        _headerUsed += amount;
+        offset += amount;
+        if (_headerUsed == PXTarBlockSize) {
+            _headerUsed = 0;
+            if (![self processHeaderBlock:_headerBlock error:error]) {
+                return NO;
+            }
+        }
+    }
+    return [self completePayloadIfNeeded:error];
+}
+
+- (BOOL)finishWithError:(NSError **)error {
+    if (_payloadRemaining != 0 || _paddingRemaining != 0 ||
+        _headerUsed != 0 || _metadataNeedsFinalize) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorTruncatedArchive,
+                             [self memberPathForIndex:_physicalHeaders field:nil],
+                             @"The archive ended within a header, payload or padding region.");
+    }
+    if (!_afterEnd || _zeroBlockCount < 2) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorTruncatedArchive,
+                             [self memberPathForIndex:_physicalHeaders field:nil],
+                             @"The archive is missing its two-block end marker.");
+    }
+    if (_hasPendingPerEntryMetadata || _pendingPAXPath || _pendingPAXSize ||
+        _pendingPAXLinkPath || _pendingGNUPath || _pendingGNULinkPath) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
+                             [self memberPathForIndex:_physicalHeaders field:nil],
+                             @"Archive metadata is pending at end of stream.");
+    }
+    return YES;
+}
+
+@end
+
+static BOOL PXArchiveInflateChunk(z_stream *stream,
+                                  const unsigned char *input,
+                                  size_t inputLength,
+                                  PXArchiveTarParser *parser,
+                                  uint64_t archiveBudget,
+                                  uint64_t *archiveInflated,
+                                  uint64_t *restoreInflated,
+                                  BOOL *streamEnded,
+                                  NSString *fieldPath,
+                                  NSError **error) {
+    stream->next_in = (Bytef *)input;
+    stream->avail_in = (uInt)inputLength;
+    unsigned char output[64 * 1024];
+
+    for (;;) {
+        uInt beforeInput = stream->avail_in;
+        stream->next_out = output;
+        stream->avail_out = (uInt)sizeof(output);
+        int status = inflate(stream, Z_NO_FLUSH);
+        size_t produced = sizeof(output) - stream->avail_out;
+        if (produced > 0) {
+            uint64_t nextArchiveInflated = 0;
+            uint64_t nextRestoreInflated = 0;
+            if (!PXArchiveAddUInt64(*archiveInflated,
+                                    (uint64_t)produced,
+                                    &nextArchiveInflated) ||
+                nextArchiveInflated > archiveBudget ||
+                !PXArchiveAddUInt64(*restoreInflated,
+                                    (uint64_t)produced,
+                                    &nextRestoreInflated) ||
+                nextRestoreInflated > PXArchiveMaximumRestoreInflatedBytes) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorLimitExceeded,
+                                     fieldPath,
+                                     @"The decompressed archive stream exceeds the fixed budget.");
+            }
+            *archiveInflated = nextArchiveInflated;
+            *restoreInflated = nextRestoreInflated;
+            if (![parser consumeBytes:output length:produced error:error]) {
+                return NO;
+            }
+        }
+        if (status == Z_STREAM_END) {
+            if (stream->avail_in != 0) {
+                return PXArchiveFail(error,
+                                     PXBackupArchiveValidatorErrorUnsupportedCompression,
+                                     fieldPath,
+                                     @"The gzip stream contains concatenated or trailing data.");
+            }
+            *streamEnded = YES;
+            return YES;
+        }
+        if (status == Z_BUF_ERROR) {
+            if (stream->avail_in == 0 && produced == 0) {
+                return YES;
+            }
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorTruncatedArchive,
+                                 fieldPath,
+                                 @"The gzip stream is incomplete.");
+        }
+        if (status != Z_OK) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorUnsupportedCompression,
+                                 fieldPath,
+                                 @"The gzip stream is invalid.");
+        }
+        if (produced == 0 && stream->avail_in == beforeInput) {
+            if (stream->avail_in == 0) {
+                return YES;
+            }
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorUnsupportedCompression,
+                                 fieldPath,
+                                 @"The gzip decoder made no progress.");
+        }
+        if (stream->avail_in == 0 && stream->avail_out != 0) {
+            return YES;
+        }
+        // Continue when compressed input remains or a full output buffer may
+        // have left additional decompressed bytes pending inside zlib.
+    }
+}
+
+static ssize_t PXArchiveReadRetry(int descriptor, void *buffer, size_t length) {
+    for (;;) {
+        ssize_t result = read(descriptor, buffer, length);
+        if (result < 0 && errno == EINTR) {
+            continue;
+        }
+        return result;
+    }
+}
+
+static BOOL PXArchiveValidateOne(PXArchiveReference *reference,
+                                 NSString *canonicalRoot,
+                                 int rootDescriptor,
+                                 uint64_t *restoreInflated,
+                                 uint64_t *restoreLogicalMembers,
+                                 NSNumber **memberCountOut,
+                                 NSNumber **regularFileBytesOut,
+                                 NSError **error) {
+    PXArchiveDeclaration *declaration = reference.declaration;
+    NSString *fieldPath = reference.fieldPath;
+    NSString *expectedCanonicalPath = [NSString stringWithFormat:@"%@/%@",
+                                       canonicalRoot,
+                                       declaration.name];
+    if (![reference.verifiedPath isEqualToString:expectedCanonicalPath]) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInconsistentManifest,
+                             fieldPath,
+                             @"The verified archive path does not match the selected backup root.");
+    }
+
+    int descriptor = -1;
+    struct stat beforeStatus;
+    if (!PXArchiveOpenRelativeFile(rootDescriptor,
+                                   declaration.name,
+                                   fieldPath,
+                                   &descriptor,
+                                   &beforeStatus,
+                                   error)) {
+        return NO;
+    }
+
+    BOOL success = NO;
+    z_stream stream;
+    memset(&stream, 0, sizeof(stream));
+    BOOL inflateInitialized = NO;
+    do {
+        if (beforeStatus.st_size < 0 ||
+            (uint64_t)beforeStatus.st_size != declaration.expectedCompressedSize) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorSizeMismatch,
+                          fieldPath,
+                          @"The compressed archive size does not match its declaration.");
+            break;
+        }
+
+        uint64_t archiveBudget = PXArchiveInflatedBudget(declaration.expectedCompressedSize);
+        PXArchiveTarParser *parser = [[PXArchiveTarParser alloc]
+            initWithArtifactIndex:declaration.originalIndex
+                    archiveBudget:archiveBudget
+           restoreLogicalMembers:restoreLogicalMembers];
+
+        int initializeStatus = inflateInit2(&stream, 16 + MAX_WBITS);
+        if (initializeStatus != Z_OK) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorUnsupportedCompression,
+                          fieldPath,
+                          @"The gzip decoder could not be initialized.");
+            break;
+        }
+        inflateInitialized = YES;
+
+        CC_SHA256_CTX digestContext;
+        CC_SHA256_Init(&digestContext);
+        uint64_t compressedRead = 0;
+        uint64_t archiveInflated = 0;
+        BOOL streamEnded = NO;
+
+        unsigned char prefix[3];
+        size_t prefixUsed = 0;
+        while (prefixUsed < sizeof(prefix)) {
+            ssize_t amount = PXArchiveReadRetry(descriptor,
+                                                prefix + prefixUsed,
+                                                sizeof(prefix) - prefixUsed);
+            if (amount < 0) {
+                PXArchiveFail(error,
+                              PXBackupArchiveValidatorErrorReadFailed,
+                              fieldPath,
+                              @"The compressed archive could not be read.");
+                break;
+            }
+            if (amount == 0) {
+                PXArchiveFail(error,
+                              PXBackupArchiveValidatorErrorTruncatedArchive,
+                              fieldPath,
+                              @"The compressed archive ended before its gzip header.");
+                break;
+            }
+            prefixUsed += (size_t)amount;
+            if (!PXArchiveAddUInt64(compressedRead,
+                                    (uint64_t)amount,
+                                    &compressedRead) ||
+                compressedRead > declaration.expectedCompressedSize) {
+                PXArchiveFail(error,
+                              PXBackupArchiveValidatorErrorSizeMismatch,
+                              fieldPath,
+                              @"The compressed archive byte count is inconsistent.");
+                break;
+            }
+            CC_SHA256_Update(&digestContext,
+                             prefix + (prefixUsed - (size_t)amount),
+                             (CC_LONG)amount);
+        }
+        if (prefixUsed != sizeof(prefix)) {
+            break;
+        }
+        if (prefix[0] != 0x1f || prefix[1] != 0x8b || prefix[2] != Z_DEFLATED) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorUnsupportedCompression,
+                          fieldPath,
+                          @"The archive is not a supported gzip deflate stream.");
+            break;
+        }
+        if (!PXArchiveInflateChunk(&stream,
+                                   prefix,
+                                   sizeof(prefix),
+                                   parser,
+                                   archiveBudget,
+                                   &archiveInflated,
+                                   restoreInflated,
+                                   &streamEnded,
+                                   fieldPath,
+                                   error)) {
+            break;
+        }
+        if (streamEnded) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorTruncatedArchive,
+                          fieldPath,
+                          @"The gzip stream ended before a complete tar stream.");
+            break;
+        }
+
+        unsigned char input[64 * 1024];
+        BOOL readFailure = NO;
+        while (!streamEnded) {
+            ssize_t amount = PXArchiveReadRetry(descriptor, input, sizeof(input));
+            if (amount < 0) {
+                PXArchiveFail(error,
+                              PXBackupArchiveValidatorErrorReadFailed,
+                              fieldPath,
+                              @"The compressed archive could not be read.");
+                readFailure = YES;
+                break;
+            }
+            if (amount == 0) {
+                PXArchiveFail(error,
+                              PXBackupArchiveValidatorErrorTruncatedArchive,
+                              fieldPath,
+                              @"The gzip stream ended before Z_STREAM_END.");
+                readFailure = YES;
+                break;
+            }
+            if (!PXArchiveAddUInt64(compressedRead,
+                                    (uint64_t)amount,
+                                    &compressedRead) ||
+                compressedRead > declaration.expectedCompressedSize) {
+                PXArchiveFail(error,
+                              PXBackupArchiveValidatorErrorSizeMismatch,
+                              fieldPath,
+                              @"The compressed archive byte count is inconsistent.");
+                readFailure = YES;
+                break;
+            }
+            CC_SHA256_Update(&digestContext, input, (CC_LONG)amount);
+            if (!PXArchiveInflateChunk(&stream,
+                                       input,
+                                       (size_t)amount,
+                                       parser,
+                                       archiveBudget,
+                                       &archiveInflated,
+                                       restoreInflated,
+                                       &streamEnded,
+                                       fieldPath,
+                                       error)) {
+                readFailure = YES;
+                break;
+            }
+        }
+        if (readFailure) {
+            break;
+        }
+        if (compressedRead != declaration.expectedCompressedSize) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorUnsupportedCompression,
+                          fieldPath,
+                          @"The gzip stream has trailing or concatenated compressed data.");
+            break;
+        }
+        if (![parser finishWithError:error]) {
+            break;
+        }
+
+        unsigned char compressedDigest[CC_SHA256_DIGEST_LENGTH];
+        CC_SHA256_Final(compressedDigest, &digestContext);
+        NSString *actualDigest = PXArchiveHexDigest(compressedDigest);
+
+        struct stat afterStatus;
+        if (fstat(descriptor, &afterStatus) != 0 ||
+            !PXArchiveStatIdentityEqual(&beforeStatus, &afterStatus)) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorFilesystemChanged,
+                          fieldPath,
+                          @"The compressed archive changed during validation.");
+            break;
+        }
+        if (compressedRead != (uint64_t)afterStatus.st_size) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorSizeMismatch,
+                          fieldPath,
+                          @"The compressed archive byte count does not match its file size.");
+            break;
+        }
+        if (![actualDigest isEqualToString:declaration.expectedDigest]) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorDigestMismatch,
+                          fieldPath,
+                          @"The compressed archive digest does not match its declaration.");
+            break;
+        }
+
+        struct stat pathStatus;
+        const char *canonicalPath = expectedCanonicalPath.fileSystemRepresentation;
+        if (!canonicalPath || lstat(canonicalPath, &pathStatus) != 0 ||
+            S_ISLNK(pathStatus.st_mode) || !S_ISREG(pathStatus.st_mode) ||
+            pathStatus.st_dev != afterStatus.st_dev ||
+            pathStatus.st_ino != afterStatus.st_ino) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorFilesystemChanged,
+                          fieldPath,
+                          @"The archive path identity changed during validation.");
+            break;
+        }
+
+        if (memberCountOut) {
+            *memberCountOut = @(parser.logicalMembers);
+        }
+        if (regularFileBytesOut) {
+            *regularFileBytesOut = @(parser.regularFileBytes);
+        }
+        success = YES;
+    } while (NO);
+
+    if (inflateInitialized) {
+        inflateEnd(&stream);
+    }
+    close(descriptor);
+    return success;
+}
+
+static BOOL PXArchiveBuildDeclarations(NSDictionary *manifest,
+                                       NSDictionary<NSString *, PXArchiveDeclaration *> **mapOut,
+                                       NSError **error) {
+    if (mapOut) {
+        *mapOut = nil;
+    }
+    id artifactsObject = manifest[@"artifacts"];
+    if (![artifactsObject isKindOfClass:[NSArray class]]) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             @"$.artifacts",
+                             @"The artifact declaration section is invalid.");
+    }
+    NSArray *artifacts = (NSArray *)artifactsObject;
+    NSMutableDictionary<NSString *, PXArchiveDeclaration *> *map =
+        [NSMutableDictionary dictionaryWithCapacity:artifacts.count];
+    for (NSUInteger index = 0; index < artifacts.count; index++) {
+        NSString *entryPath = PXArchiveIndexedPath(@"$.artifacts", index);
+        id entryObject = artifacts[index];
+        if (![entryObject isKindOfClass:[NSDictionary class]]) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 entryPath,
+                                 @"An artifact declaration is invalid.");
+        }
+        NSDictionary *entry = (NSDictionary *)entryObject;
+        id nameObject = entry[@"name"];
+        uint64_t expectedSize = 0;
+        if (!PXArchiveArtifactNameIsSafe(nameObject)) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 PXArchiveFieldPath(entryPath, @"name"),
+                                 @"An artifact name is invalid.");
+        }
+        NSString *name = (NSString *)nameObject;
+        if (map[name] != nil) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInconsistentManifest,
+                                 PXArchiveFieldPath(entryPath, @"name"),
+                                 @"An artifact declaration name is duplicated.");
+        }
+        if (!PXArchiveNonnegativeIntegralNumber(entry[@"size"], &expectedSize)) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 PXArchiveFieldPath(entryPath, @"size"),
+                                 @"An artifact compressed size is invalid.");
+        }
+        if (!PXArchiveDigestIsValid(entry[@"sha256"])) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 PXArchiveFieldPath(entryPath, @"sha256"),
+                                 @"An artifact compressed digest is invalid.");
+        }
+        PXArchiveDeclaration *declaration = [[PXArchiveDeclaration alloc] init];
+        declaration.originalIndex = index;
+        declaration.name = name;
+        declaration.expectedCompressedSize = expectedSize;
+        declaration.expectedDigest = entry[@"sha256"];
+        map[name] = declaration;
+    }
+    if (mapOut) {
+        *mapOut = [map copy];
+    }
+    return YES;
+}
+
+static BOOL PXArchiveAddReference(id nameObject,
+                                  NSString *fieldPath,
+                                  NSDictionary<NSString *, PXArchiveDeclaration *> *declarations,
+                                  PXVerifiedBackupArtifactSet *verifiedArtifacts,
+                                  NSMutableSet<NSString *> *seen,
+                                  NSMutableArray<PXArchiveReference *> *references,
+                                  NSError **error) {
+    if (!PXArchiveArtifactNameIsSafe(nameObject)) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             fieldPath,
+                             @"An archive reference is invalid.");
+    }
+    NSString *name = (NSString *)nameObject;
+    if ([seen containsObject:name]) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInconsistentManifest,
+                             fieldPath,
+                             @"An archive is referenced more than once.");
+    }
+    PXArchiveDeclaration *declaration = declarations[name];
+    if (!declaration) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorMissingArchive,
+                             fieldPath,
+                             @"An archive reference has no artifact declaration.");
+    }
+    NSString *verifiedPath = [verifiedArtifacts pathForArtifactName:name];
+    if (verifiedPath.length == 0) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorMissingArchive,
+                             fieldPath,
+                             @"An archive reference is absent from the verified artifact set.");
+    }
+    if (references.count >= PXArchiveMaximumReferences) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorLimitExceeded,
+                             fieldPath,
+                             @"The archive-reference count exceeds the fixed limit.");
+    }
+    PXArchiveReference *reference = [[PXArchiveReference alloc] init];
+    reference.fieldPath = fieldPath;
+    reference.declaration = declaration;
+    reference.verifiedPath = verifiedPath;
+    [references addObject:reference];
+    [seen addObject:name];
+    return YES;
+}
+
+static BOOL PXArchiveCollectReferences(NSDictionary *manifest,
+                                       NSDictionary<NSString *, PXArchiveDeclaration *> *declarations,
+                                       PXVerifiedBackupArtifactSet *verifiedArtifacts,
+                                       NSArray<PXArchiveReference *> **referencesOut,
+                                       NSError **error) {
+    if (referencesOut) {
+        *referencesOut = nil;
+    }
+    NSMutableArray<PXArchiveReference *> *references = [NSMutableArray array];
+    NSMutableSet<NSString *> *seen = [NSMutableSet set];
+
+    id dataObject = manifest[@"data"];
+    if (![dataObject isKindOfClass:[NSDictionary class]] ||
+        !PXArchiveAddReference(((NSDictionary *)dataObject)[@"archive"],
+                               @"$.data.archive",
+                               declarations,
+                               verifiedArtifacts,
+                               seen,
+                               references,
+                               error)) {
+        if (![dataObject isKindOfClass:[NSDictionary class]] && error && !*error) {
+            PXArchiveFail(error,
+                          PXBackupArchiveValidatorErrorInvalidInput,
+                          @"$.data",
+                          @"The data archive section is invalid.");
+        }
+        return NO;
+    }
+
+    id groupsObject = manifest[@"appGroups"];
+    if (![groupsObject isKindOfClass:[NSArray class]]) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             @"$.appGroups",
+                             @"The App Group archive section is invalid.");
+    }
+    NSArray *groups = (NSArray *)groupsObject;
+    for (NSUInteger index = 0; index < groups.count; index++) {
+        NSString *entryPath = PXArchiveIndexedPath(@"$.appGroups", index);
+        id entryObject = groups[index];
+        if (![entryObject isKindOfClass:[NSDictionary class]] ||
+            !PXArchiveAddReference(((NSDictionary *)entryObject)[@"archive"],
+                                   PXArchiveFieldPath(entryPath, @"archive"),
+                                   declarations,
+                                   verifiedArtifacts,
+                                   seen,
+                                   references,
+                                   error)) {
+            if (![entryObject isKindOfClass:[NSDictionary class]] && error && !*error) {
+                PXArchiveFail(error,
+                              PXBackupArchiveValidatorErrorInvalidInput,
+                              entryPath,
+                              @"An App Group archive entry is invalid.");
+            }
+            return NO;
+        }
+    }
+
+    NSArray<NSString *> *optionalSections = @[@"profileAppData", @"globalSafari"];
+    for (NSString *sectionName in optionalSections) {
+        NSString *sectionPath = [@"$." stringByAppendingString:sectionName];
+        id sectionObject = manifest[sectionName];
+        if (![sectionObject isKindOfClass:[NSDictionary class]]) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 sectionPath,
+                                 @"An optional archive section is invalid.");
+        }
+        NSDictionary *section = (NSDictionary *)sectionObject;
+        BOOL included = NO;
+        if (!PXArchiveExactBoolean(section[@"included"], &included)) {
+            return PXArchiveFail(error,
+                                 PXBackupArchiveValidatorErrorInvalidInput,
+                                 PXArchiveFieldPath(sectionPath, @"included"),
+                                 @"An optional archive inclusion flag is invalid.");
+        }
+        if (included &&
+            !PXArchiveAddReference(section[@"archive"],
+                                   PXArchiveFieldPath(sectionPath, @"archive"),
+                                   declarations,
+                                   verifiedArtifacts,
+                                   seen,
+                                   references,
+                                   error)) {
+            return NO;
+        }
+    }
+
+    id systemObject = manifest[@"systemGlobalLibrary"];
+    if (![systemObject isKindOfClass:[NSDictionary class]]) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             @"$.systemGlobalLibrary",
+                             @"The system-global archive section is invalid.");
+    }
+    NSDictionary *system = (NSDictionary *)systemObject;
+    BOOL systemIncluded = NO;
+    if (!PXArchiveExactBoolean(system[@"included"], &systemIncluded)) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             @"$.systemGlobalLibrary.included",
+                             @"The system-global inclusion flag is invalid.");
+    }
+    id itemsObject = system[@"items"];
+    if (![itemsObject isKindOfClass:[NSArray class]]) {
+        return PXArchiveFail(error,
+                             PXBackupArchiveValidatorErrorInvalidInput,
+                             @"$.systemGlobalLibrary.items",
+                             @"The system-global archive items are invalid.");
+    }
+    if (systemIncluded) {
+        NSArray *items = (NSArray *)itemsObject;
+        for (NSUInteger index = 0; index < items.count; index++) {
+            NSString *entryPath = PXArchiveIndexedPath(@"$.systemGlobalLibrary.items", index);
+            id entryObject = items[index];
+            if (![entryObject isKindOfClass:[NSDictionary class]] ||
+                !PXArchiveAddReference(((NSDictionary *)entryObject)[@"archive"],
+                                       PXArchiveFieldPath(entryPath, @"archive"),
+                                       declarations,
+                                       verifiedArtifacts,
+                                       seen,
+                                       references,
+                                       error)) {
+                if (![entryObject isKindOfClass:[NSDictionary class]] && error && !*error) {
+                    PXArchiveFail(error,
+                                  PXBackupArchiveValidatorErrorInvalidInput,
+                                  entryPath,
+                                  @"A system-global archive entry is invalid.");
+                }
+                return NO;
+            }
+        }
+    }
+
+    [references sortUsingComparator:^NSComparisonResult(PXArchiveReference *left,
+                                                         PXArchiveReference *right) {
+        return [left.declaration.name compare:right.declaration.name];
+    }];
+    if (referencesOut) {
+        *referencesOut = [references copy];
+    }
+    return YES;
+}
+
+@implementation PXBackupArchiveValidator
+
++ (PXValidatedBackupArchiveSet *)validatedArchivesForManifest:(NSDictionary *)manifest
+                                              backupDirectory:(NSString *)backupDirectory
+                                            verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
+                                                        error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (![manifest isKindOfClass:[NSDictionary class]] ||
+        !PXArchiveStringInputIsValid(backupDirectory) ||
+        ![verifiedArtifacts isKindOfClass:[PXVerifiedBackupArtifactSet class]]) {
+        PXArchiveFail(error,
+                      PXBackupArchiveValidatorErrorInvalidInput,
+                      @"$",
+                      @"The archive validation request is invalid.");
+        return nil;
+    }
+
+    NSDictionary<NSString *, PXArchiveDeclaration *> *declarations = nil;
+    if (!PXArchiveBuildDeclarations(manifest, &declarations, error)) {
+        return nil;
+    }
+    NSArray<PXArchiveReference *> *references = nil;
+    if (!PXArchiveCollectReferences(manifest,
+                                    declarations,
+                                    verifiedArtifacts,
+                                    &references,
+                                    error)) {
+        return nil;
+    }
+
+    NSString *canonicalRoot = nil;
+    int rootDescriptor = -1;
+    if (!PXArchiveOpenCanonicalBackupRoot(backupDirectory,
+                                          &canonicalRoot,
+                                          &rootDescriptor,
+                                          error)) {
+        return nil;
+    }
+
+    NSMutableDictionary<NSString *, NSNumber *> *memberCounts =
+        [NSMutableDictionary dictionaryWithCapacity:references.count];
+    NSMutableDictionary<NSString *, NSNumber *> *regularFileBytes =
+        [NSMutableDictionary dictionaryWithCapacity:references.count];
+    uint64_t restoreInflated = 0;
+    uint64_t restoreLogicalMembers = 0;
+    BOOL valid = YES;
+    for (PXArchiveReference *reference in references) {
+        NSNumber *memberCount = nil;
+        NSNumber *regularBytes = nil;
+        if (!PXArchiveValidateOne(reference,
+                                  canonicalRoot,
+                                  rootDescriptor,
+                                  &restoreInflated,
+                                  &restoreLogicalMembers,
+                                  &memberCount,
+                                  &regularBytes,
+                                  error)) {
+            valid = NO;
+            break;
+        }
+        memberCounts[reference.declaration.name] = memberCount;
+        regularFileBytes[reference.declaration.name] = regularBytes;
+    }
+    close(rootDescriptor);
+    if (!valid) {
+        return nil;
+    }
+
+    return [[PXValidatedBackupArchiveSet alloc]
+        initWithMemberCounts:memberCounts
+            regularFileBytes:regularFileBytes];
+}
+
+@end
```

## 18. Whitespace, generated-file, and build audit

- `git diff --check`: PASS.
- New validator files use LF, contain zero NUL bytes, and have zero trailing-whitespace lines.
- Added manager/Makefile lines have zero trailing whitespace; their existing line-ending conventions are preserved.
- No generated binary, temporary tar, object file, cache, or fixture was added.
- Local Objective-C/Theos build was not run because this Windows workspace has no `clang`, `clang-cl`, `make`, or `xcrun`.
- No compile, GitHub Actions, target-device, zlib-version, filesystem-race, or archive-fixture runtime pass is claimed.

## 19. Remaining runtime risks

- Device validation remains necessary for Darwin `openat`/`O_NOFOLLOW` behavior, zlib runtime compatibility, CommonCrypto linkage, and real gzip/tar producer fixtures.
- Static inspection cannot force every concurrent filesystem race timing or prove performance on maximum-size archives.
- TASK-2.6 validates a snapshot before extraction; later immutable planning and transaction/rollback work remain assigned to subsequent tasks.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
