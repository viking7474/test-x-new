# TASK-3.6A Report — Manifest V4 Malformed-Type Exception Safety

## Baseline and exact scope

- Required baseline and recorded HEAD before editing: `c11ac70d2389eb9a9722396336a4ff92826d9e31`.
- TASK-3.6 production review status: `CHANGES_REQUESTED`; TASK-3.7 remained locked.
- Authorized production files: `PXBackupManifestV4.m`, `PXBackupManifestValidator.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-3.6A-REPORT.md`.
- All other production diff: zero.

Baseline commands:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Baseline result: HEAD matched the required commit; `git diff --check` was empty. The following non-production coordinator artifacts already existed and were neither modified nor staged by this implementation:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.11A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.12-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.13-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.13A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.14-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.14A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.9-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.6-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.10-stage-and-validate-optional-components.md
?? docs/backup-restore-hardening/tasks/TASK-2.11-transactional-main-data-commit-and-rollback.md
?? docs/backup-restore-hardening/tasks/TASK-2.11A-fix-pre-recovery-proof-and-durability.md
?? docs/backup-restore-hardening/tasks/TASK-2.12-transactional-app-group-commit-and-rollback.md
?? docs/backup-restore-hardening/tasks/TASK-2.13-transactional-optional-component-handling.md
?? docs/backup-restore-hardening/tasks/TASK-2.13A-fix-missing-directory-tree-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.14-add-structured-restore-result.md
?? docs/backup-restore-hardening/tasks/TASK-2.14A-fix-assertion-elided-result-state.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.6-add-archive-entry-safety-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.6A-fix-archive-validator-compatibility-and-bounds.md
?? docs/backup-restore-hardening/tasks/TASK-2.7-build-immutable-restore-plan.md
?? docs/backup-restore-hardening/tasks/TASK-2.8-stage-and-validate-main-data.md
?? docs/backup-restore-hardening/tasks/TASK-2.9-stage-and-validate-app-groups.md
?? docs/backup-restore-hardening/tasks/TASK-3.1-create-unique-partial-transaction-directory.md
?? docs/backup-restore-hardening/tasks/TASK-3.2-add-per-bundle-backup-serialization.md
?? docs/backup-restore-hardening/tasks/TASK-3.3-add-common-verified-artifact-writer.md
?? docs/backup-restore-hardening/tasks/TASK-3.4-derive-preferences-inclusion-from-verified-output.md
?? docs/backup-restore-hardening/tasks/TASK-3.5-define-required-and-optional-artifact-policy.md
?? docs/backup-restore-hardening/tasks/TASK-3.6-introduce-manifest-schema-v4.md
?? docs/backup-restore-hardening/tasks/TASK-3.6A-fix-v4-malformed-type-exception-safety.md
```

Recorded log:

```text
c11ac70 phase3(task-3.6): introduce backup manifest schema v4
5366c50 phase3(task-3.5): define backup artifact policy
339ca01 phase3(task-3.4): derive preferences inclusion from verified output
849b282 phase3(task-3.3): add common verified artifact writer
dbfeb65 phase3(task-3.2): add per-bundle backup serialization
```

## TASK-3.6 blocker

TASK-3.6 introduced the accepted manifest-v4 architecture, but selected caller/on-disk dictionary values received `boolValue` or `isEqualToString:` before runtime type proof. Wrong-type objects could therefore raise `unrecognized selector` exceptions instead of returning the established NSError contract. TASK-3.6A changes only evaluation order and failure routing; it does not redesign schema v4.

## Complete unsafe-selector inventory before correction

| Surface | Field | Baseline defect |
|---|---|---|
| Builder | `$.backupMode` | raw isEqualToString: before NSString proof |
| Builder | `$.restoreCompatibility.targetBundleID` | raw isEqualToString: before NSString proof |
| Builder | `$.options.includeAppGroups` | raw boolValue before exact CFBoolean proof |
| Builder | `$.options.includePreferences` | raw boolValue before exact CFBoolean proof |
| Builder | `$.options.includeKeychain` | raw boolValue before exact CFBoolean proof |
| Builder | `$.preferences.included` | raw boolValue before exact CFBoolean proof |
| Builder | `$.preferences.archive` | raw isEqualToString: before NSString proof |
| Builder | `$.keychain.included` | raw boolValue before exact CFBoolean proof |
| Builder | `$.keychain.archive` | raw isEqualToString: before NSString proof |
| Builder | `$.keychain.method` | raw isEqualToString: before NSString proof |
| Builder | `$.profileAppData.included` | raw boolValue before exact CFBoolean proof |
| Builder | `$.profileAppData.archive` | raw isEqualToString: before NSString proof |
| Builder | `$.globalSafari.included` | raw boolValue before exact CFBoolean proof |
| Builder | `$.globalSafari.archive` | raw isEqualToString: before NSString proof |
| Builder | `$.systemGlobalLibrary.included` | raw boolValue before exact CFBoolean proof |
| Builder | `$.sharedSystemDB.included` | raw boolValue before exact CFBoolean proof |
| Validator | `$.schema.identifier` | raw isEqualToString: before NSString proof |
| Validator | `$.schema.digestAlgorithm` | raw isEqualToString: before NSString proof |
| Validator | `$.publication.protocol` | raw isEqualToString: before NSString proof |
| Validator | `$.publication.contentState` | raw isEqualToString: before NSString proof |
| Validator | `$.backupMode` | raw isEqualToString: before NSString proof |
| Validator | `$.restoreCompatibility.targetBundleID` | raw isEqualToString: before NSString proof |
| Validator | `$.artifacts[*].path/name` | raw isEqualToString: before both NSString proofs |
| Validator | `$.artifacts[*].policy.*` | four raw isEqualToString: families before NSString proof |
| Validator | `$.archiveChecksum` | raw isEqualToString: before NSString proof |
| Validator | `$.options.includeAppGroups` | raw boolValue before exact CFBoolean proof |
| Validator | `$.options.includePreferences` | raw boolValue before exact CFBoolean proof |
| Validator | `$.options.includeKeychain` | raw boolValue before exact CFBoolean proof |
| Validator | `$.preferences.included` | raw boolValue before exact CFBoolean proof |
| Validator | `$.preferences.archive` | raw isEqualToString: before NSString proof |
| Validator | `$.keychain.included` | raw boolValue before exact CFBoolean proof |
| Validator | `$.keychain.archive/method` | raw isEqualToString: before NSString proof |
| Validator | `$.profileAppData.included/archive` | raw boolValue/isEqualToString before proof |
| Validator | `$.globalSafari.included/archive` | raw boolValue/isEqualToString before proof |
| Validator | `$.systemGlobalLibrary.included` | raw boolValue before exact CFBoolean proof |
| Validator | `$.sharedSystemDB.included` | raw boolValue before exact CFBoolean proof |

Baseline raw dictionary-subscript `boolValue` patterns: **16**. Corrected: **0**.
Baseline raw dictionary-subscript `isEqualToString:` patterns: **17**. Corrected: **0**.

## Builder typed extraction

`PXBackupManifestV4.m` now centralizes string extraction in exactly one required-string helper and one optional-string helper. Both prove runtime `NSString`, enforce the existing text/NUL/lossless UTF-8/size contract, and assign the output only after success. Comparisons operate only on typed locals such as `backupMode`, `restoreTargetBundleIdentifier`, `preferencesArchive`, `keychainArchive`, `keychainMethod`, `profileArchive`, and `safariArchive`.

The centralized exact-Boolean helper performs the required sequence:

```text
NSNumber runtime class proof
→ exact CFBoolean type proof
→ boolValue extraction
→ output assignment
```

Integer `@0`/`@1`, strings, arrays, dictionaries, null, dates, data, and custom objects are rejected before `boolValue`. Profile and Safari use separate typed BOOL locals. Malformed field types map to `PXBackupManifestV4ErrorInvalidFieldValue`; logical request/factual contradictions retain `InconsistentOptions`.

The public factory clears `*error` at entry, has no raw failure return inside the normal path, clears error again on success, and has a final `@try/@catch` fail-closed boundary using the v4 error domain without exposing raw values.

## Validator typed extraction

`PXManifestV4ReadString` proves runtime `NSString`, NUL absence, lossless UTF-8 and the v4 1 MiB bound before extraction or comparison. `PXManifestV4ReadBoolean` proves runtime `NSNumber` and exact CFBoolean before its only `boolValue` call. Output pointers are assigned only on success.

Typed locals are used for schema identifier, digest algorithm, publication protocol/content state, backup mode, Restore target bundle, artifact name/path/digest, archive checksum, excluded locator/method values and all component inclusion/request Booleans.

## Policy dictionary proof

`PXManifestV4PolicyMatches` first proves the exact four-key dictionary, then passes `kind`, `requirement`, `failureDisposition`, and `emptyFilePolicy` through the centralized string reader. Exact policy comparisons occur only after all four typed locals exist. Wrong types return `NO`; the caller converts that result into a validator NSError. The zero-byte rule remains unchanged: only `sharedSystemDatabase + allow` accepts size zero.

## Schema, publication, artifact and component proof

- Schema/publication values are extracted as typed strings before exact comparison.
- Artifact `name`, `path`, and `sha256` are typed before path validation, equality, digest validation, duplicate detection or map mutation.
- `archiveChecksum` is typed and digest-validated before comparison with ApplicationData checksum.
- All eleven request/inclusion Boolean call sites in each implementation use exact-Boolean helpers.
- Preferences, Keychain, Profile, Safari, system-global and shared-DB consistency checks use typed locals.
- State mutation follows proof: records, reference sets, count totals and factual option arrays are updated only after relevant type/value checks.

## Validator error contract

The eager placeholder error at the beginning of `PXManifestValidateV4` was removed. Strict-v4 validation contains zero bare `return NO;` statements; propagated failures route through `PXManifestV4FailureResult`, which supplies a generic validator error only when a called helper did not already set one. Direct failures use existing validator codes and stable paths.

Public contract:

```text
entry   → clear *error
success → YES + nil error
failure → NO + nonnil PXBackupManifestValidator error
catch   → NO + InvalidFieldType error
```

The public v4 dispatch wraps graph and strict-schema validation in `@try/@catch`; no caught exception or raw manifest value is exposed in error descriptions.

## Exception harness and malformed matrices

A temporary Objective-C harness outside the repository contains explicit nested substitutions and wraps each public builder/validator call in `@try/@catch`. Strict frontend result: PASS.

```text
Builder malformed cases declared:   166
Validator malformed cases declared: 262
Objective-C harness frontend exit:   0
Harness source committed:            no
```

This Windows workspace has no `clang` executable, Objective-C runtime, GNUstep Foundation, Theos, or Apple SDK, so the native harness could not be linked and executed. An executable semantic model using the same type-proof order ran all 428 substitutions:

```text
builder cases:             166
builder modeled exceptions: 0
builder contract failures:   0
validator cases:           262
validator modeled exceptions:0
validator contract failures: 0
```

The distinction is material: native runtime execution remains a GitHub Actions/device gate; the report does not claim a linked Objective-C runtime result that this workspace cannot produce.

## Valid-v4 and version non-regression

The TASK-3.6 semantic model was rerun:

```text
valid manifest combinations: 1024 PASS
invalid semantic mutations:    27 PASS
version 2: legacy
version 3: legacy
version 4: strict
positive unknown: generic graph/version only
```

The legacy v2/v3 validation tail remains byte-identical with SHA-256:

`4ed81dcf438f0448352f3e36d67149b1aee80ca22b74cb53bf5efd794d0ddbb5` — PASS

Schema invariants remain: 23 builder input keys, 33 v4 root keys, unchanged schema/publication constants, relative `path == name`, canonical policy strings, one required ApplicationData record first, exact aggregate/reference coverage, empty excluded Preferences archive and factual option arrays.

## Protected production SHA-256 before and after

Protected production files checked: **303**. Changed: **0**.

| File | Before SHA-256 | After SHA-256 | Before bytes | After bytes | Gate |
|---|---|---|---:|---:|---|
| `.DS_Store` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | 14340 | 14340 | PASS |
| `.github/workflows/build-ios-arm.yml` | `43814c1ab1f47aee5dd88864aefc2068de5f91f23ce24df96394647958c5706e` | `43814c1ab1f47aee5dd88864aefc2068de5f91f23ce24df96394647958c5706e` | 4548 | 4548 | PASS |
| `.gitignore` | `5f4946295e8cee11cf3e4b1ea686c1abdf2c68aeb1c49f482452e889b68bcec2` | `5f4946295e8cee11cf3e4b1ea686c1abdf2c68aeb1c49f482452e889b68bcec2` | 111 | 111 | PASS |
| `Agent.md` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | 6521 | 6521 | PASS |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | 1442 | PASS |
| `AppDataBackupManager.m` | `e13678ed7cb32849404671f8ac35cdaa3c191d84212bd200cdb065e3490e063a` | `e13678ed7cb32849404671f8ac35cdaa3c191d84212bd200cdb065e3490e063a` | 217976 | 217976 | PASS |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 | 336 | PASS |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 | 28132 | PASS |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | 4768 | PASS |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | 370484 | PASS |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | 1061 | 1061 | PASS |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | 11626 | 11626 | PASS |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | 1356 | PASS |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | 11499 | PASS |
| `AppVersionManager.h` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | 1295 | 1295 | PASS |
| `AppVersionManager.m` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | 15049 | 15049 | PASS |
| `AppVersionSpoofingViewController.h` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | 678 | 678 | PASS |
| `AppVersionSpoofingViewController.m` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | 85181 | 85181 | PASS |
| `Assets.xcassets/.DS_Store` | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | 6148 | 6148 | PASS |
| `Assets.xcassets/AppIcon.appiconset/114.png` | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | 8495 | 8495 | PASS |
| `Assets.xcassets/AppIcon.appiconset/120.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 | 9368 | PASS |
| `Assets.xcassets/AppIcon.appiconset/180.png` | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | 17711 | 17711 | PASS |
| `Assets.xcassets/AppIcon.appiconset/29.png` | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | 1323 | 1323 | PASS |
| `Assets.xcassets/AppIcon.appiconset/40.png` | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | 2181 | 2181 | PASS |
| `Assets.xcassets/AppIcon.appiconset/57.png` | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | 3277 | 3277 | PASS |
| `Assets.xcassets/AppIcon.appiconset/58.png` | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | 3350 | 3350 | PASS |
| `Assets.xcassets/AppIcon.appiconset/60.png` | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | 3536 | 3536 | PASS |
| `Assets.xcassets/AppIcon.appiconset/80.png` | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | 5273 | 5273 | PASS |
| `Assets.xcassets/AppIcon.appiconset/87.png` | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | 5820 | 5820 | PASS |
| `Assets.xcassets/AppIcon.appiconset/Contents.json` | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | 1655 | 1655 | PASS |
| `Assets.xcassets/AppIcon.appiconset/Thumbs.db` | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | 3584 | 3584 | PASS |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | 159 | PASS |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | 9567 | PASS |
| `BottomButtons.h` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | 849 | 849 | PASS |
| `BottomButtons.m` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | 24605 | 24605 | PASS |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | 1562 | 1562 | PASS |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | 49583 | 49583 | PASS |
| `ContainerManager.h` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | 1109 | 1109 | PASS |
| `ContainerManager.m` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | 4393 | 4393 | PASS |
| `CopyHelper.h` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | 531 | 531 | PASS |
| `CopyHelper.m` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | 6147 | 6147 | PASS |
| `DEBIAN/postinst` | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | 4119 | 4119 | PASS |
| `DEBIAN/preinst` | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | 198 | 198 | PASS |
| `DEBIAN/prerm` | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | 126 | 126 | PASS |
| `DeviceSpecificSpoofingViewController+EditLabel.h` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | 161 | 161 | PASS |
| `DeviceSpecificSpoofingViewController+EditLabel.m` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | 9198 | 9198 | PASS |
| `DeviceSpecificSpoofingViewController+ProfileManagerDelegate.m` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | 508 | 508 | PASS |
| `DeviceSpecificSpoofingViewController.h` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | 134 | 134 | PASS |
| `DeviceSpecificSpoofingViewController.m` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | 56660 | 56660 | PASS |
| `DevicesViewController.h` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | 1160 | 1160 | PASS |
| `DevicesViewController.m` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | 38275 | 38275 | PASS |
| `DomainManagementViewController.h` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | 112 | 112 | PASS |
| `DomainManagementViewController.m` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | 30905 | 30905 | PASS |
| `DoorDashOrderViewController.h` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | 668 | 668 | PASS |
| `DoorDashOrderViewController.m` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | 37685 | 37685 | PASS |
| `DownloadResourcesViewController.h` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | 96 | 96 | PASS |
| `DownloadResourcesViewController.m` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | 2456 | 2456 | PASS |
| `FileManagerViewController.h` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | 658 | 658 | PASS |
| `FileManagerViewController.m` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | 55902 | 55902 | PASS |
| `FixVersionAppsViewController.h` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | 93 | 93 | PASS |
| `FixVersionAppsViewController.m` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | 7764 | 7764 | PASS |
| `FreezeManager.h` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | 385 | 385 | PASS |
| `FreezeManager.m` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | 8975 | 8975 | PASS |
| `Icon.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 | 9368 | PASS |
| `Improvement_Plan.md` | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | 12526 | 12526 | PASS |
| `Info.plist` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | 7202 | 7202 | PASS |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | 153 | PASS |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | 10227 | PASS |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | 4280 | PASS |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | 27970 | PASS |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | 14129 | 14129 | PASS |
| `LaunchScreen.storyboard` | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | 3134 | 3134 | PASS |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | 9146 | 9146 | PASS |
| `Making` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `MatrixRainView.h` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | 273 | 273 | PASS |
| `Newplan.md` | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | 17391 | 17391 | PASS |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 | 2039 | PASS |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 | 18688 | PASS |
| `PXAppGroupRestoreTransaction.h` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 | 2235 | PASS |
| `PXAppGroupRestoreTransaction.m` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 | 138376 | PASS |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 | 2361 | PASS |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | 89098 | PASS |
| `PXBackupArtifactPolicy.h` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 | 1648 | PASS |
| `PXBackupArtifactPolicy.m` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 | 4536 | PASS |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 | 1949 | PASS |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 | 43911 | PASS |
| `PXBackupArtifactWriter.h` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 | 2948 | PASS |
| `PXBackupArtifactWriter.m` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 | 83333 | PASS |
| `PXBackupBundleLock.h` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 | 1714 | PASS |
| `PXBackupBundleLock.m` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 | 36342 | PASS |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | 2354 | PASS |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | 945 | PASS |
| `PXBackupPublicationWorkspace.h` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 | 1869 | PASS |
| `PXBackupPublicationWorkspace.m` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 | 48086 | PASS |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | 1288 | 1288 | PASS |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | 4389 | 4389 | PASS |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | 3467 | 3467 | PASS |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | 10564 | 10564 | PASS |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | 1290 | 1290 | PASS |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | 8332 | 8332 | PASS |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | 1213 | 1213 | PASS |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | 32523 | 32523 | PASS |
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 | 2061 | PASS |
| `PXMainDataRestoreTransaction.m` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 | 115847 | PASS |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 | 2511 | PASS |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 | 67751 | PASS |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 | 4209 | PASS |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 | 100980 | PASS |
| `PXOptionalRestoreTransaction.h` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 | 4050 | PASS |
| `PXOptionalRestoreTransaction.m` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 | 240408 | PASS |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 | 1691 | PASS |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 | 5304 | PASS |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | 4947 | PASS |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | 48523 | PASS |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | 4512 | PASS |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | 15842 | PASS |
| `PlistViewerViewController.h` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | 184 | 184 | PASS |
| `PlistViewerViewController.m` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | 26767 | 26767 | PASS |
| `ProfileButtonsView.h` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | 254 | 254 | PASS |
| `ProfileButtonsView.m` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | 5381 | 5381 | PASS |
| `ProfileCreationViewController.h` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | 388 | 388 | PASS |
| `ProfileCreationViewController.m` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | 7575 | 7575 | PASS |
| `ProfileManagerViewController.h` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | 783 | 783 | PASS |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 | 159713 | PASS |
| `ProgressHUDView.h` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | 522 | 522 | PASS |
| `ProgressHUDView.m` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | 2263 | 2263 | PASS |
| `ProjectX` | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | 1691136 | 1691136 | PASS |
| `ProjectX.entitlements` | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | 1747 | 1747 | PASS |
| `ProjectX.h` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | 1623 | 1623 | PASS |
| `ProjectXInstaller.h` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | 1231 | 1231 | PASS |
| `ProjectXInstaller.m` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | 1898 | 1898 | PASS |
| `ProjectXSceneDelegate.h` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | 192 | 192 | PASS |
| `ProjectXSceneDelegate.m` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | 12181 | 12181 | PASS |
| `ProjectXTweak.dylib` | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | 945152 | 945152 | PASS |
| `ProjectXTweak.plist` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | 429 | 429 | PASS |
| `ProjectXTweak/AAA_TestCtor.m` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | 1614 | 1614 | PASS |
| `ProjectXTweak/AppContainerHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `ProjectXTweak/AppGroupHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `ProjectXTweak/AppInstallHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `ProjectXTweak/AppVersionHooks.h` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | 546 | 546 | PASS |
| `ProjectXTweak/AppVersionHooks.x` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | 25202 | 25202 | PASS |
| `ProjectXTweak/BatteryHooks.x` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | 17019 | 17019 | PASS |
| `ProjectXTweak/BootTimeHooks.x` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | 26933 | 26933 | PASS |
| `ProjectXTweak/CanvasFingerprintHooks.x` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | 27600 | 27600 | PASS |
| `ProjectXTweak/CoreDataHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `ProjectXTweak/DeviceModelHooks.x` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | 9012 | 9012 | PASS |
| `ProjectXTweak/DeviceSpecHooks.x` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | 81702 | 81702 | PASS |
| `ProjectXTweak/DomainBlockingHooks.x` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | 27065 | 27065 | PASS |
| `ProjectXTweak/FirebasePerfDisableScoped.x` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | 2515 | 2515 | PASS |
| `ProjectXTweak/HookOwnership.h` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | 541 | 541 | PASS |
| `ProjectXTweak/IOSVersionHooks.x` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | 112809 | 112809 | PASS |
| `ProjectXTweak/JailbreakBypassHooks.x` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | 142382 | 142382 | PASS |
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `ProjectXTweak/LocaleTimeZoneHooks.x` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | 4909 | 4909 | PASS |
| `ProjectXTweak/Makefile.bak` | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | 999 | 999 | PASS |
| `ProjectXTweak/MethodSwizzler.h` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | 341 | 341 | PASS |
| `ProjectXTweak/MethodSwizzler.m` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | 1903 | 1903 | PASS |
| `ProjectXTweak/MissingSpoofHooks.x` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | 9793 | 9793 | PASS |
| `ProjectXTweak/MobileGestalt.h` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | 11371 | 11371 | PASS |
| `ProjectXTweak/NetworkConnectionTypeHooks.x` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | 56573 | 56573 | PASS |
| `ProjectXTweak/ObjcClassPairGuard.x` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | 5439 | 5439 | PASS |
| `ProjectXTweak/PXFileDebug.h` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | 6957 | 6957 | PASS |
| `ProjectXTweak/PXNativeHookCoordinator.h` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | 9000 | 9000 | PASS |
| `ProjectXTweak/PXNativeHookCoordinator.m` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | 28291 | 28291 | PASS |
| `ProjectXTweak/PXScope.h` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | 1747 | 1747 | PASS |
| `ProjectXTweak/PXScope.m` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | 20405 | 20405 | PASS |
| `ProjectXTweak/PasteboardHooks.x` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | 37855 | 37855 | PASS |
| `ProjectXTweak/SpringBoardLaunchHook.x` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | 16185 | 16185 | PASS |
| `ProjectXTweak/StorageHooks.x` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | 41482 | 41482 | PASS |
| `ProjectXTweak/ThemeHooks.x` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | 19043 | 19043 | PASS |
| `ProjectXTweak/Tweak.x` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | 196955 | 196955 | PASS |
| `ProjectXTweak/UUIDHooks.x` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | 43164 | 43164 | PASS |
| `ProjectXTweak/UberURLHooks.x` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | 40212 | 40212 | PASS |
| `ProjectXTweak/UserDefaultsHooks.x` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | 26089 | 26089 | PASS |
| `ProjectXTweak/VPNDetectionBypass.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `ProjectXTweak/WiFiHook.x` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | 40848 | 40848 | PASS |
| `ProjectXViewController.h` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | 853 | 853 | PASS |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | 372278 | PASS |
| `README.md` | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | 184 | 184 | PASS |
| `SecurityTabViewController+IPMonitorInfo.m` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | 967 | 967 | PASS |
| `SecurityTabViewController.h` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | 5441 | 5441 | PASS |
| `SecurityTabViewController.m` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | 293431 | 293431 | PASS |
| `TabBarController+DeviceAlerts.h` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `TabBarController+DeviceAlerts.m` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | 0 | PASS |
| `TabBarController.h` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | 1019 | 1019 | PASS |
| `TabBarController.m` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | 28147 | 28147 | PASS |
| `TestCtorTweak/Makefile` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | 217 | 217 | PASS |
| `TestCtorTweak/TestCtorTweak.plist` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | 315 | 315 | PASS |
| `TestCtorTweak/Tweak.x` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | 351 | 351 | PASS |
| `ToolViewController.h` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | 280 | 280 | PASS |
| `ToolViewController.m` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | 59814 | 59814 | PASS |
| `URLMonitor.h` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | 727 | 727 | PASS |
| `URLMonitor.m` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | 8827 | 8827 | PASS |
| `UberOrderViewController.h` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | 608 | 608 | PASS |
| `UberOrderViewController.m` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | 39801 | 39801 | PASS |
| `VersionManagementViewController.h` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | 955 | 955 | PASS |
| `VersionManagementViewController.m` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | 68330 | 68330 | PASS |
| `WeaponXGuardian.m` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | 16859 | 16859 | PASS |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | 386 | PASS |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | 21970 | PASS |
| `WeaponXMountDaemon/WeaponXDaemon.m` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | 19900 | 19900 | PASS |
| `WeaponXMountDaemon/WeaponXMountDaemon.m` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | 11205 | 11205 | PASS |
| `WebKit_Filtering.md` | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | 5499 | 5499 | PASS |
| `com.hydra.weaponx.guardian.plist` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | 1145 | 1145 | PASS |
| `common/AppContainerUUIDManager.h` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | 542 | 542 | PASS |
| `common/AppContainerUUIDManager.m` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | 3559 | 3559 | PASS |
| `common/AppGroupUUIDManager.h` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | 406 | 406 | PASS |
| `common/AppGroupUUIDManager.m` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | 3449 | 3449 | PASS |
| `common/AppInstallUUIDManager.h` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | 532 | 532 | PASS |
| `common/AppInstallUUIDManager.m` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | 3539 | 3539 | PASS |
| `common/BatteryManager.h` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | 685 | 685 | PASS |
| `common/BatteryManager.m` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | 13918 | 13918 | PASS |
| `common/CarrierDB.h` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | 1418 | 1418 | PASS |
| `common/CarrierDB.m` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | 12622 | 12622 | PASS |
| `common/CoreDataUUIDManager.h` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | 422 | 422 | PASS |
| `common/CoreDataUUIDManager.m` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | 3450 | 3450 | PASS |
| `common/DBDebugLogger.h` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | 262 | 262 | PASS |
| `common/DBDebugLogger.m` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | 2783 | 2783 | PASS |
| `common/DeviceModelManager.h` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | 1697 | 1697 | PASS |
| `common/DeviceModelManager.m` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | 37928 | 37928 | PASS |
| `common/DeviceNameManager.h` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | 385 | 385 | PASS |
| `common/DeviceNameManager.m` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | 11474 | 11474 | PASS |
| `common/DomainBlockingSettings.h` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | 882 | 882 | PASS |
| `common/DomainBlockingSettings.m` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | 12424 | 12424 | PASS |
| `common/DyldCacheUUIDManager.h` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | 411 | 411 | PASS |
| `common/DyldCacheUUIDManager.m` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | 3458 | 3458 | PASS |
| `common/IDFAManager.h` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | 335 | 335 | PASS |
| `common/IDFAManager.m` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | 2745 | 2745 | PASS |
| `common/IDFVManager.h` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | 335 | 335 | PASS |
| `common/IDFVManager.m` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | 2712 | 2712 | PASS |
| `common/IOSBuildDB.h` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | 1092 | 1092 | PASS |
| `common/IOSBuildDB.m` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | 9567 | 9567 | PASS |
| `common/IOSVersionInfo.h` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | 592 | 592 | PASS |
| `common/IOSVersionInfo.m` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | 15529 | 15529 | PASS |
| `common/IPMonitorService.h` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | 224 | 224 | PASS |
| `common/IPMonitorService.m` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | 25567 | 25567 | PASS |
| `common/IPStatusCacheManager.h` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | 990 | 990 | PASS |
| `common/IPStatusCacheManager.m` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | 12562 | 12562 | PASS |
| `common/IPStatusViewController.h` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | 271 | 271 | PASS |
| `common/IPStatusViewController.m` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | 62749 | 62749 | PASS |
| `common/IPhoneModelDB.h` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | 885 | 885 | PASS |
| `common/IPhoneModelDB.m` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | 6198 | 6198 | PASS |
| `common/IdentifierManager.h` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | 3082 | 3082 | PASS |
| `common/IdentifierManager.m` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | 160824 | 160824 | PASS |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | 405 | PASS |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | 3479 | PASS |
| `common/LocationSpoofingManager.h` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | 3202 | 3202 | PASS |
| `common/LocationSpoofingManager.m` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | 65282 | 65282 | PASS |
| `common/NetworkManager.h` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | 1065 | 1065 | PASS |
| `common/NetworkManager.m` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | 17926 | 17926 | PASS |
| `common/PXPaths.h` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | 616 | 616 | PASS |
| `common/PXPaths.m` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | 2283 | 2283 | PASS |
| `common/PXProcessKiller.h` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | 554 | 554 | PASS |
| `common/PXProcessKiller.m` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | 4565 | 4565 | PASS |
| `common/PassThroughWindow.h` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | 75 | 75 | PASS |
| `common/PassThroughWindow.m` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | 486 | 486 | PASS |
| `common/PasteboardUUIDManager.h` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | 415 | 415 | PASS |
| `common/PasteboardUUIDManager.m` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | 3466 | 3466 | PASS |
| `common/ProfileIndicatorView.h` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | 174 | 174 | PASS |
| `common/ProfileIndicatorView.m` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | 56659 | 56659 | PASS |
| `common/ProfileManager.h` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | 2322 | 2322 | PASS |
| `common/ProfileManager.m` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | 72206 | 72206 | PASS |
| `common/ProjectXLogging.h` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | 460 | 460 | PASS |
| `common/ProjectXLogging.m` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | 4712 | 4712 | PASS |
| `common/ScoreMeterView.h` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | 200 | 200 | PASS |
| `common/ScoreMeterView.m` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | 2650 | 2650 | PASS |
| `common/SerialNumberManager.h` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | 486 | 486 | PASS |
| `common/SerialNumberManager.m` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | 6005 | 6005 | PASS |
| `common/StorageManager.h` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | 3350 | 3350 | PASS |
| `common/StorageManager.m` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | 9610 | 9610 | PASS |
| `common/SystemUUIDManager.h` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | 387 | 387 | PASS |
| `common/SystemUUIDManager.m` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | 3422 | 3422 | PASS |
| `common/UIButton+SafeConfiguration.h` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | 984 | 984 | PASS |
| `common/UIButton+SafeConfiguration.m` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | 1672 | 1672 | PASS |
| `common/UIButtonCompat.h` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | 1581 | 1581 | PASS |
| `common/UIButtonCompat.m` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | 5833 | 5833 | PASS |
| `common/UptimeManager.h` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | 1039 | 1039 | PASS |
| `common/UptimeManager.m` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | 18221 | 18221 | PASS |
| `common/UserDefaultsUUIDManager.h` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | 425 | 425 | PASS |
| `common/UserDefaultsUUIDManager.m` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | 3484 | 3484 | PASS |
| `common/VersionCompare.h` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | 519 | 519 | PASS |
| `common/VersionCompare.m` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | 1936 | 1936 | PASS |
| `common/WiFiManager.h` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | 664 | 664 | PASS |
| `common/WiFiManager.m` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | 26544 | 26544 | PASS |
| `control` | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | 469 | 469 | PASS |
| `data/carrier_db.json` | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | 17230 | 17230 | PASS |
| `ent.plist` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | 2881 | 2881 | PASS |
| `iOSVersionManager.h` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | 404 | 404 | PASS |
| `include/.DS_Store` | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | 6148 | 6148 | PASS |
| `include/HookKit` | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | 38 | 38 | PASS |
| `include/ellekit/ellekit.h` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | 5050 | 5050 | PASS |
| `include/substrate.h` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | 44 | 44 | PASS |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | 912 | PASS |
| `layout/Library/libSandy/projectx_filesystem_access.plist` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | 2557 | 2557 | PASS |
| `location.png` | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | 6132 | 6132 | PASS |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | 23462 | 23462 | PASS |
| `postinst` | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | 6118 | 6118 | PASS |
| `scripts/audit_native_hooks.sh` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | 4225 | 4225 | PASS |
| `scripts/keychain_backup.sh` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 | 32096 | PASS |
| `scripts/setup_altlist.sh` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | 1567 | 1567 | PASS |
| `setup_app.sh` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | 1679 | 1679 | PASS |
| `setup_dependencies.sh` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | 524 | 524 | PASS |
| `weaponx-debug.sh` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | 6254 | 6254 | PASS |

This includes byte-stable public headers, `AppDataBackupManager.h/.m`, TASK-3.1 through TASK-3.5 sources, Restore sources, UI/controllers, Makefile, CommandRunner, and Keychain helper/bridge/script sources. Git production diff outside the two authorized `.m` files is zero.

## Static gate table

| Gate | Required | Result |
|---|---:|---:|
| Builder exact-Boolean helper definitions | 1 | 1 |
| Validator exact-Boolean helper definitions | 1 | 1 |
| Validator policy string-class gate | 1 | 1 |
| Builder exact-Boolean call sites | explicit fields | 11 |
| Validator exact-Boolean call sites | explicit fields | 11 |
| Builder unsafe raw boolValue sites | 0 | 0 |
| Validator strict-v4 unsafe raw boolValue sites | 0 | 0 |
| Builder unsafe raw isEqualToString sites | 0 | 0 |
| Validator strict-v4 unsafe raw isEqualToString sites | 0 | 0 |
| Validator eager placeholder block | 0 | 0 |
| Strict-v4 bare return-NO sites | 0 | 0 |
| Builder public try/catch boundary | present | PASS |
| Validator public v4 try/catch boundary | present | PASS |
| Builder strict frontend | exit 0 | PASS |
| Validator strict frontend | exit 0 | PASS |
| Objective-C exception harness frontend | exit 0 | PASS |
| Public v4 header diff | 0 | 0 |
| Validator header diff | 0 | 0 |
| Manager source diff | 0 | 0 |
| Legacy v2/v3 tail diff | 0 | 0 |
| Other production diff | 0 | 0 |

## Explicit scenarios

Explicit scenarios: 428.

| # | Surface | Field | Substitution | Expected result |
|---:|---|---|---|---|
| 1 | Builder | `backupMode` | NSNumber | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 2 | Builder | `backupMode` | NSDictionary | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 3 | Builder | `backupMode` | NSArray | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 4 | Builder | `backupMode` | NSNull | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 5 | Builder | `backupMode` | NSDate | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 6 | Builder | `backupMode` | NSData | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 7 | Builder | `backupMode` | empty string | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 8 | Builder | `backupMode` | embedded \0 | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 9 | Builder | `restoreCompatibility.targetBundleID` | NSNumber | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 10 | Builder | `restoreCompatibility.targetBundleID` | NSDictionary | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 11 | Builder | `restoreCompatibility.targetBundleID` | NSArray | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 12 | Builder | `restoreCompatibility.targetBundleID` | NSNull | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 13 | Builder | `restoreCompatibility.targetBundleID` | NSDate | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 14 | Builder | `restoreCompatibility.targetBundleID` | NSData | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 15 | Builder | `restoreCompatibility.targetBundleID` | empty string | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 16 | Builder | `restoreCompatibility.targetBundleID` | embedded \0 | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 17 | Builder | `preferences.archive` | NSNumber | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 18 | Builder | `preferences.archive` | NSDictionary | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 19 | Builder | `preferences.archive` | NSArray | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 20 | Builder | `preferences.archive` | NSNull | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 21 | Builder | `preferences.archive` | NSDate | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 22 | Builder | `preferences.archive` | NSData | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 23 | Builder | `preferences.archive` | empty string | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 24 | Builder | `preferences.archive` | embedded \0 | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 25 | Builder | `keychain.archive` | NSNumber | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 26 | Builder | `keychain.archive` | NSDictionary | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 27 | Builder | `keychain.archive` | NSArray | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 28 | Builder | `keychain.archive` | NSNull | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 29 | Builder | `keychain.archive` | NSDate | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 30 | Builder | `keychain.archive` | NSData | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 31 | Builder | `keychain.archive` | empty string | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 32 | Builder | `keychain.archive` | embedded \0 | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 33 | Builder | `keychain.method` | NSNumber | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 34 | Builder | `keychain.method` | NSDictionary | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 35 | Builder | `keychain.method` | NSArray | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 36 | Builder | `keychain.method` | NSNull | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 37 | Builder | `keychain.method` | NSDate | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 38 | Builder | `keychain.method` | NSData | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 39 | Builder | `keychain.method` | empty string | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 40 | Builder | `keychain.method` | embedded \0 | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 41 | Builder | `profileAppData.archive` | NSNumber | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 42 | Builder | `profileAppData.archive` | NSDictionary | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 43 | Builder | `profileAppData.archive` | NSArray | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 44 | Builder | `profileAppData.archive` | NSNull | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 45 | Builder | `profileAppData.archive` | NSDate | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 46 | Builder | `profileAppData.archive` | NSData | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 47 | Builder | `profileAppData.archive` | empty string | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 48 | Builder | `profileAppData.archive` | embedded \0 | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 49 | Builder | `globalSafari.archive` | NSNumber | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 50 | Builder | `globalSafari.archive` | NSDictionary | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 51 | Builder | `globalSafari.archive` | NSArray | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 52 | Builder | `globalSafari.archive` | NSNull | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 53 | Builder | `globalSafari.archive` | NSDate | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 54 | Builder | `globalSafari.archive` | NSData | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 55 | Builder | `globalSafari.archive` | empty string | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 56 | Builder | `globalSafari.archive` | embedded \0 | nil result; PXBackupManifestV4ErrorInvalidFieldValue; no exception |
| 57 | Builder | `options.includeAppGroups` | NSNumber @42 | nil result; v4 NSError; no exception |
| 58 | Builder | `options.includeAppGroups` | NSDictionary | nil result; v4 NSError; no exception |
| 59 | Builder | `options.includeAppGroups` | NSArray | nil result; v4 NSError; no exception |
| 60 | Builder | `options.includeAppGroups` | NSNull | nil result; v4 NSError; no exception |
| 61 | Builder | `options.includeAppGroups` | NSDate | nil result; v4 NSError; no exception |
| 62 | Builder | `options.includeAppGroups` | NSData | nil result; v4 NSError; no exception |
| 63 | Builder | `options.includeAppGroups` | integer @0 | nil result; v4 NSError; no exception |
| 64 | Builder | `options.includeAppGroups` | integer @1 | nil result; v4 NSError; no exception |
| 65 | Builder | `options.includeAppGroups` | string true | nil result; v4 NSError; no exception |
| 66 | Builder | `options.includeAppGroups` | string false | nil result; v4 NSError; no exception |
| 67 | Builder | `options.includePreferences` | NSNumber @42 | nil result; v4 NSError; no exception |
| 68 | Builder | `options.includePreferences` | NSDictionary | nil result; v4 NSError; no exception |
| 69 | Builder | `options.includePreferences` | NSArray | nil result; v4 NSError; no exception |
| 70 | Builder | `options.includePreferences` | NSNull | nil result; v4 NSError; no exception |
| 71 | Builder | `options.includePreferences` | NSDate | nil result; v4 NSError; no exception |
| 72 | Builder | `options.includePreferences` | NSData | nil result; v4 NSError; no exception |
| 73 | Builder | `options.includePreferences` | integer @0 | nil result; v4 NSError; no exception |
| 74 | Builder | `options.includePreferences` | integer @1 | nil result; v4 NSError; no exception |
| 75 | Builder | `options.includePreferences` | string true | nil result; v4 NSError; no exception |
| 76 | Builder | `options.includePreferences` | string false | nil result; v4 NSError; no exception |
| 77 | Builder | `options.includeKeychain` | NSNumber @42 | nil result; v4 NSError; no exception |
| 78 | Builder | `options.includeKeychain` | NSDictionary | nil result; v4 NSError; no exception |
| 79 | Builder | `options.includeKeychain` | NSArray | nil result; v4 NSError; no exception |
| 80 | Builder | `options.includeKeychain` | NSNull | nil result; v4 NSError; no exception |
| 81 | Builder | `options.includeKeychain` | NSDate | nil result; v4 NSError; no exception |
| 82 | Builder | `options.includeKeychain` | NSData | nil result; v4 NSError; no exception |
| 83 | Builder | `options.includeKeychain` | integer @0 | nil result; v4 NSError; no exception |
| 84 | Builder | `options.includeKeychain` | integer @1 | nil result; v4 NSError; no exception |
| 85 | Builder | `options.includeKeychain` | string true | nil result; v4 NSError; no exception |
| 86 | Builder | `options.includeKeychain` | string false | nil result; v4 NSError; no exception |
| 87 | Builder | `preferences.included` | NSNumber @42 | nil result; v4 NSError; no exception |
| 88 | Builder | `preferences.included` | NSDictionary | nil result; v4 NSError; no exception |
| 89 | Builder | `preferences.included` | NSArray | nil result; v4 NSError; no exception |
| 90 | Builder | `preferences.included` | NSNull | nil result; v4 NSError; no exception |
| 91 | Builder | `preferences.included` | NSDate | nil result; v4 NSError; no exception |
| 92 | Builder | `preferences.included` | NSData | nil result; v4 NSError; no exception |
| 93 | Builder | `preferences.included` | integer @0 | nil result; v4 NSError; no exception |
| 94 | Builder | `preferences.included` | integer @1 | nil result; v4 NSError; no exception |
| 95 | Builder | `preferences.included` | string true | nil result; v4 NSError; no exception |
| 96 | Builder | `preferences.included` | string false | nil result; v4 NSError; no exception |
| 97 | Builder | `keychain.included` | NSNumber @42 | nil result; v4 NSError; no exception |
| 98 | Builder | `keychain.included` | NSDictionary | nil result; v4 NSError; no exception |
| 99 | Builder | `keychain.included` | NSArray | nil result; v4 NSError; no exception |
| 100 | Builder | `keychain.included` | NSNull | nil result; v4 NSError; no exception |
| 101 | Builder | `keychain.included` | NSDate | nil result; v4 NSError; no exception |
| 102 | Builder | `keychain.included` | NSData | nil result; v4 NSError; no exception |
| 103 | Builder | `keychain.included` | integer @0 | nil result; v4 NSError; no exception |
| 104 | Builder | `keychain.included` | integer @1 | nil result; v4 NSError; no exception |
| 105 | Builder | `keychain.included` | string true | nil result; v4 NSError; no exception |
| 106 | Builder | `keychain.included` | string false | nil result; v4 NSError; no exception |
| 107 | Builder | `profileAppData.included` | NSNumber @42 | nil result; v4 NSError; no exception |
| 108 | Builder | `profileAppData.included` | NSDictionary | nil result; v4 NSError; no exception |
| 109 | Builder | `profileAppData.included` | NSArray | nil result; v4 NSError; no exception |
| 110 | Builder | `profileAppData.included` | NSNull | nil result; v4 NSError; no exception |
| 111 | Builder | `profileAppData.included` | NSDate | nil result; v4 NSError; no exception |
| 112 | Builder | `profileAppData.included` | NSData | nil result; v4 NSError; no exception |
| 113 | Builder | `profileAppData.included` | integer @0 | nil result; v4 NSError; no exception |
| 114 | Builder | `profileAppData.included` | integer @1 | nil result; v4 NSError; no exception |
| 115 | Builder | `profileAppData.included` | string true | nil result; v4 NSError; no exception |
| 116 | Builder | `profileAppData.included` | string false | nil result; v4 NSError; no exception |
| 117 | Builder | `globalSafari.included` | NSNumber @42 | nil result; v4 NSError; no exception |
| 118 | Builder | `globalSafari.included` | NSDictionary | nil result; v4 NSError; no exception |
| 119 | Builder | `globalSafari.included` | NSArray | nil result; v4 NSError; no exception |
| 120 | Builder | `globalSafari.included` | NSNull | nil result; v4 NSError; no exception |
| 121 | Builder | `globalSafari.included` | NSDate | nil result; v4 NSError; no exception |
| 122 | Builder | `globalSafari.included` | NSData | nil result; v4 NSError; no exception |
| 123 | Builder | `globalSafari.included` | integer @0 | nil result; v4 NSError; no exception |
| 124 | Builder | `globalSafari.included` | integer @1 | nil result; v4 NSError; no exception |
| 125 | Builder | `globalSafari.included` | string true | nil result; v4 NSError; no exception |
| 126 | Builder | `globalSafari.included` | string false | nil result; v4 NSError; no exception |
| 127 | Builder | `systemGlobalLibrary.included` | NSNumber @42 | nil result; v4 NSError; no exception |
| 128 | Builder | `systemGlobalLibrary.included` | NSDictionary | nil result; v4 NSError; no exception |
| 129 | Builder | `systemGlobalLibrary.included` | NSArray | nil result; v4 NSError; no exception |
| 130 | Builder | `systemGlobalLibrary.included` | NSNull | nil result; v4 NSError; no exception |
| 131 | Builder | `systemGlobalLibrary.included` | NSDate | nil result; v4 NSError; no exception |
| 132 | Builder | `systemGlobalLibrary.included` | NSData | nil result; v4 NSError; no exception |
| 133 | Builder | `systemGlobalLibrary.included` | integer @0 | nil result; v4 NSError; no exception |
| 134 | Builder | `systemGlobalLibrary.included` | integer @1 | nil result; v4 NSError; no exception |
| 135 | Builder | `systemGlobalLibrary.included` | string true | nil result; v4 NSError; no exception |
| 136 | Builder | `systemGlobalLibrary.included` | string false | nil result; v4 NSError; no exception |
| 137 | Builder | `sharedSystemDB.included` | NSNumber @42 | nil result; v4 NSError; no exception |
| 138 | Builder | `sharedSystemDB.included` | NSDictionary | nil result; v4 NSError; no exception |
| 139 | Builder | `sharedSystemDB.included` | NSArray | nil result; v4 NSError; no exception |
| 140 | Builder | `sharedSystemDB.included` | NSNull | nil result; v4 NSError; no exception |
| 141 | Builder | `sharedSystemDB.included` | NSDate | nil result; v4 NSError; no exception |
| 142 | Builder | `sharedSystemDB.included` | NSData | nil result; v4 NSError; no exception |
| 143 | Builder | `sharedSystemDB.included` | integer @0 | nil result; v4 NSError; no exception |
| 144 | Builder | `sharedSystemDB.included` | integer @1 | nil result; v4 NSError; no exception |
| 145 | Builder | `sharedSystemDB.included` | string true | nil result; v4 NSError; no exception |
| 146 | Builder | `sharedSystemDB.included` | string false | nil result; v4 NSError; no exception |
| 147 | Builder | `restoreCompatibility.requiresSameBundleID` | NSNumber @42 | nil result; v4 NSError; no exception |
| 148 | Builder | `restoreCompatibility.requiresSameBundleID` | NSDictionary | nil result; v4 NSError; no exception |
| 149 | Builder | `restoreCompatibility.requiresSameBundleID` | NSArray | nil result; v4 NSError; no exception |
| 150 | Builder | `restoreCompatibility.requiresSameBundleID` | NSNull | nil result; v4 NSError; no exception |
| 151 | Builder | `restoreCompatibility.requiresSameBundleID` | NSDate | nil result; v4 NSError; no exception |
| 152 | Builder | `restoreCompatibility.requiresSameBundleID` | NSData | nil result; v4 NSError; no exception |
| 153 | Builder | `restoreCompatibility.requiresSameBundleID` | integer @0 | nil result; v4 NSError; no exception |
| 154 | Builder | `restoreCompatibility.requiresSameBundleID` | integer @1 | nil result; v4 NSError; no exception |
| 155 | Builder | `restoreCompatibility.requiresSameBundleID` | string true | nil result; v4 NSError; no exception |
| 156 | Builder | `restoreCompatibility.requiresSameBundleID` | string false | nil result; v4 NSError; no exception |
| 157 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | NSNumber @42 | nil result; v4 NSError; no exception |
| 158 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | NSDictionary | nil result; v4 NSError; no exception |
| 159 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | NSArray | nil result; v4 NSError; no exception |
| 160 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | NSNull | nil result; v4 NSError; no exception |
| 161 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | NSDate | nil result; v4 NSError; no exception |
| 162 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | NSData | nil result; v4 NSError; no exception |
| 163 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | integer @0 | nil result; v4 NSError; no exception |
| 164 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | integer @1 | nil result; v4 NSError; no exception |
| 165 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | string true | nil result; v4 NSError; no exception |
| 166 | Builder | `restoreCompatibility.requiresInstalledAppContainer` | string false | nil result; v4 NSError; no exception |
| 167 | Validator | `schema.identifier` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 168 | Validator | `schema.identifier` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 169 | Validator | `schema.identifier` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 170 | Validator | `schema.identifier` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 171 | Validator | `schema.identifier` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 172 | Validator | `schema.identifier` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 173 | Validator | `schema.identifier` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 174 | Validator | `schema.identifier` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 175 | Validator | `schema.digestAlgorithm` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 176 | Validator | `schema.digestAlgorithm` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 177 | Validator | `schema.digestAlgorithm` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 178 | Validator | `schema.digestAlgorithm` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 179 | Validator | `schema.digestAlgorithm` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 180 | Validator | `schema.digestAlgorithm` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 181 | Validator | `schema.digestAlgorithm` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 182 | Validator | `schema.digestAlgorithm` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 183 | Validator | `publication.protocol` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 184 | Validator | `publication.protocol` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 185 | Validator | `publication.protocol` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 186 | Validator | `publication.protocol` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 187 | Validator | `publication.protocol` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 188 | Validator | `publication.protocol` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 189 | Validator | `publication.protocol` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 190 | Validator | `publication.protocol` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 191 | Validator | `publication.contentState` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 192 | Validator | `publication.contentState` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 193 | Validator | `publication.contentState` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 194 | Validator | `publication.contentState` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 195 | Validator | `publication.contentState` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 196 | Validator | `publication.contentState` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 197 | Validator | `publication.contentState` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 198 | Validator | `publication.contentState` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 199 | Validator | `backupMode` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 200 | Validator | `backupMode` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 201 | Validator | `backupMode` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 202 | Validator | `backupMode` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 203 | Validator | `backupMode` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 204 | Validator | `backupMode` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 205 | Validator | `backupMode` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 206 | Validator | `backupMode` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 207 | Validator | `restoreCompatibility.targetBundleID` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 208 | Validator | `restoreCompatibility.targetBundleID` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 209 | Validator | `restoreCompatibility.targetBundleID` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 210 | Validator | `restoreCompatibility.targetBundleID` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 211 | Validator | `restoreCompatibility.targetBundleID` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 212 | Validator | `restoreCompatibility.targetBundleID` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 213 | Validator | `restoreCompatibility.targetBundleID` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 214 | Validator | `restoreCompatibility.targetBundleID` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 215 | Validator | `artifacts[0].name` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 216 | Validator | `artifacts[0].name` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 217 | Validator | `artifacts[0].name` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 218 | Validator | `artifacts[0].name` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 219 | Validator | `artifacts[0].name` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 220 | Validator | `artifacts[0].name` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 221 | Validator | `artifacts[0].name` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 222 | Validator | `artifacts[0].name` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 223 | Validator | `artifacts[0].path` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 224 | Validator | `artifacts[0].path` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 225 | Validator | `artifacts[0].path` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 226 | Validator | `artifacts[0].path` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 227 | Validator | `artifacts[0].path` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 228 | Validator | `artifacts[0].path` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 229 | Validator | `artifacts[0].path` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 230 | Validator | `artifacts[0].path` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 231 | Validator | `artifacts[0].sha256` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 232 | Validator | `artifacts[0].sha256` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 233 | Validator | `artifacts[0].sha256` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 234 | Validator | `artifacts[0].sha256` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 235 | Validator | `artifacts[0].sha256` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 236 | Validator | `artifacts[0].sha256` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 237 | Validator | `artifacts[0].sha256` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 238 | Validator | `artifacts[0].sha256` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 239 | Validator | `archiveChecksum` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 240 | Validator | `archiveChecksum` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 241 | Validator | `archiveChecksum` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 242 | Validator | `archiveChecksum` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 243 | Validator | `archiveChecksum` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 244 | Validator | `archiveChecksum` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 245 | Validator | `archiveChecksum` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 246 | Validator | `archiveChecksum` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 247 | Validator | `preferences.archive` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 248 | Validator | `preferences.archive` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 249 | Validator | `preferences.archive` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 250 | Validator | `preferences.archive` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 251 | Validator | `preferences.archive` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 252 | Validator | `preferences.archive` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 253 | Validator | `preferences.archive` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 254 | Validator | `preferences.archive` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 255 | Validator | `keychain.archive` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 256 | Validator | `keychain.archive` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 257 | Validator | `keychain.archive` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 258 | Validator | `keychain.archive` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 259 | Validator | `keychain.archive` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 260 | Validator | `keychain.archive` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 261 | Validator | `keychain.archive` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 262 | Validator | `keychain.archive` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 263 | Validator | `keychain.method` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 264 | Validator | `keychain.method` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 265 | Validator | `keychain.method` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 266 | Validator | `keychain.method` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 267 | Validator | `keychain.method` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 268 | Validator | `keychain.method` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 269 | Validator | `keychain.method` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 270 | Validator | `keychain.method` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 271 | Validator | `profileAppData.archive` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 272 | Validator | `profileAppData.archive` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 273 | Validator | `profileAppData.archive` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 274 | Validator | `profileAppData.archive` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 275 | Validator | `profileAppData.archive` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 276 | Validator | `profileAppData.archive` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 277 | Validator | `profileAppData.archive` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 278 | Validator | `profileAppData.archive` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 279 | Validator | `globalSafari.archive` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 280 | Validator | `globalSafari.archive` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 281 | Validator | `globalSafari.archive` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 282 | Validator | `globalSafari.archive` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 283 | Validator | `globalSafari.archive` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 284 | Validator | `globalSafari.archive` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 285 | Validator | `globalSafari.archive` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 286 | Validator | `globalSafari.archive` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 287 | Validator | `artifacts[0].policy.kind` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 288 | Validator | `artifacts[0].policy.kind` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 289 | Validator | `artifacts[0].policy.kind` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 290 | Validator | `artifacts[0].policy.kind` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 291 | Validator | `artifacts[0].policy.kind` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 292 | Validator | `artifacts[0].policy.kind` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 293 | Validator | `artifacts[0].policy.kind` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 294 | Validator | `artifacts[0].policy.kind` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 295 | Validator | `artifacts[0].policy.requirement` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 296 | Validator | `artifacts[0].policy.requirement` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 297 | Validator | `artifacts[0].policy.requirement` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 298 | Validator | `artifacts[0].policy.requirement` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 299 | Validator | `artifacts[0].policy.requirement` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 300 | Validator | `artifacts[0].policy.requirement` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 301 | Validator | `artifacts[0].policy.requirement` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 302 | Validator | `artifacts[0].policy.requirement` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 303 | Validator | `artifacts[0].policy.failureDisposition` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 304 | Validator | `artifacts[0].policy.failureDisposition` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 305 | Validator | `artifacts[0].policy.failureDisposition` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 306 | Validator | `artifacts[0].policy.failureDisposition` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 307 | Validator | `artifacts[0].policy.failureDisposition` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 308 | Validator | `artifacts[0].policy.failureDisposition` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 309 | Validator | `artifacts[0].policy.failureDisposition` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 310 | Validator | `artifacts[0].policy.failureDisposition` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 311 | Validator | `artifacts[0].policy.emptyFilePolicy` | NSNumber | NO; PXBackupManifestValidator NSError; no exception |
| 312 | Validator | `artifacts[0].policy.emptyFilePolicy` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 313 | Validator | `artifacts[0].policy.emptyFilePolicy` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 314 | Validator | `artifacts[0].policy.emptyFilePolicy` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 315 | Validator | `artifacts[0].policy.emptyFilePolicy` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 316 | Validator | `artifacts[0].policy.emptyFilePolicy` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 317 | Validator | `artifacts[0].policy.emptyFilePolicy` | empty string | NO; PXBackupManifestValidator NSError; no exception |
| 318 | Validator | `artifacts[0].policy.emptyFilePolicy` | embedded \0 | NO; PXBackupManifestValidator NSError; no exception |
| 319 | Validator | `options.includeAppGroups` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 320 | Validator | `options.includeAppGroups` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 321 | Validator | `options.includeAppGroups` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 322 | Validator | `options.includeAppGroups` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 323 | Validator | `options.includeAppGroups` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 324 | Validator | `options.includeAppGroups` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 325 | Validator | `options.includeAppGroups` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 326 | Validator | `options.includeAppGroups` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 327 | Validator | `options.includeAppGroups` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 328 | Validator | `options.includeAppGroups` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 329 | Validator | `options.includePreferences` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 330 | Validator | `options.includePreferences` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 331 | Validator | `options.includePreferences` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 332 | Validator | `options.includePreferences` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 333 | Validator | `options.includePreferences` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 334 | Validator | `options.includePreferences` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 335 | Validator | `options.includePreferences` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 336 | Validator | `options.includePreferences` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 337 | Validator | `options.includePreferences` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 338 | Validator | `options.includePreferences` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 339 | Validator | `options.includeKeychain` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 340 | Validator | `options.includeKeychain` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 341 | Validator | `options.includeKeychain` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 342 | Validator | `options.includeKeychain` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 343 | Validator | `options.includeKeychain` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 344 | Validator | `options.includeKeychain` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 345 | Validator | `options.includeKeychain` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 346 | Validator | `options.includeKeychain` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 347 | Validator | `options.includeKeychain` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 348 | Validator | `options.includeKeychain` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 349 | Validator | `preferences.included` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 350 | Validator | `preferences.included` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 351 | Validator | `preferences.included` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 352 | Validator | `preferences.included` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 353 | Validator | `preferences.included` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 354 | Validator | `preferences.included` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 355 | Validator | `preferences.included` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 356 | Validator | `preferences.included` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 357 | Validator | `preferences.included` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 358 | Validator | `preferences.included` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 359 | Validator | `keychain.included` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 360 | Validator | `keychain.included` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 361 | Validator | `keychain.included` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 362 | Validator | `keychain.included` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 363 | Validator | `keychain.included` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 364 | Validator | `keychain.included` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 365 | Validator | `keychain.included` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 366 | Validator | `keychain.included` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 367 | Validator | `keychain.included` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 368 | Validator | `keychain.included` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 369 | Validator | `profileAppData.included` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 370 | Validator | `profileAppData.included` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 371 | Validator | `profileAppData.included` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 372 | Validator | `profileAppData.included` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 373 | Validator | `profileAppData.included` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 374 | Validator | `profileAppData.included` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 375 | Validator | `profileAppData.included` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 376 | Validator | `profileAppData.included` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 377 | Validator | `profileAppData.included` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 378 | Validator | `profileAppData.included` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 379 | Validator | `globalSafari.included` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 380 | Validator | `globalSafari.included` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 381 | Validator | `globalSafari.included` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 382 | Validator | `globalSafari.included` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 383 | Validator | `globalSafari.included` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 384 | Validator | `globalSafari.included` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 385 | Validator | `globalSafari.included` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 386 | Validator | `globalSafari.included` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 387 | Validator | `globalSafari.included` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 388 | Validator | `globalSafari.included` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 389 | Validator | `systemGlobalLibrary.included` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 390 | Validator | `systemGlobalLibrary.included` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 391 | Validator | `systemGlobalLibrary.included` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 392 | Validator | `systemGlobalLibrary.included` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 393 | Validator | `systemGlobalLibrary.included` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 394 | Validator | `systemGlobalLibrary.included` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 395 | Validator | `systemGlobalLibrary.included` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 396 | Validator | `systemGlobalLibrary.included` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 397 | Validator | `systemGlobalLibrary.included` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 398 | Validator | `systemGlobalLibrary.included` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 399 | Validator | `sharedSystemDB.included` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 400 | Validator | `sharedSystemDB.included` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 401 | Validator | `sharedSystemDB.included` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 402 | Validator | `sharedSystemDB.included` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 403 | Validator | `sharedSystemDB.included` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 404 | Validator | `sharedSystemDB.included` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 405 | Validator | `sharedSystemDB.included` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 406 | Validator | `sharedSystemDB.included` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 407 | Validator | `sharedSystemDB.included` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 408 | Validator | `sharedSystemDB.included` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 409 | Validator | `restoreCompatibility.requiresSameBundleID` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 410 | Validator | `restoreCompatibility.requiresSameBundleID` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 411 | Validator | `restoreCompatibility.requiresSameBundleID` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 412 | Validator | `restoreCompatibility.requiresSameBundleID` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 413 | Validator | `restoreCompatibility.requiresSameBundleID` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 414 | Validator | `restoreCompatibility.requiresSameBundleID` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 415 | Validator | `restoreCompatibility.requiresSameBundleID` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 416 | Validator | `restoreCompatibility.requiresSameBundleID` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 417 | Validator | `restoreCompatibility.requiresSameBundleID` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 418 | Validator | `restoreCompatibility.requiresSameBundleID` | string false | NO; PXBackupManifestValidator NSError; no exception |
| 419 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | NSNumber @42 | NO; PXBackupManifestValidator NSError; no exception |
| 420 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | NSDictionary | NO; PXBackupManifestValidator NSError; no exception |
| 421 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | NSArray | NO; PXBackupManifestValidator NSError; no exception |
| 422 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | NSNull | NO; PXBackupManifestValidator NSError; no exception |
| 423 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | NSDate | NO; PXBackupManifestValidator NSError; no exception |
| 424 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | NSData | NO; PXBackupManifestValidator NSError; no exception |
| 425 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | integer @0 | NO; PXBackupManifestValidator NSError; no exception |
| 426 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | integer @1 | NO; PXBackupManifestValidator NSError; no exception |
| 427 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | string true | NO; PXBackupManifestValidator NSError; no exception |
| 428 | Validator | `restoreCompatibility.requiresInstalledAppContainer` | string false | NO; PXBackupManifestValidator NSError; no exception |

## Full authorized production diff

```diff
warning: in the working copy of 'PXBackupManifestV4.m', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'PXBackupManifestValidator.m', LF will be replaced by CRLF the next time Git touches it
diff --git a/PXBackupManifestV4.m b/PXBackupManifestV4.m
index bfc9b7c..72fe22e 100644
--- a/PXBackupManifestV4.m
+++ b/PXBackupManifestV4.m
@@ -81,19 +81,38 @@ static BOOL PXV4StringWithinLimit(NSString *value) {
     return bytes && bytes.length <= PXV4MaximumStringBytes;
 }

+static BOOL PXV4ReadRequiredString(id value, NSString **outValue) {
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    NSString *stringValue = (NSString *)value;
+    if (stringValue.length == 0 ||
+        !PXV4StringHasText(stringValue) ||
+        !PXV4StringWithinLimit(stringValue)) return NO;
+    if (outValue) *outValue = stringValue;
+    return YES;
+}
+
+static BOOL PXV4ReadOptionalString(id value, NSString **outValue) {
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    NSString *stringValue = (NSString *)value;
+    if (!PXV4StringWithinLimit(stringValue)) return NO;
+    if (outValue) *outValue = stringValue;
+    return YES;
+}
+
 static BOOL PXV4RequiredString(id value) {
-    return [value isKindOfClass:[NSString class]] &&
-           [(NSString *)value length] > 0 &&
-           PXV4StringHasText(value) && PXV4StringWithinLimit(value);
+    return PXV4ReadRequiredString(value, NULL);
 }

 static BOOL PXV4OptionalString(id value) {
-    return [value isKindOfClass:[NSString class]] && PXV4StringWithinLimit(value);
+    return PXV4ReadOptionalString(value, NULL);
 }

-static BOOL PXV4ExactBoolean(id value) {
-    return [value isKindOfClass:[NSNumber class]] &&
-           CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
+static BOOL PXV4ReadExactBoolean(id value, BOOL *outValue) {
+    if (![value isKindOfClass:[NSNumber class]]) return NO;
+    if (CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
+    BOOL booleanValue = [(NSNumber *)value boolValue];
+    if (outValue) *outValue = booleanValue;
+    return YES;
 }

 static BOOL PXV4LowercaseDigest(id value) {
@@ -434,6 +453,7 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
     if (error) {
         *error = nil;
     }
+    @try {
     if (![fields isKindOfClass:[NSDictionary class]] ||
         ![verifiedArtifacts isKindOfClass:[NSArray class]]) {
         PXV4Fail(error, PXBackupManifestV4ErrorInvalidInput,
@@ -453,7 +473,9 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
     NSDictionary *snapshot = PXV4ImmutableSnapshot(fields, error);
     if (![snapshot isKindOfClass:[NSDictionary class]]) return PXV4FailureResult(error);

-    if (!PXV4RequiredString(snapshot[@"bundleID"]) ||
+    NSString *bundleIdentifier = nil;
+    NSString *backupMode = nil;
+    if (!PXV4ReadRequiredString(snapshot[@"bundleID"], &bundleIdentifier) ||
         !PXV4OptionalString(snapshot[@"appName"]) ||
         ![snapshot[@"createdAt"] isKindOfClass:[NSDate class]] ||
         !PXV4RequiredString(snapshot[@"timestamp"]) ||
@@ -461,7 +483,8 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
         !PXV4OptionalString(snapshot[@"toolVersion"]) ||
         !PXV4OptionalString(snapshot[@"toolBuild"]) ||
         !PXV4OptionalString(snapshot[@"profileId"]) ||
-        ![snapshot[@"backupMode"] isEqualToString:@"strict"] ||
+        !PXV4ReadRequiredString(snapshot[@"backupMode"], &backupMode) ||
+        ![backupMode isEqualToString:@"strict"] ||
         !PXV4OptionalString(snapshot[@"sourceDataContainerPath"]) ||
         !PXV4OptionalString(snapshot[@"sourceDataContainerUUID"]) ||
         ![snapshot[@"warnings"] isKindOfClass:[NSArray class]]) {
@@ -489,11 +512,18 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
     NSDictionary *shared = snapshot[@"sharedSystemDB"];
     NSDictionary *options = snapshot[@"options"];

+    NSString *restoreTargetBundleIdentifier = nil;
+    BOOL requiresSameBundleIdentifier = NO;
+    BOOL requiresInstalledContainer = NO;
     if (!PXV4ExactKeys(restore, @[@"targetBundleID", @"requiresSameBundleID",
                                   @"requiresInstalledAppContainer", @"notes"]) ||
-        ![restore[@"targetBundleID"] isEqualToString:snapshot[@"bundleID"]] ||
-        !PXV4ExactBoolean(restore[@"requiresSameBundleID"]) ||
-        !PXV4ExactBoolean(restore[@"requiresInstalledAppContainer"]) ||
+        !PXV4ReadRequiredString(restore[@"targetBundleID"],
+                                &restoreTargetBundleIdentifier) ||
+        ![restoreTargetBundleIdentifier isEqualToString:bundleIdentifier] ||
+        !PXV4ReadExactBoolean(restore[@"requiresSameBundleID"],
+                              &requiresSameBundleIdentifier) ||
+        !PXV4ReadExactBoolean(restore[@"requiresInstalledAppContainer"],
+                              &requiresInstalledContainer) ||
         ![restore[@"notes"] isKindOfClass:[NSArray class]] ||
         !PXV4ExactKeys(data, @[@"uuid", @"archive", @"containerPath"]) ||
         !PXV4RequiredString(data[@"uuid"]) || !PXV4SafeRelativePath(data[@"archive"]) ||
@@ -511,13 +541,20 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
                  @"$.fields", @"A manifest component is invalid");
         return PXV4FailureResult(error);
     }
-    for (id note in restore[@"notes"]) if (!PXV4RequiredString(note)) return PXV4FailureResult(error);
-    for (NSString *key in @[@"includeAppGroups", @"includePreferences", @"includeKeychain"]) {
-        if (!PXV4ExactBoolean(options[key])) {
-            PXV4Fail(error, PXBackupManifestV4ErrorInconsistentOptions,
-                     @"$.options", @"The requested options are invalid");
-            return PXV4FailureResult(error);
-        }
+    (void)requiresSameBundleIdentifier;
+    (void)requiresInstalledContainer;
+    for (id note in restore[@"notes"]) {
+        if (!PXV4RequiredString(note)) return PXV4FailureResult(error);
+    }
+    BOOL requestGroups = NO;
+    BOOL requestPreferences = NO;
+    BOOL requestKeychain = NO;
+    if (!PXV4ReadExactBoolean(options[@"includeAppGroups"], &requestGroups) ||
+        !PXV4ReadExactBoolean(options[@"includePreferences"], &requestPreferences) ||
+        !PXV4ReadExactBoolean(options[@"includeKeychain"], &requestKeychain)) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.options", @"The requested options are invalid");
+        return PXV4FailureResult(error);
     }

     NSMutableSet *applicationGroupSet = [NSMutableSet set];
@@ -645,36 +682,61 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
         }
         [successfulGroupIDs addObject:raw[@"groupID"]];
     }
-    BOOL requestGroups = [options[@"includeAppGroups"] boolValue];
-    if ((!requestGroups && appGroups.count != 0)) {
+    if (!requestGroups && appGroups.count != 0) {
         PXV4Fail(error, PXBackupManifestV4ErrorInconsistentOptions,
                  @"$.options.includeAppGroups", @"The App Group request is inconsistent");
         return PXV4FailureResult(error);
     }

-    BOOL prefsIncluded = [preferences[@"included"] boolValue];
-    if (!PXV4ExactBoolean(preferences[@"included"]) ||
-        !PXV4OptionalString(preferences[@"archive"]) ||
-        (prefsIncluded && !PXV4AddReference(references, records, preferences[@"archive"],
-                                             PXBackupArtifactKindPreferences,
-                                             @"$.preferences.archive", error)) ||
-        (!prefsIncluded && ![preferences[@"archive"] isEqualToString:@""])) return PXV4FailureResult(error);
-    if (![options[@"includePreferences"] boolValue] && prefsIncluded) {
+    BOOL preferencesIncluded = NO;
+    NSString *preferencesArchive = nil;
+    if (!PXV4ReadExactBoolean(preferences[@"included"], &preferencesIncluded) ||
+        !PXV4ReadOptionalString(preferences[@"archive"], &preferencesArchive)) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.preferences", @"The Preferences section is invalid");
+        return PXV4FailureResult(error);
+    }
+    if (preferencesIncluded) {
+        if (!PXV4AddReference(references, records, preferencesArchive,
+                              PXBackupArtifactKindPreferences,
+                              @"$.preferences.archive", error)) {
+            return PXV4FailureResult(error);
+        }
+    } else if (![preferencesArchive isEqualToString:@""]) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.preferences.archive", @"The Preferences section is invalid");
+        return PXV4FailureResult(error);
+    }
+    if (!requestPreferences && preferencesIncluded) {
         PXV4Fail(error, PXBackupManifestV4ErrorInconsistentOptions,
                  @"$.options.includePreferences", @"The Preferences request is inconsistent");
         return PXV4FailureResult(error);
     }

-    BOOL keychainIncluded = [keychain[@"included"] boolValue];
-    if (!PXV4ExactBoolean(keychain[@"included"]) ||
-        !PXV4OptionalString(keychain[@"archive"]) ||
-        !PXV4OptionalString(keychain[@"method"]) ||
-        ![keychain[@"groupsSelected"] isKindOfClass:[NSArray class]] ||
-        (keychainIncluded && (!PXV4RequiredString(keychain[@"method"]) ||
-          !PXV4AddReference(references, records, keychain[@"archive"],
-                            PXBackupArtifactKindKeychain, @"$.keychain.archive", error))) ||
-        (!keychainIncluded && (![(NSString *)keychain[@"archive"] isEqualToString:@""] ||
-                               ![(NSString *)keychain[@"method"] isEqualToString:@""]))) return PXV4FailureResult(error);
+    BOOL keychainIncluded = NO;
+    NSString *keychainArchive = nil;
+    NSString *keychainMethod = nil;
+    if (!PXV4ReadExactBoolean(keychain[@"included"], &keychainIncluded) ||
+        !PXV4ReadOptionalString(keychain[@"archive"], &keychainArchive) ||
+        !PXV4ReadOptionalString(keychain[@"method"], &keychainMethod) ||
+        ![keychain[@"groupsSelected"] isKindOfClass:[NSArray class]]) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.keychain", @"The Keychain section is invalid");
+        return PXV4FailureResult(error);
+    }
+    if (keychainIncluded) {
+        if (!PXV4ReadRequiredString(keychainMethod, NULL) ||
+            !PXV4AddReference(references, records, keychainArchive,
+                              PXBackupArtifactKindKeychain,
+                              @"$.keychain.archive", error)) {
+            return PXV4FailureResult(error);
+        }
+    } else if (![keychainArchive isEqualToString:@""] ||
+               ![keychainMethod isEqualToString:@""]) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.keychain", @"The Keychain section is invalid");
+        return PXV4FailureResult(error);
+    }
     NSMutableSet<NSString *> *selectedGroupSet = [NSMutableSet set];
     for (id group in keychain[@"groupsSelected"]) {
         if (!PXV4RequiredString(group) || [selectedGroupSet containsObject:group]) {
@@ -685,50 +747,97 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
         }
         [selectedGroupSet addObject:group];
     }
-    if (![options[@"includeKeychain"] boolValue] && keychainIncluded) {
+    if (!requestKeychain && keychainIncluded) {
         PXV4Fail(error, PXBackupManifestV4ErrorInconsistentOptions,
                  @"$.options.includeKeychain", @"The Keychain request is inconsistent");
         return PXV4FailureResult(error);
     }

-    NSArray *singleSections = @[profile, safari];
-    NSArray *singleKinds = @[@(PXBackupArtifactKindProfileAppData), @(PXBackupArtifactKindGlobalSafari)];
-    NSArray *singlePaths = @[@"$.profileAppData.archive", @"$.globalSafari.archive"];
-    for (NSUInteger index = 0; index < singleSections.count; index++) {
-        NSDictionary *section = singleSections[index];
-        BOOL included = [section[@"included"] boolValue];
-        if (!PXV4ExactBoolean(section[@"included"]) ||
-            !PXV4OptionalString(section[@"archive"]) || !PXV4OptionalString(section[@"path"]) ||
-            (included && (!PXV4RequiredString(section[@"path"]) ||
-             !PXV4AddReference(references, records, section[@"archive"],
-                               (PXBackupArtifactKind)[singleKinds[index] unsignedIntegerValue],
-                               singlePaths[index], error))) ||
-            (!included && ![section[@"archive"] isEqualToString:@""])) return PXV4FailureResult(error);
+    BOOL profileIncluded = NO;
+    NSString *profileArchive = nil;
+    NSString *profileRecordedPath = nil;
+    if (!PXV4ReadExactBoolean(profile[@"included"], &profileIncluded) ||
+        !PXV4ReadOptionalString(profile[@"archive"], &profileArchive) ||
+        !PXV4ReadOptionalString(profile[@"path"], &profileRecordedPath)) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.profileAppData", @"The profile AppData section is invalid");
+        return PXV4FailureResult(error);
+    }
+    if (profileIncluded) {
+        if (!PXV4ReadRequiredString(profileRecordedPath, NULL) ||
+            !PXV4AddReference(references, records, profileArchive,
+                              PXBackupArtifactKindProfileAppData,
+                              @"$.profileAppData.archive", error)) {
+            return PXV4FailureResult(error);
+        }
+    } else if (![profileArchive isEqualToString:@""]) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.profileAppData.archive", @"The profile AppData section is invalid");
+        return PXV4FailureResult(error);
+    }
+
+    BOOL safariIncluded = NO;
+    NSString *safariArchive = nil;
+    NSString *safariRecordedPath = nil;
+    if (!PXV4ReadExactBoolean(safari[@"included"], &safariIncluded) ||
+        !PXV4ReadOptionalString(safari[@"archive"], &safariArchive) ||
+        !PXV4ReadOptionalString(safari[@"path"], &safariRecordedPath)) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.globalSafari", @"The global Safari section is invalid");
+        return PXV4FailureResult(error);
+    }
+    if (safariIncluded) {
+        if (!PXV4ReadRequiredString(safariRecordedPath, NULL) ||
+            !PXV4AddReference(references, records, safariArchive,
+                              PXBackupArtifactKindGlobalSafari,
+                              @"$.globalSafari.archive", error)) {
+            return PXV4FailureResult(error);
+        }
+    } else if (![safariArchive isEqualToString:@""]) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.globalSafari.archive", @"The global Safari section is invalid");
+        return PXV4FailureResult(error);
     }

     NSArray *systemItems = system[@"items"];
-    if (!PXV4ExactBoolean(system[@"included"]) || ![systemItems isKindOfClass:[NSArray class]] ||
-        ([system[@"included"] boolValue] != (systemItems.count > 0))) return PXV4FailureResult(error);
+    BOOL systemIncluded = NO;
+    if (!PXV4ReadExactBoolean(system[@"included"], &systemIncluded) ||
+        ![systemItems isKindOfClass:[NSArray class]] ||
+        systemIncluded != (systemItems.count > 0)) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.systemGlobalLibrary", @"The system-global section is invalid");
+        return PXV4FailureResult(error);
+    }
     NSMutableSet *subdirs = [NSMutableSet set];
     for (id item in systemItems) {
         if (!PXV4ExactKeys(item, @[@"subdir", @"archive"]) ||
             !PXV4RequiredString(item[@"subdir"]) || [subdirs containsObject:item[@"subdir"]] ||
             !PXV4AddReference(references, records, item[@"archive"],
                               PXBackupArtifactKindSystemGlobal,
-                              @"$.systemGlobalLibrary.items.archive", error)) return PXV4FailureResult(error);
+                              @"$.systemGlobalLibrary.items.archive", error)) {
+            return PXV4FailureResult(error);
+        }
         [subdirs addObject:item[@"subdir"]];
     }

     NSArray *sharedFiles = shared[@"files"];
-    if (!PXV4ExactBoolean(shared[@"included"]) || ![sharedFiles isKindOfClass:[NSArray class]] ||
-        ([shared[@"included"] boolValue] != (sharedFiles.count > 0))) return PXV4FailureResult(error);
+    BOOL sharedIncluded = NO;
+    if (!PXV4ReadExactBoolean(shared[@"included"], &sharedIncluded) ||
+        ![sharedFiles isKindOfClass:[NSArray class]] ||
+        sharedIncluded != (sharedFiles.count > 0)) {
+        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.sharedSystemDB", @"The shared database section is invalid");
+        return PXV4FailureResult(error);
+    }
     NSMutableSet *libraryPaths = [NSMutableSet set];
     for (id item in sharedFiles) {
         if (!PXV4ExactKeys(item, @[@"libraryRel", @"archive"]) ||
             !PXV4RequiredString(item[@"libraryRel"]) || [libraryPaths containsObject:item[@"libraryRel"]] ||
             !PXV4AddReference(references, records, item[@"archive"],
                               PXBackupArtifactKindSharedSystemDatabase,
-                              @"$.sharedSystemDB.files.archive", error)) return PXV4FailureResult(error);
+                              @"$.sharedSystemDB.files.archive", error)) {
+            return PXV4FailureResult(error);
+        }
         [libraryPaths addObject:item[@"libraryRel"]];
     }

@@ -742,7 +851,7 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
     NSMutableArray *excludedOptions = [NSMutableArray array];
     if (appGroups.count > 0) [includedOptions addObject:@"AppGroups"];
     else [excludedOptions addObject:@"AppGroups"];
-    if (prefsIncluded) [includedOptions addObject:@"GlobalPreferences"];
+    if (preferencesIncluded) [includedOptions addObject:@"GlobalPreferences"];
     else [excludedOptions addObject:@"GlobalPreferences"];
     if (keychainIncluded) [includedOptions addObject:@"Keychain"];
     else [excludedOptions addObject:@"Keychain"];
@@ -784,6 +893,14 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
     }
     if (error) *error = nil;
     return result;
+    } @catch (NSException *exception) {
+        (void)exception;
+        PXV4Fail(error,
+                 PXBackupManifestV4ErrorInvalidFieldValue,
+                 @"$.fields",
+                 @"A manifest field or component is invalid");
+        return nil;
+    }
 }

 - (instancetype)initWithBackupIdentifier:(NSString *)backupIdentifier
diff --git a/PXBackupManifestValidator.m b/PXBackupManifestValidator.m
index 53be175..3bfd824 100644
--- a/PXBackupManifestValidator.m
+++ b/PXBackupManifestValidator.m
@@ -1061,6 +1061,31 @@ static BOOL PXManifestV4RelativePath(id value) {
     return YES;
 }

+static BOOL PXManifestV4ReadString(id value,
+                                    BOOL allowEmpty,
+                                    NSString **outValue) {
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    NSString *stringValue = (NSString *)value;
+    if (PXManifestStringContainsNUL(stringValue)) return NO;
+    NSData *bytes = [stringValue dataUsingEncoding:NSUTF8StringEncoding
+                               allowLossyConversion:NO];
+    if (!bytes || bytes.length > 1024 * 1024) return NO;
+    if (!allowEmpty &&
+        (stringValue.length == 0 || !PXManifestStringHasNonWhitespace(stringValue))) {
+        return NO;
+    }
+    if (outValue) *outValue = stringValue;
+    return YES;
+}
+
+static BOOL PXManifestV4ReadBoolean(id value, BOOL *outValue) {
+    if (![value isKindOfClass:[NSNumber class]]) return NO;
+    if (CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
+    BOOL booleanValue = [(NSNumber *)value boolValue];
+    if (outValue) *outValue = booleanValue;
+    return YES;
+}
+
 static NSInteger PXManifestV4KindOrder(NSString *kind) {
     NSArray *kinds = @[@"applicationData", @"appGroup", @"profileAppData",
                        @"globalSafari", @"systemGlobal", @"sharedSystemDatabase",
@@ -1071,17 +1096,26 @@ static NSInteger PXManifestV4KindOrder(NSString *kind) {

 static BOOL PXManifestV4PolicyMatches(NSDictionary *policy,
                                       unsigned long long size,
-                                      NSInteger *kindOrder) {
+                                      NSInteger *kindOrder,
+                                      BOOL *requiredOut) {
     if (![policy isKindOfClass:[NSDictionary class]] ||
         policy.count != 4 ||
         ![[NSSet setWithArray:policy.allKeys] isEqualToSet:
-          [NSSet setWithArray:@[@"kind", @"requirement", @"failureDisposition", @"emptyFilePolicy"]]]) return NO;
-    NSString *kind = policy[@"kind"];
+          [NSSet setWithArray:@[@"kind", @"requirement", @"failureDisposition", @"emptyFilePolicy"]]]) {
+        return NO;
+    }
+    NSString *kind = nil;
+    NSString *requirement = nil;
+    NSString *disposition = nil;
+    NSString *empty = nil;
+    if (!PXManifestV4ReadString(policy[@"kind"], NO, &kind) ||
+        !PXManifestV4ReadString(policy[@"requirement"], NO, &requirement) ||
+        !PXManifestV4ReadString(policy[@"failureDisposition"], NO, &disposition) ||
+        !PXManifestV4ReadString(policy[@"emptyFilePolicy"], NO, &empty)) {
+        return NO;
+    }
     NSInteger order = PXManifestV4KindOrder(kind);
     if (order == 0) return NO;
-    NSString *requirement = policy[@"requirement"];
-    NSString *disposition = policy[@"failureDisposition"];
-    NSString *empty = policy[@"emptyFilePolicy"];
     BOOL valid = NO;
     switch (order) {
         case 1:
@@ -1107,6 +1141,7 @@ static BOOL PXManifestV4PolicyMatches(NSDictionary *policy,
     }
     if (!valid || (size == 0 && ![empty isEqualToString:@"allow"])) return NO;
     if (kindOrder) *kindOrder = order;
+    if (requiredOut) *requiredOut = [requirement isEqualToString:@"required"];
     return YES;
 }

@@ -1116,29 +1151,47 @@ static BOOL PXManifestV4AddReference(NSMutableSet<NSString *> *references,
                                      NSInteger expectedKind,
                                      NSString *fieldPath,
                                      NSError **error) {
-    if (!PXManifestV4RelativePath(name) || !kindByName[name]) {
-        return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField,
-                              fieldPath, @"The artifact reference is missing.");
+    if (!PXManifestV4RelativePath(name)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              fieldPath,
+                              @"The artifact reference is invalid.");
     }
-    if (kindByName[name].integerValue != expectedKind) {
-        return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField,
-                              fieldPath, @"The artifact reference policy is inconsistent.");
+    NSString *typedName = (NSString *)name;
+    NSNumber *kindNumber = kindByName[typedName];
+    if (![kindNumber isKindOfClass:[NSNumber class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              fieldPath,
+                              @"The artifact reference is missing.");
     }
-    if ([references containsObject:name]) {
-        return PXManifestFail(error, PXBackupManifestValidatorErrorDuplicateEntry,
-                              fieldPath, @"The artifact reference is duplicated.");
+    if (kindNumber.integerValue != expectedKind) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              fieldPath,
+                              @"The artifact reference policy is inconsistent.");
     }
-    [references addObject:name];
+    if ([references containsObject:typedName]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorDuplicateEntry,
+                              fieldPath,
+                              @"The artifact reference is duplicated.");
+    }
+    [references addObject:typedName];
     return YES;
 }

-static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
+static BOOL PXManifestV4FailureResult(NSError **error) {
     if (error && !*error) {
         PXManifestFail(error,
                        PXBackupManifestValidatorErrorInconsistentField,
                        @"$",
-                       @"The manifest v4 structure is inconsistent.");
+                       @"The manifest v4 structure is invalid.");
     }
+    return NO;
+}
+
+static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
     NSArray *rootKeys = @[
         @"manifestVersion", @"schema", @"backupID", @"publication", @"bundleID",
         @"appName", @"createdAt", @"timestamp", @"iosVersion", @"toolVersion",
@@ -1149,27 +1202,59 @@ static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
         @"preferences", @"keychain", @"profileAppData", @"globalSafari",
         @"systemGlobalLibrary", @"sharedSystemDB", @"artifacts", @"options"
     ];
-    if (!PXManifestExactKeys(manifest, rootKeys, @"$", error)) return NO;
+    if (!PXManifestExactKeys(manifest, rootKeys, @"$", error)) {
+        return PXManifestV4FailureResult(error);
+    }
+
     NSDictionary *schema = manifest[@"schema"];
     NSDictionary *publication = manifest[@"publication"];
+    if (!PXManifestExactKeys(schema,
+                             @[@"identifier", @"revision", @"digestAlgorithm"],
+                             @"$.schema",
+                             error) ||
+        !PXManifestExactKeys(publication,
+                             @[@"protocol", @"contentState"],
+                             @"$.publication",
+                             error)) {
+        return PXManifestV4FailureResult(error);
+    }
+    NSString *schemaIdentifier = nil;
+    NSString *digestAlgorithm = nil;
+    NSString *publicationProtocol = nil;
+    NSString *contentState = nil;
+    NSString *backupMode = nil;
+    if (!PXManifestV4ReadString(schema[@"identifier"], NO, &schemaIdentifier) ||
+        !PXManifestV4ReadString(schema[@"digestAlgorithm"], NO, &digestAlgorithm) ||
+        !PXManifestV4ReadString(publication[@"protocol"], NO, &publicationProtocol) ||
+        !PXManifestV4ReadString(publication[@"contentState"], NO, &contentState) ||
+        !PXManifestV4ReadString(manifest[@"backupMode"], NO, &backupMode)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$",
+                              @"The manifest v4 schema metadata has an invalid type.");
+    }
     unsigned long long schemaRevision = 0;
-    if (!PXManifestExactKeys(schema, @[@"identifier", @"revision", @"digestAlgorithm"], @"$.schema", error) ||
-        !PXManifestValidateNonnegativeIntegral(schema[@"revision"],
+    if (!PXManifestValidateNonnegativeIntegral(schema[@"revision"],
                                                @"$.schema.revision",
                                                &schemaRevision,
-                                               error) ||
-        schemaRevision != 1 ||
-        ![schema[@"identifier"] isEqualToString:@"com.hydra.projectx.backup-manifest"] ||
-        ![schema[@"digestAlgorithm"] isEqualToString:@"sha256"] ||
-        !PXManifestExactKeys(publication, @[@"protocol", @"contentState"], @"$.publication", error) ||
-        ![publication[@"protocol"] isEqualToString:@"atomic-directory-v1"] ||
-        ![publication[@"contentState"] isEqualToString:@"complete"] ||
+                                               error)) {
+        return PXManifestV4FailureResult(error);
+    }
+    if (schemaRevision != 1 ||
+        ![schemaIdentifier isEqualToString:@"com.hydra.projectx.backup-manifest"] ||
+        ![digestAlgorithm isEqualToString:@"sha256"] ||
+        ![publicationProtocol isEqualToString:@"atomic-directory-v1"] ||
+        ![contentState isEqualToString:@"complete"] ||
         !PXManifestV4CanonicalUUID(manifest[@"backupID"]) ||
-        ![manifest[@"backupMode"] isEqualToString:@"strict"]) {
-        return PXManifestFail(error, PXBackupManifestValidatorErrorInvalidFieldValue,
-                              @"$", @"The manifest v4 schema metadata is invalid.");
+        ![backupMode isEqualToString:@"strict"]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              @"$",
+                              @"The manifest v4 schema metadata is invalid.");
     }
-    if (!PXManifestValidateRequiredString(manifest[@"bundleID"], @"$.bundleID", error) ||
+
+    NSString *bundleIdentifier = nil;
+    if (!PXManifestV4ReadString(manifest[@"bundleID"], NO, &bundleIdentifier) ||
         !PXManifestValidateOptionalString(manifest[@"appName"], @"$.appName", error) ||
         ![manifest[@"createdAt"] isKindOfClass:[NSDate class]] ||
         !PXManifestValidateRequiredString(manifest[@"timestamp"], @"$.timestamp", error) ||
@@ -1177,9 +1262,14 @@ static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
         !PXManifestValidateOptionalString(manifest[@"toolVersion"], @"$.toolVersion", error) ||
         !PXManifestValidateOptionalString(manifest[@"toolBuild"], @"$.toolBuild", error) ||
         !PXManifestValidateOptionalString(manifest[@"profileId"], @"$.profileId", error) ||
-        !PXManifestValidateOptionalString(manifest[@"sourceDataContainerPath"], @"$.sourceDataContainerPath", error) ||
-        !PXManifestValidateOptionalString(manifest[@"sourceDataContainerUUID"], @"$.sourceDataContainerUUID", error) ||
-        !PXManifestValidateStringArray(manifest[@"warnings"], @"$.warnings", NO, NULL, error)) return NO;
+        !PXManifestValidateOptionalString(manifest[@"sourceDataContainerPath"],
+                                          @"$.sourceDataContainerPath", error) ||
+        !PXManifestValidateOptionalString(manifest[@"sourceDataContainerUUID"],
+                                          @"$.sourceDataContainerUUID", error) ||
+        !PXManifestValidateStringArray(manifest[@"warnings"],
+                                       @"$.warnings", NO, NULL, error)) {
+        return PXManifestV4FailureResult(error);
+    }

     NSDictionary *restore = manifest[@"restoreCompatibility"];
     NSDictionary *data = manifest[@"data"];
@@ -1192,133 +1282,507 @@ static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
     NSDictionary *system = manifest[@"systemGlobalLibrary"];
     NSDictionary *shared = manifest[@"sharedSystemDB"];
     NSDictionary *options = manifest[@"options"];
-    if (!PXManifestExactKeys(restore, @[@"targetBundleID", @"requiresSameBundleID", @"requiresInstalledAppContainer", @"notes"], @"$.restoreCompatibility", error) ||
-        ![restore[@"targetBundleID"] isEqualToString:manifest[@"bundleID"]] ||
-        !PXManifestValidateBoolean(restore[@"requiresSameBundleID"], @"$.restoreCompatibility.requiresSameBundleID", error) ||
-        !PXManifestValidateBoolean(restore[@"requiresInstalledAppContainer"], @"$.restoreCompatibility.requiresInstalledAppContainer", error) ||
-        !PXManifestValidateStringArray(restore[@"notes"], @"$.restoreCompatibility.notes", NO, NULL, error) ||
-        !PXManifestExactKeys(data, @[@"uuid", @"archive", @"containerPath"], @"$.data", error) ||
-        !PXManifestValidateRequiredString(data[@"uuid"], @"$.data.uuid", error) ||
-        !PXManifestV4RelativePath(data[@"archive"]) ||
-        !PXManifestValidateRequiredString(data[@"containerPath"], @"$.data.containerPath", error) ||
-        !PXManifestValidateStringArray(applicationGroups, @"$.applicationGroups", YES, NULL, error) ||
+    if (!PXManifestExactKeys(restore,
+                             @[@"targetBundleID", @"requiresSameBundleID",
+                               @"requiresInstalledAppContainer", @"notes"],
+                             @"$.restoreCompatibility", error) ||
+        !PXManifestExactKeys(data, @[@"uuid", @"archive", @"containerPath"],
+                             @"$.data", error) ||
+        ![applicationGroups isKindOfClass:[NSArray class]] ||
         ![appGroups isKindOfClass:[NSArray class]] ||
-        !PXManifestExactKeys(preferences, @[@"included", @"archive"], @"$.preferences", error) ||
-        !PXManifestExactKeys(keychain, @[@"included", @"archive", @"groupsSelected", @"method"], @"$.keychain", error) ||
-        !PXManifestExactKeys(profile, @[@"included", @"archive", @"path"], @"$.profileAppData", error) ||
-        !PXManifestExactKeys(safari, @[@"included", @"archive", @"path"], @"$.globalSafari", error) ||
-        !PXManifestExactKeys(system, @[@"included", @"items"], @"$.systemGlobalLibrary", error) ||
-        !PXManifestExactKeys(shared, @[@"included", @"files"], @"$.sharedSystemDB", error) ||
-        !PXManifestExactKeys(options, @[@"includeAppGroups", @"includePreferences", @"includeKeychain"], @"$.options", error)) return NO;
-    for (NSString *key in @[@"includeAppGroups", @"includePreferences", @"includeKeychain"]) {
-        if (!PXManifestValidateBoolean(options[key], PXManifestFieldPath(@"$.options", key), error)) return NO;
+        !PXManifestExactKeys(preferences, @[@"included", @"archive"],
+                             @"$.preferences", error) ||
+        !PXManifestExactKeys(keychain,
+                             @[@"included", @"archive", @"groupsSelected", @"method"],
+                             @"$.keychain", error) ||
+        !PXManifestExactKeys(profile, @[@"included", @"archive", @"path"],
+                             @"$.profileAppData", error) ||
+        !PXManifestExactKeys(safari, @[@"included", @"archive", @"path"],
+                             @"$.globalSafari", error) ||
+        !PXManifestExactKeys(system, @[@"included", @"items"],
+                             @"$.systemGlobalLibrary", error) ||
+        !PXManifestExactKeys(shared, @[@"included", @"files"],
+                             @"$.sharedSystemDB", error) ||
+        !PXManifestExactKeys(options,
+                             @[@"includeAppGroups", @"includePreferences", @"includeKeychain"],
+                             @"$.options", error)) {
+        return PXManifestV4FailureResult(error);
+    }
+
+    NSString *restoreTargetBundleIdentifier = nil;
+    BOOL requiresSameBundleIdentifier = NO;
+    BOOL requiresInstalledContainer = NO;
+    if (!PXManifestV4ReadString(restore[@"targetBundleID"],
+                                NO,
+                                &restoreTargetBundleIdentifier) ||
+        ![restoreTargetBundleIdentifier isEqualToString:bundleIdentifier] ||
+        !PXManifestV4ReadBoolean(restore[@"requiresSameBundleID"],
+                                 &requiresSameBundleIdentifier) ||
+        !PXManifestV4ReadBoolean(restore[@"requiresInstalledAppContainer"],
+                                 &requiresInstalledContainer) ||
+        !PXManifestValidateStringArray(restore[@"notes"],
+                                       @"$.restoreCompatibility.notes",
+                                       NO,
+                                       NULL,
+                                       error)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.restoreCompatibility",
+                              @"The Restore compatibility section is invalid.");
+    }
+    (void)requiresSameBundleIdentifier;
+    (void)requiresInstalledContainer;
+    if (!PXManifestValidateRequiredString(data[@"uuid"], @"$.data.uuid", error) ||
+        !PXManifestV4RelativePath(data[@"archive"]) ||
+        !PXManifestValidateRequiredString(data[@"containerPath"],
+                                          @"$.data.containerPath", error) ||
+        !PXManifestValidateStringArray(applicationGroups,
+                                       @"$.applicationGroups", YES, NULL, error)) {
+        return PXManifestV4FailureResult(error);
+    }
+
+    BOOL requestGroups = NO;
+    BOOL requestPreferences = NO;
+    BOOL requestKeychain = NO;
+    if (!PXManifestV4ReadBoolean(options[@"includeAppGroups"], &requestGroups) ||
+        !PXManifestV4ReadBoolean(options[@"includePreferences"], &requestPreferences) ||
+        !PXManifestV4ReadBoolean(options[@"includeKeychain"], &requestKeychain)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.options",
+                              @"The requested option values must be exact Booleans.");
     }

     NSArray *artifacts = manifest[@"artifacts"];
-    if (![artifacts isKindOfClass:[NSArray class]] || artifacts.count < 1 || artifacts.count > 4096) {
-        return PXManifestFail(error, PXBackupManifestValidatorErrorInvalidFieldValue,
-                              @"$.artifacts", @"The artifacts section is invalid.");
+    if (![artifacts isKindOfClass:[NSArray class]] ||
+        artifacts.count < 1 || artifacts.count > 4096) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              @"$.artifacts",
+                              @"The artifacts section is invalid.");
     }
-    NSMutableDictionary<NSString *, NSNumber *> *kindByName = [NSMutableDictionary dictionary];
-    NSMutableSet *paths = [NSMutableSet set];
+    NSMutableDictionary<NSString *, NSNumber *> *kindByName =
+        [NSMutableDictionary dictionary];
+    NSMutableSet<NSString *> *paths = [NSMutableSet set];
     unsigned long long actualTotal = 0;
     NSInteger previousKind = 0;
-    NSUInteger requiredCount = 0, dataCount = 0, profileCount = 0, safariCount = 0, prefsCount = 0, keychainCount = 0;
+    NSUInteger requiredCount = 0;
+    NSUInteger dataCount = 0;
+    NSUInteger profileCount = 0;
+    NSUInteger safariCount = 0;
+    NSUInteger preferencesCount = 0;
+    NSUInteger keychainCount = 0;
     NSString *dataChecksum = nil;
     for (NSUInteger index = 0; index < artifacts.count; index++) {
-        NSDictionary *artifact = artifacts[index];
+        id rawArtifact = artifacts[index];
         NSString *entryPath = PXManifestIndexedPath(@"$.artifacts", index);
-        if (!PXManifestExactKeys(artifact, @[@"name", @"path", @"size", @"sha256", @"policy"], entryPath, error) ||
-            !PXManifestV4RelativePath(artifact[@"name"]) ||
-            ![artifact[@"path"] isEqualToString:artifact[@"name"]] ||
-            !PXManifestV4Digest(artifact[@"sha256"]) || kindByName[artifact[@"name"]] ||
-            [paths containsObject:artifact[@"path"]]) return NO;
+        if (!PXManifestExactKeys(rawArtifact,
+                                 @[@"name", @"path", @"size", @"sha256", @"policy"],
+                                 entryPath,
+                                 error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        NSDictionary *artifact = rawArtifact;
+        NSString *name = nil;
+        NSString *recordedPath = nil;
+        NSString *digest = nil;
+        if (!PXManifestV4ReadString(artifact[@"name"], NO, &name) ||
+            !PXManifestV4ReadString(artifact[@"path"], NO, &recordedPath) ||
+            !PXManifestV4ReadString(artifact[@"sha256"], NO, &digest)) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  entryPath,
+                                  @"An artifact string field has an invalid type.");
+        }
+        if (!PXManifestV4RelativePath(name) ||
+            !PXManifestV4RelativePath(recordedPath) ||
+            ![recordedPath isEqualToString:name] ||
+            !PXManifestV4Digest(digest) ||
+            kindByName[name] || [paths containsObject:recordedPath]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldValue,
+                                  entryPath,
+                                  @"An artifact declaration is invalid.");
+        }
         unsigned long long size = 0;
-        if (!PXManifestValidateNonnegativeIntegral(artifact[@"size"], PXManifestFieldPath(entryPath, @"size"), &size, error)) return NO;
+        if (!PXManifestValidateNonnegativeIntegral(artifact[@"size"],
+                                                   PXManifestFieldPath(entryPath, @"size"),
+                                                   &size,
+                                                   error)) {
+            return PXManifestV4FailureResult(error);
+        }
         NSInteger kind = 0;
-        if (!PXManifestV4PolicyMatches(artifact[@"policy"], size, &kind) || kind < previousKind) {
-            return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField,
-                                  PXManifestFieldPath(entryPath, @"policy"), @"The artifact policy or order is invalid.");
+        BOOL required = NO;
+        if (!PXManifestV4PolicyMatches(artifact[@"policy"],
+                                       size,
+                                       &kind,
+                                       &required) ||
+            kind < previousKind) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInconsistentField,
+                                  PXManifestFieldPath(entryPath, @"policy"),
+                                  @"The artifact policy or order is invalid.");
         }
         previousKind = kind;
-        if (actualTotal > ULLONG_MAX - size) return PXManifestFail(error, PXBackupManifestValidatorErrorInvalidFieldValue, @"$.totalSize", @"The total artifact size overflowed.");
+        if (actualTotal > ULLONG_MAX - size) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldValue,
+                                  @"$.totalSize",
+                                  @"The total artifact size overflowed.");
+        }
         actualTotal += size;
-        NSString *requirement = artifact[@"policy"][@"requirement"];
-        if ([requirement isEqualToString:@"required"]) requiredCount += 1;
-        if (kind == 1) { dataCount += 1; dataChecksum = artifact[@"sha256"]; if (index != 0) return NO; }
-        if (kind == 3) profileCount += 1; if (kind == 4) safariCount += 1;
-        if (kind == 7) prefsCount += 1; if (kind == 8) keychainCount += 1;
-        kindByName[artifact[@"name"]] = @(kind); [paths addObject:artifact[@"path"]];
-    }
-    unsigned long long declaredCount = 0, declaredTotal = 0;
-    if (dataCount != 1 || requiredCount != 1 || profileCount > 1 || safariCount > 1 || prefsCount > 1 || keychainCount > 1 ||
-        !PXManifestValidateNonnegativeIntegral(manifest[@"artifactCount"], @"$.artifactCount", &declaredCount, error) ||
-        declaredCount != artifacts.count ||
-        !PXManifestValidateNonnegativeIntegral(manifest[@"totalSize"], @"$.totalSize", &declaredTotal, error) ||
-        declaredTotal != actualTotal || ![manifest[@"archiveChecksum"] isEqualToString:dataChecksum]) return NO;
-
-    NSMutableSet *references = [NSMutableSet set];
-    if (!PXManifestV4AddReference(references, kindByName, data[@"archive"], 1, @"$.data.archive", error)) return NO;
+        if (required) requiredCount += 1;
+        if (kind == 1) {
+            dataCount += 1;
+            dataChecksum = digest;
+            if (index != 0) {
+                return PXManifestFail(error,
+                                      PXBackupManifestValidatorErrorInconsistentField,
+                                      entryPath,
+                                      @"The required ApplicationData artifact must be first.");
+            }
+        } else if (kind == 3) {
+            profileCount += 1;
+        } else if (kind == 4) {
+            safariCount += 1;
+        } else if (kind == 7) {
+            preferencesCount += 1;
+        } else if (kind == 8) {
+            keychainCount += 1;
+        }
+        kindByName[name] = @(kind);
+        [paths addObject:recordedPath];
+    }
+
+    unsigned long long declaredCount = 0;
+    unsigned long long declaredTotal = 0;
+    NSString *archiveChecksum = nil;
+    if (dataCount != 1 || requiredCount != 1 ||
+        profileCount > 1 || safariCount > 1 ||
+        preferencesCount > 1 || keychainCount > 1) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.artifacts",
+                              @"The required artifact contract is invalid.");
+    }
+    if (!PXManifestValidateNonnegativeIntegral(manifest[@"artifactCount"],
+                                               @"$.artifactCount",
+                                               &declaredCount,
+                                               error) ||
+        !PXManifestValidateNonnegativeIntegral(manifest[@"totalSize"],
+                                               @"$.totalSize",
+                                               &declaredTotal,
+                                               error) ||
+        !PXManifestV4ReadString(manifest[@"archiveChecksum"],
+                                NO,
+                                &archiveChecksum)) {
+        return PXManifestV4FailureResult(error);
+    }
+    if (declaredCount != artifacts.count ||
+        declaredTotal != actualTotal ||
+        !PXManifestV4Digest(archiveChecksum) ||
+        ![archiveChecksum isEqualToString:dataChecksum]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.archiveChecksum",
+                              @"The artifact aggregate fields are inconsistent.");
+    }
+
+    NSMutableSet<NSString *> *references = [NSMutableSet set];
+    if (!PXManifestV4AddReference(references,
+                                  kindByName,
+                                  data[@"archive"],
+                                  1,
+                                  @"$.data.archive",
+                                  error)) {
+        return PXManifestV4FailureResult(error);
+    }
     NSSet *applicationGroupSet = [NSSet setWithArray:applicationGroups];
-    NSMutableSet *groupIDs = [NSMutableSet set];
+    NSMutableSet *groupIdentifiers = [NSMutableSet set];
     for (NSUInteger index = 0; index < appGroups.count; index++) {
-        NSDictionary *item = appGroups[index];
+        id rawItem = appGroups[index];
         NSString *itemPath = PXManifestIndexedPath(@"$.appGroups", index);
-        if (!PXManifestExactKeys(item, @[@"groupID", @"uuid", @"archive"], itemPath, error) ||
-            !PXManifestValidateRequiredString(item[@"groupID"], PXManifestFieldPath(itemPath, @"groupID"), error) ||
-            !PXManifestValidateRequiredString(item[@"uuid"], PXManifestFieldPath(itemPath, @"uuid"), error) ||
-            ![applicationGroupSet containsObject:item[@"groupID"]] || [groupIDs containsObject:item[@"groupID"]] ||
-            !PXManifestV4AddReference(references, kindByName, item[@"archive"], 2, PXManifestFieldPath(itemPath, @"archive"), error)) return NO;
-        [groupIDs addObject:item[@"groupID"]];
-    }
-    if (![options[@"includeAppGroups"] boolValue] && appGroups.count != 0) return NO;
-    BOOL prefsIncluded = [preferences[@"included"] boolValue];
-    if (!PXManifestValidateBoolean(preferences[@"included"], @"$.preferences.included", error) ||
-        !PXManifestValidateOptionalString(preferences[@"archive"], @"$.preferences.archive", error) ||
-        (prefsIncluded && !PXManifestV4AddReference(references, kindByName, preferences[@"archive"], 7, @"$.preferences.archive", error)) ||
-        (!prefsIncluded && ![preferences[@"archive"] isEqualToString:@""]) ||
-        (![options[@"includePreferences"] boolValue] && prefsIncluded)) return NO;
-    BOOL keychainIncluded = [keychain[@"included"] boolValue];
-    if (!PXManifestValidateBoolean(keychain[@"included"], @"$.keychain.included", error) ||
-        !PXManifestValidateOptionalString(keychain[@"archive"], @"$.keychain.archive", error) ||
-        !PXManifestValidateOptionalString(keychain[@"method"], @"$.keychain.method", error) ||
-        !PXManifestValidateStringArray(keychain[@"groupsSelected"], @"$.keychain.groupsSelected", YES, NULL, error) ||
-        (keychainIncluded && (!PXManifestStringHasNonWhitespace(keychain[@"method"]) ||
-         !PXManifestV4AddReference(references, kindByName, keychain[@"archive"], 8, @"$.keychain.archive", error))) ||
-        (!keychainIncluded && (![(NSString *)keychain[@"archive"] isEqualToString:@""] || ![(NSString *)keychain[@"method"] isEqualToString:@""])) ||
-        (![options[@"includeKeychain"] boolValue] && keychainIncluded)) return NO;
-    NSArray *singleSections = @[profile, safari]; NSArray *singleKinds = @[@3, @4]; NSArray *singlePaths = @[@"$.profileAppData", @"$.globalSafari"];
-    for (NSUInteger index = 0; index < 2; index++) {
-        NSDictionary *section = singleSections[index]; BOOL included = [section[@"included"] boolValue]; NSString *path = singlePaths[index];
-        if (!PXManifestValidateBoolean(section[@"included"], PXManifestFieldPath(path, @"included"), error) ||
-            !PXManifestValidateOptionalString(section[@"archive"], PXManifestFieldPath(path, @"archive"), error) ||
-            !PXManifestValidateOptionalString(section[@"path"], PXManifestFieldPath(path, @"path"), error) ||
-            (included && (!PXManifestStringHasNonWhitespace(section[@"path"]) || !PXManifestV4AddReference(references, kindByName, section[@"archive"], [singleKinds[index] integerValue], PXManifestFieldPath(path, @"archive"), error))) ||
-            (!included && ![section[@"archive"] isEqualToString:@""])) return NO;
+        if (!PXManifestExactKeys(rawItem,
+                                 @[@"groupID", @"uuid", @"archive"],
+                                 itemPath,
+                                 error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        NSDictionary *item = rawItem;
+        NSString *groupIdentifier = nil;
+        if (!PXManifestV4ReadString(item[@"groupID"], NO, &groupIdentifier) ||
+            !PXManifestValidateRequiredString(item[@"uuid"],
+                                              PXManifestFieldPath(itemPath, @"uuid"),
+                                              error) ||
+            ![applicationGroupSet containsObject:groupIdentifier] ||
+            [groupIdentifiers containsObject:groupIdentifier] ||
+            !PXManifestV4AddReference(references,
+                                      kindByName,
+                                      item[@"archive"],
+                                      2,
+                                      PXManifestFieldPath(itemPath, @"archive"),
+                                      error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        [groupIdentifiers addObject:groupIdentifier];
+    }
+    if (!requestGroups && appGroups.count != 0) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.options.includeAppGroups",
+                              @"The App Group request is inconsistent.");
+    }
+
+    BOOL preferencesIncluded = NO;
+    NSString *preferencesArchive = nil;
+    if (!PXManifestV4ReadBoolean(preferences[@"included"], &preferencesIncluded) ||
+        !PXManifestV4ReadString(preferences[@"archive"], YES, &preferencesArchive)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.preferences",
+                              @"The Preferences section has an invalid type.");
+    }
+    if (preferencesIncluded) {
+        if (!PXManifestV4AddReference(references,
+                                      kindByName,
+                                      preferencesArchive,
+                                      7,
+                                      @"$.preferences.archive",
+                                      error)) {
+            return PXManifestV4FailureResult(error);
+        }
+    } else if (![preferencesArchive isEqualToString:@""]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.preferences.archive",
+                              @"An excluded Preferences section requires an empty archive.");
+    }
+    if (!requestPreferences && preferencesIncluded) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.options.includePreferences",
+                              @"The Preferences request is inconsistent.");
+    }
+
+    BOOL keychainIncluded = NO;
+    NSString *keychainArchive = nil;
+    NSString *keychainMethod = nil;
+    if (!PXManifestV4ReadBoolean(keychain[@"included"], &keychainIncluded) ||
+        !PXManifestV4ReadString(keychain[@"archive"], YES, &keychainArchive) ||
+        !PXManifestV4ReadString(keychain[@"method"], YES, &keychainMethod) ||
+        !PXManifestValidateStringArray(keychain[@"groupsSelected"],
+                                       @"$.keychain.groupsSelected",
+                                       YES,
+                                       NULL,
+                                       error)) {
+        return PXManifestV4FailureResult(error);
+    }
+    if (keychainIncluded) {
+        NSString *requiredMethod = nil;
+        if (!PXManifestV4ReadString(keychainMethod, NO, &requiredMethod) ||
+            !PXManifestV4AddReference(references,
+                                      kindByName,
+                                      keychainArchive,
+                                      8,
+                                      @"$.keychain.archive",
+                                      error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        (void)requiredMethod;
+    } else if (![keychainArchive isEqualToString:@""] ||
+               ![keychainMethod isEqualToString:@""]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.keychain",
+                              @"An excluded Keychain section requires empty locator fields.");
+    }
+    if (!requestKeychain && keychainIncluded) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.options.includeKeychain",
+                              @"The Keychain request is inconsistent.");
+    }
+
+    BOOL profileIncluded = NO;
+    NSString *profileArchive = nil;
+    NSString *profileRecordedPath = nil;
+    if (!PXManifestV4ReadBoolean(profile[@"included"], &profileIncluded) ||
+        !PXManifestV4ReadString(profile[@"archive"], YES, &profileArchive) ||
+        !PXManifestV4ReadString(profile[@"path"], YES, &profileRecordedPath)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.profileAppData",
+                              @"The profile AppData section has an invalid type.");
+    }
+    if (profileIncluded) {
+        NSString *requiredPath = nil;
+        if (!PXManifestV4ReadString(profileRecordedPath, NO, &requiredPath) ||
+            !PXManifestV4AddReference(references,
+                                      kindByName,
+                                      profileArchive,
+                                      3,
+                                      @"$.profileAppData.archive",
+                                      error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        (void)requiredPath;
+    } else if (![profileArchive isEqualToString:@""]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.profileAppData.archive",
+                              @"An excluded profile AppData section requires an empty archive.");
+    }
+
+    BOOL safariIncluded = NO;
+    NSString *safariArchive = nil;
+    NSString *safariRecordedPath = nil;
+    if (!PXManifestV4ReadBoolean(safari[@"included"], &safariIncluded) ||
+        !PXManifestV4ReadString(safari[@"archive"], YES, &safariArchive) ||
+        !PXManifestV4ReadString(safari[@"path"], YES, &safariRecordedPath)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.globalSafari",
+                              @"The global Safari section has an invalid type.");
+    }
+    if (safariIncluded) {
+        NSString *requiredPath = nil;
+        if (!PXManifestV4ReadString(safariRecordedPath, NO, &requiredPath) ||
+            !PXManifestV4AddReference(references,
+                                      kindByName,
+                                      safariArchive,
+                                      4,
+                                      @"$.globalSafari.archive",
+                                      error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        (void)requiredPath;
+    } else if (![safariArchive isEqualToString:@""]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.globalSafari.archive",
+                              @"An excluded global Safari section requires an empty archive.");
     }
+
     NSArray *systemItems = system[@"items"];
-    if (!PXManifestValidateBoolean(system[@"included"], @"$.systemGlobalLibrary.included", error) || ![systemItems isKindOfClass:[NSArray class]] || ([system[@"included"] boolValue] != (systemItems.count > 0))) return NO;
-    NSMutableSet *subdirs = [NSMutableSet set];
+    BOOL systemIncluded = NO;
+    if (!PXManifestV4ReadBoolean(system[@"included"], &systemIncluded) ||
+        ![systemItems isKindOfClass:[NSArray class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.systemGlobalLibrary",
+                              @"The system-global section has an invalid type.");
+    }
+    if (systemIncluded != (systemItems.count > 0)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.systemGlobalLibrary.included",
+                              @"The system-global included flag is inconsistent.");
+    }
+    NSMutableSet *subdirectories = [NSMutableSet set];
     for (NSUInteger index = 0; index < systemItems.count; index++) {
-        NSDictionary *item = systemItems[index]; NSString *path = PXManifestIndexedPath(@"$.systemGlobalLibrary.items", index);
-        if (!PXManifestExactKeys(item, @[@"subdir", @"archive"], path, error) || !PXManifestValidateRequiredString(item[@"subdir"], PXManifestFieldPath(path, @"subdir"), error) || [subdirs containsObject:item[@"subdir"]] || !PXManifestV4AddReference(references, kindByName, item[@"archive"], 5, PXManifestFieldPath(path, @"archive"), error)) return NO;
-        [subdirs addObject:item[@"subdir"]];
+        id rawItem = systemItems[index];
+        NSString *itemPath = PXManifestIndexedPath(@"$.systemGlobalLibrary.items", index);
+        if (!PXManifestExactKeys(rawItem,
+                                 @[@"subdir", @"archive"],
+                                 itemPath,
+                                 error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        NSDictionary *item = rawItem;
+        NSString *subdirectory = nil;
+        if (!PXManifestV4ReadString(item[@"subdir"], NO, &subdirectory) ||
+            [subdirectories containsObject:subdirectory] ||
+            !PXManifestV4AddReference(references,
+                                      kindByName,
+                                      item[@"archive"],
+                                      5,
+                                      PXManifestFieldPath(itemPath, @"archive"),
+                                      error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        [subdirectories addObject:subdirectory];
     }
+
     NSArray *sharedFiles = shared[@"files"];
-    if (!PXManifestValidateBoolean(shared[@"included"], @"$.sharedSystemDB.included", error) || ![sharedFiles isKindOfClass:[NSArray class]] || ([shared[@"included"] boolValue] != (sharedFiles.count > 0))) return NO;
-    NSMutableSet *libraryRels = [NSMutableSet set];
+    BOOL sharedIncluded = NO;
+    if (!PXManifestV4ReadBoolean(shared[@"included"], &sharedIncluded) ||
+        ![sharedFiles isKindOfClass:[NSArray class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.sharedSystemDB",
+                              @"The shared database section has an invalid type.");
+    }
+    if (sharedIncluded != (sharedFiles.count > 0)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.sharedSystemDB.included",
+                              @"The shared database included flag is inconsistent.");
+    }
+    NSMutableSet *libraryLocations = [NSMutableSet set];
     for (NSUInteger index = 0; index < sharedFiles.count; index++) {
-        NSDictionary *item = sharedFiles[index]; NSString *path = PXManifestIndexedPath(@"$.sharedSystemDB.files", index);
-        if (!PXManifestExactKeys(item, @[@"libraryRel", @"archive"], path, error) || !PXManifestValidateRequiredString(item[@"libraryRel"], PXManifestFieldPath(path, @"libraryRel"), error) || [libraryRels containsObject:item[@"libraryRel"]] || !PXManifestV4AddReference(references, kindByName, item[@"archive"], 6, PXManifestFieldPath(path, @"archive"), error)) return NO;
-        [libraryRels addObject:item[@"libraryRel"]];
+        id rawItem = sharedFiles[index];
+        NSString *itemPath = PXManifestIndexedPath(@"$.sharedSystemDB.files", index);
+        if (!PXManifestExactKeys(rawItem,
+                                 @[@"libraryRel", @"archive"],
+                                 itemPath,
+                                 error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        NSDictionary *item = rawItem;
+        NSString *libraryLocation = nil;
+        if (!PXManifestV4ReadString(item[@"libraryRel"], NO, &libraryLocation) ||
+            [libraryLocations containsObject:libraryLocation] ||
+            !PXManifestV4AddReference(references,
+                                      kindByName,
+                                      item[@"archive"],
+                                      6,
+                                      PXManifestFieldPath(itemPath, @"archive"),
+                                      error)) {
+            return PXManifestV4FailureResult(error);
+        }
+        [libraryLocations addObject:libraryLocation];
     }
-    if (references.count != artifacts.count) return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField, @"$.artifacts", @"The artifact reference coverage is incomplete.");
-    NSMutableArray *expectedIncluded = [NSMutableArray arrayWithObject:@"DataContainer"];
+
+    if (references.count != artifacts.count) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.artifacts",
+                              @"The artifact reference coverage is incomplete.");
+    }
+    NSSet<NSString *> *includedSet = nil;
+    NSSet<NSString *> *excludedSet = nil;
+    if (!PXManifestValidateStringArray(manifest[@"includedOptions"],
+                                       @"$.includedOptions",
+                                       YES,
+                                       &includedSet,
+                                       error) ||
+        !PXManifestValidateStringArray(manifest[@"excludedOptions"],
+                                       @"$.excludedOptions",
+                                       YES,
+                                       &excludedSet,
+                                       error)) {
+        return PXManifestV4FailureResult(error);
+    }
+    (void)includedSet;
+    (void)excludedSet;
+    NSMutableArray *expectedIncluded =
+        [NSMutableArray arrayWithObject:@"DataContainer"];
     NSMutableArray *expectedExcluded = [NSMutableArray array];
-    if (appGroups.count) [expectedIncluded addObject:@"AppGroups"]; else [expectedExcluded addObject:@"AppGroups"];
-    if (prefsIncluded) [expectedIncluded addObject:@"GlobalPreferences"]; else [expectedExcluded addObject:@"GlobalPreferences"];
-    if (keychainIncluded) [expectedIncluded addObject:@"Keychain"]; else [expectedExcluded addObject:@"Keychain"];
-    if (![manifest[@"includedOptions"] isEqual:expectedIncluded] || ![manifest[@"excludedOptions"] isEqual:expectedExcluded]) return NO;
+    if (appGroups.count > 0) [expectedIncluded addObject:@"AppGroups"];
+    else [expectedExcluded addObject:@"AppGroups"];
+    if (preferencesIncluded) [expectedIncluded addObject:@"GlobalPreferences"];
+    else [expectedExcluded addObject:@"GlobalPreferences"];
+    if (keychainIncluded) [expectedIncluded addObject:@"Keychain"];
+    else [expectedExcluded addObject:@"Keychain"];
+    NSArray *includedOptions = manifest[@"includedOptions"];
+    NSArray *excludedOptions = manifest[@"excludedOptions"];
+    if (![includedOptions isEqual:expectedIncluded] ||
+        ![excludedOptions isEqual:expectedExcluded]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.includedOptions",
+                              @"The factual option arrays are inconsistent.");
+    }
     if (error) *error = nil;
     return YES;
 }
@@ -1344,21 +1808,29 @@ static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
         PXManifestPeekPositiveVersion(manifest[@"manifestVersion"],
                                       &versionMagnitude);
     if (hasPositiveVersion && versionMagnitude == 4) {
-        NSUInteger visitedV4 = 0;
-        NSUInteger dictionaryKeysV4 = 0;
-        NSUInteger arrayItemsV4 = 0;
-        NSHashTable *activeV4 =
-            [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
-        if (!PXManifestValidateGraphObjectV4(object,
-                                             1,
-                                             &visitedV4,
-                                             &dictionaryKeysV4,
-                                             &arrayItemsV4,
-                                             activeV4,
-                                             error)) {
-            return NO;
+        @try {
+            NSUInteger visitedV4 = 0;
+            NSUInteger dictionaryKeysV4 = 0;
+            NSUInteger arrayItemsV4 = 0;
+            NSHashTable *activeV4 =
+                [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
+            if (!PXManifestValidateGraphObjectV4(object,
+                                                 1,
+                                                 &visitedV4,
+                                                 &dictionaryKeysV4,
+                                                 &arrayItemsV4,
+                                                 activeV4,
+                                                 error)) {
+                return PXManifestV4FailureResult(error);
+            }
+            return PXManifestValidateV4(manifest, error);
+        } @catch (NSException *exception) {
+            (void)exception;
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  @"$",
+                                  @"The manifest v4 contains an invalid value type.");
         }
-        return PXManifestValidateV4(manifest, error);
     }
     NSUInteger visited = 0;
     NSHashTable *activeContainers =
```

## Whitespace, CRLF and NUL audit

- `PXBackupManifestV4.m`: SHA-256 `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7`, 44234 bytes, NUL 0, CRLF 0, final LF True.
- `PXBackupManifestValidator.m`: SHA-256 `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820`, 91751 bytes, NUL 0, CRLF 0, final LF True.
- Report is generated as UTF-8 LF-only, with no embedded NUL and an exact final two-line status block.
- `git diff --check` must be rerun after staging because full-diff code blocks may preserve baseline context whitespace.

## Build status and remaining risks

- Strict Objective-C builder frontend: PASS.
- Strict Objective-C validator frontend: PASS.
- Temporary Objective-C exception harness frontend: PASS.
- Native harness link/execution: unavailable in this Windows workspace due to missing Objective-C runtime/Foundation and Apple toolchain.
- Full Theos/iOS build and runtime malformed-manifest replay: pending GitHub Actions/device artifact.
- TASK-3.7 atomic manifest writing, TASK-3.8 publication, TASK-3.9 cleanup, TASK-3.10 stale cleanup, and later phases were not started.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
