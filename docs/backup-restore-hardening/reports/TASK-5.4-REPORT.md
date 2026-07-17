# TASK-5.4 — REQUIRE EXPLICIT CONFIRMATION FOR ADVANCED SCOPES

## Result
PASS. TASK-5.4 is implemented within the exact authorized two-file scope. Phase 6 was not started.

## User authority
TASK-5.3 was accepted as PASSED and COMPLETED by user authority, opening TASK-5.4 for implementation.

## TASK-5.3 review-file status
`docs/backup-restore-hardening/reviews/TASK-5.3-REVIEW.md` is absent. Per task authority, this is not a blocker.

## Baseline
- Required baseline: `709980e874035ebde732c4b2e38a9685b52ee025`
- Expected subject: `709980e phase5(task-5.3): display restore component results`

## Working-tree preservation
Pre-existing coordinator-document modifications and untracked task/review documents were not staged, reset, deleted, rewritten, or normalized.

## Exact authorized scope
- `M AppDataBackupRestoreViewController.m`
- `A docs/backup-restore-hardening/reports/TASK-5.4-REPORT.md`

## Current confirmation defects
The baseline read Backup switches after generic confirmation, showed Restore confirmation before backup selection, and did not bind approval to an immutable selected-manifest snapshot.

## Advanced-scope definition
Application Data remains the mandatory base scope. Seven private file-local advanced-scope bits represent Profile App Data, Global Safari, App Groups, System Global, Shared System Databases, Global Preferences, and Keychain.

## Exact seven scope bits
- `8` — Profile App Data
- `16` — Global Safari
- `1` — App Groups
- `32` — System Global
- `64` — Shared System Databases
- `2` — Global Preferences
- `4` — Keychain

## Canonical order
1. Profile App Data
2. Global Safari
3. App Groups
4. System Global
5. Shared System Databases
6. Global Preferences
7. Keychain

## Exact display names
The seven confirmation labels are emitted exactly as listed above. TASK-5.3's component label `Preferences` remains byte-identical; only confirmation uses `Global Preferences`.

## Scope-list formatting
Selected advanced scopes are rendered once each as `- <Scope Name>` in canonical order, with no count, no duplicate, no trailing blank line, and no raw mask.

## Backup option authority
Only the immutable local `PXBackupOptions` snapshot derived from the three direct UI switches is authoritative for Backup confirmation and the later manager invocation.

## Backup immutable snapshot
Each switch is read exactly once before confirmation. The positive action captures `capturedOptions` by value and contains zero switch reads.

## Data-only Backup confirmation
- Title: `Confirm Backup`
- Message: `Back up Application Data for <application>?`
- Positive action: `Backup`, default style

## Advanced Backup confirmation
- Title: `Confirm Advanced Backup`
- Positive action: `Back Up Advanced Data`, default style
- The canonical advanced-scope list is followed by the exact shared/sensitive-data warning sentence.

## Backup cancellation
Cancel creates no processing alert, performs no manager call, changes no switch, and stores no consent receipt.

## Restore manifest authority
Restore advanced scopes are derived from validated factual manifest sections, not raw request telemetry or includedOptions.

## Exact Boolean parser
`PXReadExactManifestBoolean` accepts only CFBoolean-backed property-list values and rejects integer, string, floating-point, nil, and custom boolValue-like objects.

## Version 2–5 compatibility
Versions 2 and 3 accept absent optional system/shared sections. Versions 4 and 5 consume the validated strict sections. All versions require exact bundle identity and required scope-section types.

## Actual inclusion versus raw request
App Groups requires a nonempty factual `appGroups` array. Profile, Safari, Preferences, and Keychain use exact included flags. System/shared require included=true and nonempty item arrays.

## Restore flow reorder
The sequence is now: tap Restore → discover backups → picker → select backup → validate/derive scopes → confirmation → re-read/equality check → processing alert → manager Restore → unchanged result presentation.

## Picker preservation
The ten-item limit, discovery order, timestamp title, basename fallback, Cancel action, Select Backup title, and iPad popover configuration remain present.

## Restore unavailable behavior
A selected manifest that cannot be read, validated, scope-parsed, or snapshotted shows `Restore Unavailable`; usable NSError text is preferred, otherwise the exact fallback is used. No manager call occurs.

## Immutable manifest snapshot
The validated property-list graph is serialized and deserialized with immutable containers. The external dictionary reference is not retained as confirmation authority.

## Whole-manifest confirmation binding
Inside the positive action, the manifest is read again. Restore requires exact whole-dictionary equality, equal scope masks, and matching bundle identity before the processing alert or manager call.

## Restore selection changed behavior
Any disappearance, validation failure, identity change, scope change, metadata change, warning change, or other field mutation shows `Restore Selection Changed` with the exact required message and zero processing/manager calls.

## Data-only Restore confirmation
- Title: `Confirm Restore`
- Positive action: `Restore`, destructive style

## Advanced Restore confirmation
- Title: `Confirm Advanced Restore`
- Positive action: `Restore Advanced Data`, destructive style
- The canonical advanced-scope list is followed by the exact shared/sensitive/system-impact warning sentence.

## Restore cancellation
Picker Cancel and either confirmation Cancel perform zero second-manifest reads, zero processing alerts, and zero manager calls.

## No persistent consent
No user default, Keychain value, file, notification, property, singleton, static mutable state, or manifest field stores approval.

## Privacy proof
User-facing confirmation text contains only canonical scope names and application prose. It exposes no group identifiers, UUIDs, access groups, profile IDs, paths, artifact metadata, checksums, backupID, or raw masks.

## Backup result callback hash
- bytes: 2020
- sha256: `d8f0983c5a870c6d62e616e80a9eae3826259f22eb7b9ed38dfc6648d66e576b`

## Restore result callback hash
- bytes: 3933
- sha256: `583cac544a9b7a5bded972e8d75da331be2a4fcf14a29d65c5bd68060ed90454`

## TASK-5.1 helper hashes
- backup-presentation-helpers: 1907 bytes, `eec90ebe21381e18fb5f62579aa90163ee850f544fb46d08e78f15a853366335`
- pending-alert-region: 2754 bytes, `00ba8cbbe9952292f0d9d39e0d3db7c4869b4968e3455527d373c8d503d48337`

## TASK-5.2 outcome hashes
- restore-outcome-core: 10510 bytes, `7b58e3b703dcea3d0ffb44120c65d18591420810bb833804537e3a0a91227a22`
- restore-warning-helper: 344 bytes, `bee9a0b8976adb067044fec0059d897b2e5ba9b98a17da9860073be0f1c99a34`

## TASK-5.3 formatter hash
- restore-component-formatters: 6558 bytes, `1a0a16150b4694bf66afd6b5f8a31a79d492cd61b7cebb3073602cf90f3f884f`

## Pending-alert hash
- pending-alert-region: 2754 bytes, `00ba8cbbe9952292f0d9d39e0d3db7c4869b4968e3455527d373c8d503d48337`

## Option-control hash
- view-option-controls: 3634 bytes, `d37af7c06bf0b55cfd5fb556adc4e026647e7b8394b6c8da645a935839da0af5`

## Manager and manifest hashes
- AppDataBackupManager.h: 1442 bytes, `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75`
- AppDataBackupManager.m: 239969 bytes, `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028`
- PXBackupManifestValidator.h: 945 bytes, `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836`
- PXBackupManifestValidator.m: 91206 bytes, `8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b`
- PXBackupManifestV4.h: 2354 bytes, `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054`
- PXBackupManifestV4.m: 45136 bytes, `4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037`
- PXRestorePlan.h: 4947 bytes, `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643`
- PXRestorePlan.m: 48523 bytes, `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141`
- PXRestoreResult.h: 4512 bytes, `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d`
- PXRestoreResult.m: 15842 bytes, `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb`

## Batch caller hashes
- ProfileManagerViewController.m: 159713 bytes, `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a`
- ProjectXViewController.m: 372278 bytes, `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162`

## Previous report hashes
- TASK-5.1-REPORT.md: 54678 bytes, `736d6a38719daf7c9384cca8f728b0ed7078e65f1ba935c5cb32cc34914e4fd6`
- TASK-5.2-REPORT.md: 99242 bytes, `b5c76629dbe35ac81fd7081a1195ddeda77cef7fe1d6ce424f5cbdd5ab84202c`
- TASK-5.3-REPORT.md: 126346 bytes, `8bf6b4cc86521f9cb0ea8e1a38e9cf6f619fa3e377dd137396fa055b066154a8`

## Protected production hashes
- AppDataBackupManager.h: 1442 bytes, `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75`
- AppDataBackupManager.m: 239969 bytes, `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028`
- AppDataBackupRestoreViewController.h: 336 bytes, `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf`
- KeychainHelper/KeychainBackupHelper.h: 4584 bytes, `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c`
- KeychainHelper/KeychainBackupHelper.m: 38587 bytes, `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2`
- KeychainHelper/PXKeychainHelperExitCode.h: 784 bytes, `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a`
- KeychainHelper/PXKeychainHelperResult.h: 4083 bytes, `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3`
- KeychainHelper/PXKeychainHelperResult.m: 51525 bytes, `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5`
- KeychainHelper/PXKeychainItemIdentity.h: 2387 bytes, `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4`
- KeychainHelper/PXKeychainItemIdentity.m: 62919 bytes, `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df`
- KeychainHelper/backup_helper.m: 42561 bytes, `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7`
- Makefile: 9266 bytes, `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa`
- PXAppGroupRestoreTransaction.h: 2235 bytes, `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412`
- PXAppGroupRestoreTransaction.m: 138376 bytes, `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6`
- PXBackupArchiveValidator.h: 2361 bytes, `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b`
- PXBackupArchiveValidator.m: 89098 bytes, `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e`
- PXBackupArtifactVerifier.h: 2006 bytes, `2cd726496b1830cc404c6e6665e73785552a39c74cdb9683a43d32221fc194cc`
- PXBackupArtifactVerifier.m: 46654 bytes, `2c45882144f529380bf485724bdd2258a3d9dd43de232076e857f10f3d5958f9`
- PXBackupManifestV4.h: 2354 bytes, `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054`
- PXBackupManifestV4.m: 45136 bytes, `4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037`
- PXBackupManifestValidator.h: 945 bytes, `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836`
- PXBackupManifestValidator.m: 91206 bytes, `8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b`
- PXMainDataRestoreTransaction.h: 2061 bytes, `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575`
- PXMainDataRestoreTransaction.m: 115847 bytes, `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5`
- PXOptionalRestoreStaging.h: 4355 bytes, `3d594d5f2eb509e2fb9e87849013ec9428ef7083eb0c4b52ecffe00fa56809c3`
- PXOptionalRestoreStaging.m: 104823 bytes, `1e3a0eabba6a5a8a90cb7cf3800476e9324ec4181be1fb51de0e0e08e2c5e39b`
- PXOptionalRestoreTransaction.h: 4050 bytes, `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78`
- PXOptionalRestoreTransaction.m: 240408 bytes, `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c`
- PXRestorePlan.h: 4947 bytes, `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643`
- PXRestorePlan.m: 48523 bytes, `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141`
- PXRestoreResult.h: 4512 bytes, `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d`
- PXRestoreResult.m: 15842 bytes, `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb`
- ProfileManagerViewController.m: 159713 bytes, `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a`
- ProjectXViewController.m: 372278 bytes, `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162`
- WeaponXKeychainBridge/Tweak.m: 21970 bytes, `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa`
- scripts/keychain_backup.sh: 75266 bytes, `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12`

## Static source gates
- exact `@"Confirm Backup"`: 1
- exact `@"Confirm Advanced Backup"`: 1
- exact `@"Confirm Restore"`: 1
- exact `@"Confirm Advanced Restore"`: 1
- exact `@"Back Up Advanced Data"`: 1
- exact `@"Restore Advanced Data"`: 1
- exact `@"Restore Unavailable"`: 1
- exact `@"Restore Selection Changed"`: 1
- exact `@"Global Preferences"`: 1
- exact `@"Advanced scopes may contain shared or sensitive data. Continue?"`: 1
- exact `@"Advanced scopes may replace shared or sensitive data and can affect other apps or system services. This operation cannot be undone. Continue?"`: 1
- exact `@"The selected backup changed after confirmation. Select it again and review its scopes before restoring."`: 1
- advanced-scope enum bits: 7
- canonical scope entries: 7
- display-name switch cases: 7
- Backup switch reads: 3
- switch reads inside confirmation handler: 0
- selected-flow manifest reads: 3
- whole-manifest equality checks: 1
- Backup manager source calls: 1
- Restore manager source calls: 1
- old garbled Restore warning: 0

## Eight Backup combinations
- groups=0, preferences=0, keychain=0 → Confirm Backup / Backup
- groups=0, preferences=0, keychain=1 → Confirm Advanced Backup / Back Up Advanced Data
- groups=0, preferences=1, keychain=0 → Confirm Advanced Backup / Back Up Advanced Data
- groups=0, preferences=1, keychain=1 → Confirm Advanced Backup / Back Up Advanced Data
- groups=1, preferences=0, keychain=0 → Confirm Advanced Backup / Back Up Advanced Data
- groups=1, preferences=0, keychain=1 → Confirm Advanced Backup / Back Up Advanced Data
- groups=1, preferences=1, keychain=0 → Confirm Advanced Backup / Back Up Advanced Data
- groups=1, preferences=1, keychain=1 → Confirm Advanced Backup / Back Up Advanced Data

## 128 Restore combinations
All 128 masks were tested in canonical order for each validated manifest version 2, 3, 4, and 5: 512/512 PASS.

## Manifest mutation tests
- manifestVersion: selection changed, processing=0, Restore manager=0
- bundleID: selection changed, processing=0, Restore manager=0
- timestamp: selection changed, processing=0, Restore manager=0
- backupID: selection changed, processing=0, Restore manager=0
- applicationGroups: selection changed, processing=0, Restore manager=0
- appGroups: selection changed, processing=0, Restore manager=0
- preferences: selection changed, processing=0, Restore manager=0
- keychain: selection changed, processing=0, Restore manager=0
- profileAppData: selection changed, processing=0, Restore manager=0
- globalSafari: selection changed, processing=0, Restore manager=0
- systemGlobalLibrary: selection changed, processing=0, Restore manager=0
- sharedSystemDB: selection changed, processing=0, Restore manager=0
- artifacts: selection changed, processing=0, Restore manager=0
- options: selection changed, processing=0, Restore manager=0
- warnings: selection changed, processing=0, Restore manager=0
- restoreCompatibility: selection changed, processing=0, Restore manager=0
- publication: selection changed, processing=0, Restore manager=0

## Invocation-count tests
- Cancel data-only Backup: Backup manager=0, Restore manager=0, processing alerts=0
- Cancel advanced Backup: Backup manager=0, Restore manager=0, processing alerts=0
- Confirm Backup: Backup manager=1, Restore manager=0, processing alerts=1
- Cancel picker: Backup manager=0, Restore manager=0, processing alerts=0
- Cancel data-only Restore: Backup manager=0, Restore manager=0, processing alerts=0
- Cancel advanced Restore: Backup manager=0, Restore manager=0, processing alerts=0
- Manifest unavailable: Backup manager=0, Restore manager=0, processing alerts=0
- Manifest changed: Backup manager=0, Restore manager=0, processing alerts=0
- Confirm unchanged Restore: Backup manager=0, Restore manager=1, processing alerts=1

## Explicit scenarios
Explicit numbered scenario count: 855.

| # | Group | Scenario | Result |
|---:|---|---|---|
| 1 | baseline and scope | Required baseline HEAD matches | PASS |
| 2 | baseline and scope | Expected previous commit subject matches | PASS |
| 3 | baseline and scope | TASK-5.3 user authority accepted | PASS |
| 4 | baseline and scope | Missing TASK-5.3 review file is non-blocking | PASS |
| 5 | baseline and scope | Authorized implementation scope contains controller and report only | PASS |
| 6 | baseline and scope | Controller header remains protected | PASS |
| 7 | baseline and scope | No production source file added | PASS |
| 8 | baseline and scope | No public API added | PASS |
| 9 | baseline and scope | Makefile remains protected | PASS |
| 10 | baseline and scope | Coordinator STATUS preserved | PASS |
| 11 | baseline and scope | Coordinator ROADMAP preserved | PASS |
| 12 | baseline and scope | Coordinator DECISIONS preserved | PASS |
| 13 | baseline and scope | Coordinator README preserved | PASS |
| 14 | baseline and scope | Pre-existing untracked task documents preserved | PASS |
| 15 | baseline and scope | Pre-existing untracked review documents preserved | PASS |
| 16 | baseline and scope | Phase 6 boundary remains closed | PASS |
| 17 | baseline and scope | Backup result callback is protected | PASS |
| 18 | baseline and scope | Restore result callback is protected | PASS |
| 19 | baseline and scope | Option-control defaults are protected | PASS |
| 20 | baseline and scope | Pending result presentation is protected | PASS |
| 21 | seven scope bits | Bit 8 maps to Profile App Data | PASS |
| 22 | seven scope bits | Bit 16 maps to Global Safari | PASS |
| 23 | seven scope bits | Bit 1 maps to App Groups | PASS |
| 24 | seven scope bits | Bit 32 maps to System Global | PASS |
| 25 | seven scope bits | Bit 64 maps to Shared System Databases | PASS |
| 26 | seven scope bits | Bit 2 maps to Global Preferences | PASS |
| 27 | seven scope bits | Bit 4 maps to Keychain | PASS |
| 28 | seven display names | Exact display name: Profile App Data | PASS |
| 29 | seven display names | Exact display name: Global Safari | PASS |
| 30 | seven display names | Exact display name: App Groups | PASS |
| 31 | seven display names | Exact display name: System Global | PASS |
| 32 | seven display names | Exact display name: Shared System Databases | PASS |
| 33 | seven display names | Exact display name: Global Preferences | PASS |
| 34 | seven display names | Exact display name: Keychain | PASS |
| 35 | canonical ordering | Canonical position 1: Profile App Data | PASS |
| 36 | canonical ordering | Canonical position 2: Global Safari | PASS |
| 37 | canonical ordering | Canonical position 3: App Groups | PASS |
| 38 | canonical ordering | Canonical position 4: System Global | PASS |
| 39 | canonical ordering | Canonical position 5: Shared System Databases | PASS |
| 40 | canonical ordering | Canonical position 6: Global Preferences | PASS |
| 41 | canonical ordering | Canonical position 7: Keychain | PASS |
| 42 | unknown masks | Mask 128 fails closed | PASS |
| 43 | unknown masks | Mask 129 fails closed | PASS |
| 44 | unknown masks | Mask 255 fails closed | PASS |
| 45 | unknown masks | Mask 256 fails closed | PASS |
| 46 | unknown masks | Mask 1024 fails closed | PASS |
| 47 | unknown masks | Mask -1 fails closed | PASS |
| 48 | unknown masks | Mask -128 fails closed | PASS |
| 49 | eight Backup option combinations | groups=0 preferences=0 keychain=0 -> Confirm Backup / Backup | PASS |
| 50 | eight Backup option combinations | groups=0 preferences=0 keychain=1 -> Confirm Advanced Backup / Back Up Advanced Data | PASS |
| 51 | eight Backup option combinations | groups=0 preferences=1 keychain=0 -> Confirm Advanced Backup / Back Up Advanced Data | PASS |
| 52 | eight Backup option combinations | groups=0 preferences=1 keychain=1 -> Confirm Advanced Backup / Back Up Advanced Data | PASS |
| 53 | eight Backup option combinations | groups=1 preferences=0 keychain=0 -> Confirm Advanced Backup / Back Up Advanced Data | PASS |
| 54 | eight Backup option combinations | groups=1 preferences=0 keychain=1 -> Confirm Advanced Backup / Back Up Advanced Data | PASS |
| 55 | eight Backup option combinations | groups=1 preferences=1 keychain=0 -> Confirm Advanced Backup / Back Up Advanced Data | PASS |
| 56 | eight Backup option combinations | groups=1 preferences=1 keychain=1 -> Confirm Advanced Backup / Back Up Advanced Data | PASS |
| 57 | captured option authority | Captured options 0 equal manager options | PASS |
| 58 | captured option authority | Captured options 4 equal manager options | PASS |
| 59 | captured option authority | Captured options 2 equal manager options | PASS |
| 60 | captured option authority | Captured options 6 equal manager options | PASS |
| 61 | captured option authority | Captured options 1 equal manager options | PASS |
| 62 | captured option authority | Captured options 5 equal manager options | PASS |
| 63 | captured option authority | Captured options 3 equal manager options | PASS |
| 64 | captured option authority | Captured options 7 equal manager options | PASS |
| 65 | Backup cancellation | Cancel data-only Backup causes zero manager and processing calls | PASS |
| 66 | Backup cancellation | Cancel advanced Backup causes zero manager and processing calls | PASS |
| 67 | data-only Backup confirmation | Title Confirm Backup, action Backup, default style | PASS |
| 68 | advanced Backup confirmation | Title Confirm Advanced Backup, action Back Up Advanced Data, default style | PASS |
| 69 | Backup TOCTOU | Switch reads occur exactly once before confirmation | PASS |
| 70 | Backup TOCTOU | Confirmation handler contains zero switch reads | PASS |
| 71 | Backup TOCTOU | Keychain notification cannot change captured option mask | PASS |
| 72 | Backup TOCTOU | A later Backup tap creates a new local snapshot | PASS |
| 73 | exact Boolean parser | Property-list Boolean True accepted | PASS |
| 74 | exact Boolean parser | Property-list Boolean False accepted | PASS |
| 75 | exact Boolean parser | Non-Boolean value 0 rejected | PASS |
| 76 | exact Boolean parser | Non-Boolean value 1 rejected | PASS |
| 77 | exact Boolean parser | Non-Boolean value 'true' rejected | PASS |
| 78 | exact Boolean parser | Non-Boolean value 'false' rejected | PASS |
| 79 | exact Boolean parser | Non-Boolean value 1.0 rejected | PASS |
| 80 | exact Boolean parser | Non-Boolean value None rejected | PASS |
| 81 | exact Boolean parser | Non-Boolean value [] rejected | PASS |
| 82 | exact Boolean parser | Non-Boolean value {} rejected | PASS |
| 83 | versions 2-5 | Validated manifest version 2 supported | PASS |
| 84 | versions 2-5 | Validated manifest version 3 supported | PASS |
| 85 | versions 2-5 | Validated manifest version 4 supported | PASS |
| 86 | versions 2-5 | Validated manifest version 5 supported | PASS |
| 87 | versions 2-5 | Version 2 accepts absent system/shared sections | PASS |
| 88 | versions 2-5 | Version 3 accepts absent system/shared sections | PASS |
| 89 | versions 2-5 | Version 4 reads strict system/shared sections | PASS |
| 90 | versions 2-5 | Version 5 reads strict system/shared sections | PASS |
| 91 | canonical scope-list formatting | Mask 0 emits exact canonical bullet list: [data-only] | PASS |
| 92 | canonical scope-list formatting | Mask 1 emits exact canonical bullet list: - App Groups | PASS |
| 93 | canonical scope-list formatting | Mask 2 emits exact canonical bullet list: - Global Preferences | PASS |
| 94 | canonical scope-list formatting | Mask 3 emits exact canonical bullet list: - App Groups<br>- Global Preferences | PASS |
| 95 | canonical scope-list formatting | Mask 4 emits exact canonical bullet list: - Keychain | PASS |
| 96 | canonical scope-list formatting | Mask 5 emits exact canonical bullet list: - App Groups<br>- Keychain | PASS |
| 97 | canonical scope-list formatting | Mask 6 emits exact canonical bullet list: - Global Preferences<br>- Keychain | PASS |
| 98 | canonical scope-list formatting | Mask 7 emits exact canonical bullet list: - App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 99 | canonical scope-list formatting | Mask 8 emits exact canonical bullet list: - Profile App Data | PASS |
| 100 | canonical scope-list formatting | Mask 9 emits exact canonical bullet list: - Profile App Data<br>- App Groups | PASS |
| 101 | canonical scope-list formatting | Mask 10 emits exact canonical bullet list: - Profile App Data<br>- Global Preferences | PASS |
| 102 | canonical scope-list formatting | Mask 11 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- Global Preferences | PASS |
| 103 | canonical scope-list formatting | Mask 12 emits exact canonical bullet list: - Profile App Data<br>- Keychain | PASS |
| 104 | canonical scope-list formatting | Mask 13 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- Keychain | PASS |
| 105 | canonical scope-list formatting | Mask 14 emits exact canonical bullet list: - Profile App Data<br>- Global Preferences<br>- Keychain | PASS |
| 106 | canonical scope-list formatting | Mask 15 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 107 | canonical scope-list formatting | Mask 16 emits exact canonical bullet list: - Global Safari | PASS |
| 108 | canonical scope-list formatting | Mask 17 emits exact canonical bullet list: - Global Safari<br>- App Groups | PASS |
| 109 | canonical scope-list formatting | Mask 18 emits exact canonical bullet list: - Global Safari<br>- Global Preferences | PASS |
| 110 | canonical scope-list formatting | Mask 19 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 111 | canonical scope-list formatting | Mask 20 emits exact canonical bullet list: - Global Safari<br>- Keychain | PASS |
| 112 | canonical scope-list formatting | Mask 21 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- Keychain | PASS |
| 113 | canonical scope-list formatting | Mask 22 emits exact canonical bullet list: - Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 114 | canonical scope-list formatting | Mask 23 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 115 | canonical scope-list formatting | Mask 24 emits exact canonical bullet list: - Profile App Data<br>- Global Safari | PASS |
| 116 | canonical scope-list formatting | Mask 25 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups | PASS |
| 117 | canonical scope-list formatting | Mask 26 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- Global Preferences | PASS |
| 118 | canonical scope-list formatting | Mask 27 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 119 | canonical scope-list formatting | Mask 28 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- Keychain | PASS |
| 120 | canonical scope-list formatting | Mask 29 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Keychain | PASS |
| 121 | canonical scope-list formatting | Mask 30 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 122 | canonical scope-list formatting | Mask 31 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 123 | canonical scope-list formatting | Mask 32 emits exact canonical bullet list: - System Global | PASS |
| 124 | canonical scope-list formatting | Mask 33 emits exact canonical bullet list: - App Groups<br>- System Global | PASS |
| 125 | canonical scope-list formatting | Mask 34 emits exact canonical bullet list: - System Global<br>- Global Preferences | PASS |
| 126 | canonical scope-list formatting | Mask 35 emits exact canonical bullet list: - App Groups<br>- System Global<br>- Global Preferences | PASS |
| 127 | canonical scope-list formatting | Mask 36 emits exact canonical bullet list: - System Global<br>- Keychain | PASS |
| 128 | canonical scope-list formatting | Mask 37 emits exact canonical bullet list: - App Groups<br>- System Global<br>- Keychain | PASS |
| 129 | canonical scope-list formatting | Mask 38 emits exact canonical bullet list: - System Global<br>- Global Preferences<br>- Keychain | PASS |
| 130 | canonical scope-list formatting | Mask 39 emits exact canonical bullet list: - App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 131 | canonical scope-list formatting | Mask 40 emits exact canonical bullet list: - Profile App Data<br>- System Global | PASS |
| 132 | canonical scope-list formatting | Mask 41 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global | PASS |
| 133 | canonical scope-list formatting | Mask 42 emits exact canonical bullet list: - Profile App Data<br>- System Global<br>- Global Preferences | PASS |
| 134 | canonical scope-list formatting | Mask 43 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 135 | canonical scope-list formatting | Mask 44 emits exact canonical bullet list: - Profile App Data<br>- System Global<br>- Keychain | PASS |
| 136 | canonical scope-list formatting | Mask 45 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 137 | canonical scope-list formatting | Mask 46 emits exact canonical bullet list: - Profile App Data<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 138 | canonical scope-list formatting | Mask 47 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 139 | canonical scope-list formatting | Mask 48 emits exact canonical bullet list: - Global Safari<br>- System Global | PASS |
| 140 | canonical scope-list formatting | Mask 49 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global | PASS |
| 141 | canonical scope-list formatting | Mask 50 emits exact canonical bullet list: - Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 142 | canonical scope-list formatting | Mask 51 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 143 | canonical scope-list formatting | Mask 52 emits exact canonical bullet list: - Global Safari<br>- System Global<br>- Keychain | PASS |
| 144 | canonical scope-list formatting | Mask 53 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 145 | canonical scope-list formatting | Mask 54 emits exact canonical bullet list: - Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 146 | canonical scope-list formatting | Mask 55 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 147 | canonical scope-list formatting | Mask 56 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global | PASS |
| 148 | canonical scope-list formatting | Mask 57 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global | PASS |
| 149 | canonical scope-list formatting | Mask 58 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 150 | canonical scope-list formatting | Mask 59 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 151 | canonical scope-list formatting | Mask 60 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global<br>- Keychain | PASS |
| 152 | canonical scope-list formatting | Mask 61 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 153 | canonical scope-list formatting | Mask 62 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 154 | canonical scope-list formatting | Mask 63 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 155 | canonical scope-list formatting | Mask 64 emits exact canonical bullet list: - Shared System Databases | PASS |
| 156 | canonical scope-list formatting | Mask 65 emits exact canonical bullet list: - App Groups<br>- Shared System Databases | PASS |
| 157 | canonical scope-list formatting | Mask 66 emits exact canonical bullet list: - Shared System Databases<br>- Global Preferences | PASS |
| 158 | canonical scope-list formatting | Mask 67 emits exact canonical bullet list: - App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 159 | canonical scope-list formatting | Mask 68 emits exact canonical bullet list: - Shared System Databases<br>- Keychain | PASS |
| 160 | canonical scope-list formatting | Mask 69 emits exact canonical bullet list: - App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 161 | canonical scope-list formatting | Mask 70 emits exact canonical bullet list: - Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 162 | canonical scope-list formatting | Mask 71 emits exact canonical bullet list: - App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 163 | canonical scope-list formatting | Mask 72 emits exact canonical bullet list: - Profile App Data<br>- Shared System Databases | PASS |
| 164 | canonical scope-list formatting | Mask 73 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- Shared System Databases | PASS |
| 165 | canonical scope-list formatting | Mask 74 emits exact canonical bullet list: - Profile App Data<br>- Shared System Databases<br>- Global Preferences | PASS |
| 166 | canonical scope-list formatting | Mask 75 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 167 | canonical scope-list formatting | Mask 76 emits exact canonical bullet list: - Profile App Data<br>- Shared System Databases<br>- Keychain | PASS |
| 168 | canonical scope-list formatting | Mask 77 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 169 | canonical scope-list formatting | Mask 78 emits exact canonical bullet list: - Profile App Data<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 170 | canonical scope-list formatting | Mask 79 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 171 | canonical scope-list formatting | Mask 80 emits exact canonical bullet list: - Global Safari<br>- Shared System Databases | PASS |
| 172 | canonical scope-list formatting | Mask 81 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 173 | canonical scope-list formatting | Mask 82 emits exact canonical bullet list: - Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 174 | canonical scope-list formatting | Mask 83 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 175 | canonical scope-list formatting | Mask 84 emits exact canonical bullet list: - Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 176 | canonical scope-list formatting | Mask 85 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 177 | canonical scope-list formatting | Mask 86 emits exact canonical bullet list: - Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 178 | canonical scope-list formatting | Mask 87 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 179 | canonical scope-list formatting | Mask 88 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- Shared System Databases | PASS |
| 180 | canonical scope-list formatting | Mask 89 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 181 | canonical scope-list formatting | Mask 90 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 182 | canonical scope-list formatting | Mask 91 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 183 | canonical scope-list formatting | Mask 92 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 184 | canonical scope-list formatting | Mask 93 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 185 | canonical scope-list formatting | Mask 94 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 186 | canonical scope-list formatting | Mask 95 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 187 | canonical scope-list formatting | Mask 96 emits exact canonical bullet list: - System Global<br>- Shared System Databases | PASS |
| 188 | canonical scope-list formatting | Mask 97 emits exact canonical bullet list: - App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 189 | canonical scope-list formatting | Mask 98 emits exact canonical bullet list: - System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 190 | canonical scope-list formatting | Mask 99 emits exact canonical bullet list: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 191 | canonical scope-list formatting | Mask 100 emits exact canonical bullet list: - System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 192 | canonical scope-list formatting | Mask 101 emits exact canonical bullet list: - App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 193 | canonical scope-list formatting | Mask 102 emits exact canonical bullet list: - System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 194 | canonical scope-list formatting | Mask 103 emits exact canonical bullet list: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 195 | canonical scope-list formatting | Mask 104 emits exact canonical bullet list: - Profile App Data<br>- System Global<br>- Shared System Databases | PASS |
| 196 | canonical scope-list formatting | Mask 105 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 197 | canonical scope-list formatting | Mask 106 emits exact canonical bullet list: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 198 | canonical scope-list formatting | Mask 107 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 199 | canonical scope-list formatting | Mask 108 emits exact canonical bullet list: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 200 | canonical scope-list formatting | Mask 109 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 201 | canonical scope-list formatting | Mask 110 emits exact canonical bullet list: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 202 | canonical scope-list formatting | Mask 111 emits exact canonical bullet list: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 203 | canonical scope-list formatting | Mask 112 emits exact canonical bullet list: - Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 204 | canonical scope-list formatting | Mask 113 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 205 | canonical scope-list formatting | Mask 114 emits exact canonical bullet list: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 206 | canonical scope-list formatting | Mask 115 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 207 | canonical scope-list formatting | Mask 116 emits exact canonical bullet list: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 208 | canonical scope-list formatting | Mask 117 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 209 | canonical scope-list formatting | Mask 118 emits exact canonical bullet list: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 210 | canonical scope-list formatting | Mask 119 emits exact canonical bullet list: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 211 | canonical scope-list formatting | Mask 120 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 212 | canonical scope-list formatting | Mask 121 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 213 | canonical scope-list formatting | Mask 122 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 214 | canonical scope-list formatting | Mask 123 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 215 | canonical scope-list formatting | Mask 124 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 216 | canonical scope-list formatting | Mask 125 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 217 | canonical scope-list formatting | Mask 126 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 218 | canonical scope-list formatting | Mask 127 emits exact canonical bullet list: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 219 | 128 Restore combinations across versions | Version 2, mask 0: [data-only] | PASS |
| 220 | 128 Restore combinations across versions | Version 2, mask 1: - App Groups | PASS |
| 221 | 128 Restore combinations across versions | Version 2, mask 2: - Global Preferences | PASS |
| 222 | 128 Restore combinations across versions | Version 2, mask 3: - App Groups<br>- Global Preferences | PASS |
| 223 | 128 Restore combinations across versions | Version 2, mask 4: - Keychain | PASS |
| 224 | 128 Restore combinations across versions | Version 2, mask 5: - App Groups<br>- Keychain | PASS |
| 225 | 128 Restore combinations across versions | Version 2, mask 6: - Global Preferences<br>- Keychain | PASS |
| 226 | 128 Restore combinations across versions | Version 2, mask 7: - App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 227 | 128 Restore combinations across versions | Version 2, mask 8: - Profile App Data | PASS |
| 228 | 128 Restore combinations across versions | Version 2, mask 9: - Profile App Data<br>- App Groups | PASS |
| 229 | 128 Restore combinations across versions | Version 2, mask 10: - Profile App Data<br>- Global Preferences | PASS |
| 230 | 128 Restore combinations across versions | Version 2, mask 11: - Profile App Data<br>- App Groups<br>- Global Preferences | PASS |
| 231 | 128 Restore combinations across versions | Version 2, mask 12: - Profile App Data<br>- Keychain | PASS |
| 232 | 128 Restore combinations across versions | Version 2, mask 13: - Profile App Data<br>- App Groups<br>- Keychain | PASS |
| 233 | 128 Restore combinations across versions | Version 2, mask 14: - Profile App Data<br>- Global Preferences<br>- Keychain | PASS |
| 234 | 128 Restore combinations across versions | Version 2, mask 15: - Profile App Data<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 235 | 128 Restore combinations across versions | Version 2, mask 16: - Global Safari | PASS |
| 236 | 128 Restore combinations across versions | Version 2, mask 17: - Global Safari<br>- App Groups | PASS |
| 237 | 128 Restore combinations across versions | Version 2, mask 18: - Global Safari<br>- Global Preferences | PASS |
| 238 | 128 Restore combinations across versions | Version 2, mask 19: - Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 239 | 128 Restore combinations across versions | Version 2, mask 20: - Global Safari<br>- Keychain | PASS |
| 240 | 128 Restore combinations across versions | Version 2, mask 21: - Global Safari<br>- App Groups<br>- Keychain | PASS |
| 241 | 128 Restore combinations across versions | Version 2, mask 22: - Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 242 | 128 Restore combinations across versions | Version 2, mask 23: - Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 243 | 128 Restore combinations across versions | Version 2, mask 24: - Profile App Data<br>- Global Safari | PASS |
| 244 | 128 Restore combinations across versions | Version 2, mask 25: - Profile App Data<br>- Global Safari<br>- App Groups | PASS |
| 245 | 128 Restore combinations across versions | Version 2, mask 26: - Profile App Data<br>- Global Safari<br>- Global Preferences | PASS |
| 246 | 128 Restore combinations across versions | Version 2, mask 27: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 247 | 128 Restore combinations across versions | Version 2, mask 28: - Profile App Data<br>- Global Safari<br>- Keychain | PASS |
| 248 | 128 Restore combinations across versions | Version 2, mask 29: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Keychain | PASS |
| 249 | 128 Restore combinations across versions | Version 2, mask 30: - Profile App Data<br>- Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 250 | 128 Restore combinations across versions | Version 2, mask 31: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 251 | 128 Restore combinations across versions | Version 2, mask 32: - System Global | PASS |
| 252 | 128 Restore combinations across versions | Version 2, mask 33: - App Groups<br>- System Global | PASS |
| 253 | 128 Restore combinations across versions | Version 2, mask 34: - System Global<br>- Global Preferences | PASS |
| 254 | 128 Restore combinations across versions | Version 2, mask 35: - App Groups<br>- System Global<br>- Global Preferences | PASS |
| 255 | 128 Restore combinations across versions | Version 2, mask 36: - System Global<br>- Keychain | PASS |
| 256 | 128 Restore combinations across versions | Version 2, mask 37: - App Groups<br>- System Global<br>- Keychain | PASS |
| 257 | 128 Restore combinations across versions | Version 2, mask 38: - System Global<br>- Global Preferences<br>- Keychain | PASS |
| 258 | 128 Restore combinations across versions | Version 2, mask 39: - App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 259 | 128 Restore combinations across versions | Version 2, mask 40: - Profile App Data<br>- System Global | PASS |
| 260 | 128 Restore combinations across versions | Version 2, mask 41: - Profile App Data<br>- App Groups<br>- System Global | PASS |
| 261 | 128 Restore combinations across versions | Version 2, mask 42: - Profile App Data<br>- System Global<br>- Global Preferences | PASS |
| 262 | 128 Restore combinations across versions | Version 2, mask 43: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 263 | 128 Restore combinations across versions | Version 2, mask 44: - Profile App Data<br>- System Global<br>- Keychain | PASS |
| 264 | 128 Restore combinations across versions | Version 2, mask 45: - Profile App Data<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 265 | 128 Restore combinations across versions | Version 2, mask 46: - Profile App Data<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 266 | 128 Restore combinations across versions | Version 2, mask 47: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 267 | 128 Restore combinations across versions | Version 2, mask 48: - Global Safari<br>- System Global | PASS |
| 268 | 128 Restore combinations across versions | Version 2, mask 49: - Global Safari<br>- App Groups<br>- System Global | PASS |
| 269 | 128 Restore combinations across versions | Version 2, mask 50: - Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 270 | 128 Restore combinations across versions | Version 2, mask 51: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 271 | 128 Restore combinations across versions | Version 2, mask 52: - Global Safari<br>- System Global<br>- Keychain | PASS |
| 272 | 128 Restore combinations across versions | Version 2, mask 53: - Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 273 | 128 Restore combinations across versions | Version 2, mask 54: - Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 274 | 128 Restore combinations across versions | Version 2, mask 55: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 275 | 128 Restore combinations across versions | Version 2, mask 56: - Profile App Data<br>- Global Safari<br>- System Global | PASS |
| 276 | 128 Restore combinations across versions | Version 2, mask 57: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global | PASS |
| 277 | 128 Restore combinations across versions | Version 2, mask 58: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 278 | 128 Restore combinations across versions | Version 2, mask 59: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 279 | 128 Restore combinations across versions | Version 2, mask 60: - Profile App Data<br>- Global Safari<br>- System Global<br>- Keychain | PASS |
| 280 | 128 Restore combinations across versions | Version 2, mask 61: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 281 | 128 Restore combinations across versions | Version 2, mask 62: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 282 | 128 Restore combinations across versions | Version 2, mask 63: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 283 | 128 Restore combinations across versions | Version 2, mask 64: - Shared System Databases | PASS |
| 284 | 128 Restore combinations across versions | Version 2, mask 65: - App Groups<br>- Shared System Databases | PASS |
| 285 | 128 Restore combinations across versions | Version 2, mask 66: - Shared System Databases<br>- Global Preferences | PASS |
| 286 | 128 Restore combinations across versions | Version 2, mask 67: - App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 287 | 128 Restore combinations across versions | Version 2, mask 68: - Shared System Databases<br>- Keychain | PASS |
| 288 | 128 Restore combinations across versions | Version 2, mask 69: - App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 289 | 128 Restore combinations across versions | Version 2, mask 70: - Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 290 | 128 Restore combinations across versions | Version 2, mask 71: - App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 291 | 128 Restore combinations across versions | Version 2, mask 72: - Profile App Data<br>- Shared System Databases | PASS |
| 292 | 128 Restore combinations across versions | Version 2, mask 73: - Profile App Data<br>- App Groups<br>- Shared System Databases | PASS |
| 293 | 128 Restore combinations across versions | Version 2, mask 74: - Profile App Data<br>- Shared System Databases<br>- Global Preferences | PASS |
| 294 | 128 Restore combinations across versions | Version 2, mask 75: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 295 | 128 Restore combinations across versions | Version 2, mask 76: - Profile App Data<br>- Shared System Databases<br>- Keychain | PASS |
| 296 | 128 Restore combinations across versions | Version 2, mask 77: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 297 | 128 Restore combinations across versions | Version 2, mask 78: - Profile App Data<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 298 | 128 Restore combinations across versions | Version 2, mask 79: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 299 | 128 Restore combinations across versions | Version 2, mask 80: - Global Safari<br>- Shared System Databases | PASS |
| 300 | 128 Restore combinations across versions | Version 2, mask 81: - Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 301 | 128 Restore combinations across versions | Version 2, mask 82: - Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 302 | 128 Restore combinations across versions | Version 2, mask 83: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 303 | 128 Restore combinations across versions | Version 2, mask 84: - Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 304 | 128 Restore combinations across versions | Version 2, mask 85: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 305 | 128 Restore combinations across versions | Version 2, mask 86: - Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 306 | 128 Restore combinations across versions | Version 2, mask 87: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 307 | 128 Restore combinations across versions | Version 2, mask 88: - Profile App Data<br>- Global Safari<br>- Shared System Databases | PASS |
| 308 | 128 Restore combinations across versions | Version 2, mask 89: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 309 | 128 Restore combinations across versions | Version 2, mask 90: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 310 | 128 Restore combinations across versions | Version 2, mask 91: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 311 | 128 Restore combinations across versions | Version 2, mask 92: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 312 | 128 Restore combinations across versions | Version 2, mask 93: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 313 | 128 Restore combinations across versions | Version 2, mask 94: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 314 | 128 Restore combinations across versions | Version 2, mask 95: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 315 | 128 Restore combinations across versions | Version 2, mask 96: - System Global<br>- Shared System Databases | PASS |
| 316 | 128 Restore combinations across versions | Version 2, mask 97: - App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 317 | 128 Restore combinations across versions | Version 2, mask 98: - System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 318 | 128 Restore combinations across versions | Version 2, mask 99: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 319 | 128 Restore combinations across versions | Version 2, mask 100: - System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 320 | 128 Restore combinations across versions | Version 2, mask 101: - App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 321 | 128 Restore combinations across versions | Version 2, mask 102: - System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 322 | 128 Restore combinations across versions | Version 2, mask 103: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 323 | 128 Restore combinations across versions | Version 2, mask 104: - Profile App Data<br>- System Global<br>- Shared System Databases | PASS |
| 324 | 128 Restore combinations across versions | Version 2, mask 105: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 325 | 128 Restore combinations across versions | Version 2, mask 106: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 326 | 128 Restore combinations across versions | Version 2, mask 107: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 327 | 128 Restore combinations across versions | Version 2, mask 108: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 328 | 128 Restore combinations across versions | Version 2, mask 109: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 329 | 128 Restore combinations across versions | Version 2, mask 110: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 330 | 128 Restore combinations across versions | Version 2, mask 111: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 331 | 128 Restore combinations across versions | Version 2, mask 112: - Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 332 | 128 Restore combinations across versions | Version 2, mask 113: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 333 | 128 Restore combinations across versions | Version 2, mask 114: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 334 | 128 Restore combinations across versions | Version 2, mask 115: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 335 | 128 Restore combinations across versions | Version 2, mask 116: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 336 | 128 Restore combinations across versions | Version 2, mask 117: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 337 | 128 Restore combinations across versions | Version 2, mask 118: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 338 | 128 Restore combinations across versions | Version 2, mask 119: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 339 | 128 Restore combinations across versions | Version 2, mask 120: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 340 | 128 Restore combinations across versions | Version 2, mask 121: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 341 | 128 Restore combinations across versions | Version 2, mask 122: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 342 | 128 Restore combinations across versions | Version 2, mask 123: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 343 | 128 Restore combinations across versions | Version 2, mask 124: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 344 | 128 Restore combinations across versions | Version 2, mask 125: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 345 | 128 Restore combinations across versions | Version 2, mask 126: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 346 | 128 Restore combinations across versions | Version 2, mask 127: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 347 | 128 Restore combinations across versions | Version 3, mask 0: [data-only] | PASS |
| 348 | 128 Restore combinations across versions | Version 3, mask 1: - App Groups | PASS |
| 349 | 128 Restore combinations across versions | Version 3, mask 2: - Global Preferences | PASS |
| 350 | 128 Restore combinations across versions | Version 3, mask 3: - App Groups<br>- Global Preferences | PASS |
| 351 | 128 Restore combinations across versions | Version 3, mask 4: - Keychain | PASS |
| 352 | 128 Restore combinations across versions | Version 3, mask 5: - App Groups<br>- Keychain | PASS |
| 353 | 128 Restore combinations across versions | Version 3, mask 6: - Global Preferences<br>- Keychain | PASS |
| 354 | 128 Restore combinations across versions | Version 3, mask 7: - App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 355 | 128 Restore combinations across versions | Version 3, mask 8: - Profile App Data | PASS |
| 356 | 128 Restore combinations across versions | Version 3, mask 9: - Profile App Data<br>- App Groups | PASS |
| 357 | 128 Restore combinations across versions | Version 3, mask 10: - Profile App Data<br>- Global Preferences | PASS |
| 358 | 128 Restore combinations across versions | Version 3, mask 11: - Profile App Data<br>- App Groups<br>- Global Preferences | PASS |
| 359 | 128 Restore combinations across versions | Version 3, mask 12: - Profile App Data<br>- Keychain | PASS |
| 360 | 128 Restore combinations across versions | Version 3, mask 13: - Profile App Data<br>- App Groups<br>- Keychain | PASS |
| 361 | 128 Restore combinations across versions | Version 3, mask 14: - Profile App Data<br>- Global Preferences<br>- Keychain | PASS |
| 362 | 128 Restore combinations across versions | Version 3, mask 15: - Profile App Data<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 363 | 128 Restore combinations across versions | Version 3, mask 16: - Global Safari | PASS |
| 364 | 128 Restore combinations across versions | Version 3, mask 17: - Global Safari<br>- App Groups | PASS |
| 365 | 128 Restore combinations across versions | Version 3, mask 18: - Global Safari<br>- Global Preferences | PASS |
| 366 | 128 Restore combinations across versions | Version 3, mask 19: - Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 367 | 128 Restore combinations across versions | Version 3, mask 20: - Global Safari<br>- Keychain | PASS |
| 368 | 128 Restore combinations across versions | Version 3, mask 21: - Global Safari<br>- App Groups<br>- Keychain | PASS |
| 369 | 128 Restore combinations across versions | Version 3, mask 22: - Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 370 | 128 Restore combinations across versions | Version 3, mask 23: - Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 371 | 128 Restore combinations across versions | Version 3, mask 24: - Profile App Data<br>- Global Safari | PASS |
| 372 | 128 Restore combinations across versions | Version 3, mask 25: - Profile App Data<br>- Global Safari<br>- App Groups | PASS |
| 373 | 128 Restore combinations across versions | Version 3, mask 26: - Profile App Data<br>- Global Safari<br>- Global Preferences | PASS |
| 374 | 128 Restore combinations across versions | Version 3, mask 27: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 375 | 128 Restore combinations across versions | Version 3, mask 28: - Profile App Data<br>- Global Safari<br>- Keychain | PASS |
| 376 | 128 Restore combinations across versions | Version 3, mask 29: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Keychain | PASS |
| 377 | 128 Restore combinations across versions | Version 3, mask 30: - Profile App Data<br>- Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 378 | 128 Restore combinations across versions | Version 3, mask 31: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 379 | 128 Restore combinations across versions | Version 3, mask 32: - System Global | PASS |
| 380 | 128 Restore combinations across versions | Version 3, mask 33: - App Groups<br>- System Global | PASS |
| 381 | 128 Restore combinations across versions | Version 3, mask 34: - System Global<br>- Global Preferences | PASS |
| 382 | 128 Restore combinations across versions | Version 3, mask 35: - App Groups<br>- System Global<br>- Global Preferences | PASS |
| 383 | 128 Restore combinations across versions | Version 3, mask 36: - System Global<br>- Keychain | PASS |
| 384 | 128 Restore combinations across versions | Version 3, mask 37: - App Groups<br>- System Global<br>- Keychain | PASS |
| 385 | 128 Restore combinations across versions | Version 3, mask 38: - System Global<br>- Global Preferences<br>- Keychain | PASS |
| 386 | 128 Restore combinations across versions | Version 3, mask 39: - App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 387 | 128 Restore combinations across versions | Version 3, mask 40: - Profile App Data<br>- System Global | PASS |
| 388 | 128 Restore combinations across versions | Version 3, mask 41: - Profile App Data<br>- App Groups<br>- System Global | PASS |
| 389 | 128 Restore combinations across versions | Version 3, mask 42: - Profile App Data<br>- System Global<br>- Global Preferences | PASS |
| 390 | 128 Restore combinations across versions | Version 3, mask 43: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 391 | 128 Restore combinations across versions | Version 3, mask 44: - Profile App Data<br>- System Global<br>- Keychain | PASS |
| 392 | 128 Restore combinations across versions | Version 3, mask 45: - Profile App Data<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 393 | 128 Restore combinations across versions | Version 3, mask 46: - Profile App Data<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 394 | 128 Restore combinations across versions | Version 3, mask 47: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 395 | 128 Restore combinations across versions | Version 3, mask 48: - Global Safari<br>- System Global | PASS |
| 396 | 128 Restore combinations across versions | Version 3, mask 49: - Global Safari<br>- App Groups<br>- System Global | PASS |
| 397 | 128 Restore combinations across versions | Version 3, mask 50: - Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 398 | 128 Restore combinations across versions | Version 3, mask 51: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 399 | 128 Restore combinations across versions | Version 3, mask 52: - Global Safari<br>- System Global<br>- Keychain | PASS |
| 400 | 128 Restore combinations across versions | Version 3, mask 53: - Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 401 | 128 Restore combinations across versions | Version 3, mask 54: - Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 402 | 128 Restore combinations across versions | Version 3, mask 55: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 403 | 128 Restore combinations across versions | Version 3, mask 56: - Profile App Data<br>- Global Safari<br>- System Global | PASS |
| 404 | 128 Restore combinations across versions | Version 3, mask 57: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global | PASS |
| 405 | 128 Restore combinations across versions | Version 3, mask 58: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 406 | 128 Restore combinations across versions | Version 3, mask 59: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 407 | 128 Restore combinations across versions | Version 3, mask 60: - Profile App Data<br>- Global Safari<br>- System Global<br>- Keychain | PASS |
| 408 | 128 Restore combinations across versions | Version 3, mask 61: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 409 | 128 Restore combinations across versions | Version 3, mask 62: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 410 | 128 Restore combinations across versions | Version 3, mask 63: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 411 | 128 Restore combinations across versions | Version 3, mask 64: - Shared System Databases | PASS |
| 412 | 128 Restore combinations across versions | Version 3, mask 65: - App Groups<br>- Shared System Databases | PASS |
| 413 | 128 Restore combinations across versions | Version 3, mask 66: - Shared System Databases<br>- Global Preferences | PASS |
| 414 | 128 Restore combinations across versions | Version 3, mask 67: - App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 415 | 128 Restore combinations across versions | Version 3, mask 68: - Shared System Databases<br>- Keychain | PASS |
| 416 | 128 Restore combinations across versions | Version 3, mask 69: - App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 417 | 128 Restore combinations across versions | Version 3, mask 70: - Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 418 | 128 Restore combinations across versions | Version 3, mask 71: - App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 419 | 128 Restore combinations across versions | Version 3, mask 72: - Profile App Data<br>- Shared System Databases | PASS |
| 420 | 128 Restore combinations across versions | Version 3, mask 73: - Profile App Data<br>- App Groups<br>- Shared System Databases | PASS |
| 421 | 128 Restore combinations across versions | Version 3, mask 74: - Profile App Data<br>- Shared System Databases<br>- Global Preferences | PASS |
| 422 | 128 Restore combinations across versions | Version 3, mask 75: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 423 | 128 Restore combinations across versions | Version 3, mask 76: - Profile App Data<br>- Shared System Databases<br>- Keychain | PASS |
| 424 | 128 Restore combinations across versions | Version 3, mask 77: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 425 | 128 Restore combinations across versions | Version 3, mask 78: - Profile App Data<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 426 | 128 Restore combinations across versions | Version 3, mask 79: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 427 | 128 Restore combinations across versions | Version 3, mask 80: - Global Safari<br>- Shared System Databases | PASS |
| 428 | 128 Restore combinations across versions | Version 3, mask 81: - Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 429 | 128 Restore combinations across versions | Version 3, mask 82: - Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 430 | 128 Restore combinations across versions | Version 3, mask 83: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 431 | 128 Restore combinations across versions | Version 3, mask 84: - Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 432 | 128 Restore combinations across versions | Version 3, mask 85: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 433 | 128 Restore combinations across versions | Version 3, mask 86: - Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 434 | 128 Restore combinations across versions | Version 3, mask 87: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 435 | 128 Restore combinations across versions | Version 3, mask 88: - Profile App Data<br>- Global Safari<br>- Shared System Databases | PASS |
| 436 | 128 Restore combinations across versions | Version 3, mask 89: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 437 | 128 Restore combinations across versions | Version 3, mask 90: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 438 | 128 Restore combinations across versions | Version 3, mask 91: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 439 | 128 Restore combinations across versions | Version 3, mask 92: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 440 | 128 Restore combinations across versions | Version 3, mask 93: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 441 | 128 Restore combinations across versions | Version 3, mask 94: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 442 | 128 Restore combinations across versions | Version 3, mask 95: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 443 | 128 Restore combinations across versions | Version 3, mask 96: - System Global<br>- Shared System Databases | PASS |
| 444 | 128 Restore combinations across versions | Version 3, mask 97: - App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 445 | 128 Restore combinations across versions | Version 3, mask 98: - System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 446 | 128 Restore combinations across versions | Version 3, mask 99: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 447 | 128 Restore combinations across versions | Version 3, mask 100: - System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 448 | 128 Restore combinations across versions | Version 3, mask 101: - App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 449 | 128 Restore combinations across versions | Version 3, mask 102: - System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 450 | 128 Restore combinations across versions | Version 3, mask 103: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 451 | 128 Restore combinations across versions | Version 3, mask 104: - Profile App Data<br>- System Global<br>- Shared System Databases | PASS |
| 452 | 128 Restore combinations across versions | Version 3, mask 105: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 453 | 128 Restore combinations across versions | Version 3, mask 106: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 454 | 128 Restore combinations across versions | Version 3, mask 107: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 455 | 128 Restore combinations across versions | Version 3, mask 108: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 456 | 128 Restore combinations across versions | Version 3, mask 109: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 457 | 128 Restore combinations across versions | Version 3, mask 110: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 458 | 128 Restore combinations across versions | Version 3, mask 111: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 459 | 128 Restore combinations across versions | Version 3, mask 112: - Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 460 | 128 Restore combinations across versions | Version 3, mask 113: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 461 | 128 Restore combinations across versions | Version 3, mask 114: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 462 | 128 Restore combinations across versions | Version 3, mask 115: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 463 | 128 Restore combinations across versions | Version 3, mask 116: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 464 | 128 Restore combinations across versions | Version 3, mask 117: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 465 | 128 Restore combinations across versions | Version 3, mask 118: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 466 | 128 Restore combinations across versions | Version 3, mask 119: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 467 | 128 Restore combinations across versions | Version 3, mask 120: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 468 | 128 Restore combinations across versions | Version 3, mask 121: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 469 | 128 Restore combinations across versions | Version 3, mask 122: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 470 | 128 Restore combinations across versions | Version 3, mask 123: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 471 | 128 Restore combinations across versions | Version 3, mask 124: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 472 | 128 Restore combinations across versions | Version 3, mask 125: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 473 | 128 Restore combinations across versions | Version 3, mask 126: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 474 | 128 Restore combinations across versions | Version 3, mask 127: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 475 | 128 Restore combinations across versions | Version 4, mask 0: [data-only] | PASS |
| 476 | 128 Restore combinations across versions | Version 4, mask 1: - App Groups | PASS |
| 477 | 128 Restore combinations across versions | Version 4, mask 2: - Global Preferences | PASS |
| 478 | 128 Restore combinations across versions | Version 4, mask 3: - App Groups<br>- Global Preferences | PASS |
| 479 | 128 Restore combinations across versions | Version 4, mask 4: - Keychain | PASS |
| 480 | 128 Restore combinations across versions | Version 4, mask 5: - App Groups<br>- Keychain | PASS |
| 481 | 128 Restore combinations across versions | Version 4, mask 6: - Global Preferences<br>- Keychain | PASS |
| 482 | 128 Restore combinations across versions | Version 4, mask 7: - App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 483 | 128 Restore combinations across versions | Version 4, mask 8: - Profile App Data | PASS |
| 484 | 128 Restore combinations across versions | Version 4, mask 9: - Profile App Data<br>- App Groups | PASS |
| 485 | 128 Restore combinations across versions | Version 4, mask 10: - Profile App Data<br>- Global Preferences | PASS |
| 486 | 128 Restore combinations across versions | Version 4, mask 11: - Profile App Data<br>- App Groups<br>- Global Preferences | PASS |
| 487 | 128 Restore combinations across versions | Version 4, mask 12: - Profile App Data<br>- Keychain | PASS |
| 488 | 128 Restore combinations across versions | Version 4, mask 13: - Profile App Data<br>- App Groups<br>- Keychain | PASS |
| 489 | 128 Restore combinations across versions | Version 4, mask 14: - Profile App Data<br>- Global Preferences<br>- Keychain | PASS |
| 490 | 128 Restore combinations across versions | Version 4, mask 15: - Profile App Data<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 491 | 128 Restore combinations across versions | Version 4, mask 16: - Global Safari | PASS |
| 492 | 128 Restore combinations across versions | Version 4, mask 17: - Global Safari<br>- App Groups | PASS |
| 493 | 128 Restore combinations across versions | Version 4, mask 18: - Global Safari<br>- Global Preferences | PASS |
| 494 | 128 Restore combinations across versions | Version 4, mask 19: - Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 495 | 128 Restore combinations across versions | Version 4, mask 20: - Global Safari<br>- Keychain | PASS |
| 496 | 128 Restore combinations across versions | Version 4, mask 21: - Global Safari<br>- App Groups<br>- Keychain | PASS |
| 497 | 128 Restore combinations across versions | Version 4, mask 22: - Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 498 | 128 Restore combinations across versions | Version 4, mask 23: - Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 499 | 128 Restore combinations across versions | Version 4, mask 24: - Profile App Data<br>- Global Safari | PASS |
| 500 | 128 Restore combinations across versions | Version 4, mask 25: - Profile App Data<br>- Global Safari<br>- App Groups | PASS |
| 501 | 128 Restore combinations across versions | Version 4, mask 26: - Profile App Data<br>- Global Safari<br>- Global Preferences | PASS |
| 502 | 128 Restore combinations across versions | Version 4, mask 27: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 503 | 128 Restore combinations across versions | Version 4, mask 28: - Profile App Data<br>- Global Safari<br>- Keychain | PASS |
| 504 | 128 Restore combinations across versions | Version 4, mask 29: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Keychain | PASS |
| 505 | 128 Restore combinations across versions | Version 4, mask 30: - Profile App Data<br>- Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 506 | 128 Restore combinations across versions | Version 4, mask 31: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 507 | 128 Restore combinations across versions | Version 4, mask 32: - System Global | PASS |
| 508 | 128 Restore combinations across versions | Version 4, mask 33: - App Groups<br>- System Global | PASS |
| 509 | 128 Restore combinations across versions | Version 4, mask 34: - System Global<br>- Global Preferences | PASS |
| 510 | 128 Restore combinations across versions | Version 4, mask 35: - App Groups<br>- System Global<br>- Global Preferences | PASS |
| 511 | 128 Restore combinations across versions | Version 4, mask 36: - System Global<br>- Keychain | PASS |
| 512 | 128 Restore combinations across versions | Version 4, mask 37: - App Groups<br>- System Global<br>- Keychain | PASS |
| 513 | 128 Restore combinations across versions | Version 4, mask 38: - System Global<br>- Global Preferences<br>- Keychain | PASS |
| 514 | 128 Restore combinations across versions | Version 4, mask 39: - App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 515 | 128 Restore combinations across versions | Version 4, mask 40: - Profile App Data<br>- System Global | PASS |
| 516 | 128 Restore combinations across versions | Version 4, mask 41: - Profile App Data<br>- App Groups<br>- System Global | PASS |
| 517 | 128 Restore combinations across versions | Version 4, mask 42: - Profile App Data<br>- System Global<br>- Global Preferences | PASS |
| 518 | 128 Restore combinations across versions | Version 4, mask 43: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 519 | 128 Restore combinations across versions | Version 4, mask 44: - Profile App Data<br>- System Global<br>- Keychain | PASS |
| 520 | 128 Restore combinations across versions | Version 4, mask 45: - Profile App Data<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 521 | 128 Restore combinations across versions | Version 4, mask 46: - Profile App Data<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 522 | 128 Restore combinations across versions | Version 4, mask 47: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 523 | 128 Restore combinations across versions | Version 4, mask 48: - Global Safari<br>- System Global | PASS |
| 524 | 128 Restore combinations across versions | Version 4, mask 49: - Global Safari<br>- App Groups<br>- System Global | PASS |
| 525 | 128 Restore combinations across versions | Version 4, mask 50: - Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 526 | 128 Restore combinations across versions | Version 4, mask 51: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 527 | 128 Restore combinations across versions | Version 4, mask 52: - Global Safari<br>- System Global<br>- Keychain | PASS |
| 528 | 128 Restore combinations across versions | Version 4, mask 53: - Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 529 | 128 Restore combinations across versions | Version 4, mask 54: - Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 530 | 128 Restore combinations across versions | Version 4, mask 55: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 531 | 128 Restore combinations across versions | Version 4, mask 56: - Profile App Data<br>- Global Safari<br>- System Global | PASS |
| 532 | 128 Restore combinations across versions | Version 4, mask 57: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global | PASS |
| 533 | 128 Restore combinations across versions | Version 4, mask 58: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 534 | 128 Restore combinations across versions | Version 4, mask 59: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 535 | 128 Restore combinations across versions | Version 4, mask 60: - Profile App Data<br>- Global Safari<br>- System Global<br>- Keychain | PASS |
| 536 | 128 Restore combinations across versions | Version 4, mask 61: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 537 | 128 Restore combinations across versions | Version 4, mask 62: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 538 | 128 Restore combinations across versions | Version 4, mask 63: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 539 | 128 Restore combinations across versions | Version 4, mask 64: - Shared System Databases | PASS |
| 540 | 128 Restore combinations across versions | Version 4, mask 65: - App Groups<br>- Shared System Databases | PASS |
| 541 | 128 Restore combinations across versions | Version 4, mask 66: - Shared System Databases<br>- Global Preferences | PASS |
| 542 | 128 Restore combinations across versions | Version 4, mask 67: - App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 543 | 128 Restore combinations across versions | Version 4, mask 68: - Shared System Databases<br>- Keychain | PASS |
| 544 | 128 Restore combinations across versions | Version 4, mask 69: - App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 545 | 128 Restore combinations across versions | Version 4, mask 70: - Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 546 | 128 Restore combinations across versions | Version 4, mask 71: - App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 547 | 128 Restore combinations across versions | Version 4, mask 72: - Profile App Data<br>- Shared System Databases | PASS |
| 548 | 128 Restore combinations across versions | Version 4, mask 73: - Profile App Data<br>- App Groups<br>- Shared System Databases | PASS |
| 549 | 128 Restore combinations across versions | Version 4, mask 74: - Profile App Data<br>- Shared System Databases<br>- Global Preferences | PASS |
| 550 | 128 Restore combinations across versions | Version 4, mask 75: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 551 | 128 Restore combinations across versions | Version 4, mask 76: - Profile App Data<br>- Shared System Databases<br>- Keychain | PASS |
| 552 | 128 Restore combinations across versions | Version 4, mask 77: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 553 | 128 Restore combinations across versions | Version 4, mask 78: - Profile App Data<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 554 | 128 Restore combinations across versions | Version 4, mask 79: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 555 | 128 Restore combinations across versions | Version 4, mask 80: - Global Safari<br>- Shared System Databases | PASS |
| 556 | 128 Restore combinations across versions | Version 4, mask 81: - Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 557 | 128 Restore combinations across versions | Version 4, mask 82: - Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 558 | 128 Restore combinations across versions | Version 4, mask 83: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 559 | 128 Restore combinations across versions | Version 4, mask 84: - Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 560 | 128 Restore combinations across versions | Version 4, mask 85: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 561 | 128 Restore combinations across versions | Version 4, mask 86: - Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 562 | 128 Restore combinations across versions | Version 4, mask 87: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 563 | 128 Restore combinations across versions | Version 4, mask 88: - Profile App Data<br>- Global Safari<br>- Shared System Databases | PASS |
| 564 | 128 Restore combinations across versions | Version 4, mask 89: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 565 | 128 Restore combinations across versions | Version 4, mask 90: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 566 | 128 Restore combinations across versions | Version 4, mask 91: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 567 | 128 Restore combinations across versions | Version 4, mask 92: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 568 | 128 Restore combinations across versions | Version 4, mask 93: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 569 | 128 Restore combinations across versions | Version 4, mask 94: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 570 | 128 Restore combinations across versions | Version 4, mask 95: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 571 | 128 Restore combinations across versions | Version 4, mask 96: - System Global<br>- Shared System Databases | PASS |
| 572 | 128 Restore combinations across versions | Version 4, mask 97: - App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 573 | 128 Restore combinations across versions | Version 4, mask 98: - System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 574 | 128 Restore combinations across versions | Version 4, mask 99: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 575 | 128 Restore combinations across versions | Version 4, mask 100: - System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 576 | 128 Restore combinations across versions | Version 4, mask 101: - App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 577 | 128 Restore combinations across versions | Version 4, mask 102: - System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 578 | 128 Restore combinations across versions | Version 4, mask 103: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 579 | 128 Restore combinations across versions | Version 4, mask 104: - Profile App Data<br>- System Global<br>- Shared System Databases | PASS |
| 580 | 128 Restore combinations across versions | Version 4, mask 105: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 581 | 128 Restore combinations across versions | Version 4, mask 106: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 582 | 128 Restore combinations across versions | Version 4, mask 107: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 583 | 128 Restore combinations across versions | Version 4, mask 108: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 584 | 128 Restore combinations across versions | Version 4, mask 109: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 585 | 128 Restore combinations across versions | Version 4, mask 110: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 586 | 128 Restore combinations across versions | Version 4, mask 111: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 587 | 128 Restore combinations across versions | Version 4, mask 112: - Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 588 | 128 Restore combinations across versions | Version 4, mask 113: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 589 | 128 Restore combinations across versions | Version 4, mask 114: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 590 | 128 Restore combinations across versions | Version 4, mask 115: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 591 | 128 Restore combinations across versions | Version 4, mask 116: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 592 | 128 Restore combinations across versions | Version 4, mask 117: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 593 | 128 Restore combinations across versions | Version 4, mask 118: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 594 | 128 Restore combinations across versions | Version 4, mask 119: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 595 | 128 Restore combinations across versions | Version 4, mask 120: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 596 | 128 Restore combinations across versions | Version 4, mask 121: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 597 | 128 Restore combinations across versions | Version 4, mask 122: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 598 | 128 Restore combinations across versions | Version 4, mask 123: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 599 | 128 Restore combinations across versions | Version 4, mask 124: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 600 | 128 Restore combinations across versions | Version 4, mask 125: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 601 | 128 Restore combinations across versions | Version 4, mask 126: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 602 | 128 Restore combinations across versions | Version 4, mask 127: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 603 | 128 Restore combinations across versions | Version 5, mask 0: [data-only] | PASS |
| 604 | 128 Restore combinations across versions | Version 5, mask 1: - App Groups | PASS |
| 605 | 128 Restore combinations across versions | Version 5, mask 2: - Global Preferences | PASS |
| 606 | 128 Restore combinations across versions | Version 5, mask 3: - App Groups<br>- Global Preferences | PASS |
| 607 | 128 Restore combinations across versions | Version 5, mask 4: - Keychain | PASS |
| 608 | 128 Restore combinations across versions | Version 5, mask 5: - App Groups<br>- Keychain | PASS |
| 609 | 128 Restore combinations across versions | Version 5, mask 6: - Global Preferences<br>- Keychain | PASS |
| 610 | 128 Restore combinations across versions | Version 5, mask 7: - App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 611 | 128 Restore combinations across versions | Version 5, mask 8: - Profile App Data | PASS |
| 612 | 128 Restore combinations across versions | Version 5, mask 9: - Profile App Data<br>- App Groups | PASS |
| 613 | 128 Restore combinations across versions | Version 5, mask 10: - Profile App Data<br>- Global Preferences | PASS |
| 614 | 128 Restore combinations across versions | Version 5, mask 11: - Profile App Data<br>- App Groups<br>- Global Preferences | PASS |
| 615 | 128 Restore combinations across versions | Version 5, mask 12: - Profile App Data<br>- Keychain | PASS |
| 616 | 128 Restore combinations across versions | Version 5, mask 13: - Profile App Data<br>- App Groups<br>- Keychain | PASS |
| 617 | 128 Restore combinations across versions | Version 5, mask 14: - Profile App Data<br>- Global Preferences<br>- Keychain | PASS |
| 618 | 128 Restore combinations across versions | Version 5, mask 15: - Profile App Data<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 619 | 128 Restore combinations across versions | Version 5, mask 16: - Global Safari | PASS |
| 620 | 128 Restore combinations across versions | Version 5, mask 17: - Global Safari<br>- App Groups | PASS |
| 621 | 128 Restore combinations across versions | Version 5, mask 18: - Global Safari<br>- Global Preferences | PASS |
| 622 | 128 Restore combinations across versions | Version 5, mask 19: - Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 623 | 128 Restore combinations across versions | Version 5, mask 20: - Global Safari<br>- Keychain | PASS |
| 624 | 128 Restore combinations across versions | Version 5, mask 21: - Global Safari<br>- App Groups<br>- Keychain | PASS |
| 625 | 128 Restore combinations across versions | Version 5, mask 22: - Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 626 | 128 Restore combinations across versions | Version 5, mask 23: - Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 627 | 128 Restore combinations across versions | Version 5, mask 24: - Profile App Data<br>- Global Safari | PASS |
| 628 | 128 Restore combinations across versions | Version 5, mask 25: - Profile App Data<br>- Global Safari<br>- App Groups | PASS |
| 629 | 128 Restore combinations across versions | Version 5, mask 26: - Profile App Data<br>- Global Safari<br>- Global Preferences | PASS |
| 630 | 128 Restore combinations across versions | Version 5, mask 27: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences | PASS |
| 631 | 128 Restore combinations across versions | Version 5, mask 28: - Profile App Data<br>- Global Safari<br>- Keychain | PASS |
| 632 | 128 Restore combinations across versions | Version 5, mask 29: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Keychain | PASS |
| 633 | 128 Restore combinations across versions | Version 5, mask 30: - Profile App Data<br>- Global Safari<br>- Global Preferences<br>- Keychain | PASS |
| 634 | 128 Restore combinations across versions | Version 5, mask 31: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Global Preferences<br>- Keychain | PASS |
| 635 | 128 Restore combinations across versions | Version 5, mask 32: - System Global | PASS |
| 636 | 128 Restore combinations across versions | Version 5, mask 33: - App Groups<br>- System Global | PASS |
| 637 | 128 Restore combinations across versions | Version 5, mask 34: - System Global<br>- Global Preferences | PASS |
| 638 | 128 Restore combinations across versions | Version 5, mask 35: - App Groups<br>- System Global<br>- Global Preferences | PASS |
| 639 | 128 Restore combinations across versions | Version 5, mask 36: - System Global<br>- Keychain | PASS |
| 640 | 128 Restore combinations across versions | Version 5, mask 37: - App Groups<br>- System Global<br>- Keychain | PASS |
| 641 | 128 Restore combinations across versions | Version 5, mask 38: - System Global<br>- Global Preferences<br>- Keychain | PASS |
| 642 | 128 Restore combinations across versions | Version 5, mask 39: - App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 643 | 128 Restore combinations across versions | Version 5, mask 40: - Profile App Data<br>- System Global | PASS |
| 644 | 128 Restore combinations across versions | Version 5, mask 41: - Profile App Data<br>- App Groups<br>- System Global | PASS |
| 645 | 128 Restore combinations across versions | Version 5, mask 42: - Profile App Data<br>- System Global<br>- Global Preferences | PASS |
| 646 | 128 Restore combinations across versions | Version 5, mask 43: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 647 | 128 Restore combinations across versions | Version 5, mask 44: - Profile App Data<br>- System Global<br>- Keychain | PASS |
| 648 | 128 Restore combinations across versions | Version 5, mask 45: - Profile App Data<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 649 | 128 Restore combinations across versions | Version 5, mask 46: - Profile App Data<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 650 | 128 Restore combinations across versions | Version 5, mask 47: - Profile App Data<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 651 | 128 Restore combinations across versions | Version 5, mask 48: - Global Safari<br>- System Global | PASS |
| 652 | 128 Restore combinations across versions | Version 5, mask 49: - Global Safari<br>- App Groups<br>- System Global | PASS |
| 653 | 128 Restore combinations across versions | Version 5, mask 50: - Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 654 | 128 Restore combinations across versions | Version 5, mask 51: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 655 | 128 Restore combinations across versions | Version 5, mask 52: - Global Safari<br>- System Global<br>- Keychain | PASS |
| 656 | 128 Restore combinations across versions | Version 5, mask 53: - Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 657 | 128 Restore combinations across versions | Version 5, mask 54: - Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 658 | 128 Restore combinations across versions | Version 5, mask 55: - Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 659 | 128 Restore combinations across versions | Version 5, mask 56: - Profile App Data<br>- Global Safari<br>- System Global | PASS |
| 660 | 128 Restore combinations across versions | Version 5, mask 57: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global | PASS |
| 661 | 128 Restore combinations across versions | Version 5, mask 58: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences | PASS |
| 662 | 128 Restore combinations across versions | Version 5, mask 59: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences | PASS |
| 663 | 128 Restore combinations across versions | Version 5, mask 60: - Profile App Data<br>- Global Safari<br>- System Global<br>- Keychain | PASS |
| 664 | 128 Restore combinations across versions | Version 5, mask 61: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Keychain | PASS |
| 665 | 128 Restore combinations across versions | Version 5, mask 62: - Profile App Data<br>- Global Safari<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 666 | 128 Restore combinations across versions | Version 5, mask 63: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Global Preferences<br>- Keychain | PASS |
| 667 | 128 Restore combinations across versions | Version 5, mask 64: - Shared System Databases | PASS |
| 668 | 128 Restore combinations across versions | Version 5, mask 65: - App Groups<br>- Shared System Databases | PASS |
| 669 | 128 Restore combinations across versions | Version 5, mask 66: - Shared System Databases<br>- Global Preferences | PASS |
| 670 | 128 Restore combinations across versions | Version 5, mask 67: - App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 671 | 128 Restore combinations across versions | Version 5, mask 68: - Shared System Databases<br>- Keychain | PASS |
| 672 | 128 Restore combinations across versions | Version 5, mask 69: - App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 673 | 128 Restore combinations across versions | Version 5, mask 70: - Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 674 | 128 Restore combinations across versions | Version 5, mask 71: - App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 675 | 128 Restore combinations across versions | Version 5, mask 72: - Profile App Data<br>- Shared System Databases | PASS |
| 676 | 128 Restore combinations across versions | Version 5, mask 73: - Profile App Data<br>- App Groups<br>- Shared System Databases | PASS |
| 677 | 128 Restore combinations across versions | Version 5, mask 74: - Profile App Data<br>- Shared System Databases<br>- Global Preferences | PASS |
| 678 | 128 Restore combinations across versions | Version 5, mask 75: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 679 | 128 Restore combinations across versions | Version 5, mask 76: - Profile App Data<br>- Shared System Databases<br>- Keychain | PASS |
| 680 | 128 Restore combinations across versions | Version 5, mask 77: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 681 | 128 Restore combinations across versions | Version 5, mask 78: - Profile App Data<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 682 | 128 Restore combinations across versions | Version 5, mask 79: - Profile App Data<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 683 | 128 Restore combinations across versions | Version 5, mask 80: - Global Safari<br>- Shared System Databases | PASS |
| 684 | 128 Restore combinations across versions | Version 5, mask 81: - Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 685 | 128 Restore combinations across versions | Version 5, mask 82: - Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 686 | 128 Restore combinations across versions | Version 5, mask 83: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 687 | 128 Restore combinations across versions | Version 5, mask 84: - Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 688 | 128 Restore combinations across versions | Version 5, mask 85: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 689 | 128 Restore combinations across versions | Version 5, mask 86: - Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 690 | 128 Restore combinations across versions | Version 5, mask 87: - Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 691 | 128 Restore combinations across versions | Version 5, mask 88: - Profile App Data<br>- Global Safari<br>- Shared System Databases | PASS |
| 692 | 128 Restore combinations across versions | Version 5, mask 89: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases | PASS |
| 693 | 128 Restore combinations across versions | Version 5, mask 90: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences | PASS |
| 694 | 128 Restore combinations across versions | Version 5, mask 91: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences | PASS |
| 695 | 128 Restore combinations across versions | Version 5, mask 92: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Keychain | PASS |
| 696 | 128 Restore combinations across versions | Version 5, mask 93: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Keychain | PASS |
| 697 | 128 Restore combinations across versions | Version 5, mask 94: - Profile App Data<br>- Global Safari<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 698 | 128 Restore combinations across versions | Version 5, mask 95: - Profile App Data<br>- Global Safari<br>- App Groups<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 699 | 128 Restore combinations across versions | Version 5, mask 96: - System Global<br>- Shared System Databases | PASS |
| 700 | 128 Restore combinations across versions | Version 5, mask 97: - App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 701 | 128 Restore combinations across versions | Version 5, mask 98: - System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 702 | 128 Restore combinations across versions | Version 5, mask 99: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 703 | 128 Restore combinations across versions | Version 5, mask 100: - System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 704 | 128 Restore combinations across versions | Version 5, mask 101: - App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 705 | 128 Restore combinations across versions | Version 5, mask 102: - System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 706 | 128 Restore combinations across versions | Version 5, mask 103: - App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 707 | 128 Restore combinations across versions | Version 5, mask 104: - Profile App Data<br>- System Global<br>- Shared System Databases | PASS |
| 708 | 128 Restore combinations across versions | Version 5, mask 105: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 709 | 128 Restore combinations across versions | Version 5, mask 106: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 710 | 128 Restore combinations across versions | Version 5, mask 107: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 711 | 128 Restore combinations across versions | Version 5, mask 108: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 712 | 128 Restore combinations across versions | Version 5, mask 109: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 713 | 128 Restore combinations across versions | Version 5, mask 110: - Profile App Data<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 714 | 128 Restore combinations across versions | Version 5, mask 111: - Profile App Data<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 715 | 128 Restore combinations across versions | Version 5, mask 112: - Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 716 | 128 Restore combinations across versions | Version 5, mask 113: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 717 | 128 Restore combinations across versions | Version 5, mask 114: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 718 | 128 Restore combinations across versions | Version 5, mask 115: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 719 | 128 Restore combinations across versions | Version 5, mask 116: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 720 | 128 Restore combinations across versions | Version 5, mask 117: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 721 | 128 Restore combinations across versions | Version 5, mask 118: - Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 722 | 128 Restore combinations across versions | Version 5, mask 119: - Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 723 | 128 Restore combinations across versions | Version 5, mask 120: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases | PASS |
| 724 | 128 Restore combinations across versions | Version 5, mask 121: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases | PASS |
| 725 | 128 Restore combinations across versions | Version 5, mask 122: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 726 | 128 Restore combinations across versions | Version 5, mask 123: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences | PASS |
| 727 | 128 Restore combinations across versions | Version 5, mask 124: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 728 | 128 Restore combinations across versions | Version 5, mask 125: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Keychain | PASS |
| 729 | 128 Restore combinations across versions | Version 5, mask 126: - Profile App Data<br>- Global Safari<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 730 | 128 Restore combinations across versions | Version 5, mask 127: - Profile App Data<br>- Global Safari<br>- App Groups<br>- System Global<br>- Shared System Databases<br>- Global Preferences<br>- Keychain | PASS |
| 731 | actual inclusion versus raw request | raw App Group request with empty appGroups -> factual advanced mask 0 | PASS |
| 732 | actual inclusion versus raw request | applicationGroups telemetry with empty appGroups -> factual advanced mask 0 | PASS |
| 733 | actual inclusion versus raw request | nonempty appGroups -> factual advanced mask 4 | PASS |
| 734 | actual inclusion versus raw request | Preferences requested but included false -> factual advanced mask 0 | PASS |
| 735 | actual inclusion versus raw request | Preferences included true -> factual advanced mask 32 | PASS |
| 736 | actual inclusion versus raw request | Keychain requested but included false -> factual advanced mask 0 | PASS |
| 737 | actual inclusion versus raw request | Keychain included true -> factual advanced mask 64 | PASS |
| 738 | actual inclusion versus raw request | Profile included -> factual advanced mask 1 | PASS |
| 739 | actual inclusion versus raw request | Global Safari included -> factual advanced mask 2 | PASS |
| 740 | actual inclusion versus raw request | System section absent -> factual advanced mask 0 | PASS |
| 741 | actual inclusion versus raw request | System included with items -> factual advanced mask 8 | PASS |
| 742 | actual inclusion versus raw request | Shared section absent -> factual advanced mask 0 | PASS |
| 743 | actual inclusion versus raw request | Shared included with files -> factual advanced mask 16 | PASS |
| 744 | actual inclusion versus raw request | includedOptions telemetry excluded by actual sections -> factual advanced mask 0 | PASS |
| 745 | actual inclusion versus raw request | all actual sections included -> factual advanced mask 127 | PASS |
| 746 | actual inclusion versus raw request | base Application Data only -> factual advanced mask 0 | PASS |
| 747 | manifest mutation tests | Mutation of manifestVersion blocks Restore with Restore Selection Changed | PASS |
| 748 | manifest mutation tests | Mutation of bundleID blocks Restore with Restore Selection Changed | PASS |
| 749 | manifest mutation tests | Mutation of timestamp blocks Restore with Restore Selection Changed | PASS |
| 750 | manifest mutation tests | Mutation of backupID blocks Restore with Restore Selection Changed | PASS |
| 751 | manifest mutation tests | Mutation of applicationGroups blocks Restore with Restore Selection Changed | PASS |
| 752 | manifest mutation tests | Mutation of appGroups blocks Restore with Restore Selection Changed | PASS |
| 753 | manifest mutation tests | Mutation of preferences blocks Restore with Restore Selection Changed | PASS |
| 754 | manifest mutation tests | Mutation of keychain blocks Restore with Restore Selection Changed | PASS |
| 755 | manifest mutation tests | Mutation of profileAppData blocks Restore with Restore Selection Changed | PASS |
| 756 | manifest mutation tests | Mutation of globalSafari blocks Restore with Restore Selection Changed | PASS |
| 757 | manifest mutation tests | Mutation of systemGlobalLibrary blocks Restore with Restore Selection Changed | PASS |
| 758 | manifest mutation tests | Mutation of sharedSystemDB blocks Restore with Restore Selection Changed | PASS |
| 759 | manifest mutation tests | Mutation of artifacts blocks Restore with Restore Selection Changed | PASS |
| 760 | manifest mutation tests | Mutation of options blocks Restore with Restore Selection Changed | PASS |
| 761 | manifest mutation tests | Mutation of warnings blocks Restore with Restore Selection Changed | PASS |
| 762 | manifest mutation tests | Mutation of restoreCompatibility blocks Restore with Restore Selection Changed | PASS |
| 763 | manifest mutation tests | Mutation of publication blocks Restore with Restore Selection Changed | PASS |
| 764 | cancellation and invocation counts | Cancel data-only Backup: backup=0 restore=0 processing=0 | PASS |
| 765 | cancellation and invocation counts | Cancel advanced Backup: backup=0 restore=0 processing=0 | PASS |
| 766 | cancellation and invocation counts | Confirm Backup: backup=1 restore=0 processing=1 | PASS |
| 767 | cancellation and invocation counts | Cancel picker: backup=0 restore=0 processing=0 | PASS |
| 768 | cancellation and invocation counts | Cancel data-only Restore: backup=0 restore=0 processing=0 | PASS |
| 769 | cancellation and invocation counts | Cancel advanced Restore: backup=0 restore=0 processing=0 | PASS |
| 770 | cancellation and invocation counts | Manifest unavailable: backup=0 restore=0 processing=0 | PASS |
| 771 | cancellation and invocation counts | Manifest changed: backup=0 restore=0 processing=0 | PASS |
| 772 | cancellation and invocation counts | Confirm unchanged Restore: backup=0 restore=1 processing=1 | PASS |
| 773 | protected region hashes | backup-presentation-helpers: 1907 bytes / eec90ebe21381e18fb5f62579aa90163ee850f544fb46d08e78f15a853366335 | PASS |
| 774 | protected region hashes | restore-outcome-core: 10510 bytes / 7b58e3b703dcea3d0ffb44120c65d18591420810bb833804537e3a0a91227a22 | PASS |
| 775 | protected region hashes | restore-warning-helper: 344 bytes / bee9a0b8976adb067044fec0059d897b2e5ba9b98a17da9860073be0f1c99a34 | PASS |
| 776 | protected region hashes | restore-component-formatters: 6558 bytes / 1a0a16150b4694bf66afd6b5f8a31a79d492cd61b7cebb3073602cf90f3f884f | PASS |
| 777 | protected region hashes | pending-alert-region: 2754 bytes / 00ba8cbbe9952292f0d9d39e0d3db7c4869b4968e3455527d373c8d503d48337 | PASS |
| 778 | protected region hashes | view-option-controls: 3634 bytes / d37af7c06bf0b55cfd5fb556adc4e026647e7b8394b6c8da645a935839da0af5 | PASS |
| 779 | result callback hashes | backup-result-callback: 2020 bytes / d8f0983c5a870c6d62e616e80a9eae3826259f22eb7b9ed38dfc6648d66e576b | PASS |
| 780 | result callback hashes | restore-result-callback: 3933 bytes / 583cac544a9b7a5bded972e8d75da331be2a4fcf14a29d65c5bd68060ed90454 | PASS |
| 781 | manager manifest model and batch hashes | AppDataBackupManager.h: 1442 bytes / b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75 | PASS |
| 782 | manager manifest model and batch hashes | AppDataBackupManager.m: 239969 bytes / 61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028 | PASS |
| 783 | manager manifest model and batch hashes | AppDataBackupRestoreViewController.h: 336 bytes / b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf | PASS |
| 784 | manager manifest model and batch hashes | Makefile: 9266 bytes / b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa | PASS |
| 785 | manager manifest model and batch hashes | PXBackupManifestV4.h: 2354 bytes / 4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054 | PASS |
| 786 | manager manifest model and batch hashes | PXBackupManifestV4.m: 45136 bytes / 4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037 | PASS |
| 787 | manager manifest model and batch hashes | PXBackupManifestValidator.h: 945 bytes / 6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836 | PASS |
| 788 | manager manifest model and batch hashes | PXBackupManifestValidator.m: 91206 bytes / 8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b | PASS |
| 789 | manager manifest model and batch hashes | PXRestorePlan.h: 4947 bytes / 5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643 | PASS |
| 790 | manager manifest model and batch hashes | PXRestorePlan.m: 48523 bytes / cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141 | PASS |
| 791 | manager manifest model and batch hashes | PXRestoreResult.h: 4512 bytes / cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d | PASS |
| 792 | manager manifest model and batch hashes | PXRestoreResult.m: 15842 bytes / c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb | PASS |
| 793 | manager manifest model and batch hashes | ProfileManagerViewController.m: 159713 bytes / a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a | PASS |
| 794 | manager manifest model and batch hashes | ProjectXViewController.m: 372278 bytes / b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162 | PASS |
| 795 | batch caller boundary | AppDataBackupRestoreViewController.m Restore caller count remains 1 | PASS |
| 796 | batch caller boundary | ProjectXViewController.m Restore caller count remains 2 | PASS |
| 797 | privacy, ordering, static, and boundary gates | Confirmation displays canonical scope names only | PASS |
| 798 | privacy, ordering, static, and boundary gates | Application Data stays in prose and outside advanced bullet list | PASS |
| 799 | privacy, ordering, static, and boundary gates | No App Group identifiers are displayed | PASS |
| 800 | privacy, ordering, static, and boundary gates | No App Group UUIDs are displayed | PASS |
| 801 | privacy, ordering, static, and boundary gates | No Keychain access groups are displayed | PASS |
| 802 | privacy, ordering, static, and boundary gates | No Keychain method is displayed | PASS |
| 803 | privacy, ordering, static, and boundary gates | No profile identifier is displayed | PASS |
| 804 | privacy, ordering, static, and boundary gates | No system subdirectory name is displayed | PASS |
| 805 | privacy, ordering, static, and boundary gates | No shared database path is displayed | PASS |
| 806 | privacy, ordering, static, and boundary gates | No artifact name or checksum is displayed | PASS |
| 807 | privacy, ordering, static, and boundary gates | No backup directory or manifest path is displayed | PASS |
| 808 | privacy, ordering, static, and boundary gates | No backupID is displayed | PASS |
| 809 | privacy, ordering, static, and boundary gates | No raw bitmask is displayed | PASS |
| 810 | privacy, ordering, static, and boundary gates | No persistent consent property was added | PASS |
| 811 | privacy, ordering, static, and boundary gates | No NSUserDefaults consent write was added | PASS |
| 812 | privacy, ordering, static, and boundary gates | Picker Cancel causes zero confirmation and manager calls | PASS |
| 813 | privacy, ordering, static, and boundary gates | Data-only Restore Cancel causes zero second read and manager calls | PASS |
| 814 | privacy, ordering, static, and boundary gates | Advanced Restore Cancel causes zero second read and manager calls | PASS |
| 815 | privacy, ordering, static, and boundary gates | Manifest unavailable causes zero processing and manager calls | PASS |
| 816 | privacy, ordering, static, and boundary gates | Manifest changed causes zero processing and manager calls | PASS |
| 817 | privacy, ordering, static, and boundary gates | Unchanged manifest calls Restore manager exactly once | PASS |
| 818 | privacy, ordering, static, and boundary gates | Processing alert appears only after equality checks | PASS |
| 819 | privacy, ordering, static, and boundary gates | Selected manifest is read after picker selection | PASS |
| 820 | privacy, ordering, static, and boundary gates | Selected manifest is serialized into an immutable property-list graph | PASS |
| 821 | privacy, ordering, static, and boundary gates | Current manifest is re-read inside positive confirmation action | PASS |
| 822 | privacy, ordering, static, and boundary gates | Whole-manifest equality is checked exactly once | PASS |
| 823 | privacy, ordering, static, and boundary gates | Scope mask equality is checked in addition to whole-manifest equality | PASS |
| 824 | privacy, ordering, static, and boundary gates | Bundle identity is revalidated by scope parser | PASS |
| 825 | privacy, ordering, static, and boundary gates | No automatic re-confirmation occurs after selection change | PASS |
| 826 | privacy, ordering, static, and boundary gates | User must select the backup again after selection change | PASS |
| 827 | privacy, ordering, static, and boundary gates | No preliminary Restore confirmation appears before picker | PASS |
| 828 | privacy, ordering, static, and boundary gates | No processing alert appears before final confirmation | PASS |
| 829 | privacy, ordering, static, and boundary gates | Picker limit remains ten | PASS |
| 830 | privacy, ordering, static, and boundary gates | Picker discovery order remains unchanged | PASS |
| 831 | privacy, ordering, static, and boundary gates | Picker timestamp title behavior remains unchanged | PASS |
| 832 | privacy, ordering, static, and boundary gates | Picker basename fallback remains unchanged | PASS |
| 833 | privacy, ordering, static, and boundary gates | Picker Cancel action remains present | PASS |
| 834 | privacy, ordering, static, and boundary gates | iPad popover configuration remains present | PASS |
| 835 | privacy, ordering, static, and boundary gates | No Backups Found behavior remains present | PASS |
| 836 | privacy, ordering, static, and boundary gates | Old garbled Restore warning string is absent | PASS |
| 837 | privacy, ordering, static, and boundary gates | Backup result titles remain unchanged | PASS |
| 838 | privacy, ordering, static, and boundary gates | Six Restore result titles remain unchanged | PASS |
| 839 | privacy, ordering, static, and boundary gates | Component Results section remains unchanged | PASS |
| 840 | privacy, ordering, static, and boundary gates | Aggregate warning order remains unchanged | PASS |
| 841 | privacy, ordering, static, and boundary gates | Restore copyPath remains nil | PASS |
| 842 | privacy, ordering, static, and boundary gates | Backup Copy Path behavior remains unchanged | PASS |
| 843 | privacy, ordering, static, and boundary gates | Controller is UTF-8 CRLF only | PASS |
| 844 | privacy, ordering, static, and boundary gates | Report is generated as UTF-8 LF only | PASS |
| 845 | privacy, ordering, static, and boundary gates | Controller contains no lone CR | PASS |
| 846 | privacy, ordering, static, and boundary gates | Controller contains no NUL | PASS |
| 847 | privacy, ordering, static, and boundary gates | Controller has final newline | PASS |
| 848 | privacy, ordering, static, and boundary gates | Objective-C delimiters are balanced | PASS |
| 849 | privacy, ordering, static, and boundary gates | Conflict markers are absent | PASS |
| 850 | privacy, ordering, static, and boundary gates | Protected production diff is empty | PASS |
| 851 | privacy, ordering, static, and boundary gates | ProjectX batch workflows remain unchanged | PASS |
| 852 | privacy, ordering, static, and boundary gates | ProfileManager workflows remain unchanged | PASS |
| 853 | privacy, ordering, static, and boundary gates | Makefile remains unchanged | PASS |
| 854 | privacy, ordering, static, and boundary gates | No Phase 6 report exists | PASS |
| 855 | privacy, ordering, static, and boundary gates | No Phase 6 source work was started | PASS |

## Objective-C/toolchain status
Balanced Objective-C delimiters, parentheses, brackets, braces, conflict-marker, NUL, exact literal, model, hash, and git-diff gates passed on Windows.
- clang: UNAVAILABLE
- make: UNAVAILABLE
Apple/Theos compile, link, and package were not run and are not claimed as PASS.

## Device/UI status
Device/UIKit tests were not run. Actual alert wrapping, device cancellation interaction, live manifest replacement, and background result presentation remain pending device validation.

## Full authorized diff
```diff
diff --git a/AppDataBackupRestoreViewController.m b/AppDataBackupRestoreViewController.m
index 98a0d94..d39aafd 100644
--- a/AppDataBackupRestoreViewController.m
+++ b/AppDataBackupRestoreViewController.m
@@ -3,6 +3,7 @@
 #import "AppDataBackupManager.h"
 #import "BackupKeychainGroupsViewController.h"
 #import <objc/message.h>
+#import <CoreFoundation/CoreFoundation.h>

 @interface LSApplicationWorkspace : NSObject
 + (instancetype)defaultWorkspace;
@@ -87,6 +88,318 @@ static NSString *PXBackupAlertTitleForOutcome(PXBackupAlertOutcome outcome) {
 @property (nonatomic, copy) NSString *pendingCopyPath;
 @end

+typedef NS_OPTIONS(NSUInteger, PXAdvancedDataScope) {
+    PXAdvancedDataScopeAppGroups = 1 << 0,
+    PXAdvancedDataScopePreferences = 1 << 1,
+    PXAdvancedDataScopeKeychain = 1 << 2,
+    PXAdvancedDataScopeProfileAppData = 1 << 3,
+    PXAdvancedDataScopeGlobalSafari = 1 << 4,
+    PXAdvancedDataScopeSystemGlobal = 1 << 5,
+    PXAdvancedDataScopeSharedSystemDatabases = 1 << 6,
+};
+
+static const PXAdvancedDataScope PXAdvancedDataScopeAll =
+    PXAdvancedDataScopeAppGroups |
+    PXAdvancedDataScopePreferences |
+    PXAdvancedDataScopeKeychain |
+    PXAdvancedDataScopeProfileAppData |
+    PXAdvancedDataScopeGlobalSafari |
+    PXAdvancedDataScopeSystemGlobal |
+    PXAdvancedDataScopeSharedSystemDatabases;
+
+static const PXAdvancedDataScope PXAdvancedDataScopePresentationOrder[] = {
+    PXAdvancedDataScopeProfileAppData,
+    PXAdvancedDataScopeGlobalSafari,
+    PXAdvancedDataScopeAppGroups,
+    PXAdvancedDataScopeSystemGlobal,
+    PXAdvancedDataScopeSharedSystemDatabases,
+    PXAdvancedDataScopePreferences,
+    PXAdvancedDataScopeKeychain,
+};
+
+static NSString *PXAdvancedDataScopeDisplayName(PXAdvancedDataScope scope) {
+    switch (scope) {
+        case PXAdvancedDataScopeProfileAppData:
+            return @"Profile App Data";
+        case PXAdvancedDataScopeGlobalSafari:
+            return @"Global Safari";
+        case PXAdvancedDataScopeAppGroups:
+            return @"App Groups";
+        case PXAdvancedDataScopeSystemGlobal:
+            return @"System Global";
+        case PXAdvancedDataScopeSharedSystemDatabases:
+            return @"Shared System Databases";
+        case PXAdvancedDataScopePreferences:
+            return @"Global Preferences";
+        case PXAdvancedDataScopeKeychain:
+            return @"Keychain";
+        default:
+            return nil;
+    }
+}
+
+static NSString *PXAdvancedDataScopeList(PXAdvancedDataScope scopes) {
+    if (((NSUInteger)scopes & ~(NSUInteger)PXAdvancedDataScopeAll) != 0) {
+        return nil;
+    }
+    if (scopes == 0) {
+        return @"";
+    }
+
+    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithCapacity:7];
+    NSUInteger scopeCount =
+        sizeof(PXAdvancedDataScopePresentationOrder) /
+        sizeof(PXAdvancedDataScopePresentationOrder[0]);
+    for (NSUInteger index = 0; index < scopeCount; index++) {
+        PXAdvancedDataScope scope = PXAdvancedDataScopePresentationOrder[index];
+        if ((scopes & scope) == 0) {
+            continue;
+        }
+        NSString *name = PXAdvancedDataScopeDisplayName(scope);
+        if (name.length == 0) {
+            return nil;
+        }
+        [lines addObject:[NSString stringWithFormat:@"- %@", name]];
+    }
+    return [lines componentsJoinedByString:@"\n"];
+}
+
+static PXBackupOptions PXKnownDirectBackupOptions(void) {
+    return PXBackupOptionIncludeAppGroups |
+           PXBackupOptionIncludePreferences |
+           PXBackupOptionIncludeKeychain;
+}
+
+static BOOL PXBackupOptionsAreKnown(PXBackupOptions options) {
+    return ((NSUInteger)options & ~(NSUInteger)PXKnownDirectBackupOptions()) == 0;
+}
+
+static PXAdvancedDataScope PXAdvancedDataScopesForBackupOptions(PXBackupOptions options) {
+    if (!PXBackupOptionsAreKnown(options)) {
+        return (PXAdvancedDataScope)(PXAdvancedDataScopeAll + 1);
+    }
+
+    PXAdvancedDataScope scopes = 0;
+    if ((options & PXBackupOptionIncludeAppGroups) != 0) {
+        scopes |= PXAdvancedDataScopeAppGroups;
+    }
+    if ((options & PXBackupOptionIncludePreferences) != 0) {
+        scopes |= PXAdvancedDataScopePreferences;
+    }
+    if ((options & PXBackupOptionIncludeKeychain) != 0) {
+        scopes |= PXAdvancedDataScopeKeychain;
+    }
+    return scopes;
+}
+
+static BOOL PXReadExactManifestBoolean(id value, BOOL *resultOut) {
+    if (resultOut == NULL || value == nil ||
+        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
+        return NO;
+    }
+    *resultOut = [(NSNumber *)value boolValue];
+    return YES;
+}
+
+static BOOL PXReadSupportedManifestVersion(id value, NSUInteger *versionOut) {
+    if (versionOut == NULL || ![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
+        return NO;
+    }
+    double raw = [(NSNumber *)value doubleValue];
+    NSUInteger version = [(NSNumber *)value unsignedIntegerValue];
+    if (raw != (double)version || version < 2 || version > 5) {
+        return NO;
+    }
+    *versionOut = version;
+    return YES;
+}
+
+static BOOL PXReadIncludedManifestSection(id value, BOOL *includedOut) {
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return NO;
+    }
+    return PXReadExactManifestBoolean([(NSDictionary *)value objectForKey:@"included"],
+                                      includedOut);
+}
+
+static BOOL PXAdvancedDataScopesForValidatedManifest(NSDictionary *manifest,
+                                                     NSString *expectedBundleIdentifier,
+                                                     PXAdvancedDataScope *scopesOut) {
+    if (scopesOut == NULL ||
+        ![manifest isKindOfClass:[NSDictionary class]] ||
+        ![expectedBundleIdentifier isKindOfClass:[NSString class]] ||
+        expectedBundleIdentifier.length == 0) {
+        return NO;
+    }
+
+    NSUInteger manifestVersion = 0;
+    if (!PXReadSupportedManifestVersion(manifest[@"manifestVersion"], &manifestVersion)) {
+        return NO;
+    }
+    (void)manifestVersion;
+
+    id bundleIdentifierValue = manifest[@"bundleID"];
+    if (![bundleIdentifierValue isKindOfClass:[NSString class]] ||
+        [(NSString *)bundleIdentifierValue length] == 0 ||
+        ![(NSString *)bundleIdentifierValue isEqualToString:expectedBundleIdentifier]) {
+        return NO;
+    }
+
+    id appGroups = manifest[@"appGroups"];
+    if (![appGroups isKindOfClass:[NSArray class]]) {
+        return NO;
+    }
+
+    BOOL profileIncluded = NO;
+    BOOL safariIncluded = NO;
+    BOOL preferencesIncluded = NO;
+    BOOL keychainIncluded = NO;
+    if (!PXReadIncludedManifestSection(manifest[@"profileAppData"], &profileIncluded) ||
+        !PXReadIncludedManifestSection(manifest[@"globalSafari"], &safariIncluded) ||
+        !PXReadIncludedManifestSection(manifest[@"preferences"], &preferencesIncluded) ||
+        !PXReadIncludedManifestSection(manifest[@"keychain"], &keychainIncluded)) {
+        return NO;
+    }
+
+    BOOL systemIncluded = NO;
+    id systemSection = manifest[@"systemGlobalLibrary"];
+    if (systemSection != nil) {
+        if (![systemSection isKindOfClass:[NSDictionary class]] ||
+            !PXReadExactManifestBoolean([(NSDictionary *)systemSection objectForKey:@"included"],
+                                        &systemIncluded)) {
+            return NO;
+        }
+        id items = [(NSDictionary *)systemSection objectForKey:@"items"];
+        if (![items isKindOfClass:[NSArray class]] ||
+            systemIncluded != ([(NSArray *)items count] > 0)) {
+            return NO;
+        }
+    }
+
+    BOOL sharedIncluded = NO;
+    id sharedSection = manifest[@"sharedSystemDB"];
+    if (sharedSection != nil) {
+        if (![sharedSection isKindOfClass:[NSDictionary class]] ||
+            !PXReadExactManifestBoolean([(NSDictionary *)sharedSection objectForKey:@"included"],
+                                        &sharedIncluded)) {
+            return NO;
+        }
+        id files = [(NSDictionary *)sharedSection objectForKey:@"files"];
+        if (![files isKindOfClass:[NSArray class]] ||
+            sharedIncluded != ([(NSArray *)files count] > 0)) {
+            return NO;
+        }
+    }
+
+    PXAdvancedDataScope scopes = 0;
+    if (profileIncluded) scopes |= PXAdvancedDataScopeProfileAppData;
+    if (safariIncluded) scopes |= PXAdvancedDataScopeGlobalSafari;
+    if ([(NSArray *)appGroups count] > 0) scopes |= PXAdvancedDataScopeAppGroups;
+    if (systemIncluded) scopes |= PXAdvancedDataScopeSystemGlobal;
+    if (sharedIncluded) scopes |= PXAdvancedDataScopeSharedSystemDatabases;
+    if (preferencesIncluded) scopes |= PXAdvancedDataScopePreferences;
+    if (keychainIncluded) scopes |= PXAdvancedDataScopeKeychain;
+
+    *scopesOut = scopes;
+    return YES;
+}
+
+static NSDictionary *PXImmutableManifestConfirmationSnapshot(NSDictionary *manifest) {
+    if (![manifest isKindOfClass:[NSDictionary class]]) {
+        return nil;
+    }
+
+    NSError *serializationError = nil;
+    NSData *data = [NSPropertyListSerialization dataWithPropertyList:manifest
+                                                               format:NSPropertyListBinaryFormat_v1_0
+                                                              options:0
+                                                                error:&serializationError];
+    if (data.length == 0 || serializationError != nil) {
+        return nil;
+    }
+
+    NSError *deserializationError = nil;
+    id snapshot = [NSPropertyListSerialization propertyListWithData:data
+                                                            options:NSPropertyListImmutable
+                                                             format:NULL
+                                                              error:&deserializationError];
+    if (deserializationError != nil || ![snapshot isKindOfClass:[NSDictionary class]]) {
+        return nil;
+    }
+    return snapshot;
+}
+
+static NSString *PXBackupConfirmationTitle(PXAdvancedDataScope scopes) {
+    return scopes == 0 ? @"Confirm Backup" : @"Confirm Advanced Backup";
+}
+
+static NSString *PXBackupConfirmationActionTitle(PXAdvancedDataScope scopes) {
+    return scopes == 0 ? @"Backup" : @"Back Up Advanced Data";
+}
+
+static NSString *PXBackupConfirmationMessage(NSString *application,
+                                              PXAdvancedDataScope scopes) {
+    if (![application isKindOfClass:[NSString class]] || application.length == 0 ||
+        ((NSUInteger)scopes & ~(NSUInteger)PXAdvancedDataScopeAll) != 0) {
+        return nil;
+    }
+    if (scopes == 0) {
+        return [NSString stringWithFormat:@"Back up Application Data for %@?", application];
+    }
+    NSString *scopeList = PXAdvancedDataScopeList(scopes);
+    if (scopeList.length == 0) {
+        return nil;
+    }
+    return [NSString stringWithFormat:
+        @"Back up Application Data for %@ together with these advanced scopes:\n\n%@\n\n"
+        @"Advanced scopes may contain shared or sensitive data. Continue?",
+        application,
+        scopeList];
+}
+
+static NSString *PXRestoreConfirmationTitle(PXAdvancedDataScope scopes) {
+    return scopes == 0 ? @"Confirm Restore" : @"Confirm Advanced Restore";
+}
+
+static NSString *PXRestoreConfirmationActionTitle(PXAdvancedDataScope scopes) {
+    return scopes == 0 ? @"Restore" : @"Restore Advanced Data";
+}
+
+static NSString *PXRestoreConfirmationMessage(NSString *application,
+                                               PXAdvancedDataScope scopes) {
+    if (![application isKindOfClass:[NSString class]] || application.length == 0 ||
+        ((NSUInteger)scopes & ~(NSUInteger)PXAdvancedDataScopeAll) != 0) {
+        return nil;
+    }
+    if (scopes == 0) {
+        return [NSString stringWithFormat:
+            @"Restore Application Data for %@? This replaces the current app data and cannot be undone.",
+            application];
+    }
+    NSString *scopeList = PXAdvancedDataScopeList(scopes);
+    if (scopeList.length == 0) {
+        return nil;
+    }
+    return [NSString stringWithFormat:
+        @"Restore Application Data for %@ together with these advanced scopes:\n\n%@\n\n"
+        @"Advanced scopes may replace shared or sensitive data and can affect other apps or system services. This operation cannot be undone. Continue?",
+        application,
+        scopeList];
+}
+
+static NSString *PXUsableErrorDescription(NSError *error) {
+    if (![error isKindOfClass:[NSError class]]) {
+        return nil;
+    }
+    id description = error.localizedDescription;
+    if (![description isKindOfClass:[NSString class]] ||
+        [(NSString *)description length] == 0) {
+        return nil;
+    }
+    return description;
+}
+
 typedef NS_ENUM(NSUInteger, PXRestoreAlertOutcome) {
     PXRestoreAlertOutcomeSuccessful = 1,
     PXRestoreAlertOutcomeCompletedWithWarnings = 2,
@@ -890,34 +1203,60 @@ static void PXAttemptBringProjectXToFront(void) {

 - (void)backupButtonTapped {
     NSString *appIdentifier = self.appName ?: self.bundleID ?: @"this app";
-
-    // Show a confirmation alert first
-    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"Confirm Backup"
-                                                                      message:[NSString stringWithFormat:@"Are you sure you want to backup data for %@?", appIdentifier]
-                                                               preferredStyle:UIAlertControllerStyleAlert];
-
-    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
-     [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
-        // Show processing alert
-        UIAlertController *processingAlert = [UIAlertController alertControllerWithTitle:@"Backing Up"
-                                                                          message:@"Please wait while we backup your app data..."
-                                                                   preferredStyle:UIAlertControllerStyleAlert];
+
+    PXBackupOptions options = 0;
+    BOOL includeGroups = self.includeGroupsSwitch.on;
+    BOOL includePreferences = self.includePrefsSwitch.on;
+    BOOL includeKeychain = self.includeKeychainSwitch.on;
+    if (includeGroups) {
+        options |= PXBackupOptionIncludeAppGroups;
+    }
+    if (includePreferences) {
+        options |= PXBackupOptionIncludePreferences;
+    }
+    if (includeKeychain) {
+        options |= PXBackupOptionIncludeKeychain;
+    }
+    if (!PXBackupOptionsAreKnown(options)) {
+        return;
+    }
+
+    PXAdvancedDataScope advancedScopes =
+        PXAdvancedDataScopesForBackupOptions(options);
+    NSString *confirmationTitle = PXBackupConfirmationTitle(advancedScopes);
+    NSString *confirmationMessage =
+        PXBackupConfirmationMessage(appIdentifier, advancedScopes);
+    NSString *confirmationActionTitle =
+        PXBackupConfirmationActionTitle(advancedScopes);
+    if (confirmationTitle.length == 0 ||
+        confirmationMessage.length == 0 ||
+        confirmationActionTitle.length == 0) {
+        return;
+    }
+
+    PXBackupOptions capturedOptions = options;
+    UIAlertController *confirmAlert =
+        [UIAlertController alertControllerWithTitle:confirmationTitle
+                                            message:confirmationMessage
+                                     preferredStyle:UIAlertControllerStyleAlert];
+
+    [confirmAlert addAction:
+        [UIAlertAction actionWithTitle:@"Cancel"
+                                 style:UIAlertActionStyleCancel
+                               handler:nil]];
+    [confirmAlert addAction:
+        [UIAlertAction actionWithTitle:confirmationActionTitle
+                                 style:UIAlertActionStyleDefault
+                               handler:^(__unused UIAlertAction * _Nonnull action) {
+        UIAlertController *processingAlert =
+            [UIAlertController alertControllerWithTitle:@"Backing Up"
+                                                message:@"Please wait while we backup your app data..."
+                                         preferredStyle:UIAlertControllerStyleAlert];
         [self presentViewController:processingAlert animated:YES completion:nil];
-
-        PXBackupOptions options = 0;
-        if (self.includeGroupsSwitch.on) {
-            options |= PXBackupOptionIncludeAppGroups;
-        }
-        if (self.includePrefsSwitch.on) {
-            options |= PXBackupOptionIncludePreferences;
-        }
-        if (self.includeKeychainSwitch.on) {
-            options |= PXBackupOptionIncludeKeychain;
-        }

          [[AppDataBackupManager shared] createBackupForBundleID:self.bundleID
                                                        appName:self.appName
-                                                       options:options
+                                                       options:capturedOptions
                                                     completion:^(PXBackupResult *result, NSError *error) {
              [processingAlert dismissViewControllerAnimated:YES completion:^{
                  PXBackupAlertOutcome outcome = PXBackupAlertOutcomeForResult(result, error);
@@ -953,59 +1292,149 @@ static void PXAttemptBringProjectXToFront(void) {
                                                     copyPath:copyPath];
              }];
          }];
-      }]];
-
+    }]];
+
     [self presentViewController:confirmAlert animated:YES completion:nil];
 }

 - (void)restoreButtonTapped {
     NSString *appIdentifier = self.appName ?: self.bundleID ?: @"this app";
-
-    // Show a confirmation alert first with warning
-    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"Confirm Restore"
-                                                                      message:[NSString stringWithFormat:@"⚠️ Warning: This will replace the current data for %@ with backup data. This operation cannot be undone.\n\nAre you sure you want to continue?", appIdentifier]
-                                                               preferredStyle:UIAlertControllerStyleAlert];
-
-    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
-    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
-        NSArray<NSString *> *backups = [[AppDataBackupManager shared] listBackupDirectoriesForBundleID:self.bundleID];
-        if (!backups.count) {
-            UIAlertController *noAlert = [UIAlertController alertControllerWithTitle:@"No Backups Found"
-                                                                            message:@"No backups were found for this bundle ID. Create a backup first."
-                                                                     preferredStyle:UIAlertControllerStyleAlert];
-            [noAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
-            [self presentViewController:noAlert animated:YES completion:nil];
-            return;
+    NSString *bundleIdentifier = [self.bundleID copy];
+    NSString *applicationName = [self.appName copy];
+    if (bundleIdentifier.length == 0) {
+        return;
+    }
+
+    NSArray<NSString *> *backups =
+        [[AppDataBackupManager shared] listBackupDirectoriesForBundleID:bundleIdentifier];
+    if (!backups.count) {
+        UIAlertController *noAlert =
+            [UIAlertController alertControllerWithTitle:@"No Backups Found"
+                                                message:@"No backups were found for this bundle ID. Create a backup first."
+                                         preferredStyle:UIAlertControllerStyleAlert];
+        [noAlert addAction:
+            [UIAlertAction actionWithTitle:@"OK"
+                                     style:UIAlertActionStyleDefault
+                                   handler:nil]];
+        [self presentViewController:noAlert animated:YES completion:nil];
+        return;
+    }
+
+    UIAlertController *picker =
+        [UIAlertController alertControllerWithTitle:@"Select Backup"
+                                            message:nil
+                                     preferredStyle:UIAlertControllerStyleActionSheet];
+
+    NSUInteger limit = MIN((NSUInteger)10, backups.count);
+    for (NSUInteger i = 0; i < limit; i++) {
+        NSString *dir = backups[i];
+        NSString *title = dir.lastPathComponent;
+        NSError *mErr = nil;
+        NSDictionary *manifest =
+            [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir
+                                                                    error:&mErr];
+        if ([manifest isKindOfClass:[NSDictionary class]]) {
+            NSString *ts = manifest[@"timestamp"];
+            if ([ts isKindOfClass:[NSString class]] && ts.length) {
+                title = ts;
+            }
         }

-        UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Select Backup"
-                                                                        message:nil
-                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
-
-        NSUInteger limit = MIN((NSUInteger)10, backups.count);
-        for (NSUInteger i = 0; i < limit; i++) {
-            NSString *dir = backups[i];
-            NSString *title = dir.lastPathComponent;
-            NSError *mErr = nil;
-            NSDictionary *manifest = [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir error:&mErr];
-            if ([manifest isKindOfClass:[NSDictionary class]]) {
-                NSString *ts = manifest[@"timestamp"];
-                if ([ts isKindOfClass:[NSString class]] && ts.length) {
-                    title = ts;
-                }
+        [picker addAction:
+            [UIAlertAction actionWithTitle:title
+                                     style:UIAlertActionStyleDefault
+                                   handler:^(__unused UIAlertAction * _Nonnull action) {
+            NSError *selectionError = nil;
+            NSDictionary *selectedManifest =
+                [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir
+                                                                        error:&selectionError];
+            PXAdvancedDataScope selectedScopes = 0;
+            BOOL scopesValid =
+                PXAdvancedDataScopesForValidatedManifest(selectedManifest,
+                                                         bundleIdentifier,
+                                                         &selectedScopes);
+            NSDictionary *confirmedManifestSnapshot = scopesValid
+                ? PXImmutableManifestConfirmationSnapshot(selectedManifest)
+                : nil;
+            NSString *confirmationTitle = scopesValid
+                ? PXRestoreConfirmationTitle(selectedScopes)
+                : nil;
+            NSString *confirmationMessage = scopesValid
+                ? PXRestoreConfirmationMessage(appIdentifier, selectedScopes)
+                : nil;
+            NSString *confirmationActionTitle = scopesValid
+                ? PXRestoreConfirmationActionTitle(selectedScopes)
+                : nil;
+
+            if (!scopesValid ||
+                confirmedManifestSnapshot == nil ||
+                confirmationTitle.length == 0 ||
+                confirmationMessage.length == 0 ||
+                confirmationActionTitle.length == 0) {
+                NSString *unavailableMessage =
+                    PXUsableErrorDescription(selectionError) ?:
+                    @"The selected backup could not be validated for Restore.";
+                UIAlertController *unavailableAlert =
+                    [UIAlertController alertControllerWithTitle:@"Restore Unavailable"
+                                                        message:unavailableMessage
+                                                 preferredStyle:UIAlertControllerStyleAlert];
+                [unavailableAlert addAction:
+                    [UIAlertAction actionWithTitle:@"OK"
+                                             style:UIAlertActionStyleDefault
+                                           handler:nil]];
+                [self presentViewController:unavailableAlert animated:YES completion:nil];
+                return;
             }

-            [picker addAction:[UIAlertAction actionWithTitle:title
-                                                      style:UIAlertActionStyleDefault
-                                                    handler:^(UIAlertAction * _Nonnull action) {
-                UIAlertController *processingAlert = [UIAlertController alertControllerWithTitle:@"Restoring"
-                                                                                         message:@"Please wait while we restore your app data..."
-                                                                                  preferredStyle:UIAlertControllerStyleAlert];
+            PXAdvancedDataScope confirmedScopes = selectedScopes;
+            UIAlertController *confirmAlert =
+                [UIAlertController alertControllerWithTitle:confirmationTitle
+                                                    message:confirmationMessage
+                                             preferredStyle:UIAlertControllerStyleAlert];
+            [confirmAlert addAction:
+                [UIAlertAction actionWithTitle:@"Cancel"
+                                         style:UIAlertActionStyleCancel
+                                       handler:nil]];
+            [confirmAlert addAction:
+                [UIAlertAction actionWithTitle:confirmationActionTitle
+                                         style:UIAlertActionStyleDestructive
+                                       handler:^(__unused UIAlertAction * _Nonnull confirmAction) {
+                NSError *currentManifestError = nil;
+                NSDictionary *currentManifest =
+                    [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir
+                                                                            error:&currentManifestError];
+                PXAdvancedDataScope currentScopes = 0;
+                BOOL currentScopesValid =
+                    PXAdvancedDataScopesForValidatedManifest(currentManifest,
+                                                             bundleIdentifier,
+                                                             &currentScopes);
+                BOOL selectionUnchanged =
+                    currentScopesValid &&
+                    [currentManifest isEqual:confirmedManifestSnapshot] &&
+                    currentScopes == confirmedScopes;
+                if (!selectionUnchanged) {
+                    UIAlertController *changedAlert =
+                        [UIAlertController alertControllerWithTitle:@"Restore Selection Changed"
+                                                            message:@"The selected backup changed after confirmation. Select it again and review its scopes before restoring."
+                                                     preferredStyle:UIAlertControllerStyleAlert];
+                    [changedAlert addAction:
+                        [UIAlertAction actionWithTitle:@"OK"
+                                                 style:UIAlertActionStyleDefault
+                                               handler:nil]];
+                    [self presentViewController:changedAlert animated:YES completion:nil];
+                    return;
+                }
+                (void)currentManifestError;
+
+                UIAlertController *processingAlert =
+                    [UIAlertController alertControllerWithTitle:@"Restoring"
+                                                        message:@"Please wait while we restore your app data..."
+                                                 preferredStyle:UIAlertControllerStyleAlert];
                 [self presentViewController:processingAlert animated:YES completion:nil];

                  [[AppDataBackupManager shared] restoreBackupAtDirectory:dir
-                                                                bundleID:self.bundleID
-                                                                 appName:self.appName
+                                                                bundleID:bundleIdentifier
+                                                                 appName:applicationName
                                                               completion:^(PXRestoreResult *result, NSError *error) {
                      [processingAlert dismissViewControllerAnimated:YES completion:^{
                          BOOL validResult = PXRestoreResultIsValidForPresentation(result);
@@ -1073,18 +1502,25 @@ static void PXAttemptBringProjectXToFront(void) {
                                                             copyPath:nil];
                      }];
                  }];
-             }]];
-        }
+            }]];

-        [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
-        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
-            picker.popoverPresentationController.sourceView = self.view;
-            picker.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height, 1, 1);
-        }
-        [self presentViewController:picker animated:YES completion:nil];
-    }]];
-
-    [self presentViewController:confirmAlert animated:YES completion:nil];
+            [self presentViewController:confirmAlert animated:YES completion:nil];
+        }]];
+    }
+
+    [picker addAction:
+        [UIAlertAction actionWithTitle:@"Cancel"
+                                 style:UIAlertActionStyleCancel
+                               handler:nil]];
+    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
+        picker.popoverPresentationController.sourceView = self.view;
+        picker.popoverPresentationController.sourceRect =
+            CGRectMake(self.view.bounds.size.width / 2.0,
+                       self.view.bounds.size.height,
+                       1,
+                       1);
+    }
+    [self presentViewController:picker animated:YES completion:nil];
 }

 @end
```

## Line-ending/NUL audit
- AppDataBackupRestoreViewController.m: UTF-8 CRLF, 1526 CRLF, 0 LF-only, 0 lone CR, 0 NUL, final newline present.
- TASK-5.4-REPORT.md: UTF-8 LF, no CRLF, no lone CR, no NUL, final newline required and verified after generation.

## Residual risks
Apple compiler/linker/package verification and physical-device UI behavior are not available in this Windows workspace. Manager-side validation remains the execution authority; UI equality is an additional confirmation-binding guard.

## Phase 5 closure boundary
This implementation completes only TASK-5.4 implementation evidence. It does not create a TASK-5.4 review or coordinator closure commit.

## Phase 6 boundary
No TASK-6.1 work, legacy API quarantine, CI regression guard, batch confirmation migration, manager redesign, or Phase 6 source/report was started.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
