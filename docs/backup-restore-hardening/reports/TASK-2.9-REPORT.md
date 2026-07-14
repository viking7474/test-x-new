# TASK-2.9 Implementation Report — Stage and Validate App Group Restore Targets

## 1. Baseline and exact scope

- Required baseline: `9aaa575c7ce0e62aeb155c459879043e1ea5acfb`.
- Task-start HEAD: `9aaa575c7ce0e62aeb155c459879043e1ea5acfb` (MATCH).
- TASK-2.8 source review status supplied by the coordinator: ACCEPTED.
- Production changes are limited to `PXAppGroupRestoreTargetPlan.h`, `PXAppGroupRestoreTargetPlan.m`, and `AppDataBackupManager.m`.
- The implementation commit adds this report as the fourth and final allowed file.
- Pre-existing coordinator/review/task working-tree changes were not edited, staged or included.

Task-start evidence:

```text
$ git status --short --untracked-files=all
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? .task29_report_gen.py
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
?? docs/backup-restore-hardening/reviews/TASK-2.8-REVIEW.md
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
?? docs/backup-restore-hardening/tasks/TASK-2.9-stage-and-validate-app-groups.md
$ git rev-parse HEAD
9aaa575c7ce0e62aeb155c459879043e1ea5acfb
$ git log -3 --oneline
9aaa575 phase2(task-2.8): stage and validate main data
d9ab901 phase2(task-2.7): build immutable restore plan
2bb8473 phase2(task-2.6A): fix archive validator compatibility and bounds
```

## 2. Protected production SHA-256 evidence

Hashes use canonical Git blob bytes from the required baseline and the staged index. Checkout CRLF conversion cannot change this comparison.

| Protected production file | Baseline SHA-256 | Staged SHA-256 | Result |
|---|---|---|---|
| `AppDataBackupManager.h` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | `454d4bad481ce4b11c0e361e1144a5226aa4fe51d0530ce9f4e4603ecc39c3f5` | MATCH |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | MATCH |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | MATCH |
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

Protected canonical blobs: **77/77 MATCH**.

## 3. Exact public API and nine-code enum

- Header matches the specification block byte-for-byte after LF normalization: **TRUE**.
- Exactly one error-domain export and one field-path export.
- Exactly nine public error codes with values 1 through 9.
- Exactly one immutable target class and one immutable target-plan class.
- Exactly one public factory and one exact group-ID lookup method.
- No public initializer, mutable setter, staging API, transaction API, manifest argument or raw destination-path argument.

```objc
#import <Foundation/Foundation.h>

@class PXRestorePlan;
@class PXRestorePlanAppGroupItem;
@class PXResolvedContainer;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorDomain;
FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXAppGroupRestoreTargetPlanErrorCode) {
    PXAppGroupRestoreTargetPlanErrorInvalidInput = 1,
    PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet = 2,
    PXAppGroupRestoreTargetPlanErrorUnentitledGroup = 3,
    PXAppGroupRestoreTargetPlanErrorResolverFailed = 4,
    PXAppGroupRestoreTargetPlanErrorValidatorFailed = 5,
    PXAppGroupRestoreTargetPlanErrorMissingTarget = 6,
    PXAppGroupRestoreTargetPlanErrorAmbiguousTarget = 7,
    PXAppGroupRestoreTargetPlanErrorInconsistentPlan = 8,
    PXAppGroupRestoreTargetPlanErrorLimitExceeded = 9,
};

__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTarget : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSArray<NSString *> *groupIdentifiers;
@property (nonatomic, copy, readonly) NSArray<PXResolvedContainer *> *containerModels;
@property (nonatomic, copy, readonly) NSString *canonicalPath;
@property (nonatomic, copy, readonly) NSArray<PXRestorePlanAppGroupItem *> *planItems;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTargetPlan : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSArray<PXAppGroupRestoreTarget *> *targets;

+ (nullable instancetype)targetPlanForRestorePlan:(PXRestorePlan *)restorePlan
                         entitledGroupIdentifiers:(NSArray<NSString *> *)entitledGroupIdentifiers
                                            error:(NSError * _Nullable * _Nullable)error;

- (nullable PXAppGroupRestoreTarget *)targetForGroupIdentifier:(NSString *)groupIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```

## 4. Immutability and lookup proof

- Both public classes are subclassing-restricted and implement `NSCopying` by returning `self`.
- Target constructor inputs are copied into immutable arrays/strings.
- The plan copies its target array and exact case-sensitive lookup dictionary.
- Mutable builder collections exist only during factory execution and are not retained by public values.
- The entitlement input is converted into copied exact set members; the input array is not retained by mutable alias.
- Lookup rejects nil, non-string, empty, unknown and case-mismatching values.

## 5. Signed entitlement validation

- Restore reads signed App Group entitlements exactly once only when the accepted plan includes at least one App Group item.
- Read failure, nil result or non-array result is a hard target-plan-domain `InvalidEntitlementSet` failure at `$.entitlements`.
- The manager copies the entitlement array before the single factory call.
- Planner validation requires every entitlement to be a runtime string, nonempty, contain non-whitespace text, contain no NUL and be unique by exact value.
- Planned identifiers require exact case-sensitive membership. No trimming, lowercasing, normalization, prefix, suffix or substring matching is performed.
- Extra entitled groups are ignored and do not create targets.

## 6. Fixed limits and overflow boundaries

| Limit | Exact value | Enforcement |
|---|---:|---|
| Planned App Group items | 256 | Checked before planner allocations/iteration |
| Entitlement identifiers | 4096 | Checked before entitlement set construction |
| Unique physical targets | 256 | Checked before appending a new canonical target builder |

All subsequent capacities and loop counts are bounded by these checks; no configurable limit or unchecked count addition was introduced.

## 7. Typed rootful/rootless resolution matrix

| Rootful result | Rootless result | Planner outcome |
|---|---|---|
| absent, nil error | absent, nil error | `MissingTarget` |
| validated model | absent | accepted rootful model |
| absent | validated model | accepted rootless model |
| validated path A | validated path A | one logical destination; models retained rootful then rootless |
| validated path A | validated path B | `AmbiguousTarget` |
| resolver error | not continued | `ResolverFailed` |
| successful rootful result | rootless resolver error | `ResolverFailed` |
| validator error or nil path | any | `ValidatorFailed` |

The planner contains two typed call sites in strict rootful/rootless source order and zero calls to `resolveGroupContainersForGroupIDs:`.

## 8. Canonical path authority and shared-target collapse

- Every non-nil resolved model is passed to `PXDestructivePathValidator`.
- Only the validator-returned nonempty canonical string becomes a grouping key or target destination.
- Exact canonical-path equality collapses several planned group identifiers into one physical target.
- Target order follows first plan-item occurrence; identifiers and plan items preserve Restore-plan order; models preserve rootful/rootless order for each identifier.
- Every associated identifier maps to the same immutable target object.
- Archive compatibility is deliberately not decided in the planner.

## 9. Error privacy

- Planner `userInfo` is constructed in one helper and contains only `NSLocalizedDescriptionKey` and the stable field-path key.
- Planner errors do not expose group values, paths, UUIDs, archive names, entitlement values, nested resolver/validator errors, metadata, device or inode values.
- Manager code 319, extraction code 310 and clone code 310 use exact generic descriptions without nested or path data.

## 10. Manager target-plan ordering

| Ordering assertion | Result |
|---|---|
| target plan after tar selection | PASS |
| target plan before main workspace | PASS |
| target plan before first process kill | PASS |

The previous entitlement warning-and-continue block was removed. Target-plan failure returns before main workspace creation, the first process kill and all target mutation.

## 11. Legacy Restore authority removal

| Restore-only token/call | Count after TASK-2.9 |
|---|---:|
| Restore legacy aggregate resolver calls | 0 |
| Restore AppGroupContainerInfo references | 0 |
| Restore groupContainers references | 0 |
| Restore info.path references | 0 |
| Restore info.uuid references | 0 |
| Restore missing-mapping warning strings | 0 |

The legacy resolver API and `AppGroupContainerInfo` implementation remain byte-identical for Backup and unrelated callers.

## 12. Per-source workspace lifecycle and summary binding

For each physical target, all accepted member-count and regular-file-byte summaries are validated before the first workspace is created. Each plan item then follows:

```text
plan item archiveName/sourcePath
-> restorePlan.validatedArchives summary maps
-> exact unsigned-integral validation
-> PXMainDataStagingWorkspace create
-> empty-directory validation
-> _tarExtract into currentGroupWorkspace.dataPath
-> require zero exit
-> complete staged-tree validation
-> validated result only
```

No manifest reread, backup-directory reconstruction or direct archive extraction into an App Group target remains.

## 13. Shared-source equivalence

The first successfully validated workspace/stage is retained. Every later source for the same physical target must match exactly on:

- `treeSHA256`
- `entryCount`
- `regularFileCount`
- `directoryCount`
- `regularFileBytes`

Equivalent duplicates are cleaned immediately. Any mismatch cleans current and retained workspaces best effort and fails with target-plan `InconsistentPlan` at `$.appGroups` before wipe.

## 14. Immediate target revalidation and one physical wipe

- After every source is staged and proven equivalent, every retained container model is revalidated by `PXDestructivePathValidator`.
- Every output must be nonempty and exact-equal to the stored canonical path; the stored path is never replaced.
- Failure cleans staging and returns `PXBackupErrorDomain`, code 319, with the exact generic description.
- The canonical target is wiped through exactly one source call per physical target loop.
- Clone authority is only the retained validated stage path, using tar-pipe xattr/ACL behavior with the existing system-tar cp preference and fallback policy.
- Complete clone failure cleans staging and returns code 310 with `Failed to restore validated App Group stage`.
- Chown occurs only after clone success.

## 15. Cleanup path inventory

| Path | Current workspace | Retained workspace | Primary result |
|---|---|---|---|
| Workspace creation failure | none | best-effort cleanup | exact staging error |
| Empty validation failure | best-effort cleanup | best-effort cleanup | exact staging error |
| Extraction failure | best-effort cleanup | best-effort cleanup | manager code 310 generic |
| Stage validation failure | best-effort cleanup | best-effort cleanup | exact staging error |
| Shared-source conflict | best-effort cleanup | best-effort cleanup | target-plan `InconsistentPlan` |
| Duplicate cleanup failure | cleanup attempted | best-effort cleanup | exact cleanup error/fallback |
| Target revalidation failure | n/a | best-effort cleanup | manager code 319 generic |
| Tar-pipe plus cp failure | n/a | best-effort cleanup | manager code 310 generic |
| Successful clone | n/a | explicit cleanup | warning only if cleanup fails |

Cleanup failure never replaces an already selected primary failure. Post-clone cleanup failure adds exactly `App Group staging cleanup failed`.

## 16. TASK-2.8 and prior-task non-regression

- TASK-2.8 main staging integration block is byte-semantically identical: `87d909db504202353e0d0a42aa0ad994c2c5fd20cce9fbcb649a9bf819a021ff` before and after.
- `PXMainDataStaging.h/.m` are protected and byte-identical.
- Main workspace creation, empty gate, stage validation, first-kill ordering, target revalidation, clone authority, cleanup and codes 303/316/317 are unchanged.
- Manifest/version/bundle gates, exact ApplicationData destination, artifact/archive validation and immutable Restore plan remain protected.
- Profile/global/system/shared DB/Preferences/Keychain, Backup, UI and Makefile are unchanged.

Required manager body hashes:

| Body | Baseline SHA-256 | Staged SHA-256 | Result |
|---|---|---|---|
| `PXReadUnsignedIntegralSummaryNumber` | `aedeba9015bb2d819f8d3dc96b64847ce8e98f66ef364e64d9e3ab478d968e54` | `aedeba9015bb2d819f8d3dc96b64847ce8e98f66ef364e64d9e3ab478d968e54` | MATCH |
| `PXBackupManifestVersionIsSupported` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | `344f596cb0a11dbe33f63fc669031316ef026d62800a46a5d18933d8864049c7` | MATCH |
| `PXResolveExactRestoreApplicationDataTarget` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | `b45578f6faa98f61c63f330dfe3cb01a3087422732ee069fe3c2e0f2401bed40` | MATCH |
| `readManifestAtBackupDirectory:error:` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | `f8db0debaa47e24f30fa687857787bfd7152175dc1be7f1870c40fd2d31550ff` | MATCH |
| `createBackupForBundleID:appName:options:completion:` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | `d1650f7c33b9a692edba5d559f279f664cef2a92514f94eb4a33ebf2617edede` | MATCH |
| `_tarExtract:archive:toDir:` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | `acaf6d24ced9fe497b6aea31208c62b690a801430364204ff7f61936c400774a` | MATCH |
| `_tarExtractDataArchive:archive:toDir:warnings:` | `b8a35a36213f74090fff16c3ca368392cc3807b6a649ad1dc5491660dde274ac` | `b8a35a36213f74090fff16c3ca368392cc3807b6a649ad1dc5491660dde274ac` | MATCH |

## 17. Later-task boundaries

- No profile, global Safari, system-global, shared DB, Preferences or Keychain staging was added; TASK-2.10 remains locked.
- No App Group quarantine, transaction journal, rename/swap or rollback was added; TASK-2.12 remains responsible.
- No structured Restore result, UI change or Backup publication change was added.

## 18. Static and forbidden counts

| Gate | Actual | Expected | Result |
|---|---:|---:|---|
| error-domain exports | 1 | 1 | PASS |
| field-path exports | 1 | 1 | PASS |
| public error codes | 9 | 9 | PASS |
| objc_subclassing_restricted classes | 2 | 2 | PASS |
| public factory declarations | 1 | 1 | PASS |
| public lookup declarations | 1 | 1 | PASS |
| public readwrite properties | 0 | 0 | PASS |
| copyWithZone implementations | 2 | 2 | PASS |
| planner typed resolver call sites | 2 | 2 | PASS |
| planner rootful call sites | 1 | 1 | PASS |
| planner rootless call sites | 1 | 1 | PASS |
| planner validator call sites | 2 | 2 | PASS |
| planner legacy aggregate resolver calls | 0 | 0 | PASS |
| manager planner imports | 1 | 1 | PASS |
| Restore signed entitlement reads | 1 | 1 | PASS |
| Restore target-plan factory calls | 1 | 1 | PASS |
| Restore legacy aggregate resolver calls | 0 | 0 | PASS |
| Restore AppGroupContainerInfo references | 0 | 0 | PASS |
| Restore groupContainers references | 0 | 0 | PASS |
| Restore info.path references | 0 | 0 | PASS |
| Restore info.uuid references | 0 | 0 | PASS |
| Restore missing-mapping warning strings | 0 | 0 | PASS |
| App Group target loops | 1 | 1 | PASS |
| App Group summary member-map references | 1 | 1 | PASS |
| App Group summary byte-map references | 1 | 1 | PASS |
| App Group workspace creation call sites | 1 | 1 | PASS |
| App Group empty validation call sites | 1 | 1 | PASS |
| App Group stage validation call sites | 1 | 1 | PASS |
| App Group extraction workspace.dataPath references | 1 | 1 | PASS |
| App Group validated clone dataPath references | 2 | 2 | PASS |
| App Group canonical wipe call sites | 1 | 1 | PASS |
| App Group code 319 sites | 1 | 1 | PASS |
| App Group extraction generic message | 1 | 1 | PASS |
| App Group clone generic message | 1 | 1 | PASS |
| App Group cleanup warning exact | 1 | 1 | PASS |
| post-plan direct manifest reads | 0 | 0 | PASS |
| post-plan verifiedArtifacts local lookups | 0 | 0 | PASS |
| post-plan validatedArchives local contains calls | 0 | 0 | PASS |

Planner imports:

```text
#import "PXAppGroupRestoreTargetPlan.h"
#import "PXRestorePlan.h"
#import "PXResolvedContainer.h"
#import "AppGroupContainerResolver.h"
#import "PXDestructivePathValidator.h"
```

| Forbidden planner token | Count |
|---|---:|
| `UIKit` | 0 |
| `AppDataBackupManager` | 0 |
| `AppDataCleaner` | 0 |
| `AppEntitlementsReader` | 0 |
| `PXMainDataStaging` | 0 |
| `PXBackupArtifactVerifier` | 0 |
| `PXBackupArchiveValidator` | 0 |
| `CommandRunner` | 0 |
| `NSTask` | 0 |
| `posix_spawn` | 0 |
| `system(` | 0 |
| `popen(` | 0 |
| `dispatch_` | 0 |
| `Security` | 0 |
| `SecItem` | 0 |
| `NSUserDefaults` | 0 |
| `NSFileManager` | 0 |
| `removeItemAtPath` | 0 |
| `createDirectoryAtPath` | 0 |
| `writeToFile` | 0 |
| `NSLog` | 0 |
| `os_log` | 0 |
| `resolveGroupContainersForGroupIDs:` | 0 |

Static/API/ordering gate: **PASS**. Protected canonical blobs: **77/77**.

## 19. Full production source diff

The complete staged production diff is reproduced below. Report-only trailing horizontal whitespace is normalized so the report itself remains whitespace-clean.

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index fc411f5..ec1ce72 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -13,6 +13,7 @@
 #import "PXBackupArtifactVerifier.h"
 #import "PXBackupArchiveValidator.h"
 #import "PXRestorePlan.h"
+#import "PXAppGroupRestoreTargetPlan.h"
 #import "PXMainDataStaging.h"
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
@@ -67,6 +68,19 @@ static BOOL PXReadUnsignedIntegralSummaryNumber(id value,
     return YES;
 }

+static BOOL PXValidatedMainDataStagesAreEquivalent(PXValidatedMainDataStage *left,
+                                                    PXValidatedMainDataStage *right) {
+    if (![left isKindOfClass:[PXValidatedMainDataStage class]] ||
+        ![right isKindOfClass:[PXValidatedMainDataStage class]]) {
+        return NO;
+    }
+    return [left.treeSHA256 isEqualToString:right.treeSHA256] &&
+           left.entryCount == right.entryCount &&
+           left.regularFileCount == right.regularFileCount &&
+           left.directoryCount == right.directoryCount &&
+           left.regularFileBytes == right.regularFileBytes;
+}
+
 static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
     if (![version isKindOfClass:[NSNumber class]]) {
         return NO;
@@ -2025,6 +2039,44 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"tarPath=%@", tarPath]);

+        NSArray<NSString *> *entitledGroupIdentifiers = @[];
+        if (restorePlan.includesAppGroups && restorePlan.appGroupItems.count > 0) {
+            NSError *entitlementReadError = nil;
+            AppEntitlementsReader *entitlementReader = [[AppEntitlementsReader alloc] init];
+            id entitlementResult =
+                [entitlementReader applicationGroupsForBundleID:bundleID
+                                                           error:&entitlementReadError];
+            if (entitlementReadError || ![entitlementResult isKindOfClass:[NSArray class]]) {
+                NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
+                                                   code:PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet
+                                               userInfo:@{
+                                                   NSLocalizedDescriptionKey: @"The signed App Group entitlement set could not be read safely.",
+                                                   PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.entitlements"
+                                               }];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+            entitledGroupIdentifiers = [(NSArray *)entitlementResult copy];
+        }
+
+        NSError *appGroupTargetPlanError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXAppGroupRestoreTargetPlan *appGroupTargetPlan =
+            [PXAppGroupRestoreTargetPlan targetPlanForRestorePlan:restorePlan
+                                         entitledGroupIdentifiers:entitledGroupIdentifiers
+                                                            error:&appGroupTargetPlanError];
+        if (!appGroupTargetPlan) {
+            NSError *err = appGroupTargetPlanError ?:
+                [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
+                                    code:PXAppGroupRestoreTargetPlanErrorInvalidInput
+                                userInfo:@{
+                                    NSLocalizedDescriptionKey: @"The App Group restore target plan could not be constructed.",
+                                    PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$"
+                                }];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
         if (restorePlan.manifestWarningCount > 0) {
             [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)restorePlan.manifestWarningCount]];
         }
@@ -2041,21 +2093,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         PXDebugRun(runner, debugPre, @"du data", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
         PXDebugRun(runner, debugPre, @"ls prefs", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library/Preferences"]) ]);

-        // App Groups via entitlements (Option B)
-        NSArray<AppGroupContainerInfo *> *groupContainers = @[];
-        if (restorePlan.includesAppGroups) {
-            NSError *entErr = nil;
-            AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
-            NSArray<NSString *> *groupIDs = [reader applicationGroupsForBundleID:bundleID error:&entErr];
-            if (entErr) {
-                [warnings addObject:[NSString stringWithFormat:@"Entitlements read failed: %@", entErr.localizedDescription]];
-            }
-            if (groupIDs.count) {
-                AppGroupContainerResolver *resolver = [[AppGroupContainerResolver alloc] init];
-                groupContainers = [resolver resolveGroupContainersForGroupIDs:groupIDs];
-            }
-        }
-
         NSString *dataArchiveName = restorePlan.dataArchiveName;
         NSString *dataArchive = restorePlan.dataArchivePath;
         NSNumber *logicalMemberSummary =
@@ -2294,35 +2331,260 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             }
         }

-        // Wipe and restore each group
-        for (AppGroupContainerInfo *info in groupContainers) {
-            PXRestorePlanAppGroupItem *plannedGroup =
-                [restorePlan appGroupItemForIdentifier:info.groupID];
-            NSString *archivePath = plannedGroup.sourcePath;
-            if (!plannedGroup || !archivePath.length) {
-                [warnings addObject:[NSString stringWithFormat:@"Missing manifest archive mapping for %@", info.groupID]];
-                continue;
+        // Restore each exact physical App Group target from validated staged content.
+        NSUInteger appGroupTargetIndex = 0;
+        for (PXAppGroupRestoreTarget *target in appGroupTargetPlan.targets) {
+            appGroupTargetIndex++;
+            __attribute__((objc_precise_lifetime))
+            PXMainDataStagingWorkspace *retainedGroupWorkspace = nil;
+            __attribute__((objc_precise_lifetime))
+            PXValidatedMainDataStage *retainedGroupStage = nil;
+
+            NSMutableArray<NSNumber *> *targetMemberCounts =
+                [NSMutableArray arrayWithCapacity:target.planItems.count];
+            NSMutableArray<NSNumber *> *targetRegularFileBytes =
+                [NSMutableArray arrayWithCapacity:target.planItems.count];
+            for (PXRestorePlanAppGroupItem *plannedItem in target.planItems) {
+                NSString *archiveName = plannedItem.archiveName;
+                NSNumber *memberCountSummary =
+                    restorePlan.validatedArchives.memberCountsByArchiveName[archiveName];
+                NSNumber *regularByteSummary =
+                    restorePlan.validatedArchives.regularFileBytesByArchiveName[archiveName];
+                unsigned long long memberCountValue = 0;
+                unsigned long long regularByteValue = 0;
+                if (!PXReadUnsignedIntegralSummaryNumber(memberCountSummary, &memberCountValue) ||
+                    !PXReadUnsignedIntegralSummaryNumber(regularByteSummary, &regularByteValue) ||
+                    memberCountValue > NSUIntegerMax) {
+                    NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
+                                                       code:PXAppGroupRestoreTargetPlanErrorInconsistentPlan
+                                                   userInfo:@{
+                                                       NSLocalizedDescriptionKey: @"The accepted App Group archive summary is inconsistent.",
+                                                       PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
+                                                   }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+                [targetMemberCounts addObject:@(memberCountValue)];
+                [targetRegularFileBytes addObject:@(regularByteValue)];
+            }
+
+            for (NSUInteger sourceIndex = 0; sourceIndex < target.planItems.count; sourceIndex++) {
+                PXRestorePlanAppGroupItem *plannedItem = target.planItems[sourceIndex];
+                NSString *archivePath = plannedItem.sourcePath;
+                NSUInteger memberCountValue =
+                    (NSUInteger)[targetMemberCounts[sourceIndex] unsignedLongLongValue];
+                unsigned long long regularByteValue =
+                    [targetRegularFileBytes[sourceIndex] unsignedLongLongValue];
+
+                NSError *workspaceError = nil;
+                __attribute__((objc_precise_lifetime))
+                PXMainDataStagingWorkspace *currentGroupWorkspace =
+                    [PXMainDataStagingWorkspace createWorkspaceWithError:&workspaceError];
+                if (!currentGroupWorkspace) {
+                    [retainedGroupWorkspace cleanupWithError:nil];
+                    NSError *err = workspaceError ?:
+                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                            code:PXMainDataStagingErrorWorkspaceCreationFailed
+                                        userInfo:@{
+                                            NSLocalizedDescriptionKey: @"The private App Group staging workspace could not be created.",
+                                            PXMainDataStagingErrorFieldPathKey: @"$.workspace"
+                                        }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+
+                NSError *emptyError = nil;
+                if (![currentGroupWorkspace validateEmptyDataDirectoryWithError:&emptyError]) {
+                    [currentGroupWorkspace cleanupWithError:nil];
+                    [retainedGroupWorkspace cleanupWithError:nil];
+                    NSError *err = emptyError ?:
+                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                            code:PXMainDataStagingErrorInvalidInput
+                                        userInfo:@{
+                                            NSLocalizedDescriptionKey: @"The private App Group staging workspace failed empty validation.",
+                                            PXMainDataStagingErrorFieldPathKey: @"$.data"
+                                        }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+
+                CommandResult *extractResult =
+                    [self _tarExtract:tarPath
+                              archive:archivePath
+                                toDir:currentGroupWorkspace.dataPath];
+                if (extractResult.exitCode != 0) {
+                    [currentGroupWorkspace cleanupWithError:nil];
+                    [retainedGroupWorkspace cleanupWithError:nil];
+                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                       code:310
+                                                   userInfo:@{
+                                                       NSLocalizedDescriptionKey: @"Failed to extract App Group archive to staging"
+                                                   }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+
+                NSError *validationError = nil;
+                __attribute__((objc_precise_lifetime))
+                PXValidatedMainDataStage *currentGroupStage =
+                    [currentGroupWorkspace validatedStageWithExpectedLogicalMemberCount:memberCountValue
+                                                                 expectedRegularFileBytes:regularByteValue
+                                                                                     error:&validationError];
+                if (!currentGroupStage) {
+                    [currentGroupWorkspace cleanupWithError:nil];
+                    [retainedGroupWorkspace cleanupWithError:nil];
+                    NSError *err = validationError ?:
+                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                            code:PXMainDataStagingErrorInvalidInput
+                                        userInfo:@{
+                                            NSLocalizedDescriptionKey: @"The extracted App Group stage failed validation.",
+                                            PXMainDataStagingErrorFieldPathKey: @"$.data"
+                                        }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+
+                if (!retainedGroupWorkspace) {
+                    retainedGroupWorkspace = currentGroupWorkspace;
+                    retainedGroupStage = currentGroupStage;
+                    continue;
+                }
+
+                if (!PXValidatedMainDataStagesAreEquivalent(retainedGroupStage, currentGroupStage)) {
+                    [currentGroupWorkspace cleanupWithError:nil];
+                    [retainedGroupWorkspace cleanupWithError:nil];
+                    NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
+                                                       code:PXAppGroupRestoreTargetPlanErrorInconsistentPlan
+                                                   userInfo:@{
+                                                       NSLocalizedDescriptionKey: @"App Group archives for one physical target are inconsistent.",
+                                                       PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
+                                                   }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+
+                NSError *duplicateCleanupError = nil;
+                if (![currentGroupWorkspace cleanupWithError:&duplicateCleanupError]) {
+                    [retainedGroupWorkspace cleanupWithError:nil];
+                    NSError *err = duplicateCleanupError ?:
+                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
+                                            code:PXMainDataStagingErrorCleanupFailed
+                                        userInfo:@{
+                                            NSLocalizedDescriptionKey: @"A duplicate App Group staging workspace could not be cleaned safely.",
+                                            PXMainDataStagingErrorFieldPathKey: @"$.workspace"
+                                        }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
             }

-            // Debug: group state before wipe
-            PXDebugHeader(debugPre, [NSString stringWithFormat:@"Group Restore: %@", info.groupID ?: @""]);
-            PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"groupPath=%@", info.path ?: @""]);
-            PXDebugRun(runner, debugPre, @"ls group (before)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(info.path)]);
-            [self _wipeDirectoryContents:info.path];
-            PXDebugRun(runner, debugPre, @"ls group (after wipe)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(info.path)]);
+            if (!retainedGroupWorkspace || !retainedGroupStage || target.planItems.count == 0) {
+                [retainedGroupWorkspace cleanupWithError:nil];
+                NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
+                                                   code:PXAppGroupRestoreTargetPlanErrorInconsistentPlan
+                                               userInfo:@{
+                                                   NSLocalizedDescriptionKey: @"The accepted App Group restore target has no validated source.",
+                                                   PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
+                                               }];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }

-            CommandResult *r = [self _tarExtract:tarPath archive:archivePath toDir:info.path];
-            if (r.exitCode != 0) {
-                NSString *msg = r.stderrString.length ? r.stderrString : [NSString stringWithFormat:@"Failed to extract group %@", info.groupID];
+            BOOL targetRevalidated = target.canonicalPath.length > 0 && target.containerModels.count > 0;
+            PXDestructivePathValidator *groupTargetValidator = [[PXDestructivePathValidator alloc] init];
+            for (PXResolvedContainer *containerModel in target.containerModels) {
+                NSError *targetValidationError = nil;
+                NSString *revalidatedCanonicalPath =
+                    [groupTargetValidator validatedCanonicalPathForContainer:containerModel
+                                                                       error:&targetValidationError];
+                if (targetValidationError ||
+                    revalidatedCanonicalPath.length == 0 ||
+                    ![revalidatedCanonicalPath isEqualToString:target.canonicalPath]) {
+                    targetRevalidated = NO;
+                    break;
+                }
+            }
+            if (!targetRevalidated) {
+                [retainedGroupWorkspace cleanupWithError:nil];
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
-                                                   code:310
-                                               userInfo:@{NSLocalizedDescriptionKey: msg}];
+                                                   code:319
+                                               userInfo:@{
+                                                   NSLocalizedDescriptionKey: @"Exact App Group restore target could not be revalidated safely"
+                                               }];
                 dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                 return;
             }

-            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true", PXShellQuote(info.path)]];
-            PXDebugRun(runner, debugPost, @"ls group (after extract)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(info.path)]);
+            PXDebugHeader(debugPre, @"App Group Restore (Validated Stage -> Target)");
+            PXDebugAppendLine(debugPre,
+                              [NSString stringWithFormat:@"appGroupTargetIndex=%lu targetCount=%lu",
+                               (unsigned long)appGroupTargetIndex,
+                               (unsigned long)appGroupTargetPlan.targets.count]);
+            PXDebugAppendLine(debugPre,
+                              [NSString stringWithFormat:@"appGroupStagedEntryCount=%lu",
+                               (unsigned long)retainedGroupStage.entryCount]);
+
+            NSString *canonicalTargetPath = target.canonicalPath;
+            [self _wipeDirectoryContents:canonicalTargetPath];
+
+            BOOL shouldPreferGroupCpClone =
+                [tarPath isEqualToString:@"/usr/bin/tar"] ||
+                [tarPath isEqualToString:@"/bin/tar"];
+            CommandResult *groupCloneResult = nil;
+            if (!shouldPreferGroupCpClone) {
+                NSString *cloneCommand =
+                    [NSString stringWithFormat:@"%@ --xattrs --acls -cf - -C %@ . | %@ --xattrs --acls -xf - -C %@",
+                     PXShellQuote(tarPath),
+                     PXShellQuote(retainedGroupStage.dataPath),
+                     PXShellQuote(tarPath),
+                     PXShellQuote(canonicalTargetPath)];
+                groupCloneResult = [runner runAndCapture:cloneCommand];
+                PXDebugAppendLine(debugPre,
+                                  [NSString stringWithFormat:@"appGroupTarPipeCloneExit=%d",
+                                   (int)groupCloneResult.exitCode]);
+                if (groupCloneResult.stderrString.length) {
+                    PXDebugAppendLine(debugPre, @"appGroupTarPipeCloneStderrPresent=1");
+                }
+                if (groupCloneResult.exitCode != 0 ||
+                    (groupCloneResult.stderrString.length &&
+                     [groupCloneResult.stderrString containsString:@"XATTR support is not available"])) {
+                    shouldPreferGroupCpClone = YES;
+                }
+            } else {
+                PXDebugAppendLine(debugPre, @"appGroupTarPipeCloneSkipped=1");
+            }
+
+            if (shouldPreferGroupCpClone) {
+                NSString *fallbackCommand =
+                    [NSString stringWithFormat:@"cp -a %@/. %@/ 2>/dev/null",
+                     PXShellQuote(retainedGroupStage.dataPath),
+                     PXShellQuote(canonicalTargetPath)];
+                CommandResult *copyResult = [runner runAndCapture:fallbackCommand];
+                PXDebugAppendLine(debugPre,
+                                  [NSString stringWithFormat:@"appGroupCpCloneExit=%d",
+                                   (int)copyResult.exitCode]);
+                if (copyResult.stderrString.length) {
+                    PXDebugAppendLine(debugPre, @"appGroupCpCloneStderrPresent=1");
+                }
+                if (copyResult.exitCode != 0) {
+                    [retainedGroupWorkspace cleanupWithError:nil];
+                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                       code:310
+                                                   userInfo:@{
+                                                       NSLocalizedDescriptionKey: @"Failed to restore validated App Group stage"
+                                                   }];
+                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    return;
+                }
+            }
+
+            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
+                         PXShellQuote(canonicalTargetPath)]];
+
+            NSError *groupCleanupError = nil;
+            if (![retainedGroupWorkspace cleanupWithError:&groupCleanupError]) {
+                [warnings addObject:@"App Group staging cleanup failed"];
+            }
         }

         // Restore generic system app global Library folders (if present)
diff --git a/PXAppGroupRestoreTargetPlan.h b/PXAppGroupRestoreTargetPlan.h
new file mode 100644
index 0000000..68ba5cf
--- /dev/null
+++ b/PXAppGroupRestoreTargetPlan.h
@@ -0,0 +1,53 @@
+#import <Foundation/Foundation.h>
+
+@class PXRestorePlan;
+@class PXRestorePlanAppGroupItem;
+@class PXResolvedContainer;
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorDomain;
+FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXAppGroupRestoreTargetPlanErrorCode) {
+    PXAppGroupRestoreTargetPlanErrorInvalidInput = 1,
+    PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet = 2,
+    PXAppGroupRestoreTargetPlanErrorUnentitledGroup = 3,
+    PXAppGroupRestoreTargetPlanErrorResolverFailed = 4,
+    PXAppGroupRestoreTargetPlanErrorValidatorFailed = 5,
+    PXAppGroupRestoreTargetPlanErrorMissingTarget = 6,
+    PXAppGroupRestoreTargetPlanErrorAmbiguousTarget = 7,
+    PXAppGroupRestoreTargetPlanErrorInconsistentPlan = 8,
+    PXAppGroupRestoreTargetPlanErrorLimitExceeded = 9,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXAppGroupRestoreTarget : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly) NSArray<NSString *> *groupIdentifiers;
+@property (nonatomic, copy, readonly) NSArray<PXResolvedContainer *> *containerModels;
+@property (nonatomic, copy, readonly) NSString *canonicalPath;
+@property (nonatomic, copy, readonly) NSArray<PXRestorePlanAppGroupItem *> *planItems;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXAppGroupRestoreTargetPlan : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly) NSArray<PXAppGroupRestoreTarget *> *targets;
+
++ (nullable instancetype)targetPlanForRestorePlan:(PXRestorePlan *)restorePlan
+                         entitledGroupIdentifiers:(NSArray<NSString *> *)entitledGroupIdentifiers
+                                            error:(NSError * _Nullable * _Nullable)error;
+
+- (nullable PXAppGroupRestoreTarget *)targetForGroupIdentifier:(NSString *)groupIdentifier;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXAppGroupRestoreTargetPlan.m b/PXAppGroupRestoreTargetPlan.m
new file mode 100644
index 0000000..634c71a
--- /dev/null
+++ b/PXAppGroupRestoreTargetPlan.m
@@ -0,0 +1,360 @@
+#import "PXAppGroupRestoreTargetPlan.h"
+#import "PXRestorePlan.h"
+#import "PXResolvedContainer.h"
+#import "AppGroupContainerResolver.h"
+#import "PXDestructivePathValidator.h"
+
+NSString * const PXAppGroupRestoreTargetPlanErrorDomain =
+    @"com.hydra.projectx.app-group-restore-target-plan";
+NSString * const PXAppGroupRestoreTargetPlanErrorFieldPathKey =
+    @"PXAppGroupRestoreTargetPlanErrorFieldPathKey";
+
+static const NSUInteger PXAppGroupRestoreTargetPlanMaximumPlannedItems = 256;
+static const NSUInteger PXAppGroupRestoreTargetPlanMaximumEntitlements = 4096;
+static const NSUInteger PXAppGroupRestoreTargetPlanMaximumTargets = 256;
+
+static id PXAppGroupRestoreTargetPlanFail(NSError **error,
+                                          PXAppGroupRestoreTargetPlanErrorCode code,
+                                          NSString *fieldPath,
+                                          NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
+                                     code:code
+                                 userInfo:@{
+                                     NSLocalizedDescriptionKey: description,
+                                     PXAppGroupRestoreTargetPlanErrorFieldPathKey: fieldPath
+                                 }];
+    }
+    return nil;
+}
+
+static BOOL PXAppGroupRestoreTargetPlanStringContainsNUL(NSString *value) {
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXAppGroupRestoreTargetPlanStringHasNonWhitespaceText(NSString *value) {
+    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if (![whitespace characterIsMember:[value characterAtIndex:index]]) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXAppGroupRestoreTargetPlanBasicStringIsValid(id value) {
+    return [value isKindOfClass:[NSString class]] &&
+           [(NSString *)value length] > 0 &&
+           !PXAppGroupRestoreTargetPlanStringContainsNUL((NSString *)value);
+}
+
+@interface PXAppGroupRestoreTarget ()
+- (instancetype)initWithGroupIdentifiers:(NSArray<NSString *> *)groupIdentifiers
+                          containerModels:(NSArray<PXResolvedContainer *> *)containerModels
+                            canonicalPath:(NSString *)canonicalPath
+                                planItems:(NSArray<PXRestorePlanAppGroupItem *> *)planItems;
+@end
+
+@implementation PXAppGroupRestoreTarget
+
+- (instancetype)initWithGroupIdentifiers:(NSArray<NSString *> *)groupIdentifiers
+                          containerModels:(NSArray<PXResolvedContainer *> *)containerModels
+                            canonicalPath:(NSString *)canonicalPath
+                                planItems:(NSArray<PXRestorePlanAppGroupItem *> *)planItems {
+    self = [super init];
+    if (self) {
+        _groupIdentifiers = [groupIdentifiers copy];
+        _containerModels = [containerModels copy];
+        _canonicalPath = [canonicalPath copy];
+        _planItems = [planItems copy];
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
+@interface PXAppGroupRestoreTargetPlan ()
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, PXAppGroupRestoreTarget *> *targetByGroupIdentifier;
+- (instancetype)initWithTargets:(NSArray<PXAppGroupRestoreTarget *> *)targets
+       targetByGroupIdentifier:(NSDictionary<NSString *, PXAppGroupRestoreTarget *> *)targetByGroupIdentifier;
+@end
+
+@interface PXAppGroupRestoreTargetBuilder : NSObject
+@property (nonatomic, copy) NSString *canonicalPath;
+@property (nonatomic, strong) NSMutableArray<NSString *> *groupIdentifiers;
+@property (nonatomic, strong) NSMutableArray<PXResolvedContainer *> *containerModels;
+@property (nonatomic, strong) NSMutableArray<PXRestorePlanAppGroupItem *> *planItems;
+@end
+
+@implementation PXAppGroupRestoreTargetBuilder
+@end
+
+@implementation PXAppGroupRestoreTargetPlan
+
+- (instancetype)initWithTargets:(NSArray<PXAppGroupRestoreTarget *> *)targets
+       targetByGroupIdentifier:(NSDictionary<NSString *, PXAppGroupRestoreTarget *> *)targetByGroupIdentifier {
+    self = [super init];
+    if (self) {
+        _targets = [targets copy];
+        _targetByGroupIdentifier = [targetByGroupIdentifier copy];
+    }
+    return self;
+}
+
++ (instancetype)targetPlanForRestorePlan:(PXRestorePlan *)restorePlan
+                entitledGroupIdentifiers:(NSArray<NSString *> *)entitledGroupIdentifiers
+                                   error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    if (![restorePlan isKindOfClass:[PXRestorePlan class]] ||
+        ![entitledGroupIdentifiers isKindOfClass:[NSArray class]]) {
+        return PXAppGroupRestoreTargetPlanFail(error,
+                                               PXAppGroupRestoreTargetPlanErrorInvalidInput,
+                                               @"$",
+                                               @"The App Group restore target-plan input is invalid.");
+    }
+
+    NSArray *planItems = restorePlan.appGroupItems;
+    if (![planItems isKindOfClass:[NSArray class]]) {
+        return PXAppGroupRestoreTargetPlanFail(error,
+                                               PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
+                                               @"$.appGroups",
+                                               @"The accepted App Group restore plan is inconsistent.");
+    }
+    if (!restorePlan.includesAppGroups && planItems.count != 0) {
+        return PXAppGroupRestoreTargetPlanFail(error,
+                                               PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
+                                               @"$.appGroups",
+                                               @"The accepted App Group restore plan is inconsistent.");
+    }
+    if (planItems.count > PXAppGroupRestoreTargetPlanMaximumPlannedItems) {
+        return PXAppGroupRestoreTargetPlanFail(error,
+                                               PXAppGroupRestoreTargetPlanErrorLimitExceeded,
+                                               @"$.appGroups",
+                                               @"The App Group restore target-plan item limit was exceeded.");
+    }
+    if (entitledGroupIdentifiers.count > PXAppGroupRestoreTargetPlanMaximumEntitlements) {
+        return PXAppGroupRestoreTargetPlanFail(error,
+                                               PXAppGroupRestoreTargetPlanErrorLimitExceeded,
+                                               @"$.entitlements",
+                                               @"The signed App Group entitlement limit was exceeded.");
+    }
+
+    NSMutableSet<NSString *> *entitlementSet =
+        [NSMutableSet setWithCapacity:entitledGroupIdentifiers.count];
+    for (NSUInteger index = 0; index < entitledGroupIdentifiers.count; index++) {
+        id candidate = entitledGroupIdentifiers[index];
+        NSString *fieldPath = [NSString stringWithFormat:@"$.entitlements[%lu]",
+                               (unsigned long)index];
+        if (![candidate isKindOfClass:[NSString class]] ||
+            [(NSString *)candidate length] == 0 ||
+            !PXAppGroupRestoreTargetPlanStringHasNonWhitespaceText((NSString *)candidate) ||
+            PXAppGroupRestoreTargetPlanStringContainsNUL((NSString *)candidate) ||
+            [entitlementSet containsObject:(NSString *)candidate]) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet,
+                                                   fieldPath,
+                                                   @"The signed App Group entitlement set is invalid.");
+        }
+        [entitlementSet addObject:[(NSString *)candidate copy]];
+    }
+
+    AppGroupContainerResolver *resolver = [[AppGroupContainerResolver alloc] init];
+    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
+    NSMutableSet<NSString *> *plannedGroupIdentifiers = [NSMutableSet setWithCapacity:planItems.count];
+    NSMutableDictionary<NSString *, PXAppGroupRestoreTargetBuilder *> *builderByCanonicalPath =
+        [NSMutableDictionary dictionaryWithCapacity:planItems.count];
+    NSMutableArray<PXAppGroupRestoreTargetBuilder *> *builderOrder =
+        [NSMutableArray arrayWithCapacity:planItems.count];
+
+    for (NSUInteger index = 0; index < planItems.count; index++) {
+        id candidate = planItems[index];
+        NSString *itemFieldPath = [NSString stringWithFormat:@"$.appGroups[%lu]",
+                                   (unsigned long)index];
+        NSString *identifierFieldPath = [itemFieldPath stringByAppendingString:@".groupIdentifier"];
+        NSString *destinationFieldPath = [itemFieldPath stringByAppendingString:@".destination"];
+
+        if (![candidate isKindOfClass:[PXRestorePlanAppGroupItem class]]) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
+                                                   itemFieldPath,
+                                                   @"The accepted App Group restore plan is inconsistent.");
+        }
+
+        PXRestorePlanAppGroupItem *planItem = (PXRestorePlanAppGroupItem *)candidate;
+        NSString *groupIdentifier = planItem.groupIdentifier;
+        if (!PXAppGroupRestoreTargetPlanBasicStringIsValid(groupIdentifier)) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
+                                                   identifierFieldPath,
+                                                   @"The accepted App Group restore plan is inconsistent.");
+        }
+        if (!PXAppGroupRestoreTargetPlanBasicStringIsValid(planItem.archiveName) ||
+            !PXAppGroupRestoreTargetPlanBasicStringIsValid(planItem.sourcePath)) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
+                                                   itemFieldPath,
+                                                   @"The accepted App Group restore plan is inconsistent.");
+        }
+        if ([plannedGroupIdentifiers containsObject:groupIdentifier]) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
+                                                   identifierFieldPath,
+                                                   @"The accepted App Group restore plan contains a duplicate identity.");
+        }
+        [plannedGroupIdentifiers addObject:[groupIdentifier copy]];
+
+        if (![entitlementSet containsObject:groupIdentifier]) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorUnentitledGroup,
+                                                   identifierFieldPath,
+                                                   @"A planned App Group is not authorized by the signed entitlement set.");
+        }
+
+        NSError *rootfulResolverError = nil;
+        PXResolvedContainer *rootfulModel =
+            [resolver resolveAppGroupContainerForGroupIdentifier:groupIdentifier
+                                                            root:PXResolvedContainerRootRootful
+                                                           error:&rootfulResolverError];
+        if (rootfulResolverError) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorResolverFailed,
+                                                   destinationFieldPath,
+                                                   @"An exact App Group restore target could not be resolved safely.");
+        }
+
+        NSError *rootlessResolverError = nil;
+        PXResolvedContainer *rootlessModel =
+            [resolver resolveAppGroupContainerForGroupIdentifier:groupIdentifier
+                                                            root:PXResolvedContainerRootRootless
+                                                           error:&rootlessResolverError];
+        if (rootlessResolverError) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorResolverFailed,
+                                                   destinationFieldPath,
+                                                   @"An exact App Group restore target could not be resolved safely.");
+        }
+
+        NSMutableArray<PXResolvedContainer *> *models = [NSMutableArray arrayWithCapacity:2];
+        NSMutableArray<NSString *> *canonicalPaths = [NSMutableArray arrayWithCapacity:2];
+        if (rootfulModel) {
+            NSError *validationError = nil;
+            NSString *canonicalPath =
+                [validator validatedCanonicalPathForContainer:rootfulModel error:&validationError];
+            if (validationError ||
+                ![canonicalPath isKindOfClass:[NSString class]] ||
+                canonicalPath.length == 0) {
+                return PXAppGroupRestoreTargetPlanFail(error,
+                                                       PXAppGroupRestoreTargetPlanErrorValidatorFailed,
+                                                       destinationFieldPath,
+                                                       @"An exact App Group restore target failed canonical validation.");
+            }
+            [models addObject:rootfulModel];
+            [canonicalPaths addObject:[canonicalPath copy]];
+        }
+        if (rootlessModel) {
+            NSError *validationError = nil;
+            NSString *canonicalPath =
+                [validator validatedCanonicalPathForContainer:rootlessModel error:&validationError];
+            if (validationError ||
+                ![canonicalPath isKindOfClass:[NSString class]] ||
+                canonicalPath.length == 0) {
+                return PXAppGroupRestoreTargetPlanFail(error,
+                                                       PXAppGroupRestoreTargetPlanErrorValidatorFailed,
+                                                       destinationFieldPath,
+                                                       @"An exact App Group restore target failed canonical validation.");
+            }
+            [models addObject:rootlessModel];
+            [canonicalPaths addObject:[canonicalPath copy]];
+        }
+
+        if (models.count == 0) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorMissingTarget,
+                                                   destinationFieldPath,
+                                                   @"An exact App Group restore target is missing.");
+        }
+
+        NSString *canonicalPath = canonicalPaths.firstObject;
+        if (canonicalPaths.count == 2 &&
+            ![canonicalPaths[0] isEqualToString:canonicalPaths[1]]) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorAmbiguousTarget,
+                                                   destinationFieldPath,
+                                                   @"The exact App Group restore target is ambiguous.");
+        }
+
+        PXAppGroupRestoreTargetBuilder *builder = builderByCanonicalPath[canonicalPath];
+        if (!builder) {
+            if (builderOrder.count >= PXAppGroupRestoreTargetPlanMaximumTargets) {
+                return PXAppGroupRestoreTargetPlanFail(error,
+                                                       PXAppGroupRestoreTargetPlanErrorLimitExceeded,
+                                                       @"$.appGroups",
+                                                       @"The App Group physical-target limit was exceeded.");
+            }
+            builder = [[PXAppGroupRestoreTargetBuilder alloc] init];
+            builder.canonicalPath = [canonicalPath copy];
+            builder.groupIdentifiers = [NSMutableArray array];
+            builder.containerModels = [NSMutableArray array];
+            builder.planItems = [NSMutableArray array];
+            builderByCanonicalPath[builder.canonicalPath] = builder;
+            [builderOrder addObject:builder];
+        }
+
+        [builder.groupIdentifiers addObject:[groupIdentifier copy]];
+        [builder.containerModels addObjectsFromArray:models];
+        [builder.planItems addObject:planItem];
+    }
+
+    NSMutableArray<PXAppGroupRestoreTarget *> *targets =
+        [NSMutableArray arrayWithCapacity:builderOrder.count];
+    NSMutableDictionary<NSString *, PXAppGroupRestoreTarget *> *lookup =
+        [NSMutableDictionary dictionaryWithCapacity:planItems.count];
+
+    for (PXAppGroupRestoreTargetBuilder *builder in builderOrder) {
+        PXAppGroupRestoreTarget *target =
+            [[PXAppGroupRestoreTarget alloc] initWithGroupIdentifiers:builder.groupIdentifiers
+                                                     containerModels:builder.containerModels
+                                                       canonicalPath:builder.canonicalPath
+                                                           planItems:builder.planItems];
+        if (!target) {
+            return PXAppGroupRestoreTargetPlanFail(error,
+                                                   PXAppGroupRestoreTargetPlanErrorInconsistentPlan,
+                                                   @"$.appGroups",
+                                                   @"The App Group restore target plan could not be represented safely.");
+        }
+        [targets addObject:target];
+        for (NSString *groupIdentifier in target.groupIdentifiers) {
+            lookup[groupIdentifier] = target;
+        }
+    }
+
+    return [[PXAppGroupRestoreTargetPlan alloc] initWithTargets:targets
+                                        targetByGroupIdentifier:lookup];
+}
+
+- (PXAppGroupRestoreTarget *)targetForGroupIdentifier:(NSString *)groupIdentifier {
+    if (![groupIdentifier isKindOfClass:[NSString class]] || groupIdentifier.length == 0) {
+        return nil;
+    }
+    return self.targetByGroupIdentifier[groupIdentifier];
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+@end
```

## 20. Explicit scenario matrix

These rows document the required expected behavior and the implementation/static evidence path. Target-device fault injection and boundary-volume execution remain runtime verification work.

| # | Scenario | Expected behavior | Evidence |
|---:|---|---|---|
| 1 | App Groups excluded and empty plan | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 2 | included but empty plan | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 3 | one planned entitled group | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 4 | multiple planned groups preserve plan order | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 5 | entitlement read success | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 6 | entitlement read failure hard-fails | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 7 | entitlement result non-array | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 8 | entitlement nil element | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 9 | entitlement non-string | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 10 | entitlement empty string | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 11 | entitlement whitespace-only | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 12 | entitlement NUL | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 13 | duplicate exact entitlement | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 14 | extra entitled group ignored | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 15 | planned exact entitlement accepted | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 16 | planned case mismatch rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 17 | planned prefix match rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 18 | planned substring match rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 19 | planned unentitled group rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 20 | 256 planned groups accepted | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 21 | 257 planned groups rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 22 | 4096 entitlement IDs accepted | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 23 | 4097 entitlement IDs rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 24 | duplicate plan group rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 25 | invalid plan item rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 26 | invalid plan group ID rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 27 | invalid plan archive rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 28 | invalid plan source rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 29 | rootful absent/rootless absent | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 30 | rootful only accepted | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 31 | rootless only accepted | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 32 | rootful resolver error | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 33 | rootless resolver error | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 34 | rootful validator error | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 35 | rootless validator error | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 36 | rootful/rootless same canonical path collapsed | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 37 | distinct root paths rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 38 | resolver nil without error treated absent | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 39 | validator nil without error rejected | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 40 | root order retained | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 41 | canonical path copied | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 42 | recorded App Group UUID ignored | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 43 | legacy resolver not called | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 44 | AppGroupContainerInfo not used | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 45 | two group IDs same physical target collapsed | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 46 | target first occurrence order retained | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 47 | group identifiers preserve plan order | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 48 | plan items preserve plan order | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 49 | models preserve root order | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 50 | lookup exact ID returns target | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 51 | lookup case mismatch returns nil | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 52 | lookup nil returns nil | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 53 | lookup empty returns nil | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 54 | target strings/arrays copied | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 55 | target copyWithZone returns self | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 56 | plan copyWithZone returns self | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 57 | plan does not retain mutable entitlement alias | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 58 | error clears at entry | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 59 | success error nil | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 60 | error userInfo restricted | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 61 | error omits group ID | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 62 | error omits path | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 63 | error omits UUID | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 64 | error omits nested resolver error | Planner accepts or rejects with the exact typed/error/privacy contract. | Planner API/source inspection; runtime injection pending where applicable. |
| 65 | target plan before main workspace | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 66 | target plan before first kill | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 67 | target plan failure before mutation | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 68 | main staging unchanged | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 69 | one physical target one archive stage | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 70 | workspace creation failure | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 71 | empty stage failure | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 72 | extraction nonzero failure | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 73 | stage validation failure | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 74 | summary missing | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 75 | summary Boolean rejected | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 76 | summary floating rejected | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 77 | summary negative rejected | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 78 | member count overflow rejected | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 79 | exact zero summary accepted when stage empty | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 80 | source from plan item only | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 81 | summary from restorePlan archive set only | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 82 | no manifest reread | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 83 | no backupDir path reconstruction | Failure or acceptance occurs before App Group target mutation with exact summary/staging authority. | Manager ordering/static source inspection; target runtime pending. |
| 84 | first shared-target archive retained | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 85 | second equivalent archive accepted | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 86 | duplicate workspace cleanup | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 87 | equivalent tree digest but count mismatch rejected | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 88 | digest mismatch rejected | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 89 | entry count mismatch rejected | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 90 | regular-file count mismatch rejected | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 91 | directory count mismatch rejected | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 92 | regular-byte mismatch rejected | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 93 | no sequential conflicting archive application | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 94 | conflict before target wipe | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 95 | current workspace cleanup on conflict | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 96 | retained workspace cleanup on conflict | All sources are staged; equivalent content is retained once and conflicts fail before wipe. | Five-field equivalence and cleanup source paths present. |
| 97 | one target model revalidated | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 98 | multiple target models all revalidated | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 99 | one model revalidation error | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 100 | one model canonical mismatch | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 101 | revalidation does not replace stored path | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 102 | revalidation error code 319 | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 103 | revalidation error generic | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 104 | no raw group/path in revalidation error | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 105 | target wipe after stage validation | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 106 | target wiped exactly once | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 107 | shared physical target wiped once | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 108 | clone uses validatedStage.dataPath | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 109 | direct archive extraction to target absent | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 110 | tar-pipe clone success | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 111 | tar-pipe nonzero triggers cp fallback | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 112 | xattr warning triggers cp fallback | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 113 | system tar prefers cp | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 114 | cp fallback success | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 115 | tar and cp failure code 310 | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 116 | clone error generic | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 117 | chown only after clone success | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 118 | cleanup after clone success | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 119 | cleanup failure warning exact | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 120 | no cleanup path in warning | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 121 | extraction failure cleanup | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 122 | validation failure cleanup | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 123 | revalidation failure cleanup | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 124 | clone failure cleanup | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 125 | primary failure not replaced by cleanup failure | Every model revalidates, one wipe occurs, clone uses validated stage and cleanup preserves primary failure. | Manager local-order/static cleanup inspection; runtime failure injection pending. |
| 126 | profile/global remain before App Group commit | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 127 | system-global remains after App Groups | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 128 | main data remains before App Groups | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 129 | later physical target may fail without rollback | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 130 | TASK-2.12 remains unimplemented | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 131 | PXMainDataStaging header unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 132 | PXMainDataStaging source unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 133 | PXRestorePlan unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 134 | manifest validator unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 135 | artifact verifier unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 136 | archive validator unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 137 | typed resolver source unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 138 | destructive validator unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 139 | AppEntitlementsReader unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 140 | legacy resolver remains available outside Restore | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 141 | Backup behavior unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 142 | Makefile unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 143 | UI unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 144 | Keychain unchanged | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 145 | profile staging not implemented | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 146 | global Safari staging not implemented | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 147 | system-global staging not implemented | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 148 | shared DB staging not implemented | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 149 | Preferences staging not implemented | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 150 | target quarantine absent | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 151 | transaction journal absent | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 152 | rollback absent | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 153 | structured result absent | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 154 | no shell/process in planner | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 155 | no filesystem mutation in planner | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 156 | planner fixed limits exact | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 157 | physical-target limit 256 accepted | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 158 | physical-target limit 257 rejected | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 159 | deterministic target ordering | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 160 | TASK-2.10 remains locked | Protected behavior remains unchanged and later-task functionality remains absent. | Protected blob hashes/body hashes/static forbidden counts. |
| 161 | Unicode non-whitespace entitlement retained exactly | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 162 | canonically equivalent Unicode identifiers are not normalized | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 163 | mutable entitlement input changed after factory does not affect plan | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 164 | canonical dictionary key is copied | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 165 | all associated lookup IDs return the same target instance | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 166 | rootful-only model order remains deterministic | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 167 | rootless-only model is retained when rootful is absent | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 168 | rootful resolver failure prevents rootless continuation | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 169 | validator-returned canonical path is the only stored authority | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 170 | empty target plan performs no App Group mutation | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 171 | all archive summaries validate before first App Group workspace | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 172 | duplicate workspace cleanup failure fails before target mutation | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 173 | workspace creation failure after retained source cleans retained source | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 174 | second source extraction failure cleans current and retained workspaces | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 175 | second source validation failure cleans current and retained workspaces | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 176 | digest and all four counters equal accepts shared source | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 177 | empty container-model array fails generic revalidation | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 178 | empty canonical path fails generic revalidation | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 179 | post-clone cleanup emits one exact generic warning | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |
| 180 | TASK-2.10 and TASK-2.12 production behavior remains absent | Boundary/alias/Unicode/cleanup behavior follows exact immutable and fail-closed rules. | Additional source-level coverage; runtime fault injection pending where applicable. |

Explicit scenario rows: **180**.

## 21. Whitespace, CRLF, NUL and generated-artifact audit

- Staged production `git diff --cached --check`: PASS before report generation.
- New public/implementation files are UTF-8 text with LF line endings in the staged Git blobs.
- No NUL bytes are present in the new source or this report.
- No trailing spaces or tabs are emitted by this report generator.
- The report contains the complete normalized production diff and no binary/generated build output.
- The temporary report generator is removed before report staging and commit.

## 22. Build status and remaining runtime risks

Local Objective-C/Theos build: **NOT RUN**. The available Windows workspace has no `make`, `clang`, `clang-cl`, `gcc`, `cc`, `xcrun`, and `THEOS` is not set.

Remaining runtime risks requiring CI or target-device verification:

- Darwin/Foundation Objective-C compilation and deployment-target compatibility.
- Real signed-entitlement reader behavior for malformed or unusual entitlement payloads.
- Rootful/rootless resolver and destructive-validator behavior under concurrent filesystem changes.
- Shared physical target metadata containing multiple exact group identifiers.
- Large 256-item/4096-entitlement boundary execution and memory pressure.
- Tar partial extraction/fallback behavior followed by staged-tree validation.
- Workspace cleanup failure injection, descriptor exhaustion and target replacement races.
- Tar-pipe/cp clone failures after target wipe remain non-transactional by explicit TASK-2.9 boundary.
- A later physical App Group target may fail after an earlier target commits; TASK-2.12 owns rollback.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
