# TASK-4.3 REPORT - Remove Broad Pre-Delete from Keychain Restore

## Result
- Implementation status: COMPLETE within the authorized TASK-4.3 scope.
- Baseline: `5c6e70ac4ecd815727c50216c80176d1cf9f80f2`.
- TASK-4.1 and TASK-4.2 source reviews: ACCEPTED and COMPLETED.
- No TASK-4.4 or later work is included.

## Exact scope
| Status | Path | Purpose |
|---|---|---|
| M | `KeychainHelper/KeychainBackupHelper.h` | overwrite compatibility and duplicate-preservation documentation |
| M | `KeychainHelper/KeychainBackupHelper.m` | remove broad pre-delete and preserve duplicates |
| M | `KeychainHelper/backup_helper.m` | exact direct-helper help and verbose text |
| M | `scripts/keychain_backup.sh` | exact wrapper help text |
| A | `docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md` | evidence and scenario matrix |

## Baseline evidence
Commands recorded before implementation:
```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -8 --oneline
git diff --check
```
Baseline HEAD:
```text
5c6e70ac4ecd815727c50216c80176d1cf9f80f2
```
Baseline status, excluding no files and preserving all coordinator-owned entries:
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
```
Baseline log:
```text
5c6e70a phase4(task-4.2): define reliable keychain helper exit codes
1a59e96 phase4(task-4.1): add structured keychain helper result
02770e2 phase3(task-3.10A): fix stale name classification and rollback errors
5e70a8f phase3(task-3.10): harden backup discovery and stale cleanup
aa01f73 phase3(task-3.9A): make cleanup removal race safe
aa47468 phase3(task-3.9): centralize backup failure cleanup
e55e9d6 phase3(task-3.8A): make directory publication no-replace
494cae0 phase3(task-3.8): publish completed backup atomically
```
Baseline `git diff --check`: zero errors; only existing CRLF conversion warnings for coordinator-owned documentation.

## Protected hashes and byte sizes
The following 72 protected production paths are byte-identical to the mandatory baseline. Current hashes and sizes equal the accepted TASK-4.2 before/after evidence.

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
| `KeychainHelper/PXKeychainHelperResult.h` | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | `96c326226fbb22e7b69dc68f4088aa5e6c171d391ad0bca8d321318f041f9d14` | 3191 | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | `2ff85dd7bc0e3af97b0fdf2ccd00072d6ba2d324ef70e4c4e26b739d745d9035` | 27477 | TRUE |
| `Makefile` | `9ed7ed6b376c96b8a3df8d9e169670476feabee186a177f9fe09118265a6d8c0` | 9186 | `9ed7ed6b376c96b8a3df8d9e169670476feabee186a177f9fe09118265a6d8c0` | 9186 | TRUE |
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

## Authorized source before/after
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
|---|---|---:|---|---:|
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 | `23fd5431f751401a7a09edca1eafec80ab1118321ed6493751d9061e750dc010` | 4462 |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 | `798f6c6aa87b77a525c1bcbb866877fdb6d544f41df4c63cfbdaaade56eedfa7` | 26504 |
| `KeychainHelper/backup_helper.m` | `cdd75a01da5ae7f6cdb1096724b146a54b4e1cb9096e3a077152458530c4fb0f` | 28224 | `e776a0399614c34195cd09601e420a607bc0147cf034976d740247f79cb79943` | 28261 |
| `scripts/keychain_backup.sh` | `1ea608e75ed03ab92eb2bb1ab15a68a721a9a9b80c52c3d0b1229b3b96bc2c26` | 36263 | `05a2b44a1f36ab0ffba407a9e76f7cd7cb26b4455276f6640d738753d9840f53` | 36295 |
| `docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md` | ABSENT | 0 | SELF-REFERENTIAL | SELF-REFERENTIAL |

## Old broad pre-delete inventory
- Baseline restore contained one `if (overwrite)` group/class-wide pre-delete block.
- It read `backup[@"accessGroups"]`, collected each item `_secClass`, nested access-group/class loops, built a synchronizable-any delete query, called `SecItemDelete`, and appended `Pre-wipe failed` warnings.
- Baseline restore also contained a comment claiming the group-wide pre-wipe had already executed.
- Baseline core Security counts were: `SecItemCopyMatching=5`, `SecItemAdd=1`, `SecItemDelete=2`, `SecItemUpdate=0`.

## Removal proof and Security call counts
| Scope | CopyMatching | Add | Delete | Update |
|---|---:|---:|---:|---:|
| `restoreKeychainFromFile:overwrite:error:` | 0 | 1 | 0 | 0 |
| `KeychainBackupHelper.m` after TASK-4.3 | 5 | 1 | 1 | 0 |
| `KeychainBackupHelper.m` baseline | 5 | 1 | 2 | 0 |
- The sole core `SecItemDelete` is inside explicit `wipeKeychainForAccessGroups:itemClasses:error:`.
- Restore contains no wipe selector call, dynamic selector, shell execution, bridge call, notification path, alternate delete path, identity query, or update.
- Required core count target `5/1/1/0` is satisfied exactly.
- Literal tracked-source inventory is `9/3/3/0` because protected `AppDataCleaner.m` and `WeaponXKeychainBridge/Tweak.m` contain pre-existing Security sites that this specification simultaneously requires to remain byte-identical. Those sites were not changed; this task removes the authorized core restore pre-delete only.

## Overwrite compatibility semantics
- Selector and `overwrite:(BOOL)overwrite` parameter are unchanged.
- `overwrite == YES` is retained as a compatibility request only.
- It does not trigger group/class deletion and does not add a blanket warning.
- An all-new restore can be Completed with exit 0 for either overwrite mode.
- The flag selects only the exact duplicate warning text until safe per-item replacement is implemented.

## Duplicate warning and counter matrix
| Add result | Overwrite | Existing target | Succeeded delta | Failed delta | Warning delta | Error delta |
|---|---:|---|---:|---:|---:|---:|
| `errSecSuccess` | NO/YES | new item added | +1 | 0 | 0 | 0 |
| `errSecDuplicateItem` | NO | preserved | 0 | +1 | +1 exact preserved warning | 0 |
| `errSecDuplicateItem` | YES | preserved | 0 | +1 | +1 exact pending-safe-replacement warning | 0 |
| other failure | NO/YES | unchanged by this task | 0 | +1 | 0 | +1 current generic error |
- Non-overwrite exact warning: `Item already exists; existing item was preserved: %@`.
- Overwrite exact warning: `Overwrite requested but existing item was preserved pending safe per-item replacement: %@`.
- Both use only `addQuery[kSecAttrAccount] ?: @"unknown"`; no service, group, class, secret, or path is added to duplicate warnings.

## All-new and mixed restore behavior
- All new items: processed and succeeded counts match, failed/warning/error counts are zero, completion Completed, direct exit 0.
- Any duplicate: each duplicate contributes exactly one failed item and one warning, contributes no error, completion Partial, direct exit 10.
- Any generic add error: current failed/error accounting remains, completion Partial, direct exit 10.
- Mixed new/duplicate/error items preserve successful additions and existing duplicates without a destructive pre-pass.

## Explicit wipe non-regression
- The entire explicit wipe method is text-identical to baseline.
- Its one core `SecItemDelete` site, count-before-delete query, group/class iteration, warning behavior, and counters are unchanged.

## Backup, input, and parser non-regression
- The entire backup method is text-identical to baseline.
- Restore file-read, immutable plist parsing, items-array validation, result allocation, arrays, and excluded-attribute setup are text-identical.
- Item class extraction, add-query construction, data/date decoding, synchronizable handling, sole add site, and generic nonduplicate error branch are retained.
- Backup plist version/schema and accessGroups/items production are unchanged.

## TASK-4.1 and TASK-4.2 non-regression
- `PXKeychainHelperResult.h/.m` and `PXKeychainHelperExitCode.h` are byte-identical.
- TASK-4.1 schema version 1, ten root keys, three fatal-error keys, fixed bounds, privacy exclusions, and binary-plist/base64 framing are unchanged.
- Direct helper still has one finalizer, sixteen non-help finalizer call sites, one emitter, one result-line fprintf, one flush, one INVALID literal, and no raw return 1/2/3.
- Shell still has thirteen readonly constants, one normalizer, four normalizer calls, four helper executions, unchanged status pass-through, and no result parser.

## Direct and wrapper help changes
- Direct exact help text: `--overwrite For restore: request replacement; existing duplicates are preserved` (spacing retained by the CLI format).
- Direct exact verbose text: `Starting keychain restore (overwrite requested: %@)...`.
- Wrapper exact help text: `--overwrite For restore: request replacement; existing duplicates are preserved` (spacing retained by the shell output).
- Parsing and overwrite forwarding remain unchanged.

## Zero identity/upsert proof
- Restore `SecItemCopyMatching` calls: 0.
- Restore `SecItemUpdate` calls: 0.
- Restore `SecItemDelete` calls: 0.
- No exact identity query, preflight lookup, per-item delete/add replacement, dynamic selector, rollback, or alternate mutation path was added.

## Zero manager/cleaner/bridge integration
- `AppDataBackupManager.h/.m`, `AppDataCleaner.h/.m`, and `WeaponXKeychainBridge/Tweak.m` are byte-identical.
- Manager and Cleaner remain zero/nonzero consumers; Partial 10 continues to fail closed.
- Restore warning-only aggregate policy and Clear failure accounting are unchanged.
- No result parser, exact-code switch, or bridge unification was added.

## Task boundaries
- Not implemented: exact identity query, preflight duplicate lookup, SecItemUpdate, per-item delete/add upsert, rollback, backup schema migration, strict item validation, secure workspace/path redesign, requested/effective group reporting, caller parsing, backup-file protection, UI, TASK-4.4, or later phases.

## Static gates
| Gate | Observed | Required | Result |
|---|---:|---:|---|
| restore SecItemDelete | 0 | 0 | PASS |
| restore SecItemUpdate | 0 | 0 | PASS |
| restore SecItemAdd | 1 | 1 | PASS |
| core SecItemCopyMatching | 5 | 5 | PASS |
| core SecItemAdd | 1 | 1 | PASS |
| core SecItemDelete | 1 | 1 | PASS |
| core SecItemUpdate | 0 | 0 | PASS |
| explicit wipe delete sites | 1 | 1 | PASS |
| duplicate branches | 1 | 1 | PASS |
| duplicate warning append sites | 1 | 1 | PASS |
| exact duplicate warnings | 2 | 2 | PASS |
| finalizer definitions | 1 | 1 | PASS |
| non-help finalizer calls | 16 | 16 | PASS |
| shell readonly constants | 13 | 13 | PASS |
| shell normalizer definitions/calls | 1/4 | 1/4 | PASS |
| protected files | 72 | 72 | PASS |
| outcome model assertions | 5461 | 5461 | PASS |
- `git diff --check` on authorized production files: PASS.
- Objective-C lexical delimiter/quote balance: PASS.
- Exact baseline comparison for backup, explicit wipe, list/diagnose, restore input/parser, CLI non-text behavior, and shell non-help behavior: PASS.

## Shell syntax validation
- `C:\Program Files\Git\bin\bash.exe -n scripts/keychain_backup.sh`: PASS.
- `C:\Program Files\Git\usr\bin\bash.exe -n scripts/keychain_backup.sh`: PASS.

## Explicit numbered scenarios
Explicit scenarios: 727.
| # | Area | Stimulus | Expected result |
|---:|---|---|---|
| 1 | overwrite compatibility | overwrite=NO, all items new | Completed; succeeded equals processed; failed/warnings/errors zero; exit 0 |
| 2 | overwrite compatibility | overwrite=YES, all items new | Completed; no blanket warning; exit 0 |
| 3 | duplicate | overwrite=NO, one duplicate account=alice | existing item preserved; exact non-overwrite warning with alice; failed+1; warning+1; error+0; exit 10 |
| 4 | duplicate | overwrite=YES, one duplicate account=alice | existing item preserved; exact overwrite-requested warning with alice; failed+1; warning+1; error+0; exit 10 |
| 5 | duplicate privacy | duplicate has service/group/class/secret/path fields | warning substitutes account only; no service/group/class/secret/path is appended |
| 6 | duplicate fallback | duplicate account absent | warning substitutes unknown |
| 7 | generic add error | nonduplicate SecItemAdd failure | existing generic errors behavior retained; failed+1; Partial; exit 10 |
| 8 | critical input | empty/unreadable backup file | fatal FileIO; direct exit 21 through TASK-4.2 mapping |
| 9 | critical input | invalid plist or missing items array | fatal InvalidBackupFile; direct exit 21 |
| 10 | protocol | structured result construction fails | INVALID line; ProtocolFailure exit 50 overrides intended exit |
| 11 | explicit wipe | wipe action invoked | sole core SecItemDelete remains active inside explicit wipe selector |
| 12 | restore safety | overwrite=YES | zero restore-time SecItemDelete and zero SecItemUpdate |
| 13 | restore safety | overwrite=NO | zero restore-time SecItemDelete and zero SecItemUpdate |
| 14 | help | direct helper --help | new exact compatibility wording; exit 0; no result emission |
| 15 | help | shell wrapper --help | new exact compatibility wording |
| 16 | restore matrix | overwrite=NO; item outcomes=empty | processed=0; succeeded=0; failed=0; warnings=0; errors=0; preserved duplicate warning for each duplicate; completion=Completed; exit=0 |
| 17 | restore matrix | overwrite=NO; item outcomes=success | processed=1; succeeded=1; failed=0; warnings=0; errors=0; preserved duplicate warning for each duplicate; completion=Completed; exit=0 |
| 18 | restore matrix | overwrite=NO; item outcomes=duplicate | processed=1; succeeded=0; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 19 | restore matrix | overwrite=NO; item outcomes=generic-error | processed=1; succeeded=0; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 20 | restore matrix | overwrite=NO; item outcomes=missing-class | processed=1; succeeded=0; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 21 | restore matrix | overwrite=NO; item outcomes=success,success | processed=2; succeeded=2; failed=0; warnings=0; errors=0; preserved duplicate warning for each duplicate; completion=Completed; exit=0 |
| 22 | restore matrix | overwrite=NO; item outcomes=success,duplicate | processed=2; succeeded=1; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 23 | restore matrix | overwrite=NO; item outcomes=success,generic-error | processed=2; succeeded=1; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 24 | restore matrix | overwrite=NO; item outcomes=success,missing-class | processed=2; succeeded=1; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 25 | restore matrix | overwrite=NO; item outcomes=duplicate,success | processed=2; succeeded=1; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 26 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate | processed=2; succeeded=0; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 27 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error | processed=2; succeeded=0; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 28 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class | processed=2; succeeded=0; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 29 | restore matrix | overwrite=NO; item outcomes=generic-error,success | processed=2; succeeded=1; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 30 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate | processed=2; succeeded=0; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 31 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error | processed=2; succeeded=0; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 32 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class | processed=2; succeeded=0; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 33 | restore matrix | overwrite=NO; item outcomes=missing-class,success | processed=2; succeeded=1; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 34 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate | processed=2; succeeded=0; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 35 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error | processed=2; succeeded=0; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 36 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class | processed=2; succeeded=0; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 37 | restore matrix | overwrite=NO; item outcomes=success,success,success | processed=3; succeeded=3; failed=0; warnings=0; errors=0; preserved duplicate warning for each duplicate; completion=Completed; exit=0 |
| 38 | restore matrix | overwrite=NO; item outcomes=success,success,duplicate | processed=3; succeeded=2; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 39 | restore matrix | overwrite=NO; item outcomes=success,success,generic-error | processed=3; succeeded=2; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 40 | restore matrix | overwrite=NO; item outcomes=success,success,missing-class | processed=3; succeeded=2; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 41 | restore matrix | overwrite=NO; item outcomes=success,duplicate,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 42 | restore matrix | overwrite=NO; item outcomes=success,duplicate,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 43 | restore matrix | overwrite=NO; item outcomes=success,duplicate,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 44 | restore matrix | overwrite=NO; item outcomes=success,duplicate,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 45 | restore matrix | overwrite=NO; item outcomes=success,generic-error,success | processed=3; succeeded=2; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 46 | restore matrix | overwrite=NO; item outcomes=success,generic-error,duplicate | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 47 | restore matrix | overwrite=NO; item outcomes=success,generic-error,generic-error | processed=3; succeeded=1; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 48 | restore matrix | overwrite=NO; item outcomes=success,generic-error,missing-class | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 49 | restore matrix | overwrite=NO; item outcomes=success,missing-class,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 50 | restore matrix | overwrite=NO; item outcomes=success,missing-class,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 51 | restore matrix | overwrite=NO; item outcomes=success,missing-class,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 52 | restore matrix | overwrite=NO; item outcomes=success,missing-class,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 53 | restore matrix | overwrite=NO; item outcomes=duplicate,success,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 54 | restore matrix | overwrite=NO; item outcomes=duplicate,success,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 55 | restore matrix | overwrite=NO; item outcomes=duplicate,success,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 56 | restore matrix | overwrite=NO; item outcomes=duplicate,success,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 57 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 58 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 59 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 60 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 61 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 62 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 63 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 64 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 65 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 66 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 67 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 68 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 69 | restore matrix | overwrite=NO; item outcomes=generic-error,success,success | processed=3; succeeded=2; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 70 | restore matrix | overwrite=NO; item outcomes=generic-error,success,duplicate | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 71 | restore matrix | overwrite=NO; item outcomes=generic-error,success,generic-error | processed=3; succeeded=1; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 72 | restore matrix | overwrite=NO; item outcomes=generic-error,success,missing-class | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 73 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 74 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 75 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 76 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 77 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,success | processed=3; succeeded=1; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 78 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,duplicate | processed=3; succeeded=0; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 79 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,generic-error | processed=3; succeeded=0; failed=3; warnings=0; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 80 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,missing-class | processed=3; succeeded=0; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 81 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 82 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 83 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 84 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 85 | restore matrix | overwrite=NO; item outcomes=missing-class,success,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 86 | restore matrix | overwrite=NO; item outcomes=missing-class,success,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 87 | restore matrix | overwrite=NO; item outcomes=missing-class,success,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 88 | restore matrix | overwrite=NO; item outcomes=missing-class,success,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 89 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 90 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 91 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 92 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 93 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 94 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 95 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 96 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 97 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 98 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 99 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 100 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 101 | restore matrix | overwrite=NO; item outcomes=success,success,success,success | processed=4; succeeded=4; failed=0; warnings=0; errors=0; preserved duplicate warning for each duplicate; completion=Completed; exit=0 |
| 102 | restore matrix | overwrite=NO; item outcomes=success,success,success,duplicate | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 103 | restore matrix | overwrite=NO; item outcomes=success,success,success,generic-error | processed=4; succeeded=3; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 104 | restore matrix | overwrite=NO; item outcomes=success,success,success,missing-class | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 105 | restore matrix | overwrite=NO; item outcomes=success,success,duplicate,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 106 | restore matrix | overwrite=NO; item outcomes=success,success,duplicate,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 107 | restore matrix | overwrite=NO; item outcomes=success,success,duplicate,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 108 | restore matrix | overwrite=NO; item outcomes=success,success,duplicate,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 109 | restore matrix | overwrite=NO; item outcomes=success,success,generic-error,success | processed=4; succeeded=3; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 110 | restore matrix | overwrite=NO; item outcomes=success,success,generic-error,duplicate | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 111 | restore matrix | overwrite=NO; item outcomes=success,success,generic-error,generic-error | processed=4; succeeded=2; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 112 | restore matrix | overwrite=NO; item outcomes=success,success,generic-error,missing-class | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 113 | restore matrix | overwrite=NO; item outcomes=success,success,missing-class,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 114 | restore matrix | overwrite=NO; item outcomes=success,success,missing-class,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 115 | restore matrix | overwrite=NO; item outcomes=success,success,missing-class,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 116 | restore matrix | overwrite=NO; item outcomes=success,success,missing-class,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 117 | restore matrix | overwrite=NO; item outcomes=success,duplicate,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 118 | restore matrix | overwrite=NO; item outcomes=success,duplicate,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 119 | restore matrix | overwrite=NO; item outcomes=success,duplicate,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 120 | restore matrix | overwrite=NO; item outcomes=success,duplicate,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 121 | restore matrix | overwrite=NO; item outcomes=success,duplicate,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 122 | restore matrix | overwrite=NO; item outcomes=success,duplicate,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 123 | restore matrix | overwrite=NO; item outcomes=success,duplicate,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 124 | restore matrix | overwrite=NO; item outcomes=success,duplicate,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 125 | restore matrix | overwrite=NO; item outcomes=success,duplicate,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 126 | restore matrix | overwrite=NO; item outcomes=success,duplicate,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 127 | restore matrix | overwrite=NO; item outcomes=success,duplicate,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 128 | restore matrix | overwrite=NO; item outcomes=success,duplicate,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 129 | restore matrix | overwrite=NO; item outcomes=success,duplicate,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 130 | restore matrix | overwrite=NO; item outcomes=success,duplicate,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 131 | restore matrix | overwrite=NO; item outcomes=success,duplicate,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 132 | restore matrix | overwrite=NO; item outcomes=success,duplicate,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 133 | restore matrix | overwrite=NO; item outcomes=success,generic-error,success,success | processed=4; succeeded=3; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 134 | restore matrix | overwrite=NO; item outcomes=success,generic-error,success,duplicate | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 135 | restore matrix | overwrite=NO; item outcomes=success,generic-error,success,generic-error | processed=4; succeeded=2; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 136 | restore matrix | overwrite=NO; item outcomes=success,generic-error,success,missing-class | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 137 | restore matrix | overwrite=NO; item outcomes=success,generic-error,duplicate,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 138 | restore matrix | overwrite=NO; item outcomes=success,generic-error,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 139 | restore matrix | overwrite=NO; item outcomes=success,generic-error,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 140 | restore matrix | overwrite=NO; item outcomes=success,generic-error,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 141 | restore matrix | overwrite=NO; item outcomes=success,generic-error,generic-error,success | processed=4; succeeded=2; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 142 | restore matrix | overwrite=NO; item outcomes=success,generic-error,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 143 | restore matrix | overwrite=NO; item outcomes=success,generic-error,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=0; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 144 | restore matrix | overwrite=NO; item outcomes=success,generic-error,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 145 | restore matrix | overwrite=NO; item outcomes=success,generic-error,missing-class,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 146 | restore matrix | overwrite=NO; item outcomes=success,generic-error,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 147 | restore matrix | overwrite=NO; item outcomes=success,generic-error,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 148 | restore matrix | overwrite=NO; item outcomes=success,generic-error,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 149 | restore matrix | overwrite=NO; item outcomes=success,missing-class,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 150 | restore matrix | overwrite=NO; item outcomes=success,missing-class,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 151 | restore matrix | overwrite=NO; item outcomes=success,missing-class,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 152 | restore matrix | overwrite=NO; item outcomes=success,missing-class,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 153 | restore matrix | overwrite=NO; item outcomes=success,missing-class,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 154 | restore matrix | overwrite=NO; item outcomes=success,missing-class,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 155 | restore matrix | overwrite=NO; item outcomes=success,missing-class,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 156 | restore matrix | overwrite=NO; item outcomes=success,missing-class,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 157 | restore matrix | overwrite=NO; item outcomes=success,missing-class,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 158 | restore matrix | overwrite=NO; item outcomes=success,missing-class,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 159 | restore matrix | overwrite=NO; item outcomes=success,missing-class,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 160 | restore matrix | overwrite=NO; item outcomes=success,missing-class,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 161 | restore matrix | overwrite=NO; item outcomes=success,missing-class,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 162 | restore matrix | overwrite=NO; item outcomes=success,missing-class,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 163 | restore matrix | overwrite=NO; item outcomes=success,missing-class,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 164 | restore matrix | overwrite=NO; item outcomes=success,missing-class,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 165 | restore matrix | overwrite=NO; item outcomes=duplicate,success,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 166 | restore matrix | overwrite=NO; item outcomes=duplicate,success,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 167 | restore matrix | overwrite=NO; item outcomes=duplicate,success,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 168 | restore matrix | overwrite=NO; item outcomes=duplicate,success,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 169 | restore matrix | overwrite=NO; item outcomes=duplicate,success,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 170 | restore matrix | overwrite=NO; item outcomes=duplicate,success,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 171 | restore matrix | overwrite=NO; item outcomes=duplicate,success,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 172 | restore matrix | overwrite=NO; item outcomes=duplicate,success,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 173 | restore matrix | overwrite=NO; item outcomes=duplicate,success,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 174 | restore matrix | overwrite=NO; item outcomes=duplicate,success,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 175 | restore matrix | overwrite=NO; item outcomes=duplicate,success,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 176 | restore matrix | overwrite=NO; item outcomes=duplicate,success,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 177 | restore matrix | overwrite=NO; item outcomes=duplicate,success,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 178 | restore matrix | overwrite=NO; item outcomes=duplicate,success,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 179 | restore matrix | overwrite=NO; item outcomes=duplicate,success,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 180 | restore matrix | overwrite=NO; item outcomes=duplicate,success,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 181 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 182 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 183 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 184 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 185 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 186 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 187 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 188 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 189 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 190 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 191 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 192 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 193 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 194 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 195 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 196 | restore matrix | overwrite=NO; item outcomes=duplicate,duplicate,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 197 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 198 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 199 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 200 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 201 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 202 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 203 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 204 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 205 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 206 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 207 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 208 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 209 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 210 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 211 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 212 | restore matrix | overwrite=NO; item outcomes=duplicate,generic-error,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 213 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 214 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 215 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 216 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 217 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 218 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 219 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 220 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 221 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 222 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 223 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 224 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 225 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 226 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 227 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 228 | restore matrix | overwrite=NO; item outcomes=duplicate,missing-class,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 229 | restore matrix | overwrite=NO; item outcomes=generic-error,success,success,success | processed=4; succeeded=3; failed=1; warnings=0; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 230 | restore matrix | overwrite=NO; item outcomes=generic-error,success,success,duplicate | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 231 | restore matrix | overwrite=NO; item outcomes=generic-error,success,success,generic-error | processed=4; succeeded=2; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 232 | restore matrix | overwrite=NO; item outcomes=generic-error,success,success,missing-class | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 233 | restore matrix | overwrite=NO; item outcomes=generic-error,success,duplicate,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 234 | restore matrix | overwrite=NO; item outcomes=generic-error,success,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 235 | restore matrix | overwrite=NO; item outcomes=generic-error,success,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 236 | restore matrix | overwrite=NO; item outcomes=generic-error,success,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 237 | restore matrix | overwrite=NO; item outcomes=generic-error,success,generic-error,success | processed=4; succeeded=2; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 238 | restore matrix | overwrite=NO; item outcomes=generic-error,success,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 239 | restore matrix | overwrite=NO; item outcomes=generic-error,success,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=0; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 240 | restore matrix | overwrite=NO; item outcomes=generic-error,success,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 241 | restore matrix | overwrite=NO; item outcomes=generic-error,success,missing-class,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 242 | restore matrix | overwrite=NO; item outcomes=generic-error,success,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 243 | restore matrix | overwrite=NO; item outcomes=generic-error,success,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 244 | restore matrix | overwrite=NO; item outcomes=generic-error,success,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 245 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 246 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 247 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 248 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 249 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 250 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 251 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 252 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 253 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 254 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 255 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 256 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 257 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 258 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 259 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 260 | restore matrix | overwrite=NO; item outcomes=generic-error,duplicate,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 261 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,success,success | processed=4; succeeded=2; failed=2; warnings=0; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 262 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,success,duplicate | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 263 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,success,generic-error | processed=4; succeeded=1; failed=3; warnings=0; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 264 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,success,missing-class | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 265 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,duplicate,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 266 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 267 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 268 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 269 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,generic-error,success | processed=4; succeeded=1; failed=3; warnings=0; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 270 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 271 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=0; errors=4; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 272 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 273 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,missing-class,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 274 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 275 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 276 | restore matrix | overwrite=NO; item outcomes=generic-error,generic-error,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 277 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 278 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 279 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 280 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 281 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 282 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 283 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 284 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 285 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 286 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 287 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 288 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 289 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 290 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 291 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 292 | restore matrix | overwrite=NO; item outcomes=generic-error,missing-class,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 293 | restore matrix | overwrite=NO; item outcomes=missing-class,success,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 294 | restore matrix | overwrite=NO; item outcomes=missing-class,success,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 295 | restore matrix | overwrite=NO; item outcomes=missing-class,success,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 296 | restore matrix | overwrite=NO; item outcomes=missing-class,success,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 297 | restore matrix | overwrite=NO; item outcomes=missing-class,success,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 298 | restore matrix | overwrite=NO; item outcomes=missing-class,success,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 299 | restore matrix | overwrite=NO; item outcomes=missing-class,success,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 300 | restore matrix | overwrite=NO; item outcomes=missing-class,success,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 301 | restore matrix | overwrite=NO; item outcomes=missing-class,success,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 302 | restore matrix | overwrite=NO; item outcomes=missing-class,success,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 303 | restore matrix | overwrite=NO; item outcomes=missing-class,success,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 304 | restore matrix | overwrite=NO; item outcomes=missing-class,success,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 305 | restore matrix | overwrite=NO; item outcomes=missing-class,success,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 306 | restore matrix | overwrite=NO; item outcomes=missing-class,success,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 307 | restore matrix | overwrite=NO; item outcomes=missing-class,success,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 308 | restore matrix | overwrite=NO; item outcomes=missing-class,success,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 309 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 310 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 311 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 312 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 313 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 314 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 315 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 316 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 317 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 318 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 319 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 320 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 321 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 322 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 323 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 324 | restore matrix | overwrite=NO; item outcomes=missing-class,duplicate,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 325 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 326 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 327 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 328 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 329 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 330 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 331 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 332 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 333 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 334 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 335 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 336 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 337 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 338 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 339 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 340 | restore matrix | overwrite=NO; item outcomes=missing-class,generic-error,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 341 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 342 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 343 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 344 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 345 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 346 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 347 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 348 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 349 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 350 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 351 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 352 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 353 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 354 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 355 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 356 | restore matrix | overwrite=NO; item outcomes=missing-class,missing-class,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; preserved duplicate warning for each duplicate; completion=Partial; exit=10 |
| 357 | restore matrix | overwrite=YES; item outcomes=empty | processed=0; succeeded=0; failed=0; warnings=0; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Completed; exit=0 |
| 358 | restore matrix | overwrite=YES; item outcomes=success | processed=1; succeeded=1; failed=0; warnings=0; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Completed; exit=0 |
| 359 | restore matrix | overwrite=YES; item outcomes=duplicate | processed=1; succeeded=0; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 360 | restore matrix | overwrite=YES; item outcomes=generic-error | processed=1; succeeded=0; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 361 | restore matrix | overwrite=YES; item outcomes=missing-class | processed=1; succeeded=0; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 362 | restore matrix | overwrite=YES; item outcomes=success,success | processed=2; succeeded=2; failed=0; warnings=0; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Completed; exit=0 |
| 363 | restore matrix | overwrite=YES; item outcomes=success,duplicate | processed=2; succeeded=1; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 364 | restore matrix | overwrite=YES; item outcomes=success,generic-error | processed=2; succeeded=1; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 365 | restore matrix | overwrite=YES; item outcomes=success,missing-class | processed=2; succeeded=1; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 366 | restore matrix | overwrite=YES; item outcomes=duplicate,success | processed=2; succeeded=1; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 367 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate | processed=2; succeeded=0; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 368 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error | processed=2; succeeded=0; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 369 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class | processed=2; succeeded=0; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 370 | restore matrix | overwrite=YES; item outcomes=generic-error,success | processed=2; succeeded=1; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 371 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate | processed=2; succeeded=0; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 372 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error | processed=2; succeeded=0; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 373 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class | processed=2; succeeded=0; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 374 | restore matrix | overwrite=YES; item outcomes=missing-class,success | processed=2; succeeded=1; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 375 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate | processed=2; succeeded=0; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 376 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error | processed=2; succeeded=0; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 377 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class | processed=2; succeeded=0; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 378 | restore matrix | overwrite=YES; item outcomes=success,success,success | processed=3; succeeded=3; failed=0; warnings=0; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Completed; exit=0 |
| 379 | restore matrix | overwrite=YES; item outcomes=success,success,duplicate | processed=3; succeeded=2; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 380 | restore matrix | overwrite=YES; item outcomes=success,success,generic-error | processed=3; succeeded=2; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 381 | restore matrix | overwrite=YES; item outcomes=success,success,missing-class | processed=3; succeeded=2; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 382 | restore matrix | overwrite=YES; item outcomes=success,duplicate,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 383 | restore matrix | overwrite=YES; item outcomes=success,duplicate,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 384 | restore matrix | overwrite=YES; item outcomes=success,duplicate,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 385 | restore matrix | overwrite=YES; item outcomes=success,duplicate,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 386 | restore matrix | overwrite=YES; item outcomes=success,generic-error,success | processed=3; succeeded=2; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 387 | restore matrix | overwrite=YES; item outcomes=success,generic-error,duplicate | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 388 | restore matrix | overwrite=YES; item outcomes=success,generic-error,generic-error | processed=3; succeeded=1; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 389 | restore matrix | overwrite=YES; item outcomes=success,generic-error,missing-class | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 390 | restore matrix | overwrite=YES; item outcomes=success,missing-class,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 391 | restore matrix | overwrite=YES; item outcomes=success,missing-class,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 392 | restore matrix | overwrite=YES; item outcomes=success,missing-class,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 393 | restore matrix | overwrite=YES; item outcomes=success,missing-class,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 394 | restore matrix | overwrite=YES; item outcomes=duplicate,success,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 395 | restore matrix | overwrite=YES; item outcomes=duplicate,success,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 396 | restore matrix | overwrite=YES; item outcomes=duplicate,success,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 397 | restore matrix | overwrite=YES; item outcomes=duplicate,success,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 398 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 399 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 400 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 401 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 402 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 403 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 404 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 405 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 406 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 407 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 408 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 409 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 410 | restore matrix | overwrite=YES; item outcomes=generic-error,success,success | processed=3; succeeded=2; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 411 | restore matrix | overwrite=YES; item outcomes=generic-error,success,duplicate | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 412 | restore matrix | overwrite=YES; item outcomes=generic-error,success,generic-error | processed=3; succeeded=1; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 413 | restore matrix | overwrite=YES; item outcomes=generic-error,success,missing-class | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 414 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 415 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 416 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 417 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 418 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,success | processed=3; succeeded=1; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 419 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,duplicate | processed=3; succeeded=0; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 420 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,generic-error | processed=3; succeeded=0; failed=3; warnings=0; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 421 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,missing-class | processed=3; succeeded=0; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 422 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 423 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 424 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 425 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 426 | restore matrix | overwrite=YES; item outcomes=missing-class,success,success | processed=3; succeeded=2; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 427 | restore matrix | overwrite=YES; item outcomes=missing-class,success,duplicate | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 428 | restore matrix | overwrite=YES; item outcomes=missing-class,success,generic-error | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 429 | restore matrix | overwrite=YES; item outcomes=missing-class,success,missing-class | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 430 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 431 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 432 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 433 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 434 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,success | processed=3; succeeded=1; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 435 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,duplicate | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 436 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,generic-error | processed=3; succeeded=0; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 437 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,missing-class | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 438 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,success | processed=3; succeeded=1; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 439 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,duplicate | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 440 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,generic-error | processed=3; succeeded=0; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 441 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,missing-class | processed=3; succeeded=0; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 442 | restore matrix | overwrite=YES; item outcomes=success,success,success,success | processed=4; succeeded=4; failed=0; warnings=0; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Completed; exit=0 |
| 443 | restore matrix | overwrite=YES; item outcomes=success,success,success,duplicate | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 444 | restore matrix | overwrite=YES; item outcomes=success,success,success,generic-error | processed=4; succeeded=3; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 445 | restore matrix | overwrite=YES; item outcomes=success,success,success,missing-class | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 446 | restore matrix | overwrite=YES; item outcomes=success,success,duplicate,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 447 | restore matrix | overwrite=YES; item outcomes=success,success,duplicate,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 448 | restore matrix | overwrite=YES; item outcomes=success,success,duplicate,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 449 | restore matrix | overwrite=YES; item outcomes=success,success,duplicate,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 450 | restore matrix | overwrite=YES; item outcomes=success,success,generic-error,success | processed=4; succeeded=3; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 451 | restore matrix | overwrite=YES; item outcomes=success,success,generic-error,duplicate | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 452 | restore matrix | overwrite=YES; item outcomes=success,success,generic-error,generic-error | processed=4; succeeded=2; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 453 | restore matrix | overwrite=YES; item outcomes=success,success,generic-error,missing-class | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 454 | restore matrix | overwrite=YES; item outcomes=success,success,missing-class,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 455 | restore matrix | overwrite=YES; item outcomes=success,success,missing-class,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 456 | restore matrix | overwrite=YES; item outcomes=success,success,missing-class,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 457 | restore matrix | overwrite=YES; item outcomes=success,success,missing-class,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 458 | restore matrix | overwrite=YES; item outcomes=success,duplicate,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 459 | restore matrix | overwrite=YES; item outcomes=success,duplicate,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 460 | restore matrix | overwrite=YES; item outcomes=success,duplicate,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 461 | restore matrix | overwrite=YES; item outcomes=success,duplicate,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 462 | restore matrix | overwrite=YES; item outcomes=success,duplicate,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 463 | restore matrix | overwrite=YES; item outcomes=success,duplicate,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 464 | restore matrix | overwrite=YES; item outcomes=success,duplicate,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 465 | restore matrix | overwrite=YES; item outcomes=success,duplicate,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 466 | restore matrix | overwrite=YES; item outcomes=success,duplicate,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 467 | restore matrix | overwrite=YES; item outcomes=success,duplicate,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 468 | restore matrix | overwrite=YES; item outcomes=success,duplicate,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 469 | restore matrix | overwrite=YES; item outcomes=success,duplicate,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 470 | restore matrix | overwrite=YES; item outcomes=success,duplicate,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 471 | restore matrix | overwrite=YES; item outcomes=success,duplicate,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 472 | restore matrix | overwrite=YES; item outcomes=success,duplicate,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 473 | restore matrix | overwrite=YES; item outcomes=success,duplicate,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 474 | restore matrix | overwrite=YES; item outcomes=success,generic-error,success,success | processed=4; succeeded=3; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 475 | restore matrix | overwrite=YES; item outcomes=success,generic-error,success,duplicate | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 476 | restore matrix | overwrite=YES; item outcomes=success,generic-error,success,generic-error | processed=4; succeeded=2; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 477 | restore matrix | overwrite=YES; item outcomes=success,generic-error,success,missing-class | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 478 | restore matrix | overwrite=YES; item outcomes=success,generic-error,duplicate,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 479 | restore matrix | overwrite=YES; item outcomes=success,generic-error,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 480 | restore matrix | overwrite=YES; item outcomes=success,generic-error,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 481 | restore matrix | overwrite=YES; item outcomes=success,generic-error,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 482 | restore matrix | overwrite=YES; item outcomes=success,generic-error,generic-error,success | processed=4; succeeded=2; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 483 | restore matrix | overwrite=YES; item outcomes=success,generic-error,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 484 | restore matrix | overwrite=YES; item outcomes=success,generic-error,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=0; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 485 | restore matrix | overwrite=YES; item outcomes=success,generic-error,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 486 | restore matrix | overwrite=YES; item outcomes=success,generic-error,missing-class,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 487 | restore matrix | overwrite=YES; item outcomes=success,generic-error,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 488 | restore matrix | overwrite=YES; item outcomes=success,generic-error,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 489 | restore matrix | overwrite=YES; item outcomes=success,generic-error,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 490 | restore matrix | overwrite=YES; item outcomes=success,missing-class,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 491 | restore matrix | overwrite=YES; item outcomes=success,missing-class,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 492 | restore matrix | overwrite=YES; item outcomes=success,missing-class,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 493 | restore matrix | overwrite=YES; item outcomes=success,missing-class,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 494 | restore matrix | overwrite=YES; item outcomes=success,missing-class,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 495 | restore matrix | overwrite=YES; item outcomes=success,missing-class,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 496 | restore matrix | overwrite=YES; item outcomes=success,missing-class,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 497 | restore matrix | overwrite=YES; item outcomes=success,missing-class,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 498 | restore matrix | overwrite=YES; item outcomes=success,missing-class,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 499 | restore matrix | overwrite=YES; item outcomes=success,missing-class,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 500 | restore matrix | overwrite=YES; item outcomes=success,missing-class,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 501 | restore matrix | overwrite=YES; item outcomes=success,missing-class,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 502 | restore matrix | overwrite=YES; item outcomes=success,missing-class,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 503 | restore matrix | overwrite=YES; item outcomes=success,missing-class,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 504 | restore matrix | overwrite=YES; item outcomes=success,missing-class,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 505 | restore matrix | overwrite=YES; item outcomes=success,missing-class,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 506 | restore matrix | overwrite=YES; item outcomes=duplicate,success,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 507 | restore matrix | overwrite=YES; item outcomes=duplicate,success,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 508 | restore matrix | overwrite=YES; item outcomes=duplicate,success,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 509 | restore matrix | overwrite=YES; item outcomes=duplicate,success,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 510 | restore matrix | overwrite=YES; item outcomes=duplicate,success,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 511 | restore matrix | overwrite=YES; item outcomes=duplicate,success,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 512 | restore matrix | overwrite=YES; item outcomes=duplicate,success,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 513 | restore matrix | overwrite=YES; item outcomes=duplicate,success,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 514 | restore matrix | overwrite=YES; item outcomes=duplicate,success,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 515 | restore matrix | overwrite=YES; item outcomes=duplicate,success,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 516 | restore matrix | overwrite=YES; item outcomes=duplicate,success,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 517 | restore matrix | overwrite=YES; item outcomes=duplicate,success,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 518 | restore matrix | overwrite=YES; item outcomes=duplicate,success,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 519 | restore matrix | overwrite=YES; item outcomes=duplicate,success,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 520 | restore matrix | overwrite=YES; item outcomes=duplicate,success,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 521 | restore matrix | overwrite=YES; item outcomes=duplicate,success,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 522 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 523 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 524 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 525 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 526 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 527 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 528 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 529 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 530 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 531 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 532 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 533 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 534 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 535 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 536 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 537 | restore matrix | overwrite=YES; item outcomes=duplicate,duplicate,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 538 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 539 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 540 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 541 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 542 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 543 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 544 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 545 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 546 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 547 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 548 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 549 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 550 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 551 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 552 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 553 | restore matrix | overwrite=YES; item outcomes=duplicate,generic-error,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 554 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 555 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 556 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 557 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 558 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 559 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 560 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 561 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 562 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 563 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 564 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 565 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 566 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 567 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 568 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 569 | restore matrix | overwrite=YES; item outcomes=duplicate,missing-class,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 570 | restore matrix | overwrite=YES; item outcomes=generic-error,success,success,success | processed=4; succeeded=3; failed=1; warnings=0; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 571 | restore matrix | overwrite=YES; item outcomes=generic-error,success,success,duplicate | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 572 | restore matrix | overwrite=YES; item outcomes=generic-error,success,success,generic-error | processed=4; succeeded=2; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 573 | restore matrix | overwrite=YES; item outcomes=generic-error,success,success,missing-class | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 574 | restore matrix | overwrite=YES; item outcomes=generic-error,success,duplicate,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 575 | restore matrix | overwrite=YES; item outcomes=generic-error,success,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 576 | restore matrix | overwrite=YES; item outcomes=generic-error,success,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 577 | restore matrix | overwrite=YES; item outcomes=generic-error,success,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 578 | restore matrix | overwrite=YES; item outcomes=generic-error,success,generic-error,success | processed=4; succeeded=2; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 579 | restore matrix | overwrite=YES; item outcomes=generic-error,success,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 580 | restore matrix | overwrite=YES; item outcomes=generic-error,success,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=0; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 581 | restore matrix | overwrite=YES; item outcomes=generic-error,success,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 582 | restore matrix | overwrite=YES; item outcomes=generic-error,success,missing-class,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 583 | restore matrix | overwrite=YES; item outcomes=generic-error,success,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 584 | restore matrix | overwrite=YES; item outcomes=generic-error,success,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 585 | restore matrix | overwrite=YES; item outcomes=generic-error,success,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 586 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 587 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 588 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 589 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 590 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 591 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 592 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 593 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 594 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 595 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 596 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 597 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 598 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 599 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 600 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 601 | restore matrix | overwrite=YES; item outcomes=generic-error,duplicate,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 602 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,success,success | processed=4; succeeded=2; failed=2; warnings=0; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 603 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,success,duplicate | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 604 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,success,generic-error | processed=4; succeeded=1; failed=3; warnings=0; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 605 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,success,missing-class | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 606 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,duplicate,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 607 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 608 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 609 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 610 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,generic-error,success | processed=4; succeeded=1; failed=3; warnings=0; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 611 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 612 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=0; errors=4; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 613 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 614 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,missing-class,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 615 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 616 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 617 | restore matrix | overwrite=YES; item outcomes=generic-error,generic-error,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 618 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 619 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 620 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 621 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 622 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 623 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 624 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 625 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 626 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 627 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 628 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 629 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 630 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 631 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 632 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 633 | restore matrix | overwrite=YES; item outcomes=generic-error,missing-class,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 634 | restore matrix | overwrite=YES; item outcomes=missing-class,success,success,success | processed=4; succeeded=3; failed=1; warnings=1; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 635 | restore matrix | overwrite=YES; item outcomes=missing-class,success,success,duplicate | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 636 | restore matrix | overwrite=YES; item outcomes=missing-class,success,success,generic-error | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 637 | restore matrix | overwrite=YES; item outcomes=missing-class,success,success,missing-class | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 638 | restore matrix | overwrite=YES; item outcomes=missing-class,success,duplicate,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 639 | restore matrix | overwrite=YES; item outcomes=missing-class,success,duplicate,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 640 | restore matrix | overwrite=YES; item outcomes=missing-class,success,duplicate,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 641 | restore matrix | overwrite=YES; item outcomes=missing-class,success,duplicate,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 642 | restore matrix | overwrite=YES; item outcomes=missing-class,success,generic-error,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 643 | restore matrix | overwrite=YES; item outcomes=missing-class,success,generic-error,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 644 | restore matrix | overwrite=YES; item outcomes=missing-class,success,generic-error,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 645 | restore matrix | overwrite=YES; item outcomes=missing-class,success,generic-error,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 646 | restore matrix | overwrite=YES; item outcomes=missing-class,success,missing-class,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 647 | restore matrix | overwrite=YES; item outcomes=missing-class,success,missing-class,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 648 | restore matrix | overwrite=YES; item outcomes=missing-class,success,missing-class,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 649 | restore matrix | overwrite=YES; item outcomes=missing-class,success,missing-class,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 650 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 651 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 652 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 653 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 654 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 655 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 656 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 657 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 658 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 659 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 660 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 661 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 662 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 663 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 664 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 665 | restore matrix | overwrite=YES; item outcomes=missing-class,duplicate,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 666 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,success,success | processed=4; succeeded=2; failed=2; warnings=1; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 667 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,success,duplicate | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 668 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,success,generic-error | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 669 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,success,missing-class | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 670 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,duplicate,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 671 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 672 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 673 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 674 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,generic-error,success | processed=4; succeeded=1; failed=3; warnings=1; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 675 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 676 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=1; errors=3; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 677 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 678 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,missing-class,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 679 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 680 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 681 | restore matrix | overwrite=YES; item outcomes=missing-class,generic-error,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 682 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,success,success | processed=4; succeeded=2; failed=2; warnings=2; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 683 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,success,duplicate | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 684 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,success,generic-error | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 685 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,success,missing-class | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 686 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,duplicate,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 687 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,duplicate,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 688 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,duplicate,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 689 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,duplicate,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 690 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,generic-error,success | processed=4; succeeded=1; failed=3; warnings=2; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 691 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,generic-error,duplicate | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 692 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,generic-error,generic-error | processed=4; succeeded=0; failed=4; warnings=2; errors=2; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 693 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,generic-error,missing-class | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 694 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,missing-class,success | processed=4; succeeded=1; failed=3; warnings=3; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 695 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,missing-class,duplicate | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 696 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,missing-class,generic-error | processed=4; succeeded=0; failed=4; warnings=3; errors=1; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 697 | restore matrix | overwrite=YES; item outcomes=missing-class,missing-class,missing-class,missing-class | processed=4; succeeded=0; failed=4; warnings=4; errors=0; overwrite-requested duplicate warning for each duplicate; completion=Partial; exit=10 |
| 698 | freeze/boundary | backup method remains byte-identical | no backup query/schema/count behavior changed |
| 699 | freeze/boundary | restore file read remains byte-identical | FileIO behavior unchanged |
| 700 | freeze/boundary | restore plist parser remains byte-identical | InvalidBackupFile behavior unchanged |
| 701 | freeze/boundary | restore item decoder remains unchanged | data/date decoding unchanged |
| 702 | freeze/boundary | generic add failure branch remains unchanged | errors still include current acct/service/group diagnostic |
| 703 | freeze/boundary | explicit wipe method remains byte-identical | group/class deletion behavior unchanged |
| 704 | freeze/boundary | list and diagnose methods remain byte-identical | read-only diagnostics unchanged |
| 705 | freeze/boundary | TASK-4.1 result header byte identity | schema API unchanged |
| 706 | freeze/boundary | TASK-4.1 result implementation byte identity | schema version/root/fatal/framing unchanged |
| 707 | freeze/boundary | TASK-4.2 exit enum byte identity | 13 values unchanged |
| 708 | freeze/boundary | TASK-4.2 finalizer definition/count | one definition and sixteen non-help call sites |
| 709 | freeze/boundary | TASK-4.2 emitter definition/count | one definition and one finalizer-owned call |
| 710 | freeze/boundary | TASK-4.2 shell constants | thirteen readonly constants unchanged |
| 711 | freeze/boundary | TASK-4.2 normalizer | one definition and four calls unchanged |
| 712 | freeze/boundary | manager integration | AppDataBackupManager byte-identical; zero/nonzero behavior unchanged |
| 713 | freeze/boundary | cleaner integration | AppDataCleaner byte-identical; explicit wipe accounting unchanged |
| 714 | freeze/boundary | bridge integration | WeaponXKeychainBridge byte-identical; no bridge unification |
| 715 | freeze/boundary | identity query boundary | no SecItemCopyMatching in restore |
| 716 | freeze/boundary | update boundary | no SecItemUpdate in restore or core |
| 717 | freeze/boundary | upsert boundary | no per-item delete/add replacement |
| 718 | freeze/boundary | rollback boundary | no rollback implementation |
| 719 | freeze/boundary | schema boundary | no backup schema migration |
| 720 | freeze/boundary | validation boundary | no strict item validation |
| 721 | freeze/boundary | workspace boundary | no secure path/workspace redesign |
| 722 | freeze/boundary | group reporting boundary | no requested/effective group reporting |
| 723 | freeze/boundary | caller parsing boundary | no result parser or exact-code switch |
| 724 | freeze/boundary | protection boundary | no backup-file protection |
| 725 | freeze/boundary | UI boundary | no UI or later-phase changes |
| 726 | freeze/boundary | TASK-4.4 boundary | exact identity not implemented |
| 727 | freeze/boundary | TASK-4.5 boundary | per-item upsert not implemented |

## Full authorized production diff
The report excludes its own diff/hash to avoid recursive self-embedding. Blank diff context lines are whitespace-normalized only.
```diff
diff --git a/KeychainHelper/KeychainBackupHelper.h b/KeychainHelper/KeychainBackupHelper.h
index 8519dc3..02ee22f 100644
--- a/KeychainHelper/KeychainBackupHelper.h
+++ b/KeychainHelper/KeychainBackupHelper.h
@@ -51,7 +51,9 @@ typedef NS_OPTIONS(NSUInteger, PXKeychainItemClass) {

 /// Restore keychain items from a backup plist file.
 /// @param filePath The path to the backup plist file.
-/// @param overwrite If YES, delete existing items before restore.
+/// @param overwrite Retained for compatibility. Restore never pre-deletes access-group/class contents.
+/// Duplicate existing items are preserved and reported as item failures.
+/// Safe replacement awaits future per-item identity/upsert support.
 /// @param error On failure, contains the error information.
 /// @return Result object with statistics, or nil on critical failure.
 + (PXKeychainBackupResult *_Nullable)restoreKeychainFromFile:(NSString *)filePath
diff --git a/KeychainHelper/KeychainBackupHelper.m b/KeychainHelper/KeychainBackupHelper.m
index 7077fb8..1214da7 100644
--- a/KeychainHelper/KeychainBackupHelper.m
+++ b/KeychainHelper/KeychainBackupHelper.m
@@ -358,39 +358,6 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
     NSMutableArray<NSString *> *errors = [NSMutableArray array];
     NSSet<NSString *> *excluded = PXExcludedRestoreAttributes();

-    // If overwrite, wipe target groups/classes up-front to avoid duplicate items
-    // due to incomplete per-item delete queries.
-    if (overwrite) {
-        NSArray<NSString *> *groups = [backup[@"accessGroups"] isKindOfClass:[NSArray class]] ? backup[@"accessGroups"] : @[];
-        NSMutableSet *classes = [NSMutableSet set];
-        for (NSDictionary *item in items) {
-            if (![item isKindOfClass:[NSDictionary class]]) continue;
-            id secClassValue = item[@"_secClass"];
-            if (secClassValue) {
-                [classes addObject:secClassValue];
-            }
-        }
-
-        for (NSString *group in groups) {
-            if (![group isKindOfClass:[NSString class]] || group.length == 0) continue;
-            for (id secClassValue in classes) {
-                if (!secClassValue) continue;
-                NSMutableDictionary *q = [NSMutableDictionary dictionary];
-                q[(__bridge id)kSecClass] = secClassValue;
-                q[(__bridge id)kSecAttrAccessGroup] = group;
-                // Include synchronizable items too.
-                q[(__bridge id)kSecAttrSynchronizable] = (__bridge id)kSecAttrSynchronizableAny;
-                OSStatus st = SecItemDelete((__bridge CFDictionaryRef)q);
-                if (st != errSecSuccess && st != errSecItemNotFound) {
-                    [warnings addObject:[NSString stringWithFormat:@"Pre-wipe failed for %@/%@: %@",
-                                         group,
-                                         secClassValue,
-                                         PXSecurityErrorDescription(st)]];
-                }
-            }
-        }
-    }
-
     for (NSDictionary *item in items) {
         if (![item isKindOfClass:[NSDictionary class]]) continue;
         result.itemsProcessed++;
@@ -436,8 +403,6 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
             }
         }

-        // If overwrite mode, we already performed a group-wide pre-wipe.
-
         // Add the item.
         // Ensure we can restore synchronizable items.
         if (addQuery[(__bridge id)kSecAttrSynchronizable]) {
@@ -447,9 +412,13 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {

         if (status == errSecSuccess) {
             result.itemsSucceeded++;
-        } else if (status == errSecDuplicateItem && !overwrite) {
-            [warnings addObject:[NSString stringWithFormat:@"Item already exists: %@",
-                               addQuery[(__bridge id)kSecAttrAccount] ?: @"unknown"]];
+        } else if (status == errSecDuplicateItem) {
+            NSString *duplicateWarning = overwrite
+                ? [NSString stringWithFormat:@"Overwrite requested but existing item was preserved pending safe per-item replacement: %@",
+                   addQuery[(__bridge id)kSecAttrAccount] ?: @"unknown"]
+                : [NSString stringWithFormat:@"Item already exists; existing item was preserved: %@",
+                   addQuery[(__bridge id)kSecAttrAccount] ?: @"unknown"];
+            [warnings addObject:duplicateWarning];
             result.itemsFailed++;
         } else {
             NSString *acct = addQuery[(__bridge id)kSecAttrAccount];
diff --git a/KeychainHelper/backup_helper.m b/KeychainHelper/backup_helper.m
index ff06f7d..7930929 100644
--- a/KeychainHelper/backup_helper.m
+++ b/KeychainHelper/backup_helper.m
@@ -43,7 +43,7 @@ static void printUsage(const char *progname) {
     fprintf(stderr, "  --action <action>   Action to perform: backup, restore, wipe, list\n");
     fprintf(stderr, "  --file <path>       Path to backup/restore file (plist format)\n");
     fprintf(stderr, "  --groups <groups>   Comma-separated list of keychain access groups\n");
-    fprintf(stderr, "  --overwrite         For restore: delete existing items first\n");
+    fprintf(stderr, "  --overwrite         For restore: request replacement; existing duplicates are preserved\n");
     fprintf(stderr, "  --verbose           Print detailed progress information\n");
     fprintf(stderr, "  --help              Show this help message\n");
 }
@@ -394,7 +394,7 @@ int main(int argc, const char *argv[]) {
                         PXKeychainHelperExitCodeInvalidArguments);
                 }

-                logVerbose(verbose, @"Starting keychain restore (overwrite: %@)...",
+                logVerbose(verbose, @"Starting keychain restore (overwrite requested: %@)...",
                           overwrite ? @"YES" : @"NO");
                 result = [KeychainBackupHelper restoreKeychainFromFile:filePath
                                                              overwrite:overwrite
diff --git a/scripts/keychain_backup.sh b/scripts/keychain_backup.sh
index c5b89d1..aad0ac6 100644
--- a/scripts/keychain_backup.sh
+++ b/scripts/keychain_backup.sh
@@ -961,7 +961,7 @@ print_usage() {
     echo "  list <bundleID>                   List keychain items"
     echo ""
     echo "Options:"
-    echo "  --overwrite   For restore: replace existing items"
+    echo "  --overwrite   For restore: request replacement; existing duplicates are preserved"
     echo "  --verbose     Show detailed output"
     echo ""
     echo "Example:"
```

## Whitespace, CRLF, NUL, and final newline
| File | Bytes | NUL bytes | CRLF sequences | Final LF |
|---|---:|---:|---:|---:|
| `KeychainHelper/KeychainBackupHelper.h` | 4462 | 0 | 86 | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | 26504 | 0 | 618 | TRUE |
| `KeychainHelper/backup_helper.m` | 28261 | 0 | 565 | TRUE |
| `scripts/keychain_backup.sh` | 36295 | 0 | 1108 | TRUE |
| `docs/backup-restore-hardening/reports/TASK-4.3-REPORT.md` | SELF-REFERENTIAL | 0 | 0 | TRUE |
- Existing four production files retain UTF-8 CRLF; the new report uses UTF-8 LF. No authorized file contains NUL bytes and all end with LF.

## Build, toolchain, and device risks
- Objective-C/Theos compile and link were not run because `clang.exe`, `make.exe`, and `xcrun.exe` are unavailable and `THEOS` is unset on this Windows host.
- Git Bash validation proves shell syntax only.
- Target-device validation remains required for real Security.framework duplicate statuses, item preservation, counts, stdout ordering, wrapper exit propagation, entitlement behavior, and keychain-class variations.
- GitHub Actions/source review remain authoritative for Apple SDK compilation, warnings, linking, packaging, and device integration.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
