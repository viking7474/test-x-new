# TASK-4.4 REPORT - Define Exact Keychain Item Identity

## Result
- Implementation status: COMPLETE within the authorized TASK-4.4 scope.
- Mandatory baseline: `4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1`.
- TASK-4.3 source review: ACCEPTED and COMPLETED.
- No TASK-4.5 or later work is included.

## Exact scope
| Status | Path | Purpose |
|---|---|---|
| A | `KeychainHelper/PXKeychainItemIdentity.h` | immutable public identity contract |
| A | `KeychainHelper/PXKeychainItemIdentity.m` | exact validation, canonical tuple, immutable match-query construction |
| M | `Makefile` | add identity implementation exactly once to `backup_helper_FILES` |
| A | `docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md` | implementation and validation evidence |

## Baseline evidence
Commands captured before implementation:
```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```
Baseline HEAD:
```text
4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1
```
Baseline coordinator-owned status retained and never staged or rewritten:
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
Baseline log:
```text
4c70002 phase4(task-4.3): remove broad keychain restore pre-delete
5c6e70a phase4(task-4.2): define reliable keychain helper exit codes
1a59e96 phase4(task-4.1): add structured keychain helper result
02770e2 phase3(task-3.10A): fix stale name classification and rollback errors
5e70a8f phase3(task-3.10): harden backup discovery and stale cleanup
aa01f73 phase3(task-3.9A): make cleanup removal race safe
aa47468 phase3(task-3.9): centralize backup failure cleanup
e55e9d6 phase3(task-3.8A): make directory publication no-replace
```
Baseline `git diff --check`: PASS; only existing CRLF conversion warnings for coordinator documentation were emitted.

## Protected hashes and byte sizes
All 75 protected production paths are byte-identical to baseline and match accepted TASK-4.3 evidence.
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
| `KeychainHelper/KeychainBackupHelper.h` | `23fd5431f751401a7a09edca1eafec80ab1118321ed6493751d9061e750dc010` | 4462 | `23fd5431f751401a7a09edca1eafec80ab1118321ed6493751d9061e750dc010` | 4462 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | `798f6c6aa87b77a525c1bcbb866877fdb6d544f41df4c63cfbdaaade56eedfa7` | 26504 | `798f6c6aa87b77a525c1bcbb866877fdb6d544f41df4c63cfbdaaade56eedfa7` | 26504 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.h` | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | TRUE |
| `KeychainHelper/backup_helper.m` | `e776a0399614c34195cd09601e420a607bc0147cf034976d740247f79cb79943` | 28261 | `e776a0399614c34195cd09601e420a607bc0147cf034976d740247f79cb79943` | 28261 | TRUE |
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
| `scripts/keychain_backup.sh` | `05a2b44a1f36ab0ffba407a9e76f7cd7cb26b4455276f6640d738753d9840f53` | 36295 | `05a2b44a1f36ab0ffba407a9e76f7cd7cb26b4455276f6640d738753d9840f53` | 36295 | TRUE |

## Authorized source before/after
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
|---|---|---:|---|---:|
| `KeychainHelper/PXKeychainItemIdentity.h` | ABSENT | 0 | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | 2387 |
| `KeychainHelper/PXKeychainItemIdentity.m` | ABSENT | 0 | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | 62919 |
| `Makefile` | `2b00869abcb03a3c743792b4466c2d9f3a81191863a0ff7bb5738b9dff8b3e3a` | 9012 | `99cf5ded8dfe4bbd4ab363ccdbbd477285b3f1e5aa25118b18a200c52706b566` | 9226 |
| `docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md` | ABSENT | 0 | SELF-REFERENTIAL | SELF-REFERENTIAL |

## Exact public API
- Exports: `PXKeychainItemIdentitySchemaVersion`, `PXKeychainItemIdentityErrorDomain`, and `PXKeychainItemIdentityErrorFieldPathKey`.
- Schema version is exactly `1`; error domain is `com.hydra.projectx.keychain-item-identity`; field-path key is `fieldPath`.
- `PXKeychainItemIdentity` is subclassing-restricted, immutable, and conforms to `NSCopying`.
- It exposes exactly eight readonly properties and one public factory, `identityForSecurityItemAttributes:error:`.
- `init` and `new` are unavailable; `copyWithZone:` returns `self`.

## Exact class enum
| Name | Value | Canonical className |
|---|---:|---|
| Unknown | 0 | `unknown` |
| GenericPassword | 1 | `generic-password` |
| InternetPassword | 2 | `internet-password` |
| Certificate | 3 | `certificate` |
| Key | 4 | `key` |
| Identity | 5 | `identity` |
- Successful construction never produces Unknown. The input class must be the exact supported Security constant object; an equal-looking ordinary string is rejected.

## Exact error taxonomy
| Code | Name |
|---:|---|
| 1 | `InvalidInput` |
| 2 | `UnsupportedClass` |
| 3 | `MissingAccessGroup` |
| 4 | `InvalidAccessGroup` |
| 5 | `MissingIdentityAttribute` |
| 6 | `InvalidIdentityAttributeType` |
| 7 | `InvalidIdentityAttributeValue` |
| 8 | `InvalidSynchronizable` |
| 9 | `AmbiguousIdentity` |
| 10 | `LimitExceeded` |
| 11 | `SnapshotFailed` |
| 12 | `InternalInvariantFailed` |

## Common identity rules
- Input must be an NSDictionary with at most 256 entries. The factory accepts decoded Security attributes, not wrapped backup-plist metadata.
- Every identity contains exact `kSecClass`, exact access group, exact `@YES/@NO` synchronizable, and the complete class tuple.
- Access group is a nonempty exact NSString, lossless UTF-8, at most 1024 bytes, control/NUL-free, and is never trimmed or normalized.
- Missing synchronizable canonicalizes to false. Present synchronizable must be exact CFBoolean.
- Input is snapshotted and every retained string, data, number, array, and dictionary is independently immutable.

## Exact-CFBoolean proof
- Exactly one helper, `PXKeychainItemIdentityExtractExactCFBoolean`, performs CF type-ID validation against `CFBooleanGetTypeID`.
- NSNumber 0/1, ordinary numeric objects, strings, collections, NSNull, and synchronizable-any fail with InvalidSynchronizable.
- Port validation independently requires CFNumber and explicitly rejects the exact CFBoolean helper result.

## Five exact class tuples
| Class | Required tuple after common fields | Query keys |
|---|---|---:|
| GenericPassword | account, service | 5 |
| InternetPassword | account, server, port, protocol, authenticationType, path, securityDomain | 10 |
| Certificate | issuer, serialNumber | 5 |
| Key | applicationLabel, keyClass, keyType | 6 |
| Identity | applicationLabel, issuer, serialNumber | 6 |
- Generic account/service and internet account/path/securityDomain may be empty but remain required exact strings.
- Server, protocol, authenticationType, keyClass, and keyType must be nonempty bounded strings.
- Port is finite, integral, non-Boolean, and within 0 through 65535.
- Issuer, serial number, and application label are nonempty NSData with their specified fixed byte limits.

## Malformed-type and exception matrix
| Area | Wrong type | Invalid value | Oversize | Missing/incomplete |
|---|---|---|---|---|
| access group | InvalidAccessGroup | InvalidAccessGroup | LimitExceeded | MissingAccessGroup |
| synchronizable | InvalidSynchronizable | InvalidSynchronizable | n/a | absent becomes false |
| tuple string | InvalidIdentityAttributeType | InvalidIdentityAttributeValue | LimitExceeded | MissingIdentityAttribute or AmbiguousIdentity |
| tuple data | InvalidIdentityAttributeType | InvalidIdentityAttributeValue | LimitExceeded | MissingIdentityAttribute or AmbiguousIdentity |
| port | InvalidIdentityAttributeType | InvalidIdentityAttributeValue | range failure | Missing/AmbiguousIdentity |
- Every selector is reached only after runtime type proof. One public `@try/@catch` prevents malformed Foundation subclasses from escaping the factory.
- There are 45 explicit public failure returns, each preceded by a specific error assignment path.

## Ambiguity and no-fallback proof
- Incomplete internet tuples with apparent tuple/optional identity fields fail AmbiguousIdentity.
- Partial certificate issuer/serial input and certificate-like alternate fields fail closed.
- Missing key applicationLabel is never replaced by applicationTag, label, or key-size metadata.
- Identity requires applicationLabel plus issuer plus serialNumber; certificate-only and key-only subsets fail closed.
- `_class`, `_secClass`, label, persistent reference, value data/ref, public-key hash, application tag, subject, key size, and best-available subsets are never accepted as the canonical tuple.

## Immutable and deep-copy proof
- Mutable input dictionary structure is snapshotted before validation.
- Strings are losslessly encoded and reconstructed; NSData is copied into new immutable data; port is canonicalized into a new NSNumber.
- Canonical names, identity dictionaries, and query dictionaries are copied into immutable collections.
- The independent semantic model mutates caller-owned byte buffers after construction and confirms retained values remain unchanged.
- Equality and hash cover schemaVersion, class, synchronizable, access group, identityAttributes, and matchQuery.

## Match-query key counts and whitelist
| Class | Exact count | Keys |
|---|---:|---|
| GenericPassword | 5 | class, accessGroup, synchronizable, account, service |
| InternetPassword | 10 | class, accessGroup, synchronizable, account, server, port, protocol, authenticationType, path, securityDomain |
| Certificate | 5 | class, accessGroup, synchronizable, issuer, serialNumber |
| Key | 6 | class, accessGroup, synchronizable, applicationLabel, keyClass, keyType |
| Identity | 6 | class, accessGroup, synchronizable, applicationLabel, issuer, serialNumber |
- Query construction has one class insertion plus a loop over the canonical whitelist; no caller dictionary is copied wholesale into the query.

## Forbidden query/value key proof
- Source references to match limits, return flags, authentication controls, value data/ref, persistent refs, and synchronizable-any are all zero.
- Label/comment/description/date/access-control fields are not inserted into matchQuery.
- The implementation cannot accidentally carry secrets or operational query flags from the caller because only canonical tuple snapshots are inserted.

## Privacy-safe errors and descriptions
- NSError userInfo is constructed in one site and contains only NSLocalizedDescriptionKey plus the bounded static field path.
- It does not retain the input dictionary, underlying exception, or actual identity values.
- description/debugDescription expose only canonical className, synchronizable state, and attribute count.
- Access group, account/service/server/path, issuer/serial/applicationLabel, protocol/authentication values, and key values are not rendered.

## Zero Security-operation and side-effect proof
| Operation | Calls in new implementation |
|---|---:|
| `SecItemCopyMatching` | 0 |
| `SecItemAdd` | 0 |
| `SecItemUpdate` | 0 |
| `SecItemDelete` | 0 |
| `SecItemImport` | 0 |
| `SecItemExport` | 0 |
- Filesystem, process/shell, network, dispatch, notification, and logging calls are zero. Security.framework is used only for public constant definitions and types.

## Makefile exact diff
- `KeychainHelper/PXKeychainItemIdentity.m` is appended exactly once to `backup_helper_FILES`.
- Target name, CFLAGS, frameworks, install path, codesign flags, and all other Makefile lines are unchanged.
```diff
diff --git a/Makefile b/Makefile
index 9916f34..a9e562e 100644
--- a/Makefile
+++ b/Makefile
@@ -38,7 +38,7 @@ WeaponXDaemon_CODESIGN_FLAGS = -Sent.plist
 WeaponXDaemon_LDFLAGS = -framework IOKit

 # Keychain Helper Tool - CLI for backup/restore/wipe keychain items
-backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m KeychainHelper/PXKeychainHelperResult.m
+backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m KeychainHelper/PXKeychainHelperResult.m KeychainHelper/PXKeychainItemIdentity.m
 backup_helper_CFLAGS = -fobjc-arc -Wno-error=unused-variable
 backup_helper_FRAMEWORKS = Foundation Security
 backup_helper_INSTALL_PATH = /Library/WeaponX
```

## Zero restore integration
- KeychainBackupHelper.h/.m, backup_helper.m, and scripts/keychain_backup.sh are byte-identical.
- Current restore contains zero PXKeychainItemIdentity references and does not construct, lookup, compare, delete, update, or upsert by identity.
- TASK-4.5 is the first task allowed to consume this object.

## TASK-4.1 through TASK-4.3 non-regression
- Core Security counts remain `{'SecItemCopyMatching': 5, 'SecItemAdd': 1, 'SecItemDelete': 1, 'SecItemUpdate': 0}`.
- Restore Security counts remain `{'SecItemCopyMatching': 0, 'SecItemAdd': 1, 'SecItemDelete': 0, 'SecItemUpdate': 0}`.
- TASK-4.1 schema version, root/fatal key sets, binary-plist/base64 framing, fixed bounds, and privacy exclusions are unchanged.
- TASK-4.2 thirteen-value exit taxonomy, one finalizer, sixteen non-help finalizer calls, one emitter, and shell normalizer behavior are unchanged.
- TASK-4.3 overwrite compatibility and both exact duplicate-preservation warnings are unchanged.
- Manager, Cleaner, Bridge, UI, Phase-1 through Phase-3, and restore infrastructure remain byte-identical.

## TASK-4.5 boundary
- No preflight duplicate lookup, exact SecItemCopyMatching use, SecItemUpdate, per-item delete/add replacement, rollback, or restore integration is implemented here.
- The new identity object is compiled into backup_helper solely as a Foundation-only definition for later use.

## Static gates
| Gate | Observed | Required | Result |
|---|---:|---:|---|
| exports | 3 | 3 | PASS |
| class enum values | 6 | 6 | PASS |
| error codes | 12 | 12 | PASS |
| readonly properties | 8 | 8 | PASS |
| public factories | 1 | 1 | PASS |
| exact-CFBoolean helpers | 1 | 1 | PASS |
| exception boundaries | 1 | 1 | PASS |
| public failure returns with error path | 45 | 45 | PASS |
| Security operation calls | 0 | 0 | PASS |
| forbidden query/value token references | 0 | 0 | PASS |
| Makefile identity source entries | 1 | 1 | PASS |
| protected files | 75 | 75 | PASS |
| semantic model assertions | 100418 | 100418 | PASS |
| explicit scenarios | 533 | at least 260 | PASS |
- Objective-C delimiter/quote lexical balance: PASS.
- `git diff --check` for authorized production files: PASS.
- Exact one-line Makefile delta: PASS.

## Explicit numbered scenarios
Explicit scenarios: 533.
| # | Area | Stimulus | Expected result |
|---:|---|---|---|
| 1 | public enum | Unknown | exact value 0 |
| 2 | public enum | GenericPassword | exact value 1 |
| 3 | public enum | InternetPassword | exact value 2 |
| 4 | public enum | Certificate | exact value 3 |
| 5 | public enum | Key | exact value 4 |
| 6 | public enum | Identity | exact value 5 |
| 7 | public error | InvalidInput | exact code 1 |
| 8 | public error | UnsupportedClass | exact code 2 |
| 9 | public error | MissingAccessGroup | exact code 3 |
| 10 | public error | InvalidAccessGroup | exact code 4 |
| 11 | public error | MissingIdentityAttribute | exact code 5 |
| 12 | public error | InvalidIdentityAttributeType | exact code 6 |
| 13 | public error | InvalidIdentityAttributeValue | exact code 7 |
| 14 | public error | InvalidSynchronizable | exact code 8 |
| 15 | public error | AmbiguousIdentity | exact code 9 |
| 16 | public error | LimitExceeded | exact code 10 |
| 17 | public error | SnapshotFailed | exact code 11 |
| 18 | public error | InternalInvariantFailed | exact code 12 |
| 19 | public property | schemaVersion | readonly; retained state is immutable |
| 20 | public property | itemClass | readonly; retained state is immutable |
| 21 | public property | className | readonly; retained state is immutable |
| 22 | public property | accessGroup | readonly; retained state is immutable |
| 23 | public property | synchronizable | readonly; retained state is immutable |
| 24 | public property | identityAttributeNames | readonly; retained state is immutable |
| 25 | public property | identityAttributes | readonly; retained state is immutable |
| 26 | public property | matchQuery | readonly; retained state is immutable |
| 27 | public contract | one factory only | contract preserved exactly |
| 28 | public contract | init unavailable | contract preserved exactly |
| 29 | public contract | new unavailable | contract preserved exactly |
| 30 | public contract | subclassing restricted | contract preserved exactly |
| 31 | public contract | NSCopying conformance | contract preserved exactly |
| 32 | public contract | copyWithZone returns self | contract preserved exactly |
| 33 | public contract | success clears NSError | contract preserved exactly |
| 34 | public contract | failure returns specific NSError | contract preserved exactly |
| 35 | public contract | public exception boundary | contract preserved exactly |
| 36 | valid identity | GenericPassword; synchronizable=absent | success; canonical class; exact query key count 5; nil error |
| 37 | valid identity | GenericPassword; synchronizable=exact false | success; canonical class; exact query key count 5; nil error |
| 38 | valid identity | GenericPassword; synchronizable=exact true | success; canonical class; exact query key count 5; nil error |
| 39 | canonical order | GenericPassword | kSecAttrAccessGroup, kSecAttrSynchronizable, then exact class tuple |
| 40 | query class | GenericPassword | kSecClass value is the exact supported Security constant |
| 41 | extra attributes | GenericPassword with label/comment/date/value-like unrelated fields | extras ignored; query remains whitelist-only |
| 42 | valid identity | InternetPassword; synchronizable=absent | success; canonical class; exact query key count 10; nil error |
| 43 | valid identity | InternetPassword; synchronizable=exact false | success; canonical class; exact query key count 10; nil error |
| 44 | valid identity | InternetPassword; synchronizable=exact true | success; canonical class; exact query key count 10; nil error |
| 45 | canonical order | InternetPassword | kSecAttrAccessGroup, kSecAttrSynchronizable, then exact class tuple |
| 46 | query class | InternetPassword | kSecClass value is the exact supported Security constant |
| 47 | extra attributes | InternetPassword with label/comment/date/value-like unrelated fields | extras ignored; query remains whitelist-only |
| 48 | valid identity | Certificate; synchronizable=absent | success; canonical class; exact query key count 5; nil error |
| 49 | valid identity | Certificate; synchronizable=exact false | success; canonical class; exact query key count 5; nil error |
| 50 | valid identity | Certificate; synchronizable=exact true | success; canonical class; exact query key count 5; nil error |
| 51 | canonical order | Certificate | kSecAttrAccessGroup, kSecAttrSynchronizable, then exact class tuple |
| 52 | query class | Certificate | kSecClass value is the exact supported Security constant |
| 53 | extra attributes | Certificate with label/comment/date/value-like unrelated fields | extras ignored; query remains whitelist-only |
| 54 | valid identity | Key; synchronizable=absent | success; canonical class; exact query key count 6; nil error |
| 55 | valid identity | Key; synchronizable=exact false | success; canonical class; exact query key count 6; nil error |
| 56 | valid identity | Key; synchronizable=exact true | success; canonical class; exact query key count 6; nil error |
| 57 | canonical order | Key | kSecAttrAccessGroup, kSecAttrSynchronizable, then exact class tuple |
| 58 | query class | Key | kSecClass value is the exact supported Security constant |
| 59 | extra attributes | Key with label/comment/date/value-like unrelated fields | extras ignored; query remains whitelist-only |
| 60 | valid identity | Identity; synchronizable=absent | success; canonical class; exact query key count 6; nil error |
| 61 | valid identity | Identity; synchronizable=exact false | success; canonical class; exact query key count 6; nil error |
| 62 | valid identity | Identity; synchronizable=exact true | success; canonical class; exact query key count 6; nil error |
| 63 | canonical order | Identity | kSecAttrAccessGroup, kSecAttrSynchronizable, then exact class tuple |
| 64 | query class | Identity | kSecClass value is the exact supported Security constant |
| 65 | extra attributes | Identity with label/comment/date/value-like unrelated fields | extras ignored; query remains whitelist-only |
| 66 | input type | nil | InvalidInput at root; no exception escapes |
| 67 | input type | NSArray | InvalidInput at root; no exception escapes |
| 68 | input type | NSSet | InvalidInput at root; no exception escapes |
| 69 | input type | NSString | InvalidInput at root; no exception escapes |
| 70 | input type | NSData | InvalidInput at root; no exception escapes |
| 71 | input type | NSNumber | InvalidInput at root; no exception escapes |
| 72 | input type | NSNull | InvalidInput at root; no exception escapes |
| 73 | input type | custom NSObject | InvalidInput at root; no exception escapes |
| 74 | input size | 0 dictionary entries | <=256 proceeds to field validation; >256 LimitExceeded |
| 75 | input size | 1 dictionary entries | <=256 proceeds to field validation; >256 LimitExceeded |
| 76 | input size | 255 dictionary entries | <=256 proceeds to field validation; >256 LimitExceeded |
| 77 | input size | 256 dictionary entries | <=256 proceeds to field validation; >256 LimitExceeded |
| 78 | input size | 257 dictionary entries | <=256 proceeds to field validation; >256 LimitExceeded |
| 79 | input size | 1000 dictionary entries | <=256 proceeds to field validation; >256 LimitExceeded |
| 80 | class validation | missing | UnsupportedClass; no metadata inference |
| 81 | class validation | Unknown enum number | UnsupportedClass; no metadata inference |
| 82 | class validation | plain string genp | UnsupportedClass; no metadata inference |
| 83 | class validation | copied equal-looking genp string | UnsupportedClass; no metadata inference |
| 84 | class validation | NSData | UnsupportedClass; no metadata inference |
| 85 | class validation | NSNumber | UnsupportedClass; no metadata inference |
| 86 | class validation | CFBoolean | UnsupportedClass; no metadata inference |
| 87 | class validation | collection | UnsupportedClass; no metadata inference |
| 88 | class validation | NSNull | UnsupportedClass; no metadata inference |
| 89 | class validation | unsupported Security constant | UnsupportedClass; no metadata inference |
| 90 | access group | missing | exact value validation; no trim/normalization; boundary-specific success or error |
| 91 | access group | empty | exact value validation; no trim/normalization; boundary-specific success or error |
| 92 | access group | NSNumber | exact value validation; no trim/normalization; boundary-specific success or error |
| 93 | access group | NSData | exact value validation; no trim/normalization; boundary-specific success or error |
| 94 | access group | NSArray | exact value validation; no trim/normalization; boundary-specific success or error |
| 95 | access group | NSDictionary | exact value validation; no trim/normalization; boundary-specific success or error |
| 96 | access group | NSNull | exact value validation; no trim/normalization; boundary-specific success or error |
| 97 | access group | embedded NUL | exact value validation; no trim/normalization; boundary-specific success or error |
| 98 | access group | C0 control | exact value validation; no trim/normalization; boundary-specific success or error |
| 99 | access group | C1 control | exact value validation; no trim/normalization; boundary-specific success or error |
| 100 | access group | invalid UTF-16/lossy UTF-8 | exact value validation; no trim/normalization; boundary-specific success or error |
| 101 | access group | 1024 ASCII bytes | exact value validation; no trim/normalization; boundary-specific success or error |
| 102 | access group | 1025 ASCII bytes | exact value validation; no trim/normalization; boundary-specific success or error |
| 103 | access group | 512 two-byte Unicode scalars | exact value validation; no trim/normalization; boundary-specific success or error |
| 104 | access group | leading space | exact value validation; no trim/normalization; boundary-specific success or error |
| 105 | access group | trailing space | exact value validation; no trim/normalization; boundary-specific success or error |
| 106 | access group | mixed case | exact value validation; no trim/normalization; boundary-specific success or error |
| 107 | synchronizable | absent | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 108 | synchronizable | kCFBooleanFalse | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 109 | synchronizable | kCFBooleanTrue | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 110 | synchronizable | NSNumber 0 | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 111 | synchronizable | NSNumber 1 | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 112 | synchronizable | integer 2 | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 113 | synchronizable | string false | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 114 | synchronizable | string true | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 115 | synchronizable | NSArray | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 116 | synchronizable | NSDictionary | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 117 | synchronizable | NSData | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 118 | synchronizable | NSNull | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 119 | synchronizable | kSecAttrSynchronizableAny | only absent/exact CFBoolean accepted; absent canonicalizes to false |
| 120 | string tuple | GenericPassword.account: missing | MissingIdentityAttribute |
| 121 | string tuple | GenericPassword.account: exact NSString | success with immutable exact snapshot |
| 122 | string tuple | GenericPassword.account: NSMutableString then caller mutation | success with immutable exact snapshot |
| 123 | string tuple | GenericPassword.account: empty | success with immutable exact snapshot |
| 124 | string tuple | GenericPassword.account: embedded NUL | specific type/value error |
| 125 | string tuple | GenericPassword.account: C0 control | specific type/value error |
| 126 | string tuple | GenericPassword.account: C1 control | specific type/value error |
| 127 | string tuple | GenericPassword.account: NSNumber | specific type/value error |
| 128 | string tuple | GenericPassword.account: NSData | specific type/value error |
| 129 | string tuple | GenericPassword.account: NSArray | specific type/value error |
| 130 | string tuple | GenericPassword.account: NSDictionary | specific type/value error |
| 131 | string tuple | GenericPassword.account: NSNull | specific type/value error |
| 132 | string tuple | GenericPassword.account: exact 4096 UTF-8 bytes | success with immutable exact snapshot |
| 133 | string tuple | GenericPassword.account: 4097 UTF-8 bytes | LimitExceeded |
| 134 | string tuple | GenericPassword.account: lossless multibyte boundary | success with immutable exact snapshot |
| 135 | string tuple | GenericPassword.account: unpaired surrogate | specific type/value error |
| 136 | string tuple | GenericPassword.service: missing | MissingIdentityAttribute |
| 137 | string tuple | GenericPassword.service: exact NSString | success with immutable exact snapshot |
| 138 | string tuple | GenericPassword.service: NSMutableString then caller mutation | success with immutable exact snapshot |
| 139 | string tuple | GenericPassword.service: empty | success with immutable exact snapshot |
| 140 | string tuple | GenericPassword.service: embedded NUL | specific type/value error |
| 141 | string tuple | GenericPassword.service: C0 control | specific type/value error |
| 142 | string tuple | GenericPassword.service: C1 control | specific type/value error |
| 143 | string tuple | GenericPassword.service: NSNumber | specific type/value error |
| 144 | string tuple | GenericPassword.service: NSData | specific type/value error |
| 145 | string tuple | GenericPassword.service: NSArray | specific type/value error |
| 146 | string tuple | GenericPassword.service: NSDictionary | specific type/value error |
| 147 | string tuple | GenericPassword.service: NSNull | specific type/value error |
| 148 | string tuple | GenericPassword.service: exact 4096 UTF-8 bytes | success with immutable exact snapshot |
| 149 | string tuple | GenericPassword.service: 4097 UTF-8 bytes | LimitExceeded |
| 150 | string tuple | GenericPassword.service: lossless multibyte boundary | success with immutable exact snapshot |
| 151 | string tuple | GenericPassword.service: unpaired surrogate | specific type/value error |
| 152 | string tuple | InternetPassword.account: missing | MissingIdentityAttribute |
| 153 | string tuple | InternetPassword.account: exact NSString | success with immutable exact snapshot |
| 154 | string tuple | InternetPassword.account: NSMutableString then caller mutation | success with immutable exact snapshot |
| 155 | string tuple | InternetPassword.account: empty | success with immutable exact snapshot |
| 156 | string tuple | InternetPassword.account: embedded NUL | specific type/value error |
| 157 | string tuple | InternetPassword.account: C0 control | specific type/value error |
| 158 | string tuple | InternetPassword.account: C1 control | specific type/value error |
| 159 | string tuple | InternetPassword.account: NSNumber | specific type/value error |
| 160 | string tuple | InternetPassword.account: NSData | specific type/value error |
| 161 | string tuple | InternetPassword.account: NSArray | specific type/value error |
| 162 | string tuple | InternetPassword.account: NSDictionary | specific type/value error |
| 163 | string tuple | InternetPassword.account: NSNull | specific type/value error |
| 164 | string tuple | InternetPassword.account: exact 4096 UTF-8 bytes | success with immutable exact snapshot |
| 165 | string tuple | InternetPassword.account: 4097 UTF-8 bytes | LimitExceeded |
| 166 | string tuple | InternetPassword.account: lossless multibyte boundary | success with immutable exact snapshot |
| 167 | string tuple | InternetPassword.account: unpaired surrogate | specific type/value error |
| 168 | string tuple | InternetPassword.server: missing | MissingIdentityAttribute |
| 169 | string tuple | InternetPassword.server: exact NSString | success with immutable exact snapshot |
| 170 | string tuple | InternetPassword.server: NSMutableString then caller mutation | success with immutable exact snapshot |
| 171 | string tuple | InternetPassword.server: empty | specific type/value error |
| 172 | string tuple | InternetPassword.server: embedded NUL | specific type/value error |
| 173 | string tuple | InternetPassword.server: C0 control | specific type/value error |
| 174 | string tuple | InternetPassword.server: C1 control | specific type/value error |
| 175 | string tuple | InternetPassword.server: NSNumber | specific type/value error |
| 176 | string tuple | InternetPassword.server: NSData | specific type/value error |
| 177 | string tuple | InternetPassword.server: NSArray | specific type/value error |
| 178 | string tuple | InternetPassword.server: NSDictionary | specific type/value error |
| 179 | string tuple | InternetPassword.server: NSNull | specific type/value error |
| 180 | string tuple | InternetPassword.server: exact 4096 UTF-8 bytes | success with immutable exact snapshot |
| 181 | string tuple | InternetPassword.server: 4097 UTF-8 bytes | LimitExceeded |
| 182 | string tuple | InternetPassword.server: lossless multibyte boundary | success with immutable exact snapshot |
| 183 | string tuple | InternetPassword.server: unpaired surrogate | specific type/value error |
| 184 | string tuple | InternetPassword.protocol: missing | MissingIdentityAttribute |
| 185 | string tuple | InternetPassword.protocol: exact NSString | success with immutable exact snapshot |
| 186 | string tuple | InternetPassword.protocol: NSMutableString then caller mutation | success with immutable exact snapshot |
| 187 | string tuple | InternetPassword.protocol: empty | specific type/value error |
| 188 | string tuple | InternetPassword.protocol: embedded NUL | specific type/value error |
| 189 | string tuple | InternetPassword.protocol: C0 control | specific type/value error |
| 190 | string tuple | InternetPassword.protocol: C1 control | specific type/value error |
| 191 | string tuple | InternetPassword.protocol: NSNumber | specific type/value error |
| 192 | string tuple | InternetPassword.protocol: NSData | specific type/value error |
| 193 | string tuple | InternetPassword.protocol: NSArray | specific type/value error |
| 194 | string tuple | InternetPassword.protocol: NSDictionary | specific type/value error |
| 195 | string tuple | InternetPassword.protocol: NSNull | specific type/value error |
| 196 | string tuple | InternetPassword.protocol: exact 255 UTF-8 bytes | success with immutable exact snapshot |
| 197 | string tuple | InternetPassword.protocol: 256 UTF-8 bytes | LimitExceeded |
| 198 | string tuple | InternetPassword.protocol: lossless multibyte boundary | success with immutable exact snapshot |
| 199 | string tuple | InternetPassword.protocol: unpaired surrogate | specific type/value error |
| 200 | string tuple | InternetPassword.authenticationType: missing | MissingIdentityAttribute |
| 201 | string tuple | InternetPassword.authenticationType: exact NSString | success with immutable exact snapshot |
| 202 | string tuple | InternetPassword.authenticationType: NSMutableString then caller mutation | success with immutable exact snapshot |
| 203 | string tuple | InternetPassword.authenticationType: empty | specific type/value error |
| 204 | string tuple | InternetPassword.authenticationType: embedded NUL | specific type/value error |
| 205 | string tuple | InternetPassword.authenticationType: C0 control | specific type/value error |
| 206 | string tuple | InternetPassword.authenticationType: C1 control | specific type/value error |
| 207 | string tuple | InternetPassword.authenticationType: NSNumber | specific type/value error |
| 208 | string tuple | InternetPassword.authenticationType: NSData | specific type/value error |
| 209 | string tuple | InternetPassword.authenticationType: NSArray | specific type/value error |
| 210 | string tuple | InternetPassword.authenticationType: NSDictionary | specific type/value error |
| 211 | string tuple | InternetPassword.authenticationType: NSNull | specific type/value error |
| 212 | string tuple | InternetPassword.authenticationType: exact 255 UTF-8 bytes | success with immutable exact snapshot |
| 213 | string tuple | InternetPassword.authenticationType: 256 UTF-8 bytes | LimitExceeded |
| 214 | string tuple | InternetPassword.authenticationType: lossless multibyte boundary | success with immutable exact snapshot |
| 215 | string tuple | InternetPassword.authenticationType: unpaired surrogate | specific type/value error |
| 216 | string tuple | InternetPassword.path: missing | MissingIdentityAttribute |
| 217 | string tuple | InternetPassword.path: exact NSString | success with immutable exact snapshot |
| 218 | string tuple | InternetPassword.path: NSMutableString then caller mutation | success with immutable exact snapshot |
| 219 | string tuple | InternetPassword.path: empty | success with immutable exact snapshot |
| 220 | string tuple | InternetPassword.path: embedded NUL | specific type/value error |
| 221 | string tuple | InternetPassword.path: C0 control | specific type/value error |
| 222 | string tuple | InternetPassword.path: C1 control | specific type/value error |
| 223 | string tuple | InternetPassword.path: NSNumber | specific type/value error |
| 224 | string tuple | InternetPassword.path: NSData | specific type/value error |
| 225 | string tuple | InternetPassword.path: NSArray | specific type/value error |
| 226 | string tuple | InternetPassword.path: NSDictionary | specific type/value error |
| 227 | string tuple | InternetPassword.path: NSNull | specific type/value error |
| 228 | string tuple | InternetPassword.path: exact 4096 UTF-8 bytes | success with immutable exact snapshot |
| 229 | string tuple | InternetPassword.path: 4097 UTF-8 bytes | LimitExceeded |
| 230 | string tuple | InternetPassword.path: lossless multibyte boundary | success with immutable exact snapshot |
| 231 | string tuple | InternetPassword.path: unpaired surrogate | specific type/value error |
| 232 | string tuple | InternetPassword.securityDomain: missing | MissingIdentityAttribute |
| 233 | string tuple | InternetPassword.securityDomain: exact NSString | success with immutable exact snapshot |
| 234 | string tuple | InternetPassword.securityDomain: NSMutableString then caller mutation | success with immutable exact snapshot |
| 235 | string tuple | InternetPassword.securityDomain: empty | success with immutable exact snapshot |
| 236 | string tuple | InternetPassword.securityDomain: embedded NUL | specific type/value error |
| 237 | string tuple | InternetPassword.securityDomain: C0 control | specific type/value error |
| 238 | string tuple | InternetPassword.securityDomain: C1 control | specific type/value error |
| 239 | string tuple | InternetPassword.securityDomain: NSNumber | specific type/value error |
| 240 | string tuple | InternetPassword.securityDomain: NSData | specific type/value error |
| 241 | string tuple | InternetPassword.securityDomain: NSArray | specific type/value error |
| 242 | string tuple | InternetPassword.securityDomain: NSDictionary | specific type/value error |
| 243 | string tuple | InternetPassword.securityDomain: NSNull | specific type/value error |
| 244 | string tuple | InternetPassword.securityDomain: exact 4096 UTF-8 bytes | success with immutable exact snapshot |
| 245 | string tuple | InternetPassword.securityDomain: 4097 UTF-8 bytes | LimitExceeded |
| 246 | string tuple | InternetPassword.securityDomain: lossless multibyte boundary | success with immutable exact snapshot |
| 247 | string tuple | InternetPassword.securityDomain: unpaired surrogate | specific type/value error |
| 248 | string tuple | Key.keyClass: missing | MissingIdentityAttribute |
| 249 | string tuple | Key.keyClass: exact NSString | success with immutable exact snapshot |
| 250 | string tuple | Key.keyClass: NSMutableString then caller mutation | success with immutable exact snapshot |
| 251 | string tuple | Key.keyClass: empty | specific type/value error |
| 252 | string tuple | Key.keyClass: embedded NUL | specific type/value error |
| 253 | string tuple | Key.keyClass: C0 control | specific type/value error |
| 254 | string tuple | Key.keyClass: C1 control | specific type/value error |
| 255 | string tuple | Key.keyClass: NSNumber | specific type/value error |
| 256 | string tuple | Key.keyClass: NSData | specific type/value error |
| 257 | string tuple | Key.keyClass: NSArray | specific type/value error |
| 258 | string tuple | Key.keyClass: NSDictionary | specific type/value error |
| 259 | string tuple | Key.keyClass: NSNull | specific type/value error |
| 260 | string tuple | Key.keyClass: exact 255 UTF-8 bytes | success with immutable exact snapshot |
| 261 | string tuple | Key.keyClass: 256 UTF-8 bytes | LimitExceeded |
| 262 | string tuple | Key.keyClass: lossless multibyte boundary | success with immutable exact snapshot |
| 263 | string tuple | Key.keyClass: unpaired surrogate | specific type/value error |
| 264 | string tuple | Key.keyType: missing | MissingIdentityAttribute |
| 265 | string tuple | Key.keyType: exact NSString | success with immutable exact snapshot |
| 266 | string tuple | Key.keyType: NSMutableString then caller mutation | success with immutable exact snapshot |
| 267 | string tuple | Key.keyType: empty | specific type/value error |
| 268 | string tuple | Key.keyType: embedded NUL | specific type/value error |
| 269 | string tuple | Key.keyType: C0 control | specific type/value error |
| 270 | string tuple | Key.keyType: C1 control | specific type/value error |
| 271 | string tuple | Key.keyType: NSNumber | specific type/value error |
| 272 | string tuple | Key.keyType: NSData | specific type/value error |
| 273 | string tuple | Key.keyType: NSArray | specific type/value error |
| 274 | string tuple | Key.keyType: NSDictionary | specific type/value error |
| 275 | string tuple | Key.keyType: NSNull | specific type/value error |
| 276 | string tuple | Key.keyType: exact 255 UTF-8 bytes | success with immutable exact snapshot |
| 277 | string tuple | Key.keyType: 256 UTF-8 bytes | LimitExceeded |
| 278 | string tuple | Key.keyType: lossless multibyte boundary | success with immutable exact snapshot |
| 279 | string tuple | Key.keyType: unpaired surrogate | specific type/value error |
| 280 | data tuple | Certificate.issuer: missing | Missing or AmbiguousIdentity according to tuple completeness |
| 281 | data tuple | Certificate.issuer: empty NSData | specific type/value error |
| 282 | data tuple | Certificate.issuer: one byte | success with immutable NSData snapshot |
| 283 | data tuple | Certificate.issuer: NSMutableData then caller mutation | success with immutable NSData snapshot |
| 284 | data tuple | Certificate.issuer: NSString | specific type/value error |
| 285 | data tuple | Certificate.issuer: NSNumber | specific type/value error |
| 286 | data tuple | Certificate.issuer: NSArray | specific type/value error |
| 287 | data tuple | Certificate.issuer: NSDictionary | specific type/value error |
| 288 | data tuple | Certificate.issuer: NSNull | specific type/value error |
| 289 | data tuple | Certificate.issuer: exact 65536 bytes | success with immutable NSData snapshot |
| 290 | data tuple | Certificate.issuer: 65537 bytes | LimitExceeded |
| 291 | data tuple | Certificate.serialNumber: missing | Missing or AmbiguousIdentity according to tuple completeness |
| 292 | data tuple | Certificate.serialNumber: empty NSData | specific type/value error |
| 293 | data tuple | Certificate.serialNumber: one byte | success with immutable NSData snapshot |
| 294 | data tuple | Certificate.serialNumber: NSMutableData then caller mutation | success with immutable NSData snapshot |
| 295 | data tuple | Certificate.serialNumber: NSString | specific type/value error |
| 296 | data tuple | Certificate.serialNumber: NSNumber | specific type/value error |
| 297 | data tuple | Certificate.serialNumber: NSArray | specific type/value error |
| 298 | data tuple | Certificate.serialNumber: NSDictionary | specific type/value error |
| 299 | data tuple | Certificate.serialNumber: NSNull | specific type/value error |
| 300 | data tuple | Certificate.serialNumber: exact 1024 bytes | success with immutable NSData snapshot |
| 301 | data tuple | Certificate.serialNumber: 1025 bytes | LimitExceeded |
| 302 | data tuple | Key.applicationLabel: missing | Missing or AmbiguousIdentity according to tuple completeness |
| 303 | data tuple | Key.applicationLabel: empty NSData | specific type/value error |
| 304 | data tuple | Key.applicationLabel: one byte | success with immutable NSData snapshot |
| 305 | data tuple | Key.applicationLabel: NSMutableData then caller mutation | success with immutable NSData snapshot |
| 306 | data tuple | Key.applicationLabel: NSString | specific type/value error |
| 307 | data tuple | Key.applicationLabel: NSNumber | specific type/value error |
| 308 | data tuple | Key.applicationLabel: NSArray | specific type/value error |
| 309 | data tuple | Key.applicationLabel: NSDictionary | specific type/value error |
| 310 | data tuple | Key.applicationLabel: NSNull | specific type/value error |
| 311 | data tuple | Key.applicationLabel: exact 1024 bytes | success with immutable NSData snapshot |
| 312 | data tuple | Key.applicationLabel: 1025 bytes | LimitExceeded |
| 313 | data tuple | Identity.applicationLabel: missing | Missing or AmbiguousIdentity according to tuple completeness |
| 314 | data tuple | Identity.applicationLabel: empty NSData | specific type/value error |
| 315 | data tuple | Identity.applicationLabel: one byte | success with immutable NSData snapshot |
| 316 | data tuple | Identity.applicationLabel: NSMutableData then caller mutation | success with immutable NSData snapshot |
| 317 | data tuple | Identity.applicationLabel: NSString | specific type/value error |
| 318 | data tuple | Identity.applicationLabel: NSNumber | specific type/value error |
| 319 | data tuple | Identity.applicationLabel: NSArray | specific type/value error |
| 320 | data tuple | Identity.applicationLabel: NSDictionary | specific type/value error |
| 321 | data tuple | Identity.applicationLabel: NSNull | specific type/value error |
| 322 | data tuple | Identity.applicationLabel: exact 1024 bytes | success with immutable NSData snapshot |
| 323 | data tuple | Identity.applicationLabel: 1025 bytes | LimitExceeded |
| 324 | data tuple | Identity.issuer: missing | Missing or AmbiguousIdentity according to tuple completeness |
| 325 | data tuple | Identity.issuer: empty NSData | specific type/value error |
| 326 | data tuple | Identity.issuer: one byte | success with immutable NSData snapshot |
| 327 | data tuple | Identity.issuer: NSMutableData then caller mutation | success with immutable NSData snapshot |
| 328 | data tuple | Identity.issuer: NSString | specific type/value error |
| 329 | data tuple | Identity.issuer: NSNumber | specific type/value error |
| 330 | data tuple | Identity.issuer: NSArray | specific type/value error |
| 331 | data tuple | Identity.issuer: NSDictionary | specific type/value error |
| 332 | data tuple | Identity.issuer: NSNull | specific type/value error |
| 333 | data tuple | Identity.issuer: exact 65536 bytes | success with immutable NSData snapshot |
| 334 | data tuple | Identity.issuer: 65537 bytes | LimitExceeded |
| 335 | data tuple | Identity.serialNumber: missing | Missing or AmbiguousIdentity according to tuple completeness |
| 336 | data tuple | Identity.serialNumber: empty NSData | specific type/value error |
| 337 | data tuple | Identity.serialNumber: one byte | success with immutable NSData snapshot |
| 338 | data tuple | Identity.serialNumber: NSMutableData then caller mutation | success with immutable NSData snapshot |
| 339 | data tuple | Identity.serialNumber: NSString | specific type/value error |
| 340 | data tuple | Identity.serialNumber: NSNumber | specific type/value error |
| 341 | data tuple | Identity.serialNumber: NSArray | specific type/value error |
| 342 | data tuple | Identity.serialNumber: NSDictionary | specific type/value error |
| 343 | data tuple | Identity.serialNumber: NSNull | specific type/value error |
| 344 | data tuple | Identity.serialNumber: exact 1024 bytes | success with immutable NSData snapshot |
| 345 | data tuple | Identity.serialNumber: 1025 bytes | LimitExceeded |
| 346 | internet port | missing | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 347 | internet port | 0 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 348 | internet port | 1 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 349 | internet port | 443 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 350 | internet port | 65535 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 351 | internet port | -1 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 352 | internet port | 65536 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 353 | internet port | 1.5 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 354 | internet port | NaN | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 355 | internet port | +Infinity | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 356 | internet port | -Infinity | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 357 | internet port | CFBoolean true | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 358 | internet port | CFBoolean false | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 359 | internet port | NSNumber decimal integral | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 360 | internet port | NSNumber decimal fractional | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 361 | internet port | NSString 443 | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 362 | internet port | NSData | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 363 | internet port | NSArray | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 364 | internet port | NSDictionary | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 365 | internet port | NSNull | accept only finite integral non-Boolean NSNumber in 0...65535; otherwise specific error/ambiguity |
| 366 | ambiguity | InternetPassword tuple missing account while other tuple fields exist | AmbiguousIdentity; no best-subset query |
| 367 | ambiguity | InternetPassword tuple missing server while other tuple fields exist | AmbiguousIdentity; no best-subset query |
| 368 | ambiguity | InternetPassword tuple missing port while other tuple fields exist | AmbiguousIdentity; no best-subset query |
| 369 | ambiguity | InternetPassword tuple missing protocol while other tuple fields exist | AmbiguousIdentity; no best-subset query |
| 370 | ambiguity | InternetPassword tuple missing authenticationType while other tuple fields exist | AmbiguousIdentity; no best-subset query |
| 371 | ambiguity | InternetPassword tuple missing path while other tuple fields exist | AmbiguousIdentity; no best-subset query |
| 372 | ambiguity | InternetPassword tuple missing securityDomain while other tuple fields exist | AmbiguousIdentity; no best-subset query |
| 373 | ambiguity | Certificate issuer only | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 374 | ambiguity | Certificate serial only | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 375 | ambiguity | Certificate label only | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 376 | ambiguity | Certificate subject only | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 377 | ambiguity | Certificate subjectKeyID only | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 378 | ambiguity | Certificate publicKeyHash only | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 379 | ambiguity | Certificate issuer plus label | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 380 | ambiguity | Certificate serial plus subject | AmbiguousIdentity or MissingIdentityAttribute; never infer fallback identity |
| 381 | ambiguity | Key applicationTag only | fail closed; no application-tag/label/key-size fallback |
| 382 | ambiguity | Key label only | fail closed; no application-tag/label/key-size fallback |
| 383 | ambiguity | Key effectiveKeySize only | fail closed; no application-tag/label/key-size fallback |
| 384 | ambiguity | Key keySizeInBits only | fail closed; no application-tag/label/key-size fallback |
| 385 | ambiguity | Key keyClass/keyType without applicationLabel | fail closed; no application-tag/label/key-size fallback |
| 386 | ambiguity | Identity applicationLabel only | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 387 | ambiguity | Identity issuer only | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 388 | ambiguity | Identity serial only | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 389 | ambiguity | Identity issuer+serial certificate-only | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 390 | ambiguity | Identity applicationLabel+issuer | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 391 | ambiguity | Identity applicationLabel+serial | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 392 | ambiguity | Identity key metadata only | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 393 | ambiguity | Identity certificate metadata only | AmbiguousIdentity or missing tuple; no certificate-only/key-only fallback |
| 394 | no inference | _class | never used to construct identity |
| 395 | no inference | _secClass | never used to construct identity |
| 396 | no inference | label | never used to construct identity |
| 397 | no inference | persistent reference | never used to construct identity |
| 398 | no inference | value data | never used to construct identity |
| 399 | no inference | value ref | never used to construct identity |
| 400 | no inference | public-key hash | never used to construct identity |
| 401 | no inference | application tag | never used to construct identity |
| 402 | no inference | subject | never used to construct identity |
| 403 | no inference | key size | never used to construct identity |
| 404 | no inference | best available subset | never used to construct identity |
| 405 | match query key | GenericPassword: kSecClass | present exactly once; total key count 5 |
| 406 | match query key | GenericPassword: accessGroup | present exactly once; total key count 5 |
| 407 | match query key | GenericPassword: synchronizable | present exactly once; total key count 5 |
| 408 | match query key | GenericPassword: account | present exactly once; total key count 5 |
| 409 | match query key | GenericPassword: service | present exactly once; total key count 5 |
| 410 | match query key | InternetPassword: kSecClass | present exactly once; total key count 10 |
| 411 | match query key | InternetPassword: accessGroup | present exactly once; total key count 10 |
| 412 | match query key | InternetPassword: synchronizable | present exactly once; total key count 10 |
| 413 | match query key | InternetPassword: account | present exactly once; total key count 10 |
| 414 | match query key | InternetPassword: server | present exactly once; total key count 10 |
| 415 | match query key | InternetPassword: port | present exactly once; total key count 10 |
| 416 | match query key | InternetPassword: protocol | present exactly once; total key count 10 |
| 417 | match query key | InternetPassword: authenticationType | present exactly once; total key count 10 |
| 418 | match query key | InternetPassword: path | present exactly once; total key count 10 |
| 419 | match query key | InternetPassword: securityDomain | present exactly once; total key count 10 |
| 420 | match query key | Certificate: kSecClass | present exactly once; total key count 5 |
| 421 | match query key | Certificate: accessGroup | present exactly once; total key count 5 |
| 422 | match query key | Certificate: synchronizable | present exactly once; total key count 5 |
| 423 | match query key | Certificate: issuer | present exactly once; total key count 5 |
| 424 | match query key | Certificate: serialNumber | present exactly once; total key count 5 |
| 425 | match query key | Key: kSecClass | present exactly once; total key count 6 |
| 426 | match query key | Key: accessGroup | present exactly once; total key count 6 |
| 427 | match query key | Key: synchronizable | present exactly once; total key count 6 |
| 428 | match query key | Key: applicationLabel | present exactly once; total key count 6 |
| 429 | match query key | Key: keyClass | present exactly once; total key count 6 |
| 430 | match query key | Key: keyType | present exactly once; total key count 6 |
| 431 | match query key | Identity: kSecClass | present exactly once; total key count 6 |
| 432 | match query key | Identity: accessGroup | present exactly once; total key count 6 |
| 433 | match query key | Identity: synchronizable | present exactly once; total key count 6 |
| 434 | match query key | Identity: applicationLabel | present exactly once; total key count 6 |
| 435 | match query key | Identity: issuer | present exactly once; total key count 6 |
| 436 | match query key | Identity: serialNumber | present exactly once; total key count 6 |
| 437 | forbidden query key | kSecMatchLimit | absent from every matchQuery |
| 438 | forbidden query key | kSecReturnAttributes | absent from every matchQuery |
| 439 | forbidden query key | kSecReturnData | absent from every matchQuery |
| 440 | forbidden query key | kSecReturnRef | absent from every matchQuery |
| 441 | forbidden query key | kSecReturnPersistentRef | absent from every matchQuery |
| 442 | forbidden query key | kSecUseAuthenticationUI | absent from every matchQuery |
| 443 | forbidden query key | kSecUseOperationPrompt | absent from every matchQuery |
| 444 | forbidden query key | kSecValueData | absent from every matchQuery |
| 445 | forbidden query key | kSecValueRef | absent from every matchQuery |
| 446 | forbidden query key | kSecValuePersistentRef | absent from every matchQuery |
| 447 | forbidden query key | kSecAttrSynchronizableAny | absent from every matchQuery |
| 448 | forbidden query key | label | absent from every matchQuery |
| 449 | forbidden query key | comment | absent from every matchQuery |
| 450 | forbidden query key | description | absent from every matchQuery |
| 451 | forbidden query key | creationDate | absent from every matchQuery |
| 452 | forbidden query key | modificationDate | absent from every matchQuery |
| 453 | forbidden query key | accessControl | absent from every matchQuery |
| 454 | deep copy | caller dictionary | post-construction caller mutation cannot change retained identity |
| 455 | deep copy | mutable accessGroup | post-construction caller mutation cannot change retained identity |
| 456 | deep copy | mutable account | post-construction caller mutation cannot change retained identity |
| 457 | deep copy | mutable service | post-construction caller mutation cannot change retained identity |
| 458 | deep copy | mutable server | post-construction caller mutation cannot change retained identity |
| 459 | deep copy | mutable path | post-construction caller mutation cannot change retained identity |
| 460 | deep copy | mutable securityDomain | post-construction caller mutation cannot change retained identity |
| 461 | deep copy | mutable issuer | post-construction caller mutation cannot change retained identity |
| 462 | deep copy | mutable serialNumber | post-construction caller mutation cannot change retained identity |
| 463 | deep copy | mutable applicationLabel | post-construction caller mutation cannot change retained identity |
| 464 | deep copy | identityAttributeNames array | post-construction caller mutation cannot change retained identity |
| 465 | deep copy | identityAttributes dictionary | post-construction caller mutation cannot change retained identity |
| 466 | deep copy | matchQuery dictionary | post-construction caller mutation cannot change retained identity |
| 467 | deep copy | port NSNumber | post-construction caller mutation cannot change retained identity |
| 468 | deep copy | synchronizable NSNumber | post-construction caller mutation cannot change retained identity |
| 469 | privacy | access group | absent from NSError userInfo and description/debugDescription |
| 470 | privacy | account | absent from NSError userInfo and description/debugDescription |
| 471 | privacy | service | absent from NSError userInfo and description/debugDescription |
| 472 | privacy | server | absent from NSError userInfo and description/debugDescription |
| 473 | privacy | path | absent from NSError userInfo and description/debugDescription |
| 474 | privacy | security domain | absent from NSError userInfo and description/debugDescription |
| 475 | privacy | issuer bytes | absent from NSError userInfo and description/debugDescription |
| 476 | privacy | serial bytes | absent from NSError userInfo and description/debugDescription |
| 477 | privacy | applicationLabel bytes | absent from NSError userInfo and description/debugDescription |
| 478 | privacy | protocol value | absent from NSError userInfo and description/debugDescription |
| 479 | privacy | authenticationType value | absent from NSError userInfo and description/debugDescription |
| 480 | privacy | keyClass value | absent from NSError userInfo and description/debugDescription |
| 481 | privacy | keyType value | absent from NSError userInfo and description/debugDescription |
| 482 | privacy | input dictionary | absent from NSError userInfo and description/debugDescription |
| 483 | privacy | underlying exception | absent from NSError userInfo and description/debugDescription |
| 484 | exception boundary | input count accessor throws | caught; nil result; InternalInvariantFailed with generic error |
| 485 | exception boundary | dictionary snapshot throws | caught; nil result; InternalInvariantFailed with generic error |
| 486 | exception boundary | malicious NSString selector throws | caught; nil result; InternalInvariantFailed with generic error |
| 487 | exception boundary | malicious NSData selector throws | caught; nil result; InternalInvariantFailed with generic error |
| 488 | exception boundary | malicious NSNumber selector throws | caught; nil result; InternalInvariantFailed with generic error |
| 489 | exception boundary | collection copy throws | caught; nil result; InternalInvariantFailed with generic error |
| 490 | exception boundary | query dictionary insertion throws | caught; nil result; InternalInvariantFailed with generic error |
| 491 | exception boundary | object initialization throws | caught; nil result; InternalInvariantFailed with generic error |
| 492 | purity | SecItemCopyMatching | zero calls in new implementation |
| 493 | purity | SecItemAdd | zero calls in new implementation |
| 494 | purity | SecItemUpdate | zero calls in new implementation |
| 495 | purity | SecItemDelete | zero calls in new implementation |
| 496 | purity | SecItemImport | zero calls in new implementation |
| 497 | purity | SecItemExport | zero calls in new implementation |
| 498 | purity | filesystem read | zero calls in new implementation |
| 499 | purity | filesystem write | zero calls in new implementation |
| 500 | purity | shell/process spawn | zero calls in new implementation |
| 501 | purity | network request | zero calls in new implementation |
| 502 | purity | dispatch queue | zero calls in new implementation |
| 503 | purity | notification bridge | zero calls in new implementation |
| 504 | purity | logging | zero calls in new implementation |
| 505 | non-regression | KeychainBackupHelper.h | byte-identical |
| 506 | non-regression | KeychainBackupHelper.m | byte-identical |
| 507 | non-regression | backup_helper.m | byte-identical |
| 508 | non-regression | scripts/keychain_backup.sh | byte-identical |
| 509 | non-regression | PXKeychainHelperResult.h | byte-identical |
| 510 | non-regression | PXKeychainHelperResult.m | byte-identical |
| 511 | non-regression | PXKeychainHelperExitCode.h | byte-identical |
| 512 | non-regression | AppDataBackupManager.h/.m | byte-identical |
| 513 | non-regression | AppDataCleaner.h/.m | byte-identical |
| 514 | non-regression | WeaponXKeychainBridge/Tweak.m | byte-identical |
| 515 | non-regression | restore identity construction | zero references |
| 516 | non-regression | restore preflight lookup | not implemented |
| 517 | non-regression | restore SecItemDelete | zero |
| 518 | non-regression | restore SecItemUpdate | zero |
| 519 | non-regression | core SecItemCopyMatching | 5 |
| 520 | non-regression | core SecItemAdd | 1 |
| 521 | non-regression | core SecItemDelete | 1 |
| 522 | non-regression | core SecItemUpdate | 0 |
| 523 | non-regression | TASK-4.1 schema | unchanged |
| 524 | non-regression | TASK-4.1 framing | unchanged |
| 525 | non-regression | TASK-4.2 finalizer | one definition; sixteen non-help calls |
| 526 | non-regression | TASK-4.2 exit taxonomy | thirteen values unchanged |
| 527 | non-regression | TASK-4.3 duplicate NO warning | unchanged |
| 528 | non-regression | TASK-4.3 duplicate YES warning | unchanged |
| 529 | non-regression | TASK-4.3 overwrite compatibility | unchanged |
| 530 | non-regression | manager/cleaner result parsing | not implemented |
| 531 | non-regression | TASK-4.5 lookup/upsert | not implemented |
| 532 | non-regression | rollback | not implemented |
| 533 | non-regression | UI | not modified |

## Full authorized production diff
The report excludes its own diff/hash to avoid recursive self-embedding.
```diff
diff --git a/KeychainHelper/PXKeychainItemIdentity.h b/KeychainHelper/PXKeychainItemIdentity.h
new file mode 100644
index 0000000..a1cc68b
--- /dev/null
+++ b/KeychainHelper/PXKeychainItemIdentity.h
@@ -0,0 +1,54 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSInteger const PXKeychainItemIdentitySchemaVersion;
+FOUNDATION_EXPORT NSErrorDomain const PXKeychainItemIdentityErrorDomain;
+FOUNDATION_EXPORT NSString * const PXKeychainItemIdentityErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXKeychainItemIdentityClass) {
+    PXKeychainItemIdentityClassUnknown = 0,
+    PXKeychainItemIdentityClassGenericPassword = 1,
+    PXKeychainItemIdentityClassInternetPassword = 2,
+    PXKeychainItemIdentityClassCertificate = 3,
+    PXKeychainItemIdentityClassKey = 4,
+    PXKeychainItemIdentityClassIdentity = 5,
+};
+
+typedef NS_ERROR_ENUM(PXKeychainItemIdentityErrorDomain,
+                      PXKeychainItemIdentityErrorCode) {
+    PXKeychainItemIdentityErrorInvalidInput = 1,
+    PXKeychainItemIdentityErrorUnsupportedClass = 2,
+    PXKeychainItemIdentityErrorMissingAccessGroup = 3,
+    PXKeychainItemIdentityErrorInvalidAccessGroup = 4,
+    PXKeychainItemIdentityErrorMissingIdentityAttribute = 5,
+    PXKeychainItemIdentityErrorInvalidIdentityAttributeType = 6,
+    PXKeychainItemIdentityErrorInvalidIdentityAttributeValue = 7,
+    PXKeychainItemIdentityErrorInvalidSynchronizable = 8,
+    PXKeychainItemIdentityErrorAmbiguousIdentity = 9,
+    PXKeychainItemIdentityErrorLimitExceeded = 10,
+    PXKeychainItemIdentityErrorSnapshotFailed = 11,
+    PXKeychainItemIdentityErrorInternalInvariantFailed = 12,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXKeychainItemIdentity : NSObject <NSCopying>
+
+@property (nonatomic, readonly) NSInteger schemaVersion;
+@property (nonatomic, readonly) PXKeychainItemIdentityClass itemClass;
+@property (nonatomic, copy, readonly) NSString *className;
+@property (nonatomic, copy, readonly) NSString *accessGroup;
+@property (nonatomic, readonly, getter=isSynchronizable) BOOL synchronizable;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *identityAttributeNames;
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *identityAttributes;
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *matchQuery;
+
++ (nullable instancetype)identityForSecurityItemAttributes:(NSDictionary<NSString *, id> *)attributes
+                                                     error:(NSError **)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/KeychainHelper/PXKeychainItemIdentity.m b/KeychainHelper/PXKeychainItemIdentity.m
new file mode 100644
index 0000000..8fbff4b
--- /dev/null
+++ b/KeychainHelper/PXKeychainItemIdentity.m
@@ -0,0 +1,1191 @@
+#import "PXKeychainItemIdentity.h"
+#import <Security/Security.h>
+#import <CoreFoundation/CoreFoundation.h>
+#import <math.h>
+#import <stdint.h>
+
+NSInteger const PXKeychainItemIdentitySchemaVersion = 1;
+NSErrorDomain const PXKeychainItemIdentityErrorDomain = @"com.hydra.projectx.keychain-item-identity";
+NSString * const PXKeychainItemIdentityErrorFieldPathKey = @"fieldPath";
+
+static const NSUInteger PXKeychainItemIdentityMaximumInputEntries = 256;
+static const NSUInteger PXKeychainItemIdentityMaximumAccessGroupBytes = 1024;
+static const NSUInteger PXKeychainItemIdentityMaximumOrdinaryStringBytes = 4096;
+static const NSUInteger PXKeychainItemIdentityMaximumConstantStringBytes = 255;
+static const NSUInteger PXKeychainItemIdentityMaximumIssuerBytes = 65536;
+static const NSUInteger PXKeychainItemIdentityMaximumSerialNumberBytes = 1024;
+static const NSUInteger PXKeychainItemIdentityMaximumApplicationLabelBytes = 1024;
+static const NSUInteger PXKeychainItemIdentityMaximumAttributeCount = 10;
+static const NSUInteger PXKeychainItemIdentityMaximumQueryKeyCount = 10;
+static const NSUInteger PXKeychainItemIdentityMaximumAggregateBytes = 131072;
+
+static NSString * const PXKeychainItemIdentityRootFieldPath = @"$";
+static NSString * const PXKeychainItemIdentityClassFieldPath = @"$.kSecClass";
+static NSString * const PXKeychainItemIdentityAccessGroupFieldPath = @"$.kSecAttrAccessGroup";
+static NSString * const PXKeychainItemIdentitySynchronizableFieldPath = @"$.kSecAttrSynchronizable";
+static NSString * const PXKeychainItemIdentityAccountFieldPath = @"$.kSecAttrAccount";
+static NSString * const PXKeychainItemIdentityServiceFieldPath = @"$.kSecAttrService";
+static NSString * const PXKeychainItemIdentityServerFieldPath = @"$.kSecAttrServer";
+static NSString * const PXKeychainItemIdentityPortFieldPath = @"$.kSecAttrPort";
+static NSString * const PXKeychainItemIdentityProtocolFieldPath = @"$.kSecAttrProtocol";
+static NSString * const PXKeychainItemIdentityAuthenticationTypeFieldPath = @"$.kSecAttrAuthenticationType";
+static NSString * const PXKeychainItemIdentityPathFieldPath = @"$.kSecAttrPath";
+static NSString * const PXKeychainItemIdentitySecurityDomainFieldPath = @"$.kSecAttrSecurityDomain";
+static NSString * const PXKeychainItemIdentityIssuerFieldPath = @"$.kSecAttrIssuer";
+static NSString * const PXKeychainItemIdentitySerialNumberFieldPath = @"$.kSecAttrSerialNumber";
+static NSString * const PXKeychainItemIdentityApplicationLabelFieldPath = @"$.kSecAttrApplicationLabel";
+static NSString * const PXKeychainItemIdentityKeyClassFieldPath = @"$.kSecAttrKeyClass";
+static NSString * const PXKeychainItemIdentityKeyTypeFieldPath = @"$.kSecAttrKeyType";
+static NSString * const PXKeychainItemIdentityTupleFieldPath = @"$.identity";
+
+typedef NS_ENUM(NSInteger, PXKeychainItemIdentityValueStatus) {
+    PXKeychainItemIdentityValueStatusSuccess = 0,
+    PXKeychainItemIdentityValueStatusMissing = 1,
+    PXKeychainItemIdentityValueStatusWrongType = 2,
+    PXKeychainItemIdentityValueStatusInvalidValue = 3,
+    PXKeychainItemIdentityValueStatusLimitExceeded = 4,
+    PXKeychainItemIdentityValueStatusSnapshotFailed = 5,
+};
+
+static void PXKeychainItemIdentitySetError(NSError **error,
+                                            PXKeychainItemIdentityErrorCode code,
+                                            NSString *fieldPath,
+                                            NSString *description) {
+    if (!error) {
+        return;
+    }
+    *error = [NSError errorWithDomain:PXKeychainItemIdentityErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXKeychainItemIdentityErrorFieldPathKey: fieldPath,
+                             }];
+}
+
+static BOOL PXKeychainItemIdentityExtractExactCFBoolean(id value,
+                                                         BOOL *booleanOut) {
+    if (![value isKindOfClass:[NSNumber class]]) {
+        return NO;
+    }
+    CFTypeRef cfValue = (__bridge CFTypeRef)value;
+    if (CFGetTypeID(cfValue) != CFBooleanGetTypeID()) {
+        return NO;
+    }
+    if (booleanOut) {
+        *booleanOut = CFBooleanGetValue((__bridge CFBooleanRef)value);
+    }
+    return YES;
+}
+
+static BOOL PXKeychainItemIdentityIsString(id value) {
+    return [value isKindOfClass:[NSString class]] &&
+           CFGetTypeID((__bridge CFTypeRef)value) == CFStringGetTypeID();
+}
+
+static BOOL PXKeychainItemIdentityIsData(id value) {
+    return [value isKindOfClass:[NSData class]] &&
+           CFGetTypeID((__bridge CFTypeRef)value) == CFDataGetTypeID();
+}
+
+static BOOL PXKeychainItemIdentityStringContainsControlCharacter(NSString *string) {
+    NSUInteger length = string.length;
+    for (NSUInteger index = 0; index < length; index++) {
+        unichar character = [string characterAtIndex:index];
+        if (character <= 0x001F ||
+            (character >= 0x007F && character <= 0x009F)) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static PXKeychainItemIdentityValueStatus PXKeychainItemIdentityCopyString(
+    id value,
+    BOOL allowEmpty,
+    NSUInteger maximumBytes,
+    NSString **stringOut,
+    NSUInteger *byteCountOut) {
+    if (!value) {
+        return PXKeychainItemIdentityValueStatusMissing;
+    }
+    if (!PXKeychainItemIdentityIsString(value)) {
+        return PXKeychainItemIdentityValueStatusWrongType;
+    }
+
+    NSString *string = (NSString *)value;
+    NSData *utf8 = [string dataUsingEncoding:NSUTF8StringEncoding
+                        allowLossyConversion:NO];
+    if (!utf8) {
+        return PXKeychainItemIdentityValueStatusInvalidValue;
+    }
+    if (utf8.length > maximumBytes) {
+        return PXKeychainItemIdentityValueStatusLimitExceeded;
+    }
+
+    NSString *snapshot = [[NSString alloc] initWithData:utf8
+                                                 encoding:NSUTF8StringEncoding];
+    if (!snapshot) {
+        return PXKeychainItemIdentityValueStatusSnapshotFailed;
+    }
+    if (![snapshot isEqualToString:string] ||
+        (!allowEmpty && snapshot.length == 0) ||
+        PXKeychainItemIdentityStringContainsControlCharacter(snapshot)) {
+        return PXKeychainItemIdentityValueStatusInvalidValue;
+    }
+
+    if (stringOut) {
+        *stringOut = snapshot;
+    }
+    if (byteCountOut) {
+        *byteCountOut = utf8.length;
+    }
+    return PXKeychainItemIdentityValueStatusSuccess;
+}
+
+static PXKeychainItemIdentityValueStatus PXKeychainItemIdentityCopyData(
+    id value,
+    NSUInteger maximumBytes,
+    NSData **dataOut,
+    NSUInteger *byteCountOut) {
+    if (!value) {
+        return PXKeychainItemIdentityValueStatusMissing;
+    }
+    if (!PXKeychainItemIdentityIsData(value)) {
+        return PXKeychainItemIdentityValueStatusWrongType;
+    }
+
+    NSData *data = (NSData *)value;
+    NSUInteger length = data.length;
+    if (length == 0) {
+        return PXKeychainItemIdentityValueStatusInvalidValue;
+    }
+    if (length > maximumBytes) {
+        return PXKeychainItemIdentityValueStatusLimitExceeded;
+    }
+
+    NSData *snapshot = [[NSData alloc] initWithData:data];
+    if (!snapshot || snapshot.length != length) {
+        return PXKeychainItemIdentityValueStatusSnapshotFailed;
+    }
+    if (dataOut) {
+        *dataOut = snapshot;
+    }
+    if (byteCountOut) {
+        *byteCountOut = length;
+    }
+    return PXKeychainItemIdentityValueStatusSuccess;
+}
+
+static PXKeychainItemIdentityValueStatus PXKeychainItemIdentityCopyPort(
+    id value,
+    NSNumber **numberOut,
+    NSUInteger *byteCountOut) {
+    if (!value) {
+        return PXKeychainItemIdentityValueStatusMissing;
+    }
+    if (![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) {
+        return PXKeychainItemIdentityValueStatusWrongType;
+    }
+
+    BOOL booleanValue = NO;
+    if (PXKeychainItemIdentityExtractExactCFBoolean(value, &booleanValue)) {
+        (void)booleanValue;
+        return PXKeychainItemIdentityValueStatusWrongType;
+    }
+
+    double port = [(NSNumber *)value doubleValue];
+    if (!isfinite(port) || floor(port) != port || port < 0.0 || port > 65535.0) {
+        return PXKeychainItemIdentityValueStatusInvalidValue;
+    }
+
+    NSNumber *snapshot = [NSNumber numberWithUnsignedInteger:(NSUInteger)port];
+    if (!snapshot) {
+        return PXKeychainItemIdentityValueStatusSnapshotFailed;
+    }
+    if (numberOut) {
+        *numberOut = snapshot;
+    }
+    if (byteCountOut) {
+        *byteCountOut = sizeof(uint64_t);
+    }
+    return PXKeychainItemIdentityValueStatusSuccess;
+}
+
+static void PXKeychainItemIdentitySetAttributeError(
+    PXKeychainItemIdentityValueStatus status,
+    NSString *fieldPath,
+    NSError **error) {
+    switch (status) {
+        case PXKeychainItemIdentityValueStatusMissing:
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorMissingIdentityAttribute,
+                                            fieldPath,
+                                            @"A required identity attribute is missing.");
+            break;
+        case PXKeychainItemIdentityValueStatusWrongType:
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorInvalidIdentityAttributeType,
+                                            fieldPath,
+                                            @"An identity attribute has an invalid type.");
+            break;
+        case PXKeychainItemIdentityValueStatusInvalidValue:
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorInvalidIdentityAttributeValue,
+                                            fieldPath,
+                                            @"An identity attribute has an invalid value.");
+            break;
+        case PXKeychainItemIdentityValueStatusLimitExceeded:
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorLimitExceeded,
+                                            fieldPath,
+                                            @"An identity attribute exceeds a fixed limit.");
+            break;
+        case PXKeychainItemIdentityValueStatusSnapshotFailed:
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorSnapshotFailed,
+                                            fieldPath,
+                                            @"An immutable identity attribute snapshot could not be created.");
+            break;
+        case PXKeychainItemIdentityValueStatusSuccess:
+            break;
+    }
+}
+
+static BOOL PXKeychainItemIdentitySafeAdd(NSUInteger *total,
+                                           NSUInteger amount) {
+    if (!total || amount > NSUIntegerMax - *total) {
+        return NO;
+    }
+    *total += amount;
+    return YES;
+}
+
+static NSUInteger PXKeychainItemIdentityStringByteCount(NSString *string) {
+    NSData *utf8 = [string dataUsingEncoding:NSUTF8StringEncoding
+                        allowLossyConversion:NO];
+    return utf8 ? utf8.length : NSUIntegerMax;
+}
+
+static NSString *PXKeychainItemIdentityClassName(PXKeychainItemIdentityClass itemClass) {
+    switch (itemClass) {
+        case PXKeychainItemIdentityClassUnknown:
+            return @"unknown";
+        case PXKeychainItemIdentityClassGenericPassword:
+            return @"generic-password";
+        case PXKeychainItemIdentityClassInternetPassword:
+            return @"internet-password";
+        case PXKeychainItemIdentityClassCertificate:
+            return @"certificate";
+        case PXKeychainItemIdentityClassKey:
+            return @"key";
+        case PXKeychainItemIdentityClassIdentity:
+            return @"identity";
+    }
+    return nil;
+}
+
+static BOOL PXKeychainItemIdentityResolveClass(
+    id classValue,
+    PXKeychainItemIdentityClass *itemClassOut,
+    CFStringRef *securityClassOut,
+    NSUInteger *expectedQueryCountOut) {
+    if (!PXKeychainItemIdentityIsString(classValue)) {
+        return NO;
+    }
+
+    PXKeychainItemIdentityClass itemClass = PXKeychainItemIdentityClassUnknown;
+    CFStringRef securityClass = NULL;
+    NSUInteger expectedQueryCount = 0;
+
+    if (classValue == (__bridge id)kSecClassGenericPassword) {
+        itemClass = PXKeychainItemIdentityClassGenericPassword;
+        securityClass = kSecClassGenericPassword;
+        expectedQueryCount = 5;
+    } else if (classValue == (__bridge id)kSecClassInternetPassword) {
+        itemClass = PXKeychainItemIdentityClassInternetPassword;
+        securityClass = kSecClassInternetPassword;
+        expectedQueryCount = 10;
+    } else if (classValue == (__bridge id)kSecClassCertificate) {
+        itemClass = PXKeychainItemIdentityClassCertificate;
+        securityClass = kSecClassCertificate;
+        expectedQueryCount = 5;
+    } else if (classValue == (__bridge id)kSecClassKey) {
+        itemClass = PXKeychainItemIdentityClassKey;
+        securityClass = kSecClassKey;
+        expectedQueryCount = 6;
+    } else if (classValue == (__bridge id)kSecClassIdentity) {
+        itemClass = PXKeychainItemIdentityClassIdentity;
+        securityClass = kSecClassIdentity;
+        expectedQueryCount = 6;
+    } else {
+        return NO;
+    }
+
+    if (itemClassOut) {
+        *itemClassOut = itemClass;
+    }
+    if (securityClassOut) {
+        *securityClassOut = securityClass;
+    }
+    if (expectedQueryCountOut) {
+        *expectedQueryCountOut = expectedQueryCount;
+    }
+    return YES;
+}
+
+static BOOL PXKeychainItemIdentityHasInternetFallbackAttributes(NSDictionary *attributes) {
+    return attributes[(__bridge id)kSecAttrAccount] != nil ||
+           attributes[(__bridge id)kSecAttrServer] != nil ||
+           attributes[(__bridge id)kSecAttrPort] != nil ||
+           attributes[(__bridge id)kSecAttrProtocol] != nil ||
+           attributes[(__bridge id)kSecAttrAuthenticationType] != nil ||
+           attributes[(__bridge id)kSecAttrPath] != nil ||
+           attributes[(__bridge id)kSecAttrSecurityDomain] != nil ||
+           attributes[(__bridge id)kSecAttrLabel] != nil ||
+           attributes[(__bridge id)kSecAttrDescription] != nil ||
+           attributes[(__bridge id)kSecAttrComment] != nil;
+}
+
+static BOOL PXKeychainItemIdentityHasCertificateFallbackAttributes(NSDictionary *attributes) {
+    return attributes[(__bridge id)kSecAttrLabel] != nil ||
+           attributes[(__bridge id)kSecAttrSubject] != nil ||
+           attributes[(__bridge id)kSecAttrSubjectKeyID] != nil ||
+           attributes[(__bridge id)kSecAttrPublicKeyHash] != nil;
+}
+
+static BOOL PXKeychainItemIdentityHasKeyFallbackAttributes(NSDictionary *attributes) {
+    return attributes[(__bridge id)kSecAttrApplicationTag] != nil ||
+           attributes[(__bridge id)kSecAttrLabel] != nil ||
+           attributes[(__bridge id)kSecAttrEffectiveKeySize] != nil ||
+           attributes[(__bridge id)kSecAttrKeySizeInBits] != nil;
+}
+
+static BOOL PXKeychainItemIdentityHasIdentityFallbackAttributes(NSDictionary *attributes) {
+    return PXKeychainItemIdentityHasCertificateFallbackAttributes(attributes) ||
+           PXKeychainItemIdentityHasKeyFallbackAttributes(attributes) ||
+           attributes[(__bridge id)kSecAttrKeyClass] != nil ||
+           attributes[(__bridge id)kSecAttrKeyType] != nil;
+}
+
+static BOOL PXKeychainItemIdentityAppendAttribute(
+    NSMutableArray<NSString *> *names,
+    NSMutableDictionary<NSString *, id> *identityAttributes,
+    CFStringRef key,
+    id value,
+    NSUInteger valueByteCount,
+    NSUInteger *aggregateByteCount) {
+    if (!names || !identityAttributes || !key || !value || !aggregateByteCount ||
+        names.count >= PXKeychainItemIdentityMaximumAttributeCount) {
+        return NO;
+    }
+
+    NSString *keySnapshot = [(__bridge NSString *)key copy];
+    if (!keySnapshot || identityAttributes[keySnapshot] != nil) {
+        return NO;
+    }
+    NSUInteger keyByteCount = PXKeychainItemIdentityStringByteCount(keySnapshot);
+    if (keyByteCount == NSUIntegerMax ||
+        !PXKeychainItemIdentitySafeAdd(aggregateByteCount, keyByteCount) ||
+        !PXKeychainItemIdentitySafeAdd(aggregateByteCount, valueByteCount) ||
+        *aggregateByteCount > PXKeychainItemIdentityMaximumAggregateBytes) {
+        return NO;
+    }
+
+    [names addObject:keySnapshot];
+    identityAttributes[keySnapshot] = value;
+    return YES;
+}
+
+static BOOL PXKeychainItemIdentityValueIsImmutablePropertyListPrimitive(id value) {
+    if (PXKeychainItemIdentityIsString(value)) {
+        return ![value isKindOfClass:[NSMutableString class]];
+    }
+    if (PXKeychainItemIdentityIsData(value)) {
+        return ![value isKindOfClass:[NSMutableData class]];
+    }
+    return [value isKindOfClass:[NSNumber class]];
+}
+
+static BOOL PXKeychainItemIdentitySnapshotMatchesState(
+    PXKeychainItemIdentityClass itemClass,
+    NSString *className,
+    NSString *accessGroup,
+    BOOL synchronizable,
+    NSArray<NSString *> *identityAttributeNames,
+    NSDictionary<NSString *, id> *identityAttributes,
+    NSDictionary<NSString *, id> *matchQuery,
+    CFStringRef securityClass,
+    NSUInteger expectedQueryCount) {
+    if (itemClass == PXKeychainItemIdentityClassUnknown ||
+        ![className isEqualToString:PXKeychainItemIdentityClassName(itemClass)] ||
+        !PXKeychainItemIdentityIsString(accessGroup) ||
+        ![identityAttributeNames isKindOfClass:[NSArray class]] ||
+        ![identityAttributes isKindOfClass:[NSDictionary class]] ||
+        ![matchQuery isKindOfClass:[NSDictionary class]] ||
+        identityAttributeNames.count == 0 ||
+        identityAttributeNames.count > PXKeychainItemIdentityMaximumAttributeCount ||
+        identityAttributes.count != identityAttributeNames.count ||
+        matchQuery.count != expectedQueryCount ||
+        matchQuery.count != identityAttributeNames.count + 1 ||
+        matchQuery.count > PXKeychainItemIdentityMaximumQueryKeyCount) {
+        return NO;
+    }
+
+    NSSet *uniqueNames = [NSSet setWithArray:identityAttributeNames];
+    if (uniqueNames.count != identityAttributeNames.count) {
+        return NO;
+    }
+
+    NSString *accessGroupKey = (__bridge NSString *)kSecAttrAccessGroup;
+    NSString *synchronizableKey = (__bridge NSString *)kSecAttrSynchronizable;
+    id retainedAccessGroup = identityAttributes[accessGroupKey];
+    id retainedSynchronizable = identityAttributes[synchronizableKey];
+    BOOL retainedBoolean = NO;
+    if (!PXKeychainItemIdentityIsString(retainedAccessGroup) ||
+        ![(NSString *)retainedAccessGroup isEqualToString:accessGroup] ||
+        !PXKeychainItemIdentityExtractExactCFBoolean(retainedSynchronizable, &retainedBoolean) ||
+        retainedBoolean != synchronizable) {
+        return NO;
+    }
+
+    id retainedClass = matchQuery[(__bridge id)kSecClass];
+    if (!PXKeychainItemIdentityIsString(retainedClass) ||
+        retainedClass != (__bridge id)securityClass) {
+        return NO;
+    }
+
+    for (id nameObject in identityAttributeNames) {
+        if (!PXKeychainItemIdentityIsString(nameObject)) {
+            return NO;
+        }
+        NSString *name = (NSString *)nameObject;
+        id identityValue = identityAttributes[name];
+        id queryValue = matchQuery[name];
+        if (!identityValue || !queryValue ||
+            ![identityValue isEqual:queryValue] ||
+            !PXKeychainItemIdentityValueIsImmutablePropertyListPrimitive(identityValue)) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+@interface PXKeychainItemIdentity ()
+
+- (instancetype)px_initWithItemClass:(PXKeychainItemIdentityClass)itemClass
+                           className:(NSString *)className
+                         accessGroup:(NSString *)accessGroup
+                      synchronizable:(BOOL)synchronizable
+              identityAttributeNames:(NSArray<NSString *> *)identityAttributeNames
+                  identityAttributes:(NSDictionary<NSString *, id> *)identityAttributes
+                          matchQuery:(NSDictionary<NSString *, id> *)matchQuery;
+
+@end
+
+@implementation PXKeychainItemIdentity
+
++ (instancetype)identityForSecurityItemAttributes:(NSDictionary<NSString *, id> *)attributes
+                                             error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    @try {
+        if (![attributes isKindOfClass:[NSDictionary class]]) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorInvalidInput,
+                                            PXKeychainItemIdentityRootFieldPath,
+                                            @"The identity input must be a dictionary.");
+            return nil;
+        }
+        if (attributes.count > PXKeychainItemIdentityMaximumInputEntries) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorLimitExceeded,
+                                            PXKeychainItemIdentityRootFieldPath,
+                                            @"The identity input exceeds the entry limit.");
+            return nil;
+        }
+
+        NSDictionary<NSString *, id> *input =
+            [[NSDictionary alloc] initWithDictionary:attributes copyItems:NO];
+        if (!input) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorSnapshotFailed,
+                                            PXKeychainItemIdentityRootFieldPath,
+                                            @"The identity input snapshot could not be created.");
+            return nil;
+        }
+        if (input.count > PXKeychainItemIdentityMaximumInputEntries) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorLimitExceeded,
+                                            PXKeychainItemIdentityRootFieldPath,
+                                            @"The identity input snapshot exceeds the entry limit.");
+            return nil;
+        }
+
+        PXKeychainItemIdentityClass itemClass = PXKeychainItemIdentityClassUnknown;
+        CFStringRef securityClass = NULL;
+        NSUInteger expectedQueryCount = 0;
+        if (!PXKeychainItemIdentityResolveClass(input[(__bridge id)kSecClass],
+                                                 &itemClass,
+                                                 &securityClass,
+                                                 &expectedQueryCount)) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorUnsupportedClass,
+                                            PXKeychainItemIdentityClassFieldPath,
+                                            @"The Security item class is missing or unsupported.");
+            return nil;
+        }
+
+        id accessGroupValue = input[(__bridge id)kSecAttrAccessGroup];
+        if (!accessGroupValue) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorMissingAccessGroup,
+                                            PXKeychainItemIdentityAccessGroupFieldPath,
+                                            @"The access group is required.");
+            return nil;
+        }
+
+        NSString *accessGroup = nil;
+        NSUInteger accessGroupByteCount = 0;
+        PXKeychainItemIdentityValueStatus accessGroupStatus =
+            PXKeychainItemIdentityCopyString(accessGroupValue,
+                                              NO,
+                                              PXKeychainItemIdentityMaximumAccessGroupBytes,
+                                              &accessGroup,
+                                              &accessGroupByteCount);
+        if (accessGroupStatus != PXKeychainItemIdentityValueStatusSuccess) {
+            if (accessGroupStatus == PXKeychainItemIdentityValueStatusLimitExceeded) {
+                PXKeychainItemIdentitySetError(error,
+                                                PXKeychainItemIdentityErrorLimitExceeded,
+                                                PXKeychainItemIdentityAccessGroupFieldPath,
+                                                @"The access group exceeds the byte limit.");
+            } else if (accessGroupStatus == PXKeychainItemIdentityValueStatusSnapshotFailed) {
+                PXKeychainItemIdentitySetError(error,
+                                                PXKeychainItemIdentityErrorSnapshotFailed,
+                                                PXKeychainItemIdentityAccessGroupFieldPath,
+                                                @"The immutable access-group snapshot could not be created.");
+            } else {
+                PXKeychainItemIdentitySetError(error,
+                                                PXKeychainItemIdentityErrorInvalidAccessGroup,
+                                                PXKeychainItemIdentityAccessGroupFieldPath,
+                                                @"The access group has an invalid type or value.");
+            }
+            return nil;
+        }
+
+        BOOL synchronizable = NO;
+        id synchronizableValue = input[(__bridge id)kSecAttrSynchronizable];
+        if (synchronizableValue &&
+            !PXKeychainItemIdentityExtractExactCFBoolean(synchronizableValue,
+                                                         &synchronizable)) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorInvalidSynchronizable,
+                                            PXKeychainItemIdentitySynchronizableFieldPath,
+                                            @"The synchronizable attribute must be an exact Boolean.");
+            return nil;
+        }
+        NSNumber *canonicalSynchronizable = @(synchronizable);
+
+        NSString *className = PXKeychainItemIdentityClassName(itemClass);
+        NSString *classNameSnapshot = [[NSString alloc] initWithString:className];
+        if (!classNameSnapshot) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorSnapshotFailed,
+                                            PXKeychainItemIdentityClassFieldPath,
+                                            @"The immutable class-name snapshot could not be created.");
+            return nil;
+        }
+
+        NSUInteger aggregateByteCount = PXKeychainItemIdentityStringByteCount(classNameSnapshot);
+        if (aggregateByteCount == NSUIntegerMax ||
+            aggregateByteCount > PXKeychainItemIdentityMaximumAggregateBytes) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorLimitExceeded,
+                                            PXKeychainItemIdentityTupleFieldPath,
+                                            @"The retained identity exceeds the aggregate byte limit.");
+            return nil;
+        }
+
+        NSMutableArray<NSString *> *names = [NSMutableArray array];
+        NSMutableDictionary<NSString *, id> *identityAttributes = [NSMutableDictionary dictionary];
+        if (!PXKeychainItemIdentityAppendAttribute(names,
+                                                    identityAttributes,
+                                                    kSecAttrAccessGroup,
+                                                    accessGroup,
+                                                    accessGroupByteCount,
+                                                    &aggregateByteCount) ||
+            !PXKeychainItemIdentityAppendAttribute(names,
+                                                    identityAttributes,
+                                                    kSecAttrSynchronizable,
+                                                    canonicalSynchronizable,
+                                                    sizeof(BOOL),
+                                                    &aggregateByteCount)) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorSnapshotFailed,
+                                            PXKeychainItemIdentityTupleFieldPath,
+                                            @"The common identity snapshot could not be created.");
+            return nil;
+        }
+
+        switch (itemClass) {
+            case PXKeychainItemIdentityClassGenericPassword: {
+                NSString *account = nil;
+                NSString *service = nil;
+                NSUInteger accountBytes = 0;
+                NSUInteger serviceBytes = 0;
+                PXKeychainItemIdentityValueStatus accountStatus =
+                    PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrAccount],
+                                                      YES,
+                                                      PXKeychainItemIdentityMaximumOrdinaryStringBytes,
+                                                      &account,
+                                                      &accountBytes);
+                if (accountStatus != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(accountStatus,
+                                                             PXKeychainItemIdentityAccountFieldPath,
+                                                             error);
+                    return nil;
+                }
+                PXKeychainItemIdentityValueStatus serviceStatus =
+                    PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrService],
+                                                      YES,
+                                                      PXKeychainItemIdentityMaximumOrdinaryStringBytes,
+                                                      &service,
+                                                      &serviceBytes);
+                if (serviceStatus != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(serviceStatus,
+                                                             PXKeychainItemIdentityServiceFieldPath,
+                                                             error);
+                    return nil;
+                }
+                if (!PXKeychainItemIdentityAppendAttribute(names,
+                                                            identityAttributes,
+                                                            kSecAttrAccount,
+                                                            account,
+                                                            accountBytes,
+                                                            &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names,
+                                                            identityAttributes,
+                                                            kSecAttrService,
+                                                            service,
+                                                            serviceBytes,
+                                                            &aggregateByteCount)) {
+                    PXKeychainItemIdentitySetError(error,
+                                                    PXKeychainItemIdentityErrorSnapshotFailed,
+                                                    PXKeychainItemIdentityTupleFieldPath,
+                                                    @"The generic-password identity snapshot could not be created.");
+                    return nil;
+                }
+                break;
+            }
+
+            case PXKeychainItemIdentityClassInternetPassword: {
+                CFStringRef requiredKeys[] = {
+                    kSecAttrAccount,
+                    kSecAttrServer,
+                    kSecAttrPort,
+                    kSecAttrProtocol,
+                    kSecAttrAuthenticationType,
+                    kSecAttrPath,
+                    kSecAttrSecurityDomain,
+                };
+                NSString *requiredPaths[] = {
+                    PXKeychainItemIdentityAccountFieldPath,
+                    PXKeychainItemIdentityServerFieldPath,
+                    PXKeychainItemIdentityPortFieldPath,
+                    PXKeychainItemIdentityProtocolFieldPath,
+                    PXKeychainItemIdentityAuthenticationTypeFieldPath,
+                    PXKeychainItemIdentityPathFieldPath,
+                    PXKeychainItemIdentitySecurityDomainFieldPath,
+                };
+                for (NSUInteger index = 0; index < sizeof(requiredKeys) / sizeof(requiredKeys[0]); index++) {
+                    if (!input[(__bridge id)requiredKeys[index]]) {
+                        if (PXKeychainItemIdentityHasInternetFallbackAttributes(input)) {
+                            PXKeychainItemIdentitySetError(error,
+                                                            PXKeychainItemIdentityErrorAmbiguousIdentity,
+                                                            PXKeychainItemIdentityTupleFieldPath,
+                                                            @"The internet-password identity tuple is ambiguous.");
+                        } else {
+                            PXKeychainItemIdentitySetError(error,
+                                                            PXKeychainItemIdentityErrorMissingIdentityAttribute,
+                                                            requiredPaths[index],
+                                                            @"A required identity attribute is missing.");
+                        }
+                        return nil;
+                    }
+                }
+
+                NSString *account = nil;
+                NSString *server = nil;
+                NSString *protocol = nil;
+                NSString *authenticationType = nil;
+                NSString *path = nil;
+                NSString *securityDomain = nil;
+                NSNumber *port = nil;
+                NSUInteger accountBytes = 0;
+                NSUInteger serverBytes = 0;
+                NSUInteger protocolBytes = 0;
+                NSUInteger authenticationTypeBytes = 0;
+                NSUInteger pathBytes = 0;
+                NSUInteger securityDomainBytes = 0;
+                NSUInteger portBytes = 0;
+
+                PXKeychainItemIdentityValueStatus status =
+                    PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrAccount],
+                                                      YES,
+                                                      PXKeychainItemIdentityMaximumOrdinaryStringBytes,
+                                                      &account,
+                                                      &accountBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityAccountFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrServer],
+                                                           NO,
+                                                           PXKeychainItemIdentityMaximumOrdinaryStringBytes,
+                                                           &server,
+                                                           &serverBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityServerFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyPort(input[(__bridge id)kSecAttrPort],
+                                                         &port,
+                                                         &portBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityPortFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrProtocol],
+                                                           NO,
+                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
+                                                           &protocol,
+                                                           &protocolBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityProtocolFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrAuthenticationType],
+                                                           NO,
+                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
+                                                           &authenticationType,
+                                                           &authenticationTypeBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityAuthenticationTypeFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrPath],
+                                                           YES,
+                                                           PXKeychainItemIdentityMaximumOrdinaryStringBytes,
+                                                           &path,
+                                                           &pathBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityPathFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrSecurityDomain],
+                                                           YES,
+                                                           PXKeychainItemIdentityMaximumOrdinaryStringBytes,
+                                                           &securityDomain,
+                                                           &securityDomainBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentitySecurityDomainFieldPath,
+                                                             error);
+                    return nil;
+                }
+
+                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrAccount, account, accountBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrServer, server, serverBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrPort, port, portBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrProtocol, protocol, protocolBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrAuthenticationType, authenticationType, authenticationTypeBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrPath, path, pathBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrSecurityDomain, securityDomain, securityDomainBytes, &aggregateByteCount)) {
+                    PXKeychainItemIdentitySetError(error,
+                                                    PXKeychainItemIdentityErrorSnapshotFailed,
+                                                    PXKeychainItemIdentityTupleFieldPath,
+                                                    @"The internet-password identity snapshot could not be created.");
+                    return nil;
+                }
+                break;
+            }
+
+            case PXKeychainItemIdentityClassCertificate: {
+                id issuerValue = input[(__bridge id)kSecAttrIssuer];
+                id serialNumberValue = input[(__bridge id)kSecAttrSerialNumber];
+                if (!issuerValue || !serialNumberValue) {
+                    if (issuerValue || serialNumberValue ||
+                        PXKeychainItemIdentityHasCertificateFallbackAttributes(input)) {
+                        PXKeychainItemIdentitySetError(error,
+                                                        PXKeychainItemIdentityErrorAmbiguousIdentity,
+                                                        PXKeychainItemIdentityTupleFieldPath,
+                                                        @"The certificate identity tuple is ambiguous.");
+                    } else {
+                        PXKeychainItemIdentitySetError(error,
+                                                        PXKeychainItemIdentityErrorMissingIdentityAttribute,
+                                                        issuerValue ? PXKeychainItemIdentitySerialNumberFieldPath : PXKeychainItemIdentityIssuerFieldPath,
+                                                        @"A required identity attribute is missing.");
+                    }
+                    return nil;
+                }
+
+                NSData *issuer = nil;
+                NSData *serialNumber = nil;
+                NSUInteger issuerBytes = 0;
+                NSUInteger serialNumberBytes = 0;
+                PXKeychainItemIdentityValueStatus status =
+                    PXKeychainItemIdentityCopyData(issuerValue,
+                                                    PXKeychainItemIdentityMaximumIssuerBytes,
+                                                    &issuer,
+                                                    &issuerBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityIssuerFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyData(serialNumberValue,
+                                                         PXKeychainItemIdentityMaximumSerialNumberBytes,
+                                                         &serialNumber,
+                                                         &serialNumberBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentitySerialNumberFieldPath,
+                                                             error);
+                    return nil;
+                }
+                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrIssuer, issuer, issuerBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrSerialNumber, serialNumber, serialNumberBytes, &aggregateByteCount)) {
+                    PXKeychainItemIdentitySetError(error,
+                                                    PXKeychainItemIdentityErrorSnapshotFailed,
+                                                    PXKeychainItemIdentityTupleFieldPath,
+                                                    @"The certificate identity snapshot could not be created.");
+                    return nil;
+                }
+                break;
+            }
+
+            case PXKeychainItemIdentityClassKey: {
+                id applicationLabelValue = input[(__bridge id)kSecAttrApplicationLabel];
+                if (!applicationLabelValue) {
+                    if (PXKeychainItemIdentityHasKeyFallbackAttributes(input)) {
+                        PXKeychainItemIdentitySetError(error,
+                                                        PXKeychainItemIdentityErrorAmbiguousIdentity,
+                                                        PXKeychainItemIdentityTupleFieldPath,
+                                                        @"The key identity tuple is ambiguous.");
+                    } else {
+                        PXKeychainItemIdentitySetError(error,
+                                                        PXKeychainItemIdentityErrorMissingIdentityAttribute,
+                                                        PXKeychainItemIdentityApplicationLabelFieldPath,
+                                                        @"A required identity attribute is missing.");
+                    }
+                    return nil;
+                }
+
+                NSData *applicationLabel = nil;
+                NSString *keyClass = nil;
+                NSString *keyType = nil;
+                NSUInteger applicationLabelBytes = 0;
+                NSUInteger keyClassBytes = 0;
+                NSUInteger keyTypeBytes = 0;
+                PXKeychainItemIdentityValueStatus status =
+                    PXKeychainItemIdentityCopyData(applicationLabelValue,
+                                                    PXKeychainItemIdentityMaximumApplicationLabelBytes,
+                                                    &applicationLabel,
+                                                    &applicationLabelBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityApplicationLabelFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrKeyClass],
+                                                           NO,
+                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
+                                                           &keyClass,
+                                                           &keyClassBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityKeyClassFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrKeyType],
+                                                           NO,
+                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
+                                                           &keyType,
+                                                           &keyTypeBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityKeyTypeFieldPath,
+                                                             error);
+                    return nil;
+                }
+                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrApplicationLabel, applicationLabel, applicationLabelBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrKeyClass, keyClass, keyClassBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrKeyType, keyType, keyTypeBytes, &aggregateByteCount)) {
+                    PXKeychainItemIdentitySetError(error,
+                                                    PXKeychainItemIdentityErrorSnapshotFailed,
+                                                    PXKeychainItemIdentityTupleFieldPath,
+                                                    @"The key identity snapshot could not be created.");
+                    return nil;
+                }
+                break;
+            }
+
+            case PXKeychainItemIdentityClassIdentity: {
+                id applicationLabelValue = input[(__bridge id)kSecAttrApplicationLabel];
+                id issuerValue = input[(__bridge id)kSecAttrIssuer];
+                id serialNumberValue = input[(__bridge id)kSecAttrSerialNumber];
+                if (!applicationLabelValue || !issuerValue || !serialNumberValue) {
+                    if (applicationLabelValue || issuerValue || serialNumberValue ||
+                        PXKeychainItemIdentityHasIdentityFallbackAttributes(input)) {
+                        PXKeychainItemIdentitySetError(error,
+                                                        PXKeychainItemIdentityErrorAmbiguousIdentity,
+                                                        PXKeychainItemIdentityTupleFieldPath,
+                                                        @"The identity tuple is ambiguous.");
+                    } else {
+                        NSString *missingFieldPath = !applicationLabelValue
+                            ? PXKeychainItemIdentityApplicationLabelFieldPath
+                            : (!issuerValue
+                                ? PXKeychainItemIdentityIssuerFieldPath
+                                : PXKeychainItemIdentitySerialNumberFieldPath);
+                        PXKeychainItemIdentitySetError(error,
+                                                        PXKeychainItemIdentityErrorMissingIdentityAttribute,
+                                                        missingFieldPath,
+                                                        @"A required identity attribute is missing.");
+                    }
+                    return nil;
+                }
+
+                NSData *applicationLabel = nil;
+                NSData *issuer = nil;
+                NSData *serialNumber = nil;
+                NSUInteger applicationLabelBytes = 0;
+                NSUInteger issuerBytes = 0;
+                NSUInteger serialNumberBytes = 0;
+                PXKeychainItemIdentityValueStatus status =
+                    PXKeychainItemIdentityCopyData(applicationLabelValue,
+                                                    PXKeychainItemIdentityMaximumApplicationLabelBytes,
+                                                    &applicationLabel,
+                                                    &applicationLabelBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityApplicationLabelFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyData(issuerValue,
+                                                         PXKeychainItemIdentityMaximumIssuerBytes,
+                                                         &issuer,
+                                                         &issuerBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentityIssuerFieldPath,
+                                                             error);
+                    return nil;
+                }
+                status = PXKeychainItemIdentityCopyData(serialNumberValue,
+                                                         PXKeychainItemIdentityMaximumSerialNumberBytes,
+                                                         &serialNumber,
+                                                         &serialNumberBytes);
+                if (status != PXKeychainItemIdentityValueStatusSuccess) {
+                    PXKeychainItemIdentitySetAttributeError(status,
+                                                             PXKeychainItemIdentitySerialNumberFieldPath,
+                                                             error);
+                    return nil;
+                }
+                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrApplicationLabel, applicationLabel, applicationLabelBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrIssuer, issuer, issuerBytes, &aggregateByteCount) ||
+                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrSerialNumber, serialNumber, serialNumberBytes, &aggregateByteCount)) {
+                    PXKeychainItemIdentitySetError(error,
+                                                    PXKeychainItemIdentityErrorSnapshotFailed,
+                                                    PXKeychainItemIdentityTupleFieldPath,
+                                                    @"The identity snapshot could not be created.");
+                    return nil;
+                }
+                break;
+            }
+
+            case PXKeychainItemIdentityClassUnknown:
+                PXKeychainItemIdentitySetError(error,
+                                                PXKeychainItemIdentityErrorInternalInvariantFailed,
+                                                PXKeychainItemIdentityClassFieldPath,
+                                                @"The resolved identity class is invalid.");
+                return nil;
+        }
+
+        if (names.count > PXKeychainItemIdentityMaximumAttributeCount ||
+            identityAttributes.count != names.count ||
+            expectedQueryCount != names.count + 1 ||
+            expectedQueryCount > PXKeychainItemIdentityMaximumQueryKeyCount) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorInternalInvariantFailed,
+                                            PXKeychainItemIdentityTupleFieldPath,
+                                            @"The identity tuple has an invalid canonical shape.");
+            return nil;
+        }
+
+        NSString *classKey = [(__bridge NSString *)kSecClass copy];
+        NSString *classValue = [(__bridge NSString *)securityClass copy];
+        NSUInteger classKeyBytes = PXKeychainItemIdentityStringByteCount(classKey);
+        NSUInteger classValueBytes = PXKeychainItemIdentityStringByteCount(classValue);
+        if (!classKey || !classValue ||
+            classKeyBytes == NSUIntegerMax || classValueBytes == NSUIntegerMax ||
+            !PXKeychainItemIdentitySafeAdd(&aggregateByteCount, classKeyBytes) ||
+            !PXKeychainItemIdentitySafeAdd(&aggregateByteCount, classValueBytes) ||
+            aggregateByteCount > PXKeychainItemIdentityMaximumAggregateBytes) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorLimitExceeded,
+                                            PXKeychainItemIdentityTupleFieldPath,
+                                            @"The retained identity exceeds the aggregate byte limit.");
+            return nil;
+        }
+
+        NSMutableDictionary<NSString *, id> *query =
+            [NSMutableDictionary dictionaryWithCapacity:expectedQueryCount];
+        query[classKey] = classValue;
+        for (NSString *name in names) {
+            id value = identityAttributes[name];
+            if (!value) {
+                PXKeychainItemIdentitySetError(error,
+                                                PXKeychainItemIdentityErrorSnapshotFailed,
+                                                PXKeychainItemIdentityTupleFieldPath,
+                                                @"The match-query snapshot could not be completed.");
+                return nil;
+            }
+            query[name] = value;
+        }
+
+        NSArray<NSString *> *immutableNames = [NSArray arrayWithArray:names];
+        NSDictionary<NSString *, id> *immutableIdentityAttributes =
+            [NSDictionary dictionaryWithDictionary:identityAttributes];
+        NSDictionary<NSString *, id> *immutableQuery =
+            [NSDictionary dictionaryWithDictionary:query];
+        if (!immutableNames || !immutableIdentityAttributes || !immutableQuery) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorSnapshotFailed,
+                                            PXKeychainItemIdentityTupleFieldPath,
+                                            @"The immutable identity snapshot could not be created.");
+            return nil;
+        }
+
+        if (!PXKeychainItemIdentitySnapshotMatchesState(itemClass,
+                                                         classNameSnapshot,
+                                                         accessGroup,
+                                                         synchronizable,
+                                                         immutableNames,
+                                                         immutableIdentityAttributes,
+                                                         immutableQuery,
+                                                         securityClass,
+                                                         expectedQueryCount)) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorInternalInvariantFailed,
+                                            PXKeychainItemIdentityTupleFieldPath,
+                                            @"The immutable identity snapshot failed validation.");
+            return nil;
+        }
+
+        PXKeychainItemIdentity *identity =
+            [[PXKeychainItemIdentity alloc] px_initWithItemClass:itemClass
+                                                       className:classNameSnapshot
+                                                     accessGroup:accessGroup
+                                                  synchronizable:synchronizable
+                                          identityAttributeNames:immutableNames
+                                              identityAttributes:immutableIdentityAttributes
+                                                      matchQuery:immutableQuery];
+        if (!identity) {
+            PXKeychainItemIdentitySetError(error,
+                                            PXKeychainItemIdentityErrorSnapshotFailed,
+                                            PXKeychainItemIdentityTupleFieldPath,
+                                            @"The immutable identity object could not be created.");
+            return nil;
+        }
+        return identity;
+    } @catch (__unused NSException *exception) {
+        PXKeychainItemIdentitySetError(error,
+                                        PXKeychainItemIdentityErrorInternalInvariantFailed,
+                                        PXKeychainItemIdentityRootFieldPath,
+                                        @"The identity input could not be processed safely.");
+        return nil;
+    }
+}
+
+- (instancetype)px_initWithItemClass:(PXKeychainItemIdentityClass)itemClass
+                           className:(NSString *)className
+                         accessGroup:(NSString *)accessGroup
+                      synchronizable:(BOOL)synchronizable
+              identityAttributeNames:(NSArray<NSString *> *)identityAttributeNames
+                  identityAttributes:(NSDictionary<NSString *, id> *)identityAttributes
+                          matchQuery:(NSDictionary<NSString *, id> *)matchQuery {
+    self = [super init];
+    if (self) {
+        _schemaVersion = PXKeychainItemIdentitySchemaVersion;
+        _itemClass = itemClass;
+        _className = [[NSString alloc] initWithString:className];
+        _accessGroup = [[NSString alloc] initWithString:accessGroup];
+        _synchronizable = synchronizable;
+        _identityAttributeNames = [NSArray arrayWithArray:identityAttributeNames];
+        _identityAttributes = [NSDictionary dictionaryWithDictionary:identityAttributes];
+        _matchQuery = [NSDictionary dictionaryWithDictionary:matchQuery];
+    }
+    return self;
+}
+
+- (id)copyWithZone:(NSZone *)zone {
+    (void)zone;
+    return self;
+}
+
+- (BOOL)isEqual:(id)object {
+    if (self == object) {
+        return YES;
+    }
+    if (![object isMemberOfClass:[PXKeychainItemIdentity class]]) {
+        return NO;
+    }
+    PXKeychainItemIdentity *other = object;
+    return self.schemaVersion == other.schemaVersion &&
+           self.itemClass == other.itemClass &&
+           self.synchronizable == other.synchronizable &&
+           [self.accessGroup isEqualToString:other.accessGroup] &&
+           [self.identityAttributes isEqualToDictionary:other.identityAttributes] &&
+           [self.matchQuery isEqualToDictionary:other.matchQuery];
+}
+
+- (NSUInteger)hash {
+    NSUInteger value = (NSUInteger)self.schemaVersion;
+    value ^= (NSUInteger)self.itemClass;
+    value ^= (NSUInteger)self.synchronizable;
+    value ^= self.accessGroup.hash;
+    value ^= self.identityAttributes.hash;
+    value ^= self.matchQuery.hash;
+    return value;
+}
+
+- (NSString *)description {
+    return [NSString stringWithFormat:@"<PXKeychainItemIdentity class=%@ synchronizable=%@ attributes=%lu>",
+            self.className,
+            self.isSynchronizable ? @"true" : @"false",
+            (unsigned long)self.identityAttributeNames.count];
+}
+
+- (NSString *)debugDescription {
+    return self.description;
+}
+
+@end
diff --git a/Makefile b/Makefile
index 9916f34..a9e562e 100644
--- a/Makefile
+++ b/Makefile
@@ -38,7 +38,7 @@ WeaponXDaemon_CODESIGN_FLAGS = -Sent.plist
 WeaponXDaemon_LDFLAGS = -framework IOKit

 # Keychain Helper Tool - CLI for backup/restore/wipe keychain items
-backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m KeychainHelper/PXKeychainHelperResult.m
+backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m KeychainHelper/PXKeychainHelperResult.m KeychainHelper/PXKeychainItemIdentity.m
 backup_helper_CFLAGS = -fobjc-arc -Wno-error=unused-variable
 backup_helper_FRAMEWORKS = Foundation Security
 backup_helper_INSTALL_PATH = /Library/WeaponX
```

## Whitespace, CRLF, NUL, and final newline
| File | Bytes | NUL bytes | CRLF sequences | Final LF | Trailing whitespace introduced |
|---|---:|---:|---:|---:|---:|
| `KeychainHelper/PXKeychainItemIdentity.h` | 2387 | 0 | 0 | TRUE | 0 |
| `KeychainHelper/PXKeychainItemIdentity.m` | 62919 | 0 | 0 | TRUE | 0 |
| `Makefile` | 9226 | 0 | 174 | TRUE | 0 |
| `docs/backup-restore-hardening/reports/TASK-4.4-REPORT.md` | SELF-REFERENTIAL | 0 | 0 | TRUE | 0 |
- New source/report files use UTF-8 LF, contain no NUL bytes, end with LF, and have no trailing whitespace.
- Makefile retains its baseline CRLF style and pre-existing trailing spaces on unrelated framework lines; TASK-4.4 changes only the source assignment line and introduces no whitespace defect.

## Build, toolchain, and device risks
- Objective-C/Theos compile and link were not run because clang.exe, make.exe, and xcrun.exe are unavailable and THEOS is unset on this Windows host.
- Static source/model validation cannot prove Apple SDK availability of every Security constant on all deployment targets or runtime behavior of malicious Foundation subclasses.
- GitHub Actions/source review remain authoritative for Apple SDK compilation, ARC warnings, linking, package integration, and target-device validation.
- TASK-4.5 must validate actual Security.framework lookup behavior before using matchQuery for mutation.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
