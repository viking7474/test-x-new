# TASK-2.4 REPORT — Remove Recorded Destination Fallbacks

## 1. Baseline and initial status

- Required and observed baseline: `1c5eda02e91c5705e7798ef2414475f3aebfcef2`
- TASK-2.3 source review: **ACCEPTED**.
- Production change scope: `AppDataBackupManager.m` only.
- Required report: `docs/backup-restore-hardening/reports/TASK-2.4-REPORT.md`.

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
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
```

Initial log:

```text
1c5eda0 phase2(task-2.3): enforce exact restore bundle identity
9727a0a phase2(task-2.2): enforce supported manifest versions
e15f101 phase2(task-2.1): add manifest schema validator
```

Coordinator-owned modifications and untracked specifications/reviews were neither rewritten nor staged.

## 2. Exact production scope

| File | Change |
|---|---|
| `AppDataBackupManager.m` | Add typed resolver/validator imports, exact destination helper, early canonical target preflight, remove legacy/recorded destination authority, add pre-mutation revalidation. |
| `docs/backup-restore-hardening/reports/TASK-2.4-REPORT.md` | This evidence report. |

- Baseline manager Git-blob SHA-256: `c2907f600780f9d2b9c27de11d5c122ed7ef74d60cb86025b57ae6798890d742`
- Working manager raw-file SHA-256: `0f1f98e8c959a3b8e4dd7890f68eab24c247d2678c52d860bb1870c239979adb`

## 3. Protected SHA-256 before/after

| Protected file | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | unchanged |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | unchanged |
| `PXBackupManifestValidator.m` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | unchanged |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | unchanged |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | unchanged |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | unchanged |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | unchanged |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | unchanged |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | unchanged |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | unchanged |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | unchanged |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | unchanged |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | unchanged |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | unchanged |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | unchanged |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | unchanged |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | unchanged |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | unchanged |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | unchanged |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | unchanged |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | unchanged |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | unchanged |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | unchanged |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | unchanged |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | unchanged |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | unchanged |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | unchanged |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | unchanged |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | unchanged |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | unchanged |

Protected working-tree diff exit code: `0`.

## 4. TASK-2.1 through TASK-2.3 non-regression

- `PXBackupManifestVersionIsSupported` body is byte-identical; exact set remains `{2,3}`.
- `readManifestAtBackupDirectory:error:` body is byte-identical.
- Validator propagation, read code `200`, unsupported code `201`, and original dictionary return remain unchanged.
- Exact case-sensitive bundle comparison remains exactly once and precedes destination resolution.
- Bundle mismatch remains manager code `304` with the same generic description.
- Backup writer remains `@"manifestVersion": @3`.

Body hashes:

```text
PXBackupManifestVersionIsSupported
344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7

readManifestAtBackupDirectory:error:
f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff
```

Precedence remains: `300` → `200`/validator → `201` → `304` → destination `303` → later Restore errors.

## 5. Exact destination helper and root policy

`PXResolveExactRestoreApplicationDataTarget` is file-local and clears model, path, and error outputs at entry. It processes rootful then rootless with one explicit resolver call per root. A nil model without error means absent. Any resolver error or validator error fails the entire operation.

Every returned model is passed immediately to `validatedCanonicalPathForContainer:error:`. The helper retains only validator-returned canonical strings. Rootful is retained first; a rootless model with the same canonical path is treated as the same physical target. A different canonical path fails closed as ambiguous. Zero validated models also fails.

| Source contract | Count/result |
|---|---:|
| Helper definitions | 1 |
| Rootful resolver call sites | 1 |
| Rootless resolver call sites | 1 |
| Initial validator call sites | 2, one conditional call per possible resolved model |
| Restore helper calls | 1 |
| Raw helper path return | 0 |
| LaunchServices or manifest authority inside helper | 0 |

## 6. Destination error and privacy contract

All helper/pre-mutation destination failures use:

```text
domain: PXBackupErrorDomain
code: 303
description: Exact application data container could not be resolved safely
```

The manager error contains only `NSLocalizedDescriptionKey`. It does not include bundle ID, LaunchServices path, manifest path/UUID, raw/canonical candidate, container UUID, metadata, filesystem excerpt, or nested resolver/validator NSError.

## 7. Recorded and legacy destination authority removed

Within Restore destination selection:

```text
manifest data.containerPath reads: 0
manifest data.uuid reads: 0
sourceDataContainerPath reads: 0
sourceDataContainerUUID reads: 0
manifestDataUUID token: 0
direct PXDataContainerPathFromLaunchServices target calls: 0
direct PXFindDataContainerUUIDByMetadata target calls: 0
raw ApplicationData base arrays: 0
manifest containerPath fallback warning: 0
manifest UUID fallback warning: 0
old sensitive code-303 detail: 0
```

LaunchServices remains only in read-only diagnostics after the canonical target is already accepted. Backup-side LaunchServices and metadata scanning remain byte-identical.

## 8. Early ordering proof

The verified Restore order is:

```text
public parameter guard
common manifest read/schema/version
exact bundle identity comparison
typed exact destination helper
warnings / NSFileManager / CommandRunner / debug state
tar discovery / process kill / profile lookup
artifact and archive checks
staging extraction
pre-mutation canonical revalidation
first main-target wipe
```

A destination failure therefore cannot be masked by tar code `301`, archive code `305`, target kill, debug writes, or artifact checks.

## 9. Canonical target state

- `dataContainerPath` is initialized once and populated only through the helper output backed by validator canonical output.
- It has zero later assignments or LaunchServices/metadata/manifest overwrites.
- `dataUUID` is assigned exactly once from `dataContainerModel.containerUUID`.
- No path is reconstructed from UUID after validation.
- Main ApplicationData wipe, tar-pipe clone, cp fallback, ownership correction, in-app Keychain bridge, post-debug, and metadata/Library checks all consume `dataContainerPath`.

## 10. Pre-mutation revalidation

After extraction to the existing staging directory and immediately before `_wipeDirectoryContents:dataContainerPath`, a fresh `PXDestructivePathValidator` revalidates the retained model. The result must be nonempty, error-free, and exactly equal to the preflight canonical path.

On failure:

- `stagingRoot` is removed best effort;
- no target wipe occurs;
- no tar-pipe clone, cp fallback, or target chown occurs;
- completion is dispatched on the main queue with nil result and generic code `303`;
- the stored canonical path is not replaced.

## 11. Backup and later-task boundaries

The complete `createBackupForBundleID:` body is byte-identical. Backup still prefers LaunchServices, retains metadata scan fallback, writes version 3, and emits `data.uuid`, `data.containerPath`, `sourceDataContainerUUID`, and `sourceDataContainerPath`.

The following bodies/blocks are unchanged:

- `PXVerifyArtifact`;
- `_tarExtract:` and `_tarExtractDataArchive:`;
- App Group preflight and Restore;
- preferences and Keychain Restore policy;
- profile/global/system optional Restore.

No archive-entry inspection, `PXRestorePlan`, staging redesign, rollback, transaction, or structured-result work was added. TASK-2.5 remains unimplemented.

## 12. Static gate table

Machine gate result: **134/134 PASS**.

| Gate | Result | Detail |
|---|---|---|
| PXDataContainerResolver import exactly one | PASS |  |
| PXDestructivePathValidator import exactly one | PASS |  |
| validator import unchanged at one | PASS |  |
| version helper definition unchanged at one | PASS |  |
| version helper body byte-identical | PASS | 344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7 |
| version helper exact set 2 and 3 | PASS |  |
| readManifest body byte-identical | PASS | f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff |
| read validator call retained once | PASS |  |
| read version helper call retained once | PASS |  |
| read code 200 retained | PASS |  |
| read code 201 retained | PASS |  |
| bundle mismatch comparison retained once | PASS |  |
| bundle mismatch code 304 retained once | PASS |  |
| bundle mismatch generic description retained once | PASS |  |
| exact destination helper definition exactly one | PASS |  |
| helper clears container out | PASS |  |
| helper clears canonical path out | PASS |  |
| helper clears error out | PASS |  |
| helper fail-closed input | PASS |  |
| helper instantiates resolver once | PASS |  |
| helper instantiates validator once | PASS |  |
| helper resolver calls exactly two | PASS |  |
| helper rootful resolver call exactly one | PASS |  |
| helper rootless resolver call exactly one | PASS |  |
| helper rootful before rootless | PASS |  |
| helper rootful resolver error total failure | PASS |  |
| helper rootless resolver error total failure | PASS |  |
| helper validator calls one per possible model | PASS |  |
| helper validates rootful model | PASS |  |
| helper validates rootless model | PASS |  |
| helper rootful validator failure total failure | PASS |  |
| helper rootless validator failure total failure | PASS |  |
| helper exact canonical ambiguity check | PASS |  |
| helper same-path keeps first model | PASS |  |
| helper zero-target failure | PASS |  |
| helper returns validator canonical path only | PASS |  |
| helper returns retained resolved model | PASS |  |
| helper no LaunchServices authority | PASS |  |
| helper no legacy metadata authority | PASS |  |
| helper no manifest authority | PASS |  |
| helper generic manager code 303 | PASS |  |
| helper exact generic description constant | PASS |  |
| helper no nested resolver/validator error in userInfo | PASS |  |
| Restore common reader calls exactly one | PASS |  |
| Restore exact destination helper calls exactly one | PASS |  |
| Restore direct manifest dictionary load zero | PASS |  |
| Restore direct validator schema calls zero | PASS |  |
| Restore direct version helper calls zero | PASS |  |
| Restore direct LaunchServices destination call zero | PASS |  |
| Restore direct legacy metadata target call zero | PASS |  |
| Restore raw destination base literals zero | PASS |  |
| Restore manifest data.containerPath reads zero | PASS |  |
| Restore manifest data.uuid reads zero | PASS |  |
| Restore source recorded path reads zero | PASS |  |
| manifestDataUUID token zero globally | PASS |  |
| containerPath fallback warning zero | PASS |  |
| UUID fallback warning zero | PASS |  |
| sensitive old code-303 detail zero in Restore | PASS |  |
| destination generic description exact once | PASS |  |
| dataContainerModel declared once | PASS |  |
| dataContainerPath declared once | PASS |  |
| dataContainerPath output comes from helper | PASS |  |
| dataContainerPath later overwrite zero | PASS | [] |
| dataUUID assigned from retained model only | PASS |  |
| dataUUID later overwrite zero | PASS |  |
| path reconstruction from UUID zero | PASS |  |
| in-app Keychain receives canonical path | PASS |  |
| post-restore metadata uses canonical path | PASS |  |
| post-restore Library uses canonical path | PASS |  |
| manifest read precedes bundle comparison | PASS |  |
| bundle comparison precedes destination helper | PASS |  |
| destination helper precedes warnings allocation | PASS | 2003 < 2804 |
| destination helper precedes Restore file manager acquisition | PASS | 2003 < 2875 |
| destination helper precedes Restore runner acquisition | PASS | 2003 < 2935 |
| destination helper precedes debug path | PASS | 2003 < 2992 |
| destination helper precedes debug write | PASS | 2003 < 3350 |
| destination helper precedes debug LaunchServices lookup | PASS | 2003 < 3716 |
| destination helper precedes tar discovery | PASS | 2003 < 5012 |
| destination helper precedes target kill | PASS | 2003 < 6385 |
| destination helper precedes active profile lookup | PASS | 2003 < 6624 |
| destination helper precedes artifact verification | PASS | 2003 < 9253 |
| destination helper precedes archive existence | PASS | 2003 < 9571 |
| destination helper precedes staging creation | PASS | 2003 < 11750 |
| destination helper precedes archive extraction | PASS | 2003 < 12115 |
| pre-mutation validator instance exactly one in Restore | PASS |  |
| pre-mutation revalidation call exactly one | PASS |  |
| pre-mutation canonical equality exactly one | PASS |  |
| revalidation requires nonempty path | PASS |  |
| revalidation checks validator error | PASS |  |
| staging extraction precedes revalidation | PASS |  |
| staging cleanup present on revalidation failure | PASS |  |
| revalidation precedes first main target wipe | PASS |  |
| no main target wipe before revalidation | PASS |  |
| revalidation branch immediately precedes wipe | PASS |  |
| revalidation failure uses generic manager 303 | PASS |  |
| revalidation failure main queue completion once | PASS |  |
| revalidation failure returns before wipe | PASS |  |
| wipe uses canonical path | PASS |  |
| tar pipe destination uses canonical path | PASS |  |
| cp fallback destination uses canonical path | PASS |  |
| ownership correction target uses canonical path | PASS |  |
| Backup writer method byte-identical | PASS | d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede |
| Backup writer retains @"manifestVersion": @3 | PASS |  |
| Backup writer retains @"sourceDataContainerPath": dataContainerPath ?: @"" | PASS |  |
| Backup writer retains @"sourceDataContainerUUID": dataUUID ?: @"" | PASS |  |
| Backup writer retains @"uuid": dataUUID | PASS |  |
| Backup writer retains @"containerPath": dataContainerPath | PASS |  |
| Backup LaunchServices preference retained | PASS |  |
| Backup metadata fallback retained | PASS |  |
| artifact verifier byte-identical | PASS | 20bb62665e7878704ffb5565de49849402631c72d5cba40cc3868dd46b312a1f |
| tar extract method byte-identical | PASS | acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a |
| data tar extract method byte-identical | PASS | 892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881 |
| App Group preflight block byte-identical | PASS |  |
| artifact verification block byte-identical | PASS |  |
| profile/global optional block byte-identical | PASS |  |
| App Group restore block byte-identical | PASS |  |
| system/global restore block byte-identical | PASS |  |
| preferences/Keychain block byte-identical | PASS |  |
| no PXRestorePlan additions | PASS |  |
| no archive-entry validator additions | PASS |  |
| protected working-tree diff zero | PASS | 0 |
| AppDataBackupManager.h diff zero | PASS |  |
| PXDataContainerResolver.h diff zero | PASS |  |
| PXDataContainerResolver.m diff zero | PASS |  |
| PXDestructivePathValidator.h diff zero | PASS |  |
| PXDestructivePathValidator.m diff zero | PASS |  |
| AppDataBackupRestoreViewController.m diff zero | PASS |  |
| ProfileManagerViewController.m diff zero | PASS |  |
| ProjectXViewController.m diff zero | PASS |  |
| Makefile diff zero | PASS |  |
| manager NUL zero | PASS |  |
| manager CRLF preserved | PASS | crlf=2480 lf=2480 |
| added source trailing whitespace zero | PASS |  |
| source diff check | PASS |  |

## 13. Scenario matrix

Scenario count: **85**. These are static/source contract cases. Device behavior is marked pending where target filesystem fixtures are required; no row claims unperformed device execution.

| # | Scenario | Expected/verified behavior | Status |
|---:|---|---|---|
| 1 | Missing backup directory | Existing public guard returns manager code 300 before manifest read. | Static PASS |
| 2 | Empty requested bundle identifier | Existing public guard returns manager code 300. | Static PASS |
| 3 | Missing manifest file | Common reader returns manager code 200 before destination work. | Static PASS |
| 4 | Structurally invalid manifest | Exact validator NSError remains earlier than destination resolution. | Static PASS |
| 5 | Unsupported positive manifest version | Common reader returns manager code 201 before destination resolution. | Static PASS |
| 6 | Supported manifest with bundle mismatch | Exact TASK-2.3 gate returns manager code 304 before destination resolution. | Static PASS |
| 7 | Rootful exact target only | Rootful model is validated and returned as the unique target. | Source-covered; device pending |
| 8 | Rootless exact target only | Absent rootful plus valid rootless model returns rootless canonical target. | Source-covered; device pending |
| 9 | Neither root has an exact target | Both resolver calls may return nil/no error; helper returns generic code 303. | Static PASS |
| 10 | Both roots canonicalize to same path | Rootful model is retained and rootless equal canonical path is treated as one target. | Static PASS |
| 11 | Roots canonicalize to distinct paths | Exact string inequality fails closed as ambiguous with code 303. | Static PASS |
| 12 | Rootful resolver error | Helper stops and emits generic code 303 without exposing nested error. | Static PASS |
| 13 | Rootless resolver error after rootful match | Helper fails the whole request with generic code 303. | Static PASS |
| 14 | Rootful validator error | Rootful candidate is rejected; helper emits generic code 303. | Static PASS |
| 15 | Rootless validator error after rootful match | Helper fails rather than silently using rootful target. | Static PASS |
| 16 | Multiple exact candidates in rootful root | Resolver ambiguity becomes generic manager code 303. | Source-covered; device pending |
| 17 | Multiple exact candidates in rootless root | Resolver ambiguity becomes generic manager code 303. | Source-covered; device pending |
| 18 | Manifest containerPath points to unrelated existing directory | Restore contains zero destination reads of recorded containerPath. | Static PASS |
| 19 | Manifest UUID points to unrelated existing container | Restore contains zero recorded UUID destination reads or reconstruction loops. | Static PASS |
| 20 | Recorded containerPath equals current canonical path | Recorded path remains ignored; typed resolver/validator still establishes authority. | Static PASS |
| 21 | Recorded UUID equals current model UUID | Recorded UUID remains ignored; dataUUID comes from retained model only. | Static PASS |
| 22 | sourceDataContainerPath present | Field is not read for Restore destination selection. | Static PASS |
| 23 | sourceDataContainerUUID present | Field is not read for Restore destination selection. | Static PASS |
| 24 | LaunchServices path equals canonical target | LaunchServices may appear in read-only debug after preflight but grants no authority. | Static PASS |
| 25 | LaunchServices path differs from canonical target | Debug value cannot overwrite canonical dataContainerPath. | Static PASS |
| 26 | Legacy metadata scan would find another path | Restore performs zero direct legacy metadata target calls. | Static PASS |
| 27 | Same canonical alias from rootful and rootless | First model is retained in deterministic rootful-before-rootless order. | Static PASS |
| 28 | Resolver raw candidate differs from validator output | Only validator-returned canonical string is assigned to output. | Static PASS |
| 29 | Resolver returns nil without error | Root is treated as absent rather than an error. | Static PASS |
| 30 | Helper receives invalid input | Out parameters are cleared and helper fails closed with generic code 303. | Static PASS |
| 31 | Pre-populated model/path outputs on failure | Both outputs are cleared at helper entry. | Static PASS |
| 32 | Pre-populated error output | Error is cleared at helper entry before processing. | Static PASS |
| 33 | Destination failure error shape | Domain is PXBackupErrorDomain, code 303, fixed generic description. | Static PASS |
| 34 | Resolver/validator returns sensitive nested NSError | Nested errors are not placed in public Restore error userInfo. | Static PASS |
| 35 | Destination error privacy | No bundle ID, path, UUID, metadata or manifest value is interpolated. | Static PASS |
| 36 | Destination failure versus warnings allocation | Destination helper executes before warnings are allocated. | Static PASS |
| 37 | Destination failure versus NSFileManager setup | Restore file-manager acquisition occurs only after accepted destination. | Static PASS |
| 38 | Destination failure versus CommandRunner setup | Runner acquisition occurs only after accepted destination. | Static PASS |
| 39 | Destination failure versus debug output | Debug paths and writes occur only after accepted destination. | Static PASS |
| 40 | Destination failure versus tar discovery | Code 303 precedes possible tar-not-found code 301. | Static PASS |
| 41 | Destination failure versus process kill | Target process is not killed on destination preflight failure. | Static PASS |
| 42 | Destination failure versus profile lookup | Active profile lookup remains after destination acceptance. | Static PASS |
| 43 | Destination failure versus artifact verification | Artifact verification is not reached on destination failure. | Static PASS |
| 44 | Destination failure versus archive checks | data.tar.gz checks remain later. | Static PASS |
| 45 | Destination failure versus staging creation | No task staging directory is created before destination acceptance. | Static PASS |
| 46 | Destination failure versus extraction | Archive extraction remains after destination acceptance. | Static PASS |
| 47 | Malformed manifest plus missing destination | Structural validator error wins over code 303. | Static PASS |
| 48 | Unsupported version plus missing destination | Unsupported code 201 wins over code 303. | Static PASS |
| 49 | Bundle mismatch plus missing destination | Mismatch code 304 wins over code 303. | Static PASS |
| 50 | Valid target plus tar missing | Existing tar-unavailable code 301 remains later. | Static PASS |
| 51 | Valid target plus data archive missing | Existing data archive code 305 remains later. | Static PASS |
| 52 | Pre-mutation revalidation returns same canonical path | Current wipe/clone flow proceeds unchanged. | Static PASS |
| 53 | Pre-mutation validator returns error | Staging is removed, code 303 is completed, and target is not wiped. | Static PASS |
| 54 | Pre-mutation validator returns nil/empty path | Fail closed with staging cleanup and code 303. | Static PASS |
| 55 | Canonical path changes before mutation | Exact inequality fails; stored destination is not replaced. | Static PASS |
| 56 | Staging exists when revalidation fails | stagingRoot is removed best effort before completion. | Static PASS |
| 57 | Revalidation failure and wipe | No main ApplicationData wipe occurs before successful revalidation. | Static PASS |
| 58 | Revalidation failure and tar-pipe clone | Return occurs before clone command construction/execution. | Static PASS |
| 59 | Revalidation failure and cp fallback | Return occurs before cp clone fallback. | Static PASS |
| 60 | Revalidation failure and ownership correction | Return occurs before recursive chown of main target. | Static PASS |
| 61 | Revalidation failure callback | Completion is dispatched on main queue once with nil result and code 303. | Static PASS |
| 62 | Revalidation failure with nil completion | Main-queue block preserves existing guarded completion behavior. | Static PASS |
| 63 | Pre-wipe debug inspection | Inspection command consumes retained canonical dataContainerPath. | Static PASS |
| 64 | Main data wipe | _wipeDirectoryContents receives canonical dataContainerPath only. | Static PASS |
| 65 | Tar-pipe destination | Destination -C uses canonical dataContainerPath. | Static PASS |
| 66 | cp fallback destination | cp destination uses canonical dataContainerPath. | Static PASS |
| 67 | Ownership correction | Recursive chown target uses canonical dataContainerPath. | Static PASS |
| 68 | In-app Keychain restore | Bridge receives canonical dataContainerPath. | Static PASS |
| 69 | Post-restore debug | Chosen target diagnostics use canonical dataContainerPath. | Static PASS |
| 70 | Metadata postcondition | Metadata path is derived from canonical dataContainerPath. | Static PASS |
| 71 | Library postcondition | Library path is derived from canonical dataContainerPath. | Static PASS |
| 72 | Backup LaunchServices preference | createBackup method is byte-identical and still uses LaunchServices first. | Static PASS |
| 73 | Backup metadata scan fallback | createBackup method retains PXFindDataContainerUUIDByMetadata behavior. | Static PASS |
| 74 | Backup manifest version | Writer remains manifestVersion @3. | Static PASS |
| 75 | Backup data.uuid field | Writer still emits dataUUID. | Static PASS |
| 76 | Backup data.containerPath field | Writer still emits source dataContainerPath in data section. | Static PASS |
| 77 | Backup sourceDataContainer fields | Both source path and UUID metadata fields remain emitted. | Static PASS |
| 78 | Artifact verification policy | PXVerifyArtifact body is byte-identical. | Static PASS |
| 79 | Archive extraction policy | _tarExtract and _tarExtractDataArchive bodies are byte-identical. | Static PASS |
| 80 | App Group preflight/restore | Compared blocks are byte-identical. | Static PASS |
| 81 | Preferences and Keychain Restore | Compared block is byte-identical except canonical path already supplied to existing bridge call. | Static PASS |
| 82 | Profile/global/system Restore | Compared optional-component blocks are byte-identical. | Static PASS |
| 83 | Restore planning | No PXRestorePlan type or plan construction was added. | Static PASS |
| 84 | TASK-2.5 artifact redesign | No common artifact redesign or archive-entry inspection was added. | Static PASS |
| 85 | Build/runtime honesty | Static gates pass; local Objective-C/device runtime was not available in this Windows workspace. | Static PASS / runtime pending |

## 14. Complete focused source diff

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index 6b7bbd7..aaf39a5 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -10,6 +10,8 @@
 #import "AppEntitlementsReader.h"
 #import "AppGroupContainerResolver.h"
 #import "PXBackupManifestValidator.h"
+#import "PXDataContainerResolver.h"
+#import "PXDestructivePathValidator.h"
 #import "CommandRunner.h"
 #import "common/PXProcessKiller.h"
 #import "common/PXPaths.h"
@@ -18,6 +20,8 @@
 #import <notify.h>

 static NSString * const PXBackupErrorDomain = @"com.hydra.projectx.backup";
+static NSString * const PXExactRestoreDestinationErrorDescription =
+    @"Exact application data container could not be resolved safely";

 static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
     if (![version isKindOfClass:[NSNumber class]]) {
@@ -28,6 +32,102 @@ static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
     return value == 2 || value == 3;
 }

+static BOOL PXResolveExactRestoreApplicationDataTarget(
+    NSString *bundleID,
+    PXResolvedContainer **containerOut,
+    NSString **canonicalPathOut,
+    NSError **error) {
+    if (containerOut) {
+        *containerOut = nil;
+    }
+    if (canonicalPathOut) {
+        *canonicalPathOut = nil;
+    }
+    if (error) {
+        *error = nil;
+    }
+
+    BOOL resolved = NO;
+    do {
+        if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) {
+            break;
+        }
+
+        PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
+        PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
+
+        PXResolvedContainer *selectedModel = nil;
+        NSString *selectedCanonicalPath = nil;
+
+        NSError *rootfulResolverError = nil;
+        PXResolvedContainer *rootfulModel =
+            [resolver resolveApplicationDataContainerForIdentifier:bundleID
+                                                              root:PXResolvedContainerRootRootful
+                                                             error:&rootfulResolverError];
+        if (rootfulResolverError) {
+            break;
+        }
+        if (rootfulModel) {
+            NSError *rootfulValidationError = nil;
+            NSString *rootfulCanonicalPath =
+                [validator validatedCanonicalPathForContainer:rootfulModel
+                                                        error:&rootfulValidationError];
+            if (rootfulValidationError || rootfulCanonicalPath.length == 0) {
+                break;
+            }
+            selectedModel = rootfulModel;
+            selectedCanonicalPath = rootfulCanonicalPath;
+        }
+
+        NSError *rootlessResolverError = nil;
+        PXResolvedContainer *rootlessModel =
+            [resolver resolveApplicationDataContainerForIdentifier:bundleID
+                                                              root:PXResolvedContainerRootRootless
+                                                             error:&rootlessResolverError];
+        if (rootlessResolverError) {
+            break;
+        }
+        if (rootlessModel) {
+            NSError *rootlessValidationError = nil;
+            NSString *rootlessCanonicalPath =
+                [validator validatedCanonicalPathForContainer:rootlessModel
+                                                        error:&rootlessValidationError];
+            if (rootlessValidationError || rootlessCanonicalPath.length == 0) {
+                break;
+            }
+            if (!selectedModel) {
+                selectedModel = rootlessModel;
+                selectedCanonicalPath = rootlessCanonicalPath;
+            } else if (![selectedCanonicalPath isEqualToString:rootlessCanonicalPath]) {
+                break;
+            }
+        }
+
+        if (!selectedModel || selectedCanonicalPath.length == 0) {
+            break;
+        }
+
+        if (containerOut) {
+            *containerOut = selectedModel;
+        }
+        if (canonicalPathOut) {
+            *canonicalPathOut = selectedCanonicalPath;
+        }
+        resolved = YES;
+    } while (NO);
+
+    if (resolved) {
+        return YES;
+    }
+
+    if (error) {
+        *error = [NSError errorWithDomain:PXBackupErrorDomain
+                                     code:303
+                                 userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
+    }
+    return NO;
+}
+
 @implementation PXBackupResult
 @end

@@ -1775,6 +1875,21 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             return;
         }

+        PXResolvedContainer *dataContainerModel = nil;
+        NSString *dataContainerPath = nil;
+        NSError *destinationError = nil;
+        if (!PXResolveExactRestoreApplicationDataTarget(bundleID,
+                                                        &dataContainerModel,
+                                                        &dataContainerPath,
+                                                        &destinationError)) {
+            NSError *err = destinationError ?: [NSError errorWithDomain:PXBackupErrorDomain
+                                                                    code:303
+                                                                userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+        NSString *dataUUID = dataContainerModel.containerUUID;
+
         NSMutableArray<NSString *> *warnings = [NSMutableArray array];
         NSFileManager *fm = [NSFileManager defaultManager];
         CommandRunner *runner = [CommandRunner shared];
@@ -1845,82 +1960,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             [warnings addObject:[NSString stringWithFormat:@"Backup profileId %@ != active profileId %@", manifestProfileId, activeProfileId]];
         }

-        // Data container lookup:
-        // Prefer active container path (LaunchServices). Fall back to metadata scan.
-        NSString *manifestDataUUID = nil;
-        if ([manifest[@"data"] isKindOfClass:[NSDictionary class]] && [manifest[@"data"][@"uuid"] isKindOfClass:[NSString class]]) {
-            manifestDataUUID = manifest[@"data"][@"uuid"];
-        }
-
-        NSString *dataUUID = nil;
-        NSString *dataContainerPath = nil;
-
-        // Prefer LaunchServices-reported container path (most reliable for the *active* container).
-        {
-            NSString *lsPath = PXDataContainerPathFromLaunchServices(bundleID);
-            BOOL isDir = NO;
-            if (lsPath.length && [fm fileExistsAtPath:lsPath isDirectory:&isDir] && isDir) {
-                dataContainerPath = lsPath;
-                dataUUID = lsPath.lastPathComponent;
-            }
-        }
-
-        NSArray<NSString *> *bases = @[
-            @"/var/mobile/Containers/Data/Application",
-            @"/private/var/mobile/Containers/Data/Application",
-            @"/containers/Data/Application",
-            @"/private/var/containers/Data/Application"
-        ];
-
-        // Scan bases for a container with matching metadata.
-        if (!dataContainerPath) {
-            for (NSString *base in bases) {
-                NSString *found = PXFindDataContainerUUIDByMetadata(fm, base, bundleID);
-                if (found.length) {
-                    dataUUID = found;
-                    dataContainerPath = [base stringByAppendingPathComponent:found];
-                    break;
-                }
-            }
-        }
-
-        // Fallback: use manifest containerPath/UUID if directory exists (useful after aggressive clears).
-        if (!dataContainerPath) {
-            NSString *p = nil;
-            if ([manifest[@"data"] isKindOfClass:[NSDictionary class]] && [manifest[@"data"][@"containerPath"] isKindOfClass:[NSString class]]) {
-                p = manifest[@"data"][@"containerPath"];
-            }
-            BOOL isDir = NO;
-            if (p.length && [fm fileExistsAtPath:p isDirectory:&isDir] && isDir) {
-                dataContainerPath = p;
-                dataUUID = p.lastPathComponent;
-                [warnings addObject:@"Using manifest containerPath for restore (fallback)" ];
-            }
-        }
-        if (!dataContainerPath && manifestDataUUID.length) {
-            for (NSString *base in bases) {
-                NSString *p = [base stringByAppendingPathComponent:manifestDataUUID];
-                BOOL isDir = NO;
-                if ([fm fileExistsAtPath:p isDirectory:&isDir] && isDir) {
-                    dataContainerPath = p;
-                    dataUUID = manifestDataUUID;
-                    [warnings addObject:@"Using manifest UUID for restore (fallback)" ];
-                    break;
-                }
-            }
-        }
-
-        if (!dataUUID.length || !dataContainerPath.length) {
-            NSString *hint = @"Data container not found. Ensure the app is installed and launched at least once (to create its data container).";
-            NSString *lsPath = PXDataContainerPathFromLaunchServices(bundleID) ?: @"";
-            NSString *detail = [NSString stringWithFormat:@"%@ (bundleID=%@ lsPath=%@ manifestUUID=%@)", hint, bundleID, lsPath, manifestDataUUID ?: @""];
-            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                               code:303
-                                           userInfo:@{NSLocalizedDescriptionKey: detail}];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-            return;
-        }
-
         PXDebugHeader(debugPre, @"Chosen Container");
         PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"chosenDataContainerPath=%@", dataContainerPath ?: @""]);
         PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"chosenDataUUID=%@", dataUUID ?: @""]);
@@ -2020,6 +2059,23 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"stagingData=%@", stagingData ?: @""]);
         PXDebugRun(runner, debugPre, @"du stagingData", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(stagingData)]);
         PXDebugRun(runner, debugPre, @"ls container (before wipe)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
+
+        PXDestructivePathValidator *preMutationValidator = [[PXDestructivePathValidator alloc] init];
+        NSError *preMutationValidationError = nil;
+        NSString *preMutationCanonicalPath =
+            [preMutationValidator validatedCanonicalPathForContainer:dataContainerModel
+                                                               error:&preMutationValidationError];
+        if (preMutationValidationError ||
+            preMutationCanonicalPath.length == 0 ||
+            ![preMutationCanonicalPath isEqualToString:dataContainerPath]) {
+            [fm removeItemAtPath:stagingRoot error:nil];
+            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                               code:303
+                                           userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
         [self _wipeDirectoryContents:dataContainerPath];
         PXDebugRun(runner, debugPre, @"ls container (after wipe)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
         BOOL shouldPreferCpClone = NO;
```

## 15. Whitespace, line endings, NUL, and generated audit

- Manager raw bytes: `129166`; SHA-256: `0f1f98e8c959a3b8e4dd7890f68eab24c247d2678c52d860bb1870c239979adb`.
- Manager CRLF count: `2480`; LF count: `2480`; CRLF preserved.
- Manager NUL bytes: `0`.
- Added production lines with trailing whitespace: `0`.
- `git diff --check -- AppDataBackupManager.m`: PASS.
- Temporary `.task24*` audit files are not implementation artifacts and will be deleted before staging.
- No generated/binary production artifact was created.

## 16. Build status and remaining runtime risks

Local build was not run because this Windows workspace has no `clang`, `clang-cl`, `make`, or `xcrun`. GitHub Actions and target-device execution are pending; this report does not claim a compile or runtime pass.

Remaining device risks to exercise include rootful/rootless alias canonicalization, concurrent filesystem identity changes between preflight and mutation, resolver ambiguity fixtures, ownership/mode policy, callback timing, and staging cleanup failure tolerance. These do not justify implementing TASK-2.5 in this task.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
