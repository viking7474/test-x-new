# TASK-4.6 REPORT - Secure Keychain Helper Temporary Workspace and Path Validation

## Result
- COMPLETE within TASK-4.6 scope.
- Wrapper environment, workspace and path boundary hardened.
- Direct helper/Keychain behavior unchanged.
- TASK-4.7 and later tasks not started.

## User authority and TASK-4.5 review-file status
- User specification is authority; mandatory baseline `0aa40dfe21c27c0088bbacaaa0cd1e3159d2f1fb`.
- TASK-4.5 is declared ACCEPTED and COMPLETED; TASK-4.6 READY.
- `TASK-4.5-REVIEW.md` is absent, was not treated as a blocker, and was not created.
- Specification names nonexistent `PXOptionalRestoreStagingWorkspace.*`; actual `PXOptionalRestoreStaging.*` files were read/protected.

## Baseline
Exact initial HEAD: `0aa40dfe21c27c0088bbacaaa0cd1e3159d2f1fb`.
```text
0aa40df phase4(task-4.5): implement exact per-item keychain upsert
9d637e2 phase4(task-4.4): define exact keychain item identity
4c70002 phase4(task-4.3): remove broad keychain restore pre-delete
5c6e70a phase4(task-4.2): define reliable keychain helper exit codes
1a59e96 phase4(task-4.1): add structured keychain helper result
02770e2 phase3(task-3.10A): fix stale name classification and rollback errors
5e70a8f phase3(task-3.10): harden backup discovery and stale cleanup
aa01f73 phase3(task-3.9A): make cleanup removal race safe
```

## Exact authorized scope
| Status | Path |
|---|---|
| M | `scripts/keychain_backup.sh` |
| A | `docs/backup-restore-hardening/reports/TASK-4.6-REPORT.md` |
All other production files and Makefile are protected.

## Working-tree preservation
Pre-existing coordinator-owned state remained unstaged:
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
?? docs/backup-restore-hardening/reviews/TASK-3.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.10A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.6-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.6A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.8A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.9-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.9A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-4.1-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-4.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-4.3-REVIEW.md
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
?? docs/backup-restore-hardening/tasks/TASK-3.10-harden-backup-discovery-and-stale-partial-cleanup.md
?? docs/backup-restore-hardening/tasks/TASK-3.10A-fix-top-level-name-classification-and-rollback-errors.md
?? docs/backup-restore-hardening/tasks/TASK-3.2-add-per-bundle-backup-serialization.md
?? docs/backup-restore-hardening/tasks/TASK-3.3-add-common-verified-artifact-writer.md
?? docs/backup-restore-hardening/tasks/TASK-3.4-derive-preferences-inclusion-from-verified-output.md
?? docs/backup-restore-hardening/tasks/TASK-3.5-define-required-and-optional-artifact-policy.md
?? docs/backup-restore-hardening/tasks/TASK-3.6-introduce-manifest-schema-v4.md
?? docs/backup-restore-hardening/tasks/TASK-3.6A-fix-v4-malformed-type-exception-safety.md
?? docs/backup-restore-hardening/tasks/TASK-3.7-write-and-validate-manifest-atomically.md
?? docs/backup-restore-hardening/tasks/TASK-3.8-publish-completed-backup-atomically.md
?? docs/backup-restore-hardening/tasks/TASK-3.8A-enforce-atomic-no-replace-directory-publication.md
?? docs/backup-restore-hardening/tasks/TASK-3.9-centralize-backup-failure-cleanup.md
?? docs/backup-restore-hardening/tasks/TASK-3.9A-make-cleanup-removal-race-safe.md
?? docs/backup-restore-hardening/tasks/TASK-4.1-add-structured-keychain-helper-result.md
?? docs/backup-restore-hardening/tasks/TASK-4.2-define-reliable-keychain-helper-exit-codes.md
?? docs/backup-restore-hardening/tasks/TASK-4.3-remove-broad-pre-delete-from-keychain-restore.md
?? docs/backup-restore-hardening/tasks/TASK-4.4-define-exact-keychain-item-identity.md
```

## Protected hashes and byte sizes
Protected production files: 77.
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes | Match |
|---|---|---:|---|---:|---:|
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 | TRUE |
| `AppDataBackupManager.m` | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | `d6a302c90ab988a2c9b27c36fa664bc219082c6175f631942426b5fb91d2191e` | 221835 | TRUE |
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
| `KeychainHelper/PXKeychainHelperResult.h` | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.h` | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.m` | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | TRUE |
| `KeychainHelper/backup_helper.m` | `f3af22735ef307a2f583079832c4a7222ffbcf2617c366de564086cf538c1eee` | 28260 | `f3af22735ef307a2f583079832c4a7222ffbcf2617c366de564086cf538c1eee` | 28260 | TRUE |
| `Makefile` | `99cf5ded8dfe4bbd4ab363ccdbbd477285b3f1e5aa25118b18a200c52706b566` | 9226 | `99cf5ded8dfe4bbd4ab363ccdbbd477285b3f1e5aa25118b18a200c52706b566` | 9226 | TRUE |
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

## Authorized source before and after
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
|---|---|---:|---|---:|
| `scripts/keychain_backup.sh` | `b4193337633fea4b126c6466c3172c637c759c1a041b6bf7532a7cdd7a27bdce` | 36294 | `f4a2099e023c06639742631fc639c3a309a9381f28eb6b6578a38ae2f6752478` | 67455 |
| report | ABSENT | 0 | SELF-REFERENTIAL | SELF-REFERENTIAL |

## Original workspace vulnerability inventory
| Item | Count |
|---|---:|
| PID-only `/tmp/keychain_helper_$$` | 1 |
| `mkdir -p` workspace sites | 4 |
| mktemp authority | 0 |
| `rm -rf` | 1 |
| rmdir | 0 |
| helper `-x`-only acceptance | 1 |

## Original path-validation inventory
Restore sent raw caller path; backup sent raw destination; app discovery trusted glob paths and bare plutil; CFBundleExecutable, Info.plist identity, target identity and output types were not closed over operation windows.

## Original external-command inventory
| Command/site | Count |
|---|---:|
| bare plutil | 4 |
| grep | 16 |
| sed | 4 |
| cp | 5 |
| chmod | 5 |
| mkdir | 4 |
| rm | 1 |
| cmp/stat/mktemp | 0/0/0 |
| helper executions | 4 |
| normalizer | 1 definition / 4 calls |

## Threat model
Protects against hostile shell environment, predictable/precreated workspace, symlink/type/mode substitution, unsafe helper/dependency/target/input/output paths, detectable metadata races and recursive cleanup escape. Does not claim defense against malicious root/kernel, compromised filesystem, descriptor-perfect arbitrary-path transactions, crash-durable publication, encryption or Data Protection policy.

## Safe shell environment
Fixed exported PATH, reset IFS, unset CDPATH/ENV/BASH_ENV/GLOBIGNORE, fixed locale and umask 077 precede external work. TMP/TEMP/TMPDIR are not authorities.

## Trusted utility resolver
One bounded resolver accepts fixed absolute candidates only after physical-parent, regular non-symlink executable, root-owner, nonzero and non-writable-mode proof. Missing/unsafe mandatory dependency =>65. Bootstrap stat is self/parent revalidated.

## Physical path canonicalization
Caller paths require bounded absolute control-free syntax and safe basename. Parent is resolved by cd -P/pwd -P and reconstructed canonical paths become operational authority.

## Metadata snapshot format
One BSD stat -f helper parses device|inode|uid|gid|mode|size|links|mtime|ctime with exact nonempty numeric fields, octal mode, one line and bounded internal prefix.

## Workspace parent validation
Only physical /private/var/tmp; root-owned traversable non-symlink directory; sticky required when writable; identity stable around creation.

## Unique workspace creation
One mktemp -d with `.weaponx-keychain-helper.XXXXXXXX`; direct child, exact prefix, EUID owner, same filesystem, empty and 0700; one repair; one attempt.

## Workspace identity retention
Retains root/parent device/inode plus owner/group/mode/links and revalidates at every critical extraction/copy/sign/execute/cleanup boundary.

## Workspace child allowlist
Only app_ent.xml, helper_ent.plist, backup_helper and restore_input.plist. Data/plist children 0600; helper 0700; exact absent direct-child and metadata proof.

## Installed helper validation
Exact configured physical path, regular non-symlink executable, root-owned, nonzero, single-link, safe mode and trusted parent; no repair/in-place signing; failure=>60.

## Working helper snapshot proof
Source compared with entry and before/after-copy snapshots, bytes cmp-checked, destination absent, chmod/revalidate 0700. Source authority=>60; workspace copy assurance=>63.

## Trusted ldid
Resolved absolute trusted binary only. Extraction failure=>62; signing process=>64; workspace identity=>63. Full output suppressed.

## Trusted plutil
Resolved absolute trusted binary for every plist operation; bare calls zero; Info.plist stable around each read.

## Target app root validation
Only six fixed roots, physicalized. System app direct child; App Store UUID/direct app child. Symlink/nested/arbitrary roots rejected; no recursive find.

## Info.plist validation
Exact child, regular non-symlink readable nonzero <=16 MiB, root/mobile owner, single-link, safe mode, complete snapshot stable around reads.

## CFBundleExecutable validation
Bounded nonempty control-free safe basename; no slash/backslash/dot/dotdot/leading option; direct child only.

## Target executable validation
Direct child regular non-symlink executable nonzero root/mobile-owned single-link safe-mode file; complete snapshot stable during entitlement extraction.

## Entitlement output validation
app_ent.xml absent before redirect, exact 0600 nonempty workspace child; target/workspace stable and ldid status checked.

## Helper entitlement validation
helper_ent.plist absent/exact/0600; source snapshot and cmp for full-entitlement copy; trusted plutil; final file nonempty and revalidated.

## Restore snapshot design
Canonical source and parent snapshots, private restore_input.plist copy, source/parent recheck, cmp, 0600; helper never receives raw path. Caller failure=>21; internal=>63.

## Backup output path validation
Physical writable parent and safe regular/absent leaf, pre/post identity/type checks; helper success/Partial requires nonempty regular output. Initial=>21; assurance loss=>63.

## Signing pre/post validation
Exact entitlement/helper before signing; entitlement unchanged and exact regular executable 0700 helper after signing.

## Helper execution preconditions
Workspace/helper/entitlement and action path checked; raw status captured immediately next line; then post-check and unchanged normalizer.

## Bounded cleanup
Revalidate root, unlink exact known file/symlink children only, verify empty, trusted rmdir; zero recursive deletion/rm-rf.

## Unknown-content preservation
Unexpected/nested content is preserved; root is not removed; cleanup fails closed.

## EXIT trap status policy
One trap captures original status, disables recursion, cleans active workspace only; success preserves status; any cleanup failure=>63; stderr-only generic diagnostic.

## Exact exit-code mapping
20 invalid args/bundle; 21 invalid caller file/path; 60 helper; 61 target; 62 entitlement; 63 workspace/path/cleanup; 64 signing; 65 dependency; recognized helper unchanged; unknown=>40.

## Protocol passthrough proof
Direct helper stdout remains byte-for-byte; no parse/filter/re-encode/envelope; zero result-prefix references; normalizer 1/4.

## TASK-4.1 result non-regression
Result schema/framing sources byte-identical.

## TASK-4.2 exit-policy non-regression
Exit enum/direct helper byte-identical; thirteen constants and recognized policy retained.

## TASK-4.3 zero-restore-delete non-regression
Restore delete remains zero; explicit wipe sole delete.

## TASK-4.4 identity non-regression
Identity module and Makefile byte-identical.

## TASK-4.5 upsert non-regression
Core operations {'SecItemCopyMatching': 6, 'SecItemAdd': 1, 'SecItemUpdate': 1, 'SecItemDelete': 1}; restore {'SecItemCopyMatching': 1, 'SecItemAdd': 1, 'SecItemUpdate': 1, 'SecItemDelete': 0}; add-first/exact lookup/in-place update unchanged.

## TASK-4.7 through TASK-4.9 boundaries
No requested/effective group reporting, manager parsing, final protection policy, UI/bridge/later phase work.

## Static gate table
| Gate | Observed | Required | Result |
|---|---:|---:|---|
| `predictable TEMP_DIR` | 0 | 0 | PASS |
| `legacy /tmp prefix` | 0 | 0 | PASS |
| `caller TMPDIR workspace use` | 0 | 0 | PASS |
| `secure workspace factory definitions` | 1 | 1 | PASS |
| `workspace creation call sites` | 4 | 4 | PASS |
| `mktemp -d authority` | 1 | 1 | PASS |
| `fixed parent definitions` | 1 | 1 | PASS |
| `reserved prefix definitions` | 1 | 1 | PASS |
| `mkdir -p` | 0 | 0 | PASS |
| `rm -rf` | 0 | 0 | PASS |
| `bounded cleanup definitions` | 1 | 1 | PASS |
| `EXIT cleanup traps` | 1 | 1 | PASS |
| `umask 077` | 1 | 1 | PASS |
| `safe PATH assignments` | 1 | 1 | PASS |
| `bare plutil operational calls` | 0 | 0 | PASS |
| `bare ldid operational calls` | 0 | 0 | PASS |
| `restore private snapshot argv` | 1 | 1 | PASS |
| `working-helper 0700 validations` | 5 | 5 | PASS |
| `normalizer definitions` | 1 | 1 | PASS |
| `normalizer calls` | 4 | 4 | PASS |
| `shell exit constants` | 13 | 13 | PASS |
| `result-prefix references` | 0 | 0 | PASS |
| protected production diffs | 0 across 77 | 0 | PASS |
| core Security calls | 6/1/1/1 | 6/1/1/1 | PASS |
| restore Security calls | 1/1/1/0 | 1/1/1/0 | PASS |
| deterministic model assertions | 421130 | 421130 | PASS |
| explicit scenarios | 632 | >=400 | PASS |

## Explicit numbered scenarios
Explicit scenarios: 632.
| # | Area | Stimulus | Expected |
|---:|---|---|---|
| 1 | authority | exact mandatory baseline | enforced |
| 2 | authority | TASK-4.5 ACCEPTED authority | enforced |
| 3 | authority | TASK-4.5 COMPLETED authority | enforced |
| 4 | authority | TASK-4.6 READY authority | enforced |
| 5 | authority | TASK-4.5 review absent | enforced |
| 6 | authority | review not synthesized | enforced |
| 7 | authority | two authorized files | enforced |
| 8 | authority | Makefile protected | enforced |
| 9 | authority | Keychain core protected | enforced |
| 10 | authority | coordinator state preserved | enforced |
| 11 | authority | no push | enforced |
| 12 | authority | no TASK-4.7 | enforced |
| 13 | environment | hostile PATH | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 14 | environment | current directory in PATH | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 15 | environment | hostile IFS | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 16 | environment | hostile CDPATH | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 17 | environment | hostile ENV | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 18 | environment | hostile BASH_ENV | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 19 | environment | hostile GLOBIGNORE | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 20 | environment | attacker TMPDIR | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 21 | environment | attacker TEMP | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 22 | environment | attacker TMP | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 23 | environment | hostile locale | fixed PATH/IFS/locale; unset unsafe variables; umask 077 |
| 24 | trusted utility | stat: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 25 | trusted utility | stat: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 26 | trusted utility | stat: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 27 | trusted utility | stat: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 28 | trusted utility | stat: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 29 | trusted utility | stat: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 30 | trusted utility | stat: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 31 | trusted utility | stat: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 32 | trusted utility | stat: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 33 | trusted utility | stat: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 34 | trusted utility | stat: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 35 | trusted utility | stat: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 36 | trusted utility | mktemp: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 37 | trusted utility | mktemp: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 38 | trusted utility | mktemp: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 39 | trusted utility | mktemp: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 40 | trusted utility | mktemp: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 41 | trusted utility | mktemp: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 42 | trusted utility | mktemp: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 43 | trusted utility | mktemp: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 44 | trusted utility | mktemp: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 45 | trusted utility | mktemp: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 46 | trusted utility | mktemp: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 47 | trusted utility | mktemp: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 48 | trusted utility | cp: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 49 | trusted utility | cp: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 50 | trusted utility | cp: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 51 | trusted utility | cp: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 52 | trusted utility | cp: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 53 | trusted utility | cp: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 54 | trusted utility | cp: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 55 | trusted utility | cp: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 56 | trusted utility | cp: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 57 | trusted utility | cp: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 58 | trusted utility | cp: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 59 | trusted utility | cp: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 60 | trusted utility | cmp: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 61 | trusted utility | cmp: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 62 | trusted utility | cmp: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 63 | trusted utility | cmp: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 64 | trusted utility | cmp: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 65 | trusted utility | cmp: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 66 | trusted utility | cmp: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 67 | trusted utility | cmp: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 68 | trusted utility | cmp: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 69 | trusted utility | cmp: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 70 | trusted utility | cmp: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 71 | trusted utility | cmp: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 72 | trusted utility | chmod: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 73 | trusted utility | chmod: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 74 | trusted utility | chmod: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 75 | trusted utility | chmod: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 76 | trusted utility | chmod: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 77 | trusted utility | chmod: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 78 | trusted utility | chmod: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 79 | trusted utility | chmod: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 80 | trusted utility | chmod: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 81 | trusted utility | chmod: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 82 | trusted utility | chmod: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 83 | trusted utility | chmod: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 84 | trusted utility | rm: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 85 | trusted utility | rm: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 86 | trusted utility | rm: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 87 | trusted utility | rm: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 88 | trusted utility | rm: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 89 | trusted utility | rm: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 90 | trusted utility | rm: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 91 | trusted utility | rm: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 92 | trusted utility | rm: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 93 | trusted utility | rm: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 94 | trusted utility | rm: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 95 | trusted utility | rm: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 96 | trusted utility | rmdir: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 97 | trusted utility | rmdir: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 98 | trusted utility | rmdir: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 99 | trusted utility | rmdir: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 100 | trusted utility | rmdir: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 101 | trusted utility | rmdir: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 102 | trusted utility | rmdir: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 103 | trusted utility | rmdir: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 104 | trusted utility | rmdir: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 105 | trusted utility | rmdir: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 106 | trusted utility | rmdir: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 107 | trusted utility | rmdir: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 108 | trusted utility | plutil: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 109 | trusted utility | plutil: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 110 | trusted utility | plutil: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 111 | trusted utility | plutil: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 112 | trusted utility | plutil: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 113 | trusted utility | plutil: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 114 | trusted utility | plutil: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 115 | trusted utility | plutil: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 116 | trusted utility | plutil: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 117 | trusted utility | plutil: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 118 | trusted utility | plutil: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 119 | trusted utility | plutil: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 120 | trusted utility | ldid: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 121 | trusted utility | ldid: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 122 | trusted utility | ldid: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 123 | trusted utility | ldid: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 124 | trusted utility | ldid: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 125 | trusted utility | ldid: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 126 | trusted utility | ldid: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 127 | trusted utility | ldid: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 128 | trusted utility | ldid: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 129 | trusted utility | ldid: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 130 | trusted utility | ldid: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 131 | trusted utility | ldid: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 132 | trusted utility | grep: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 133 | trusted utility | grep: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 134 | trusted utility | grep: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 135 | trusted utility | grep: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 136 | trusted utility | grep: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 137 | trusted utility | grep: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 138 | trusted utility | grep: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 139 | trusted utility | grep: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 140 | trusted utility | grep: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 141 | trusted utility | grep: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 142 | trusted utility | grep: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 143 | trusted utility | grep: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 144 | trusted utility | sed: missing | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 145 | trusted utility | sed: directory | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 146 | trusted utility | sed: final symlink | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 147 | trusted utility | sed: non-executable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 148 | trusted utility | sed: zero size | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 149 | trusted utility | sed: group writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 150 | trusted utility | sed: world writable | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 151 | trusted utility | sed: wrong owner | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 152 | trusted utility | sed: unsafe parent | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 153 | trusted utility | sed: physical parent alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 154 | trusted utility | sed: safe system binary | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 155 | trusted utility | sed: safe rootless alias | reject unsafe; next bounded candidate; no safe candidate => 65 |
| 156 | BSD stat | valid nine fields | single-line fixed delimiter or fail closed |
| 157 | BSD stat | missing device | single-line fixed delimiter or fail closed |
| 158 | BSD stat | missing inode | single-line fixed delimiter or fail closed |
| 159 | BSD stat | missing uid | single-line fixed delimiter or fail closed |
| 160 | BSD stat | missing gid | single-line fixed delimiter or fail closed |
| 161 | BSD stat | missing mode | single-line fixed delimiter or fail closed |
| 162 | BSD stat | missing size | single-line fixed delimiter or fail closed |
| 163 | BSD stat | missing links | single-line fixed delimiter or fail closed |
| 164 | BSD stat | missing mtime | single-line fixed delimiter or fail closed |
| 165 | BSD stat | missing ctime | single-line fixed delimiter or fail closed |
| 166 | BSD stat | extra field | single-line fixed delimiter or fail closed |
| 167 | BSD stat | newline | single-line fixed delimiter or fail closed |
| 168 | BSD stat | CR | single-line fixed delimiter or fail closed |
| 169 | BSD stat | nonnumeric | single-line fixed delimiter or fail closed |
| 170 | BSD stat | invalid octal | single-line fixed delimiter or fail closed |
| 171 | BSD stat | locale text | single-line fixed delimiter or fail closed |
| 172 | BSD stat | self changes | single-line fixed delimiter or fail closed |
| 173 | BSD stat | unsafe parent | single-line fixed delimiter or fail closed |
| 174 | BSD stat | valid self and parent | single-line fixed delimiter or fail closed |
| 175 | workspace parent | missing | 63 unless exact physical /private/var/tmp authority |
| 176 | workspace parent | file | 63 unless exact physical /private/var/tmp authority |
| 177 | workspace parent | symlink | 63 unless exact physical /private/var/tmp authority |
| 178 | workspace parent | wrong physical path | 63 unless exact physical /private/var/tmp authority |
| 179 | workspace parent | wrong owner | 63 unless exact physical /private/var/tmp authority |
| 180 | workspace parent | not traversable | 63 unless exact physical /private/var/tmp authority |
| 181 | workspace parent | writable without sticky | 63 unless exact physical /private/var/tmp authority |
| 182 | workspace parent | 1777 root-owned | 63 unless exact physical /private/var/tmp authority |
| 183 | workspace parent | identity changes before creation | 63 unless exact physical /private/var/tmp authority |
| 184 | workspace parent | identity changes after creation | 63 unless exact physical /private/var/tmp authority |
| 185 | workspace parent | valid stable parent | 63 unless exact physical /private/var/tmp authority |
| 186 | workspace creation | mktemp failure | one mktemp -d authority or 63 |
| 187 | workspace creation | empty output | one mktemp -d authority or 63 |
| 188 | workspace creation | relative output | one mktemp -d authority or 63 |
| 189 | workspace creation | newline output | one mktemp -d authority or 63 |
| 190 | workspace creation | wrong prefix | one mktemp -d authority or 63 |
| 191 | workspace creation | short suffix | one mktemp -d authority or 63 |
| 192 | workspace creation | long suffix | one mktemp -d authority or 63 |
| 193 | workspace creation | nested path | one mktemp -d authority or 63 |
| 194 | workspace creation | symlink result | one mktemp -d authority or 63 |
| 195 | workspace creation | file result | one mktemp -d authority or 63 |
| 196 | workspace creation | wrong owner | one mktemp -d authority or 63 |
| 197 | workspace creation | mode repair succeeds | one mktemp -d authority or 63 |
| 198 | workspace creation | mode repair fails | one mktemp -d authority or 63 |
| 199 | workspace creation | different filesystem | one mktemp -d authority or 63 |
| 200 | workspace creation | nonempty result | one mktemp -d authority or 63 |
| 201 | workspace creation | parent replacement | one mktemp -d authority or 63 |
| 202 | workspace creation | precreated PID path | one mktemp -d authority or 63 |
| 203 | workspace creation | concurrent invocation A | one mktemp -d authority or 63 |
| 204 | workspace creation | concurrent invocation B | one mktemp -d authority or 63 |
| 205 | workspace creation | second factory call | one mktemp -d authority or 63 |
| 206 | workspace creation | valid unique 0700 | one mktemp -d authority or 63 |
| 207 | workspace identity | post-create: device | fail closed; no recursive cleanup |
| 208 | workspace identity | post-create: inode | fail closed; no recursive cleanup |
| 209 | workspace identity | post-create: uid | fail closed; no recursive cleanup |
| 210 | workspace identity | post-create: gid | fail closed; no recursive cleanup |
| 211 | workspace identity | post-create: mode | fail closed; no recursive cleanup |
| 212 | workspace identity | post-create: links | fail closed; no recursive cleanup |
| 213 | workspace identity | post-create: root symlink | fail closed; no recursive cleanup |
| 214 | workspace identity | post-create: parent inode | fail closed; no recursive cleanup |
| 215 | workspace identity | pre-extract: device | fail closed; no recursive cleanup |
| 216 | workspace identity | pre-extract: inode | fail closed; no recursive cleanup |
| 217 | workspace identity | pre-extract: uid | fail closed; no recursive cleanup |
| 218 | workspace identity | pre-extract: gid | fail closed; no recursive cleanup |
| 219 | workspace identity | pre-extract: mode | fail closed; no recursive cleanup |
| 220 | workspace identity | pre-extract: links | fail closed; no recursive cleanup |
| 221 | workspace identity | pre-extract: root symlink | fail closed; no recursive cleanup |
| 222 | workspace identity | pre-extract: parent inode | fail closed; no recursive cleanup |
| 223 | workspace identity | post-extract: device | fail closed; no recursive cleanup |
| 224 | workspace identity | post-extract: inode | fail closed; no recursive cleanup |
| 225 | workspace identity | post-extract: uid | fail closed; no recursive cleanup |
| 226 | workspace identity | post-extract: gid | fail closed; no recursive cleanup |
| 227 | workspace identity | post-extract: mode | fail closed; no recursive cleanup |
| 228 | workspace identity | post-extract: links | fail closed; no recursive cleanup |
| 229 | workspace identity | post-extract: root symlink | fail closed; no recursive cleanup |
| 230 | workspace identity | post-extract: parent inode | fail closed; no recursive cleanup |
| 231 | workspace identity | pre-copy: device | fail closed; no recursive cleanup |
| 232 | workspace identity | pre-copy: inode | fail closed; no recursive cleanup |
| 233 | workspace identity | pre-copy: uid | fail closed; no recursive cleanup |
| 234 | workspace identity | pre-copy: gid | fail closed; no recursive cleanup |
| 235 | workspace identity | pre-copy: mode | fail closed; no recursive cleanup |
| 236 | workspace identity | pre-copy: links | fail closed; no recursive cleanup |
| 237 | workspace identity | pre-copy: root symlink | fail closed; no recursive cleanup |
| 238 | workspace identity | pre-copy: parent inode | fail closed; no recursive cleanup |
| 239 | workspace identity | post-copy: device | fail closed; no recursive cleanup |
| 240 | workspace identity | post-copy: inode | fail closed; no recursive cleanup |
| 241 | workspace identity | post-copy: uid | fail closed; no recursive cleanup |
| 242 | workspace identity | post-copy: gid | fail closed; no recursive cleanup |
| 243 | workspace identity | post-copy: mode | fail closed; no recursive cleanup |
| 244 | workspace identity | post-copy: links | fail closed; no recursive cleanup |
| 245 | workspace identity | post-copy: root symlink | fail closed; no recursive cleanup |
| 246 | workspace identity | post-copy: parent inode | fail closed; no recursive cleanup |
| 247 | workspace identity | pre-sign: device | fail closed; no recursive cleanup |
| 248 | workspace identity | pre-sign: inode | fail closed; no recursive cleanup |
| 249 | workspace identity | pre-sign: uid | fail closed; no recursive cleanup |
| 250 | workspace identity | pre-sign: gid | fail closed; no recursive cleanup |
| 251 | workspace identity | pre-sign: mode | fail closed; no recursive cleanup |
| 252 | workspace identity | pre-sign: links | fail closed; no recursive cleanup |
| 253 | workspace identity | pre-sign: root symlink | fail closed; no recursive cleanup |
| 254 | workspace identity | pre-sign: parent inode | fail closed; no recursive cleanup |
| 255 | workspace identity | post-sign: device | fail closed; no recursive cleanup |
| 256 | workspace identity | post-sign: inode | fail closed; no recursive cleanup |
| 257 | workspace identity | post-sign: uid | fail closed; no recursive cleanup |
| 258 | workspace identity | post-sign: gid | fail closed; no recursive cleanup |
| 259 | workspace identity | post-sign: mode | fail closed; no recursive cleanup |
| 260 | workspace identity | post-sign: links | fail closed; no recursive cleanup |
| 261 | workspace identity | post-sign: root symlink | fail closed; no recursive cleanup |
| 262 | workspace identity | post-sign: parent inode | fail closed; no recursive cleanup |
| 263 | workspace identity | pre-exec: device | fail closed; no recursive cleanup |
| 264 | workspace identity | pre-exec: inode | fail closed; no recursive cleanup |
| 265 | workspace identity | pre-exec: uid | fail closed; no recursive cleanup |
| 266 | workspace identity | pre-exec: gid | fail closed; no recursive cleanup |
| 267 | workspace identity | pre-exec: mode | fail closed; no recursive cleanup |
| 268 | workspace identity | pre-exec: links | fail closed; no recursive cleanup |
| 269 | workspace identity | pre-exec: root symlink | fail closed; no recursive cleanup |
| 270 | workspace identity | pre-exec: parent inode | fail closed; no recursive cleanup |
| 271 | workspace identity | post-exec: device | fail closed; no recursive cleanup |
| 272 | workspace identity | post-exec: inode | fail closed; no recursive cleanup |
| 273 | workspace identity | post-exec: uid | fail closed; no recursive cleanup |
| 274 | workspace identity | post-exec: gid | fail closed; no recursive cleanup |
| 275 | workspace identity | post-exec: mode | fail closed; no recursive cleanup |
| 276 | workspace identity | post-exec: links | fail closed; no recursive cleanup |
| 277 | workspace identity | post-exec: root symlink | fail closed; no recursive cleanup |
| 278 | workspace identity | post-exec: parent inode | fail closed; no recursive cleanup |
| 279 | workspace identity | pre-cleanup: device | fail closed; no recursive cleanup |
| 280 | workspace identity | pre-cleanup: inode | fail closed; no recursive cleanup |
| 281 | workspace identity | pre-cleanup: uid | fail closed; no recursive cleanup |
| 282 | workspace identity | pre-cleanup: gid | fail closed; no recursive cleanup |
| 283 | workspace identity | pre-cleanup: mode | fail closed; no recursive cleanup |
| 284 | workspace identity | pre-cleanup: links | fail closed; no recursive cleanup |
| 285 | workspace identity | pre-cleanup: root symlink | fail closed; no recursive cleanup |
| 286 | workspace identity | pre-cleanup: parent inode | fail closed; no recursive cleanup |
| 287 | workspace child | app_ent.xml: absent | allowlisted direct child only; 0600/0700 exact validation |
| 288 | workspace child | app_ent.xml: preexisting regular | allowlisted direct child only; 0600/0700 exact validation |
| 289 | workspace child | app_ent.xml: preexisting symlink | allowlisted direct child only; 0600/0700 exact validation |
| 290 | workspace child | app_ent.xml: directory | allowlisted direct child only; 0600/0700 exact validation |
| 291 | workspace child | app_ent.xml: FIFO | allowlisted direct child only; 0600/0700 exact validation |
| 292 | workspace child | app_ent.xml: wrong owner | allowlisted direct child only; 0600/0700 exact validation |
| 293 | workspace child | app_ent.xml: wrong mode | allowlisted direct child only; 0600/0700 exact validation |
| 294 | workspace child | app_ent.xml: wrong device | allowlisted direct child only; 0600/0700 exact validation |
| 295 | workspace child | app_ent.xml: hard linked | allowlisted direct child only; 0600/0700 exact validation |
| 296 | workspace child | app_ent.xml: safe exact child | allowlisted direct child only; 0600/0700 exact validation |
| 297 | workspace child | app_ent.xml: replaced after create | allowlisted direct child only; 0600/0700 exact validation |
| 298 | workspace child | helper_ent.plist: absent | allowlisted direct child only; 0600/0700 exact validation |
| 299 | workspace child | helper_ent.plist: preexisting regular | allowlisted direct child only; 0600/0700 exact validation |
| 300 | workspace child | helper_ent.plist: preexisting symlink | allowlisted direct child only; 0600/0700 exact validation |
| 301 | workspace child | helper_ent.plist: directory | allowlisted direct child only; 0600/0700 exact validation |
| 302 | workspace child | helper_ent.plist: FIFO | allowlisted direct child only; 0600/0700 exact validation |
| 303 | workspace child | helper_ent.plist: wrong owner | allowlisted direct child only; 0600/0700 exact validation |
| 304 | workspace child | helper_ent.plist: wrong mode | allowlisted direct child only; 0600/0700 exact validation |
| 305 | workspace child | helper_ent.plist: wrong device | allowlisted direct child only; 0600/0700 exact validation |
| 306 | workspace child | helper_ent.plist: hard linked | allowlisted direct child only; 0600/0700 exact validation |
| 307 | workspace child | helper_ent.plist: safe exact child | allowlisted direct child only; 0600/0700 exact validation |
| 308 | workspace child | helper_ent.plist: replaced after create | allowlisted direct child only; 0600/0700 exact validation |
| 309 | workspace child | backup_helper: absent | allowlisted direct child only; 0600/0700 exact validation |
| 310 | workspace child | backup_helper: preexisting regular | allowlisted direct child only; 0600/0700 exact validation |
| 311 | workspace child | backup_helper: preexisting symlink | allowlisted direct child only; 0600/0700 exact validation |
| 312 | workspace child | backup_helper: directory | allowlisted direct child only; 0600/0700 exact validation |
| 313 | workspace child | backup_helper: FIFO | allowlisted direct child only; 0600/0700 exact validation |
| 314 | workspace child | backup_helper: wrong owner | allowlisted direct child only; 0600/0700 exact validation |
| 315 | workspace child | backup_helper: wrong mode | allowlisted direct child only; 0600/0700 exact validation |
| 316 | workspace child | backup_helper: wrong device | allowlisted direct child only; 0600/0700 exact validation |
| 317 | workspace child | backup_helper: hard linked | allowlisted direct child only; 0600/0700 exact validation |
| 318 | workspace child | backup_helper: safe exact child | allowlisted direct child only; 0600/0700 exact validation |
| 319 | workspace child | backup_helper: replaced after create | allowlisted direct child only; 0600/0700 exact validation |
| 320 | workspace child | restore_input.plist: absent | allowlisted direct child only; 0600/0700 exact validation |
| 321 | workspace child | restore_input.plist: preexisting regular | allowlisted direct child only; 0600/0700 exact validation |
| 322 | workspace child | restore_input.plist: preexisting symlink | allowlisted direct child only; 0600/0700 exact validation |
| 323 | workspace child | restore_input.plist: directory | allowlisted direct child only; 0600/0700 exact validation |
| 324 | workspace child | restore_input.plist: FIFO | allowlisted direct child only; 0600/0700 exact validation |
| 325 | workspace child | restore_input.plist: wrong owner | allowlisted direct child only; 0600/0700 exact validation |
| 326 | workspace child | restore_input.plist: wrong mode | allowlisted direct child only; 0600/0700 exact validation |
| 327 | workspace child | restore_input.plist: wrong device | allowlisted direct child only; 0600/0700 exact validation |
| 328 | workspace child | restore_input.plist: hard linked | allowlisted direct child only; 0600/0700 exact validation |
| 329 | workspace child | restore_input.plist: safe exact child | allowlisted direct child only; 0600/0700 exact validation |
| 330 | workspace child | restore_input.plist: replaced after create | allowlisted direct child only; 0600/0700 exact validation |
| 331 | installed helper | missing | 60 for source authority; 63 for internal copy assurance |
| 332 | installed helper | directory | 60 for source authority; 63 for internal copy assurance |
| 333 | installed helper | FIFO | 60 for source authority; 63 for internal copy assurance |
| 334 | installed helper | socket | 60 for source authority; 63 for internal copy assurance |
| 335 | installed helper | symlink | 60 for source authority; 63 for internal copy assurance |
| 336 | installed helper | non-executable | 60 for source authority; 63 for internal copy assurance |
| 337 | installed helper | empty | 60 for source authority; 63 for internal copy assurance |
| 338 | installed helper | group writable | 60 for source authority; 63 for internal copy assurance |
| 339 | installed helper | world writable | 60 for source authority; 63 for internal copy assurance |
| 340 | installed helper | wrong owner | 60 for source authority; 63 for internal copy assurance |
| 341 | installed helper | hard linked | 60 for source authority; 63 for internal copy assurance |
| 342 | installed helper | unsafe parent | 60 for source authority; 63 for internal copy assurance |
| 343 | installed helper | changes before copy | 60 for source authority; 63 for internal copy assurance |
| 344 | installed helper | changes during copy | 60 for source authority; 63 for internal copy assurance |
| 345 | installed helper | cmp mismatch | 60 for source authority; 63 for internal copy assurance |
| 346 | installed helper | safe stable source | 60 for source authority; 63 for internal copy assurance |
| 347 | target discovery | system app | bounded fixed-root discovery or 61 |
| 348 | target discovery | rootless system app | bounded fixed-root discovery or 61 |
| 349 | target discovery | App Store app | bounded fixed-root discovery or 61 |
| 350 | target discovery | arbitrary root | bounded fixed-root discovery or 61 |
| 351 | target discovery | nested recursive app | bounded fixed-root discovery or 61 |
| 352 | target discovery | symlink app | bounded fixed-root discovery or 61 |
| 353 | target discovery | symlink UUID | bounded fixed-root discovery or 61 |
| 354 | target discovery | duplicate bundle ID | bounded fixed-root discovery or 61 |
| 355 | target discovery | missing root | bounded fixed-root discovery or 61 |
| 356 | target discovery | physical root alias | bounded fixed-root discovery or 61 |
| 357 | target discovery | valid direct child | bounded fixed-root discovery or 61 |
| 358 | Info.plist | missing | candidate rejected unless exact stable safe file |
| 359 | Info.plist | directory | candidate rejected unless exact stable safe file |
| 360 | Info.plist | symlink | candidate rejected unless exact stable safe file |
| 361 | Info.plist | unreadable | candidate rejected unless exact stable safe file |
| 362 | Info.plist | empty | candidate rejected unless exact stable safe file |
| 363 | Info.plist | oversized | candidate rejected unless exact stable safe file |
| 364 | Info.plist | group writable | candidate rejected unless exact stable safe file |
| 365 | Info.plist | world writable | candidate rejected unless exact stable safe file |
| 366 | Info.plist | wrong owner | candidate rejected unless exact stable safe file |
| 367 | Info.plist | hard linked | candidate rejected unless exact stable safe file |
| 368 | Info.plist | changes during identifier read | candidate rejected unless exact stable safe file |
| 369 | Info.plist | changes during executable read | candidate rejected unless exact stable safe file |
| 370 | Info.plist | valid stable | candidate rejected unless exact stable safe file |
| 371 | CFBundleExecutable | empty | safe direct-child basename only |
| 372 | CFBundleExecutable | slash | safe direct-child basename only |
| 373 | CFBundleExecutable | backslash | safe direct-child basename only |
| 374 | CFBundleExecutable | dot | safe direct-child basename only |
| 375 | CFBundleExecutable | dotdot | safe direct-child basename only |
| 376 | CFBundleExecutable | leading dash | safe direct-child basename only |
| 377 | CFBundleExecutable | newline | safe direct-child basename only |
| 378 | CFBundleExecutable | control | safe direct-child basename only |
| 379 | CFBundleExecutable | overlong | safe direct-child basename only |
| 380 | CFBundleExecutable | normal basename | safe direct-child basename only |
| 381 | CFBundleExecutable | unicode basename | safe direct-child basename only |
| 382 | CFBundleExecutable | Frameworks/foo | safe direct-child basename only |
| 383 | CFBundleExecutable | ../foo | safe direct-child basename only |
| 384 | CFBundleExecutable | foo/bar | safe direct-child basename only |
| 385 | target executable | missing | 61 unless regular stable safe executable |
| 386 | target executable | directory | 61 unless regular stable safe executable |
| 387 | target executable | symlink | 61 unless regular stable safe executable |
| 388 | target executable | FIFO | 61 unless regular stable safe executable |
| 389 | target executable | socket | 61 unless regular stable safe executable |
| 390 | target executable | non-executable | 61 unless regular stable safe executable |
| 391 | target executable | empty | 61 unless regular stable safe executable |
| 392 | target executable | group writable | 61 unless regular stable safe executable |
| 393 | target executable | world writable | 61 unless regular stable safe executable |
| 394 | target executable | wrong owner | 61 unless regular stable safe executable |
| 395 | target executable | hard linked | 61 unless regular stable safe executable |
| 396 | target executable | changes during extraction | 61 unless regular stable safe executable |
| 397 | target executable | safe root-owned | 61 unless regular stable safe executable |
| 398 | target executable | safe mobile-owned | 61 unless regular stable safe executable |
| 399 | bundle identifier | empty | malformed => 20 |
| 400 | bundle identifier | slash | malformed => 20 |
| 401 | bundle identifier | backslash | malformed => 20 |
| 402 | bundle identifier | space | malformed => 20 |
| 403 | bundle identifier | shell metacharacter | malformed => 20 |
| 404 | bundle identifier | leading dot | malformed => 20 |
| 405 | bundle identifier | leading dash | malformed => 20 |
| 406 | bundle identifier | newline | malformed => 20 |
| 407 | bundle identifier | control | malformed => 20 |
| 408 | bundle identifier | overlong | malformed => 20 |
| 409 | bundle identifier | valid dotted | malformed => 20 |
| 410 | bundle identifier | valid underscore | malformed => 20 |
| 411 | bundle identifier | valid hyphen | malformed => 20 |
| 412 | restore input | relative | caller/source failure =>21; internal snapshot assurance =>63 |
| 413 | restore input | missing | caller/source failure =>21; internal snapshot assurance =>63 |
| 414 | restore input | directory | caller/source failure =>21; internal snapshot assurance =>63 |
| 415 | restore input | symlink | caller/source failure =>21; internal snapshot assurance =>63 |
| 416 | restore input | FIFO | caller/source failure =>21; internal snapshot assurance =>63 |
| 417 | restore input | socket | caller/source failure =>21; internal snapshot assurance =>63 |
| 418 | restore input | device | caller/source failure =>21; internal snapshot assurance =>63 |
| 419 | restore input | empty | caller/source failure =>21; internal snapshot assurance =>63 |
| 420 | restore input | unreadable | caller/source failure =>21; internal snapshot assurance =>63 |
| 421 | restore input | parent missing | caller/source failure =>21; internal snapshot assurance =>63 |
| 422 | restore input | parent replacement | caller/source failure =>21; internal snapshot assurance =>63 |
| 423 | restore input | source replacement | caller/source failure =>21; internal snapshot assurance =>63 |
| 424 | restore input | copy mismatch | caller/source failure =>21; internal snapshot assurance =>63 |
| 425 | restore input | spaces | caller/source failure =>21; internal snapshot assurance =>63 |
| 426 | restore input | dot filename | caller/source failure =>21; internal snapshot assurance =>63 |
| 427 | restore input | safe regular | caller/source failure =>21; internal snapshot assurance =>63 |
| 428 | backup output | relative | initial invalid =>21; authority loss =>63 |
| 429 | backup output | missing parent | initial invalid =>21; authority loss =>63 |
| 430 | backup output | parent file | initial invalid =>21; authority loss =>63 |
| 431 | backup output | physical parent symlink | initial invalid =>21; authority loss =>63 |
| 432 | backup output | unwritable parent | initial invalid =>21; authority loss =>63 |
| 433 | backup output | existing regular | initial invalid =>21; authority loss =>63 |
| 434 | backup output | existing symlink | initial invalid =>21; authority loss =>63 |
| 435 | backup output | existing directory | initial invalid =>21; authority loss =>63 |
| 436 | backup output | existing FIFO | initial invalid =>21; authority loss =>63 |
| 437 | backup output | existing socket | initial invalid =>21; authority loss =>63 |
| 438 | backup output | absent safe leaf | initial invalid =>21; authority loss =>63 |
| 439 | backup output | leading dash | initial invalid =>21; authority loss =>63 |
| 440 | backup output | spaces | initial invalid =>21; authority loss =>63 |
| 441 | backup output | parent changes before | initial invalid =>21; authority loss =>63 |
| 442 | backup output | leaf changes before | initial invalid =>21; authority loss =>63 |
| 443 | backup output | parent changes after | initial invalid =>21; authority loss =>63 |
| 444 | backup output | no output on success | initial invalid =>21; authority loss =>63 |
| 445 | backup output | empty output | initial invalid =>21; authority loss =>63 |
| 446 | backup output | symlink output | initial invalid =>21; authority loss =>63 |
| 447 | backup output | directory output | initial invalid =>21; authority loss =>63 |
| 448 | backup output | nonempty regular output | initial invalid =>21; authority loss =>63 |
| 449 | backup output | failure without output | initial invalid =>21; authority loss =>63 |
| 450 | entitlement path | app_ent preexists | 62 semantic failure or 63 workspace assurance |
| 451 | entitlement path | app_ent symlink | 62 semantic failure or 63 workspace assurance |
| 452 | entitlement path | extract fails | 62 semantic failure or 63 workspace assurance |
| 453 | entitlement path | target changes | 62 semantic failure or 63 workspace assurance |
| 454 | entitlement path | app_ent wrong mode | 62 semantic failure or 63 workspace assurance |
| 455 | entitlement path | helper_ent preexists | 62 semantic failure or 63 workspace assurance |
| 456 | entitlement path | source changes | 62 semantic failure or 63 workspace assurance |
| 457 | entitlement path | copy mismatch | 62 semantic failure or 63 workspace assurance |
| 458 | entitlement path | plutil unsafe replacement | 62 semantic failure or 63 workspace assurance |
| 459 | entitlement path | generated empty | 62 semantic failure or 63 workspace assurance |
| 460 | entitlement path | valid 0600 | 62 semantic failure or 63 workspace assurance |
| 461 | helper/signing | destination exists | 60/63/64 according to authority boundary |
| 462 | helper/signing | source changes before copy | 60/63/64 according to authority boundary |
| 463 | helper/signing | source changes during copy | 60/63/64 according to authority boundary |
| 464 | helper/signing | copy fails | 60/63/64 according to authority boundary |
| 465 | helper/signing | cmp mismatch | 60/63/64 according to authority boundary |
| 466 | helper/signing | chmod fails | 60/63/64 according to authority boundary |
| 467 | helper/signing | wrong owner | 60/63/64 according to authority boundary |
| 468 | helper/signing | wrong mode | 60/63/64 according to authority boundary |
| 469 | helper/signing | entitlement changes | 60/63/64 according to authority boundary |
| 470 | helper/signing | ldid nonzero | 60/63/64 according to authority boundary |
| 471 | helper/signing | helper symlink replacement | 60/63/64 according to authority boundary |
| 472 | helper/signing | helper empty | 60/63/64 according to authority boundary |
| 473 | helper/signing | post-sign wrong mode | 60/63/64 according to authority boundary |
| 474 | helper/signing | valid signed helper | 60/63/64 according to authority boundary |
| 475 | helper execution | backup: workspace changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 476 | helper execution | backup: helper changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 477 | helper execution | backup: entitlement changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 478 | helper execution | backup: immediate raw capture | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 479 | helper execution | backup: status 0 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 480 | helper execution | backup: status 10 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 481 | helper execution | backup: status 20 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 482 | helper execution | backup: status 21 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 483 | helper execution | backup: status 30 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 484 | helper execution | backup: status 40 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 485 | helper execution | backup: status 50 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 486 | helper execution | backup: status 1 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 487 | helper execution | backup: status 2 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 488 | helper execution | backup: signal status | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 489 | helper execution | restore: workspace changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 490 | helper execution | restore: helper changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 491 | helper execution | restore: entitlement changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 492 | helper execution | restore: immediate raw capture | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 493 | helper execution | restore: status 0 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 494 | helper execution | restore: status 10 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 495 | helper execution | restore: status 20 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 496 | helper execution | restore: status 21 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 497 | helper execution | restore: status 30 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 498 | helper execution | restore: status 40 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 499 | helper execution | restore: status 50 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 500 | helper execution | restore: status 1 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 501 | helper execution | restore: status 2 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 502 | helper execution | restore: signal status | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 503 | helper execution | wipe: workspace changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 504 | helper execution | wipe: helper changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 505 | helper execution | wipe: entitlement changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 506 | helper execution | wipe: immediate raw capture | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 507 | helper execution | wipe: status 0 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 508 | helper execution | wipe: status 10 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 509 | helper execution | wipe: status 20 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 510 | helper execution | wipe: status 21 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 511 | helper execution | wipe: status 30 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 512 | helper execution | wipe: status 40 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 513 | helper execution | wipe: status 50 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 514 | helper execution | wipe: status 1 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 515 | helper execution | wipe: status 2 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 516 | helper execution | wipe: signal status | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 517 | helper execution | list: workspace changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 518 | helper execution | list: helper changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 519 | helper execution | list: entitlement changed | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 520 | helper execution | list: immediate raw capture | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 521 | helper execution | list: status 0 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 522 | helper execution | list: status 10 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 523 | helper execution | list: status 20 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 524 | helper execution | list: status 21 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 525 | helper execution | list: status 30 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 526 | helper execution | list: status 40 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 527 | helper execution | list: status 50 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 528 | helper execution | list: status 1 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 529 | helper execution | list: status 2 | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 530 | helper execution | list: signal status | direct stdout passthrough; recognized unchanged; unknown =>40 |
| 531 | cleanup | empty | bounded known-child unlink; unknown preserved; failure =>63 |
| 532 | cleanup | all known files | bounded known-child unlink; unknown preserved; failure =>63 |
| 533 | cleanup | one known absent | bounded known-child unlink; unknown preserved; failure =>63 |
| 534 | cleanup | known symlink | bounded known-child unlink; unknown preserved; failure =>63 |
| 535 | cleanup | known directory | bounded known-child unlink; unknown preserved; failure =>63 |
| 536 | cleanup | known FIFO | bounded known-child unlink; unknown preserved; failure =>63 |
| 537 | cleanup | unknown regular | bounded known-child unlink; unknown preserved; failure =>63 |
| 538 | cleanup | unknown symlink | bounded known-child unlink; unknown preserved; failure =>63 |
| 539 | cleanup | unknown directory | bounded known-child unlink; unknown preserved; failure =>63 |
| 540 | cleanup | nested content | bounded known-child unlink; unknown preserved; failure =>63 |
| 541 | cleanup | root symlink | bounded known-child unlink; unknown preserved; failure =>63 |
| 542 | cleanup | inode mismatch | bounded known-child unlink; unknown preserved; failure =>63 |
| 543 | cleanup | owner mismatch | bounded known-child unlink; unknown preserved; failure =>63 |
| 544 | cleanup | mode mismatch | bounded known-child unlink; unknown preserved; failure =>63 |
| 545 | cleanup | parent mismatch | bounded known-child unlink; unknown preserved; failure =>63 |
| 546 | cleanup | rm failure | bounded known-child unlink; unknown preserved; failure =>63 |
| 547 | cleanup | rmdir failure | bounded known-child unlink; unknown preserved; failure =>63 |
| 548 | cleanup | after success | bounded known-child unlink; unknown preserved; failure =>63 |
| 549 | cleanup | after Partial | bounded known-child unlink; unknown preserved; failure =>63 |
| 550 | cleanup | after sign failure | bounded known-child unlink; unknown preserved; failure =>63 |
| 551 | cleanup | after target failure | bounded known-child unlink; unknown preserved; failure =>63 |
| 552 | cleanup | after snapshot failure | bounded known-child unlink; unknown preserved; failure =>63 |
| 553 | normalizer | raw 0 | 0 |
| 554 | cleanup override | original 0, cleanup fails | 63 |
| 555 | normalizer | raw 10 | 10 |
| 556 | cleanup override | original 10, cleanup fails | 63 |
| 557 | normalizer | raw 20 | 20 |
| 558 | cleanup override | original 20, cleanup fails | 63 |
| 559 | normalizer | raw 21 | 21 |
| 560 | cleanup override | original 21, cleanup fails | 63 |
| 561 | normalizer | raw 30 | 30 |
| 562 | cleanup override | original 30, cleanup fails | 63 |
| 563 | normalizer | raw 40 | 40 |
| 564 | cleanup override | original 40, cleanup fails | 63 |
| 565 | normalizer | raw 50 | 50 |
| 566 | cleanup override | original 50, cleanup fails | 63 |
| 567 | normalizer | raw 1 | 40 |
| 568 | cleanup override | original 1, cleanup fails | 63 |
| 569 | normalizer | raw 2 | 40 |
| 570 | cleanup override | original 2, cleanup fails | 63 |
| 571 | normalizer | raw 60 | 40 |
| 572 | cleanup override | original 60, cleanup fails | 63 |
| 573 | normalizer | raw 61 | 40 |
| 574 | cleanup override | original 61, cleanup fails | 63 |
| 575 | normalizer | raw 62 | 40 |
| 576 | cleanup override | original 62, cleanup fails | 63 |
| 577 | normalizer | raw 63 | 40 |
| 578 | cleanup override | original 63, cleanup fails | 63 |
| 579 | normalizer | raw 64 | 40 |
| 580 | cleanup override | original 64, cleanup fails | 63 |
| 581 | normalizer | raw 65 | 40 |
| 582 | cleanup override | original 65, cleanup fails | 63 |
| 583 | normalizer | raw 126 | 40 |
| 584 | cleanup override | original 126, cleanup fails | 63 |
| 585 | normalizer | raw 127 | 40 |
| 586 | cleanup override | original 127, cleanup fails | 63 |
| 587 | normalizer | raw 128 | 40 |
| 588 | cleanup override | original 128, cleanup fails | 63 |
| 589 | normalizer | raw 137 | 40 |
| 590 | cleanup override | original 137, cleanup fails | 63 |
| 591 | normalizer | raw 255 | 40 |
| 592 | cleanup override | original 255, cleanup fails | 63 |
| 593 | protocol | stdout bytes unchanged | TASK-4.1/4.2 framing unchanged |
| 594 | protocol | machine line untouched | TASK-4.1/4.2 framing unchanged |
| 595 | protocol | stderr separate | TASK-4.1/4.2 framing unchanged |
| 596 | protocol | no wrapper envelope | TASK-4.1/4.2 framing unchanged |
| 597 | protocol | no parse | TASK-4.1/4.2 framing unchanged |
| 598 | protocol | no filter | TASK-4.1/4.2 framing unchanged |
| 599 | protocol | no re-encode | TASK-4.1/4.2 framing unchanged |
| 600 | protocol | pre-helper failure | TASK-4.1/4.2 framing unchanged |
| 601 | protocol | one normalizer | TASK-4.1/4.2 framing unchanged |
| 602 | protocol | four calls | TASK-4.1/4.2 framing unchanged |
| 603 | action compatibility | backup groups | existing CLI/group policy preserved |
| 604 | action compatibility | backup no override | existing CLI/group policy preserved |
| 605 | action compatibility | restore no overwrite | existing CLI/group policy preserved |
| 606 | action compatibility | restore overwrite | existing CLI/group policy preserved |
| 607 | action compatibility | wipe | existing CLI/group policy preserved |
| 608 | action compatibility | list | existing CLI/group policy preserved |
| 609 | action compatibility | verbose | existing CLI/group policy preserved |
| 610 | action compatibility | help | existing CLI/group policy preserved |
| 611 | action compatibility | missing action | existing CLI/group policy preserved |
| 612 | action compatibility | unknown action | existing CLI/group policy preserved |
| 613 | action compatibility | invalid bundle | existing CLI/group policy preserved |
| 614 | action compatibility | application-id fallback | existing CLI/group policy preserved |
| 615 | action compatibility | system entitlement policy | existing CLI/group policy preserved |
| 616 | action compatibility | App Store policy | existing CLI/group policy preserved |
| 617 | non-regression | TASK-4.1 schema | byte-identical |
| 618 | non-regression | ten-key graph | byte-identical |
| 619 | non-regression | prefix | byte-identical |
| 620 | non-regression | emitter | byte-identical |
| 621 | non-regression | finalizer | byte-identical |
| 622 | non-regression | TASK-4.2 codes | byte-identical |
| 623 | non-regression | TASK-4.3 zero restore delete | byte-identical |
| 624 | non-regression | TASK-4.4 identity | byte-identical |
| 625 | non-regression | TASK-4.5 add-first | byte-identical |
| 626 | non-regression | TASK-4.5 lookup | byte-identical |
| 627 | non-regression | TASK-4.5 update | byte-identical |
| 628 | non-regression | wipe sole delete | byte-identical |
| 629 | non-regression | manager | byte-identical |
| 630 | non-regression | bridge | byte-identical |
| 631 | non-regression | Makefile | byte-identical |
| 632 | non-regression | package layout | byte-identical |

## Shell syntax evidence
```text
C:\Program Files\Git\bin\bash.exe -n scripts/keychain_backup.sh    PASS
C:\Program Files\Git\usr\bin\bash.exe -n scripts/keychain_backup.sh    PASS
```
Git Bash proves grammar, not iOS BSD runtime. BSD assumptions have model/static coverage and remain device pending.

## Full authorized production diff
Report self-diff excluded; physical diff lines right-trimmed only for report hygiene.
```diff
diff --git a/scripts/keychain_backup.sh b/scripts/keychain_backup.sh
index 45f0cba..222056f 100644
--- a/scripts/keychain_backup.sh
+++ b/scripts/keychain_backup.sh
@@ -19,11 +19,35 @@

 # Removed 'set -e' for better error handling - we handle errors explicitly

+# === Fixed shell environment ===
+PATH="/usr/bin:/bin:/usr/sbin:/sbin:/var/jb/usr/bin:/var/jb/bin:/private/preboot/jb/usr/bin:/private/preboot/jb/bin"
+export PATH
+IFS=$' \t\n'
+export -n IFS 2>/dev/null || true
+unset CDPATH ENV BASH_ENV GLOBIGNORE
+LC_ALL=C
+LANG=C
+export LC_ALL LANG
+umask 077
+
 # === Configuration ===
-HELPER_TOOL_PATH="/Library/WeaponX/backup_helper"
-TEMP_DIR="/tmp/keychain_helper_$$"
+readonly HELPER_TOOL_PATH="/Library/WeaponX/backup_helper"
+readonly PX_WORKSPACE_PARENT="/private/var/tmp"
+readonly PX_WORKSPACE_PREFIX=".weaponx-keychain-helper."
 VERBOSE=0

+PX_WORKSPACE_PATH=""
+PX_WORKSPACE_DEVICE=""
+PX_WORKSPACE_INODE=""
+PX_WORKSPACE_UID=""
+PX_WORKSPACE_GID=""
+PX_WORKSPACE_MODE=""
+PX_WORKSPACE_LINKS=""
+PX_WORKSPACE_PARENT_DEVICE=""
+PX_WORKSPACE_PARENT_INODE=""
+PX_WORKSPACE_ACTIVE=0
+PX_WORKSPACE_CREATE_ATTEMPTED=0
+
 readonly PX_KEYCHAIN_EXIT_COMPLETED=0
 readonly PX_KEYCHAIN_EXIT_PARTIAL=10
 readonly PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS=20
@@ -73,6 +97,248 @@ log_verbose() {
     fi
 }

+PX_STAT_PATH=""
+PX_MKTEMP_PATH=""
+PX_CP_PATH=""
+PX_CMP_PATH=""
+PX_CHMOD_PATH=""
+PX_RM_PATH=""
+PX_RMDIR_PATH=""
+PX_PLUTIL_PATH=""
+PX_LDID_PATH=""
+PX_GREP_PATH=""
+PX_SED_PATH=""
+PX_METADATA_READY=0
+PX_DEPENDENCIES_READY=0
+
+px_mode_is_safe_executable() {
+    local mode="$1"
+    case "$mode" in
+        ""|*[!0-7]*) return 1 ;;
+    esac
+    local mode_value=$((8#$mode))
+    [ $((mode_value & 0022)) -eq 0 ]
+}
+
+px_bootstrap_stat() {
+    local candidates=(
+        "/usr/bin/stat"
+        "/bin/stat"
+        "/var/jb/usr/bin/stat"
+        "/private/preboot/jb/usr/bin/stat"
+    )
+    local candidate parent basename physical_parent resolved output
+    local device inode uid gid mode size links mtime ctime extra
+    for candidate in "${candidates[@]}"; do
+        [ -f "$candidate" ] || continue
+        [ ! -L "$candidate" ] || continue
+        [ -x "$candidate" ] || continue
+        [ -s "$candidate" ] || continue
+        parent="${candidate%/*}"
+        basename="${candidate##*/}"
+        physical_parent=$(cd -P "$parent" 2>/dev/null && pwd -P) || continue
+        resolved="${physical_parent%/}/$basename"
+        [ -f "$resolved" ] || continue
+        [ ! -L "$resolved" ] || continue
+        [ -x "$resolved" ] || continue
+        output=$("$resolved" -f '%d|%i|%u|%g|%Lp|%z|%l|%m|%c' "$resolved" 2>/dev/null) || continue
+        case "$output" in *$'\n'*|*$'\r'*) continue ;; esac
+        IFS='|' read -r device inode uid gid mode size links mtime ctime extra <<< "$output"
+        [ -z "$extra" ] || continue
+        [ -n "$device" ] && [ -n "$inode" ] && [ -n "$uid" ] && [ -n "$gid" ] || continue
+        [ -n "$size" ] && [ -n "$links" ] && [ -n "$mtime" ] && [ -n "$ctime" ] || continue
+        case "$device:$inode:$uid:$gid:$size:$links:$mtime:$ctime" in
+            *[!0-9:]*|::*|:*:) continue ;;
+        esac
+        [ "$uid" -eq 0 ] || continue
+        [ "$size" -gt 0 ] || continue
+        px_mode_is_safe_executable "$mode" || continue
+        PX_STAT_PATH="$resolved"
+        return 0
+    done
+    return 1
+}
+
+px_valid_snapshot_prefix() {
+    local prefix="$1"
+    [ -n "$prefix" ] && [ "${#prefix}" -le 64 ] || return 1
+    case "$prefix" in
+        PX_*) ;;
+        *) return 1 ;;
+    esac
+    case "$prefix" in
+        *[!A-Z0-9_]*) return 1 ;;
+    esac
+    return 0
+}
+
+px_stat_snapshot() {
+    local path="$1"
+    local prefix="$2"
+    [ "$PX_METADATA_READY" -eq 1 ] || return 1
+    [ -n "$path" ] || return 1
+    px_valid_snapshot_prefix "$prefix" || return 1
+    local output device inode uid gid mode size links mtime ctime extra
+    output=$("$PX_STAT_PATH" -f '%d|%i|%u|%g|%Lp|%z|%l|%m|%c' "$path" 2>/dev/null) || return 1
+    case "$output" in *$'\n'*|*$'\r'*) return 1 ;; esac
+    IFS='|' read -r device inode uid gid mode size links mtime ctime extra <<< "$output"
+    [ -z "$extra" ] || return 1
+    [ -n "$device" ] && [ -n "$inode" ] && [ -n "$uid" ] && [ -n "$gid" ] || return 1
+    [ -n "$size" ] && [ -n "$links" ] && [ -n "$mtime" ] && [ -n "$ctime" ] || return 1
+    case "$device:$inode:$uid:$gid:$size:$links:$mtime:$ctime" in
+        *[!0-9:]*|::*|:*:) return 1 ;;
+    esac
+    case "$mode" in ""|*[!0-7]*) return 1 ;; esac
+    printf -v "${prefix}_DEVICE" '%s' "$device"
+    printf -v "${prefix}_INODE" '%s' "$inode"
+    printf -v "${prefix}_UID" '%s' "$uid"
+    printf -v "${prefix}_GID" '%s' "$gid"
+    printf -v "${prefix}_MODE" '%s' "$mode"
+    printf -v "${prefix}_SIZE" '%s' "$size"
+    printf -v "${prefix}_LINKS" '%s' "$links"
+    printf -v "${prefix}_MTIME" '%s' "$mtime"
+    printf -v "${prefix}_CTIME" '%s' "$ctime"
+    return 0
+}
+
+px_same_identity() {
+    px_valid_snapshot_prefix "$1" || return 1
+    px_valid_snapshot_prefix "$2" || return 1
+    local left="$1"
+    local right="$2"
+    local field left_value right_value
+    for field in DEVICE INODE UID GID MODE LINKS; do
+        eval "left_value=\${${left}_${field}}"
+        eval "right_value=\${${right}_${field}}"
+        [ "$left_value" = "$right_value" ] || return 1
+    done
+    return 0
+}
+
+px_same_complete_snapshot() {
+    px_valid_snapshot_prefix "$1" || return 1
+    px_valid_snapshot_prefix "$2" || return 1
+    local left="$1"
+    local right="$2"
+    px_same_identity "$left" "$right" || return 1
+    local field left_value right_value
+    for field in SIZE MTIME CTIME; do
+        eval "left_value=\${${left}_${field}}"
+        eval "right_value=\${${right}_${field}}"
+        [ "$left_value" = "$right_value" ] || return 1
+    done
+    return 0
+}
+
+px_physical_directory() {
+    local directory="$1"
+    [ -n "$directory" ] || return 1
+    case "$directory" in /*) ;; *) return 1 ;; esac
+    case "$directory" in *$'\n'*|*$'\r'*) return 1 ;; esac
+    [ "${#directory}" -le 4096 ] || return 1
+    local physical
+    physical=$(cd -P "$directory" 2>/dev/null && pwd -P) || return 1
+    case "$physical" in /*) ;; *) return 1 ;; esac
+    PX_PHYSICAL_DIRECTORY="$physical"
+    return 0
+}
+
+px_resolve_trusted_utility() {
+    local variable_name="$1"
+    shift
+    local candidate parent basename resolved
+    for candidate in "$@"; do
+        case "$candidate" in /*) ;; *) continue ;; esac
+        [ ! -L "$candidate" ] || continue
+        parent="${candidate%/*}"
+        basename="${candidate##*/}"
+        px_physical_directory "$parent" || continue
+        resolved="${PX_PHYSICAL_DIRECTORY%/}/$basename"
+        [ -f "$resolved" ] || continue
+        [ ! -L "$resolved" ] || continue
+        [ -x "$resolved" ] || continue
+        [ -s "$resolved" ] || continue
+        px_stat_snapshot "$resolved" PX_UTILITY || continue
+        px_stat_snapshot "$PX_PHYSICAL_DIRECTORY" PX_UTILITY_PARENT || continue
+        [ "$PX_UTILITY_UID" -eq 0 ] || continue
+        [ "$PX_UTILITY_PARENT_UID" -eq 0 ] || continue
+        px_mode_is_safe_executable "$PX_UTILITY_MODE" || continue
+        px_mode_is_safe_executable "$PX_UTILITY_PARENT_MODE" || continue
+        printf -v "$variable_name" '%s' "$resolved"
+        return 0
+    done
+    return 1
+}
+
+px_initialize_metadata_boundary() {
+    [ "$PX_METADATA_READY" -eq 0 ] || return 0
+    px_bootstrap_stat || return 1
+    PX_METADATA_READY=1
+    px_stat_snapshot "$PX_STAT_PATH" PX_STAT_SELF || return 1
+    [ "$PX_STAT_SELF_UID" -eq 0 ] || return 1
+    [ "$PX_STAT_SELF_SIZE" -gt 0 ] || return 1
+    px_mode_is_safe_executable "$PX_STAT_SELF_MODE" || return 1
+    px_physical_directory "${PX_STAT_PATH%/*}" || return 1
+    px_stat_snapshot "$PX_PHYSICAL_DIRECTORY" PX_STAT_PARENT || return 1
+    [ "$PX_STAT_PARENT_UID" -eq 0 ] || return 1
+    px_mode_is_safe_executable "$PX_STAT_PARENT_MODE" || return 1
+    readonly PX_STAT_PATH
+    return 0
+}
+
+px_resolve_trusted_dependencies() {
+    [ "$PX_DEPENDENCIES_READY" -eq 0 ] || return 0
+    px_resolve_trusted_utility PX_MKTEMP_PATH \
+        /usr/bin/mktemp /bin/mktemp /var/jb/usr/bin/mktemp /private/preboot/jb/usr/bin/mktemp || return 1
+    px_resolve_trusted_utility PX_CP_PATH \
+        /bin/cp /usr/bin/cp /var/jb/bin/cp /var/jb/usr/bin/cp /private/preboot/jb/bin/cp || return 1
+    px_resolve_trusted_utility PX_CMP_PATH \
+        /usr/bin/cmp /bin/cmp /var/jb/usr/bin/cmp /private/preboot/jb/usr/bin/cmp || return 1
+    px_resolve_trusted_utility PX_CHMOD_PATH \
+        /bin/chmod /usr/bin/chmod /var/jb/bin/chmod /private/preboot/jb/bin/chmod || return 1
+    px_resolve_trusted_utility PX_RM_PATH \
+        /bin/rm /usr/bin/rm /var/jb/bin/rm /private/preboot/jb/bin/rm || return 1
+    px_resolve_trusted_utility PX_RMDIR_PATH \
+        /bin/rmdir /usr/bin/rmdir /var/jb/bin/rmdir /private/preboot/jb/bin/rmdir || return 1
+    px_resolve_trusted_utility PX_PLUTIL_PATH \
+        /usr/bin/plutil /var/jb/usr/bin/plutil /private/preboot/jb/usr/bin/plutil /bin/plutil || return 1
+    px_resolve_trusted_utility PX_LDID_PATH \
+        /usr/bin/ldid /var/jb/usr/bin/ldid /private/preboot/jb/usr/bin/ldid /bin/ldid || return 1
+    px_resolve_trusted_utility PX_GREP_PATH \
+        /usr/bin/grep /bin/grep /var/jb/usr/bin/grep /private/preboot/jb/usr/bin/grep || return 1
+    px_resolve_trusted_utility PX_SED_PATH \
+        /usr/bin/sed /bin/sed /var/jb/usr/bin/sed /private/preboot/jb/usr/bin/sed || return 1
+    readonly PX_MKTEMP_PATH PX_CP_PATH PX_CMP_PATH PX_CHMOD_PATH PX_RM_PATH PX_RMDIR_PATH
+    readonly PX_PLUTIL_PATH PX_LDID_PATH PX_GREP_PATH PX_SED_PATH
+    PX_DEPENDENCIES_READY=1
+    return 0
+}
+
+px_validate_installed_helper() {
+    case "$HELPER_TOOL_PATH" in /*) ;; *) return 1 ;; esac
+    [ -f "$HELPER_TOOL_PATH" ] || return 1
+    [ ! -L "$HELPER_TOOL_PATH" ] || return 1
+    [ -x "$HELPER_TOOL_PATH" ] || return 1
+    [ -s "$HELPER_TOOL_PATH" ] || return 1
+    local parent="${HELPER_TOOL_PATH%/*}"
+    local basename="${HELPER_TOOL_PATH##*/}"
+    px_physical_directory "$parent" || return 1
+    local resolved="${PX_PHYSICAL_DIRECTORY%/}/$basename"
+    [ -f "$resolved" ] || return 1
+    [ ! -L "$resolved" ] || return 1
+    [ -x "$resolved" ] || return 1
+    px_stat_snapshot "$resolved" PX_INSTALLED_HELPER || return 1
+    px_stat_snapshot "$PX_PHYSICAL_DIRECTORY" PX_INSTALLED_HELPER_PARENT || return 1
+    [ "$PX_INSTALLED_HELPER_UID" -eq 0 ] || return 1
+    [ "$PX_INSTALLED_HELPER_PARENT_UID" -eq 0 ] || return 1
+    [ "$PX_INSTALLED_HELPER_LINKS" -eq 1 ] || return 1
+    [ "$PX_INSTALLED_HELPER_SIZE" -gt 0 ] || return 1
+    px_mode_is_safe_executable "$PX_INSTALLED_HELPER_MODE" || return 1
+    px_mode_is_safe_executable "$PX_INSTALLED_HELPER_PARENT_MODE" || return 1
+    PX_INSTALLED_HELPER_PATH="$resolved"
+    return 0
+}
+
 normalize_helper_exit_status() {
     local raw_status="$1"
     case "$raw_status" in
@@ -90,241 +356,598 @@ normalize_helper_exit_status() {
     esac
 }

-cleanup() {
-    if [ -d "$TEMP_DIR" ]; then
-        rm -rf "$TEMP_DIR"
+px_mode_is_exact() {
+    local actual="$1"
+    local expected="$2"
+    while [ "${actual#0}" != "$actual" ]; do actual="${actual#0}"; done
+    while [ "${expected#0}" != "$expected" ]; do expected="${expected#0}"; done
+    [ "$actual" = "$expected" ]
+}
+
+px_parent_has_safe_sticky_semantics() {
+    local mode="$1"
+    case "$mode" in ""|*[!0-7]*) return 1 ;; esac
+    local value=$((8#$mode))
+    if [ $((value & 0022)) -ne 0 ]; then
+        [ $((value & 01000)) -ne 0 ] || return 1
     fi
+    return 0
 }

-trap cleanup EXIT
+px_directory_is_empty() (
+    local directory="$1"
+    shopt -s nullglob dotglob
+    local entries=("$directory"/*)
+    [ "${#entries[@]}" -eq 0 ]
+)

-# === Find ldid binary ===
-find_ldid() {
-    local paths=(
-        "/usr/bin/ldid"
-        "/var/jb/usr/bin/ldid"
-        "/private/preboot/jb/usr/bin/ldid"
-        "/bin/ldid"
-    )
-
-    for path in "${paths[@]}"; do
-        if [ -x "$path" ]; then
-            echo "$path"
-            return 0
+px_workspace_path_has_authority() {
+    local path="$1"
+    [ -n "$path" ] && [ "${#path}" -le 4096 ] || return 1
+    px_string_has_control_character "$path" && return 1
+    case "$path" in
+        "$PX_WORKSPACE_PARENT/$PX_WORKSPACE_PREFIX"????????) ;;
+        *) return 1 ;;
+    esac
+    local basename="${path##*/}"
+    case "$basename" in */*|""|.|..) return 1 ;; esac
+    [ "${path%/*}" = "$PX_WORKSPACE_PARENT" ] || return 1
+    return 0
+}
+
+px_validate_workspace_parent() {
+    [ -d "$PX_WORKSPACE_PARENT" ] || return 1
+    [ ! -L "$PX_WORKSPACE_PARENT" ] || return 1
+    [ -x "$PX_WORKSPACE_PARENT" ] || return 1
+    px_physical_directory "$PX_WORKSPACE_PARENT" || return 1
+    [ "$PX_PHYSICAL_DIRECTORY" = "$PX_WORKSPACE_PARENT" ] || return 1
+    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_CURRENT || return 1
+    [ "$PX_WORKSPACE_PARENT_CURRENT_UID" -eq 0 ] || return 1
+    px_parent_has_safe_sticky_semantics "$PX_WORKSPACE_PARENT_CURRENT_MODE" || return 1
+    return 0
+}
+
+px_discard_unactivated_workspace() {
+    local path="$1"
+    px_workspace_path_has_authority "$path" || return 1
+    if [ -L "$path" ]; then
+        "$PX_RM_PATH" -f "$path" >/dev/null 2>&1 || return 1
+        return 0
+    fi
+    if [ -d "$path" ]; then
+        px_directory_is_empty "$path" || return 1
+        "$PX_RMDIR_PATH" "$path" >/dev/null 2>&1 || return 1
+        return 0
+    fi
+    if [ -e "$path" ]; then
+        return 1
+    fi
+    return 0
+}
+
+px_create_workspace() {
+    [ "$PX_WORKSPACE_CREATE_ATTEMPTED" -eq 0 ] || return 1
+    PX_WORKSPACE_CREATE_ATTEMPTED=1
+    px_validate_workspace_parent || return 1
+    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_BEFORE || return 1
+
+    local created
+    created=$("$PX_MKTEMP_PATH" -d "$PX_WORKSPACE_PARENT/$PX_WORKSPACE_PREFIX"XXXXXXXX 2>/dev/null) || return 1
+    case "$created" in *$'\n'*|*$'\r'*) return 1 ;; esac
+    if ! px_workspace_path_has_authority "$created"; then
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    fi
+    if [ -L "$created" ] || [ ! -d "$created" ]; then
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    fi
+
+    px_stat_snapshot "$created" PX_WORKSPACE_NEW || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+    if ! px_mode_is_exact "$PX_WORKSPACE_NEW_MODE" 700; then
+        "$PX_CHMOD_PATH" 700 "$created" >/dev/null 2>&1 || {
+            px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+            return 1
+        }
+        px_stat_snapshot "$created" PX_WORKSPACE_NEW || {
+            px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+            return 1
+        }
+    fi
+
+    [ "$PX_WORKSPACE_NEW_UID" -eq "$EUID" ] || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+    px_mode_is_exact "$PX_WORKSPACE_NEW_MODE" 700 || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+    [ "$PX_WORKSPACE_NEW_DEVICE" = "$PX_WORKSPACE_PARENT_BEFORE_DEVICE" ] || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+    px_directory_is_empty "$created" || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+    px_validate_workspace_parent || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_AFTER || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+    px_same_identity PX_WORKSPACE_PARENT_BEFORE PX_WORKSPACE_PARENT_AFTER || {
+        px_discard_unactivated_workspace "$created" >/dev/null 2>&1 || true
+        return 1
+    }
+
+    PX_WORKSPACE_PATH="$created"
+    PX_WORKSPACE_DEVICE="$PX_WORKSPACE_NEW_DEVICE"
+    PX_WORKSPACE_INODE="$PX_WORKSPACE_NEW_INODE"
+    PX_WORKSPACE_UID="$PX_WORKSPACE_NEW_UID"
+    PX_WORKSPACE_GID="$PX_WORKSPACE_NEW_GID"
+    PX_WORKSPACE_MODE="$PX_WORKSPACE_NEW_MODE"
+    PX_WORKSPACE_LINKS="$PX_WORKSPACE_NEW_LINKS"
+    PX_WORKSPACE_PARENT_DEVICE="$PX_WORKSPACE_PARENT_AFTER_DEVICE"
+    PX_WORKSPACE_PARENT_INODE="$PX_WORKSPACE_PARENT_AFTER_INODE"
+    PX_WORKSPACE_ACTIVE=1
+    return 0
+}
+
+px_validate_workspace_identity() {
+    [ "$PX_WORKSPACE_ACTIVE" -eq 1 ] || return 1
+    px_workspace_path_has_authority "$PX_WORKSPACE_PATH" || return 1
+    [ -d "$PX_WORKSPACE_PATH" ] || return 1
+    [ ! -L "$PX_WORKSPACE_PATH" ] || return 1
+    px_validate_workspace_parent || return 1
+    px_stat_snapshot "$PX_WORKSPACE_PARENT" PX_WORKSPACE_PARENT_LIVE || return 1
+    [ "$PX_WORKSPACE_PARENT_LIVE_DEVICE" = "$PX_WORKSPACE_PARENT_DEVICE" ] || return 1
+    [ "$PX_WORKSPACE_PARENT_LIVE_INODE" = "$PX_WORKSPACE_PARENT_INODE" ] || return 1
+    px_stat_snapshot "$PX_WORKSPACE_PATH" PX_WORKSPACE_LIVE || return 1
+    [ "$PX_WORKSPACE_LIVE_DEVICE" = "$PX_WORKSPACE_DEVICE" ] || return 1
+    [ "$PX_WORKSPACE_LIVE_INODE" = "$PX_WORKSPACE_INODE" ] || return 1
+    [ "$PX_WORKSPACE_LIVE_UID" = "$PX_WORKSPACE_UID" ] || return 1
+    [ "$PX_WORKSPACE_LIVE_GID" = "$PX_WORKSPACE_GID" ] || return 1
+    [ "$PX_WORKSPACE_LIVE_LINKS" = "$PX_WORKSPACE_LINKS" ] || return 1
+    [ "$PX_WORKSPACE_LIVE_UID" -eq "$EUID" ] || return 1
+    px_mode_is_exact "$PX_WORKSPACE_LIVE_MODE" 700 || return 1
+    return 0
+}
+
+px_workspace_child_path() {
+    local name="$1"
+    case "$name" in
+        app_ent.xml|helper_ent.plist|backup_helper|restore_input.plist) ;;
+        *) return 1 ;;
+    esac
+    PX_WORKSPACE_CHILD_PATH="$PX_WORKSPACE_PATH/$name"
+    return 0
+}
+
+px_require_workspace_child_absent() {
+    local name="$1"
+    px_validate_workspace_identity || return 1
+    px_workspace_child_path "$name" || return 1
+    [ ! -e "$PX_WORKSPACE_CHILD_PATH" ] || return 1
+    [ ! -L "$PX_WORKSPACE_CHILD_PATH" ] || return 1
+    return 0
+}
+
+px_validate_workspace_file() {
+    local path="$1"
+    local expected_mode="$2"
+    local require_executable="$3"
+    local require_nonzero="$4"
+    px_validate_workspace_identity || return 1
+    [ "${path%/*}" = "$PX_WORKSPACE_PATH" ] || return 1
+    local name="${path##*/}"
+    px_workspace_child_path "$name" || return 1
+    [ "$path" = "$PX_WORKSPACE_CHILD_PATH" ] || return 1
+    [ -f "$path" ] || return 1
+    [ ! -L "$path" ] || return 1
+    if [ "$require_executable" -eq 1 ]; then
+        [ -x "$path" ] || return 1
+    fi
+    px_stat_snapshot "$path" PX_WORKSPACE_FILE || return 1
+    [ "$PX_WORKSPACE_FILE_DEVICE" = "$PX_WORKSPACE_DEVICE" ] || return 1
+    [ "$PX_WORKSPACE_FILE_UID" -eq "$EUID" ] || return 1
+    [ "$PX_WORKSPACE_FILE_LINKS" -eq 1 ] || return 1
+    px_mode_is_exact "$PX_WORKSPACE_FILE_MODE" "$expected_mode" || return 1
+    if [ "$require_nonzero" -eq 1 ]; then
+        [ "$PX_WORKSPACE_FILE_SIZE" -gt 0 ] || return 1
+    fi
+    px_validate_workspace_identity || return 1
+    return 0
+}
+
+px_cleanup_workspace() {
+    px_validate_workspace_identity || return 1
+    local name child failed=0
+    for name in restore_input.plist backup_helper helper_ent.plist app_ent.xml; do
+        px_workspace_child_path "$name" || return 1
+        child="$PX_WORKSPACE_CHILD_PATH"
+        if [ -L "$child" ]; then
+            "$PX_RM_PATH" -f "$child" >/dev/null 2>&1 || failed=1
+        elif [ -f "$child" ]; then
+            "$PX_RM_PATH" -f "$child" >/dev/null 2>&1 || failed=1
+        elif [ -e "$child" ]; then
+            failed=1
         fi
     done
-
-    return 1
+    [ "$failed" -eq 0 ] || return 1
+    px_validate_workspace_identity || return 1
+    px_directory_is_empty "$PX_WORKSPACE_PATH" || return 1
+    "$PX_RMDIR_PATH" "$PX_WORKSPACE_PATH" >/dev/null 2>&1 || return 1
+    PX_WORKSPACE_ACTIVE=0
+    PX_WORKSPACE_PATH=""
+    return 0
 }

-# === Find plutil binary ===
-find_plutil() {
-    local paths=(
-        "/usr/bin/plutil"
-        "/var/jb/usr/bin/plutil"
-        "/bin/plutil"
-    )
-
-    for path in "${paths[@]}"; do
-        if [ -x "$path" ]; then
-            echo "$path"
-            return 0
+px_exit_trap() {
+    local original_status=$?
+    trap - EXIT
+    if [ "$PX_WORKSPACE_ACTIVE" -eq 1 ]; then
+        if ! px_cleanup_workspace; then
+            log_error "Temporary workspace cleanup failed (original status: $original_status)"
+            exit "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
         fi
-    done
-
-    return 1
+    fi
+    exit "$original_status"
+}
+
+trap px_exit_trap EXIT
+
+# === Trusted ldid/plutil accessors ===
+find_ldid() {
+    [ "$PX_DEPENDENCIES_READY" -eq 1 ] || return 1
+    printf '%s\n' "$PX_LDID_PATH"
+}
+
+find_plutil() {
+    [ "$PX_DEPENDENCIES_READY" -eq 1 ] || return 1
+    printf '%s\n' "$PX_PLUTIL_PATH"
+}
+
+# === Path and target validation ===
+PX_TARGET_PATH=""
+PX_TARGET_APP_BUNDLE=""
+PX_TARGET_IS_SYSTEM=0
+PX_APP_ENT_PATH=""
+PX_HELPER_ENT_PATH=""
+PX_WORKING_HELPER_PATH=""
+PX_RESTORE_INPUT_PATH=""
+PX_BACKUP_OUTPUT_PATH=""
+PX_BACKUP_OUTPUT_PARENT=""
+PX_BACKUP_OUTPUT_EXISTED=0
+
+px_string_has_control_character() {
+    local value="$1"
+    printf '%s' "$value" | "$PX_GREP_PATH" -q '[[:cntrl:]]'
+}
+
+px_validate_bundle_id() {
+    local bundle_id="$1"
+    [ -n "$bundle_id" ] || return 1
+    [ "${#bundle_id}" -le 255 ] || return 1
+    px_string_has_control_character "$bundle_id" && return 1
+    case "$bundle_id" in
+        *'/'*|*'\\'*|*[!A-Za-z0-9._-]*|.|..|-*) return 1 ;;
+        [A-Za-z0-9]*) ;;
+        *) return 1 ;;
+    esac
+    return 0
+}
+
+px_validate_safe_basename() {
+    local basename="$1"
+    [ -n "$basename" ] || return 1
+    [ "${#basename}" -le 255 ] || return 1
+    px_string_has_control_character "$basename" && return 1
+    case "$basename" in
+        */*|*'\\'*|.|..|-*) return 1 ;;
+    esac
+    return 0
+}
+
+px_validate_absolute_path_lexical() {
+    local path="$1"
+    [ -n "$path" ] || return 1
+    [ "${#path}" -le 4096 ] || return 1
+    case "$path" in /*) ;; *) return 1 ;; esac
+    px_string_has_control_character "$path" && return 1
+    local basename="${path##*/}"
+    px_validate_safe_basename "$basename" || return 1
+    local parent="${path%/*}"
+    [ -n "$parent" ] || parent="/"
+    PX_PATH_PARENT="$parent"
+    PX_PATH_BASENAME="$basename"
+    return 0
+}
+
+px_canonicalize_existing_file() {
+    local path="$1"
+    px_validate_absolute_path_lexical "$path" || return 1
+    local raw_parent="$PX_PATH_PARENT"
+    local basename="$PX_PATH_BASENAME"
+    px_physical_directory "$raw_parent" || return 1
+    local physical_parent="$PX_PHYSICAL_DIRECTORY"
+    local canonical="${physical_parent%/}/$basename"
+    [ -f "$canonical" ] || return 1
+    [ ! -L "$canonical" ] || return 1
+    [ -r "$canonical" ] || return 1
+    px_stat_snapshot "$physical_parent" PX_CANONICAL_PARENT || return 1
+    px_stat_snapshot "$canonical" PX_CANONICAL_FILE || return 1
+    [ "$PX_CANONICAL_FILE_SIZE" -gt 0 ] || return 1
+    PX_CANONICAL_PATH="$canonical"
+    PX_CANONICAL_PARENT_PATH="$physical_parent"
+    return 0
+}
+
+px_canonicalize_output_path() {
+    local path="$1"
+    px_validate_absolute_path_lexical "$path" || return 1
+    local raw_parent="$PX_PATH_PARENT"
+    local basename="$PX_PATH_BASENAME"
+    px_physical_directory "$raw_parent" || return 1
+    local physical_parent="$PX_PHYSICAL_DIRECTORY"
+    [ -d "$physical_parent" ] || return 1
+    [ -w "$physical_parent" ] || return 1
+    px_stat_snapshot "$physical_parent" PX_OUTPUT_PARENT_INITIAL || return 1
+    local canonical="${physical_parent%/}/$basename"
+    [ ! -L "$canonical" ] || return 1
+    if [ -e "$canonical" ]; then
+        [ -f "$canonical" ] || return 1
+        [ -w "$canonical" ] || return 1
+        px_stat_snapshot "$canonical" PX_OUTPUT_FILE_INITIAL || return 1
+        PX_BACKUP_OUTPUT_EXISTED=1
+    else
+        PX_BACKUP_OUTPUT_EXISTED=0
+    fi
+    PX_CANONICAL_OUTPUT_PATH="$canonical"
+    PX_CANONICAL_OUTPUT_PARENT="$physical_parent"
+    return 0
+}
+
+px_owner_is_app_trusted() {
+    local uid="$1"
+    [ "$uid" -eq 0 ] || [ "$uid" -eq 501 ]
+}
+
+px_validate_app_directory() {
+    local directory="$1"
+    [ -d "$directory" ] || return 1
+    [ ! -L "$directory" ] || return 1
+    [ -x "$directory" ] || return 1
+    px_stat_snapshot "$directory" PX_APP_DIRECTORY || return 1
+    px_owner_is_app_trusted "$PX_APP_DIRECTORY_UID" || return 1
+    px_mode_is_safe_executable "$PX_APP_DIRECTORY_MODE" || return 1
+    return 0
+}
+
+px_validate_info_plist() {
+    local plist="$1"
+    [ -f "$plist" ] || return 1
+    [ ! -L "$plist" ] || return 1
+    [ -r "$plist" ] || return 1
+    px_stat_snapshot "$plist" PX_INFO_PLIST || return 1
+    px_owner_is_app_trusted "$PX_INFO_PLIST_UID" || return 1
+    px_mode_is_safe_executable "$PX_INFO_PLIST_MODE" || return 1
+    [ "$PX_INFO_PLIST_LINKS" -eq 1 ] || return 1
+    [ "$PX_INFO_PLIST_SIZE" -gt 0 ] || return 1
+    [ "$PX_INFO_PLIST_SIZE" -le 16777216 ] || return 1
+    return 0
+}
+
+px_read_info_value() {
+    local plist="$1"
+    local key="$2"
+    px_validate_info_plist "$plist" || return 1
+    px_stat_snapshot "$plist" PX_INFO_BEFORE || return 1
+    local value
+    value=$("$PX_PLUTIL_PATH" -key "$key" "$plist" 2>/dev/null)
+    local status=$?
+    px_stat_snapshot "$plist" PX_INFO_AFTER || return 1
+    px_same_complete_snapshot PX_INFO_BEFORE PX_INFO_AFTER || return 1
+    [ "$status" -eq 0 ] || return 1
+    [ -n "$value" ] || return 1
+    [ "${#value}" -le 4096 ] || return 1
+    px_string_has_control_character "$value" && return 1
+    PX_PLIST_VALUE="$value"
+    return 0
+}
+
+px_validate_target_executable() {
+    local target="$1"
+    [ -f "$target" ] || return 1
+    [ ! -L "$target" ] || return 1
+    [ -x "$target" ] || return 1
+    px_stat_snapshot "$target" PX_TARGET_CANDIDATE || return 1
+    px_owner_is_app_trusted "$PX_TARGET_CANDIDATE_UID" || return 1
+    px_mode_is_safe_executable "$PX_TARGET_CANDIDATE_MODE" || return 1
+    [ "$PX_TARGET_CANDIDATE_LINKS" -eq 1 ] || return 1
+    [ "$PX_TARGET_CANDIDATE_SIZE" -gt 0 ] || return 1
+    return 0
+}
+
+px_consider_app_bundle() {
+    local app_dir="$1"
+    local bundle_id="$2"
+    local is_system="$3"
+    px_validate_app_directory "$app_dir" || return 1
+    local info_plist="$app_dir/Info.plist"
+    px_validate_info_plist "$info_plist" || return 1
+    px_read_info_value "$info_plist" CFBundleIdentifier || return 1
+    local found_bundle_id="$PX_PLIST_VALUE"
+    [ "$found_bundle_id" = "$bundle_id" ] || return 1
+    px_read_info_value "$info_plist" CFBundleExecutable || return 1
+    local executable_name="$PX_PLIST_VALUE"
+    px_validate_safe_basename "$executable_name" || return 1
+    local target="$app_dir/$executable_name"
+    px_validate_target_executable "$target" || return 1
+
+    PX_TARGET_PATH="$target"
+    PX_TARGET_APP_BUNDLE="$app_dir"
+    PX_TARGET_IS_SYSTEM="$is_system"
+    PX_TARGET_DEVICE="$PX_TARGET_CANDIDATE_DEVICE"
+    PX_TARGET_INODE="$PX_TARGET_CANDIDATE_INODE"
+    PX_TARGET_UID="$PX_TARGET_CANDIDATE_UID"
+    PX_TARGET_GID="$PX_TARGET_CANDIDATE_GID"
+    PX_TARGET_MODE="$PX_TARGET_CANDIDATE_MODE"
+    PX_TARGET_SIZE="$PX_TARGET_CANDIDATE_SIZE"
+    PX_TARGET_LINKS="$PX_TARGET_CANDIDATE_LINKS"
+    PX_TARGET_MTIME="$PX_TARGET_CANDIDATE_MTIME"
+    PX_TARGET_CTIME="$PX_TARGET_CANDIDATE_CTIME"
+    return 0
 }

-# === Find app executable path from bundle ID ===
 find_app_executable() {
     local bundle_id="$1"
-
-    log_verbose "Searching for app with bundle ID: $bundle_id"
-
-    # === 1. Check system apps in /Applications ===
-    local system_app_paths=(
+    px_validate_bundle_id "$bundle_id" || return 1
+    PX_TARGET_PATH=""
+    local raw_root root app_dir uuid_dir
+    local system_roots=(
         "/Applications"
         "/var/jb/Applications"
         "/private/preboot/jb/Applications"
     )
-
-    for base_path in "${system_app_paths[@]}"; do
-        if [ ! -d "$base_path" ]; then
-            continue
-        fi
-
-        for app_dir in "$base_path"/*.app; do
-            if [ ! -d "$app_dir" ]; then
-                continue
-            fi
-
-            local info_plist="$app_dir/Info.plist"
-            if [ ! -f "$info_plist" ]; then
-                continue
-            fi
-
-            # Extract CFBundleIdentifier
-            local found_bundle_id
-            found_bundle_id=$(plutil -key CFBundleIdentifier "$info_plist" 2>/dev/null || true)
-
-            if [ "$found_bundle_id" = "$bundle_id" ]; then
-                # Found matching app, get executable name
-                local exe_name
-                exe_name=$(plutil -key CFBundleExecutable "$info_plist" 2>/dev/null || true)
-
-                if [ -n "$exe_name" ] && [ -f "$app_dir/$exe_name" ]; then
-                    log_verbose "Found system app: $app_dir/$exe_name"
-                    echo "$app_dir/$exe_name"
-                    return 0
-                fi
-            fi
+    for raw_root in "${system_roots[@]}"; do
+        [ -e "$raw_root" ] || continue
+        px_physical_directory "$raw_root" || continue
+        root="$PX_PHYSICAL_DIRECTORY"
+        px_validate_app_directory "$root" || continue
+        for app_dir in "$root"/*.app; do
+            [ -d "$app_dir" ] || continue
+            [ ! -L "$app_dir" ] || continue
+            px_consider_app_bundle "$app_dir" "$bundle_id" 1 && return 0
         done
     done
-
-    # === 2. Check App Store apps in /var/containers/Bundle/Application ===
-    local bundle_paths=(
+
+    local bundle_roots=(
         "/var/containers/Bundle/Application"
         "/var/mobile/Containers/Bundle/Application"
         "/private/var/containers/Bundle/Application"
     )
-
-    for base_path in "${bundle_paths[@]}"; do
-        if [ ! -d "$base_path" ]; then
-            continue
-        fi
-
-        # Search through all app UUIDs
-        for uuid_dir in "$base_path"/*; do
-            if [ ! -d "$uuid_dir" ]; then
-                continue
-            fi
-
-            # Find .app directory
+    for raw_root in "${bundle_roots[@]}"; do
+        [ -e "$raw_root" ] || continue
+        px_physical_directory "$raw_root" || continue
+        root="$PX_PHYSICAL_DIRECTORY"
+        px_validate_app_directory "$root" || continue
+        for uuid_dir in "$root"/*; do
+            [ -d "$uuid_dir" ] || continue
+            [ ! -L "$uuid_dir" ] || continue
+            px_validate_app_directory "$uuid_dir" || continue
             for app_dir in "$uuid_dir"/*.app; do
-                if [ ! -d "$app_dir" ]; then
-                    continue
-                fi
-
-                # Check Info.plist for bundle ID
-                local info_plist="$app_dir/Info.plist"
-                if [ ! -f "$info_plist" ]; then
-                    continue
-                fi
-
-                # Extract CFBundleIdentifier
-                local found_bundle_id
-                found_bundle_id=$(plutil -key CFBundleIdentifier "$info_plist" 2>/dev/null || true)
-
-                if [ "$found_bundle_id" = "$bundle_id" ]; then
-                    # Found matching app, get executable name
-                    local exe_name
-                    exe_name=$(plutil -key CFBundleExecutable "$info_plist" 2>/dev/null || true)
-
-                    if [ -n "$exe_name" ] && [ -f "$app_dir/$exe_name" ]; then
-                        log_verbose "Found App Store app: $app_dir/$exe_name"
-                        echo "$app_dir/$exe_name"
-                        return 0
-                    fi
-                fi
+                [ -d "$app_dir" ] || continue
+                [ ! -L "$app_dir" ] || continue
+                px_consider_app_bundle "$app_dir" "$bundle_id" 0 && return 0
             done
         done
     done
-
     return 1
 }

+px_validate_target_unchanged() {
+    [ -n "$PX_TARGET_PATH" ] || return 1
+    px_validate_target_executable "$PX_TARGET_PATH" || return 1
+    [ "$PX_TARGET_CANDIDATE_DEVICE" = "$PX_TARGET_DEVICE" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_INODE" = "$PX_TARGET_INODE" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_UID" = "$PX_TARGET_UID" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_GID" = "$PX_TARGET_GID" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_MODE" = "$PX_TARGET_MODE" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_SIZE" = "$PX_TARGET_SIZE" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_LINKS" = "$PX_TARGET_LINKS" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_MTIME" = "$PX_TARGET_MTIME" ] || return 1
+    [ "$PX_TARGET_CANDIDATE_CTIME" = "$PX_TARGET_CTIME" ] || return 1
+    return 0
+}
+
 # === Extract entitlements from app ===
 extract_entitlements() {
     local app_binary="$1"
     local output_file="$2"
-    local ldid_path
-
-    ldid_path=$(find_ldid) || {
-        log_error "ldid not found. Please install ldid."
-        return "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
-    }
-
-    log_verbose "Using ldid: $ldid_path"
-    log_verbose "Extracting entitlements from: $app_binary"
-
-    "$ldid_path" -e "$app_binary" > "$output_file" 2>/dev/null
-
-    if [ ! -s "$output_file" ]; then
-        log_error "Failed to extract entitlements or app has no entitlements"
-        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
-    fi
-
+    [ "$app_binary" = "$PX_TARGET_PATH" ] || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_workspace_child_path app_ent.xml || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ "$output_file" = "$PX_WORKSPACE_CHILD_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ ! -e "$output_file" ] && [ ! -L "$output_file" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_target_unchanged || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
+    px_stat_snapshot "$app_binary" PX_TARGET_EXTRACT_BEFORE || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
+
+    "$PX_LDID_PATH" -e "$app_binary" > "$output_file" 2>/dev/null
+    local extract_status=$?
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$app_binary" PX_TARGET_EXTRACT_AFTER || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
+    px_same_complete_snapshot PX_TARGET_EXTRACT_BEFORE PX_TARGET_EXTRACT_AFTER || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
+    [ "$extract_status" -eq 0 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    "$PX_CHMOD_PATH" 600 "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$output_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    PX_APP_ENT_PATH="$output_file"
     return "$PX_KEYCHAIN_EXIT_COMPLETED"
 }

 # === Parse keychain access groups from entitlements ===
 parse_keychain_groups() {
     local ent_file="$1"
-    local plutil_path
-
-    plutil_path=$(find_plutil) || {
-        log_error "plutil not found"
-        return 1
-    }
-
-    # Try to extract keychain-access-groups array
-    # plutil -extract keychain-access-groups xml1 -o - "$ent_file"
-
-    # Use grep/sed as fallback for extracting groups
+    px_validate_workspace_file "$ent_file" 600 0 1 || return 1
+    px_stat_snapshot "$ent_file" PX_PARSE_GROUPS_BEFORE || return 1
     local groups=""
     local in_groups=0
-
+    local line group
     while IFS= read -r line; do
-        if echo "$line" | grep -q "keychain-access-groups"; then
+        if printf '%s' "$line" | "$PX_GREP_PATH" -q "keychain-access-groups"; then
             in_groups=1
             continue
         fi
-
         if [ "$in_groups" -eq 1 ]; then
-            if echo "$line" | grep -q "</array>"; then
+            if printf '%s' "$line" | "$PX_GREP_PATH" -q "</array>"; then
                 in_groups=0
                 continue
             fi
-
-            if echo "$line" | grep -q "<string>"; then
-                local group
-                group=$(echo "$line" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
+            if printf '%s' "$line" | "$PX_GREP_PATH" -q "<string>"; then
+                group=$(printf '%s' "$line" | "$PX_SED_PATH" -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
                 if [ -n "$group" ]; then
-                    if [ -n "$groups" ]; then
-                        groups="$groups,$group"
-                    else
-                        groups="$group"
-                    fi
+                    if [ -n "$groups" ]; then groups="$groups,$group"; else groups="$group"; fi
                 fi
             fi
         fi
     done < "$ent_file"
-
-    echo "$groups"
+    px_stat_snapshot "$ent_file" PX_PARSE_GROUPS_AFTER || return 1
+    px_same_complete_snapshot PX_PARSE_GROUPS_BEFORE PX_PARSE_GROUPS_AFTER || return 1
+    [ "${#groups}" -le 65536 ] || return 1
+    px_string_has_control_character "$groups" && return 1
+    printf '%s\n' "$groups"
 }

 # === Parse application-identifier from entitlements ===
 parse_app_identifier() {
     local ent_file="$1"
+    px_validate_workspace_file "$ent_file" 600 0 1 || return 1
+    px_stat_snapshot "$ent_file" PX_PARSE_IDENTIFIER_BEFORE || return 1
     local identifier=""
-
-    # Look for application-identifier key and extract the string value
     local found_key=0
+    local line
     while IFS= read -r line; do
-        if echo "$line" | grep -q "application-identifier"; then
+        if printf '%s' "$line" | "$PX_GREP_PATH" -q "application-identifier"; then
             found_key=1
             continue
         fi
-
-        if [ "$found_key" -eq 1 ]; then
-            if echo "$line" | grep -q "<string>"; then
-                identifier=$(echo "$line" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
-                break
-            fi
+        if [ "$found_key" -eq 1 ] && printf '%s' "$line" | "$PX_GREP_PATH" -q "<string>"; then
+            identifier=$(printf '%s' "$line" | "$PX_SED_PATH" -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
+            break
         fi
     done < "$ent_file"
-
-    echo "$identifier"
+    px_stat_snapshot "$ent_file" PX_PARSE_IDENTIFIER_AFTER || return 1
+    px_same_complete_snapshot PX_PARSE_IDENTIFIER_BEFORE PX_PARSE_IDENTIFIER_AFTER || return 1
+    [ "${#identifier}" -le 4096 ] || return 1
+    px_string_has_control_character "$identifier" && return 1
+    printf '%s\n' "$identifier"
 }

 # === Ensure a group exists in a CSV list ===
@@ -336,7 +959,7 @@ ensure_group_in_csv() {
         return 0
     fi
     # Normalize: remove any surrounding whitespace
-    group="$(echo "$group" | sed 's/^ *//;s/ *$//')"
+    group="$(echo "$group" | "$PX_SED_PATH" 's/^ *//;s/ *$//')"
     if [ -z "$group" ]; then
         echo "$csv"
         return 0
@@ -352,423 +975,416 @@ ensure_group_in_csv() {
 }

 # === Generate entitlements plist for helper tool ===
-# For system apps, we copy the full entitlements and add our extras
-# For App Store apps, we generate minimal entitlements
+# For system apps, copy the accepted entitlement snapshot and retain existing policy.
 generate_helper_entitlements() {
     local keychain_groups="$1"
     local app_groups="$2"
     local output_file="$3"
     local app_identifier="$4"
-    local source_ent_file="$5"  # Optional: full entitlements file from target app
-
-    log_verbose "Generating entitlements to: $output_file"
-    log_verbose "Keychain groups: $keychain_groups"
-    log_verbose "App identifier: $app_identifier"
-    log_verbose "Source entitlements: $source_ent_file"
-
-    # Check if this is a system app (use full entitlements)
-    if [ -n "$source_ent_file" ] && [ -f "$source_ent_file" ]; then
-        log_verbose "Using full entitlements from target app (system app mode)"
-
-        # Copy source entitlements and inject our security overrides
-        # We'll modify the plist to add no-sandbox and no-container
-        cp "$source_ent_file" "$output_file"
-
-        # Add our security entitlements using plutil if available
-        local plutil_path
-        plutil_path=$(find_plutil) || true
-
-        if [ -n "$plutil_path" ]; then
-            # Add security entitlements
-            "$plutil_path" -replace "com.apple.private.security.no-sandbox" -bool true "$output_file" 2>/dev/null || true
-            "$plutil_path" -replace "com.apple.private.security.no-container" -bool true "$output_file" 2>/dev/null || true
-            "$plutil_path" -replace "com.apple.private.security.container-required" -bool false "$output_file" 2>/dev/null || true
-
-            log_verbose "Injected security entitlements via plutil"
-        else
-            log_warn "plutil not available, using source entitlements as-is"
-        fi
+    local source_ent_file="$5"
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_require_workspace_child_absent helper_ent.plist || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ "$output_file" = "$PX_WORKSPACE_CHILD_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ "${#keychain_groups}" -le 65536 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    [ "${#app_groups}" -le 65536 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    [ "${#app_identifier}" -le 4096 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    px_string_has_control_character "$keychain_groups" && return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    px_string_has_control_character "$app_groups" && return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    px_string_has_control_character "$app_identifier" && return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+
+    if [ -n "$source_ent_file" ]; then
+        [ "$source_ent_file" = "$PX_APP_ENT_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        px_validate_workspace_file "$source_ent_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        px_stat_snapshot "$source_ent_file" PX_SOURCE_ENT_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        "$PX_CP_PATH" "$source_ent_file" "$output_file" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        px_stat_snapshot "$source_ent_file" PX_SOURCE_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        px_same_complete_snapshot PX_SOURCE_ENT_BEFORE PX_SOURCE_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        "$PX_CMP_PATH" "$source_ent_file" "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        "$PX_CHMOD_PATH" 600 "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+        px_validate_workspace_file "$output_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
+        "$PX_PLUTIL_PATH" -replace "com.apple.private.security.no-sandbox" -bool true "$output_file" 2>/dev/null || true
+        "$PX_PLUTIL_PATH" -replace "com.apple.private.security.no-container" -bool true "$output_file" 2>/dev/null || true
+        "$PX_PLUTIL_PATH" -replace "com.apple.private.security.container-required" -bool false "$output_file" 2>/dev/null || true
     else
-        log_verbose "Generating custom entitlements (App Store app mode)"
-
-        # Use printf to avoid heredoc CRLF issues
         {
             printf '<?xml version="1.0" encoding="UTF-8"?>\n'
             printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
             printf '<plist version="1.0">\n'
             printf '<dict>\n'
-
-            # Platform application - required for system-level access
             printf '    <key>platform-application</key>\n'
             printf '    <true/>\n'
-
-            # Application identifier - critical for keychain access matching
             if [ -n "$app_identifier" ]; then
                 printf '    <key>application-identifier</key>\n'
                 printf '    <string>%s</string>\n' "$app_identifier"
             fi
-
-            # Security entitlements
             printf '    <key>com.apple.private.security.no-sandbox</key>\n'
             printf '    <true/>\n'
             printf '    <key>com.apple.private.security.no-container</key>\n'
             printf '    <true/>\n'
             printf '    <key>com.apple.private.security.container-required</key>\n'
             printf '    <false/>\n'
-
-            # Keychain specific entitlements
             printf '    <key>com.apple.keystore.access-keychain-keys</key>\n'
             printf '    <true/>\n'
             printf '    <key>com.apple.keystore.device</key>\n'
             printf '    <true/>\n'
-
-            # Add keychain-access-groups
             if [ -n "$keychain_groups" ]; then
                 printf '    <key>keychain-access-groups</key>\n'
                 printf '    <array>\n'
-
                 IFS=',' read -ra GROUPS <<< "$keychain_groups"
+                local group
                 for group in "${GROUPS[@]}"; do
                     printf '        <string>%s</string>\n' "$group"
                 done
-
                 printf '    </array>\n'
             fi
-
-            # Add application-groups if present
             if [ -n "$app_groups" ]; then
                 printf '    <key>com.apple.security.application-groups</key>\n'
                 printf '    <array>\n'
-
                 IFS=',' read -ra GROUPS <<< "$app_groups"
+                local group
                 for group in "${GROUPS[@]}"; do
                     printf '        <string>%s</string>\n' "$group"
                 done
-
                 printf '    </array>\n'
             fi
-
             printf '</dict>\n'
             printf '</plist>\n'
-        } > "$output_file"
+        } > "$output_file" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi
-
-    # Verify file was created
-    if [ ! -f "$output_file" ]; then
-        log_error "Failed to create entitlements file: $output_file"
-        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
-    fi
-
-    log_verbose "Entitlements file created successfully"
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ -f "$output_file" ] && [ ! -L "$output_file" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    "$PX_CHMOD_PATH" 600 "$output_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$output_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    PX_HELPER_ENT_PATH="$output_file"
     return "$PX_KEYCHAIN_EXIT_COMPLETED"
 }

-# === Parse application groups from entitlements ===
+# === Parse application groups from the accepted entitlement snapshot ===
 parse_app_groups() {
     local ent_file="$1"
+    px_validate_workspace_file "$ent_file" 600 0 1 || return 1
+    px_stat_snapshot "$ent_file" PX_PARSE_APP_GROUPS_BEFORE || return 1
     local groups=""
     local in_groups=0
-
+    local line group
     while IFS= read -r line; do
-        if echo "$line" | grep -q "com.apple.security.application-groups"; then
+        if printf '%s' "$line" | "$PX_GREP_PATH" -q "com.apple.security.application-groups"; then
             in_groups=1
             continue
         fi
-
         if [ "$in_groups" -eq 1 ]; then
-            if echo "$line" | grep -q "</array>"; then
+            if printf '%s' "$line" | "$PX_GREP_PATH" -q "</array>"; then
                 in_groups=0
                 continue
             fi
-
-            if echo "$line" | grep -q "<string>"; then
-                local group
-                group=$(echo "$line" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
+            if printf '%s' "$line" | "$PX_GREP_PATH" -q "<string>"; then
+                group=$(printf '%s' "$line" | "$PX_SED_PATH" -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
                 if [ -n "$group" ]; then
-                    if [ -n "$groups" ]; then
-                        groups="$groups,$group"
-                    else
-                        groups="$group"
-                    fi
+                    if [ -n "$groups" ]; then groups="$groups,$group"; else groups="$group"; fi
                 fi
             fi
         fi
     done < "$ent_file"
-
-    echo "$groups"
+    px_stat_snapshot "$ent_file" PX_PARSE_APP_GROUPS_AFTER || return 1
+    px_same_complete_snapshot PX_PARSE_APP_GROUPS_BEFORE PX_PARSE_APP_GROUPS_AFTER || return 1
+    [ "${#groups}" -le 65536 ] || return 1
+    px_string_has_control_character "$groups" && return 1
+    printf '%s\n' "$groups"
+}
+
+px_prepare_working_helper() {
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_require_workspace_child_absent backup_helper || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    local destination="$PX_WORKSPACE_CHILD_PATH"
+    px_stat_snapshot "$PX_INSTALLED_HELPER_PATH" PX_HELPER_SOURCE_BEFORE || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
+    px_same_complete_snapshot PX_INSTALLED_HELPER PX_HELPER_SOURCE_BEFORE || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
+    "$PX_CP_PATH" "$PX_INSTALLED_HELPER_PATH" "$destination" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$PX_INSTALLED_HELPER_PATH" PX_HELPER_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
+    px_same_complete_snapshot PX_HELPER_SOURCE_BEFORE PX_HELPER_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
+    "$PX_CMP_PATH" "$PX_INSTALLED_HELPER_PATH" "$destination" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    "$PX_CHMOD_PATH" 700 "$destination" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$destination" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    PX_WORKING_HELPER_PATH="$destination"
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
 }

-# === Resign helper tool with new entitlements ===
-# Usage: resign_helper <entitlements_file> <target_binary>
+# === Resign the private working helper only ===
 resign_helper() {
     local ent_file="$1"
     local binary_path="$2"
-    local ldid_path
-
-    ldid_path=$(find_ldid) || {
-        log_error "ldid not found"
-        return "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
-    }
-
-    # Check if binary exists
-    if [ ! -f "$binary_path" ]; then
-        log_error "Binary not found at: $binary_path"
-        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ "$ent_file" = "$PX_HELPER_ENT_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ "$binary_path" = "$PX_WORKING_HELPER_PATH" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$ent_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$binary_path" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$ent_file" PX_SIGN_ENT_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$binary_path" PX_SIGN_HELPER_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
+    "$PX_LDID_PATH" -S"$ent_file" "$binary_path" >/dev/null 2>&1
+    local sign_status=$?
+    [ "$sign_status" -eq 0 ] || return "$PX_KEYCHAIN_EXIT_SIGNING_FAILURE"
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$ent_file" PX_SIGN_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_same_complete_snapshot PX_SIGN_ENT_BEFORE PX_SIGN_ENT_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ -f "$binary_path" ] && [ ! -L "$binary_path" ] || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    "$PX_CHMOD_PATH" 700 "$binary_path" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$binary_path" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
+}
+
+px_prepare_restore_snapshot() {
+    local source_path="$1"
+    px_canonicalize_existing_file "$source_path" || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    local canonical_source="$PX_CANONICAL_PATH"
+    local canonical_parent="$PX_CANONICAL_PARENT_PATH"
+    px_stat_snapshot "$canonical_source" PX_RESTORE_SOURCE_BEFORE || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    px_stat_snapshot "$canonical_parent" PX_RESTORE_PARENT_BEFORE || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    px_require_workspace_child_absent restore_input.plist || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    local snapshot="$PX_WORKSPACE_CHILD_PATH"
+    "$PX_CP_PATH" "$canonical_source" "$snapshot" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$canonical_source" PX_RESTORE_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    px_stat_snapshot "$canonical_parent" PX_RESTORE_PARENT_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    px_same_complete_snapshot PX_RESTORE_SOURCE_BEFORE PX_RESTORE_SOURCE_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    px_same_identity PX_RESTORE_PARENT_BEFORE PX_RESTORE_PARENT_AFTER || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    "$PX_CMP_PATH" "$canonical_source" "$snapshot" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    "$PX_CHMOD_PATH" 600 "$snapshot" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$snapshot" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    PX_RESTORE_INPUT_PATH="$snapshot"
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
+}
+
+px_prepare_backup_output() {
+    local output_path="$1"
+    px_canonicalize_output_path "$output_path" || return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
+    PX_BACKUP_OUTPUT_PATH="$PX_CANONICAL_OUTPUT_PATH"
+    PX_BACKUP_OUTPUT_PARENT="$PX_CANONICAL_OUTPUT_PARENT"
+    PX_BACKUP_PARENT_DEVICE="$PX_OUTPUT_PARENT_INITIAL_DEVICE"
+    PX_BACKUP_PARENT_INODE="$PX_OUTPUT_PARENT_INITIAL_INODE"
+    PX_BACKUP_PARENT_UID="$PX_OUTPUT_PARENT_INITIAL_UID"
+    PX_BACKUP_PARENT_GID="$PX_OUTPUT_PARENT_INITIAL_GID"
+    PX_BACKUP_PARENT_MODE="$PX_OUTPUT_PARENT_INITIAL_MODE"
+    PX_BACKUP_PARENT_LINKS="$PX_OUTPUT_PARENT_INITIAL_LINKS"
+    if [ "$PX_BACKUP_OUTPUT_EXISTED" -eq 1 ]; then
+        PX_BACKUP_FILE_DEVICE="$PX_OUTPUT_FILE_INITIAL_DEVICE"
+        PX_BACKUP_FILE_INODE="$PX_OUTPUT_FILE_INITIAL_INODE"
+        PX_BACKUP_FILE_UID="$PX_OUTPUT_FILE_INITIAL_UID"
+        PX_BACKUP_FILE_GID="$PX_OUTPUT_FILE_INITIAL_GID"
+        PX_BACKUP_FILE_MODE="$PX_OUTPUT_FILE_INITIAL_MODE"
+        PX_BACKUP_FILE_SIZE="$PX_OUTPUT_FILE_INITIAL_SIZE"
+        PX_BACKUP_FILE_LINKS="$PX_OUTPUT_FILE_INITIAL_LINKS"
+        PX_BACKUP_FILE_MTIME="$PX_OUTPUT_FILE_INITIAL_MTIME"
+        PX_BACKUP_FILE_CTIME="$PX_OUTPUT_FILE_INITIAL_CTIME"
     fi
-
-    # Check if entitlements file exists
-    if [ ! -f "$ent_file" ]; then
-        log_error "Entitlements file not found: $ent_file"
-        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
+}
+
+px_backup_parent_is_unchanged() {
+    [ -d "$PX_BACKUP_OUTPUT_PARENT" ] || return 1
+    [ -w "$PX_BACKUP_OUTPUT_PARENT" ] || return 1
+    px_stat_snapshot "$PX_BACKUP_OUTPUT_PARENT" PX_BACKUP_PARENT_LIVE || return 1
+    [ "$PX_BACKUP_PARENT_LIVE_DEVICE" = "$PX_BACKUP_PARENT_DEVICE" ] || return 1
+    [ "$PX_BACKUP_PARENT_LIVE_INODE" = "$PX_BACKUP_PARENT_INODE" ] || return 1
+    [ "$PX_BACKUP_PARENT_LIVE_UID" = "$PX_BACKUP_PARENT_UID" ] || return 1
+    [ "$PX_BACKUP_PARENT_LIVE_GID" = "$PX_BACKUP_PARENT_GID" ] || return 1
+    [ "$PX_BACKUP_PARENT_LIVE_MODE" = "$PX_BACKUP_PARENT_MODE" ] || return 1
+    [ "$PX_BACKUP_PARENT_LIVE_LINKS" = "$PX_BACKUP_PARENT_LINKS" ] || return 1
+    return 0
+}
+
+px_revalidate_backup_output_before_execution() {
+    px_backup_parent_is_unchanged || return 1
+    [ ! -L "$PX_BACKUP_OUTPUT_PATH" ] || return 1
+    if [ "$PX_BACKUP_OUTPUT_EXISTED" -eq 1 ]; then
+        [ -f "$PX_BACKUP_OUTPUT_PATH" ] || return 1
+        px_stat_snapshot "$PX_BACKUP_OUTPUT_PATH" PX_BACKUP_FILE_LIVE || return 1
+        [ "$PX_BACKUP_FILE_LIVE_DEVICE" = "$PX_BACKUP_FILE_DEVICE" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_INODE" = "$PX_BACKUP_FILE_INODE" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_UID" = "$PX_BACKUP_FILE_UID" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_GID" = "$PX_BACKUP_FILE_GID" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_MODE" = "$PX_BACKUP_FILE_MODE" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_SIZE" = "$PX_BACKUP_FILE_SIZE" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_LINKS" = "$PX_BACKUP_FILE_LINKS" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_MTIME" = "$PX_BACKUP_FILE_MTIME" ] || return 1
+        [ "$PX_BACKUP_FILE_LIVE_CTIME" = "$PX_BACKUP_FILE_CTIME" ] || return 1
+    else
+        [ ! -e "$PX_BACKUP_OUTPUT_PATH" ] || return 1
     fi
-
-    log_verbose "Resigning binary: $binary_path"
-    log_verbose "With entitlements: $ent_file"
-
-    # Run ldid and capture any errors
-    local ldid_output
-    ldid_output=$("$ldid_path" -S"$ent_file" "$binary_path" 2>&1)
-    local exit_code=$?
-
-    if [ $exit_code -ne 0 ]; then
-        log_error "ldid failed with exit code $exit_code"
-        if [ -n "$ldid_output" ]; then
-            log_error "ldid output: $ldid_output"
+    return 0
+}
+
+px_validate_backup_output_after_execution() {
+    local raw_status="$1"
+    px_backup_parent_is_unchanged || return 1
+    [ ! -L "$PX_BACKUP_OUTPUT_PATH" ] || return 1
+    if [ -e "$PX_BACKUP_OUTPUT_PATH" ]; then
+        [ -f "$PX_BACKUP_OUTPUT_PATH" ] || return 1
+        px_stat_snapshot "$PX_BACKUP_OUTPUT_PATH" PX_BACKUP_OUTPUT_AFTER || return 1
+        if [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ] ||
+           [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_PARTIAL" ]; then
+            [ "$PX_BACKUP_OUTPUT_AFTER_SIZE" -gt 0 ] || return 1
         fi
-        return "$PX_KEYCHAIN_EXIT_SIGNING_FAILURE"
-    fi
-
-    # Verify signing worked
-    if [ ! -x "$binary_path" ]; then
-        chmod +x "$binary_path"
+    elif [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ] ||
+         [ "$raw_status" -eq "$PX_KEYCHAIN_EXIT_PARTIAL" ]; then
+        return 1
     fi
-
-    log_verbose "Binary resigned successfully"
-    return "$PX_KEYCHAIN_EXIT_COMPLETED"
+    return 0
+}
+
+px_validate_helper_execution() {
+    px_validate_workspace_identity || return 1
+    px_validate_workspace_file "$PX_HELPER_ENT_PATH" 600 0 1 || return 1
+    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return 1
+    return 0
 }

 # === Main functions ===
+px_prepare_target_context() {
+    local bundle_id="$1"
+    find_app_executable "$bundle_id" || return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
+    local ent_file="$PX_WORKSPACE_PATH/app_ent.xml"
+    extract_entitlements "$PX_TARGET_PATH" "$ent_file"
+    return $?
+}
+
+px_select_source_entitlement() {
+    local app_identifier="$1"
+    PX_SOURCE_ENT_FOR_SYSTEM=""
+    if [ "$PX_TARGET_IS_SYSTEM" -eq 1 ]; then
+        PX_SOURCE_ENT_FOR_SYSTEM="$PX_APP_ENT_PATH"
+    else
+        case "$app_identifier" in
+            com.apple.*) PX_SOURCE_ENT_FOR_SYSTEM="$PX_APP_ENT_PATH" ;;
+        esac
+    fi
+}
+
+px_finish_signed_helper() {
+    local keychain_groups="$1"
+    local app_groups="$2"
+    local app_identifier="$3"
+    local source_ent_file="$4"
+    local helper_ent="$PX_WORKSPACE_PATH/helper_ent.plist"
+    generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_file"
+    local status=$?
+    [ "$status" -eq 0 ] || return "$status"
+    px_prepare_working_helper
+    status=$?
+    [ "$status" -eq 0 ] || return "$status"
+    resign_helper "$PX_HELPER_ENT_PATH" "$PX_WORKING_HELPER_PATH"
+    return $?
+}

 do_backup() {
     local bundle_id="$1"
     local backup_file="$2"
     local override_groups="$3"
-
-    log_info "Starting keychain backup for: $bundle_id"
-
-    # Find app executable
-    log_info "Locating app executable..."
-    local app_binary
-    app_binary=$(find_app_executable "$bundle_id") || {
-        log_error "Could not find app with bundle ID: $bundle_id"
-        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
-    }
-    log_verbose "Found app: $app_binary"
-
-    # Create temp directory
-    mkdir -p "$TEMP_DIR"
-
-    # Extract entitlements
-    log_info "Extracting entitlements..."
-    local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file"
-    local entitlement_status=$?
-    if [ "$entitlement_status" -ne 0 ]; then
-        return "$entitlement_status"
-    fi
-
-    # Parse keychain groups
-    log_info "Parsing keychain access groups..."
-    local keychain_groups
-    keychain_groups=$(parse_keychain_groups "$ent_file")

-    # If caller provided a subset, use it.
+    log_info "Starting keychain backup"
+    px_prepare_backup_output "$backup_file"
+    local path_status=$?
+    [ "$path_status" -eq 0 ] || return "$path_status"
+    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
+    log_info "Locating target application..."
+    px_prepare_target_context "$bundle_id"
+    local context_status=$?
+    [ "$context_status" -eq 0 ] || return "$context_status"
+
+    local keychain_groups
+    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     if [ -n "$override_groups" ]; then
-        log_info "Using override keychain groups: $override_groups"
+        log_info "Using caller-selected keychain groups"
         keychain_groups="$override_groups"
     fi
-
     if [ -z "$keychain_groups" ]; then
         log_error "No keychain-access-groups found in app entitlements"
         return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi
-    log_info "Found keychain groups: $keychain_groups"
-
-    # Parse app groups (optional)
-    local app_groups
-    app_groups=$(parse_app_groups "$ent_file")
-
-    # Parse application-identifier (critical for keychain access)
-    local app_identifier
-    app_identifier=$(parse_app_identifier "$ent_file")
-    if [ -n "$app_identifier" ]; then
-        log_info "Found application-identifier: $app_identifier"
-    else
+
+    local app_groups app_identifier
+    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    if [ -z "$app_identifier" ]; then
         log_warn "No application-identifier found, using bundle ID"
         app_identifier="$bundle_id"
     fi
-
-    # Include the app's default keychain access group (application-identifier).
-    # Many apps store keychain items under this group even if it is not listed in keychain-access-groups.
     keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-    log_info "Final keychain groups: $keychain_groups"
-
-    # Detect if this is a system/Apple app that needs full entitlements
-    # Check: 1) In /Applications, OR 2) Bundle ID starts with com.apple.
-    local is_system_app=0
-    local source_ent_for_system=""
-    if echo "$app_binary" | grep -q "^/Applications/"; then
-        is_system_app=1
-        source_ent_for_system="$ent_file"
-        log_info "Detected system app (by path) - will use full entitlements"
-    elif echo "$app_identifier" | grep -q "^com\.apple\."; then
-        is_system_app=1
-        source_ent_for_system="$ent_file"
-        log_info "Detected Apple app (by identifier) - will use full entitlements"
-    fi
-
-    # Generate helper entitlements
-    log_info "Generating helper entitlements..."
-    local helper_ent="$TEMP_DIR/helper_ent.plist"
-    generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
-    local generation_status=$?
-    if [ "$generation_status" -ne 0 ]; then
-        log_error "Failed to generate helper entitlements"
-        return "$generation_status"
-    fi
-
-    # Prepare working copy of helper tool
-    local working_helper="$TEMP_DIR/backup_helper"
-    if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
-        log_error "Failed to copy helper tool to temp: $working_helper"
-        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    fi
-    chmod 755 "$working_helper"
-
-    # Resign helper
-    log_info "Resigning KeychainHelper..."
-    resign_helper "$helper_ent" "$working_helper"
-    local resign_status=$?
-    if [ "$resign_status" -ne 0 ]; then
-        log_error "Failed to resign helper tool"
-        return "$resign_status"
-    fi
-
-    # Execute backup using the resigned copy
-    log_info "Executing backup..."
-    local helper_args=("--action" "backup" "--file" "$backup_file" "--groups" "$keychain_groups")
-    if [ "$VERBOSE" -eq 1 ]; then
-        helper_args+=("--verbose")
-    fi
-    "$working_helper" "${helper_args[@]}"
-
+    px_select_source_entitlement "$app_identifier"
+
+    log_info "Preparing private signed helper..."
+    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    local helper_status=$?
+    [ "$helper_status" -eq 0 ] || return "$helper_status"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_revalidate_backup_output_before_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
+    local helper_args=("--action" "backup" "--file" "$PX_BACKUP_OUTPUT_PATH" "--groups" "$keychain_groups")
+    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
+    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_backup_output_after_execution "$raw_exit_code" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     local exit_code=$?
     if [ "$exit_code" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ]; then
-        log_info "Backup completed successfully: $backup_file"
+        log_info "Backup completed successfully"
     else
         log_error "Backup failed with exit code: $exit_code"
     fi
-
     return "$exit_code"
 }

 do_restore() {
     local bundle_id="$1"
-    local backup_file="$2"
+    local restore_file="$2"
     local overwrite="$3"
     local override_groups="$4"
-
-    log_info "Starting keychain restore for: $bundle_id"
-
-    if [ ! -f "$backup_file" ]; then
-        log_error "Backup file not found: $backup_file"
-        return "$PX_KEYCHAIN_EXIT_INVALID_INPUT"
-    fi
-
-    # Find app executable and resign with its entitlements
-    log_info "Locating app executable..."
-    local app_binary
-    app_binary=$(find_app_executable "$bundle_id") || {
-        log_error "Could not find app with bundle ID: $bundle_id"
-        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
-    }
-
-    mkdir -p "$TEMP_DIR"
-
-    log_info "Extracting entitlements..."
-    local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file"
-    local entitlement_status=$?
-    if [ "$entitlement_status" -ne 0 ]; then
-        return "$entitlement_status"
-    fi
-
-    local keychain_groups
-    keychain_groups=$(parse_keychain_groups "$ent_file")

+    log_info "Starting keychain restore"
+    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_prepare_restore_snapshot "$restore_file"
+    local snapshot_status=$?
+    [ "$snapshot_status" -eq 0 ] || return "$snapshot_status"
+
+    log_info "Locating target application..."
+    px_prepare_target_context "$bundle_id"
+    local context_status=$?
+    [ "$context_status" -eq 0 ] || return "$context_status"
+
+    local keychain_groups app_groups app_identifier
+    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     if [ -n "$override_groups" ]; then
-        log_info "Using override keychain groups: $override_groups"
+        log_info "Using caller-selected keychain groups"
         keychain_groups="$override_groups"
     fi
-    local app_groups
-    app_groups=$(parse_app_groups "$ent_file")
-    local app_identifier
-    app_identifier=$(parse_app_identifier "$ent_file")
-    [ -z "$app_identifier" ] && app_identifier="$bundle_id"
-
-    # Always include the default app keychain group.
+    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ -n "$app_identifier" ] || app_identifier="$bundle_id"
     keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-
-    # Detect system/Apple app
-    local source_ent_for_system=""
-    if echo "$app_binary" | grep -q "^/Applications/"; then
-        source_ent_for_system="$ent_file"
-    elif echo "$app_identifier" | grep -q "^com\.apple\."; then
-        source_ent_for_system="$ent_file"
-        log_info "Detected Apple app - will use full entitlements"
-    fi
-
-    local helper_ent="$TEMP_DIR/helper_ent.plist"
-    generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
-    local generation_status=$?
-    if [ "$generation_status" -ne 0 ]; then
-        return "$generation_status"
-    fi
-
-    # Prepare working copy of helper tool
-    local working_helper="$TEMP_DIR/backup_helper"
-    if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
-        log_error "Failed to copy helper tool to temp: $working_helper"
-        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    fi
-    chmod 755 "$working_helper"
-
-    log_info "Resigning KeychainHelper..."
-    resign_helper "$helper_ent" "$working_helper"
-    local resign_status=$?
-    if [ "$resign_status" -ne 0 ]; then
-        return "$resign_status"
-    fi
-
-    # Execute restore using the resigned copy
-    log_info "Executing restore..."
-    local extra_args=""
-    if [ "$overwrite" = "--overwrite" ]; then
-        extra_args="--overwrite"
-    fi
-
-    local helper_args=("--action" "restore" "--file" "$backup_file")
-    if [ -n "$extra_args" ]; then
-        helper_args+=("$extra_args")
-    fi
-    if [ "$VERBOSE" -eq 1 ]; then
-        helper_args+=("--verbose")
-    fi
-    "$working_helper" "${helper_args[@]}"
-
+    px_select_source_entitlement "$app_identifier"
+
+    log_info "Preparing private signed helper..."
+    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    local helper_status=$?
+    [ "$helper_status" -eq 0 ] || return "$helper_status"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_RESTORE_INPUT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
+    local helper_args=("--action" "restore" "--file" "$PX_RESTORE_INPUT_PATH")
+    if [ "$overwrite" = "--overwrite" ]; then helper_args+=("--overwrite"); fi
+    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
+    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_RESTORE_INPUT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     local exit_code=$?
     if [ "$exit_code" -eq "$PX_KEYCHAIN_EXIT_COMPLETED" ]; then
@@ -776,92 +1392,48 @@ do_restore() {
     else
         log_error "Restore failed with exit code: $exit_code"
     fi
-
     return "$exit_code"
 }

 do_wipe() {
     local bundle_id="$1"
     local override_groups="$2"
-
-    log_info "Starting keychain wipe for: $bundle_id"
-
-    # Find app and get entitlements
-    local app_binary
-    app_binary=$(find_app_executable "$bundle_id") || {
-        log_error "Could not find app with bundle ID: $bundle_id"
-        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
-    }
-
-    mkdir -p "$TEMP_DIR"
-
-    local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file"
-    local entitlement_status=$?
-    if [ "$entitlement_status" -ne 0 ]; then
-        return "$entitlement_status"
-    fi
-
-    local keychain_groups
-    keychain_groups=$(parse_keychain_groups "$ent_file")

+    log_info "Starting keychain wipe"
+    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_prepare_target_context "$bundle_id"
+    local context_status=$?
+    [ "$context_status" -eq 0 ] || return "$context_status"
+
+    local keychain_groups app_groups app_identifier
+    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     if [ -n "$override_groups" ]; then
-        log_info "Using override keychain groups: $override_groups"
+        log_info "Using caller-selected keychain groups"
         keychain_groups="$override_groups"
     fi
-
     if [ -z "$keychain_groups" ]; then
         log_error "No keychain-access-groups found"
         return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
     fi
-
-    log_warn "This will DELETE all keychain items for: $keychain_groups"
-
-    local app_groups
-    app_groups=$(parse_app_groups "$ent_file")
-    local app_identifier
-    app_identifier=$(parse_app_identifier "$ent_file")
-    [ -z "$app_identifier" ] && app_identifier="$bundle_id"
-
-    # Always include the default app keychain group.
+    log_warn "This will delete all Keychain items for the selected groups"
+    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ -n "$app_identifier" ] || app_identifier="$bundle_id"
     keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-
-    # Detect system/Apple app
-    local source_ent_for_system=""
-    if echo "$app_binary" | grep -q "^/Applications/"; then
-        source_ent_for_system="$ent_file"
-    elif echo "$app_identifier" | grep -q "^com\.apple\."; then
-        source_ent_for_system="$ent_file"
-    fi
-
-    local helper_ent="$TEMP_DIR/helper_ent.plist"
-    generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
-    local generation_status=$?
-    if [ "$generation_status" -ne 0 ]; then
-        return "$generation_status"
-    fi
-
-    # Prepare working copy
-    local working_helper="$TEMP_DIR/backup_helper"
-    if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
-        log_error "Failed to copy helper"
-        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    fi
-    chmod 755 "$working_helper"
-
-    resign_helper "$helper_ent" "$working_helper"
-    local resign_status=$?
-    if [ "$resign_status" -ne 0 ]; then
-        return "$resign_status"
-    fi
-
+    px_select_source_entitlement "$app_identifier"
+
+    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    local helper_status=$?
+    [ "$helper_status" -eq 0 ] || return "$helper_status"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
     local helper_args=("--action" "wipe" "--groups" "$keychain_groups")
-    if [ "$VERBOSE" -eq 1 ]; then
-        helper_args+=("--verbose")
-    fi
-    "$working_helper" "${helper_args[@]}"
-
+    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
+    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     return $?
 }
@@ -869,88 +1441,45 @@ do_wipe() {
 do_list() {
     local bundle_id="$1"
     local override_groups="$2"
-
-    log_info "Listing keychain items for: $bundle_id"
-
-    local app_binary
-    app_binary=$(find_app_executable "$bundle_id") || {
-        log_error "Could not find app with bundle ID: $bundle_id"
-        return "$PX_KEYCHAIN_EXIT_TARGET_UNAVAILABLE"
-    }
-
-    mkdir -p "$TEMP_DIR"
-
-    local ent_file="$TEMP_DIR/app_ent.xml"
-    extract_entitlements "$app_binary" "$ent_file"
-    local entitlement_status=$?
-    if [ "$entitlement_status" -ne 0 ]; then
-        return "$entitlement_status"
-    fi
-
-    local keychain_groups
-    keychain_groups=$(parse_keychain_groups "$ent_file")

+    log_info "Listing keychain items"
+    px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_prepare_target_context "$bundle_id"
+    local context_status=$?
+    [ "$context_status" -eq 0 ] || return "$context_status"
+
+    local keychain_groups app_groups app_identifier
+    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     if [ -n "$override_groups" ]; then
-        log_info "Using override keychain groups: $override_groups"
+        log_info "Using caller-selected keychain groups"
         keychain_groups="$override_groups"
     fi
-
     if [ -z "$keychain_groups" ]; then
         log_info "No keychain-access-groups found in app"
         return "$PX_KEYCHAIN_EXIT_COMPLETED"
     fi
-
-    local app_groups
-    app_groups=$(parse_app_groups "$ent_file")
-    local app_identifier
-    app_identifier=$(parse_app_identifier "$ent_file")
-    [ -z "$app_identifier" ] && app_identifier="$bundle_id"
-
-    # Always include the default app keychain group.
+    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ -n "$app_identifier" ] || app_identifier="$bundle_id"
     keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-
-    # Detect system/Apple app
-    local source_ent_for_system=""
-    if echo "$app_binary" | grep -q "^/Applications/"; then
-        source_ent_for_system="$ent_file"
-    elif echo "$app_identifier" | grep -q "^com\.apple\."; then
-        source_ent_for_system="$ent_file"
-    fi
-
-    local helper_ent="$TEMP_DIR/helper_ent.plist"
-    generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_for_system"
-    local generation_status=$?
-    if [ "$generation_status" -ne 0 ]; then
-        return "$generation_status"
-    fi
-
-    # Prepare working copy
-    local working_helper="$TEMP_DIR/backup_helper"
-    if ! cp "$HELPER_TOOL_PATH" "$working_helper"; then
-        log_error "Failed to copy helper"
-        return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    fi
-    chmod 755 "$working_helper"
-
-    resign_helper "$helper_ent" "$working_helper"
-    local resign_status=$?
-    if [ "$resign_status" -ne 0 ]; then
-        return "$resign_status"
-    fi
-
+    px_select_source_entitlement "$app_identifier"
+
+    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    local helper_status=$?
+    [ "$helper_status" -eq 0 ] || return "$helper_status"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
     local helper_args=("--action" "list" "--groups" "$keychain_groups")
-    if [ "$VERBOSE" -eq 1 ]; then
-        helper_args+=("--verbose")
-    fi
-    "$working_helper" "${helper_args[@]}"
-
+    if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
+    "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     return $?
 }

-# === Entry Point ===
-
 print_usage() {
     echo "Usage: $0 <action> <bundleID> [options]"
     echo ""
@@ -969,12 +1498,19 @@ print_usage() {
     echo "  $0 restore com.game.app /var/tmp/game_keychain.plist --overwrite"
 }

-# Check helper tool exists
-if [ ! -x "$HELPER_TOOL_PATH" ]; then
-    log_error "KeychainHelper not found at: $HELPER_TOOL_PATH"
-    log_error "Please ensure the WeaponX package is properly installed"
+# Initialize the trusted metadata and dependency boundary before external work.
+if ! px_initialize_metadata_boundary; then
+    log_error "Trusted filesystem metadata utility is unavailable"
+    exit "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
+fi
+if ! px_validate_installed_helper; then
+    log_error "Installed Keychain helper failed safety validation"
     exit "$PX_KEYCHAIN_EXIT_HELPER_UNAVAILABLE"
 fi
+if ! px_resolve_trusted_dependencies; then
+    log_error "A required trusted utility is unavailable"
+    exit "$PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE"
+fi

 # Parse global options
 while [[ "$1" == --* ]]; do
@@ -1003,6 +1539,11 @@ ACTION="$1"
 BUNDLE_ID="$2"
 shift 2

+if ! px_validate_bundle_id "$BUNDLE_ID"; then
+    log_error "Invalid bundle identifier"
+    exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+fi
+
 case "$ACTION" in
     backup)
         if [ -z "$1" ]; then
```

## CRLF, LF, NUL and final-newline audit
| File | Before CRLF | After CRLF | NUL | Final newline | Trailing whitespace |
|---|---:|---:|---:|---:|---:|
| `scripts/keychain_backup.sh` | 1108 | 1649 | 0 | TRUE | 0 |
| report | 0 | 0 | 0 | TRUE | 0 |
Wrapper remains CRLF; report UTF-8 LF; git diff --check PASS.

## Build and device limitations
- clang.exe, make.exe and xcrun.exe unavailable; THEOS unset.
- No Objective-C source changed.
- iOS tests pending for BSD stat/mktemp, rootless aliases, real ownership/modes, ldid replacement and all four helper actions.
- GitHub Actions pending.

## Residual shell-boundary risks
Metadata snapshots are not descriptor-pinned transactions. Malicious root/kernel or compromised filesystem remains out of scope. Backup publication is not crash-durable and no encryption/Data Protection policy is added. Strict fail-closed ownership/mode/link checks may reject unusual legitimate installations until device compatibility is confirmed.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
