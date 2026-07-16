# TASK-4.9 REPORT - Finalize Keychain Backup Protection Policy

## Result

TASK-4.9 implementation is complete and is ready for source review.

The Keychain backup protection policy is now fail-closed: regular file, one hard link, exact process ownership, exact mode `0600`, Data Protection Complete / protection class A, descriptor verification, and durability are required before an artifact is accepted.

Phase 5 was not started. No custom content encryption, password UI, Secure Enclave key management, bridge protocol redesign, or external-backup migration was implemented.

## User authority

The controlling task specification declares:

- TASK-4.8: PASSED
- TASK-4.8: COMPLETED
- TASK-4.9: READY

This user authority controlled implementation even though coordinator documentation still described TASK-4.9 as locked. Coordinator-owned STATUS, ROADMAP, DECISIONS, and README files were not modified, staged, reset, deleted, or rewritten.

## TASK-4.8 review-file status

`docs/backup-restore-hardening/reviews/TASK-4.8-REVIEW.md` was absent at baseline and remains absent.

This was not treated as a blocker because HEAD matched the required TASK-4.8 implementation baseline, the TASK-4.8 report existed, the TASK-4.8 commit had the expected scope, and user authority explicitly confirmed PASS and COMPLETED. No TASK-4.8 review file was created.

## Baseline

Required and observed baseline: `a8d4b434fe3531b7895fef1712ce8be5507439e0`.

Observed HEAD at S1: `a8d4b43 phase4(task-4.8): integrate structured keychain partial results`.

Initial `git show --check`, exact TASK-4.8 commit manifest, and `git diff --check` passed.

## Exact authorized scope

The implementation commit is restricted to exactly sixteen files:

- `PXFileProtection.h`
- `PXFileProtection.m`
- `PXBackupArtifactPolicy.h`
- `PXBackupArtifactPolicy.m`
- `PXBackupArtifactWriter.h`
- `PXBackupArtifactWriter.m`
- `PXBackupManifestV4.m`
- `PXBackupManifestValidator.m`
- `PXBackupArtifactVerifier.h`
- `PXBackupArtifactVerifier.m`
- `PXBackupDirectoryPublisher.h`
- `PXBackupDirectoryPublisher.m`
- `PXOptionalRestoreStaging.h`
- `PXOptionalRestoreStaging.m`
- `AppDataBackupManager.m`
- `docs/backup-restore-hardening/reports/TASK-4.9-REPORT.md`

`Makefile` must remain byte-identical and the two root-level source files are collected automatically by the existing `$(wildcard *.m)` ProjectX target. They are not added to `backup_helper_FILES`.

## Working-tree preservation

Pre-existing coordinator-owned modified and untracked documentation was preserved and remained unstaged throughout implementation.

No reset, checkout, clean, delete, rename, or broad line-ending normalization was applied to those files.

## Protected hashes and byte sizes

Protected production files: 271.

| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes | Equal |
| --- | --- | ---: | --- | ---: | --- |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | TRUE |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 | TRUE |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 | TRUE |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | TRUE |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | TRUE |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | 1061 | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | 1061 | TRUE |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | 11626 | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | 11626 | TRUE |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | TRUE |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | TRUE |
| `AppVersionManager.h` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | 1295 | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | 1295 | TRUE |
| `AppVersionManager.m` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | 15049 | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | 15049 | TRUE |
| `AppVersionSpoofingViewController.h` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | 678 | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | 678 | TRUE |
| `AppVersionSpoofingViewController.m` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | 85181 | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | 85181 | TRUE |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | TRUE |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | TRUE |
| `BottomButtons.h` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | 849 | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | 849 | TRUE |
| `BottomButtons.m` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | 24605 | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | 24605 | TRUE |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | 1562 | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | 1562 | TRUE |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | 49583 | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | 49583 | TRUE |
| `ContainerManager.h` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | 1109 | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | 1109 | TRUE |
| `ContainerManager.m` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | 4393 | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | 4393 | TRUE |
| `CopyHelper.h` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | 531 | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | 531 | TRUE |
| `CopyHelper.m` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | 6147 | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | 6147 | TRUE |
| `DeviceSpecificSpoofingViewController+EditLabel.h` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | 161 | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | 161 | TRUE |
| `DeviceSpecificSpoofingViewController+EditLabel.m` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | 9198 | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | 9198 | TRUE |
| `DeviceSpecificSpoofingViewController+ProfileManagerDelegate.m` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | 508 | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | 508 | TRUE |
| `DeviceSpecificSpoofingViewController.h` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | 134 | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | 134 | TRUE |
| `DeviceSpecificSpoofingViewController.m` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | 56660 | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | 56660 | TRUE |
| `DevicesViewController.h` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | 1160 | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | 1160 | TRUE |
| `DevicesViewController.m` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | 38275 | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | 38275 | TRUE |
| `DomainManagementViewController.h` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | 112 | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | 112 | TRUE |
| `DomainManagementViewController.m` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | 30905 | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | 30905 | TRUE |
| `DoorDashOrderViewController.h` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | 668 | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | 668 | TRUE |
| `DoorDashOrderViewController.m` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | 37685 | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | 37685 | TRUE |
| `DownloadResourcesViewController.h` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | 96 | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | 96 | TRUE |
| `DownloadResourcesViewController.m` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | 2456 | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | 2456 | TRUE |
| `FileManagerViewController.h` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | 658 | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | 658 | TRUE |
| `FileManagerViewController.m` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | 55902 | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | 55902 | TRUE |
| `FixVersionAppsViewController.h` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | 93 | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | 93 | TRUE |
| `FixVersionAppsViewController.m` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | 7764 | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | 7764 | TRUE |
| `FreezeManager.h` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | 385 | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | 385 | TRUE |
| `FreezeManager.m` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | 8975 | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | 8975 | TRUE |
| `Info.plist` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | 7202 | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | 7202 | TRUE |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | TRUE |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | 4584 | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | 4584 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | 38587 | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | 38587 | TRUE |
| `KeychainHelper/PXKeychainHelperExitCode.h` | `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a` | 784 | `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a` | 784 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.h` | `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3` | 4083 | `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3` | 4083 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5` | 51525 | `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5` | 51525 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.h` | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.m` | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | TRUE |
| `KeychainHelper/backup_helper.m` | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | 42561 | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | 42561 | TRUE |
| `Makefile` | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` | 9266 | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` | 9266 | TRUE |
| `MatrixRainView.h` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | 273 | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | 273 | TRUE |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 | TRUE |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 | TRUE |
| `PXAppGroupRestoreTransaction.h` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 | TRUE |
| `PXAppGroupRestoreTransaction.m` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 | TRUE |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 | TRUE |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | TRUE |
| `PXBackupBundleLock.h` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 | TRUE |
| `PXBackupBundleLock.m` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 | TRUE |
| `PXBackupDirectoryDiscovery.h` | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | 1708 | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | 1708 | TRUE |
| `PXBackupDirectoryDiscovery.m` | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | 38228 | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | 38228 | TRUE |
| `PXBackupFailureCleanup.h` | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 | TRUE |
| `PXBackupFailureCleanup.m` | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | 80668 | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | 80668 | TRUE |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | TRUE |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | TRUE |
| `PXBackupManifestWriter.h` | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | 2431 | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | 2431 | TRUE |
| `PXBackupManifestWriter.m` | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | 54069 | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | 54069 | TRUE |
| `PXBackupPublicationWorkspace.h` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 | TRUE |
| `PXBackupPublicationWorkspace.m` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 | TRUE |
| `PXBackupStaleWorkspaceCleanup.h` | `82cdc1e356907c75e9e04b39de6ff81809bd50cb0fd265d2683d865444cba76d` | 2265 | `82cdc1e356907c75e9e04b39de6ff81809bd50cb0fd265d2683d865444cba76d` | 2265 | TRUE |
| `PXBackupStaleWorkspaceCleanup.m` | `f96ed6b3be43b32ef4b31687fd10e797957d93f831fda58bfd39c3b3c26d4584` | 81407 | `f96ed6b3be43b32ef4b31687fd10e797957d93f831fda58bfd39c3b3c26d4584` | 81407 | TRUE |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | 1288 | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | 1288 | TRUE |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | 4389 | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | 4389 | TRUE |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | 3467 | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | 3467 | TRUE |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | 10564 | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | 10564 | TRUE |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | 1290 | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | 1290 | TRUE |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | 8332 | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | 8332 | TRUE |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | 1213 | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | 1213 | TRUE |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | 32523 | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | 32523 | TRUE |
| `PXKeychainHelperInvocationResult.h` | `7c166a99f440535a1c8810633ad9ae9176d2625d3447586dfe27b9c4cb30198a` | 2316 | `7c166a99f440535a1c8810633ad9ae9176d2625d3447586dfe27b9c4cb30198a` | 2316 | TRUE |
| `PXKeychainHelperInvocationResult.m` | `ebfefa4a24417c3366b0114cb5ed2dcbc343b19b241942399b2109562a134180` | 18014 | `ebfefa4a24417c3366b0114cb5ed2dcbc343b19b241942399b2109562a134180` | 18014 | TRUE |
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 | TRUE |
| `PXMainDataRestoreTransaction.m` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 | TRUE |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 | TRUE |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 | TRUE |
| `PXOptionalRestoreTransaction.h` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 | TRUE |
| `PXOptionalRestoreTransaction.m` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 | TRUE |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 | TRUE |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 | TRUE |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | TRUE |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | TRUE |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | TRUE |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | TRUE |
| `PlistViewerViewController.h` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | 184 | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | 184 | TRUE |
| `PlistViewerViewController.m` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | 26767 | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | 26767 | TRUE |
| `ProfileButtonsView.h` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | 254 | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | 254 | TRUE |
| `ProfileButtonsView.m` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | 5381 | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | 5381 | TRUE |
| `ProfileCreationViewController.h` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | 388 | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | 388 | TRUE |
| `ProfileCreationViewController.m` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | 7575 | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | 7575 | TRUE |
| `ProfileManagerViewController.h` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | 783 | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | 783 | TRUE |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 | TRUE |
| `ProgressHUDView.h` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | 522 | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | 522 | TRUE |
| `ProgressHUDView.m` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | 2263 | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | 2263 | TRUE |
| `ProjectX.h` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | 1623 | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | 1623 | TRUE |
| `ProjectXInstaller.h` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | 1231 | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | 1231 | TRUE |
| `ProjectXInstaller.m` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | 1898 | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | 1898 | TRUE |
| `ProjectXSceneDelegate.h` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | 192 | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | 192 | TRUE |
| `ProjectXSceneDelegate.m` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | 12181 | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | 12181 | TRUE |
| `ProjectXTweak.plist` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | 429 | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | 429 | TRUE |
| `ProjectXTweak/AAA_TestCtor.m` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | 1614 | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | 1614 | TRUE |
| `ProjectXTweak/AppContainerHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/AppGroupHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/AppInstallHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/AppVersionHooks.h` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | 546 | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | 546 | TRUE |
| `ProjectXTweak/AppVersionHooks.x` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | 25202 | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | 25202 | TRUE |
| `ProjectXTweak/BatteryHooks.x` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | 17019 | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | 17019 | TRUE |
| `ProjectXTweak/BootTimeHooks.x` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | 26933 | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | 26933 | TRUE |
| `ProjectXTweak/CanvasFingerprintHooks.x` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | 27600 | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | 27600 | TRUE |
| `ProjectXTweak/CoreDataHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/DeviceModelHooks.x` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | 9012 | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | 9012 | TRUE |
| `ProjectXTweak/DeviceSpecHooks.x` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | 81702 | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | 81702 | TRUE |
| `ProjectXTweak/DomainBlockingHooks.x` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | 27065 | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | 27065 | TRUE |
| `ProjectXTweak/FirebasePerfDisableScoped.x` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | 2515 | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | 2515 | TRUE |
| `ProjectXTweak/HookOwnership.h` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | 541 | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | 541 | TRUE |
| `ProjectXTweak/IOSVersionHooks.x` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | 112809 | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | 112809 | TRUE |
| `ProjectXTweak/JailbreakBypassHooks.x` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | 142382 | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | 142382 | TRUE |
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/LocaleTimeZoneHooks.x` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | 4909 | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | 4909 | TRUE |
| `ProjectXTweak/MethodSwizzler.h` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | 341 | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | 341 | TRUE |
| `ProjectXTweak/MethodSwizzler.m` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | 1903 | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | 1903 | TRUE |
| `ProjectXTweak/MissingSpoofHooks.x` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | 9793 | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | 9793 | TRUE |
| `ProjectXTweak/MobileGestalt.h` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | 11371 | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | 11371 | TRUE |
| `ProjectXTweak/NetworkConnectionTypeHooks.x` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | 56573 | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | 56573 | TRUE |
| `ProjectXTweak/ObjcClassPairGuard.x` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | 5439 | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | 5439 | TRUE |
| `ProjectXTweak/PXFileDebug.h` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | 6957 | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | 6957 | TRUE |
| `ProjectXTweak/PXNativeHookCoordinator.h` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | 9000 | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | 9000 | TRUE |
| `ProjectXTweak/PXNativeHookCoordinator.m` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | 28291 | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | 28291 | TRUE |
| `ProjectXTweak/PXScope.h` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | 1747 | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | 1747 | TRUE |
| `ProjectXTweak/PXScope.m` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | 20405 | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | 20405 | TRUE |
| `ProjectXTweak/PasteboardHooks.x` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | 37855 | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | 37855 | TRUE |
| `ProjectXTweak/SpringBoardLaunchHook.x` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | 16185 | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | 16185 | TRUE |
| `ProjectXTweak/StorageHooks.x` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | 41482 | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | 41482 | TRUE |
| `ProjectXTweak/ThemeHooks.x` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | 19043 | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | 19043 | TRUE |
| `ProjectXTweak/Tweak.x` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | 196955 | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | 196955 | TRUE |
| `ProjectXTweak/UUIDHooks.x` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | 43164 | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | 43164 | TRUE |
| `ProjectXTweak/UberURLHooks.x` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | 40212 | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | 40212 | TRUE |
| `ProjectXTweak/UserDefaultsHooks.x` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | 26089 | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | 26089 | TRUE |
| `ProjectXTweak/VPNDetectionBypass.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXTweak/WiFiHook.x` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | 40848 | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | 40848 | TRUE |
| `ProjectXViewController.h` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | 853 | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | 853 | TRUE |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | TRUE |
| `SecurityTabViewController+IPMonitorInfo.m` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | 967 | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | 967 | TRUE |
| `SecurityTabViewController.h` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | 5441 | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | 5441 | TRUE |
| `SecurityTabViewController.m` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | 293431 | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | 293431 | TRUE |
| `TabBarController+DeviceAlerts.h` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `TabBarController+DeviceAlerts.m` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `TabBarController.h` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | 1019 | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | 1019 | TRUE |
| `TabBarController.m` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | 28147 | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | 28147 | TRUE |
| `TestCtorTweak/TestCtorTweak.plist` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | 315 | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | 315 | TRUE |
| `TestCtorTweak/Tweak.x` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | 351 | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | 351 | TRUE |
| `ToolViewController.h` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | 280 | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | 280 | TRUE |
| `ToolViewController.m` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | 59814 | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | 59814 | TRUE |
| `URLMonitor.h` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | 727 | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | 727 | TRUE |
| `URLMonitor.m` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | 8827 | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | 8827 | TRUE |
| `UberOrderViewController.h` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | 608 | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | 608 | TRUE |
| `UberOrderViewController.m` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | 39801 | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | 39801 | TRUE |
| `VersionManagementViewController.h` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | 955 | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | 955 | TRUE |
| `VersionManagementViewController.m` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | 68330 | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | 68330 | TRUE |
| `WeaponXGuardian.m` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | 16859 | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | 16859 | TRUE |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | TRUE |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | TRUE |
| `WeaponXMountDaemon/WeaponXDaemon.m` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | 19900 | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | 19900 | TRUE |
| `WeaponXMountDaemon/WeaponXMountDaemon.m` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | 11205 | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | 11205 | TRUE |
| `com.hydra.weaponx.guardian.plist` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | 1145 | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | 1145 | TRUE |
| `common/AppContainerUUIDManager.h` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | 542 | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | 542 | TRUE |
| `common/AppContainerUUIDManager.m` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | 3559 | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | 3559 | TRUE |
| `common/AppGroupUUIDManager.h` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | 406 | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | 406 | TRUE |
| `common/AppGroupUUIDManager.m` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | 3449 | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | 3449 | TRUE |
| `common/AppInstallUUIDManager.h` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | 532 | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | 532 | TRUE |
| `common/AppInstallUUIDManager.m` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | 3539 | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | 3539 | TRUE |
| `common/BatteryManager.h` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | 685 | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | 685 | TRUE |
| `common/BatteryManager.m` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | 13918 | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | 13918 | TRUE |
| `common/CarrierDB.h` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | 1418 | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | 1418 | TRUE |
| `common/CarrierDB.m` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | 12622 | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | 12622 | TRUE |
| `common/CoreDataUUIDManager.h` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | 422 | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | 422 | TRUE |
| `common/CoreDataUUIDManager.m` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | 3450 | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | 3450 | TRUE |
| `common/DBDebugLogger.h` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | 262 | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | 262 | TRUE |
| `common/DBDebugLogger.m` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | 2783 | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | 2783 | TRUE |
| `common/DeviceModelManager.h` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | 1697 | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | 1697 | TRUE |
| `common/DeviceModelManager.m` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | 37928 | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | 37928 | TRUE |
| `common/DeviceNameManager.h` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | 385 | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | 385 | TRUE |
| `common/DeviceNameManager.m` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | 11474 | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | 11474 | TRUE |
| `common/DomainBlockingSettings.h` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | 882 | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | 882 | TRUE |
| `common/DomainBlockingSettings.m` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | 12424 | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | 12424 | TRUE |
| `common/DyldCacheUUIDManager.h` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | 411 | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | 411 | TRUE |
| `common/DyldCacheUUIDManager.m` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | 3458 | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | 3458 | TRUE |
| `common/IDFAManager.h` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | 335 | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | 335 | TRUE |
| `common/IDFAManager.m` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | 2745 | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | 2745 | TRUE |
| `common/IDFVManager.h` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | 335 | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | 335 | TRUE |
| `common/IDFVManager.m` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | 2712 | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | 2712 | TRUE |
| `common/IOSBuildDB.h` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | 1092 | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | 1092 | TRUE |
| `common/IOSBuildDB.m` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | 9567 | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | 9567 | TRUE |
| `common/IOSVersionInfo.h` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | 592 | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | 592 | TRUE |
| `common/IOSVersionInfo.m` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | 15529 | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | 15529 | TRUE |
| `common/IPMonitorService.h` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | 224 | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | 224 | TRUE |
| `common/IPMonitorService.m` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | 25567 | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | 25567 | TRUE |
| `common/IPStatusCacheManager.h` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | 990 | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | 990 | TRUE |
| `common/IPStatusCacheManager.m` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | 12562 | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | 12562 | TRUE |
| `common/IPStatusViewController.h` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | 271 | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | 271 | TRUE |
| `common/IPStatusViewController.m` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | 62749 | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | 62749 | TRUE |
| `common/IPhoneModelDB.h` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | 885 | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | 885 | TRUE |
| `common/IPhoneModelDB.m` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | 6198 | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | 6198 | TRUE |
| `common/IdentifierManager.h` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | 3082 | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | 3082 | TRUE |
| `common/IdentifierManager.m` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | 160824 | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | 160824 | TRUE |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | TRUE |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | TRUE |
| `common/LocationSpoofingManager.h` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | 3202 | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | 3202 | TRUE |
| `common/LocationSpoofingManager.m` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | 65282 | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | 65282 | TRUE |
| `common/NetworkManager.h` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | 1065 | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | 1065 | TRUE |
| `common/NetworkManager.m` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | 17926 | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | 17926 | TRUE |
| `common/PXPaths.h` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | 616 | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | 616 | TRUE |
| `common/PXPaths.m` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | 2283 | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | 2283 | TRUE |
| `common/PXProcessKiller.h` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | 554 | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | 554 | TRUE |
| `common/PXProcessKiller.m` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | 4565 | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | 4565 | TRUE |
| `common/PassThroughWindow.h` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | 75 | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | 75 | TRUE |
| `common/PassThroughWindow.m` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | 486 | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | 486 | TRUE |
| `common/PasteboardUUIDManager.h` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | 415 | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | 415 | TRUE |
| `common/PasteboardUUIDManager.m` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | 3466 | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | 3466 | TRUE |
| `common/ProfileIndicatorView.h` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | 174 | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | 174 | TRUE |
| `common/ProfileIndicatorView.m` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | 56659 | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | 56659 | TRUE |
| `common/ProfileManager.h` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | 2322 | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | 2322 | TRUE |
| `common/ProfileManager.m` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | 72206 | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | 72206 | TRUE |
| `common/ProjectXLogging.h` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | 460 | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | 460 | TRUE |
| `common/ProjectXLogging.m` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | 4712 | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | 4712 | TRUE |
| `common/ScoreMeterView.h` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | 200 | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | 200 | TRUE |
| `common/ScoreMeterView.m` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | 2650 | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | 2650 | TRUE |
| `common/SerialNumberManager.h` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | 486 | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | 486 | TRUE |
| `common/SerialNumberManager.m` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | 6005 | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | 6005 | TRUE |
| `common/StorageManager.h` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | 3350 | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | 3350 | TRUE |
| `common/StorageManager.m` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | 9610 | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | 9610 | TRUE |
| `common/SystemUUIDManager.h` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | 387 | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | 387 | TRUE |
| `common/SystemUUIDManager.m` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | 3422 | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | 3422 | TRUE |
| `common/UIButton+SafeConfiguration.h` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | 984 | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | 984 | TRUE |
| `common/UIButton+SafeConfiguration.m` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | 1672 | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | 1672 | TRUE |
| `common/UIButtonCompat.h` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | 1581 | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | 1581 | TRUE |
| `common/UIButtonCompat.m` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | 5833 | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | 5833 | TRUE |
| `common/UptimeManager.h` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | 1039 | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | 1039 | TRUE |
| `common/UptimeManager.m` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | 18221 | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | 18221 | TRUE |
| `common/UserDefaultsUUIDManager.h` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | 425 | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | 425 | TRUE |
| `common/UserDefaultsUUIDManager.m` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | 3484 | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | 3484 | TRUE |
| `common/VersionCompare.h` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | 519 | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | 519 | TRUE |
| `common/VersionCompare.m` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | 1936 | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | 1936 | TRUE |
| `common/WiFiManager.h` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | 664 | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | 664 | TRUE |
| `common/WiFiManager.m` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | 26544 | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | 26544 | TRUE |
| `ent.plist` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | 2881 | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | 2881 | TRUE |
| `iOSVersionManager.h` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | 404 | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | 404 | TRUE |
| `include/ellekit/ellekit.h` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | 5050 | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | 5050 | TRUE |
| `include/substrate.h` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | 44 | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | 44 | TRUE |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | TRUE |
| `layout/Library/libSandy/projectx_filesystem_access.plist` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | 2557 | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | 2557 | TRUE |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | 23462 | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | 23462 | TRUE |
| `scripts/audit_native_hooks.sh` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | 4225 | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | 4225 | TRUE |
| `scripts/keychain_backup.sh` | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | 75266 | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | 75266 | TRUE |
| `scripts/setup_altlist.sh` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | 1567 | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | 1567 | TRUE |
| `setup_app.sh` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | 1679 | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | 1679 | TRUE |
| `setup_dependencies.sh` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | 524 | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | 524 | TRUE |
| `weaponx-debug.sh` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | 6254 | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | 6254 | TRUE |

## Authorized source before and after

| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
| --- | --- | ---: | --- | ---: |
| `PXBackupArtifactPolicy.h` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 | `08255fad381774a6e2b0f9e7e0c0176fd00decc141f54ba2caa7455a00e147bc` | 2013 |
| `PXBackupArtifactPolicy.m` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 | `0d2083ea85bc4e7610cd3393adfb558429899a003029b4384b35056836330b3d` | 6259 |
| `PXBackupArtifactWriter.h` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 | `8834bbbe5834a343c1f58c9fc1c823ce68b30f5d11158f8a2a7cec45f9419012` | 3059 |
| `PXBackupArtifactWriter.m` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 | `01296680380daeb92fb2fa1a9e1e46d18fd381f0e55db55f5627fc4215cc19ff` | 96014 |
| `PXBackupManifestV4.m` | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | 44234 | `4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037` | 45136 |
| `PXBackupManifestValidator.m` | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | 91751 | `8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b` | 91206 |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 | `2cd726496b1830cc404c6e6665e73785552a39c74cdb9683a43d32221fc194cc` | 2006 |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 | `2c45882144f529380bf485724bdd2258a3d9dd43de232076e857f10f3d5958f9` | 46654 |
| `PXBackupDirectoryPublisher.h` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 | `0acc8af4a05df17b2e20319905773c0ba6350a749ed3b0204b94499c1da2e88d` | 2955 |
| `PXBackupDirectoryPublisher.m` | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | 70795 | `e146f716619708ab496bf08d8aca8c8736d0e4b4e3df024f1bc1e7a1a83ae2f6` | 82028 |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 | `3d594d5f2eb509e2fb9e87849013ec9428ef7083eb0c4b52ecffe00fa56809c3` | 4355 |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 | `1e3a0eabba6a5a8a90cb7cf3800476e9324ec4181be1fb51de0e0e08e2c5e39b` | 104823 |
| `AppDataBackupManager.m` | `f4478b67d8fb5efdc04f215f2f1f11ad2007126d941adb94ab8ae149eddece2d` | 234119 | `96415127cff03f0261a4372f9df60fa7abe3095124261d01280480f51ba9fc29` | 238739 |
| `PXFileProtection.h` | ABSENT | 0 | `5c7163ec17f24c9ea4e0d4a53012fcb4c62e57decfb7891fdf8be72c554c8fb7` | 1095 |
| `PXFileProtection.m` | ABSENT | 0 | `a6fb37302b7b32958026ba2842563769ee0098cf1007a6500763d3ce4f231947` | 11505 |

## Original protection inventory

Baseline production inventory:

- `NSFileProtection` references: 0
- `F_SETPROTECTIONCLASS` references: 0
- `F_GETPROTECTIONCLASS` references: 0
- protection class A references: 0
- custom protection xattr authority: 0
- custom content-encryption implementation: 0
- manifest schema revision: 1
- generic optional-file staging Data Protection enforcement: absent
- publication-time Keychain protection verification: absent

## Original best-effort chmod inventory

Baseline `AppDataBackupManager.m` contained exactly two Keychain-specific best-effort commands:

```text
chmod 600 <temporaryOutputPath> 2>/dev/null || true
```

One followed helper backup and one followed the in-app fallback. Neither result was checked. Both Keychain-specific calls were removed. One unrelated baseline `chmod 600` remains outside Keychain backup/restore branches.

## Threat model

The policy protects Keychain backup content at rest through the iOS Data Protection subsystem and rejects unsafe local filesystem state.

It does not claim protection against root or kernel compromise while the device is unlocked, malicious jailbreak substrate, live privileged filesystem access, or process-memory extraction. Predictable bridge filenames and the Darwin notification protocol remain a documented residual boundary.

## Data Protection Complete decision

New Keychain artifacts require `PROTECTION_CLASS_A`, corresponding to Data Protection Complete.

There is no fallback to class C, CompleteUntilFirstUserAuthentication, NoProtection, inherited default class, xattr marker, or best-effort success. Unsupported `F_SETPROTECTIONCLASS`/`F_GETPROTECTIONCLASS` behavior fails closed.

## Ownership decision

Every protected file must satisfy `st_uid == geteuid()` and `st_gid == getegid()`.

No UID/GID is hard-coded, no recursive chown is performed, and an ownership mismatch is rejected rather than repaired.

## POSIX mode decision

The exact accepted permission mode is `0600`.

Setuid, setgid, and sticky bits are rejected. Apply uses descriptor-based `fchmod`, then verification requires exact mode `0600`; path-based chmod is not final authority.

## Hard-link decision

Every protected Keychain file must be a regular file with `st_nlink == 1` before and after protection and across all publication verification points.

## Encryption boundary

TASK-4.9 implements platform Data Protection metadata only.

It does not add AES wrapping, passwords, custom master keys, Secure Enclave wrapping, Keychain-stored encryption keys, an encrypted archive format, key rotation, or password UI.

## File-protection API

`PXFileProtection.h/.m` provides exactly two descriptor-authority operations:

- `PXApplyCompleteFileProtectionToDescriptor`
- `PXVerifyCompleteFileProtectionOnDescriptor`

The production authority inventory contains exactly one `F_SETPROTECTIONCLASS` and one `F_GETPROTECTIONCLASS`, both in `PXFileProtection.m`.

## Apply algorithm

The apply primitive performs, in order: descriptor validation, FD_CLOEXEC proof, initial fstat, regular-file/link/owner/special-bit checks, descriptor fchmod to `0600`, `F_SETPROTECTIONCLASS(PROTECTION_CLASS_A)`, fsync, final fstat, same dev/inode/type/size proof, exact owner/mode/link proof, and exact class-A readback.

EINTR is retried for relevant fcntl, fstat, fchmod, and fsync operations.

## Verify algorithm

The verify primitive is nonmutating. It validates descriptor/FD_CLOEXEC, regular file, one link, exact effective owner, exact mode `0600`, absence of special bits, successful `F_GETPROTECTIONCLASS`, and exact class A.

## Error privacy

Protection errors contain only a stable domain, stable code, generic localized description, and deterministic field path.

They do not include a path, filename, bundle identifier, access group, raw descriptor, errno text, actual UID/GID, actual protection-class value, command, or helper output.

## Artifact policy changes

Canonical policies now carry immutable `requiredPOSIXMode` and `dataProtectionRequirement` fields. Every artifact requires mode `0600`; only Keychain requires Complete, while all other kinds remain Unspecified.

Equality and hash include both new policy facts.

## Keychain failure disposition

The canonical Keychain policy is Optional, WarnAndContinue, Reject-empty, mode `0600`, and Complete.

A protection failure omits the optional Keychain artifact and adds exactly one safe policy warning: `Keychain backup could not be protected and was omitted`. Raw writer/protection errors are not appended to the user warning.

## Revision 1 compatibility

Manifest version remains 4. Validator support is the exact closed revision set `{1,2}`.

Revision 1 retains the historical exact four-key policy graph and historical Keychain `continueWithoutWarning` disposition. Revision 1 does not claim source class A and is never rewritten. A legacy source is copied into private staging and only the staged inode is upgraded to class A.

## Revision 2 exact graph

Revision 2 artifact policy declarations contain exactly six keys: `kind`, `requirement`, `failureDisposition`, `emptyFilePolicy`, `posixMode`, and `dataProtection`.

Only `posixMode = "0600"` is accepted. Keychain requires `dataProtection = "complete"` and `warnAndContinue`; every non-Keychain kind requires `dataProtection = "unspecified"` and its historical disposition.

## Manifest builder changes

New backups emit schema revision 2. The builder requires canonical policy objects and verified artifact protection state before serializing the six-key graph.

Top-level manifest key count remains 33, version/schema identifier/publication protocol remain unchanged, artifact ordering remains unchanged, and `$.keychain` remains exactly `included`, `archive`, `groupsSelected`, and `method`.

## Manifest validator changes

The validator dispatches by exact integral schema revision. Revision 1 requires exactly four policy keys; revision 2 requires exactly six. Boolean, floating, negative, zero, revision 3+, alias modes, mixed graphs, wrong class declarations, and wrong Keychain disposition are rejected.

## Writer integration

After producer success, the writer securely opens the payload with O_RDWR for Complete policy, proves regular/link/owner/bounds/identity, applies class A before digest, verifies protection, snapshots protected identity, streams SHA-256, fsyncs, reverifies before rename, atomically renames, reopens and verifies after rename, fsyncs the parent, removes the temporary directory, and only then creates a verified artifact record.

## Writer failure cleanup

Protection failure uses writer error code 18 and field `$.artifact.payload.protection`. Existing bounded owned-state cleanup removes temporary/final state on failure. Cleanup failure retains its existing precedence over the earlier operation error.

## Pre-artifact-rename proof

Immediately before artifact rename, the retained payload descriptor and namespace are revalidated against the protected identity, exact mode/owner/link, stable size/timestamps, and class A.

## Post-artifact-rename proof

After artifact rename, the writer verifies the retained descriptor, securely reopens the final namespace entry, proves same dev/inode/size, verifies class A and exact filesystem policy, then retains a duplicated descriptor as immutable record authority.

## Pre-publication proof

`artifactWriter validateIdentityWithError:` revalidates every accepted retained descriptor and secure workspace namespace entry. The directory publisher validates the revision-2 declaration, securely opens the declared Keychain artifact from the workspace directory descriptor, verifies class A, captures identity, and repeats final writer/protection checks immediately before directory rename.

## Post-publication proof

After atomic directory rename, the publisher opens the final directory descriptor, reads and validates the final manifest, confirms snapshot identity, resolves the Keychain declaration again, securely opens the final artifact, verifies class A, and requires the same dev/inode identity as the pre-rename artifact.

## Publication rollback proof

A final manifest mismatch, protected-artifact mismatch, identity mismatch, or parent durability failure enters the existing rollback flow. Post-rename protection failure cannot return publication success. Publisher error code 19 and field `$.artifacts.protection` report the safe failure class.

## Artifact verifier behavior

Revision 1 source verification preserves historical path/type/link/size/digest/stability checks without requiring class A.

Revision 2 Keychain verification additionally requires descriptor-verified class A and exact mode/owner/link before and after digest. The verifier does not mutate or repair published backup source state.

## Restore staging protection

`PXOptionalFileStagingWorkspace applyCompleteFileProtectionWithError:` validates retained parent/root/payload descriptor and namespace identities, applies class A through the retained payload descriptor, verifies exact mode/owner/link/class, revalidates namespace identity, and updates the retained stable identity only after success.

## Legacy restore upgrade

A revision-1 source may lack class A. The source is not mutated. Its private staged copy is upgraded and verified before helper or bridge invocation.

## Revision 2 restore

A revision-2 source must pass source class-A verification. Staging creates a new inode and reapplies/verifies class A rather than relying on protection inheritance.

## In-app import protection

After copying the staged payload to the manager-owned bridge import file, the manager opens it O_RDWR/O_NOFOLLOW/O_CLOEXEC, proves regular/link/owner/identity, applies and verifies class A, and only then creates the request and posts the Darwin notification. Failure deletes the owned import file and does not notify the bridge.

## In-app export boundary

After a successful bridge response and before copying export content to the artifact-writer producer destination, the manager securely opens the export, proves regular/link/owner/identity, and applies/verifies class A. The writer independently reapplies and verifies final producer output protection.

Residual risk: the unchanged bridge may create the predictable export file before the manager can protect it. Full bridge workspace redesign is outside TASK-4.9.

## Portability policy

Data Protection class is local iOS filesystem metadata. A revision-2 backup copied through a filesystem that loses class A is rejected when copied back. TASK-4.9 does not silently repair, downgrade, or import-migrate such a backup.

## Lock/unlock test status

Device lock/unlock testing is PENDING. No claim is made that runtime class-A denial/recovery has passed without an iOS device environment.

Required device cases remain: unlocked read success, locked read denial using a newly opened descriptor, unlock recovery with unchanged digest, and staged restore lock-before-helper failure followed by successful unlocked retry.

## Privacy/static logging gates

No raw protection class, descriptor, UID/GID, path, errno description, access group, item content, or helper output is added to warnings or debug summaries.

Allowed state is represented only by generic outcomes and canonical manifest strings `0600`, `complete`, and `unspecified`.

## Makefile zero-diff proof

`Makefile` remained byte-identical to `a8d4b434fe3531b7895fef1712ce8be5507439e0` with SHA-256 `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` and 9266 bytes.

`PXFileProtection.m` is collected automatically by the existing root wildcard and is absent from `backup_helper_FILES`.

## V2 result-model non-regression

`KeychainHelper/PXKeychainHelperResult.h/.m` and `PXKeychainHelperInvocationResult.h/.m` are byte-identical to baseline. V2 emission/strict decode, bounded invocation, exit/completion consistency, Partial integration, and raw-output privacy contracts remain unchanged.

## Keychain core non-regression

Keychain item query/add/update/delete source is byte-identical. TASK-4.9 changes file artifact protection only; it does not alter item identity, exact upsert, requested/effective group reporting, helper workspace, or wrapper protocol behavior.

## Security operation counts

Whole Keychain core remains:

- SecItemCopyMatching = 6
- SecItemAdd = 1
- SecItemUpdate = 1
- SecItemDelete = 1

Restore remains:

- SecItemCopyMatching = 1
- SecItemAdd = 1
- SecItemUpdate = 1
- SecItemDelete = 0

## Wrapper/helper/bridge zero-diff proof

`scripts/keychain_backup.sh`, `KeychainHelper/backup_helper.m`, Keychain core/result/identity/exit-code files, `WeaponXKeychainBridge/Tweak.m`, and bridge plist are byte-identical to baseline. Both available Git Bash executables pass `bash -n` for the unchanged wrapper.

## Static gates

- S2 final primitive model: 300,073 assertions PASS
- S3 policy/writer model: 300,031 assertions PASS
- S4 manifest/verifier/publisher model: 300,023 assertions PASS
- S5 staging/manager model: 900,012 assertions PASS
- Total model assertions: 1,800,139 PASS
- Protected production hash gate: 271/271 PASS
- Production protection authority gate: PASS
- Makefile zero-diff gate: PASS
- Keychain-specific manager chmod gate: 0 PASS
- Security operation count gate: PASS
- Objective-C lexical delimiter gate: PASS
- `git diff --check`: PASS
- wrapper shell syntax: PASS

## Explicit scenarios

Explicit scenarios: 850.

| # | Category | Stimulus | Expected outcome |
| ---: | --- | --- | --- |
| 1 | primitive | invalid negative descriptor | reject with InvalidDescriptor |
| 2 | primitive | closed descriptor | reject without fallback |
| 3 | primitive | descriptor lacks FD_CLOEXEC | reject |
| 4 | primitive | directory descriptor | reject InvalidFileType |
| 5 | primitive | non-regular object | reject |
| 6 | primitive | hard-link count two | reject InvalidLinkCount |
| 7 | ownership | uid differs from geteuid | reject without chown |
| 8 | ownership | gid differs from getegid | reject without chown |
| 9 | mode | setuid bit present | reject before fchmod |
| 10 | mode | setgid bit present | reject before fchmod |
| 11 | mode | sticky bit present | reject before fchmod |
| 12 | mode | mode 0644 | apply exact 0600 or fail |
| 13 | class | F_SETPROTECTIONCLASS fails EINVAL | fail closed |
| 14 | class | F_SETPROTECTIONCLASS fails ENOTSUP | fail closed |
| 15 | class | F_SETPROTECTIONCLASS fails ENOTTY | fail closed |
| 16 | class | F_GETPROTECTIONCLASS fails | reject |
| 17 | class | readback class C | reject ClassMismatch |
| 18 | class | readback class D | reject ClassMismatch |
| 19 | class | readback class A | accept |
| 20 | durability | fsync fails | reject DurabilityFailed |
| 21 | identity | device changes after apply | reject IdentityChanged |
| 22 | identity | inode changes after apply | reject IdentityChanged |
| 23 | identity | type changes after apply | reject IdentityChanged |
| 24 | identity | size changes after apply | reject IdentityChanged |
| 25 | verify | verify exact class A/mode/owner/link | accept without mutation |
| 26 | verify | verify mode 0400 | reject |
| 27 | writer | non-Keychain policy | mode 0600 and protection unspecified |
| 28 | writer | Keychain producer success | apply class A before digest |
| 29 | writer | producer output missing | reject output |
| 30 | writer | producer creates directory | reject output |
| 31 | writer | producer creates symlink | reject output |
| 32 | writer | producer creates hard-linked file | reject output |
| 33 | writer | producer creates wrong-owner file | reject output |
| 34 | writer | protection apply failure | error 18 and cleanup |
| 35 | writer | protection changes before rename | reject before rename |
| 36 | writer | protection changes after artifact rename | reject and cleanup |
| 37 | writer | parent fsync failure | reject durability |
| 38 | writer | cleanup failure after protection failure | cleanup error precedence |
| 39 | manifest-r1 | valid historical four-key graph | accept |
| 40 | manifest-r1 | six-key policy graph | reject mixed revision |
| 41 | manifest-r1 | Keychain warnAndContinue | reject historical mismatch |
| 42 | manifest-r2 | valid six-key graph | accept |
| 43 | manifest-r2 | four-key graph | reject mixed revision |
| 44 | manifest-r2 | missing posixMode | reject |
| 45 | manifest-r2 | missing dataProtection | reject |
| 46 | manifest-r2 | extra policy key | reject |
| 47 | manifest-r2 | mode string 600 | reject |
| 48 | manifest-r2 | numeric mode 384 | reject |
| 49 | manifest-r2 | Keychain unspecified | reject |
| 50 | manifest-r2 | non-Keychain complete | reject |
| 51 | manifest-r2 | Keychain old failure disposition | reject |
| 52 | revision | revision zero | reject |
| 53 | revision | revision three | reject |
| 54 | revision | Boolean revision | reject |
| 55 | revision | floating revision | reject |
| 56 | verifier | revision-1 Keychain without class A | verify legacy content without mutation |
| 57 | verifier | revision-2 Keychain class A | verify content and protection |
| 58 | verifier | revision-2 Keychain class C | fail before restore plan |
| 59 | publisher | revision 2 without Keychain | publish without protected artifact requirement |
| 60 | publisher | revision 2 protected Keychain | pre/post verification succeeds |
| 61 | publisher | pre-rename class mismatch | fail before directory rename |
| 62 | publisher | post-rename class mismatch | rollback |
| 63 | publisher | post-rename inode mismatch | rollback |
| 64 | publisher | post-rename manifest mismatch | rollback |
| 65 | publisher | rollback failure | report rollback failure, never success |
| 66 | staging | revision-1 source stages | upgrade staged copy to class A |
| 67 | staging | revision-2 source stages | reapply class A to new inode |
| 68 | staging | class set failure | hard fail before helper |
| 69 | staging | class read failure | hard fail before helper |
| 70 | staging | namespace identity changes | hard fail |
| 71 | bridge-import | copy succeeds and protection succeeds | request then notify |
| 72 | bridge-import | protection fails | delete import and do not notify |
| 73 | bridge-export | bridge export exists and protection succeeds | copy to producer destination |
| 74 | bridge-export | protection fails | delete export and omit fallback result |
| 75 | backup | writer protection failure | omit Keychain and add safe warning |
| 76 | backup | manifest references protected Keychain then invariant changes | fail backup before publication |
| 77 | privacy | protection error | no path, uid, gid, fd, class value, errno text |
| 78 | portability | revision-2 backup loses class A in transit | reject; do not repair |
| 79 | lock | unlocked fresh open | device test expected read success |
| 80 | lock | locked fresh open | device test expected OS denial |
| 81 | lock | unlock recovery | device test expected read success and same digest |
| 82 | non-regression | Keychain core | Security counts unchanged |
| 83 | non-regression | wrapper/helper/bridge | byte-identical |
| 84 | non-regression | Makefile | byte-identical |
| 85 | boundary | Phase 5 | not started |
| 86 | primitive-apply | descriptor: valid | accept only canonical fail-closed state |
| 87 | primitive-apply | descriptor: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 88 | primitive-apply | descriptor: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 89 | primitive-apply | descriptor: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 90 | primitive-apply | regular-file: valid | accept only canonical fail-closed state |
| 91 | primitive-apply | regular-file: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 92 | primitive-apply | regular-file: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 93 | primitive-apply | regular-file: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 94 | primitive-apply | link-count: valid | accept only canonical fail-closed state |
| 95 | primitive-apply | link-count: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 96 | primitive-apply | link-count: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 97 | primitive-apply | link-count: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 98 | primitive-apply | owner: valid | accept only canonical fail-closed state |
| 99 | primitive-apply | owner: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 100 | primitive-apply | owner: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 101 | primitive-apply | owner: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 102 | primitive-apply | mode: valid | accept only canonical fail-closed state |
| 103 | primitive-apply | mode: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 104 | primitive-apply | mode: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 105 | primitive-apply | mode: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 106 | primitive-apply | class-set: valid | accept only canonical fail-closed state |
| 107 | primitive-apply | class-set: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 108 | primitive-apply | class-set: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 109 | primitive-apply | class-set: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 110 | primitive-apply | fsync: valid | accept only canonical fail-closed state |
| 111 | primitive-apply | fsync: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 112 | primitive-apply | fsync: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 113 | primitive-apply | fsync: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 114 | primitive-apply | identity: valid | accept only canonical fail-closed state |
| 115 | primitive-apply | identity: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 116 | primitive-apply | identity: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 117 | primitive-apply | identity: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 118 | primitive-apply | size: valid | accept only canonical fail-closed state |
| 119 | primitive-apply | size: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 120 | primitive-apply | size: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 121 | primitive-apply | size: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 122 | primitive-apply | class-read: valid | accept only canonical fail-closed state |
| 123 | primitive-apply | class-read: invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 124 | primitive-apply | class-read: changed | reject or rollback without downgrade, raw disclosure, or false success |
| 125 | primitive-apply | class-read: interrupted | reject or rollback without downgrade, raw disclosure, or false success |
| 126 | primitive-verify | fd-flags: canonical | accept only canonical fail-closed state |
| 127 | primitive-verify | fd-flags: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 128 | primitive-verify | fd-flags: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 129 | primitive-verify | fd-flags: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 130 | primitive-verify | type: canonical | accept only canonical fail-closed state |
| 131 | primitive-verify | type: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 132 | primitive-verify | type: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 133 | primitive-verify | type: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 134 | primitive-verify | links: canonical | accept only canonical fail-closed state |
| 135 | primitive-verify | links: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 136 | primitive-verify | links: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 137 | primitive-verify | links: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 138 | primitive-verify | uid: canonical | accept only canonical fail-closed state |
| 139 | primitive-verify | uid: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 140 | primitive-verify | uid: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 141 | primitive-verify | uid: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 142 | primitive-verify | gid: canonical | accept only canonical fail-closed state |
| 143 | primitive-verify | gid: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 144 | primitive-verify | gid: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 145 | primitive-verify | gid: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 146 | primitive-verify | mode: canonical | accept only canonical fail-closed state |
| 147 | primitive-verify | mode: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 148 | primitive-verify | mode: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 149 | primitive-verify | mode: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 150 | primitive-verify | special-bits: canonical | accept only canonical fail-closed state |
| 151 | primitive-verify | special-bits: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 152 | primitive-verify | special-bits: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 153 | primitive-verify | special-bits: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 154 | primitive-verify | class-read: canonical | accept only canonical fail-closed state |
| 155 | primitive-verify | class-read: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 156 | primitive-verify | class-read: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 157 | primitive-verify | class-read: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 158 | primitive-verify | class-value: canonical | accept only canonical fail-closed state |
| 159 | primitive-verify | class-value: mismatch | reject or rollback without downgrade, raw disclosure, or false success |
| 160 | primitive-verify | class-value: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 161 | primitive-verify | class-value: EINTR | reject or rollback without downgrade, raw disclosure, or false success |
| 162 | writer-lifecycle | producer: success | accept only canonical fail-closed state |
| 163 | writer-lifecycle | producer: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 164 | writer-lifecycle | producer: race | reject or rollback without downgrade, raw disclosure, or false success |
| 165 | writer-lifecycle | producer: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 166 | writer-lifecycle | namespace: success | accept only canonical fail-closed state |
| 167 | writer-lifecycle | namespace: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 168 | writer-lifecycle | namespace: race | reject or rollback without downgrade, raw disclosure, or false success |
| 169 | writer-lifecycle | namespace: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 170 | writer-lifecycle | descriptor: success | accept only canonical fail-closed state |
| 171 | writer-lifecycle | descriptor: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 172 | writer-lifecycle | descriptor: race | reject or rollback without downgrade, raw disclosure, or false success |
| 173 | writer-lifecycle | descriptor: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 174 | writer-lifecycle | protection: success | accept only canonical fail-closed state |
| 175 | writer-lifecycle | protection: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 176 | writer-lifecycle | protection: race | reject or rollback without downgrade, raw disclosure, or false success |
| 177 | writer-lifecycle | protection: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 178 | writer-lifecycle | digest: success | accept only canonical fail-closed state |
| 179 | writer-lifecycle | digest: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 180 | writer-lifecycle | digest: race | reject or rollback without downgrade, raw disclosure, or false success |
| 181 | writer-lifecycle | digest: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 182 | writer-lifecycle | file-sync: success | accept only canonical fail-closed state |
| 183 | writer-lifecycle | file-sync: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 184 | writer-lifecycle | file-sync: race | reject or rollback without downgrade, raw disclosure, or false success |
| 185 | writer-lifecycle | file-sync: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 186 | writer-lifecycle | pre-rename: success | accept only canonical fail-closed state |
| 187 | writer-lifecycle | pre-rename: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 188 | writer-lifecycle | pre-rename: race | reject or rollback without downgrade, raw disclosure, or false success |
| 189 | writer-lifecycle | pre-rename: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 190 | writer-lifecycle | rename: success | accept only canonical fail-closed state |
| 191 | writer-lifecycle | rename: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 192 | writer-lifecycle | rename: race | reject or rollback without downgrade, raw disclosure, or false success |
| 193 | writer-lifecycle | rename: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 194 | writer-lifecycle | post-rename: success | accept only canonical fail-closed state |
| 195 | writer-lifecycle | post-rename: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 196 | writer-lifecycle | post-rename: race | reject or rollback without downgrade, raw disclosure, or false success |
| 197 | writer-lifecycle | post-rename: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 198 | writer-lifecycle | parent-sync: success | accept only canonical fail-closed state |
| 199 | writer-lifecycle | parent-sync: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 200 | writer-lifecycle | parent-sync: race | reject or rollback without downgrade, raw disclosure, or false success |
| 201 | writer-lifecycle | parent-sync: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 202 | writer-lifecycle | cleanup: success | accept only canonical fail-closed state |
| 203 | writer-lifecycle | cleanup: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 204 | writer-lifecycle | cleanup: race | reject or rollback without downgrade, raw disclosure, or false success |
| 205 | writer-lifecycle | cleanup: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 206 | writer-lifecycle | record: success | accept only canonical fail-closed state |
| 207 | writer-lifecycle | record: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 208 | writer-lifecycle | record: race | reject or rollback without downgrade, raw disclosure, or false success |
| 209 | writer-lifecycle | record: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 210 | manifest-r1 | revision: canonical | accept only canonical fail-closed state |
| 211 | manifest-r1 | revision: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 212 | manifest-r1 | revision: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 213 | manifest-r1 | revision: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 214 | manifest-r1 | revision: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 215 | manifest-r1 | policy-keys: canonical | accept only canonical fail-closed state |
| 216 | manifest-r1 | policy-keys: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 217 | manifest-r1 | policy-keys: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 218 | manifest-r1 | policy-keys: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 219 | manifest-r1 | policy-keys: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 220 | manifest-r1 | kind: canonical | accept only canonical fail-closed state |
| 221 | manifest-r1 | kind: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 222 | manifest-r1 | kind: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 223 | manifest-r1 | kind: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 224 | manifest-r1 | kind: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 225 | manifest-r1 | requirement: canonical | accept only canonical fail-closed state |
| 226 | manifest-r1 | requirement: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 227 | manifest-r1 | requirement: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 228 | manifest-r1 | requirement: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 229 | manifest-r1 | requirement: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 230 | manifest-r1 | disposition: canonical | accept only canonical fail-closed state |
| 231 | manifest-r1 | disposition: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 232 | manifest-r1 | disposition: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 233 | manifest-r1 | disposition: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 234 | manifest-r1 | disposition: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 235 | manifest-r1 | empty-policy: canonical | accept only canonical fail-closed state |
| 236 | manifest-r1 | empty-policy: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 237 | manifest-r1 | empty-policy: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 238 | manifest-r1 | empty-policy: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 239 | manifest-r1 | empty-policy: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 240 | manifest-r1 | ordering: canonical | accept only canonical fail-closed state |
| 241 | manifest-r1 | ordering: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 242 | manifest-r1 | ordering: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 243 | manifest-r1 | ordering: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 244 | manifest-r1 | ordering: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 245 | manifest-r1 | references: canonical | accept only canonical fail-closed state |
| 246 | manifest-r1 | references: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 247 | manifest-r1 | references: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 248 | manifest-r1 | references: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 249 | manifest-r1 | references: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 250 | manifest-r2 | revision: canonical | accept only canonical fail-closed state |
| 251 | manifest-r2 | revision: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 252 | manifest-r2 | revision: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 253 | manifest-r2 | revision: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 254 | manifest-r2 | revision: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 255 | manifest-r2 | policy-keys: canonical | accept only canonical fail-closed state |
| 256 | manifest-r2 | policy-keys: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 257 | manifest-r2 | policy-keys: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 258 | manifest-r2 | policy-keys: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 259 | manifest-r2 | policy-keys: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 260 | manifest-r2 | posix-mode: canonical | accept only canonical fail-closed state |
| 261 | manifest-r2 | posix-mode: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 262 | manifest-r2 | posix-mode: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 263 | manifest-r2 | posix-mode: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 264 | manifest-r2 | posix-mode: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 265 | manifest-r2 | data-protection: canonical | accept only canonical fail-closed state |
| 266 | manifest-r2 | data-protection: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 267 | manifest-r2 | data-protection: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 268 | manifest-r2 | data-protection: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 269 | manifest-r2 | data-protection: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 270 | manifest-r2 | keychain-disposition: canonical | accept only canonical fail-closed state |
| 271 | manifest-r2 | keychain-disposition: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 272 | manifest-r2 | keychain-disposition: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 273 | manifest-r2 | keychain-disposition: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 274 | manifest-r2 | keychain-disposition: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 275 | manifest-r2 | non-keychain-protection: canonical | accept only canonical fail-closed state |
| 276 | manifest-r2 | non-keychain-protection: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 277 | manifest-r2 | non-keychain-protection: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 278 | manifest-r2 | non-keychain-protection: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 279 | manifest-r2 | non-keychain-protection: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 280 | manifest-r2 | ordering: canonical | accept only canonical fail-closed state |
| 281 | manifest-r2 | ordering: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 282 | manifest-r2 | ordering: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 283 | manifest-r2 | ordering: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 284 | manifest-r2 | ordering: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 285 | manifest-r2 | references: canonical | accept only canonical fail-closed state |
| 286 | manifest-r2 | references: missing | reject or rollback without downgrade, raw disclosure, or false success |
| 287 | manifest-r2 | references: extra | reject or rollback without downgrade, raw disclosure, or false success |
| 288 | manifest-r2 | references: wrong-type | reject or rollback without downgrade, raw disclosure, or false success |
| 289 | manifest-r2 | references: alias | reject or rollback without downgrade, raw disclosure, or false success |
| 290 | artifact-verifier | source-open: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 291 | artifact-verifier | source-open: revision2-valid | accept only canonical fail-closed state |
| 292 | artifact-verifier | source-open: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 293 | artifact-verifier | source-open: race | reject or rollback without downgrade, raw disclosure, or false success |
| 294 | artifact-verifier | type: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 295 | artifact-verifier | type: revision2-valid | accept only canonical fail-closed state |
| 296 | artifact-verifier | type: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 297 | artifact-verifier | type: race | reject or rollback without downgrade, raw disclosure, or false success |
| 298 | artifact-verifier | links: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 299 | artifact-verifier | links: revision2-valid | accept only canonical fail-closed state |
| 300 | artifact-verifier | links: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 301 | artifact-verifier | links: race | reject or rollback without downgrade, raw disclosure, or false success |
| 302 | artifact-verifier | size: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 303 | artifact-verifier | size: revision2-valid | accept only canonical fail-closed state |
| 304 | artifact-verifier | size: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 305 | artifact-verifier | size: race | reject or rollback without downgrade, raw disclosure, or false success |
| 306 | artifact-verifier | digest: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 307 | artifact-verifier | digest: revision2-valid | accept only canonical fail-closed state |
| 308 | artifact-verifier | digest: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 309 | artifact-verifier | digest: race | reject or rollback without downgrade, raw disclosure, or false success |
| 310 | artifact-verifier | stability: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 311 | artifact-verifier | stability: revision2-valid | accept only canonical fail-closed state |
| 312 | artifact-verifier | stability: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 313 | artifact-verifier | stability: race | reject or rollback without downgrade, raw disclosure, or false success |
| 314 | artifact-verifier | class: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 315 | artifact-verifier | class: revision2-valid | accept only canonical fail-closed state |
| 316 | artifact-verifier | class: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 317 | artifact-verifier | class: race | reject or rollback without downgrade, raw disclosure, or false success |
| 318 | artifact-verifier | mode: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 319 | artifact-verifier | mode: revision2-valid | accept only canonical fail-closed state |
| 320 | artifact-verifier | mode: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 321 | artifact-verifier | mode: race | reject or rollback without downgrade, raw disclosure, or false success |
| 322 | artifact-verifier | owner: revision1 | reject or rollback without downgrade, raw disclosure, or false success |
| 323 | artifact-verifier | owner: revision2-valid | accept only canonical fail-closed state |
| 324 | artifact-verifier | owner: revision2-invalid | reject or rollback without downgrade, raw disclosure, or false success |
| 325 | artifact-verifier | owner: race | reject or rollback without downgrade, raw disclosure, or false success |
| 326 | publication | manifest: success | accept only canonical fail-closed state |
| 327 | publication | manifest: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 328 | publication | manifest: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 329 | publication | manifest: race | reject or rollback without downgrade, raw disclosure, or false success |
| 330 | publication | workspace: success | accept only canonical fail-closed state |
| 331 | publication | workspace: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 332 | publication | workspace: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 333 | publication | workspace: race | reject or rollback without downgrade, raw disclosure, or false success |
| 334 | publication | writer: success | accept only canonical fail-closed state |
| 335 | publication | writer: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 336 | publication | writer: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 337 | publication | writer: race | reject or rollback without downgrade, raw disclosure, or false success |
| 338 | publication | pre-protection: success | accept only canonical fail-closed state |
| 339 | publication | pre-protection: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 340 | publication | pre-protection: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 341 | publication | pre-protection: race | reject or rollback without downgrade, raw disclosure, or false success |
| 342 | publication | lock: success | accept only canonical fail-closed state |
| 343 | publication | lock: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 344 | publication | lock: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 345 | publication | lock: race | reject or rollback without downgrade, raw disclosure, or false success |
| 346 | publication | directory-rename: success | accept only canonical fail-closed state |
| 347 | publication | directory-rename: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 348 | publication | directory-rename: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 349 | publication | directory-rename: race | reject or rollback without downgrade, raw disclosure, or false success |
| 350 | publication | final-manifest: success | accept only canonical fail-closed state |
| 351 | publication | final-manifest: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 352 | publication | final-manifest: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 353 | publication | final-manifest: race | reject or rollback without downgrade, raw disclosure, or false success |
| 354 | publication | post-protection: success | accept only canonical fail-closed state |
| 355 | publication | post-protection: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 356 | publication | post-protection: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 357 | publication | post-protection: race | reject or rollback without downgrade, raw disclosure, or false success |
| 358 | publication | parent-sync: success | accept only canonical fail-closed state |
| 359 | publication | parent-sync: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 360 | publication | parent-sync: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 361 | publication | parent-sync: race | reject or rollback without downgrade, raw disclosure, or false success |
| 362 | publication | rollback: success | accept only canonical fail-closed state |
| 363 | publication | rollback: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 364 | publication | rollback: collision | reject or rollback without downgrade, raw disclosure, or false success |
| 365 | publication | rollback: race | reject or rollback without downgrade, raw disclosure, or false success |
| 366 | restore-staging | source-copy: legacy | accept only canonical fail-closed state |
| 367 | restore-staging | source-copy: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 368 | restore-staging | source-copy: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 369 | restore-staging | source-copy: race | reject or rollback without downgrade, raw disclosure, or false success |
| 370 | restore-staging | root-identity: legacy | accept only canonical fail-closed state |
| 371 | restore-staging | root-identity: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 372 | restore-staging | root-identity: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 373 | restore-staging | root-identity: race | reject or rollback without downgrade, raw disclosure, or false success |
| 374 | restore-staging | payload-identity: legacy | accept only canonical fail-closed state |
| 375 | restore-staging | payload-identity: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 376 | restore-staging | payload-identity: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 377 | restore-staging | payload-identity: race | reject or rollback without downgrade, raw disclosure, or false success |
| 378 | restore-staging | owner: legacy | accept only canonical fail-closed state |
| 379 | restore-staging | owner: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 380 | restore-staging | owner: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 381 | restore-staging | owner: race | reject or rollback without downgrade, raw disclosure, or false success |
| 382 | restore-staging | mode: legacy | accept only canonical fail-closed state |
| 383 | restore-staging | mode: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 384 | restore-staging | mode: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 385 | restore-staging | mode: race | reject or rollback without downgrade, raw disclosure, or false success |
| 386 | restore-staging | class-set: legacy | accept only canonical fail-closed state |
| 387 | restore-staging | class-set: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 388 | restore-staging | class-set: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 389 | restore-staging | class-set: race | reject or rollback without downgrade, raw disclosure, or false success |
| 390 | restore-staging | class-read: legacy | accept only canonical fail-closed state |
| 391 | restore-staging | class-read: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 392 | restore-staging | class-read: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 393 | restore-staging | class-read: race | reject or rollback without downgrade, raw disclosure, or false success |
| 394 | restore-staging | fsync: legacy | accept only canonical fail-closed state |
| 395 | restore-staging | fsync: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 396 | restore-staging | fsync: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 397 | restore-staging | fsync: race | reject or rollback without downgrade, raw disclosure, or false success |
| 398 | restore-staging | namespace: legacy | accept only canonical fail-closed state |
| 399 | restore-staging | namespace: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 400 | restore-staging | namespace: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 401 | restore-staging | namespace: race | reject or rollback without downgrade, raw disclosure, or false success |
| 402 | restore-staging | cleanup: legacy | accept only canonical fail-closed state |
| 403 | restore-staging | cleanup: revision2 | reject or rollback without downgrade, raw disclosure, or false success |
| 404 | restore-staging | cleanup: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 405 | restore-staging | cleanup: race | reject or rollback without downgrade, raw disclosure, or false success |
| 406 | bridge-boundary | export-open: success | accept only canonical fail-closed state |
| 407 | bridge-boundary | export-open: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 408 | bridge-boundary | export-open: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 409 | bridge-boundary | export-open: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 410 | bridge-boundary | export-protect: success | accept only canonical fail-closed state |
| 411 | bridge-boundary | export-protect: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 412 | bridge-boundary | export-protect: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 413 | bridge-boundary | export-protect: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 414 | bridge-boundary | export-copy: success | accept only canonical fail-closed state |
| 415 | bridge-boundary | export-copy: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 416 | bridge-boundary | export-copy: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 417 | bridge-boundary | export-copy: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 418 | bridge-boundary | import-copy: success | accept only canonical fail-closed state |
| 419 | bridge-boundary | import-copy: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 420 | bridge-boundary | import-copy: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 421 | bridge-boundary | import-copy: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 422 | bridge-boundary | import-open: success | accept only canonical fail-closed state |
| 423 | bridge-boundary | import-open: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 424 | bridge-boundary | import-open: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 425 | bridge-boundary | import-open: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 426 | bridge-boundary | import-protect: success | accept only canonical fail-closed state |
| 427 | bridge-boundary | import-protect: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 428 | bridge-boundary | import-protect: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 429 | bridge-boundary | import-protect: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 430 | bridge-boundary | request-write: success | accept only canonical fail-closed state |
| 431 | bridge-boundary | request-write: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 432 | bridge-boundary | request-write: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 433 | bridge-boundary | request-write: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 434 | bridge-boundary | notification: success | accept only canonical fail-closed state |
| 435 | bridge-boundary | notification: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 436 | bridge-boundary | notification: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 437 | bridge-boundary | notification: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 438 | bridge-boundary | cleanup: success | accept only canonical fail-closed state |
| 439 | bridge-boundary | cleanup: failure | reject or rollback without downgrade, raw disclosure, or false success |
| 440 | bridge-boundary | cleanup: replacement | reject or rollback without downgrade, raw disclosure, or false success |
| 441 | bridge-boundary | cleanup: lock | reject or rollback without downgrade, raw disclosure, or false success |
| 442 | privacy | NSError: path | reject or rollback without downgrade, raw disclosure, or false success |
| 443 | privacy | NSError: descriptor | reject or rollback without downgrade, raw disclosure, or false success |
| 444 | privacy | NSError: uid-gid | reject or rollback without downgrade, raw disclosure, or false success |
| 445 | privacy | NSError: class-value | reject or rollback without downgrade, raw disclosure, or false success |
| 446 | privacy | NSError: errno | reject or rollback without downgrade, raw disclosure, or false success |
| 447 | privacy | NSError: content | reject or rollback without downgrade, raw disclosure, or false success |
| 448 | privacy | NSError: safe-summary | accept only canonical fail-closed state |
| 449 | privacy | warning: path | reject or rollback without downgrade, raw disclosure, or false success |
| 450 | privacy | warning: descriptor | reject or rollback without downgrade, raw disclosure, or false success |
| 451 | privacy | warning: uid-gid | reject or rollback without downgrade, raw disclosure, or false success |
| 452 | privacy | warning: class-value | reject or rollback without downgrade, raw disclosure, or false success |
| 453 | privacy | warning: errno | reject or rollback without downgrade, raw disclosure, or false success |
| 454 | privacy | warning: content | reject or rollback without downgrade, raw disclosure, or false success |
| 455 | privacy | warning: safe-summary | accept only canonical fail-closed state |
| 456 | privacy | debug: path | reject or rollback without downgrade, raw disclosure, or false success |
| 457 | privacy | debug: descriptor | reject or rollback without downgrade, raw disclosure, or false success |
| 458 | privacy | debug: uid-gid | reject or rollback without downgrade, raw disclosure, or false success |
| 459 | privacy | debug: class-value | reject or rollback without downgrade, raw disclosure, or false success |
| 460 | privacy | debug: errno | reject or rollback without downgrade, raw disclosure, or false success |
| 461 | privacy | debug: content | reject or rollback without downgrade, raw disclosure, or false success |
| 462 | privacy | debug: safe-summary | accept only canonical fail-closed state |
| 463 | privacy | manifest: path | reject or rollback without downgrade, raw disclosure, or false success |
| 464 | privacy | manifest: descriptor | reject or rollback without downgrade, raw disclosure, or false success |
| 465 | privacy | manifest: uid-gid | reject or rollback without downgrade, raw disclosure, or false success |
| 466 | privacy | manifest: class-value | reject or rollback without downgrade, raw disclosure, or false success |
| 467 | privacy | manifest: errno | reject or rollback without downgrade, raw disclosure, or false success |
| 468 | privacy | manifest: content | reject or rollback without downgrade, raw disclosure, or false success |
| 469 | privacy | manifest: safe-summary | accept only canonical fail-closed state |
| 470 | privacy | report: path | reject or rollback without downgrade, raw disclosure, or false success |
| 471 | privacy | report: descriptor | reject or rollback without downgrade, raw disclosure, or false success |
| 472 | privacy | report: uid-gid | reject or rollback without downgrade, raw disclosure, or false success |
| 473 | privacy | report: class-value | reject or rollback without downgrade, raw disclosure, or false success |
| 474 | privacy | report: errno | reject or rollback without downgrade, raw disclosure, or false success |
| 475 | privacy | report: content | reject or rollback without downgrade, raw disclosure, or false success |
| 476 | privacy | report: safe-summary | accept only canonical fail-closed state |
| 477 | non-regression | V2-result: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 478 | non-regression | V2-result: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 479 | non-regression | V2-result: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 480 | non-regression | V2-result: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 481 | non-regression | exit-taxonomy: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 482 | non-regression | exit-taxonomy: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 483 | non-regression | exit-taxonomy: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 484 | non-regression | exit-taxonomy: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 485 | non-regression | identity: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 486 | non-regression | identity: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 487 | non-regression | identity: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 488 | non-regression | identity: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 489 | non-regression | upsert: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 490 | non-regression | upsert: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 491 | non-regression | upsert: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 492 | non-regression | upsert: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 493 | non-regression | workspace: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 494 | non-regression | workspace: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 495 | non-regression | workspace: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 496 | non-regression | workspace: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 497 | non-regression | groups: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 498 | non-regression | groups: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 499 | non-regression | groups: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 500 | non-regression | groups: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 501 | non-regression | partial-integration: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 502 | non-regression | partial-integration: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 503 | non-regression | partial-integration: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 504 | non-regression | partial-integration: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 505 | non-regression | Makefile: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 506 | non-regression | Makefile: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 507 | non-regression | Makefile: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 508 | non-regression | Makefile: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 509 | non-regression | bridge: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 510 | non-regression | bridge: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 511 | non-regression | bridge: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 512 | non-regression | bridge: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 513 | non-regression | Keychain-core: hash | reject or rollback without downgrade, raw disclosure, or false success |
| 514 | non-regression | Keychain-core: operation-count | reject or rollback without downgrade, raw disclosure, or false success |
| 515 | non-regression | Keychain-core: schema | reject or rollback without downgrade, raw disclosure, or false success |
| 516 | non-regression | Keychain-core: scope | reject or rollback without downgrade, raw disclosure, or false success |
| 517 | cross-stage-race | mode mutation at apply case 1 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 518 | cross-stage-race | mode mutation at digest case 2 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 519 | cross-stage-race | mode mutation at artifact-rename case 3 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 520 | cross-stage-race | mode mutation at manifest-write case 4 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 521 | cross-stage-race | mode mutation at pre-publication case 5 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 522 | cross-stage-race | mode mutation at directory-rename case 6 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 523 | cross-stage-race | mode mutation at post-publication case 7 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 524 | cross-stage-race | mode mutation at restore-stage case 8 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 525 | cross-stage-race | mode mutation at bridge-notify case 9 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 526 | cross-stage-race | owner mutation at apply case 10 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 527 | cross-stage-race | owner mutation at digest case 11 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 528 | cross-stage-race | owner mutation at artifact-rename case 12 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 529 | cross-stage-race | owner mutation at manifest-write case 13 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 530 | cross-stage-race | owner mutation at pre-publication case 14 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 531 | cross-stage-race | owner mutation at directory-rename case 15 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 532 | cross-stage-race | owner mutation at post-publication case 16 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 533 | cross-stage-race | owner mutation at restore-stage case 17 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 534 | cross-stage-race | owner mutation at bridge-notify case 18 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 535 | cross-stage-race | link-count mutation at apply case 19 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 536 | cross-stage-race | link-count mutation at digest case 20 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 537 | cross-stage-race | link-count mutation at artifact-rename case 21 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 538 | cross-stage-race | link-count mutation at manifest-write case 22 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 539 | cross-stage-race | link-count mutation at pre-publication case 23 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 540 | cross-stage-race | link-count mutation at directory-rename case 24 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 541 | cross-stage-race | link-count mutation at post-publication case 25 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 542 | cross-stage-race | link-count mutation at restore-stage case 26 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 543 | cross-stage-race | link-count mutation at bridge-notify case 27 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 544 | cross-stage-race | class mutation at apply case 28 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 545 | cross-stage-race | class mutation at digest case 29 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 546 | cross-stage-race | class mutation at artifact-rename case 30 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 547 | cross-stage-race | class mutation at manifest-write case 31 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 548 | cross-stage-race | class mutation at pre-publication case 32 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 549 | cross-stage-race | class mutation at directory-rename case 33 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 550 | cross-stage-race | class mutation at post-publication case 34 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 551 | cross-stage-race | class mutation at restore-stage case 35 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 552 | cross-stage-race | class mutation at bridge-notify case 36 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 553 | cross-stage-race | inode mutation at apply case 37 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 554 | cross-stage-race | inode mutation at digest case 38 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 555 | cross-stage-race | inode mutation at artifact-rename case 39 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 556 | cross-stage-race | inode mutation at manifest-write case 40 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 557 | cross-stage-race | inode mutation at pre-publication case 41 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 558 | cross-stage-race | inode mutation at directory-rename case 42 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 559 | cross-stage-race | inode mutation at post-publication case 43 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 560 | cross-stage-race | inode mutation at restore-stage case 44 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 561 | cross-stage-race | inode mutation at bridge-notify case 45 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 562 | cross-stage-race | size mutation at apply case 46 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 563 | cross-stage-race | size mutation at digest case 47 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 564 | cross-stage-race | size mutation at artifact-rename case 48 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 565 | cross-stage-race | size mutation at manifest-write case 49 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 566 | cross-stage-race | size mutation at pre-publication case 50 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 567 | cross-stage-race | size mutation at directory-rename case 51 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 568 | cross-stage-race | size mutation at post-publication case 52 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 569 | cross-stage-race | size mutation at restore-stage case 53 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 570 | cross-stage-race | size mutation at bridge-notify case 54 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 571 | cross-stage-race | manifest mutation at apply case 55 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 572 | cross-stage-race | manifest mutation at digest case 56 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 573 | cross-stage-race | manifest mutation at artifact-rename case 57 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 574 | cross-stage-race | manifest mutation at manifest-write case 58 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 575 | cross-stage-race | manifest mutation at pre-publication case 59 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 576 | cross-stage-race | manifest mutation at directory-rename case 60 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 577 | cross-stage-race | manifest mutation at post-publication case 61 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 578 | cross-stage-race | manifest mutation at restore-stage case 62 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 579 | cross-stage-race | manifest mutation at bridge-notify case 63 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 580 | cross-stage-race | namespace mutation at apply case 64 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 581 | cross-stage-race | namespace mutation at digest case 65 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 582 | cross-stage-race | namespace mutation at artifact-rename case 66 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 583 | cross-stage-race | namespace mutation at manifest-write case 67 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 584 | cross-stage-race | namespace mutation at pre-publication case 68 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 585 | cross-stage-race | namespace mutation at directory-rename case 69 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 586 | cross-stage-race | namespace mutation at post-publication case 70 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 587 | cross-stage-race | namespace mutation at restore-stage case 71 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 588 | cross-stage-race | namespace mutation at bridge-notify case 72 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 589 | cross-stage-race | mode mutation at apply case 73 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 590 | cross-stage-race | mode mutation at digest case 74 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 591 | cross-stage-race | mode mutation at artifact-rename case 75 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 592 | cross-stage-race | mode mutation at manifest-write case 76 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 593 | cross-stage-race | mode mutation at pre-publication case 77 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 594 | cross-stage-race | mode mutation at directory-rename case 78 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 595 | cross-stage-race | mode mutation at post-publication case 79 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 596 | cross-stage-race | mode mutation at restore-stage case 80 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 597 | cross-stage-race | mode mutation at bridge-notify case 81 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 598 | cross-stage-race | owner mutation at apply case 82 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 599 | cross-stage-race | owner mutation at digest case 83 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 600 | cross-stage-race | owner mutation at artifact-rename case 84 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 601 | cross-stage-race | owner mutation at manifest-write case 85 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 602 | cross-stage-race | owner mutation at pre-publication case 86 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 603 | cross-stage-race | owner mutation at directory-rename case 87 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 604 | cross-stage-race | owner mutation at post-publication case 88 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 605 | cross-stage-race | owner mutation at restore-stage case 89 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 606 | cross-stage-race | owner mutation at bridge-notify case 90 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 607 | cross-stage-race | link-count mutation at apply case 91 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 608 | cross-stage-race | link-count mutation at digest case 92 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 609 | cross-stage-race | link-count mutation at artifact-rename case 93 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 610 | cross-stage-race | link-count mutation at manifest-write case 94 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 611 | cross-stage-race | link-count mutation at pre-publication case 95 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 612 | cross-stage-race | link-count mutation at directory-rename case 96 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 613 | cross-stage-race | link-count mutation at post-publication case 97 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 614 | cross-stage-race | link-count mutation at restore-stage case 98 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 615 | cross-stage-race | link-count mutation at bridge-notify case 99 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 616 | cross-stage-race | class mutation at apply case 100 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 617 | cross-stage-race | class mutation at digest case 101 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 618 | cross-stage-race | class mutation at artifact-rename case 102 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 619 | cross-stage-race | class mutation at manifest-write case 103 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 620 | cross-stage-race | class mutation at pre-publication case 104 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 621 | cross-stage-race | class mutation at directory-rename case 105 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 622 | cross-stage-race | class mutation at post-publication case 106 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 623 | cross-stage-race | class mutation at restore-stage case 107 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 624 | cross-stage-race | class mutation at bridge-notify case 108 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 625 | cross-stage-race | inode mutation at apply case 109 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 626 | cross-stage-race | inode mutation at digest case 110 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 627 | cross-stage-race | inode mutation at artifact-rename case 111 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 628 | cross-stage-race | inode mutation at manifest-write case 112 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 629 | cross-stage-race | inode mutation at pre-publication case 113 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 630 | cross-stage-race | inode mutation at directory-rename case 114 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 631 | cross-stage-race | inode mutation at post-publication case 115 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 632 | cross-stage-race | inode mutation at restore-stage case 116 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 633 | cross-stage-race | inode mutation at bridge-notify case 117 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 634 | cross-stage-race | size mutation at apply case 118 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 635 | cross-stage-race | size mutation at digest case 119 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 636 | cross-stage-race | size mutation at artifact-rename case 120 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 637 | cross-stage-race | size mutation at manifest-write case 121 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 638 | cross-stage-race | size mutation at pre-publication case 122 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 639 | cross-stage-race | size mutation at directory-rename case 123 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 640 | cross-stage-race | size mutation at post-publication case 124 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 641 | cross-stage-race | size mutation at restore-stage case 125 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 642 | cross-stage-race | size mutation at bridge-notify case 126 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 643 | cross-stage-race | manifest mutation at apply case 127 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 644 | cross-stage-race | manifest mutation at digest case 128 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 645 | cross-stage-race | manifest mutation at artifact-rename case 129 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 646 | cross-stage-race | manifest mutation at manifest-write case 130 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 647 | cross-stage-race | manifest mutation at pre-publication case 131 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 648 | cross-stage-race | manifest mutation at directory-rename case 132 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 649 | cross-stage-race | manifest mutation at post-publication case 133 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 650 | cross-stage-race | manifest mutation at restore-stage case 134 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 651 | cross-stage-race | manifest mutation at bridge-notify case 135 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 652 | cross-stage-race | namespace mutation at apply case 136 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 653 | cross-stage-race | namespace mutation at digest case 137 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 654 | cross-stage-race | namespace mutation at artifact-rename case 138 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 655 | cross-stage-race | namespace mutation at manifest-write case 139 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 656 | cross-stage-race | namespace mutation at pre-publication case 140 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 657 | cross-stage-race | namespace mutation at directory-rename case 141 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 658 | cross-stage-race | namespace mutation at post-publication case 142 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 659 | cross-stage-race | namespace mutation at restore-stage case 143 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 660 | cross-stage-race | namespace mutation at bridge-notify case 144 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 661 | cross-stage-race | mode mutation at apply case 145 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 662 | cross-stage-race | mode mutation at digest case 146 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 663 | cross-stage-race | mode mutation at artifact-rename case 147 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 664 | cross-stage-race | mode mutation at manifest-write case 148 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 665 | cross-stage-race | mode mutation at pre-publication case 149 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 666 | cross-stage-race | mode mutation at directory-rename case 150 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 667 | cross-stage-race | mode mutation at post-publication case 151 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 668 | cross-stage-race | mode mutation at restore-stage case 152 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 669 | cross-stage-race | mode mutation at bridge-notify case 153 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 670 | cross-stage-race | owner mutation at apply case 154 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 671 | cross-stage-race | owner mutation at digest case 155 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 672 | cross-stage-race | owner mutation at artifact-rename case 156 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 673 | cross-stage-race | owner mutation at manifest-write case 157 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 674 | cross-stage-race | owner mutation at pre-publication case 158 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 675 | cross-stage-race | owner mutation at directory-rename case 159 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 676 | cross-stage-race | owner mutation at post-publication case 160 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 677 | cross-stage-race | owner mutation at restore-stage case 161 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 678 | cross-stage-race | owner mutation at bridge-notify case 162 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 679 | cross-stage-race | link-count mutation at apply case 163 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 680 | cross-stage-race | link-count mutation at digest case 164 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 681 | cross-stage-race | link-count mutation at artifact-rename case 165 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 682 | cross-stage-race | link-count mutation at manifest-write case 166 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 683 | cross-stage-race | link-count mutation at pre-publication case 167 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 684 | cross-stage-race | link-count mutation at directory-rename case 168 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 685 | cross-stage-race | link-count mutation at post-publication case 169 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 686 | cross-stage-race | link-count mutation at restore-stage case 170 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 687 | cross-stage-race | link-count mutation at bridge-notify case 171 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 688 | cross-stage-race | class mutation at apply case 172 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 689 | cross-stage-race | class mutation at digest case 173 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 690 | cross-stage-race | class mutation at artifact-rename case 174 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 691 | cross-stage-race | class mutation at manifest-write case 175 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 692 | cross-stage-race | class mutation at pre-publication case 176 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 693 | cross-stage-race | class mutation at directory-rename case 177 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 694 | cross-stage-race | class mutation at post-publication case 178 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 695 | cross-stage-race | class mutation at restore-stage case 179 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 696 | cross-stage-race | class mutation at bridge-notify case 180 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 697 | cross-stage-race | inode mutation at apply case 181 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 698 | cross-stage-race | inode mutation at digest case 182 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 699 | cross-stage-race | inode mutation at artifact-rename case 183 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 700 | cross-stage-race | inode mutation at manifest-write case 184 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 701 | cross-stage-race | inode mutation at pre-publication case 185 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 702 | cross-stage-race | inode mutation at directory-rename case 186 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 703 | cross-stage-race | inode mutation at post-publication case 187 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 704 | cross-stage-race | inode mutation at restore-stage case 188 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 705 | cross-stage-race | inode mutation at bridge-notify case 189 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 706 | cross-stage-race | size mutation at apply case 190 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 707 | cross-stage-race | size mutation at digest case 191 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 708 | cross-stage-race | size mutation at artifact-rename case 192 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 709 | cross-stage-race | size mutation at manifest-write case 193 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 710 | cross-stage-race | size mutation at pre-publication case 194 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 711 | cross-stage-race | size mutation at directory-rename case 195 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 712 | cross-stage-race | size mutation at post-publication case 196 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 713 | cross-stage-race | size mutation at restore-stage case 197 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 714 | cross-stage-race | size mutation at bridge-notify case 198 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 715 | cross-stage-race | manifest mutation at apply case 199 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 716 | cross-stage-race | manifest mutation at digest case 200 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 717 | cross-stage-race | manifest mutation at artifact-rename case 201 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 718 | cross-stage-race | manifest mutation at manifest-write case 202 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 719 | cross-stage-race | manifest mutation at pre-publication case 203 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 720 | cross-stage-race | manifest mutation at directory-rename case 204 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 721 | cross-stage-race | manifest mutation at post-publication case 205 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 722 | cross-stage-race | manifest mutation at restore-stage case 206 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 723 | cross-stage-race | manifest mutation at bridge-notify case 207 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 724 | cross-stage-race | namespace mutation at apply case 208 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 725 | cross-stage-race | namespace mutation at digest case 209 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 726 | cross-stage-race | namespace mutation at artifact-rename case 210 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 727 | cross-stage-race | namespace mutation at manifest-write case 211 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 728 | cross-stage-race | namespace mutation at pre-publication case 212 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 729 | cross-stage-race | namespace mutation at directory-rename case 213 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 730 | cross-stage-race | namespace mutation at post-publication case 214 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 731 | cross-stage-race | namespace mutation at restore-stage case 215 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 732 | cross-stage-race | namespace mutation at bridge-notify case 216 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 733 | cross-stage-race | mode mutation at apply case 217 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 734 | cross-stage-race | mode mutation at digest case 218 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 735 | cross-stage-race | mode mutation at artifact-rename case 219 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 736 | cross-stage-race | mode mutation at manifest-write case 220 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 737 | cross-stage-race | mode mutation at pre-publication case 221 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 738 | cross-stage-race | mode mutation at directory-rename case 222 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 739 | cross-stage-race | mode mutation at post-publication case 223 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 740 | cross-stage-race | mode mutation at restore-stage case 224 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 741 | cross-stage-race | mode mutation at bridge-notify case 225 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 742 | cross-stage-race | owner mutation at apply case 226 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 743 | cross-stage-race | owner mutation at digest case 227 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 744 | cross-stage-race | owner mutation at artifact-rename case 228 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 745 | cross-stage-race | owner mutation at manifest-write case 229 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 746 | cross-stage-race | owner mutation at pre-publication case 230 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 747 | cross-stage-race | owner mutation at directory-rename case 231 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 748 | cross-stage-race | owner mutation at post-publication case 232 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 749 | cross-stage-race | owner mutation at restore-stage case 233 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 750 | cross-stage-race | owner mutation at bridge-notify case 234 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 751 | cross-stage-race | link-count mutation at apply case 235 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 752 | cross-stage-race | link-count mutation at digest case 236 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 753 | cross-stage-race | link-count mutation at artifact-rename case 237 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 754 | cross-stage-race | link-count mutation at manifest-write case 238 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 755 | cross-stage-race | link-count mutation at pre-publication case 239 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 756 | cross-stage-race | link-count mutation at directory-rename case 240 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 757 | cross-stage-race | link-count mutation at post-publication case 241 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 758 | cross-stage-race | link-count mutation at restore-stage case 242 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 759 | cross-stage-race | link-count mutation at bridge-notify case 243 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 760 | cross-stage-race | class mutation at apply case 244 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 761 | cross-stage-race | class mutation at digest case 245 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 762 | cross-stage-race | class mutation at artifact-rename case 246 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 763 | cross-stage-race | class mutation at manifest-write case 247 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 764 | cross-stage-race | class mutation at pre-publication case 248 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 765 | cross-stage-race | class mutation at directory-rename case 249 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 766 | cross-stage-race | class mutation at post-publication case 250 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 767 | cross-stage-race | class mutation at restore-stage case 251 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 768 | cross-stage-race | class mutation at bridge-notify case 252 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 769 | cross-stage-race | inode mutation at apply case 253 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 770 | cross-stage-race | inode mutation at digest case 254 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 771 | cross-stage-race | inode mutation at artifact-rename case 255 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 772 | cross-stage-race | inode mutation at manifest-write case 256 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 773 | cross-stage-race | inode mutation at pre-publication case 257 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 774 | cross-stage-race | inode mutation at directory-rename case 258 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 775 | cross-stage-race | inode mutation at post-publication case 259 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 776 | cross-stage-race | inode mutation at restore-stage case 260 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 777 | cross-stage-race | inode mutation at bridge-notify case 261 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 778 | cross-stage-race | size mutation at apply case 262 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 779 | cross-stage-race | size mutation at digest case 263 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 780 | cross-stage-race | size mutation at artifact-rename case 264 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 781 | cross-stage-race | size mutation at manifest-write case 265 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 782 | cross-stage-race | size mutation at pre-publication case 266 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 783 | cross-stage-race | size mutation at directory-rename case 267 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 784 | cross-stage-race | size mutation at post-publication case 268 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 785 | cross-stage-race | size mutation at restore-stage case 269 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 786 | cross-stage-race | size mutation at bridge-notify case 270 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 787 | cross-stage-race | manifest mutation at apply case 271 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 788 | cross-stage-race | manifest mutation at digest case 272 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 789 | cross-stage-race | manifest mutation at artifact-rename case 273 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 790 | cross-stage-race | manifest mutation at manifest-write case 274 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 791 | cross-stage-race | manifest mutation at pre-publication case 275 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 792 | cross-stage-race | manifest mutation at directory-rename case 276 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 793 | cross-stage-race | manifest mutation at post-publication case 277 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 794 | cross-stage-race | manifest mutation at restore-stage case 278 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 795 | cross-stage-race | manifest mutation at bridge-notify case 279 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 796 | cross-stage-race | namespace mutation at apply case 280 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 797 | cross-stage-race | namespace mutation at digest case 281 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 798 | cross-stage-race | namespace mutation at artifact-rename case 282 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 799 | cross-stage-race | namespace mutation at manifest-write case 283 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 800 | cross-stage-race | namespace mutation at pre-publication case 284 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 801 | cross-stage-race | namespace mutation at directory-rename case 285 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 802 | cross-stage-race | namespace mutation at post-publication case 286 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 803 | cross-stage-race | namespace mutation at restore-stage case 287 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 804 | cross-stage-race | namespace mutation at bridge-notify case 288 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 805 | cross-stage-race | mode mutation at apply case 289 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 806 | cross-stage-race | mode mutation at digest case 290 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 807 | cross-stage-race | mode mutation at artifact-rename case 291 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 808 | cross-stage-race | mode mutation at manifest-write case 292 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 809 | cross-stage-race | mode mutation at pre-publication case 293 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 810 | cross-stage-race | mode mutation at directory-rename case 294 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 811 | cross-stage-race | mode mutation at post-publication case 295 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 812 | cross-stage-race | mode mutation at restore-stage case 296 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 813 | cross-stage-race | mode mutation at bridge-notify case 297 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 814 | cross-stage-race | owner mutation at apply case 298 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 815 | cross-stage-race | owner mutation at digest case 299 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 816 | cross-stage-race | owner mutation at artifact-rename case 300 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 817 | cross-stage-race | owner mutation at manifest-write case 301 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 818 | cross-stage-race | owner mutation at pre-publication case 302 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 819 | cross-stage-race | owner mutation at directory-rename case 303 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 820 | cross-stage-race | owner mutation at post-publication case 304 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 821 | cross-stage-race | owner mutation at restore-stage case 305 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 822 | cross-stage-race | owner mutation at bridge-notify case 306 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 823 | cross-stage-race | link-count mutation at apply case 307 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 824 | cross-stage-race | link-count mutation at digest case 308 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 825 | cross-stage-race | link-count mutation at artifact-rename case 309 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 826 | cross-stage-race | link-count mutation at manifest-write case 310 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 827 | cross-stage-race | link-count mutation at pre-publication case 311 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 828 | cross-stage-race | link-count mutation at directory-rename case 312 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 829 | cross-stage-race | link-count mutation at post-publication case 313 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 830 | cross-stage-race | link-count mutation at restore-stage case 314 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 831 | cross-stage-race | link-count mutation at bridge-notify case 315 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 832 | cross-stage-race | class mutation at apply case 316 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 833 | cross-stage-race | class mutation at digest case 317 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 834 | cross-stage-race | class mutation at artifact-rename case 318 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 835 | cross-stage-race | class mutation at manifest-write case 319 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 836 | cross-stage-race | class mutation at pre-publication case 320 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 837 | cross-stage-race | class mutation at directory-rename case 321 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 838 | cross-stage-race | class mutation at post-publication case 322 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 839 | cross-stage-race | class mutation at restore-stage case 323 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 840 | cross-stage-race | class mutation at bridge-notify case 324 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 841 | cross-stage-race | inode mutation at apply case 325 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 842 | cross-stage-race | inode mutation at digest case 326 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 843 | cross-stage-race | inode mutation at artifact-rename case 327 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 844 | cross-stage-race | inode mutation at manifest-write case 328 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 845 | cross-stage-race | inode mutation at pre-publication case 329 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 846 | cross-stage-race | inode mutation at directory-rename case 330 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 847 | cross-stage-race | inode mutation at post-publication case 331 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 848 | cross-stage-race | inode mutation at restore-stage case 332 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 849 | cross-stage-race | inode mutation at bridge-notify case 333 | detect at next authority checkpoint; cleanup or rollback; never report success |
| 850 | cross-stage-race | size mutation at apply case 334 | detect at next authority checkpoint; cleanup or rollback; never report success |

## Objective-C/toolchain status

Objective-C compile/link/package status is PENDING because the Windows host does not provide `clang.exe`, `make.exe`, `xcrun.exe`, or THEOS.

No claim is made for Apple SDK symbol availability, iOS 12 compatibility, arm64/arm64e compilation, ARC compilation, ProjectX link, package build, or Darwin fcntl runtime. The implementation intentionally does not hard-code fcntl commands or protection-class numeric values; missing SDK declarations must fail visibly in Apple CI.

## Device test status

Device tests are PENDING. Static/model evidence cannot prove real Security/Data Protection behavior, protected-data lock transitions, or filesystem support for class-A fcntl operations.

## Line-ending/NUL audit

| File | Before CRLF | After CRLF | NUL | Final newline |
| --- | ---: | ---: | ---: | --- |
| `PXBackupArtifactPolicy.h` | 0 | 0 | 0 | TRUE |
| `PXBackupArtifactPolicy.m` | 0 | 0 | 0 | TRUE |
| `PXBackupArtifactWriter.h` | 0 | 0 | 0 | TRUE |
| `PXBackupArtifactWriter.m` | 0 | 0 | 0 | TRUE |
| `PXBackupManifestV4.m` | 0 | 0 | 0 | TRUE |
| `PXBackupManifestValidator.m` | 0 | 0 | 0 | TRUE |
| `PXBackupArtifactVerifier.h` | 0 | 0 | 0 | TRUE |
| `PXBackupArtifactVerifier.m` | 0 | 0 | 0 | TRUE |
| `PXBackupDirectoryPublisher.h` | 0 | 0 | 0 | TRUE |
| `PXBackupDirectoryPublisher.m` | 0 | 0 | 0 | TRUE |
| `PXOptionalRestoreStaging.h` | 0 | 0 | 0 | TRUE |
| `PXOptionalRestoreStaging.m` | 0 | 0 | 0 | TRUE |
| `AppDataBackupManager.m` | 0 | 0 | 0 | TRUE |
| `PXFileProtection.h` | 0 | 0 | 0 | TRUE |
| `PXFileProtection.m` | 0 | 0 | 0 | TRUE |

## Residual risks

- Apple SDK build and device runtime are not available on this Windows host.
- The unchanged bridge can create predictable `/tmp` export/import names before manager-side protection; manager protection narrows but does not eliminate the bridge creation window.
- Data Protection does not defend against privileged live access while the device is unlocked.
- A backup copied through a filesystem that loses protection metadata is intentionally rejected; no migration/repair flow exists in this task.
- Device lock during backup/restore may cause a fail-closed operation failure; no downgrade is attempted.
- Runtime support and exact behavior of `F_SETPROTECTIONCLASS`, `F_GETPROTECTIONCLASS`, and `PROTECTION_CLASS_A` must be confirmed by Apple CI and device tests.

## Phase 4 closure boundary

TASK-4.9 stops after the descriptor primitive, writer/manifest/verifier/publication integration, restore-stage upgrade, manager cleanup, report, implementation commit, and post-commit evidence.

It does not create a TASK-4.9 review, update coordinator status documents, perform coordinator Phase-4 closure, push the commit, or start Phase 5/Phase 6.

## Full authorized diff

The following is the complete implementation-source diff against the required baseline, excluding this generated report.

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index bba0939..e106a8b 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -30,6 +30,7 @@
 #import "PXMainDataRestoreTransaction.h"
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
+#import "PXFileProtection.h"
 #import "CommandRunner.h"
 #import "PXKeychainHelperInvocationResult.h"
 #import "common/PXProcessKiller.h"
@@ -37,6 +38,13 @@

 #import <notify.h>

+#include <errno.h>
+#include <fcntl.h>
+#include <stdlib.h>
+#include <string.h>
+#include <sys/stat.h>
+#include <unistd.h>
+
 static NSString * const PXBackupErrorDomain = @"com.hydra.projectx.backup";
 static NSString * const PXExactRestoreDestinationErrorDescription =
     @"Exact application data container could not be resolved safely";
@@ -44,6 +52,70 @@ static const NSTimeInterval PXKeychainHelperInvocationTimeoutSeconds = 300.0;
 static const NSUInteger PXKeychainHelperInvocationOutputLimitBytes = 1024 * 1024;
 static const NSUInteger PXKeychainBackupPlistMaximumBytes = 64 * 1024 * 1024;

+static BOOL PXProtectOwnedKeychainTemporaryFileAtPath(NSString *filePath) {
+    if (![filePath isKindOfClass:[NSString class]] || filePath.length == 0) {
+        return NO;
+    }
+    NSData *pathData = [filePath dataUsingEncoding:NSUTF8StringEncoding
+                              allowLossyConversion:NO];
+    if (!pathData || pathData.length == 0 || pathData.length > 4096 ||
+        memchr(pathData.bytes, 0, pathData.length) != NULL) {
+        return NO;
+    }
+    char *pathBytes = calloc(pathData.length + 1, 1);
+    if (!pathBytes) return NO;
+    memcpy(pathBytes, pathData.bytes, pathData.length);
+    struct stat namespaceBefore;
+    int statResult = -1;
+    do {
+        statResult = lstat(pathBytes, &namespaceBefore);
+    } while (statResult < 0 && errno == EINTR);
+    if (statResult != 0 || !S_ISREG(namespaceBefore.st_mode) ||
+        namespaceBefore.st_nlink != 1 ||
+        namespaceBefore.st_uid != geteuid() ||
+        namespaceBefore.st_gid != getegid()) {
+        free(pathBytes);
+        return NO;
+    }
+    int descriptor = -1;
+    do {
+        descriptor = open(pathBytes,
+                          O_RDWR | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    } while (descriptor < 0 && errno == EINTR);
+    if (descriptor < 0) {
+        free(pathBytes);
+        return NO;
+    }
+    struct stat descriptorBefore;
+    BOOL valid = fstat(descriptor, &descriptorBefore) == 0 &&
+        descriptorBefore.st_dev == namespaceBefore.st_dev &&
+        descriptorBefore.st_ino == namespaceBefore.st_ino &&
+        S_ISREG(descriptorBefore.st_mode) &&
+        descriptorBefore.st_nlink == 1 &&
+        descriptorBefore.st_uid == geteuid() &&
+        descriptorBefore.st_gid == getegid() &&
+        PXApplyCompleteFileProtectionToDescriptor(descriptor, NULL) &&
+        PXVerifyCompleteFileProtectionOnDescriptor(descriptor, NULL);
+    struct stat descriptorAfter;
+    struct stat namespaceAfter;
+    if (valid) {
+        valid = fstat(descriptor, &descriptorAfter) == 0 &&
+            descriptorAfter.st_dev == descriptorBefore.st_dev &&
+            descriptorAfter.st_ino == descriptorBefore.st_ino &&
+            descriptorAfter.st_size == descriptorBefore.st_size &&
+            lstat(pathBytes, &namespaceAfter) == 0 &&
+            namespaceAfter.st_dev == descriptorAfter.st_dev &&
+            namespaceAfter.st_ino == descriptorAfter.st_ino &&
+            namespaceAfter.st_nlink == 1 &&
+            namespaceAfter.st_uid == geteuid() &&
+            namespaceAfter.st_gid == getegid() &&
+            (namespaceAfter.st_mode & 07777) == 0600;
+    }
+    close(descriptor);
+    free(pathBytes);
+    return valid;
+}
+
 static BOOL PXReadUnsignedIntegralSummaryNumber(id value,
                                                 unsigned long long *numberOut) {
     if (![value isKindOfClass:[NSNumber class]] ||
@@ -1413,6 +1485,12 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         return NO;
     }

+    if (!PXProtectOwnedKeychainTemporaryFileAtPath(outPath)) {
+        [warnings addObject:@"In-app keychain backup export protection failed"];
+        [self _killRelatedProcessesForBundleID:bundleID];
+        [fm removeItemAtPath:outPath error:nil];
+        return NO;
+    }
     [fm removeItemAtPath:destFile error:nil];
     if (![fm copyItemAtPath:outPath toPath:destFile error:nil]) {
         [warnings addObject:@"In-app keychain backup: failed to copy export to destination" ];
@@ -1457,6 +1535,11 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         [warnings addObject:@"In-app keychain restore: failed to stage import file" ];
         return NO;
     }
+    if (!PXProtectOwnedKeychainTemporaryFileAtPath(inPath)) {
+        [fm removeItemAtPath:inPath error:nil];
+        [warnings addObject:@"In-app keychain restore import protection failed"];
+        return NO;
+    }

     NSDictionary *req = @{
         @"action": @"restore",
@@ -2426,8 +2509,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                         [NSString stringWithFormat:@"plistItemCount=%lu",
                          (unsigned long)plistItemCount]);
                     keychainMethod = @"helper";
-                    [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true",
-                                 PXShellQuote(temporaryOutputPath)]];

                     if (plistItemCount == 0 &&
                         PXGroupsContainPlatformFamily(selectedKeychainGroups)) {
@@ -2447,8 +2528,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                                 return NO;
                             }
                             keychainMethod = @"in_app";
-                            [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true",
-                                         PXShellQuote(temporaryOutputPath)]];
                             PXDebugAppendLine(debugKeychain,
                                 [NSString stringWithFormat:@"inAppPlistItemCount=%lu",
                                  (unsigned long)replacementCount]);
@@ -2467,10 +2546,18 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                 keychainBackupPath = keychainArtifactRecord.filePath;
             } else {
                 NSError *fatalPolicyError = nil;
+                BOOL protectionFailure =
+                    [keychainArtifactError.domain
+                        isEqualToString:PXBackupArtifactWriterErrorDomain] &&
+                    keychainArtifactError.code ==
+                        PXBackupArtifactWriterErrorProtectionFailed;
+                NSString *safeKeychainWarning = protectionFailure
+                    ? @"Keychain backup could not be protected and was omitted"
+                    : @"Keychain backup could not be created and was omitted";
                 BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
                     keychainArtifactPolicy,
                     warnings,
-                    nil,
+                    safeKeychainWarning,
                     nil,
                     &fatalPolicyError);
                 if (!shouldContinue) {
@@ -4238,6 +4325,26 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                 return;
             }

+            NSError *keychainProtectionError = nil;
+            if (![keychainWorkspace
+                    applyCompleteFileProtectionWithError:&keychainProtectionError]) {
+                [keychainWorkspace cleanupWithError:nil];
+                NSError *err = keychainProtectionError ?:
+                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
+                                        code:PXOptionalRestoreStagingErrorProtectionFailed
+                                    userInfo:@{
+                                        NSLocalizedDescriptionKey:
+                                            @"The staged Keychain input could not be protected.",
+                                        PXOptionalRestoreStagingErrorFieldPathKey:
+                                            @"$.source.protection"
+                                    }];
+                completeStructuredFailure(PXRestoreComponentKeychain,
+                                          err,
+                                          PXRestoreRollbackStatusNotPerformed,
+                                          keychainBranchWarningStart);
+                return;
+            }
+
             NSString *keychainBackupPath = keychainWorkspace.validatedStage.filePath;
             NSArray<NSString *> *groups = restorePlan.keychainGroups;
             BOOL shouldUseInApp = restorePlan.keychainUsesInAppMethod;
diff --git a/PXBackupArtifactPolicy.h b/PXBackupArtifactPolicy.h
index 0bd9bc3..a480b0e 100644
--- a/PXBackupArtifactPolicy.h
+++ b/PXBackupArtifactPolicy.h
@@ -29,6 +29,11 @@ typedef NS_ENUM(NSUInteger, PXBackupArtifactEmptyFilePolicy) {
     PXBackupArtifactEmptyFilePolicyAllow = 2,
 };

+typedef NS_ENUM(NSUInteger, PXBackupArtifactDataProtectionRequirement) {
+    PXBackupArtifactDataProtectionRequirementUnspecified = 1,
+    PXBackupArtifactDataProtectionRequirementComplete = 2,
+};
+
 __attribute__((objc_subclassing_restricted))
 @interface PXBackupArtifactPolicy : NSObject <NSCopying>

@@ -36,6 +41,9 @@ __attribute__((objc_subclassing_restricted))
 @property (nonatomic, readonly) PXBackupArtifactRequirement requirement;
 @property (nonatomic, readonly) PXBackupArtifactFailureDisposition failureDisposition;
 @property (nonatomic, readonly) PXBackupArtifactEmptyFilePolicy emptyFilePolicy;
+@property (nonatomic, readonly) NSUInteger requiredPOSIXMode;
+@property (nonatomic, readonly)
+    PXBackupArtifactDataProtectionRequirement dataProtectionRequirement;

 + (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind;

diff --git a/PXBackupArtifactPolicy.m b/PXBackupArtifactPolicy.m
index 5afd57b..720db8a 100644
--- a/PXBackupArtifactPolicy.m
+++ b/PXBackupArtifactPolicy.m
@@ -5,7 +5,9 @@
 - (instancetype)initWithKind:(PXBackupArtifactKind)kind
                  requirement:(PXBackupArtifactRequirement)requirement
           failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
-             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy;
+             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy
+           requiredPOSIXMode:(NSUInteger)requiredPOSIXMode
+   dataProtectionRequirement:(PXBackupArtifactDataProtectionRequirement)dataProtectionRequirement;

 @end

@@ -14,6 +16,8 @@
     PXBackupArtifactRequirement _requirement;
     PXBackupArtifactFailureDisposition _failureDisposition;
     PXBackupArtifactEmptyFilePolicy _emptyFilePolicy;
+    NSUInteger _requiredPOSIXMode;
+    PXBackupArtifactDataProtectionRequirement _dataProtectionRequirement;
 }

 + (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind {
@@ -22,6 +26,9 @@
         PXBackupArtifactFailureDispositionContinueWithoutWarning;
     PXBackupArtifactEmptyFilePolicy emptyFilePolicy =
         PXBackupArtifactEmptyFilePolicyReject;
+    NSUInteger requiredPOSIXMode = 0600;
+    PXBackupArtifactDataProtectionRequirement dataProtectionRequirement =
+        PXBackupArtifactDataProtectionRequirementUnspecified;

     switch (kind) {
         case PXBackupArtifactKindApplicationData:
@@ -44,12 +51,18 @@
             emptyFilePolicy = PXBackupArtifactEmptyFilePolicyAllow;
             break;
         case PXBackupArtifactKindPreferences:
-        case PXBackupArtifactKindKeychain:
             requirement = PXBackupArtifactRequirementOptional;
             failureDisposition =
                 PXBackupArtifactFailureDispositionContinueWithoutWarning;
             emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
             break;
+        case PXBackupArtifactKindKeychain:
+            requirement = PXBackupArtifactRequirementOptional;
+            failureDisposition = PXBackupArtifactFailureDispositionWarnAndContinue;
+            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
+            dataProtectionRequirement =
+                PXBackupArtifactDataProtectionRequirementComplete;
+            break;
         default:
             return nil;
     }
@@ -57,19 +70,25 @@
     return [[PXBackupArtifactPolicy alloc] initWithKind:kind
                          requirement:requirement
                   failureDisposition:failureDisposition
-                     emptyFilePolicy:emptyFilePolicy];
+                     emptyFilePolicy:emptyFilePolicy
+                   requiredPOSIXMode:requiredPOSIXMode
+           dataProtectionRequirement:dataProtectionRequirement];
 }

 - (instancetype)initWithKind:(PXBackupArtifactKind)kind
                  requirement:(PXBackupArtifactRequirement)requirement
           failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
-             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy {
+             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy
+           requiredPOSIXMode:(NSUInteger)requiredPOSIXMode
+   dataProtectionRequirement:(PXBackupArtifactDataProtectionRequirement)dataProtectionRequirement {
     self = [super init];
     if (self) {
         _kind = kind;
         _requirement = requirement;
         _failureDisposition = failureDisposition;
         _emptyFilePolicy = emptyFilePolicy;
+        _requiredPOSIXMode = requiredPOSIXMode;
+        _dataProtectionRequirement = dataProtectionRequirement;
     }
     return self;
 }
@@ -80,6 +99,10 @@
     return _failureDisposition;
 }
 - (PXBackupArtifactEmptyFilePolicy)emptyFilePolicy { return _emptyFilePolicy; }
+- (NSUInteger)requiredPOSIXMode { return _requiredPOSIXMode; }
+- (PXBackupArtifactDataProtectionRequirement)dataProtectionRequirement {
+    return _dataProtectionRequirement;
+}

 - (BOOL)acceptsFileSize:(unsigned long long)fileSize {
     return fileSize > 0 ||
@@ -102,7 +125,9 @@
     return self.kind == other.kind &&
            self.requirement == other.requirement &&
            self.failureDisposition == other.failureDisposition &&
-           self.emptyFilePolicy == other.emptyFilePolicy;
+           self.emptyFilePolicy == other.emptyFilePolicy &&
+           self.requiredPOSIXMode == other.requiredPOSIXMode &&
+           self.dataProtectionRequirement == other.dataProtectionRequirement;
 }

 - (NSUInteger)hash {
@@ -113,6 +138,10 @@
              (value << 6) + (value >> 2);
     value ^= (NSUInteger)self.emptyFilePolicy + (NSUInteger)0x9e3779b9 +
              (value << 6) + (value >> 2);
+    value ^= self.requiredPOSIXMode + (NSUInteger)0x9e3779b9 +
+             (value << 6) + (value >> 2);
+    value ^= (NSUInteger)self.dataProtectionRequirement + (NSUInteger)0x9e3779b9 +
+             (value << 6) + (value >> 2);
     return value;
 }

diff --git a/PXBackupArtifactVerifier.h b/PXBackupArtifactVerifier.h
index 64d8650..ef5cba5 100644
--- a/PXBackupArtifactVerifier.h
+++ b/PXBackupArtifactVerifier.h
@@ -22,6 +22,7 @@ typedef NS_ENUM(NSInteger, PXBackupArtifactVerifierErrorCode) {
     PXBackupArtifactVerifierErrorDigestMismatch = 11,
     PXBackupArtifactVerifierErrorFilesystemChanged = 12,
     PXBackupArtifactVerifierErrorInconsistentManifest = 13,
+    PXBackupArtifactVerifierErrorProtectionInvalid = 14,
 };

 __attribute__((objc_subclassing_restricted))
diff --git a/PXBackupArtifactVerifier.m b/PXBackupArtifactVerifier.m
index ceb6b63..1ae8d74 100644
--- a/PXBackupArtifactVerifier.m
+++ b/PXBackupArtifactVerifier.m
@@ -1,4 +1,5 @@
 #import "PXBackupArtifactVerifier.h"
+#import "PXFileProtection.h"

 #import <CommonCrypto/CommonDigest.h>

@@ -44,6 +45,7 @@ NSString * const PXBackupArtifactVerifierErrorFieldPathKey =
         _expectedSize = expectedSize;
         _expectedDigest = [expectedDigest copy];
         _originalIndex = originalIndex;
+        _requiresCompleteProtection = requiresCompleteProtection;
     }
     return self;
 }
@@ -621,6 +623,8 @@ static BOOL PXArtifactVerifyDeclaration(
     NSString *namePath = PXArtifactFieldPath(entryPath, @"name");
     NSString *sizePath = PXArtifactFieldPath(entryPath, @"size");
     NSString *digestPath = PXArtifactFieldPath(entryPath, @"sha256");
+    NSString *protectionPath = PXArtifactFieldPath(
+        PXArtifactFieldPath(entryPath, @"policy"), @"dataProtection");

     int fileDescriptor = -1;
     if (!PXArtifactOpenRelativeFile(rootDescriptor,
@@ -655,6 +659,15 @@ static BOOL PXArtifactVerifyDeclaration(
                               @"The artifact size does not match the manifest.");
     }

+    if (declaration.requiresCompleteProtection &&
+        !PXVerifyCompleteFileProtectionOnDescriptor(fileDescriptor, NULL)) {
+        close(fileDescriptor);
+        return PXArtifactFail(error,
+                              PXBackupArtifactVerifierErrorProtectionInvalid,
+                              protectionPath,
+                              @"The artifact protection policy is invalid.");
+    }
+
     NSString *actualDigest = nil;
     if (!PXArtifactHashDescriptor(fileDescriptor,
                                   &actualDigest,
@@ -665,12 +678,20 @@ static BOOL PXArtifactVerifyDeclaration(
     }

     struct stat afterStatus;
-    if (fstat(fileDescriptor, &afterStatus) != 0) {
+    BOOL finalProtectionValid =
+        !declaration.requiresCompleteProtection ||
+        PXVerifyCompleteFileProtectionOnDescriptor(fileDescriptor, NULL);
+    if (fstat(fileDescriptor, &afterStatus) != 0 || !finalProtectionValid) {
         close(fileDescriptor);
         return PXArtifactFail(error,
-                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
-                              namePath,
-                              @"The artifact could not be inspected after verification.");
+                              declaration.requiresCompleteProtection
+                                  ? PXBackupArtifactVerifierErrorProtectionInvalid
+                                  : PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
+                              declaration.requiresCompleteProtection
+                                  ? protectionPath : namePath,
+                              declaration.requiresCompleteProtection
+                                  ? @"The artifact protection policy is invalid."
+                                  : @"The artifact could not be inspected after verification.");
     }
     close(fileDescriptor);

@@ -780,6 +801,18 @@ static BOOL PXArtifactAddRequiredReference(
     }

     NSArray *artifactEntries = (NSArray *)artifactsValue;
+    NSDictionary *schema = [manifest[@"schema"] isKindOfClass:[NSDictionary class]]
+        ? manifest[@"schema"] : nil;
+    uint64_t schemaRevision = 0;
+    if (!schema ||
+        !PXArtifactReadUnsignedIntegral(schema[@"revision"], 2, &schemaRevision) ||
+        (schemaRevision != 1 && schemaRevision != 2)) {
+        PXArtifactFail(error,
+                       PXBackupArtifactVerifierErrorInconsistentManifest,
+                       @"$.schema.revision",
+                       @"The manifest schema revision is invalid.");
+        return nil;
+    }
     NSMutableArray<PXBackupArtifactDeclaration *> *declarations =
         [NSMutableArray arrayWithCapacity:artifactEntries.count];
     NSMutableDictionary<NSString *, PXBackupArtifactDeclaration *>
@@ -841,12 +874,30 @@ static BOOL PXArtifactAddRequiredReference(
             return nil;
         }

+        NSDictionary *policy =
+            [entry[@"policy"] isKindOfClass:[NSDictionary class]]
+                ? entry[@"policy"] : nil;
+        BOOL requiresCompleteProtection = schemaRevision == 2 &&
+            [policy[@"kind"] isEqualToString:@"keychain"];
+        if (schemaRevision == 2 &&
+            ((!requiresCompleteProtection &&
+              ![policy[@"dataProtection"] isEqualToString:@"unspecified"]) ||
+             (requiresCompleteProtection &&
+              (![policy[@"dataProtection"] isEqualToString:@"complete"] ||
+               ![policy[@"posixMode"] isEqualToString:@"0600"])))) {
+            PXArtifactFail(error,
+                           PXBackupArtifactVerifierErrorInconsistentManifest,
+                           PXArtifactFieldPath(entryPath, @"policy"),
+                           @"The artifact protection declaration is invalid.");
+            return nil;
+        }
         PXBackupArtifactDeclaration *declaration =
             [[PXBackupArtifactDeclaration alloc]
                 initWithName:name
                 expectedSize:expectedSize
                 expectedDigest:(NSString *)digestValue
-                originalIndex:index];
+                originalIndex:index
+                requiresCompleteProtection:requiresCompleteProtection];
         [declarations addObject:declaration];
         declarationsByName[name] = declaration;

diff --git a/PXBackupArtifactWriter.h b/PXBackupArtifactWriter.h
index b9fe7ba..e156c60 100644
--- a/PXBackupArtifactWriter.h
+++ b/PXBackupArtifactWriter.h
@@ -28,6 +28,7 @@ typedef NS_ERROR_ENUM(PXBackupArtifactWriterErrorDomain,
     PXBackupArtifactWriterErrorFinalizationFailed = 15,
     PXBackupArtifactWriterErrorCleanupFailed = 16,
     PXBackupArtifactWriterErrorPolicyRejected = 17,
+    PXBackupArtifactWriterErrorProtectionFailed = 18,
 };

 typedef BOOL (^PXBackupArtifactProducer)(NSString *temporaryOutputPath);
@@ -40,6 +41,7 @@ __attribute__((objc_subclassing_restricted))
 @property (nonatomic, readonly) unsigned long long size;
 @property (nonatomic, copy, readonly) NSString *sha256;
 @property (nonatomic, strong, readonly) PXBackupArtifactPolicy *policy;
+@property (nonatomic, readonly) BOOL protectionVerified;
 @property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *manifestRepresentation;

 - (instancetype)init NS_UNAVAILABLE;
diff --git a/PXBackupArtifactWriter.m b/PXBackupArtifactWriter.m
index 6ec132b..6dbde34 100644
--- a/PXBackupArtifactWriter.m
+++ b/PXBackupArtifactWriter.m
@@ -1,5 +1,6 @@
 #import "PXBackupArtifactWriter.h"
 #import "PXBackupPublicationWorkspace.h"
+#import "PXFileProtection.h"

 #import <CommonCrypto/CommonDigest.h>

@@ -27,6 +28,7 @@ static NSString * const PXBackupArtifactParentField = @"$.artifact.parent";
 static NSString * const PXBackupArtifactTemporaryField = @"$.artifact.temporary";
 static NSString * const PXBackupArtifactPayloadField = @"$.artifact.payload";
 static NSString * const PXBackupArtifactPolicyField = @"$.artifact.policy";
+static NSString * const PXBackupArtifactProtectionField = @"$.artifact.payload.protection";

 static const NSUInteger PXBackupArtifactMaximumArtifacts = 4096;
 static const NSUInteger PXBackupArtifactMaximumRelativePathBytes = 4096;
@@ -154,6 +156,49 @@ static BOOL PXBackupArtifactStrictSync(int descriptor) {
     return result == 0;
 }

+static BOOL PXBackupArtifactSetMode(int descriptor, mode_t mode) {
+    if (descriptor < 0) return NO;
+    int result = -1;
+    do {
+        result = fchmod(descriptor, mode);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXBackupArtifactProtectedStatMatchesPolicy(
+    const struct stat *status,
+    PXBackupArtifactPolicy *policy) {
+    return status &&
+           [policy isMemberOfClass:[PXBackupArtifactPolicy class]] &&
+           S_ISREG(status->st_mode) &&
+           status->st_nlink == 1 &&
+           status->st_uid == geteuid() &&
+           status->st_gid == getegid() &&
+           (status->st_mode & (S_ISUID | S_ISGID)) == 0 &&
+           (status->st_mode & 07777) == (mode_t)policy.requiredPOSIXMode;
+}
+
+static BOOL PXBackupArtifactVerifyDescriptorForPolicy(
+    int descriptor,
+    PXBackupArtifactPolicy *policy,
+    struct stat *statusOut) {
+    if (descriptor < 0 ||
+        ![policy isMemberOfClass:[PXBackupArtifactPolicy class]] ||
+        !PXBackupArtifactDescriptorHasCloseOnExec(descriptor)) return NO;
+    if (policy.dataProtectionRequirement ==
+        PXBackupArtifactDataProtectionRequirementComplete) {
+        if (!PXVerifyCompleteFileProtectionOnDescriptor(descriptor, NULL)) return NO;
+    } else if (policy.dataProtectionRequirement !=
+               PXBackupArtifactDataProtectionRequirementUnspecified) {
+        return NO;
+    }
+    struct stat status;
+    if (fstat(descriptor, &status) != 0 ||
+        !PXBackupArtifactProtectedStatMatchesPolicy(&status, policy)) return NO;
+    if (statusOut) *statusOut = status;
+    return YES;
+}
+
 static BOOL PXBackupArtifactStringContainsNull(NSString *value) {
     for (NSUInteger index = 0; index < value.length; index++) {
         if ([value characterAtIndex:index] == 0) {
@@ -187,6 +232,64 @@ static char *PXBackupArtifactCopyCString(NSData *data) {
     return result;
 }

+static int PXBackupArtifactOpenRelativeFile(int rootDescriptor,
+                                            NSString *relativePath,
+                                            int accessMode) {
+    if (rootDescriptor < 0 ||
+        ![relativePath isKindOfClass:[NSString class]] ||
+        relativePath.length == 0 ||
+        (accessMode != O_RDONLY && accessMode != O_RDWR)) return -1;
+    NSArray<NSString *> *components =
+        [relativePath componentsSeparatedByString:@"/"];
+    if (components.count == 0 ||
+        components.count > PXBackupArtifactMaximumRelativeDepth) return -1;
+    int currentDescriptor = rootDescriptor;
+    BOOL ownsCurrentDescriptor = NO;
+    for (NSUInteger index = 0; index + 1 < components.count; index++) {
+        NSData *componentData = PXBackupArtifactLosslessUTF8Data(components[index]);
+        char *componentName = PXBackupArtifactCopyCString(componentData);
+        if (!componentName || componentName[0] == '\0') {
+            free(componentName);
+            if (ownsCurrentDescriptor) close(currentDescriptor);
+            return -1;
+        }
+        int nextDescriptor = openat(currentDescriptor,
+                                    componentName,
+                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        free(componentName);
+        struct stat status;
+        BOOL valid = nextDescriptor >= 0 &&
+                     PXBackupArtifactDescriptorHasCloseOnExec(nextDescriptor) &&
+                     fstat(nextDescriptor, &status) == 0 &&
+                     S_ISDIR(status.st_mode);
+        if (!valid) {
+            if (nextDescriptor >= 0) close(nextDescriptor);
+            if (ownsCurrentDescriptor) close(currentDescriptor);
+            return -1;
+        }
+        if (ownsCurrentDescriptor) close(currentDescriptor);
+        currentDescriptor = nextDescriptor;
+        ownsCurrentDescriptor = YES;
+    }
+    NSData *finalData = PXBackupArtifactLosslessUTF8Data(components.lastObject);
+    char *finalName = PXBackupArtifactCopyCString(finalData);
+    if (!finalName || finalName[0] == '\0') {
+        free(finalName);
+        if (ownsCurrentDescriptor) close(currentDescriptor);
+        return -1;
+    }
+    int descriptor = openat(currentDescriptor,
+                            finalName,
+                            accessMode | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    free(finalName);
+    if (ownsCurrentDescriptor) close(currentDescriptor);
+    if (descriptor < 0 || !PXBackupArtifactDescriptorHasCloseOnExec(descriptor)) {
+        if (descriptor >= 0) close(descriptor);
+        return -1;
+    }
+    return descriptor;
+}
+
 static NSString *PXBackupArtifactAppendComponent(NSString *parent,
                                                   NSString *component) {
     if ([parent isEqualToString:@"/"]) {
@@ -591,7 +694,11 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                             filePath:(NSString *)filePath
                                 size:(unsigned long long)size
                               sha256:(NSString *)sha256
-                              policy:(PXBackupArtifactPolicy *)policy;
+                              policy:(PXBackupArtifactPolicy *)policy
+                          descriptor:(int)descriptor
+                            identity:(const struct stat *)identity;
+- (BOOL)validateRetainedDescriptor;
+- (const struct stat *)identityPointer;

 @end

@@ -601,24 +708,39 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
     unsigned long long _size;
     NSString *_sha256;
     PXBackupArtifactPolicy *_policy;
+    BOOL _protectionVerified;
     NSDictionary<NSString *, id> *_manifestRepresentation;
+    int _descriptor;
+    struct stat _identity;
 }

 - (instancetype)initWithRelativePath:(NSString *)relativePath
                             filePath:(NSString *)filePath
                                 size:(unsigned long long)size
                               sha256:(NSString *)sha256
-                              policy:(PXBackupArtifactPolicy *)policy {
-    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]]) {
+                              policy:(PXBackupArtifactPolicy *)policy
+                          descriptor:(int)descriptor
+                            identity:(const struct stat *)identity {
+    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]] ||
+        descriptor < 0 || !identity ||
+        !PXBackupArtifactVerifyDescriptorForPolicy(descriptor, policy, NULL)) {
+        if (descriptor >= 0) close(descriptor);
         return nil;
     }
     self = [super init];
-    if (self) {
+    if (!self) {
+        close(descriptor);
+        return nil;
+    }
+    {
         _relativePath = [relativePath copy];
         _filePath = [filePath copy];
         _size = size;
         _sha256 = [sha256 copy];
         _policy = policy;
+        _protectionVerified = YES;
+        _descriptor = descriptor;
+        _identity = *identity;
         _manifestRepresentation = @{
             @"name": _relativePath,
             @"path": _filePath,
@@ -634,9 +756,19 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
 - (unsigned long long)size { return _size; }
 - (NSString *)sha256 { return _sha256; }
 - (PXBackupArtifactPolicy *)policy { return _policy; }
+- (BOOL)protectionVerified { return _protectionVerified; }
 - (NSDictionary<NSString *,id> *)manifestRepresentation {
     return _manifestRepresentation;
 }
+- (const struct stat *)identityPointer { return &_identity; }
+- (BOOL)validateRetainedDescriptor {
+    struct stat current;
+    return _descriptor >= 0 &&
+           PXBackupArtifactVerifyDescriptorForPolicy(_descriptor,
+                                                     _policy,
+                                                     &current) &&
+           PXBackupArtifactStableFileStatMatches(&_identity, &current);
+}

 - (id)copyWithZone:(NSZone *)zone {
     (void)zone;
@@ -667,6 +799,13 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
     return value;
 }

+- (void)dealloc {
+    if (_descriptor >= 0) {
+        close(_descriptor);
+        _descriptor = -1;
+    }
+}
+
 @end

 @interface PXBackupArtifactWriter ()
@@ -685,6 +824,7 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
     struct stat _workspaceIdentity;
     NSMutableSet<NSString *> *_acceptedPaths;
     NSMutableSet<NSString *> *_acceptedNormalizedAliases;
+    NSMutableArray<PXVerifiedBackupArtifact *> *_acceptedArtifacts;
     NSUInteger _artifactCount;
 }

@@ -791,8 +931,11 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                  workspaceIdentity:(const struct stat *)workspaceIdentity {
     NSMutableSet<NSString *> *acceptedPaths = [NSMutableSet set];
     NSMutableSet<NSString *> *acceptedAliases = [NSMutableSet set];
+    NSMutableArray<PXVerifiedBackupArtifact *> *acceptedArtifacts =
+        [NSMutableArray array];
     NSString *copiedWorkspacePath = [workspacePath copy];
-    if (!acceptedPaths || !acceptedAliases || !copiedWorkspacePath) {
+    if (!acceptedPaths || !acceptedAliases || !acceptedArtifacts ||
+        !copiedWorkspacePath) {
         return nil;
     }
     self = [super init];
@@ -803,6 +946,7 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
         _workspaceIdentity = *workspaceIdentity;
         _acceptedPaths = acceptedPaths;
         _acceptedNormalizedAliases = acceptedAliases;
+        _acceptedArtifacts = acceptedArtifacts;
         _artifactCount = 0;
     }
     return self;
@@ -847,6 +991,36 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                                  @"The writer workspace identity changed");
         return NO;
     }
+    for (PXVerifiedBackupArtifact *artifact in _acceptedArtifacts) {
+        if (![artifact isMemberOfClass:[PXVerifiedBackupArtifact class]] ||
+            !artifact.protectionVerified ||
+            ![artifact validateRetainedDescriptor]) {
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorProtectionFailed,
+                                     PXBackupArtifactProtectionField,
+                                     @"An accepted artifact protection invariant is invalid");
+            return NO;
+        }
+        int namespaceDescriptor =
+            PXBackupArtifactOpenRelativeFile(_workspaceDescriptor,
+                                             artifact.relativePath,
+                                             O_RDONLY);
+        struct stat namespaceStatus;
+        BOOL namespaceValid = namespaceDescriptor >= 0 &&
+            PXBackupArtifactVerifyDescriptorForPolicy(namespaceDescriptor,
+                                                      artifact.policy,
+                                                      &namespaceStatus) &&
+            PXBackupArtifactStableFileStatMatches([artifact identityPointer],
+                                                  &namespaceStatus);
+        if (namespaceDescriptor >= 0) close(namespaceDescriptor);
+        if (!namespaceValid) {
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorProtectionFailed,
+                                     PXBackupArtifactProtectionField,
+                                     @"An accepted artifact protection invariant is invalid");
+            return NO;
+        }
+    }
     return YES;
 }

@@ -1401,7 +1575,16 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
     if (error) {
         *error = nil;
     }
-    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]]) {
+    PXBackupArtifactPolicy *canonicalPolicy =
+        [policy isMemberOfClass:[PXBackupArtifactPolicy class]]
+            ? [PXBackupArtifactPolicy policyForKind:policy.kind]
+            : nil;
+    if (!canonicalPolicy || ![policy isEqual:canonicalPolicy] ||
+        policy.requiredPOSIXMode != 0600 ||
+        (policy.dataProtectionRequirement !=
+             PXBackupArtifactDataProtectionRequirementUnspecified &&
+         policy.dataProtectionRequirement !=
+             PXBackupArtifactDataProtectionRequirementComplete)) {
         PXBackupArtifactSetError(error,
                                  PXBackupArtifactWriterErrorInvalidInput,
                                  PXBackupArtifactPolicyField,
@@ -1503,6 +1686,7 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
     BOOL finalRenamed = NO;
     BOOL temporaryRemoved = NO;
     int payloadDescriptor = -1;
+    int retainedArtifactDescriptor = -1;
     NSString *digestString = nil;
     unsigned long long streamedBytes = 0;
     PXVerifiedBackupArtifact *record = nil;
@@ -1592,9 +1776,15 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                                      @"The producer output is invalid");
             break;
         }
+        int payloadAccessMode =
+            policy.dataProtectionRequirement ==
+                    PXBackupArtifactDataProtectionRequirementComplete
+                ? O_RDWR
+                : O_RDONLY;
         payloadDescriptor = openat(temporary.descriptor,
                                    PXBackupArtifactPayloadName,
-                                   O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+                                   payloadAccessMode | O_NONBLOCK |
+                                       O_NOFOLLOW | O_CLOEXEC);
         if (payloadDescriptor < 0) {
             PXBackupArtifactSetError(&operationError,
                                      PXBackupArtifactWriterErrorOutputInvalid,
@@ -1602,29 +1792,53 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                                      @"The producer output could not be opened safely");
             break;
         }
-        if (fchmod(payloadDescriptor, 0600) != 0 ||
-            fstat(payloadDescriptor, &payloadIdentity) != 0 ||
-            !S_ISREG(payloadIdentity.st_mode) ||
-            payloadIdentity.st_nlink != 1 ||
-            (payloadIdentity.st_mode & (S_ISUID | S_ISGID)) != 0 ||
-            (payloadIdentity.st_mode & 07777) != 0600 ||
-            payloadIdentity.st_dev != _workspaceIdentity.st_dev ||
-            payloadIdentity.st_size < 0 ||
-            (unsigned long long)payloadIdentity.st_size >
+        struct stat preProtectionStatus;
+        if (fstat(payloadDescriptor, &preProtectionStatus) != 0 ||
+            !S_ISREG(preProtectionStatus.st_mode) ||
+            preProtectionStatus.st_nlink != 1 ||
+            preProtectionStatus.st_uid != geteuid() ||
+            preProtectionStatus.st_gid != getegid() ||
+            (preProtectionStatus.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+            preProtectionStatus.st_dev != _workspaceIdentity.st_dev ||
+            preProtectionStatus.st_size < 0 ||
+            (unsigned long long)preProtectionStatus.st_size >
                 PXBackupArtifactMaximumFileBytes ||
             !PXBackupArtifactStatIdentityMatches(&payloadNamespaceStat,
-                                                &payloadIdentity) ||
+                                                &preProtectionStatus) ||
             !PXBackupArtifactDescriptorHasCloseOnExec(payloadDescriptor)) {
             PXBackupArtifactSetError(&operationError,
-                                     (payloadIdentity.st_size >= 0 &&
-                                      (unsigned long long)payloadIdentity.st_size >
-                                          PXBackupArtifactMaximumFileBytes)
-                                         ? PXBackupArtifactWriterErrorLimitExceeded
-                                         : PXBackupArtifactWriterErrorOutputInvalid,
+                                     PXBackupArtifactWriterErrorOutputInvalid,
                                      PXBackupArtifactPayloadField,
                                      @"The producer output is invalid");
             break;
         }
+        BOOL protectionApplied = NO;
+        if (policy.dataProtectionRequirement ==
+            PXBackupArtifactDataProtectionRequirementComplete) {
+            protectionApplied =
+                PXApplyCompleteFileProtectionToDescriptor(payloadDescriptor, NULL);
+        } else {
+            protectionApplied =
+                PXBackupArtifactSetMode(payloadDescriptor,
+                                        (mode_t)policy.requiredPOSIXMode);
+        }
+        if (!protectionApplied ||
+            !PXBackupArtifactVerifyDescriptorForPolicy(payloadDescriptor,
+                                                       policy,
+                                                       &payloadIdentity) ||
+            payloadIdentity.st_dev != _workspaceIdentity.st_dev ||
+            payloadIdentity.st_size < 0 ||
+            (unsigned long long)payloadIdentity.st_size >
+                PXBackupArtifactMaximumFileBytes ||
+            !PXBackupArtifactStatIdentityMatches(&preProtectionStatus,
+                                                &payloadIdentity) ||
+            preProtectionStatus.st_size != payloadIdentity.st_size) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorProtectionFailed,
+                                     PXBackupArtifactProtectionField,
+                                     @"The artifact protection policy could not be enforced");
+            break;
+        }
         payloadIdentityKnown = YES;
         CC_SHA256_CTX digestContext;
         CC_SHA256_Init(&digestContext);
@@ -1721,7 +1935,9 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
         }
         struct stat payloadNamespaceRevalidation;
         struct stat preRenameDescriptorStat;
-        if (fstat(payloadDescriptor, &preRenameDescriptorStat) != 0 ||
+        if (!PXBackupArtifactVerifyDescriptorForPolicy(payloadDescriptor,
+                                                       policy,
+                                                       &preRenameDescriptorStat) ||
             !PXBackupArtifactStableFileStatMatches(&payloadIdentity,
                                                    &preRenameDescriptorStat) ||
             fstatat(temporary.descriptor,
@@ -1730,7 +1946,10 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                     AT_SYMLINK_NOFOLLOW) != 0 ||
             !S_ISREG(payloadNamespaceRevalidation.st_mode) ||
             payloadNamespaceRevalidation.st_nlink != 1 ||
-            (payloadNamespaceRevalidation.st_mode & 07777) != 0600 ||
+            payloadNamespaceRevalidation.st_uid != geteuid() ||
+            payloadNamespaceRevalidation.st_gid != getegid() ||
+            (payloadNamespaceRevalidation.st_mode & 07777) !=
+                (mode_t)policy.requiredPOSIXMode ||
             !PXBackupArtifactStatIdentityMatches(&payloadNamespaceRevalidation,
                                                 &payloadIdentity) ||
             fstatat(parent.descriptor,
@@ -1762,7 +1981,10 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                     AT_SYMLINK_NOFOLLOW) != 0 ||
             !S_ISREG(finalNamespaceStat.st_mode) ||
             finalNamespaceStat.st_nlink != 1 ||
-            (finalNamespaceStat.st_mode & 07777) != 0600 ||
+            finalNamespaceStat.st_uid != geteuid() ||
+            finalNamespaceStat.st_gid != getegid() ||
+            (finalNamespaceStat.st_mode & 07777) !=
+                (mode_t)policy.requiredPOSIXMode ||
             finalNamespaceStat.st_dev != _workspaceIdentity.st_dev ||
             !PXBackupArtifactStatIdentityMatches(&finalNamespaceStat,
                                                 &payloadIdentity)) {
@@ -1772,6 +1994,45 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                                      @"The finalized artifact identity is invalid");
             break;
         }
+        if (!PXBackupArtifactVerifyDescriptorForPolicy(payloadDescriptor,
+                                                       policy,
+                                                       NULL)) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorProtectionFailed,
+                                     PXBackupArtifactProtectionField,
+                                     @"The finalized artifact protection is invalid");
+            break;
+        }
+        int finalizedDescriptor = openat(parent.descriptor,
+                                         finalNameCString,
+                                         O_RDONLY | O_NONBLOCK |
+                                             O_NOFOLLOW | O_CLOEXEC);
+        struct stat finalizedDescriptorStat;
+        BOOL finalizedProtectionValid = finalizedDescriptor >= 0 &&
+            PXBackupArtifactVerifyDescriptorForPolicy(finalizedDescriptor,
+                                                      policy,
+                                                      &finalizedDescriptorStat) &&
+            PXBackupArtifactStatIdentityMatches(&payloadIdentity,
+                                                &finalizedDescriptorStat) &&
+            payloadIdentity.st_size == finalizedDescriptorStat.st_size;
+        if (finalizedDescriptor >= 0) close(finalizedDescriptor);
+        if (!finalizedProtectionValid) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorProtectionFailed,
+                                     PXBackupArtifactProtectionField,
+                                     @"The finalized artifact protection is invalid");
+            break;
+        }
+        payloadIdentity = finalizedDescriptorStat;
+        retainedArtifactDescriptor =
+            PXBackupArtifactDuplicateDescriptor(payloadDescriptor);
+        if (retainedArtifactDescriptor < 0) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorProtectionFailed,
+                                     PXBackupArtifactProtectionField,
+                                     @"The finalized artifact protection authority could not be retained");
+            break;
+        }
         if (!PXBackupArtifactStrictSync(parent.descriptor)) {
             PXBackupArtifactSetError(&operationError,
                                      PXBackupArtifactWriterErrorDurabilityFailed,
@@ -1830,7 +2091,10 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                         filePath:finalFilePath
                             size:streamedBytes
                           sha256:digestString
-                          policy:policy];
+                          policy:policy
+                      descriptor:retainedArtifactDescriptor
+                        identity:&payloadIdentity];
+        retainedArtifactDescriptor = -1;
         if (!record) {
             PXBackupArtifactSetError(&operationError,
                                      PXBackupArtifactWriterErrorFinalizationFailed,
@@ -1844,6 +2108,10 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
         close(payloadDescriptor);
         payloadDescriptor = -1;
     }
+    if (!record && retainedArtifactDescriptor >= 0) {
+        close(retainedArtifactDescriptor);
+        retainedArtifactDescriptor = -1;
+    }
     if (!record) {
         BOOL cleanupSucceeded =
             [self cleanupParent:parent
@@ -1874,6 +2142,7 @@ static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
         [relativePath precomposedStringWithCanonicalMapping]];
     [_acceptedNormalizedAliases addObject:
         [relativePath decomposedStringWithCanonicalMapping]];
+    [_acceptedArtifacts addObject:record];
     _artifactCount += 1;
     free(finalNameCString);
     return record;
diff --git a/PXBackupDirectoryPublisher.h b/PXBackupDirectoryPublisher.h
index 91590ad..28729fc 100644
--- a/PXBackupDirectoryPublisher.h
+++ b/PXBackupDirectoryPublisher.h
@@ -30,6 +30,7 @@ typedef NS_ERROR_ENUM(PXBackupDirectoryPublisherErrorDomain,
     PXBackupDirectoryPublisherErrorManifestValidationFailed = 16,
     PXBackupDirectoryPublisherErrorSnapshotMismatch = 17,
     PXBackupDirectoryPublisherErrorRollbackFailed = 18,
+    PXBackupDirectoryPublisherErrorProtectedArtifactInvalid = 19,
 };

 __attribute__((objc_subclassing_restricted))
diff --git a/PXBackupDirectoryPublisher.m b/PXBackupDirectoryPublisher.m
index b3e431d..2490e7d 100644
--- a/PXBackupDirectoryPublisher.m
+++ b/PXBackupDirectoryPublisher.m
@@ -4,6 +4,7 @@
 #import "PXBackupArtifactWriter.h"
 #import "PXBackupManifestWriter.h"
 #import "PXBackupManifestValidator.h"
+#import "PXFileProtection.h"

 #import <CommonCrypto/CommonDigest.h>

@@ -30,6 +31,7 @@ static NSString * const PXBackupDirectoryPublisherWorkspaceField = @"$.publicati
 static NSString * const PXBackupDirectoryPublisherFinalField = @"$.publication.finalDirectory";
 static NSString * const PXBackupDirectoryPublisherManifestField = @"$.publication.manifest";
 static NSString * const PXBackupDirectoryPublisherSnapshotField = @"$.publication.snapshot";
+static NSString * const PXBackupDirectoryPublisherProtectionField = @"$.artifacts.protection";

 static const NSUInteger PXBackupDirectoryMaximumPathBytes = 4096U;
 static const NSUInteger PXBackupDirectoryMaximumComponentBytes = 255U;
@@ -592,6 +594,151 @@ static BOOL PXBackupDirectoryManifestMatches(
     return YES;
 }

+static BOOL PXBackupDirectoryExactBoolean(id value, BOOL *resultOut) {
+    if (![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
+    if (resultOut) *resultOut = [(NSNumber *)value boolValue];
+    return YES;
+}
+
+static BOOL PXBackupDirectorySafeRelativePath(NSString *relativePath) {
+    NSData *pathData = PXBackupDirectoryLosslessUTF8Data(
+        relativePath, PXBackupDirectoryMaximumPathBytes, NO);
+    if (!pathData || relativePath.length == 0 ||
+        [relativePath hasPrefix:@"/"] || [relativePath hasSuffix:@"/"]) return NO;
+    NSArray<NSString *> *components =
+        [relativePath componentsSeparatedByString:@"/"];
+    if (components.count == 0 || components.count > 32) return NO;
+    for (NSString *component in components) {
+        if ([component isEqualToString:@"."] ||
+            [component isEqualToString:@".."] ||
+            !PXBackupDirectoryValidateSafeComponent(component, NULL)) return NO;
+    }
+    return [[components componentsJoinedByString:@"/"]
+        isEqualToString:relativePath];
+}
+
+static BOOL PXBackupDirectoryResolveProtectedArtifact(
+    NSDictionary *manifest,
+    BOOL *requiredOut,
+    NSString **relativePathOut) {
+    if (requiredOut) *requiredOut = NO;
+    if (relativePathOut) *relativePathOut = nil;
+    NSDictionary *schema = [manifest[@"schema"] isKindOfClass:[NSDictionary class]]
+        ? manifest[@"schema"] : nil;
+    unsigned long long revision = 0;
+    if (!schema ||
+        !PXBackupDirectoryReadUnsignedIntegral(schema[@"revision"], &revision) ||
+        (revision != 1 && revision != 2)) return NO;
+    if (revision == 1) return YES;
+    NSDictionary *keychain = [manifest[@"keychain"] isKindOfClass:[NSDictionary class]]
+        ? manifest[@"keychain"] : nil;
+    BOOL included = NO;
+    if (!keychain ||
+        !PXBackupDirectoryExactBoolean(keychain[@"included"], &included)) return NO;
+    if (!included) return YES;
+    NSString *archive = [keychain[@"archive"] isKindOfClass:[NSString class]]
+        ? keychain[@"archive"] : nil;
+    if (!PXBackupDirectorySafeRelativePath(archive)) return NO;
+    NSArray *artifacts = [manifest[@"artifacts"] isKindOfClass:[NSArray class]]
+        ? manifest[@"artifacts"] : nil;
+    NSUInteger matches = 0;
+    for (id value in artifacts) {
+        if (![value isKindOfClass:[NSDictionary class]]) return NO;
+        NSDictionary *artifact = value;
+        NSDictionary *policy = [artifact[@"policy"] isKindOfClass:[NSDictionary class]]
+            ? artifact[@"policy"] : nil;
+        if ([artifact[@"name"] isEqualToString:archive] &&
+            [artifact[@"path"] isEqualToString:archive] &&
+            [policy[@"kind"] isEqualToString:@"keychain"] &&
+            [policy[@"posixMode"] isEqualToString:@"0600"] &&
+            [policy[@"dataProtection"] isEqualToString:@"complete"] &&
+            [policy[@"failureDisposition"] isEqualToString:@"warnAndContinue"]) {
+            matches += 1;
+        }
+    }
+    if (matches != 1) return NO;
+    if (requiredOut) *requiredOut = YES;
+    if (relativePathOut) *relativePathOut = [archive copy];
+    return YES;
+}
+
+static int PXBackupDirectoryOpenRelativeFile(int rootDescriptor,
+                                             NSString *relativePath) {
+    if (rootDescriptor < 0 ||
+        !PXBackupDirectorySafeRelativePath(relativePath)) return -1;
+    NSArray<NSString *> *components =
+        [relativePath componentsSeparatedByString:@"/"];
+    int currentDescriptor = rootDescriptor;
+    BOOL ownsCurrent = NO;
+    for (NSUInteger index = 0; index + 1 < components.count; index++) {
+        NSData *data = PXBackupDirectoryLosslessUTF8Data(
+            components[index], PXBackupDirectoryMaximumComponentBytes, NO);
+        char *name = PXBackupDirectoryCopyCString(data);
+        if (!name) {
+            if (ownsCurrent) close(currentDescriptor);
+            return -1;
+        }
+        int next = openat(currentDescriptor, name,
+                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        free(name);
+        struct stat status;
+        BOOL valid = next >= 0 &&
+                     PXBackupDirectoryDescriptorHasCloseOnExec(next) &&
+                     fstat(next, &status) == 0 && S_ISDIR(status.st_mode);
+        if (!valid) {
+            if (next >= 0) close(next);
+            if (ownsCurrent) close(currentDescriptor);
+            return -1;
+        }
+        if (ownsCurrent) close(currentDescriptor);
+        currentDescriptor = next;
+        ownsCurrent = YES;
+    }
+    NSData *data = PXBackupDirectoryLosslessUTF8Data(
+        components.lastObject, PXBackupDirectoryMaximumComponentBytes, NO);
+    char *name = PXBackupDirectoryCopyCString(data);
+    if (!name) {
+        if (ownsCurrent) close(currentDescriptor);
+        return -1;
+    }
+    int descriptor = openat(currentDescriptor, name,
+                            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    free(name);
+    if (ownsCurrent) close(currentDescriptor);
+    if (descriptor < 0 ||
+        !PXBackupDirectoryDescriptorHasCloseOnExec(descriptor)) {
+        if (descriptor >= 0) close(descriptor);
+        return -1;
+    }
+    return descriptor;
+}
+
+static BOOL PXBackupDirectoryVerifyProtectedArtifact(
+    int rootDescriptor,
+    NSString *relativePath,
+    const struct stat *expectedIdentity,
+    struct stat *identityOut,
+    int *descriptorOut) {
+    if (descriptorOut) *descriptorOut = -1;
+    int descriptor = PXBackupDirectoryOpenRelativeFile(rootDescriptor,
+                                                       relativePath);
+    struct stat status;
+    BOOL valid = descriptor >= 0 &&
+        PXVerifyCompleteFileProtectionOnDescriptor(descriptor, NULL) &&
+        fstat(descriptor, &status) == 0 &&
+        (!expectedIdentity ||
+         PXBackupDirectoryStatIdentityMatches(expectedIdentity, &status));
+    if (!valid) {
+        if (descriptor >= 0) close(descriptor);
+        return NO;
+    }
+    if (identityOut) *identityOut = status;
+    if (descriptorOut) *descriptorOut = descriptor;
+    else close(descriptor);
+    return YES;
+}
+
 @interface PXBackupDirectoryPublisher ()

 - (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
@@ -1075,6 +1222,7 @@ cleanup:
     BOOL accepted = NO;
     int finalDirectoryDescriptor = -1;
     int finalManifestDescriptor = -1;
+    int protectedArtifactDescriptor = -1;
     int forwardRenameErrno = 0;
     int rollbackRenameErrno = 0;
     NSError *originalError = nil;
@@ -1088,14 +1236,18 @@ cleanup:
     NSData *manifestData = nil;
     NSDictionary *parsedManifest = nil;
     NSError *validationError = nil;
+    NSString *protectedArtifactRelativePath = nil;
+    BOOL protectedArtifactRequired = NO;
     struct stat finalNamespaceIdentity;
     struct stat finalDirectoryIdentity;
     struct stat finalManifestIdentity;
     struct stat stableManifestIdentity;
+    struct stat protectedArtifactIdentity;
     memset(&finalNamespaceIdentity, 0, sizeof(finalNamespaceIdentity));
     memset(&finalDirectoryIdentity, 0, sizeof(finalDirectoryIdentity));
     memset(&finalManifestIdentity, 0, sizeof(finalManifestIdentity));
     memset(&stableManifestIdentity, 0, sizeof(stableManifestIdentity));
+    memset(&protectedArtifactIdentity, 0, sizeof(protectedArtifactIdentity));

     if (!PXBackupDirectoryValidateSafeComponent(_workspaceName,
                                                 &workspaceNameData) ||
@@ -1200,6 +1352,29 @@ cleanup:
                                   @"The accepted manifest does not match publication identity");
         goto cleanup;
     }
+    if (!PXBackupDirectoryResolveProtectedArtifact(
+            manifestRepresentation,
+            &protectedArtifactRequired,
+            &protectedArtifactRelativePath)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorProtectedArtifactInvalid,
+                                  PXBackupDirectoryPublisherProtectionField,
+                                  @"The protected artifact declaration is invalid");
+        goto cleanup;
+    }
+    if (protectedArtifactRequired &&
+        !PXBackupDirectoryVerifyProtectedArtifact(
+            _workspaceDescriptor,
+            protectedArtifactRelativePath,
+            NULL,
+            &protectedArtifactIdentity,
+            &protectedArtifactDescriptor)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorProtectedArtifactInvalid,
+                                  PXBackupDirectoryPublisherProtectionField,
+                                  @"The protected artifact failed pre-publication verification");
+        goto cleanup;
+    }
     if (!PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes)) {
         PXBackupDirectorySetError(error,
                                   PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists,
@@ -1241,6 +1416,48 @@ cleanup:
                                   @"The publication filesystem identity changed before rename");
         goto cleanup;
     }
+    artifactError = nil;
+    if (![artifactWriter validateIdentityWithError:&artifactError]) {
+        BOOL protectionFailure =
+            [artifactError.domain isEqualToString:PXBackupArtifactWriterErrorDomain] &&
+            artifactError.code == PXBackupArtifactWriterErrorProtectionFailed;
+        PXBackupDirectorySetError(
+            error,
+            protectionFailure
+                ? PXBackupDirectoryPublisherErrorProtectedArtifactInvalid
+                : PXBackupDirectoryPublisherErrorArtifactWriterValidationFailed,
+            protectionFailure
+                ? PXBackupDirectoryPublisherProtectionField
+                : PXBackupDirectoryPublisherWorkspaceField,
+            protectionFailure
+                ? @"The protected artifact failed final writer validation"
+                : @"The artifact writer failed final publication validation");
+        goto cleanup;
+    }
+    if (protectedArtifactRequired) {
+        struct stat retainedProtectedIdentity;
+        int namespaceProtectedDescriptor = -1;
+        BOOL retainedValid =
+            PXVerifyCompleteFileProtectionOnDescriptor(
+                protectedArtifactDescriptor, NULL) &&
+            fstat(protectedArtifactDescriptor, &retainedProtectedIdentity) == 0 &&
+            PXBackupDirectoryStatIdentityMatches(&protectedArtifactIdentity,
+                                                 &retainedProtectedIdentity) &&
+            PXBackupDirectoryVerifyProtectedArtifact(
+                _workspaceDescriptor,
+                protectedArtifactRelativePath,
+                &protectedArtifactIdentity,
+                NULL,
+                &namespaceProtectedDescriptor);
+        if (namespaceProtectedDescriptor >= 0) close(namespaceProtectedDescriptor);
+        if (!retainedValid) {
+            PXBackupDirectorySetError(error,
+                                      PXBackupDirectoryPublisherErrorProtectedArtifactInvalid,
+                                      PXBackupDirectoryPublisherProtectionField,
+                                      @"The protected artifact failed pre-rename verification");
+            goto cleanup;
+        }
+    }
     if (!PXBackupDirectoryRenameEntryNoReplace(_parentDescriptor,
                                                workspaceNameBytes,
                                                _parentDescriptor,
@@ -1358,6 +1575,34 @@ cleanup:
                                   @"The published manifest does not match its accepted snapshot");
         goto rollback;
     }
+    if (protectedArtifactRequired) {
+        BOOL finalDeclarationRequired = NO;
+        NSString *finalProtectedPath = nil;
+        struct stat finalProtectedIdentity;
+        int finalProtectedDescriptor = -1;
+        BOOL finalProtectedValid =
+            PXBackupDirectoryResolveProtectedArtifact(parsedManifest,
+                                                      &finalDeclarationRequired,
+                                                      &finalProtectedPath) &&
+            finalDeclarationRequired &&
+            [finalProtectedPath isEqualToString:protectedArtifactRelativePath] &&
+            PXBackupDirectoryVerifyProtectedArtifact(
+                finalDirectoryDescriptor,
+                finalProtectedPath,
+                &protectedArtifactIdentity,
+                &finalProtectedIdentity,
+                &finalProtectedDescriptor) &&
+            PXVerifyCompleteFileProtectionOnDescriptor(
+                protectedArtifactDescriptor, NULL);
+        if (finalProtectedDescriptor >= 0) close(finalProtectedDescriptor);
+        if (!finalProtectedValid) {
+            PXBackupDirectorySetError(error,
+                                      PXBackupDirectoryPublisherErrorProtectedArtifactInvalid,
+                                      PXBackupDirectoryPublisherProtectionField,
+                                      @"The published protected artifact is invalid");
+            goto rollback;
+        }
+    }
     if (!PXBackupDirectoryPathMatchesDescriptor(_parentPath,
                                                 _parentDescriptor,
                                                 &_parentIdentity,
@@ -1442,6 +1687,7 @@ rollback:
     if (error) *error = originalError;

 cleanup:
+    if (protectedArtifactDescriptor >= 0) close(protectedArtifactDescriptor);
     if (finalManifestDescriptor >= 0) close(finalManifestDescriptor);
     if (finalDirectoryDescriptor >= 0) close(finalDirectoryDescriptor);
     free(workspaceNameBytes);
diff --git a/PXBackupManifestV4.m b/PXBackupManifestV4.m
index 72fe22e..b8c6002 100644
--- a/PXBackupManifestV4.m
+++ b/PXBackupManifestV4.m
@@ -7,7 +7,7 @@
 NSInteger const PXBackupManifestV4Version = 4;
 NSString * const PXBackupManifestV4SchemaIdentifier =
     @"com.hydra.projectx.backup-manifest";
-NSInteger const PXBackupManifestV4SchemaRevision = 1;
+NSInteger const PXBackupManifestV4SchemaRevision = 2;
 NSString * const PXBackupManifestV4DigestAlgorithm = @"sha256";
 NSString * const PXBackupManifestV4PublicationProtocol = @"atomic-directory-v1";
 NSString * const PXBackupManifestV4ContentStateComplete = @"complete";
@@ -640,7 +640,24 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
         NSString *requirement = PXV4RequirementString(policy.requirement);
         NSString *disposition = PXV4DispositionString(policy.failureDisposition);
         NSString *empty = PXV4EmptyString(policy.emptyFilePolicy);
-        if (!kind || !requirement || !disposition || !empty) return PXV4FailureResult(error);
+        NSString *posixMode = policy.requiredPOSIXMode == 0600 ? @"0600" : nil;
+        NSString *dataProtection = nil;
+        switch (policy.dataProtectionRequirement) {
+            case PXBackupArtifactDataProtectionRequirementUnspecified:
+                dataProtection = @"unspecified";
+                break;
+            case PXBackupArtifactDataProtectionRequirementComplete:
+                dataProtection = @"complete";
+                break;
+        }
+        if (!kind || !requirement || !disposition || !empty ||
+            !posixMode || !dataProtection || !record.protectionVerified ||
+            (policy.kind == PXBackupArtifactKindKeychain &&
+             ![dataProtection isEqualToString:@"complete"]) ||
+            (policy.kind != PXBackupArtifactKindKeychain &&
+             ![dataProtection isEqualToString:@"unspecified"])) {
+            return PXV4FailureResult(error);
+        }
         NSDictionary *declaration = @{
             @"name": record.relativePath,
             @"path": record.relativePath,
@@ -651,6 +668,8 @@ static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
                 @"requirement": requirement,
                 @"failureDisposition": disposition,
                 @"emptyFilePolicy": empty,
+                @"posixMode": posixMode,
+                @"dataProtection": dataProtection,
             },
         };
         records[record.relativePath] = record;
diff --git a/PXBackupManifestValidator.m b/PXBackupManifestValidator.m
index 3bfd824..c600e7a 100644
--- a/PXBackupManifestValidator.m
+++ b/PXBackupManifestValidator.m
@@ -1095,15 +1095,25 @@ static NSInteger PXManifestV4KindOrder(NSString *kind) {
 }

 static BOOL PXManifestV4PolicyMatches(NSDictionary *policy,
-                                      unsigned long long size,
-                                      NSInteger *kindOrder,
-                                      BOOL *requiredOut) {
-    if (![policy isKindOfClass:[NSDictionary class]] ||
-        policy.count != 4 ||
-        ![[NSSet setWithArray:policy.allKeys] isEqualToSet:
-          [NSSet setWithArray:@[@"kind", @"requirement", @"failureDisposition", @"emptyFilePolicy"]]]) {
-        return NO;
-    }
+                                       unsigned long long schemaRevision,
+                                       unsigned long long size,
+                                       NSInteger *kindOrder,
+                                       BOOL *requiredOut) {
+    if (![policy isKindOfClass:[NSDictionary class]]) return NO;
+    NSSet *revisionOneKeys = [NSSet setWithArray:@[
+        @"kind", @"requirement", @"failureDisposition", @"emptyFilePolicy"
+    ]];
+    NSSet *revisionTwoKeys = [NSSet setWithArray:@[
+        @"kind", @"requirement", @"failureDisposition", @"emptyFilePolicy",
+        @"posixMode", @"dataProtection"
+    ]];
+    NSSet *actualKeys = [NSSet setWithArray:policy.allKeys];
+    if ((schemaRevision == 1 &&
+         (policy.count != 4 || ![actualKeys isEqualToSet:revisionOneKeys])) ||
+        (schemaRevision == 2 &&
+         (policy.count != 6 || ![actualKeys isEqualToSet:revisionTwoKeys])) ||
+        (schemaRevision != 1 && schemaRevision != 2)) return NO;
+
     NSString *kind = nil;
     NSString *requirement = nil;
     NSString *disposition = nil;
@@ -1111,9 +1121,16 @@ static BOOL PXManifestV4PolicyMatches(NSDictionary *policy,
     if (!PXManifestV4ReadString(policy[@"kind"], NO, &kind) ||
         !PXManifestV4ReadString(policy[@"requirement"], NO, &requirement) ||
         !PXManifestV4ReadString(policy[@"failureDisposition"], NO, &disposition) ||
-        !PXManifestV4ReadString(policy[@"emptyFilePolicy"], NO, &empty)) {
-        return NO;
-    }
+        !PXManifestV4ReadString(policy[@"emptyFilePolicy"], NO, &empty)) return NO;
+
+    NSString *posixMode = nil;
+    NSString *dataProtection = nil;
+    if (schemaRevision == 2 &&
+        (!PXManifestV4ReadString(policy[@"posixMode"], NO, &posixMode) ||
+         !PXManifestV4ReadString(policy[@"dataProtection"], NO,
+                                 &dataProtection) ||
+         ![posixMode isEqualToString:@"0600"])) return NO;
+
     NSInteger order = PXManifestV4KindOrder(kind);
     if (order == 0) return NO;
     BOOL valid = NO;
@@ -1133,11 +1150,25 @@ static BOOL PXManifestV4PolicyMatches(NSDictionary *policy,
                     [disposition isEqualToString:@"continueWithoutWarning"] &&
                     [empty isEqualToString:@"allow"];
             break;
-        case 7: case 8:
+        case 7:
             valid = [requirement isEqualToString:@"optional"] &&
                     [disposition isEqualToString:@"continueWithoutWarning"] &&
                     [empty isEqualToString:@"reject"];
             break;
+        case 8:
+            valid = [requirement isEqualToString:@"optional"] &&
+                    [disposition isEqualToString:
+                        schemaRevision == 1
+                            ? @"continueWithoutWarning"
+                            : @"warnAndContinue"] &&
+                    [empty isEqualToString:@"reject"];
+            break;
+    }
+    if (schemaRevision == 2) {
+        BOOL complete = order == 8;
+        valid = valid &&
+            [dataProtection isEqualToString:
+                complete ? @"complete" : @"unspecified"];
     }
     if (!valid || (size == 0 && ![empty isEqualToString:@"allow"])) return NO;
     if (kindOrder) *kindOrder = order;
@@ -1145,52 +1176,6 @@ static BOOL PXManifestV4PolicyMatches(NSDictionary *policy,
     return YES;
 }

-static BOOL PXManifestV4AddReference(NSMutableSet<NSString *> *references,
-                                     NSDictionary<NSString *, NSNumber *> *kindByName,
-                                     id name,
-                                     NSInteger expectedKind,
-                                     NSString *fieldPath,
-                                     NSError **error) {
-    if (!PXManifestV4RelativePath(name)) {
-        return PXManifestFail(error,
-                              PXBackupManifestValidatorErrorInvalidFieldType,
-                              fieldPath,
-                              @"The artifact reference is invalid.");
-    }
-    NSString *typedName = (NSString *)name;
-    NSNumber *kindNumber = kindByName[typedName];
-    if (![kindNumber isKindOfClass:[NSNumber class]]) {
-        return PXManifestFail(error,
-                              PXBackupManifestValidatorErrorInconsistentField,
-                              fieldPath,
-                              @"The artifact reference is missing.");
-    }
-    if (kindNumber.integerValue != expectedKind) {
-        return PXManifestFail(error,
-                              PXBackupManifestValidatorErrorInconsistentField,
-                              fieldPath,
-                              @"The artifact reference policy is inconsistent.");
-    }
-    if ([references containsObject:typedName]) {
-        return PXManifestFail(error,
-                              PXBackupManifestValidatorErrorDuplicateEntry,
-                              fieldPath,
-                              @"The artifact reference is duplicated.");
-    }
-    [references addObject:typedName];
-    return YES;
-}
-
-static BOOL PXManifestV4FailureResult(NSError **error) {
-    if (error && !*error) {
-        PXManifestFail(error,
-                       PXBackupManifestValidatorErrorInconsistentField,
-                       @"$",
-                       @"The manifest v4 structure is invalid.");
-    }
-    return NO;
-}
-
 static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
     NSArray *rootKeys = @[
         @"manifestVersion", @"schema", @"backupID", @"publication", @"bundleID",
@@ -1240,7 +1225,7 @@ static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
                                                error)) {
         return PXManifestV4FailureResult(error);
     }
-    if (schemaRevision != 1 ||
+    if ((schemaRevision != 1 && schemaRevision != 2) ||
         ![schemaIdentifier isEqualToString:@"com.hydra.projectx.backup-manifest"] ||
         ![digestAlgorithm isEqualToString:@"sha256"] ||
         ![publicationProtocol isEqualToString:@"atomic-directory-v1"] ||
diff --git a/PXOptionalRestoreStaging.h b/PXOptionalRestoreStaging.h
index 06bdf22..8c65a66 100644
--- a/PXOptionalRestoreStaging.h
+++ b/PXOptionalRestoreStaging.h
@@ -24,6 +24,7 @@ typedef NS_ENUM(NSInteger, PXOptionalRestoreStagingErrorCode) {
     PXOptionalRestoreStagingErrorLimitExceeded = 14,
     PXOptionalRestoreStagingErrorCleanupFailed = 15,
     PXOptionalRestoreStagingErrorInconsistentPlan = 16,
+    PXOptionalRestoreStagingErrorProtectionFailed = 17,
 };

 __attribute__((objc_subclassing_restricted))
@@ -43,6 +44,8 @@ __attribute__((objc_subclassing_restricted))
 @property (nonatomic, strong, readonly) PXValidatedOptionalFileStage *validatedStage;
 + (nullable instancetype)workspaceByStagingSourceFileAtPath:(NSString *)sourcePath
                                                      error:(NSError * _Nullable * _Nullable)error;
+- (BOOL)applyCompleteFileProtectionWithError:
+    (NSError * _Nullable * _Nullable)error;
 - (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;
 - (instancetype)init NS_UNAVAILABLE;
 + (instancetype)new NS_UNAVAILABLE;
diff --git a/PXOptionalRestoreStaging.m b/PXOptionalRestoreStaging.m
index 08c3230..6971a1d 100644
--- a/PXOptionalRestoreStaging.m
+++ b/PXOptionalRestoreStaging.m
@@ -1,5 +1,6 @@
 #import "PXOptionalRestoreStaging.h"
 #import "PXRestorePlan.h"
+#import "PXFileProtection.h"
 #import <CommonCrypto/CommonDigest.h>

 #include <dirent.h>
@@ -1571,6 +1572,81 @@ static BOOL PXOptionalCleanupDirectoryContents(int descriptor,
     return nil;
 }

+- (BOOL)applyCompleteFileProtectionWithError:(NSError **)error {
+    if (error) *error = nil;
+    if (self.isCleaned || self.ownershipLost ||
+        self.parentDescriptor < 0 || self.rootDescriptor < 0 ||
+        self.payloadDescriptor < 0 || self.rootBasename.length == 0) {
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorProtectionFailed,
+                              @"$.source.protection",
+                              @"The staged file protection precondition is invalid.");
+    }
+    char *rootName = PXOptionalCopyComponentRepresentation(self.rootBasename);
+    if (!rootName) {
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorProtectionFailed,
+                              @"$.source.protection",
+                              @"The staged file protection precondition is invalid.");
+    }
+    struct stat parentStatus;
+    struct stat rootDescriptorStatus;
+    struct stat rootNamespaceStatus;
+    struct stat payloadBefore;
+    struct stat payloadNamespaceBefore;
+    BOOL initialValid =
+        fstat(self.parentDescriptor, &parentStatus) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.parentIdentity, &parentStatus) &&
+        fstat(self.rootDescriptor, &rootDescriptorStatus) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.rootIdentity, &rootDescriptorStatus) &&
+        fstatat(self.parentDescriptor, rootName, &rootNamespaceStatus,
+                AT_SYMLINK_NOFOLLOW) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.rootIdentity, &rootNamespaceStatus) &&
+        fstat(self.payloadDescriptor, &payloadBefore) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.payloadIdentity, &payloadBefore) &&
+        fstatat(self.rootDescriptor, "payload", &payloadNamespaceBefore,
+                AT_SYMLINK_NOFOLLOW) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.payloadIdentity,
+                                       &payloadNamespaceBefore) &&
+        payloadBefore.st_nlink == 1 &&
+        payloadBefore.st_uid == geteuid() &&
+        payloadBefore.st_gid == getegid() &&
+        S_ISREG(payloadBefore.st_mode);
+    free(rootName);
+    if (!initialValid ||
+        !PXApplyCompleteFileProtectionToDescriptor(self.payloadDescriptor,
+                                                   NULL)) {
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorProtectionFailed,
+                              @"$.source.protection",
+                              @"The staged file protection could not be applied.");
+    }
+    struct stat payloadAfter;
+    struct stat payloadNamespaceAfter;
+    BOOL finalValid =
+        PXVerifyCompleteFileProtectionOnDescriptor(self.payloadDescriptor,
+                                                   NULL) &&
+        fstat(self.payloadDescriptor, &payloadAfter) == 0 &&
+        PXOptionalIdentityMatchesBasic(self.payloadIdentity, &payloadAfter) &&
+        payloadBefore.st_size == payloadAfter.st_size &&
+        fstatat(self.rootDescriptor, "payload", &payloadNamespaceAfter,
+                AT_SYMLINK_NOFOLLOW) == 0 &&
+        PXOptionalIdentityMatchesBasic(PXOptionalIdentityFromStat(&payloadAfter),
+                                       &payloadNamespaceAfter) &&
+        payloadAfter.st_nlink == 1 &&
+        payloadAfter.st_uid == geteuid() &&
+        payloadAfter.st_gid == getegid() &&
+        (payloadAfter.st_mode & 07777) == 0600;
+    if (!finalValid) {
+        return PXOptionalFail(error,
+                              PXOptionalRestoreStagingErrorProtectionFailed,
+                              @"$.source.protection",
+                              @"The staged file protection could not be verified.");
+    }
+    self.payloadIdentity = PXOptionalIdentityFromStat(&payloadAfter);
+    return YES;
+}
+
 - (BOOL)cleanupWithError:(NSError **)error {
     if (error) {
         *error = nil;
diff --git a/PXFileProtection.h b/PXFileProtection.h
new file mode 100644
--- /dev/null
+++ b/PXFileProtection.h
@@ -0,0 +1,32 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSErrorDomain const PXFileProtectionErrorDomain;
+FOUNDATION_EXPORT NSString * const PXFileProtectionErrorFieldPathKey;
+
+typedef NS_ERROR_ENUM(PXFileProtectionErrorDomain, PXFileProtectionErrorCode) {
+    PXFileProtectionErrorInvalidDescriptor = 1,
+    PXFileProtectionErrorInspectionFailed = 2,
+    PXFileProtectionErrorInvalidFileType = 3,
+    PXFileProtectionErrorInvalidLinkCount = 4,
+    PXFileProtectionErrorOwnershipMismatch = 5,
+    PXFileProtectionErrorPermissionUpdateFailed = 6,
+    PXFileProtectionErrorClassUpdateFailed = 7,
+    PXFileProtectionErrorClassInspectionFailed = 8,
+    PXFileProtectionErrorClassMismatch = 9,
+    PXFileProtectionErrorDurabilityFailed = 10,
+    PXFileProtectionErrorIdentityChanged = 11,
+};
+
+FOUNDATION_EXPORT BOOL
+PXApplyCompleteFileProtectionToDescriptor(
+    int descriptor,
+    NSError * _Nullable * _Nullable error);
+
+FOUNDATION_EXPORT BOOL
+PXVerifyCompleteFileProtectionOnDescriptor(
+    int descriptor,
+    NSError * _Nullable * _Nullable error);
+
+NS_ASSUME_NONNULL_END
diff --git a/PXFileProtection.m b/PXFileProtection.m
new file mode 100644
--- /dev/null
+++ b/PXFileProtection.m
@@ -0,0 +1,273 @@
+#import "PXFileProtection.h"
+
+#include <errno.h>
+#include <fcntl.h>
+#include <sys/stat.h>
+#include <sys/types.h>
+#include <unistd.h>
+
+NSErrorDomain const PXFileProtectionErrorDomain =
+    @"com.hydra.projectx.file-protection";
+NSString * const PXFileProtectionErrorFieldPathKey = @"fieldPath";
+
+static NSString * const PXFileProtectionDescriptorField = @"$.descriptor";
+static NSString * const PXFileProtectionIdentityField = @"$.descriptor.identity";
+static NSString * const PXFileProtectionModeField = @"$.descriptor.mode";
+static NSString * const PXFileProtectionClassField = @"$.descriptor.protectionClass";
+static NSString * const PXFileProtectionDurabilityField = @"$.descriptor.durability";
+
+static BOOL PXFileProtectionFail(NSError **error,
+                                 PXFileProtectionErrorCode code,
+                                 NSString *fieldPath,
+                                 NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXFileProtectionErrorDomain
+                                     code:code
+                                 userInfo:@{
+                                     NSLocalizedDescriptionKey: description,
+                                     PXFileProtectionErrorFieldPathKey: fieldPath,
+                                 }];
+    }
+    return NO;
+}
+
+static int PXFileProtectionGetDescriptorFlags(int descriptor) {
+    int result = -1;
+    do {
+        result = fcntl(descriptor, F_GETFD);
+    } while (result < 0 && errno == EINTR);
+    return result;
+}
+
+static BOOL PXFileProtectionDescriptorHasCloseOnExec(int descriptor) {
+    int flags = PXFileProtectionGetDescriptorFlags(descriptor);
+    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
+}
+
+static BOOL PXFileProtectionStatDescriptor(int descriptor,
+                                           struct stat *status) {
+    if (!status) {
+        return NO;
+    }
+    int result = -1;
+    do {
+        result = fstat(descriptor, status);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXFileProtectionSetMode(int descriptor, mode_t mode) {
+    int result = -1;
+    do {
+        result = fchmod(descriptor, mode);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXFileProtectionSetCompleteClass(int descriptor) {
+    int result = -1;
+    do {
+        result = fcntl(descriptor,
+                       F_SETPROTECTIONCLASS,
+                       PROTECTION_CLASS_A);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXFileProtectionGetClass(int descriptor,
+                                     int *protectionClassOut) {
+    int result = -1;
+    do {
+        result = fcntl(descriptor, F_GETPROTECTIONCLASS);
+    } while (result < 0 && errno == EINTR);
+    if (result < 0) {
+        return NO;
+    }
+    if (protectionClassOut) {
+        *protectionClassOut = result;
+    }
+    return YES;
+}
+
+static BOOL PXFileProtectionSyncDescriptor(int descriptor) {
+    int result = -1;
+    do {
+        result = fsync(descriptor);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXFileProtectionBasicIdentityMatches(const struct stat *left,
+                                                  const struct stat *right) {
+    return left && right &&
+           left->st_dev == right->st_dev &&
+           left->st_ino == right->st_ino &&
+           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
+}
+
+static BOOL PXFileProtectionVerifyCommon(int descriptor,
+                                         const struct stat *expectedIdentity,
+                                         BOOL requireSameSize,
+                                         struct stat *verifiedIdentityOut,
+                                         NSError **error) {
+    if (descriptor < 0 ||
+        !PXFileProtectionDescriptorHasCloseOnExec(descriptor)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInvalidDescriptor,
+                                    PXFileProtectionDescriptorField,
+                                    @"The file descriptor is invalid.");
+    }
+
+    struct stat status;
+    if (!PXFileProtectionStatDescriptor(descriptor, &status)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInspectionFailed,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected file could not be inspected.");
+    }
+    if (!S_ISREG(status.st_mode)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInvalidFileType,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected object must be a regular file.");
+    }
+    if (status.st_nlink != 1) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInvalidLinkCount,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected file link count is invalid.");
+    }
+    if (status.st_uid != geteuid() || status.st_gid != getegid()) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorOwnershipMismatch,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected file ownership is invalid.");
+    }
+    if ((status.st_mode & 07777) != 0600 ||
+        (status.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorPermissionUpdateFailed,
+                                    PXFileProtectionModeField,
+                                    @"The protected file permissions are invalid.");
+    }
+    if (expectedIdentity &&
+        (!PXFileProtectionBasicIdentityMatches(expectedIdentity, &status) ||
+         (requireSameSize && expectedIdentity->st_size != status.st_size))) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorIdentityChanged,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected file identity changed.");
+    }
+
+    int protectionClass = 0;
+    if (!PXFileProtectionGetClass(descriptor, &protectionClass)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorClassInspectionFailed,
+                                    PXFileProtectionClassField,
+                                    @"The file protection class could not be inspected.");
+    }
+    if (protectionClass != PROTECTION_CLASS_A) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorClassMismatch,
+                                    PXFileProtectionClassField,
+                                    @"The file protection class is invalid.");
+    }
+    if (verifiedIdentityOut) {
+        *verifiedIdentityOut = status;
+    }
+    return YES;
+}
+
+BOOL PXApplyCompleteFileProtectionToDescriptor(int descriptor,
+                                               NSError **error) {
+    if (error) {
+        *error = nil;
+    }
+    if (descriptor < 0 ||
+        !PXFileProtectionDescriptorHasCloseOnExec(descriptor)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInvalidDescriptor,
+                                    PXFileProtectionDescriptorField,
+                                    @"The file descriptor is invalid.");
+    }
+
+    struct stat initialStatus;
+    if (!PXFileProtectionStatDescriptor(descriptor, &initialStatus)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInspectionFailed,
+                                    PXFileProtectionIdentityField,
+                                    @"The file could not be inspected before protection.");
+    }
+    if (!S_ISREG(initialStatus.st_mode)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInvalidFileType,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected object must be a regular file.");
+    }
+    if (initialStatus.st_nlink != 1) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorInvalidLinkCount,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected file link count is invalid.");
+    }
+    if (initialStatus.st_uid != geteuid() ||
+        initialStatus.st_gid != getegid()) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorOwnershipMismatch,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected file ownership is invalid.");
+    }
+    if ((initialStatus.st_mode & (S_ISUID | S_ISGID | S_ISVTX)) != 0) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorPermissionUpdateFailed,
+                                    PXFileProtectionModeField,
+                                    @"The protected file permissions are invalid.");
+    }
+    if (!PXFileProtectionSetMode(descriptor, 0600)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorPermissionUpdateFailed,
+                                    PXFileProtectionModeField,
+                                    @"The protected file permissions could not be applied.");
+    }
+    if (!PXFileProtectionSetCompleteClass(descriptor)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorClassUpdateFailed,
+                                    PXFileProtectionClassField,
+                                    @"The file protection class could not be applied.");
+    }
+    if (!PXFileProtectionSyncDescriptor(descriptor)) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorDurabilityFailed,
+                                    PXFileProtectionDurabilityField,
+                                    @"The protected file could not be synchronized.");
+    }
+
+    struct stat finalStatus;
+    if (!PXFileProtectionVerifyCommon(descriptor,
+                                      &initialStatus,
+                                      YES,
+                                      &finalStatus,
+                                      error)) {
+        return NO;
+    }
+    if (!PXFileProtectionBasicIdentityMatches(&initialStatus, &finalStatus) ||
+        initialStatus.st_size != finalStatus.st_size) {
+        return PXFileProtectionFail(error,
+                                    PXFileProtectionErrorIdentityChanged,
+                                    PXFileProtectionIdentityField,
+                                    @"The protected file identity changed.");
+    }
+    return YES;
+}
+
+BOOL PXVerifyCompleteFileProtectionOnDescriptor(int descriptor,
+                                                NSError **error) {
+    if (error) {
+        *error = nil;
+    }
+    return PXFileProtectionVerifyCommon(descriptor,
+                                        NULL,
+                                        NO,
+                                        NULL,
+                                        error);
+}
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
