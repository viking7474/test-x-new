# TASK-4.7 REPORT - Requested and Effective Keychain Access Groups

## Result
- COMPLETE within TASK-4.7 scope.
- Result protocol migrated intentionally from V1 to V2.
- Requested and signed-effective group authorities are proven before helper execution.
- TASK-4.8 and TASK-4.9 were not started.

## User authority
- Mandatory baseline `b079d1a92fa78e3e5f78fcc2de7a4f798b2fa50d`.
- User authority confirms TASK-4.6 ACCEPTED/COMPLETED and TASK-4.7 READY.

## TASK-4.6 review-file status
- TASK-4.6 review is absent and was not treated as a blocker.
- No review file was synthesized.

## Baseline
```text
b079d1a phase4(task-4.6): secure keychain helper workspace paths
0aa40df phase4(task-4.5): implement exact per-item keychain upsert
9d637e2 phase4(task-4.4): define exact keychain item identity
4c70002 phase4(task-4.3): remove broad keychain restore pre-delete
5c6e70a phase4(task-4.2): define reliable keychain helper exit codes
1a59e96 phase4(task-4.1): add structured keychain helper result
02770e2 phase3(task-3.10A): fix stale name classification and rollback errors
5e70a8f phase3(task-3.10): harden backup discovery and stale cleanup
```

## Exact authorized scope
| Status | Path |
|---|---|
| M | `KeychainHelper/PXKeychainHelperResult.h` |
| M | `KeychainHelper/PXKeychainHelperResult.m` |
| M | `KeychainHelper/backup_helper.m` |
| M | `scripts/keychain_backup.sh` |
| A | `docs/backup-restore-hardening/reports/TASK-4.7-REPORT.md` |

## Working-tree preservation
Coordinator-owned paths remained unstaged:
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
Protected production files: 74.
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
| `KeychainHelper/PXKeychainItemIdentity.h` | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.m` | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 | TRUE |
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
| `KeychainHelper/PXKeychainHelperResult.h` | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | `78ba2ea6126db71d1d28026c7f1f1c66b2244aa792f411bc837f1e192e1c5a4a` | 3713 |
| `KeychainHelper/PXKeychainHelperResult.m` | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | `ff6ab760a6ba350efb55fa5c67bb3db157e0fea9992dffa67aab76f3847d3d6a` | 37518 |
| `KeychainHelper/backup_helper.m` | `f3af22735ef307a2f583079832c4a7222ffbcf2617c366de564086cf538c1eee` | 28260 | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | 42561 |
| `scripts/keychain_backup.sh` | `f4a2099e023c06639742631fc639c3a309a9381f28eb6b6578a38ae2f6752478` | 67455 | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | 75266 |
| report | ABSENT | 0 | SELF-REFERENTIAL | SELF-REFERENTIAL |

## V1 protocol inventory
| Item | Baseline |
|---|---:|
| public result properties | 14 |
| schema version | 1 |
| V1 prefix definitions | 1 |
| V1 INVALID fallback | 1 |
| root keys | 10 |
| fatalError nested keys | 3 |
| accessGroups root key | 0 |
| result constructor references | 17 |
| finalizer references | 17 |
| emitter references | 2 |
| wrapper target group parse calls | 4 |
| wrapper override nonempty checks | 4 |
| application-ID augmentation calls | 4 |
| helper entitlement generation calls | 1 |
| helper signing calls | 1 |
| ldid extraction sites | 1 |
| workspace allowlist entries | 4 |
| helper argv sites | 4 |
| legacy list shortcut | 2 |
| normalizer definitions | 1 |
| normalizer calls | 4 |

## Original group-selection inventory
Four actions independently selected groups, override presence was inferred from nonempty text, and V1 carried no group facts.

## Original system/full-entitlement behavior
System mode copied full target entitlements, so signed effective scope could be wider without being reported.

## Original list no-group shortcut
List returned before app-ID augmentation when the explicit array was empty; that shortcut is now removed.

## Requested-group definition
Canonical ordered override or target groups, deduplicated first-occurrence order, plus validated application identifier or validated bundle-ID fallback.

## Effective-group definition
Canonical groups parsed from exact `signed_helper_ent.plist` extracted by trusted `ldid -e` from the signed private helper.

## Requested/effective relation
Both wrapper and direct helper prove `requested ⊆ effective`; proper effective supersets are allowed and reported.

## V2 migration rationale
D-343 excluded groups from V1. TASK-4.7 is the first authorized bounded privacy expansion: schema 2, V2 prefix, 11 root keys, no compatibility line.

## Exact V2 graph
```text
{ schemaVersion, operation, completion, attemptedCount, succeededCount, failedCount, skippedCount, warningCount, errorCount, fatalError={present,domain,code}, accessGroups={requested,effective} }
```

## Result public API changes
Adds copied readonly requested/effective arrays; extends the sole factory/private initializer; updates equality/hash; removes the obsolete overload.

## Group validation bounds
| Bound | Value |
|---|---:|
| groups per array | 128 |
| bytes per group | 512 |
| bytes per array | 8192 |
| combined group bytes | 16384 |

## Deep immutability
Copies every string and array; retains immutable nested/root dictionaries; immutable plist read-back must deep-equal state.

## Serialization limits
Binary plist 32768 bytes, base64 49152 bytes, complete line 51200 bytes; arithmetic is overflow-safe.

## V2 read-back proof
Binary plist -> base64 -> byte-equal decode -> immutable binary-plist parse -> exact graph/state equality.

## Direct-helper new arguments
`--requested-groups` carries requested authority; `--effective-entitlements-file` carries signed snapshot authority; restore rejects operational `--groups`.

## Requested CSV parser
Bounded strict parser rejects controls/empty entries, trims surrounding spaces, validates, deduplicates and preserves order.

## Effective entitlement parser
Uses lstat, regular non-symlink bounded file, immutable XML/binary plist parse, dictionary root and strict keychain-access-groups array.

## Operational consistency proof
Backup/wipe/list canonical operational arrays must exactly equal requested arrays. Restore has no operational query and no core filtering change.

## Wrapper canonical group authority
One canonicalizer and one `px_prepare_requested_groups` flow serve all four actions; no sorting/lowercasing/wildcard/Team-ID inference.

## Override presence behavior
Explicit empty/malformed/missing/duplicate override fails exit 20 and never falls back.

## Application identifier augmentation
App ID or validated bundle fallback is appended before terminal emptiness; list no longer exits early.

## Signed helper entitlement extraction
Exact absent 0600 child, immediate ldid status capture, workspace/helper snapshots, parse and subset proof.

## Effective group authority
Signing input and signed extraction remain separate; only signed extraction is effective report authority.

## Requested subset proof
Wrapper prevalidates and direct helper independently parses/proves subset before any Keychain core call.

## System effective-superset behavior
Full entitlements remain unchanged; extra effective groups are reported, not removed or rejected.

## Custom entitlement equality behavior
Custom mode normally yields equality; factual signed extraction remains authoritative.

## Restore reporting semantics
Reports intended versus actual capability without item filtering, access-group rewriting, schema filtering or per-group counters.

## Workspace allowlist extension
Adds exact `signed_helper_ent.plist` 0600 child to the five-child allowlist.

## Cleanup extension
Reverse cleanup includes signed snapshot; bounded/nonrecursive behavior and unknown-content preservation remain.

## Helper pre/post execution revalidation
Workspace, signing input, signed helper and signed entitlement complete snapshots are revalidated before and after all four executions.

## Exit-code mapping
Malformed caller groups 20; invalid direct effective file 21; signed extraction/plist/subset 62; workspace identity 63; protocol 50; unknown helper status 40.

## Privacy expansion and remaining exclusions
Only requested/effective group strings are added to machine V2. No paths, raw entitlements, bundle/app identifiers as separate fields, Keychain item identifiers, secrets or human messages. Shell logs omit group values.

## TASK-4.1 intentional protocol migration
Preserves immutable factual binary-plist/base64 one-line framing, exact validation/read-back and INVALID semantics; intentional migration is V2/accessGroups/bounds/factory.

## TASK-4.2 non-regression
Thirteen-value taxonomy, one finalizer, wrapper normalizer 1/4, unknown->40 and Partial exit10 remain.

## TASK-4.3 zero-delete proof
Restore SecItemDelete remains zero; explicit wipe is sole core delete.

## TASK-4.4 identity non-regression
Identity sources and Makefile are byte-identical.

## TASK-4.5 upsert non-regression
Whole core [6, 1, 1, 1]; restore [1, 1, 1, 0]; add-first/exact lookup/persistent-reference update/no delete-add fallback unchanged.

## TASK-4.6 workspace non-regression
Fixed /private/var/tmp, mktemp, 0700, trusted utilities, path checks, restore snapshot, bounded cleanup and zero rm-rf remain.

## TASK-4.8 boundary
Manager/result/bridge unchanged; no V2 parsing, Partial integration, manifest/UI consumption or success-decision changes.

## TASK-4.9 boundary
No final mode/ownership/encryption/Data Protection/xattr/at-rest/publication policy change.

## Static gate table
| Gate | Observed | Required | Result |
|---|---:|---:|---|
| `schema version definitions` | 1 | 1 | PASS |
| `production V1 output-prefix definitions` | 0 | 0 | PASS |
| `production V2 output-prefix definitions` | 1 | 1 | PASS |
| `V1 INVALID fallback` | 0 | 0 | PASS |
| `V2 INVALID fallback` | 1 | 1 | PASS |
| `V2 root keys` | 11 | 11 | PASS |
| `accessGroups root keys` | 1 | 1 | PASS |
| `requested nested keys` | 1 | 1 | PASS |
| `effective nested keys` | 1 | 1 | PASS |
| `result group properties` | 2 | 2 | PASS |
| `result factory group parameters` | 2 | 2 | PASS |
| `subset invariant definitions` | 1 | 1 | PASS |
| `requested max count` | 128 | 128 | PASS |
| `effective max count` | 128 | 128 | PASS |
| `wrapper requested canonicalizer` | 1 | 1 | PASS |
| `signed extraction authority` | 1 | 1 | PASS |
| `signed entitlement child` | 1 | 1 | PASS |
| `signed cleanup entry` | 1 | 1 | PASS |
| `requested argv sites` | 4 | 4 | PASS |
| `effective-file argv sites` | 4 | 4 | PASS |
| `operational groups sites` | 3 | 3 | PASS |
| `restore operational groups` | 0 | 0 | PASS |
| `legacy list shortcut` | 0 | 0 | PASS |
| `wrapper V2 parsing` | 0 | 0 | PASS |
| `wrapper prefix references` | 0 | 0 | PASS |
| `normalizer definitions` | 1 | 1 | PASS |
| `normalizer calls` | 4 | 4 | PASS |
| `shell exit constants` | 13 | 13 | PASS |
| `manager diffs` | 0 | 0 | PASS |
| `bridge diffs` | 0 | 0 | PASS |
| `Makefile diffs` | 0 | 0 | PASS |
| `Keychain core diffs` | 0 | 0 | PASS |
| `restore SecItemDelete` | 0 | 0 | PASS |
| `TASK-4.8 implementation` | 0 | 0 | PASS |
| `TASK-4.9 implementation` | 0 | 0 | PASS |
| protected hashes | 74 | 74 | PASS |
| core Security calls | 6/1/1/1 | 6/1/1/1 | PASS |
| restore Security calls | 1/1/1/0 | 1/1/1/0 | PASS |
| source-gate assertions | 243 | 243 | PASS |
| result-model assertions | 722450 | 722450 | PASS |
| helper-model assertions | 150048 | 150048 | PASS |
| shell-model assertions | 493440 | 493440 | PASS |
| actual Git Bash cases | 48 | 48 | PASS |
| explicit scenarios | 526 | >=420 | PASS |

## Result-model test summary
722,450 deterministic assertions passed for schema, arrays, relation, immutability, serialization and bounds.

## Helper CLI test summary
150,048 deterministic assertions passed for CSV, XML/binary plist, arguments, consistency, subset and outcomes.

## Shell test summary
493,440 deterministic assertions passed; extracted actual functions passed 24/24 under each Git Bash executable.

## Explicit numbered scenarios
Explicit scenarios: 526.
| # | Area | Stimulus | Expected |
|---:|---|---|---|
| 1 | authority | exact baseline | enforced |
| 2 | authority | TASK-4.6 accepted | enforced |
| 3 | authority | TASK-4.6 completed | enforced |
| 4 | authority | TASK-4.7 ready | enforced |
| 5 | authority | TASK-4.6 review absent | enforced |
| 6 | authority | review not created | enforced |
| 7 | authority | five authorized files | enforced |
| 8 | authority | Makefile protected | enforced |
| 9 | authority | manager protected | enforced |
| 10 | authority | bridge protected | enforced |
| 11 | authority | coordinator docs preserved | enforced |
| 12 | authority | no push | enforced |
| 13 | authority | no TASK-4.8 | enforced |
| 14 | authority | no TASK-4.9 | enforced |
| 15 | V2 schema | schema 2 | exact contract |
| 16 | V2 schema | V2 prefix byte zero | exact contract |
| 17 | V2 schema | V1 absent | exact contract |
| 18 | V2 schema | one V2 prefix | exact contract |
| 19 | V2 schema | binary plist | exact contract |
| 20 | V2 schema | base64 no newline | exact contract |
| 21 | V2 schema | root count 11 | exact contract |
| 22 | V2 schema | fatal count 3 | exact contract |
| 23 | V2 schema | accessGroups count 2 | exact contract |
| 24 | V2 schema | deep read-back | exact contract |
| 25 | V2 schema | V2 INVALID | exact contract |
| 26 | V2 schema | no compatibility line | exact contract |
| 27 | V2 schema | failed | exact contract |
| 28 | V2 schema | completed | exact contract |
| 29 | V2 schema | partial | exact contract |
| 30 | result requested | empty | reject |
| 31 | result requested | ASCII | accept |
| 32 | result requested | Unicode | accept |
| 33 | result requested | 512 bytes | accept |
| 34 | result requested | 513 bytes | reject |
| 35 | result requested | NUL | reject |
| 36 | result requested | CR | reject |
| 37 | result requested | LF | reject |
| 38 | result requested | tab | reject |
| 39 | result requested | comma | reject |
| 40 | result requested | leading space | reject |
| 41 | result requested | trailing space | reject |
| 42 | result requested | mutable string | copy |
| 43 | result requested | NSNumber | reject |
| 44 | result requested | NSData | reject |
| 45 | result requested | dictionary | reject |
| 46 | result requested | nested array | reject |
| 47 | result requested | 0 elements | accept |
| 48 | result requested | 1 elements | accept |
| 49 | result requested | 64 elements | accept |
| 50 | result requested | 128 elements | accept |
| 51 | result requested | 129 elements | reject |
| 52 | result requested | duplicate | reject |
| 53 | result requested | 8192 bytes | bounded |
| 54 | result requested | over 8192 | reject |
| 55 | result requested | mutable array | copy |
| 56 | result requested | NSNull | reject |
| 57 | result effective | empty | reject |
| 58 | result effective | ASCII | accept |
| 59 | result effective | Unicode | accept |
| 60 | result effective | 512 bytes | accept |
| 61 | result effective | 513 bytes | reject |
| 62 | result effective | NUL | reject |
| 63 | result effective | CR | reject |
| 64 | result effective | LF | reject |
| 65 | result effective | tab | reject |
| 66 | result effective | comma | reject |
| 67 | result effective | leading space | reject |
| 68 | result effective | trailing space | reject |
| 69 | result effective | mutable string | copy |
| 70 | result effective | NSNumber | reject |
| 71 | result effective | NSData | reject |
| 72 | result effective | dictionary | reject |
| 73 | result effective | nested array | reject |
| 74 | result effective | 0 elements | accept |
| 75 | result effective | 1 elements | accept |
| 76 | result effective | 64 elements | accept |
| 77 | result effective | 128 elements | accept |
| 78 | result effective | 129 elements | reject |
| 79 | result effective | duplicate | reject |
| 80 | result effective | 8192 bytes | bounded |
| 81 | result effective | over 8192 | reject |
| 82 | result effective | mutable array | copy |
| 83 | result effective | NSNull | reject |
| 84 | set relation | empty subset empty | accept |
| 85 | set relation | empty subset nonempty | accept |
| 86 | set relation | one subset same | accept |
| 87 | set relation | one subset effective extra | accept |
| 88 | set relation | two subset same different order | accept |
| 89 | set relation | two subset missing one | reject |
| 90 | set relation | A subset a | reject |
| 91 | set relation | Unicode subset same | accept |
| 92 | set relation | duplicate requested subset same | reject |
| 93 | set relation | one subset duplicate effective | reject |
| 94 | immutability | mutate requested array | unchanged |
| 95 | immutability | mutate effective array | unchanged |
| 96 | immutability | mutate requested string | unchanged |
| 97 | immutability | mutate effective string | unchanged |
| 98 | immutability | copy result | unchanged |
| 99 | immutability | equal result | unchanged |
| 100 | immutability | unequal requested | unchanged |
| 101 | immutability | unequal effective | unchanged |
| 102 | immutability | hash stability | unchanged |
| 103 | immutability | nested mutation | unchanged |
| 104 | serialization | plist at 32768 | bounded |
| 105 | serialization | plist over | bounded |
| 106 | serialization | base64 at 49152 | bounded |
| 107 | serialization | base64 over | bounded |
| 108 | serialization | line at 51200 | bounded |
| 109 | serialization | line over | bounded |
| 110 | serialization | count overflow | bounded |
| 111 | serialization | UTF-8 overflow | bounded |
| 112 | serialization | combined at 16384 | bounded |
| 113 | serialization | combined over | bounded |
| 114 | helper CLI backup | missing action | help only has no machine line; invalid metadata fails safely; valid continues |
| 115 | helper CLI backup | unknown action | help only has no machine line; invalid metadata fails safely; valid continues |
| 116 | helper CLI backup | missing requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 117 | helper CLI backup | missing effective file | help only has no machine line; invalid metadata fails safely; valid continues |
| 118 | helper CLI backup | requested only | help only has no machine line; invalid metadata fails safely; valid continues |
| 119 | helper CLI backup | effective only | help only has no machine line; invalid metadata fails safely; valid continues |
| 120 | helper CLI backup | duplicate requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 121 | helper CLI backup | duplicate effective | help only has no machine line; invalid metadata fails safely; valid continues |
| 122 | helper CLI backup | duplicate action | help only has no machine line; invalid metadata fails safely; valid continues |
| 123 | helper CLI backup | unknown option | help only has no machine line; invalid metadata fails safely; valid continues |
| 124 | helper CLI backup | value begins -- | help only has no machine line; invalid metadata fails safely; valid continues |
| 125 | helper CLI backup | empty requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 126 | helper CLI backup | restore with groups | help only has no machine line; invalid metadata fails safely; valid continues |
| 127 | helper CLI backup | valid metadata | help only has no machine line; invalid metadata fails safely; valid continues |
| 128 | helper CLI backup | help | help only has no machine line; invalid metadata fails safely; valid continues |
| 129 | helper CLI restore | missing action | help only has no machine line; invalid metadata fails safely; valid continues |
| 130 | helper CLI restore | unknown action | help only has no machine line; invalid metadata fails safely; valid continues |
| 131 | helper CLI restore | missing requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 132 | helper CLI restore | missing effective file | help only has no machine line; invalid metadata fails safely; valid continues |
| 133 | helper CLI restore | requested only | help only has no machine line; invalid metadata fails safely; valid continues |
| 134 | helper CLI restore | effective only | help only has no machine line; invalid metadata fails safely; valid continues |
| 135 | helper CLI restore | duplicate requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 136 | helper CLI restore | duplicate effective | help only has no machine line; invalid metadata fails safely; valid continues |
| 137 | helper CLI restore | duplicate action | help only has no machine line; invalid metadata fails safely; valid continues |
| 138 | helper CLI restore | unknown option | help only has no machine line; invalid metadata fails safely; valid continues |
| 139 | helper CLI restore | value begins -- | help only has no machine line; invalid metadata fails safely; valid continues |
| 140 | helper CLI restore | empty requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 141 | helper CLI restore | restore with groups | help only has no machine line; invalid metadata fails safely; valid continues |
| 142 | helper CLI restore | valid metadata | help only has no machine line; invalid metadata fails safely; valid continues |
| 143 | helper CLI restore | help | help only has no machine line; invalid metadata fails safely; valid continues |
| 144 | helper CLI wipe | missing action | help only has no machine line; invalid metadata fails safely; valid continues |
| 145 | helper CLI wipe | unknown action | help only has no machine line; invalid metadata fails safely; valid continues |
| 146 | helper CLI wipe | missing requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 147 | helper CLI wipe | missing effective file | help only has no machine line; invalid metadata fails safely; valid continues |
| 148 | helper CLI wipe | requested only | help only has no machine line; invalid metadata fails safely; valid continues |
| 149 | helper CLI wipe | effective only | help only has no machine line; invalid metadata fails safely; valid continues |
| 150 | helper CLI wipe | duplicate requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 151 | helper CLI wipe | duplicate effective | help only has no machine line; invalid metadata fails safely; valid continues |
| 152 | helper CLI wipe | duplicate action | help only has no machine line; invalid metadata fails safely; valid continues |
| 153 | helper CLI wipe | unknown option | help only has no machine line; invalid metadata fails safely; valid continues |
| 154 | helper CLI wipe | value begins -- | help only has no machine line; invalid metadata fails safely; valid continues |
| 155 | helper CLI wipe | empty requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 156 | helper CLI wipe | restore with groups | help only has no machine line; invalid metadata fails safely; valid continues |
| 157 | helper CLI wipe | valid metadata | help only has no machine line; invalid metadata fails safely; valid continues |
| 158 | helper CLI wipe | help | help only has no machine line; invalid metadata fails safely; valid continues |
| 159 | helper CLI list | missing action | help only has no machine line; invalid metadata fails safely; valid continues |
| 160 | helper CLI list | unknown action | help only has no machine line; invalid metadata fails safely; valid continues |
| 161 | helper CLI list | missing requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 162 | helper CLI list | missing effective file | help only has no machine line; invalid metadata fails safely; valid continues |
| 163 | helper CLI list | requested only | help only has no machine line; invalid metadata fails safely; valid continues |
| 164 | helper CLI list | effective only | help only has no machine line; invalid metadata fails safely; valid continues |
| 165 | helper CLI list | duplicate requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 166 | helper CLI list | duplicate effective | help only has no machine line; invalid metadata fails safely; valid continues |
| 167 | helper CLI list | duplicate action | help only has no machine line; invalid metadata fails safely; valid continues |
| 168 | helper CLI list | unknown option | help only has no machine line; invalid metadata fails safely; valid continues |
| 169 | helper CLI list | value begins -- | help only has no machine line; invalid metadata fails safely; valid continues |
| 170 | helper CLI list | empty requested | help only has no machine line; invalid metadata fails safely; valid continues |
| 171 | helper CLI list | restore with groups | help only has no machine line; invalid metadata fails safely; valid continues |
| 172 | helper CLI list | valid metadata | help only has no machine line; invalid metadata fails safely; valid continues |
| 173 | helper CLI list | help | help only has no machine line; invalid metadata fails safely; valid continues |
| 174 | requested CSV | a | canonical or reject per bound |
| 175 | requested CSV | a,b | canonical or reject per bound |
| 176 | requested CSV | a, b | canonical or reject per bound |
| 177 | requested CSV |  a  | canonical or reject per bound |
| 178 | requested CSV | a,a | canonical or reject per bound |
| 179 | requested CSV | a,b,a | canonical or reject per bound |
| 180 | requested CSV | a,,b | canonical or reject per bound |
| 181 | requested CSV | ,a | canonical or reject per bound |
| 182 | requested CSV | a, | canonical or reject per bound |
| 183 | requested CSV | space-only | canonical or reject per bound |
| 184 | requested CSV | CR | canonical or reject per bound |
| 185 | requested CSV | LF | canonical or reject per bound |
| 186 | requested CSV | control | canonical or reject per bound |
| 187 | requested CSV | 512 bytes | canonical or reject per bound |
| 188 | requested CSV | 513 bytes | canonical or reject per bound |
| 189 | requested CSV | 128 entries | canonical or reject per bound |
| 190 | requested CSV | 129 entries | canonical or reject per bound |
| 191 | requested CSV | 8192 bytes | canonical or reject per bound |
| 192 | requested CSV | over 8192 | canonical or reject per bound |
| 193 | requested CSV | first order | canonical or reject per bound |
| 194 | requested CSV | case-sensitive | canonical or reject per bound |
| 195 | effective plist | missing | canonical immutable array only for valid regular plist |
| 196 | effective plist | empty | canonical immutable array only for valid regular plist |
| 197 | effective plist | oversized | canonical immutable array only for valid regular plist |
| 198 | effective plist | symlink | canonical immutable array only for valid regular plist |
| 199 | effective plist | directory | canonical immutable array only for valid regular plist |
| 200 | effective plist | FIFO | canonical immutable array only for valid regular plist |
| 201 | effective plist | socket | canonical immutable array only for valid regular plist |
| 202 | effective plist | malformed XML | canonical immutable array only for valid regular plist |
| 203 | effective plist | malformed binary | canonical immutable array only for valid regular plist |
| 204 | effective plist | array root | canonical immutable array only for valid regular plist |
| 205 | effective plist | string root | canonical immutable array only for valid regular plist |
| 206 | effective plist | missing key | canonical immutable array only for valid regular plist |
| 207 | effective plist | key string | canonical immutable array only for valid regular plist |
| 208 | effective plist | empty array | canonical immutable array only for valid regular plist |
| 209 | effective plist | strings | canonical immutable array only for valid regular plist |
| 210 | effective plist | duplicates | canonical immutable array only for valid regular plist |
| 211 | effective plist | NSNumber | canonical immutable array only for valid regular plist |
| 212 | effective plist | NSData | canonical immutable array only for valid regular plist |
| 213 | effective plist | empty string | canonical immutable array only for valid regular plist |
| 214 | effective plist | control string | canonical immutable array only for valid regular plist |
| 215 | effective plist | comma string | canonical immutable array only for valid regular plist |
| 216 | effective plist | valid XML | canonical immutable array only for valid regular plist |
| 217 | effective plist | valid binary | canonical immutable array only for valid regular plist |
| 218 | operational backup | equal | exact order/value equality plus subset required |
| 219 | operational backup | same set different order | exact order/value equality plus subset required |
| 220 | operational backup | subset | exact order/value equality plus subset required |
| 221 | operational backup | superset | exact order/value equality plus subset required |
| 222 | operational backup | malformed | exact order/value equality plus subset required |
| 223 | operational backup | requested missing effective | exact order/value equality plus subset required |
| 224 | operational backup | effective extra | exact order/value equality plus subset required |
| 225 | operational wipe | equal | exact order/value equality plus subset required |
| 226 | operational wipe | same set different order | exact order/value equality plus subset required |
| 227 | operational wipe | subset | exact order/value equality plus subset required |
| 228 | operational wipe | superset | exact order/value equality plus subset required |
| 229 | operational wipe | malformed | exact order/value equality plus subset required |
| 230 | operational wipe | requested missing effective | exact order/value equality plus subset required |
| 231 | operational wipe | effective extra | exact order/value equality plus subset required |
| 232 | operational list | equal | exact order/value equality plus subset required |
| 233 | operational list | same set different order | exact order/value equality plus subset required |
| 234 | operational list | subset | exact order/value equality plus subset required |
| 235 | operational list | superset | exact order/value equality plus subset required |
| 236 | operational list | malformed | exact order/value equality plus subset required |
| 237 | operational list | requested missing effective | exact order/value equality plus subset required |
| 238 | operational list | effective extra | exact order/value equality plus subset required |
| 239 | operational restore | no groups | report-only; no core filter; subset required |
| 240 | operational restore | valid | report-only; no core filter; subset required |
| 241 | operational restore | proper subset | report-only; no core filter; subset required |
| 242 | operational restore | effective extra | report-only; no core filter; subset required |
| 243 | operational restore | requested missing | report-only; no core filter; subset required |
| 244 | V2 propagation backup | Completed | arrays retained after acceptance; empty or INVALID before acceptance |
| 245 | V2 propagation backup | Partial | arrays retained after acceptance; empty or INVALID before acceptance |
| 246 | V2 propagation backup | Failed after metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 247 | V2 propagation backup | missing metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 248 | V2 propagation backup | bad requested | arrays retained after acceptance; empty or INVALID before acceptance |
| 249 | V2 propagation backup | bad effective | arrays retained after acceptance; empty or INVALID before acceptance |
| 250 | V2 propagation backup | protocol failure | arrays retained after acceptance; empty or INVALID before acceptance |
| 251 | V2 propagation restore | Completed | arrays retained after acceptance; empty or INVALID before acceptance |
| 252 | V2 propagation restore | Partial | arrays retained after acceptance; empty or INVALID before acceptance |
| 253 | V2 propagation restore | Failed after metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 254 | V2 propagation restore | missing metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 255 | V2 propagation restore | bad requested | arrays retained after acceptance; empty or INVALID before acceptance |
| 256 | V2 propagation restore | bad effective | arrays retained after acceptance; empty or INVALID before acceptance |
| 257 | V2 propagation restore | protocol failure | arrays retained after acceptance; empty or INVALID before acceptance |
| 258 | V2 propagation wipe | Completed | arrays retained after acceptance; empty or INVALID before acceptance |
| 259 | V2 propagation wipe | Partial | arrays retained after acceptance; empty or INVALID before acceptance |
| 260 | V2 propagation wipe | Failed after metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 261 | V2 propagation wipe | missing metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 262 | V2 propagation wipe | bad requested | arrays retained after acceptance; empty or INVALID before acceptance |
| 263 | V2 propagation wipe | bad effective | arrays retained after acceptance; empty or INVALID before acceptance |
| 264 | V2 propagation wipe | protocol failure | arrays retained after acceptance; empty or INVALID before acceptance |
| 265 | V2 propagation list | Completed | arrays retained after acceptance; empty or INVALID before acceptance |
| 266 | V2 propagation list | Partial | arrays retained after acceptance; empty or INVALID before acceptance |
| 267 | V2 propagation list | Failed after metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 268 | V2 propagation list | missing metadata | arrays retained after acceptance; empty or INVALID before acceptance |
| 269 | V2 propagation list | bad requested | arrays retained after acceptance; empty or INVALID before acceptance |
| 270 | V2 propagation list | bad effective | arrays retained after acceptance; empty or INVALID before acceptance |
| 271 | V2 propagation list | protocol failure | arrays retained after acceptance; empty or INVALID before acceptance |
| 272 | wrapper override | override absent | canonical or exit 20; no fallback |
| 273 | wrapper override | one | canonical or exit 20; no fallback |
| 274 | wrapper override | multiple | canonical or exit 20; no fallback |
| 275 | wrapper override | duplicate | canonical or exit 20; no fallback |
| 276 | wrapper override | spaces | canonical or exit 20; no fallback |
| 277 | wrapper override | explicit empty | canonical or exit 20; no fallback |
| 278 | wrapper override | space-only | canonical or exit 20; no fallback |
| 279 | wrapper override | control | canonical or exit 20; no fallback |
| 280 | wrapper override | oversized | canonical or exit 20; no fallback |
| 281 | wrapper override | too many | canonical or exit 20; no fallback |
| 282 | wrapper override | duplicate option | canonical or exit 20; no fallback |
| 283 | wrapper override | missing value | canonical or exit 20; no fallback |
| 284 | target groups | one | canonical source or exit 62 |
| 285 | target groups | multiple | canonical source or exit 62 |
| 286 | target groups | duplicates | canonical source or exit 62 |
| 287 | target groups | empty array | canonical source or exit 62 |
| 288 | target groups | missing key | canonical source or exit 62 |
| 289 | target groups | malformed | canonical source or exit 62 |
| 290 | target groups | comma | canonical source or exit 62 |
| 291 | target groups | oversized | canonical source or exit 62 |
| 292 | target groups | control | canonical source or exit 62 |
| 293 | target groups | Unicode | canonical source or exit 62 |
| 294 | application identifier | already selected | append once or fail |
| 295 | application identifier | not selected | append once or fail |
| 296 | application identifier | selected empty | append once or fail |
| 297 | application identifier | missing fallback | append once or fail |
| 298 | application identifier | malformed | append once or fail |
| 299 | application identifier | duplicate | append once or fail |
| 300 | application identifier | case difference | append once or fail |
| 301 | application identifier | Unicode | append once or fail |
| 302 | application identifier | 512 bytes | append once or fail |
| 303 | application identifier | over 512 | append once or fail |
| 304 | signed authority | pre-extract: workspace inode | exit 63 |
| 305 | signed authority | pre-extract: workspace mode | exit 63 |
| 306 | signed authority | pre-extract: helper inode | exit 63 |
| 307 | signed authority | pre-extract: helper size | exit 63 |
| 308 | signed authority | pre-extract: helper mtime | exit 63 |
| 309 | signed authority | pre-extract: signing input | exit 63 |
| 310 | signed authority | pre-extract: signed ent inode | exit 63 |
| 311 | signed authority | pre-extract: signed ent size | exit 63 |
| 312 | signed authority | during extract: workspace inode | exit 63 |
| 313 | signed authority | during extract: workspace mode | exit 63 |
| 314 | signed authority | during extract: helper inode | exit 63 |
| 315 | signed authority | during extract: helper size | exit 63 |
| 316 | signed authority | during extract: helper mtime | exit 63 |
| 317 | signed authority | during extract: signing input | exit 63 |
| 318 | signed authority | during extract: signed ent inode | exit 63 |
| 319 | signed authority | during extract: signed ent size | exit 63 |
| 320 | signed authority | post-extract: workspace inode | exit 63 |
| 321 | signed authority | post-extract: workspace mode | exit 63 |
| 322 | signed authority | post-extract: helper inode | exit 63 |
| 323 | signed authority | post-extract: helper size | exit 63 |
| 324 | signed authority | post-extract: helper mtime | exit 63 |
| 325 | signed authority | post-extract: signing input | exit 63 |
| 326 | signed authority | post-extract: signed ent inode | exit 63 |
| 327 | signed authority | post-extract: signed ent size | exit 63 |
| 328 | signed authority | pre-chmod: workspace inode | exit 63 |
| 329 | signed authority | pre-chmod: workspace mode | exit 63 |
| 330 | signed authority | pre-chmod: helper inode | exit 63 |
| 331 | signed authority | pre-chmod: helper size | exit 63 |
| 332 | signed authority | pre-chmod: helper mtime | exit 63 |
| 333 | signed authority | pre-chmod: signing input | exit 63 |
| 334 | signed authority | pre-chmod: signed ent inode | exit 63 |
| 335 | signed authority | pre-chmod: signed ent size | exit 63 |
| 336 | signed authority | post-chmod: workspace inode | exit 63 |
| 337 | signed authority | post-chmod: workspace mode | exit 63 |
| 338 | signed authority | post-chmod: helper inode | exit 63 |
| 339 | signed authority | post-chmod: helper size | exit 63 |
| 340 | signed authority | post-chmod: helper mtime | exit 63 |
| 341 | signed authority | post-chmod: signing input | exit 63 |
| 342 | signed authority | post-chmod: signed ent inode | exit 63 |
| 343 | signed authority | post-chmod: signed ent size | exit 63 |
| 344 | signed authority | pre-parse: workspace inode | exit 63 |
| 345 | signed authority | pre-parse: workspace mode | exit 63 |
| 346 | signed authority | pre-parse: helper inode | exit 63 |
| 347 | signed authority | pre-parse: helper size | exit 63 |
| 348 | signed authority | pre-parse: helper mtime | exit 63 |
| 349 | signed authority | pre-parse: signing input | exit 63 |
| 350 | signed authority | pre-parse: signed ent inode | exit 63 |
| 351 | signed authority | pre-parse: signed ent size | exit 63 |
| 352 | signed authority | post-parse: workspace inode | exit 63 |
| 353 | signed authority | post-parse: workspace mode | exit 63 |
| 354 | signed authority | post-parse: helper inode | exit 63 |
| 355 | signed authority | post-parse: helper size | exit 63 |
| 356 | signed authority | post-parse: helper mtime | exit 63 |
| 357 | signed authority | post-parse: signing input | exit 63 |
| 358 | signed authority | post-parse: signed ent inode | exit 63 |
| 359 | signed authority | post-parse: signed ent size | exit 63 |
| 360 | signed authority | pre-exec: workspace inode | exit 63 |
| 361 | signed authority | pre-exec: workspace mode | exit 63 |
| 362 | signed authority | pre-exec: helper inode | exit 63 |
| 363 | signed authority | pre-exec: helper size | exit 63 |
| 364 | signed authority | pre-exec: helper mtime | exit 63 |
| 365 | signed authority | pre-exec: signing input | exit 63 |
| 366 | signed authority | pre-exec: signed ent inode | exit 63 |
| 367 | signed authority | pre-exec: signed ent size | exit 63 |
| 368 | signed authority | during exec: workspace inode | exit 63 |
| 369 | signed authority | during exec: workspace mode | exit 63 |
| 370 | signed authority | during exec: helper inode | exit 63 |
| 371 | signed authority | during exec: helper size | exit 63 |
| 372 | signed authority | during exec: helper mtime | exit 63 |
| 373 | signed authority | during exec: signing input | exit 63 |
| 374 | signed authority | during exec: signed ent inode | exit 63 |
| 375 | signed authority | during exec: signed ent size | exit 63 |
| 376 | signed authority | post-exec: workspace inode | exit 63 |
| 377 | signed authority | post-exec: workspace mode | exit 63 |
| 378 | signed authority | post-exec: helper inode | exit 63 |
| 379 | signed authority | post-exec: helper size | exit 63 |
| 380 | signed authority | post-exec: helper mtime | exit 63 |
| 381 | signed authority | post-exec: signing input | exit 63 |
| 382 | signed authority | post-exec: signed ent inode | exit 63 |
| 383 | signed authority | post-exec: signed ent size | exit 63 |
| 384 | signed extraction | ldid fails | accept factual subset or fail 62/63 |
| 385 | signed extraction | empty output | accept factual subset or fail 62/63 |
| 386 | signed extraction | symlink output | accept factual subset or fail 62/63 |
| 387 | signed extraction | directory output | accept factual subset or fail 62/63 |
| 388 | signed extraction | wrong mode | accept factual subset or fail 62/63 |
| 389 | signed extraction | wrong owner | accept factual subset or fail 62/63 |
| 390 | signed extraction | malformed plist | accept factual subset or fail 62/63 |
| 391 | signed extraction | missing key | accept factual subset or fail 62/63 |
| 392 | signed extraction | equal | accept factual subset or fail 62/63 |
| 393 | signed extraction | proper subset | accept factual subset or fail 62/63 |
| 394 | signed extraction | requested absent | accept factual subset or fail 62/63 |
| 395 | signed extraction | effective extra | accept factual subset or fail 62/63 |
| 396 | entitlement mode custom | equal | report subset; missing requested fails |
| 397 | entitlement mode custom | effective superset | report subset; missing requested fails |
| 398 | entitlement mode custom | effective missing requested | report subset; missing requested fails |
| 399 | entitlement mode system full | equal | report subset; missing requested fails |
| 400 | entitlement mode system full | effective superset | report subset; missing requested fails |
| 401 | entitlement mode system full | effective missing requested | report subset; missing requested fails |
| 402 | workspace app_ent.xml | absent | exact-child validation and bounded cleanup |
| 403 | workspace app_ent.xml | safe regular | exact-child validation and bounded cleanup |
| 404 | workspace app_ent.xml | symlink | exact-child validation and bounded cleanup |
| 405 | workspace app_ent.xml | directory | exact-child validation and bounded cleanup |
| 406 | workspace app_ent.xml | FIFO | exact-child validation and bounded cleanup |
| 407 | workspace app_ent.xml | wrong mode | exact-child validation and bounded cleanup |
| 408 | workspace app_ent.xml | wrong owner | exact-child validation and bounded cleanup |
| 409 | workspace app_ent.xml | wrong device | exact-child validation and bounded cleanup |
| 410 | workspace app_ent.xml | hard link | exact-child validation and bounded cleanup |
| 411 | workspace app_ent.xml | replaced before | exact-child validation and bounded cleanup |
| 412 | workspace app_ent.xml | replaced after | exact-child validation and bounded cleanup |
| 413 | workspace app_ent.xml | cleanup failure | exact-child validation and bounded cleanup |
| 414 | workspace helper_ent.plist | absent | exact-child validation and bounded cleanup |
| 415 | workspace helper_ent.plist | safe regular | exact-child validation and bounded cleanup |
| 416 | workspace helper_ent.plist | symlink | exact-child validation and bounded cleanup |
| 417 | workspace helper_ent.plist | directory | exact-child validation and bounded cleanup |
| 418 | workspace helper_ent.plist | FIFO | exact-child validation and bounded cleanup |
| 419 | workspace helper_ent.plist | wrong mode | exact-child validation and bounded cleanup |
| 420 | workspace helper_ent.plist | wrong owner | exact-child validation and bounded cleanup |
| 421 | workspace helper_ent.plist | wrong device | exact-child validation and bounded cleanup |
| 422 | workspace helper_ent.plist | hard link | exact-child validation and bounded cleanup |
| 423 | workspace helper_ent.plist | replaced before | exact-child validation and bounded cleanup |
| 424 | workspace helper_ent.plist | replaced after | exact-child validation and bounded cleanup |
| 425 | workspace helper_ent.plist | cleanup failure | exact-child validation and bounded cleanup |
| 426 | workspace backup_helper | absent | exact-child validation and bounded cleanup |
| 427 | workspace backup_helper | safe regular | exact-child validation and bounded cleanup |
| 428 | workspace backup_helper | symlink | exact-child validation and bounded cleanup |
| 429 | workspace backup_helper | directory | exact-child validation and bounded cleanup |
| 430 | workspace backup_helper | FIFO | exact-child validation and bounded cleanup |
| 431 | workspace backup_helper | wrong mode | exact-child validation and bounded cleanup |
| 432 | workspace backup_helper | wrong owner | exact-child validation and bounded cleanup |
| 433 | workspace backup_helper | wrong device | exact-child validation and bounded cleanup |
| 434 | workspace backup_helper | hard link | exact-child validation and bounded cleanup |
| 435 | workspace backup_helper | replaced before | exact-child validation and bounded cleanup |
| 436 | workspace backup_helper | replaced after | exact-child validation and bounded cleanup |
| 437 | workspace backup_helper | cleanup failure | exact-child validation and bounded cleanup |
| 438 | workspace signed_helper_ent.plist | absent | exact-child validation and bounded cleanup |
| 439 | workspace signed_helper_ent.plist | safe regular | exact-child validation and bounded cleanup |
| 440 | workspace signed_helper_ent.plist | symlink | exact-child validation and bounded cleanup |
| 441 | workspace signed_helper_ent.plist | directory | exact-child validation and bounded cleanup |
| 442 | workspace signed_helper_ent.plist | FIFO | exact-child validation and bounded cleanup |
| 443 | workspace signed_helper_ent.plist | wrong mode | exact-child validation and bounded cleanup |
| 444 | workspace signed_helper_ent.plist | wrong owner | exact-child validation and bounded cleanup |
| 445 | workspace signed_helper_ent.plist | wrong device | exact-child validation and bounded cleanup |
| 446 | workspace signed_helper_ent.plist | hard link | exact-child validation and bounded cleanup |
| 447 | workspace signed_helper_ent.plist | replaced before | exact-child validation and bounded cleanup |
| 448 | workspace signed_helper_ent.plist | replaced after | exact-child validation and bounded cleanup |
| 449 | workspace signed_helper_ent.plist | cleanup failure | exact-child validation and bounded cleanup |
| 450 | workspace restore_input.plist | absent | exact-child validation and bounded cleanup |
| 451 | workspace restore_input.plist | safe regular | exact-child validation and bounded cleanup |
| 452 | workspace restore_input.plist | symlink | exact-child validation and bounded cleanup |
| 453 | workspace restore_input.plist | directory | exact-child validation and bounded cleanup |
| 454 | workspace restore_input.plist | FIFO | exact-child validation and bounded cleanup |
| 455 | workspace restore_input.plist | wrong mode | exact-child validation and bounded cleanup |
| 456 | workspace restore_input.plist | wrong owner | exact-child validation and bounded cleanup |
| 457 | workspace restore_input.plist | wrong device | exact-child validation and bounded cleanup |
| 458 | workspace restore_input.plist | hard link | exact-child validation and bounded cleanup |
| 459 | workspace restore_input.plist | replaced before | exact-child validation and bounded cleanup |
| 460 | workspace restore_input.plist | replaced after | exact-child validation and bounded cleanup |
| 461 | workspace restore_input.plist | cleanup failure | exact-child validation and bounded cleanup |
| 462 | cleanup | known absent | unknown preserved; failure =>63 |
| 463 | cleanup | known regular | unknown preserved; failure =>63 |
| 464 | cleanup | known symlink | unknown preserved; failure =>63 |
| 465 | cleanup | known directory | unknown preserved; failure =>63 |
| 466 | cleanup | known FIFO | unknown preserved; failure =>63 |
| 467 | cleanup | unknown regular | unknown preserved; failure =>63 |
| 468 | cleanup | unknown symlink | unknown preserved; failure =>63 |
| 469 | cleanup | unknown directory | unknown preserved; failure =>63 |
| 470 | cleanup | nested unknown | unknown preserved; failure =>63 |
| 471 | cleanup | root inode change | unknown preserved; failure =>63 |
| 472 | cleanup | root mode change | unknown preserved; failure =>63 |
| 473 | cleanup | parent change | unknown preserved; failure =>63 |
| 474 | cleanup | rmdir failure | unknown preserved; failure =>63 |
| 475 | cleanup | after exit0 | unknown preserved; failure =>63 |
| 476 | cleanup | after exit10 | unknown preserved; failure =>63 |
| 477 | cleanup | after exit40 | unknown preserved; failure =>63 |
| 478 | normalizer | 0 | 0 |
| 479 | normalizer | 10 | 10 |
| 480 | normalizer | 20 | 20 |
| 481 | normalizer | 21 | 21 |
| 482 | normalizer | 30 | 30 |
| 483 | normalizer | 40 | 40 |
| 484 | normalizer | 50 | 50 |
| 485 | normalizer | 1 | 40 |
| 486 | normalizer | 2 | 40 |
| 487 | normalizer | 60 | 40 |
| 488 | normalizer | 61 | 40 |
| 489 | normalizer | 62 | 40 |
| 490 | normalizer | 63 | 40 |
| 491 | normalizer | 64 | 40 |
| 492 | normalizer | 65 | 40 |
| 493 | normalizer | 126 | 40 |
| 494 | normalizer | 127 | 40 |
| 495 | normalizer | 128 | 40 |
| 496 | normalizer | 137 | 40 |
| 497 | normalizer | 255 | 40 |
| 498 | passthrough | stdout unchanged | TASK-4.8 first consumer |
| 499 | passthrough | no decode | TASK-4.8 first consumer |
| 500 | passthrough | no plist parse | TASK-4.8 first consumer |
| 501 | passthrough | no base64 | TASK-4.8 first consumer |
| 502 | passthrough | no filter | TASK-4.8 first consumer |
| 503 | passthrough | no rewrite | TASK-4.8 first consumer |
| 504 | passthrough | no wrapper result | TASK-4.8 first consumer |
| 505 | passthrough | stderr separate | TASK-4.8 first consumer |
| 506 | passthrough | one normalizer | TASK-4.8 first consumer |
| 507 | passthrough | four calls | TASK-4.8 first consumer |
| 508 | non-regression | TASK-4.1 immutability | preserved |
| 509 | non-regression | TASK-4.1 framing | preserved |
| 510 | non-regression | TASK-4.2 exits | preserved |
| 511 | non-regression | TASK-4.2 Partial | preserved |
| 512 | non-regression | TASK-4.3 zero restore delete | preserved |
| 513 | non-regression | TASK-4.3 wipe delete | preserved |
| 514 | non-regression | TASK-4.4 identity | preserved |
| 515 | non-regression | TASK-4.5 add-first | preserved |
| 516 | non-regression | TASK-4.5 lookup | preserved |
| 517 | non-regression | TASK-4.5 update | preserved |
| 518 | non-regression | TASK-4.5 no fallback | preserved |
| 519 | non-regression | TASK-4.6 mktemp | preserved |
| 520 | non-regression | TASK-4.6 0700 | preserved |
| 521 | non-regression | TASK-4.6 cleanup | preserved |
| 522 | non-regression | TASK-4.6 restore snapshot | preserved |
| 523 | non-regression | manager | preserved |
| 524 | non-regression | bridge | preserved |
| 525 | non-regression | Makefile | preserved |
| 526 | non-regression | package layout | preserved |

## Shell syntax evidence
```text
C:\Program Files\Git\bin\bash.exe -n scripts/keychain_backup.sh    PASS
C:\Program Files\Git\usr\bin\bash.exe -n scripts/keychain_backup.sh    PASS
```
Grammar only; not iOS runtime proof.

## Objective-C and toolchain limitations
clang.exe/make.exe/xcrun.exe unavailable; THEOS unset. Compile/link/package PASS is not claimed. Lexical, selector, call-site, graph and import audits passed.

## Device validation pending
ldid signed output forms; rootless paths; actual system supersets; argv length; all four actions.

## CRLF, LF, NUL and final-newline audit
| File | Before CRLF | After CRLF | NUL | Final newline | Trailing whitespace |
|---|---:|---:|---:|---:|---:|
| `KeychainHelper/PXKeychainHelperResult.h` | 0 | 0 | 0 | TRUE | 0 |
| `KeychainHelper/PXKeychainHelperResult.m` | 0 | 0 | 0 | TRUE | 0 |
| `KeychainHelper/backup_helper.m` | 565 | 821 | 0 | TRUE | 0 |
| `scripts/keychain_backup.sh` | 1649 | 1829 | 0 | TRUE | 0 |
| report | 0 | 0 | 0 | TRUE | 0 |

## Full authorized production diff
Report self-diff excluded.
```diff
diff --git a/KeychainHelper/PXKeychainHelperResult.h b/KeychainHelper/PXKeychainHelperResult.h
index 220a314..07ed146 100644
--- a/KeychainHelper/PXKeychainHelperResult.h
+++ b/KeychainHelper/PXKeychainHelperResult.h
@@ -31,6 +31,9 @@ typedef NS_ERROR_ENUM(PXKeychainHelperResultErrorDomain,
     PXKeychainHelperResultErrorLimitExceeded = 6,
     PXKeychainHelperResultErrorSerializationFailed = 7,
     PXKeychainHelperResultErrorInternalInvariantFailed = 8,
+    PXKeychainHelperResultErrorInvalidAccessGroups = 9,
+    PXKeychainHelperResultErrorDuplicateAccessGroup = 10,
+    PXKeychainHelperResultErrorAccessGroupRelationInvalid = 11,
 };

 __attribute__((objc_subclassing_restricted))
@@ -45,6 +48,8 @@ __attribute__((objc_subclassing_restricted))
 @property (nonatomic, readonly) NSUInteger skippedCount;
 @property (nonatomic, readonly) NSUInteger warningCount;
 @property (nonatomic, readonly) NSUInteger errorCount;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *requestedAccessGroups;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *effectiveAccessGroups;
 @property (nonatomic, readonly) BOOL fatalErrorPresent;
 @property (nonatomic, copy, readonly) NSString *fatalErrorDomain;
 @property (nonatomic, readonly) NSInteger fatalErrorCode;
@@ -59,6 +64,8 @@ __attribute__((objc_subclassing_restricted))
                                 skippedCount:(NSUInteger)skippedCount
                                 warningCount:(NSUInteger)warningCount
                                   errorCount:(NSUInteger)errorCount
+                       requestedAccessGroups:(NSArray<NSString *> *)requestedAccessGroups
+                       effectiveAccessGroups:(NSArray<NSString *> *)effectiveAccessGroups
                                   fatalError:(NSError * _Nullable)fatalError
                                        error:(NSError * _Nullable * _Nullable)error;

diff --git a/KeychainHelper/PXKeychainHelperResult.m b/KeychainHelper/PXKeychainHelperResult.m
index 593af3e..675d376 100644
--- a/KeychainHelper/PXKeychainHelperResult.m
+++ b/KeychainHelper/PXKeychainHelperResult.m
@@ -1,16 +1,20 @@
 #import "PXKeychainHelperResult.h"
 #import <CoreFoundation/CoreFoundation.h>

-NSInteger const PXKeychainHelperResultSchemaVersion = 1;
-NSString * const PXKeychainHelperResultOutputPrefix = @"PXKEYCHAIN_HELPER_RESULT_V1=";
+NSInteger const PXKeychainHelperResultSchemaVersion = 2;
+NSString * const PXKeychainHelperResultOutputPrefix = @"PXKEYCHAIN_HELPER_RESULT_V2=";
 NSErrorDomain const PXKeychainHelperResultErrorDomain = @"com.hydra.projectx.keychain-helper-result";
 NSString * const PXKeychainHelperResultErrorFieldPathKey = @"fieldPath";

 static const NSUInteger PXKeychainHelperResultMaximumCount = 1000000;
 static const NSUInteger PXKeychainHelperResultMaximumFatalDomainBytes = 255;
-static const NSUInteger PXKeychainHelperResultMaximumBinaryPlistBytes = 16 * 1024;
-static const NSUInteger PXKeychainHelperResultMaximumBase64Bytes = 24 * 1024;
-static const NSUInteger PXKeychainHelperResultMaximumOutputLineBytes = 25 * 1024;
+static const NSUInteger PXKeychainHelperResultMaximumAccessGroupsPerArray = 128;
+static const NSUInteger PXKeychainHelperResultMaximumAccessGroupBytes = 512;
+static const NSUInteger PXKeychainHelperResultMaximumAccessGroupArrayBytes = 8 * 1024;
+static const NSUInteger PXKeychainHelperResultMaximumCombinedAccessGroupBytes = 16 * 1024;
+static const NSUInteger PXKeychainHelperResultMaximumBinaryPlistBytes = 32 * 1024;
+static const NSUInteger PXKeychainHelperResultMaximumBase64Bytes = 48 * 1024;
+static const NSUInteger PXKeychainHelperResultMaximumOutputLineBytes = 50 * 1024;

 static void PXKeychainHelperResultSetError(NSError **error,
                                             PXKeychainHelperResultErrorCode code,
@@ -74,6 +78,19 @@ static BOOL PXKeychainHelperResultCountsFitAttempted(NSUInteger attemptedCount,
     return skippedCount <= remaining;
 }

+static BOOL PXKeychainHelperResultAddWithoutOverflow(NSUInteger left,
+                                                      NSUInteger right,
+                                                      NSUInteger limit,
+                                                      NSUInteger *sumOut) {
+    if (left > limit || right > limit || right > limit - left) {
+        return NO;
+    }
+    if (sumOut) {
+        *sumOut = left + right;
+    }
+    return YES;
+}
+
 static BOOL PXKeychainHelperResultFatalDomainIsValid(NSString *domain,
                                                       NSUInteger *byteCountOut) {
     if (![domain isKindOfClass:[NSString class]] || domain.length == 0) {
@@ -101,6 +118,117 @@ static BOOL PXKeychainHelperResultFatalDomainIsValid(NSString *domain,
     return YES;
 }

+static BOOL PXKeychainHelperResultAccessGroupStringIsValid(NSString *group,
+                                                            NSUInteger *byteCountOut) {
+    if (![group isKindOfClass:[NSString class]] || group.length == 0) {
+        return NO;
+    }
+    NSData *utf8 = [group dataUsingEncoding:NSUTF8StringEncoding
+                       allowLossyConversion:NO];
+    if (!utf8 || utf8.length == 0 ||
+        utf8.length > PXKeychainHelperResultMaximumAccessGroupBytes) {
+        return NO;
+    }
+    NSString *roundTrip = [[NSString alloc] initWithData:utf8
+                                                 encoding:NSUTF8StringEncoding];
+    if (!roundTrip || ![roundTrip isEqualToString:group]) {
+        return NO;
+    }
+    unichar nulCharacter = 0;
+    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
+    if ([group rangeOfString:nulString].location != NSNotFound ||
+        [group rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound ||
+        [group rangeOfString:@","].location != NSNotFound) {
+        return NO;
+    }
+    NSCharacterSet *edgeWhitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    if (![[group stringByTrimmingCharactersInSet:edgeWhitespace] isEqualToString:group]) {
+        return NO;
+    }
+    if (byteCountOut) {
+        *byteCountOut = utf8.length;
+    }
+    return YES;
+}
+
+static NSArray<NSString *> *PXKeychainHelperResultValidatedGroupSnapshot(
+    id value,
+    NSString *fieldPath,
+    NSUInteger *byteCountOut,
+    NSError **error) {
+    if (![value isKindOfClass:[NSArray class]]) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorInvalidAccessGroups,
+                                       fieldPath,
+                                       @"The access-group field must be an array.");
+        return nil;
+    }
+    NSArray *input = (NSArray *)value;
+    if (input.count > PXKeychainHelperResultMaximumAccessGroupsPerArray) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorLimitExceeded,
+                                       fieldPath,
+                                       @"The access-group array exceeds the fixed count limit.");
+        return nil;
+    }
+
+    NSMutableArray<NSString *> *snapshot = [NSMutableArray arrayWithCapacity:input.count];
+    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:input.count];
+    NSUInteger totalBytes = 0;
+    for (NSUInteger index = 0; index < input.count; index++) {
+        id candidate = input[index];
+        NSString *elementPath = [NSString stringWithFormat:@"%@[%lu]",
+                                 fieldPath,
+                                 (unsigned long)index];
+        NSUInteger groupBytes = 0;
+        if (!PXKeychainHelperResultAccessGroupStringIsValid(candidate, &groupBytes)) {
+            PXKeychainHelperResultSetError(error,
+                                           PXKeychainHelperResultErrorInvalidAccessGroups,
+                                           elementPath,
+                                           @"An access-group element is invalid.");
+            return nil;
+        }
+        NSString *immutableGroup = [(NSString *)candidate copy];
+        if ([seen containsObject:immutableGroup]) {
+            PXKeychainHelperResultSetError(error,
+                                           PXKeychainHelperResultErrorDuplicateAccessGroup,
+                                           elementPath,
+                                           @"The access-group array contains a duplicate.");
+            return nil;
+        }
+        NSUInteger nextTotal = 0;
+        if (!PXKeychainHelperResultAddWithoutOverflow(totalBytes,
+                                                      groupBytes,
+                                                      PXKeychainHelperResultMaximumAccessGroupArrayBytes,
+                                                      &nextTotal)) {
+            PXKeychainHelperResultSetError(error,
+                                           PXKeychainHelperResultErrorLimitExceeded,
+                                           fieldPath,
+                                           @"The access-group array exceeds the fixed byte limit.");
+            return nil;
+        }
+        totalBytes = nextTotal;
+        [seen addObject:immutableGroup];
+        [snapshot addObject:immutableGroup];
+    }
+    if (byteCountOut) {
+        *byteCountOut = totalBytes;
+    }
+    return [snapshot copy];
+}
+
+static BOOL PXKeychainHelperResultRequestedGroupsAreSubset(
+    NSArray<NSString *> *requestedAccessGroups,
+    NSArray<NSString *> *effectiveAccessGroups) {
+    NSSet<NSString *> *effectiveSet = [NSSet setWithArray:effectiveAccessGroups];
+    for (NSString *group in requestedAccessGroups) {
+        if (![effectiveSet containsObject:group]) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
 static BOOL PXKeychainHelperResultIsNumber(id value) {
     return [value isKindOfClass:[NSNumber class]] &&
            CFGetTypeID((__bridge CFTypeRef)value) == CFNumberGetTypeID();
@@ -121,10 +249,12 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
     NSUInteger skippedCount,
     NSUInteger warningCount,
     NSUInteger errorCount,
+    NSArray<NSString *> *requestedAccessGroups,
+    NSArray<NSString *> *effectiveAccessGroups,
     BOOL fatalErrorPresent,
     NSString *fatalErrorDomain,
     NSInteger fatalErrorCode) {
-    if (![representation isKindOfClass:[NSDictionary class]] || representation.count != 10) {
+    if (![representation isKindOfClass:[NSDictionary class]] || representation.count != 11) {
         return NO;
     }
     NSSet<NSString *> *rootKeys = [NSSet setWithArray:@[
@@ -138,6 +268,7 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
         @"warningCount",
         @"errorCount",
         @"fatalError",
+        @"accessGroups",
     ]];
     if (![[NSSet setWithArray:representation.allKeys] isEqualToSet:rootKeys]) {
         return NO;
@@ -153,6 +284,7 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
     NSNumber *warningNumber = representation[@"warningCount"];
     NSNumber *errorNumber = representation[@"errorCount"];
     NSDictionary<NSString *, id> *fatalRepresentation = representation[@"fatalError"];
+    NSDictionary<NSString *, id> *accessGroupsRepresentation = representation[@"accessGroups"];

     if (!PXKeychainHelperResultIsNumber(schemaNumber) ||
         schemaNumber.integerValue != PXKeychainHelperResultSchemaVersion ||
@@ -171,7 +303,9 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
         !PXKeychainHelperResultIsNumber(errorNumber) ||
         errorNumber.unsignedIntegerValue != errorCount ||
         ![fatalRepresentation isKindOfClass:[NSDictionary class]] ||
-        fatalRepresentation.count != 3) {
+        fatalRepresentation.count != 3 ||
+        ![accessGroupsRepresentation isKindOfClass:[NSDictionary class]] ||
+        accessGroupsRepresentation.count != 2) {
         return NO;
     }

@@ -180,19 +314,30 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
         @"domain",
         @"code",
     ]];
-    if (![[NSSet setWithArray:fatalRepresentation.allKeys] isEqualToSet:fatalKeys]) {
+    NSSet<NSString *> *accessGroupKeys = [NSSet setWithArray:@[
+        @"requested",
+        @"effective",
+    ]];
+    if (![[NSSet setWithArray:fatalRepresentation.allKeys] isEqualToSet:fatalKeys] ||
+        ![[NSSet setWithArray:accessGroupsRepresentation.allKeys] isEqualToSet:accessGroupKeys]) {
         return NO;
     }

     NSNumber *presentNumber = fatalRepresentation[@"present"];
     NSString *domain = fatalRepresentation[@"domain"];
     NSNumber *codeNumber = fatalRepresentation[@"code"];
+    NSArray *requestedRepresentation = accessGroupsRepresentation[@"requested"];
+    NSArray *effectiveRepresentation = accessGroupsRepresentation[@"effective"];
     return PXKeychainHelperResultIsBoolean(presentNumber) &&
            presentNumber.boolValue == fatalErrorPresent &&
            [domain isKindOfClass:[NSString class]] &&
            [domain isEqualToString:fatalErrorDomain] &&
            PXKeychainHelperResultIsNumber(codeNumber) &&
-           codeNumber.integerValue == fatalErrorCode;
+           codeNumber.integerValue == fatalErrorCode &&
+           [requestedRepresentation isKindOfClass:[NSArray class]] &&
+           [requestedRepresentation isEqualToArray:requestedAccessGroups] &&
+           [effectiveRepresentation isKindOfClass:[NSArray class]] &&
+           [effectiveRepresentation isEqualToArray:effectiveAccessGroups];
 }

 @interface PXKeychainHelperResult ()
@@ -205,6 +350,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
                         skippedCount:(NSUInteger)skippedCount
                         warningCount:(NSUInteger)warningCount
                           errorCount:(NSUInteger)errorCount
+               requestedAccessGroups:(NSArray<NSString *> *)requestedAccessGroups
+               effectiveAccessGroups:(NSArray<NSString *> *)effectiveAccessGroups
                    fatalErrorPresent:(BOOL)fatalErrorPresent
                     fatalErrorDomain:(NSString *)fatalErrorDomain
                       fatalErrorCode:(NSInteger)fatalErrorCode
@@ -223,6 +370,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
                        skippedCount:(NSUInteger)skippedCount
                        warningCount:(NSUInteger)warningCount
                          errorCount:(NSUInteger)errorCount
+              requestedAccessGroups:(NSArray<NSString *> *)requestedAccessGroups
+              effectiveAccessGroups:(NSArray<NSString *> *)effectiveAccessGroups
                          fatalError:(NSError *)fatalError
                               error:(NSError **)error {
     if (error) {
@@ -310,6 +459,44 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
         return nil;
     }

+    NSUInteger requestedBytes = 0;
+    NSArray<NSString *> *immutableRequested = PXKeychainHelperResultValidatedGroupSnapshot(
+        requestedAccessGroups,
+        @"$.accessGroups.requested",
+        &requestedBytes,
+        error);
+    if (!immutableRequested) {
+        return nil;
+    }
+    NSUInteger effectiveBytes = 0;
+    NSArray<NSString *> *immutableEffective = PXKeychainHelperResultValidatedGroupSnapshot(
+        effectiveAccessGroups,
+        @"$.accessGroups.effective",
+        &effectiveBytes,
+        error);
+    if (!immutableEffective) {
+        return nil;
+    }
+    NSUInteger combinedBytes = 0;
+    if (!PXKeychainHelperResultAddWithoutOverflow(requestedBytes,
+                                                  effectiveBytes,
+                                                  PXKeychainHelperResultMaximumCombinedAccessGroupBytes,
+                                                  &combinedBytes)) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorLimitExceeded,
+                                       @"$.accessGroups",
+                                       @"The combined access-group fields exceed the fixed byte limit.");
+        return nil;
+    }
+    (void)combinedBytes;
+    if (!PXKeychainHelperResultRequestedGroupsAreSubset(immutableRequested, immutableEffective)) {
+        PXKeychainHelperResultSetError(error,
+                                       PXKeychainHelperResultErrorAccessGroupRelationInvalid,
+                                       @"$.accessGroups.requested",
+                                       @"The requested access-group set is not contained in the effective set.");
+        return nil;
+    }
+
     BOOL fatalErrorPresent = fatalError != nil;
     NSString *fatalErrorDomain = @"";
     NSInteger fatalErrorCode = 0;
@@ -334,12 +521,16 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
         fatalErrorCode = fatalError.code;
     }

-    NSDictionary<NSString *, id> *fatalRepresentation = @{
+    NSDictionary<NSString *, id> *fatalRepresentation = [@{
         @"present": @(fatalErrorPresent),
         @"domain": [fatalErrorDomain copy],
         @"code": @(fatalErrorCode),
-    };
-    NSDictionary<NSString *, id> *snapshot = @{
+    } copy];
+    NSDictionary<NSString *, id> *accessGroupsRepresentation = [@{
+        @"requested": [immutableRequested copy],
+        @"effective": [immutableEffective copy],
+    } copy];
+    NSDictionary<NSString *, id> *snapshot = [@{
         @"schemaVersion": @(PXKeychainHelperResultSchemaVersion),
         @"operation": [operationString copy],
         @"completion": [completionString copy],
@@ -349,9 +540,9 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
         @"skippedCount": @(skippedCount),
         @"warningCount": @(warningCount),
         @"errorCount": @(errorCount),
-        @"fatalError": [fatalRepresentation copy],
-    };
-    snapshot = [snapshot copy];
+        @"fatalError": fatalRepresentation,
+        @"accessGroups": accessGroupsRepresentation,
+    } copy];

     if (!PXKeychainHelperResultRepresentationMatchesState(snapshot,
                                                            operation,
@@ -362,6 +553,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
                                                            skippedCount,
                                                            warningCount,
                                                            errorCount,
+                                                           immutableRequested,
+                                                           immutableEffective,
                                                            fatalErrorPresent,
                                                            fatalErrorDomain,
                                                            fatalErrorCode)) {
@@ -433,6 +626,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
                                                            skippedCount,
                                                            warningCount,
                                                            errorCount,
+                                                           immutableRequested,
+                                                           immutableEffective,
                                                            fatalErrorPresent,
                                                            fatalErrorDomain,
                                                            fatalErrorCode)) {
@@ -476,6 +671,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
                                                skippedCount:skippedCount
                                                warningCount:warningCount
                                                  errorCount:errorCount
+                                      requestedAccessGroups:immutableRequested
+                                      effectiveAccessGroups:immutableEffective
                                           fatalErrorPresent:fatalErrorPresent
                                            fatalErrorDomain:fatalErrorDomain
                                              fatalErrorCode:fatalErrorCode
@@ -498,6 +695,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
                         skippedCount:(NSUInteger)skippedCount
                         warningCount:(NSUInteger)warningCount
                           errorCount:(NSUInteger)errorCount
+               requestedAccessGroups:(NSArray<NSString *> *)requestedAccessGroups
+               effectiveAccessGroups:(NSArray<NSString *> *)effectiveAccessGroups
                    fatalErrorPresent:(BOOL)fatalErrorPresent
                     fatalErrorDomain:(NSString *)fatalErrorDomain
                       fatalErrorCode:(NSInteger)fatalErrorCode
@@ -514,6 +713,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
         _skippedCount = skippedCount;
         _warningCount = warningCount;
         _errorCount = errorCount;
+        _requestedAccessGroups = [requestedAccessGroups copy];
+        _effectiveAccessGroups = [effectiveAccessGroups copy];
         _fatalErrorPresent = fatalErrorPresent;
         _fatalErrorDomain = [fatalErrorDomain copy];
         _fatalErrorCode = fatalErrorCode;
@@ -545,6 +746,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
            self.skippedCount == other.skippedCount &&
            self.warningCount == other.warningCount &&
            self.errorCount == other.errorCount &&
+           [self.requestedAccessGroups isEqualToArray:other.requestedAccessGroups] &&
+           [self.effectiveAccessGroups isEqualToArray:other.effectiveAccessGroups] &&
            self.fatalErrorPresent == other.fatalErrorPresent &&
            [self.fatalErrorDomain isEqualToString:other.fatalErrorDomain] &&
            self.fatalErrorCode == other.fatalErrorCode &&
@@ -555,6 +758,8 @@ static BOOL PXKeychainHelperResultRepresentationMatchesState(
 - (NSUInteger)hash {
     NSUInteger value = self.propertyListRepresentation.hash;
     value ^= self.machineReadableLine.hash;
+    value ^= self.requestedAccessGroups.hash;
+    value ^= self.effectiveAccessGroups.hash;
     value ^= self.fatalErrorDomain.hash;
     value ^= (NSUInteger)self.schemaVersion;
     value ^= (NSUInteger)self.operation;
diff --git a/KeychainHelper/backup_helper.m b/KeychainHelper/backup_helper.m
index d851deb..3fce950 100644
--- a/KeychainHelper/backup_helper.m
+++ b/KeychainHelper/backup_helper.m
@@ -1,12 +1,6 @@
 /**
  * backup_helper - iOS Keychain Backup/Restore CLI Tool
  *
- * Usage:
- *   backup_helper --action backup --target <bundleID> --file <path>
- *   backup_helper --action restore --file <path> [--overwrite]
- *   backup_helper --action wipe --target <bundleID>
- *   backup_helper --action list --target <bundleID>
- *
  * This tool must be resigned with the target app's keychain-access-groups
  * entitlements before running. Use the keychain_backup.sh wrapper script.
  *
@@ -21,6 +15,7 @@
  */

 #import <Foundation/Foundation.h>
+#import <sys/stat.h>
 #import "KeychainBackupHelper.h"
 #import "PXKeychainHelperExitCode.h"
 #import "PXKeychainHelperResult.h"
@@ -33,19 +28,27 @@ typedef NS_ENUM(NSInteger, PXHelperAction) {
     PXHelperActionList,
 };

+static const NSUInteger PXHelperMaximumAccessGroups = 128;
+static const NSUInteger PXHelperMaximumAccessGroupBytes = 512;
+static const NSUInteger PXHelperMaximumAccessGroupCSVBytes = 8 * 1024;
+static const NSUInteger PXHelperMaximumEntitlementsFileBytes = 64 * 1024;
+static const NSUInteger PXHelperMaximumPathBytes = 4 * 1024;
+
 static void printUsage(const char *progname) {
     fprintf(stderr, "Usage:\n");
-    fprintf(stderr, "  %s --action backup --file <path> [--groups <group1,group2,...>]\n", progname);
-    fprintf(stderr, "  %s --action restore --file <path> [--overwrite]\n", progname);
-    fprintf(stderr, "  %s --action wipe --groups <group1,group2,...>\n", progname);
-    fprintf(stderr, "  %s --action list --groups <group1,group2,...>\n", progname);
+    fprintf(stderr, "  %s --action backup --file <path> --groups <groups> --requested-groups <groups> --effective-entitlements-file <path>\n", progname);
+    fprintf(stderr, "  %s --action restore --file <path> --requested-groups <groups> --effective-entitlements-file <path> [--overwrite]\n", progname);
+    fprintf(stderr, "  %s --action wipe --groups <groups> --requested-groups <groups> --effective-entitlements-file <path>\n", progname);
+    fprintf(stderr, "  %s --action list --groups <groups> --requested-groups <groups> --effective-entitlements-file <path>\n", progname);
     fprintf(stderr, "\nOptions:\n");
-    fprintf(stderr, "  --action <action>   Action to perform: backup, restore, wipe, list\n");
-    fprintf(stderr, "  --file <path>       Path to backup/restore file (plist format)\n");
-    fprintf(stderr, "  --groups <groups>   Comma-separated list of keychain access groups\n");
-    fprintf(stderr, "  --overwrite         For restore: update one exact existing item in place; never delete\n");
-    fprintf(stderr, "  --verbose           Print detailed progress information\n");
-    fprintf(stderr, "  --help              Show this help message\n");
+    fprintf(stderr, "  --action <action>                     Action: backup, restore, wipe, list\n");
+    fprintf(stderr, "  --file <path>                         Backup/restore plist path\n");
+    fprintf(stderr, "  --groups <groups>                     Canonical operational access groups\n");
+    fprintf(stderr, "  --requested-groups <groups>           Canonical requested access-group report\n");
+    fprintf(stderr, "  --effective-entitlements-file <path>  Signed-helper entitlement snapshot\n");
+    fprintf(stderr, "  --overwrite                           Restore exact existing items in place\n");
+    fprintf(stderr, "  --verbose                             Print detailed progress information\n");
+    fprintf(stderr, "  --help                                Show this help message\n");
 }

 static PXHelperAction parseAction(NSString *actionStr) {
@@ -56,19 +59,6 @@ static PXHelperAction parseAction(NSString *actionStr) {
     return PXHelperActionUnknown;
 }

-static NSArray<NSString *> *parseGroups(NSString *groupsStr) {
-    if (!groupsStr.length) return @[];
-    NSArray *parts = [groupsStr componentsSeparatedByString:@","];
-    NSMutableArray *groups = [NSMutableArray array];
-    for (NSString *part in parts) {
-        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
-        if (trimmed.length) {
-            [groups addObject:trimmed];
-        }
-    }
-    return groups;
-}
-
 static void logVerbose(BOOL verbose, NSString *format, ...) {
     if (!verbose) return;
     va_list args;
@@ -98,53 +88,258 @@ static NSString *PXHexStringFromData(NSData *data) {
     if (![data isKindOfClass:[NSData class]] || data.length == 0) return @"";
     const unsigned char *bytes = (const unsigned char *)data.bytes;
     NSUInteger len = data.length;
-    // Cap to avoid huge logs
     NSUInteger maxLen = MIN(len, 32);
     NSMutableString *hex = [NSMutableString stringWithCapacity:maxLen * 2];
     for (NSUInteger i = 0; i < maxLen; i++) {
         [hex appendFormat:@"%02x", bytes[i]];
     }
     if (len > maxLen) {
-        [hex appendString:@"..." ];
+        [hex appendString:@"..."];
     }
     return hex;
 }

-static NSString *PXSafeString(id v) {
-    if (!v || v == (id)kCFNull) return @"";
-    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
-    if ([v isKindOfClass:[NSData class]]) {
-        NSString *s = [[NSString alloc] initWithData:(NSData *)v encoding:NSUTF8StringEncoding];
-        if (s.length) return s;
-        return [NSString stringWithFormat:@"<data:%@>", PXHexStringFromData((NSData *)v)];
+static NSString *PXSafeString(id value) {
+    if (!value || value == (id)kCFNull) return @"";
+    if ([value isKindOfClass:[NSString class]]) return (NSString *)value;
+    if ([value isKindOfClass:[NSData class]]) {
+        NSString *string = [[NSString alloc] initWithData:(NSData *)value encoding:NSUTF8StringEncoding];
+        if (string.length) return string;
+        return [NSString stringWithFormat:@"<data:%@>", PXHexStringFromData((NSData *)value)];
+    }
+    if ([value respondsToSelector:@selector(stringValue)]) {
+        NSString *string = [value performSelector:@selector(stringValue)];
+        if ([string isKindOfClass:[NSString class]] && string.length) return string;
+    }
+    return [[value description] ?: @"" copy];
+}
+
+static BOOL PXHelperAddWithoutOverflow(NSUInteger left,
+                                       NSUInteger right,
+                                       NSUInteger limit,
+                                       NSUInteger *sumOut) {
+    if (left > limit || right > limit || right > limit - left) {
+        return NO;
     }
-    if ([v respondsToSelector:@selector(stringValue)]) {
-        NSString *s = [v performSelector:@selector(stringValue)];
-        if ([s isKindOfClass:[NSString class]] && s.length) return s;
+    if (sumOut) {
+        *sumOut = left + right;
     }
-    return [[v description] ?: @"" copy];
+    return YES;
+}
+
+static BOOL PXHelperAccessGroupIsValid(NSString *group, NSUInteger *byteCountOut) {
+    if (![group isKindOfClass:[NSString class]] || group.length == 0) {
+        return NO;
+    }
+    NSData *utf8 = [group dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!utf8 || utf8.length == 0 || utf8.length > PXHelperMaximumAccessGroupBytes) {
+        return NO;
+    }
+    NSString *roundTrip = [[NSString alloc] initWithData:utf8 encoding:NSUTF8StringEncoding];
+    if (!roundTrip || ![roundTrip isEqualToString:group]) {
+        return NO;
+    }
+    unichar nulCharacter = 0;
+    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
+    if ([group rangeOfString:nulString].location != NSNotFound ||
+        [group rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound ||
+        [group rangeOfString:@","].location != NSNotFound) {
+        return NO;
+    }
+    if (![[group stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
+          isEqualToString:group]) {
+        return NO;
+    }
+    if (byteCountOut) {
+        *byteCountOut = utf8.length;
+    }
+    return YES;
+}
+
+static NSArray<NSString *> *PXCanonicalAccessGroupsFromCSV(NSString *csv,
+                                                            NSError **error) {
+    if (error) *error = nil;
+    if (![csv isKindOfClass:[NSString class]] || csv.length == 0) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidArguments
+                                            userInfo:nil];
+        return nil;
+    }
+    NSData *csvBytes = [csv dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!csvBytes || csvBytes.length == 0 || csvBytes.length > PXHelperMaximumAccessGroupCSVBytes ||
+        [csv rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidArguments
+                                            userInfo:nil];
+        return nil;
+    }
+
+    NSArray<NSString *> *parts = [csv componentsSeparatedByString:@","];
+    if (parts.count == 0 || parts.count > PXHelperMaximumAccessGroups) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidArguments
+                                            userInfo:nil];
+        return nil;
+    }
+    NSMutableArray<NSString *> *groups = [NSMutableArray arrayWithCapacity:parts.count];
+    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:parts.count];
+    NSUInteger totalBytes = 0;
+    for (NSString *part in parts) {
+        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
+        NSUInteger groupBytes = 0;
+        if (!PXHelperAccessGroupIsValid(trimmed, &groupBytes)) {
+            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                    code:PXKeychainBackupErrorInvalidArguments
+                                                userInfo:nil];
+            return nil;
+        }
+        NSUInteger nextTotal = 0;
+        if (!PXHelperAddWithoutOverflow(totalBytes,
+                                        groupBytes,
+                                        PXHelperMaximumAccessGroupCSVBytes,
+                                        &nextTotal)) {
+            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                    code:PXKeychainBackupErrorInvalidArguments
+                                                userInfo:nil];
+            return nil;
+        }
+        totalBytes = nextTotal;
+        NSString *immutableGroup = [trimmed copy];
+        if (![seen containsObject:immutableGroup]) {
+            [seen addObject:immutableGroup];
+            [groups addObject:immutableGroup];
+        }
+    }
+    if (groups.count == 0 || groups.count > PXHelperMaximumAccessGroups) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidArguments
+                                            userInfo:nil];
+        return nil;
+    }
+    return [groups copy];
+}
+
+static NSArray<NSString *> *PXEffectiveAccessGroupsFromEntitlementsFile(NSString *filePath,
+                                                                         NSError **error) {
+    if (error) *error = nil;
+    if (![filePath isKindOfClass:[NSString class]] || filePath.length == 0) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidBackupFile
+                                            userInfo:nil];
+        return nil;
+    }
+    NSData *pathBytes = [filePath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    if (!pathBytes || pathBytes.length == 0 || pathBytes.length > PXHelperMaximumPathBytes ||
+        [filePath rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidBackupFile
+                                            userInfo:nil];
+        return nil;
+    }
+
+    struct stat fileStatus;
+    if (lstat(filePath.fileSystemRepresentation, &fileStatus) != 0 ||
+        !S_ISREG(fileStatus.st_mode) || fileStatus.st_size <= 0 ||
+        (unsigned long long)fileStatus.st_size > PXHelperMaximumEntitlementsFileBytes) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidBackupFile
+                                            userInfo:nil];
+        return nil;
+    }
+
+    NSError *readError = nil;
+    NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:&readError];
+    if (!data || readError || data.length == 0 || data.length > PXHelperMaximumEntitlementsFileBytes ||
+        data.length != (NSUInteger)fileStatus.st_size) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidBackupFile
+                                            userInfo:nil];
+        return nil;
+    }
+
+    NSPropertyListFormat format = NSPropertyListOpenStepFormat;
+    NSError *plistError = nil;
+    id plist = [NSPropertyListSerialization propertyListWithData:data
+                                                         options:NSPropertyListImmutable
+                                                          format:&format
+                                                           error:&plistError];
+    if (plistError || ![plist isKindOfClass:[NSDictionary class]]) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidBackupFile
+                                            userInfo:nil];
+        return nil;
+    }
+    id rawGroups = ((NSDictionary *)plist)[@"keychain-access-groups"];
+    if (![rawGroups isKindOfClass:[NSArray class]] || [(NSArray *)rawGroups count] == 0 ||
+        [(NSArray *)rawGroups count] > PXHelperMaximumAccessGroups) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidBackupFile
+                                            userInfo:nil];
+        return nil;
+    }
+
+    NSMutableArray<NSString *> *groups = [NSMutableArray arrayWithCapacity:[(NSArray *)rawGroups count]];
+    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:[(NSArray *)rawGroups count]];
+    NSUInteger totalBytes = 0;
+    for (id value in (NSArray *)rawGroups) {
+        NSUInteger groupBytes = 0;
+        if (!PXHelperAccessGroupIsValid(value, &groupBytes)) {
+            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                    code:PXKeychainBackupErrorInvalidBackupFile
+                                                userInfo:nil];
+            return nil;
+        }
+        NSUInteger nextTotal = 0;
+        if (!PXHelperAddWithoutOverflow(totalBytes,
+                                        groupBytes,
+                                        PXHelperMaximumAccessGroupCSVBytes,
+                                        &nextTotal)) {
+            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                    code:PXKeychainBackupErrorInvalidBackupFile
+                                                userInfo:nil];
+            return nil;
+        }
+        totalBytes = nextTotal;
+        NSString *immutableGroup = [(NSString *)value copy];
+        if (![seen containsObject:immutableGroup]) {
+            [seen addObject:immutableGroup];
+            [groups addObject:immutableGroup];
+        }
+    }
+    if (groups.count == 0) {
+        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
+                                                code:PXKeychainBackupErrorInvalidBackupFile
+                                            userInfo:nil];
+        return nil;
+    }
+    return [groups copy];
+}
+
+static BOOL PXRequestedGroupsAreSubsetOfEffectiveGroups(
+    NSArray<NSString *> *requested,
+    NSArray<NSString *> *effective) {
+    NSSet<NSString *> *effectiveSet = [NSSet setWithArray:effective];
+    for (NSString *group in requested) {
+        if (![effectiveSet containsObject:group]) {
+            return NO;
+        }
+    }
+    return YES;
 }

 static PXKeychainHelperOperation PXStructuredOperationForAction(PXHelperAction action) {
     switch (action) {
-        case PXHelperActionBackup:
-            return PXKeychainHelperOperationBackup;
-        case PXHelperActionRestore:
-            return PXKeychainHelperOperationRestore;
-        case PXHelperActionWipe:
-            return PXKeychainHelperOperationWipe;
-        case PXHelperActionList:
-            return PXKeychainHelperOperationList;
-        case PXHelperActionUnknown:
-            return PXKeychainHelperOperationUnknown;
+        case PXHelperActionBackup: return PXKeychainHelperOperationBackup;
+        case PXHelperActionRestore: return PXKeychainHelperOperationRestore;
+        case PXHelperActionWipe: return PXKeychainHelperOperationWipe;
+        case PXHelperActionList: return PXKeychainHelperOperationList;
+        case PXHelperActionUnknown: return PXKeychainHelperOperationUnknown;
     }
     return PXKeychainHelperOperationUnknown;
 }

 static PXKeychainHelperCompletion PXStructuredCompletionForResult(PXKeychainBackupResult *result) {
-    if (!result) {
-        return PXKeychainHelperCompletionFailed;
-    }
+    if (!result) return PXKeychainHelperCompletionFailed;
     if (result.itemsFailed > 0 || result.warnings.count > 0 || result.errors.count > 0) {
         return PXKeychainHelperCompletionPartial;
     }
@@ -160,7 +355,6 @@ static PXKeychainHelperExitCode PXExitCodeForFatalError(PXKeychainHelperOperatio
     if (![fatalError.domain isEqualToString:PXKeychainBackupErrorDomain]) {
         return PXKeychainHelperExitCodeOperationFailed;
     }
-
     switch ((PXKeychainBackupErrorCode)fatalError.code) {
         case PXKeychainBackupErrorInvalidArguments:
         case PXKeychainBackupErrorNoAccessGroups:
@@ -178,11 +372,14 @@ static PXKeychainHelperExitCode PXExitCodeForFatalError(PXKeychainHelperOperatio
     return PXKeychainHelperExitCodeOperationFailed;
 }

-static PXKeychainHelperResult *PXCreateStructuredResult(PXKeychainHelperOperation operation,
-                                                        PXKeychainHelperCompletion completion,
-                                                        PXKeychainBackupResult *result,
-                                                        NSUInteger listCount,
-                                                        NSError *fatalError) {
+static PXKeychainHelperResult *PXCreateStructuredResult(
+    PXKeychainHelperOperation operation,
+    PXKeychainHelperCompletion completion,
+    PXKeychainBackupResult *result,
+    NSUInteger listCount,
+    NSArray<NSString *> *requestedAccessGroups,
+    NSArray<NSString *> *effectiveAccessGroups,
+    NSError *fatalError) {
     NSUInteger attemptedCount = 0;
     NSUInteger succeededCount = 0;
     NSUInteger failedCount = 0;
@@ -210,6 +407,8 @@ static PXKeychainHelperResult *PXCreateStructuredResult(PXKeychainHelperOperatio
                                        skippedCount:0
                                        warningCount:warningCount
                                          errorCount:errorCount
+                              requestedAccessGroups:requestedAccessGroups ?: @[]
+                              effectiveAccessGroups:effectiveAccessGroups ?: @[]
                                          fatalError:fatalError
                                               error:&constructionError];
     (void)constructionError;
@@ -219,7 +418,7 @@ static PXKeychainHelperResult *PXCreateStructuredResult(PXKeychainHelperOperatio
 static void PXEmitStructuredResult(PXKeychainHelperResult *result) {
     NSString *line = result.machineReadableLine;
     if (!line.length) {
-        line = @"PXKEYCHAIN_HELPER_RESULT_V1=INVALID";
+        line = @"PXKEYCHAIN_HELPER_RESULT_V2=INVALID";
     }
     fprintf(stdout, "%s\n", [line UTF8String] ?: "");
     fflush(stdout);
@@ -233,7 +432,6 @@ static PXKeychainHelperExitCode PXFinalizeStructuredResult(
                       line.length > PXKeychainHelperResultOutputPrefix.length &&
                       [line hasPrefix:PXKeychainHelperResultOutputPrefix] &&
                       [line rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location == NSNotFound;
-
     if (compatible) {
         switch (result.completion) {
             case PXKeychainHelperCompletionCompleted:
@@ -253,206 +451,279 @@ static PXKeychainHelperExitCode PXFinalizeStructuredResult(
                 break;
         }
     }
-
     PXEmitStructuredResult(compatible ? result : nil);
     return compatible ? intendedExitCode : PXKeychainHelperExitCodeProtocolFailure;
 }

+static PXKeychainHelperExitCode PXFinalizeFailure(
+    PXKeychainHelperOperation operation,
+    PXKeychainHelperExitCode exitCode,
+    NSArray<NSString *> *requestedAccessGroups,
+    NSArray<NSString *> *effectiveAccessGroups,
+    PXKeychainBackupErrorCode errorCode) {
+    return PXFinalizeStructuredResult(
+        PXCreateStructuredResult(operation,
+                                 PXKeychainHelperCompletionFailed,
+                                 nil,
+                                 0,
+                                 requestedAccessGroups ?: @[],
+                                 effectiveAccessGroups ?: @[],
+                                 PXStructuredSyntheticError(errorCode)),
+        exitCode);
+}
+
 int main(int argc, const char *argv[]) {
     @autoreleasepool {
-        // Parse arguments.
-        NSMutableDictionary *args = [NSMutableDictionary dictionary];
-
+        NSMutableDictionary<NSString *, id> *args = [NSMutableDictionary dictionary];
+        NSMutableSet<NSString *> *seenOptions = [NSMutableSet set];
+        NSSet<NSString *> *valueOptions = [NSSet setWithArray:@[
+            @"action",
+            @"file",
+            @"groups",
+            @"requested-groups",
+            @"effective-entitlements-file",
+        ]];
+        BOOL argumentParseFailed = NO;
+
         for (int i = 1; i < argc; i++) {
-            NSString *arg = @(argv[i]);
-
-            if ([arg isEqualToString:@"--help"] || [arg isEqualToString:@"-h"]) {
+            NSString *argument = @(argv[i]);
+            if ([argument isEqualToString:@"--help"] || [argument isEqualToString:@"-h"]) {
                 printUsage(argv[0]);
                 return PXKeychainHelperExitCodeCompleted;
-            } else if ([arg isEqualToString:@"--verbose"] || [arg isEqualToString:@"-v"]) {
-                args[@"verbose"] = @YES;
-            } else if ([arg isEqualToString:@"--overwrite"]) {
-                args[@"overwrite"] = @YES;
-            } else if ([arg hasPrefix:@"--"] && i + 1 < argc) {
-                NSString *key = [arg substringFromIndex:2];
-                NSString *value = @(argv[++i]);
-                args[key] = value;
             }
+            if ([argument isEqualToString:@"--verbose"] || [argument isEqualToString:@"-v"] ||
+                [argument isEqualToString:@"--overwrite"]) {
+                NSString *key = [argument isEqualToString:@"--overwrite"] ? @"overwrite" : @"verbose";
+                if ([seenOptions containsObject:key]) {
+                    argumentParseFailed = YES;
+                    break;
+                }
+                [seenOptions addObject:key];
+                args[key] = @YES;
+                continue;
+            }
+            if (![argument hasPrefix:@"--"]) {
+                argumentParseFailed = YES;
+                break;
+            }
+            NSString *key = [argument substringFromIndex:2];
+            if (![valueOptions containsObject:key] || [seenOptions containsObject:key] ||
+                i + 1 >= argc) {
+                argumentParseFailed = YES;
+                break;
+            }
+            NSString *value = @(argv[i + 1]);
+            [seenOptions addObject:key];
+            args[key] = value;
+            i++;
         }
-
-        BOOL verbose = [args[@"verbose"] boolValue];
-
-        // Validate action.
-        NSString *actionStr = args[@"action"];
-        if (!actionStr.length) {
+
+        NSString *actionString = args[@"action"];
+        PXHelperAction action = parseAction(actionString);
+        PXKeychainHelperOperation structuredOperation = PXStructuredOperationForAction(action);
+        NSArray<NSString *> *emptyGroups = @[];
+        if (argumentParseFailed) {
+            logError(@"Invalid or duplicate command-line argument");
+            return PXFinalizeFailure(structuredOperation,
+                                     PXKeychainHelperExitCodeInvalidArguments,
+                                     emptyGroups,
+                                     emptyGroups,
+                                     PXKeychainBackupErrorInvalidArguments);
+        }
+        if (!actionString.length) {
             logError(@"Missing required --action argument");
             printUsage(argv[0]);
-            return PXFinalizeStructuredResult(
-                PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
-                                         PXKeychainHelperCompletionFailed,
-                                         nil,
-                                         0,
-                                         PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
-                PXKeychainHelperExitCodeInvalidArguments);
+            return PXFinalizeFailure(PXKeychainHelperOperationUnknown,
+                                     PXKeychainHelperExitCodeInvalidArguments,
+                                     emptyGroups,
+                                     emptyGroups,
+                                     PXKeychainBackupErrorInvalidArguments);
         }
-
-        PXHelperAction action = parseAction(actionStr);
         if (action == PXHelperActionUnknown) {
-            logError(@"Unknown action: %@", actionStr);
+            logError(@"Unknown action");
             printUsage(argv[0]);
-            return PXFinalizeStructuredResult(
-                PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
-                                         PXKeychainHelperCompletionFailed,
-                                         nil,
-                                         0,
-                                         PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
-                PXKeychainHelperExitCodeInvalidArguments);
+            return PXFinalizeFailure(PXKeychainHelperOperationUnknown,
+                                     PXKeychainHelperExitCodeInvalidArguments,
+                                     emptyGroups,
+                                     emptyGroups,
+                                     PXKeychainBackupErrorInvalidArguments);
         }
-        PXKeychainHelperOperation structuredOperation = PXStructuredOperationForAction(action);
-
+
+        NSString *requestedCSV = args[@"requested-groups"];
+        NSString *effectiveEntitlementsPath = args[@"effective-entitlements-file"];
+        if (![requestedCSV isKindOfClass:[NSString class]] ||
+            ![effectiveEntitlementsPath isKindOfClass:[NSString class]]) {
+            logError(@"Missing required group-report metadata");
+            return PXFinalizeFailure(structuredOperation,
+                                     PXKeychainHelperExitCodeInvalidArguments,
+                                     emptyGroups,
+                                     emptyGroups,
+                                     PXKeychainBackupErrorInvalidArguments);
+        }
+
+        NSError *metadataError = nil;
+        NSArray<NSString *> *requestedAccessGroups =
+            PXCanonicalAccessGroupsFromCSV(requestedCSV, &metadataError);
+        if (!requestedAccessGroups) {
+            logError(@"Invalid requested access-group metadata");
+            return PXFinalizeFailure(structuredOperation,
+                                     PXKeychainHelperExitCodeInvalidArguments,
+                                     emptyGroups,
+                                     emptyGroups,
+                                     PXKeychainBackupErrorInvalidArguments);
+        }
+        NSArray<NSString *> *effectiveAccessGroups =
+            PXEffectiveAccessGroupsFromEntitlementsFile(effectiveEntitlementsPath, &metadataError);
+        if (!effectiveAccessGroups ||
+            !PXRequestedGroupsAreSubsetOfEffectiveGroups(requestedAccessGroups, effectiveAccessGroups)) {
+            logError(@"Invalid effective access-group metadata");
+            return PXFinalizeFailure(structuredOperation,
+                                     PXKeychainHelperExitCodeInvalidInput,
+                                     emptyGroups,
+                                     emptyGroups,
+                                     PXKeychainBackupErrorInvalidBackupFile);
+        }
+
         NSString *filePath = args[@"file"];
-        NSArray<NSString *> *groups = parseGroups(args[@"groups"]);
+        NSString *operationalCSV = args[@"groups"];
+        NSArray<NSString *> *operationalGroups = nil;
+        if (action == PXHelperActionRestore && operationalCSV != nil) {
+            logError(@"Restore does not accept operational access groups");
+            return PXFinalizeFailure(structuredOperation,
+                                     PXKeychainHelperExitCodeInvalidArguments,
+                                     requestedAccessGroups,
+                                     effectiveAccessGroups,
+                                     PXKeychainBackupErrorInvalidArguments);
+        }
+        if (action == PXHelperActionBackup || action == PXHelperActionWipe || action == PXHelperActionList) {
+            operationalGroups = PXCanonicalAccessGroupsFromCSV(operationalCSV, &metadataError);
+            if (!operationalGroups ||
+                ![operationalGroups isEqualToArray:requestedAccessGroups]) {
+                logError(@"Operational access groups do not match requested metadata");
+                return PXFinalizeFailure(structuredOperation,
+                                         PXKeychainHelperExitCodeInvalidArguments,
+                                         requestedAccessGroups,
+                                         effectiveAccessGroups,
+                                         PXKeychainBackupErrorInvalidArguments);
+            }
+        }
+
+        BOOL verbose = [args[@"verbose"] boolValue];
         BOOL overwrite = [args[@"overwrite"] boolValue];
-
-        logVerbose(verbose, @"Action: %@", actionStr);
-        logVerbose(verbose, @"File: %@", filePath ?: @"(none)");
-        logVerbose(verbose, @"Groups: %@", [groups componentsJoinedByString:@", "] ?: @"(none)");
-
+        logVerbose(verbose, @"Group-report metadata accepted");
+
         NSError *error = nil;
         PXKeychainBackupResult *result = nil;
-
         switch (action) {
             case PXHelperActionBackup: {
                 if (!filePath.length) {
                     logError(@"--file is required for backup");
-                    return PXFinalizeStructuredResult(
-                        PXCreateStructuredResult(structuredOperation,
-                                                 PXKeychainHelperCompletionFailed,
-                                                 nil,
-                                                 0,
-                                                 PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
-                        PXKeychainHelperExitCodeInvalidArguments);
+                    return PXFinalizeFailure(structuredOperation,
+                                             PXKeychainHelperExitCodeInvalidArguments,
+                                             requestedAccessGroups,
+                                             effectiveAccessGroups,
+                                             PXKeychainBackupErrorInvalidArguments);
                 }
-                if (!groups.count) {
-                    logError(@"--groups is required for backup");
-                    return PXFinalizeStructuredResult(
-                        PXCreateStructuredResult(structuredOperation,
-                                                 PXKeychainHelperCompletionFailed,
-                                                 nil,
-                                                 0,
-                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
-                        PXKeychainHelperExitCodeInvalidArguments);
-                }
-
                 logVerbose(verbose, @"Starting keychain backup...");
                 result = [KeychainBackupHelper backupKeychainToFile:filePath
-                                                       accessGroups:groups
+                                                       accessGroups:operationalGroups
                                                         itemClasses:PXKeychainItemClassAll
                                                               error:&error];
-
                 if (!result) {
                     logError(@"Backup failed: %@", error.localizedDescription);
                     NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
-                    PXKeychainHelperExitCode exitCode =
-                        PXExitCodeForFatalError(structuredOperation, fatalError);
+                    PXKeychainHelperExitCode exitCode = PXExitCodeForFatalError(structuredOperation, fatalError);
                     return PXFinalizeStructuredResult(
                         PXCreateStructuredResult(structuredOperation,
                                                  PXKeychainHelperCompletionFailed,
                                                  nil,
                                                  0,
+                                                 requestedAccessGroups,
+                                                 effectiveAccessGroups,
                                                  fatalError),
                         exitCode);
                 }
-
                 logSuccess(@"Backup complete: %lu items processed, %lu succeeded, %lu failed",
-                          (unsigned long)result.itemsProcessed,
-                          (unsigned long)result.itemsSucceeded,
-                          (unsigned long)result.itemsFailed);
-
-                for (id warningObj in result.warnings) {
-                    NSString *warning = PXSafeString(warningObj);
+                           (unsigned long)result.itemsProcessed,
+                           (unsigned long)result.itemsSucceeded,
+                           (unsigned long)result.itemsFailed);
+                for (id warningObject in result.warnings) {
+                    NSString *warning = PXSafeString(warningObject);
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
                 PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                 PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
-                    ? PXKeychainHelperExitCodeCompleted
-                    : PXKeychainHelperExitCodePartial;
+                    ? PXKeychainHelperExitCodeCompleted : PXKeychainHelperExitCodePartial;
                 return PXFinalizeStructuredResult(
-                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
+                    PXCreateStructuredResult(structuredOperation,
+                                             completion,
+                                             result,
+                                             0,
+                                             requestedAccessGroups,
+                                             effectiveAccessGroups,
+                                             nil),
                     exitCode);
             }
-
+
             case PXHelperActionRestore: {
                 if (!filePath.length) {
                     logError(@"--file is required for restore");
-                    return PXFinalizeStructuredResult(
-                        PXCreateStructuredResult(structuredOperation,
-                                                 PXKeychainHelperCompletionFailed,
-                                                 nil,
-                                                 0,
-                                                 PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
-                        PXKeychainHelperExitCodeInvalidArguments);
+                    return PXFinalizeFailure(structuredOperation,
+                                             PXKeychainHelperExitCodeInvalidArguments,
+                                             requestedAccessGroups,
+                                             effectiveAccessGroups,
+                                             PXKeychainBackupErrorInvalidArguments);
                 }
-
                 logVerbose(verbose, @"Starting keychain restore (overwrite requested: %@)...",
-                          overwrite ? @"YES" : @"NO");
+                           overwrite ? @"YES" : @"NO");
                 result = [KeychainBackupHelper restoreKeychainFromFile:filePath
                                                              overwrite:overwrite
                                                                  error:&error];
-
                 if (!result) {
                     logError(@"Restore failed: %@", error.localizedDescription);
                     NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
-                    PXKeychainHelperExitCode exitCode =
-                        PXExitCodeForFatalError(structuredOperation, fatalError);
+                    PXKeychainHelperExitCode exitCode = PXExitCodeForFatalError(structuredOperation, fatalError);
                     return PXFinalizeStructuredResult(
                         PXCreateStructuredResult(structuredOperation,
                                                  PXKeychainHelperCompletionFailed,
                                                  nil,
                                                  0,
+                                                 requestedAccessGroups,
+                                                 effectiveAccessGroups,
                                                  fatalError),
                         exitCode);
                 }
-
                 logSuccess(@"Restore complete: %lu items processed, %lu succeeded, %lu failed",
-                          (unsigned long)result.itemsProcessed,
-                          (unsigned long)result.itemsSucceeded,
-                          (unsigned long)result.itemsFailed);
-
-                for (id warningObj in result.warnings) {
-                    NSString *warning = PXSafeString(warningObj);
+                           (unsigned long)result.itemsProcessed,
+                           (unsigned long)result.itemsSucceeded,
+                           (unsigned long)result.itemsFailed);
+                for (id warningObject in result.warnings) {
+                    NSString *warning = PXSafeString(warningObject);
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
-                for (id errObj in result.errors) {
-                    NSString *err = PXSafeString(errObj);
-                    fprintf(stderr, "[ERR] %s\n", [err UTF8String] ?: "");
+                for (id errorObject in result.errors) {
+                    NSString *itemError = PXSafeString(errorObject);
+                    fprintf(stderr, "[ERR] %s\n", [itemError UTF8String] ?: "");
                 }
                 PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                 PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
-                    ? PXKeychainHelperExitCodeCompleted
-                    : PXKeychainHelperExitCodePartial;
+                    ? PXKeychainHelperExitCodeCompleted : PXKeychainHelperExitCodePartial;
                 return PXFinalizeStructuredResult(
-                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
+                    PXCreateStructuredResult(structuredOperation,
+                                             completion,
+                                             result,
+                                             0,
+                                             requestedAccessGroups,
+                                             effectiveAccessGroups,
+                                             nil),
                     exitCode);
             }
-
+
             case PXHelperActionWipe: {
-                if (!groups.count) {
-                    logError(@"--groups is required for wipe");
-                    return PXFinalizeStructuredResult(
-                        PXCreateStructuredResult(structuredOperation,
-                                                 PXKeychainHelperCompletionFailed,
-                                                 nil,
-                                                 0,
-                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
-                        PXKeychainHelperExitCodeInvalidArguments);
-                }
-
                 logVerbose(verbose, @"Starting keychain wipe...");
-                result = [KeychainBackupHelper wipeKeychainForAccessGroups:groups
+                result = [KeychainBackupHelper wipeKeychainForAccessGroups:operationalGroups
                                                                itemClasses:PXKeychainItemClassAll
                                                                      error:&error];
-
                 NSUInteger processed = result ? result.itemsProcessed : 0;
                 NSUInteger succeeded = result ? result.itemsSucceeded : 0;
                 NSUInteger failed = result ? result.itemsFailed : 0;
@@ -463,103 +734,88 @@ int main(int argc, const char *argv[]) {
                         (unsigned long)succeeded,
                         (unsigned long)failed,
                         (unsigned long)warningCount);
-
                 if (!result) {
                     logError(@"Wipe failed: %@", error.localizedDescription);
                     NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
-                    PXKeychainHelperExitCode exitCode =
-                        PXExitCodeForFatalError(structuredOperation, fatalError);
+                    PXKeychainHelperExitCode exitCode = PXExitCodeForFatalError(structuredOperation, fatalError);
                     return PXFinalizeStructuredResult(
                         PXCreateStructuredResult(structuredOperation,
                                                  PXKeychainHelperCompletionFailed,
                                                  nil,
                                                  0,
+                                                 requestedAccessGroups,
+                                                 effectiveAccessGroups,
                                                  fatalError),
                         exitCode);
                 }
-
-                for (id warningObj in result.warnings) {
-                    NSString *warning = PXSafeString(warningObj);
+                for (id warningObject in result.warnings) {
+                    NSString *warning = PXSafeString(warningObject);
                     fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                 }
-                if (result.itemsFailed > 0 || result.warnings.count > 0) {
-                    return PXFinalizeStructuredResult(
-                        PXCreateStructuredResult(structuredOperation,
-                                                 PXKeychainHelperCompletionPartial,
-                                                 result,
-                                                 0,
-                                                 nil),
-                        PXKeychainHelperExitCodePartial);
-                }
-
-                logSuccess(@"Wipe complete: %lu items deleted",
-                          (unsigned long)result.itemsSucceeded);
                 PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                 PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
-                    ? PXKeychainHelperExitCodeCompleted
-                    : PXKeychainHelperExitCodePartial;
+                    ? PXKeychainHelperExitCodeCompleted : PXKeychainHelperExitCodePartial;
+                if (completion == PXKeychainHelperCompletionCompleted) {
+                    logSuccess(@"Wipe complete: %lu items deleted", (unsigned long)result.itemsSucceeded);
+                }
                 return PXFinalizeStructuredResult(
-                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
+                    PXCreateStructuredResult(structuredOperation,
+                                             completion,
+                                             result,
+                                             0,
+                                             requestedAccessGroups,
+                                             effectiveAccessGroups,
+                                             nil),
                     exitCode);
             }
-
-            case PXHelperActionList: {
-                if (!groups.count) {
-                    logError(@"--groups is required for list");
-                    return PXFinalizeStructuredResult(
-                        PXCreateStructuredResult(structuredOperation,
-                                                 PXKeychainHelperCompletionFailed,
-                                                 nil,
-                                                 0,
-                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
-                        PXKeychainHelperExitCodeInvalidArguments);
-                }

+            case PXHelperActionList: {
                 logVerbose(verbose, @"Diagnosing keychain access...");
                 if (verbose) {
-                    NSArray<NSDictionary *> *diag = [KeychainBackupHelper diagnoseKeychainAccessForGroups:groups
-                                                                                           itemClasses:PXKeychainItemClassAll];
-                    for (NSDictionary *d in diag) {
+                    NSArray<NSDictionary *> *diagnostics =
+                        [KeychainBackupHelper diagnoseKeychainAccessForGroups:operationalGroups
+                                                                  itemClasses:PXKeychainItemClassAll];
+                    for (NSDictionary *diagnostic in diagnostics) {
                         fprintf(stdout, "[DIAG] group=%s class=%s status=%d (%s) count=%lu\n",
-                                [[d[@"accessGroup"] description] UTF8String] ?: "",
-                                [[d[@"class"] description] UTF8String] ?: "",
-                                [d[@"status"] intValue],
-                                [[d[@"statusDesc"] description] UTF8String] ?: "",
-                                (unsigned long)[d[@"count"] unsignedIntegerValue]);
+                                [[diagnostic[@"accessGroup"] description] UTF8String] ?: "",
+                                [[diagnostic[@"class"] description] UTF8String] ?: "",
+                                [diagnostic[@"status"] intValue],
+                                [[diagnostic[@"statusDesc"] description] UTF8String] ?: "",
+                                (unsigned long)[diagnostic[@"count"] unsignedIntegerValue]);
                     }
                 }
-
                 logVerbose(verbose, @"Listing keychain items...");
-                NSArray<NSDictionary *> *items = [KeychainBackupHelper listKeychainItemsForAccessGroups:groups
-                                                                                             itemClasses:PXKeychainItemClassAll];
-
+                NSArray<NSDictionary *> *items =
+                    [KeychainBackupHelper listKeychainItemsForAccessGroups:operationalGroups
+                                                                itemClasses:PXKeychainItemClassAll];
                 fprintf(stdout, "Found %lu keychain items:\n", (unsigned long)items.count);
                 for (NSDictionary *item in items) {
-                    NSString *cls = PXSafeString(item[@"class"]);
-                    NSString *svc = PXSafeString(item[@"service"]);
-                    NSString *acc = PXSafeString(item[@"account"]);
+                    NSString *itemClass = PXSafeString(item[@"class"]);
+                    NSString *service = PXSafeString(item[@"service"]);
+                    NSString *account = PXSafeString(item[@"account"]);
                     fprintf(stdout, "  - [%s] %s/%s\n",
-                           cls.length ? [cls UTF8String] : "?",
-                           [svc UTF8String] ?: "",
-                           [acc UTF8String] ?: "");
+                            itemClass.length ? [itemClass UTF8String] : "?",
+                            [service UTF8String] ?: "",
+                            [account UTF8String] ?: "");
                 }
                 return PXFinalizeStructuredResult(
                     PXCreateStructuredResult(structuredOperation,
                                              PXKeychainHelperCompletionCompleted,
                                              nil,
                                              items.count,
+                                             requestedAccessGroups,
+                                             effectiveAccessGroups,
                                              nil),
                     PXKeychainHelperExitCodeCompleted);
             }
-
-            default:
-                return PXFinalizeStructuredResult(
-                    PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
-                                             PXKeychainHelperCompletionFailed,
-                                             nil,
-                                             0,
-                                             PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
-                    PXKeychainHelperExitCodeInvalidArguments);
+
+            case PXHelperActionUnknown:
+                break;
         }
+        return PXFinalizeFailure(PXKeychainHelperOperationUnknown,
+                                 PXKeychainHelperExitCodeInvalidArguments,
+                                 emptyGroups,
+                                 emptyGroups,
+                                 PXKeychainBackupErrorInvalidArguments);
     }
 }
diff --git a/scripts/keychain_backup.sh b/scripts/keychain_backup.sh
index 222056f..8b22447 100644
--- a/scripts/keychain_backup.sh
+++ b/scripts/keychain_backup.sh
@@ -64,6 +64,12 @@ readonly PX_KEYCHAIN_EXIT_DEPENDENCY_UNAVAILABLE=65

 # Optional subset of keychain groups (CSV) provided by caller.
 OVERRIDE_KEYCHAIN_GROUPS=""
+OVERRIDE_KEYCHAIN_GROUPS_PRESENT=0
+PX_REQUESTED_GROUPS_CSV=""
+PX_EFFECTIVE_GROUPS_CSV=""
+PX_EFFECTIVE_ENT_PATH=""
+PX_APP_IDENTIFIER=""
+PX_APP_GROUPS_CSV=""

 # === Color Output ===
 # Only use colors if running in a TTY (interactive terminal)
@@ -523,7 +529,7 @@ px_validate_workspace_identity() {
 px_workspace_child_path() {
     local name="$1"
     case "$name" in
-        app_ent.xml|helper_ent.plist|backup_helper|restore_input.plist) ;;
+        app_ent.xml|helper_ent.plist|backup_helper|signed_helper_ent.plist|restore_input.plist) ;;
         *) return 1 ;;
     esac
     PX_WORKSPACE_CHILD_PATH="$PX_WORKSPACE_PATH/$name"
@@ -569,7 +575,7 @@ px_validate_workspace_file() {
 px_cleanup_workspace() {
     px_validate_workspace_identity || return 1
     local name child failed=0
-    for name in restore_input.plist backup_helper helper_ent.plist app_ent.xml; do
+    for name in restore_input.plist signed_helper_ent.plist backup_helper helper_ent.plist app_ent.xml; do
         px_workspace_child_path "$name" || return 1
         child="$PX_WORKSPACE_CHILD_PATH"
         if [ -L "$child" ]; then
@@ -621,6 +627,7 @@ PX_TARGET_IS_SYSTEM=0
 PX_APP_ENT_PATH=""
 PX_HELPER_ENT_PATH=""
 PX_WORKING_HELPER_PATH=""
+PX_SIGNED_HELPER_ENT_PATH=""
 PX_RESTORE_INPUT_PATH=""
 PX_BACKUP_OUTPUT_PATH=""
 PX_BACKUP_OUTPUT_PARENT=""
@@ -628,6 +635,9 @@ PX_BACKUP_OUTPUT_EXISTED=0

 px_string_has_control_character() {
     local value="$1"
+    case "$value" in
+        *$'\n'*|*$'\r'*) return 0 ;;
+    esac
     printf '%s' "$value" | "$PX_GREP_PATH" -q '[[:cntrl:]]'
 }

@@ -892,6 +902,94 @@ extract_entitlements() {
     return "$PX_KEYCHAIN_EXIT_COMPLETED"
 }

+# === Canonical Keychain access-group authority ===
+PX_CANONICAL_GROUP_CSV=""
+
+px_group_value_is_valid() {
+    local group="$1"
+    [ -n "$group" ] || return 1
+    [ "${#group}" -le 512 ] || return 1
+    px_string_has_control_character "$group" && return 1
+    case "$group" in *,*) return 1 ;; esac
+    local trimmed
+    trimmed=$(printf '%s' "$group" | "$PX_SED_PATH" 's/^ *//;s/ *$//') || return 1
+    [ "$trimmed" = "$group" ] || return 1
+    return 0
+}
+
+px_group_csv_contains() {
+    local csv="$1"
+    local group="$2"
+    [ -n "$csv" ] || return 1
+    case ",$csv," in
+        *",$group,"*) return 0 ;;
+        *) return 1 ;;
+    esac
+}
+
+px_canonicalize_group_csv() {
+    local input="$1"
+    PX_CANONICAL_GROUP_CSV=""
+    [ -n "$input" ] || return 1
+    [ "${#input}" -le 8192 ] || return 1
+    px_string_has_control_character "$input" && return 1
+    case "$input" in ,*|*,|*,,*) return 1 ;; esac
+    local parts=()
+    IFS=',' read -ra parts <<< "$input"
+    [ "${#parts[@]}" -gt 0 ] && [ "${#parts[@]}" -le 128 ] || return 1
+    local part group result="" count=0
+    for part in "${parts[@]}"; do
+        group=$(printf '%s' "$part" | "$PX_SED_PATH" 's/^ *//;s/ *$//') || return 1
+        px_group_value_is_valid "$group" || return 1
+        if ! px_group_csv_contains "$result" "$group"; then
+            count=$((count + 1))
+            [ "$count" -le 128 ] || return 1
+            if [ -n "$result" ]; then result="$result,$group"; else result="$group"; fi
+            [ "${#result}" -le 8192 ] || return 1
+        fi
+    done
+    [ -n "$result" ] || return 1
+    PX_CANONICAL_GROUP_CSV="$result"
+    return 0
+}
+
+px_add_group_to_canonical_csv() {
+    local csv="$1"
+    local group="$2"
+    PX_CANONICAL_GROUP_CSV=""
+    px_group_value_is_valid "$group" || return 1
+    if [ -z "$csv" ]; then
+        PX_CANONICAL_GROUP_CSV="$group"
+        return 0
+    fi
+    px_canonicalize_group_csv "$csv" || return 1
+    local result="$PX_CANONICAL_GROUP_CSV"
+    if ! px_group_csv_contains "$result" "$group"; then
+        result="$result,$group"
+        [ "${#result}" -le 8192 ] || return 1
+        local entries=()
+        IFS=',' read -ra entries <<< "$result"
+        [ "${#entries[@]}" -le 128 ] || return 1
+    fi
+    PX_CANONICAL_GROUP_CSV="$result"
+    return 0
+}
+
+px_group_csv_is_subset() {
+    local requested="$1"
+    local effective="$2"
+    px_canonicalize_group_csv "$requested" || return 1
+    local canonical_requested="$PX_CANONICAL_GROUP_CSV"
+    px_canonicalize_group_csv "$effective" || return 1
+    local canonical_effective="$PX_CANONICAL_GROUP_CSV"
+    local groups=() group
+    IFS=',' read -ra groups <<< "$canonical_requested"
+    for group in "${groups[@]}"; do
+        px_group_csv_contains "$canonical_effective" "$group" || return 1
+    done
+    return 0
+}
+
 # === Parse keychain access groups from entitlements ===
 parse_keychain_groups() {
     local ent_file="$1"
@@ -899,7 +997,7 @@ parse_keychain_groups() {
     px_stat_snapshot "$ent_file" PX_PARSE_GROUPS_BEFORE || return 1
     local groups=""
     local in_groups=0
-    local line group
+    local line group group_count=0
     while IFS= read -r line; do
         if printf '%s' "$line" | "$PX_GREP_PATH" -q "keychain-access-groups"; then
             in_groups=1
@@ -912,16 +1010,16 @@ parse_keychain_groups() {
             fi
             if printf '%s' "$line" | "$PX_GREP_PATH" -q "<string>"; then
                 group=$(printf '%s' "$line" | "$PX_SED_PATH" -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
-                if [ -n "$group" ]; then
-                    if [ -n "$groups" ]; then groups="$groups,$group"; else groups="$group"; fi
-                fi
+                px_group_value_is_valid "$group" || return 1
+                group_count=$((group_count + 1))
+                [ "$group_count" -le 128 ] || return 1
+                if [ -n "$groups" ]; then groups="$groups,$group"; else groups="$group"; fi
+                [ "${#groups}" -le 8192 ] || return 1
             fi
         fi
     done < "$ent_file"
     px_stat_snapshot "$ent_file" PX_PARSE_GROUPS_AFTER || return 1
     px_same_complete_snapshot PX_PARSE_GROUPS_BEFORE PX_PARSE_GROUPS_AFTER || return 1
-    [ "${#groups}" -le 65536 ] || return 1
-    px_string_has_control_character "$groups" && return 1
     printf '%s\n' "$groups"
 }

@@ -1236,8 +1334,19 @@ px_validate_backup_output_after_execution() {

 px_validate_helper_execution() {
     px_validate_workspace_identity || return 1
+    [ -n "$PX_HELPER_ENT_PATH" ] || return 1
+    [ -n "$PX_WORKING_HELPER_PATH" ] || return 1
+    [ -n "$PX_EFFECTIVE_ENT_PATH" ] || return 1
+    [ "$PX_EFFECTIVE_ENT_PATH" = "$PX_SIGNED_HELPER_ENT_PATH" ] || return 1
     px_validate_workspace_file "$PX_HELPER_ENT_PATH" 600 0 1 || return 1
     px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return 1
+    px_validate_workspace_file "$PX_EFFECTIVE_ENT_PATH" 600 0 1 || return 1
+    px_stat_snapshot "$PX_HELPER_ENT_PATH" PX_HELPER_ENT_LIVE || return 1
+    px_same_complete_snapshot PX_HELPER_ENT_AUTHORITY PX_HELPER_ENT_LIVE || return 1
+    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_SIGNED_HELPER_LIVE || return 1
+    px_same_complete_snapshot PX_SIGNED_HELPER_AUTHORITY PX_SIGNED_HELPER_LIVE || return 1
+    px_stat_snapshot "$PX_EFFECTIVE_ENT_PATH" PX_EFFECTIVE_LIVE || return 1
+    px_same_complete_snapshot PX_EFFECTIVE_AUTHORITY PX_EFFECTIVE_LIVE || return 1
     return 0
 }

@@ -1262,26 +1371,91 @@ px_select_source_entitlement() {
     fi
 }

+px_prepare_requested_groups() {
+    local bundle_id="$1"
+    local source_groups selected_groups app_identifier app_groups
+    source_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+
+    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
+        px_canonicalize_group_csv "$OVERRIDE_KEYCHAIN_GROUPS" || return "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+        selected_groups="$PX_CANONICAL_GROUP_CSV"
+        log_info "Using caller-selected keychain groups"
+    elif [ -n "$source_groups" ]; then
+        px_canonicalize_group_csv "$source_groups" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+        selected_groups="$PX_CANONICAL_GROUP_CSV"
+    else
+        selected_groups=""
+    fi
+
+    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    if [ -z "$app_identifier" ]; then
+        app_identifier="$bundle_id"
+    fi
+    px_group_value_is_valid "$app_identifier" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    px_add_group_to_canonical_csv "$selected_groups" "$app_identifier" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    PX_REQUESTED_GROUPS_CSV="$PX_CANONICAL_GROUP_CSV"
+    [ -n "$PX_REQUESTED_GROUPS_CSV" ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+
+    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    PX_APP_IDENTIFIER="$app_identifier"
+    PX_APP_GROUPS_CSV="$app_groups"
+    px_select_source_entitlement "$app_identifier"
+    log_info "Requested groups validated"
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
+}
+
+px_extract_signed_helper_entitlements() {
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_HELPER_ENT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_require_workspace_child_absent signed_helper_ent.plist || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    local signed_ent_file="$PX_WORKSPACE_CHILD_PATH"
+    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_EFFECTIVE_HELPER_BEFORE || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
+    "$PX_LDID_PATH" -e "$PX_WORKING_HELPER_PATH" > "$signed_ent_file" 2>/dev/null
+    local extraction_status=$?
+
+    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_EFFECTIVE_HELPER_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_same_complete_snapshot PX_EFFECTIVE_HELPER_BEFORE PX_EFFECTIVE_HELPER_AFTER || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_stat_snapshot "$PX_WORKING_HELPER_PATH" PX_SIGNED_HELPER_AUTHORITY || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    [ "$extraction_status" -eq 0 ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    "$PX_CHMOD_PATH" 600 "$signed_ent_file" >/dev/null 2>&1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_workspace_file "$signed_ent_file" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+
+    local effective_groups
+    effective_groups=$(parse_keychain_groups "$signed_ent_file") || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    [ -n "$effective_groups" ] || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    px_canonicalize_group_csv "$effective_groups" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+    PX_EFFECTIVE_GROUPS_CSV="$PX_CANONICAL_GROUP_CSV"
+    px_group_csv_is_subset "$PX_REQUESTED_GROUPS_CSV" "$PX_EFFECTIVE_GROUPS_CSV" || return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
+
+    PX_SIGNED_HELPER_ENT_PATH="$signed_ent_file"
+    PX_EFFECTIVE_ENT_PATH="$signed_ent_file"
+    px_stat_snapshot "$PX_EFFECTIVE_ENT_PATH" PX_EFFECTIVE_AUTHORITY || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    log_info "Signed helper access scope validated"
+    return "$PX_KEYCHAIN_EXIT_COMPLETED"
+}
+
 px_finish_signed_helper() {
-    local keychain_groups="$1"
-    local app_groups="$2"
-    local app_identifier="$3"
-    local source_ent_file="$4"
     local helper_ent="$PX_WORKSPACE_PATH/helper_ent.plist"
-    generate_helper_entitlements "$keychain_groups" "$app_groups" "$helper_ent" "$app_identifier" "$source_ent_file"
+    generate_helper_entitlements "$PX_REQUESTED_GROUPS_CSV" "$PX_APP_GROUPS_CSV" "$helper_ent" "$PX_APP_IDENTIFIER" "$PX_SOURCE_ENT_FOR_SYSTEM"
     local status=$?
     [ "$status" -eq 0 ] || return "$status"
     px_prepare_working_helper
     status=$?
     [ "$status" -eq 0 ] || return "$status"
     resign_helper "$PX_HELPER_ENT_PATH" "$PX_WORKING_HELPER_PATH"
+    status=$?
+    [ "$status" -eq 0 ] || return "$status"
+    px_stat_snapshot "$PX_HELPER_ENT_PATH" PX_HELPER_ENT_AUTHORITY || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_extract_signed_helper_entitlements
     return $?
 }

 do_backup() {
     local bundle_id="$1"
     local backup_file="$2"
-    local override_groups="$3"

     log_info "Starting keychain backup"
     px_prepare_backup_output "$backup_file"
@@ -1293,42 +1467,29 @@ do_backup() {
     px_prepare_target_context "$bundle_id"
     local context_status=$?
     [ "$context_status" -eq 0 ] || return "$context_status"
-
-    local keychain_groups
-    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    if [ -n "$override_groups" ]; then
-        log_info "Using caller-selected keychain groups"
-        keychain_groups="$override_groups"
-    fi
-    if [ -z "$keychain_groups" ]; then
-        log_error "No keychain-access-groups found in app entitlements"
-        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
-    fi
-
-    local app_groups app_identifier
-    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    if [ -z "$app_identifier" ]; then
-        log_warn "No application-identifier found, using bundle ID"
-        app_identifier="$bundle_id"
-    fi
-    keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-    px_select_source_entitlement "$app_identifier"
+    px_prepare_requested_groups "$bundle_id"
+    local group_status=$?
+    [ "$group_status" -eq 0 ] || return "$group_status"

     log_info "Preparing private signed helper..."
-    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    px_finish_signed_helper
     local helper_status=$?
     [ "$helper_status" -eq 0 ] || return "$helper_status"
     px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     px_revalidate_backup_output_before_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

-    local helper_args=("--action" "backup" "--file" "$PX_BACKUP_OUTPUT_PATH" "--groups" "$keychain_groups")
+    local helper_args=(
+        "--action" "backup"
+        "--file" "$PX_BACKUP_OUTPUT_PATH"
+        "--groups" "$PX_REQUESTED_GROUPS_CSV"
+        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
+        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
+    )
     if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
     "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?

-    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     px_validate_backup_output_after_execution "$raw_exit_code" || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     local exit_code=$?
@@ -1344,7 +1505,6 @@ do_restore() {
     local bundle_id="$1"
     local restore_file="$2"
     local overwrite="$3"
-    local override_groups="$4"

     log_info "Starting keychain restore"
     px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
@@ -1356,34 +1516,29 @@ do_restore() {
     px_prepare_target_context "$bundle_id"
     local context_status=$?
     [ "$context_status" -eq 0 ] || return "$context_status"
-
-    local keychain_groups app_groups app_identifier
-    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    if [ -n "$override_groups" ]; then
-        log_info "Using caller-selected keychain groups"
-        keychain_groups="$override_groups"
-    fi
-    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    [ -n "$app_identifier" ] || app_identifier="$bundle_id"
-    keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-    px_select_source_entitlement "$app_identifier"
+    px_prepare_requested_groups "$bundle_id"
+    local group_status=$?
+    [ "$group_status" -eq 0 ] || return "$group_status"

     log_info "Preparing private signed helper..."
-    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    px_finish_signed_helper
     local helper_status=$?
     [ "$helper_status" -eq 0 ] || return "$helper_status"
     px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     px_validate_workspace_file "$PX_RESTORE_INPUT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

-    local helper_args=("--action" "restore" "--file" "$PX_RESTORE_INPUT_PATH")
+    local helper_args=(
+        "--action" "restore"
+        "--file" "$PX_RESTORE_INPUT_PATH"
+        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
+        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
+    )
     if [ "$overwrite" = "--overwrite" ]; then helper_args+=("--overwrite"); fi
     if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
     "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?

-    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     px_validate_workspace_file "$PX_RESTORE_INPUT_PATH" 600 0 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     local exit_code=$?
@@ -1397,85 +1552,65 @@ do_restore() {

 do_wipe() {
     local bundle_id="$1"
-    local override_groups="$2"

     log_info "Starting keychain wipe"
     px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     px_prepare_target_context "$bundle_id"
     local context_status=$?
     [ "$context_status" -eq 0 ] || return "$context_status"
+    px_prepare_requested_groups "$bundle_id"
+    local group_status=$?
+    [ "$group_status" -eq 0 ] || return "$group_status"

-    local keychain_groups app_groups app_identifier
-    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    if [ -n "$override_groups" ]; then
-        log_info "Using caller-selected keychain groups"
-        keychain_groups="$override_groups"
-    fi
-    if [ -z "$keychain_groups" ]; then
-        log_error "No keychain-access-groups found"
-        return "$PX_KEYCHAIN_EXIT_ENTITLEMENT_FAILURE"
-    fi
     log_warn "This will delete all Keychain items for the selected groups"
-    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    [ -n "$app_identifier" ] || app_identifier="$bundle_id"
-    keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-    px_select_source_entitlement "$app_identifier"
-
-    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    px_finish_signed_helper
     local helper_status=$?
     [ "$helper_status" -eq 0 ] || return "$helper_status"
     px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

-    local helper_args=("--action" "wipe" "--groups" "$keychain_groups")
+    local helper_args=(
+        "--action" "wipe"
+        "--groups" "$PX_REQUESTED_GROUPS_CSV"
+        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
+        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
+    )
     if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
     "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?

-    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     return $?
 }

 do_list() {
     local bundle_id="$1"
-    local override_groups="$2"

     log_info "Listing keychain items"
     px_create_workspace || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     px_prepare_target_context "$bundle_id"
     local context_status=$?
     [ "$context_status" -eq 0 ] || return "$context_status"
+    px_prepare_requested_groups "$bundle_id"
+    local group_status=$?
+    [ "$group_status" -eq 0 ] || return "$group_status"

-    local keychain_groups app_groups app_identifier
-    keychain_groups=$(parse_keychain_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    if [ -n "$override_groups" ]; then
-        log_info "Using caller-selected keychain groups"
-        keychain_groups="$override_groups"
-    fi
-    if [ -z "$keychain_groups" ]; then
-        log_info "No keychain-access-groups found in app"
-        return "$PX_KEYCHAIN_EXIT_COMPLETED"
-    fi
-    app_groups=$(parse_app_groups "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    app_identifier=$(parse_app_identifier "$PX_APP_ENT_PATH") || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    [ -n "$app_identifier" ] || app_identifier="$bundle_id"
-    keychain_groups=$(ensure_group_in_csv "$keychain_groups" "$app_identifier")
-    px_select_source_entitlement "$app_identifier"
-
-    px_finish_signed_helper "$keychain_groups" "$app_groups" "$app_identifier" "$PX_SOURCE_ENT_FOR_SYSTEM"
+    px_finish_signed_helper
     local helper_status=$?
     [ "$helper_status" -eq 0 ] || return "$helper_status"
     px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"

-    local helper_args=("--action" "list" "--groups" "$keychain_groups")
+    local helper_args=(
+        "--action" "list"
+        "--groups" "$PX_REQUESTED_GROUPS_CSV"
+        "--requested-groups" "$PX_REQUESTED_GROUPS_CSV"
+        "--effective-entitlements-file" "$PX_EFFECTIVE_ENT_PATH"
+    )
     if [ "$VERBOSE" -eq 1 ]; then helper_args+=("--verbose"); fi
     "$PX_WORKING_HELPER_PATH" "${helper_args[@]}"
     local raw_exit_code=$?

-    px_validate_workspace_identity || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
-    px_validate_workspace_file "$PX_WORKING_HELPER_PATH" 700 1 1 || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
+    px_validate_helper_execution || return "$PX_KEYCHAIN_EXIT_WORKSPACE_FAILURE"
     normalize_helper_exit_status "$raw_exit_code"
     return $?
 }
@@ -1490,6 +1625,7 @@ print_usage() {
     echo "  list <bundleID>                   List keychain items"
     echo ""
     echo "Options:"
+    echo "  --groups CSV  Select canonical Keychain access groups"
     echo "  --overwrite   For restore: update one exact existing item in place; never delete"
     echo "  --verbose     Show detailed output"
     echo ""
@@ -1557,10 +1693,20 @@ case "$ACTION" in
         while [[ "$1" == --* ]]; do
             case "$1" in
                 --groups)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
+                        log_error "Invalid or duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="$2"
                     shift 2
                     ;;
                 --groups=*)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
+                        log_error "Duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                     shift 1
                     ;;
@@ -1569,7 +1715,8 @@ case "$ACTION" in
                     ;;
             esac
         done
-        do_backup "$BUNDLE_ID" "$shift_file" "$OVERRIDE_KEYCHAIN_GROUPS"
+        [ $# -eq 0 ] || { log_error "Unexpected backup argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
+        do_backup "$BUNDLE_ID" "$shift_file"
         ;;
     restore)
         if [ -z "$1" ]; then
@@ -1589,10 +1736,20 @@ case "$ACTION" in
         while [[ "$1" == --* ]]; do
             case "$1" in
                 --groups)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
+                        log_error "Invalid or duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="$2"
                     shift 2
                     ;;
                 --groups=*)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
+                        log_error "Duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                     shift 1
                     ;;
@@ -1601,16 +1758,27 @@ case "$ACTION" in
                     ;;
             esac
         done
-        do_restore "$BUNDLE_ID" "$shift_file" "$restore_overwrite" "$OVERRIDE_KEYCHAIN_GROUPS"
+        [ $# -eq 0 ] || { log_error "Unexpected restore argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
+        do_restore "$BUNDLE_ID" "$shift_file" "$restore_overwrite"
         ;;
     wipe)
         while [[ "$1" == --* ]]; do
             case "$1" in
                 --groups)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
+                        log_error "Invalid or duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="$2"
                     shift 2
                     ;;
                 --groups=*)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
+                        log_error "Duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                     shift 1
                     ;;
@@ -1619,16 +1787,27 @@ case "$ACTION" in
                     ;;
             esac
         done
-        do_wipe "$BUNDLE_ID" "$OVERRIDE_KEYCHAIN_GROUPS"
+        [ $# -eq 0 ] || { log_error "Unexpected wipe argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
+        do_wipe "$BUNDLE_ID"
         ;;
     list)
         while [[ "$1" == --* ]]; do
             case "$1" in
                 --groups)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ] || [ $# -lt 2 ] || [[ "$2" == --* ]]; then
+                        log_error "Invalid or duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="$2"
                     shift 2
                     ;;
                 --groups=*)
+                    if [ "$OVERRIDE_KEYCHAIN_GROUPS_PRESENT" -eq 1 ]; then
+                        log_error "Duplicate --groups option"
+                        exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"
+                    fi
+                    OVERRIDE_KEYCHAIN_GROUPS_PRESENT=1
                     OVERRIDE_KEYCHAIN_GROUPS="${1#*=}"
                     shift 1
                     ;;
@@ -1637,7 +1816,8 @@ case "$ACTION" in
                     ;;
             esac
         done
-        do_list "$BUNDLE_ID" "$OVERRIDE_KEYCHAIN_GROUPS"
+        [ $# -eq 0 ] || { log_error "Unexpected list argument"; exit "$PX_KEYCHAIN_EXIT_INVALID_ARGUMENTS"; }
+        do_list "$BUNDLE_ID"
         ;;
     *)
         log_error "Unknown action: $ACTION"
```

## Residual risks
Shell XML parsing is prevalidation; direct immutable plist parser is final authority. Metadata snapshots are not descriptor-pinned against malicious root/kernel/filesystem. Full system scope may remain wider. Device ldid/argv evidence and TASK-4.9 at-rest policy remain pending.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
