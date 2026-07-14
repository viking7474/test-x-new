# TASK-2.5 REPORT — Common Backup Artifact Verifier

## 1. Baseline and exact scope

- Required baseline and verified initial HEAD: `c1d9067bab57085f71fb59443e81506c32237e3a`.
- Previous TASK-2.4 source review: ACCEPTED.
- Production scope: `PXBackupArtifactVerifier.h`, `PXBackupArtifactVerifier.m`, `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-2.5-REPORT.md`.
- Coordinator-owned documentation/specification/review files were not edited or staged.

Initial `git status --short --untracked-files=all`:

```text
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
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
```

Initial `git log -3 --oneline`:

```text
c1d9067 phase2(task-2.4): remove recorded destination fallbacks
1c5eda0 phase2(task-2.3): enforce exact restore bundle identity
9727a0a phase2(task-2.2): enforce supported manifest versions
```

## 2. Protected SHA-256 before/after

| Protected file | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | PASS |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | PASS |
| `PXBackupManifestValidator.m` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | PASS |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | PASS |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | PASS |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | PASS |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | PASS |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | PASS |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | PASS |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | PASS |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | PASS |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | PASS |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | PASS |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | PASS |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | PASS |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | PASS |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | PASS |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | PASS |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | PASS |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | PASS |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | PASS |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | PASS |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | PASS |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | PASS |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | PASS |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | PASS |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | PASS |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | PASS |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | PASS |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | PASS |

`git diff --exit-code -- <protected files>`: PASS.

## 3. Exact public API and error enum

- Header matches the specification byte-for-byte after LF normalization.
- One exported error domain and one exported field-path key.
- Exactly 13 closed error codes, numbered 1 through 13.
- One immutable `PXVerifiedBackupArtifactSet` result class.
- One public verifier method: `verifiedArtifactsForManifest:backupDirectory:error:`.
- No alternate file-path API, bypass flag, warning mode, shell API or archive parser.

Failure `userInfo` is constructed centrally and contains only:

```text
NSLocalizedDescriptionKey
PXBackupArtifactVerifierErrorFieldPathKey
```

Descriptions and field paths are generic/stable and never interpolate artifact names, recorded paths, backup directory, canonical path, digest, sizes, bundle ID, group ID, errno or raw manifest excerpts.

## 4. Immutable result proof

- Copies the canonical name-to-path dictionary at initialization.
- Derives `artifactNames` from copied keys and sorts with exact `compare:`.
- Public properties are readonly/copy.
- `pathForArtifactName:` returns nil for non-string, empty or unknown lookup.
- `copyWithZone:` returns self.
- No descriptor, callback, mutable collection, cache or lazy verification state is retained.

## 5. Relative-name policy and recorded-path non-authority

Artifact identity is exclusively `artifact[@"name"]`. The verifier contains zero reads of `artifact[@"path"]` or equivalent key access.

Accepted names are nonempty, non-whitespace, NUL-free relative Unix paths with no leading/trailing slash, doubled slash, empty component, `.` or `..`. No trim, case conversion, standardization, symlink resolution, percent decoding or tilde expansion occurs. Backslash remains an ordinary Unix filename character.

This means a copied/moved backup remains valid even when every recorded absolute `path` is stale.

## 6. Reference inventory and deterministic order

References are collected in this exact order:

1. `$.data.archive`;
2. `$.appGroups[i].archive` in array order;
3. `$.preferences.archive` when included;
4. `$.keychain.archive` when included;
5. `$.profileAppData.archive` when included;
6. `$.globalSafari.archive` when included;
7. `$.systemGlobalLibrary.items[i].archive` when included;
8. `$.sharedSystemDB.files[i].archive` when included.

Each reference is safe-name checked, duplicate cross-section references fail at the later field path, and missing declarations fail closed. Declarations are validated in original array order, retain original indexes, then are sorted by exact name for filesystem verification. Unreferenced declarations are still fully verified.

## 7. Descriptor-relative filesystem and symlink proof

- Strips only trailing backup-directory separators for final-component inspection.
- `lstat` rejects a final root symlink and requires a directory.
- Opens the raw final root with `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC` and compares lstat/open identities.
- Canonicalizes with `realpath`, opens the canonical root descriptor, and compares raw/canonical identities.
- Ancestor aliases such as `/var -> /private/var` remain allowed.
- Walks parent components with descriptor-relative `openat` plus `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`.
- Opens final artifacts with `O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC`; `O_NONBLOCK` prevents FIFO hangs before fstat rejects non-regular objects.
- Every parent, artifact, raw-root and canonical-root descriptor has an explicit close path.
- Canonical result paths are built beneath the canonical root and checked with a slash boundary.

## 8. Regular file, exact size and SHA-256 proof

- `fstat` requires a regular file before hashing.
- Size accepts only non-CFBoolean integral NSNumber encodings, rejects floating/coerced values, and compares exactly including expected zero.
- Every digest must be exactly 64 ASCII lowercase hexadecimal characters.
- SHA-256 uses CommonCrypto over a bounded 64 KiB streaming buffer.
- `EINTR` retries; other read failures become `DigestReadFailed`.
- No NSData whole-file loading, shell, `sha256sum`, OpenSSL, NSTask, CommandRunner or helper process.

## 9. Before/after identity stability

The same opened descriptor is fstat-ed before and after hashing. Device, inode, regular-file type, size, mtime and ctime must remain unchanged; atime is intentionally ignored. A change fails with `FilesystemChanged` before digest mismatch classification.

## 10. Aggregate consistency

- Optional `totalSize` is parsed as an exact integral value and must equal overflow-checked declared and actual verified sums.
- Optional `archiveChecksum` must be a complete lowercase SHA-256 and equal both the declared and actual verified digest of the artifact referenced by `data.archive`.
- Version 2 manifests may omit both optional fields.
- `artifactCount` remains owned by TASK-2.1 schema validation and is not redefined here.

## 11. Restore ordering and exact error propagation

Restore order is now:

```text
parameter guard
common manifest read/schema/version
exact requested bundle match
TASK-2.4 exact destination resolution
common artifact verifier
artifact failure callback/return
warnings / NSFileManager / CommandRunner / debug / tar / kill / extraction / mutation
```

The verifier is called exactly once. A non-nil verifier NSError is propagated directly. Artifact failure dispatches one `completion(nil, err)` on the main queue and returns before operational side effects.

## 12. Verified-path inventory and legacy removal

| Restore component | Manifest identity | Source path |
|---|---|---|
| Main ApplicationData | `data.archive` | `pathForArtifactName:dataArchiveName` |
| App Group | exact `groupID -> appGroups[].archive` | `pathForArtifactName:archiveName` before group wipe |
| Preferences | `preferences.archive` | `pathForArtifactName:prefArchiveName` |
| Keychain | `keychain.archive` | `pathForArtifactName:keychainArchiveName` |
| Profile app data | `profileAppData.archive` | `pathForArtifactName:archiveName` |
| Global Safari | `globalSafari.archive` | `pathForArtifactName:archiveName` |
| System-global item | `items[i].archive` | `pathForArtifactName:archive` |
| Shared system DB | `files[i].archive` | `pathForArtifactName:archiveRel` |

An entitled/resolved App Group without an exact manifest mapping warns and continues before debug/wipe. Sanitized computed filenames no longer authorize Restore input.

Removed from Restore: `artByName`, best-effort `PXVerifyArtifact`, artifact warning prefix, manual data existence/size/hash blocks, manager codes 305/314/315, hard-coded `data.tar.gz` source selection, and all backupDir-plus-archive joins. Only three debug-file joins remain.

## 13. TASK-2.1 through TASK-2.4 and later-boundary proof

Byte-identical body hashes:

```text
PXBackupManifestVersionIsSupported: 344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7
readManifestAtBackupDirectory:error: f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff
PXResolveExactRestoreApplicationDataTarget: b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40
createBackupForBundleID:...: d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede
PXVerifyArtifact: 20bb62665e7878704ffb5565de49849402631c72d5cba40cc3868dd46b312a1f
```

Preserved: exact versions `{2,3}`, validator error propagation/code 201, exact bundle comparison/code 304, exact destination helper/code 303, retained canonical destination and pre-mutation revalidation, Backup writer version 3, recorded source path/UUID fields, and Backup PXVerifyArtifact self-check.

Not implemented: archive-member inspection/TASK-2.6, PXRestorePlan, staging redesign, rollback/transaction or structured result changes.

## 14. Static gate table

Machine source gate result: **188/188 PASS**.

| Gate | Result |
|---|---|
| Exact public header and 13 enum values | PASS |
| Implementation import isolation | PASS |
| Centralized two-key errors | PASS |
| Recorded path authority | 0 / PASS |
| Safe relative-name policy | PASS |
| Declaration/reference deterministic order | PASS |
| Raw and canonical root descriptor identity | PASS |
| openat/O_NOFOLLOW traversal | PASS |
| Regular-file fstat | PASS |
| Exact zero-inclusive size | PASS |
| 64 lowercase hex SHA-256 | PASS |
| Streaming/EINTR handling | PASS |
| Before/after identity comparison | PASS |
| Descriptor cleanup source paths | PASS |
| totalSize/archiveChecksum consistency | PASS |
| Verifier forbidden APIs/mutation/logging | 0 / PASS |
| Restore verifier calls | 1 / PASS |
| Backup verifier calls | 0 / PASS |
| Restore pathForArtifactName lookups | 8 / PASS |
| Restore PXVerifyArtifact calls | 0 / PASS |
| Legacy codes 305/314/315 | 0 / PASS |
| Restore artifact backupDir joins | 0 / PASS |
| App Group lookup-before-wipe | PASS |
| Backup self-check retained | PASS |
| Protected production diffs | 0 / PASS |
| Makefile diff | 0 / PASS |
| Archive-entry additions | 0 / PASS |
| Restore-plan/transaction additions | 0 / PASS |

## 15. Scenario matrix

These rows are explicit static/source contract coverage. Rows marked device/race/fault-injection required do not claim runtime execution.

| # | Scenario | Required outcome | Evidence |
|---:|---|---|---|
| 1 | Valid v2 manifest with complete hashes | Accept when every declaration/reference/file/size/digest is valid and optional aggregates are absent. | STATIC CONTRACT; device fixture required. |
| 2 | Valid v3 manifest with aggregate metadata | Accept when totalSize and archiveChecksum exactly match declared and verified data. | STATIC CONTRACT; device fixture required. |
| 3 | Moved backup with stale absolute recorded paths | Ignore every artifact path field and resolve only relative name below selected backup root. | SOURCE PASS. |
| 4 | Absolute artifact name | Reject /data.tar.gz as UnsafeRelativePath. | SOURCE PASS. |
| 5 | Leading slash | Reject any name beginning with /. | SOURCE PASS. |
| 6 | Trailing slash | Reject groups/ as UnsafeRelativePath. | SOURCE PASS. |
| 7 | Doubled slash | Reject groups//a.tar.gz. | SOURCE PASS. |
| 8 | Dot component | Reject groups/./a.tar.gz. | SOURCE PASS. |
| 9 | Dot-dot component | Reject groups/../a.tar.gz and ../data.tar.gz. | SOURCE PASS. |
| 10 | NUL in artifact name | Reject before filesystem representation/open. | SOURCE PASS. |
| 11 | Whitespace-only artifact name | Reject as UnsafeRelativePath. | SOURCE PASS. |
| 12 | Backslash in Unix name | Treat backslash as an ordinary character, not a separator. | SOURCE PASS; runtime fixture required. |
| 13 | Percent-encoded slash text | Do not percent-decode; treat literal percent characters as filename text. | SOURCE PASS. |
| 14 | Tilde-prefixed name | Do not expand tilde. | SOURCE PASS. |
| 15 | Mixed-case name | Preserve exact case; no lowercase normalization. | SOURCE PASS. |
| 16 | Unicode artifact name exact | Preserve exact NSString value and filesystem representation. | STATIC CONTRACT; device fixture required. |
| 17 | Duplicate declaration exact name | Reject later artifacts[i].name with InconsistentManifest. | SOURCE PASS. |
| 18 | Case-distinct declarations | Treat names differing only by case as distinct declarations. | STATIC CONTRACT; filesystem behavior requires device fixture. |
| 19 | Declaration entry non-dictionary | Reject at $.artifacts[i] with InvalidInput. | SOURCE PASS. |
| 20 | Artifacts root not array | Reject at $.artifacts with InvalidInput. | SOURCE PASS. |
| 21 | Missing data declaration | Fail MissingArtifact at $.data.archive. | SOURCE PASS. |
| 22 | Missing App Group declaration | Fail MissingArtifact at later $.appGroups[i].archive. | SOURCE PASS. |
| 23 | Missing preferences declaration | Fail MissingArtifact when preferences.included is true. | SOURCE PASS. |
| 24 | Missing Keychain declaration | Fail MissingArtifact when keychain.included is true. | SOURCE PASS. |
| 25 | Missing profile declaration | Fail MissingArtifact when profileAppData.included is true. | SOURCE PASS. |
| 26 | Missing global Safari declaration | Fail MissingArtifact when globalSafari.included is true. | SOURCE PASS. |
| 27 | Missing system-global declaration | Fail MissingArtifact at exact item archive path. | SOURCE PASS. |
| 28 | Missing shared-DB declaration | Fail MissingArtifact at exact file archive path. | SOURCE PASS. |
| 29 | Duplicate data/App Group reference | Fail InvalidReference at later App Group reference. | SOURCE PASS. |
| 30 | Duplicate two App Group references | Fail InvalidReference at the later array index. | SOURCE PASS. |
| 31 | Duplicate preferences/Keychain reference | Fail InvalidReference at keychain.archive. | SOURCE PASS. |
| 32 | Duplicate optional/system reference | Fail at the later deterministic section reference. | SOURCE PASS. |
| 33 | Valid unreferenced declaration | Verify fully and include in immutable result. | SOURCE PASS. |
| 34 | Missing physical unreferenced artifact | Fail during sorted filesystem verification. | SOURCE PASS; device fixture required. |
| 35 | Unreferenced digest mismatch | Fail DigestMismatch despite no Restore section reference. | SOURCE PASS; device fixture required. |
| 36 | Reference collection ordering | Data, App Groups, preferences, Keychain, profile, Safari, system, shared DB. | SOURCE PASS. |
| 37 | Declaration validation ordering | Validate declarations in original array order before reference checks. | SOURCE PASS. |
| 38 | Filesystem verification ordering | Sort accepted declarations by exact compare: name. | SOURCE PASS. |
| 39 | First declaration failure deterministic | Report the first invalid original array entry. | SOURCE PASS. |
| 40 | First filesystem failure deterministic | Report first failing sorted artifact name without exposing its value. | SOURCE PASS; device fixture required. |
| 41 | Absent backup directory | Fail FilesystemInspectionFailed at $. | SOURCE PASS; device fixture required. |
| 42 | Backup directory final symlink | Reject SymlinkRejected, including input with trailing slash. | SOURCE PASS; device fixture required. |
| 43 | Backup path ancestor alias | Allow /var-style ancestor alias and return canonical root spelling. | SOURCE PASS; device fixture required. |
| 44 | Backup root not directory | Fail before artifact traversal. | SOURCE PASS; device fixture required. |
| 45 | Backup root changes before raw open | Detect lstat/open inode mismatch as FilesystemChanged. | SOURCE PASS; race fixture required. |
| 46 | Backup root changes during canonicalization | Detect raw/canonical descriptor identity mismatch. | SOURCE PASS; race fixture required. |
| 47 | Symlink parent under backup root | openat O_NOFOLLOW traversal rejects parent. | SOURCE PASS; device fixture required. |
| 48 | Non-directory parent component | Fail descriptor-relative traversal. | SOURCE PASS; device fixture required. |
| 49 | Final artifact symlink | Reject through final O_NOFOLLOW open. | SOURCE PASS; device fixture required. |
| 50 | Final artifact directory | fstat rejects as NotRegularFile. | SOURCE PASS; device fixture required. |
| 51 | Final artifact FIFO | O_NONBLOCK prevents blocking; fstat rejects as NotRegularFile. | SOURCE PASS; device fixture required. |
| 52 | Final artifact socket | Open/fstat path rejects; never hashes. | SOURCE PASS; device fixture required. |
| 53 | Final artifact device | Reject non-regular file before read. | SOURCE PASS; device fixture required. |
| 54 | Parent open failure | Close any owned parent descriptor and fail closed. | SOURCE PASS. |
| 55 | Final open failure | Close parent descriptors and return fixed verifier error. | SOURCE PASS. |
| 56 | Initial fstat failure | Close final descriptor and fail FilesystemInspectionFailed. | SOURCE PASS. |
| 57 | Post-hash fstat failure | Close final descriptor and fail FilesystemInspectionFailed. | SOURCE PASS. |
| 58 | Descriptor cleanup on hash error | Caller closes final descriptor after DigestReadFailed. | SOURCE PASS. |
| 59 | Root descriptor cleanup on artifact failure | Close canonical root before returning nil. | SOURCE PASS. |
| 60 | Canonical boundary containment | Require canonicalRoot + slash component boundary. | SOURCE PASS. |
| 61 | Expected and actual size zero | Exact comparison accepts zero equals zero. | SOURCE PASS; device fixture required. |
| 62 | Expected zero, actual nonzero | Fail SizeMismatch. | SOURCE PASS; device fixture required. |
| 63 | Expected nonzero mismatch | Fail SizeMismatch at artifacts[i].size. | SOURCE PASS; device fixture required. |
| 64 | Boolean size | Reject exact CFBoolean as InvalidInput. | SOURCE PASS. |
| 65 | Floating size | Reject f/d Objective-C numeric representations. | SOURCE PASS. |
| 66 | Negative signed size | Reject before filesystem verification. | SOURCE PASS. |
| 67 | Unsigned size over comparable file range | Reject as InvalidInput. | SOURCE PASS. |
| 68 | Empty digest | Fail InvalidDigest. | SOURCE PASS. |
| 69 | Uppercase digest | Fail InvalidDigest. | SOURCE PASS. |
| 70 | Short digest | Fail InvalidDigest. | SOURCE PASS. |
| 71 | Long digest | Fail InvalidDigest. | SOURCE PASS. |
| 72 | Non-hex digest | Fail InvalidDigest. | SOURCE PASS. |
| 73 | Digest with whitespace | Fail InvalidDigest. | SOURCE PASS. |
| 74 | sha256: prefix | Fail InvalidDigest. | SOURCE PASS. |
| 75 | Streaming large artifact | Use bounded 64 KiB buffer, not whole-file NSData. | SOURCE PASS; performance fixture required. |
| 76 | EINTR during read | Retry without losing digest state. | SOURCE PASS; fault injection required. |
| 77 | Hard read failure | Fail DigestReadFailed. | SOURCE PASS; fault injection required. |
| 78 | Digest mismatch | Fail DigestMismatch only after stable post-hash fstat. | SOURCE PASS; device fixture required. |
| 79 | File replacement during hashing | Device/inode mismatch yields FilesystemChanged. | SOURCE PASS; race fixture required. |
| 80 | Regular type changes during hashing | Fail FilesystemChanged. | SOURCE PASS; race fixture required. |
| 81 | Size changes during hashing | Fail FilesystemChanged. | SOURCE PASS; race fixture required. |
| 82 | mtime changes during hashing | Fail FilesystemChanged. | SOURCE PASS; race fixture required. |
| 83 | ctime changes during hashing | Fail FilesystemChanged. | SOURCE PASS; race fixture required. |
| 84 | atime changes during hashing | Do not reject solely for atime. | SOURCE PASS; device fixture required. |
| 85 | totalSize exact | Accept exact declared and actual sums. | SOURCE PASS; device fixture required. |
| 86 | totalSize mismatch declared sum | Fail InconsistentManifest at $.totalSize. | SOURCE PASS. |
| 87 | totalSize mismatch actual sum | Fail InconsistentManifest at $.totalSize. | SOURCE PASS; device fixture required. |
| 88 | totalSize overflow | Fail InconsistentManifest when optional aggregate is present. | SOURCE PASS. |
| 89 | totalSize Boolean/floating | Fail InconsistentManifest. | SOURCE PASS. |
| 90 | archiveChecksum exact | Accept only exact data.archive declared and verified digest. | SOURCE PASS; device fixture required. |
| 91 | archiveChecksum empty | Fail InconsistentManifest. | SOURCE PASS. |
| 92 | archiveChecksum uppercase | Fail InconsistentManifest. | SOURCE PASS. |
| 93 | archiveChecksum mismatch declared data digest | Fail InconsistentManifest. | SOURCE PASS. |
| 94 | archiveChecksum mismatch actual digest | Fail InconsistentManifest. | SOURCE PASS. |
| 95 | v2 optional aggregate fields absent | Accept after per-artifact verification. | SOURCE PASS; device fixture required. |
| 96 | Stable error field path | Return schema path such as $.artifacts[i].sha256. | SOURCE PASS. |
| 97 | No raw values in verifier error | Only localized description and field-path key. | SOURCE PASS. |
| 98 | No nested POSIX error | Do not expose errno or underlying error. | SOURCE PASS. |
| 99 | Success clears prior NSError | Set *error nil at entry and leave nil. | SOURCE PASS. |
| 100 | Immutable sorted artifactNames | Expose names sorted by compare:. | SOURCE PASS. |
| 101 | Immutable canonical map | Copy local mutable dictionary into result. | SOURCE PASS. |
| 102 | copyWithZone behavior | Return self. | SOURCE PASS. |
| 103 | Unknown lookup | Return nil. | SOURCE PASS. |
| 104 | Empty lookup | Return nil. | SOURCE PASS. |
| 105 | Non-string lookup at runtime | Return nil through runtime category check. | SOURCE PASS. |
| 106 | Artifact verification before warnings | Verifier call precedes warnings allocation. | SOURCE PASS. |
| 107 | Artifact verification before NSFileManager/runner | Verifier precedes operational setup. | SOURCE PASS. |
| 108 | Artifact verification before debug | No debug file write on artifact rejection. | SOURCE PASS. |
| 109 | Artifact verification before tar discovery | Artifact error has precedence over code 301. | SOURCE PASS. |
| 110 | Artifact verification before process kill | No target kill on artifact rejection. | SOURCE PASS. |
| 111 | Artifact verification before extraction/mutation | Fail before staging and target wipe. | SOURCE PASS. |
| 112 | Exact verifier NSError propagation | Use artifactError object directly when non-nil. | SOURCE PASS. |
| 113 | Main data verified source | manifest.data.archive -> verified path. | SOURCE PASS. |
| 114 | Profile appdata verified source | profileAppData.archive -> verified path. | SOURCE PASS. |
| 115 | Global Safari verified source | globalSafari.archive -> verified path. | SOURCE PASS. |
| 116 | System-global verified source | items[i].archive -> verified path. | SOURCE PASS. |
| 117 | Shared DB verified source | files[i].archive -> verified path. | SOURCE PASS. |
| 118 | Preferences verified source | preferences.archive -> verified path. | SOURCE PASS. |
| 119 | Keychain verified source | keychain.archive -> verified path. | SOURCE PASS. |
| 120 | App Group exact mapping | groupID -> manifest archive -> verified path. | SOURCE PASS. |
| 121 | Installed group absent from manifest mapping | Warn and continue before group wipe. | SOURCE PASS. |
| 122 | App Group mapping exists | Lookup verified path before debug/wipe/extract. | SOURCE PASS. |
| 123 | Sanitized App Group filename authority removed | No computed sanitized source path in Restore. | SOURCE PASS. |
| 124 | Restore backupDir artifact joins removed | Only three debug-file joins remain. | SOURCE PASS. |
| 125 | Legacy best-effort loop removed | No artByName, Restore PXVerifyArtifact or warning prefix. | SOURCE PASS. |
| 126 | Manual data existence check removed | No manager code 305 preflight. | SOURCE PASS. |
| 127 | Manual data size/hash checks removed | No manager codes 314/315. | SOURCE PASS. |
| 128 | Backup PXVerifyArtifact retained | Backup warning-only self-check remains byte-identical. | SOURCE PASS. |
| 129 | TASK-2.1 validator unchanged | Protected source hash/diff unchanged. | SOURCE PASS. |
| 130 | TASK-2.2 versions and read boundary | Exact {2,3}, code 201 and body hash retained. | SOURCE PASS. |
| 131 | TASK-2.3 bundle identity | Exact comparison and code 304 retained. | SOURCE PASS. |
| 132 | TASK-2.4 destination contract | Exact destination helper/code303 and revalidation retained. | SOURCE PASS. |
| 133 | Backup writer version and recorded fields | Writer remains v3 and emits path/UUID metadata. | SOURCE PASS. |
| 134 | No archive-entry inspection | No tar listing/libarchive/member validation added. | BOUNDARY PASS. |
| 135 | No PXRestorePlan | TASK-2.7 remains untouched. | BOUNDARY PASS. |
| 136 | No staging redesign | Current staging architecture retained. | BOUNDARY PASS. |
| 137 | No rollback/transaction | Later transactional tasks remain untouched. | BOUNDARY PASS. |
| 138 | No UI/controller changes | Protected UI diffs are zero. | SOURCE PASS. |
| 139 | No Makefile change | Existing root wildcard compiles new .m. | SOURCE PASS. |
| 140 | Generated/temp audit | Only target production/report files may enter commit; .task25 files removed before staging. | PRE-COMMIT GATE. |
| 141 | Local build availability | No clang/clang-cl/make/xcrun in Windows workspace. | NOT RUN; static gates only. |

Scenario count: **141**.

## 16. Complete source diff

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index aaf39a5..f7fcaae 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -10,6 +10,7 @@
 #import "AppEntitlementsReader.h"
 #import "AppGroupContainerResolver.h"
 #import "PXBackupManifestValidator.h"
+#import "PXBackupArtifactVerifier.h"
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
 #import "CommandRunner.h"
@@ -1890,6 +1891,22 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }
         NSString *dataUUID = dataContainerModel.containerUUID;

+        NSError *artifactError = nil;
+        PXVerifiedBackupArtifactSet *verifiedArtifacts =
+            [PXBackupArtifactVerifier verifiedArtifactsForManifest:manifest
+                                                    backupDirectory:backupDir
+                                                              error:&artifactError];
+        if (!verifiedArtifacts) {
+            NSError *err = artifactError ?: [NSError errorWithDomain:PXBackupArtifactVerifierErrorDomain
+                                                                 code:PXBackupArtifactVerifierErrorInvalidInput
+                                                             userInfo:@{
+                                                                 NSLocalizedDescriptionKey: @"Backup artifact verification failed",
+                                                                 PXBackupArtifactVerifierErrorFieldPathKey: @"$"
+                                                             }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
         NSMutableArray<NSString *> *warnings = [NSMutableArray array];
         NSFileManager *fm = [NSFileManager defaultManager];
         CommandRunner *runner = [CommandRunner shared];
@@ -1986,57 +2003,22 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             }
         }

-        // Integrity verify artifacts (best-effort)
-        NSDictionary *artByName = nil;
-        if ([manifest[@"artifacts"] isKindOfClass:[NSArray class]]) {
-            NSMutableDictionary *m = [NSMutableDictionary dictionary];
-            for (NSDictionary *a in (NSArray *)manifest[@"artifacts"]) {
-                if (![a isKindOfClass:[NSDictionary class]]) continue;
-                NSString *name = a[@"name"];
-                if ([name isKindOfClass:[NSString class]] && name.length) {
-                    m[name] = a;
-                }
-                NSString *verifyWarning = PXVerifyArtifact(backupDir, a);
-                if (verifyWarning.length) {
-                    [warnings addObject:[@"Restore artifact verification: " stringByAppendingString:verifyWarning]];
-                }
+        NSMutableDictionary<NSString *, NSString *> *groupArchiveNamesByIDBuilder =
+            [NSMutableDictionary dictionary];
+        for (NSDictionary *entry in (NSArray *)manifest[@"appGroups"]) {
+            NSString *groupID = entry[@"groupID"];
+            NSString *archiveName = entry[@"archive"];
+            if (groupID.length && archiveName.length) {
+                groupArchiveNamesByIDBuilder[groupID] = archiveName;
             }
-            artByName = m;
         }
+        NSDictionary<NSString *, NSString *> *groupArchiveNamesByID =
+            [groupArchiveNamesByIDBuilder copy];

-        // Validate data archive before wiping
-        NSString *dataArchive = [backupDir stringByAppendingPathComponent:@"data.tar.gz"];
-        if (![fm fileExistsAtPath:dataArchive]) {
-            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                               code:305
-                                           userInfo:@{NSLocalizedDescriptionKey: @"data.tar.gz missing"}];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-            return;
-        }
-        NSDictionary *dataArt = artByName ? artByName[@"data.tar.gz"] : nil;
-        if ([dataArt isKindOfClass:[NSDictionary class]]) {
-            NSNumber *expectedSize = dataArt[@"size"];
-            NSString *expectedHash = dataArt[@"sha256"];
-            NSDictionary *attrs = [fm attributesOfItemAtPath:dataArchive error:nil];
-            NSNumber *size = attrs[NSFileSize];
-            if (expectedSize && size && [expectedSize longLongValue] > 0 && [size longLongValue] != [expectedSize longLongValue]) {
-                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                   code:314
-                                               userInfo:@{NSLocalizedDescriptionKey: @"data.tar.gz size mismatch"}];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-                return;
-            }
-            if ([expectedHash isKindOfClass:[NSString class]] && expectedHash.length > 0) {
-                NSString *actual = PXHexString(PXFileSHA256(dataArchive));
-                if (actual.length && ![actual isEqualToString:expectedHash]) {
-                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                       code:315
-                                                   userInfo:@{NSLocalizedDescriptionKey: @"data.tar.gz sha256 mismatch"}];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-                    return;
-                }
-            }
-        }
+        NSDictionary *dataInfo = manifest[@"data"];
+        NSString *dataArchiveName = dataInfo[@"archive"];
+        NSString *dataArchive =
+            [verifiedArtifacts pathForArtifactName:dataArchiveName];

         // Two-phase restore for data container: extract to staging first.
         NSString *stagingRoot = [NSString stringWithFormat:@"/tmp/weaponx_restore_%d", getpid()];
@@ -2149,8 +2131,10 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }
         if (includeProfileAppData) {
             NSString *profileAppDataPath = [self _profileAppDataPathForBundleID:bundleID];
-            NSString *archivePath = [backupDir stringByAppendingPathComponent:@"profile_appdata.tar.gz"];
-            if (profileAppDataPath.length && [fm fileExistsAtPath:archivePath]) {
+            NSString *archiveName = profileAppData[@"archive"];
+            NSString *archivePath =
+                [verifiedArtifacts pathForArtifactName:archiveName];
+            if (profileAppDataPath.length && archivePath.length) {
                 BOOL isDir = NO;
                 if ([fm fileExistsAtPath:profileAppDataPath isDirectory:&isDir] && isDir) {
                     [self _wipeDirectoryContents:profileAppDataPath];
@@ -2188,8 +2172,10 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }
         if (includeGlobalSafari) {
             NSString *globalSafariPath = [self _globalSafariLibraryPath];
-            NSString *archivePath = [backupDir stringByAppendingPathComponent:@"global_safari.tar.gz"];
-            if (globalSafariPath.length && [fm fileExistsAtPath:archivePath]) {
+            NSString *archiveName = globalSafari[@"archive"];
+            NSString *archivePath =
+                [verifiedArtifacts pathForArtifactName:archiveName];
+            if (globalSafariPath.length && archivePath.length) {
                 BOOL isDir = NO;
                 if ([fm fileExistsAtPath:globalSafariPath isDirectory:&isDir] && isDir) {
                     [self _wipeDirectoryContents:globalSafariPath];
@@ -2221,6 +2207,14 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         // Wipe and restore each group
         for (AppGroupContainerInfo *info in groupContainers) {
+            NSString *archiveName = groupArchiveNamesByID[info.groupID];
+            NSString *archivePath =
+                [verifiedArtifacts pathForArtifactName:archiveName];
+            if (!archiveName.length || !archivePath.length) {
+                [warnings addObject:[NSString stringWithFormat:@"Missing manifest archive mapping for %@", info.groupID]];
+                continue;
+            }
+
             // Debug: group state before wipe
             PXDebugHeader(debugPre, [NSString stringWithFormat:@"Group Restore: %@", info.groupID ?: @""]);
             PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"groupPath=%@", info.path ?: @""]);
@@ -2228,13 +2222,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             [self _wipeDirectoryContents:info.path];
             PXDebugRun(runner, debugPre, @"ls group (after wipe)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(info.path)]);

-            NSString *archiveName = [NSString stringWithFormat:@"%@.tar.gz", PXSanitizeFilenameComponent(info.groupID)];
-            NSString *archivePath = [[backupDir stringByAppendingPathComponent:@"groups"] stringByAppendingPathComponent:archiveName];
-            if (![fm fileExistsAtPath:archivePath]) {
-                [warnings addObject:[NSString stringWithFormat:@"Missing group archive for %@", info.groupID]];
-                continue;
-            }
-
             CommandResult *r = [self _tarExtract:tarPath archive:archivePath toDir:info.path];
             if (r.exitCode != 0) {
                 NSString *msg = r.stderrString.length ? r.stderrString : [NSString stringWithFormat:@"Failed to extract group %@", info.groupID];
@@ -2274,11 +2261,8 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                     continue;
                 }

-                NSString *archivePath = [backupDir stringByAppendingPathComponent:archive];
-                if (![fm fileExistsAtPath:archivePath]) {
-                    [warnings addObject:[NSString stringWithFormat:@"Missing system global archive for %@; skipping", subdir]];
-                    continue;
-                }
+                NSString *archivePath =
+                    [verifiedArtifacts pathForArtifactName:archive];

                 NSString *dest = [libBase stringByAppendingPathComponent:subdir];
                 [self _killRelatedProcessesForBundleID:bundleID];
@@ -2335,11 +2319,8 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                 NSString *archiveRel = [it[@"archive"] isKindOfClass:[NSString class]] ? it[@"archive"] : nil;
                 if (!libraryRel.length || !archiveRel.length) continue;

-                NSString *src = [backupDir stringByAppendingPathComponent:archiveRel];
-                if (![fm fileExistsAtPath:src]) {
-                    [warnings addObject:[NSString stringWithFormat:@"Missing shared DB archive %@; skipping", archiveRel]];
-                    continue;
-                }
+                NSString *src =
+                    [verifiedArtifacts pathForArtifactName:archiveRel];

                 NSString *dest = [libBase stringByAppendingPathComponent:libraryRel];
                 NSString *destDir = [dest stringByDeletingLastPathComponent];
@@ -2371,9 +2352,11 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             includePrefs = [prefs[@"included"] boolValue];
         }
         if (includePrefs) {
-            NSString *prefBackup = [[backupDir stringByAppendingPathComponent:@"preferences"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleID]];
+            NSString *prefArchiveName = prefs[@"archive"];
+            NSString *prefBackup =
+                [verifiedArtifacts pathForArtifactName:prefArchiveName];
             NSString *prefDest = [self _preferencesPlistPathForBundleID:bundleID];
-            if ([fm fileExistsAtPath:prefBackup]) {
+            if (prefBackup.length) {
                 [runner run:[NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null || true", PXShellQuote(prefBackup), PXShellQuote(prefDest)]];
                 [runner run:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true", PXShellQuote(prefDest)]];
                 [runner run:[NSString stringWithFormat:@"chmod 644 %@ 2>/dev/null || true", PXShellQuote(prefDest)]];
@@ -2390,7 +2373,9 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             includeKeychain = [keychainInfo[@"included"] boolValue];
         }
         if (includeKeychain) {
-            NSString *keychainBackupPath = [backupDir stringByAppendingPathComponent:@"keychain.plist"];
+            NSString *keychainArchiveName = keychainInfo[@"archive"];
+            NSString *keychainBackupPath =
+                [verifiedArtifacts pathForArtifactName:keychainArchiveName];
             NSArray<NSString *> *groups = @[];
             if ([keychainInfo isKindOfClass:[NSDictionary class]] && [keychainInfo[@"groupsSelected"] isKindOfClass:[NSArray class]]) {
                 groups = keychainInfo[@"groupsSelected"];
diff --git a/PXBackupArtifactVerifier.h b/PXBackupArtifactVerifier.h
new file mode 100644
index 0000000..64d8650
--- /dev/null
+++ b/PXBackupArtifactVerifier.h
@@ -0,0 +1,55 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSString * const
+    PXBackupArtifactVerifierErrorDomain;
+
+FOUNDATION_EXPORT NSString * const
+    PXBackupArtifactVerifierErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXBackupArtifactVerifierErrorCode) {
+    PXBackupArtifactVerifierErrorInvalidInput = 1,
+    PXBackupArtifactVerifierErrorInvalidReference = 2,
+    PXBackupArtifactVerifierErrorUnsafeRelativePath = 3,
+    PXBackupArtifactVerifierErrorMissingArtifact = 4,
+    PXBackupArtifactVerifierErrorFilesystemInspectionFailed = 5,
+    PXBackupArtifactVerifierErrorSymlinkRejected = 6,
+    PXBackupArtifactVerifierErrorNotRegularFile = 7,
+    PXBackupArtifactVerifierErrorSizeMismatch = 8,
+    PXBackupArtifactVerifierErrorInvalidDigest = 9,
+    PXBackupArtifactVerifierErrorDigestReadFailed = 10,
+    PXBackupArtifactVerifierErrorDigestMismatch = 11,
+    PXBackupArtifactVerifierErrorFilesystemChanged = 12,
+    PXBackupArtifactVerifierErrorInconsistentManifest = 13,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXVerifiedBackupArtifactSet : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly)
+    NSArray<NSString *> *artifactNames;
+
+@property (nonatomic, copy, readonly)
+    NSDictionary<NSString *, NSString *> *canonicalPathsByName;
+
+- (nullable NSString *)pathForArtifactName:(NSString *)artifactName;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupArtifactVerifier : NSObject
+
++ (nullable PXVerifiedBackupArtifactSet *)verifiedArtifactsForManifest:(NSDictionary *)manifest
+                                                       backupDirectory:(NSString *)backupDirectory
+                                                                 error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXBackupArtifactVerifier.m b/PXBackupArtifactVerifier.m
new file mode 100644
index 0000000..ceb6b63
--- /dev/null
+++ b/PXBackupArtifactVerifier.m
@@ -0,0 +1,1144 @@
+#import "PXBackupArtifactVerifier.h"
+
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
+
+NSString * const PXBackupArtifactVerifierErrorDomain =
+    @"PXBackupArtifactVerifierErrorDomain";
+
+NSString * const PXBackupArtifactVerifierErrorFieldPathKey =
+    @"PXBackupArtifactVerifierErrorFieldPathKey";
+
+@interface PXBackupArtifactDeclaration : NSObject
+
+@property (nonatomic, copy, readonly) NSString *name;
+@property (nonatomic, assign, readonly) uint64_t expectedSize;
+@property (nonatomic, copy, readonly) NSString *expectedDigest;
+@property (nonatomic, assign, readonly) NSUInteger originalIndex;
+
+- (instancetype)initWithName:(NSString *)name
+                expectedSize:(uint64_t)expectedSize
+              expectedDigest:(NSString *)expectedDigest
+               originalIndex:(NSUInteger)originalIndex;
+
+@end
+
+@implementation PXBackupArtifactDeclaration
+
+- (instancetype)initWithName:(NSString *)name
+                expectedSize:(uint64_t)expectedSize
+              expectedDigest:(NSString *)expectedDigest
+               originalIndex:(NSUInteger)originalIndex {
+    self = [super init];
+    if (self) {
+        _name = [name copy];
+        _expectedSize = expectedSize;
+        _expectedDigest = [expectedDigest copy];
+        _originalIndex = originalIndex;
+    }
+    return self;
+}
+
+@end
+
+@interface PXVerifiedBackupArtifactSet ()
+
+@property (nonatomic, copy, readwrite) NSArray<NSString *> *artifactNames;
+@property (nonatomic, copy, readwrite)
+    NSDictionary<NSString *, NSString *> *canonicalPathsByName;
+
+- (instancetype)initWithCanonicalPathsByName:
+    (NSDictionary<NSString *, NSString *> *)canonicalPathsByName;
+
+@end
+
+@implementation PXVerifiedBackupArtifactSet
+
+- (instancetype)initWithCanonicalPathsByName:
+    (NSDictionary<NSString *, NSString *> *)canonicalPathsByName {
+    self = [super init];
+    if (self) {
+        _canonicalPathsByName = [canonicalPathsByName copy];
+        _artifactNames = [[_canonicalPathsByName allKeys]
+            sortedArrayUsingSelector:@selector(compare:)];
+    }
+    return self;
+}
+
+- (NSString *)pathForArtifactName:(NSString *)artifactName {
+    if (![artifactName isKindOfClass:[NSString class]] ||
+        artifactName.length == 0) {
+        return nil;
+    }
+    return self.canonicalPathsByName[artifactName];
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
+
+static BOOL PXArtifactFail(NSError **error,
+                           PXBackupArtifactVerifierErrorCode code,
+                           NSString *fieldPath,
+                           NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXBackupArtifactVerifierErrorDomain
+                                     code:code
+                                 userInfo:@{
+                                     NSLocalizedDescriptionKey: description,
+                                     PXBackupArtifactVerifierErrorFieldPathKey: fieldPath
+                                 }];
+    }
+    return NO;
+}
+
+static NSString *PXArtifactIndexedPath(NSString *basePath, NSUInteger index) {
+    NSString *indexString = [[NSNumber numberWithUnsignedInteger:index] stringValue];
+    NSString *prefix = [[basePath stringByAppendingString:@"["]
+        stringByAppendingString:indexString];
+    return [prefix stringByAppendingString:@"]"];
+}
+
+static NSString *PXArtifactFieldPath(NSString *basePath, NSString *field) {
+    return [[basePath stringByAppendingString:@"."] stringByAppendingString:field];
+}
+
+static BOOL PXArtifactStringContainsNUL(NSString *value) {
+    unichar nulCharacter = 0;
+    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
+    return [value rangeOfString:nulString].location != NSNotFound;
+}
+
+static BOOL PXArtifactStringContainsNonWhitespace(NSString *value) {
+    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
+        != NSNotFound;
+}
+
+static BOOL PXArtifactBackupDirectoryStringIsValid(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSString *string = (NSString *)value;
+    return string.length > 0 &&
+           PXArtifactStringContainsNonWhitespace(string) &&
+           !PXArtifactStringContainsNUL(string);
+}
+
+static BOOL PXArtifactRelativeNameIsSafe(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+
+    NSString *name = (NSString *)value;
+    if (name.length == 0 ||
+        !PXArtifactStringContainsNonWhitespace(name) ||
+        PXArtifactStringContainsNUL(name) ||
+        [name characterAtIndex:0] == (unichar)'/' ||
+        [name characterAtIndex:(name.length - 1)] == (unichar)'/' ||
+        [name rangeOfString:@"//"].location != NSNotFound) {
+        return NO;
+    }
+
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
+static BOOL PXArtifactIsExactBoolean(id value) {
+    if (![value isKindOfClass:[NSNumber class]]) {
+        return NO;
+    }
+    return CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
+}
+
+static BOOL PXArtifactReadExactBoolean(id value, BOOL *result) {
+    if (!PXArtifactIsExactBoolean(value)) {
+        return NO;
+    }
+    if (result) {
+        *result = [(NSNumber *)value boolValue];
+    }
+    return YES;
+}
+
+static BOOL PXArtifactReadUnsignedIntegral(id value,
+                                           uint64_t maximum,
+                                           uint64_t *result) {
+    if (![value isKindOfClass:[NSNumber class]] ||
+        PXArtifactIsExactBoolean(value)) {
+        return NO;
+    }
+
+    NSNumber *number = (NSNumber *)value;
+    const char *type = number.objCType;
+    if (!type || type[0] == '\0' || type[1] != '\0') {
+        return NO;
+    }
+
+    uint64_t parsed = 0;
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
+            parsed = (uint64_t)signedValue;
+            break;
+        }
+        case 'C':
+        case 'S':
+        case 'I':
+        case 'L':
+        case 'Q':
+            parsed = number.unsignedLongLongValue;
+            break;
+        default:
+            return NO;
+    }
+
+    if (parsed > maximum) {
+        return NO;
+    }
+    if (result) {
+        *result = parsed;
+    }
+    return YES;
+}
+
+static BOOL PXArtifactDigestIsCompleteLowercaseSHA256(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+
+    NSString *digest = (NSString *)value;
+    if (digest.length != CC_SHA256_DIGEST_LENGTH * 2) {
+        return NO;
+    }
+    for (NSUInteger index = 0; index < digest.length; index++) {
+        unichar character = [digest characterAtIndex:index];
+        BOOL decimal = character >= (unichar)'0' && character <= (unichar)'9';
+        BOOL lowercaseHex = character >= (unichar)'a' && character <= (unichar)'f';
+        if (!decimal && !lowercaseHex) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+static NSString *PXArtifactHexDigest(
+    const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
+    static const char alphabet[] = "0123456789abcdef";
+    char output[CC_SHA256_DIGEST_LENGTH * 2];
+    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
+        output[index * 2] = alphabet[(digest[index] >> 4) & 0x0f];
+        output[(index * 2) + 1] = alphabet[digest[index] & 0x0f];
+    }
+    return [[NSString alloc] initWithBytes:output
+                                    length:sizeof(output)
+                                  encoding:NSASCIIStringEncoding];
+}
+
+static BOOL PXArtifactTimespecEqual(struct timespec left,
+                                    struct timespec right) {
+    return left.tv_sec == right.tv_sec && left.tv_nsec == right.tv_nsec;
+}
+
+static BOOL PXArtifactStatIdentityIsStable(const struct stat *before,
+                                           const struct stat *after) {
+    if (!before || !after) {
+        return NO;
+    }
+    if (before->st_dev != after->st_dev ||
+        before->st_ino != after->st_ino ||
+        !S_ISREG(before->st_mode) ||
+        !S_ISREG(after->st_mode) ||
+        before->st_size != after->st_size) {
+        return NO;
+    }
+#if defined(__APPLE__)
+    return PXArtifactTimespecEqual(before->st_mtimespec, after->st_mtimespec) &&
+           PXArtifactTimespecEqual(before->st_ctimespec, after->st_ctimespec);
+#else
+    return PXArtifactTimespecEqual(before->st_mtim, after->st_mtim) &&
+           PXArtifactTimespecEqual(before->st_ctim, after->st_ctim);
+#endif
+}
+
+static PXBackupArtifactVerifierErrorCode PXArtifactOpenErrorCode(int openError) {
+    if (openError == ELOOP) {
+        return PXBackupArtifactVerifierErrorSymlinkRejected;
+    }
+    if (openError == ENOENT) {
+        return PXBackupArtifactVerifierErrorMissingArtifact;
+    }
+    return PXBackupArtifactVerifierErrorFilesystemInspectionFailed;
+}
+
+static BOOL PXArtifactOpenCanonicalBackupRoot(NSString *backupDirectory,
+                                              NSString **canonicalRootOut,
+                                              int *rootDescriptorOut,
+                                              NSError **error) {
+    if (canonicalRootOut) {
+        *canonicalRootOut = nil;
+    }
+    if (rootDescriptorOut) {
+        *rootDescriptorOut = -1;
+    }
+
+    NSString *inspectionPath = backupDirectory;
+    while (inspectionPath.length > 1 &&
+           [inspectionPath characterAtIndex:(inspectionPath.length - 1)] ==
+               (unichar)'/') {
+        inspectionPath = [inspectionPath substringToIndex:(inspectionPath.length - 1)];
+    }
+
+    const char *rawPath = inspectionPath.fileSystemRepresentation;
+    if (!rawPath) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorInvalidInput,
+                              @"$",
+                              @"The backup directory input is invalid.");
+    }
+
+    struct stat rawStatus;
+    errno = 0;
+    if (lstat(rawPath, &rawStatus) != 0) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              @"$",
+                              @"The backup directory could not be inspected.");
+    }
+    if (S_ISLNK(rawStatus.st_mode)) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorSymlinkRejected,
+                              @"$",
+                              @"The backup directory final component must not be a symbolic link.");
+    }
+    if (!S_ISDIR(rawStatus.st_mode)) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              @"$",
+                              @"The backup directory must be a directory.");
+    }
+
+    int rawDescriptor = open(rawPath,
+                             O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (rawDescriptor < 0) {
+        PXBackupArtifactVerifierErrorCode code =
+            errno == ELOOP
+                ? PXBackupArtifactVerifierErrorSymlinkRejected
+                : PXBackupArtifactVerifierErrorFilesystemInspectionFailed;
+        return PXArtifactFail(error,
+                              code,
+                              @"$",
+                              @"The backup directory could not be opened safely.");
+    }
+
+    struct stat openedRawStatus;
+    if (fstat(rawDescriptor, &openedRawStatus) != 0 ||
+        !S_ISDIR(openedRawStatus.st_mode)) {
+        close(rawDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              @"$",
+                              @"The backup directory descriptor could not be verified.");
+    }
+    if (rawStatus.st_dev != openedRawStatus.st_dev ||
+        rawStatus.st_ino != openedRawStatus.st_ino) {
+        close(rawDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemChanged,
+                              @"$",
+                              @"The backup directory changed before it was opened.");
+    }
+
+    char canonicalBuffer[PATH_MAX];
+    errno = 0;
+    if (realpath(rawPath, canonicalBuffer) == NULL) {
+        close(rawDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              @"$",
+                              @"The backup directory could not be canonicalized.");
+    }
+
+    NSString *canonicalRoot = [[NSString alloc]
+        initWithBytes:canonicalBuffer
+               length:strlen(canonicalBuffer)
+             encoding:NSUTF8StringEncoding];
+    if (canonicalRoot.length == 0) {
+        close(rawDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              @"$",
+                              @"The canonical backup directory is invalid.");
+    }
+
+    int rootDescriptor = open(canonicalBuffer,
+                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (rootDescriptor < 0) {
+        PXBackupArtifactVerifierErrorCode code =
+            errno == ELOOP
+                ? PXBackupArtifactVerifierErrorSymlinkRejected
+                : PXBackupArtifactVerifierErrorFilesystemInspectionFailed;
+        close(rawDescriptor);
+        return PXArtifactFail(error,
+                              code,
+                              @"$",
+                              @"The canonical backup directory could not be opened safely.");
+    }
+
+    struct stat canonicalStatus;
+    if (fstat(rootDescriptor, &canonicalStatus) != 0 ||
+        !S_ISDIR(canonicalStatus.st_mode)) {
+        close(rootDescriptor);
+        close(rawDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              @"$",
+                              @"The canonical backup directory could not be verified.");
+    }
+    if (openedRawStatus.st_dev != canonicalStatus.st_dev ||
+        openedRawStatus.st_ino != canonicalStatus.st_ino) {
+        close(rootDescriptor);
+        close(rawDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemChanged,
+                              @"$",
+                              @"The backup directory changed during canonicalization.");
+    }
+    close(rawDescriptor);
+
+    if (canonicalRootOut) {
+        *canonicalRootOut = canonicalRoot;
+    }
+    if (rootDescriptorOut) {
+        *rootDescriptorOut = rootDescriptor;
+    } else {
+        close(rootDescriptor);
+    }
+    return YES;
+}
+
+static BOOL PXArtifactCanonicalPathIsWithinRoot(NSString *canonicalRoot,
+                                                NSString *canonicalPath) {
+    if (canonicalRoot.length == 0 || canonicalPath.length == 0) {
+        return NO;
+    }
+    NSString *boundaryPrefix = [canonicalRoot stringByAppendingString:@"/"];
+    return canonicalPath.length > boundaryPrefix.length &&
+           [canonicalPath hasPrefix:boundaryPrefix];
+}
+
+static BOOL PXArtifactOpenRelativeFile(int rootDescriptor,
+                                       NSString *relativeName,
+                                       NSString *fieldPath,
+                                       int *fileDescriptorOut,
+                                       NSError **error) {
+    if (fileDescriptorOut) {
+        *fileDescriptorOut = -1;
+    }
+
+    NSArray<NSString *> *components =
+        [relativeName componentsSeparatedByString:@"/"];
+    int currentDescriptor = rootDescriptor;
+    BOOL ownsCurrentDescriptor = NO;
+
+    for (NSUInteger index = 0; index + 1 < components.count; index++) {
+        NSString *component = components[index];
+        const char *componentName = component.fileSystemRepresentation;
+        if (!componentName) {
+            if (ownsCurrentDescriptor) {
+                close(currentDescriptor);
+            }
+            return PXArtifactFail(error,
+                                  PXBackupArtifactVerifierErrorUnsafeRelativePath,
+                                  fieldPath,
+                                  @"The artifact name cannot be represented safely.");
+        }
+
+        int nextDescriptor = openat(currentDescriptor,
+                                    componentName,
+                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        if (nextDescriptor < 0) {
+            int capturedError = errno;
+            if (ownsCurrentDescriptor) {
+                close(currentDescriptor);
+            }
+            return PXArtifactFail(error,
+                                  PXArtifactOpenErrorCode(capturedError),
+                                  fieldPath,
+                                  @"An artifact parent component could not be opened safely.");
+        }
+        if (ownsCurrentDescriptor) {
+            close(currentDescriptor);
+        }
+        currentDescriptor = nextDescriptor;
+        ownsCurrentDescriptor = YES;
+    }
+
+    NSString *finalComponent = components.lastObject;
+    const char *finalName = finalComponent.fileSystemRepresentation;
+    if (!finalName) {
+        if (ownsCurrentDescriptor) {
+            close(currentDescriptor);
+        }
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorUnsafeRelativePath,
+                              fieldPath,
+                              @"The artifact name cannot be represented safely.");
+    }
+
+    int fileDescriptor = openat(currentDescriptor,
+                                finalName,
+                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    int capturedError = errno;
+    if (ownsCurrentDescriptor) {
+        close(currentDescriptor);
+    }
+    if (fileDescriptor < 0) {
+        return PXArtifactFail(error,
+                              PXArtifactOpenErrorCode(capturedError),
+                              fieldPath,
+                              @"The artifact could not be opened safely.");
+    }
+
+    if (fileDescriptorOut) {
+        *fileDescriptorOut = fileDescriptor;
+    } else {
+        close(fileDescriptor);
+    }
+    return YES;
+}
+
+static BOOL PXArtifactHashDescriptor(int fileDescriptor,
+                                     NSString **digestOut,
+                                     NSError **error,
+                                     NSString *fieldPath) {
+    if (digestOut) {
+        *digestOut = nil;
+    }
+
+    CC_SHA256_CTX context;
+    if (CC_SHA256_Init(&context) != 1) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorDigestReadFailed,
+                              fieldPath,
+                              @"The artifact digest could not be initialized.");
+    }
+
+    unsigned char buffer[64 * 1024];
+    for (;;) {
+        ssize_t count = read(fileDescriptor, buffer, sizeof(buffer));
+        if (count > 0) {
+            if (CC_SHA256_Update(&context, buffer, (CC_LONG)count) != 1) {
+                return PXArtifactFail(error,
+                                      PXBackupArtifactVerifierErrorDigestReadFailed,
+                                      fieldPath,
+                                      @"The artifact digest could not be updated.");
+            }
+            continue;
+        }
+        if (count == 0) {
+            break;
+        }
+        if (errno == EINTR) {
+            continue;
+        }
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorDigestReadFailed,
+                              fieldPath,
+                              @"The artifact could not be read for digest verification.");
+    }
+
+    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
+    if (CC_SHA256_Final(digest, &context) != 1) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorDigestReadFailed,
+                              fieldPath,
+                              @"The artifact digest could not be finalized.");
+    }
+
+    NSString *digestString = PXArtifactHexDigest(digest);
+    if (digestString.length != CC_SHA256_DIGEST_LENGTH * 2) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorDigestReadFailed,
+                              fieldPath,
+                              @"The artifact digest result is invalid.");
+    }
+    if (digestOut) {
+        *digestOut = digestString;
+    }
+    return YES;
+}
+
+static BOOL PXArtifactVerifyDeclaration(
+    PXBackupArtifactDeclaration *declaration,
+    int rootDescriptor,
+    NSString *canonicalRoot,
+    NSString **canonicalPathOut,
+    NSString **actualDigestOut,
+    uint64_t *actualSizeOut,
+    NSError **error) {
+    if (canonicalPathOut) {
+        *canonicalPathOut = nil;
+    }
+    if (actualDigestOut) {
+        *actualDigestOut = nil;
+    }
+    if (actualSizeOut) {
+        *actualSizeOut = 0;
+    }
+
+    NSString *entryPath = PXArtifactIndexedPath(@"$.artifacts",
+                                                 declaration.originalIndex);
+    NSString *namePath = PXArtifactFieldPath(entryPath, @"name");
+    NSString *sizePath = PXArtifactFieldPath(entryPath, @"size");
+    NSString *digestPath = PXArtifactFieldPath(entryPath, @"sha256");
+
+    int fileDescriptor = -1;
+    if (!PXArtifactOpenRelativeFile(rootDescriptor,
+                                    declaration.name,
+                                    namePath,
+                                    &fileDescriptor,
+                                    error)) {
+        return NO;
+    }
+
+    struct stat beforeStatus;
+    if (fstat(fileDescriptor, &beforeStatus) != 0) {
+        close(fileDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              namePath,
+                              @"The artifact could not be inspected.");
+    }
+    if (!S_ISREG(beforeStatus.st_mode)) {
+        close(fileDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorNotRegularFile,
+                              namePath,
+                              @"The artifact must be a regular file.");
+    }
+    if (beforeStatus.st_size < 0 ||
+        (uint64_t)beforeStatus.st_size != declaration.expectedSize) {
+        close(fileDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorSizeMismatch,
+                              sizePath,
+                              @"The artifact size does not match the manifest.");
+    }
+
+    NSString *actualDigest = nil;
+    if (!PXArtifactHashDescriptor(fileDescriptor,
+                                  &actualDigest,
+                                  error,
+                                  digestPath)) {
+        close(fileDescriptor);
+        return NO;
+    }
+
+    struct stat afterStatus;
+    if (fstat(fileDescriptor, &afterStatus) != 0) {
+        close(fileDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              namePath,
+                              @"The artifact could not be inspected after verification.");
+    }
+    close(fileDescriptor);
+
+    if (!PXArtifactStatIdentityIsStable(&beforeStatus, &afterStatus)) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorFilesystemChanged,
+                              namePath,
+                              @"The artifact changed during verification.");
+    }
+    if (![actualDigest isEqualToString:declaration.expectedDigest]) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorDigestMismatch,
+                              digestPath,
+                              @"The artifact digest does not match the manifest.");
+    }
+
+    NSString *canonicalPath = [[canonicalRoot stringByAppendingString:@"/"]
+        stringByAppendingString:declaration.name];
+    if (!PXArtifactCanonicalPathIsWithinRoot(canonicalRoot, canonicalPath)) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorUnsafeRelativePath,
+                              namePath,
+                              @"The artifact path escapes the canonical backup directory.");
+    }
+
+    if (canonicalPathOut) {
+        *canonicalPathOut = canonicalPath;
+    }
+    if (actualDigestOut) {
+        *actualDigestOut = actualDigest;
+    }
+    if (actualSizeOut) {
+        *actualSizeOut = (uint64_t)afterStatus.st_size;
+    }
+    return YES;
+}
+
+static BOOL PXArtifactAddRequiredReference(
+    id value,
+    NSString *fieldPath,
+    NSDictionary<NSString *, PXBackupArtifactDeclaration *> *declarationsByName,
+    NSMutableSet<NSString *> *referencedNames,
+    NSString **acceptedNameOut,
+    NSError **error) {
+    if (acceptedNameOut) {
+        *acceptedNameOut = nil;
+    }
+    if (!PXArtifactRelativeNameIsSafe(value)) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorUnsafeRelativePath,
+                              fieldPath,
+                              @"The artifact reference must be a safe relative name.");
+    }
+
+    NSString *name = (NSString *)value;
+    if ([referencedNames containsObject:name]) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorInvalidReference,
+                              fieldPath,
+                              @"An artifact is referenced by more than one Restore component.");
+    }
+    if (!declarationsByName[name]) {
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorMissingArtifact,
+                              fieldPath,
+                              @"The referenced artifact is not declared.");
+    }
+
+    [referencedNames addObject:name];
+    if (acceptedNameOut) {
+        *acceptedNameOut = name;
+    }
+    return YES;
+}
+
+@implementation PXBackupArtifactVerifier
+
++ (PXVerifiedBackupArtifactSet *)verifiedArtifactsForManifest:(NSDictionary *)manifest
+                                              backupDirectory:(NSString *)backupDirectory
+                                                        error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    if (![manifest isKindOfClass:[NSDictionary class]]) {
+        PXArtifactFail(error,
+                       PXBackupArtifactVerifierErrorInvalidInput,
+                       @"$",
+                       @"The manifest input must be a dictionary.");
+        return nil;
+    }
+    if (!PXArtifactBackupDirectoryStringIsValid(backupDirectory)) {
+        PXArtifactFail(error,
+                       PXBackupArtifactVerifierErrorInvalidInput,
+                       @"$",
+                       @"The backup directory input is invalid.");
+        return nil;
+    }
+
+    id artifactsValue = manifest[@"artifacts"];
+    if (![artifactsValue isKindOfClass:[NSArray class]]) {
+        PXArtifactFail(error,
+                       PXBackupArtifactVerifierErrorInvalidInput,
+                       @"$.artifacts",
+                       @"The artifacts section must be an array.");
+        return nil;
+    }
+
+    NSArray *artifactEntries = (NSArray *)artifactsValue;
+    NSMutableArray<PXBackupArtifactDeclaration *> *declarations =
+        [NSMutableArray arrayWithCapacity:artifactEntries.count];
+    NSMutableDictionary<NSString *, PXBackupArtifactDeclaration *>
+        *declarationsByName = [NSMutableDictionary dictionary];
+
+    uint64_t declaredSizeSum = 0;
+    BOOL declaredSizeOverflow = NO;
+    uint64_t maximumFileSize = (uint64_t)LLONG_MAX;
+
+    for (NSUInteger index = 0; index < artifactEntries.count; index++) {
+        NSString *entryPath = PXArtifactIndexedPath(@"$.artifacts", index);
+        id entryValue = artifactEntries[index];
+        if (![entryValue isKindOfClass:[NSDictionary class]]) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           entryPath,
+                           @"Each artifact declaration must be a dictionary.");
+            return nil;
+        }
+
+        NSDictionary *entry = (NSDictionary *)entryValue;
+        NSString *namePath = PXArtifactFieldPath(entryPath, @"name");
+        id nameValue = entry[@"name"];
+        if (!PXArtifactRelativeNameIsSafe(nameValue)) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorUnsafeRelativePath,
+                           namePath,
+                           @"The artifact name must be a safe relative path.");
+            return nil;
+        }
+        NSString *name = (NSString *)nameValue;
+        if (declarationsByName[name]) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInconsistentManifest,
+                           namePath,
+                           @"The manifest contains a duplicate artifact declaration.");
+            return nil;
+        }
+
+        NSString *sizePath = PXArtifactFieldPath(entryPath, @"size");
+        uint64_t expectedSize = 0;
+        if (!PXArtifactReadUnsignedIntegral(entry[@"size"],
+                                            maximumFileSize,
+                                            &expectedSize)) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           sizePath,
+                           @"The artifact size must be a nonnegative integral value.");
+            return nil;
+        }
+
+        NSString *digestPath = PXArtifactFieldPath(entryPath, @"sha256");
+        id digestValue = entry[@"sha256"];
+        if (!PXArtifactDigestIsCompleteLowercaseSHA256(digestValue)) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidDigest,
+                           digestPath,
+                           @"The artifact digest must be a complete lowercase SHA-256 value.");
+            return nil;
+        }
+
+        PXBackupArtifactDeclaration *declaration =
+            [[PXBackupArtifactDeclaration alloc]
+                initWithName:name
+                expectedSize:expectedSize
+                expectedDigest:(NSString *)digestValue
+                originalIndex:index];
+        [declarations addObject:declaration];
+        declarationsByName[name] = declaration;
+
+        if (UINT64_MAX - declaredSizeSum < expectedSize) {
+            declaredSizeOverflow = YES;
+        } else if (!declaredSizeOverflow) {
+            declaredSizeSum += expectedSize;
+        }
+    }
+
+    NSMutableSet<NSString *> *referencedNames = [NSMutableSet set];
+    NSString *dataArchiveName = nil;
+
+    id dataValue = manifest[@"data"];
+    if (![dataValue isKindOfClass:[NSDictionary class]]) {
+        PXArtifactFail(error,
+                       PXBackupArtifactVerifierErrorInvalidInput,
+                       @"$.data",
+                       @"The data section must be a dictionary.");
+        return nil;
+    }
+    if (!PXArtifactAddRequiredReference(((NSDictionary *)dataValue)[@"archive"],
+                                        @"$.data.archive",
+                                        declarationsByName,
+                                        referencedNames,
+                                        &dataArchiveName,
+                                        error)) {
+        return nil;
+    }
+
+    id appGroupsValue = manifest[@"appGroups"];
+    if (![appGroupsValue isKindOfClass:[NSArray class]]) {
+        PXArtifactFail(error,
+                       PXBackupArtifactVerifierErrorInvalidInput,
+                       @"$.appGroups",
+                       @"The App Groups section must be an array.");
+        return nil;
+    }
+    NSArray *appGroups = (NSArray *)appGroupsValue;
+    for (NSUInteger index = 0; index < appGroups.count; index++) {
+        NSString *entryPath = PXArtifactIndexedPath(@"$.appGroups", index);
+        id entryValue = appGroups[index];
+        if (![entryValue isKindOfClass:[NSDictionary class]]) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           entryPath,
+                           @"Each App Group entry must be a dictionary.");
+            return nil;
+        }
+        if (!PXArtifactAddRequiredReference(((NSDictionary *)entryValue)[@"archive"],
+                                            PXArtifactFieldPath(entryPath, @"archive"),
+                                            declarationsByName,
+                                            referencedNames,
+                                            NULL,
+                                            error)) {
+            return nil;
+        }
+    }
+
+    NSArray<NSString *> *singleArchiveSections = @[
+        @"preferences",
+        @"keychain",
+        @"profileAppData",
+        @"globalSafari"
+    ];
+    for (NSString *sectionName in singleArchiveSections) {
+        NSString *sectionPath = PXArtifactFieldPath(@"$", sectionName);
+        id sectionValue = manifest[sectionName];
+        if (![sectionValue isKindOfClass:[NSDictionary class]]) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           sectionPath,
+                           @"The Restore component section must be a dictionary.");
+            return nil;
+        }
+        NSDictionary *section = (NSDictionary *)sectionValue;
+        BOOL included = NO;
+        if (!PXArtifactReadExactBoolean(section[@"included"], &included)) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           PXArtifactFieldPath(sectionPath, @"included"),
+                           @"The Restore component inclusion flag must be Boolean.");
+            return nil;
+        }
+        if (included &&
+            !PXArtifactAddRequiredReference(section[@"archive"],
+                                            PXArtifactFieldPath(sectionPath, @"archive"),
+                                            declarationsByName,
+                                            referencedNames,
+                                            NULL,
+                                            error)) {
+            return nil;
+        }
+    }
+
+    id systemGlobalValue = manifest[@"systemGlobalLibrary"];
+    if (systemGlobalValue) {
+        if (![systemGlobalValue isKindOfClass:[NSDictionary class]]) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           @"$.systemGlobalLibrary",
+                           @"The system-global section must be a dictionary.");
+            return nil;
+        }
+        NSDictionary *systemGlobal = (NSDictionary *)systemGlobalValue;
+        BOOL included = NO;
+        if (!PXArtifactReadExactBoolean(systemGlobal[@"included"], &included)) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           @"$.systemGlobalLibrary.included",
+                           @"The system-global inclusion flag must be Boolean.");
+            return nil;
+        }
+        if (included) {
+            id itemsValue = systemGlobal[@"items"];
+            if (![itemsValue isKindOfClass:[NSArray class]]) {
+                PXArtifactFail(error,
+                               PXBackupArtifactVerifierErrorInvalidInput,
+                               @"$.systemGlobalLibrary.items",
+                               @"The system-global items field must be an array.");
+                return nil;
+            }
+            NSArray *items = (NSArray *)itemsValue;
+            for (NSUInteger index = 0; index < items.count; index++) {
+                NSString *entryPath = PXArtifactIndexedPath(
+                    @"$.systemGlobalLibrary.items", index);
+                id entryValue = items[index];
+                if (![entryValue isKindOfClass:[NSDictionary class]]) {
+                    PXArtifactFail(error,
+                                   PXBackupArtifactVerifierErrorInvalidInput,
+                                   entryPath,
+                                   @"Each system-global item must be a dictionary.");
+                    return nil;
+                }
+                if (!PXArtifactAddRequiredReference(
+                        ((NSDictionary *)entryValue)[@"archive"],
+                        PXArtifactFieldPath(entryPath, @"archive"),
+                        declarationsByName,
+                        referencedNames,
+                        NULL,
+                        error)) {
+                    return nil;
+                }
+            }
+        }
+    }
+
+    id sharedDBValue = manifest[@"sharedSystemDB"];
+    if (sharedDBValue) {
+        if (![sharedDBValue isKindOfClass:[NSDictionary class]]) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           @"$.sharedSystemDB",
+                           @"The shared-system-DB section must be a dictionary.");
+            return nil;
+        }
+        NSDictionary *sharedDB = (NSDictionary *)sharedDBValue;
+        BOOL included = NO;
+        if (!PXArtifactReadExactBoolean(sharedDB[@"included"], &included)) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInvalidInput,
+                           @"$.sharedSystemDB.included",
+                           @"The shared-system-DB inclusion flag must be Boolean.");
+            return nil;
+        }
+        if (included) {
+            id filesValue = sharedDB[@"files"];
+            if (![filesValue isKindOfClass:[NSArray class]]) {
+                PXArtifactFail(error,
+                               PXBackupArtifactVerifierErrorInvalidInput,
+                               @"$.sharedSystemDB.files",
+                               @"The shared-system-DB files field must be an array.");
+                return nil;
+            }
+            NSArray *files = (NSArray *)filesValue;
+            for (NSUInteger index = 0; index < files.count; index++) {
+                NSString *entryPath = PXArtifactIndexedPath(
+                    @"$.sharedSystemDB.files", index);
+                id entryValue = files[index];
+                if (![entryValue isKindOfClass:[NSDictionary class]]) {
+                    PXArtifactFail(error,
+                                   PXBackupArtifactVerifierErrorInvalidInput,
+                                   entryPath,
+                                   @"Each shared-system-DB file entry must be a dictionary.");
+                    return nil;
+                }
+                if (!PXArtifactAddRequiredReference(
+                        ((NSDictionary *)entryValue)[@"archive"],
+                        PXArtifactFieldPath(entryPath, @"archive"),
+                        declarationsByName,
+                        referencedNames,
+                        NULL,
+                        error)) {
+                    return nil;
+                }
+            }
+        }
+    }
+
+    NSArray<PXBackupArtifactDeclaration *> *sortedDeclarations =
+        [declarations sortedArrayUsingComparator:
+            ^NSComparisonResult(PXBackupArtifactDeclaration *left,
+                                PXBackupArtifactDeclaration *right) {
+                return [left.name compare:right.name];
+            }];
+
+    NSString *canonicalRoot = nil;
+    int rootDescriptor = -1;
+    if (!PXArtifactOpenCanonicalBackupRoot(backupDirectory,
+                                           &canonicalRoot,
+                                           &rootDescriptor,
+                                           error)) {
+        return nil;
+    }
+
+    NSMutableDictionary<NSString *, NSString *> *canonicalPathsByName =
+        [NSMutableDictionary dictionaryWithCapacity:sortedDeclarations.count];
+    NSMutableDictionary<NSString *, NSString *> *actualDigestsByName =
+        [NSMutableDictionary dictionaryWithCapacity:sortedDeclarations.count];
+    uint64_t actualSizeSum = 0;
+    BOOL actualSizeOverflow = NO;
+
+    for (PXBackupArtifactDeclaration *declaration in sortedDeclarations) {
+        NSString *canonicalPath = nil;
+        NSString *actualDigest = nil;
+        uint64_t actualSize = 0;
+        if (!PXArtifactVerifyDeclaration(declaration,
+                                         rootDescriptor,
+                                         canonicalRoot,
+                                         &canonicalPath,
+                                         &actualDigest,
+                                         &actualSize,
+                                         error)) {
+            close(rootDescriptor);
+            return nil;
+        }
+        canonicalPathsByName[declaration.name] = canonicalPath;
+        actualDigestsByName[declaration.name] = actualDigest;
+        if (UINT64_MAX - actualSizeSum < actualSize) {
+            actualSizeOverflow = YES;
+        } else if (!actualSizeOverflow) {
+            actualSizeSum += actualSize;
+        }
+    }
+    close(rootDescriptor);
+
+    id totalSizeValue = manifest[@"totalSize"];
+    if (totalSizeValue) {
+        uint64_t manifestTotalSize = 0;
+        if (!PXArtifactReadUnsignedIntegral(totalSizeValue,
+                                            UINT64_MAX,
+                                            &manifestTotalSize) ||
+            declaredSizeOverflow ||
+            actualSizeOverflow ||
+            manifestTotalSize != declaredSizeSum ||
+            manifestTotalSize != actualSizeSum) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInconsistentManifest,
+                           @"$.totalSize",
+                           @"The aggregate artifact size is inconsistent.");
+            return nil;
+        }
+    }
+
+    id archiveChecksumValue = manifest[@"archiveChecksum"];
+    if (archiveChecksumValue) {
+        if (!PXArtifactDigestIsCompleteLowercaseSHA256(archiveChecksumValue)) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInconsistentManifest,
+                           @"$.archiveChecksum",
+                           @"The aggregate archive checksum is invalid.");
+            return nil;
+        }
+        PXBackupArtifactDeclaration *dataDeclaration =
+            declarationsByName[dataArchiveName];
+        NSString *actualDataDigest = actualDigestsByName[dataArchiveName];
+        if (!dataDeclaration ||
+            !actualDataDigest ||
+            ![(NSString *)archiveChecksumValue
+                isEqualToString:dataDeclaration.expectedDigest] ||
+            ![(NSString *)archiveChecksumValue
+                isEqualToString:actualDataDigest]) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInconsistentManifest,
+                           @"$.archiveChecksum",
+                           @"The aggregate archive checksum is inconsistent.");
+            return nil;
+        }
+    }
+
+    return [[PXVerifiedBackupArtifactSet alloc]
+        initWithCanonicalPathsByName:canonicalPathsByName];
+}
+
+@end
```

## 17. Source hashes and whitespace/generated audit

| File | SHA-256 | Bytes | Lines | Newline/audit |
|---|---|---:|---:|---|
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 | 55 | LF; trailing whitespace 0; NUL 0 |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 | 1144 | LF; trailing whitespace 0; NUL 0 |
| `AppDataBackupManager.m` | `7ad65ad958af56593e22050dd952cd54a61d157ad938234ae844e07dce6d45c0` | 127747 | 2465 | CRLF preserved; added-line whitespace clean; NUL 0 |

- `git diff --check`: PASS.
- Lexical delimiter balance outside comments/strings: PASS for all three production files.
- Temporary `.task25*` audit scripts are not implementation artifacts and must be removed before staging.
- The report itself is generated as LF UTF-8 with no NUL or trailing whitespace.

## 18. Build status and remaining runtime risks

Local Objective-C/Theos build was not run because this Windows workspace has no `clang`, `clang-cl`, `make` or `xcrun`. No target-device or GitHub Actions artifact is available, so this report does not claim compile, device or race-fixture execution.

Remaining runtime validation should cover CommonCrypto availability/linking, Darwin `openat/O_NOFOLLOW/O_NONBLOCK` behavior, ancestor alias canonicalization, Unicode filesystem names, descriptor cleanup under injected failures, EINTR/read faults, FIFO/socket/device fixtures, file/root replacement races, and all v2/v3 component combinations. The verified result is intentionally a snapshot and does not prevent replacement after the verifier returns; TASK-2.6 and later transaction work remain necessary.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
