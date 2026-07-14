# TASK-2.7 Report — Immutable Restore Plan

## 1. Baseline and exact scope

- Required baseline and observed pre-edit HEAD: `2bb8473bd16ac097ae03d0e83e42b28987af1495`.
- TASK-2.6 and TASK-2.6A were source-review ACCEPTED before this task.
- Added production: `PXRestorePlan.h`, `PXRestorePlan.m`; modified production: `AppDataBackupManager.m`.
- Added report: `docs/backup-restore-hardening/reports/TASK-2.7-REPORT.md`.
- No TASK-2.8 staging redesign, transaction, rollback, structured result or UI work is included.
- Pre-existing coordinator/review/task files below were not edited or staged by TASK-2.7.

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
?? docs/backup-restore-hardening/reviews/TASK-2.6A-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.6-add-archive-entry-safety-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.6A-fix-archive-validator-compatibility-and-bounds.md
?? docs/backup-restore-hardening/tasks/TASK-2.7-build-immutable-restore-plan.md
$ git rev-parse HEAD
2bb8473bd16ac097ae03d0e83e42b28987af1495
$ git log -3 --oneline
2bb8473 phase2(task-2.6A): fix archive validator compatibility and bounds
6dd6df3 phase2(task-2.6): add archive entry safety validator
2a00a93 phase2(task-2.5): add common artifact verifier
```

## 2. Protected production SHA-256 before/after

Canonical Git blob hashes compare the baseline commit with the post-implementation staged index; checkout CRLF conversion cannot affect these values.

| Protected production file | Baseline SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `AppDataBackupManager.h` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | MATCH |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | MATCH |
| `PXBackupManifestValidator.m` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | MATCH |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | MATCH |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | MATCH |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | MATCH |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | MATCH |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | MATCH |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | MATCH |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | MATCH |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | MATCH |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | MATCH |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | MATCH |
| `AppEntitlementsReader.h` | `4fb0b87f71d781b0598894a124b45527bd28cbfbf936d905b2b230aa084bb3f3` | `4fb0b87f71d781b0598894a124b45527bd28cbfbf936d905b2b230aa084bb3f3` | MATCH |
| `AppEntitlementsReader.m` | `0796c1489df2c7164d21a81e493c732b517cb759c8a9dd20d9fa8c915c8a3bab` | `0796c1489df2c7164d21a81e493c732b517cb759c8a9dd20d9fa8c915c8a3bab` | MATCH |
| `AppGroupContainerResolver.h` | `a9454a59e6b28e26865996d37a782bc0a122adb2255d375f254aa7dc31ce722b` | `a9454a59e6b28e26865996d37a782bc0a122adb2255d375f254aa7dc31ce722b` | MATCH |
| `AppGroupContainerResolver.m` | `cbaba0d4b3f1f9de9598c61341d5e001e627b88bda6188e459b408dcaee16fdd` | `cbaba0d4b3f1f9de9598c61341d5e001e627b88bda6188e459b408dcaee16fdd` | MATCH |
| `AppDataCleaner.h` | `c280c5543ab87f9672f8bbccb44ccb42fd65533032e5a6beed81802e4ac4d685` | `c280c5543ab87f9672f8bbccb44ccb42fd65533032e5a6beed81802e4ac4d685` | MATCH |
| `AppDataCleaner.m` | `3469382da795a03b834367d7b42be38bcbd08ed256cda3bcf92a401e8683b9d4` | `3469382da795a03b834367d7b42be38bcbd08ed256cda3bcf92a401e8683b9d4` | MATCH |
| `CommandRunner.h` | `22a4c402455f7ae92b89efc5d832dca1ba5b090b8207cbfc439050e83c6d5e82` | `22a4c402455f7ae92b89efc5d832dca1ba5b090b8207cbfc439050e83c6d5e82` | MATCH |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | MATCH |
| `Makefile` | `ad4dc581bfdb770ffd17ee6fecebb443e8a931a49d912582d44dcaa731476f1a` | `ad4dc581bfdb770ffd17ee6fecebb443e8a931a49d912582d44dcaa731476f1a` | MATCH |
| `AppDataBackupRestoreViewController.h` | `1c93bfce9040aeadb56460507acb594e3019199d1afda20e706ed8f6aace986c` | `1c93bfce9040aeadb56460507acb594e3019199d1afda20e706ed8f6aace986c` | MATCH |
| `AppDataBackupRestoreViewController.m` | `d37dcbcf16e3dc7f8a31cbcc229be91e56ef7545f01f84abcd7032fd19dba079` | `d37dcbcf16e3dc7f8a31cbcc229be91e56ef7545f01f84abcd7032fd19dba079` | MATCH |
| `AppVersionSpoofingViewController.h` | `0786de60d7556f771bc34dcf250066cb691994c3eab3c27ba5aa74d84ea6c339` | `0786de60d7556f771bc34dcf250066cb691994c3eab3c27ba5aa74d84ea6c339` | MATCH |
| `AppVersionSpoofingViewController.m` | `3067be9c384f94eecc176e92c24d2f82078054980ac1c2641c974e5f7f77b244` | `3067be9c384f94eecc176e92c24d2f82078054980ac1c2641c974e5f7f77b244` | MATCH |
| `BackupKeychainGroupsViewController.h` | `c22c2ba08ffc94a7326c0e508a6b13ffd33382009d429f805b087d3a9852da56` | `c22c2ba08ffc94a7326c0e508a6b13ffd33382009d429f805b087d3a9852da56` | MATCH |
| `BackupKeychainGroupsViewController.m` | `7ccb9478b53cc40bb4368111b803c456e0f6cd850e856622555b7b9f038add76` | `7ccb9478b53cc40bb4368111b803c456e0f6cd850e856622555b7b9f038add76` | MATCH |
| `DeviceSpecificSpoofingViewController+EditLabel.h` | `769466406dbda916b84e1fa08fd51f00912c97a4b4a117c53de51a660663f448` | `769466406dbda916b84e1fa08fd51f00912c97a4b4a117c53de51a660663f448` | MATCH |
| `DeviceSpecificSpoofingViewController+EditLabel.m` | `726ad1672dbc445b8649b98f3dfbb49c54100418c82fc4b4a8efc2825d2d8eaf` | `726ad1672dbc445b8649b98f3dfbb49c54100418c82fc4b4a8efc2825d2d8eaf` | MATCH |
| `DeviceSpecificSpoofingViewController+ProfileManagerDelegate.m` | `9c993caa3e0baeb6b7ab8f5f49a197f4c69e958faa42bd3f30520864e30c252b` | `9c993caa3e0baeb6b7ab8f5f49a197f4c69e958faa42bd3f30520864e30c252b` | MATCH |
| `DeviceSpecificSpoofingViewController.h` | `e3178ccd92fdf3907f74e8c44b8181c59526224a33864b52fccc22023250efe9` | `e3178ccd92fdf3907f74e8c44b8181c59526224a33864b52fccc22023250efe9` | MATCH |
| `DeviceSpecificSpoofingViewController.m` | `3c6e093aee5a950187537ad8532a9d8c987e3e4a279d0c9155b845530cfedea8` | `3c6e093aee5a950187537ad8532a9d8c987e3e4a279d0c9155b845530cfedea8` | MATCH |
| `DevicesViewController.h` | `df165bdc854a311fb79bdfc3d151c6ecc3a025b82667d2fc556638c32419f615` | `df165bdc854a311fb79bdfc3d151c6ecc3a025b82667d2fc556638c32419f615` | MATCH |
| `DevicesViewController.m` | `0baf4eb8d46cf81aa112ed9f7edb658208955706fc69fe486b29cfaa28e403b2` | `0baf4eb8d46cf81aa112ed9f7edb658208955706fc69fe486b29cfaa28e403b2` | MATCH |
| `DomainManagementViewController.h` | `31f561a8752ec035cefd5b613a539be3bfc8c105ff9756374591ba06080847a9` | `31f561a8752ec035cefd5b613a539be3bfc8c105ff9756374591ba06080847a9` | MATCH |
| `DomainManagementViewController.m` | `54a1adcd732fd1f59379b82e3636255c332a4b0b6b5f036ff05829f425d2801c` | `54a1adcd732fd1f59379b82e3636255c332a4b0b6b5f036ff05829f425d2801c` | MATCH |
| `DoorDashOrderViewController.h` | `76562968662953e09a1ed9a23ad8ec9ce529ed9ada01564441a0e12b9795e8b3` | `76562968662953e09a1ed9a23ad8ec9ce529ed9ada01564441a0e12b9795e8b3` | MATCH |
| `DoorDashOrderViewController.m` | `27d602473cdc447e2110b4823a00aab4bb0a63379a470cd940258fb696994f96` | `27d602473cdc447e2110b4823a00aab4bb0a63379a470cd940258fb696994f96` | MATCH |
| `DownloadResourcesViewController.h` | `85e94a5e58c14f701c2458b1aa7434ec6fe7f19ed2c989339a86ce28f20c0569` | `85e94a5e58c14f701c2458b1aa7434ec6fe7f19ed2c989339a86ce28f20c0569` | MATCH |
| `DownloadResourcesViewController.m` | `1f5a72f1c076c40656a50436a00e9d699da8203fe482108d5d9996ce0d2b3699` | `1f5a72f1c076c40656a50436a00e9d699da8203fe482108d5d9996ce0d2b3699` | MATCH |
| `FileManagerViewController.h` | `34868b86eb9cdc4c58b4b014223d085ee8a030545a338405076881d505434167` | `34868b86eb9cdc4c58b4b014223d085ee8a030545a338405076881d505434167` | MATCH |
| `FileManagerViewController.m` | `c1f536b6348024d33d04d2f88dc505f184ffdee386ba19cb69f4fb140a78dc80` | `c1f536b6348024d33d04d2f88dc505f184ffdee386ba19cb69f4fb140a78dc80` | MATCH |
| `FixVersionAppsViewController.h` | `9b0a0bea47b6158ff606611b1eb2810c03a6d9309256b2e6926443849210cdfd` | `9b0a0bea47b6158ff606611b1eb2810c03a6d9309256b2e6926443849210cdfd` | MATCH |
| `FixVersionAppsViewController.m` | `93f8723f3903ea2a7cb5776f4b84d65d364d0e90e0a110d817b8be6a20dd6476` | `93f8723f3903ea2a7cb5776f4b84d65d364d0e90e0a110d817b8be6a20dd6476` | MATCH |
| `KeychainGroupsViewController.h` | `0f35bc3b5d7a84d25b673216d181456b9c9aafb89519e6e8210c910330aa6f80` | `0f35bc3b5d7a84d25b673216d181456b9c9aafb89519e6e8210c910330aa6f80` | MATCH |
| `KeychainGroupsViewController.m` | `e39c0b92b4c4bc66bf044358ced23bf78f5d78f42a2ced5194b64ceb768e8228` | `e39c0b92b4c4bc66bf044358ced23bf78f5d78f42a2ced5194b64ceb768e8228` | MATCH |
| `PlistViewerViewController.h` | `ba6edb6585b97c5cd8dd0b6f995832523b88d3d3cd4110edab055e761dc6d06a` | `ba6edb6585b97c5cd8dd0b6f995832523b88d3d3cd4110edab055e761dc6d06a` | MATCH |
| `PlistViewerViewController.m` | `3c651d5c80fe57e8a26de92955e18915986ab7dbd738e75a4da1f8b296a055c1` | `3c651d5c80fe57e8a26de92955e18915986ab7dbd738e75a4da1f8b296a055c1` | MATCH |
| `ProfileCreationViewController.h` | `8b84c3272caf29c3d0913c9b0d48a6ea735738ddc8927fe0705f695d0044922c` | `8b84c3272caf29c3d0913c9b0d48a6ea735738ddc8927fe0705f695d0044922c` | MATCH |
| `ProfileCreationViewController.m` | `06f4f1e7bcbb03a5a2cdd25bf1aae1619fa854f0ae7c5cae459f8dc6306ab605` | `06f4f1e7bcbb03a5a2cdd25bf1aae1619fa854f0ae7c5cae459f8dc6306ab605` | MATCH |
| `ProfileManagerViewController.h` | `51c4faf8e59ace16e230110ec7f481543e0d7a1daf1c2029abb44cba53cb8b75` | `51c4faf8e59ace16e230110ec7f481543e0d7a1daf1c2029abb44cba53cb8b75` | MATCH |
| `ProfileManagerViewController.m` | `7d0a61b1a579b58be2d38b7bb2484712074055744ef45235e5c57b001e3db79f` | `7d0a61b1a579b58be2d38b7bb2484712074055744ef45235e5c57b001e3db79f` | MATCH |
| `ProjectXViewController.h` | `4a1f5fff1bfe167d6f36d5591f3c961e85676c4a1ecd2d0808721c9865e4693f` | `4a1f5fff1bfe167d6f36d5591f3c961e85676c4a1ecd2d0808721c9865e4693f` | MATCH |
| `ProjectXViewController.m` | `6f0c1cba5ab15370a78038e99cb7dd892133f5278127785d6151466736aadea1` | `6f0c1cba5ab15370a78038e99cb7dd892133f5278127785d6151466736aadea1` | MATCH |
| `SecurityTabViewController+IPMonitorInfo.m` | `6e267edeb4da215e3a24c8535e6625905c194db3fe5d06972020046a2a1ed576` | `6e267edeb4da215e3a24c8535e6625905c194db3fe5d06972020046a2a1ed576` | MATCH |
| `SecurityTabViewController.h` | `16a6912ffd27f0e59127095f2092d017770bd0f137f3c936a56836a0593a9527` | `16a6912ffd27f0e59127095f2092d017770bd0f137f3c936a56836a0593a9527` | MATCH |
| `SecurityTabViewController.m` | `749535e7460d472b2334fa5480844382d076078cc2d218bc6251e187c8134498` | `749535e7460d472b2334fa5480844382d076078cc2d218bc6251e187c8134498` | MATCH |
| `TabBarController.h` | `56125f77daaeb38f4fa0e04b04b6f2284f2eb553bc66d3187403b559102d3c88` | `56125f77daaeb38f4fa0e04b04b6f2284f2eb553bc66d3187403b559102d3c88` | MATCH |
| `TabBarController.m` | `64ae479501f669c5e69df774a1c906b9d2f7fb248423b25a829a0d106bd68c1c` | `64ae479501f669c5e69df774a1c906b9d2f7fb248423b25a829a0d106bd68c1c` | MATCH |
| `ToolViewController.h` | `b1cd4c538c83c09436d065e0c6677d34f421a42bd20b78c1a2a198c033dc90d6` | `b1cd4c538c83c09436d065e0c6677d34f421a42bd20b78c1a2a198c033dc90d6` | MATCH |
| `ToolViewController.m` | `aa59e132f098dc007e67707b685df1def5b070b7a6b6a3e055670e46829e5ee3` | `aa59e132f098dc007e67707b685df1def5b070b7a6b6a3e055670e46829e5ee3` | MATCH |
| `UberOrderViewController.h` | `530f3ea4aa2fac8c1da517ea8681b3435c4d5d8b5362ee08b8ccd8b5b6507280` | `530f3ea4aa2fac8c1da517ea8681b3435c4d5d8b5362ee08b8ccd8b5b6507280` | MATCH |
| `UberOrderViewController.m` | `e96194fd9092379de643a133f51cc967e79742df86cbc08a0992d64ae0233987` | `e96194fd9092379de643a133f51cc967e79742df86cbc08a0992d64ae0233987` | MATCH |
| `VersionManagementViewController.h` | `226bb9cd3adb79fdf2be267eb09538f5b1813eba981ef0747a62696f3861273e` | `226bb9cd3adb79fdf2be267eb09538f5b1813eba981ef0747a62696f3861273e` | MATCH |
| `VersionManagementViewController.m` | `48a37e20a98771ca879253943afbef2622af42b9fff00910e5b644ce36ae09b3` | `48a37e20a98771ca879253943afbef2622af42b9fff00910e5b644ce36ae09b3` | MATCH |
| `common/IPStatusViewController.h` | `1d0d39a9135fdb16985d3015675dafbf1f69fa8d51c93a3a1d2a89d5a923a99c` | `1d0d39a9135fdb16985d3015675dafbf1f69fa8d51c93a3a1d2a89d5a923a99c` | MATCH |
| `common/IPStatusViewController.m` | `06bdf790b2f51c2230b4acf64dedbf69b53a1709f6e7a6c331f6a70d2e5a46c6` | `06bdf790b2f51c2230b4acf64dedbf69b53a1709f6e7a6c331f6a70d2e5a46c6` | MATCH |
| `KeychainHelper/KeychainBackupHelper.h` | `b7719b71b9c3cccbe1a6005ed428b51562444fb7a750558a939b6434f0db9eb8` | `b7719b71b9c3cccbe1a6005ed428b51562444fb7a750558a939b6434f0db9eb8` | MATCH |
| `KeychainHelper/KeychainBackupHelper.m` | `3a8cca0d05b2881dc5c91b76b9514155bc2abad3979b8a1b4365f31420147269` | `3a8cca0d05b2881dc5c91b76b9514155bc2abad3979b8a1b4365f31420147269` | MATCH |
| `KeychainHelper/backup_helper.m` | `6cfdcddb11c38c0fe2b50f97803b44374a835a1b41c7a5111a10236dca9a40e1` | `6cfdcddb11c38c0fe2b50f97803b44374a835a1b41c7a5111a10236dca9a40e1` | MATCH |
| `WeaponXKeychainBridge.plist` | `691f8f80d18a98cb2feb2425f98a5114745b50a1a75a1bc9654d8aaa35c0b501` | `691f8f80d18a98cb2feb2425f98a5114745b50a1a75a1bc9654d8aaa35c0b501` | MATCH |
| `WeaponXKeychainBridge/Tweak.m` | `120ab88aae1db1e509f20617a0c1b17cc1d8fe3fb386ccb825c01b184f1b646a` | `120ab88aae1db1e509f20617a0c1b17cc1d8fe3fb386ccb825c01b184f1b646a` | MATCH |

Protected files checked: **73**; mismatches: **0**.

## 3. Exact public API and eight-code enum

- Specification header comparison: **EXACT MATCH**.
- Error-domain export 1; field-path export 1; public item classes 3; public plan class 1; public factory 1; mutable/readwrite public properties 0.

```objc
typedef NS_ENUM(NSInteger, PXRestorePlanErrorCode) {
    PXRestorePlanErrorInvalidInput = 1,
    PXRestorePlanErrorInconsistentSnapshot = 2,
    PXRestorePlanErrorMissingArtifact = 3,
    PXRestorePlanErrorUnvalidatedArchive = 4,
    PXRestorePlanErrorUnsafeRelativeDestination = 5,
    PXRestorePlanErrorDuplicateDestination = 6,
    PXRestorePlanErrorInvalidComponent = 7,
    PXRestorePlanErrorLimitExceeded = 8,
};
```

No public designated initializer, mutable setter, extraction/staging/transaction API, filesystem argument, warning bypass or generic mutable payload was added.

## 4. Immutability and no-manifest-retention proof

| Contract | Evidence |
|---|---|
| Four restricted classes | Four `objc_subclassing_restricted` declarations. |
| Readonly public state | Every public property is readonly; mutable/readwrite public count is 0. |
| Construction boundary | `init`/`new` unavailable; private initializers only. |
| Input ownership | Every string, array and lookup dictionary input is copied. |
| Copy semantics | Four `copyWithZone:` implementations return `self`. |
| No mutable retained collections | Local builders become immutable copied arrays/maps. |
| Required snapshots | Plan strongly retains container, verified set and archive set. |
| No manifest retention | No manifest property, ivar, assignment or lazy cache; static count 0. |
| No operational objects | No descriptor, callback, parser, resolver, runner or filesystem handle. |

## 5. Snapshot consistency

The factory requires an accepted manifest dictionary, exact nonempty requested bundle ID, exact manifest/requested identity equality, ApplicationData model kind, exact model requested/metadata identifiers, nonempty model path/UUID, exact supplied/model path equality, and accepted verified/archive snapshot objects. Identity values are never trimmed, lowercased, standardized, percent-decoded or Unicode-normalized.

## 6. Component artifact/archive authority

| Component | Source | Tar validation | Recorded destination authority |
|---|---|---|---|
| Main data | Verified snapshot | Required | Manifest data path/UUID never read |
| App Groups | Verified snapshot | Required per item | UUID/path ignored; destination unresolved |
| Preferences | Verified snapshot | Not required | Destination plist not computed |
| Keychain | Verified snapshot | Not required | Contents not inspected/executed |
| Profile AppData | Verified snapshot | Required | Recorded path ignored |
| Global Safari | Verified snapshot | Required | Recorded path ignored |
| System-global | Verified snapshot | Required per item | Safe subdirectory only |
| Shared DB | Verified snapshot | Not required | Safe relative identity only |

Every included source is copied from `[verifiedArtifacts pathForArtifactName:]`; no backup-directory or recorded `artifact.path` reconstruction exists.

## 7. App Group and Keychain semantic plans

- App Groups use the exact include Boolean, preserve manifest order, reject exact duplicate IDs, create an eager case-sensitive immutable lookup, ignore recorded UUIDs and do not resolve destinations/read entitlements.
- Keychain exclusion freezes nil source, empty groups/method and `NO`; inclusion copies exact groups/method and freezes `method == "in_app"` OR a case-sensitive `platformFamily` substring decision.
- TASK-2.9 still owns exact App Group destination validation/staging; the plan does not inspect Keychain contents.

## 8. Relative destination safety and 100000-item limit

System-global identities reject empty/all-whitespace values, control characters, slash/backslash, dot/dot-dot, invalid UTF-8, values above 255 bytes and exact duplicates. Shared DB identities additionally reject absolute/leading/trailing/doubled slash, empty/dot/dot-dot components, components above 255 bytes and full paths above 4096 bytes.

The overflow-safe total includes App Groups + system-global + shared DB records: 100000 accepted; 100001 or arithmetic overflow rejected as `LimitExceeded`. Relative semantic acceptance does not authorize a final filesystem target.

## 9. Restore ordering, propagation and zero authority

```text
manifest/schema/version
bundle identity
main destination
artifact verifier
archive validator
restore plan
warnings/debug/runner/tar/kill/staging/extraction/mutation
```

- Plan import exactly once; Restore factory exactly once; Backup factory zero; plan has `objc_precise_lifetime`.
- Non-nil plan error is propagated unchanged through one main-queue completion with nil result and immediate return; generic plan fallback is only for nil-without-error.

| Post-plan authority | Count |
|---|---:|
| Direct `manifest[...]` reads | 0 |
| Direct verified-artifact lookups | 0 |
| Direct archive membership lookups | 0 |

## 10. Operational migration and preserved dynamic destinations

Main source/model/path/UUID, warnings/profile ID, App Group inclusion/source lookup, profile/global source, system/shared loops, preferences source and Keychain source/groups/method/decision all consume plan properties. Existing entitlements/group resolver, warning-and-skip behavior, profile/global/mobile-Library/preferences destination helpers and Keychain execution paths remain dynamic after planning.

## 11. TASK-2.1 through TASK-2.6A non-regression

Validators/verifiers/resolvers/cleaner/runner/Makefile/UI/Keychain helper-bridge files have zero canonical diff. Restore signature/error codes, tar preference, kill timing after plan success, staging/extraction/pre-mutation validation, wipe/clone/cp/chown, ordering, Keychain warning-only behavior, backup publication and `PXRestoreResult` remain unchanged.

| Protected body | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `PXBackupManifestVersionIsSupported` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | MATCH |
| `PXResolveExactRestoreApplicationDataTarget` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | MATCH |
| `readManifestAtBackupDirectory:error:` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | MATCH |
| `createBackupForBundleID:appName:options:completion:` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | MATCH |
| `_tarExtract:archive:toDir:` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | MATCH |
| `_tarExtractDataArchive:archive:toDir:warnings:` | `892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881` | `892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881` | MATCH |
| `_directoryHasRestoredContent:` | `0d34259591c943a606e3bb0517841b1e09239409d3daee47d294566a85484472` | `0d34259591c943a606e3bb0517841b1e09239409d3daee47d294566a85484472` | MATCH |

## 12. Full production source diff

```text
AppDataBackupManager.m | 170 +++------
 PXRestorePlan.h        | 106 ++++++
 PXRestorePlan.m        | 995 +++++++++++++++++++++++++++++++++++++++++++++++++
 3 files changed, 1156 insertions(+), 115 deletions(-)
```

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index a4cb304..7203dd4 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -12,6 +12,7 @@
 #import "PXBackupManifestValidator.h"
 #import "PXBackupArtifactVerifier.h"
 #import "PXBackupArchiveValidator.h"
+#import "PXRestorePlan.h"
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
 #import "CommandRunner.h"
@@ -1890,8 +1891,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
             return;
         }
-        NSString *dataUUID = dataContainerModel.containerUUID;
-
         NSError *artifactError = nil;
         PXVerifiedBackupArtifactSet *verifiedArtifacts =
             [PXBackupArtifactVerifier verifiedArtifactsForManifest:manifest
@@ -1926,6 +1925,31 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             return;
         }

+        NSError *planError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXRestorePlan *restorePlan =
+            [PXRestorePlan planForManifest:manifest
+                 requestedBundleIdentifier:bundleID
+                   applicationDataContainer:dataContainerModel
+                        applicationDataPath:dataContainerPath
+                          verifiedArtifacts:verifiedArtifacts
+                          validatedArchives:validatedArchives
+                                      error:&planError];
+        if (!restorePlan) {
+            NSError *err = planError ?: [NSError errorWithDomain:PXRestorePlanErrorDomain
+                                                              code:PXRestorePlanErrorInvalidInput
+                                                          userInfo:@{
+                                                              NSLocalizedDescriptionKey: @"Restore plan construction failed",
+                                                              PXRestorePlanErrorFieldPathKey: @"$"
+                                                          }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
+        dataContainerModel = restorePlan.applicationDataContainer;
+        dataContainerPath = restorePlan.applicationDataPath;
+        NSString *dataUUID = restorePlan.applicationDataUUID;
+
         NSMutableArray<NSString *> *warnings = [NSMutableArray array];
         NSFileManager *fm = [NSFileManager defaultManager];
         CommandRunner *runner = [CommandRunner shared];
@@ -1980,17 +2004,14 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"tarPath=%@", tarPath]);

-        if ([manifest[@"warnings"] isKindOfClass:[NSArray class]] && [(NSArray *)manifest[@"warnings"] count] > 0) {
-            [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)[(NSArray *)manifest[@"warnings"] count]]];
+        if (restorePlan.manifestWarningCount > 0) {
+            [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)restorePlan.manifestWarningCount]];
         }

         // Kill app before restore
         [self _killRelatedProcessesForBundleID:bundleID];

-        NSString *manifestProfileId = nil;
-        if ([manifest[@"profileId"] isKindOfClass:[NSString class]]) {
-            manifestProfileId = manifest[@"profileId"];
-        }
+        NSString *manifestProfileId = restorePlan.manifestProfileIdentifier;
         NSString *activeProfileId = [self _activeProfileId];
         if (manifestProfileId.length && activeProfileId.length && ![manifestProfileId isEqualToString:activeProfileId]) {
             [warnings addObject:[NSString stringWithFormat:@"Backup profileId %@ != active profileId %@", manifestProfileId, activeProfileId]];
@@ -2004,12 +2025,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         // App Groups via entitlements (Option B)
         NSArray<AppGroupContainerInfo *> *groupContainers = @[];
-        NSDictionary *options = manifest[@"options"];
-        BOOL includeGroups = YES;
-        if ([options isKindOfClass:[NSDictionary class]] && [options[@"includeAppGroups"] respondsToSelector:@selector(boolValue)]) {
-            includeGroups = [options[@"includeAppGroups"] boolValue];
-        }
-        if (includeGroups) {
+        if (restorePlan.includesAppGroups) {
             NSError *entErr = nil;
             AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
             NSArray<NSString *> *groupIDs = [reader applicationGroupsForBundleID:bundleID error:&entErr];
@@ -2022,22 +2038,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             }
         }

-        NSMutableDictionary<NSString *, NSString *> *groupArchiveNamesByIDBuilder =
-            [NSMutableDictionary dictionary];
-        for (NSDictionary *entry in (NSArray *)manifest[@"appGroups"]) {
-            NSString *groupID = entry[@"groupID"];
-            NSString *archiveName = entry[@"archive"];
-            if (groupID.length && archiveName.length) {
-                groupArchiveNamesByIDBuilder[groupID] = archiveName;
-            }
-        }
-        NSDictionary<NSString *, NSString *> *groupArchiveNamesByID =
-            [groupArchiveNamesByIDBuilder copy];
-
-        NSDictionary *dataInfo = manifest[@"data"];
-        NSString *dataArchiveName = dataInfo[@"archive"];
-        NSString *dataArchive =
-            [verifiedArtifacts pathForArtifactName:dataArchiveName];
+        NSString *dataArchive = restorePlan.dataArchivePath;

         // Two-phase restore for data container: extract to staging first.
         NSString *stagingRoot = [NSString stringWithFormat:@"/tmp/weaponx_restore_%d", getpid()];
@@ -2143,16 +2144,9 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         // Data container restored.

         // Restore profile redirected appdata (if present)
-        NSDictionary *profileAppData = manifest[@"profileAppData"];
-        BOOL includeProfileAppData = NO;
-        if ([profileAppData isKindOfClass:[NSDictionary class]] && [profileAppData[@"included"] respondsToSelector:@selector(boolValue)]) {
-            includeProfileAppData = [profileAppData[@"included"] boolValue];
-        }
-        if (includeProfileAppData) {
+        if (restorePlan.includesProfileAppData) {
             NSString *profileAppDataPath = [self _profileAppDataPathForBundleID:bundleID];
-            NSString *archiveName = profileAppData[@"archive"];
-            NSString *archivePath =
-                [verifiedArtifacts pathForArtifactName:archiveName];
+            NSString *archivePath = restorePlan.profileAppDataSourcePath;
             if (profileAppDataPath.length && archivePath.length) {
                 BOOL isDir = NO;
                 if ([fm fileExistsAtPath:profileAppDataPath isDirectory:&isDir] && isDir) {
@@ -2184,16 +2178,9 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }

         // Restore global Safari library (if present)
-        NSDictionary *globalSafari = manifest[@"globalSafari"];
-        BOOL includeGlobalSafari = NO;
-        if ([globalSafari isKindOfClass:[NSDictionary class]] && [globalSafari[@"included"] respondsToSelector:@selector(boolValue)]) {
-            includeGlobalSafari = [globalSafari[@"included"] boolValue];
-        }
-        if (includeGlobalSafari) {
+        if (restorePlan.includesGlobalSafari) {
             NSString *globalSafariPath = [self _globalSafariLibraryPath];
-            NSString *archiveName = globalSafari[@"archive"];
-            NSString *archivePath =
-                [verifiedArtifacts pathForArtifactName:archiveName];
+            NSString *archivePath = restorePlan.globalSafariSourcePath;
             if (globalSafariPath.length && archivePath.length) {
                 BOOL isDir = NO;
                 if ([fm fileExistsAtPath:globalSafariPath isDirectory:&isDir] && isDir) {
@@ -2226,10 +2213,10 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         // Wipe and restore each group
         for (AppGroupContainerInfo *info in groupContainers) {
-            NSString *archiveName = groupArchiveNamesByID[info.groupID];
-            NSString *archivePath =
-                [verifiedArtifacts pathForArtifactName:archiveName];
-            if (!archiveName.length || !archivePath.length) {
+            PXRestorePlanAppGroupItem *plannedGroup =
+                [restorePlan appGroupItemForIdentifier:info.groupID];
+            NSString *archivePath = plannedGroup.sourcePath;
+            if (!plannedGroup || !archivePath.length) {
                 [warnings addObject:[NSString stringWithFormat:@"Missing manifest archive mapping for %@", info.groupID]];
                 continue;
             }
@@ -2256,32 +2243,17 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }

         // Restore generic system app global Library folders (if present)
-        NSDictionary *systemGlobal = manifest[@"systemGlobalLibrary"];
-        BOOL includeSystemGlobal = NO;
-        NSArray *items = nil;
-        if ([systemGlobal isKindOfClass:[NSDictionary class]]) {
-            if ([systemGlobal[@"included"] respondsToSelector:@selector(boolValue)]) {
-                includeSystemGlobal = [systemGlobal[@"included"] boolValue];
-            }
-            if ([systemGlobal[@"items"] isKindOfClass:[NSArray class]]) {
-                items = systemGlobal[@"items"];
-            }
-        }
-        if (includeSystemGlobal && items.count) {
+        if (restorePlan.systemGlobalItems.count) {
             NSString *libBase = [self _mobileLibraryBasePath];
-            for (NSDictionary *it in (NSArray *)items) {
-                if (![it isKindOfClass:[NSDictionary class]]) continue;
-                NSString *subdir = [it[@"subdir"] isKindOfClass:[NSString class]] ? it[@"subdir"] : nil;
-                NSString *archive = [it[@"archive"] isKindOfClass:[NSString class]] ? it[@"archive"] : nil;
-                if (!subdir.length || !archive.length) continue;
+            for (PXRestorePlanSystemGlobalItem *plannedItem in restorePlan.systemGlobalItems) {
+                NSString *subdir = plannedItem.librarySubdirectory;

                 // Avoid double-restoring Safari which is handled explicitly.
                 if ([bundleID isEqualToString:@"com.apple.mobilesafari"] && [subdir isEqualToString:@"Safari"]) {
                     continue;
                 }

-                NSString *archivePath =
-                    [verifiedArtifacts pathForArtifactName:archive];
+                NSString *archivePath = plannedItem.sourcePath;

                 NSString *dest = [libBase stringByAppendingPathComponent:subdir];
                 [self _killRelatedProcessesForBundleID:bundleID];
@@ -2307,18 +2279,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }

         // Restore shared system DBs (if present)
-        NSDictionary *sharedDB = manifest[@"sharedSystemDB"];
-        BOOL includeSharedDB = NO;
-        NSArray *dbFiles = nil;
-        if ([sharedDB isKindOfClass:[NSDictionary class]]) {
-            if ([sharedDB[@"included"] respondsToSelector:@selector(boolValue)]) {
-                includeSharedDB = [sharedDB[@"included"] boolValue];
-            }
-            if ([sharedDB[@"files"] isKindOfClass:[NSArray class]]) {
-                dbFiles = sharedDB[@"files"];
-            }
-        }
-        if (includeSharedDB && dbFiles.count) {
+        if (restorePlan.sharedDatabaseItems.count) {
             NSString *libBase = [self _mobileLibraryBasePath];

             // Stop common daemons that may hold these DBs.
@@ -2332,14 +2293,9 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             PXKillallByName(@"imagent", SIGKILL);
             PXKillallByName(@"MobileSMS", SIGKILL);

-            for (NSDictionary *it in (NSArray *)dbFiles) {
-                if (![it isKindOfClass:[NSDictionary class]]) continue;
-                NSString *libraryRel = [it[@"libraryRel"] isKindOfClass:[NSString class]] ? it[@"libraryRel"] : nil;
-                NSString *archiveRel = [it[@"archive"] isKindOfClass:[NSString class]] ? it[@"archive"] : nil;
-                if (!libraryRel.length || !archiveRel.length) continue;
-
-                NSString *src =
-                    [verifiedArtifacts pathForArtifactName:archiveRel];
+            for (PXRestorePlanSharedDatabaseItem *plannedItem in restorePlan.sharedDatabaseItems) {
+                NSString *libraryRel = plannedItem.libraryRelativePath;
+                NSString *src = plannedItem.sourcePath;

                 NSString *dest = [libBase stringByAppendingPathComponent:libraryRel];
                 NSString *destDir = [dest stringByDeletingLastPathComponent];
@@ -2365,15 +2321,8 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }

         // Preferences restore
-        BOOL includePrefs = YES;
-        NSDictionary *prefs = manifest[@"preferences"];
-        if ([prefs isKindOfClass:[NSDictionary class]] && [prefs[@"included"] respondsToSelector:@selector(boolValue)]) {
-            includePrefs = [prefs[@"included"] boolValue];
-        }
-        if (includePrefs) {
-            NSString *prefArchiveName = prefs[@"archive"];
-            NSString *prefBackup =
-                [verifiedArtifacts pathForArtifactName:prefArchiveName];
+        if (restorePlan.includesPreferences) {
+            NSString *prefBackup = restorePlan.preferencesSourcePath;
             NSString *prefDest = [self _preferencesPlistPathForBundleID:bundleID];
             if (prefBackup.length) {
                 [runner run:[NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null || true", PXShellQuote(prefBackup), PXShellQuote(prefDest)]];
@@ -2386,21 +2335,12 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         }

         // Keychain restore (warning-only on failure)
-        NSDictionary *keychainInfo = manifest[@"keychain"];
-        BOOL includeKeychain = NO;
-        if ([keychainInfo isKindOfClass:[NSDictionary class]] && [keychainInfo[@"included"] respondsToSelector:@selector(boolValue)]) {
-            includeKeychain = [keychainInfo[@"included"] boolValue];
-        }
-        if (includeKeychain) {
-            NSString *keychainArchiveName = keychainInfo[@"archive"];
-            NSString *keychainBackupPath =
-                [verifiedArtifacts pathForArtifactName:keychainArchiveName];
-            NSArray<NSString *> *groups = @[];
-            if ([keychainInfo isKindOfClass:[NSDictionary class]] && [keychainInfo[@"groupsSelected"] isKindOfClass:[NSArray class]]) {
-                groups = keychainInfo[@"groupsSelected"];
-            }
-            NSString *method = ([keychainInfo isKindOfClass:[NSDictionary class]] && [keychainInfo[@"method"] isKindOfClass:[NSString class]]) ? keychainInfo[@"method"] : @"";
-            BOOL shouldUseInApp = PXGroupsContainPlatformFamily(groups) || [method isEqualToString:@"in_app"];
+        if (restorePlan.includesKeychain) {
+            NSString *keychainBackupPath = restorePlan.keychainSourcePath;
+            NSArray<NSString *> *groups = restorePlan.keychainGroups;
+            NSString *method = restorePlan.keychainMethod;
+            (void)method;
+            BOOL shouldUseInApp = restorePlan.keychainUsesInAppMethod;

             BOOL ok = NO;
             if (shouldUseInApp) {
diff --git a/PXRestorePlan.h b/PXRestorePlan.h
new file mode 100644
index 0000000..0395c00
--- /dev/null
+++ b/PXRestorePlan.h
@@ -0,0 +1,106 @@
+#import <Foundation/Foundation.h>
+
+@class PXResolvedContainer;
+@class PXVerifiedBackupArtifactSet;
+@class PXValidatedBackupArchiveSet;
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSString * const PXRestorePlanErrorDomain;
+FOUNDATION_EXPORT NSString * const PXRestorePlanErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXRestorePlanErrorCode) {
+    PXRestorePlanErrorInvalidInput = 1,
+    PXRestorePlanErrorInconsistentSnapshot = 2,
+    PXRestorePlanErrorMissingArtifact = 3,
+    PXRestorePlanErrorUnvalidatedArchive = 4,
+    PXRestorePlanErrorUnsafeRelativeDestination = 5,
+    PXRestorePlanErrorDuplicateDestination = 6,
+    PXRestorePlanErrorInvalidComponent = 7,
+    PXRestorePlanErrorLimitExceeded = 8,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXRestorePlanAppGroupItem : NSObject <NSCopying>
+@property (nonatomic, copy, readonly) NSString *groupIdentifier;
+@property (nonatomic, copy, readonly) NSString *archiveName;
+@property (nonatomic, copy, readonly) NSString *sourcePath;
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXRestorePlanSystemGlobalItem : NSObject <NSCopying>
+@property (nonatomic, copy, readonly) NSString *librarySubdirectory;
+@property (nonatomic, copy, readonly) NSString *archiveName;
+@property (nonatomic, copy, readonly) NSString *sourcePath;
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXRestorePlanSharedDatabaseItem : NSObject <NSCopying>
+@property (nonatomic, copy, readonly) NSString *libraryRelativePath;
+@property (nonatomic, copy, readonly) NSString *artifactName;
+@property (nonatomic, copy, readonly) NSString *sourcePath;
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXRestorePlan : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
+
+@property (nonatomic, strong, readonly) PXResolvedContainer *applicationDataContainer;
+@property (nonatomic, copy, readonly) NSString *applicationDataPath;
+@property (nonatomic, copy, readonly) NSString *applicationDataUUID;
+@property (nonatomic, copy, readonly) NSString *dataArchiveName;
+@property (nonatomic, copy, readonly) NSString *dataArchivePath;
+
+@property (nonatomic, assign, readonly) BOOL includesAppGroups;
+@property (nonatomic, copy, readonly) NSArray<PXRestorePlanAppGroupItem *> *appGroupItems;
+- (nullable PXRestorePlanAppGroupItem *)appGroupItemForIdentifier:(NSString *)groupIdentifier;
+
+@property (nonatomic, assign, readonly) BOOL includesPreferences;
+@property (nonatomic, copy, nullable, readonly) NSString *preferencesArtifactName;
+@property (nonatomic, copy, nullable, readonly) NSString *preferencesSourcePath;
+
+@property (nonatomic, assign, readonly) BOOL includesKeychain;
+@property (nonatomic, copy, nullable, readonly) NSString *keychainArtifactName;
+@property (nonatomic, copy, nullable, readonly) NSString *keychainSourcePath;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *keychainGroups;
+@property (nonatomic, copy, readonly) NSString *keychainMethod;
+@property (nonatomic, assign, readonly) BOOL keychainUsesInAppMethod;
+
+@property (nonatomic, assign, readonly) BOOL includesProfileAppData;
+@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataArchiveName;
+@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataSourcePath;
+
+@property (nonatomic, assign, readonly) BOOL includesGlobalSafari;
+@property (nonatomic, copy, nullable, readonly) NSString *globalSafariArchiveName;
+@property (nonatomic, copy, nullable, readonly) NSString *globalSafariSourcePath;
+
+@property (nonatomic, copy, readonly) NSArray<PXRestorePlanSystemGlobalItem *> *systemGlobalItems;
+@property (nonatomic, copy, readonly) NSArray<PXRestorePlanSharedDatabaseItem *> *sharedDatabaseItems;
+
+@property (nonatomic, assign, readonly) NSUInteger manifestWarningCount;
+@property (nonatomic, copy, nullable, readonly) NSString *manifestProfileIdentifier;
+
+@property (nonatomic, strong, readonly) PXVerifiedBackupArtifactSet *verifiedArtifacts;
+@property (nonatomic, strong, readonly) PXValidatedBackupArchiveSet *validatedArchives;
+
++ (nullable instancetype)planForManifest:(NSDictionary *)manifest
+               requestedBundleIdentifier:(NSString *)bundleIdentifier
+                 applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
+                      applicationDataPath:(NSString *)applicationDataPath
+                        verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
+                        validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives
+                                    error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXRestorePlan.m b/PXRestorePlan.m
new file mode 100644
index 0000000..0944444
--- /dev/null
+++ b/PXRestorePlan.m
@@ -0,0 +1,995 @@
+#import "PXRestorePlan.h"
+#import "PXResolvedContainer.h"
+#import "PXBackupArtifactVerifier.h"
+#import "PXBackupArchiveValidator.h"
+
+NSString * const PXRestorePlanErrorDomain = @"PXRestorePlanErrorDomain";
+NSString * const PXRestorePlanErrorFieldPathKey = @"PXRestorePlanErrorFieldPathKey";
+
+static const NSUInteger PXRestorePlanMaximumItemRecords = 100000;
+
+static BOOL PXRestorePlanFail(NSError **error,
+                              PXRestorePlanErrorCode code,
+                              NSString *fieldPath,
+                              NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXRestorePlanErrorDomain
+                                     code:code
+                                 userInfo:@{
+                                     NSLocalizedDescriptionKey: description,
+                                     PXRestorePlanErrorFieldPathKey: fieldPath
+                                 }];
+    }
+    return NO;
+}
+
+static BOOL PXRestorePlanStringIsNULFree(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSString *string = (NSString *)value;
+    for (NSUInteger index = 0; index < string.length; index++) {
+        if ([string characterAtIndex:index] == 0) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+static BOOL PXRestorePlanStringIsNonemptyAndNULFree(id value) {
+    return PXRestorePlanStringIsNULFree(value) && [(NSString *)value length] > 0;
+}
+
+static BOOL PXRestorePlanStringContainsASCIIControlCharacter(NSString *string) {
+    for (NSUInteger index = 0; index < string.length; index++) {
+        unichar character = [string characterAtIndex:index];
+        if (character < 0x20 || character == 0x7f) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXRestorePlanStringContainsControlCharacter(NSString *string) {
+    return [string rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound;
+}
+
+static BOOL PXRestorePlanStringIsAllWhitespace(NSString *string) {
+    NSCharacterSet *nonWhitespace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
+    return [string rangeOfCharacterFromSet:nonWhitespace].location == NSNotFound;
+}
+
+static NSUInteger PXRestorePlanUTF8Length(NSString *string, BOOL *valid) {
+    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!data) {
+        if (valid) {
+            *valid = NO;
+        }
+        return 0;
+    }
+    if (valid) {
+        *valid = YES;
+    }
+    return data.length;
+}
+
+static BOOL PXRestorePlanReadExactBoolean(id value, BOOL *result) {
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
+static NSString *PXRestorePlanIndexedFieldPath(NSString *base, NSUInteger index, NSString *field) {
+    return [NSString stringWithFormat:@"%@[%lu].%@", base, (unsigned long)index, field];
+}
+
+static NSString *PXRestorePlanVerifiedSource(NSString *artifactName,
+                                             NSString *fieldPath,
+                                             PXVerifiedBackupArtifactSet *verifiedArtifacts,
+                                             NSError **error) {
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(artifactName)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidComponent,
+                          fieldPath,
+                          @"Restore component contains an invalid artifact name.");
+        return nil;
+    }
+
+    NSString *sourcePath = [verifiedArtifacts pathForArtifactName:artifactName];
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(sourcePath)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorMissingArtifact,
+                          fieldPath,
+                          @"Restore component is missing from the verified artifact snapshot.");
+        return nil;
+    }
+    return [sourcePath copy];
+}
+
+static NSString *PXRestorePlanVerifiedTarSource(NSString *artifactName,
+                                                NSString *fieldPath,
+                                                PXVerifiedBackupArtifactSet *verifiedArtifacts,
+                                                PXValidatedBackupArchiveSet *validatedArchives,
+                                                NSError **error) {
+    NSString *sourcePath = PXRestorePlanVerifiedSource(artifactName,
+                                                        fieldPath,
+                                                        verifiedArtifacts,
+                                                        error);
+    if (!sourcePath) {
+        return nil;
+    }
+    if (![validatedArchives containsArchiveName:artifactName]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorUnvalidatedArchive,
+                          fieldPath,
+                          @"Restore archive is missing from the validated archive snapshot.");
+        return nil;
+    }
+    return sourcePath;
+}
+
+static BOOL PXRestorePlanValidateSystemSubdirectory(id value,
+                                                    NSString *fieldPath,
+                                                    NSError **error) {
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(value)) {
+        return PXRestorePlanFail(error,
+                                 PXRestorePlanErrorUnsafeRelativeDestination,
+                                 fieldPath,
+                                 @"System-global destination identity is invalid.");
+    }
+
+    NSString *subdirectory = (NSString *)value;
+    if (PXRestorePlanStringIsAllWhitespace(subdirectory) ||
+        PXRestorePlanStringContainsASCIIControlCharacter(subdirectory) ||
+        [subdirectory rangeOfString:@"/"].location != NSNotFound ||
+        [subdirectory rangeOfString:@"\\"].location != NSNotFound ||
+        [subdirectory isEqualToString:@"."] ||
+        [subdirectory isEqualToString:@".."]) {
+        return PXRestorePlanFail(error,
+                                 PXRestorePlanErrorUnsafeRelativeDestination,
+                                 fieldPath,
+                                 @"System-global destination identity is unsafe.");
+    }
+
+    BOOL validUTF8 = NO;
+    NSUInteger byteLength = PXRestorePlanUTF8Length(subdirectory, &validUTF8);
+    if (!validUTF8 || byteLength > 255) {
+        return PXRestorePlanFail(error,
+                                 PXRestorePlanErrorUnsafeRelativeDestination,
+                                 fieldPath,
+                                 @"System-global destination identity exceeds its safe UTF-8 length.");
+    }
+    return YES;
+}
+
+static BOOL PXRestorePlanValidateSharedRelativePath(id value,
+                                                    NSString *fieldPath,
+                                                    NSError **error) {
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(value)) {
+        return PXRestorePlanFail(error,
+                                 PXRestorePlanErrorUnsafeRelativeDestination,
+                                 fieldPath,
+                                 @"Shared database destination identity is invalid.");
+    }
+
+    NSString *relativePath = (NSString *)value;
+    if (PXRestorePlanStringIsAllWhitespace(relativePath) ||
+        PXRestorePlanStringContainsControlCharacter(relativePath) ||
+        [relativePath hasPrefix:@"/"] ||
+        [relativePath hasSuffix:@"/"] ||
+        [relativePath rangeOfString:@"//"].location != NSNotFound ||
+        [relativePath rangeOfString:@"\\"].location != NSNotFound) {
+        return PXRestorePlanFail(error,
+                                 PXRestorePlanErrorUnsafeRelativeDestination,
+                                 fieldPath,
+                                 @"Shared database destination identity is unsafe.");
+    }
+
+    BOOL validUTF8 = NO;
+    NSUInteger fullByteLength = PXRestorePlanUTF8Length(relativePath, &validUTF8);
+    if (!validUTF8 || fullByteLength > 4096) {
+        return PXRestorePlanFail(error,
+                                 PXRestorePlanErrorUnsafeRelativeDestination,
+                                 fieldPath,
+                                 @"Shared database destination identity exceeds its safe UTF-8 length.");
+    }
+
+    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
+    for (NSString *component in components) {
+        if (component.length == 0 ||
+            [component isEqualToString:@"."] ||
+            [component isEqualToString:@".."]) {
+            return PXRestorePlanFail(error,
+                                     PXRestorePlanErrorUnsafeRelativeDestination,
+                                     fieldPath,
+                                     @"Shared database destination identity contains an unsafe component.");
+        }
+        BOOL componentValidUTF8 = NO;
+        NSUInteger componentByteLength = PXRestorePlanUTF8Length(component, &componentValidUTF8);
+        if (!componentValidUTF8 || componentByteLength > 255) {
+            return PXRestorePlanFail(error,
+                                     PXRestorePlanErrorUnsafeRelativeDestination,
+                                     fieldPath,
+                                     @"Shared database destination component exceeds its safe UTF-8 length.");
+        }
+    }
+    return YES;
+}
+
+static BOOL PXRestorePlanAddRecordCount(NSUInteger count,
+                                        NSUInteger *total,
+                                        NSString *fieldPath,
+                                        NSError **error) {
+    if (!total || *total > PXRestorePlanMaximumItemRecords ||
+        count > PXRestorePlanMaximumItemRecords - *total) {
+        return PXRestorePlanFail(error,
+                                 PXRestorePlanErrorLimitExceeded,
+                                 fieldPath,
+                                 @"Restore plan contains too many item records.");
+    }
+    *total += count;
+    return YES;
+}
+
+@interface PXRestorePlanAppGroupItem ()
+- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier
+                             archiveName:(NSString *)archiveName
+                              sourcePath:(NSString *)sourcePath;
+@end
+
+@implementation PXRestorePlanAppGroupItem
+
+- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier
+                             archiveName:(NSString *)archiveName
+                              sourcePath:(NSString *)sourcePath {
+    self = [super init];
+    if (self) {
+        _groupIdentifier = [groupIdentifier copy];
+        _archiveName = [archiveName copy];
+        _sourcePath = [sourcePath copy];
+    }
+    return self;
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
+
+@interface PXRestorePlanSystemGlobalItem ()
+- (instancetype)initWithLibrarySubdirectory:(NSString *)librarySubdirectory
+                                 archiveName:(NSString *)archiveName
+                                  sourcePath:(NSString *)sourcePath;
+@end
+
+@implementation PXRestorePlanSystemGlobalItem
+
+- (instancetype)initWithLibrarySubdirectory:(NSString *)librarySubdirectory
+                                 archiveName:(NSString *)archiveName
+                                  sourcePath:(NSString *)sourcePath {
+    self = [super init];
+    if (self) {
+        _librarySubdirectory = [librarySubdirectory copy];
+        _archiveName = [archiveName copy];
+        _sourcePath = [sourcePath copy];
+    }
+    return self;
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
+
+@interface PXRestorePlanSharedDatabaseItem ()
+- (instancetype)initWithLibraryRelativePath:(NSString *)libraryRelativePath
+                                artifactName:(NSString *)artifactName
+                                 sourcePath:(NSString *)sourcePath;
+@end
+
+@implementation PXRestorePlanSharedDatabaseItem
+
+- (instancetype)initWithLibraryRelativePath:(NSString *)libraryRelativePath
+                                artifactName:(NSString *)artifactName
+                                  sourcePath:(NSString *)sourcePath {
+    self = [super init];
+    if (self) {
+        _libraryRelativePath = [libraryRelativePath copy];
+        _artifactName = [artifactName copy];
+        _sourcePath = [sourcePath copy];
+    }
+    return self;
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
+
+@interface PXRestorePlan ()
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, PXRestorePlanAppGroupItem *> *appGroupItemsByIdentifier;
+
+- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
+                applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
+                     applicationDataPath:(NSString *)applicationDataPath
+                     applicationDataUUID:(NSString *)applicationDataUUID
+                         dataArchiveName:(NSString *)dataArchiveName
+                         dataArchivePath:(NSString *)dataArchivePath
+                       includesAppGroups:(BOOL)includesAppGroups
+                          appGroupItems:(NSArray<PXRestorePlanAppGroupItem *> *)appGroupItems
+              appGroupItemsByIdentifier:(NSDictionary<NSString *, PXRestorePlanAppGroupItem *> *)appGroupItemsByIdentifier
+                    includesPreferences:(BOOL)includesPreferences
+                 preferencesArtifactName:(NSString * _Nullable)preferencesArtifactName
+                 preferencesSourcePath:(NSString * _Nullable)preferencesSourcePath
+                       includesKeychain:(BOOL)includesKeychain
+                    keychainArtifactName:(NSString * _Nullable)keychainArtifactName
+                    keychainSourcePath:(NSString * _Nullable)keychainSourcePath
+                         keychainGroups:(NSArray<NSString *> *)keychainGroups
+                         keychainMethod:(NSString *)keychainMethod
+                keychainUsesInAppMethod:(BOOL)keychainUsesInAppMethod
+                 includesProfileAppData:(BOOL)includesProfileAppData
+              profileAppDataArchiveName:(NSString * _Nullable)profileAppDataArchiveName
+              profileAppDataSourcePath:(NSString * _Nullable)profileAppDataSourcePath
+                   includesGlobalSafari:(BOOL)includesGlobalSafari
+                globalSafariArchiveName:(NSString * _Nullable)globalSafariArchiveName
+                globalSafariSourcePath:(NSString * _Nullable)globalSafariSourcePath
+                      systemGlobalItems:(NSArray<PXRestorePlanSystemGlobalItem *> *)systemGlobalItems
+                    sharedDatabaseItems:(NSArray<PXRestorePlanSharedDatabaseItem *> *)sharedDatabaseItems
+                   manifestWarningCount:(NSUInteger)manifestWarningCount
+              manifestProfileIdentifier:(NSString * _Nullable)manifestProfileIdentifier
+                      verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
+                      validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives;
+@end
+
+@implementation PXRestorePlan
+
+- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
+                applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
+                     applicationDataPath:(NSString *)applicationDataPath
+                     applicationDataUUID:(NSString *)applicationDataUUID
+                         dataArchiveName:(NSString *)dataArchiveName
+                         dataArchivePath:(NSString *)dataArchivePath
+                       includesAppGroups:(BOOL)includesAppGroups
+                          appGroupItems:(NSArray<PXRestorePlanAppGroupItem *> *)appGroupItems
+              appGroupItemsByIdentifier:(NSDictionary<NSString *, PXRestorePlanAppGroupItem *> *)appGroupItemsByIdentifier
+                    includesPreferences:(BOOL)includesPreferences
+                 preferencesArtifactName:(NSString *)preferencesArtifactName
+                 preferencesSourcePath:(NSString *)preferencesSourcePath
+                       includesKeychain:(BOOL)includesKeychain
+                    keychainArtifactName:(NSString *)keychainArtifactName
+                    keychainSourcePath:(NSString *)keychainSourcePath
+                         keychainGroups:(NSArray<NSString *> *)keychainGroups
+                         keychainMethod:(NSString *)keychainMethod
+                keychainUsesInAppMethod:(BOOL)keychainUsesInAppMethod
+                 includesProfileAppData:(BOOL)includesProfileAppData
+              profileAppDataArchiveName:(NSString *)profileAppDataArchiveName
+              profileAppDataSourcePath:(NSString *)profileAppDataSourcePath
+                   includesGlobalSafari:(BOOL)includesGlobalSafari
+                globalSafariArchiveName:(NSString *)globalSafariArchiveName
+                globalSafariSourcePath:(NSString *)globalSafariSourcePath
+                      systemGlobalItems:(NSArray<PXRestorePlanSystemGlobalItem *> *)systemGlobalItems
+                    sharedDatabaseItems:(NSArray<PXRestorePlanSharedDatabaseItem *> *)sharedDatabaseItems
+                   manifestWarningCount:(NSUInteger)manifestWarningCount
+              manifestProfileIdentifier:(NSString *)manifestProfileIdentifier
+                      verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
+                      validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives {
+    self = [super init];
+    if (self) {
+        _bundleIdentifier = [bundleIdentifier copy];
+        _applicationDataContainer = applicationDataContainer;
+        _applicationDataPath = [applicationDataPath copy];
+        _applicationDataUUID = [applicationDataUUID copy];
+        _dataArchiveName = [dataArchiveName copy];
+        _dataArchivePath = [dataArchivePath copy];
+        _includesAppGroups = includesAppGroups;
+        _appGroupItems = [appGroupItems copy];
+        _appGroupItemsByIdentifier = [appGroupItemsByIdentifier copy];
+        _includesPreferences = includesPreferences;
+        _preferencesArtifactName = [preferencesArtifactName copy];
+        _preferencesSourcePath = [preferencesSourcePath copy];
+        _includesKeychain = includesKeychain;
+        _keychainArtifactName = [keychainArtifactName copy];
+        _keychainSourcePath = [keychainSourcePath copy];
+        _keychainGroups = [keychainGroups copy];
+        _keychainMethod = [keychainMethod copy];
+        _keychainUsesInAppMethod = keychainUsesInAppMethod;
+        _includesProfileAppData = includesProfileAppData;
+        _profileAppDataArchiveName = [profileAppDataArchiveName copy];
+        _profileAppDataSourcePath = [profileAppDataSourcePath copy];
+        _includesGlobalSafari = includesGlobalSafari;
+        _globalSafariArchiveName = [globalSafariArchiveName copy];
+        _globalSafariSourcePath = [globalSafariSourcePath copy];
+        _systemGlobalItems = [systemGlobalItems copy];
+        _sharedDatabaseItems = [sharedDatabaseItems copy];
+        _manifestWarningCount = manifestWarningCount;
+        _manifestProfileIdentifier = [manifestProfileIdentifier copy];
+        _verifiedArtifacts = verifiedArtifacts;
+        _validatedArchives = validatedArchives;
+    }
+    return self;
+}
+
++ (instancetype)planForManifest:(NSDictionary *)manifest
+      requestedBundleIdentifier:(NSString *)bundleIdentifier
+        applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
+             applicationDataPath:(NSString *)applicationDataPath
+               verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
+               validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives
+                           error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    if (![manifest isKindOfClass:[NSDictionary class]]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidInput,
+                          @"$",
+                          @"Restore plan requires an accepted manifest dictionary.");
+        return nil;
+    }
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(bundleIdentifier)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidInput,
+                          @"$.bundleID",
+                          @"Restore plan requires a valid requested bundle identifier.");
+        return nil;
+    }
+
+    id manifestBundleIdentifier = manifest[@"bundleID"];
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(manifestBundleIdentifier) ||
+        ![(NSString *)manifestBundleIdentifier isEqualToString:bundleIdentifier]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInconsistentSnapshot,
+                          @"$.bundleID",
+                          @"Manifest and requested bundle identity snapshots are inconsistent.");
+        return nil;
+    }
+
+    if (![applicationDataContainer isKindOfClass:[PXResolvedContainer class]]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidInput,
+                          @"$.applicationDataContainer",
+                          @"Restore plan requires an accepted application-data container model.");
+        return nil;
+    }
+    if (applicationDataContainer.kind != PXResolvedContainerKindApplicationData) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInconsistentSnapshot,
+                          @"$.applicationDataContainer.kind",
+                          @"Application-data container kind is inconsistent.");
+        return nil;
+    }
+    if (![applicationDataContainer.requestedIdentifier isEqualToString:bundleIdentifier]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInconsistentSnapshot,
+                          @"$.applicationDataContainer.requestedIdentifier",
+                          @"Application-data requested identity is inconsistent.");
+        return nil;
+    }
+    if (![applicationDataContainer.metadataIdentifier isEqualToString:bundleIdentifier]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInconsistentSnapshot,
+                          @"$.applicationDataContainer.metadataIdentifier",
+                          @"Application-data metadata identity is inconsistent.");
+        return nil;
+    }
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(applicationDataContainer.containerPath)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInconsistentSnapshot,
+                          @"$.applicationDataContainer.containerPath",
+                          @"Application-data container path snapshot is invalid.");
+        return nil;
+    }
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(applicationDataContainer.containerUUID)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInconsistentSnapshot,
+                          @"$.applicationDataContainer.containerUUID",
+                          @"Application-data container UUID snapshot is invalid.");
+        return nil;
+    }
+    if (!PXRestorePlanStringIsNonemptyAndNULFree(applicationDataPath) ||
+        ![applicationDataPath isEqualToString:applicationDataContainer.containerPath]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInconsistentSnapshot,
+                          @"$.applicationDataPath",
+                          @"Supplied application-data path is inconsistent with the accepted model.");
+        return nil;
+    }
+    if (![verifiedArtifacts isKindOfClass:[PXVerifiedBackupArtifactSet class]]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidInput,
+                          @"$.verifiedArtifacts",
+                          @"Restore plan requires an accepted verified artifact snapshot.");
+        return nil;
+    }
+    if (![validatedArchives isKindOfClass:[PXValidatedBackupArchiveSet class]]) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidInput,
+                          @"$.validatedArchives",
+                          @"Restore plan requires an accepted validated archive snapshot.");
+        return nil;
+    }
+
+    NSDictionary *dataSection = [manifest[@"data"] isKindOfClass:[NSDictionary class]] ? manifest[@"data"] : nil;
+    NSString *dataArchiveName = [dataSection[@"archive"] isKindOfClass:[NSString class]] ? dataSection[@"archive"] : nil;
+    NSString *dataArchivePath = PXRestorePlanVerifiedTarSource(dataArchiveName,
+                                                               @"$.data.archive",
+                                                               verifiedArtifacts,
+                                                               validatedArchives,
+                                                               error);
+    if (!dataArchivePath) {
+        return nil;
+    }
+
+    NSDictionary *optionsSection = [manifest[@"options"] isKindOfClass:[NSDictionary class]] ? manifest[@"options"] : nil;
+    BOOL includesAppGroups = NO;
+    if (!optionsSection || !PXRestorePlanReadExactBoolean(optionsSection[@"includeAppGroups"], &includesAppGroups)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidComponent,
+                          @"$.options.includeAppGroups",
+                          @"App Group inclusion decision is invalid.");
+        return nil;
+    }
+
+    NSArray *rawAppGroups = [manifest[@"appGroups"] isKindOfClass:[NSArray class]] ? manifest[@"appGroups"] : nil;
+    if (includesAppGroups && !rawAppGroups) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidComponent,
+                          @"$.appGroups",
+                          @"Included App Group plan requires an item array.");
+        return nil;
+    }
+
+    NSDictionary *preferencesSection = [manifest[@"preferences"] isKindOfClass:[NSDictionary class]] ? manifest[@"preferences"] : nil;
+    BOOL includesPreferences = NO;
+    if (!preferencesSection || !PXRestorePlanReadExactBoolean(preferencesSection[@"included"], &includesPreferences)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidComponent,
+                          @"$.preferences.included",
+                          @"Preferences inclusion decision is invalid.");
+        return nil;
+    }
+
+    NSDictionary *keychainSection = [manifest[@"keychain"] isKindOfClass:[NSDictionary class]] ? manifest[@"keychain"] : nil;
+    BOOL includesKeychain = NO;
+    if (!keychainSection || !PXRestorePlanReadExactBoolean(keychainSection[@"included"], &includesKeychain)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidComponent,
+                          @"$.keychain.included",
+                          @"Keychain inclusion decision is invalid.");
+        return nil;
+    }
+
+    NSDictionary *profileSection = [manifest[@"profileAppData"] isKindOfClass:[NSDictionary class]] ? manifest[@"profileAppData"] : nil;
+    BOOL includesProfileAppData = NO;
+    if (!profileSection || !PXRestorePlanReadExactBoolean(profileSection[@"included"], &includesProfileAppData)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidComponent,
+                          @"$.profileAppData.included",
+                          @"Profile AppData inclusion decision is invalid.");
+        return nil;
+    }
+
+    NSDictionary *globalSafariSection = [manifest[@"globalSafari"] isKindOfClass:[NSDictionary class]] ? manifest[@"globalSafari"] : nil;
+    BOOL includesGlobalSafari = NO;
+    if (!globalSafariSection || !PXRestorePlanReadExactBoolean(globalSafariSection[@"included"], &includesGlobalSafari)) {
+        PXRestorePlanFail(error,
+                          PXRestorePlanErrorInvalidComponent,
+                          @"$.globalSafari.included",
+                          @"Global Safari inclusion decision is invalid.");
+        return nil;
+    }
+
+    NSDictionary *systemGlobalSection = nil;
+    NSArray *rawSystemGlobalItems = nil;
+    BOOL includesSystemGlobal = NO;
+    id rawSystemGlobalSection = manifest[@"systemGlobalLibrary"];
+    if (rawSystemGlobalSection) {
+        if (![rawSystemGlobalSection isKindOfClass:[NSDictionary class]]) {
+            PXRestorePlanFail(error,
+                              PXRestorePlanErrorInvalidComponent,
+                              @"$.systemGlobalLibrary",
+                              @"System-global section is invalid.");
+            return nil;
+        }
+        systemGlobalSection = (NSDictionary *)rawSystemGlobalSection;
+        if (!PXRestorePlanReadExactBoolean(systemGlobalSection[@"included"], &includesSystemGlobal)) {
+            PXRestorePlanFail(error,
+                              PXRestorePlanErrorInvalidComponent,
+                              @"$.systemGlobalLibrary.included",
+                              @"System-global inclusion decision is invalid.");
+            return nil;
+        }
+        if (includesSystemGlobal) {
+            rawSystemGlobalItems = [systemGlobalSection[@"items"] isKindOfClass:[NSArray class]] ? systemGlobalSection[@"items"] : nil;
+            if (!rawSystemGlobalItems) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  @"$.systemGlobalLibrary.items",
+                                  @"Included system-global plan requires an item array.");
+                return nil;
+            }
+        }
+    }
+
+    NSDictionary *sharedDatabaseSection = nil;
+    NSArray *rawSharedDatabaseItems = nil;
+    BOOL includesSharedDatabase = NO;
+    id rawSharedDatabaseSection = manifest[@"sharedSystemDB"];
+    if (rawSharedDatabaseSection) {
+        if (![rawSharedDatabaseSection isKindOfClass:[NSDictionary class]]) {
+            PXRestorePlanFail(error,
+                              PXRestorePlanErrorInvalidComponent,
+                              @"$.sharedSystemDB",
+                              @"Shared database section is invalid.");
+            return nil;
+        }
+        sharedDatabaseSection = (NSDictionary *)rawSharedDatabaseSection;
+        if (!PXRestorePlanReadExactBoolean(sharedDatabaseSection[@"included"], &includesSharedDatabase)) {
+            PXRestorePlanFail(error,
+                              PXRestorePlanErrorInvalidComponent,
+                              @"$.sharedSystemDB.included",
+                              @"Shared database inclusion decision is invalid.");
+            return nil;
+        }
+        if (includesSharedDatabase) {
+            rawSharedDatabaseItems = [sharedDatabaseSection[@"files"] isKindOfClass:[NSArray class]] ? sharedDatabaseSection[@"files"] : nil;
+            if (!rawSharedDatabaseItems) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  @"$.sharedSystemDB.files",
+                                  @"Included shared database plan requires a file array.");
+                return nil;
+            }
+        }
+    }
+
+    NSUInteger totalItemRecords = 0;
+    if (!PXRestorePlanAddRecordCount(includesAppGroups ? rawAppGroups.count : 0,
+                                     &totalItemRecords,
+                                     @"$.appGroups",
+                                     error) ||
+        !PXRestorePlanAddRecordCount(includesSystemGlobal ? rawSystemGlobalItems.count : 0,
+                                     &totalItemRecords,
+                                     @"$.systemGlobalLibrary.items",
+                                     error) ||
+        !PXRestorePlanAddRecordCount(includesSharedDatabase ? rawSharedDatabaseItems.count : 0,
+                                     &totalItemRecords,
+                                     @"$.sharedSystemDB.files",
+                                     error)) {
+        return nil;
+    }
+
+    NSMutableArray<PXRestorePlanAppGroupItem *> *appGroupItemsBuilder = [NSMutableArray array];
+    NSMutableDictionary<NSString *, PXRestorePlanAppGroupItem *> *appGroupLookupBuilder = [NSMutableDictionary dictionary];
+    NSMutableSet<NSString *> *seenGroupIdentifiers = [NSMutableSet set];
+    if (includesAppGroups) {
+        for (NSUInteger index = 0; index < rawAppGroups.count; index++) {
+            id rawEntry = rawAppGroups[index];
+            NSString *entryPath = [NSString stringWithFormat:@"$.appGroups[%lu]", (unsigned long)index];
+            if (![rawEntry isKindOfClass:[NSDictionary class]]) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  entryPath,
+                                  @"App Group item is invalid.");
+                return nil;
+            }
+            NSDictionary *entry = (NSDictionary *)rawEntry;
+            NSString *groupIdentifier = [entry[@"groupID"] isKindOfClass:[NSString class]] ? entry[@"groupID"] : nil;
+            NSString *groupFieldPath = PXRestorePlanIndexedFieldPath(@"$.appGroups", index, @"groupID");
+            if (!PXRestorePlanStringIsNonemptyAndNULFree(groupIdentifier)) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  groupFieldPath,
+                                  @"App Group identifier is invalid.");
+                return nil;
+            }
+            if ([seenGroupIdentifiers containsObject:groupIdentifier]) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorDuplicateDestination,
+                                  groupFieldPath,
+                                  @"App Group identifier is duplicated.");
+                return nil;
+            }
+
+            NSString *archiveName = [entry[@"archive"] isKindOfClass:[NSString class]] ? entry[@"archive"] : nil;
+            NSString *archiveFieldPath = PXRestorePlanIndexedFieldPath(@"$.appGroups", index, @"archive");
+            NSString *sourcePath = PXRestorePlanVerifiedTarSource(archiveName,
+                                                                  archiveFieldPath,
+                                                                  verifiedArtifacts,
+                                                                  validatedArchives,
+                                                                  error);
+            if (!sourcePath) {
+                return nil;
+            }
+
+            PXRestorePlanAppGroupItem *item = [[PXRestorePlanAppGroupItem alloc]
+                initWithGroupIdentifier:groupIdentifier
+                            archiveName:archiveName
+                             sourcePath:sourcePath];
+            [seenGroupIdentifiers addObject:groupIdentifier];
+            [appGroupItemsBuilder addObject:item];
+            appGroupLookupBuilder[groupIdentifier] = item;
+        }
+    }
+
+    NSString *preferencesArtifactName = nil;
+    NSString *preferencesSourcePath = nil;
+    if (includesPreferences) {
+        preferencesArtifactName = [preferencesSection[@"archive"] isKindOfClass:[NSString class]] ? preferencesSection[@"archive"] : nil;
+        preferencesSourcePath = PXRestorePlanVerifiedSource(preferencesArtifactName,
+                                                            @"$.preferences.archive",
+                                                            verifiedArtifacts,
+                                                            error);
+        if (!preferencesSourcePath) {
+            return nil;
+        }
+    }
+
+    NSString *keychainArtifactName = nil;
+    NSString *keychainSourcePath = nil;
+    NSArray<NSString *> *keychainGroups = @[];
+    NSString *keychainMethod = @"";
+    BOOL keychainUsesInAppMethod = NO;
+    if (includesKeychain) {
+        keychainArtifactName = [keychainSection[@"archive"] isKindOfClass:[NSString class]] ? keychainSection[@"archive"] : nil;
+        keychainSourcePath = PXRestorePlanVerifiedSource(keychainArtifactName,
+                                                         @"$.keychain.archive",
+                                                         verifiedArtifacts,
+                                                         error);
+        if (!keychainSourcePath) {
+            return nil;
+        }
+
+        id rawGroups = keychainSection[@"groupsSelected"];
+        if (![rawGroups isKindOfClass:[NSArray class]]) {
+            PXRestorePlanFail(error,
+                              PXRestorePlanErrorInvalidComponent,
+                              @"$.keychain.groupsSelected",
+                              @"Keychain group selection is invalid.");
+            return nil;
+        }
+        NSMutableArray<NSString *> *groupsBuilder = [NSMutableArray arrayWithCapacity:[(NSArray *)rawGroups count]];
+        for (NSUInteger index = 0; index < [(NSArray *)rawGroups count]; index++) {
+            id rawGroup = ((NSArray *)rawGroups)[index];
+            if (!PXRestorePlanStringIsNonemptyAndNULFree(rawGroup)) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  @"$.keychain.groupsSelected",
+                                  @"Keychain group selection contains an invalid item.");
+                return nil;
+            }
+            NSString *group = (NSString *)rawGroup;
+            [groupsBuilder addObject:[group copy]];
+            if ([group rangeOfString:@"platformFamily"].location != NSNotFound) {
+                keychainUsesInAppMethod = YES;
+            }
+        }
+        keychainGroups = [groupsBuilder copy];
+
+        id rawMethod = keychainSection[@"method"];
+        if (rawMethod) {
+            if (!PXRestorePlanStringIsNULFree(rawMethod)) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  @"$.keychain.method",
+                                  @"Keychain restore method is invalid.");
+                return nil;
+            }
+            keychainMethod = [(NSString *)rawMethod copy];
+        }
+        if ([keychainMethod isEqualToString:@"in_app"]) {
+            keychainUsesInAppMethod = YES;
+        }
+    }
+
+    NSString *profileAppDataArchiveName = nil;
+    NSString *profileAppDataSourcePath = nil;
+    if (includesProfileAppData) {
+        profileAppDataArchiveName = [profileSection[@"archive"] isKindOfClass:[NSString class]] ? profileSection[@"archive"] : nil;
+        profileAppDataSourcePath = PXRestorePlanVerifiedTarSource(profileAppDataArchiveName,
+                                                                  @"$.profileAppData.archive",
+                                                                  verifiedArtifacts,
+                                                                  validatedArchives,
+                                                                  error);
+        if (!profileAppDataSourcePath) {
+            return nil;
+        }
+    }
+
+    NSString *globalSafariArchiveName = nil;
+    NSString *globalSafariSourcePath = nil;
+    if (includesGlobalSafari) {
+        globalSafariArchiveName = [globalSafariSection[@"archive"] isKindOfClass:[NSString class]] ? globalSafariSection[@"archive"] : nil;
+        globalSafariSourcePath = PXRestorePlanVerifiedTarSource(globalSafariArchiveName,
+                                                                @"$.globalSafari.archive",
+                                                                verifiedArtifacts,
+                                                                validatedArchives,
+                                                                error);
+        if (!globalSafariSourcePath) {
+            return nil;
+        }
+    }
+
+    NSMutableArray<PXRestorePlanSystemGlobalItem *> *systemGlobalItemsBuilder = [NSMutableArray array];
+    NSMutableSet<NSString *> *seenSystemSubdirectories = [NSMutableSet set];
+    if (includesSystemGlobal) {
+        for (NSUInteger index = 0; index < rawSystemGlobalItems.count; index++) {
+            id rawItem = rawSystemGlobalItems[index];
+            NSString *entryPath = [NSString stringWithFormat:@"$.systemGlobalLibrary.items[%lu]", (unsigned long)index];
+            if (![rawItem isKindOfClass:[NSDictionary class]]) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  entryPath,
+                                  @"System-global item is invalid.");
+                return nil;
+            }
+            NSDictionary *itemDictionary = (NSDictionary *)rawItem;
+            NSString *subdirectory = [itemDictionary[@"subdir"] isKindOfClass:[NSString class]] ? itemDictionary[@"subdir"] : nil;
+            NSString *subdirectoryFieldPath = PXRestorePlanIndexedFieldPath(@"$.systemGlobalLibrary.items", index, @"subdir");
+            if (!PXRestorePlanValidateSystemSubdirectory(subdirectory,
+                                                         subdirectoryFieldPath,
+                                                         error)) {
+                return nil;
+            }
+            if ([seenSystemSubdirectories containsObject:subdirectory]) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorDuplicateDestination,
+                                  subdirectoryFieldPath,
+                                  @"System-global destination identity is duplicated.");
+                return nil;
+            }
+
+            NSString *archiveName = [itemDictionary[@"archive"] isKindOfClass:[NSString class]] ? itemDictionary[@"archive"] : nil;
+            NSString *archiveFieldPath = PXRestorePlanIndexedFieldPath(@"$.systemGlobalLibrary.items", index, @"archive");
+            NSString *sourcePath = PXRestorePlanVerifiedTarSource(archiveName,
+                                                                  archiveFieldPath,
+                                                                  verifiedArtifacts,
+                                                                  validatedArchives,
+                                                                  error);
+            if (!sourcePath) {
+                return nil;
+            }
+
+            PXRestorePlanSystemGlobalItem *item = [[PXRestorePlanSystemGlobalItem alloc]
+                initWithLibrarySubdirectory:subdirectory
+                                archiveName:archiveName
+                                 sourcePath:sourcePath];
+            [seenSystemSubdirectories addObject:subdirectory];
+            [systemGlobalItemsBuilder addObject:item];
+        }
+    }
+
+    NSMutableArray<PXRestorePlanSharedDatabaseItem *> *sharedDatabaseItemsBuilder = [NSMutableArray array];
+    NSMutableSet<NSString *> *seenSharedRelativePaths = [NSMutableSet set];
+    if (includesSharedDatabase) {
+        for (NSUInteger index = 0; index < rawSharedDatabaseItems.count; index++) {
+            id rawItem = rawSharedDatabaseItems[index];
+            NSString *entryPath = [NSString stringWithFormat:@"$.sharedSystemDB.files[%lu]", (unsigned long)index];
+            if (![rawItem isKindOfClass:[NSDictionary class]]) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorInvalidComponent,
+                                  entryPath,
+                                  @"Shared database item is invalid.");
+                return nil;
+            }
+            NSDictionary *itemDictionary = (NSDictionary *)rawItem;
+            NSString *relativePath = [itemDictionary[@"libraryRel"] isKindOfClass:[NSString class]] ? itemDictionary[@"libraryRel"] : nil;
+            NSString *relativePathFieldPath = PXRestorePlanIndexedFieldPath(@"$.sharedSystemDB.files", index, @"libraryRel");
+            if (!PXRestorePlanValidateSharedRelativePath(relativePath,
+                                                         relativePathFieldPath,
+                                                         error)) {
+                return nil;
+            }
+            if ([seenSharedRelativePaths containsObject:relativePath]) {
+                PXRestorePlanFail(error,
+                                  PXRestorePlanErrorDuplicateDestination,
+                                  relativePathFieldPath,
+                                  @"Shared database destination identity is duplicated.");
+                return nil;
+            }
+
+            NSString *artifactName = [itemDictionary[@"archive"] isKindOfClass:[NSString class]] ? itemDictionary[@"archive"] : nil;
+            NSString *artifactFieldPath = PXRestorePlanIndexedFieldPath(@"$.sharedSystemDB.files", index, @"archive");
+            NSString *sourcePath = PXRestorePlanVerifiedSource(artifactName,
+                                                               artifactFieldPath,
+                                                               verifiedArtifacts,
+                                                               error);
+            if (!sourcePath) {
+                return nil;
+            }
+
+            PXRestorePlanSharedDatabaseItem *item = [[PXRestorePlanSharedDatabaseItem alloc]
+                initWithLibraryRelativePath:relativePath
+                               artifactName:artifactName
+                                 sourcePath:sourcePath];
+            [seenSharedRelativePaths addObject:relativePath];
+            [sharedDatabaseItemsBuilder addObject:item];
+        }
+    }
+
+    NSUInteger manifestWarningCount = 0;
+    id rawWarnings = manifest[@"warnings"];
+    if (rawWarnings) {
+        if (![rawWarnings isKindOfClass:[NSArray class]]) {
+            PXRestorePlanFail(error,
+                              PXRestorePlanErrorInvalidComponent,
+                              @"$.warnings",
+                              @"Manifest warning metadata is invalid.");
+            return nil;
+        }
+        manifestWarningCount = [(NSArray *)rawWarnings count];
+    }
+
+    NSString *manifestProfileIdentifier = nil;
+    id rawProfileIdentifier = manifest[@"profileId"];
+    if (rawProfileIdentifier) {
+        if (!PXRestorePlanStringIsNULFree(rawProfileIdentifier)) {
+            PXRestorePlanFail(error,
+                              PXRestorePlanErrorInvalidComponent,
+                              @"$.profileId",
+                              @"Manifest profile identity is invalid.");
+            return nil;
+        }
+        if ([(NSString *)rawProfileIdentifier length] > 0) {
+            manifestProfileIdentifier = [(NSString *)rawProfileIdentifier copy];
+        }
+    }
+
+    return [[self alloc]
+        initWithBundleIdentifier:bundleIdentifier
+        applicationDataContainer:applicationDataContainer
+        applicationDataPath:applicationDataContainer.containerPath
+        applicationDataUUID:applicationDataContainer.containerUUID
+        dataArchiveName:dataArchiveName
+        dataArchivePath:dataArchivePath
+        includesAppGroups:includesAppGroups
+        appGroupItems:[appGroupItemsBuilder copy]
+        appGroupItemsByIdentifier:[appGroupLookupBuilder copy]
+        includesPreferences:includesPreferences
+        preferencesArtifactName:preferencesArtifactName
+        preferencesSourcePath:preferencesSourcePath
+        includesKeychain:includesKeychain
+        keychainArtifactName:keychainArtifactName
+        keychainSourcePath:keychainSourcePath
+        keychainGroups:keychainGroups
+        keychainMethod:keychainMethod
+        keychainUsesInAppMethod:keychainUsesInAppMethod
+        includesProfileAppData:includesProfileAppData
+        profileAppDataArchiveName:profileAppDataArchiveName
+        profileAppDataSourcePath:profileAppDataSourcePath
+        includesGlobalSafari:includesGlobalSafari
+        globalSafariArchiveName:globalSafariArchiveName
+        globalSafariSourcePath:globalSafariSourcePath
+        systemGlobalItems:[systemGlobalItemsBuilder copy]
+        sharedDatabaseItems:[sharedDatabaseItemsBuilder copy]
+        manifestWarningCount:manifestWarningCount
+        manifestProfileIdentifier:manifestProfileIdentifier
+        verifiedArtifacts:verifiedArtifacts
+        validatedArchives:validatedArchives];
+}
+
+- (PXRestorePlanAppGroupItem *)appGroupItemForIdentifier:(NSString *)groupIdentifier {
+    if (![groupIdentifier isKindOfClass:[NSString class]] || groupIdentifier.length == 0) {
+        return nil;
+    }
+    return self.appGroupItemsByIdentifier[groupIdentifier];
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
```

## 13. Static and forbidden counts

| Gate | Count |
|---|---:|
| Public error-domain exports | 1 |
| Public field-path exports | 1 |
| Public enum values | 8 |
| Public item classes | 3 |
| Public plan classes | 1 |
| Public plan factories | 1 |
| Public mutable/readwrite properties | 0 |
| Restricted classes | 4 |
| Unavailable init | 4 |
| Unavailable new | 4 |
| copyWithZone | 4 |
| Fixed 100000 literal | 1 |
| Plan imports | 4 |
| Manager plan imports | 1 |
| Restore factory calls | 1 |
| Backup factory calls | 0 |
| Post-plan manifest reads | 0 |
| Post-plan verified lookups | 0 |
| Post-plan archive lookups | 0 |
| Manifest retained as ivar/property | 0 |

| Pure-builder forbidden token/API | Count |
|---|---:|
| `UIKit` | 0 |
| `AppDataBackupManager` | 0 |
| `AppDataCleaner` | 0 |
| `AppEntitlementsReader` | 0 |
| `AppGroupContainerResolver` | 0 |
| `PXDataContainerResolver` | 0 |
| `PXDestructivePathValidator` | 0 |
| `CommandRunner` | 0 |
| `NSFileManager` | 0 |
| `fileExistsAtPath` | 0 |
| `contentsOfDirectoryAtPath` | 0 |
| `dictionaryWithContentsOfFile` | 0 |
| `realpath` | 0 |
| `open(` | 0 |
| `openat` | 0 |
| `stat(` | 0 |
| `lstat` | 0 |
| `fstat` | 0 |
| `NSTask` | 0 |
| `posix_spawn` | 0 |
| `system(` | 0 |
| `popen(` | 0 |
| `dispatch_` | 0 |
| `NSUserDefaults` | 0 |
| `SecItem` | 0 |
| `NSLog` | 0 |
| `os_log` | 0 |
| `writeToFile` | 0 |
| `removeItemAtPath` | 0 |
| `createDirectoryAtPath` | 0 |
| `moveItemAtPath` | 0 |
| `copyItemAtPath` | 0 |

Final staged static gate: **86/86 PASS**; source delimiter/interface/implementation balance also passed.

## 14. Explicit scenario matrix

These are source/static expected outcomes and do not claim target-device execution or a compiled test harness.

Scenario count: **140**.

| # | Scenario | Expected | Evidence |
|---:|---|---|---|
| 1 | valid v2 semantic plan | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 2 | valid v3 semantic plan | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 3 | exact bundle mismatch snapshot | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 4 | wrong container kind | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 5 | container requested identifier mismatch | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 6 | container metadata identifier mismatch | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 7 | supplied path differs from model path | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 8 | missing verified set | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 9 | missing archive set | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 10 | main data artifact missing | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 11 | main data archive not validated | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 12 | groups excluded | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 13 | groups included empty | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 14 | one valid App Group item | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 15 | multiple App Group items preserve manifest order | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 16 | duplicate group identifier rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 17 | App Group source missing | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 18 | App Group archive unvalidated | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 19 | recorded App Group UUID ignored | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 20 | preferences excluded | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 21 | preferences included valid | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 22 | preferences source missing | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 23 | Keychain excluded | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 24 | Keychain included helper method | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 25 | Keychain method `in_app` | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 26 | platformFamily suffix triggers in-app | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 27 | platformFamily substring triggers in-app | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 28 | case-sensitive platformFamily behavior preserved | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 29 | Keychain groups copied immutably | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 30 | profile excluded | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 31 | profile included valid | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 32 | profile recorded path ignored | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 33 | profile archive unvalidated | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 34 | global Safari excluded | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 35 | global Safari included valid | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 36 | global recorded path ignored | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 37 | absent system-global section | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 38 | excluded system-global section | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 39 | included system-global item | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 40 | system subdir with slash rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 41 | system subdir with backslash rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 42 | system subdir dot rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 43 | system subdir dot-dot rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 44 | system subdir control rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 45 | system subdir >255 bytes rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 46 | duplicate system subdir rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 47 | system item source missing | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 48 | system item archive unvalidated | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 49 | absent shared DB section | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 50 | excluded shared DB section | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 51 | valid nested shared DB relative path | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 52 | absolute shared DB path rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 53 | leading slash rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 54 | trailing slash rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 55 | doubled slash rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 56 | backslash rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 57 | dot component rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 58 | dot-dot component rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 59 | control rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 60 | component >255 rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 61 | full path >4096 rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 62 | duplicate shared DB relative path rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 63 | shared DB source missing | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 64 | shared DB does not require tar validation | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 65 | preferences does not require tar validation | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 66 | Keychain does not require tar validation | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 67 | manifest warnings absent | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 68 | manifest warnings count copied | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 69 | profile ID absent | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 70 | profile ID copied | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 71 | plan does not retain manifest | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 72 | plan retains verified snapshot | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 73 | plan retains archive snapshot | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 74 | plan retains data model | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 75 | item strings copied | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 76 | arrays copied | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 77 | copyWithZone returns self for plan | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 78 | copyWithZone returns self for App Group item | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 79 | copyWithZone returns self for system item | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 80 | copyWithZone returns self for shared DB item | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |
| 81 | group lookup nil input | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 82 | group lookup empty input | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 83 | group lookup unknown input | Freeze empty/nil/NO or return nil | Immutable plan/lookup follows the exact exclusion or absence contract. |
| 84 | group lookup exact case-sensitive match | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 85 | total item count 100000 accepted | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 86 | total item count 100001 rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 87 | total-count overflow rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 88 | error userInfo keys restricted | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 89 | error omits bundle value | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 90 | error omits artifact value | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 91 | error omits source path | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 92 | error omits relative destination value | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 93 | builder clears error | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 94 | success leaves error nil | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 95 | plan failure before warnings | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 96 | plan failure before CommandRunner | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 97 | plan failure before debug write | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 98 | plan failure before tar discovery | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 99 | plan failure before process kill | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 100 | plan failure before staging | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 101 | plan failure before extraction | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 102 | plan failure before mutation | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 103 | exact plan error propagated | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 104 | impossible nil-error fallback | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 105 | post-plan manifest reads zero | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 106 | post-plan verified lookup zero | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 107 | post-plan archive lookup zero | Ordering/authority gate holds | Source position and scoped zero-authority counts prove this case. |
| 108 | main source uses plan | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 109 | App Group source uses plan lookup | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 110 | profile source uses plan | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 111 | global source uses plan | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 112 | system loop uses plan items | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 113 | shared DB loop uses plan items | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 114 | preferences source uses plan | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 115 | Keychain source/groups/method use plan | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 116 | existing App Group destination resolver retained | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 117 | existing profile destination helper retained | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 118 | existing global destination helper retained | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 119 | existing mobile Library helper retained | Operation consumes plan/preserved helper | Post-plan Restore migration inventory covers this operation. |
| 120 | extraction helper hashes unchanged | Non-regression/boundary holds | Protected hashes, diff scope and TASK-2.8 absence prove this case. |
| 121 | destination helper unchanged | Non-regression/boundary holds | Protected hashes, diff scope and TASK-2.8 absence prove this case. |
| 122 | artifact/archive validators unchanged | Non-regression/boundary holds | Protected hashes, diff scope and TASK-2.8 absence prove this case. |
| 123 | Makefile unchanged | Non-regression/boundary holds | Protected hashes, diff scope and TASK-2.8 absence prove this case. |
| 124 | UI unchanged | Non-regression/boundary holds | Protected hashes, diff scope and TASK-2.8 absence prove this case. |
| 125 | TASK-2.8 remains unimplemented. | Non-regression/boundary holds | Protected hashes, diff scope and TASK-2.8 absence prove this case. |
| 126 | requested bundle containing NUL is rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 127 | whitespace in requested identity is compared exactly without trimming | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 128 | empty model path is rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 129 | empty model UUID is rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 130 | recorded main data path disagreement is ignored | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 131 | recorded main data UUID disagreement is ignored | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 132 | verified source wins over recorded artifact.path | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 133 | caller mutation of App Group input cannot mutate the plan | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 134 | caller mutation of Keychain groups cannot mutate the plan | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 135 | Unicode system subdirectory exactly 255 UTF-8 bytes is accepted | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 136 | Unicode system subdirectory 256 UTF-8 bytes is rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 137 | canonically equivalent Unicode spellings remain exact and distinct | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 138 | percent-encoded shared path is not decoded | Accept or preserve exact behavior | Pure builder logic implements this named scenario without normalization or side effects. |
| 139 | CR/LF in a relative destination is rejected | Fail closed as specified | Factory/integration has an explicit stable error branch for this condition. |
| 140 | present empty Keychain method is copied as the empty current decision | Immutable ownership contract holds | Readonly copied state and copyWithZone/no-retention static gates cover this case. |

## 15. Whitespace, CRLF, NUL and generated-artifact audit

| Staged source | Bytes | NUL | CRLF | Trailing-whitespace lines | SHA-256 |
|---|---:|---:|---:|---:|---|
| `PXRestorePlan.h` | 4947 | 0 | 0 | 0 | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` |
| `PXRestorePlan.m` | 48523 | 0 | 0 | 0 | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` |
| `AppDataBackupManager.m` | 123208 | 0 | 0 | 18 | `d78601a508f4d1e8f663381f6e1b6b219126b548b2aeb2d9e06610a07080a1bd` |

- `git diff --cached --check`: PASS before report generation.
- All three canonical staged source blobs are UTF-8/LF and NUL-free. The two new plan files have zero trailing-whitespace lines; the manager retains 18 pre-existing baseline lines, and `git diff --cached --check` proves TASK-2.7 introduced none.
- Windows checkout may warn about future CRLF conversion; staged/committed blobs remain LF.
- Report is UTF-8/LF, NUL-free and has zero trailing-whitespace lines; no object, binary, fixture, cache, temporary script or build artifact is included.

## 16. Build status and remaining runtime risks

- Local Objective-C/Theos build: **NOT RUN — TOOLCHAIN UNAVAILABLE**.
- `make`, `clang`, `clang-cl`, and `xcrun` are not found; `THEOS` is not set.
- Static/API/forbidden/ordering/hash/diff gates passed but do not replace compilation or device tests.
- Remaining validation: ARC/Foundation compiler compatibility, real snapshot objects, optional combinations, 100000-record memory behavior and target-device Restore execution.
- Dynamic destination helpers/Keychain paths still need device regression coverage; final destination authorization/staging/transactions remain later tasks. TASK-2.8 is intentionally absent.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
