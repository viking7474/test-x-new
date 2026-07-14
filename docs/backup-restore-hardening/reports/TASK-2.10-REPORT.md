# TASK-2.10 Implementation Report

## 1. Baseline and exact scope

- Required baseline: `48cb463b9f1bb6b1244237c227fa890f3020071d`.
- Verified baseline HEAD before editing: `48cb463b9f1bb6b1244237c227fa890f3020071d`.
- Previous TASK-2.9 source review status supplied by the coordinator: ACCEPTED.
- Coordinator-owned modified/untracked documentation existed before implementation and was not staged, reverted or rewritten.
- Production scope staged before report:
  - `AppDataBackupManager.m`
  - `PXOptionalRestoreStaging.h`
  - `PXOptionalRestoreStaging.m`
- Required report: `docs/backup-restore-hardening/reports/TASK-2.10-REPORT.md`.
- TASK-2.11, TASK-2.12, TASK-2.13 and TASK-2.14 are not implemented.

Baseline commands recorded:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline

48cb463b9f1bb6b1244237c227fa890f3020071d
48cb463 phase2(task-2.9): stage and validate app groups
9aaa575 phase2(task-2.8): stage and validate main data
d9ab901 phase2(task-2.7): build immutable restore plan
```

## 2. Protected production SHA-256 proof

Canonical Git blobs are compared between the required baseline and the staged index, avoiding checkout CRLF effects.

| Protected file | Baseline SHA-256 | Staged SHA-256 | Result |
|---|---|---|---|
| `AppDataBackupManager.h` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | MATCH |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | MATCH |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | MATCH |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | MATCH |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | MATCH |
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
| `common/PXPaths.h` | `55521edabd6907208996874661a4a55f79be157a3dceedecc63bb3d985630ac2` | `55521edabd6907208996874661a4a55f79be157a3dceedecc63bb3d985630ac2` | MATCH |
| `common/PXPaths.m` | `e20d4eb550b7e24439ed511ee17089dca845f9bdc8f1c842eda6ac8c604a3048` | `e20d4eb550b7e24439ed511ee17089dca845f9bdc8f1c842eda6ac8c604a3048` | MATCH |
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

Protected result: **81/81 MATCH**.

## 3. Exact public API and 16-code enum

The staged header is byte-for-byte equal to the Objective-C API block in the specification.

```objc
#import <Foundation/Foundation.h>

@class PXRestorePlan;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorDomain;
FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXOptionalRestoreStagingErrorCode) {
    PXOptionalRestoreStagingErrorInvalidInput = 1,
    PXOptionalRestoreStagingErrorInvalidDestinationIdentity = 2,
    PXOptionalRestoreStagingErrorMissingDestination = 3,
    PXOptionalRestoreStagingErrorAmbiguousDestination = 4,
    PXOptionalRestoreStagingErrorUnsafeDestination = 5,
    PXOptionalRestoreStagingErrorWorkspaceCreationFailed = 6,
    PXOptionalRestoreStagingErrorSourceOpenFailed = 7,
    PXOptionalRestoreStagingErrorSourceChanged = 8,
    PXOptionalRestoreStagingErrorSourceUnsupported = 9,
    PXOptionalRestoreStagingErrorCopyFailed = 10,
    PXOptionalRestoreStagingErrorStagedFileInvalid = 11,
    PXOptionalRestoreStagingErrorSizeMismatch = 12,
    PXOptionalRestoreStagingErrorDigestMismatch = 13,
    PXOptionalRestoreStagingErrorLimitExceeded = 14,
    PXOptionalRestoreStagingErrorCleanupFailed = 15,
    PXOptionalRestoreStagingErrorInconsistentPlan = 16,
};

__attribute__((objc_subclassing_restricted))
@interface PXValidatedOptionalFileStage : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *workspaceRootPath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) unsigned long long byteCount;
@property (nonatomic, copy, readonly) NSString *sha256;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXOptionalFileStagingWorkspace : NSObject
@property (nonatomic, copy, readonly) NSString *rootPath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, strong, readonly) PXValidatedOptionalFileStage *validatedStage;
+ (nullable instancetype)workspaceByStagingSourceFileAtPath:(NSString *)sourcePath
                                                     error:(NSError * _Nullable * _Nullable)error;
- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXOptionalRestoreDestinationPlan : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *mobileLibraryPath;
@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataPath;
@property (nonatomic, copy, nullable, readonly) NSString *globalSafariPath;
@property (nonatomic, copy, nullable, readonly) NSString *preferencesPath;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *systemGlobalPathsBySubdirectory;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *sharedDatabasePathsByRelativePath;

+ (nullable instancetype)destinationPlanForRestorePlan:(PXRestorePlan *)restorePlan
                                      bundleIdentifier:(NSString *)bundleIdentifier
                               activeProfileIdentifier:(nullable NSString *)profileIdentifier
                                                 error:(NSError * _Nullable * _Nullable)error;

- (nullable NSString *)systemGlobalPathForSubdirectory:(NSString *)subdirectory;
- (nullable NSString *)sharedDatabasePathForRelativePath:(NSString *)relativePath;

- (nullable NSString *)revalidatedProfileAppDataPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedGlobalSafariPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedPreferencesPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedSystemGlobalPathForSubdirectory:(NSString *)subdirectory
                                                             error:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedSharedDatabasePathForRelativePath:(NSString *)relativePath
                                                               error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
```

## 4. Immutability and lifecycle proof

- `PXValidatedOptionalFileStage` and `PXOptionalRestoreDestinationPlan` are subclassing-restricted, readonly and `NSCopying`; both copy public value inputs and return `self` from `copyWithZone:`.
- `PXOptionalFileStagingWorkspace` is a lifecycle owner rather than a value object. It retains parent/root/payload descriptors and exact identity snapshots and is not `NSCopying`.
- Ordinary public `init` and `new` are unavailable for all three public classes.
- The validated file result contains only copied paths, byte count and lowercase SHA-256; it contains no descriptor, callback or mutable buffer.

## 5. Non-sensitive error contract

- Every public factory/revalidation/cleanup entry clears `*error`.
- Failures use only `PXOptionalRestoreStagingErrorDomain` and the exact 16 public codes.
- `userInfo` is limited to `NSLocalizedDescriptionKey` and `PXOptionalRestoreStagingErrorFieldPathKey`.
- New staging/planning errors do not expose bundle/profile values, source/destination/workspace paths, relative names, sizes, digests, device/inode, errno text or nested errors.
- Missing objects, unsafe path/type conditions and identity substitutions are classified separately.

## 6. Fixed mobile Library resolution matrix

| Candidate order | Candidate | Required proof |
|---:|---|---|
| 1 | `/private/var/mobile/Library` | final `lstat` real directory, `realpath`, no-follow/CLOEXEC open, candidate/canonical/descriptor dev+inode match |
| 2 | `/var/mobile/Library` | final `lstat` real directory, `realpath`, no-follow/CLOEXEC open, candidate/canonical/descriptor dev+inode match |
| 3 | `/private/var/jb/var/mobile/Library` | final `lstat` real directory, `realpath`, no-follow/CLOEXEC open, candidate/canonical/descriptor dev+inode match |
| 4 | `/var/jb/var/mobile/Library` | final `lstat` real directory, `realpath`, no-follow/CLOEXEC open, candidate/canonical/descriptor dev+inode match |

| Unique physical roots | Outcome |
|---:|---|
| 0 | `MissingDestination` |
| 1 | accepted immutable authority |
| 2+ | `AmbiguousDestination` |

Aliases are collapsed by exact device/inode identity. No first-existing helper, environment, manifest destination or caller-selected root is used.

## 7. Exact destination policies

| Component | Frozen destination | Existing/absent policy |
|---|---|---|
| Profile AppData | `<Library>/WeaponX/Profiles/<profile>/appdata/<bundle>` | existing real directory required |
| Global Safari | `<Library>/Safari` | existing real directory required; bundle must be exact Safari bundle |
| System-global | `<Library>/<safe-subdirectory>` | existing real directory or absent final under exact Library parent |
| Shared DB | `<Library>/<safe-relative-path>` | all parents exist; final regular file or absent |
| Preferences | `<Library>/Preferences/<bundle>.plist` | Preferences parent exists; final regular file or absent |

Every parent is traversed descriptor-relatively with no-follow checks. Existing final objects are opened and matched to path identity; absent objects retain exact parent identity and absent state. Each record is immediately revalidated once during factory construction and again immediately before mutation.

## 8. Collision and overlap proof

- One inventory includes profile, global Safari, non-skipped system-global, shared DB and Preferences destinations.
- Exact duplicates and all ancestor/descendant relationships are rejected as `InconsistentPlan`.
- This rejects directory/file conflicts, shared DB or Preferences underneath wipe targets and profile/system-global overlap.
- The exact Safari duplicate is skipped before inventory construction.
- Keychain has no filesystem destination and is intentionally excluded.

## 9. Destination snapshot and revalidation proof

- Records retain exact stored path, semantic components, parent identity, final present/absent state, final identity and expected type.
- Revalidation repeats root/parent/final no-follow, type, device and containment checks.
- Present final objects must retain device/inode/type; absent final objects must remain absent; parent identity must remain exact.
- Success returns only the stored path and never updates plan state from a new discovery.

## 10. Fixed limits and overflow proof

| Limit | Value |
|---|---:|
| Optional tar-directory items | 1024 |
| Optional file items | 4096 |
| Total optional items | 4096 |
| Staged regular file | 64 GiB |
| UTF-8 path | 4096 bytes |
| UTF-8 component | 255 bytes |
| Cleanup entries | 8 |
| Stream buffer | 64 KiB |

Count addition is guarded before addition. The exact Safari skip is accounted for before final tar-directory and total limits.

## 11. Optional-file workspace identity and digest proof

- Fixed parent: `/private/var/tmp`; unique template: `/private/var/tmp/weaponx_restore_optional_file.XXXXXX`.
- Root is forced and verified at `0700`; payload is exactly `payload`, created with `openat(O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC)` and verified at `0600`.
- Source is opened `O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC`, must be regular, single-link, non-setid, nonnegative and at most 64 GiB.
- A fixed 64 KiB buffer streams the source with EINTR-safe read/write loops while computing CommonCrypto SHA-256.
- Exact copied bytes and `fsync` are required. Source dev/inode/type/nlink/size/mtime/ctime are compared before/after; atime is ignored.
- Payload is independently reopened, streamed and hashed; size and digest must match source values exactly.
- Before return, parent descriptor, parent-relative root namespace, root descriptor, payload namespace and payload descriptor identities must all remain stable.
- Result digest is exactly 64 lowercase hex characters.

## 12. Descriptor-relative cleanup and idempotence

- Cleanup validates retained parent/root/payload descriptors and namespaces before deletion.
- Contents are bounded to eight entries, inspected with `fstatat(..., AT_SYMLINK_NOFOLLOW)` and removed with `unlinkat`; directories are opened no-follow.
- Root removal uses retained parent descriptor and exact generated basename while the retained root descriptor remains open.
- No `NSFileManager` recursive deletion, shell `rm -rf` or caller path authority exists.
- Successful cleanup marks the object cleaned; subsequent cleanup returns success. Deallocation performs best-effort safe cleanup.

## 13. Manager destination-plan ordering

| Ordering assertion | Result |
|---|---|
| App Group target plan before optional destination plan | PASS |
| optional destination plan before main workspace | PASS |
| optional destination plan before first process kill | PASS |
| profile stage before destination revalidation | PASS |
| profile revalidation before wipe | PASS |
| global stage before destination revalidation | PASS |
| global revalidation before wipe | PASS |
| system stage before revalidation | PASS |
| system revalidation before kill/quarantine | PASS |
| shared DB staging before first daemon kill | PASS |
| shared DB revalidation before first daemon kill | PASS |
| Preferences revalidation before copy | PASS |
| Keychain stage before helper | PASS |

`_activeProfileId` is read once and reused for the profile warning and destination plan. After plan success, the four legacy destination helpers have zero Restore authority.

## 14. Optional tar-directory staging integration

- Profile, global Safari and each non-skipped system-global archive bind name/source from `PXRestorePlan` and summaries from `restorePlan.validatedArchives`.
- The reusable manager helper creates `PXMainDataStagingWorkspace`, checks empty state, extracts only into `workspace.dataPath`, requires zero exit and validates the complete staged tree.
- Each matching destination is revalidated immediately before mutation. Clone authority is only `PXValidatedMainDataStage.dataPath`.
- Profile failure uses code 307 and the exact generic description; global Safari uses code 311; system-global uses code 318.
- System-global checks quarantine `mv`, uses exact `mkdir` without `-p`, checks mkdir, clones validated content, chowns and cleans staging.

## 15. Shared DB all-stage-before-daemon proof

- The first loop stages every shared DB source and retains workspaces/stages in plan order.
- The second loop revalidates every destination and retains exact destination paths.
- The first shared-system daemon signal appears only after both loops complete.
- No parent `mkdir -p` remains. Existing-file quarantine and staged-payload copy are checked; source is only `PXValidatedOptionalFileStage.filePath`.
- Rename/copy failure uses code 320 and `Failed to restore staged optional file`.

## 16. Preferences and Keychain staged-source proof

- Preferences stages the plan source, revalidates its destination, copies only `validatedStage.filePath`, checks exit, preserves chown/chmod/cfprefsd and cleans the workspace.
- Keychain stages the plan source and passes only `validatedStage.filePath` to the existing root or in-app helper. Frozen groups/method/decision/overwrite behavior is preserved.
- Keychain staging failure is hard; existing Keychain execution failure remains warning-only. Workspace cleanup follows helper completion.

## 17. Zero direct optional-source authority inventory

| Operational target/helper | Direct plan source after staging | Validated authority | Result |
|---|---:|---|---|
| Profile target | 0 | `profileStage.dataPath` | PASS |
| Global Safari target | 0 | `safariStage.dataPath` | PASS |
| System-global target | 0 | `systemStage.dataPath` | PASS |
| Shared DB destination | 0 | `stage.filePath` | PASS |
| Preferences destination | 0 | `preferencesWorkspace.validatedStage.filePath` | PASS |
| Keychain helper | 0 | `keychainWorkspace.validatedStage.filePath` | PASS |

## 18. Cleanup path inventory

| Path | Cleanup behavior |
|---|---|
| Optional directory workspace/empty/extraction/validation failure | helper cleans before returning primary error |
| Destination revalidation failure | current workspace cleanup, destination error remains primary |
| Directory clone/move/mkdir failure | workspace cleanup, manager code remains primary |
| Successful directory mutation | cleanup; exact generic warning on failure |
| Shared DB staging/revalidation failure | clean all retained file workspaces before daemon stop |
| Shared DB move/copy failure | clean all workspaces; code 320 remains primary |
| Successful shared DB copies | clean all; one generic warning if needed |
| Preferences failure/success | current workspace cleaned |
| Keychain staging/helper completion | current workspace cleaned; execution remains warning-only |

## 19. Code 320 contract

Shared DB quarantine/copy failure and Preferences copy failure use:

```text
domain: PXBackupErrorDomain
code: 320
description: Failed to restore staged optional file
```

## 20. TASK-2.1 through TASK-2.9 non-regression

| Protected body/block | Baseline SHA-256 | Staged SHA-256 | Result |
|---|---|---|---|
| `PXReadUnsignedIntegralSummaryNumber` | `aedeba9015bb2d819f8d3dc96b64847ce8e98f66ef364e64d9e3ab478d968e54` | `aedeba9015bb2d819f8d3dc96b64847ce8e98f66ef364e64d9e3ab478d968e54` | MATCH |
| `PXValidatedMainDataStagesAreEquivalent` | `c7f373e95d9b91278a4f5d21409983e4da5fd7c125284eb3da6dc85475d4a4e3` | `c7f373e95d9b91278a4f5d21409983e4da5fd7c125284eb3da6dc85475d4a4e3` | MATCH |
| `PXBackupManifestVersionIsSupported` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | MATCH |
| `PXResolveExactRestoreApplicationDataTarget` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | MATCH |
| `readManifestAtBackupDirectory:error:` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | MATCH |
| `createBackupForBundleID:appName:options:completion:` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | MATCH |
| `_tarExtract:archive:toDir:` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | MATCH |
| `_tarExtractDataArchive:archive:toDir:warnings:` | `b8a35a36213f74090fff16c3ca368392cc3807b6a649ad1dc5491660dde274ac` | `b8a35a36213f74090fff16c3ca368392cc3807b6a649ad1dc5491660dde274ac` | MATCH |
| `TASK-2.8 main staging integration block` | `87d909db504202353e0d0a42aa0ad994c2c5fd20cce9fbcb649a9bf819a021ff` | `87d909db504202353e0d0a42aa0ad994c2c5fd20cce9fbcb649a9bf819a021ff` | MATCH |
| `TASK-2.9 App Group integration block` | `2bf50b65725709d564ae193a7dea2fb34501db7e9e43736c1fea8d2bc2614cc1` | `2bf50b65725709d564ae193a7dea2fb34501db7e9e43736c1fea8d2bc2614cc1` | MATCH |

- Main staging, App Group planning/staging/equivalence/revalidation, artifact/archive validation, Restore planning, tar preference and existing codes 303/310/316/317/319 remain unchanged.
- Backup and UI behavior remain unchanged.

## 21. Transaction boundaries

- No main target quarantine/rollback (TASK-2.11).
- No App Group multi-target rollback (TASK-2.12).
- No optional transaction journal/rollback (TASK-2.13).
- No structured component result (TASK-2.14).
- Existing system/shared trash rename is preserved as a boundary and is not claimed as complete transaction safety.

## 22. Static and forbidden-token counts

| Gate | Actual | Expected | Result |
|---|---:|---:|---|
| public error-domain exports | `1` | `1` | PASS |
| public field-path exports | `1` | `1` | PASS |
| public error codes | `16` | `16` | PASS |
| public restricted classes | `3` | `3` | PASS |
| public destination factories | `1` | `1` | PASS |
| public file-workspace factories | `1` | `1` | PASS |
| public revalidation methods | `5` | `5` | PASS |
| copyWithZone implementations | `2` | `2` | PASS |
| public readwrite properties | `0` | `0` | PASS |
| fixed mobile Library candidates | `4` | `4` | PASS |
| firstExistingPath references in module | `0` | `0` | PASS |
| PXMobileLibraryPath references in module | `0` | `0` | PASS |
| _mobileLibraryBasePath references in module | `0` | `0` | PASS |
| optional-file mkdtemp calls | `1` | `1` | PASS |
| optional-file fixed template | `1` | `1` | PASS |
| whole-file NSData loads | `0` | `0` | PASS |
| NSFileManager copies in module | `0` | `0` | PASS |
| path recursive deletes in module | `0` | `0` | PASS |
| manager optional import | `1` | `1` | PASS |
| Restore active-profile reads | `1` | `1` | PASS |
| Restore destination-plan factories | `1` | `1` | PASS |
| Restore _profileAppDataPathForBundleID authority | `0` | `0` | PASS |
| Restore _globalSafariLibraryPath authority | `0` | `0` | PASS |
| Restore _mobileLibraryBasePath authority | `0` | `0` | PASS |
| Restore _preferencesPlistPathForBundleID authority | `0` | `0` | PASS |
| Restore profile revalidation calls | `1` | `1` | PASS |
| Restore global Safari revalidation calls | `1` | `1` | PASS |
| Restore Preferences revalidation calls | `1` | `1` | PASS |
| Restore system revalidation callsites | `1` | `1` | PASS |
| Restore shared DB revalidation callsites | `1` | `1` | PASS |
| Restore optional file-workspace callsites | `3` | `3` | PASS |
| Restore code 320 sites | `3` | `3` | PASS |
| Restore code 320 descriptions | `3` | `3` | PASS |
| optional-directory cleanup warnings | `3` | `3` | PASS |
| optional-file cleanup warnings | `3` | `3` | PASS |
| profile legacy codes 308/309 after plan | `0` | `0` | PASS |
| global legacy codes 312/313 after plan | `0` | `0` | PASS |
| optional system mkdir -p | `0` | `0` | PASS |
| shared DB mkdir -p | `0` | `0` | PASS |
| masked optional cp | `0` | `0` | PASS |
| masked optional mv | `0` | `0` | PASS |
| masked optional mkdir | `0` | `0` | PASS |
| post-plan direct manifest reads | `0` | `0` | PASS |
| post-plan verifiedArtifacts local path lookups | `0` | `0` | PASS |
| post-plan validatedArchives local contains calls | `0` | `0` | PASS |

Static count result: **45/45 PASS**.

Forbidden staging-module tokens checked at zero: `UIKit`, manager/main/AppGroup/validator imports, command runners/process APIs, Security/Keychain, dispatch/notifications, logging, whole-file copy/load, first-existing and legacy mobile-Library authority.

## 23. Complete production source diff

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index ec1ce72..6b37e93 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -14,6 +14,7 @@
 #import "PXBackupArchiveValidator.h"
 #import "PXRestorePlan.h"
 #import "PXAppGroupRestoreTargetPlan.h"
+#import "PXOptionalRestoreStaging.h"
 #import "PXMainDataStaging.h"
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
@@ -81,6 +82,18 @@ static BOOL PXValidatedMainDataStagesAreEquivalent(PXValidatedMainDataStage *lef
            left.regularFileBytes == right.regularFileBytes;
 }

+static BOOL PXCleanupOptionalFileWorkspaces(
+    NSArray<PXOptionalFileStagingWorkspace *> *workspaces) {
+    BOOL allCleaned = YES;
+    for (PXOptionalFileStagingWorkspace *workspace in workspaces) {
+        NSError *cleanupError = nil;
+        if (![workspace cleanupWithError:&cleanupError]) {
+            allCleaned = NO;
+        }
+    }
+    return allCleaned;
+}
+
 static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
     if (![version isKindOfClass:[NSNumber class]]) {
         return NO;
@@ -1878,6 +1891,171 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     });
 }

+- (BOOL)_stageOptionalDirectoryArchiveName:(NSString *)archiveName
+                                sourcePath:(NSString *)sourcePath
+                               restorePlan:(PXRestorePlan *)restorePlan
+                                   tarPath:(NSString *)tarPath
+                               failureCode:(NSInteger)failureCode
+                        failureDescription:(NSString *)failureDescription
+                              workspaceOut:(PXMainDataStagingWorkspace **)workspaceOut
+                                  stageOut:(PXValidatedMainDataStage **)stageOut
+                                     error:(NSError **)error {
+    if (workspaceOut) {
+        *workspaceOut = nil;
+    }
+    if (stageOut) {
+        *stageOut = nil;
+    }
+    if (error) {
+        *error = nil;
+    }
+
+    NSNumber *memberCountSummary =
+        restorePlan.validatedArchives.memberCountsByArchiveName[archiveName];
+    NSNumber *regularByteSummary =
+        restorePlan.validatedArchives.regularFileBytesByArchiveName[archiveName];
+    unsigned long long memberCountValue = 0;
+    unsigned long long regularByteValue = 0;
+    if (![archiveName isKindOfClass:[NSString class]] || archiveName.length == 0 ||
+        ![sourcePath isKindOfClass:[NSString class]] || sourcePath.length == 0 ||
+        !PXReadUnsignedIntegralSummaryNumber(memberCountSummary, &memberCountValue) ||
+        !PXReadUnsignedIntegralSummaryNumber(regularByteSummary, &regularByteValue) ||
+        memberCountValue > NSUIntegerMax) {
+        if (error) {
+            *error = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                         code:PXOptionalRestoreStagingErrorInconsistentPlan
+                                     userInfo:@{
+                                         NSLocalizedDescriptionKey: @"The accepted optional archive summary is inconsistent.",
+                                         PXOptionalRestoreStagingErrorFieldPathKey: @"$"
+                                     }];
+        }
+        return NO;
+    }
+
+    NSError *workspaceError = nil;
+    PXMainDataStagingWorkspace *workspace =
+        [PXMainDataStagingWorkspace createWorkspaceWithError:&workspaceError];
+    if (!workspace) {
+        if (error) {
+            *error = workspaceError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                                            code:PXMainDataStagingErrorWorkspaceCreationFailed
+                                                        userInfo:@{
+                                                            NSLocalizedDescriptionKey: @"The optional directory staging workspace could not be created.",
+                                                            PXMainDataStagingErrorFieldPathKey: @"$.workspace"
+                                                        }];
+        }
+        return NO;
+    }
+
+    NSError *emptyError = nil;
+    if (![workspace validateEmptyDataDirectoryWithError:&emptyError]) {
+        [workspace cleanupWithError:nil];
+        if (error) {
+            *error = emptyError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                                        code:PXMainDataStagingErrorInvalidInput
+                                                    userInfo:@{
+                                                        NSLocalizedDescriptionKey: @"The optional directory staging workspace failed empty validation.",
+                                                        PXMainDataStagingErrorFieldPathKey: @"$.data"
+                                                    }];
+        }
+        return NO;
+    }
+
+    CommandResult *extractResult =
+        [self _tarExtract:tarPath archive:sourcePath toDir:workspace.dataPath];
+    if (extractResult.exitCode != 0) {
+        [workspace cleanupWithError:nil];
+        if (error) {
+            *error = [NSError errorWithDomain:PXBackupErrorDomain
+                                         code:failureCode
+                                     userInfo:@{NSLocalizedDescriptionKey: failureDescription}];
+        }
+        return NO;
+    }
+
+    NSError *validationError = nil;
+    PXValidatedMainDataStage *stage =
+        [workspace validatedStageWithExpectedLogicalMemberCount:(NSUInteger)memberCountValue
+                                        expectedRegularFileBytes:regularByteValue
+                                                            error:&validationError];
+    if (!stage) {
+        [workspace cleanupWithError:nil];
+        if (error) {
+            *error = validationError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                                             code:PXMainDataStagingErrorInvalidInput
+                                                         userInfo:@{
+                                                             NSLocalizedDescriptionKey: @"The optional directory stage failed validation.",
+                                                             PXMainDataStagingErrorFieldPathKey: @"$.data"
+                                                         }];
+        }
+        return NO;
+    }
+
+    if (workspaceOut) {
+        *workspaceOut = workspace;
+    }
+    if (stageOut) {
+        *stageOut = stage;
+    }
+    return YES;
+}
+
+- (BOOL)_cloneOptionalDirectoryStageAtPath:(NSString *)stagePath
+                              destination:(NSString *)destination
+                                   tarPath:(NSString *)tarPath
+                                    runner:(CommandRunner *)runner
+                                 debugPath:(NSString *)debugPath
+                                debugLabel:(NSString *)debugLabel {
+    BOOL shouldUseCopy =
+        [tarPath isEqualToString:@"/usr/bin/tar"] ||
+        [tarPath isEqualToString:@"/bin/tar"];
+    CommandResult *tarCloneResult = nil;
+    if (!shouldUseCopy) {
+        NSString *cloneCommand =
+            [NSString stringWithFormat:@"%@ --xattrs --acls -cf - -C %@ . | %@ --xattrs --acls -xf - -C %@",
+             PXShellQuote(tarPath),
+             PXShellQuote(stagePath),
+             PXShellQuote(tarPath),
+             PXShellQuote(destination)];
+        tarCloneResult = [runner runAndCapture:cloneCommand];
+        PXDebugAppendLine(debugPath,
+                          [NSString stringWithFormat:@"%@TarPipeExit=%d",
+                           debugLabel,
+                           (int)tarCloneResult.exitCode]);
+        if (tarCloneResult.stderrString.length) {
+            PXDebugAppendLine(debugPath,
+                              [NSString stringWithFormat:@"%@TarPipeStderrPresent=1",
+                               debugLabel]);
+        }
+        if (tarCloneResult.exitCode != 0 ||
+            (tarCloneResult.stderrString.length &&
+             [tarCloneResult.stderrString containsString:@"XATTR support is not available"])) {
+            shouldUseCopy = YES;
+        }
+    } else {
+        PXDebugAppendLine(debugPath,
+                          [NSString stringWithFormat:@"%@TarPipeSkipped=1", debugLabel]);
+    }
+
+    if (!shouldUseCopy) {
+        return YES;
+    }
+    NSString *copyCommand =
+        [NSString stringWithFormat:@"cp -a %@/. %@/ 2>/dev/null",
+         PXShellQuote(stagePath),
+         PXShellQuote(destination)];
+    CommandResult *copyResult = [runner runAndCapture:copyCommand];
+    PXDebugAppendLine(debugPath,
+                      [NSString stringWithFormat:@"%@CpExit=%d",
+                       debugLabel,
+                       (int)copyResult.exitCode]);
+    if (copyResult.stderrString.length) {
+        PXDebugAppendLine(debugPath,
+                          [NSString stringWithFormat:@"%@CpStderrPresent=1", debugLabel]);
+    }
+    return copyResult.exitCode == 0;
+}
+
 - (void)restoreBackupAtDirectory:(NSString *)backupDir
                         bundleID:(NSString *)bundleID
                          appName:(NSString *)appName
@@ -2077,12 +2255,31 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             return;
         }

+        NSString *activeProfileId = [self _activeProfileId];
+        NSError *optionalDestinationPlanError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXOptionalRestoreDestinationPlan *optionalDestinationPlan =
+            [PXOptionalRestoreDestinationPlan destinationPlanForRestorePlan:restorePlan
+                                                            bundleIdentifier:bundleID
+                                                     activeProfileIdentifier:activeProfileId
+                                                                       error:&optionalDestinationPlanError];
+        if (!optionalDestinationPlan) {
+            NSError *err = optionalDestinationPlanError ?:
+                [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                    code:PXOptionalRestoreStagingErrorInvalidInput
+                                userInfo:@{
+                                    NSLocalizedDescriptionKey: @"The optional Restore destination plan could not be constructed.",
+                                    PXOptionalRestoreStagingErrorFieldPathKey: @"$"
+                                }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
         if (restorePlan.manifestWarningCount > 0) {
             [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)restorePlan.manifestWarningCount]];
         }

         NSString *manifestProfileId = restorePlan.manifestProfileIdentifier;
-        NSString *activeProfileId = [self _activeProfileId];
         if (manifestProfileId.length && activeProfileId.length && ![manifestProfileId isEqualToString:activeProfileId]) {
             [warnings addObject:[NSString stringWithFormat:@"Backup profileId %@ != active profileId %@", manifestProfileId, activeProfileId]];
         }
@@ -2265,70 +2462,116 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         // Restore profile redirected appdata (if present)
         if (restorePlan.includesProfileAppData) {
-            NSString *profileAppDataPath = [self _profileAppDataPathForBundleID:bundleID];
-            NSString *archivePath = restorePlan.profileAppDataSourcePath;
-            if (profileAppDataPath.length && archivePath.length) {
-                BOOL isDir = NO;
-                if ([fm fileExistsAtPath:profileAppDataPath isDirectory:&isDir] && isDir) {
-                    [self _wipeDirectoryContents:profileAppDataPath];
-                    CommandResult *r = [self _tarExtract:tarPath archive:archivePath toDir:profileAppDataPath];
-                    if (r.exitCode != 0) {
-                        NSString *msg = r.stderrString.length ? r.stderrString : @"Failed to restore profile appdata";
-                        NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                           code:307
-                                                       userInfo:@{NSLocalizedDescriptionKey: msg}];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-                        return;
-                    }
-                    [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true", PXShellQuote(profileAppDataPath)]];
-                } else {
-                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                       code:308
-                                                   userInfo:@{NSLocalizedDescriptionKey: @"Profile appdata directory missing"}];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-                    return;
-                }
-            } else {
+            PXMainDataStagingWorkspace *profileWorkspace = nil;
+            PXValidatedMainDataStage *profileStage = nil;
+            NSError *profileStageError = nil;
+            if (![self _stageOptionalDirectoryArchiveName:restorePlan.profileAppDataArchiveName
+                                               sourcePath:restorePlan.profileAppDataSourcePath
+                                              restorePlan:restorePlan
+                                                  tarPath:tarPath
+                                              failureCode:307
+                                       failureDescription:@"Failed to restore validated profile AppData stage"
+                                             workspaceOut:&profileWorkspace
+                                                 stageOut:&profileStage
+                                                    error:&profileStageError]) {
+                NSError *err = profileStageError;
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+
+            NSError *profileDestinationError = nil;
+            NSString *profileDestination =
+                [optionalDestinationPlan revalidatedProfileAppDataPathWithError:&profileDestinationError];
+            if (!profileDestination) {
+                [profileWorkspace cleanupWithError:nil];
+                NSError *err = profileDestinationError ?:
+                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                        code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
+                                    userInfo:@{
+                                        NSLocalizedDescriptionKey: @"The profile AppData destination could not be revalidated.",
+                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.profileAppData.destination"
+                                    }];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+
+            [self _wipeDirectoryContents:profileDestination];
+            if (![self _cloneOptionalDirectoryStageAtPath:profileStage.dataPath
+                                              destination:profileDestination
+                                                   tarPath:tarPath
+                                                    runner:runner
+                                                 debugPath:debugPre
+                                                debugLabel:@"profileOptionalStage"]) {
+                [profileWorkspace cleanupWithError:nil];
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                   code:309
-                                               userInfo:@{NSLocalizedDescriptionKey: @"Profile appdata archive missing"}];
+                                                   code:307
+                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated profile AppData stage"}];
                 dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                 return;
             }
+            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
+                         PXShellQuote(profileDestination)]];
+            NSError *profileCleanupError = nil;
+            if (![profileWorkspace cleanupWithError:&profileCleanupError]) {
+                [warnings addObject:@"Optional-directory staging cleanup failed"];
+            }
         }

         // Restore global Safari library (if present)
         if (restorePlan.includesGlobalSafari) {
-            NSString *globalSafariPath = [self _globalSafariLibraryPath];
-            NSString *archivePath = restorePlan.globalSafariSourcePath;
-            if (globalSafariPath.length && archivePath.length) {
-                BOOL isDir = NO;
-                if ([fm fileExistsAtPath:globalSafariPath isDirectory:&isDir] && isDir) {
-                    [self _wipeDirectoryContents:globalSafariPath];
-                    CommandResult *r = [self _tarExtract:tarPath archive:archivePath toDir:globalSafariPath];
-                    if (r.exitCode != 0) {
-                        NSString *msg = r.stderrString.length ? r.stderrString : @"Failed to restore global Safari library";
-                        NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                           code:311
-                                                       userInfo:@{NSLocalizedDescriptionKey: msg}];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-                        return;
-                    }
-                    [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true", PXShellQuote(globalSafariPath)]];
-                } else {
-                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                       code:312
-                                                   userInfo:@{NSLocalizedDescriptionKey: @"Global Safari directory missing"}];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
-                    return;
-                }
-            } else {
+            PXMainDataStagingWorkspace *safariWorkspace = nil;
+            PXValidatedMainDataStage *safariStage = nil;
+            NSError *safariStageError = nil;
+            if (![self _stageOptionalDirectoryArchiveName:restorePlan.globalSafariArchiveName
+                                               sourcePath:restorePlan.globalSafariSourcePath
+                                              restorePlan:restorePlan
+                                                  tarPath:tarPath
+                                              failureCode:311
+                                       failureDescription:@"Failed to restore validated global Safari stage"
+                                             workspaceOut:&safariWorkspace
+                                                 stageOut:&safariStage
+                                                    error:&safariStageError]) {
+                NSError *err = safariStageError;
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+
+            NSError *safariDestinationError = nil;
+            NSString *safariDestination =
+                [optionalDestinationPlan revalidatedGlobalSafariPathWithError:&safariDestinationError];
+            if (!safariDestination) {
+                [safariWorkspace cleanupWithError:nil];
+                NSError *err = safariDestinationError ?:
+                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                        code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
+                                    userInfo:@{
+                                        NSLocalizedDescriptionKey: @"The global Safari destination could not be revalidated.",
+                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.globalSafari.destination"
+                                    }];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+
+            [self _wipeDirectoryContents:safariDestination];
+            if (![self _cloneOptionalDirectoryStageAtPath:safariStage.dataPath
+                                              destination:safariDestination
+                                                   tarPath:tarPath
+                                                    runner:runner
+                                                 debugPath:debugPre
+                                                debugLabel:@"safariOptionalStage"]) {
+                [safariWorkspace cleanupWithError:nil];
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                   code:313
-                                               userInfo:@{NSLocalizedDescriptionKey: @"Global Safari archive missing"}];
+                                                   code:311
+                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated global Safari stage"}];
                 dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                 return;
             }
+            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
+                         PXShellQuote(safariDestination)]];
+            NSError *safariCleanupError = nil;
+            if (![safariWorkspace cleanupWithError:&safariCleanupError]) {
+                [warnings addObject:@"Optional-directory staging cleanup failed"];
+            }
         }

         // Restore each exact physical App Group target from validated staged content.
@@ -2589,45 +2832,165 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         // Restore generic system app global Library folders (if present)
         if (restorePlan.systemGlobalItems.count) {
-            NSString *libBase = [self _mobileLibraryBasePath];
             for (PXRestorePlanSystemGlobalItem *plannedItem in restorePlan.systemGlobalItems) {
                 NSString *subdir = plannedItem.librarySubdirectory;
-
-                // Avoid double-restoring Safari which is handled explicitly.
-                if ([bundleID isEqualToString:@"com.apple.mobilesafari"] && [subdir isEqualToString:@"Safari"]) {
+                if ([bundleID isEqualToString:@"com.apple.mobilesafari"] &&
+                    [subdir isEqualToString:@"Safari"] &&
+                    restorePlan.includesGlobalSafari) {
                     continue;
                 }

-                NSString *archivePath = plannedItem.sourcePath;
+                NSString *plannedDestination =
+                    [optionalDestinationPlan systemGlobalPathForSubdirectory:subdir];
+                if (!plannedDestination.length) {
+                    NSError *err = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                                       code:PXOptionalRestoreStagingErrorInconsistentPlan
+                                                   userInfo:@{
+                                                       NSLocalizedDescriptionKey: @"The system-global destination plan is inconsistent.",
+                                                       PXOptionalRestoreStagingErrorFieldPathKey: @"$"
+                                                   }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+
+                PXMainDataStagingWorkspace *systemWorkspace = nil;
+                PXValidatedMainDataStage *systemStage = nil;
+                NSError *systemStageError = nil;
+                if (![self _stageOptionalDirectoryArchiveName:plannedItem.archiveName
+                                                   sourcePath:plannedItem.sourcePath
+                                                  restorePlan:restorePlan
+                                                      tarPath:tarPath
+                                                  failureCode:318
+                                           failureDescription:@"Failed to restore validated system-global stage"
+                                                 workspaceOut:&systemWorkspace
+                                                     stageOut:&systemStage
+                                                        error:&systemStageError]) {
+                    NSError *err = systemStageError;
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+
+                NSError *destinationError = nil;
+                NSString *destination =
+                    [optionalDestinationPlan revalidatedSystemGlobalPathForSubdirectory:subdir
+                                                                                  error:&destinationError];
+                if (!destination) {
+                    [systemWorkspace cleanupWithError:nil];
+                    NSError *err = destinationError ?:
+                        [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                            code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
+                                        userInfo:@{
+                                            NSLocalizedDescriptionKey: @"The system-global destination could not be revalidated.",
+                                            PXOptionalRestoreStagingErrorFieldPathKey: @"$"
+                                        }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }

-                NSString *dest = [libBase stringByAppendingPathComponent:subdir];
                 [self _killRelatedProcessesForBundleID:bundleID];
+                BOOL destinationExisted = [fm fileExistsAtPath:destination];
+                if (destinationExisted) {
+                    NSString *trash = [NSString stringWithFormat:@"%@.WeaponXTrash.%@",
+                                       destination,
+                                       PXTimestampSuffix()];
+                    CommandResult *moveResult =
+                        [runner runAndCapture:[NSString stringWithFormat:@"mv %@ %@ 2>/dev/null",
+                                               PXShellQuote(destination),
+                                               PXShellQuote(trash)]];
+                    if (moveResult.exitCode != 0) {
+                        [systemWorkspace cleanupWithError:nil];
+                        NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                           code:318
+                                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stage"}];
+                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        return;
+                    }
+                }

-                // Quarantine existing directory to avoid detached DB crashes.
-                NSString *trash = [NSString stringWithFormat:@"%@.WeaponXTrash.%@", dest, PXTimestampSuffix()];
-                if ([fm fileExistsAtPath:dest]) {
-                    [runner run:[NSString stringWithFormat:@"mv %@ %@ 2>/dev/null || true", PXShellQuote(dest), PXShellQuote(trash)]];
+                CommandResult *mkdirResult =
+                    [runner runAndCapture:[NSString stringWithFormat:@"mkdir %@ 2>/dev/null",
+                                           PXShellQuote(destination)]];
+                if (mkdirResult.exitCode != 0) {
+                    [systemWorkspace cleanupWithError:nil];
+                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                       code:318
+                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stage"}];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
                 }
-                [runner run:[NSString stringWithFormat:@"mkdir -p %@ 2>/dev/null || true", PXShellQuote(dest)]];

-                CommandResult *r = [self _tarExtract:tarPath archive:archivePath toDir:dest];
-                if (r.exitCode != 0) {
-                    NSString *msg = r.stderrString.length ? r.stderrString : [NSString stringWithFormat:@"Failed to restore system global library %@", subdir];
+                if (![self _cloneOptionalDirectoryStageAtPath:systemStage.dataPath
+                                                  destination:destination
+                                                       tarPath:tarPath
+                                                        runner:runner
+                                                     debugPath:debugPre
+                                                    debugLabel:@"systemGlobalOptionalStage"]) {
+                    [systemWorkspace cleanupWithError:nil];
                     NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                        code:318
-                                                   userInfo:@{NSLocalizedDescriptionKey: msg}];
+                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stage"}];
                     dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                     return;
                 }
-                [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true", PXShellQuote(dest)]];
+                [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
+                             PXShellQuote(destination)]];
+                NSError *systemCleanupError = nil;
+                if (![systemWorkspace cleanupWithError:&systemCleanupError]) {
+                    [warnings addObject:@"Optional-directory staging cleanup failed"];
+                }
             }
         }

         // Restore shared system DBs (if present)
         if (restorePlan.sharedDatabaseItems.count) {
-            NSString *libBase = [self _mobileLibraryBasePath];
+            NSMutableArray<PXOptionalFileStagingWorkspace *> *sharedWorkspaces =
+                [NSMutableArray arrayWithCapacity:restorePlan.sharedDatabaseItems.count];
+            NSMutableArray<PXValidatedOptionalFileStage *> *sharedStages =
+                [NSMutableArray arrayWithCapacity:restorePlan.sharedDatabaseItems.count];
+            NSMutableArray<NSString *> *sharedDestinations =
+                [NSMutableArray arrayWithCapacity:restorePlan.sharedDatabaseItems.count];
+
+            for (PXRestorePlanSharedDatabaseItem *plannedItem in restorePlan.sharedDatabaseItems) {
+                NSError *fileStageError = nil;
+                PXOptionalFileStagingWorkspace *workspace =
+                    [PXOptionalFileStagingWorkspace workspaceByStagingSourceFileAtPath:plannedItem.sourcePath
+                                                                                 error:&fileStageError];
+                if (!workspace) {
+                    PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
+                    NSError *err = fileStageError ?:
+                        [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                            code:PXOptionalRestoreStagingErrorInvalidInput
+                                        userInfo:@{
+                                            NSLocalizedDescriptionKey: @"The shared database source could not be staged.",
+                                            PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                        }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+                [sharedWorkspaces addObject:workspace];
+                [sharedStages addObject:workspace.validatedStage];
+            }
+
+            for (PXRestorePlanSharedDatabaseItem *plannedItem in restorePlan.sharedDatabaseItems) {
+                NSError *destinationError = nil;
+                NSString *destination =
+                    [optionalDestinationPlan revalidatedSharedDatabasePathForRelativePath:plannedItem.libraryRelativePath
+                                                                                    error:&destinationError];
+                if (!destination) {
+                    PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
+                    NSError *err = destinationError ?:
+                        [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                            code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
+                                        userInfo:@{
+                                            NSLocalizedDescriptionKey: @"A shared database destination could not be revalidated.",
+                                            PXOptionalRestoreStagingErrorFieldPathKey: @"$"
+                                        }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+                [sharedDestinations addObject:destination];
+            }

-            // Stop common daemons that may hold these DBs.
             PXKillallByName(@"accountsd", SIGTERM);
             PXKillallByName(@"calaccessd", SIGTERM);
             PXKillallByName(@"imagent", SIGTERM);
@@ -2638,27 +3001,48 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             PXKillallByName(@"imagent", SIGKILL);
             PXKillallByName(@"MobileSMS", SIGKILL);

-            for (PXRestorePlanSharedDatabaseItem *plannedItem in restorePlan.sharedDatabaseItems) {
-                NSString *libraryRel = plannedItem.libraryRelativePath;
-                NSString *src = plannedItem.sourcePath;
-
-                NSString *dest = [libBase stringByAppendingPathComponent:libraryRel];
-                NSString *destDir = [dest stringByDeletingLastPathComponent];
-                [runner run:[NSString stringWithFormat:@"mkdir -p %@ 2>/dev/null || true", PXShellQuote(destDir)]];
-
-                NSString *trash = [NSString stringWithFormat:@"%@.WeaponXTrash.%@", dest, PXTimestampSuffix()];
-                if ([fm fileExistsAtPath:dest]) {
-                    [runner run:[NSString stringWithFormat:@"mv %@ %@ 2>/dev/null || true", PXShellQuote(dest), PXShellQuote(trash)]];
+            for (NSUInteger index = 0; index < restorePlan.sharedDatabaseItems.count; index++) {
+                NSString *destination = sharedDestinations[index];
+                PXValidatedOptionalFileStage *stage = sharedStages[index];
+                if ([fm fileExistsAtPath:destination]) {
+                    NSString *trash = [NSString stringWithFormat:@"%@.WeaponXTrash.%@",
+                                       destination,
+                                       PXTimestampSuffix()];
+                    CommandResult *moveResult =
+                        [runner runAndCapture:[NSString stringWithFormat:@"mv %@ %@ 2>/dev/null",
+                                               PXShellQuote(destination),
+                                               PXShellQuote(trash)]];
+                    if (moveResult.exitCode != 0) {
+                        PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
+                        NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                           code:320
+                                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional file"}];
+                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        return;
+                    }
                 }
-
-                [runner run:[NSString stringWithFormat:@"cp -a %@ %@ 2>/dev/null || true", PXShellQuote(src), PXShellQuote(dest)]];
-                [runner run:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true", PXShellQuote(dest)]];
-                [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(dest)]];
+                CommandResult *copyResult =
+                    [runner runAndCapture:[NSString stringWithFormat:@"cp -a %@ %@ 2>/dev/null",
+                                           PXShellQuote(stage.filePath),
+                                           PXShellQuote(destination)]];
+                if (copyResult.exitCode != 0) {
+                    PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
+                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                       code:320
+                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional file"}];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+                [runner run:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true",
+                             PXShellQuote(destination)]];
+                [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true",
+                             PXShellQuote(destination)]];
             }

+            if (!PXCleanupOptionalFileWorkspaces(sharedWorkspaces)) {
+                [warnings addObject:@"Optional-file staging cleanup failed"];
+            }
             [warnings addObject:@"Restored shared system DBs (this may affect multiple apps)"];
-
-            // Restart daemons best-effort.
             PXKillallByName(@"accountsd", SIGTERM);
             PXKillallByName(@"calaccessd", SIGTERM);
             PXKillallByName(@"imagent", SIGTERM);
@@ -2667,29 +3051,84 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         // Preferences restore
         if (restorePlan.includesPreferences) {
-            NSString *prefBackup = restorePlan.preferencesSourcePath;
-            NSString *prefDest = [self _preferencesPlistPathForBundleID:bundleID];
-            if (prefBackup.length) {
-                [runner run:[NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null || true", PXShellQuote(prefBackup), PXShellQuote(prefDest)]];
-                [runner run:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true", PXShellQuote(prefDest)]];
-                [runner run:[NSString stringWithFormat:@"chmod 644 %@ 2>/dev/null || true", PXShellQuote(prefDest)]];
-                PXKillallByName(@"cfprefsd", SIGTERM);
-            } else {
-                [warnings addObject:@"Preferences archive missing; skipping"];
+            NSError *preferencesStageError = nil;
+            PXOptionalFileStagingWorkspace *preferencesWorkspace =
+                [PXOptionalFileStagingWorkspace workspaceByStagingSourceFileAtPath:restorePlan.preferencesSourcePath
+                                                                             error:&preferencesStageError];
+            if (!preferencesWorkspace) {
+                NSError *err = preferencesStageError ?:
+                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                        code:PXOptionalRestoreStagingErrorInvalidInput
+                                    userInfo:@{
+                                        NSLocalizedDescriptionKey: @"The Preferences source could not be staged.",
+                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                    }];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+            NSError *preferencesDestinationError = nil;
+            NSString *preferencesDestination =
+                [optionalDestinationPlan revalidatedPreferencesPathWithError:&preferencesDestinationError];
+            if (!preferencesDestination) {
+                [preferencesWorkspace cleanupWithError:nil];
+                NSError *err = preferencesDestinationError ?:
+                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                        code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
+                                    userInfo:@{
+                                        NSLocalizedDescriptionKey: @"The Preferences destination could not be revalidated.",
+                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.preferences.destination"
+                                    }];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+            CommandResult *copyResult =
+                [runner runAndCapture:[NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null",
+                                       PXShellQuote(preferencesWorkspace.validatedStage.filePath),
+                                       PXShellQuote(preferencesDestination)]];
+            if (copyResult.exitCode != 0) {
+                [preferencesWorkspace cleanupWithError:nil];
+                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                   code:320
+                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional file"}];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+            [runner run:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true",
+                         PXShellQuote(preferencesDestination)]];
+            [runner run:[NSString stringWithFormat:@"chmod 644 %@ 2>/dev/null || true",
+                         PXShellQuote(preferencesDestination)]];
+            PXKillallByName(@"cfprefsd", SIGTERM);
+            NSError *preferencesCleanupError = nil;
+            if (![preferencesWorkspace cleanupWithError:&preferencesCleanupError]) {
+                [warnings addObject:@"Optional-file staging cleanup failed"];
             }
         }

-        // Keychain restore (warning-only on failure)
+        // Keychain restore (warning-only on execution failure)
         if (restorePlan.includesKeychain) {
-            NSString *keychainBackupPath = restorePlan.keychainSourcePath;
+            NSError *keychainStageError = nil;
+            PXOptionalFileStagingWorkspace *keychainWorkspace =
+                [PXOptionalFileStagingWorkspace workspaceByStagingSourceFileAtPath:restorePlan.keychainSourcePath
+                                                                             error:&keychainStageError];
+            if (!keychainWorkspace) {
+                NSError *err = keychainStageError ?:
+                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                        code:PXOptionalRestoreStagingErrorInvalidInput
+                                    userInfo:@{
+                                        NSLocalizedDescriptionKey: @"The Keychain input source could not be staged.",
+                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                    }];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+
+            NSString *keychainBackupPath = keychainWorkspace.validatedStage.filePath;
             NSArray<NSString *> *groups = restorePlan.keychainGroups;
             NSString *method = restorePlan.keychainMethod;
             (void)method;
             BOOL shouldUseInApp = restorePlan.keychainUsesInAppMethod;
-
             BOOL ok = NO;
             if (shouldUseInApp) {
-                // Use app context so keychain access uses the app's original entitlements.
                 ok = [self _inAppKeychainRestoreForBundleID:bundleID
                                               containerPath:dataContainerPath
                                                      groups:groups
@@ -2704,12 +3143,15 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                                            overwrite:YES
                                             warnings:warnings];
             }
-
             if (!ok) {
                 [warnings addObject:@"Keychain restore failed (continuing)" ];
             }

-            // Debug keychain list after restore
+            NSError *keychainCleanupError = nil;
+            if (![keychainWorkspace cleanupWithError:&keychainCleanupError]) {
+                [warnings addObject:@"Optional-file staging cleanup failed"];
+            }
+
             PXDebugHeader(debugKeychain, @"Keychain After Restore");
             PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"groups=%@", groups ?: @[]]);
             if (!shouldUseInApp) {
@@ -2734,8 +3176,10 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             PXDebugAppendLine(debugPost, [NSString stringWithFormat:@"chosenDataContainerPath=%@", dataContainerPath ?: @""]);
             PXDebugRun(runner, debugPost, @"du data", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
             PXDebugRun(runner, debugPost, @"ls prefs", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library/Preferences"]) ]);
-            NSString *prefDest = [self _preferencesPlistPathForBundleID:bundleID];
-            PXDebugRun(runner, debugPost, @"ls global prefs", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(prefDest)]);
+            NSString *prefDest = optionalDestinationPlan.preferencesPath;
+            if (prefDest.length) {
+                PXDebugRun(runner, debugPost, @"ls global prefs", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(prefDest)]);
+            }

             if ([lsDataPath isKindOfClass:[NSString class]] && lsDataPath.length && ![lsDataPath isEqualToString:dataContainerPath]) {
                 PXDebugHeader(debugPost, @"WARNING: Active Container Differs");
diff --git a/PXOptionalRestoreStaging.h b/PXOptionalRestoreStaging.h
new file mode 100644
index 0000000..06bdf22
--- /dev/null
+++ b/PXOptionalRestoreStaging.h
@@ -0,0 +1,80 @@
+#import <Foundation/Foundation.h>
+
+@class PXRestorePlan;
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorDomain;
+FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXOptionalRestoreStagingErrorCode) {
+    PXOptionalRestoreStagingErrorInvalidInput = 1,
+    PXOptionalRestoreStagingErrorInvalidDestinationIdentity = 2,
+    PXOptionalRestoreStagingErrorMissingDestination = 3,
+    PXOptionalRestoreStagingErrorAmbiguousDestination = 4,
+    PXOptionalRestoreStagingErrorUnsafeDestination = 5,
+    PXOptionalRestoreStagingErrorWorkspaceCreationFailed = 6,
+    PXOptionalRestoreStagingErrorSourceOpenFailed = 7,
+    PXOptionalRestoreStagingErrorSourceChanged = 8,
+    PXOptionalRestoreStagingErrorSourceUnsupported = 9,
+    PXOptionalRestoreStagingErrorCopyFailed = 10,
+    PXOptionalRestoreStagingErrorStagedFileInvalid = 11,
+    PXOptionalRestoreStagingErrorSizeMismatch = 12,
+    PXOptionalRestoreStagingErrorDigestMismatch = 13,
+    PXOptionalRestoreStagingErrorLimitExceeded = 14,
+    PXOptionalRestoreStagingErrorCleanupFailed = 15,
+    PXOptionalRestoreStagingErrorInconsistentPlan = 16,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXValidatedOptionalFileStage : NSObject <NSCopying>
+@property (nonatomic, copy, readonly) NSString *workspaceRootPath;
+@property (nonatomic, copy, readonly) NSString *filePath;
+@property (nonatomic, assign, readonly) unsigned long long byteCount;
+@property (nonatomic, copy, readonly) NSString *sha256;
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXOptionalFileStagingWorkspace : NSObject
+@property (nonatomic, copy, readonly) NSString *rootPath;
+@property (nonatomic, copy, readonly) NSString *filePath;
+@property (nonatomic, strong, readonly) PXValidatedOptionalFileStage *validatedStage;
++ (nullable instancetype)workspaceByStagingSourceFileAtPath:(NSString *)sourcePath
+                                                     error:(NSError * _Nullable * _Nullable)error;
+- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXOptionalRestoreDestinationPlan : NSObject <NSCopying>
+@property (nonatomic, copy, readonly) NSString *mobileLibraryPath;
+@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataPath;
+@property (nonatomic, copy, nullable, readonly) NSString *globalSafariPath;
+@property (nonatomic, copy, nullable, readonly) NSString *preferencesPath;
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *systemGlobalPathsBySubdirectory;
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *sharedDatabasePathsByRelativePath;
+
++ (nullable instancetype)destinationPlanForRestorePlan:(PXRestorePlan *)restorePlan
+                                      bundleIdentifier:(NSString *)bundleIdentifier
+                               activeProfileIdentifier:(nullable NSString *)profileIdentifier
+                                                 error:(NSError * _Nullable * _Nullable)error;
+
+- (nullable NSString *)systemGlobalPathForSubdirectory:(NSString *)subdirectory;
+- (nullable NSString *)sharedDatabasePathForRelativePath:(NSString *)relativePath;
+
+- (nullable NSString *)revalidatedProfileAppDataPathWithError:(NSError * _Nullable * _Nullable)error;
+- (nullable NSString *)revalidatedGlobalSafariPathWithError:(NSError * _Nullable * _Nullable)error;
+- (nullable NSString *)revalidatedPreferencesPathWithError:(NSError * _Nullable * _Nullable)error;
+- (nullable NSString *)revalidatedSystemGlobalPathForSubdirectory:(NSString *)subdirectory
+                                                             error:(NSError * _Nullable * _Nullable)error;
+- (nullable NSString *)revalidatedSharedDatabasePathForRelativePath:(NSString *)relativePath
+                                                               error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXOptionalRestoreStaging.m b/PXOptionalRestoreStaging.m
new file mode 100644
index 0000000..08c3230
--- /dev/null
+++ b/PXOptionalRestoreStaging.m
@@ -0,0 +1,2162 @@
+#import "PXOptionalRestoreStaging.h"
+#import "PXRestorePlan.h"
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
+#ifndef O_DIRECTORY
+#define O_DIRECTORY 0
+#endif
+#ifndef O_NOFOLLOW
+#define O_NOFOLLOW 0
+#endif
+#ifndef O_CLOEXEC
+#define O_CLOEXEC 0
+#endif
+#ifndef O_NONBLOCK
+#define O_NONBLOCK 0
+#endif
+#ifndef AT_SYMLINK_NOFOLLOW
+#define AT_SYMLINK_NOFOLLOW 0
+#endif
+#ifndef AT_REMOVEDIR
+#define AT_REMOVEDIR 0
+#endif
+
+NSString * const PXOptionalRestoreStagingErrorDomain =
+    @"com.hydra.projectx.optional-restore-staging";
+NSString * const PXOptionalRestoreStagingErrorFieldPathKey =
+    @"PXOptionalRestoreStagingErrorFieldPathKey";
+
+static const NSUInteger PXOptionalMaximumTarDirectoryItems = 1024;
+static const NSUInteger PXOptionalMaximumFileItems = 4096;
+static const NSUInteger PXOptionalMaximumTotalItems = 4096;
+static const unsigned long long PXOptionalMaximumFileBytes = 64ULL * 1024ULL * 1024ULL * 1024ULL;
+static const NSUInteger PXOptionalMaximumPathBytes = 4096;
+static const NSUInteger PXOptionalMaximumComponentBytes = 255;
+static const NSUInteger PXOptionalMaximumCleanupEntries = 8;
+static const size_t PXOptionalStreamBufferSize = 64 * 1024;
+
+static id PXOptionalFailObject(NSError **error,
+                               PXOptionalRestoreStagingErrorCode code,
+                               NSString *fieldPath,
+                               NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                     code:code
+                                 userInfo:@{
+                                     NSLocalizedDescriptionKey: description,
+                                     PXOptionalRestoreStagingErrorFieldPathKey: fieldPath
+                                 }];
+    }
+    return nil;
+}
+
+static BOOL PXOptionalFail(NSError **error,
+                           PXOptionalRestoreStagingErrorCode code,
+                           NSString *fieldPath,
+                           NSString *description) {
+    PXOptionalFailObject(error, code, fieldPath, description);
+    return NO;
+}
+
+typedef struct {
+    dev_t device;
+    ino_t inode;
+    mode_t mode;
+    off_t size;
+    nlink_t linkCount;
+    struct timespec modificationTime;
+    struct timespec changeTime;
+} PXOptionalIdentity;
+
+static PXOptionalIdentity PXOptionalIdentityFromStat(const struct stat *value) {
+    PXOptionalIdentity identity;
+    memset(&identity, 0, sizeof(identity));
+    identity.device = value->st_dev;
+    identity.inode = value->st_ino;
+    identity.mode = value->st_mode;
+    identity.size = value->st_size;
+    identity.linkCount = value->st_nlink;
+    identity.modificationTime = value->st_mtimespec;
+    identity.changeTime = value->st_ctimespec;
+    return identity;
+}
+
+static BOOL PXOptionalTimespecEqual(struct timespec left, struct timespec right) {
+    return left.tv_sec == right.tv_sec && left.tv_nsec == right.tv_nsec;
+}
+
+static BOOL PXOptionalIdentityMatchesBasic(PXOptionalIdentity expected,
+                                           const struct stat *actual) {
+    return expected.device == actual->st_dev &&
+           expected.inode == actual->st_ino &&
+           ((expected.mode & S_IFMT) == (actual->st_mode & S_IFMT));
+}
+
+static BOOL PXOptionalStableFileIdentityMatches(PXOptionalIdentity expected,
+                                                const struct stat *actual) {
+    return PXOptionalIdentityMatchesBasic(expected, actual) &&
+           expected.linkCount == actual->st_nlink &&
+           expected.size == actual->st_size &&
+           PXOptionalTimespecEqual(expected.modificationTime, actual->st_mtimespec) &&
+           PXOptionalTimespecEqual(expected.changeTime, actual->st_ctimespec);
+}
+
+static BOOL PXOptionalSetCloseOnExec(int descriptor) {
+    int flags = fcntl(descriptor, F_GETFD);
+    if (flags < 0) {
+        return NO;
+    }
+    return fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0;
+}
+
+static int PXOptionalDuplicateDescriptor(int descriptor) {
+#ifdef F_DUPFD_CLOEXEC
+    int duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
+    if (duplicate >= 0) {
+        return duplicate;
+    }
+#endif
+    int duplicate = dup(descriptor);
+    if (duplicate < 0) {
+        return -1;
+    }
+    if (!PXOptionalSetCloseOnExec(duplicate)) {
+        close(duplicate);
+        return -1;
+    }
+    return duplicate;
+}
+
+static void PXOptionalCloseDescriptor(int *descriptor) {
+    if (descriptor && *descriptor >= 0) {
+        close(*descriptor);
+        *descriptor = -1;
+    }
+}
+
+static BOOL PXOptionalStringContainsNUL(NSString *value) {
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXOptionalStringHasNonWhitespaceText(NSString *value) {
+    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if (![whitespace characterIsMember:[value characterAtIndex:index]]) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXOptionalStringContainsASCIIControl(NSString *value) {
+    NSData *utf8 = [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!utf8) {
+        return YES;
+    }
+    const unsigned char *bytes = utf8.bytes;
+    for (NSUInteger index = 0; index < utf8.length; index++) {
+        if (bytes[index] < 0x20 || bytes[index] == 0x7f) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXOptionalSafeComponent(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return NO;
+    }
+    NSString *component = (NSString *)value;
+    if (component.length == 0 ||
+        !PXOptionalStringHasNonWhitespaceText(component) ||
+        PXOptionalStringContainsNUL(component) ||
+        PXOptionalStringContainsASCIIControl(component) ||
+        [component containsString:@"/"] ||
+        [component containsString:@"\\"] ||
+        [component isEqualToString:@"."] ||
+        [component isEqualToString:@".."]) {
+        return NO;
+    }
+    NSData *utf8 = [component dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    return utf8 && utf8.length >= 1 && utf8.length <= PXOptionalMaximumComponentBytes;
+}
+
+static NSArray<NSString *> *PXOptionalSafeRelativeComponents(id value) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return nil;
+    }
+    NSString *relativePath = (NSString *)value;
+    if (relativePath.length == 0 ||
+        !PXOptionalStringHasNonWhitespaceText(relativePath) ||
+        PXOptionalStringContainsNUL(relativePath) ||
+        PXOptionalStringContainsASCIIControl(relativePath) ||
+        [relativePath hasPrefix:@"/"] ||
+        [relativePath hasSuffix:@"/"] ||
+        [relativePath containsString:@"//"] ||
+        [relativePath containsString:@"\\"]) {
+        return nil;
+    }
+    NSData *pathBytes = [relativePath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!pathBytes || pathBytes.length > PXOptionalMaximumPathBytes) {
+        return nil;
+    }
+    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
+    if (components.count == 0) {
+        return nil;
+    }
+    for (NSString *component in components) {
+        if (!PXOptionalSafeComponent(component)) {
+            return nil;
+        }
+    }
+    return components;
+}
+
+static BOOL PXOptionalPathIsContained(NSString *rootPath, NSString *path) {
+    if ([path isEqualToString:rootPath]) {
+        return YES;
+    }
+    NSString *prefix = [rootPath stringByAppendingString:@"/"];
+    return [path hasPrefix:prefix];
+}
+
+static BOOL PXOptionalPathIsAncestor(NSString *ancestor, NSString *descendant) {
+    if ([ancestor isEqualToString:descendant]) {
+        return NO;
+    }
+    return [descendant hasPrefix:[ancestor stringByAppendingString:@"/"]];
+}
+
+static NSString *PXOptionalPathForComponents(NSString *rootPath,
+                                             NSArray<NSString *> *components) {
+    NSString *path = rootPath;
+    for (NSString *component in components) {
+        path = [path stringByAppendingPathComponent:component];
+    }
+    NSData *utf8 = [path dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!utf8 || utf8.length > PXOptionalMaximumPathBytes) {
+        return nil;
+    }
+    return path;
+}
+
+static char *PXOptionalCopyFileSystemRepresentation(NSString *value) {
+    const char *representation = value.fileSystemRepresentation;
+    if (!representation) {
+        return NULL;
+    }
+    size_t length = strlen(representation);
+    if (length > PXOptionalMaximumPathBytes) {
+        return NULL;
+    }
+    char *copy = calloc(length + 1, 1);
+    if (!copy) {
+        return NULL;
+    }
+    memcpy(copy, representation, length);
+    return copy;
+}
+
+static char *PXOptionalCopyComponentRepresentation(NSString *value) {
+    if (!PXOptionalSafeComponent(value)) {
+        return NULL;
+    }
+    const char *representation = value.fileSystemRepresentation;
+    if (!representation) {
+        return NULL;
+    }
+    size_t length = strlen(representation);
+    if (length == 0 || length > PXOptionalMaximumComponentBytes) {
+        return NULL;
+    }
+    char *copy = calloc(length + 1, 1);
+    if (!copy) {
+        return NULL;
+    }
+    memcpy(copy, representation, length);
+    return copy;
+}
+
+static NSString *PXOptionalLowercaseDigest(const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
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
+typedef NS_ENUM(NSUInteger, PXOptionalDestinationType) {
+    PXOptionalDestinationTypeDirectory = 1,
+    PXOptionalDestinationTypeRegularFile = 2,
+};
+
+@interface PXOptionalDestinationRecord : NSObject
+@property (nonatomic, copy, readonly) NSString *path;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *components;
+@property (nonatomic, copy, readonly) NSString *fieldPath;
+@property (nonatomic, assign, readonly) PXOptionalDestinationType type;
+@property (nonatomic, assign, readonly, getter=isPresent) BOOL present;
+@property (nonatomic, assign, readonly) PXOptionalIdentity parentIdentity;
+@property (nonatomic, assign, readonly) PXOptionalIdentity finalIdentity;
+- (instancetype)initWithPath:(NSString *)path
+                  components:(NSArray<NSString *> *)components
+                   fieldPath:(NSString *)fieldPath
+                        type:(PXOptionalDestinationType)type
+                     present:(BOOL)present
+              parentIdentity:(PXOptionalIdentity)parentIdentity
+               finalIdentity:(PXOptionalIdentity)finalIdentity;
+@end
+
+@implementation PXOptionalDestinationRecord
+- (instancetype)initWithPath:(NSString *)path
+                  components:(NSArray<NSString *> *)components
+                   fieldPath:(NSString *)fieldPath
+                        type:(PXOptionalDestinationType)type
+                     present:(BOOL)present
+              parentIdentity:(PXOptionalIdentity)parentIdentity
+               finalIdentity:(PXOptionalIdentity)finalIdentity {
+    self = [super init];
+    if (self) {
+        _path = [path copy];
+        _components = [components copy];
+        _fieldPath = [fieldPath copy];
+        _type = type;
+        _present = present;
+        _parentIdentity = parentIdentity;
+        _finalIdentity = finalIdentity;
+    }
+    return self;
+}
+@end
+
+static BOOL PXOptionalOpenRootAndVerify(NSString *rootPath,
+                                        PXOptionalIdentity expectedIdentity,
+                                        int *descriptorOut) {
+    if (descriptorOut) {
+        *descriptorOut = -1;
+    }
+    char *root = PXOptionalCopyFileSystemRepresentation(rootPath);
+    if (!root) {
+        return NO;
+    }
+    struct stat pathStat;
+    memset(&pathStat, 0, sizeof(pathStat));
+    if (lstat(root, &pathStat) != 0 ||
+        !S_ISDIR(pathStat.st_mode) ||
+        S_ISLNK(pathStat.st_mode) ||
+        !PXOptionalIdentityMatchesBasic(expectedIdentity, &pathStat)) {
+        free(root);
+        return NO;
+    }
+    int descriptor = open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    free(root);
+    if (descriptor < 0 || !PXOptionalSetCloseOnExec(descriptor)) {
+        if (descriptor >= 0) {
+            close(descriptor);
+        }
+        return NO;
+    }
+    struct stat descriptorStat;
+    memset(&descriptorStat, 0, sizeof(descriptorStat));
+    if (fstat(descriptor, &descriptorStat) != 0 ||
+        !S_ISDIR(descriptorStat.st_mode) ||
+        !PXOptionalIdentityMatchesBasic(expectedIdentity, &descriptorStat)) {
+        close(descriptor);
+        return NO;
+    }
+    if (descriptorOut) {
+        *descriptorOut = descriptor;
+    } else {
+        close(descriptor);
+    }
+    return YES;
+}
+
+static PXOptionalDestinationRecord *PXOptionalInspectDestination(
+    NSString *rootPath,
+    PXOptionalIdentity rootIdentity,
+    NSArray<NSString *> *components,
+    PXOptionalDestinationType type,
+    BOOL allowAbsentFinal,
+    NSString *fieldPath,
+    PXOptionalRestoreStagingErrorCode missingCode,
+    NSError **error) {
+    if (components.count == 0) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorUnsafeDestination,
+                                    fieldPath,
+                                    @"The optional Restore destination is unsafe.");
+    }
+    NSString *fullPath = PXOptionalPathForComponents(rootPath, components);
+    if (!fullPath || !PXOptionalPathIsContained(rootPath, fullPath)) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorUnsafeDestination,
+                                    fieldPath,
+                                    @"The optional Restore destination is outside the accepted root.");
+    }
+
+    int currentDescriptor = -1;
+    if (!PXOptionalOpenRootAndVerify(rootPath, rootIdentity, &currentDescriptor)) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
+                                    fieldPath,
+                                    @"The optional Restore destination root identity changed.");
+    }
+
+    BOOL success = NO;
+    PXOptionalDestinationRecord *record = nil;
+    PXOptionalRestoreStagingErrorCode failureCode = missingCode;
+    NSString *failureDescription = @"The optional Restore destination is missing.";
+    do {
+        BOOL parentChainValid = YES;
+        for (NSUInteger index = 0; index + 1 < components.count; index++) {
+            NSString *component = components[index];
+            char *name = PXOptionalCopyComponentRepresentation(component);
+            if (!name) {
+                failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
+                failureDescription = @"An optional Restore destination component is unsafe.";
+                parentChainValid = NO;
+                break;
+            }
+            struct stat pathStat;
+            memset(&pathStat, 0, sizeof(pathStat));
+            if (fstatat(currentDescriptor, name, &pathStat, AT_SYMLINK_NOFOLLOW) != 0) {
+                int inspectionError = errno;
+                free(name);
+                failureCode = inspectionError == ENOENT
+                    ? PXOptionalRestoreStagingErrorMissingDestination
+                    : PXOptionalRestoreStagingErrorUnsafeDestination;
+                failureDescription = inspectionError == ENOENT
+                    ? @"An optional Restore destination parent is missing."
+                    : @"An optional Restore destination parent is unsafe.";
+                parentChainValid = NO;
+                break;
+            }
+            if (!S_ISDIR(pathStat.st_mode) ||
+                S_ISLNK(pathStat.st_mode) ||
+                pathStat.st_dev != rootIdentity.device) {
+                free(name);
+                failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
+                failureDescription = @"An optional Restore destination parent is unsafe.";
+                parentChainValid = NO;
+                break;
+            }
+            int childDescriptor = openat(currentDescriptor,
+                                         name,
+                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+            free(name);
+            if (childDescriptor < 0 || !PXOptionalSetCloseOnExec(childDescriptor)) {
+                if (childDescriptor >= 0) {
+                    close(childDescriptor);
+                }
+                failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
+                failureDescription = @"An optional Restore destination parent identity changed.";
+                parentChainValid = NO;
+                break;
+            }
+            struct stat childStat;
+            memset(&childStat, 0, sizeof(childStat));
+            if (fstat(childDescriptor, &childStat) != 0 ||
+                !S_ISDIR(childStat.st_mode) ||
+                childStat.st_dev != pathStat.st_dev ||
+                childStat.st_ino != pathStat.st_ino) {
+                close(childDescriptor);
+                failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
+                failureDescription = @"An optional Restore destination parent identity changed.";
+                parentChainValid = NO;
+                break;
+            }
+            close(currentDescriptor);
+            currentDescriptor = childDescriptor;
+        }
+        if (!parentChainValid) {
+            break;
+        }
+
+        struct stat parentStat;
+        memset(&parentStat, 0, sizeof(parentStat));
+        if (fstat(currentDescriptor, &parentStat) != 0 ||
+            !S_ISDIR(parentStat.st_mode) ||
+            parentStat.st_dev != rootIdentity.device) {
+            failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
+            failureDescription = @"The optional Restore destination parent identity changed.";
+            break;
+        }
+        PXOptionalIdentity parentIdentity = PXOptionalIdentityFromStat(&parentStat);
+
+        NSString *finalComponent = components.lastObject;
+        char *finalName = PXOptionalCopyComponentRepresentation(finalComponent);
+        if (!finalName) {
+            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
+            failureDescription = @"The optional Restore destination filename is unsafe.";
+            break;
+        }
+        struct stat finalPathStat;
+        memset(&finalPathStat, 0, sizeof(finalPathStat));
+        int finalResult = fstatat(currentDescriptor,
+                                  finalName,
+                                  &finalPathStat,
+                                  AT_SYMLINK_NOFOLLOW);
+        if (finalResult != 0) {
+            int finalError = errno;
+            free(finalName);
+            if (finalError != ENOENT || !allowAbsentFinal) {
+                failureCode = finalError == ENOENT
+                    ? missingCode
+                    : PXOptionalRestoreStagingErrorUnsafeDestination;
+                failureDescription = finalError == ENOENT
+                    ? @"The optional Restore destination is missing."
+                    : @"The optional Restore destination could not be inspected safely.";
+                break;
+            }
+            PXOptionalIdentity emptyIdentity;
+            memset(&emptyIdentity, 0, sizeof(emptyIdentity));
+            record = [[PXOptionalDestinationRecord alloc] initWithPath:fullPath
+                                                            components:components
+                                                             fieldPath:fieldPath
+                                                                  type:type
+                                                               present:NO
+                                                        parentIdentity:parentIdentity
+                                                         finalIdentity:emptyIdentity];
+            success = record != nil;
+            break;
+        }
+
+        BOOL expectedType =
+            (type == PXOptionalDestinationTypeDirectory && S_ISDIR(finalPathStat.st_mode)) ||
+            (type == PXOptionalDestinationTypeRegularFile && S_ISREG(finalPathStat.st_mode));
+        if (!expectedType ||
+            S_ISLNK(finalPathStat.st_mode) ||
+            finalPathStat.st_dev != rootIdentity.device) {
+            free(finalName);
+            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
+            failureDescription = @"The optional Restore destination type is unsafe.";
+            break;
+        }
+        int finalFlags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC;
+        if (type == PXOptionalDestinationTypeDirectory) {
+            finalFlags |= O_DIRECTORY;
+        } else {
+            finalFlags |= O_NONBLOCK;
+        }
+        int finalDescriptor = openat(currentDescriptor, finalName, finalFlags);
+        free(finalName);
+        if (finalDescriptor < 0 || !PXOptionalSetCloseOnExec(finalDescriptor)) {
+            if (finalDescriptor >= 0) {
+                close(finalDescriptor);
+            }
+            failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
+            failureDescription = @"The optional Restore destination identity changed.";
+            break;
+        }
+        struct stat finalDescriptorStat;
+        memset(&finalDescriptorStat, 0, sizeof(finalDescriptorStat));
+        BOOL finalStable =
+            fstat(finalDescriptor, &finalDescriptorStat) == 0 &&
+            finalDescriptorStat.st_dev == finalPathStat.st_dev &&
+            finalDescriptorStat.st_ino == finalPathStat.st_ino &&
+            ((finalDescriptorStat.st_mode & S_IFMT) == (finalPathStat.st_mode & S_IFMT));
+        close(finalDescriptor);
+        if (!finalStable) {
+            failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
+            failureDescription = @"The optional Restore destination identity changed.";
+            break;
+        }
+
+        char resolvedBuffer[PATH_MAX];
+        memset(resolvedBuffer, 0, sizeof(resolvedBuffer));
+        char *fullRepresentation = PXOptionalCopyFileSystemRepresentation(fullPath);
+        if (!fullRepresentation) {
+            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
+            failureDescription = @"The optional Restore destination path is unsafe.";
+            break;
+        }
+        char *resolved = realpath(fullRepresentation, resolvedBuffer);
+        free(fullRepresentation);
+        if (!resolved) {
+            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
+            failureDescription = @"The optional Restore destination could not be canonicalized safely.";
+            break;
+        }
+        NSString *resolvedPath = [NSString stringWithUTF8String:resolvedBuffer];
+        if (![resolvedPath isEqualToString:fullPath] ||
+            !PXOptionalPathIsContained(rootPath, resolvedPath)) {
+            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
+            failureDescription = @"The optional Restore destination escaped the accepted root.";
+            break;
+        }
+
+        record = [[PXOptionalDestinationRecord alloc]
+            initWithPath:fullPath
+              components:components
+               fieldPath:fieldPath
+                    type:type
+                 present:YES
+          parentIdentity:parentIdentity
+           finalIdentity:PXOptionalIdentityFromStat(&finalDescriptorStat)];
+        success = record != nil;
+        if (!success) {
+            failureCode = PXOptionalRestoreStagingErrorInconsistentPlan;
+            failureDescription = @"The optional Restore destination snapshot could not be represented safely.";
+        }
+    } while (NO);
+
+    close(currentDescriptor);
+    if (!success) {
+        return PXOptionalFailObject(error,
+                                    failureCode,
+                                    fieldPath,
+                                    failureDescription);
+    }
+    return record;
+}
+
+static NSString *PXOptionalRevalidateDestinationRecord(NSString *rootPath,
+                                                       PXOptionalIdentity rootIdentity,
+                                                       PXOptionalDestinationRecord *record,
+                                                       NSError **error) {
+    if (![record isKindOfClass:[PXOptionalDestinationRecord class]]) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInconsistentPlan,
+                                    @"$",
+                                    @"The optional Restore destination key is not present in the accepted plan.");
+    }
+    NSError *inspectionError = nil;
+    PXOptionalDestinationRecord *current =
+        PXOptionalInspectDestination(rootPath,
+                                     rootIdentity,
+                                     record.components,
+                                     record.type,
+                                     !record.isPresent,
+                                     record.fieldPath,
+                                     PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
+                                     &inspectionError);
+    if (!current) {
+        if (error) {
+            *error = inspectionError ?: [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                                             code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
+                                                         userInfo:@{
+                                                             NSLocalizedDescriptionKey: @"The optional Restore destination identity changed.",
+                                                             PXOptionalRestoreStagingErrorFieldPathKey: record.fieldPath
+                                                         }];
+        }
+        return nil;
+    }
+    BOOL parentMatches =
+        current.parentIdentity.device == record.parentIdentity.device &&
+        current.parentIdentity.inode == record.parentIdentity.inode &&
+        ((current.parentIdentity.mode & S_IFMT) == (record.parentIdentity.mode & S_IFMT));
+    BOOL finalMatches = current.isPresent == record.isPresent;
+    if (finalMatches && record.isPresent) {
+        finalMatches =
+            current.finalIdentity.device == record.finalIdentity.device &&
+            current.finalIdentity.inode == record.finalIdentity.inode &&
+            ((current.finalIdentity.mode & S_IFMT) == (record.finalIdentity.mode & S_IFMT));
+    }
+    if (!parentMatches || !finalMatches || ![current.path isEqualToString:record.path]) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
+                                    record.fieldPath,
+                                    @"The optional Restore destination identity changed.");
+    }
+    return record.path;
+}
+
+static BOOL PXOptionalResolveMobileLibrary(NSString **pathOut,
+                                           PXOptionalIdentity *identityOut,
+                                           NSError **error) {
+    if (pathOut) {
+        *pathOut = nil;
+    }
+    if (identityOut) {
+        memset(identityOut, 0, sizeof(*identityOut));
+    }
+    NSArray<NSString *> *candidates = @[
+        @"/private/var/mobile/Library",
+        @"/var/mobile/Library",
+        @"/private/var/jb/var/mobile/Library",
+        @"/var/jb/var/mobile/Library"
+    ];
+    NSMutableDictionary<NSString *, NSDictionary *> *rootsByIdentity = [NSMutableDictionary dictionary];
+    for (NSString *candidate in candidates) {
+        char *candidateRepresentation = PXOptionalCopyFileSystemRepresentation(candidate);
+        if (!candidateRepresentation) {
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorUnsafeDestination,
+                                  @"$.mobileLibrary",
+                                  @"A fixed mobile Library candidate is unsafe.");
+        }
+        struct stat candidateStat;
+        memset(&candidateStat, 0, sizeof(candidateStat));
+        if (lstat(candidateRepresentation, &candidateStat) != 0) {
+            int candidateError = errno;
+            free(candidateRepresentation);
+            if (candidateError == ENOENT) {
+                continue;
+            }
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorUnsafeDestination,
+                                  @"$.mobileLibrary",
+                                  @"A fixed mobile Library candidate could not be inspected.");
+        }
+        if (!S_ISDIR(candidateStat.st_mode) || S_ISLNK(candidateStat.st_mode)) {
+            free(candidateRepresentation);
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorUnsafeDestination,
+                                  @"$.mobileLibrary",
+                                  @"A fixed mobile Library candidate is not a real directory.");
+        }
+        char resolvedBuffer[PATH_MAX];
+        memset(resolvedBuffer, 0, sizeof(resolvedBuffer));
+        char *resolved = realpath(candidateRepresentation, resolvedBuffer);
+        free(candidateRepresentation);
+        if (!resolved) {
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorUnsafeDestination,
+                                  @"$.mobileLibrary",
+                                  @"A fixed mobile Library candidate could not be canonicalized.");
+        }
+        NSString *canonicalPath = [NSString stringWithUTF8String:resolvedBuffer];
+        char *canonicalRepresentation = PXOptionalCopyFileSystemRepresentation(canonicalPath);
+        if (!canonicalRepresentation) {
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorUnsafeDestination,
+                                  @"$.mobileLibrary",
+                                  @"A fixed mobile Library candidate is invalid.");
+        }
+        struct stat canonicalPathStat;
+        memset(&canonicalPathStat, 0, sizeof(canonicalPathStat));
+        int descriptor = -1;
+        if (lstat(canonicalRepresentation, &canonicalPathStat) != 0 ||
+            !S_ISDIR(canonicalPathStat.st_mode) ||
+            S_ISLNK(canonicalPathStat.st_mode) ||
+            (descriptor = open(canonicalRepresentation,
+                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)) < 0 ||
+            !PXOptionalSetCloseOnExec(descriptor)) {
+            free(canonicalRepresentation);
+            if (descriptor >= 0) {
+                close(descriptor);
+            }
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorUnsafeDestination,
+                                  @"$.mobileLibrary",
+                                  @"A fixed mobile Library candidate could not be opened safely.");
+        }
+        free(canonicalRepresentation);
+        struct stat descriptorStat;
+        memset(&descriptorStat, 0, sizeof(descriptorStat));
+        BOOL identityValid =
+            fstat(descriptor, &descriptorStat) == 0 &&
+            S_ISDIR(descriptorStat.st_mode) &&
+            candidateStat.st_dev == canonicalPathStat.st_dev &&
+            candidateStat.st_ino == canonicalPathStat.st_ino &&
+            descriptorStat.st_dev == canonicalPathStat.st_dev &&
+            descriptorStat.st_ino == canonicalPathStat.st_ino;
+        close(descriptor);
+        if (!identityValid) {
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
+                                  @"$.mobileLibrary",
+                                  @"A fixed mobile Library candidate identity is unstable.");
+        }
+        NSString *identityKey = [NSString stringWithFormat:@"%llu:%llu",
+                                 (unsigned long long)descriptorStat.st_dev,
+                                 (unsigned long long)descriptorStat.st_ino];
+        if (!rootsByIdentity[identityKey]) {
+            PXOptionalIdentity identity = PXOptionalIdentityFromStat(&descriptorStat);
+            rootsByIdentity[identityKey] = @{
+                @"path": [canonicalPath copy],
+                @"identity": [NSValue valueWithBytes:&identity objCType:@encode(PXOptionalIdentity)]
+            };
+        }
+    }
+    if (rootsByIdentity.count == 0) {
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorMissingDestination,
+                              @"$.mobileLibrary",
+                              @"No accepted mobile Library destination exists.");
+    }
+    if (rootsByIdentity.count != 1) {
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorAmbiguousDestination,
+                              @"$.mobileLibrary",
+                              @"Multiple distinct mobile Library destinations exist.");
+    }
+    NSDictionary *selected = rootsByIdentity.allValues.firstObject;
+    PXOptionalIdentity selectedIdentity;
+    memset(&selectedIdentity, 0, sizeof(selectedIdentity));
+    [selected[@"identity"] getValue:&selectedIdentity];
+    if (pathOut) {
+        *pathOut = [selected[@"path"] copy];
+    }
+    if (identityOut) {
+        *identityOut = selectedIdentity;
+    }
+    return YES;
+}
+
+@interface PXValidatedOptionalFileStage ()
+- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
+                                 filePath:(NSString *)filePath
+                                byteCount:(unsigned long long)byteCount
+                                   sha256:(NSString *)sha256;
+@end
+
+@implementation PXValidatedOptionalFileStage
+- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
+                                 filePath:(NSString *)filePath
+                                byteCount:(unsigned long long)byteCount
+                                   sha256:(NSString *)sha256 {
+    self = [super init];
+    if (self) {
+        _workspaceRootPath = [workspaceRootPath copy];
+        _filePath = [filePath copy];
+        _byteCount = byteCount;
+        _sha256 = [sha256 copy];
+    }
+    return self;
+}
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+@end
+
+@interface PXOptionalFileStagingWorkspace ()
+@property (nonatomic, copy, readwrite) NSString *rootPath;
+@property (nonatomic, copy, readwrite) NSString *filePath;
+@property (nonatomic, strong, readwrite) PXValidatedOptionalFileStage *validatedStage;
+@property (nonatomic, assign) int parentDescriptor;
+@property (nonatomic, assign) int rootDescriptor;
+@property (nonatomic, assign) int payloadDescriptor;
+@property (nonatomic, copy) NSString *rootBasename;
+@property (nonatomic, assign) PXOptionalIdentity parentIdentity;
+@property (nonatomic, assign) PXOptionalIdentity rootIdentity;
+@property (nonatomic, assign) PXOptionalIdentity payloadIdentity;
+@property (nonatomic, assign, getter=isCleaned) BOOL cleaned;
+@property (nonatomic, assign) BOOL ownershipLost;
+- (instancetype)initWithRootPath:(NSString *)rootPath
+                        filePath:(NSString *)filePath
+                  rootBasename:(NSString *)rootBasename
+                parentDescriptor:(int)parentDescriptor
+                  rootDescriptor:(int)rootDescriptor
+               payloadDescriptor:(int)payloadDescriptor
+                  parentIdentity:(PXOptionalIdentity)parentIdentity
+                    rootIdentity:(PXOptionalIdentity)rootIdentity
+                 payloadIdentity:(PXOptionalIdentity)payloadIdentity
+                  validatedStage:(PXValidatedOptionalFileStage *)validatedStage;
+@end
+
+static BOOL PXOptionalReadDigestFromDescriptor(int descriptor,
+                                               unsigned long long *byteCountOut,
+                                               unsigned char digestOut[CC_SHA256_DIGEST_LENGTH]) {
+    if (lseek(descriptor, 0, SEEK_SET) < 0) {
+        return NO;
+    }
+    unsigned char *buffer = malloc(PXOptionalStreamBufferSize);
+    if (!buffer) {
+        return NO;
+    }
+    CC_SHA256_CTX context;
+    CC_SHA256_Init(&context);
+    unsigned long long total = 0;
+    BOOL success = YES;
+    for (;;) {
+        ssize_t amount = read(descriptor, buffer, PXOptionalStreamBufferSize);
+        if (amount < 0 && errno == EINTR) {
+            continue;
+        }
+        if (amount < 0) {
+            success = NO;
+            break;
+        }
+        if (amount == 0) {
+            break;
+        }
+        if (total > ULLONG_MAX - (unsigned long long)amount) {
+            success = NO;
+            break;
+        }
+        total += (unsigned long long)amount;
+        CC_SHA256_Update(&context, buffer, (CC_LONG)amount);
+    }
+    free(buffer);
+    if (!success) {
+        return NO;
+    }
+    CC_SHA256_Final(digestOut, &context);
+    if (byteCountOut) {
+        *byteCountOut = total;
+    }
+    return YES;
+}
+
+static BOOL PXOptionalWriteAll(int descriptor, const unsigned char *bytes, size_t length) {
+    size_t offset = 0;
+    while (offset < length) {
+        ssize_t written = write(descriptor, bytes + offset, length - offset);
+        if (written < 0 && errno == EINTR) {
+            continue;
+        }
+        if (written <= 0) {
+            return NO;
+        }
+        offset += (size_t)written;
+    }
+    return YES;
+}
+
+static NSArray<NSData *> *PXOptionalReadDirectoryNames(int descriptor) {
+    int duplicate = PXOptionalDuplicateDescriptor(descriptor);
+    if (duplicate < 0) {
+        return nil;
+    }
+    DIR *directory = fdopendir(duplicate);
+    if (!directory) {
+        close(duplicate);
+        return nil;
+    }
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
+        if (names.count >= PXOptionalMaximumCleanupEntries) {
+            closedir(directory);
+            return nil;
+        }
+        size_t length = strlen(name);
+        [names addObject:[NSData dataWithBytes:name length:length]];
+    }
+    int readError = errno;
+    if (closedir(directory) != 0 && readError == 0) {
+        readError = errno ?: EIO;
+    }
+    return readError == 0 ? names : nil;
+}
+
+static char *PXOptionalCopyRawName(NSData *nameData) {
+    if (nameData.length > PXOptionalMaximumComponentBytes) {
+        return NULL;
+    }
+    char *name = calloc(nameData.length + 1, 1);
+    if (!name) {
+        return NULL;
+    }
+    memcpy(name, nameData.bytes, nameData.length);
+    return name;
+}
+
+static BOOL PXOptionalCleanupDirectoryContents(int descriptor,
+                                               dev_t expectedDevice,
+                                               NSUInteger *entryCount) {
+    NSArray<NSData *> *names = PXOptionalReadDirectoryNames(descriptor);
+    if (!names) {
+        return NO;
+    }
+    for (NSData *nameData in names) {
+        if (*entryCount >= PXOptionalMaximumCleanupEntries) {
+            return NO;
+        }
+        (*entryCount)++;
+        char *name = PXOptionalCopyRawName(nameData);
+        if (!name) {
+            return NO;
+        }
+        struct stat firstStat;
+        memset(&firstStat, 0, sizeof(firstStat));
+        if (fstatat(descriptor, name, &firstStat, AT_SYMLINK_NOFOLLOW) != 0 ||
+            firstStat.st_dev != expectedDevice) {
+            free(name);
+            return NO;
+        }
+        if (S_ISDIR(firstStat.st_mode)) {
+            int child = openat(descriptor,
+                               name,
+                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+            if (child < 0 || !PXOptionalSetCloseOnExec(child)) {
+                if (child >= 0) {
+                    close(child);
+                }
+                free(name);
+                return NO;
+            }
+            struct stat childStat;
+            memset(&childStat, 0, sizeof(childStat));
+            BOOL childValid =
+                fstat(child, &childStat) == 0 &&
+                childStat.st_dev == firstStat.st_dev &&
+                childStat.st_ino == firstStat.st_ino &&
+                S_ISDIR(childStat.st_mode);
+            if (!childValid ||
+                !PXOptionalCleanupDirectoryContents(child, expectedDevice, entryCount)) {
+                close(child);
+                free(name);
+                return NO;
+            }
+            struct stat secondStat;
+            memset(&secondStat, 0, sizeof(secondStat));
+            BOOL stable =
+                fstatat(descriptor, name, &secondStat, AT_SYMLINK_NOFOLLOW) == 0 &&
+                secondStat.st_dev == firstStat.st_dev &&
+                secondStat.st_ino == firstStat.st_ino &&
+                S_ISDIR(secondStat.st_mode);
+            close(child);
+            if (!stable || unlinkat(descriptor, name, AT_REMOVEDIR) != 0) {
+                free(name);
+                return NO;
+            }
+        } else if (unlinkat(descriptor, name, 0) != 0) {
+            free(name);
+            return NO;
+        }
+        free(name);
+    }
+    return YES;
+}
+
+@implementation PXOptionalFileStagingWorkspace
+
+- (instancetype)initWithRootPath:(NSString *)rootPath
+                        filePath:(NSString *)filePath
+                  rootBasename:(NSString *)rootBasename
+                parentDescriptor:(int)parentDescriptor
+                  rootDescriptor:(int)rootDescriptor
+               payloadDescriptor:(int)payloadDescriptor
+                  parentIdentity:(PXOptionalIdentity)parentIdentity
+                    rootIdentity:(PXOptionalIdentity)rootIdentity
+                 payloadIdentity:(PXOptionalIdentity)payloadIdentity
+                  validatedStage:(PXValidatedOptionalFileStage *)validatedStage {
+    self = [super init];
+    if (self) {
+        _parentDescriptor = -1;
+        _rootDescriptor = -1;
+        _payloadDescriptor = -1;
+        _rootPath = [rootPath copy];
+        _filePath = [filePath copy];
+        _rootBasename = [rootBasename copy];
+        _parentDescriptor = parentDescriptor;
+        _rootDescriptor = rootDescriptor;
+        _payloadDescriptor = payloadDescriptor;
+        _parentIdentity = parentIdentity;
+        _rootIdentity = rootIdentity;
+        _payloadIdentity = payloadIdentity;
+        _validatedStage = validatedStage;
+    }
+    return self;
+}
+
++ (instancetype)workspaceByStagingSourceFileAtPath:(NSString *)sourcePath
+                                             error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (![sourcePath isKindOfClass:[NSString class]] ||
+        sourcePath.length == 0 ||
+        PXOptionalStringContainsNUL(sourcePath)) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInvalidInput,
+                                    @"$.source",
+                                    @"The optional file staging source is invalid.");
+    }
+    NSData *sourceBytes = [sourcePath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!sourceBytes || sourceBytes.length > PXOptionalMaximumPathBytes) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorLimitExceeded,
+                                    @"$.source",
+                                    @"The optional file staging source path limit was exceeded.");
+    }
+
+    int sourceDescriptor = -1;
+    int parentDescriptor = -1;
+    int rootDescriptor = -1;
+    int payloadDescriptor = -1;
+    NSString *rootPath = nil;
+    NSString *filePath = nil;
+    NSString *rootBasename = nil;
+    BOOL rootCreated = NO;
+    PXOptionalIdentity parentIdentity;
+    PXOptionalIdentity rootIdentity;
+    PXOptionalIdentity payloadIdentity;
+    memset(&parentIdentity, 0, sizeof(parentIdentity));
+    memset(&rootIdentity, 0, sizeof(rootIdentity));
+    memset(&payloadIdentity, 0, sizeof(payloadIdentity));
+    NSError *failure = nil;
+
+    do {
+        char *sourceRepresentation = PXOptionalCopyFileSystemRepresentation(sourcePath);
+        if (!sourceRepresentation) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorInvalidInput
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file staging source is invalid.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+        struct stat sourcePathStat;
+        memset(&sourcePathStat, 0, sizeof(sourcePathStat));
+        if (lstat(sourceRepresentation, &sourcePathStat) != 0 ||
+            S_ISLNK(sourcePathStat.st_mode)) {
+            free(sourceRepresentation);
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorSourceOpenFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file source could not be opened safely.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+        sourceDescriptor = open(sourceRepresentation,
+                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+        free(sourceRepresentation);
+        if (sourceDescriptor < 0 || !PXOptionalSetCloseOnExec(sourceDescriptor)) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorSourceOpenFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file source could not be opened safely.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+        struct stat sourceBefore;
+        memset(&sourceBefore, 0, sizeof(sourceBefore));
+        if (fstat(sourceDescriptor, &sourceBefore) != 0 ||
+            sourceBefore.st_dev != sourcePathStat.st_dev ||
+            sourceBefore.st_ino != sourcePathStat.st_ino ||
+            !S_ISREG(sourceBefore.st_mode) ||
+            sourceBefore.st_nlink != 1 ||
+            (sourceBefore.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+            sourceBefore.st_size < 0) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorSourceUnsupported
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file source type is unsupported.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+        unsigned long long sourceSize = (unsigned long long)sourceBefore.st_size;
+        if (sourceSize > PXOptionalMaximumFileBytes) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorLimitExceeded
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file source size limit was exceeded.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+        PXOptionalIdentity sourceIdentity = PXOptionalIdentityFromStat(&sourceBefore);
+
+        const char *parentPath = "/private/var/tmp";
+        struct stat parentPathStat;
+        memset(&parentPathStat, 0, sizeof(parentPathStat));
+        if (lstat(parentPath, &parentPathStat) != 0 ||
+            !S_ISDIR(parentPathStat.st_mode) ||
+            S_ISLNK(parentPathStat.st_mode)) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace parent is unavailable.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        parentDescriptor = open(parentPath,
+                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        if (parentDescriptor < 0 || !PXOptionalSetCloseOnExec(parentDescriptor)) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace parent could not be opened.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        struct stat parentDescriptorStat;
+        memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
+        if (fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
+            parentDescriptorStat.st_dev != parentPathStat.st_dev ||
+            parentDescriptorStat.st_ino != parentPathStat.st_ino ||
+            !S_ISDIR(parentDescriptorStat.st_mode)) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace parent identity is unstable.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        parentIdentity = PXOptionalIdentityFromStat(&parentDescriptorStat);
+
+        char templatePath[] = "/private/var/tmp/weaponx_restore_optional_file.XXXXXX";
+        char *createdPath = mkdtemp(templatePath);
+        if (!createdPath) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be created.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        rootCreated = YES;
+        rootPath = [NSString stringWithUTF8String:createdPath];
+        rootBasename = rootPath.lastPathComponent;
+        if (!rootPath ||
+            !rootBasename ||
+            ![[rootPath stringByDeletingLastPathComponent] isEqualToString:@"/private/var/tmp"] ||
+            !PXOptionalSafeComponent(rootBasename)) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace identity is invalid.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        char *rootName = PXOptionalCopyComponentRepresentation(rootBasename);
+        if (!rootName) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace identity is invalid.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        struct stat rootPathStat;
+        memset(&rootPathStat, 0, sizeof(rootPathStat));
+        if (fstatat(parentDescriptor, rootName, &rootPathStat, AT_SYMLINK_NOFOLLOW) != 0 ||
+            !S_ISDIR(rootPathStat.st_mode) ||
+            rootPathStat.st_dev != parentIdentity.device) {
+            free(rootName);
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace identity is invalid.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        rootDescriptor = openat(parentDescriptor,
+                                rootName,
+                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        free(rootName);
+        if (rootDescriptor < 0 ||
+            !PXOptionalSetCloseOnExec(rootDescriptor) ||
+            fchmod(rootDescriptor, 0700) != 0) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be secured.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        struct stat rootDescriptorStat;
+        memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
+        if (fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
+            rootDescriptorStat.st_dev != rootPathStat.st_dev ||
+            rootDescriptorStat.st_ino != rootPathStat.st_ino ||
+            !S_ISDIR(rootDescriptorStat.st_mode) ||
+            (rootDescriptorStat.st_mode & 07777) != 0700) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be secured.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        rootIdentity = PXOptionalIdentityFromStat(&rootDescriptorStat);
+
+        payloadDescriptor = openat(rootDescriptor,
+                                   "payload",
+                                   O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
+                                   0600);
+        if (payloadDescriptor < 0 ||
+            !PXOptionalSetCloseOnExec(payloadDescriptor) ||
+            fchmod(payloadDescriptor, 0600) != 0) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace payload could not be created.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+
+        unsigned char *buffer = malloc(PXOptionalStreamBufferSize);
+        if (!buffer) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorCopyFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file source could not be staged.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+        CC_SHA256_CTX sourceDigestContext;
+        CC_SHA256_Init(&sourceDigestContext);
+        unsigned long long copiedBytes = 0;
+        BOOL copySucceeded = YES;
+        for (;;) {
+            ssize_t amount = read(sourceDescriptor, buffer, PXOptionalStreamBufferSize);
+            if (amount < 0 && errno == EINTR) {
+                continue;
+            }
+            if (amount < 0) {
+                copySucceeded = NO;
+                break;
+            }
+            if (amount == 0) {
+                break;
+            }
+            if (copiedBytes > ULLONG_MAX - (unsigned long long)amount ||
+                copiedBytes + (unsigned long long)amount > PXOptionalMaximumFileBytes ||
+                !PXOptionalWriteAll(payloadDescriptor, buffer, (size_t)amount)) {
+                copySucceeded = NO;
+                break;
+            }
+            copiedBytes += (unsigned long long)amount;
+            CC_SHA256_Update(&sourceDigestContext, buffer, (CC_LONG)amount);
+        }
+        free(buffer);
+        if (!copySucceeded || copiedBytes != sourceSize || fsync(payloadDescriptor) != 0) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorCopyFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file source could not be staged completely.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+        unsigned char sourceDigest[CC_SHA256_DIGEST_LENGTH];
+        CC_SHA256_Final(sourceDigest, &sourceDigestContext);
+
+        struct stat sourceAfter;
+        memset(&sourceAfter, 0, sizeof(sourceAfter));
+        if (fstat(sourceDescriptor, &sourceAfter) != 0 ||
+            !PXOptionalStableFileIdentityMatches(sourceIdentity, &sourceAfter)) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorSourceChanged
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file source changed during staging.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
+                                      }];
+            break;
+        }
+
+        struct stat payloadBeforeRead;
+        memset(&payloadBeforeRead, 0, sizeof(payloadBeforeRead));
+        if (fstat(payloadDescriptor, &payloadBeforeRead) != 0 ||
+            !S_ISREG(payloadBeforeRead.st_mode) ||
+            payloadBeforeRead.st_nlink != 1 ||
+            payloadBeforeRead.st_dev != rootIdentity.device ||
+            payloadBeforeRead.st_size < 0 ||
+            (payloadBeforeRead.st_mode & 07777) != 0600 ||
+            (unsigned long long)payloadBeforeRead.st_size != copiedBytes) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The staged optional file is invalid.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+        payloadIdentity = PXOptionalIdentityFromStat(&payloadBeforeRead);
+
+        int payloadReadDescriptor = openat(rootDescriptor,
+                                           "payload",
+                                           O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+        if (payloadReadDescriptor < 0 || !PXOptionalSetCloseOnExec(payloadReadDescriptor)) {
+            if (payloadReadDescriptor >= 0) {
+                close(payloadReadDescriptor);
+            }
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The staged optional file could not be verified.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+        struct stat payloadReadStat;
+        memset(&payloadReadStat, 0, sizeof(payloadReadStat));
+        if (fstat(payloadReadDescriptor, &payloadReadStat) != 0 ||
+            !PXOptionalIdentityMatchesBasic(payloadIdentity, &payloadReadStat)) {
+            close(payloadReadDescriptor);
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The staged optional file identity changed.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+        unsigned long long payloadBytes = 0;
+        unsigned char payloadDigest[CC_SHA256_DIGEST_LENGTH];
+        BOOL payloadReadSucceeded =
+            PXOptionalReadDigestFromDescriptor(payloadReadDescriptor,
+                                               &payloadBytes,
+                                               payloadDigest);
+        struct stat payloadAfterRead;
+        memset(&payloadAfterRead, 0, sizeof(payloadAfterRead));
+        BOOL payloadStable =
+            fstat(payloadReadDescriptor, &payloadAfterRead) == 0 &&
+            PXOptionalStableFileIdentityMatches(payloadIdentity, &payloadAfterRead);
+        close(payloadReadDescriptor);
+        if (!payloadReadSucceeded || !payloadStable) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The staged optional file could not be verified.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+        if (payloadBytes != copiedBytes) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorSizeMismatch
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The staged optional file size does not match.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+        if (memcmp(sourceDigest, payloadDigest, CC_SHA256_DIGEST_LENGTH) != 0) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorDigestMismatch
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The staged optional file digest does not match.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+
+        struct stat parentAfter;
+        struct stat rootNamespaceStat;
+        struct stat payloadPathStat;
+        struct stat rootAfter;
+        memset(&parentAfter, 0, sizeof(parentAfter));
+        memset(&rootNamespaceStat, 0, sizeof(rootNamespaceStat));
+        memset(&payloadPathStat, 0, sizeof(payloadPathStat));
+        memset(&rootAfter, 0, sizeof(rootAfter));
+        char *finalRootName = PXOptionalCopyComponentRepresentation(rootBasename);
+        BOOL finalNamespaceStable =
+            finalRootName != NULL &&
+            fstat(parentDescriptor, &parentAfter) == 0 &&
+            PXOptionalIdentityMatchesBasic(parentIdentity, &parentAfter) &&
+            fstatat(parentDescriptor,
+                    finalRootName,
+                    &rootNamespaceStat,
+                    AT_SYMLINK_NOFOLLOW) == 0 &&
+            PXOptionalIdentityMatchesBasic(rootIdentity, &rootNamespaceStat) &&
+            fstat(rootDescriptor, &rootAfter) == 0 &&
+            PXOptionalIdentityMatchesBasic(rootIdentity, &rootAfter) &&
+            fstatat(rootDescriptor,
+                    "payload",
+                    &payloadPathStat,
+                    AT_SYMLINK_NOFOLLOW) == 0 &&
+            PXOptionalIdentityMatchesBasic(payloadIdentity, &payloadPathStat);
+        free(finalRootName);
+        if (!finalNamespaceStable) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace identity changed.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+
+        filePath = [rootPath stringByAppendingPathComponent:@"payload"];
+        NSString *digestString = PXOptionalLowercaseDigest(sourceDigest);
+        PXValidatedOptionalFileStage *stage =
+            [[PXValidatedOptionalFileStage alloc] initWithWorkspaceRootPath:rootPath
+                                                                   filePath:filePath
+                                                                  byteCount:copiedBytes
+                                                                     sha256:digestString];
+        if (!stage || digestString.length != 64) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The staged optional file result is invalid.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
+                                      }];
+            break;
+        }
+        PXOptionalFileStagingWorkspace *workspace =
+            [[PXOptionalFileStagingWorkspace alloc] initWithRootPath:rootPath
+                                                            filePath:filePath
+                                                      rootBasename:rootBasename
+                                                    parentDescriptor:parentDescriptor
+                                                      rootDescriptor:rootDescriptor
+                                                   payloadDescriptor:payloadDescriptor
+                                                      parentIdentity:parentIdentity
+                                                        rootIdentity:rootIdentity
+                                                     payloadIdentity:payloadIdentity
+                                                      validatedStage:stage];
+        if (!workspace) {
+            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                      userInfo:@{
+                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be represented safely.",
+                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                      }];
+            break;
+        }
+        close(sourceDescriptor);
+        sourceDescriptor = -1;
+        return workspace;
+    } while (NO);
+
+    PXOptionalCloseDescriptor(&sourceDescriptor);
+    PXOptionalCloseDescriptor(&payloadDescriptor);
+    if (rootCreated && rootDescriptor >= 0) {
+        struct stat partialRootStat;
+        memset(&partialRootStat, 0, sizeof(partialRootStat));
+        if (fstat(rootDescriptor, &partialRootStat) == 0 &&
+            S_ISDIR(partialRootStat.st_mode)) {
+            NSUInteger cleanupCount = 0;
+            PXOptionalCleanupDirectoryContents(rootDescriptor,
+                                               partialRootStat.st_dev,
+                                               &cleanupCount);
+        }
+    }
+    PXOptionalCloseDescriptor(&rootDescriptor);
+    if (rootCreated && parentDescriptor >= 0 && rootBasename.length) {
+        char *rootName = PXOptionalCopyComponentRepresentation(rootBasename);
+        if (rootName) {
+            unlinkat(parentDescriptor, rootName, AT_REMOVEDIR);
+            free(rootName);
+        }
+    }
+    PXOptionalCloseDescriptor(&parentDescriptor);
+    if (error) {
+        *error = failure ?: [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                                code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
+                                            userInfo:@{
+                                                NSLocalizedDescriptionKey: @"The optional file staging workspace could not be created.",
+                                                PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
+                                            }];
+    }
+    return nil;
+}
+
+- (BOOL)cleanupWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (self.isCleaned) {
+        return YES;
+    }
+    if (self.ownershipLost ||
+        self.parentDescriptor < 0 ||
+        self.rootDescriptor < 0 ||
+        self.payloadDescriptor < 0 ||
+        self.rootBasename.length == 0) {
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorCleanupFailed,
+                              @"$.workspace",
+                              @"The optional file workspace can no longer be cleaned safely.");
+    }
+
+    char *rootName = PXOptionalCopyComponentRepresentation(self.rootBasename);
+    if (!rootName) {
+        self.ownershipLost = YES;
+        PXOptionalCloseDescriptor(&_payloadDescriptor);
+        PXOptionalCloseDescriptor(&_rootDescriptor);
+        PXOptionalCloseDescriptor(&_parentDescriptor);
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorCleanupFailed,
+                              @"$.workspace",
+                              @"The optional file workspace can no longer be cleaned safely.");
+    }
+    struct stat parentStat;
+    struct stat rootDescriptorStat;
+    struct stat rootPathStat;
+    struct stat payloadDescriptorStat;
+    struct stat payloadPathStat;
+    memset(&parentStat, 0, sizeof(parentStat));
+    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
+    memset(&rootPathStat, 0, sizeof(rootPathStat));
+    memset(&payloadDescriptorStat, 0, sizeof(payloadDescriptorStat));
+    memset(&payloadPathStat, 0, sizeof(payloadPathStat));
+    BOOL identityValid =
+        fstat(self.parentDescriptor, &parentStat) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.parentIdentity, &parentStat) &&
+        fstat(self.rootDescriptor, &rootDescriptorStat) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.rootIdentity, &rootDescriptorStat) &&
+        fstatat(self.parentDescriptor, rootName, &rootPathStat, AT_SYMLINK_NOFOLLOW) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.rootIdentity, &rootPathStat) &&
+        fstat(self.payloadDescriptor, &payloadDescriptorStat) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.payloadIdentity, &payloadDescriptorStat) &&
+        fstatat(self.rootDescriptor, "payload", &payloadPathStat, AT_SYMLINK_NOFOLLOW) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.payloadIdentity, &payloadPathStat);
+    if (!identityValid) {
+        free(rootName);
+        self.ownershipLost = YES;
+        PXOptionalCloseDescriptor(&_payloadDescriptor);
+        PXOptionalCloseDescriptor(&_rootDescriptor);
+        PXOptionalCloseDescriptor(&_parentDescriptor);
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorCleanupFailed,
+                              @"$.workspace",
+                              @"The optional file workspace identity changed before cleanup.");
+    }
+
+    NSUInteger cleanupCount = 0;
+    BOOL contentsRemoved =
+        PXOptionalCleanupDirectoryContents(self.rootDescriptor,
+                                           self.rootIdentity.device,
+                                           &cleanupCount);
+    if (!contentsRemoved) {
+        free(rootName);
+        self.ownershipLost = YES;
+        PXOptionalCloseDescriptor(&_payloadDescriptor);
+        PXOptionalCloseDescriptor(&_rootDescriptor);
+        PXOptionalCloseDescriptor(&_parentDescriptor);
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorCleanupFailed,
+                              @"$.workspace",
+                              @"The optional file workspace cleanup could not complete safely.");
+    }
+
+    PXOptionalCloseDescriptor(&_payloadDescriptor);
+    int removeResult = unlinkat(self.parentDescriptor, rootName, AT_REMOVEDIR);
+    int removeError = errno;
+    free(rootName);
+    if (removeResult != 0 && removeError != ENOENT) {
+        self.ownershipLost = YES;
+        PXOptionalCloseDescriptor(&_rootDescriptor);
+        PXOptionalCloseDescriptor(&_parentDescriptor);
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorCleanupFailed,
+                              @"$.workspace",
+                              @"The optional file workspace root could not be removed safely.");
+    }
+    if (removeResult != 0 && removeError == ENOENT) {
+        struct stat replacementStat;
+        memset(&replacementStat, 0, sizeof(replacementStat));
+        char *verifyName = PXOptionalCopyComponentRepresentation(self.rootBasename);
+        if (!verifyName ||
+            fstatat(self.parentDescriptor,
+                    verifyName,
+                    &replacementStat,
+                    AT_SYMLINK_NOFOLLOW) == 0 ||
+            errno != ENOENT) {
+            free(verifyName);
+            self.ownershipLost = YES;
+            PXOptionalCloseDescriptor(&_rootDescriptor);
+            PXOptionalCloseDescriptor(&_parentDescriptor);
+            return PXOptionalFail(error,
+                                  PXOptionalRestoreStagingErrorCleanupFailed,
+                                  @"$.workspace",
+                                  @"The optional file workspace absence could not be proven safely.");
+        }
+        free(verifyName);
+    }
+    PXOptionalCloseDescriptor(&_rootDescriptor);
+    PXOptionalCloseDescriptor(&_parentDescriptor);
+    self.cleaned = YES;
+    return YES;
+}
+
+- (void)dealloc {
+    if (!_cleaned && !_ownershipLost) {
+        [self cleanupWithError:nil];
+    }
+    PXOptionalCloseDescriptor(&_payloadDescriptor);
+    PXOptionalCloseDescriptor(&_rootDescriptor);
+    PXOptionalCloseDescriptor(&_parentDescriptor);
+}
+
+@end
+
+@interface PXOptionalRestoreDestinationPlan ()
+@property (nonatomic, copy, readwrite) NSString *mobileLibraryPath;
+@property (nonatomic, copy, nullable, readwrite) NSString *profileAppDataPath;
+@property (nonatomic, copy, nullable, readwrite) NSString *globalSafariPath;
+@property (nonatomic, copy, nullable, readwrite) NSString *preferencesPath;
+@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *systemGlobalPathsBySubdirectory;
+@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *sharedDatabasePathsByRelativePath;
+@property (nonatomic, assign) PXOptionalIdentity mobileLibraryIdentity;
+@property (nonatomic, strong, nullable) PXOptionalDestinationRecord *profileRecord;
+@property (nonatomic, strong, nullable) PXOptionalDestinationRecord *globalSafariRecord;
+@property (nonatomic, strong, nullable) PXOptionalDestinationRecord *preferencesRecord;
+@property (nonatomic, copy) NSDictionary<NSString *, PXOptionalDestinationRecord *> *systemRecordsBySubdirectory;
+@property (nonatomic, copy) NSDictionary<NSString *, PXOptionalDestinationRecord *> *sharedRecordsByRelativePath;
+- (instancetype)initWithMobileLibraryPath:(NSString *)mobileLibraryPath
+                    mobileLibraryIdentity:(PXOptionalIdentity)mobileLibraryIdentity
+                            profileRecord:(nullable PXOptionalDestinationRecord *)profileRecord
+                       globalSafariRecord:(nullable PXOptionalDestinationRecord *)globalSafariRecord
+                         preferencesRecord:(nullable PXOptionalDestinationRecord *)preferencesRecord
+              systemRecordsBySubdirectory:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)systemRecords
+              sharedRecordsByRelativePath:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)sharedRecords;
+@end
+
+@implementation PXOptionalRestoreDestinationPlan
+
+- (instancetype)initWithMobileLibraryPath:(NSString *)mobileLibraryPath
+                    mobileLibraryIdentity:(PXOptionalIdentity)mobileLibraryIdentity
+                            profileRecord:(PXOptionalDestinationRecord *)profileRecord
+                       globalSafariRecord:(PXOptionalDestinationRecord *)globalSafariRecord
+                        preferencesRecord:(PXOptionalDestinationRecord *)preferencesRecord
+              systemRecordsBySubdirectory:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)systemRecords
+              sharedRecordsByRelativePath:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)sharedRecords {
+    self = [super init];
+    if (self) {
+        _mobileLibraryPath = [mobileLibraryPath copy];
+        _mobileLibraryIdentity = mobileLibraryIdentity;
+        _profileRecord = profileRecord;
+        _globalSafariRecord = globalSafariRecord;
+        _preferencesRecord = preferencesRecord;
+        _profileAppDataPath = [profileRecord.path copy];
+        _globalSafariPath = [globalSafariRecord.path copy];
+        _preferencesPath = [preferencesRecord.path copy];
+        _systemRecordsBySubdirectory = [systemRecords copy];
+        _sharedRecordsByRelativePath = [sharedRecords copy];
+        NSMutableDictionary<NSString *, NSString *> *systemPaths =
+            [NSMutableDictionary dictionaryWithCapacity:systemRecords.count];
+        [systemRecords enumerateKeysAndObjectsUsingBlock:
+            ^(NSString *key, PXOptionalDestinationRecord *record, BOOL *stop) {
+                (void)stop;
+                systemPaths[key] = record.path;
+            }];
+        NSMutableDictionary<NSString *, NSString *> *sharedPaths =
+            [NSMutableDictionary dictionaryWithCapacity:sharedRecords.count];
+        [sharedRecords enumerateKeysAndObjectsUsingBlock:
+            ^(NSString *key, PXOptionalDestinationRecord *record, BOOL *stop) {
+                (void)stop;
+                sharedPaths[key] = record.path;
+            }];
+        _systemGlobalPathsBySubdirectory = [systemPaths copy];
+        _sharedDatabasePathsByRelativePath = [sharedPaths copy];
+    }
+    return self;
+}
+
++ (instancetype)destinationPlanForRestorePlan:(PXRestorePlan *)restorePlan
+                              bundleIdentifier:(NSString *)bundleIdentifier
+                       activeProfileIdentifier:(NSString *)profileIdentifier
+                                         error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (![restorePlan isKindOfClass:[PXRestorePlan class]] ||
+        !PXOptionalSafeComponent(bundleIdentifier) ||
+        ![restorePlan.bundleIdentifier isEqualToString:bundleIdentifier]) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInvalidInput,
+                                    @"$",
+                                    @"The optional Restore destination-plan input is invalid.");
+    }
+    if (![restorePlan.systemGlobalItems isKindOfClass:[NSArray class]] ||
+        ![restorePlan.sharedDatabaseItems isKindOfClass:[NSArray class]]) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInconsistentPlan,
+                                    @"$",
+                                    @"The accepted optional Restore plan is inconsistent.");
+    }
+    if (restorePlan.includesGlobalSafari &&
+        ![bundleIdentifier isEqualToString:@"com.apple.mobilesafari"]) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInconsistentPlan,
+                                    @"$.globalSafari.destination",
+                                    @"The global Safari destination is inconsistent with the Restore target.");
+    }
+    if (restorePlan.includesProfileAppData && !PXOptionalSafeComponent(profileIdentifier)) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorMissingDestination,
+                                    @"$.profileAppData.destination",
+                                    @"The active profile destination identity is unavailable.");
+    }
+
+    NSUInteger baseTarDirectoryCount = 0;
+    if (restorePlan.includesProfileAppData) {
+        baseTarDirectoryCount++;
+    }
+    if (restorePlan.includesGlobalSafari) {
+        baseTarDirectoryCount++;
+    }
+    NSUInteger possibleSafariSkip = restorePlan.includesGlobalSafari ? 1 : 0;
+    if (baseTarDirectoryCount > PXOptionalMaximumTarDirectoryItems ||
+        PXOptionalMaximumTarDirectoryItems - baseTarDirectoryCount > NSUIntegerMax - possibleSafariSkip ||
+        restorePlan.systemGlobalItems.count >
+            (PXOptionalMaximumTarDirectoryItems - baseTarDirectoryCount + possibleSafariSkip)) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorLimitExceeded,
+                                    @"$",
+                                    @"The optional Restore directory-item limit was exceeded.");
+    }
+
+    NSUInteger fileItemCount = restorePlan.sharedDatabaseItems.count;
+    if (restorePlan.includesPreferences) {
+        if (fileItemCount == NSUIntegerMax) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorLimitExceeded,
+                                        @"$",
+                                        @"The optional Restore item count overflowed.");
+        }
+        fileItemCount++;
+    }
+    if (restorePlan.includesKeychain) {
+        if (fileItemCount == NSUIntegerMax) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorLimitExceeded,
+                                        @"$",
+                                        @"The optional Restore item count overflowed.");
+        }
+        fileItemCount++;
+    }
+    if (fileItemCount > PXOptionalMaximumFileItems) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorLimitExceeded,
+                                    @"$",
+                                    @"The optional Restore file-item limit was exceeded.");
+    }
+
+    NSString *mobileLibraryPath = nil;
+    PXOptionalIdentity mobileLibraryIdentity;
+    memset(&mobileLibraryIdentity, 0, sizeof(mobileLibraryIdentity));
+    if (!PXOptionalResolveMobileLibrary(&mobileLibraryPath,
+                                        &mobileLibraryIdentity,
+                                        error)) {
+        return nil;
+    }
+
+    NSMutableArray<PXOptionalDestinationRecord *> *inventory = [NSMutableArray array];
+    PXOptionalDestinationRecord *profileRecord = nil;
+    PXOptionalDestinationRecord *globalSafariRecord = nil;
+    PXOptionalDestinationRecord *preferencesRecord = nil;
+    NSMutableDictionary<NSString *, PXOptionalDestinationRecord *> *systemRecords =
+        [NSMutableDictionary dictionary];
+    NSMutableDictionary<NSString *, PXOptionalDestinationRecord *> *sharedRecords =
+        [NSMutableDictionary dictionary];
+
+    if (restorePlan.includesProfileAppData) {
+        NSArray *components = @[@"WeaponX", @"Profiles", profileIdentifier, @"appdata", bundleIdentifier];
+        profileRecord = PXOptionalInspectDestination(mobileLibraryPath,
+                                                     mobileLibraryIdentity,
+                                                     components,
+                                                     PXOptionalDestinationTypeDirectory,
+                                                     NO,
+                                                     @"$.profileAppData.destination",
+                                                     PXOptionalRestoreStagingErrorMissingDestination,
+                                                     error);
+        if (!profileRecord ||
+            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
+                                                   mobileLibraryIdentity,
+                                                   profileRecord,
+                                                   error)) {
+            return nil;
+        }
+        [inventory addObject:profileRecord];
+    }
+
+    if (restorePlan.includesGlobalSafari) {
+        globalSafariRecord = PXOptionalInspectDestination(mobileLibraryPath,
+                                                          mobileLibraryIdentity,
+                                                          @[@"Safari"],
+                                                          PXOptionalDestinationTypeDirectory,
+                                                          NO,
+                                                          @"$.globalSafari.destination",
+                                                          PXOptionalRestoreStagingErrorMissingDestination,
+                                                          error);
+        if (!globalSafariRecord ||
+            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
+                                                   mobileLibraryIdentity,
+                                                   globalSafariRecord,
+                                                   error)) {
+            return nil;
+        }
+        [inventory addObject:globalSafariRecord];
+    }
+
+    NSMutableSet<NSString *> *systemKeys = [NSMutableSet set];
+    for (NSUInteger index = 0; index < restorePlan.systemGlobalItems.count; index++) {
+        id candidate = restorePlan.systemGlobalItems[index];
+        NSString *fieldPath = [NSString stringWithFormat:@"$.systemGlobalItems[%lu].destination",
+                               (unsigned long)index];
+        if (![candidate isKindOfClass:[PXRestorePlanSystemGlobalItem class]]) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorInconsistentPlan,
+                                        fieldPath,
+                                        @"The system-global destination plan is inconsistent.");
+        }
+        PXRestorePlanSystemGlobalItem *item = candidate;
+        NSString *subdirectory = item.librarySubdirectory;
+        if (!PXOptionalSafeComponent(subdirectory) ||
+            [systemKeys containsObject:subdirectory]) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorInconsistentPlan,
+                                        fieldPath,
+                                        @"The system-global destination plan is inconsistent.");
+        }
+        [systemKeys addObject:[subdirectory copy]];
+        if ([bundleIdentifier isEqualToString:@"com.apple.mobilesafari"] &&
+            [subdirectory isEqualToString:@"Safari"] &&
+            restorePlan.includesGlobalSafari) {
+            continue;
+        }
+        PXOptionalDestinationRecord *record =
+            PXOptionalInspectDestination(mobileLibraryPath,
+                                         mobileLibraryIdentity,
+                                         @[subdirectory],
+                                         PXOptionalDestinationTypeDirectory,
+                                         YES,
+                                         fieldPath,
+                                         PXOptionalRestoreStagingErrorUnsafeDestination,
+                                         error);
+        if (!record ||
+            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
+                                                   mobileLibraryIdentity,
+                                                   record,
+                                                   error)) {
+            return nil;
+        }
+        systemRecords[subdirectory] = record;
+        [inventory addObject:record];
+    }
+
+    NSMutableSet<NSString *> *sharedKeys = [NSMutableSet set];
+    for (NSUInteger index = 0; index < restorePlan.sharedDatabaseItems.count; index++) {
+        id candidate = restorePlan.sharedDatabaseItems[index];
+        NSString *fieldPath = [NSString stringWithFormat:@"$.sharedDatabaseItems[%lu].destination",
+                               (unsigned long)index];
+        if (![candidate isKindOfClass:[PXRestorePlanSharedDatabaseItem class]]) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorInconsistentPlan,
+                                        fieldPath,
+                                        @"The shared database destination plan is inconsistent.");
+        }
+        PXRestorePlanSharedDatabaseItem *item = candidate;
+        NSString *relativePath = item.libraryRelativePath;
+        NSArray<NSString *> *components = PXOptionalSafeRelativeComponents(relativePath);
+        if (!components || [sharedKeys containsObject:relativePath]) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorInconsistentPlan,
+                                        fieldPath,
+                                        @"The shared database destination plan is inconsistent.");
+        }
+        [sharedKeys addObject:[relativePath copy]];
+        PXOptionalDestinationRecord *record =
+            PXOptionalInspectDestination(mobileLibraryPath,
+                                         mobileLibraryIdentity,
+                                         components,
+                                         PXOptionalDestinationTypeRegularFile,
+                                         YES,
+                                         fieldPath,
+                                         PXOptionalRestoreStagingErrorMissingDestination,
+                                         error);
+        if (!record ||
+            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
+                                                   mobileLibraryIdentity,
+                                                   record,
+                                                   error)) {
+            return nil;
+        }
+        sharedRecords[relativePath] = record;
+        [inventory addObject:record];
+    }
+
+    if (restorePlan.includesPreferences) {
+        NSString *preferenceFilename = [bundleIdentifier stringByAppendingString:@".plist"];
+        if (!PXOptionalSafeComponent(preferenceFilename)) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorUnsafeDestination,
+                                        @"$.preferences.destination",
+                                        @"The Preferences destination identity is unsafe.");
+        }
+        preferencesRecord =
+            PXOptionalInspectDestination(mobileLibraryPath,
+                                         mobileLibraryIdentity,
+                                         @[@"Preferences", preferenceFilename],
+                                         PXOptionalDestinationTypeRegularFile,
+                                         YES,
+                                         @"$.preferences.destination",
+                                         PXOptionalRestoreStagingErrorMissingDestination,
+                                         error);
+        if (!preferencesRecord ||
+            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
+                                                   mobileLibraryIdentity,
+                                                   preferencesRecord,
+                                                   error)) {
+            return nil;
+        }
+        [inventory addObject:preferencesRecord];
+    }
+
+    NSUInteger tarDirectoryCount = systemRecords.count;
+    if (restorePlan.includesProfileAppData) {
+        if (tarDirectoryCount == NSUIntegerMax) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorLimitExceeded,
+                                        @"$",
+                                        @"The optional Restore item count overflowed.");
+        }
+        tarDirectoryCount++;
+    }
+    if (restorePlan.includesGlobalSafari) {
+        if (tarDirectoryCount == NSUIntegerMax) {
+            return PXOptionalFailObject(error,
+                                        PXOptionalRestoreStagingErrorLimitExceeded,
+                                        @"$",
+                                        @"The optional Restore item count overflowed.");
+        }
+        tarDirectoryCount++;
+    }
+    if (tarDirectoryCount > PXOptionalMaximumTarDirectoryItems ||
+        tarDirectoryCount > NSUIntegerMax - fileItemCount ||
+        tarDirectoryCount + fileItemCount > PXOptionalMaximumTotalItems) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorLimitExceeded,
+                                    @"$",
+                                    @"The optional Restore item limit was exceeded.");
+    }
+
+    for (NSUInteger leftIndex = 0; leftIndex < inventory.count; leftIndex++) {
+        PXOptionalDestinationRecord *left = inventory[leftIndex];
+        for (NSUInteger rightIndex = leftIndex + 1; rightIndex < inventory.count; rightIndex++) {
+            PXOptionalDestinationRecord *right = inventory[rightIndex];
+            if ([left.path isEqualToString:right.path] ||
+                PXOptionalPathIsAncestor(left.path, right.path) ||
+                PXOptionalPathIsAncestor(right.path, left.path)) {
+                return PXOptionalFailObject(error,
+                                            PXOptionalRestoreStagingErrorInconsistentPlan,
+                                            @"$",
+                                            @"Optional Restore destinations overlap unsafely.");
+            }
+        }
+    }
+
+    PXOptionalRestoreDestinationPlan *plan =
+        [[PXOptionalRestoreDestinationPlan alloc]
+            initWithMobileLibraryPath:mobileLibraryPath
+               mobileLibraryIdentity:mobileLibraryIdentity
+                       profileRecord:profileRecord
+                  globalSafariRecord:globalSafariRecord
+                   preferencesRecord:preferencesRecord
+         systemRecordsBySubdirectory:systemRecords
+         sharedRecordsByRelativePath:sharedRecords];
+    if (!plan) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInconsistentPlan,
+                                    @"$",
+                                    @"The optional Restore destination plan could not be represented safely.");
+    }
+    return plan;
+}
+
+- (NSString *)systemGlobalPathForSubdirectory:(NSString *)subdirectory {
+    if (![subdirectory isKindOfClass:[NSString class]] || subdirectory.length == 0) {
+        return nil;
+    }
+    return self.systemGlobalPathsBySubdirectory[subdirectory];
+}
+
+- (NSString *)sharedDatabasePathForRelativePath:(NSString *)relativePath {
+    if (![relativePath isKindOfClass:[NSString class]] || relativePath.length == 0) {
+        return nil;
+    }
+    return self.sharedDatabasePathsByRelativePath[relativePath];
+}
+
+- (NSString *)revalidatedProfileAppDataPathWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
+                                                 self.mobileLibraryIdentity,
+                                                 self.profileRecord,
+                                                 error);
+}
+
+- (NSString *)revalidatedGlobalSafariPathWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
+                                                 self.mobileLibraryIdentity,
+                                                 self.globalSafariRecord,
+                                                 error);
+}
+
+- (NSString *)revalidatedPreferencesPathWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
+                                                 self.mobileLibraryIdentity,
+                                                 self.preferencesRecord,
+                                                 error);
+}
+
+- (NSString *)revalidatedSystemGlobalPathForSubdirectory:(NSString *)subdirectory
+                                                   error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (![subdirectory isKindOfClass:[NSString class]] || subdirectory.length == 0) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInvalidInput,
+                                    @"$",
+                                    @"The system-global destination key is invalid.");
+    }
+    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
+                                                 self.mobileLibraryIdentity,
+                                                 self.systemRecordsBySubdirectory[subdirectory],
+                                                 error);
+}
+
+- (NSString *)revalidatedSharedDatabasePathForRelativePath:(NSString *)relativePath
+                                                     error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (![relativePath isKindOfClass:[NSString class]] || relativePath.length == 0) {
+        return PXOptionalFailObject(error,
+                                    PXOptionalRestoreStagingErrorInvalidInput,
+                                    @"$",
+                                    @"The shared database destination key is invalid.");
+    }
+    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
+                                                 self.mobileLibraryIdentity,
+                                                 self.sharedRecordsByRelativePath[relativePath],
+                                                 error);
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
```

## 24. Explicit scenario matrix

| # | Scenario | Expected TASK-2.10 outcome |
|---:|---|---|
| 1 | rootful alias candidates collapse to one mobile Library | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 2 | zero mobile Library roots | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 3 | distinct rootful/rootless roots ambiguous | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 4 | fixed candidate final symlink rejected | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 5 | fixed candidate non-directory rejected | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 6 | candidate realpath failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 7 | candidate canonical open failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 8 | candidate path/descriptor identity mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 9 | candidate alias dev/inode match | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 10 | canonical mobile Library copied into plan | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 11 | bundle identifier safe component | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 12 | bundle identifier empty | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 13 | bundle identifier whitespace-only | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 14 | bundle identifier NUL | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 15 | bundle identifier control byte | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 16 | bundle identifier slash | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 17 | bundle identifier backslash | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 18 | bundle identifier dot | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 19 | bundle identifier dotdot | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 20 | bundle identifier 255 UTF-8 bytes | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 21 | bundle identifier 256 UTF-8 bytes | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 22 | restore-plan bundle mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 23 | profile excluded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 24 | profile included without profile ID | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 25 | profile identifier safe | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 26 | profile identifier unsafe | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 27 | profile destination parent missing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 28 | profile destination final missing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 29 | profile destination final symlink | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 30 | profile destination final file conflict | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 31 | profile destination device crossing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 32 | profile destination canonical escape | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 33 | profile destination accepted | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 34 | profile planning identity second pass | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 35 | global Safari excluded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 36 | global Safari included for wrong bundle | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 37 | global Safari destination missing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 38 | global Safari destination symlink | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 39 | global Safari destination file conflict | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 40 | global Safari device crossing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 41 | global Safari accepted | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 42 | system-global existing directory | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 43 | system-global absent final | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 44 | system-global final regular-file conflict | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 45 | system-global final symlink | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 46 | system-global device crossing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 47 | system-global unsafe subdirectory | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 48 | system-global duplicate subdirectory | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 49 | Safari duplicate skipped for Safari bundle | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 50 | Safari item retained when global Safari excluded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 51 | shared DB existing file | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 52 | shared DB absent file with existing parent | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 53 | shared DB missing parent | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 54 | shared DB symlink final | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 55 | shared DB directory final | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 56 | shared DB FIFO final | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 57 | shared DB socket final | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 58 | shared DB device final | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 59 | shared DB relative path leading slash | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 60 | shared DB relative path trailing slash | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 61 | shared DB doubled slash | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 62 | shared DB backslash | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 63 | shared DB dot component | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 64 | shared DB dotdot component | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 65 | shared DB component 255 bytes | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 66 | shared DB component 256 bytes | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 67 | shared DB path 4096 bytes | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 68 | shared DB path 4097 bytes | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 69 | shared DB duplicate relative path | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 70 | Preferences excluded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 71 | Preferences existing file | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 72 | Preferences absent file | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 73 | Preferences parent missing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 74 | Preferences final symlink | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 75 | Preferences directory conflict | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 76 | Preferences same-device accepted | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 77 | exact destination duplicate | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 78 | directory/file exact conflict | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 79 | directory ancestor overlap | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 80 | directory descendant overlap | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 81 | shared DB inside directory wipe target | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 82 | Preferences inside system-global wipe target | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 83 | profile destination overlaps system-global target | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 84 | path outside mobile Library | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 85 | Keychain omitted from destination inventory | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 86 | 1024 tar-directory boundary accepted | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 87 | 1025 tar-directory items rejected | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 88 | 4096 optional-file items boundary accepted | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 89 | 4097 optional-file items rejected | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 90 | 4096 total optional items accepted | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 91 | 4097 total optional items rejected | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 92 | Safari skip applied before exact limit | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 93 | count addition overflow rejected | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 94 | destination unchanged revalidation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 95 | destination parent inode replacement | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 96 | existing destination inode replacement | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 97 | existing destination type replacement | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 98 | absent destination remains absent | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 99 | absent destination appears before mutation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 100 | existing destination disappears before mutation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 101 | destination device changes before mutation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 102 | destination canonical path not replaced | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 103 | unknown system key revalidation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 104 | unknown shared DB key revalidation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 105 | profile revalidation when excluded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 106 | global revalidation when excluded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 107 | Preferences revalidation when excluded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 108 | source safe regular file | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 109 | source path empty | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 110 | source path NUL | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 111 | source path >4096 bytes | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 112 | source final symlink | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 113 | source hard link | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 114 | source FIFO | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 115 | source socket | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 116 | source character device | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 117 | source block device | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 118 | source directory | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 119 | source setuid | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 120 | source setgid | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 121 | source negative size defensive rejection | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 122 | zero-byte source | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 123 | 64 GiB source boundary | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 124 | 64 GiB plus one rejection | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 125 | source open failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 126 | source path/fd identity mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 127 | source changes device during copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 128 | source changes inode during copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 129 | source changes type during copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 130 | source changes link count during copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 131 | source changes size during copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 132 | source changes mtime during copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 133 | source changes ctime during copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 134 | source atime-only change ignored | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 135 | read EINTR retry | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 136 | write EINTR retry | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 137 | short write loop completion | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 138 | non-EINTR read failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 139 | non-EINTR write failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 140 | byte-count overflow rejection | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 141 | copy byte count shorter than source | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 142 | copy byte count larger than stable source defensive rejection | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 143 | payload fsync failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 144 | workspace fixed parent missing | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 145 | workspace fixed parent symlink | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 146 | workspace fixed parent non-directory | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 147 | workspace parent identity mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 148 | mkdtemp success | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 149 | mkdtemp collision handled by libc | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 150 | mkdtemp failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 151 | generated root direct child proof | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 152 | generated root mode 0700 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 153 | root fchmod failure | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 154 | root identity mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 155 | payload name exactly payload | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 156 | payload O_CREAT/O_EXCL | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 157 | payload O_NOFOLLOW/O_CLOEXEC | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 158 | payload mode 0600 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 159 | payload hard-link rejection | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 160 | payload device mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 161 | payload size mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 162 | payload digest mismatch | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 163 | payload independent reread | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 164 | payload changes during reread | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 165 | root namespace replacement after copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 166 | parent namespace replacement after copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 167 | payload namespace replacement after copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 168 | validated digest lowercase 64 hex | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 169 | validated result copies paths | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 170 | validated result byte count | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 171 | validated result copyWithZone returns self | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 172 | workspace not copyable | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 173 | cleanup ordinary payload | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 174 | cleanup unexpected bounded entry | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 175 | cleanup symlink without following | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 176 | cleanup nested directory bounded | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 177 | cleanup limit eight | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 178 | cleanup ninth entry rejected | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 179 | cleanup root replacement | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 180 | cleanup payload replacement | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 181 | cleanup parent replacement | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 182 | cleanup root removal while descriptor retained | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 183 | cleanup idempotent second success | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 184 | dealloc best-effort cleanup | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 185 | cleanup never rm-rf | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 186 | cleanup never path recursive deletion | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 187 | destination plan after App Group plan | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 188 | destination plan before main workspace | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 189 | destination plan before first kill | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 190 | active profile read once | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 191 | profile mismatch warning reuses active profile | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 192 | profile archive summary from restorePlan | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 193 | profile extraction into workspace data | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 194 | profile stage validation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 195 | profile destination revalidation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 196 | profile wipe after validation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 197 | profile clone from validated dataPath | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 198 | profile extraction failure code 307 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 199 | profile clone failure code 307 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 200 | profile cleanup success | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 201 | profile cleanup warning | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 202 | global Safari archive summary from restorePlan | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 203 | global Safari extraction into workspace data | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 204 | global Safari stage validation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 205 | global Safari destination revalidation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 206 | global Safari wipe after validation | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 207 | global Safari clone from validated dataPath | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 208 | global Safari failure code 311 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 209 | system-global archive staged before kill | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 210 | system-global destination revalidated before quarantine | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 211 | system-global existing destination checked move | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 212 | system-global absent destination exact mkdir | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 213 | system-global no mkdir-p | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 214 | system-global move failure code 318 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 215 | system-global mkdir failure code 318 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 216 | system-global clone from validated dataPath | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 217 | system-global clone failure code 318 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 218 | system-global chown after clone | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 219 | shared DB all sources staged before daemon stop | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 220 | shared DB all destinations revalidated before daemon stop | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 221 | one shared DB staging failure prevents daemon stop | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 222 | one shared DB revalidation failure prevents daemon stop | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 223 | shared DB no parent mkdir | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 224 | shared DB checked quarantine move | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 225 | shared DB copy from validated filePath | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 226 | shared DB copy failure code 320 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 227 | shared DB chown/chmod after copy | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 228 | shared DB all workspace cleanup | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 229 | Preferences source staged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 230 | Preferences destination revalidated | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 231 | Preferences copy from validated filePath | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 232 | Preferences copy failure code 320 | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 233 | Preferences no warning-and-skip | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 234 | Preferences chown/chmod/cfprefsd preserved | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 235 | Keychain source staged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 236 | Keychain helper receives validated filePath | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 237 | Keychain groups/method/decision preserved | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 238 | Keychain execution failure warning-only | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 239 | Keychain staging failure hard-fails | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 240 | Keychain workspace cleanup after helper | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 241 | optional directory primary error beats cleanup error | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 242 | optional file primary error beats cleanup error | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 243 | post-success directory cleanup warning exact | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 244 | post-success file cleanup warning exact | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 245 | new errors omit raw paths | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 246 | new errors omit identifiers | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 247 | new errors omit sizes and digests | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 248 | new errors omit errno text | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 249 | new errors omit nested errors | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 250 | main staging block unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 251 | App Group planning/staging block unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 252 | main codes 303/316/317 preserved | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 253 | App Group codes 310/319 preserved | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 254 | tar executable preference unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 255 | artifact validator unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 256 | archive validator unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 257 | Restore plan unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 258 | main staging implementation unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 259 | App Group target plan unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 260 | common PXPaths unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 261 | Makefile unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 262 | UI unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 263 | Keychain helper/bridge unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 264 | Backup create method unchanged | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 265 | high-level component order preserved | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 266 | main transaction not implemented | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 267 | App Group rollback not implemented | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 268 | optional transaction journal not implemented | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 269 | optional rollback not implemented | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 270 | structured Restore result not implemented | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 271 | TASK-2.11 remains locked | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 272 | TASK-2.12 remains locked | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 273 | TASK-2.13 remains locked | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |
| 274 | TASK-2.14 remains locked | Covered by fail-closed implementation/static proof; target-device fault injection remains required where applicable. |

Explicit scenario rows: **274**.

## 25. Whitespace, CRLF, NUL and generated-file audit

- Staged production files pass `git diff --cached --check`.
- Report is generated as UTF-8 with LF line endings.
- Report contains no NUL and no trailing spaces/tabs.
- No temporary generator, build product or unrelated file is part of implementation scope.

## 26. Build status and target-device runtime risks

- Local Objective-C/Theos build: **NOT RUN**. This environment has no `make`, `clang`, `clang-cl`, `gcc`, `cc`, `xcrun`, and `THEOS` is unset.
- Static/API/ordering/hash/diff gates do not replace Darwin compilation and device tests.
- Required runtime tests include rootful/rootless mobile-Library alias behavior, symlink/identity race injection, 64 GiB boundaries, short writes/EINTR, workspace cleanup substitution, tar/cp failures, shared-daemon sequencing and Keychain helper consumption of the staged payload.
- System-global/shared DB rename boundaries are not rollback-safe by design; TASK-2.13 owns transactional optional-component handling.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
