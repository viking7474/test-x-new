# TASK-4.8 REPORT — Integrate Structured Keychain Partial Results Into AppDataBackupManager

## Result

PASS — TASK-4.8 implementation is complete and ready for review. TASK-4.9 was not started.

## User authority

The user-supplied specification is the controlling authority: TASK-4.7 is ACCEPTED/COMPLETED and TASK-4.8 is READY. This task stops before TASK-4.9.

## TASK-4.7 review-file status

`docs/backup-restore-hardening/reviews/TASK-4.7-REVIEW.md` does not exist. This was not treated as a blocker because HEAD matched the accepted TASK-4.7 baseline, the TASK-4.7 report exists, the commit scope was correct, and user authority explicitly confirmed completion. No TASK-4.7 review file was created.

## Baseline

Baseline and pre-implementation HEAD: `051c5c7b026b81aae180a0d83c90185501cfc841` (`051c5c7 phase4(task-4.7): report requested and effective keychain groups`).

## Exact authorized scope

| Status | Path |
| --- | --- |
| M | Makefile |
| M | KeychainHelper/PXKeychainHelperResult.h |
| M | KeychainHelper/PXKeychainHelperResult.m |
| A | PXKeychainHelperInvocationResult.h |
| A | PXKeychainHelperInvocationResult.m |
| M | AppDataBackupManager.m |
| A | docs/backup-restore-hardening/reports/TASK-4.8-REPORT.md |

## Working-tree preservation

Pre-existing coordinator-owned changes in STATUS/ROADMAP/DECISIONS/README and untracked task/review documents were not staged, reset, rewritten, deleted, or committed. Only the seven authorized files are intended for the implementation commit.

## Protected hashes and byte sizes

| Path | Before SHA-256 | Before bytes | After SHA-256 | After bytes | Equal |
| --- | --- | --- | --- | --- | --- |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | TRUE |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 | TRUE |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 | TRUE |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 | TRUE |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 | TRUE |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 | TRUE |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 | TRUE |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 | TRUE |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | 4584 | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | 4584 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | 38587 | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | 38587 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.h` | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.m` | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | TRUE |
| `KeychainHelper/backup_helper.m` | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | 42561 | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | 42561 | TRUE |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 | TRUE |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 | TRUE |
| `PXAppGroupRestoreTransaction.h` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 | TRUE |
| `PXAppGroupRestoreTransaction.m` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 | TRUE |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 | TRUE |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 | TRUE |
| `PXBackupArtifactPolicy.h` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 | TRUE |
| `PXBackupArtifactPolicy.m` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 | TRUE |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 | TRUE |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 | TRUE |
| `PXBackupArtifactWriter.h` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 | TRUE |
| `PXBackupArtifactWriter.m` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 | TRUE |
| `PXBackupBundleLock.h` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 | TRUE |
| `PXBackupBundleLock.m` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 | TRUE |
| `PXBackupDirectoryDiscovery.h` | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | 1708 | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | 1708 | TRUE |
| `PXBackupDirectoryDiscovery.m` | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | 38228 | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | 38228 | TRUE |
| `PXBackupDirectoryPublisher.h` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 | TRUE |
| `PXBackupDirectoryPublisher.m` | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | 70795 | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | 70795 | TRUE |
| `PXBackupFailureCleanup.h` | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 | TRUE |
| `PXBackupFailureCleanup.m` | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | 80668 | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | 80668 | TRUE |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 | TRUE |
| `PXBackupManifestV4.m` | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | 44234 | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | 44234 | TRUE |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 | TRUE |
| `PXBackupManifestValidator.m` | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | 91751 | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | 91751 | TRUE |
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
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 | TRUE |
| `PXMainDataRestoreTransaction.m` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 | TRUE |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 | TRUE |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 | TRUE |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 | TRUE |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 | TRUE |
| `PXOptionalRestoreTransaction.h` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 | TRUE |
| `PXOptionalRestoreTransaction.m` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 | TRUE |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 | TRUE |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 | TRUE |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 | TRUE |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 | TRUE |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 | TRUE |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 | TRUE |
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 | TRUE |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 | TRUE |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 | TRUE |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 | TRUE |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 | TRUE |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 | TRUE |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 | TRUE |
| `scripts/keychain_backup.sh` | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | 75266 | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | 75266 | TRUE |

## Authorized source before and after

| Path | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
| --- | --- | --- | --- | --- |
| `Makefile` | `99cf5ded8dfe4bbd4ab363ccdbbd477285b3f1e5aa25118b18a200c52706b566` | 9226 | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` | 9266 |
| `KeychainHelper/PXKeychainHelperResult.h` | `78ba2ea6126db71d1d28026c7f1f1c66b2244aa792f411bc837f1e192e1c5a4a` | 3713 | `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3` | 4083 |
| `KeychainHelper/PXKeychainHelperResult.m` | `ff6ab760a6ba350efb55fa5c67bb3db157e0fea9992dffa67aab76f3847d3d6a` | 37518 | `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5` | 51525 |
| `AppDataBackupManager.m` | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | `f4478b67d8fb5efdc04f215f2f1f11ad2007126d941adb94ab8ae149eddece2d` | 234119 |
| `PXKeychainHelperInvocationResult.h` | ABSENT | 0 | `7c166a99f440535a1c8810633ad9ae9176d2625d3447586dfe27b9c4cb30198a` | 2316 |
| `PXKeychainHelperInvocationResult.m` | ABSENT | 0 | `ebfefa4a24417c3366b0114cb5ed2dcbc343b19b241942399b2109562a134180` | 18014 |

## Original manager call-site inventory

| Inventory | Baseline | After |
| --- | --- | --- |
| Keychain BOOL helper APIs | 4 | 0 |
| Keychain runAndCapture sites | 2 | 0 |
| Bounded direct executable sites | 0 | 1 |
| Raw stdout references in Keychain helper methods | 5 | 0 |
| Raw stderr references in Keychain helper methods | 5 | 0 |
| PXKeychainRestoreResult_ references | 1 | 0 |
| Selected-group value debug sites | 1 | 0 |
| Post-restore group value debug sites | 1 | 0 |
| Keychain wrapper list debug calls | 2 | 0 |

## Original nonzero-exit behavior

Baseline backup and restore treated every nonzero wrapper exit identically. Exit 10 therefore lost Partial semantics. The new invocation model classifies public helper, protocol, wrapper, and process outcomes separately.

## Original raw persistence inventory

Baseline restore persisted bundle ID, group values, raw command, exit code, stdout, and stderr under `PXKeychainRestoreResult_<bundleID>`. The write site was removed; production references are now zero. No migration or historical-default deletion was added.

## V2 decoder design

`PXKeychainHelperResult` now accepts exactly one machine-readable line, decodes only V2 binary-plist/base64 framing, validates the exact graph and field types, reconstructs through the canonical factory, and requires graph equality plus byte-equal canonical re-emission. No V1 decoder or downgrade path exists.

## Exact decode limits

| Limit | Value |
| --- | --- |
| Complete line | 50 KiB |
| Base64 suffix | 48 KiB |
| Decoded binary plist | 32 KiB |
| Access groups per array | 128 |
| Bytes per group | 512 |
| Bytes per array | 8 KiB |
| Combined group bytes | 16 KiB |
| Result counts | 0…1,000,000 |

## Canonical round-trip proof

The existing V2 emission factory text is byte-for-byte unchanged. Decoder fixtures reconstruct via that factory, require decoded graph deep equality, then require the canonical machine-readable line bytes to equal the original input. Alternative graph ordering or numeric coercion is rejected unless it is already the exact canonical encoding.

## Invocation result API

`PXKeychainHelperInvocationResult` is immutable and exposes only status, expected operation, exit code, decoded helper result, additional effective-group count, and diagnostic truncation. It does not expose or retain CommandResult, stdout, stderr, command, argv, file path, bundle ID, or a separate machine-line copy.

## Process-health policy

Usable process evidence requires spawnError=0, runnerError=0, normal exit, no timeout, signal=0, and untruncated stdout. Stderr truncation remains parseable and produces a generic diagnostic warning. Process facts and stream strings are copied to local snapshots only while parsing and are not retained in the invocation object.

## Machine-line extraction

Bounded stdout is split only on LF. Exactly one candidate may begin at position zero with the V2 prefix. V1, unknown generic tokens, mid-line tokens, CR candidates, and multiple candidates are rejected. Exit 50 requires the exact `PXKEYCHAIN_HELPER_RESULT_V2=INVALID` marker and always maps to ProtocolFailed.

## Exit/completion matrix

| Exit | Required protocol evidence | Invocation status |
| --- | --- | --- |
| 0 | decoded completed, expected operation/groups | Completed |
| 10 | decoded partial, expected operation/groups | Partial |
| 20/21/30/40 | decoded failed + fatal present | HelperFailed |
| 50 | exact INVALID marker | ProtocolFailed |
| 60–65 | wrapper failure; ignore prior line | WrapperFailed |
| Other | none trusted | ProtocolFailed |

## Operation validation

Production manager workflows accept only expected backup or restore. A decoded operation mismatch is ProtocolFailed even if exit/completion otherwise match.

## Requested-group validation

Manager groups are canonicalized with lossless UTF-8, bounds, control/comma rejection, surrounding-whitespace trimming, and first-occurrence deduplication. The decoded requested array must equal the canonical manager array exactly and in order.

## Effective-superset handling

The V2 factory proves requested ⊆ effective. A proper effective superset is valid. The invocation object reports only the additional count; manager warnings and debug output never disclose values.

## Backup Completed policy

Completed accepts only an existing, parseable Keychain plist whose `items.count` equals `succeededCount`. Zero-item Completed preserves baseline behavior after verification.

## Backup Partial policy

Partial with positive successful items is accepted only after the same output/result count cross-check and emits a count-only warning. Partial with zero successful items is rejected unless the existing platform-family in-app fallback succeeds.

## Backup output/result count cross-check

The manager performs a bounded 64 MiB immutable plist read and requires the items-array count to equal the structured succeeded count before the artifact writer may publish the output.

## In-app backup fallback interaction

Fallback is attempted only after a verified Completed/Partial zero-item helper result for platform-family groups. A successful in-app export replaces the output and sets method=`in_app`; a failed fallback preserves Completed-zero baseline behavior but cannot rescue zero-success Partial.

## Restore Completed policy

Completed maps the Keychain component to Succeeded with planned=1 and committed=1 through the unchanged PXRestoreResult accumulator.

## Warning-only Partial mapping

Partial maps to Succeeded only when failed=0, skipped=0, error=0, attempted=succeeded, and warningCount>0. The component receives bounded count warnings and no failure snapshot.

## Substantive Partial mapping

Any failed/skipped/error item or attempted/succeeded mismatch maps Keychain to Failed, committed=0, rollback=NotPerformed, code 323, and continues restore. A generic warning states that some Keychain items may have changed; no rollback is claimed.

## Helper failure mapping

HelperFailed maps to component failure code 322 with a generic message and optional numeric exit warning. Raw fatal domain/description is not used.

## Protocol/wrapper/process failure mapping

ProtocolFailed, WrapperFailed, ProcessFailed, missing invocation, and invalid expected groups map to code 324 with generic bounded warnings. Wrapper exits 60–65 invalidate any earlier helper line.

## Restore continuation proof

After a successfully staged Keychain input, no execution outcome calls `completeStructuredFailure` or returns from the workflow. Only staging/plan failure remains a structured hard stop. All execution outcomes publish a component result and continue.

## In-app restore non-regression

The in-app bridge protocol is unchanged. In-app success maps to Succeeded; in-app failure maps to Failed/code 322 and continues. No synthetic V2 result is created.

## PXRestoreResult non-regression

`PXRestoreResult.h/.m` are byte-identical. No Partial enum, mask, item-level public counts, or Keychain-specific public properties were added. Partial uses existing Succeeded+warnings or Failed+failure states.

## Raw output persistence removal

`PXKeychainRestoreResult_` production references: 0. The replacement does not persist raw streams, command, arguments, group values, path, line, or payload.

## Warning privacy

New shell-helper warnings contain only generic text, exit code, additional effective-group count, or item counters. They never contain stdout, stderr, machine payload, group values, file paths, item identities, or fatal localized descriptions.

## Debug privacy

The two raw wrapper list calls and selected/effective group-value debug lines were removed. Shell-helper debug now contains operation, manager outcome, exit code, truncation state, counters, and group counts only. Generic unrelated PXDebugRun behavior and the separate in-app bridge branch remain outside this parser change.

## Makefile target integration

ProjectX app target now includes `KeychainHelper/PXKeychainHelperResult.m` exactly once. Root wildcard includes the new invocation implementation. The backup_helper target still includes the result model once and does not include the invocation parser.

## Schema V2 non-regression

Schema version remains 2; prefix, exact 11-key graph, nested accessGroups/fatalError graphs, serialization bounds, group validation, and factory emission are unchanged. The only result-model extension is strict decode API/errors.

## Exit taxonomy non-regression

`PXKeychainHelperExitCode.h` is byte-identical. The manager classifies only 0,10,20,21,30,40,50,60–65 and treats unknown exits as protocol failures.

## TASK-4.3 zero-delete proof

Keychain core is byte-identical. Restore Security counts remain CopyMatching=1, Add=1, Update=1, Delete=0.

## TASK-4.4 identity non-regression

PXKeychainItemIdentity files are byte-identical and exact per-item identity semantics are unchanged.

## TASK-4.5 upsert non-regression

Add-first, exact duplicate lookup, and persistent-reference update behavior remain unchanged in the protected Keychain core.

## TASK-4.6 workspace non-regression

Wrapper and direct helper are byte-identical. Private workspace, signed-entitlement snapshot, cleanup, and exit normalization behavior are unchanged; both available Git Bash syntax checks pass.

## TASK-4.7 group-report non-regression

V2 requested/effective facts, subset invariant, wrapper argv propagation, and helper emission are unchanged. Manager now consumes those facts without rewriting them.

## TASK-4.9 boundary

No Data Protection class, ownership policy, encryption, xattr, crash-durable protection, archive-at-rest policy, or manifest protection metadata was implemented. Existing chmod 600 behavior is preserved but is not claimed as final TASK-4.9 policy.

## Bridge boundary

WeaponXKeychainBridge files are byte-identical. No V2 bridge emission/parsing, Darwin notification changes, or in-app/shell result unification was introduced.

## Full authorized diff

The following is the full six-source implementation diff; the report file itself is excluded from its own embedded diff.
```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index 6b2adc2..bba0939 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -31,6 +31,7 @@
 #import "PXDataContainerResolver.h"
 #import "PXDestructivePathValidator.h"
 #import "CommandRunner.h"
+#import "PXKeychainHelperInvocationResult.h"
 #import "common/PXProcessKiller.h"
 #import "common/PXPaths.h"

@@ -39,6 +40,9 @@
 static NSString * const PXBackupErrorDomain = @"com.hydra.projectx.backup";
 static NSString * const PXExactRestoreDestinationErrorDescription =
     @"Exact application data container could not be resolved safely";
+static const NSTimeInterval PXKeychainHelperInvocationTimeoutSeconds = 300.0;
+static const NSUInteger PXKeychainHelperInvocationOutputLimitBytes = 1024 * 1024;
+static const NSUInteger PXKeychainBackupPlistMaximumBytes = 64 * 1024 * 1024;

 static BOOL PXReadUnsignedIntegralSummaryNumber(id value,
                                                 unsigned long long *numberOut) {
@@ -1091,14 +1095,138 @@ static BOOL PXGroupsContainPlatformFamily(NSArray<NSString *> *groups) {
     return NO;
 }

-static NSUInteger PXKeychainPlistItemCount(NSString *plistPath) {
-    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:plistPath];
-    if (![d isKindOfClass:[NSDictionary class]]) return 0;
-    id items = d[@"items"];
-    if ([items isKindOfClass:[NSArray class]]) {
-        return [(NSArray *)items count];
+static BOOL PXKeychainPlistItemCount(NSString *plistPath,
+                                       NSUInteger *countOut) {
+    if (countOut) {
+        *countOut = 0;
     }
-    return 0;
+    if (![plistPath isKindOfClass:[NSString class]] || plistPath.length == 0) {
+        return NO;
+    }
+    NSError *attributeError = nil;
+    NSDictionary<NSFileAttributeKey, id> *attributes =
+        [[NSFileManager defaultManager] attributesOfItemAtPath:plistPath
+                                                         error:&attributeError];
+    NSNumber *sizeNumber = attributes[NSFileSize];
+    NSString *fileType = attributes[NSFileType];
+    if (attributeError ||
+        ![fileType isEqualToString:NSFileTypeRegular] ||
+        ![sizeNumber isKindOfClass:[NSNumber class]] ||
+        sizeNumber.unsignedLongLongValue == 0 ||
+        sizeNumber.unsignedLongLongValue > PXKeychainBackupPlistMaximumBytes) {
+        return NO;
+    }
+    NSError *readError = nil;
+    NSData *data = [NSData dataWithContentsOfFile:plistPath
+                                         options:NSDataReadingMappedIfSafe
+                                           error:&readError];
+    if (!data || readError ||
+        data.length != sizeNumber.unsignedLongLongValue ||
+        data.length > PXKeychainBackupPlistMaximumBytes) {
+        return NO;
+    }
+    NSError *parseError = nil;
+    id root = [NSPropertyListSerialization propertyListWithData:data
+                                                        options:NSPropertyListImmutable
+                                                         format:NULL
+                                                          error:&parseError];
+    if (parseError || ![root isKindOfClass:[NSDictionary class]]) {
+        return NO;
+    }
+    id items = ((NSDictionary *)root)[@"items"];
+    if (![items isKindOfClass:[NSArray class]]) {
+        return NO;
+    }
+    if (countOut) {
+        *countOut = [(NSArray *)items count];
+    }
+    return YES;
+}
+
+static NSString *PXKeychainInvocationOutcomeName(
+    PXKeychainHelperInvocationStatus status) {
+    switch (status) {
+        case PXKeychainHelperInvocationStatusCompleted: return @"completed";
+        case PXKeychainHelperInvocationStatusPartial: return @"partial";
+        case PXKeychainHelperInvocationStatusHelperFailed: return @"helper_failed";
+        case PXKeychainHelperInvocationStatusProtocolFailed: return @"protocol_failed";
+        case PXKeychainHelperInvocationStatusWrapperFailed: return @"wrapper_failed";
+        case PXKeychainHelperInvocationStatusProcessFailed: return @"process_failed";
+    }
+    return @"unknown";
+}
+
+static NSString *PXKeychainOperationName(PXKeychainHelperOperation operation) {
+    switch (operation) {
+        case PXKeychainHelperOperationBackup: return @"backup";
+        case PXKeychainHelperOperationRestore: return @"restore";
+        case PXKeychainHelperOperationWipe: return @"wipe";
+        case PXKeychainHelperOperationList: return @"list";
+        case PXKeychainHelperOperationUnknown: return @"unknown";
+    }
+    return @"unknown";
+}
+
+static void PXDebugAppendKeychainInvocationSummary(
+    NSString *debugPath,
+    PXKeychainHelperInvocationResult *invocation) {
+    if (![invocation isKindOfClass:[PXKeychainHelperInvocationResult class]]) {
+        PXDebugAppendLine(debugPath, @"managerOutcome=unavailable");
+        return;
+    }
+    PXKeychainHelperResult *result = invocation.helperResult;
+    PXDebugAppendLine(debugPath,
+        [NSString stringWithFormat:@"operation=%@ managerOutcome=%@ exitCode=%ld diagnosticOutputTruncated=%d",
+         PXKeychainOperationName(invocation.expectedOperation),
+         PXKeychainInvocationOutcomeName(invocation.status),
+         (long)invocation.exitCode,
+         invocation.diagnosticOutputTruncated ? 1 : 0]);
+    if (!result) {
+        return;
+    }
+    PXDebugAppendLine(debugPath,
+        [NSString stringWithFormat:@"attemptedCount=%lu succeededCount=%lu failedCount=%lu skippedCount=%lu warningCount=%lu errorCount=%lu",
+         (unsigned long)result.attemptedCount,
+         (unsigned long)result.succeededCount,
+         (unsigned long)result.failedCount,
+         (unsigned long)result.skippedCount,
+         (unsigned long)result.warningCount,
+         (unsigned long)result.errorCount]);
+    PXDebugAppendLine(debugPath,
+        [NSString stringWithFormat:@"requestedGroupCount=%lu effectiveGroupCount=%lu additionalEffectiveGroupCount=%lu",
+         (unsigned long)result.requestedAccessGroups.count,
+         (unsigned long)result.effectiveAccessGroups.count,
+         (unsigned long)invocation.additionalEffectiveAccessGroupCount]);
+}
+
+static void PXAppendKeychainInvocationCommonWarnings(
+    NSMutableArray<NSString *> *warnings,
+    PXKeychainHelperInvocationResult *invocation) {
+    if (![warnings isKindOfClass:[NSMutableArray class]] ||
+        ![invocation isKindOfClass:[PXKeychainHelperInvocationResult class]]) {
+        return;
+    }
+    if (invocation.diagnosticOutputTruncated) {
+        [warnings addObject:@"Keychain helper diagnostic output was truncated"];
+    }
+    if (invocation.additionalEffectiveAccessGroupCount > 0) {
+        [warnings addObject:[NSString stringWithFormat:
+            @"Keychain helper used %lu additional effective access group(s)",
+            (unsigned long)invocation.additionalEffectiveAccessGroupCount]];
+    }
+}
+
+static NSString *PXKeychainPartialSummary(NSString *operation,
+                                           PXKeychainHelperResult *result) {
+    return [NSString stringWithFormat:
+        @"Keychain %@ partially completed: attempted=%lu succeeded=%lu failed=%lu skipped=%lu warnings=%lu errors=%lu",
+        operation,
+        (unsigned long)result.attemptedCount,
+        (unsigned long)result.succeededCount,
+        (unsigned long)result.failedCount,
+        (unsigned long)result.skippedCount,
+        (unsigned long)result.warningCount,
+        (unsigned long)result.errorCount];
 }

 static BOOL PXOpenApplication(NSString *bundleID) {
@@ -1399,95 +1527,73 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
     return YES;
 }

-- (BOOL)_backupKeychainForBundleID:(NSString *)bundleID
-                            groups:(NSArray<NSString *> *)groups
-                            toFile:(NSString *)backupFile
-                          warnings:(NSMutableArray<NSString *> *)warnings {
+- (PXKeychainHelperInvocationResult *)_runKeychainWrapperWithArguments:(NSArray<NSString *> *)arguments
+                                                      expectedOperation:(PXKeychainHelperOperation)expectedOperation
+                                                 expectedAccessGroups:(NSArray<NSString *> *)expectedAccessGroups {
     NSString *scriptPath = [self _keychainBackupScriptPath];
-    if (!scriptPath) {
-        [warnings addObject:@"Keychain backup script not found; skipping keychain backup"];
-        return NO;
-    }
-
-    CommandRunner *runner = [CommandRunner shared];
-    NSString *groupsArg = groups.count ? [NSString stringWithFormat:@" --groups %@", PXShellQuote([groups componentsJoinedByString:@","])] : @"";
-    NSString *cmd = [NSString stringWithFormat:@"%@ backup %@ %@%@",
-                     PXShellQuote(scriptPath),
-                     PXShellQuote(bundleID),
-                     PXShellQuote(backupFile),
-                     groupsArg];
-
-    CommandResult *res = [runner runAndCapture:cmd];
-    if (res.exitCode != 0) {
-        NSString *stderrMsg = res.stderrString.length ? res.stderrString : @"";
-        NSString *stdoutMsg = res.stdoutString.length ? res.stdoutString : @"";
-        NSMutableString *msg = [NSMutableString stringWithString:@"Keychain backup failed"];
-        if (stderrMsg.length) {
-            [msg appendFormat:@"\nstderr: %@", stderrMsg];
-        }
-        if (stdoutMsg.length) {
-            [msg appendFormat:@"\nstdout: %@", stdoutMsg];
-        }
-        [warnings addObject:[NSString stringWithFormat:@"Keychain backup: %@", msg]];
-        return NO;
+    if (!scriptPath.length ||
+        ![arguments isKindOfClass:[NSArray class]] ||
+        arguments.count == 0 ||
+        ![expectedAccessGroups isKindOfClass:[NSArray class]] ||
+        expectedAccessGroups.count == 0) {
+        return nil;
     }
-
-    return [[NSFileManager defaultManager] fileExistsAtPath:backupFile];
+    CommandResult *commandResult = [[CommandRunner shared]
+        runExecutableAndCapture:scriptPath
+                      arguments:arguments
+                     timeoutSec:PXKeychainHelperInvocationTimeoutSeconds
+                 maxOutputBytes:PXKeychainHelperInvocationOutputLimitBytes];
+    NSError *invocationError = nil;
+    PXKeychainHelperInvocationResult *invocation =
+        [PXKeychainHelperInvocationResult resultWithCommandResult:commandResult
+                                                expectedOperation:expectedOperation
+                                   expectedRequestedAccessGroups:expectedAccessGroups
+                                                            error:&invocationError];
+    (void)invocationError;
+    return invocation;
 }

-- (BOOL)_restoreKeychainForBundleID:(NSString *)bundleID
-                             groups:(NSArray<NSString *> *)groups
-                           fromFile:(NSString *)backupFile
-                          overwrite:(BOOL)overwrite
-                           warnings:(NSMutableArray<NSString *> *)warnings {
-    NSString *scriptPath = [self _keychainBackupScriptPath];
-    if (!scriptPath) {
-        [warnings addObject:@"Keychain backup script not found; skipping keychain restore"];
-        return NO;
+- (PXKeychainHelperInvocationResult *)_runKeychainBackupForBundleID:(NSString *)bundleID
+                                                            groups:(NSArray<NSString *> *)groups
+                                                            toFile:(NSString *)backupFile {
+    if (!bundleID.length || !backupFile.length || groups.count == 0) {
+        return nil;
     }
-
-    if (![[NSFileManager defaultManager] fileExistsAtPath:backupFile]) {
-        [warnings addObject:@"Keychain backup file not found; skipping keychain restore"];
-        return NO;
+    NSString *csv = [groups componentsJoinedByString:@","];
+    NSArray<NSString *> *arguments = @[
+        @"backup",
+        bundleID,
+        backupFile,
+        @"--groups",
+        csv,
+    ];
+    return [self _runKeychainWrapperWithArguments:arguments
+                                expectedOperation:PXKeychainHelperOperationBackup
+                               expectedAccessGroups:groups];
+}
+
+- (PXKeychainHelperInvocationResult *)_runKeychainRestoreForBundleID:(NSString *)bundleID
+                                                             groups:(NSArray<NSString *> *)groups
+                                                           fromFile:(NSString *)backupFile
+                                                          overwrite:(BOOL)overwrite {
+    if (!bundleID.length || !backupFile.length || groups.count == 0 ||
+        ![[NSFileManager defaultManager] fileExistsAtPath:backupFile]) {
+        return nil;
     }
-
-    CommandRunner *runner = [CommandRunner shared];
-    NSString *overwriteArg = overwrite ? @"--overwrite" : @"";
-    NSString *groupsArg = groups.count ? [NSString stringWithFormat:@" --groups %@", PXShellQuote([groups componentsJoinedByString:@","])] : @"";
-    NSString *cmd = [NSString stringWithFormat:@"%@ restore %@ %@ %@%@",
-                     PXShellQuote(scriptPath),
-                     PXShellQuote(bundleID),
-                     PXShellQuote(backupFile),
-                     overwriteArg,
-                     groupsArg];
-
-    CommandResult *res = [runner runAndCapture:cmd];
-    // Store last keychain restore output for debugging
-    NSDictionary *report = @{
-        @"bundleID": bundleID ?: @"",
-        @"groups": groups ?: @[],
-        @"cmd": cmd ?: @"",
-        @"exitCode": @(res.exitCode),
-        @"stdout": res.stdoutString ?: @"",
-        @"stderr": res.stderrString ?: @"",
-    };
-    [[NSUserDefaults standardUserDefaults] setObject:report forKey:[NSString stringWithFormat:@"PXKeychainRestoreResult_%@", bundleID]];
-    [[NSUserDefaults standardUserDefaults] synchronize];
-    if (res.exitCode != 0) {
-        NSString *stderrMsg = res.stderrString.length ? res.stderrString : @"";
-        NSString *stdoutMsg = res.stdoutString.length ? res.stdoutString : @"";
-        NSMutableString *msg = [NSMutableString stringWithString:@"Keychain restore failed"];
-        if (stderrMsg.length) {
-            [msg appendFormat:@"\nstderr: %@", stderrMsg];
-        }
-        if (stdoutMsg.length) {
-            [msg appendFormat:@"\nstdout: %@", stdoutMsg];
-        }
-        [warnings addObject:[NSString stringWithFormat:@"Keychain restore: %@", msg]];
-        return NO;
+    NSString *csv = [groups componentsJoinedByString:@","];
+    NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithObjects:
+        @"restore",
+        bundleID,
+        backupFile,
+        nil];
+    if (overwrite) {
+        [arguments addObject:@"--overwrite"];
     }
-
-    return YES;
+    [arguments addObject:@"--groups"];
+    [arguments addObject:csv];
+    return [self _runKeychainWrapperWithArguments:[arguments copy]
+                                expectedOperation:PXKeychainHelperOperationRestore
+                               expectedAccessGroups:groups];
 }

 - (NSString *)_backupRoot {
@@ -2242,43 +2348,91 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                 }
             }

-            // Debug: list keychain items before backup
-            {
-                PXDebugHeader(debugKeychain, @"Keychain Before Backup");
-                PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"selectedGroups=%@", selectedKeychainGroups ?: @[]]);
-                NSString *scriptPath = [runner firstExistingPath:@[@"/Library/WeaponX/keychain_backup.sh",
-                                                                  @"/var/jb/Library/WeaponX/keychain_backup.sh",
-                                                                  @"/private/var/jb/Library/WeaponX/keychain_backup.sh"]];
-                if (scriptPath.length && selectedKeychainGroups.count) {
-                    NSString *csv = [selectedKeychainGroups componentsJoinedByString:@","];
-                    PXDebugRun(runner, debugKeychain, @"list", [NSString stringWithFormat:@"%@ list %@ --groups %@", PXShellQuote(scriptPath), PXShellQuote(bundleID), PXShellQuote(csv)]);
-                }
+            NSError *canonicalGroupError = nil;
+            NSArray<NSString *> *canonicalGroups =
+                [PXKeychainHelperInvocationResult
+                    canonicalAccessGroupsFromArray:selectedKeychainGroups ?: @[]
+                                                error:&canonicalGroupError];
+            (void)canonicalGroupError;
+            if (!canonicalGroups) {
+                selectedKeychainGroups = @[];
+                [warnings addObject:@"Keychain access groups were invalid; skipping helper backup"];
+            } else {
+                selectedKeychainGroups = canonicalGroups;
             }
+            PXDebugHeader(debugKeychain, @"Keychain Before Backup");
+            PXDebugAppendLine(debugKeychain,
+                [NSString stringWithFormat:@"selectedGroupCount=%lu",
+                 (unsigned long)selectedKeychainGroups.count]);

             NSError *keychainArtifactError = nil;
             keychainArtifactRecord =
                 [artifactWriter writeArtifactAtRelativePath:@"keychain.plist"
                                                      policy:keychainArtifactPolicy
                                                    producer:^BOOL(NSString *temporaryOutputPath) {
-                    BOOL keychainSuccess = [self _backupKeychainForBundleID:bundleID
-                                                                    groups:selectedKeychainGroups
-                                                                    toFile:temporaryOutputPath
-                                                                  warnings:warnings];
-                    if (!keychainSuccess) {
+                    if (selectedKeychainGroups.count == 0) {
                         return NO;
                     }
-                    keychainMethod = @"helper";
-                    [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]];
+                    PXKeychainHelperInvocationResult *invocation =
+                        [self _runKeychainBackupForBundleID:bundleID
+                                                    groups:selectedKeychainGroups
+                                                    toFile:temporaryOutputPath];
                     PXDebugHeader(debugKeychain, @"Keychain Backup Result");
-                    PXDebugAppendLine(debugKeychain, @"status=ok");
-                    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"archive=%@", temporaryOutputPath]);
-                    PXDebugRun(runner, debugKeychain, @"ls keychain.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]);
-
-                    // If helper cannot access restricted groups (e.g. *.platformFamily), fallback to in-app export.
-                    NSUInteger count = PXKeychainPlistItemCount(temporaryOutputPath);
-                    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItems=%lu", (unsigned long)count]);
-                    if (count == 0 && PXGroupsContainPlatformFamily(selectedKeychainGroups)) {
-                        PXDebugAppendLine(debugKeychain, @"helper returned 0 items; trying in-app export");
+                    PXDebugAppendKeychainInvocationSummary(debugKeychain, invocation);
+                    if (!invocation) {
+                        [warnings addObject:@"Keychain helper could not be invoked"];
+                        return NO;
+                    }
+                    PXAppendKeychainInvocationCommonWarnings(warnings, invocation);
+                    PXKeychainHelperResult *helperResult = invocation.helperResult;
+                    BOOL completed = invocation.status == PXKeychainHelperInvocationStatusCompleted;
+                    BOOL partial = invocation.status == PXKeychainHelperInvocationStatusPartial;
+                    if (!completed && !partial) {
+                        switch (invocation.status) {
+                            case PXKeychainHelperInvocationStatusHelperFailed:
+                                [warnings addObject:[NSString stringWithFormat:
+                                    @"Keychain helper failed with exit code %ld",
+                                    (long)invocation.exitCode]];
+                                break;
+                            case PXKeychainHelperInvocationStatusProcessFailed:
+                                [warnings addObject:@"Keychain helper process failed"];
+                                break;
+                            case PXKeychainHelperInvocationStatusWrapperFailed:
+                                [warnings addObject:[NSString stringWithFormat:
+                                    @"Keychain wrapper failed with exit code %ld",
+                                    (long)invocation.exitCode]];
+                                break;
+                            case PXKeychainHelperInvocationStatusProtocolFailed:
+                                [warnings addObject:@"Keychain helper result was invalid"];
+                                break;
+                            case PXKeychainHelperInvocationStatusCompleted:
+                            case PXKeychainHelperInvocationStatusPartial:
+                                break;
+                        }
+                        return NO;
+                    }
+                    if (partial) {
+                        [warnings addObject:PXKeychainPartialSummary(@"backup", helperResult)];
+                    }
+
+                    NSUInteger plistItemCount = 0;
+                    if (!helperResult ||
+                        !PXKeychainPlistItemCount(temporaryOutputPath, &plistItemCount) ||
+                        plistItemCount != helperResult.succeededCount) {
+                        [warnings addObject:@"Keychain backup output did not match the verified helper result"];
+                        return NO;
+                    }
+                    PXDebugAppendLine(debugKeychain,
+                        [NSString stringWithFormat:@"plistItemCount=%lu",
+                         (unsigned long)plistItemCount]);
+                    keychainMethod = @"helper";
+                    [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true",
+                                 PXShellQuote(temporaryOutputPath)]];
+
+                    if (plistItemCount == 0 &&
+                        PXGroupsContainPlatformFamily(selectedKeychainGroups)) {
+                        PXDebugAppendLine(debugKeychain,
+                                          @"zeroItemFallbackAttempted=1");
                         BOOL inAppOK = [self _inAppKeychainBackupForBundleID:bundleID
                                                                containerPath:dataContainerPath
                                                                       groups:selectedKeychainGroups
@@ -2286,13 +2440,25 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                                                                    debugPath:debugKeychain
                                                                     warnings:warnings];
                         if (inAppOK) {
+                            NSUInteger replacementCount = 0;
+                            if (!PXKeychainPlistItemCount(temporaryOutputPath,
+                                                         &replacementCount)) {
+                                [warnings addObject:@"In-app Keychain backup output could not be verified"];
+                                return NO;
+                            }
                             keychainMethod = @"in_app";
-                            [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]];
-                            PXDebugRun(runner, debugKeychain, @"ls keychain.plist (after in-app)", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]);
-                            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItemsAfterInApp=%lu", (unsigned long)PXKeychainPlistItemCount(temporaryOutputPath)]);
-                        } else {
-                            PXDebugAppendLine(debugKeychain, @"in-app export failed");
+                            [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true",
+                                         PXShellQuote(temporaryOutputPath)]];
+                            PXDebugAppendLine(debugKeychain,
+                                [NSString stringWithFormat:@"inAppPlistItemCount=%lu",
+                                 (unsigned long)replacementCount]);
+                            return YES;
                         }
+                        PXDebugAppendLine(debugKeychain, @"zeroItemFallbackSucceeded=0");
+                    }
+                    if (partial && helperResult.succeededCount == 0) {
+                        [warnings addObject:@"Keychain partial backup produced no usable items"];
+                        return NO;
                     }
                     return YES;
                 }
@@ -4074,28 +4240,107 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

             NSString *keychainBackupPath = keychainWorkspace.validatedStage.filePath;
             NSArray<NSString *> *groups = restorePlan.keychainGroups;
-            NSString *method = restorePlan.keychainMethod;
-            (void)method;
             BOOL shouldUseInApp = restorePlan.keychainUsesInAppMethod;
             NSUInteger keychainExecutionWarningStart = warnings.count;
-            BOOL ok = NO;
+            BOOL keychainComponentSucceeded = NO;
+            NSInteger keychainFailureCode = 0;
+            NSString *keychainFailureMessage = nil;
+            PXKeychainHelperInvocationResult *invocation = nil;
+
+            PXDebugHeader(debugKeychain, @"Keychain Restore Result");
             if (shouldUseInApp) {
-                ok = [self _inAppKeychainRestoreForBundleID:bundleID
-                                              containerPath:dataContainerPath
-                                                     groups:groups
-                                                   fromFile:keychainBackupPath
-                                                  overwrite:YES
-                                                  debugPath:debugKeychain
-                                                   warnings:warnings];
+                BOOL inAppSucceeded =
+                    [self _inAppKeychainRestoreForBundleID:bundleID
+                                             containerPath:dataContainerPath
+                                                    groups:groups
+                                                  fromFile:keychainBackupPath
+                                                 overwrite:YES
+                                                 debugPath:debugKeychain
+                                                  warnings:warnings];
+                keychainComponentSucceeded = inAppSucceeded;
+                PXDebugAppendLine(debugKeychain,
+                    inAppSucceeded
+                        ? @"operation=restore managerOutcome=completed method=in_app"
+                        : @"operation=restore managerOutcome=helper_failed method=in_app");
+                if (!inAppSucceeded) {
+                    [warnings addObject:@"In-app Keychain restore failed (continuing)"];
+                    keychainFailureCode = 322;
+                    keychainFailureMessage = @"Keychain helper operation failed";
+                }
             } else {
-                ok = [self _restoreKeychainForBundleID:bundleID
-                                              groups:groups
-                                            fromFile:keychainBackupPath
-                                           overwrite:YES
-                                            warnings:warnings];
-            }
-            if (!ok) {
-                [warnings addObject:@"Keychain restore failed (continuing)" ];
+                NSError *canonicalGroupError = nil;
+                NSArray<NSString *> *canonicalGroups =
+                    [PXKeychainHelperInvocationResult
+                        canonicalAccessGroupsFromArray:groups ?: @[]
+                                                    error:&canonicalGroupError];
+                (void)canonicalGroupError;
+                if (!canonicalGroups) {
+                    [warnings addObject:@"Keychain helper result could not be verified"];
+                    keychainFailureCode = 324;
+                    keychainFailureMessage = @"Keychain helper result could not be verified";
+                    PXDebugAppendLine(debugKeychain,
+                                      @"operation=restore managerOutcome=protocol_failed");
+                } else {
+                    invocation = [self _runKeychainRestoreForBundleID:bundleID
+                                                               groups:canonicalGroups
+                                                             fromFile:keychainBackupPath
+                                                            overwrite:YES];
+                    PXDebugAppendKeychainInvocationSummary(debugKeychain, invocation);
+                    if (!invocation) {
+                        [warnings addObject:@"Keychain helper could not be invoked"];
+                        keychainFailureCode = 324;
+                        keychainFailureMessage = @"Keychain helper result could not be verified";
+                    } else {
+                        PXAppendKeychainInvocationCommonWarnings(warnings, invocation);
+                        PXKeychainHelperResult *helperResult = invocation.helperResult;
+                        switch (invocation.status) {
+                            case PXKeychainHelperInvocationStatusCompleted:
+                                keychainComponentSucceeded = YES;
+                                break;
+                            case PXKeychainHelperInvocationStatusPartial: {
+                                [warnings addObject:PXKeychainPartialSummary(@"restore", helperResult)];
+                                BOOL warningOnlyPartial = helperResult &&
+                                    helperResult.failedCount == 0 &&
+                                    helperResult.skippedCount == 0 &&
+                                    helperResult.errorCount == 0 &&
+                                    helperResult.attemptedCount == helperResult.succeededCount &&
+                                    helperResult.warningCount > 0;
+                                if (warningOnlyPartial) {
+                                    keychainComponentSucceeded = YES;
+                                } else {
+                                    [warnings addObject:@"Keychain restore partially completed; some Keychain items may have been changed"];
+                                    keychainFailureCode = 323;
+                                    keychainFailureMessage = @"Keychain restore partially completed";
+                                }
+                                break;
+                            }
+                            case PXKeychainHelperInvocationStatusHelperFailed:
+                                [warnings addObject:[NSString stringWithFormat:
+                                    @"Keychain helper failed with exit code %ld",
+                                    (long)invocation.exitCode]];
+                                keychainFailureCode = 322;
+                                keychainFailureMessage = @"Keychain helper operation failed";
+                                break;
+                            case PXKeychainHelperInvocationStatusProtocolFailed:
+                                [warnings addObject:@"Keychain helper result was invalid"];
+                                keychainFailureCode = 324;
+                                keychainFailureMessage = @"Keychain helper result could not be verified";
+                                break;
+                            case PXKeychainHelperInvocationStatusWrapperFailed:
+                                [warnings addObject:[NSString stringWithFormat:
+                                    @"Keychain wrapper failed with exit code %ld",
+                                    (long)invocation.exitCode]];
+                                keychainFailureCode = 324;
+                                keychainFailureMessage = @"Keychain helper result could not be verified";
+                                break;
+                            case PXKeychainHelperInvocationStatusProcessFailed:
+                                [warnings addObject:@"Keychain helper process failed"];
+                                keychainFailureCode = 324;
+                                keychainFailureMessage = @"Keychain helper result could not be verified";
+                                break;
+                        }
+                    }
+                }
             }

             NSError *keychainCleanupError = nil;
@@ -4104,7 +4349,7 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             }
             NSArray<NSString *> *keychainWarnings =
                 PXRestoreWarningsSuffix(warnings, keychainExecutionWarningStart);
-            if (ok) {
+            if (keychainComponentSucceeded) {
                 BOOL keychainSuccessResultMarked =
                     [resultAccumulator markComponentSucceeded:PXRestoreComponentKeychain
                                                       warnings:keychainWarnings];
@@ -4112,10 +4357,14 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                           @"Keychain success result state must be publishable");
                 (void)keychainSuccessResultMarked;
             } else {
+                if (keychainFailureCode == 0 || keychainFailureMessage.length == 0) {
+                    keychainFailureCode = 324;
+                    keychainFailureMessage = @"Keychain helper result could not be verified";
+                }
                 PXRestoreFailure *keychainFailure =
                     [[PXRestoreFailure alloc] initWithDomain:PXBackupErrorDomain
-                                                       code:322
-                                                    message:@"Keychain restore failed"];
+                                                       code:keychainFailureCode
+                                                    message:keychainFailureMessage];
                 BOOL keychainFailureResultMarked =
                     [resultAccumulator markComponentFailed:PXRestoreComponentKeychain
                                                    failure:keychainFailure
@@ -4125,20 +4374,6 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                           @"Keychain failure result state must be publishable");
                 (void)keychainFailureResultMarked;
             }
-
-            PXDebugHeader(debugKeychain, @"Keychain After Restore");
-            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"groups=%@", groups ?: @[]]);
-            if (!shouldUseInApp) {
-                NSString *scriptPath = [runner firstExistingPath:@[@"/Library/WeaponX/keychain_backup.sh",
-                                                                  @"/var/jb/Library/WeaponX/keychain_backup.sh",
-                                                                  @"/private/var/jb/Library/WeaponX/keychain_backup.sh"]];
-                if (scriptPath.length && groups.count) {
-                    NSString *csv = [groups componentsJoinedByString:@","];
-                    PXDebugRun(runner, debugKeychain, @"list", [NSString stringWithFormat:@"%@ list %@ --groups %@", PXShellQuote(scriptPath), PXShellQuote(bundleID), PXShellQuote(csv)]);
-                }
-            } else {
-                PXDebugAppendLine(debugKeychain, @"post-restore list skipped (used in-app keychain method)" );
-            }
         }

         // Debug snapshot: after restore
diff --git a/KeychainHelper/PXKeychainHelperResult.h b/KeychainHelper/PXKeychainHelperResult.h
index 07ed146..277232f 100644
--- a/KeychainHelper/PXKeychainHelperResult.h
+++ b/KeychainHelper/PXKeychainHelperResult.h
@@ -34,6 +34,9 @@ typedef NS_ERROR_ENUM(PXKeychainHelperResultErrorDomain,
     PXKeychainHelperResultErrorInvalidAccessGroups = 9,
     PXKeychainHelperResultErrorDuplicateAccessGroup = 10,
     PXKeychainHelperResultErrorAccessGroupRelationInvalid = 11,
+    PXKeychainHelperResultErrorInvalidMachineReadableLine = 12,
+    PXKeychainHelperResultErrorDeserializationFailed = 13,
+    PXKeychainHelperResultErrorNoncanonicalRepresentation = 14,
 };

 __attribute__((objc_subclassing_restricted))
@@ -69,6 +72,9 @@ __attribute__((objc_subclassing_restricted))
                                   fatalError:(NSError * _Nullable)fatalError
                                        error:(NSError * _Nullable * _Nullable)error;

++ (nullable instancetype)resultFromMachineReadableLine:(NSString *)machineReadableLine
+                                                 error:(NSError * _Nullable * _Nullable)error;
+
 - (instancetype)init NS_UNAVAILABLE;
 + (instancetype)new NS_UNAVAILABLE;

diff --git a/KeychainHelper/PXKeychainHelperResult.m b/KeychainHelper/PXKeychainHelperResult.m
index 675d376..da455f9 100644
--- a/KeychainHelper/PXKeychainHelperResult.m
+++ b/KeychainHelper/PXKeychainHelperResult.m
@@ -340,6 +340,77 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
            [effectiveRepresentation isEqualToArray:effectiveAccessGroups];
 }

+static BOOL PXKeychainHelperOperationFromString(NSString *value,
+                                                  PXKeychainHelperOperation *operationOut) {
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    PXKeychainHelperOperation operation = PXKeychainHelperOperationUnknown;
+    if ([value isEqualToString:@"unknown"]) operation = PXKeychainHelperOperationUnknown;
+    else if ([value isEqualToString:@"backup"]) operation = PXKeychainHelperOperationBackup;
+    else if ([value isEqualToString:@"restore"]) operation = PXKeychainHelperOperationRestore;
+    else if ([value isEqualToString:@"wipe"]) operation = PXKeychainHelperOperationWipe;
+    else if ([value isEqualToString:@"list"]) operation = PXKeychainHelperOperationList;
+    else return NO;
+    if (operationOut) *operationOut = operation;
+    return YES;
+}
+
+static BOOL PXKeychainHelperCompletionFromString(NSString *value,
+                                                   PXKeychainHelperCompletion *completionOut) {
+    if (![value isKindOfClass:[NSString class]]) return NO;
+    PXKeychainHelperCompletion completion = PXKeychainHelperCompletionFailed;
+    if ([value isEqualToString:@"failed"]) completion = PXKeychainHelperCompletionFailed;
+    else if ([value isEqualToString:@"completed"]) completion = PXKeychainHelperCompletionCompleted;
+    else if ([value isEqualToString:@"partial"]) completion = PXKeychainHelperCompletionPartial;
+    else return NO;
+    if (completionOut) *completionOut = completion;
+    return YES;
+}
+
+static BOOL PXKeychainHelperResultReadSignedInteger(id value,
+                                                     NSInteger *integerOut) {
+    if (!PXKeychainHelperResultIsNumber(value) ||
+        CFNumberIsFloatType((__bridge CFNumberRef)value)) return NO;
+    int64_t parsed = 0;
+    if (!CFNumberGetValue((__bridge CFNumberRef)value, kCFNumberSInt64Type, &parsed) ||
+        parsed < (int64_t)NSIntegerMin ||
+        parsed > (int64_t)NSIntegerMax) return NO;
+    if (integerOut) *integerOut = (NSInteger)parsed;
+    return YES;
+}
+
+static BOOL PXKeychainHelperResultReadUnsignedCount(id value,
+                                                     NSUInteger *countOut) {
+    if (!PXKeychainHelperResultIsNumber(value) ||
+        CFNumberIsFloatType((__bridge CFNumberRef)value)) return NO;
+    int64_t parsed = 0;
+    if (!CFNumberGetValue((__bridge CFNumberRef)value, kCFNumberSInt64Type, &parsed) ||
+        parsed < 0 || (uint64_t)parsed > (uint64_t)NSUIntegerMax) return NO;
+    if (countOut) *countOut = (NSUInteger)parsed;
+    return YES;
+}
+
+static BOOL PXKeychainHelperResultDictionaryHasExactKeys(id value,
+                                                          NSArray<NSString *> *keys) {
+    if (![value isKindOfClass:[NSDictionary class]]) return NO;
+    NSDictionary *dictionary = value;
+    return dictionary.count == keys.count &&
+        [[NSSet setWithArray:dictionary.allKeys] isEqualToSet:[NSSet setWithArray:keys]];
+}
+
+static NSString *PXKeychainHelperResultDecoderFieldPath(NSError *constructionError) {
+    NSString *path = constructionError.userInfo[PXKeychainHelperResultErrorFieldPathKey];
+    if (![path isKindOfClass:[NSString class]]) return @"$";
+    if ([path hasPrefix:@"$.accessGroups.requested"]) return @"$.accessGroups.requested";
+    if ([path hasPrefix:@"$.accessGroups.effective"]) return @"$.accessGroups.effective";
+    if ([path hasPrefix:@"$.accessGroups"]) return @"$.accessGroups";
+    if ([path hasPrefix:@"$.fatalError"]) return @"$.fatalError";
+    if ([path hasPrefix:@"$.counts"]) return @"$.counts";
+    if ([path isEqualToString:@"$.schemaVersion"] ||
+        [path isEqualToString:@"$.operation"] ||
+        [path isEqualToString:@"$.completion"]) return path;
+    return @"$";
+}
+
 @interface PXKeychainHelperResult ()

 - (instancetype)px_initWithOperation:(PXKeychainHelperOperation)operation
@@ -687,6 +758,165 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
     return result;
 }

++ (instancetype)resultFromMachineReadableLine:(NSString *)machineReadableLine
+                                                 error:(NSError **)error {
+    if (error) *error = nil;
+    if (![machineReadableLine isKindOfClass:[NSString class]] || machineReadableLine.length == 0) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
+                                       @"$", @"The helper result line is invalid.");
+        return nil;
+    }
+    NSData *lineBytes = [machineReadableLine dataUsingEncoding:NSUTF8StringEncoding
+                                          allowLossyConversion:NO];
+    if (!lineBytes || lineBytes.length == 0 ||
+        lineBytes.length > PXKeychainHelperResultMaximumOutputLineBytes ||
+        [machineReadableLine rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
+                                       @"$", @"The helper result line violates the fixed framing contract.");
+        return nil;
+    }
+    NSRange prefix = [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix];
+    if (prefix.location != 0 || prefix.length != PXKeychainHelperResultOutputPrefix.length) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
+                                       @"$", @"The helper result line has an invalid prefix.");
+        return nil;
+    }
+    NSRange suffixRange = NSMakeRange(PXKeychainHelperResultOutputPrefix.length,
+                                      machineReadableLine.length - PXKeychainHelperResultOutputPrefix.length);
+    if (suffixRange.length == 0 ||
+        [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix
+                                  options:0 range:suffixRange].location != NSNotFound) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
+                                       @"$", @"The helper result line has ambiguous framing.");
+        return nil;
+    }
+    NSString *base64 = [machineReadableLine substringWithRange:suffixRange];
+    NSData *base64Bytes = [base64 dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!base64Bytes || base64Bytes.length == 0 ||
+        base64Bytes.length > PXKeychainHelperResultMaximumBase64Bytes ||
+        [base64 rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
+                                       @"$", @"The encoded helper result is invalid.");
+        return nil;
+    }
+    NSData *binaryPlist = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
+    if (!binaryPlist || binaryPlist.length == 0 ||
+        binaryPlist.length > PXKeychainHelperResultMaximumBinaryPlistBytes) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorDeserializationFailed,
+                                       @"$", @"The encoded helper result could not be decoded.");
+        return nil;
+    }
+    NSError *readError = nil;
+    NSPropertyListFormat format = NSPropertyListOpenStepFormat;
+    id decodedObject = [NSPropertyListSerialization propertyListWithData:binaryPlist
+                                                                  options:NSPropertyListImmutable
+                                                                   format:&format error:&readError];
+    if (readError || format != NSPropertyListBinaryFormat_v1_0 ||
+        ![decodedObject isKindOfClass:[NSDictionary class]]) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorDeserializationFailed,
+                                       @"$", @"The helper result property list is invalid.");
+        return nil;
+    }
+    NSDictionary<NSString *, id> *representation = decodedObject;
+    NSArray<NSString *> *rootKeys = @[@"schemaVersion", @"operation", @"completion",
+        @"attemptedCount", @"succeededCount", @"failedCount", @"skippedCount",
+        @"warningCount", @"errorCount", @"fatalError", @"accessGroups"];
+    if (!PXKeychainHelperResultDictionaryHasExactKeys(representation, rootKeys)) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$", @"The helper result graph is not canonical.");
+        return nil;
+    }
+    NSInteger schemaVersion = 0;
+    if (!PXKeychainHelperResultReadSignedInteger(representation[@"schemaVersion"], &schemaVersion) ||
+        schemaVersion != PXKeychainHelperResultSchemaVersion) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.schemaVersion", @"The helper result schema version is invalid.");
+        return nil;
+    }
+    PXKeychainHelperOperation operation = PXKeychainHelperOperationUnknown;
+    if (!PXKeychainHelperOperationFromString(representation[@"operation"], &operation)) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.operation", @"The helper result operation is invalid.");
+        return nil;
+    }
+    PXKeychainHelperCompletion completion = PXKeychainHelperCompletionFailed;
+    if (!PXKeychainHelperCompletionFromString(representation[@"completion"], &completion)) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.completion", @"The helper result completion is invalid.");
+        return nil;
+    }
+    NSUInteger attemptedCount=0, succeededCount=0, failedCount=0, skippedCount=0;
+    NSUInteger warningCount=0, errorCount=0;
+    if (!PXKeychainHelperResultReadUnsignedCount(representation[@"attemptedCount"], &attemptedCount) ||
+        !PXKeychainHelperResultReadUnsignedCount(representation[@"succeededCount"], &succeededCount) ||
+        !PXKeychainHelperResultReadUnsignedCount(representation[@"failedCount"], &failedCount) ||
+        !PXKeychainHelperResultReadUnsignedCount(representation[@"skippedCount"], &skippedCount) ||
+        !PXKeychainHelperResultReadUnsignedCount(representation[@"warningCount"], &warningCount) ||
+        !PXKeychainHelperResultReadUnsignedCount(representation[@"errorCount"], &errorCount)) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.counts", @"A helper result count is invalid.");
+        return nil;
+    }
+    NSDictionary *fatalGraph = representation[@"fatalError"];
+    if (!PXKeychainHelperResultDictionaryHasExactKeys(fatalGraph, @[@"present", @"domain", @"code"])) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.fatalError", @"The fatal error graph is invalid.");
+        return nil;
+    }
+    id presentValue = fatalGraph[@"present"];
+    NSString *fatalDomain = fatalGraph[@"domain"];
+    NSInteger fatalCode = 0;
+    if (!PXKeychainHelperResultIsBoolean(presentValue) ||
+        ![fatalDomain isKindOfClass:[NSString class]] ||
+        !PXKeychainHelperResultReadSignedInteger(fatalGraph[@"code"], &fatalCode)) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.fatalError", @"The fatal error fields are invalid.");
+        return nil;
+    }
+    NSDictionary *groupGraph = representation[@"accessGroups"];
+    if (!PXKeychainHelperResultDictionaryHasExactKeys(groupGraph, @[@"requested", @"effective"])) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.accessGroups", @"The access-group graph is invalid.");
+        return nil;
+    }
+    id requestedGroups = groupGraph[@"requested"];
+    id effectiveGroups = groupGraph[@"effective"];
+    if (![requestedGroups isKindOfClass:[NSArray class]]) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.accessGroups.requested", @"The requested access-group array is invalid.");
+        return nil;
+    }
+    if (![effectiveGroups isKindOfClass:[NSArray class]]) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$.accessGroups.effective", @"The effective access-group array is invalid.");
+        return nil;
+    }
+    NSError *fatalError = [presentValue boolValue]
+        ? [NSError errorWithDomain:fatalDomain code:fatalCode userInfo:nil] : nil;
+    NSError *constructionError = nil;
+    PXKeychainHelperResult *result = [PXKeychainHelperResult
+        resultWithOperation:operation completion:completion attemptedCount:attemptedCount
+        succeededCount:succeededCount failedCount:failedCount skippedCount:skippedCount
+        warningCount:warningCount errorCount:errorCount
+        requestedAccessGroups:requestedGroups effectiveAccessGroups:effectiveGroups
+        fatalError:fatalError error:&constructionError];
+    if (!result) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+            PXKeychainHelperResultDecoderFieldPath(constructionError),
+            @"The helper result graph failed canonical reconstruction.");
+        return nil;
+    }
+    NSData *canonicalLineBytes = [result.machineReadableLine dataUsingEncoding:NSUTF8StringEncoding
+                                                          allowLossyConversion:NO];
+    if (![result.propertyListRepresentation isEqualToDictionary:representation] ||
+        !canonicalLineBytes || ![canonicalLineBytes isEqualToData:lineBytes]) {
+        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
+                                       @"$", @"The helper result is not in canonical form.");
+        return nil;
+    }
+    return result;
+}
+
 - (instancetype)px_initWithOperation:(PXKeychainHelperOperation)operation
                           completion:(PXKeychainHelperCompletion)completion
                       attemptedCount:(NSUInteger)attemptedCount
diff --git a/Makefile b/Makefile
index a9e562e..7b46cb9 100644
--- a/Makefile
+++ b/Makefile
@@ -17,7 +17,7 @@ TOOL_NAME = WeaponXDaemon backup_helper


 # App files
-ProjectX_FILES = $(wildcard *.m) $(wildcard common/*.m)
+ProjectX_FILES = $(wildcard *.m) $(wildcard common/*.m) KeychainHelper/PXKeychainHelperResult.m
 ProjectX_RESOURCE_DIRS = Assets.xcassets
 ProjectX_RESOURCE_FILES = Info.plist Icon.png LaunchScreen.storyboard
 ProjectX_PRIVATE_FRAMEWORKS = FrontBoardServices SpringBoardServices BackBoardServices StoreKitUI MobileCoreServices
diff --git a/PXKeychainHelperInvocationResult.h b/PXKeychainHelperInvocationResult.h
new file mode 100644
--- /dev/null
+++ b/PXKeychainHelperInvocationResult.h
@@ -0,0 +1,51 @@
+#import <Foundation/Foundation.h>
+
+#import "CommandRunner.h"
+#import "KeychainHelper/PXKeychainHelperResult.h"
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSErrorDomain const PXKeychainHelperInvocationResultErrorDomain;
+FOUNDATION_EXPORT NSString * const PXKeychainHelperInvocationResultErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXKeychainHelperInvocationStatus) {
+    PXKeychainHelperInvocationStatusCompleted = 0,
+    PXKeychainHelperInvocationStatusPartial,
+    PXKeychainHelperInvocationStatusHelperFailed,
+    PXKeychainHelperInvocationStatusProtocolFailed,
+    PXKeychainHelperInvocationStatusWrapperFailed,
+    PXKeychainHelperInvocationStatusProcessFailed,
+};
+
+typedef NS_ERROR_ENUM(PXKeychainHelperInvocationResultErrorDomain,
+                      PXKeychainHelperInvocationResultErrorCode) {
+    PXKeychainHelperInvocationResultErrorInvalidInput = 1,
+    PXKeychainHelperInvocationResultErrorInvalidExpectedOperation = 2,
+    PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups = 3,
+    PXKeychainHelperInvocationResultErrorInternalInvariantFailed = 4,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXKeychainHelperInvocationResult : NSObject <NSCopying>
+
+@property (nonatomic, readonly) PXKeychainHelperInvocationStatus status;
+@property (nonatomic, readonly) PXKeychainHelperOperation expectedOperation;
+@property (nonatomic, readonly) NSInteger exitCode;
+@property (nonatomic, copy, nullable, readonly) PXKeychainHelperResult *helperResult;
+@property (nonatomic, readonly) NSUInteger additionalEffectiveAccessGroupCount;
+@property (nonatomic, readonly) BOOL diagnosticOutputTruncated;
+
++ (nullable NSArray<NSString *> *)canonicalAccessGroupsFromArray:(NSArray<NSString *> *)accessGroups
+                                                           error:(NSError * _Nullable * _Nullable)error;
+
++ (nullable instancetype)resultWithCommandResult:(CommandResult * _Nullable)commandResult
+                               expectedOperation:(PXKeychainHelperOperation)expectedOperation
+                  expectedRequestedAccessGroups:(NSArray<NSString *> *)expectedRequestedAccessGroups
+                                           error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXKeychainHelperInvocationResult.m b/PXKeychainHelperInvocationResult.m
new file mode 100644
--- /dev/null
+++ b/PXKeychainHelperInvocationResult.m
@@ -0,0 +1,415 @@
+#import "PXKeychainHelperInvocationResult.h"
+
+NSErrorDomain const PXKeychainHelperInvocationResultErrorDomain =
+    @"com.hydra.projectx.keychain-helper-invocation-result";
+NSString * const PXKeychainHelperInvocationResultErrorFieldPathKey = @"fieldPath";
+
+static const NSUInteger PXKeychainHelperInvocationMaximumAccessGroups = 128;
+static const NSUInteger PXKeychainHelperInvocationMaximumAccessGroupBytes = 512;
+static const NSUInteger PXKeychainHelperInvocationMaximumAccessGroupArrayBytes = 8 * 1024;
+static const NSUInteger PXKeychainHelperInvocationMaximumStdoutBytes = 1024 * 1024;
+static NSString * const PXKeychainHelperInvocationGenericResultToken =
+    @"PXKEYCHAIN_HELPER_RESULT_";
+
+typedef NS_ENUM(NSInteger, PXKeychainHelperMachineScanStatus) {
+    PXKeychainHelperMachineScanStatusNone = 0,
+    PXKeychainHelperMachineScanStatusResult,
+    PXKeychainHelperMachineScanStatusInvalidMarker,
+    PXKeychainHelperMachineScanStatusInvalid,
+};
+
+static void PXKeychainHelperInvocationSetError(
+    NSError **error,
+    PXKeychainHelperInvocationResultErrorCode code,
+    NSString *fieldPath,
+    NSString *description) {
+    if (!error) {
+        return;
+    }
+    *error = [NSError errorWithDomain:PXKeychainHelperInvocationResultErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXKeychainHelperInvocationResultErrorFieldPathKey: fieldPath,
+                             }];
+}
+
+static BOOL PXKeychainHelperInvocationOperationIsSupported(
+    PXKeychainHelperOperation operation) {
+    return operation == PXKeychainHelperOperationBackup ||
+           operation == PXKeychainHelperOperationRestore;
+}
+
+static BOOL PXKeychainHelperInvocationStringHasControlCharacter(NSString *value) {
+    return [value rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location !=
+        NSNotFound;
+}
+
+static NSArray<NSString *> *PXKeychainHelperInvocationCanonicalAccessGroups(
+    id value,
+    NSError **error) {
+    if (![value isKindOfClass:[NSArray class]]) {
+        PXKeychainHelperInvocationSetError(
+            error,
+            PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
+            @"$.expectedRequestedAccessGroups",
+            @"The expected access groups must be an array.");
+        return nil;
+    }
+    NSArray *input = value;
+    if (input.count == 0 ||
+        input.count > PXKeychainHelperInvocationMaximumAccessGroups) {
+        PXKeychainHelperInvocationSetError(
+            error,
+            PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
+            @"$.expectedRequestedAccessGroups",
+            @"The expected access-group array violates the fixed count limit.");
+        return nil;
+    }
+
+    NSMutableArray<NSString *> *canonical = [NSMutableArray arrayWithCapacity:input.count];
+    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:input.count];
+    NSUInteger totalBytes = 0;
+    NSCharacterSet *edgeWhitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    for (id candidate in input) {
+        if (![candidate isKindOfClass:[NSString class]] ||
+            [(NSString *)candidate length] == 0 ||
+            PXKeychainHelperInvocationStringHasControlCharacter(candidate)) {
+            PXKeychainHelperInvocationSetError(
+                error,
+                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
+                @"$.expectedRequestedAccessGroups",
+                @"An expected access-group value is invalid.");
+            return nil;
+        }
+        NSData *sourceUTF8 = [(NSString *)candidate
+            dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+        NSString *sourceRoundTrip = sourceUTF8
+            ? [[NSString alloc] initWithData:sourceUTF8 encoding:NSUTF8StringEncoding]
+            : nil;
+        if (!sourceUTF8 ||
+            ![sourceRoundTrip isEqualToString:(NSString *)candidate]) {
+            PXKeychainHelperInvocationSetError(
+                error,
+                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
+                @"$.expectedRequestedAccessGroups",
+                @"An expected access-group value is not valid UTF-8.");
+            return nil;
+        }
+
+        NSString *trimmed = [(NSString *)candidate
+            stringByTrimmingCharactersInSet:edgeWhitespace];
+        NSData *utf8 = [trimmed dataUsingEncoding:NSUTF8StringEncoding
+                             allowLossyConversion:NO];
+        NSString *roundTrip = utf8
+            ? [[NSString alloc] initWithData:utf8 encoding:NSUTF8StringEncoding]
+            : nil;
+        if (trimmed.length == 0 ||
+            !utf8 ||
+            utf8.length == 0 ||
+            utf8.length > PXKeychainHelperInvocationMaximumAccessGroupBytes ||
+            ![roundTrip isEqualToString:trimmed] ||
+            PXKeychainHelperInvocationStringHasControlCharacter(trimmed) ||
+            [trimmed rangeOfString:@","].location != NSNotFound) {
+            PXKeychainHelperInvocationSetError(
+                error,
+                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
+                @"$.expectedRequestedAccessGroups",
+                @"An expected access-group value violates the canonical contract.");
+            return nil;
+        }
+        if ([seen containsObject:trimmed]) {
+            continue;
+        }
+        if (totalBytes > PXKeychainHelperInvocationMaximumAccessGroupArrayBytes ||
+            utf8.length > PXKeychainHelperInvocationMaximumAccessGroupArrayBytes - totalBytes) {
+            PXKeychainHelperInvocationSetError(
+                error,
+                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
+                @"$.expectedRequestedAccessGroups",
+                @"The expected access groups exceed the fixed byte limit.");
+            return nil;
+        }
+        totalBytes += utf8.length;
+        NSString *snapshot = [trimmed copy];
+        [seen addObject:snapshot];
+        [canonical addObject:snapshot];
+    }
+    if (canonical.count == 0) {
+        PXKeychainHelperInvocationSetError(
+            error,
+            PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
+            @"$.expectedRequestedAccessGroups",
+            @"The canonical expected access-group array is empty.");
+        return nil;
+    }
+    return [canonical copy];
+}
+
+static PXKeychainHelperMachineScanStatus PXKeychainHelperInvocationScanStdout(
+    id stdoutValue,
+    NSString **machineLineOut) {
+    if (machineLineOut) {
+        *machineLineOut = nil;
+    }
+    if (![stdoutValue isKindOfClass:[NSString class]]) {
+        return PXKeychainHelperMachineScanStatusInvalid;
+    }
+    NSString *stdoutString = stdoutValue;
+    NSData *stdoutBytes = [stdoutString dataUsingEncoding:NSUTF8StringEncoding
+                                     allowLossyConversion:NO];
+    if (!stdoutBytes ||
+        stdoutBytes.length > PXKeychainHelperInvocationMaximumStdoutBytes) {
+        return PXKeychainHelperMachineScanStatusInvalid;
+    }
+
+    NSString *invalidMarker =
+        [PXKeychainHelperResultOutputPrefix stringByAppendingString:@"INVALID"];
+    PXKeychainHelperMachineScanStatus candidateStatus =
+        PXKeychainHelperMachineScanStatusNone;
+    NSString *candidateLine = nil;
+    NSArray<NSString *> *lines = [stdoutString componentsSeparatedByString:@"\n"];
+    for (NSString *line in lines) {
+        NSRange genericToken = [line rangeOfString:PXKeychainHelperInvocationGenericResultToken];
+        if (genericToken.location == NSNotFound) {
+            continue;
+        }
+        if (genericToken.location != 0 ||
+            ![line hasPrefix:PXKeychainHelperResultOutputPrefix] ||
+            [line rangeOfString:@"\r"].location != NSNotFound ||
+            candidateStatus != PXKeychainHelperMachineScanStatusNone) {
+            return PXKeychainHelperMachineScanStatusInvalid;
+        }
+        candidateStatus = [line isEqualToString:invalidMarker]
+            ? PXKeychainHelperMachineScanStatusInvalidMarker
+            : PXKeychainHelperMachineScanStatusResult;
+        candidateLine = [line copy];
+    }
+    if (candidateStatus == PXKeychainHelperMachineScanStatusResult && machineLineOut) {
+        *machineLineOut = candidateLine;
+    }
+    return candidateStatus;
+}
+
+static BOOL PXKeychainHelperInvocationExitIsHelperFailure(NSInteger exitCode) {
+    return exitCode == 20 || exitCode == 21 ||
+           exitCode == 30 || exitCode == 40;
+}
+
+static BOOL PXKeychainHelperInvocationExitIsWrapperFailure(NSInteger exitCode) {
+    return exitCode >= 60 && exitCode <= 65;
+}
+
+@interface PXKeychainHelperInvocationResult ()
+
+- (instancetype)px_initWithStatus:(PXKeychainHelperInvocationStatus)status
+                expectedOperation:(PXKeychainHelperOperation)expectedOperation
+                         exitCode:(NSInteger)exitCode
+                     helperResult:(PXKeychainHelperResult * _Nullable)helperResult
+ additionalEffectiveAccessGroupCount:(NSUInteger)additionalEffectiveAccessGroupCount
+        diagnosticOutputTruncated:(BOOL)diagnosticOutputTruncated;
+
+@end
+
+@implementation PXKeychainHelperInvocationResult
+
++ (NSArray<NSString *> *)canonicalAccessGroupsFromArray:(NSArray<NSString *> *)accessGroups
+                                                   error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    return PXKeychainHelperInvocationCanonicalAccessGroups(accessGroups, error);
+}
+
++ (instancetype)resultWithCommandResult:(CommandResult *)commandResult
+                      expectedOperation:(PXKeychainHelperOperation)expectedOperation
+         expectedRequestedAccessGroups:(NSArray<NSString *> *)expectedRequestedAccessGroups
+                                  error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (!PXKeychainHelperInvocationOperationIsSupported(expectedOperation)) {
+        PXKeychainHelperInvocationSetError(
+            error,
+            PXKeychainHelperInvocationResultErrorInvalidExpectedOperation,
+            @"$.expectedOperation",
+            @"The expected helper operation is invalid.");
+        return nil;
+    }
+    NSError *groupError = nil;
+    NSArray<NSString *> *canonicalExpectedGroups =
+        PXKeychainHelperInvocationCanonicalAccessGroups(
+            expectedRequestedAccessGroups,
+            &groupError);
+    if (!canonicalExpectedGroups) {
+        if (error) {
+            *error = groupError;
+        }
+        return nil;
+    }
+
+    BOOL validCommandResult = [commandResult isKindOfClass:[CommandResult class]];
+    NSInteger exitCode = validCommandResult ? commandResult.exitCode : -1;
+    int spawnError = validCommandResult ? commandResult.spawnError : -1;
+    int runnerError = validCommandResult ? commandResult.runnerError : -1;
+    BOOL exitedNormally = validCommandResult && commandResult.exitedNormally;
+    BOOL timedOut = validCommandResult && commandResult.timedOut;
+    int terminationSignal = validCommandResult ? commandResult.terminationSignal : 0;
+    BOOL stdoutTruncated = validCommandResult && commandResult.stdoutTruncated;
+    BOOL diagnosticOutputTruncated = validCommandResult && commandResult.stderrTruncated;
+    NSString *stdoutSnapshot = validCommandResult &&
+        [commandResult.stdoutString isKindOfClass:[NSString class]]
+            ? [commandResult.stdoutString copy]
+            : nil;
+    NSString *stderrSnapshot = validCommandResult &&
+        [commandResult.stderrString isKindOfClass:[NSString class]]
+            ? [commandResult.stderrString copy]
+            : nil;
+    BOOL processUsable = validCommandResult &&
+        stdoutSnapshot != nil &&
+        stderrSnapshot != nil &&
+        spawnError == 0 &&
+        runnerError == 0 &&
+        exitedNormally &&
+        !timedOut &&
+        terminationSignal == 0 &&
+        !stdoutTruncated;
+    if (!processUsable) {
+        return [[PXKeychainHelperInvocationResult alloc]
+            px_initWithStatus:PXKeychainHelperInvocationStatusProcessFailed
+            expectedOperation:expectedOperation
+            exitCode:exitCode
+            helperResult:nil
+            additionalEffectiveAccessGroupCount:0
+            diagnosticOutputTruncated:diagnosticOutputTruncated];
+    }
+
+    if (PXKeychainHelperInvocationExitIsWrapperFailure(exitCode)) {
+        return [[PXKeychainHelperInvocationResult alloc]
+            px_initWithStatus:PXKeychainHelperInvocationStatusWrapperFailed
+            expectedOperation:expectedOperation
+            exitCode:exitCode
+            helperResult:nil
+            additionalEffectiveAccessGroupCount:0
+            diagnosticOutputTruncated:diagnosticOutputTruncated];
+    }
+    BOOL recognizedDirectExit = exitCode == 0 || exitCode == 10 ||
+        PXKeychainHelperInvocationExitIsHelperFailure(exitCode) || exitCode == 50;
+    if (!recognizedDirectExit) {
+        return [[PXKeychainHelperInvocationResult alloc]
+            px_initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
+            expectedOperation:expectedOperation
+            exitCode:exitCode
+            helperResult:nil
+            additionalEffectiveAccessGroupCount:0
+            diagnosticOutputTruncated:diagnosticOutputTruncated];
+    }
+
+    NSString *machineLine = nil;
+    PXKeychainHelperMachineScanStatus scanStatus =
+        PXKeychainHelperInvocationScanStdout(stdoutSnapshot, &machineLine);
+    if (exitCode == 50) {
+        if (scanStatus != PXKeychainHelperMachineScanStatusInvalidMarker) {
+            return [[PXKeychainHelperInvocationResult alloc]
+                px_initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
+                expectedOperation:expectedOperation
+                exitCode:exitCode
+                helperResult:nil
+                additionalEffectiveAccessGroupCount:0
+                diagnosticOutputTruncated:diagnosticOutputTruncated];
+        }
+        return [[PXKeychainHelperInvocationResult alloc]
+            px_initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
+            expectedOperation:expectedOperation
+            exitCode:exitCode
+            helperResult:nil
+            additionalEffectiveAccessGroupCount:0
+            diagnosticOutputTruncated:diagnosticOutputTruncated];
+    }
+    if (scanStatus != PXKeychainHelperMachineScanStatusResult ||
+        machineLine.length == 0) {
+        return [[PXKeychainHelperInvocationResult alloc]
+            px_initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
+            expectedOperation:expectedOperation
+            exitCode:exitCode
+            helperResult:nil
+            additionalEffectiveAccessGroupCount:0
+            diagnosticOutputTruncated:diagnosticOutputTruncated];
+    }
+
+    NSError *decodeError = nil;
+    PXKeychainHelperResult *helperResult =
+        [PXKeychainHelperResult resultFromMachineReadableLine:machineLine
+                                                       error:&decodeError];
+    (void)decodeError;
+    if (!helperResult ||
+        helperResult.operation != expectedOperation ||
+        ![helperResult.requestedAccessGroups isEqualToArray:canonicalExpectedGroups]) {
+        return [[PXKeychainHelperInvocationResult alloc]
+            px_initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
+            expectedOperation:expectedOperation
+            exitCode:exitCode
+            helperResult:nil
+            additionalEffectiveAccessGroupCount:0
+            diagnosticOutputTruncated:diagnosticOutputTruncated];
+    }
+
+    PXKeychainHelperInvocationStatus status =
+        PXKeychainHelperInvocationStatusProtocolFailed;
+    if (exitCode == 0 &&
+        helperResult.completion == PXKeychainHelperCompletionCompleted) {
+        status = PXKeychainHelperInvocationStatusCompleted;
+    } else if (exitCode == 10 &&
+               helperResult.completion == PXKeychainHelperCompletionPartial) {
+        status = PXKeychainHelperInvocationStatusPartial;
+    } else if (PXKeychainHelperInvocationExitIsHelperFailure(exitCode) &&
+               helperResult.completion == PXKeychainHelperCompletionFailed &&
+               helperResult.fatalErrorPresent) {
+        status = PXKeychainHelperInvocationStatusHelperFailed;
+    }
+    if (status == PXKeychainHelperInvocationStatusProtocolFailed) {
+        return [[PXKeychainHelperInvocationResult alloc]
+            px_initWithStatus:status
+            expectedOperation:expectedOperation
+            exitCode:exitCode
+            helperResult:nil
+            additionalEffectiveAccessGroupCount:0
+            diagnosticOutputTruncated:diagnosticOutputTruncated];
+    }
+
+    NSUInteger additionalEffectiveAccessGroupCount =
+        helperResult.effectiveAccessGroups.count -
+        helperResult.requestedAccessGroups.count;
+    return [[PXKeychainHelperInvocationResult alloc]
+        px_initWithStatus:status
+        expectedOperation:expectedOperation
+        exitCode:exitCode
+        helperResult:helperResult
+        additionalEffectiveAccessGroupCount:additionalEffectiveAccessGroupCount
+        diagnosticOutputTruncated:diagnosticOutputTruncated];
+}
+
+- (instancetype)px_initWithStatus:(PXKeychainHelperInvocationStatus)status
+                expectedOperation:(PXKeychainHelperOperation)expectedOperation
+                         exitCode:(NSInteger)exitCode
+                     helperResult:(PXKeychainHelperResult *)helperResult
+ additionalEffectiveAccessGroupCount:(NSUInteger)additionalEffectiveAccessGroupCount
+        diagnosticOutputTruncated:(BOOL)diagnosticOutputTruncated {
+    self = [super init];
+    if (self) {
+        _status = status;
+        _expectedOperation = expectedOperation;
+        _exitCode = exitCode;
+        _helperResult = [helperResult copy];
+        _additionalEffectiveAccessGroupCount = additionalEffectiveAccessGroupCount;
+        _diagnosticOutputTruncated = diagnosticOutputTruncated;
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
```

## Static gates

| Gate | Observed | Result |
| --- | --- | --- |
| Schema version | 2 | PASS |
| V2 prefix definition | 1 | PASS |
| V1 production decoder | 0 | PASS |
| Strict decode API | 1 | PASS |
| Canonical line round-trip | 1 | PASS |
| Invocation parser header/implementation | 1/1 | PASS |
| Invocation enum values | 6 | PASS |
| ProjectX result source inclusion | 1 | PASS |
| backup_helper result source inclusion | 1 | PASS |
| Keychain runAndCapture operational sites | 0 | PASS |
| Bounded executable invocation | 1 centralized | PASS |
| Timeout/output cap | 300 s / 1 MiB | PASS |
| Raw stdout/stderr warning sites in shell Keychain path | 0/0 | PASS |
| PXKeychainRestoreResult_ references | 0 | PASS |
| Keychain raw wrapper list calls | 0 | PASS |
| Requested group exact verification | 1 | PASS |
| Effective superset count handling | 1 | PASS |
| Exit 10 handling | backup + restore | PASS |
| Backup Partial with successes | accepted after cross-check | PASS |
| Partial item-count cross-check | 1 | PASS |
| Restore warning-only Partial | Succeeded | PASS |
| Restore substantive Partial | Failed code 323 | PASS |
| PXRestoreResult diff | 0 | PASS |
| Wrapper/direct helper/core/bridge diffs | 0 | PASS |
| TASK-4.9 implementation | 0 | PASS |
| Decoder model assertions | 200,039 | PASS |
| Invocation model assertions | 253,990 | PASS |
| Manager policy model assertions | 600,082 | PASS |
| Objective-C/API static assertions | 66 | PASS |
| Manager/privacy static assertions | 54 | PASS |
| Protected/scope static assertions | 112 | PASS |
| Protected production hashes | 74 | PASS |
| Security whole/restore | 6,1,1,1 / 1,1,1,0 | PASS |

## Explicit scenarios

Explicit scenarios: 710.
| # | Category | Stimulus | Expected outcome |
| --- | --- | --- | --- |
| 1 | decoder | valid completed canonical V2 | decode succeeds and canonical line is byte-identical |
| 2 | decoder | valid partial canonical V2 | decode succeeds with partial completion and unchanged counters |
| 3 | decoder | valid failed canonical V2 | decode succeeds with fatalError.present=true |
| 4 | decoder | nil input | reject with bounded invalid-line error |
| 5 | decoder | NSNumber input | reject non-string input |
| 6 | decoder | empty string | reject empty machine line |
| 7 | decoder | V1 prefix | reject; no downgrade |
| 8 | decoder | missing prefix | reject |
| 9 | decoder | V2 prefix mid-line | reject |
| 10 | decoder | duplicate exact V2 prefix | reject |
| 11 | decoder | empty base64 suffix | reject |
| 12 | decoder | invalid base64 character | reject |
| 13 | decoder | base64 containing space | reject |
| 14 | decoder | base64 containing tab | reject |
| 15 | decoder | line containing LF | reject |
| 16 | decoder | line containing CR | reject |
| 17 | decoder | decoded empty data | reject |
| 18 | decoder | decoded payload above 32 KiB | reject |
| 19 | decoder | XML plist payload | reject non-binary format |
| 20 | decoder | malformed binary plist | reject deserialization |
| 21 | decoder | array plist root | reject non-dictionary root |
| 22 | decoder | string plist root | reject non-dictionary root |
| 23 | decoder | 10 root keys | reject missing key |
| 24 | decoder | 12 root keys | reject extra key |
| 25 | decoder | unknown root key | reject exact-key mismatch |
| 26 | decoder | missing accessGroups | reject |
| 27 | decoder | accessGroups array instead of dictionary | reject |
| 28 | decoder | fatalError array instead of dictionary | reject |
| 29 | decoder | schemaVersion string | reject type |
| 30 | decoder | schemaVersion Boolean | reject Boolean numeric coercion |
| 31 | decoder | schemaVersion float | reject floating numeric coercion |
| 32 | decoder | schemaVersion negative | reject |
| 33 | decoder | schemaVersion 1 | reject V1 graph |
| 34 | decoder | schemaVersion 3 | reject unsupported graph |
| 35 | decoder | unknown operation string | reject |
| 36 | decoder | unknown completion string | reject |
| 37 | decoder | Boolean attemptedCount | reject |
| 38 | decoder | floating succeededCount | reject |
| 39 | decoder | negative failedCount | reject |
| 40 | decoder | count above fixed one-million bound | reject during canonical factory reconstruction |
| 41 | decoder | fatal present NSNumber 1 | reject non-CFBoolean |
| 42 | decoder | fatal domain invalid | reject through factory |
| 43 | decoder | requested groups non-array | reject |
| 44 | decoder | effective groups non-array | reject |
| 45 | decoder | requested duplicate group | reject |
| 46 | decoder | requested group with comma | reject |
| 47 | decoder | requested not subset of effective | reject |
| 48 | decoder | alternative binary key order | reject unless byte-identical canonical emission |
| 49 | decoder | canonical graph with altered base64 encoding | reject noncanonical line |
| 50 | decoder | mutable-source graph copied before mutation | decoded immutable result remains unchanged |
| 51 | decoder | canonical backup/completed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 52 | decoder | canonical backup/completed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 53 | decoder | canonical backup/completed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 54 | decoder | canonical backup/completed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 55 | decoder | canonical backup/partial fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 56 | decoder | canonical backup/partial fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 57 | decoder | canonical backup/partial fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 58 | decoder | canonical backup/partial fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 59 | decoder | canonical backup/failed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 60 | decoder | canonical backup/failed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 61 | decoder | canonical backup/failed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 62 | decoder | canonical backup/failed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 63 | decoder | canonical restore/completed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 64 | decoder | canonical restore/completed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 65 | decoder | canonical restore/completed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 66 | decoder | canonical restore/completed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 67 | decoder | canonical restore/partial fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 68 | decoder | canonical restore/partial fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 69 | decoder | canonical restore/partial fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 70 | decoder | canonical restore/partial fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 71 | decoder | canonical restore/failed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 72 | decoder | canonical restore/failed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 73 | decoder | canonical restore/failed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 74 | decoder | canonical restore/failed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 75 | decoder | canonical wipe/completed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 76 | decoder | canonical wipe/completed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 77 | decoder | canonical wipe/completed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 78 | decoder | canonical wipe/completed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 79 | decoder | canonical wipe/partial fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 80 | decoder | canonical wipe/partial fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 81 | decoder | canonical wipe/partial fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 82 | decoder | canonical wipe/partial fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 83 | decoder | canonical wipe/failed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 84 | decoder | canonical wipe/failed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 85 | decoder | canonical wipe/failed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 86 | decoder | canonical wipe/failed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 87 | decoder | canonical list/completed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 88 | decoder | canonical list/completed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 89 | decoder | canonical list/completed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 90 | decoder | canonical list/completed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 91 | decoder | canonical list/partial fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 92 | decoder | canonical list/partial fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 93 | decoder | canonical list/partial fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 94 | decoder | canonical list/partial fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 95 | decoder | canonical list/failed fixture with exact groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 96 | decoder | canonical list/failed fixture with effective superset | canonical decode succeeds when completion counters/fatal graph are consistent |
| 97 | decoder | canonical list/failed fixture with empty requested with nonempty effective | canonical decode succeeds when completion counters/fatal graph are consistent |
| 98 | decoder | canonical list/failed fixture with two ordered requested groups | canonical decode succeeds when completion counters/fatal graph are consistent |
| 99 | decoder | attemptedCount encoded as CFBoolean | reject noncanonical numeric field |
| 100 | decoder | attemptedCount encoded as double | reject noncanonical numeric field |
| 101 | decoder | attemptedCount encoded as negative integer | reject noncanonical numeric field |
| 102 | decoder | attemptedCount encoded as one-million boundary | accept exact nonnegative integer at the boundary |
| 103 | decoder | attemptedCount encoded as one-million-plus-one | reject noncanonical numeric field |
| 104 | decoder | succeededCount encoded as CFBoolean | reject noncanonical numeric field |
| 105 | decoder | succeededCount encoded as double | reject noncanonical numeric field |
| 106 | decoder | succeededCount encoded as negative integer | reject noncanonical numeric field |
| 107 | decoder | succeededCount encoded as one-million boundary | accept exact nonnegative integer at the boundary |
| 108 | decoder | succeededCount encoded as one-million-plus-one | reject noncanonical numeric field |
| 109 | decoder | failedCount encoded as CFBoolean | reject noncanonical numeric field |
| 110 | decoder | failedCount encoded as double | reject noncanonical numeric field |
| 111 | decoder | failedCount encoded as negative integer | reject noncanonical numeric field |
| 112 | decoder | failedCount encoded as one-million boundary | accept exact nonnegative integer at the boundary |
| 113 | decoder | failedCount encoded as one-million-plus-one | reject noncanonical numeric field |
| 114 | decoder | skippedCount encoded as CFBoolean | reject noncanonical numeric field |
| 115 | decoder | skippedCount encoded as double | reject noncanonical numeric field |
| 116 | decoder | skippedCount encoded as negative integer | reject noncanonical numeric field |
| 117 | decoder | skippedCount encoded as one-million boundary | accept exact nonnegative integer at the boundary |
| 118 | decoder | skippedCount encoded as one-million-plus-one | reject noncanonical numeric field |
| 119 | decoder | warningCount encoded as CFBoolean | reject noncanonical numeric field |
| 120 | decoder | warningCount encoded as double | reject noncanonical numeric field |
| 121 | decoder | warningCount encoded as negative integer | reject noncanonical numeric field |
| 122 | decoder | warningCount encoded as one-million boundary | accept exact nonnegative integer at the boundary |
| 123 | decoder | warningCount encoded as one-million-plus-one | reject noncanonical numeric field |
| 124 | decoder | errorCount encoded as CFBoolean | reject noncanonical numeric field |
| 125 | decoder | errorCount encoded as double | reject noncanonical numeric field |
| 126 | decoder | errorCount encoded as negative integer | reject noncanonical numeric field |
| 127 | decoder | errorCount encoded as one-million boundary | accept exact nonnegative integer at the boundary |
| 128 | decoder | errorCount encoded as one-million-plus-one | reject noncanonical numeric field |
| 129 | decoder | canonical base64 fixture with deterministic byte mutation #1 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 130 | decoder | canonical base64 fixture with deterministic byte mutation #2 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 131 | decoder | canonical base64 fixture with deterministic byte mutation #3 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 132 | decoder | canonical base64 fixture with deterministic byte mutation #4 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 133 | decoder | canonical base64 fixture with deterministic byte mutation #5 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 134 | decoder | canonical base64 fixture with deterministic byte mutation #6 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 135 | decoder | canonical base64 fixture with deterministic byte mutation #7 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 136 | decoder | canonical base64 fixture with deterministic byte mutation #8 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 137 | decoder | canonical base64 fixture with deterministic byte mutation #9 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 138 | decoder | canonical base64 fixture with deterministic byte mutation #10 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 139 | decoder | canonical base64 fixture with deterministic byte mutation #11 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 140 | decoder | canonical base64 fixture with deterministic byte mutation #12 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 141 | decoder | canonical base64 fixture with deterministic byte mutation #13 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 142 | decoder | canonical base64 fixture with deterministic byte mutation #14 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 143 | decoder | canonical base64 fixture with deterministic byte mutation #15 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 144 | decoder | canonical base64 fixture with deterministic byte mutation #16 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 145 | decoder | canonical base64 fixture with deterministic byte mutation #17 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 146 | decoder | canonical base64 fixture with deterministic byte mutation #18 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 147 | decoder | canonical base64 fixture with deterministic byte mutation #19 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 148 | decoder | canonical base64 fixture with deterministic byte mutation #20 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 149 | decoder | canonical base64 fixture with deterministic byte mutation #21 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 150 | decoder | canonical base64 fixture with deterministic byte mutation #22 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 151 | decoder | canonical base64 fixture with deterministic byte mutation #23 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 152 | decoder | canonical base64 fixture with deterministic byte mutation #24 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 153 | decoder | canonical base64 fixture with deterministic byte mutation #25 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 154 | decoder | canonical base64 fixture with deterministic byte mutation #26 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 155 | decoder | canonical base64 fixture with deterministic byte mutation #27 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 156 | decoder | canonical base64 fixture with deterministic byte mutation #28 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 157 | decoder | canonical base64 fixture with deterministic byte mutation #29 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 158 | decoder | canonical base64 fixture with deterministic byte mutation #30 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 159 | decoder | canonical base64 fixture with deterministic byte mutation #31 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 160 | decoder | canonical base64 fixture with deterministic byte mutation #32 | reject unless mutation itself forms a different fully canonical V2 line with byte-equal re-emission |
| 161 | invocation | nil CommandResult | ProcessFailed |
| 162 | invocation | spawnError nonzero | ProcessFailed |
| 163 | invocation | runnerError nonzero | ProcessFailed |
| 164 | invocation | timedOut true | ProcessFailed without parsing stdout |
| 165 | invocation | termination signal 9 | ProcessFailed without parsing stdout |
| 166 | invocation | exitedNormally false | ProcessFailed |
| 167 | invocation | stdoutTruncated true | ProcessFailed |
| 168 | invocation | stderrTruncated true with healthy stdout | continue parsing and set diagnosticOutputTruncated |
| 169 | invocation | stdout non-string | ProcessFailed |
| 170 | invocation | stderr non-string | ProcessFailed |
| 171 | invocation | no machine line | ProtocolFailed for recognized direct exit |
| 172 | invocation | one exact V2 line | decode candidate |
| 173 | invocation | two exact V2 lines | ProtocolFailed |
| 174 | invocation | V1 line only | ProtocolFailed |
| 175 | invocation | V1 plus V2 | ProtocolFailed |
| 176 | invocation | V2 token mid-line | ProtocolFailed |
| 177 | invocation | exact INVALID marker | ProtocolFailed for exit 50 |
| 178 | invocation | human line before one V2 | ignore human line and decode V2 |
| 179 | invocation | V2 without final newline | decode |
| 180 | invocation | CRLF candidate | ProtocolFailed |
| 181 | invocation | unknown generic result token | ProtocolFailed |
| 182 | invocation | stdout exactly one MiB and canonical candidate present | scan within bound unless runner marks truncation |
| 183 | invocation | exit 0 with completed payload/marker | Completed |
| 184 | invocation | exit 0 with partial payload/marker | ProtocolFailed |
| 185 | invocation | exit 0 with failed payload/marker | ProtocolFailed |
| 186 | invocation | exit 0 with INVALID payload/marker | ProtocolFailed |
| 187 | invocation | exit 0 with missing payload/marker | ProtocolFailed |
| 188 | invocation | exit 10 with completed payload/marker | ProtocolFailed |
| 189 | invocation | exit 10 with partial payload/marker | Partial |
| 190 | invocation | exit 10 with failed payload/marker | ProtocolFailed |
| 191 | invocation | exit 10 with INVALID payload/marker | ProtocolFailed |
| 192 | invocation | exit 10 with missing payload/marker | ProtocolFailed |
| 193 | invocation | exit 20 with completed payload/marker | ProtocolFailed |
| 194 | invocation | exit 20 with partial payload/marker | ProtocolFailed |
| 195 | invocation | exit 20 with failed payload/marker | HelperFailed only with fatalError.present=true |
| 196 | invocation | exit 20 with INVALID payload/marker | ProtocolFailed |
| 197 | invocation | exit 20 with missing payload/marker | ProtocolFailed |
| 198 | invocation | exit 21 with completed payload/marker | ProtocolFailed |
| 199 | invocation | exit 21 with partial payload/marker | ProtocolFailed |
| 200 | invocation | exit 21 with failed payload/marker | HelperFailed only with fatalError.present=true |
| 201 | invocation | exit 21 with INVALID payload/marker | ProtocolFailed |
| 202 | invocation | exit 21 with missing payload/marker | ProtocolFailed |
| 203 | invocation | exit 30 with completed payload/marker | ProtocolFailed |
| 204 | invocation | exit 30 with partial payload/marker | ProtocolFailed |
| 205 | invocation | exit 30 with failed payload/marker | HelperFailed only with fatalError.present=true |
| 206 | invocation | exit 30 with INVALID payload/marker | ProtocolFailed |
| 207 | invocation | exit 30 with missing payload/marker | ProtocolFailed |
| 208 | invocation | exit 40 with completed payload/marker | ProtocolFailed |
| 209 | invocation | exit 40 with partial payload/marker | ProtocolFailed |
| 210 | invocation | exit 40 with failed payload/marker | HelperFailed only with fatalError.present=true |
| 211 | invocation | exit 40 with INVALID payload/marker | ProtocolFailed |
| 212 | invocation | exit 40 with missing payload/marker | ProtocolFailed |
| 213 | invocation | exit 50 with completed payload/marker | ProtocolFailed |
| 214 | invocation | exit 50 with partial payload/marker | ProtocolFailed |
| 215 | invocation | exit 50 with failed payload/marker | ProtocolFailed |
| 216 | invocation | exit 50 with INVALID payload/marker | ProtocolFailed |
| 217 | invocation | exit 50 with missing payload/marker | ProtocolFailed |
| 218 | invocation | exit 60 with completed payload/marker | WrapperFailed and ignore any machine line |
| 219 | invocation | exit 60 with partial payload/marker | WrapperFailed and ignore any machine line |
| 220 | invocation | exit 60 with failed payload/marker | WrapperFailed and ignore any machine line |
| 221 | invocation | exit 60 with INVALID payload/marker | WrapperFailed and ignore any machine line |
| 222 | invocation | exit 60 with missing payload/marker | WrapperFailed and ignore any machine line |
| 223 | invocation | exit 61 with completed payload/marker | WrapperFailed and ignore any machine line |
| 224 | invocation | exit 61 with partial payload/marker | WrapperFailed and ignore any machine line |
| 225 | invocation | exit 61 with failed payload/marker | WrapperFailed and ignore any machine line |
| 226 | invocation | exit 61 with INVALID payload/marker | WrapperFailed and ignore any machine line |
| 227 | invocation | exit 61 with missing payload/marker | WrapperFailed and ignore any machine line |
| 228 | invocation | exit 62 with completed payload/marker | WrapperFailed and ignore any machine line |
| 229 | invocation | exit 62 with partial payload/marker | WrapperFailed and ignore any machine line |
| 230 | invocation | exit 62 with failed payload/marker | WrapperFailed and ignore any machine line |
| 231 | invocation | exit 62 with INVALID payload/marker | WrapperFailed and ignore any machine line |
| 232 | invocation | exit 62 with missing payload/marker | WrapperFailed and ignore any machine line |
| 233 | invocation | exit 63 with completed payload/marker | WrapperFailed and ignore any machine line |
| 234 | invocation | exit 63 with partial payload/marker | WrapperFailed and ignore any machine line |
| 235 | invocation | exit 63 with failed payload/marker | WrapperFailed and ignore any machine line |
| 236 | invocation | exit 63 with INVALID payload/marker | WrapperFailed and ignore any machine line |
| 237 | invocation | exit 63 with missing payload/marker | WrapperFailed and ignore any machine line |
| 238 | invocation | exit 64 with completed payload/marker | WrapperFailed and ignore any machine line |
| 239 | invocation | exit 64 with partial payload/marker | WrapperFailed and ignore any machine line |
| 240 | invocation | exit 64 with failed payload/marker | WrapperFailed and ignore any machine line |
| 241 | invocation | exit 64 with INVALID payload/marker | WrapperFailed and ignore any machine line |
| 242 | invocation | exit 64 with missing payload/marker | WrapperFailed and ignore any machine line |
| 243 | invocation | exit 65 with completed payload/marker | WrapperFailed and ignore any machine line |
| 244 | invocation | exit 65 with partial payload/marker | WrapperFailed and ignore any machine line |
| 245 | invocation | exit 65 with failed payload/marker | WrapperFailed and ignore any machine line |
| 246 | invocation | exit 65 with INVALID payload/marker | WrapperFailed and ignore any machine line |
| 247 | invocation | exit 65 with missing payload/marker | WrapperFailed and ignore any machine line |
| 248 | invocation | exit -1 with completed payload/marker | ProtocolFailed |
| 249 | invocation | exit -1 with partial payload/marker | ProtocolFailed |
| 250 | invocation | exit -1 with failed payload/marker | ProtocolFailed |
| 251 | invocation | exit -1 with INVALID payload/marker | ProtocolFailed |
| 252 | invocation | exit -1 with missing payload/marker | ProtocolFailed |
| 253 | invocation | exit 1 with completed payload/marker | ProtocolFailed |
| 254 | invocation | exit 1 with partial payload/marker | ProtocolFailed |
| 255 | invocation | exit 1 with failed payload/marker | ProtocolFailed |
| 256 | invocation | exit 1 with INVALID payload/marker | ProtocolFailed |
| 257 | invocation | exit 1 with missing payload/marker | ProtocolFailed |
| 258 | invocation | exit 11 with completed payload/marker | ProtocolFailed |
| 259 | invocation | exit 11 with partial payload/marker | ProtocolFailed |
| 260 | invocation | exit 11 with failed payload/marker | ProtocolFailed |
| 261 | invocation | exit 11 with INVALID payload/marker | ProtocolFailed |
| 262 | invocation | exit 11 with missing payload/marker | ProtocolFailed |
| 263 | invocation | exit 42 with completed payload/marker | ProtocolFailed |
| 264 | invocation | exit 42 with partial payload/marker | ProtocolFailed |
| 265 | invocation | exit 42 with failed payload/marker | ProtocolFailed |
| 266 | invocation | exit 42 with INVALID payload/marker | ProtocolFailed |
| 267 | invocation | exit 42 with missing payload/marker | ProtocolFailed |
| 268 | invocation | exit 66 with completed payload/marker | ProtocolFailed |
| 269 | invocation | exit 66 with partial payload/marker | ProtocolFailed |
| 270 | invocation | exit 66 with failed payload/marker | ProtocolFailed |
| 271 | invocation | exit 66 with INVALID payload/marker | ProtocolFailed |
| 272 | invocation | exit 66 with missing payload/marker | ProtocolFailed |
| 273 | invocation | exit 127 with completed payload/marker | ProtocolFailed |
| 274 | invocation | exit 127 with partial payload/marker | ProtocolFailed |
| 275 | invocation | exit 127 with failed payload/marker | ProtocolFailed |
| 276 | invocation | exit 127 with INVALID payload/marker | ProtocolFailed |
| 277 | invocation | exit 127 with missing payload/marker | ProtocolFailed |
| 278 | invocation | exit 255 with completed payload/marker | ProtocolFailed |
| 279 | invocation | exit 255 with partial payload/marker | ProtocolFailed |
| 280 | invocation | exit 255 with failed payload/marker | ProtocolFailed |
| 281 | invocation | exit 255 with INVALID payload/marker | ProtocolFailed |
| 282 | invocation | exit 255 with missing payload/marker | ProtocolFailed |
| 283 | invocation | expected operation backup; payload operation backup | continue only when payload equals expected; otherwise ProtocolFailed |
| 284 | invocation | expected operation backup; payload operation restore | continue only when payload equals expected; otherwise ProtocolFailed |
| 285 | invocation | expected operation backup; payload operation wipe | continue only when payload equals expected; otherwise ProtocolFailed |
| 286 | invocation | expected operation backup; payload operation list | continue only when payload equals expected; otherwise ProtocolFailed |
| 287 | invocation | expected operation backup; payload operation unknown | continue only when payload equals expected; otherwise ProtocolFailed |
| 288 | invocation | expected operation restore; payload operation backup | continue only when payload equals expected; otherwise ProtocolFailed |
| 289 | invocation | expected operation restore; payload operation restore | continue only when payload equals expected; otherwise ProtocolFailed |
| 290 | invocation | expected operation restore; payload operation wipe | continue only when payload equals expected; otherwise ProtocolFailed |
| 291 | invocation | expected operation restore; payload operation list | continue only when payload equals expected; otherwise ProtocolFailed |
| 292 | invocation | expected operation restore; payload operation unknown | continue only when payload equals expected; otherwise ProtocolFailed |
| 293 | invocation | backup invocation with exact ordered array | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 294 | invocation | backup invocation with same set different order | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 295 | invocation | backup invocation with duplicate manager groups | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 296 | invocation | backup invocation with surrounding spaces | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 297 | invocation | backup invocation with missing expected group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 298 | invocation | backup invocation with extra payload requested group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 299 | invocation | backup invocation with empty expected array | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 300 | invocation | backup invocation with comma-containing group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 301 | invocation | backup invocation with control-containing group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 302 | invocation | backup invocation with effective proper superset | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 303 | invocation | restore invocation with exact ordered array | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 304 | invocation | restore invocation with same set different order | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 305 | invocation | restore invocation with duplicate manager groups | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 306 | invocation | restore invocation with surrounding spaces | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 307 | invocation | restore invocation with missing expected group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 308 | invocation | restore invocation with extra payload requested group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 309 | invocation | restore invocation with empty expected array | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 310 | invocation | restore invocation with comma-containing group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 311 | invocation | restore invocation with control-containing group | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 312 | invocation | restore invocation with effective proper superset | canonicalize manager input, require exact ordered requested equality, and allow effective superset only |
| 313 | backup | Completed, succeededCount=0, output=missing | reject helper artifact before manifest publication |
| 314 | backup | Completed, succeededCount=0, output=valid-count-match | accept verified helper artifact, including zero-item Completed |
| 315 | backup | Completed, succeededCount=0, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 316 | backup | Completed, succeededCount=1, output=missing | reject helper artifact before manifest publication |
| 317 | backup | Completed, succeededCount=1, output=valid-count-match | accept verified helper artifact, including zero-item Completed |
| 318 | backup | Completed, succeededCount=1, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 319 | backup | Completed, succeededCount=3, output=missing | reject helper artifact before manifest publication |
| 320 | backup | Completed, succeededCount=3, output=valid-count-match | accept verified helper artifact, including zero-item Completed |
| 321 | backup | Completed, succeededCount=3, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 322 | backup | Partial, succeededCount=0, output=missing | reject helper artifact before manifest publication |
| 323 | backup | Partial, succeededCount=0, output=valid-count-match | reject helper artifact before manifest publication |
| 324 | backup | Partial, succeededCount=0, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 325 | backup | Partial, succeededCount=1, output=missing | reject helper artifact before manifest publication |
| 326 | backup | Partial, succeededCount=1, output=valid-count-match | accept verified partial artifact and add count summary warning |
| 327 | backup | Partial, succeededCount=1, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 328 | backup | Partial, succeededCount=3, output=missing | reject helper artifact before manifest publication |
| 329 | backup | Partial, succeededCount=3, output=valid-count-match | accept verified partial artifact and add count summary warning |
| 330 | backup | Partial, succeededCount=3, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 331 | backup | HelperFailed, succeededCount=0, output=missing | reject helper artifact before manifest publication |
| 332 | backup | HelperFailed, succeededCount=0, output=valid-count-match | reject helper artifact before manifest publication |
| 333 | backup | HelperFailed, succeededCount=0, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 334 | backup | HelperFailed, succeededCount=1, output=missing | reject helper artifact before manifest publication |
| 335 | backup | HelperFailed, succeededCount=1, output=valid-count-match | reject helper artifact before manifest publication |
| 336 | backup | HelperFailed, succeededCount=1, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 337 | backup | HelperFailed, succeededCount=3, output=missing | reject helper artifact before manifest publication |
| 338 | backup | HelperFailed, succeededCount=3, output=valid-count-match | reject helper artifact before manifest publication |
| 339 | backup | HelperFailed, succeededCount=3, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 340 | backup | ProtocolFailed, succeededCount=0, output=missing | reject helper artifact before manifest publication |
| 341 | backup | ProtocolFailed, succeededCount=0, output=valid-count-match | reject helper artifact before manifest publication |
| 342 | backup | ProtocolFailed, succeededCount=0, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 343 | backup | ProtocolFailed, succeededCount=1, output=missing | reject helper artifact before manifest publication |
| 344 | backup | ProtocolFailed, succeededCount=1, output=valid-count-match | reject helper artifact before manifest publication |
| 345 | backup | ProtocolFailed, succeededCount=1, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 346 | backup | ProtocolFailed, succeededCount=3, output=missing | reject helper artifact before manifest publication |
| 347 | backup | ProtocolFailed, succeededCount=3, output=valid-count-match | reject helper artifact before manifest publication |
| 348 | backup | ProtocolFailed, succeededCount=3, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 349 | backup | WrapperFailed, succeededCount=0, output=missing | reject helper artifact before manifest publication |
| 350 | backup | WrapperFailed, succeededCount=0, output=valid-count-match | reject helper artifact before manifest publication |
| 351 | backup | WrapperFailed, succeededCount=0, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 352 | backup | WrapperFailed, succeededCount=1, output=missing | reject helper artifact before manifest publication |
| 353 | backup | WrapperFailed, succeededCount=1, output=valid-count-match | reject helper artifact before manifest publication |
| 354 | backup | WrapperFailed, succeededCount=1, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 355 | backup | WrapperFailed, succeededCount=3, output=missing | reject helper artifact before manifest publication |
| 356 | backup | WrapperFailed, succeededCount=3, output=valid-count-match | reject helper artifact before manifest publication |
| 357 | backup | WrapperFailed, succeededCount=3, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 358 | backup | ProcessFailed, succeededCount=0, output=missing | reject helper artifact before manifest publication |
| 359 | backup | ProcessFailed, succeededCount=0, output=valid-count-match | reject helper artifact before manifest publication |
| 360 | backup | ProcessFailed, succeededCount=0, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 361 | backup | ProcessFailed, succeededCount=1, output=missing | reject helper artifact before manifest publication |
| 362 | backup | ProcessFailed, succeededCount=1, output=valid-count-match | reject helper artifact before manifest publication |
| 363 | backup | ProcessFailed, succeededCount=1, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 364 | backup | ProcessFailed, succeededCount=3, output=missing | reject helper artifact before manifest publication |
| 365 | backup | ProcessFailed, succeededCount=3, output=valid-count-match | reject helper artifact before manifest publication |
| 366 | backup | ProcessFailed, succeededCount=3, output=valid-count-mismatch | reject helper artifact before manifest publication |
| 367 | backup | Completed zero-item result, platformFamily=False, fallback=not attempted | retain verified helper zero-item behavior when fallback does not replace it |
| 368 | backup | Completed zero-item result, platformFamily=False, fallback=succeeds | retain verified helper zero-item behavior when fallback does not replace it |
| 369 | backup | Completed zero-item result, platformFamily=False, fallback=fails | retain verified helper zero-item behavior when fallback does not replace it |
| 370 | backup | Completed zero-item result, platformFamily=True, fallback=not attempted | retain verified helper zero-item behavior when fallback does not replace it |
| 371 | backup | Completed zero-item result, platformFamily=True, fallback=succeeds | replace output with verified in-app artifact and method=in_app |
| 372 | backup | Completed zero-item result, platformFamily=True, fallback=fails | retain verified helper zero-item behavior when fallback does not replace it |
| 373 | backup | Partial zero-item result, platformFamily=False, fallback=not attempted | reject zero-success Partial when fallback does not succeed |
| 374 | backup | Partial zero-item result, platformFamily=False, fallback=succeeds | reject zero-success Partial when fallback does not succeed |
| 375 | backup | Partial zero-item result, platformFamily=False, fallback=fails | reject zero-success Partial when fallback does not succeed |
| 376 | backup | Partial zero-item result, platformFamily=True, fallback=not attempted | reject zero-success Partial when fallback does not succeed |
| 377 | backup | Partial zero-item result, platformFamily=True, fallback=succeeds | replace output with verified in-app artifact and method=in_app |
| 378 | backup | Partial zero-item result, platformFamily=True, fallback=fails | reject zero-success Partial when fallback does not succeed |
| 379 | backup | Partial fixture #1 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 380 | backup | Partial fixture #2 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 381 | backup | Partial fixture #3 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 382 | backup | Partial fixture #4 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 383 | backup | Partial fixture #5 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 384 | backup | Partial fixture #6 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 385 | backup | Partial fixture #7 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 386 | backup | Partial fixture #8 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 387 | backup | Partial fixture #9 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 388 | backup | Partial fixture #10 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 389 | backup | Partial fixture #11 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 390 | backup | Partial fixture #12 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 391 | backup | Partial fixture #13 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 392 | backup | Partial fixture #14 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 393 | backup | Partial fixture #15 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 394 | backup | Partial fixture #16 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 395 | backup | Partial fixture #17 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 396 | backup | Partial fixture #18 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 397 | backup | Partial fixture #19 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 398 | backup | Partial fixture #20 with positive successes and mixed failed/warning/error counts | accept only when plist items exactly equal succeededCount; warning contains numeric counters only |
| 399 | restore | Completed | Succeeded, planned=1 committed=1 |
| 400 | restore | warning-only Partial: failed=0 skipped=0 errors=0 attempted=succeeded warning>0 | Succeeded with warnings, planned=1 committed=1 |
| 401 | restore | Partial failedCount>0 | Failed code 323, committed=0, continue |
| 402 | restore | Partial skippedCount>0 | Failed code 323, committed=0, continue |
| 403 | restore | Partial errorCount>0 | Failed code 323, committed=0, continue |
| 404 | restore | Partial attemptedCount!=succeededCount | Failed code 323, committed=0, continue |
| 405 | restore | HelperFailed 20 | Failed code 322, continue |
| 406 | restore | HelperFailed 21 | Failed code 322, continue |
| 407 | restore | HelperFailed 30 | Failed code 322, continue |
| 408 | restore | HelperFailed 40 | Failed code 322, continue |
| 409 | restore | ProtocolFailed | Failed code 324, continue |
| 410 | restore | WrapperFailed 60-65 | Failed code 324, continue |
| 411 | restore | ProcessFailed | Failed code 324, continue |
| 412 | restore | in-app success | Succeeded using existing branch |
| 413 | restore | in-app failure | Failed code 322 and continue |
| 414 | restore | staging failure | structured hard failure and stop before execution |
| 415 | restore | Partial attempted=0, succeeded=0, issue=warning-only | Succeeded with warnings |
| 416 | restore | Partial attempted=0, succeeded=0, issue=failed item | Failed code 323 and continue |
| 417 | restore | Partial attempted=0, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 418 | restore | Partial attempted=0, succeeded=0, issue=error item | Failed code 323 and continue |
| 419 | restore | Partial attempted=0, succeeded=1, issue=warning-only | Failed code 323 and continue |
| 420 | restore | Partial attempted=0, succeeded=1, issue=failed item | Failed code 323 and continue |
| 421 | restore | Partial attempted=0, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 422 | restore | Partial attempted=0, succeeded=1, issue=error item | Failed code 323 and continue |
| 423 | restore | Partial attempted=0, succeeded=2, issue=warning-only | Failed code 323 and continue |
| 424 | restore | Partial attempted=0, succeeded=2, issue=failed item | Failed code 323 and continue |
| 425 | restore | Partial attempted=0, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 426 | restore | Partial attempted=0, succeeded=2, issue=error item | Failed code 323 and continue |
| 427 | restore | Partial attempted=0, succeeded=3, issue=warning-only | Failed code 323 and continue |
| 428 | restore | Partial attempted=0, succeeded=3, issue=failed item | Failed code 323 and continue |
| 429 | restore | Partial attempted=0, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 430 | restore | Partial attempted=0, succeeded=3, issue=error item | Failed code 323 and continue |
| 431 | restore | Partial attempted=0, succeeded=4, issue=warning-only | Failed code 323 and continue |
| 432 | restore | Partial attempted=0, succeeded=4, issue=failed item | Failed code 323 and continue |
| 433 | restore | Partial attempted=0, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 434 | restore | Partial attempted=0, succeeded=4, issue=error item | Failed code 323 and continue |
| 435 | restore | Partial attempted=0, succeeded=5, issue=warning-only | Failed code 323 and continue |
| 436 | restore | Partial attempted=0, succeeded=5, issue=failed item | Failed code 323 and continue |
| 437 | restore | Partial attempted=0, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 438 | restore | Partial attempted=0, succeeded=5, issue=error item | Failed code 323 and continue |
| 439 | restore | Partial attempted=0, succeeded=6, issue=warning-only | Failed code 323 and continue |
| 440 | restore | Partial attempted=0, succeeded=6, issue=failed item | Failed code 323 and continue |
| 441 | restore | Partial attempted=0, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 442 | restore | Partial attempted=0, succeeded=6, issue=error item | Failed code 323 and continue |
| 443 | restore | Partial attempted=0, succeeded=7, issue=warning-only | Failed code 323 and continue |
| 444 | restore | Partial attempted=0, succeeded=7, issue=failed item | Failed code 323 and continue |
| 445 | restore | Partial attempted=0, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 446 | restore | Partial attempted=0, succeeded=7, issue=error item | Failed code 323 and continue |
| 447 | restore | Partial attempted=1, succeeded=0, issue=warning-only | Failed code 323 and continue |
| 448 | restore | Partial attempted=1, succeeded=0, issue=failed item | Failed code 323 and continue |
| 449 | restore | Partial attempted=1, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 450 | restore | Partial attempted=1, succeeded=0, issue=error item | Failed code 323 and continue |
| 451 | restore | Partial attempted=1, succeeded=1, issue=warning-only | Succeeded with warnings |
| 452 | restore | Partial attempted=1, succeeded=1, issue=failed item | Failed code 323 and continue |
| 453 | restore | Partial attempted=1, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 454 | restore | Partial attempted=1, succeeded=1, issue=error item | Failed code 323 and continue |
| 455 | restore | Partial attempted=1, succeeded=2, issue=warning-only | Failed code 323 and continue |
| 456 | restore | Partial attempted=1, succeeded=2, issue=failed item | Failed code 323 and continue |
| 457 | restore | Partial attempted=1, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 458 | restore | Partial attempted=1, succeeded=2, issue=error item | Failed code 323 and continue |
| 459 | restore | Partial attempted=1, succeeded=3, issue=warning-only | Failed code 323 and continue |
| 460 | restore | Partial attempted=1, succeeded=3, issue=failed item | Failed code 323 and continue |
| 461 | restore | Partial attempted=1, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 462 | restore | Partial attempted=1, succeeded=3, issue=error item | Failed code 323 and continue |
| 463 | restore | Partial attempted=1, succeeded=4, issue=warning-only | Failed code 323 and continue |
| 464 | restore | Partial attempted=1, succeeded=4, issue=failed item | Failed code 323 and continue |
| 465 | restore | Partial attempted=1, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 466 | restore | Partial attempted=1, succeeded=4, issue=error item | Failed code 323 and continue |
| 467 | restore | Partial attempted=1, succeeded=5, issue=warning-only | Failed code 323 and continue |
| 468 | restore | Partial attempted=1, succeeded=5, issue=failed item | Failed code 323 and continue |
| 469 | restore | Partial attempted=1, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 470 | restore | Partial attempted=1, succeeded=5, issue=error item | Failed code 323 and continue |
| 471 | restore | Partial attempted=1, succeeded=6, issue=warning-only | Failed code 323 and continue |
| 472 | restore | Partial attempted=1, succeeded=6, issue=failed item | Failed code 323 and continue |
| 473 | restore | Partial attempted=1, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 474 | restore | Partial attempted=1, succeeded=6, issue=error item | Failed code 323 and continue |
| 475 | restore | Partial attempted=1, succeeded=7, issue=warning-only | Failed code 323 and continue |
| 476 | restore | Partial attempted=1, succeeded=7, issue=failed item | Failed code 323 and continue |
| 477 | restore | Partial attempted=1, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 478 | restore | Partial attempted=1, succeeded=7, issue=error item | Failed code 323 and continue |
| 479 | restore | Partial attempted=2, succeeded=0, issue=warning-only | Failed code 323 and continue |
| 480 | restore | Partial attempted=2, succeeded=0, issue=failed item | Failed code 323 and continue |
| 481 | restore | Partial attempted=2, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 482 | restore | Partial attempted=2, succeeded=0, issue=error item | Failed code 323 and continue |
| 483 | restore | Partial attempted=2, succeeded=1, issue=warning-only | Failed code 323 and continue |
| 484 | restore | Partial attempted=2, succeeded=1, issue=failed item | Failed code 323 and continue |
| 485 | restore | Partial attempted=2, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 486 | restore | Partial attempted=2, succeeded=1, issue=error item | Failed code 323 and continue |
| 487 | restore | Partial attempted=2, succeeded=2, issue=warning-only | Succeeded with warnings |
| 488 | restore | Partial attempted=2, succeeded=2, issue=failed item | Failed code 323 and continue |
| 489 | restore | Partial attempted=2, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 490 | restore | Partial attempted=2, succeeded=2, issue=error item | Failed code 323 and continue |
| 491 | restore | Partial attempted=2, succeeded=3, issue=warning-only | Failed code 323 and continue |
| 492 | restore | Partial attempted=2, succeeded=3, issue=failed item | Failed code 323 and continue |
| 493 | restore | Partial attempted=2, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 494 | restore | Partial attempted=2, succeeded=3, issue=error item | Failed code 323 and continue |
| 495 | restore | Partial attempted=2, succeeded=4, issue=warning-only | Failed code 323 and continue |
| 496 | restore | Partial attempted=2, succeeded=4, issue=failed item | Failed code 323 and continue |
| 497 | restore | Partial attempted=2, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 498 | restore | Partial attempted=2, succeeded=4, issue=error item | Failed code 323 and continue |
| 499 | restore | Partial attempted=2, succeeded=5, issue=warning-only | Failed code 323 and continue |
| 500 | restore | Partial attempted=2, succeeded=5, issue=failed item | Failed code 323 and continue |
| 501 | restore | Partial attempted=2, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 502 | restore | Partial attempted=2, succeeded=5, issue=error item | Failed code 323 and continue |
| 503 | restore | Partial attempted=2, succeeded=6, issue=warning-only | Failed code 323 and continue |
| 504 | restore | Partial attempted=2, succeeded=6, issue=failed item | Failed code 323 and continue |
| 505 | restore | Partial attempted=2, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 506 | restore | Partial attempted=2, succeeded=6, issue=error item | Failed code 323 and continue |
| 507 | restore | Partial attempted=2, succeeded=7, issue=warning-only | Failed code 323 and continue |
| 508 | restore | Partial attempted=2, succeeded=7, issue=failed item | Failed code 323 and continue |
| 509 | restore | Partial attempted=2, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 510 | restore | Partial attempted=2, succeeded=7, issue=error item | Failed code 323 and continue |
| 511 | restore | Partial attempted=3, succeeded=0, issue=warning-only | Failed code 323 and continue |
| 512 | restore | Partial attempted=3, succeeded=0, issue=failed item | Failed code 323 and continue |
| 513 | restore | Partial attempted=3, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 514 | restore | Partial attempted=3, succeeded=0, issue=error item | Failed code 323 and continue |
| 515 | restore | Partial attempted=3, succeeded=1, issue=warning-only | Failed code 323 and continue |
| 516 | restore | Partial attempted=3, succeeded=1, issue=failed item | Failed code 323 and continue |
| 517 | restore | Partial attempted=3, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 518 | restore | Partial attempted=3, succeeded=1, issue=error item | Failed code 323 and continue |
| 519 | restore | Partial attempted=3, succeeded=2, issue=warning-only | Failed code 323 and continue |
| 520 | restore | Partial attempted=3, succeeded=2, issue=failed item | Failed code 323 and continue |
| 521 | restore | Partial attempted=3, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 522 | restore | Partial attempted=3, succeeded=2, issue=error item | Failed code 323 and continue |
| 523 | restore | Partial attempted=3, succeeded=3, issue=warning-only | Succeeded with warnings |
| 524 | restore | Partial attempted=3, succeeded=3, issue=failed item | Failed code 323 and continue |
| 525 | restore | Partial attempted=3, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 526 | restore | Partial attempted=3, succeeded=3, issue=error item | Failed code 323 and continue |
| 527 | restore | Partial attempted=3, succeeded=4, issue=warning-only | Failed code 323 and continue |
| 528 | restore | Partial attempted=3, succeeded=4, issue=failed item | Failed code 323 and continue |
| 529 | restore | Partial attempted=3, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 530 | restore | Partial attempted=3, succeeded=4, issue=error item | Failed code 323 and continue |
| 531 | restore | Partial attempted=3, succeeded=5, issue=warning-only | Failed code 323 and continue |
| 532 | restore | Partial attempted=3, succeeded=5, issue=failed item | Failed code 323 and continue |
| 533 | restore | Partial attempted=3, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 534 | restore | Partial attempted=3, succeeded=5, issue=error item | Failed code 323 and continue |
| 535 | restore | Partial attempted=3, succeeded=6, issue=warning-only | Failed code 323 and continue |
| 536 | restore | Partial attempted=3, succeeded=6, issue=failed item | Failed code 323 and continue |
| 537 | restore | Partial attempted=3, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 538 | restore | Partial attempted=3, succeeded=6, issue=error item | Failed code 323 and continue |
| 539 | restore | Partial attempted=3, succeeded=7, issue=warning-only | Failed code 323 and continue |
| 540 | restore | Partial attempted=3, succeeded=7, issue=failed item | Failed code 323 and continue |
| 541 | restore | Partial attempted=3, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 542 | restore | Partial attempted=3, succeeded=7, issue=error item | Failed code 323 and continue |
| 543 | restore | Partial attempted=4, succeeded=0, issue=warning-only | Failed code 323 and continue |
| 544 | restore | Partial attempted=4, succeeded=0, issue=failed item | Failed code 323 and continue |
| 545 | restore | Partial attempted=4, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 546 | restore | Partial attempted=4, succeeded=0, issue=error item | Failed code 323 and continue |
| 547 | restore | Partial attempted=4, succeeded=1, issue=warning-only | Failed code 323 and continue |
| 548 | restore | Partial attempted=4, succeeded=1, issue=failed item | Failed code 323 and continue |
| 549 | restore | Partial attempted=4, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 550 | restore | Partial attempted=4, succeeded=1, issue=error item | Failed code 323 and continue |
| 551 | restore | Partial attempted=4, succeeded=2, issue=warning-only | Failed code 323 and continue |
| 552 | restore | Partial attempted=4, succeeded=2, issue=failed item | Failed code 323 and continue |
| 553 | restore | Partial attempted=4, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 554 | restore | Partial attempted=4, succeeded=2, issue=error item | Failed code 323 and continue |
| 555 | restore | Partial attempted=4, succeeded=3, issue=warning-only | Failed code 323 and continue |
| 556 | restore | Partial attempted=4, succeeded=3, issue=failed item | Failed code 323 and continue |
| 557 | restore | Partial attempted=4, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 558 | restore | Partial attempted=4, succeeded=3, issue=error item | Failed code 323 and continue |
| 559 | restore | Partial attempted=4, succeeded=4, issue=warning-only | Succeeded with warnings |
| 560 | restore | Partial attempted=4, succeeded=4, issue=failed item | Failed code 323 and continue |
| 561 | restore | Partial attempted=4, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 562 | restore | Partial attempted=4, succeeded=4, issue=error item | Failed code 323 and continue |
| 563 | restore | Partial attempted=4, succeeded=5, issue=warning-only | Failed code 323 and continue |
| 564 | restore | Partial attempted=4, succeeded=5, issue=failed item | Failed code 323 and continue |
| 565 | restore | Partial attempted=4, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 566 | restore | Partial attempted=4, succeeded=5, issue=error item | Failed code 323 and continue |
| 567 | restore | Partial attempted=4, succeeded=6, issue=warning-only | Failed code 323 and continue |
| 568 | restore | Partial attempted=4, succeeded=6, issue=failed item | Failed code 323 and continue |
| 569 | restore | Partial attempted=4, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 570 | restore | Partial attempted=4, succeeded=6, issue=error item | Failed code 323 and continue |
| 571 | restore | Partial attempted=4, succeeded=7, issue=warning-only | Failed code 323 and continue |
| 572 | restore | Partial attempted=4, succeeded=7, issue=failed item | Failed code 323 and continue |
| 573 | restore | Partial attempted=4, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 574 | restore | Partial attempted=4, succeeded=7, issue=error item | Failed code 323 and continue |
| 575 | restore | Partial attempted=5, succeeded=0, issue=warning-only | Failed code 323 and continue |
| 576 | restore | Partial attempted=5, succeeded=0, issue=failed item | Failed code 323 and continue |
| 577 | restore | Partial attempted=5, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 578 | restore | Partial attempted=5, succeeded=0, issue=error item | Failed code 323 and continue |
| 579 | restore | Partial attempted=5, succeeded=1, issue=warning-only | Failed code 323 and continue |
| 580 | restore | Partial attempted=5, succeeded=1, issue=failed item | Failed code 323 and continue |
| 581 | restore | Partial attempted=5, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 582 | restore | Partial attempted=5, succeeded=1, issue=error item | Failed code 323 and continue |
| 583 | restore | Partial attempted=5, succeeded=2, issue=warning-only | Failed code 323 and continue |
| 584 | restore | Partial attempted=5, succeeded=2, issue=failed item | Failed code 323 and continue |
| 585 | restore | Partial attempted=5, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 586 | restore | Partial attempted=5, succeeded=2, issue=error item | Failed code 323 and continue |
| 587 | restore | Partial attempted=5, succeeded=3, issue=warning-only | Failed code 323 and continue |
| 588 | restore | Partial attempted=5, succeeded=3, issue=failed item | Failed code 323 and continue |
| 589 | restore | Partial attempted=5, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 590 | restore | Partial attempted=5, succeeded=3, issue=error item | Failed code 323 and continue |
| 591 | restore | Partial attempted=5, succeeded=4, issue=warning-only | Failed code 323 and continue |
| 592 | restore | Partial attempted=5, succeeded=4, issue=failed item | Failed code 323 and continue |
| 593 | restore | Partial attempted=5, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 594 | restore | Partial attempted=5, succeeded=4, issue=error item | Failed code 323 and continue |
| 595 | restore | Partial attempted=5, succeeded=5, issue=warning-only | Succeeded with warnings |
| 596 | restore | Partial attempted=5, succeeded=5, issue=failed item | Failed code 323 and continue |
| 597 | restore | Partial attempted=5, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 598 | restore | Partial attempted=5, succeeded=5, issue=error item | Failed code 323 and continue |
| 599 | restore | Partial attempted=5, succeeded=6, issue=warning-only | Failed code 323 and continue |
| 600 | restore | Partial attempted=5, succeeded=6, issue=failed item | Failed code 323 and continue |
| 601 | restore | Partial attempted=5, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 602 | restore | Partial attempted=5, succeeded=6, issue=error item | Failed code 323 and continue |
| 603 | restore | Partial attempted=5, succeeded=7, issue=warning-only | Failed code 323 and continue |
| 604 | restore | Partial attempted=5, succeeded=7, issue=failed item | Failed code 323 and continue |
| 605 | restore | Partial attempted=5, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 606 | restore | Partial attempted=5, succeeded=7, issue=error item | Failed code 323 and continue |
| 607 | restore | Partial attempted=6, succeeded=0, issue=warning-only | Failed code 323 and continue |
| 608 | restore | Partial attempted=6, succeeded=0, issue=failed item | Failed code 323 and continue |
| 609 | restore | Partial attempted=6, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 610 | restore | Partial attempted=6, succeeded=0, issue=error item | Failed code 323 and continue |
| 611 | restore | Partial attempted=6, succeeded=1, issue=warning-only | Failed code 323 and continue |
| 612 | restore | Partial attempted=6, succeeded=1, issue=failed item | Failed code 323 and continue |
| 613 | restore | Partial attempted=6, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 614 | restore | Partial attempted=6, succeeded=1, issue=error item | Failed code 323 and continue |
| 615 | restore | Partial attempted=6, succeeded=2, issue=warning-only | Failed code 323 and continue |
| 616 | restore | Partial attempted=6, succeeded=2, issue=failed item | Failed code 323 and continue |
| 617 | restore | Partial attempted=6, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 618 | restore | Partial attempted=6, succeeded=2, issue=error item | Failed code 323 and continue |
| 619 | restore | Partial attempted=6, succeeded=3, issue=warning-only | Failed code 323 and continue |
| 620 | restore | Partial attempted=6, succeeded=3, issue=failed item | Failed code 323 and continue |
| 621 | restore | Partial attempted=6, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 622 | restore | Partial attempted=6, succeeded=3, issue=error item | Failed code 323 and continue |
| 623 | restore | Partial attempted=6, succeeded=4, issue=warning-only | Failed code 323 and continue |
| 624 | restore | Partial attempted=6, succeeded=4, issue=failed item | Failed code 323 and continue |
| 625 | restore | Partial attempted=6, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 626 | restore | Partial attempted=6, succeeded=4, issue=error item | Failed code 323 and continue |
| 627 | restore | Partial attempted=6, succeeded=5, issue=warning-only | Failed code 323 and continue |
| 628 | restore | Partial attempted=6, succeeded=5, issue=failed item | Failed code 323 and continue |
| 629 | restore | Partial attempted=6, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 630 | restore | Partial attempted=6, succeeded=5, issue=error item | Failed code 323 and continue |
| 631 | restore | Partial attempted=6, succeeded=6, issue=warning-only | Succeeded with warnings |
| 632 | restore | Partial attempted=6, succeeded=6, issue=failed item | Failed code 323 and continue |
| 633 | restore | Partial attempted=6, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 634 | restore | Partial attempted=6, succeeded=6, issue=error item | Failed code 323 and continue |
| 635 | restore | Partial attempted=6, succeeded=7, issue=warning-only | Failed code 323 and continue |
| 636 | restore | Partial attempted=6, succeeded=7, issue=failed item | Failed code 323 and continue |
| 637 | restore | Partial attempted=6, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 638 | restore | Partial attempted=6, succeeded=7, issue=error item | Failed code 323 and continue |
| 639 | restore | Partial attempted=7, succeeded=0, issue=warning-only | Failed code 323 and continue |
| 640 | restore | Partial attempted=7, succeeded=0, issue=failed item | Failed code 323 and continue |
| 641 | restore | Partial attempted=7, succeeded=0, issue=skipped item | Failed code 323 and continue |
| 642 | restore | Partial attempted=7, succeeded=0, issue=error item | Failed code 323 and continue |
| 643 | restore | Partial attempted=7, succeeded=1, issue=warning-only | Failed code 323 and continue |
| 644 | restore | Partial attempted=7, succeeded=1, issue=failed item | Failed code 323 and continue |
| 645 | restore | Partial attempted=7, succeeded=1, issue=skipped item | Failed code 323 and continue |
| 646 | restore | Partial attempted=7, succeeded=1, issue=error item | Failed code 323 and continue |
| 647 | restore | Partial attempted=7, succeeded=2, issue=warning-only | Failed code 323 and continue |
| 648 | restore | Partial attempted=7, succeeded=2, issue=failed item | Failed code 323 and continue |
| 649 | restore | Partial attempted=7, succeeded=2, issue=skipped item | Failed code 323 and continue |
| 650 | restore | Partial attempted=7, succeeded=2, issue=error item | Failed code 323 and continue |
| 651 | restore | Partial attempted=7, succeeded=3, issue=warning-only | Failed code 323 and continue |
| 652 | restore | Partial attempted=7, succeeded=3, issue=failed item | Failed code 323 and continue |
| 653 | restore | Partial attempted=7, succeeded=3, issue=skipped item | Failed code 323 and continue |
| 654 | restore | Partial attempted=7, succeeded=3, issue=error item | Failed code 323 and continue |
| 655 | restore | Partial attempted=7, succeeded=4, issue=warning-only | Failed code 323 and continue |
| 656 | restore | Partial attempted=7, succeeded=4, issue=failed item | Failed code 323 and continue |
| 657 | restore | Partial attempted=7, succeeded=4, issue=skipped item | Failed code 323 and continue |
| 658 | restore | Partial attempted=7, succeeded=4, issue=error item | Failed code 323 and continue |
| 659 | restore | Partial attempted=7, succeeded=5, issue=warning-only | Failed code 323 and continue |
| 660 | restore | Partial attempted=7, succeeded=5, issue=failed item | Failed code 323 and continue |
| 661 | restore | Partial attempted=7, succeeded=5, issue=skipped item | Failed code 323 and continue |
| 662 | restore | Partial attempted=7, succeeded=5, issue=error item | Failed code 323 and continue |
| 663 | restore | Partial attempted=7, succeeded=6, issue=warning-only | Failed code 323 and continue |
| 664 | restore | Partial attempted=7, succeeded=6, issue=failed item | Failed code 323 and continue |
| 665 | restore | Partial attempted=7, succeeded=6, issue=skipped item | Failed code 323 and continue |
| 666 | restore | Partial attempted=7, succeeded=6, issue=error item | Failed code 323 and continue |
| 667 | restore | Partial attempted=7, succeeded=7, issue=warning-only | Succeeded with warnings |
| 668 | restore | Partial attempted=7, succeeded=7, issue=failed item | Failed code 323 and continue |
| 669 | restore | Partial attempted=7, succeeded=7, issue=skipped item | Failed code 323 and continue |
| 670 | restore | Partial attempted=7, succeeded=7, issue=error item | Failed code 323 and continue |
| 671 | privacy | raw helper command | zero persistence/logging in manager Keychain path |
| 672 | privacy | argv array | not logged or persisted |
| 673 | privacy | stdout | not appended to warning/debug/defaults |
| 674 | privacy | stderr | not appended to warning/debug/defaults |
| 675 | privacy | V2 machine line | not logged or persisted by manager |
| 676 | privacy | base64 payload | not logged or persisted |
| 677 | privacy | requested group values | not written to Keychain debug summary |
| 678 | privacy | effective group values | not written to warnings/debug |
| 679 | privacy | fatal localizedDescription | not used in manager warning/failure message |
| 680 | privacy | helper file path from output | not logged |
| 681 | privacy | stderr truncation | generic bounded warning only |
| 682 | privacy | effective superset | count-only warning |
| 683 | privacy | Partial backup | numeric counter summary only |
| 684 | privacy | Partial restore | numeric counter summary only |
| 685 | privacy | PXKeychainRestoreResult_ defaults key | zero production references |
| 686 | privacy | pre-backup wrapper list debug | zero calls |
| 687 | privacy | post-restore wrapper list debug | zero calls |
| 688 | privacy | selectedGroups=<array> debug | zero sites |
| 689 | privacy | groups=<array> debug | zero sites |
| 690 | privacy | generic unrelated PXDebugRun | left unchanged outside Keychain wrapper path |
| 691 | non-regression | PXRestoreResult.h/.m | byte-identical; no Partial enum |
| 692 | non-regression | CommandRunner.h/.m | byte-identical |
| 693 | non-regression | direct helper | byte-identical |
| 694 | non-regression | wrapper | byte-identical and syntax-valid |
| 695 | non-regression | Keychain core | byte-identical; Security counts unchanged |
| 696 | non-regression | identity model | byte-identical |
| 697 | non-regression | exit-code header | byte-identical taxonomy |
| 698 | non-regression | bridge | byte-identical |
| 699 | non-regression | backup artifact writer | byte-identical |
| 700 | non-regression | restore plan | byte-identical |
| 701 | non-regression | AppDataBackupManager.h | byte-identical |
| 702 | non-regression | Makefile helper target | still includes result model once |
| 703 | non-regression | Makefile app target | includes result model once |
| 704 | non-regression | root wildcard | includes invocation parser once |
| 705 | non-regression | TASK-4.9 protection metadata | not implemented |
| 706 | non-regression | manifest schema | unchanged |
| 707 | non-regression | existing chmod 600 | preserved but not claimed as TASK-4.9 |
| 708 | non-regression | coordinator documents | preserved and unstaged |
| 709 | non-regression | Git push | not performed |
| 710 | non-regression | TASK-4.9 | not started |

## Objective-C validation

Header/implementation selector parity, nullable surface, enum membership, factory callers, lexical delimiter balance, Foundation/CoreFoundation usage, immutable snapshots, Makefile membership, and duplicate-symbol boundaries passed static checks. The existing V2 emission factory text matches baseline exactly.

## Build/toolchain limitations

This Windows host has no clang.exe, make.exe, xcrun.exe, or THEOS environment. Objective-C compilation, linking, package build, and GitHub Actions were not claimed as PASS. GitHub Actions must compile ProjectX and backup_helper, link both result-model copies in separate targets, and build the package.

## Device test status

PENDING — device validation must cover actual wrapper stdout framing, exits 0/10/20/21/30/40/50/60–65, timeouts/signals/truncation, completed/partial backup artifacts, count mismatch, platform-family fallback, restore continuation, system effective supersets, rootless paths, and cleanup override behavior.

## CRLF/LF/NUL audit

| Path | CRLF count | Lines | NUL | Final newline | Trailing whitespace |
| --- | --- | --- | --- | --- | --- |
| `Makefile` | 174 | 174 | 0 | TRUE | 2 |
| `KeychainHelper/PXKeychainHelperResult.h` | 0 | 83 | 0 | TRUE | 0 |
| `KeychainHelper/PXKeychainHelperResult.m` | 0 | 1008 | 0 | TRUE | 0 |
| `AppDataBackupManager.m` | 0 | 4429 | 0 | TRUE | 0 new trailing-whitespace lines |
| `PXKeychainHelperInvocationResult.h` | 0 | 51 | 0 | TRUE | 0 |
| `PXKeychainHelperInvocationResult.m` | 0 | 415 | 0 | TRUE | 0 |
Note: the specification described AppDataBackupManager.m as CRLF, but the accepted baseline blob/worktree content was LF. TASK-4.8 preserved the actual baseline LF style and did not broad-normalize the file. Makefile retained CRLF.

The report itself was verified after generation as UTF-8 LF with zero CRLF sequences, zero NUL bytes, a final newline, and zero trailing-whitespace lines.

## Residual risks

- Apple Objective-C compile/link/package evidence is pending.
- Device behavior of ldid/wrapper output and CommandRunner truncation boundaries is pending.
- The bounded plist count cross-check is path-based and not descriptor-pinned against a malicious root/kernel/filesystem race; artifact-writer verification still owns publication.
- PXKeychainHelperInvocationResult retains the immutable decoded result, whose canonical machine line remains in memory by design; manager never logs or persists it.
- The in-app bridge branch and its pre-existing diagnostics remain a separate protocol boundary and were not converted to V2.
- Effective access may remain wider than requested for system/full-entitlement mode; TASK-4.8 reports only the additional count.
- Backup-file at-rest protection remains entirely owned by TASK-4.9.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
