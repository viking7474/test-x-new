# TASK-2.8 Report — Stage and Validate Main Application Data

## 1. Baseline and exact scope

- Required and observed task-start HEAD: `d9ab9013b5d637ceb71695003bbc7153ac78151c`.
- TASK-2.7 source review status supplied by the coordinator: ACCEPTED.
- Production scope is exactly `PXMainDataStaging.h`, `PXMainDataStaging.m`, and `AppDataBackupManager.m`; the only additional artifact is this report.
- Existing coordinator/review/task working-tree content was not staged or modified by TASK-2.8.
- TASK-2.9 and TASK-2.11 remain unimplemented.

Task-start evidence:

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
?? docs/backup-restore-hardening/reviews/TASK-2.7-REVIEW.md
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
?? docs/backup-restore-hardening/tasks/TASK-2.8-stage-and-validate-main-data.md
$ git rev-parse HEAD
d9ab9013b5d637ceb71695003bbc7153ac78151c
$ git log -3 --oneline
d9ab901 phase2(task-2.7): build immutable restore plan
2bb8473 phase2(task-2.6A): fix archive validator compatibility and bounds
6dd6df3 phase2(task-2.6): add archive entry safety validator
```

## 2. Protected production SHA-256 before and after

Hashes below use canonical Git blobs from the required baseline and the staged index, avoiding checkout CRLF conversion artifacts.

| Protected production file | Baseline SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `AppDataBackupManager.h` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | MATCH |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | MATCH |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | MATCH |
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

Protected canonical blobs: **75/75 MATCH**. Explicit protected-file Git diff is zero.

## 3. Exact public API and fourteen-code enum

- Exact specification/header comparison: **PASS**.
- Exports are exactly `PXMainDataStagingErrorDomain` and `PXMainDataStagingErrorFieldPathKey`.
- Public classes are exactly immutable `PXValidatedMainDataStage` and lifecycle `PXMainDataStagingWorkspace`.
- Public methods are exactly one factory, one empty gate, one stage validator and one cleanup method; there are no extraction, target, transaction, App Group or optional-component APIs.

| Value | Error code |
|---:|---|
| 1 | `PXMainDataStagingErrorInvalidInput` |
| 2 | `PXMainDataStagingErrorWorkspaceCreationFailed` |
| 3 | `PXMainDataStagingErrorWorkspaceIdentityChanged` |
| 4 | `PXMainDataStagingErrorWorkspaceNotEmpty` |
| 5 | `PXMainDataStagingErrorEnumerationFailed` |
| 6 | `PXMainDataStagingErrorUnsafeEntryPath` |
| 7 | `PXMainDataStagingErrorUnsupportedEntryType` |
| 8 | `PXMainDataStagingErrorHardLinkRejected` |
| 9 | `PXMainDataStagingErrorForbiddenContainerMetadata` |
| 10 | `PXMainDataStagingErrorLimitExceeded` |
| 11 | `PXMainDataStagingErrorReadFailed` |
| 12 | `PXMainDataStagingErrorFilesystemChanged` |
| 13 | `PXMainDataStagingErrorSizeMismatch` |
| 14 | `PXMainDataStagingErrorCleanupFailed` |

## 4. Workspace creation, fixed parent and retained identity

- The fixed real parent is exactly `/private/var/tmp`; no manifest, environment, bundle, backup-directory or caller-selected parent exists.
- Creation performs parent `lstat`, no-follow/CLOEXEC open, exact `mkdtemp` template `weaponx_restore_main.XXXXXX`, direct-child basename proof, parent recheck, root `lstat`/open, root `0700` enforcement, `mkdirat("data", 0700)`, data no-follow open and data `0700` enforcement.
- The workspace retains fixed-parent, root and data descriptors plus device/inode/type/time snapshots. Root/data must remain same-device directories without setuid/setgid.
- Public paths are copied strings used only at the explicitly permitted external extraction and validated clone boundaries; descriptors are private.

## 5. Empty-directory gate

- `validateEmptyDataDirectoryWithError:` clears the error, verifies all retained identities, requires root to contain exactly `data`, and requires `data` to contain no entry other than dot entries.
- Enumeration duplicates descriptors, sets/verifies `FD_CLOEXEC`, resets the shared directory offset, uses `fdopendir/readdir`, and compares directory device/inode/type/mtime/ctime before and after.
- Unexpected entries fail `WorkspaceNotEmpty`; the method never deletes them.

## 6. Descriptor-relative deterministic traversal and path/type policy

- Validation begins from a duplicate of the retained data descriptor and uses iterative heap frames, never the public path.
- Each directory name is captured as raw bytes, strict UTF-8 round-tripped, sorted in raw UTF-8 byte lexicographic order and assigned one monotonic global pre-order index.
- `fstatat(..., AT_SYMLINK_NOFOLLOW)` precedes `openat`; child directories use `O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`, regular files use `O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC`.
- Components reject empty/dot/dot-dot, invalid UTF-8, NUL/control, slash/backslash, >255 bytes, paths >4096 bytes and depth >2048 without normalization, case folding or percent decoding.
- Only regular files and directories are accepted. Symlinks/special files, hard links, device crossings and setuid/setgid entries fail closed.

## 7. Forbidden container metadata

- Exact case-sensitive root-level checks reject `.com.apple.mobile_container_manager.metadata.plist` and `.com.apple.containermanagerd.metadata.plist`.
- Nested occurrences and case-different names are not broadened into an unrelated policy.

## 8. Fixed limits, overflow and exact regular-file accounting

| Limit | Fixed value |
|---|---:|
| Accepted logical archive members | 200000 |
| Derived implicit directories | 200000 |
| Staged entries | 400000 |
| Cleanup entries | 500000 |
| UTF-8 relative path bytes | 4096 |
| UTF-8 component bytes | 255 |
| Traversal depth | 2048 |
| Streaming read buffer | 65536 bytes |

- The staged ceiling is zero for logical count zero; otherwise overflow-safe `min(400000, logical+200000)`. Global enumerated and processed counts are bounded before append/processing.
- Every regular file is opened descriptor-relatively, `fstat`ed before/after, streamed with EINTR retry, exact-size checked, and required stable in device/inode/type/link-count/size/mtime/ctime. Atime is ignored.
- Running byte addition is overflow-safe and the final total must exactly equal `regularFileBytesByArchiveName[dataArchiveName]`.

## 9. Deterministic staged-tree SHA-256 and immutable result

- CommonCrypto SHA-256 starts with `PXMainDataStageTreeV1\0` and hashes each pre-order entry as type, uint32 big-endian path length, exact path bytes, uint32 big-endian mode masked to 07777, uint64 big-endian file size or zero, and file contents.
- Absolute paths, device/inode, timestamps, uid/gid, atime and xattr/ACL bytes are excluded.
- The result copies root/data paths, counts, byte total and exactly 64 lowercase hex digest characters; it returns self from `copyWithZone:` and retains no descriptor/callback/parser/mutable collection.

## 10. Cleanup ownership, bounds and idempotence

- Cleanup verifies parent/root/data ownership, traverses with `fstatat`/`openat` and removes entries with `unlinkat`; symlinks and special files are unlinked without traversal.
- The retained `data` identity is rechecked before deleting it. Directories are removed post-order while their verified descriptors remain open; the root is removed through the retained parent descriptor.
- Cleanup is limited to 500000 entries and depth 2048, closes every descriptor, marks cleaned only after owned-root removal or safe proof that the owned namespace is already absent, and is idempotent thereafter.
- No `NSFileManager` recursive delete and no `rm -rf` fallback exist. Deallocation performs best-effort safe cleanup only.

## 11. Accepted archive-summary and manager integration

- Manager reads only `restorePlan.dataArchiveName`, `restorePlan.dataArchivePath`, and the two summary maps retained by `restorePlan.validatedArchives`. Summary values must be nonnegative integral `NSNumber` values representable by method argument types; invalid values fail before workspace creation.
- `mainDataWorkspace.dataPath` occurs exactly once and is only the external extraction destination. `validatedStage.dataPath` occurs exactly once and becomes the only tar-pipe/cp clone source.
- Required order is source-proven: plan → tar selection → workspace create → empty gate → zero-exit extraction → stage validation → first process kill → target revalidation → wipe → tar/cp clone → chown → cleanup.
- Stage validation precedes all optional-component mutation. Post-plan authority remains manifest/artifact/archive local counts `0/0/0`.

## 12. Fail-closed extraction and cleanup-path inventory

- `_tarExtractDataArchive` now returns the actual `_tarExtract` result; the compatibility warning parameter is unused and cannot authorize continuation.
- `Cannot open: File exists`, `_directoryHasRestoredContent` and partial-stage continuation are absent. Nonzero extraction remains manager code 316; target failure remains 303; clone failure remains 317.

| Path | Cleanup behavior | Primary outcome |
|---|---|---|
| Empty validation failure | One idempotent cleanup call | Exact staging error |
| Extraction failure | One cleanup call | Manager code 316 |
| Stage validation failure | One cleanup call | Exact staging error |
| Target revalidation failure | One cleanup call | Manager code 303 |
| Tar-pipe plus cp failure | One cleanup call | Manager code 317 |
| Successful clone/chown | One cleanup call | Continue; cleanup failure adds only `Main-data staging cleanup failed` |

## 13. TASK-2.1 through TASK-2.7 non-regression and later boundaries

- Manifest/version/bundle/destination gates, artifact verifier, archive validator, immutable restore plan, tar preference, target validator, wipe/clone/chown behavior, App Group and optional-component behavior, Backup, UI and `PXRestoreResult` remain outside the intentional TASK-2.8 changes.
- No App Group staging, optional-component staging, quarantine, atomic swap, transaction journal, rollback or structured component result was added. TASK-2.9 and TASK-2.11 remain locked/unimplemented.

| Protected body | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|
| `PXBackupManifestVersionIsSupported` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | MATCH |
| `PXResolveExactRestoreApplicationDataTarget` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | MATCH |
| `readManifestAtBackupDirectory:error:` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | MATCH |
| `createBackupForBundleID:appName:options:completion:` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | MATCH |
| `_tarExtract:archive:toDir:` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | MATCH |
| `PXRestorePlan planForManifest:` | `b7a675118c523db2f80b6e135f313c17a4b974e4a2e0b892c3838cd4decb75a4` | `b7a675118c523db2f80b6e135f313c17a4b974e4a2e0b892c3838cd4decb75a4` | MATCH |
| `verifiedArtifactsForManifest:` | `00d15963d903c45b3d843d3b4506e936893d8e3e53f23d2cd69aa4510d864df5` | `00d15963d903c45b3d843d3b4506e936893d8e3e53f23d2cd69aa4510d864df5` | MATCH |
| `validatedArchivesForManifest:` | `b0564c8b3bac33b9c572694656a1a5cd64496bcffa9b1000722fdcf89ac408a7` | `b0564c8b3bac33b9c572694656a1a5cd64496bcffa9b1000722fdcf89ac408a7` | MATCH |
| `_tarExtractDataArchive:archive:toDir:warnings:` | `892933c64a16aee9fed8165d41cb2e73f8e226980cb28b060c51502348e69881` | `b8a35a36213f74090fff16c3ca368392cc3807b6a649ad1dc5491660dde274ac` | INTENTIONAL FAIL-CLOSED CHANGE |

## 14. Full production source diff

```text
AppDataBackupManager.m |  183 ++++--
 PXMainDataStaging.h    |   62 ++
 PXMainDataStaging.m    | 1548 ++++++++++++++++++++++++++++++++++++++++++++++++
 3 files changed, 1743 insertions(+), 50 deletions(-)
```

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index 7203dd4..fc411f5 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -13,6 +13,7 @@
 #import "PXBackupArtifactVerifier.h"
 #import "PXBackupArchiveValidator.h"
 #import "PXRestorePlan.h"
+#import "PXMainDataStaging.h"
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
 #import "CommandRunner.h"
@@ -26,6 +27,46 @@ static NSString * const PXBackupErrorDomain = @"com.hydra.projectx.backup";
 static NSString * const PXExactRestoreDestinationErrorDescription =
     @"Exact application data container could not be resolved safely";

+static BOOL PXReadUnsignedIntegralSummaryNumber(id value,
+                                                unsigned long long *numberOut) {
+    if (![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) {
+        return NO;
+    }
+    const char *type = [(NSNumber *)value objCType];
+    if (!type || !type[0]) {
+        return NO;
+    }
+    unsigned long long unsignedValue = 0;
+    switch (type[0]) {
+        case 'C':
+        case 'S':
+        case 'I':
+        case 'L':
+        case 'Q':
+            unsignedValue = [(NSNumber *)value unsignedLongLongValue];
+            break;
+        case 'c':
+        case 's':
+        case 'i':
+        case 'l':
+        case 'q': {
+            long long signedValue = [(NSNumber *)value longLongValue];
+            if (signedValue < 0) {
+                return NO;
+            }
+            unsignedValue = (unsigned long long)signedValue;
+            break;
+        }
+        default:
+            return NO;
+    }
+    if (numberOut) {
+        *numberOut = unsignedValue;
+    }
+    return YES;
+}
+
 static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
     if (![version isKindOfClass:[NSNumber class]]) {
         return NO;
@@ -616,32 +657,12 @@ static NSString *PXCleanSubdirName(NSString *s) {
     return [runner runAndCapture:fallback];
 }

-- (BOOL)_directoryHasRestoredContent:(NSString *)dirPath {
-    if (!dirPath.length) return NO;
-    NSArray<NSString *> *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:nil];
-    for (NSString *item in items) {
-        if (![item isKindOfClass:[NSString class]] || !item.length) continue;
-        if ([item hasPrefix:@".com.apple"]) continue;
-        return YES;
-    }
-    return NO;
-}
-
 - (CommandResult *)_tarExtractDataArchive:(NSString *)tarPath
                                   archive:(NSString *)archivePath
                                     toDir:(NSString *)destDir
                                  warnings:(NSMutableArray<NSString *> *)warnings {
-    CommandResult *res = [self _tarExtract:tarPath archive:archivePath toDir:destDir];
-    if (res.exitCode == 0) {
-        return res;
-    }
-
-    NSString *stderrText = res.stderrString ?: @"";
-    if ([stderrText containsString:@"Cannot open: File exists"] && [self _directoryHasRestoredContent:destDir]) {
-        [warnings addObject:@"data.tar.gz extract reported 'File exists'; continuing because staging contains restored content"];
-        res.exitCode = 0;
-    }
-    return res;
+    (void)warnings;
+    return [self _tarExtract:tarPath archive:archivePath toDir:destDir];
 }

 - (NSString *)_preferencesDirectory {
@@ -2008,9 +2029,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)restorePlan.manifestWarningCount]];
         }

-        // Kill app before restore
-        [self _killRelatedProcessesForBundleID:bundleID];
-
         NSString *manifestProfileId = restorePlan.manifestProfileIdentifier;
         NSString *activeProfileId = [self _activeProfileId];
         if (manifestProfileId.length && activeProfileId.length && ![manifestProfileId isEqualToString:activeProfileId]) {
@@ -2038,30 +2056,96 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             }
         }

+        NSString *dataArchiveName = restorePlan.dataArchiveName;
         NSString *dataArchive = restorePlan.dataArchivePath;
+        NSNumber *logicalMemberSummary =
+            restorePlan.validatedArchives.memberCountsByArchiveName[dataArchiveName];
+        NSNumber *regularFileByteSummary =
+            restorePlan.validatedArchives.regularFileBytesByArchiveName[dataArchiveName];
+        unsigned long long logicalMemberValue = 0;
+        unsigned long long expectedRegularFileBytes = 0;
+        if (!PXReadUnsignedIntegralSummaryNumber(logicalMemberSummary, &logicalMemberValue) ||
+            !PXReadUnsignedIntegralSummaryNumber(regularFileByteSummary, &expectedRegularFileBytes) ||
+            logicalMemberValue > NSUIntegerMax) {
+            NSError *err = [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                               code:PXMainDataStagingErrorInvalidInput
+                                           userInfo:@{
+                                               NSLocalizedDescriptionKey: @"The accepted main archive summary is invalid.",
+                                               PXMainDataStagingErrorFieldPathKey: @"$.data"
+                                           }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+        NSUInteger expectedLogicalMemberCount = (NSUInteger)logicalMemberValue;
+
+        NSError *workspaceError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXMainDataStagingWorkspace *mainDataWorkspace =
+            [PXMainDataStagingWorkspace createWorkspaceWithError:&workspaceError];
+        if (!mainDataWorkspace) {
+            NSError *err = workspaceError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                                                  code:PXMainDataStagingErrorWorkspaceCreationFailed
+                                                              userInfo:@{
+                                                                  NSLocalizedDescriptionKey: @"The private main-data staging workspace could not be created.",
+                                                                  PXMainDataStagingErrorFieldPathKey: @"$.workspace"
+                                                              }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }

-        // Two-phase restore for data container: extract to staging first.
-        NSString *stagingRoot = [NSString stringWithFormat:@"/tmp/weaponx_restore_%d", getpid()];
-        NSString *stagingData = [stagingRoot stringByAppendingPathComponent:@"data"];
-        [fm removeItemAtPath:stagingRoot error:nil];
-        [fm createDirectoryAtPath:stagingData withIntermediateDirectories:YES attributes:nil error:nil];
+        NSError *emptyStageError = nil;
+        if (![mainDataWorkspace validateEmptyDataDirectoryWithError:&emptyStageError]) {
+            [mainDataWorkspace cleanupWithError:nil];
+            NSError *err = emptyStageError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                                                    code:PXMainDataStagingErrorInvalidInput
+                                                                userInfo:@{
+                                                                    NSLocalizedDescriptionKey: @"The private main-data staging workspace failed empty validation.",
+                                                                    PXMainDataStagingErrorFieldPathKey: @"$.data"
+                                                                }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }

-        CommandResult *stx = [self _tarExtractDataArchive:tarPath archive:dataArchive toDir:stagingData warnings:warnings];
+        CommandResult *stx = [self _tarExtractDataArchive:tarPath
+                                                   archive:dataArchive
+                                                     toDir:mainDataWorkspace.dataPath
+                                                  warnings:warnings];
         if (stx.exitCode != 0) {
-            NSString *msg = stx.stderrString.length ? stx.stderrString : @"Failed to extract data archive to staging";
+            [mainDataWorkspace cleanupWithError:nil];
             NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                code:316
-                                           userInfo:@{NSLocalizedDescriptionKey: msg}];
+                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract data archive to staging"}];
             dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
             return;
         }

-        // Wipe data container contents and clone from staging via tar pipe.
-        PXDebugHeader(debugPre, @"Data Restore (Staging -> Container)");
-        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"stagingData=%@", stagingData ?: @""]);
-        PXDebugRun(runner, debugPre, @"du stagingData", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(stagingData)]);
+        NSError *stageValidationError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXValidatedMainDataStage *validatedStage =
+            [mainDataWorkspace validatedStageWithExpectedLogicalMemberCount:expectedLogicalMemberCount
+                                                     expectedRegularFileBytes:expectedRegularFileBytes
+                                                                         error:&stageValidationError];
+        if (!validatedStage) {
+            [mainDataWorkspace cleanupWithError:nil];
+            NSError *err = stageValidationError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                                                        code:PXMainDataStagingErrorInvalidInput
+                                                                    userInfo:@{
+                                                                        NSLocalizedDescriptionKey: @"The extracted main-data stage failed validation.",
+                                                                        PXMainDataStagingErrorFieldPathKey: @"$.data"
+                                                                    }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
+        NSString *validatedStagingData = validatedStage.dataPath;
+        PXDebugHeader(debugPre, @"Data Restore (Validated Staging -> Container)");
+        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"stagedEntryCount=%lu", (unsigned long)validatedStage.entryCount]);
+        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"stagedRegularFileCount=%lu", (unsigned long)validatedStage.regularFileCount]);
         PXDebugRun(runner, debugPre, @"ls container (before wipe)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);

+        // The target process is not terminated until the complete staged tree is accepted.
+        [self _killRelatedProcessesForBundleID:bundleID];
+
         PXDestructivePathValidator *preMutationValidator = [[PXDestructivePathValidator alloc] init];
         NSError *preMutationValidationError = nil;
         NSString *preMutationCanonicalPath =
@@ -2070,7 +2154,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         if (preMutationValidationError ||
             preMutationCanonicalPath.length == 0 ||
             ![preMutationCanonicalPath isEqualToString:dataContainerPath]) {
-            [fm removeItemAtPath:stagingRoot error:nil];
+            [mainDataWorkspace cleanupWithError:nil];
             NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                code:303
                                            userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
@@ -2090,13 +2174,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         if (!shouldPreferCpClone) {
             NSString *cloneCmd = [NSString stringWithFormat:@"%@ --xattrs --acls -cf - -C %@ . | %@ --xattrs --acls -xf - -C %@",
                                   PXShellQuote(tarPath),
-                                  PXShellQuote(stagingData),
+                                  PXShellQuote(validatedStagingData),
                                   PXShellQuote(tarPath),
                                   PXShellQuote(dataContainerPath)];
             cloneRes = [runner runAndCapture:cloneCmd];
             PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"tarPipeCloneExit=%d", (int)cloneRes.exitCode]);
             if (cloneRes.stderrString.length) {
-                PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"tarPipeCloneStderr=%@", cloneRes.stderrString]);
+                PXDebugAppendLine(debugPre, @"tarPipeCloneStderrPresent=1");
             }
             if (cloneRes.exitCode != 0) {
                 shouldPreferCpClone = YES;
@@ -2111,21 +2195,18 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         if (shouldPreferCpClone) {
             NSString *fallbackCmd = [NSString stringWithFormat:@"cp -a %@/. %@/ 2>/dev/null",
-                                     PXShellQuote(stagingData),
+                                     PXShellQuote(validatedStagingData),
                                      PXShellQuote(dataContainerPath)];
             CommandResult *cpRes = [runner runAndCapture:fallbackCmd];
             PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"cpCloneExit=%d", (int)cpRes.exitCode]);
             if (cpRes.stderrString.length) {
-                PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"cpCloneStderr=%@", cpRes.stderrString]);
+                PXDebugAppendLine(debugPre, @"cpCloneStderrPresent=1");
             }
             if (cpRes.exitCode != 0) {
-                NSString *msg = (cloneRes && cloneRes.stderrString.length) ? cloneRes.stderrString : @"tar pipe clone failed";
-                if (cpRes.stderrString.length) {
-                    msg = [msg stringByAppendingFormat:@"; cp: %@", cpRes.stderrString];
-                }
+                [mainDataWorkspace cleanupWithError:nil];
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                    code:317
-                                               userInfo:@{NSLocalizedDescriptionKey: msg}];
+                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to clone validated main-data stage"}];
                 dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                 return;
             }
@@ -2134,13 +2215,15 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         // Ensure ownership is correct (some extraction/copy paths may produce root-owned files).
         [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]];

+        NSError *mainDataCleanupError = nil;
+        if (![mainDataWorkspace cleanupWithError:&mainDataCleanupError]) {
+            [warnings addObject:@"Main-data staging cleanup failed"];
+        }
+
         // Post-restore hygiene: refresh preferences daemon caches.
         // Some apps read state via cfprefsd and may not notice external file writes immediately.
         PXKillallByName(@"cfprefsd", SIGTERM);

-        // Cleanup staging best-effort
-        [fm removeItemAtPath:stagingRoot error:nil];
-
         // Data container restored.

         // Restore profile redirected appdata (if present)
diff --git a/PXMainDataStaging.h b/PXMainDataStaging.h
new file mode 100644
index 0000000..c03e5e3
--- /dev/null
+++ b/PXMainDataStaging.h
@@ -0,0 +1,62 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSString * const PXMainDataStagingErrorDomain;
+FOUNDATION_EXPORT NSString * const PXMainDataStagingErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXMainDataStagingErrorCode) {
+    PXMainDataStagingErrorInvalidInput = 1,
+    PXMainDataStagingErrorWorkspaceCreationFailed = 2,
+    PXMainDataStagingErrorWorkspaceIdentityChanged = 3,
+    PXMainDataStagingErrorWorkspaceNotEmpty = 4,
+    PXMainDataStagingErrorEnumerationFailed = 5,
+    PXMainDataStagingErrorUnsafeEntryPath = 6,
+    PXMainDataStagingErrorUnsupportedEntryType = 7,
+    PXMainDataStagingErrorHardLinkRejected = 8,
+    PXMainDataStagingErrorForbiddenContainerMetadata = 9,
+    PXMainDataStagingErrorLimitExceeded = 10,
+    PXMainDataStagingErrorReadFailed = 11,
+    PXMainDataStagingErrorFilesystemChanged = 12,
+    PXMainDataStagingErrorSizeMismatch = 13,
+    PXMainDataStagingErrorCleanupFailed = 14,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXValidatedMainDataStage : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly) NSString *workspaceRootPath;
+@property (nonatomic, copy, readonly) NSString *dataPath;
+@property (nonatomic, assign, readonly) NSUInteger entryCount;
+@property (nonatomic, assign, readonly) NSUInteger regularFileCount;
+@property (nonatomic, assign, readonly) NSUInteger directoryCount;
+@property (nonatomic, assign, readonly) unsigned long long regularFileBytes;
+@property (nonatomic, copy, readonly) NSString *treeSHA256;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXMainDataStagingWorkspace : NSObject
+
+@property (nonatomic, copy, readonly) NSString *rootPath;
+@property (nonatomic, copy, readonly) NSString *dataPath;
+
++ (nullable instancetype)createWorkspaceWithError:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)validateEmptyDataDirectoryWithError:(NSError * _Nullable * _Nullable)error;
+
+- (nullable PXValidatedMainDataStage *)validatedStageWithExpectedLogicalMemberCount:(NSUInteger)logicalMemberCount
+                                                           expectedRegularFileBytes:(unsigned long long)regularFileBytes
+                                                                               error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXMainDataStaging.m b/PXMainDataStaging.m
new file mode 100644
index 0000000..c924898
--- /dev/null
+++ b/PXMainDataStaging.m
@@ -0,0 +1,1548 @@
+#import "PXMainDataStaging.h"
+#import <CommonCrypto/CommonDigest.h>
+
+#include <dirent.h>
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
+NSString * const PXMainDataStagingErrorDomain = @"PXMainDataStagingErrorDomain";
+NSString * const PXMainDataStagingErrorFieldPathKey = @"PXMainDataStagingErrorFieldPathKey";
+
+static NSString * const PXMainDataStagingParentPath = @"/private/var/tmp";
+static const NSUInteger PXMainDataMaximumLogicalMembers = 200000;
+static const NSUInteger PXMainDataMaximumImplicitDirectories = 200000;
+static const NSUInteger PXMainDataMaximumStagedEntries = 400000;
+static const NSUInteger PXMainDataMaximumCleanupEntries = 500000;
+static const NSUInteger PXMainDataMaximumPathBytes = 4096;
+static const NSUInteger PXMainDataMaximumComponentBytes = 255;
+static const NSUInteger PXMainDataMaximumDepth = 2048;
+static const size_t PXMainDataReadBufferSize = 64 * 1024;
+
+typedef struct {
+    dev_t device;
+    ino_t inode;
+    mode_t mode;
+    struct timespec modificationTime;
+    struct timespec changeTime;
+} PXMainDataIdentity;
+
+static PXMainDataIdentity PXMainDataIdentityFromStat(const struct stat *value) {
+    PXMainDataIdentity identity;
+    identity.device = value->st_dev;
+    identity.inode = value->st_ino;
+    identity.mode = value->st_mode;
+    identity.modificationTime = value->st_mtimespec;
+    identity.changeTime = value->st_ctimespec;
+    return identity;
+}
+
+static BOOL PXMainDataTimesEqual(struct timespec left, struct timespec right) {
+    return left.tv_sec == right.tv_sec && left.tv_nsec == right.tv_nsec;
+}
+
+static BOOL PXMainDataIdentityMatchesBasic(PXMainDataIdentity expected,
+                                           const struct stat *actual) {
+    return expected.device == actual->st_dev &&
+           expected.inode == actual->st_ino &&
+           ((expected.mode & S_IFMT) == (actual->st_mode & S_IFMT));
+}
+
+static BOOL PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentity expected,
+                                                     const struct stat *actual) {
+    return PXMainDataIdentityMatchesBasic(expected, actual) &&
+           PXMainDataTimesEqual(expected.modificationTime, actual->st_mtimespec) &&
+           PXMainDataTimesEqual(expected.changeTime, actual->st_ctimespec);
+}
+
+static BOOL PXMainDataStableFileStatsEqual(const struct stat *before,
+                                           const struct stat *after) {
+    return before->st_dev == after->st_dev &&
+           before->st_ino == after->st_ino &&
+           ((before->st_mode & S_IFMT) == (after->st_mode & S_IFMT)) &&
+           before->st_nlink == after->st_nlink &&
+           before->st_size == after->st_size &&
+           PXMainDataTimesEqual(before->st_mtimespec, after->st_mtimespec) &&
+           PXMainDataTimesEqual(before->st_ctimespec, after->st_ctimespec);
+}
+
+static BOOL PXMainDataFail(NSError **error,
+                           PXMainDataStagingErrorCode code,
+                           NSString *fieldPath,
+                           NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                     code:code
+                                 userInfo:@{
+                                     NSLocalizedDescriptionKey: description,
+                                     PXMainDataStagingErrorFieldPathKey: fieldPath
+                                 }];
+    }
+    return NO;
+}
+
+static id PXMainDataFailObject(NSError **error,
+                               PXMainDataStagingErrorCode code,
+                               NSString *fieldPath,
+                               NSString *description) {
+    PXMainDataFail(error, code, fieldPath, description);
+    return nil;
+}
+
+static void PXMainDataCloseDescriptor(int *descriptor) {
+    if (descriptor && *descriptor >= 0) {
+        close(*descriptor);
+        *descriptor = -1;
+    }
+}
+
+static BOOL PXMainDataSetCloseOnExec(int descriptor) {
+    int flags = fcntl(descriptor, F_GETFD);
+    if (flags < 0) {
+        return NO;
+    }
+    if ((flags & FD_CLOEXEC) == 0 &&
+        fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) < 0) {
+        return NO;
+    }
+    int verified = fcntl(descriptor, F_GETFD);
+    return verified >= 0 && (verified & FD_CLOEXEC) != 0;
+}
+
+static int PXMainDataDuplicateDescriptor(int descriptor) {
+    int duplicate = dup(descriptor);
+    if (duplicate < 0) {
+        return -1;
+    }
+    if (!PXMainDataSetCloseOnExec(duplicate)) {
+        close(duplicate);
+        return -1;
+    }
+    return duplicate;
+}
+
+static NSComparisonResult PXMainDataCompareRawNames(NSData *left, NSData *right) {
+    NSUInteger commonLength = MIN(left.length, right.length);
+    int result = commonLength > 0 ? memcmp(left.bytes, right.bytes, commonLength) : 0;
+    if (result < 0) {
+        return NSOrderedAscending;
+    }
+    if (result > 0) {
+        return NSOrderedDescending;
+    }
+    if (left.length < right.length) {
+        return NSOrderedAscending;
+    }
+    if (left.length > right.length) {
+        return NSOrderedDescending;
+    }
+    return NSOrderedSame;
+}
+
+static NSArray<NSData *> *PXMainDataReadDirectoryNames(int descriptor,
+                                                       NSUInteger maximumNameCount,
+                                                       PXMainDataStagingErrorCode code,
+                                                       PXMainDataStagingErrorCode limitCode,
+                                                       NSString *fieldPath,
+                                                       NSError **error) {
+    int enumerationDescriptor = PXMainDataDuplicateDescriptor(descriptor);
+    if (enumerationDescriptor < 0 ||
+        lseek(enumerationDescriptor, 0, SEEK_SET) < 0) {
+        if (enumerationDescriptor >= 0) {
+            close(enumerationDescriptor);
+        }
+        return PXMainDataFailObject(error,
+                                    code,
+                                    fieldPath,
+                                    @"A directory enumeration descriptor could not be prepared.");
+    }
+
+    DIR *directory = fdopendir(enumerationDescriptor);
+    if (!directory) {
+        close(enumerationDescriptor);
+        return PXMainDataFailObject(error,
+                                    code,
+                                    fieldPath,
+                                    @"A directory could not be enumerated.");
+    }
+
+    NSMutableArray<NSData *> *names = [NSMutableArray array];
+    errno = 0;
+    for (;;) {
+        struct dirent *entry = readdir(directory);
+        if (!entry) {
+            break;
+        }
+        const char *name = entry->d_name;
+        if ((name[0] == '.' && name[1] == '\0') ||
+            (name[0] == '.' && name[1] == '.' && name[2] == '\0')) {
+            continue;
+        }
+        if (names.count >= maximumNameCount) {
+            closedir(directory);
+            return PXMainDataFailObject(error,
+                                        limitCode,
+                                        fieldPath,
+                                        @"A directory entry limit was exceeded.");
+        }
+        size_t length = strlen(name);
+        NSData *nameData = [NSData dataWithBytes:name length:length];
+        [names addObject:nameData];
+    }
+    int enumerationError = errno;
+    if (closedir(directory) != 0 && enumerationError == 0) {
+        enumerationError = errno ?: EIO;
+    }
+    if (enumerationError != 0) {
+        return PXMainDataFailObject(error,
+                                    code,
+                                    fieldPath,
+                                    @"Directory enumeration did not complete safely.");
+    }
+
+    return [names sortedArrayUsingComparator:^NSComparisonResult(NSData *left, NSData *right) {
+        return PXMainDataCompareRawNames(left, right);
+    }];
+}
+
+static char *PXMainDataCopyTerminatedName(NSData *nameData) {
+    if (nameData.length > SIZE_MAX - 1) {
+        return NULL;
+    }
+    char *name = calloc(nameData.length + 1, 1);
+    if (!name) {
+        return NULL;
+    }
+    if (nameData.length > 0) {
+        memcpy(name, nameData.bytes, nameData.length);
+    }
+    return name;
+}
+
+static BOOL PXMainDataRawNameEquals(NSData *nameData, const char *literal) {
+    size_t length = strlen(literal);
+    return nameData.length == length &&
+           (length == 0 || memcmp(nameData.bytes, literal, length) == 0);
+}
+
+static NSString *PXMainDataStrictStringForName(NSData *nameData) {
+    NSString *value = [[NSString alloc] initWithData:nameData
+                                             encoding:NSUTF8StringEncoding];
+    if (!value) {
+        return nil;
+    }
+    NSData *roundTrip = [value dataUsingEncoding:NSUTF8StringEncoding
+                            allowLossyConversion:NO];
+    if (!roundTrip || ![roundTrip isEqualToData:nameData]) {
+        return nil;
+    }
+    return value;
+}
+
+static BOOL PXMainDataNameBytesAreSafe(NSData *nameData) {
+    if (nameData.length == 0 || nameData.length > PXMainDataMaximumComponentBytes) {
+        return NO;
+    }
+    const unsigned char *bytes = nameData.bytes;
+    for (NSUInteger index = 0; index < nameData.length; index++) {
+        unsigned char value = bytes[index];
+        if (value == 0 || value < 0x20 || value == 0x7f || value == '\\' || value == '/') {
+            return NO;
+        }
+    }
+    return !PXMainDataRawNameEquals(nameData, ".") &&
+           !PXMainDataRawNameEquals(nameData, "..");
+}
+
+static NSData *PXMainDataRelativePath(NSData *parent,
+                                      NSData *name,
+                                      NSError **error,
+                                      NSString *fieldPath) {
+    NSUInteger separatorLength = parent.length > 0 ? 1 : 0;
+    if (parent.length > NSUIntegerMax - separatorLength ||
+        parent.length + separatorLength > NSUIntegerMax - name.length) {
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorLimitExceeded,
+                                    fieldPath,
+                                    @"A staged path length overflowed.");
+    }
+    NSUInteger totalLength = parent.length + separatorLength + name.length;
+    if (totalLength > PXMainDataMaximumPathBytes) {
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorUnsafeEntryPath,
+                                    fieldPath,
+                                    @"A staged path exceeds the fixed path limit.");
+    }
+    NSMutableData *path = [NSMutableData dataWithCapacity:totalLength];
+    if (parent.length > 0) {
+        [path appendData:parent];
+        const unsigned char separator = '/';
+        [path appendBytes:&separator length:1];
+    }
+    [path appendData:name];
+    return [path copy];
+}
+
+static void PXMainDataHashUInt32(CC_SHA256_CTX *context, uint32_t value) {
+    unsigned char bytes[4] = {
+        (unsigned char)((value >> 24) & 0xff),
+        (unsigned char)((value >> 16) & 0xff),
+        (unsigned char)((value >> 8) & 0xff),
+        (unsigned char)(value & 0xff)
+    };
+    CC_SHA256_Update(context, bytes, (CC_LONG)sizeof(bytes));
+}
+
+static void PXMainDataHashUInt64(CC_SHA256_CTX *context, uint64_t value) {
+    unsigned char bytes[8] = {
+        (unsigned char)((value >> 56) & 0xff),
+        (unsigned char)((value >> 48) & 0xff),
+        (unsigned char)((value >> 40) & 0xff),
+        (unsigned char)((value >> 32) & 0xff),
+        (unsigned char)((value >> 24) & 0xff),
+        (unsigned char)((value >> 16) & 0xff),
+        (unsigned char)((value >> 8) & 0xff),
+        (unsigned char)(value & 0xff)
+    };
+    CC_SHA256_Update(context, bytes, (CC_LONG)sizeof(bytes));
+}
+
+static void PXMainDataHashEntryHeader(CC_SHA256_CTX *context,
+                                      unsigned char type,
+                                      NSData *relativePath,
+                                      mode_t mode,
+                                      uint64_t size) {
+    CC_SHA256_Update(context, &type, 1);
+    PXMainDataHashUInt32(context, (uint32_t)relativePath.length);
+    if (relativePath.length > 0) {
+        CC_SHA256_Update(context, relativePath.bytes, (CC_LONG)relativePath.length);
+    }
+    PXMainDataHashUInt32(context, (uint32_t)(mode & 07777));
+    PXMainDataHashUInt64(context, size);
+}
+
+static NSString *PXMainDataLowercaseHexDigest(const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
+    static const char hex[] = "0123456789abcdef";
+    char output[(CC_SHA256_DIGEST_LENGTH * 2) + 1];
+    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
+        output[index * 2] = hex[(digest[index] >> 4) & 0x0f];
+        output[(index * 2) + 1] = hex[digest[index] & 0x0f];
+    }
+    output[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
+    return [NSString stringWithUTF8String:output];
+}
+
+@interface PXStageDirectoryFrame : NSObject
+@property (nonatomic, assign) int descriptor;
+@property (nonatomic, copy) NSArray<NSData *> *names;
+@property (nonatomic, assign) NSUInteger nextIndex;
+@property (nonatomic, copy) NSData *relativePath;
+@property (nonatomic, copy) NSString *fieldPath;
+@property (nonatomic, assign) NSUInteger depth;
+@property (nonatomic, assign) PXMainDataIdentity identity;
+@end
+
+@implementation PXStageDirectoryFrame
+- (instancetype)init {
+    self = [super init];
+    if (self) {
+        _descriptor = -1;
+    }
+    return self;
+}
+- (void)dealloc {
+    if (_descriptor >= 0) {
+        close(_descriptor);
+        _descriptor = -1;
+    }
+}
+@end
+
+@interface PXCleanupDirectoryFrame : NSObject
+@property (nonatomic, assign) int descriptor;
+@property (nonatomic, copy) NSArray<NSData *> *names;
+@property (nonatomic, assign) NSUInteger nextIndex;
+@property (nonatomic, copy, nullable) NSData *entryName;
+@property (nonatomic, assign) NSUInteger depth;
+@property (nonatomic, assign) PXMainDataIdentity identity;
+@end
+
+@implementation PXCleanupDirectoryFrame
+- (instancetype)init {
+    self = [super init];
+    if (self) {
+        _descriptor = -1;
+    }
+    return self;
+}
+- (void)dealloc {
+    if (_descriptor >= 0) {
+        close(_descriptor);
+        _descriptor = -1;
+    }
+}
+@end
+
+static PXStageDirectoryFrame *PXMainDataCreateValidationFrame(int descriptor,
+                                                              NSData *relativePath,
+                                                              NSUInteger depth,
+                                                              NSUInteger maximumNameCount,
+                                                              dev_t expectedDevice,
+                                                              NSString *fieldPath,
+                                                              NSError **error) {
+    struct stat before;
+    struct stat after;
+    memset(&before, 0, sizeof(before));
+    memset(&after, 0, sizeof(after));
+    if (fstat(descriptor, &before) != 0 ||
+        !S_ISDIR(before.st_mode) ||
+        before.st_dev != expectedDevice ||
+        (before.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        close(descriptor);
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorUnsupportedEntryType,
+                                    fieldPath,
+                                    @"A staged directory is not supported.");
+    }
+    NSArray<NSData *> *names = PXMainDataReadDirectoryNames(descriptor,
+                                                           maximumNameCount,
+                                                           PXMainDataStagingErrorEnumerationFailed,
+                                                           PXMainDataStagingErrorLimitExceeded,
+                                                           fieldPath,
+                                                           error);
+    if (!names) {
+        close(descriptor);
+        return nil;
+    }
+    if (fstat(descriptor, &after) != 0 ||
+        !PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentityFromStat(&before), &after)) {
+        close(descriptor);
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorFilesystemChanged,
+                                    fieldPath,
+                                    @"A staged directory changed during enumeration.");
+    }
+    PXStageDirectoryFrame *frame = [[PXStageDirectoryFrame alloc] init];
+    frame.descriptor = descriptor;
+    frame.names = names;
+    frame.nextIndex = 0;
+    frame.relativePath = [relativePath copy];
+    frame.fieldPath = [fieldPath copy];
+    frame.depth = depth;
+    frame.identity = PXMainDataIdentityFromStat(&before);
+    return frame;
+}
+
+static BOOL PXMainDataCleanupStatsMatch(const struct stat *first,
+                                        const struct stat *second) {
+    return first->st_dev == second->st_dev &&
+           first->st_ino == second->st_ino &&
+           ((first->st_mode & S_IFMT) == (second->st_mode & S_IFMT));
+}
+
+@interface PXValidatedMainDataStage ()
+- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
+                                 dataPath:(NSString *)dataPath
+                               entryCount:(NSUInteger)entryCount
+                         regularFileCount:(NSUInteger)regularFileCount
+                           directoryCount:(NSUInteger)directoryCount
+                         regularFileBytes:(unsigned long long)regularFileBytes
+                               treeSHA256:(NSString *)treeSHA256;
+@end
+
+@implementation PXValidatedMainDataStage
+
+- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
+                                 dataPath:(NSString *)dataPath
+                               entryCount:(NSUInteger)entryCount
+                         regularFileCount:(NSUInteger)regularFileCount
+                           directoryCount:(NSUInteger)directoryCount
+                         regularFileBytes:(unsigned long long)regularFileBytes
+                               treeSHA256:(NSString *)treeSHA256 {
+    self = [super init];
+    if (self) {
+        _workspaceRootPath = [workspaceRootPath copy];
+        _dataPath = [dataPath copy];
+        _entryCount = entryCount;
+        _regularFileCount = regularFileCount;
+        _directoryCount = directoryCount;
+        _regularFileBytes = regularFileBytes;
+        _treeSHA256 = [treeSHA256 copy];
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
+@interface PXMainDataStagingWorkspace ()
+@property (nonatomic, copy, readwrite) NSString *rootPath;
+@property (nonatomic, copy, readwrite) NSString *dataPath;
+@property (nonatomic, copy) NSString *rootBasename;
+@property (nonatomic, assign) int parentDescriptor;
+@property (nonatomic, assign) int rootDescriptor;
+@property (nonatomic, assign) int dataDescriptor;
+@property (nonatomic, assign) PXMainDataIdentity parentIdentity;
+@property (nonatomic, assign) PXMainDataIdentity rootIdentity;
+@property (nonatomic, assign) PXMainDataIdentity dataIdentity;
+@property (nonatomic, assign) BOOL cleaned;
+- (instancetype)initWithRootPath:(NSString *)rootPath
+                        dataPath:(NSString *)dataPath
+                    rootBasename:(NSString *)rootBasename
+                parentDescriptor:(int)parentDescriptor
+                  rootDescriptor:(int)rootDescriptor
+                  dataDescriptor:(int)dataDescriptor
+                  parentIdentity:(PXMainDataIdentity)parentIdentity
+                    rootIdentity:(PXMainDataIdentity)rootIdentity
+                    dataIdentity:(PXMainDataIdentity)dataIdentity;
+- (BOOL)verifyWorkspaceIdentityWithError:(NSError * _Nullable * _Nullable)error;
+- (BOOL)closeOwnedDescriptorsAfterCleanupFailure:(NSError * _Nullable * _Nullable)error;
+@end
+
+@implementation PXMainDataStagingWorkspace
+
+- (instancetype)initWithRootPath:(NSString *)rootPath
+                        dataPath:(NSString *)dataPath
+                    rootBasename:(NSString *)rootBasename
+                parentDescriptor:(int)parentDescriptor
+                  rootDescriptor:(int)rootDescriptor
+                  dataDescriptor:(int)dataDescriptor
+                  parentIdentity:(PXMainDataIdentity)parentIdentity
+                    rootIdentity:(PXMainDataIdentity)rootIdentity
+                    dataIdentity:(PXMainDataIdentity)dataIdentity {
+    self = [super init];
+    if (self) {
+        _rootPath = [rootPath copy];
+        _dataPath = [dataPath copy];
+        _rootBasename = [rootBasename copy];
+        _parentDescriptor = parentDescriptor;
+        _rootDescriptor = rootDescriptor;
+        _dataDescriptor = dataDescriptor;
+        _parentIdentity = parentIdentity;
+        _rootIdentity = rootIdentity;
+        _dataIdentity = dataIdentity;
+        _cleaned = NO;
+    }
+    return self;
+}
+
++ (instancetype)createWorkspaceWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    int parentDescriptor = -1;
+    int rootDescriptor = -1;
+    int dataDescriptor = -1;
+    BOOL rootCreated = NO;
+    BOOL dataCreated = NO;
+    NSString *rootBasename = nil;
+    NSString *rootPath = nil;
+    NSString *dataPath = nil;
+    PXMainDataStagingErrorCode failureCode = PXMainDataStagingErrorWorkspaceCreationFailed;
+    NSString *failureField = @"$.workspace";
+    NSString *failureDescription = @"The private main-data staging workspace could not be created.";
+
+    struct stat parentPathStat;
+    memset(&parentPathStat, 0, sizeof(parentPathStat));
+    if (lstat(PXMainDataStagingParentPath.fileSystemRepresentation, &parentPathStat) != 0 ||
+        !S_ISDIR(parentPathStat.st_mode)) {
+        goto failure;
+    }
+
+    parentDescriptor = open(PXMainDataStagingParentPath.fileSystemRepresentation,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (parentDescriptor < 0 || !PXMainDataSetCloseOnExec(parentDescriptor)) {
+        goto failure;
+    }
+    struct stat parentDescriptorStat;
+    memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
+    if (fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
+        !S_ISDIR(parentDescriptorStat.st_mode) ||
+        parentDescriptorStat.st_dev != parentPathStat.st_dev ||
+        parentDescriptorStat.st_ino != parentPathStat.st_ino) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+
+    char workspaceTemplate[] = "/private/var/tmp/weaponx_restore_main.XXXXXX";
+    char *generatedPath = mkdtemp(workspaceTemplate);
+    if (!generatedPath) {
+        goto failure;
+    }
+    rootCreated = YES;
+
+    const char prefix[] = "/private/var/tmp/";
+    size_t prefixLength = sizeof(prefix) - 1;
+    size_t generatedLength = strlen(generatedPath);
+    if (generatedLength <= prefixLength ||
+        memcmp(generatedPath, prefix, prefixLength) != 0 ||
+        strchr(generatedPath + prefixLength, '/') != NULL) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+    rootBasename = [NSString stringWithUTF8String:generatedPath + prefixLength];
+    rootPath = [NSString stringWithUTF8String:generatedPath];
+    if (!rootBasename.length || !rootPath.length ||
+        ![rootBasename hasPrefix:@"weaponx_restore_main."]) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+
+    struct stat parentPathAfterCreation;
+    memset(&parentPathAfterCreation, 0, sizeof(parentPathAfterCreation));
+    if (lstat(PXMainDataStagingParentPath.fileSystemRepresentation,
+              &parentPathAfterCreation) != 0 ||
+        !S_ISDIR(parentPathAfterCreation.st_mode) ||
+        parentPathAfterCreation.st_dev != parentDescriptorStat.st_dev ||
+        parentPathAfterCreation.st_ino != parentDescriptorStat.st_ino) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+
+    struct stat rootPathStat;
+    memset(&rootPathStat, 0, sizeof(rootPathStat));
+    if (lstat(generatedPath, &rootPathStat) != 0 || !S_ISDIR(rootPathStat.st_mode)) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+    rootDescriptor = openat(parentDescriptor,
+                            rootBasename.fileSystemRepresentation,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (rootDescriptor < 0 || !PXMainDataSetCloseOnExec(rootDescriptor)) {
+        goto failure;
+    }
+    struct stat rootDescriptorStat;
+    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
+    if (fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
+        !S_ISDIR(rootDescriptorStat.st_mode) ||
+        rootDescriptorStat.st_dev != rootPathStat.st_dev ||
+        rootDescriptorStat.st_ino != rootPathStat.st_ino) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+    if ((rootDescriptorStat.st_mode & 07777) != 0700) {
+        if (fchmod(rootDescriptor, 0700) != 0 ||
+            fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
+            (rootDescriptorStat.st_mode & 07777) != 0700) {
+            goto failure;
+        }
+    }
+
+    if (mkdirat(rootDescriptor, "data", 0700) != 0) {
+        goto failure;
+    }
+    dataCreated = YES;
+    dataDescriptor = openat(rootDescriptor,
+                            "data",
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (dataDescriptor < 0 || !PXMainDataSetCloseOnExec(dataDescriptor)) {
+        goto failure;
+    }
+    struct stat dataDescriptorStat;
+    memset(&dataDescriptorStat, 0, sizeof(dataDescriptorStat));
+    if (fstat(dataDescriptor, &dataDescriptorStat) != 0 ||
+        !S_ISDIR(dataDescriptorStat.st_mode)) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+    if ((dataDescriptorStat.st_mode & 07777) != 0700) {
+        if (fchmod(dataDescriptor, 0700) != 0 ||
+            fstat(dataDescriptor, &dataDescriptorStat) != 0 ||
+            (dataDescriptorStat.st_mode & 07777) != 0700) {
+            goto failure;
+        }
+    }
+
+    struct stat dataPathStat;
+    memset(&dataPathStat, 0, sizeof(dataPathStat));
+    if (fstatat(rootDescriptor, "data", &dataPathStat, AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(dataPathStat.st_mode) ||
+        dataPathStat.st_dev != dataDescriptorStat.st_dev ||
+        dataPathStat.st_ino != dataDescriptorStat.st_ino ||
+        dataDescriptorStat.st_dev != rootDescriptorStat.st_dev) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        failureField = @"$.data";
+        goto failure;
+    }
+
+    if (fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
+        fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
+        fstat(dataDescriptor, &dataDescriptorStat) != 0) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+    if ((rootDescriptorStat.st_mode & 07777) != 0700 ||
+        (dataDescriptorStat.st_mode & 07777) != 0700 ||
+        (rootDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (dataDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        rootDescriptorStat.st_dev != dataDescriptorStat.st_dev) {
+        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
+        goto failure;
+    }
+
+    dataPath = [rootPath stringByAppendingPathComponent:@"data"];
+    if (!dataPath.length) {
+        goto failure;
+    }
+
+    return [[self alloc] initWithRootPath:rootPath
+                                dataPath:dataPath
+                            rootBasename:rootBasename
+                        parentDescriptor:parentDescriptor
+                          rootDescriptor:rootDescriptor
+                          dataDescriptor:dataDescriptor
+                          parentIdentity:PXMainDataIdentityFromStat(&parentDescriptorStat)
+                            rootIdentity:PXMainDataIdentityFromStat(&rootDescriptorStat)
+                            dataIdentity:PXMainDataIdentityFromStat(&dataDescriptorStat)];
+
+failure:
+    PXMainDataCloseDescriptor(&dataDescriptor);
+    if (rootDescriptor >= 0 && dataCreated) {
+        unlinkat(rootDescriptor, "data", AT_REMOVEDIR);
+    }
+    PXMainDataCloseDescriptor(&rootDescriptor);
+    if (parentDescriptor >= 0 && rootCreated && rootBasename.length) {
+        unlinkat(parentDescriptor,
+                 rootBasename.fileSystemRepresentation,
+                 AT_REMOVEDIR);
+    }
+    PXMainDataCloseDescriptor(&parentDescriptor);
+    PXMainDataFail(error, failureCode, failureField, failureDescription);
+    return nil;
+}
+
+- (BOOL)verifyWorkspaceIdentityWithError:(NSError **)error {
+    if (self.cleaned ||
+        self.parentDescriptor < 0 ||
+        self.rootDescriptor < 0 ||
+        self.dataDescriptor < 0 ||
+        !self.rootBasename.length) {
+        return PXMainDataFail(error,
+                              PXMainDataStagingErrorInvalidInput,
+                              @"$.workspace",
+                              @"The staging workspace is no longer available.");
+    }
+
+    struct stat parentPathStat;
+    struct stat parentDescriptorStat;
+    struct stat rootDescriptorStat;
+    struct stat dataDescriptorStat;
+    struct stat rootPathStat;
+    struct stat dataPathStat;
+    memset(&parentPathStat, 0, sizeof(parentPathStat));
+    memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
+    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
+    memset(&dataDescriptorStat, 0, sizeof(dataDescriptorStat));
+    memset(&rootPathStat, 0, sizeof(rootPathStat));
+    memset(&dataPathStat, 0, sizeof(dataPathStat));
+
+    if (lstat(PXMainDataStagingParentPath.fileSystemRepresentation,
+              &parentPathStat) != 0 ||
+        fstat(self.parentDescriptor, &parentDescriptorStat) != 0 ||
+        fstat(self.rootDescriptor, &rootDescriptorStat) != 0 ||
+        fstat(self.dataDescriptor, &dataDescriptorStat) != 0 ||
+        fstatat(self.parentDescriptor,
+                self.rootBasename.fileSystemRepresentation,
+                &rootPathStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        fstatat(self.rootDescriptor,
+                "data",
+                &dataPathStat,
+                AT_SYMLINK_NOFOLLOW) != 0) {
+        return PXMainDataFail(error,
+                              PXMainDataStagingErrorWorkspaceIdentityChanged,
+                              @"$.workspace",
+                              @"The staging workspace identity could not be verified.");
+    }
+
+    BOOL valid = S_ISDIR(parentPathStat.st_mode) &&
+                 S_ISDIR(parentDescriptorStat.st_mode) &&
+                 PXMainDataIdentityMatchesBasic(self.parentIdentity, &parentPathStat) &&
+                 S_ISDIR(rootDescriptorStat.st_mode) &&
+                 S_ISDIR(dataDescriptorStat.st_mode) &&
+                 S_ISDIR(rootPathStat.st_mode) &&
+                 S_ISDIR(dataPathStat.st_mode) &&
+                 PXMainDataIdentityMatchesBasic(self.parentIdentity, &parentDescriptorStat) &&
+                 PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootDescriptorStat) &&
+                 PXMainDataIdentityMatchesBasic(self.dataIdentity, &dataDescriptorStat) &&
+                 PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootPathStat) &&
+                 PXMainDataIdentityMatchesBasic(self.dataIdentity, &dataPathStat) &&
+                 rootDescriptorStat.st_dev == self.rootIdentity.device &&
+                 dataDescriptorStat.st_dev == self.rootIdentity.device &&
+                 rootPathStat.st_dev == self.rootIdentity.device &&
+                 dataPathStat.st_dev == self.rootIdentity.device &&
+                 (rootDescriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 (dataDescriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0;
+    if (!valid) {
+        return PXMainDataFail(error,
+                              PXMainDataStagingErrorWorkspaceIdentityChanged,
+                              @"$.workspace",
+                              @"The staging workspace identity changed.");
+    }
+    return YES;
+}
+
+- (BOOL)validateEmptyDataDirectoryWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (![self verifyWorkspaceIdentityWithError:error]) {
+        return NO;
+    }
+
+    struct stat rootBefore;
+    struct stat rootAfter;
+    struct stat dataBefore;
+    struct stat dataAfter;
+    memset(&rootBefore, 0, sizeof(rootBefore));
+    memset(&rootAfter, 0, sizeof(rootAfter));
+    memset(&dataBefore, 0, sizeof(dataBefore));
+    memset(&dataAfter, 0, sizeof(dataAfter));
+
+    if (fstat(self.rootDescriptor, &rootBefore) != 0 ||
+        fstat(self.dataDescriptor, &dataBefore) != 0) {
+        return PXMainDataFail(error,
+                              PXMainDataStagingErrorEnumerationFailed,
+                              @"$.workspace",
+                              @"The empty staging workspace could not be inspected.");
+    }
+
+    NSArray<NSData *> *rootNames = PXMainDataReadDirectoryNames(self.rootDescriptor,
+                                                               2,
+                                                               PXMainDataStagingErrorEnumerationFailed,
+                                                               PXMainDataStagingErrorWorkspaceNotEmpty,
+                                                               @"$.workspace",
+                                                               error);
+    if (!rootNames) {
+        return NO;
+    }
+    if (rootNames.count != 1 || !PXMainDataRawNameEquals(rootNames.firstObject, "data")) {
+        return PXMainDataFail(error,
+                              PXMainDataStagingErrorWorkspaceNotEmpty,
+                              @"$.workspace",
+                              @"The staging workspace root contains an unexpected entry.");
+    }
+
+    NSArray<NSData *> *dataNames = PXMainDataReadDirectoryNames(self.dataDescriptor,
+                                                               1,
+                                                               PXMainDataStagingErrorEnumerationFailed,
+                                                               PXMainDataStagingErrorWorkspaceNotEmpty,
+                                                               @"$.data",
+                                                               error);
+    if (!dataNames) {
+        return NO;
+    }
+    if (dataNames.count != 0) {
+        return PXMainDataFail(error,
+                              PXMainDataStagingErrorWorkspaceNotEmpty,
+                              @"$.data",
+                              @"The staging data directory is not empty.");
+    }
+
+    if (fstat(self.rootDescriptor, &rootAfter) != 0 ||
+        fstat(self.dataDescriptor, &dataAfter) != 0 ||
+        !PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentityFromStat(&rootBefore), &rootAfter) ||
+        !PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentityFromStat(&dataBefore), &dataAfter)) {
+        return PXMainDataFail(error,
+                              PXMainDataStagingErrorFilesystemChanged,
+                              @"$.workspace",
+                              @"The staging workspace changed during empty validation.");
+    }
+
+    return [self verifyWorkspaceIdentityWithError:error];
+}
+
+- (PXValidatedMainDataStage *)validatedStageWithExpectedLogicalMemberCount:(NSUInteger)logicalMemberCount
+                                                  expectedRegularFileBytes:(unsigned long long)regularFileBytes
+                                                                      error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (logicalMemberCount > PXMainDataMaximumLogicalMembers) {
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorLimitExceeded,
+                                    @"$.data",
+                                    @"The accepted archive member limit was exceeded.");
+    }
+    if (![self verifyWorkspaceIdentityWithError:error]) {
+        return nil;
+    }
+
+    NSUInteger maximumEntries = 0;
+    if (logicalMemberCount > 0) {
+        if (logicalMemberCount > NSUIntegerMax - PXMainDataMaximumImplicitDirectories) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        @"$.data",
+                                        @"The staged entry limit overflowed.");
+        }
+        maximumEntries = logicalMemberCount + PXMainDataMaximumImplicitDirectories;
+        if (maximumEntries > PXMainDataMaximumStagedEntries) {
+            maximumEntries = PXMainDataMaximumStagedEntries;
+        }
+    }
+
+    int rootDataDescriptor = PXMainDataDuplicateDescriptor(self.dataDescriptor);
+    if (rootDataDescriptor < 0) {
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorEnumerationFailed,
+                                    @"$.data",
+                                    @"The staged data root could not be opened for validation.");
+    }
+
+    NSError *frameError = nil;
+    PXStageDirectoryFrame *rootFrame = PXMainDataCreateValidationFrame(rootDataDescriptor,
+                                                                      [NSData data],
+                                                                      0,
+                                                                      maximumEntries,
+                                                                      self.dataIdentity.device,
+                                                                      @"$.data",
+                                                                      &frameError);
+    if (!rootFrame) {
+        if (error) {
+            *error = frameError;
+        }
+        return nil;
+    }
+
+    NSMutableArray<PXStageDirectoryFrame *> *stack = [NSMutableArray arrayWithObject:rootFrame];
+    NSUInteger enumeratedEntryCount = rootFrame.names.count;
+    NSUInteger entryCount = 0;
+    NSUInteger regularFileCount = 0;
+    NSUInteger directoryCount = 0;
+    unsigned long long actualRegularFileBytes = 0;
+    CC_SHA256_CTX digestContext;
+    CC_SHA256_Init(&digestContext);
+    static const unsigned char domainPrefix[] = "PXMainDataStageTreeV1";
+    CC_SHA256_Update(&digestContext, domainPrefix, (CC_LONG)sizeof(domainPrefix));
+
+    while (stack.count > 0) {
+        PXStageDirectoryFrame *frame = stack.lastObject;
+        if (frame.nextIndex >= frame.names.count) {
+            struct stat finalDirectoryStat;
+            memset(&finalDirectoryStat, 0, sizeof(finalDirectoryStat));
+            if (fstat(frame.descriptor, &finalDirectoryStat) != 0 ||
+                !PXMainDataIdentityMatchesStableDirectory(frame.identity, &finalDirectoryStat)) {
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorFilesystemChanged,
+                                            frame.fieldPath ?: @"$.data",
+                                            @"A staged directory changed during validation.");
+            }
+            [stack removeLastObject];
+            continue;
+        }
+
+        NSData *nameData = frame.names[frame.nextIndex++];
+        NSUInteger currentIndex = entryCount;
+        NSString *entryField = [NSString stringWithFormat:@"$.data.entries[%lu]",
+                                (unsigned long)currentIndex];
+        NSString *pathField = [entryField stringByAppendingString:@".path"];
+
+        if (!PXMainDataNameBytesAreSafe(nameData) || !PXMainDataStrictStringForName(nameData)) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorUnsafeEntryPath,
+                                        pathField,
+                                        @"A staged entry path is unsafe.");
+        }
+        if (frame.depth >= PXMainDataMaximumDepth) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        pathField,
+                                        @"The staged tree depth limit was exceeded.");
+        }
+        NSData *relativePath = PXMainDataRelativePath(frame.relativePath,
+                                                      nameData,
+                                                      error,
+                                                      pathField);
+        if (!relativePath) {
+            return nil;
+        }
+        NSUInteger entryDepth = frame.depth + 1;
+        if (entryDepth > PXMainDataMaximumDepth) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        pathField,
+                                        @"The staged tree depth limit was exceeded.");
+        }
+        if (entryCount == NSUIntegerMax || entryCount >= maximumEntries) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        entryField,
+                                        @"The staged entry limit was exceeded.");
+        }
+        entryCount++;
+
+        if (entryDepth == 1 &&
+            (PXMainDataRawNameEquals(nameData, ".com.apple.mobile_container_manager.metadata.plist") ||
+             PXMainDataRawNameEquals(nameData, ".com.apple.containermanagerd.metadata.plist"))) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorForbiddenContainerMetadata,
+                                        pathField,
+                                        @"A forbidden container metadata entry is present.");
+        }
+
+        char *entryName = PXMainDataCopyTerminatedName(nameData);
+        if (!entryName) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        entryField,
+                                        @"A staged entry name could not be represented safely.");
+        }
+        struct stat pathStat;
+        memset(&pathStat, 0, sizeof(pathStat));
+        int statResult = fstatat(frame.descriptor,
+                                entryName,
+                                &pathStat,
+                                AT_SYMLINK_NOFOLLOW);
+        if (statResult != 0) {
+            free(entryName);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorEnumerationFailed,
+                                        entryField,
+                                        @"A staged entry could not be inspected.");
+        }
+        if (pathStat.st_dev != self.dataIdentity.device ||
+            (pathStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+            free(entryName);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorUnsupportedEntryType,
+                                        entryField,
+                                        @"A staged entry type is not supported.");
+        }
+
+        if (S_ISDIR(pathStat.st_mode)) {
+            int childDescriptor = openat(frame.descriptor,
+                                         entryName,
+                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+            free(entryName);
+            if (childDescriptor < 0 || !PXMainDataSetCloseOnExec(childDescriptor)) {
+                if (childDescriptor >= 0) {
+                    close(childDescriptor);
+                }
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorFilesystemChanged,
+                                            entryField,
+                                            @"A staged directory could not be opened safely.");
+            }
+            struct stat openedDirectoryStat;
+            memset(&openedDirectoryStat, 0, sizeof(openedDirectoryStat));
+            if (fstat(childDescriptor, &openedDirectoryStat) != 0 ||
+                !S_ISDIR(openedDirectoryStat.st_mode) ||
+                openedDirectoryStat.st_dev != pathStat.st_dev ||
+                openedDirectoryStat.st_ino != pathStat.st_ino ||
+                (openedDirectoryStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+                close(childDescriptor);
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorFilesystemChanged,
+                                            entryField,
+                                            @"A staged directory identity changed.");
+            }
+            if (directoryCount == NSUIntegerMax) {
+                close(childDescriptor);
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorLimitExceeded,
+                                            entryField,
+                                            @"The staged directory count overflowed.");
+            }
+            directoryCount++;
+            PXMainDataHashEntryHeader(&digestContext,
+                                      'D',
+                                      relativePath,
+                                      openedDirectoryStat.st_mode,
+                                      0);
+            if (enumeratedEntryCount > maximumEntries) {
+                close(childDescriptor);
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorLimitExceeded,
+                                            entryField,
+                                            @"The staged entry limit was exceeded.");
+            }
+            NSUInteger remainingEntryBudget = maximumEntries - enumeratedEntryCount;
+            PXStageDirectoryFrame *childFrame =
+                PXMainDataCreateValidationFrame(childDescriptor,
+                                                relativePath,
+                                                entryDepth,
+                                                remainingEntryBudget,
+                                                self.dataIdentity.device,
+                                                entryField,
+                                                error);
+            if (!childFrame) {
+                return nil;
+            }
+            if (childFrame.names.count > maximumEntries - enumeratedEntryCount) {
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorLimitExceeded,
+                                            entryField,
+                                            @"The staged entry limit was exceeded.");
+            }
+            enumeratedEntryCount += childFrame.names.count;
+            [stack addObject:childFrame];
+            continue;
+        }
+
+        if (!S_ISREG(pathStat.st_mode)) {
+            free(entryName);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorUnsupportedEntryType,
+                                        entryField,
+                                        @"A staged entry type is not supported.");
+        }
+        if (pathStat.st_nlink != 1) {
+            free(entryName);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorHardLinkRejected,
+                                        entryField,
+                                        @"A staged hard-linked file is not supported.");
+        }
+
+        int fileDescriptor = openat(frame.descriptor,
+                                    entryName,
+                                    O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+        free(entryName);
+        if (fileDescriptor < 0 || !PXMainDataSetCloseOnExec(fileDescriptor)) {
+            if (fileDescriptor >= 0) {
+                close(fileDescriptor);
+            }
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorFilesystemChanged,
+                                        entryField,
+                                        @"A staged file could not be opened safely.");
+        }
+
+        struct stat fileBefore;
+        memset(&fileBefore, 0, sizeof(fileBefore));
+        if (fstat(fileDescriptor, &fileBefore) != 0 ||
+            !S_ISREG(fileBefore.st_mode) ||
+            fileBefore.st_dev != self.dataIdentity.device ||
+            fileBefore.st_dev != pathStat.st_dev ||
+            fileBefore.st_ino != pathStat.st_ino ||
+            fileBefore.st_nlink != 1 ||
+            fileBefore.st_size < 0 ||
+            (fileBefore.st_mode & (S_ISUID | S_ISGID)) != 0) {
+            close(fileDescriptor);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorFilesystemChanged,
+                                        entryField,
+                                        @"A staged file identity changed.");
+        }
+
+        unsigned long long fileSize = (unsigned long long)fileBefore.st_size;
+        if (actualRegularFileBytes > ULLONG_MAX - fileSize) {
+            close(fileDescriptor);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        @"$.data.regularFileBytes",
+                                        @"The staged regular-file byte total overflowed.");
+        }
+        if (regularFileCount == NSUIntegerMax || regularFileCount >= logicalMemberCount) {
+            close(fileDescriptor);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        entryField,
+                                        @"The staged regular-file count exceeds the accepted archive summary.");
+        }
+        regularFileCount++;
+        PXMainDataHashEntryHeader(&digestContext,
+                                  'F',
+                                  relativePath,
+                                  fileBefore.st_mode,
+                                  fileSize);
+
+        unsigned char buffer[PXMainDataReadBufferSize];
+        unsigned long long bytesRead = 0;
+        for (;;) {
+            ssize_t amount = read(fileDescriptor, buffer, sizeof(buffer));
+            if (amount < 0 && errno == EINTR) {
+                continue;
+            }
+            if (amount < 0) {
+                close(fileDescriptor);
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorReadFailed,
+                                            entryField,
+                                            @"A staged file could not be read completely.");
+            }
+            if (amount == 0) {
+                break;
+            }
+            if (bytesRead > ULLONG_MAX - (unsigned long long)amount) {
+                close(fileDescriptor);
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorLimitExceeded,
+                                            @"$.data.regularFileBytes",
+                                            @"The staged read byte count overflowed.");
+            }
+            bytesRead += (unsigned long long)amount;
+            if (bytesRead > fileSize) {
+                close(fileDescriptor);
+                return PXMainDataFailObject(error,
+                                            PXMainDataStagingErrorFilesystemChanged,
+                                            entryField,
+                                            @"A staged file changed while it was read.");
+            }
+            CC_SHA256_Update(&digestContext, buffer, (CC_LONG)amount);
+        }
+
+        struct stat fileAfter;
+        memset(&fileAfter, 0, sizeof(fileAfter));
+        if (fstat(fileDescriptor, &fileAfter) != 0) {
+            close(fileDescriptor);
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorReadFailed,
+                                        entryField,
+                                        @"A staged file could not be rechecked after reading.");
+        }
+        close(fileDescriptor);
+        if (bytesRead != fileSize) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorReadFailed,
+                                        entryField,
+                                        @"A staged file read was incomplete.");
+        }
+        if (!PXMainDataStableFileStatsEqual(&fileBefore, &fileAfter)) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorFilesystemChanged,
+                                        entryField,
+                                        @"A staged file changed while it was read.");
+        }
+        actualRegularFileBytes += fileSize;
+    }
+
+    if (entryCount > logicalMemberCount) {
+        NSUInteger derivedDirectories = entryCount - logicalMemberCount;
+        if (derivedDirectories > PXMainDataMaximumImplicitDirectories) {
+            return PXMainDataFailObject(error,
+                                        PXMainDataStagingErrorLimitExceeded,
+                                        @"$.data",
+                                        @"The staged implicit-directory limit was exceeded.");
+        }
+    }
+    if (regularFileCount > logicalMemberCount) {
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorLimitExceeded,
+                                    @"$.data",
+                                    @"The staged regular-file count exceeds the accepted archive summary.");
+    }
+    if (actualRegularFileBytes != regularFileBytes) {
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorSizeMismatch,
+                                    @"$.data.regularFileBytes",
+                                    @"The staged regular-file byte total does not match the accepted archive summary.");
+    }
+    if (![self verifyWorkspaceIdentityWithError:error]) {
+        return nil;
+    }
+
+    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
+    CC_SHA256_Final(digest, &digestContext);
+    NSString *treeSHA256 = PXMainDataLowercaseHexDigest(digest);
+    if (treeSHA256.length != CC_SHA256_DIGEST_LENGTH * 2) {
+        return PXMainDataFailObject(error,
+                                    PXMainDataStagingErrorReadFailed,
+                                    @"$.data",
+                                    @"The staged tree digest could not be finalized.");
+    }
+
+    return [[PXValidatedMainDataStage alloc]
+        initWithWorkspaceRootPath:self.rootPath
+                        dataPath:self.dataPath
+                      entryCount:entryCount
+                regularFileCount:regularFileCount
+                  directoryCount:directoryCount
+                regularFileBytes:actualRegularFileBytes
+                      treeSHA256:treeSHA256];
+}
+
+- (BOOL)closeOwnedDescriptorsAfterCleanupFailure:(NSError **)error {
+    PXMainDataCloseDescriptor(&_dataDescriptor);
+    PXMainDataCloseDescriptor(&_rootDescriptor);
+    PXMainDataCloseDescriptor(&_parentDescriptor);
+    return PXMainDataFail(error,
+                          PXMainDataStagingErrorCleanupFailed,
+                          @"$.workspace",
+                          @"The staging workspace could not be cleaned safely.");
+}
+
+- (BOOL)cleanupWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (self.cleaned) {
+        return YES;
+    }
+    if (self.parentDescriptor < 0 ||
+        self.rootDescriptor < 0 ||
+        !self.rootBasename.length) {
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+
+    struct stat retainedParentStat;
+    struct stat retainedRootStat;
+    struct stat namespaceRootStat;
+    memset(&retainedParentStat, 0, sizeof(retainedParentStat));
+    memset(&retainedRootStat, 0, sizeof(retainedRootStat));
+    memset(&namespaceRootStat, 0, sizeof(namespaceRootStat));
+    if (fstat(self.parentDescriptor, &retainedParentStat) != 0 ||
+        fstat(self.rootDescriptor, &retainedRootStat) != 0 ||
+        !PXMainDataIdentityMatchesBasic(self.parentIdentity, &retainedParentStat) ||
+        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &retainedRootStat)) {
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+    if (fstatat(self.parentDescriptor,
+                self.rootBasename.fileSystemRepresentation,
+                &namespaceRootStat,
+                AT_SYMLINK_NOFOLLOW) != 0) {
+        if (errno == ENOENT) {
+            PXMainDataCloseDescriptor(&_dataDescriptor);
+            PXMainDataCloseDescriptor(&_rootDescriptor);
+            PXMainDataCloseDescriptor(&_parentDescriptor);
+            self.cleaned = YES;
+            return YES;
+        }
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+    if (!PXMainDataIdentityMatchesBasic(self.rootIdentity, &namespaceRootStat) ||
+        !S_ISDIR(namespaceRootStat.st_mode)) {
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+
+    NSError *identityError = nil;
+    if (![self verifyWorkspaceIdentityWithError:&identityError]) {
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+
+    PXMainDataCloseDescriptor(&_dataDescriptor);
+    int cleanupRootDescriptor = PXMainDataDuplicateDescriptor(self.rootDescriptor);
+    if (cleanupRootDescriptor < 0) {
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+    struct stat cleanupRootStat;
+    memset(&cleanupRootStat, 0, sizeof(cleanupRootStat));
+    if (fstat(cleanupRootDescriptor, &cleanupRootStat) != 0 ||
+        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &cleanupRootStat)) {
+        close(cleanupRootDescriptor);
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+
+    NSError *enumerationError = nil;
+    NSArray<NSData *> *rootNames = PXMainDataReadDirectoryNames(cleanupRootDescriptor,
+                                                               PXMainDataMaximumCleanupEntries,
+                                                               PXMainDataStagingErrorCleanupFailed,
+                                                               PXMainDataStagingErrorCleanupFailed,
+                                                               @"$.workspace",
+                                                               &enumerationError);
+    if (!rootNames) {
+        close(cleanupRootDescriptor);
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+
+    PXCleanupDirectoryFrame *rootFrame = [[PXCleanupDirectoryFrame alloc] init];
+    rootFrame.descriptor = cleanupRootDescriptor;
+    rootFrame.names = rootNames;
+    rootFrame.nextIndex = 0;
+    rootFrame.entryName = nil;
+    rootFrame.depth = 0;
+    rootFrame.identity = PXMainDataIdentityFromStat(&cleanupRootStat);
+    NSMutableArray<PXCleanupDirectoryFrame *> *stack = [NSMutableArray arrayWithObject:rootFrame];
+    NSUInteger enumeratedCleanupEntryCount = rootNames.count;
+    NSUInteger cleanupEntryCount = 0;
+
+    while (stack.count > 0) {
+        PXCleanupDirectoryFrame *frame = stack.lastObject;
+        if (frame.nextIndex >= frame.names.count) {
+            if (stack.count == 1) {
+                [stack removeLastObject];
+                break;
+            }
+            PXCleanupDirectoryFrame *parent = stack[stack.count - 2];
+            char *childName = PXMainDataCopyTerminatedName(frame.entryName);
+            if (!childName) {
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            struct stat descriptorStat;
+            struct stat pathStat;
+            memset(&descriptorStat, 0, sizeof(descriptorStat));
+            memset(&pathStat, 0, sizeof(pathStat));
+            BOOL childIdentityValid =
+                fstat(frame.descriptor, &descriptorStat) == 0 &&
+                fstatat(parent.descriptor, childName, &pathStat, AT_SYMLINK_NOFOLLOW) == 0 &&
+                S_ISDIR(descriptorStat.st_mode) &&
+                S_ISDIR(pathStat.st_mode) &&
+                PXMainDataIdentityMatchesBasic(frame.identity, &descriptorStat) &&
+                PXMainDataIdentityMatchesBasic(frame.identity, &pathStat) &&
+                descriptorStat.st_dev == self.rootIdentity.device;
+            if (!childIdentityValid) {
+                free(childName);
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            if (unlinkat(parent.descriptor, childName, AT_REMOVEDIR) != 0) {
+                free(childName);
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            close(frame.descriptor);
+            frame.descriptor = -1;
+            free(childName);
+            [stack removeLastObject];
+            continue;
+        }
+
+        if (cleanupEntryCount == NSUIntegerMax ||
+            cleanupEntryCount >= PXMainDataMaximumCleanupEntries) {
+            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+        }
+        cleanupEntryCount++;
+
+        NSData *nameData = frame.names[frame.nextIndex++];
+        char *entryName = PXMainDataCopyTerminatedName(nameData);
+        if (!entryName) {
+            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+        }
+        struct stat firstStat;
+        memset(&firstStat, 0, sizeof(firstStat));
+        if (fstatat(frame.descriptor,
+                    entryName,
+                    &firstStat,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            firstStat.st_dev != self.rootIdentity.device) {
+            free(entryName);
+            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+        }
+        BOOL isRootDataEntry =
+            stack.count == 1 && PXMainDataRawNameEquals(nameData, "data");
+        if (isRootDataEntry &&
+            (!S_ISDIR(firstStat.st_mode) ||
+             !PXMainDataIdentityMatchesBasic(self.dataIdentity, &firstStat))) {
+            free(entryName);
+            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+        }
+
+        if (S_ISDIR(firstStat.st_mode)) {
+            BOOL isRetainedDataDirectory =
+                stack.count == 1 && PXMainDataRawNameEquals(nameData, "data");
+            NSUInteger childDepth = frame.depth;
+            if (!isRetainedDataDirectory) {
+                if (frame.depth >= PXMainDataMaximumDepth) {
+                    free(entryName);
+                    return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+                }
+                childDepth = frame.depth + 1;
+            }
+            int childDescriptor = openat(frame.descriptor,
+                                         entryName,
+                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+            if (childDescriptor < 0 || !PXMainDataSetCloseOnExec(childDescriptor)) {
+                if (childDescriptor >= 0) {
+                    close(childDescriptor);
+                }
+                free(entryName);
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            struct stat openedStat;
+            memset(&openedStat, 0, sizeof(openedStat));
+            if (fstat(childDescriptor, &openedStat) != 0 ||
+                !PXMainDataCleanupStatsMatch(&firstStat, &openedStat) ||
+                !S_ISDIR(openedStat.st_mode) ||
+                openedStat.st_dev != self.rootIdentity.device) {
+                close(childDescriptor);
+                free(entryName);
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            if (enumeratedCleanupEntryCount > PXMainDataMaximumCleanupEntries) {
+                close(childDescriptor);
+                free(entryName);
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            NSUInteger remainingCleanupBudget =
+                PXMainDataMaximumCleanupEntries - enumeratedCleanupEntryCount;
+            NSArray<NSData *> *childNames = PXMainDataReadDirectoryNames(childDescriptor,
+                                                                        remainingCleanupBudget,
+                                                                        PXMainDataStagingErrorCleanupFailed,
+                                                                        PXMainDataStagingErrorCleanupFailed,
+                                                                        @"$.workspace",
+                                                                        &enumerationError);
+            if (!childNames) {
+                close(childDescriptor);
+                free(entryName);
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            PXCleanupDirectoryFrame *childFrame = [[PXCleanupDirectoryFrame alloc] init];
+            childFrame.descriptor = childDescriptor;
+            childFrame.names = childNames;
+            if (childNames.count >
+                PXMainDataMaximumCleanupEntries - enumeratedCleanupEntryCount) {
+                close(childDescriptor);
+                free(entryName);
+                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+            }
+            enumeratedCleanupEntryCount += childNames.count;
+            childFrame.nextIndex = 0;
+            childFrame.entryName = nameData;
+            childFrame.depth = childDepth;
+            childFrame.identity = PXMainDataIdentityFromStat(&openedStat);
+            [stack addObject:childFrame];
+            free(entryName);
+            continue;
+        }
+
+        struct stat secondStat;
+        memset(&secondStat, 0, sizeof(secondStat));
+        if (fstatat(frame.descriptor,
+                    entryName,
+                    &secondStat,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            !PXMainDataCleanupStatsMatch(&firstStat, &secondStat) ||
+            unlinkat(frame.descriptor, entryName, 0) != 0) {
+            free(entryName);
+            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+        }
+        free(entryName);
+    }
+
+    struct stat rootDescriptorStat;
+    struct stat rootPathStat;
+    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
+    memset(&rootPathStat, 0, sizeof(rootPathStat));
+    if (fstat(self.rootDescriptor, &rootDescriptorStat) != 0 ||
+        fstatat(self.parentDescriptor,
+                self.rootBasename.fileSystemRepresentation,
+                &rootPathStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootDescriptorStat) ||
+        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootPathStat) ||
+        !S_ISDIR(rootDescriptorStat.st_mode) ||
+        !S_ISDIR(rootPathStat.st_mode)) {
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+
+    if (unlinkat(self.parentDescriptor,
+                 self.rootBasename.fileSystemRepresentation,
+                 AT_REMOVEDIR) != 0) {
+        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
+    }
+    PXMainDataCloseDescriptor(&_rootDescriptor);
+    PXMainDataCloseDescriptor(&_parentDescriptor);
+    self.cleaned = YES;
+    return YES;
+}
+
+- (void)dealloc {
+    if (!self.cleaned) {
+        [self cleanupWithError:nil];
+    }
+    PXMainDataCloseDescriptor(&_dataDescriptor);
+    PXMainDataCloseDescriptor(&_rootDescriptor);
+    PXMainDataCloseDescriptor(&_parentDescriptor);
+}
+
+@end
```

## 15. Static and forbidden counts

Machine static/API/ordering gate before report generation: **92/92 PASS**.

| Gate/token | Count |
|---|---:|
| Public API exact match | 1 |
| Public error codes | 14 |
| Public restricted classes | 2 |
| Public mutable setters | 0 |
| Fixed parent literal | 1 |
| mkdtemp calls | 1 |
| Exact unique template | 1 |
| PID-only staging templates | 0 |
| mkdirat data calls | 1 |
| fchmod calls | 2 |
| fstatat calls | 9 |
| AT_SYMLINK_NOFOLLOW mentions | 9 |
| O_NOFOLLOW mentions | 6 |
| O_CLOEXEC mentions | 6 |
| fdopendir calls | 1 |
| readdir calls | 1 |
| unlinkat calls | 5 |
| CommonCrypto update calls | 6 |
| Forbidden metadata identities | 2 |
| Whole-file NSData loads | 0 |
| NSFileManager in staging source | 0 |
| Shell/process APIs in staging source | 0 |
| Logging APIs in staging source | 0 |
| Manager staging import | 1 |
| Restore workspace creation calls | 1 |
| Restore empty validation calls | 1 |
| Restore stage validation calls | 1 |
| Restore workspace.dataPath uses | 1 |
| Restore validatedStage.dataPath uses | 1 |
| Restore predictable staging paths | 0 |
| Restore staging removeItemAtPath | 0 |
| Restore staging createDirectoryAtPath | 0 |
| Legacy directory-content helper | 0 |
| Legacy File-exists continuation | 0 |
| Post-plan direct manifest reads | 0 |
| Post-plan local verified lookups | 0 |
| Post-plan local archive lookups | 0 |
| Restore workspace cleanup calls | 6 |

Forbidden staging-source imports/APIs (`UIKit`, manager/plan/validator classes, cleaner, runner, process/shell execution, Security/Keychain, defaults, dispatch/notifications, logging and NSFileManager mutation) are all zero.

## 16. Explicit scenario matrix

Scenario count: **170**. These are deterministic source/static expected outcomes; they do not claim target-device fault injection or runtime execution.

| # | Scenario | Expected | Evidence |
|---:|---|---|---|
| 1 | fixed parent exists as real directory | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 2 | fixed parent missing | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 3 | fixed parent final symlink | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 4 | fixed parent non-directory | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 5 | parent open failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 6 | mkdtemp success | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 7 | mkdtemp collision retry handled by libc | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 8 | mkdtemp failure cleanup | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 9 | generated root mode 0700 | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 10 | root fchmod failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 11 | root identity mismatch | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 12 | data mkdirat success | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 13 | data already exists unexpectedly | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 14 | data open no-follow | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 15 | data identity mismatch | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 16 | root/data device mismatch | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 17 | root contains only data | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 18 | root has unexpected sibling | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 19 | data empty accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 20 | data nonempty rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 21 | enumeration descriptor CLOEXEC | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 22 | empty validation clears prior error | Accept or perform the stated behavior exactly when all relevant invariants hold. | Workspace creation/identity/empty-gate source paths use fixed-parent descriptors, mkdtemp, 0700 verification and stable enumeration. |
| 23 | ordinary regular file accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 24 | ordinary directory accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 25 | nested valid tree accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 26 | symlink file rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 27 | symlink directory rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 28 | hard-linked regular file rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 29 | FIFO rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 30 | socket rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 31 | character device rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 32 | block device rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 33 | unknown type rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 34 | mount/device crossing rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 35 | setuid regular file rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 36 | setgid regular file rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 37 | setuid directory rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 38 | invalid UTF-8 component rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 39 | ASCII control component rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 40 | backslash component rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 41 | component 255 bytes accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 42 | component 256 bytes rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 43 | full path 4096 bytes accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 44 | full path 4097 bytes rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 45 | depth 2048 accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 46 | depth 2049 rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 47 | root mobile-container metadata rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 48 | root containermanagerd metadata rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 49 | case-different metadata name not broadened | Accept or perform the stated behavior exactly when all relevant invariants hold. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 50 | nested same metadata filename not broadly rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Deterministic fstatat/openat traversal applies strict UTF-8/path, type, link, device, mode and root-metadata policy. |
| 51 | expected zero bytes and empty stage accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 52 | expected zero bytes and zero-byte file handled | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 53 | expected nonzero bytes exact accepted | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 54 | actual fewer bytes rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 55 | actual more bytes rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 56 | byte-sum overflow rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 57 | regular file count <= logical count accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 58 | regular file count > logical count rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 59 | logical count zero and empty accepted | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 60 | logical count zero and directory rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 61 | derived implicit-directory allowance | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 62 | 400000 entry boundary accepted when allowed | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 63 | 400001 entry rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 64 | entry-count overflow rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 65 | file read retries EINTR | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 66 | non-EINTR read failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 67 | short read against stable size rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 68 | file device changes during read | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 69 | file inode changes during read | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 70 | file type changes during read | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 71 | file size changes during read | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 72 | file mtime changes during read | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 73 | file ctime changes during read | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 74 | file link count changes during read | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 75 | atime-only change ignored | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 76 | directory changes during enumeration | Fail closed with the specified staging/manager error and no unsafe target continuation. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 77 | directory atime-only change ignored | Accept or perform the stated behavior exactly when all relevant invariants hold. | Fixed limits and streaming pre/post-fstat byte accounting enforce the boundary without atime authority. |
| 78 | deterministic sibling byte ordering | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 79 | deterministic pre-order indexing | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 80 | digest domain prefix included | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 81 | digest includes type | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 82 | digest includes path length/path bytes | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 83 | digest includes mode | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 84 | digest includes file size | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 85 | digest includes file contents | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 86 | digest omits absolute staging path | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 87 | digest lowercase 64 hex | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 88 | identical tree gives identical digest | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 89 | content change changes digest | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 90 | path change changes digest | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 91 | validated result copies paths | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 92 | validated result counts files/directories | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 93 | validated result copyWithZone returns self | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 94 | workspace not copyable | Accept or perform the stated behavior exactly when all relevant invariants hold. | CommonCrypto pre-order digest and immutable result construction freeze the validated snapshot. |
| 95 | cleanup empty workspace | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 96 | cleanup populated workspace | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 97 | cleanup symlink without following | Fail closed with the specified staging/manager error and no unsafe target continuation. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 98 | cleanup special file without opening | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 99 | cleanup nested directories | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 100 | cleanup entry limit 500000 | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 101 | cleanup limit exceeded fails safely | Fail closed with the specified staging/manager error and no unsafe target continuation. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 102 | cleanup root replacement mismatch | Fail closed with the specified staging/manager error and no unsafe target continuation. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 103 | cleanup data replacement mismatch | Fail closed with the specified staging/manager error and no unsafe target continuation. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 104 | cleanup idempotent second call | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 105 | cleanup closes descriptors | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 106 | dealloc best-effort cleanup | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 107 | cleanup never rm -rf | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 108 | cleanup never NSFileManager recursive delete | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Iterative unlinkat cleanup is identity-bound, no-follow, bounded and idempotent. |
| 109 | plan summary member count present | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 110 | plan summary byte count present | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 111 | invalid summary fails before workspace creation | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 112 | main archive source from plan | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 113 | workspace data path used for extraction | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 114 | validated-stage data path used for clone | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 115 | predictable PID staging path removed | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 116 | manager direct staging mkdir removed | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 117 | manager direct staging remove removed | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 118 | extraction zero exit continues | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 119 | extraction nonzero fails 316 | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 120 | partial content plus nonzero still fails | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 121 | old File-exists continuation removed | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 122 | workspace cleanup on empty validation failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 123 | workspace cleanup on extraction failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 124 | workspace cleanup on stage validation failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 125 | workspace cleanup on target revalidation failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 126 | workspace cleanup on clone failure | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 127 | workspace cleanup on successful clone | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 128 | pre-mutation cleanup failure preserves primary error | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 129 | post-clone cleanup failure becomes generic warning | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 130 | stage validation precedes first process kill | Ordering invariant holds in Restore. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 131 | stage validation precedes target validator | Ordering invariant holds in Restore. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 132 | stage validation precedes target wipe | Ordering invariant holds in Restore. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 133 | stage validation precedes tar-pipe clone | Ordering invariant holds in Restore. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 134 | stage validation precedes cp fallback | Ordering invariant holds in Restore. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 135 | stage validation precedes target chown | Ordering invariant holds in Restore. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 136 | stage failure performs no optional-component mutation | Fail closed with the specified staging/manager error and no unsafe target continuation. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 137 | target revalidation code 303 preserved | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 138 | clone code 317 preserved | Accept or perform the stated behavior exactly when all relevant invariants hold. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 139 | tar preference list unchanged | Non-regression or later-task boundary remains intact. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 140 | tar xattr/ACL fallback retained | Non-regression or later-task boundary remains intact. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 141 | main target wipe semantics unchanged | Non-regression or later-task boundary remains intact. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 142 | main target chown unchanged | Non-regression or later-task boundary remains intact. | Restore consumes plan summaries, validates before first kill, preserves codes 303/316/317 and cleans every required path. |
| 143 | plan source unchanged | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 144 | archive validator unchanged | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 145 | artifact verifier unchanged | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 146 | Makefile unchanged | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 147 | App Group behavior unchanged | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 148 | optional-component behavior unchanged | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 149 | no main transaction or rollback | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 150 | TASK-2.9 remains unimplemented. | Non-regression or later-task boundary remains intact. | Canonical protected blobs/body hashes and scope checks preserve TASK-2.1 through TASK-2.7 and later-task boundaries. |
| 151 | create clears a preexisting NSError pointer | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 152 | empty validation clears a preexisting NSError pointer | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 153 | stage validation clears a preexisting NSError pointer | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 154 | cleanup clears a preexisting NSError pointer | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 155 | all staging errors contain only description and field-path keys | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 156 | staging errors omit absolute workspace paths and entry names | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 157 | directory enumeration resets duplicated descriptor offset before fdopendir | Ordering invariant holds in Restore. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 158 | duplicated enumeration descriptors verify FD_CLOEXEC | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 159 | fixed parent pathname replacement after creation is rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 160 | cleanup treats an already absent owned root as safely cleaned | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 161 | cleanup rejects a replacement root without deleting it | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 162 | cleanup rejects a replacement data directory without deleting it | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 163 | cleanup unlinks a symlink entry without traversing it | Fail closed with the specified staging/manager error and no unsafe target continuation. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 164 | cleanup unlinks a FIFO or socket without opening it | Fail closed with the specified staging/manager error and no unsafe target continuation. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 165 | CFBoolean archive-summary values are rejected | Fail closed with the specified staging/manager error and no unsafe target continuation. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 166 | unsigned 64-bit regular-byte summary remains representable | Non-regression or later-task boundary remains intact. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 167 | logical-member value above NSUIntegerMax fails before workspace creation | Fail closed with the specified staging/manager error and no unsafe target continuation. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 168 | tree digest masks mode to 07777 | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 169 | tree digest omits timestamps uid gid and inode | Accept or perform the stated behavior exactly when all relevant invariants hold. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |
| 170 | validated result retains no descriptor or cleanup callback | Descriptor-relative bounded cleanup succeeds or fails safely without following links. | Explicit static source check covers the additional error, descriptor, Unicode, ownership or digest invariant. |

## 17. Whitespace, CRLF, NUL and generated-artifact audit

| Staged source | Bytes | NUL | CRLF | Trailing-whitespace lines | SHA-256 |
|---|---:|---:|---:|---:|---|
| `PXMainDataStaging.h` | 2511 | 0 | 0 | 0 | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` |
| `PXMainDataStaging.m` | 67751 | 0 | 0 | 0 | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` |
| `AppDataBackupManager.m` | 127830 | 0 | 0 | 17 | `d2c27573954c62341b6bb872d9d6f2c47146e157ef48c51efadf42676b9edb26` |

- `git diff --cached --check`: PASS before report generation.
- Added staging sources are UTF-8/LF, NUL-free and contain no trailing whitespace. Existing manager context retains its preexisting whitespace outside added lines; no added whitespace error is present.
- No object, binary, test fixture, extracted tree, cache, workspace or temporary generator is included in the implementation commit.

## 18. Build status and remaining runtime risks

- Local Objective-C/Theos build: **NOT RUN — TOOLCHAIN UNAVAILABLE**.
- `make`, `clang`, `clang-cl`, and `xcrun` are not found; `THEOS` is not set.
- Static/API/ordering/hash/diff gates do not replace Darwin compilation, target-device extraction, concurrent namespace-race injection, descriptor exhaustion, 400000-entry traversal, 500000-entry cleanup or CommonCrypto runtime tests.
- External tar and path-based clone remain deliberate TASK-2.8 boundaries; the validated result is a snapshot and TASK-2.11 still owns transactional commit/rollback.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
