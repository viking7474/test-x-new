# TASK-4.5 REPORT - Implement Exact Per-Item Keychain Upsert

## Result
- Implementation status: COMPLETE within TASK-4.5 scope.
- Mandatory baseline: `9d637e272030d51ffd48de76d7a4413a5b9b8d8b`.
- TASK-4.6 and later tasks were not started.

## Baseline and exact scope
| Status | Path | Purpose |
|---|---|---|
| M | `KeychainHelper/KeychainBackupHelper.h` | public restore contract |
| M | `KeychainHelper/KeychainBackupHelper.m` | exact per-item upsert |
| M | `KeychainHelper/backup_helper.m` | overwrite help only |
| M | `scripts/keychain_backup.sh` | overwrite help only |
| A | `docs/backup-restore-hardening/reports/TASK-4.5-REPORT.md` | evidence |
- Makefile remains protected and unchanged.

## Precondition TASK-4.4 acceptance
- Commit `9d637e272030d51ffd48de76d7a4413a5b9b8d8b` is the exact baseline.
- The owner-provided TASK-4.5 specification declares TASK-4.4 review ACCEPTED, status COMPLETED and TASK-4.5 READY.
- `docs/backup-restore-hardening/reviews/TASK-4.4-REVIEW.md` is absent. This is explicitly disclosed; no coordinator document was created or altered.
- TASK-4.4 report/source/identity contract were read and revalidated.

## Baseline evidence
```text
git status --short --untracked-files=all
git rev-parse HEAD
git log --oneline -n 8
git diff --check
git show --check --oneline HEAD
```
HEAD:
```text
9d637e272030d51ffd48de76d7a4413a5b9b8d8b
```
Coordinator-owned state preserved:
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
Log:
```text
9d637e2 phase4(task-4.4): define exact keychain item identity
4c70002 phase4(task-4.3): remove broad keychain restore pre-delete
5c6e70a phase4(task-4.2): define reliable keychain helper exit codes
1a59e96 phase4(task-4.1): add structured keychain helper result
02770e2 phase3(task-3.10A): fix stale name classification and rollback errors
5e70a8f phase3(task-3.10): harden backup discovery and stale cleanup
aa01f73 phase3(task-3.9A): make cleanup removal race safe
aa47468 phase3(task-3.9): centralize backup failure cleanup
```
Checks: PASS; coordinator documentation emitted only pre-existing line-ending warnings.

## Protected hashes and byte sizes
Protected paths: 74; all byte-identical.
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

## Authorized source before/after
| File | Before SHA-256 | Before bytes | After SHA-256 | After bytes |
|---|---|---:|---|---:|
| `KeychainHelper/KeychainBackupHelper.h` | `23fd5431f751401a7a09edca1eafec80ab1118321ed6493751d9061e750dc010` | 4462 | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | 4584 |
| `KeychainHelper/KeychainBackupHelper.m` | `798f6c6aa87b77a525c1bcbb866877fdb6d544f41df4c63cfbdaaade56eedfa7` | 26504 | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | 38587 |
| `KeychainHelper/backup_helper.m` | `e776a0399614c34195cd09601e420a607bc0147cf034976d740247f79cb79943` | 28261 | `f3af22735ef307a2f583079832c4a7222ffbcf2617c366de564086cf538c1eee` | 28260 |
| `scripts/keychain_backup.sh` | `05a2b44a1f36ab0ffba407a9e76f7cd7cb26b4455276f6640d738753d9840f53` | 36295 | `b4193337633fea4b126c6466c3172c637c759c1a041b6bf7532a7cdd7a27bdce` | 36294 |
| `docs/backup-restore-hardening/reports/TASK-4.5-REPORT.md` | ABSENT | 0 | SELF-REFERENTIAL | SELF-REFERENTIAL |

## Current restore behavior inventory
Baseline inserted raw `_secClass`, attempted one add, preserved every duplicate, had zero restore lookup/update, and emitted identity-bearing diagnostics.
TASK-4.5 canonicalizes class, retains add-first, preserves duplicate overwrite-NO, and for duplicate overwrite-YES performs exact identity, unique lookup and persistent-ref update with privacy-safe diagnostics.

## Security operation inventory
| Scope | CopyMatching | Add | Update | Delete |
|---|---:|---:|---:|---:|
| Baseline core | 5 | 1 | 0 | 1 |
| Baseline restore | 0 | 1 | 0 | 0 |
| TASK-4.5 core | 6 | 1 | 1 | 1 |
| TASK-4.5 restore | 1 | 1 | 1 | 0 |
The one delete remains explicit wipe.

## Current addQuery inventory
Decoded dictionary plus canonical kSecClass is the authority. Metadata, raw class and system-managed restore attributes are omitted. Recognized data/date wrappers require exact types. The raw wrapped item is never passed to identity. Entry count is bounded to 256.

## Canonical `_secClass` boundary
Exactly one helper proves CFString type, compares against five class constants and returns the exact constant only for cardinality one. `_secClass` is authority; `_class` is consistency-only. Missing, wrong, unsupported, ambiguous or conflicting values fail before mutation. No shape/value/label fallback exists.

## Add-first design
One add attempt is the fast path. Success does not construct identity or query/update. Nonduplicate errors fail immediately. Identity occurs only after duplicate plus overwrite YES. No lookup-before-add, wider retry or restore delete exists.

## Duplicate overwrite NO behavior
Preserve existing item; increment failed and warning once; no identity, lookup, update or delete. Bounded warning yields Partial/exit 10 through unchanged protocol logic.

## Duplicate overwrite YES behavior
Decoded addQuery is passed once to the TASK-4.4 factory. Identity failure preserves the item. Valid identity proceeds to one exact lookup and requires one persistent reference before update.

## PXKeychainItemIdentity integration
Identity files remain byte-identical. Canonical class is installed before factory invocation. Exact class/access-group/synchronizable/class tuple and TASK-4.4 no-fallback rules remain authoritative.

## Exact lookup query
Starts from identity.matchQuery and adds only matchLimitAll, returnPersistentRef YES and authenticationUIFail. It retains exact synchronizable YES/NO and excludes synchronizableAny, data/ref returns, values and fallback attributes.

## Unique cardinality proof
Accept one nonempty NSData or an array containing exactly one nonempty NSData. Nil, empty/multiple, wrong type/element, empty data, non-success status, snapshot failure and exception all fail closed before update.

## Persistent-reference snapshot proof
Resolved data is copied into immutable NSData and length/equality checked. It is local only and never stored, logged or returned.

## Update dictionary construction
Starts from decoded addQuery. Removes class, access group, synchronizable, identityAttributeNames, system-managed attributes, query/return/auth controls and reference values. Returns immutable filtered attributes.

## Identity-key exclusion proof
Generic removes account/service; internet removes account/server/port/protocol/authenticationType/path/securityDomain; certificate removes issuer/serial; key removes applicationLabel/keyClass/keyType; identity removes applicationLabel/issuer/serial. Existing identity cannot change.

## Query-control exclusion proof
All listed controls are removed from attributes. Update query contains only valuePersistentRef plus authenticationUIFail. Direct update using identity.matchQuery: 0.

## Secret payload retention proof
kSecValueData is not excluded and remains update payload. Rejection by Security fails the item; it never converts to delete/add.

## Empty update payload behavior
After unique resolution, empty filtered attributes are success with no update, warning or error.

## SecItemUpdate result handling
Success increments succeeded. Item-not-found, duplicate, auth/interaction and other statuses increment failed once with numeric generic diagnostic. No prompt, retry, delete or rollback.

## Race and fail-closed behavior
Disappearance or invalid persistent ref between lookup/update fails once without retry or deletion. No old-value snapshot or transaction is claimed.

## Counter invariants
Non-dictionary entries preserve legacy skip. Every dictionary increments processed once and exactly one succeeded/failed. Deterministic aggregate model proves equality.

## Privacy-safe diagnostics
New text contains generic operation plus numeric status/error code only. It excludes all identity fields, secret data, persistent ref, raw item and exception text.

## Zero restore delete and explicit wipe sole-delete proof
Restore helper/method delete sites: 0. Core delete sites: 1, in explicit wipe. Delete-then-add sites: 0.

## TASK-4.1 through TASK-4.4 non-regression
TASK-4.1 schema/framing files are byte-identical. TASK-4.2 has 13 exit constants, one finalizer, 16 calls and unchanged shell normalization. TASK-4.3 zero restore delete remains. TASK-4.4 identity and Makefile are byte-identical.

## Wrapper passthrough non-regression
Wrapper changes one help line only. TEMP_DIR, trap, entitlement logic, copy/resign, groups, argv, normalizer and passthrough are unchanged. Both bash syntax checks pass.

## TASK-4.6 through TASK-4.9 boundaries
No workspace/path hardening, access-group reporting, manager integration, protection policy, UI or later work. Coordinator docs remain unstaged.

## Static gates
| Gate | Observed | Required | Result |
|---|---:|---:|---|
| canonical helper | 1 | 1 | PASS |
| restore CopyMatching/Add/Update/Delete | 1/1/1/0 | 1/1/1/0 | PASS |
| core CopyMatching/Add/Update/Delete | 6/1/1/1 | 6/1/1/1 | PASS |
| identity factory call | 1 | 1 | PASS |
| direct identity.matchQuery update | 0 | 0 | PASS |
| persistent-ref update | 1 | 1 | PASS |
| synchronizableAny/fallback/delete-add/rollback | 0/0/0/0 | 0/0/0/0 | PASS |
| wrapper normalizer defs/calls | 1/4 | unchanged | PASS |
| schema/exit constants | 1/13 | unchanged | PASS |
| protected production paths | 74 | 74 | PASS |
| behavioral model assertions | 466415 | 466415 | PASS |
| scenarios | 664 | >=320 | PASS |
- Lexical balance, shell syntax and git diff check: PASS.

## Explicit numbered scenarios
Explicit scenarios: 664.
| # | Area | Stimulus | Expected |
|---:|---|---|---|
| 1 | precondition | baseline exact | enforced |
| 2 | precondition | TASK-4.4 commit present | enforced |
| 3 | precondition | owner spec review ACCEPTED | enforced |
| 4 | precondition | owner spec status COMPLETED | enforced |
| 5 | precondition | TASK-4.5 READY | enforced |
| 6 | precondition | TASK-4.4 report present | enforced |
| 7 | precondition | TASK-4.4 review file absent/disclosed | enforced |
| 8 | precondition | coordinator state preserved | enforced |
| 9 | precondition | exact five-file scope | enforced |
| 10 | precondition | Makefile protected | enforced |
| 11 | precondition | identity protected | enforced |
| 12 | precondition | protocol protected | enforced |
| 13 | precondition | no TASK-4.6 | enforced |
| 14 | canonical class | GenericPassword: exact kSecClassGenericPassword | canonical kSecClassGenericPassword |
| 15 | canonical class | GenericPassword: plist string equal to kSecClassGenericPassword | canonical kSecClassGenericPassword |
| 16 | canonical class | GenericPassword: mutable string equal to kSecClassGenericPassword | canonical kSecClassGenericPassword |
| 17 | canonical class | GenericPassword: matching _class | accept |
| 18 | canonical class | GenericPassword: absent _class | accept; _secClass authority |
| 19 | canonical class | GenericPassword: conflicting _class | fail before mutation |
| 20 | canonical class | InternetPassword: exact kSecClassInternetPassword | canonical kSecClassInternetPassword |
| 21 | canonical class | InternetPassword: plist string equal to kSecClassInternetPassword | canonical kSecClassInternetPassword |
| 22 | canonical class | InternetPassword: mutable string equal to kSecClassInternetPassword | canonical kSecClassInternetPassword |
| 23 | canonical class | InternetPassword: matching _class | accept |
| 24 | canonical class | InternetPassword: absent _class | accept; _secClass authority |
| 25 | canonical class | InternetPassword: conflicting _class | fail before mutation |
| 26 | canonical class | Certificate: exact kSecClassCertificate | canonical kSecClassCertificate |
| 27 | canonical class | Certificate: plist string equal to kSecClassCertificate | canonical kSecClassCertificate |
| 28 | canonical class | Certificate: mutable string equal to kSecClassCertificate | canonical kSecClassCertificate |
| 29 | canonical class | Certificate: matching _class | accept |
| 30 | canonical class | Certificate: absent _class | accept; _secClass authority |
| 31 | canonical class | Certificate: conflicting _class | fail before mutation |
| 32 | canonical class | Key: exact kSecClassKey | canonical kSecClassKey |
| 33 | canonical class | Key: plist string equal to kSecClassKey | canonical kSecClassKey |
| 34 | canonical class | Key: mutable string equal to kSecClassKey | canonical kSecClassKey |
| 35 | canonical class | Key: matching _class | accept |
| 36 | canonical class | Key: absent _class | accept; _secClass authority |
| 37 | canonical class | Key: conflicting _class | fail before mutation |
| 38 | canonical class | Identity: exact kSecClassIdentity | canonical kSecClassIdentity |
| 39 | canonical class | Identity: plist string equal to kSecClassIdentity | canonical kSecClassIdentity |
| 40 | canonical class | Identity: mutable string equal to kSecClassIdentity | canonical kSecClassIdentity |
| 41 | canonical class | Identity: matching _class | accept |
| 42 | canonical class | Identity: absent _class | accept; _secClass authority |
| 43 | canonical class | Identity: conflicting _class | fail before mutation |
| 44 | canonical class | missing _secClass | fail before add/lookup/update/delete |
| 45 | canonical class | NSNumber | fail before add/lookup/update/delete |
| 46 | canonical class | CFBoolean | fail before add/lookup/update/delete |
| 47 | canonical class | NSData | fail before add/lookup/update/delete |
| 48 | canonical class | NSArray | fail before add/lookup/update/delete |
| 49 | canonical class | NSDictionary | fail before add/lookup/update/delete |
| 50 | canonical class | NSNull | fail before add/lookup/update/delete |
| 51 | canonical class | unsupported string | fail before add/lookup/update/delete |
| 52 | canonical class | human class name only | fail before add/lookup/update/delete |
| 53 | canonical class | _class only | fail before add/lookup/update/delete |
| 54 | canonical class | ambiguous result | fail before add/lookup/update/delete |
| 55 | canonical class | throwing subclass | fail before add/lookup/update/delete |
| 56 | decode/addQuery | non-dictionary item | bounded explicit handling; malformed item fails before mutation |
| 57 | decode/addQuery | 0 entries | bounded explicit handling; malformed item fails before mutation |
| 58 | decode/addQuery | 256 entries | bounded explicit handling; malformed item fails before mutation |
| 59 | decode/addQuery | 257 entries | bounded explicit handling; malformed item fails before mutation |
| 60 | decode/addQuery | non-string key | bounded explicit handling; malformed item fails before mutation |
| 61 | decode/addQuery | metadata key | bounded explicit handling; malformed item fails before mutation |
| 62 | decode/addQuery | raw kSecClass | bounded explicit handling; malformed item fails before mutation |
| 63 | decode/addQuery | accessControl | bounded explicit handling; malformed item fails before mutation |
| 64 | decode/addQuery | creationDate | bounded explicit handling; malformed item fails before mutation |
| 65 | decode/addQuery | modificationDate | bounded explicit handling; malformed item fails before mutation |
| 66 | decode/addQuery | persistentReference | bounded explicit handling; malformed item fails before mutation |
| 67 | decode/addQuery | valuePersistentRef | bounded explicit handling; malformed item fails before mutation |
| 68 | decode/addQuery | valid wrapped data | bounded explicit handling; malformed item fails before mutation |
| 69 | decode/addQuery | missing base64 | bounded explicit handling; malformed item fails before mutation |
| 70 | decode/addQuery | wrong base64 type | bounded explicit handling; malformed item fails before mutation |
| 71 | decode/addQuery | invalid base64 | bounded explicit handling; malformed item fails before mutation |
| 72 | decode/addQuery | valid integer date | bounded explicit handling; malformed item fails before mutation |
| 73 | decode/addQuery | valid floating date | bounded explicit handling; malformed item fails before mutation |
| 74 | decode/addQuery | Boolean timestamp | bounded explicit handling; malformed item fails before mutation |
| 75 | decode/addQuery | NaN timestamp | bounded explicit handling; malformed item fails before mutation |
| 76 | decode/addQuery | infinite timestamp | bounded explicit handling; malformed item fails before mutation |
| 77 | decode/addQuery | wrong _type type | bounded explicit handling; malformed item fails before mutation |
| 78 | decode/addQuery | unknown wrapper | bounded explicit handling; malformed item fails before mutation |
| 79 | decode/addQuery | ordinary dictionary value | bounded explicit handling; malformed item fails before mutation |
| 80 | decode/addQuery | nil decoded value | bounded explicit handling; malformed item fails before mutation |
| 81 | decode/addQuery | indexing exception | bounded explicit handling; malformed item fails before mutation |
| 82 | add-first | GenericPassword; sync=absent; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 83 | add-first | GenericPassword; sync=absent; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 84 | add-first | GenericPassword; sync=absent; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 85 | add-first | GenericPassword; sync=absent; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 86 | add-first | GenericPassword; sync=absent; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 87 | add-first | GenericPassword; sync=absent; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 88 | add-first | GenericPassword; sync=absent; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 89 | add-first | GenericPassword; sync=absent; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 90 | add-first | GenericPassword; sync=absent; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 91 | add-first | GenericPassword; sync=absent; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 92 | add-first | GenericPassword; sync=absent; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 93 | add-first | GenericPassword; sync=absent; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 94 | add-first | GenericPassword; sync=false; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 95 | add-first | GenericPassword; sync=false; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 96 | add-first | GenericPassword; sync=false; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 97 | add-first | GenericPassword; sync=false; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 98 | add-first | GenericPassword; sync=false; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 99 | add-first | GenericPassword; sync=false; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 100 | add-first | GenericPassword; sync=false; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 101 | add-first | GenericPassword; sync=false; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 102 | add-first | GenericPassword; sync=false; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 103 | add-first | GenericPassword; sync=false; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 104 | add-first | GenericPassword; sync=false; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 105 | add-first | GenericPassword; sync=false; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 106 | add-first | GenericPassword; sync=true; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 107 | add-first | GenericPassword; sync=true; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 108 | add-first | GenericPassword; sync=true; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 109 | add-first | GenericPassword; sync=true; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 110 | add-first | GenericPassword; sync=true; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 111 | add-first | GenericPassword; sync=true; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 112 | add-first | GenericPassword; sync=true; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 113 | add-first | GenericPassword; sync=true; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 114 | add-first | GenericPassword; sync=true; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 115 | add-first | GenericPassword; sync=true; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 116 | add-first | GenericPassword; sync=true; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 117 | add-first | GenericPassword; sync=true; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 118 | add-first | InternetPassword; sync=absent; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 119 | add-first | InternetPassword; sync=absent; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 120 | add-first | InternetPassword; sync=absent; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 121 | add-first | InternetPassword; sync=absent; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 122 | add-first | InternetPassword; sync=absent; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 123 | add-first | InternetPassword; sync=absent; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 124 | add-first | InternetPassword; sync=absent; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 125 | add-first | InternetPassword; sync=absent; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 126 | add-first | InternetPassword; sync=absent; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 127 | add-first | InternetPassword; sync=absent; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 128 | add-first | InternetPassword; sync=absent; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 129 | add-first | InternetPassword; sync=absent; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 130 | add-first | InternetPassword; sync=false; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 131 | add-first | InternetPassword; sync=false; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 132 | add-first | InternetPassword; sync=false; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 133 | add-first | InternetPassword; sync=false; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 134 | add-first | InternetPassword; sync=false; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 135 | add-first | InternetPassword; sync=false; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 136 | add-first | InternetPassword; sync=false; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 137 | add-first | InternetPassword; sync=false; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 138 | add-first | InternetPassword; sync=false; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 139 | add-first | InternetPassword; sync=false; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 140 | add-first | InternetPassword; sync=false; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 141 | add-first | InternetPassword; sync=false; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 142 | add-first | InternetPassword; sync=true; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 143 | add-first | InternetPassword; sync=true; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 144 | add-first | InternetPassword; sync=true; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 145 | add-first | InternetPassword; sync=true; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 146 | add-first | InternetPassword; sync=true; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 147 | add-first | InternetPassword; sync=true; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 148 | add-first | InternetPassword; sync=true; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 149 | add-first | InternetPassword; sync=true; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 150 | add-first | InternetPassword; sync=true; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 151 | add-first | InternetPassword; sync=true; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 152 | add-first | InternetPassword; sync=true; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 153 | add-first | InternetPassword; sync=true; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 154 | add-first | Certificate; sync=absent; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 155 | add-first | Certificate; sync=absent; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 156 | add-first | Certificate; sync=absent; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 157 | add-first | Certificate; sync=absent; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 158 | add-first | Certificate; sync=absent; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 159 | add-first | Certificate; sync=absent; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 160 | add-first | Certificate; sync=absent; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 161 | add-first | Certificate; sync=absent; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 162 | add-first | Certificate; sync=absent; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 163 | add-first | Certificate; sync=absent; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 164 | add-first | Certificate; sync=absent; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 165 | add-first | Certificate; sync=absent; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 166 | add-first | Certificate; sync=false; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 167 | add-first | Certificate; sync=false; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 168 | add-first | Certificate; sync=false; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 169 | add-first | Certificate; sync=false; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 170 | add-first | Certificate; sync=false; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 171 | add-first | Certificate; sync=false; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 172 | add-first | Certificate; sync=false; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 173 | add-first | Certificate; sync=false; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 174 | add-first | Certificate; sync=false; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 175 | add-first | Certificate; sync=false; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 176 | add-first | Certificate; sync=false; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 177 | add-first | Certificate; sync=false; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 178 | add-first | Certificate; sync=true; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 179 | add-first | Certificate; sync=true; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 180 | add-first | Certificate; sync=true; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 181 | add-first | Certificate; sync=true; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 182 | add-first | Certificate; sync=true; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 183 | add-first | Certificate; sync=true; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 184 | add-first | Certificate; sync=true; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 185 | add-first | Certificate; sync=true; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 186 | add-first | Certificate; sync=true; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 187 | add-first | Certificate; sync=true; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 188 | add-first | Certificate; sync=true; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 189 | add-first | Certificate; sync=true; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 190 | add-first | Key; sync=absent; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 191 | add-first | Key; sync=absent; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 192 | add-first | Key; sync=absent; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 193 | add-first | Key; sync=absent; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 194 | add-first | Key; sync=absent; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 195 | add-first | Key; sync=absent; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 196 | add-first | Key; sync=absent; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 197 | add-first | Key; sync=absent; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 198 | add-first | Key; sync=absent; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 199 | add-first | Key; sync=absent; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 200 | add-first | Key; sync=absent; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 201 | add-first | Key; sync=absent; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 202 | add-first | Key; sync=false; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 203 | add-first | Key; sync=false; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 204 | add-first | Key; sync=false; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 205 | add-first | Key; sync=false; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 206 | add-first | Key; sync=false; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 207 | add-first | Key; sync=false; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 208 | add-first | Key; sync=false; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 209 | add-first | Key; sync=false; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 210 | add-first | Key; sync=false; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 211 | add-first | Key; sync=false; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 212 | add-first | Key; sync=false; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 213 | add-first | Key; sync=false; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 214 | add-first | Key; sync=true; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 215 | add-first | Key; sync=true; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 216 | add-first | Key; sync=true; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 217 | add-first | Key; sync=true; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 218 | add-first | Key; sync=true; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 219 | add-first | Key; sync=true; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 220 | add-first | Key; sync=true; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 221 | add-first | Key; sync=true; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 222 | add-first | Key; sync=true; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 223 | add-first | Key; sync=true; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 224 | add-first | Key; sync=true; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 225 | add-first | Key; sync=true; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 226 | add-first | Identity; sync=absent; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 227 | add-first | Identity; sync=absent; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 228 | add-first | Identity; sync=absent; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 229 | add-first | Identity; sync=absent; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 230 | add-first | Identity; sync=absent; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 231 | add-first | Identity; sync=absent; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 232 | add-first | Identity; sync=absent; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 233 | add-first | Identity; sync=absent; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 234 | add-first | Identity; sync=absent; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 235 | add-first | Identity; sync=absent; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 236 | add-first | Identity; sync=absent; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 237 | add-first | Identity; sync=absent; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 238 | add-first | Identity; sync=false; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 239 | add-first | Identity; sync=false; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 240 | add-first | Identity; sync=false; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 241 | add-first | Identity; sync=false; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 242 | add-first | Identity; sync=false; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 243 | add-first | Identity; sync=false; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 244 | add-first | Identity; sync=false; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 245 | add-first | Identity; sync=false; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 246 | add-first | Identity; sync=false; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 247 | add-first | Identity; sync=false; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 248 | add-first | Identity; sync=false; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 249 | add-first | Identity; sync=false; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 250 | add-first | Identity; sync=true; overwrite=NO; errSecSuccess | success; add only; zero delete |
| 251 | add-first | Identity; sync=true; overwrite=NO; errSecDuplicateItem | preserve; failed+warning; no identity/lookup/update; zero delete |
| 252 | add-first | Identity; sync=true; overwrite=NO; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 253 | add-first | Identity; sync=true; overwrite=NO; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 254 | add-first | Identity; sync=true; overwrite=NO; errSecParam | failed error; no identity/lookup/update; zero delete |
| 255 | add-first | Identity; sync=true; overwrite=NO; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 256 | add-first | Identity; sync=true; overwrite=YES; errSecSuccess | success; add only; zero delete |
| 257 | add-first | Identity; sync=true; overwrite=YES; errSecDuplicateItem | identity then exact lookup/update; zero delete |
| 258 | add-first | Identity; sync=true; overwrite=YES; errSecAuthFailed | failed error; no identity/lookup/update; zero delete |
| 259 | add-first | Identity; sync=true; overwrite=YES; errSecInteractionNotAllowed | failed error; no identity/lookup/update; zero delete |
| 260 | add-first | Identity; sync=true; overwrite=YES; errSecParam | failed error; no identity/lookup/update; zero delete |
| 261 | add-first | Identity; sync=true; overwrite=YES; unexpected OSStatus | failed error; no identity/lookup/update; zero delete |
| 262 | identity | GenericPassword: complete tuple | identity success only after duplicate+YES |
| 263 | identity | GenericPassword: missing access group | fail before lookup |
| 264 | identity | GenericPassword: invalid access group | fail before lookup |
| 265 | identity | GenericPassword: invalid synchronizable | fail before lookup |
| 266 | identity | GenericPassword.account: missing | specific identity failure; no fallback/lookup/update/delete |
| 267 | identity | GenericPassword.account: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 268 | identity | GenericPassword.account: oversized | specific identity failure; no fallback/lookup/update/delete |
| 269 | identity | GenericPassword.service: missing | specific identity failure; no fallback/lookup/update/delete |
| 270 | identity | GenericPassword.service: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 271 | identity | GenericPassword.service: oversized | specific identity failure; no fallback/lookup/update/delete |
| 272 | identity | InternetPassword: complete tuple | identity success only after duplicate+YES |
| 273 | identity | InternetPassword: missing access group | fail before lookup |
| 274 | identity | InternetPassword: invalid access group | fail before lookup |
| 275 | identity | InternetPassword: invalid synchronizable | fail before lookup |
| 276 | identity | InternetPassword.account: missing | specific identity failure; no fallback/lookup/update/delete |
| 277 | identity | InternetPassword.account: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 278 | identity | InternetPassword.account: oversized | specific identity failure; no fallback/lookup/update/delete |
| 279 | identity | InternetPassword.server: missing | specific identity failure; no fallback/lookup/update/delete |
| 280 | identity | InternetPassword.server: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 281 | identity | InternetPassword.server: oversized | specific identity failure; no fallback/lookup/update/delete |
| 282 | identity | InternetPassword.port: missing | specific identity failure; no fallback/lookup/update/delete |
| 283 | identity | InternetPassword.port: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 284 | identity | InternetPassword.port: oversized | specific identity failure; no fallback/lookup/update/delete |
| 285 | identity | InternetPassword.protocol: missing | specific identity failure; no fallback/lookup/update/delete |
| 286 | identity | InternetPassword.protocol: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 287 | identity | InternetPassword.protocol: oversized | specific identity failure; no fallback/lookup/update/delete |
| 288 | identity | InternetPassword.authenticationType: missing | specific identity failure; no fallback/lookup/update/delete |
| 289 | identity | InternetPassword.authenticationType: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 290 | identity | InternetPassword.authenticationType: oversized | specific identity failure; no fallback/lookup/update/delete |
| 291 | identity | InternetPassword.path: missing | specific identity failure; no fallback/lookup/update/delete |
| 292 | identity | InternetPassword.path: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 293 | identity | InternetPassword.path: oversized | specific identity failure; no fallback/lookup/update/delete |
| 294 | identity | InternetPassword.securityDomain: missing | specific identity failure; no fallback/lookup/update/delete |
| 295 | identity | InternetPassword.securityDomain: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 296 | identity | InternetPassword.securityDomain: oversized | specific identity failure; no fallback/lookup/update/delete |
| 297 | identity | Certificate: complete tuple | identity success only after duplicate+YES |
| 298 | identity | Certificate: missing access group | fail before lookup |
| 299 | identity | Certificate: invalid access group | fail before lookup |
| 300 | identity | Certificate: invalid synchronizable | fail before lookup |
| 301 | identity | Certificate.issuer: missing | specific identity failure; no fallback/lookup/update/delete |
| 302 | identity | Certificate.issuer: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 303 | identity | Certificate.issuer: oversized | specific identity failure; no fallback/lookup/update/delete |
| 304 | identity | Certificate.serialNumber: missing | specific identity failure; no fallback/lookup/update/delete |
| 305 | identity | Certificate.serialNumber: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 306 | identity | Certificate.serialNumber: oversized | specific identity failure; no fallback/lookup/update/delete |
| 307 | identity | Key: complete tuple | identity success only after duplicate+YES |
| 308 | identity | Key: missing access group | fail before lookup |
| 309 | identity | Key: invalid access group | fail before lookup |
| 310 | identity | Key: invalid synchronizable | fail before lookup |
| 311 | identity | Key.applicationLabel: missing | specific identity failure; no fallback/lookup/update/delete |
| 312 | identity | Key.applicationLabel: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 313 | identity | Key.applicationLabel: oversized | specific identity failure; no fallback/lookup/update/delete |
| 314 | identity | Key.keyClass: missing | specific identity failure; no fallback/lookup/update/delete |
| 315 | identity | Key.keyClass: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 316 | identity | Key.keyClass: oversized | specific identity failure; no fallback/lookup/update/delete |
| 317 | identity | Key.keyType: missing | specific identity failure; no fallback/lookup/update/delete |
| 318 | identity | Key.keyType: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 319 | identity | Key.keyType: oversized | specific identity failure; no fallback/lookup/update/delete |
| 320 | identity | Identity: complete tuple | identity success only after duplicate+YES |
| 321 | identity | Identity: missing access group | fail before lookup |
| 322 | identity | Identity: invalid access group | fail before lookup |
| 323 | identity | Identity: invalid synchronizable | fail before lookup |
| 324 | identity | Identity.applicationLabel: missing | specific identity failure; no fallback/lookup/update/delete |
| 325 | identity | Identity.applicationLabel: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 326 | identity | Identity.applicationLabel: oversized | specific identity failure; no fallback/lookup/update/delete |
| 327 | identity | Identity.issuer: missing | specific identity failure; no fallback/lookup/update/delete |
| 328 | identity | Identity.issuer: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 329 | identity | Identity.issuer: oversized | specific identity failure; no fallback/lookup/update/delete |
| 330 | identity | Identity.serialNumber: missing | specific identity failure; no fallback/lookup/update/delete |
| 331 | identity | Identity.serialNumber: wrong type | specific identity failure; no fallback/lookup/update/delete |
| 332 | identity | Identity.serialNumber: oversized | specific identity failure; no fallback/lookup/update/delete |
| 333 | identity | ambiguous certificate | generic bounded code-only diagnostic |
| 334 | identity | ambiguous key | generic bounded code-only diagnostic |
| 335 | identity | ambiguous identity | generic bounded code-only diagnostic |
| 336 | identity | fractional port | generic bounded code-only diagnostic |
| 337 | identity | negative port | generic bounded code-only diagnostic |
| 338 | identity | oversized port | generic bounded code-only diagnostic |
| 339 | identity | Boolean port | generic bounded code-only diagnostic |
| 340 | identity | factory exception | generic bounded code-only diagnostic |
| 341 | identity | sentinel-bearing NSError | generic bounded code-only diagnostic |
| 342 | lookup cardinality | GenericPassword: success + one NSData | snapshot and proceed |
| 343 | lookup cardinality | GenericPassword: success + one mutable NSData | snapshot and proceed |
| 344 | lookup cardinality | GenericPassword: success + array one NSData | snapshot and proceed |
| 345 | lookup cardinality | GenericPassword: success + nil | fail closed; zero update/delete/fallback |
| 346 | lookup cardinality | GenericPassword: success + empty array | fail closed; zero update/delete/fallback |
| 347 | lookup cardinality | GenericPassword: success + array two NSData | fail closed; zero update/delete/fallback |
| 348 | lookup cardinality | GenericPassword: success + wrong root string | fail closed; zero update/delete/fallback |
| 349 | lookup cardinality | GenericPassword: success + wrong root dictionary | fail closed; zero update/delete/fallback |
| 350 | lookup cardinality | GenericPassword: success + wrong element | fail closed; zero update/delete/fallback |
| 351 | lookup cardinality | GenericPassword: success + empty NSData | fail closed; zero update/delete/fallback |
| 352 | lookup cardinality | GenericPassword: success + snapshot failure | fail closed; zero update/delete/fallback |
| 353 | lookup cardinality | GenericPassword: success + exception | fail closed; zero update/delete/fallback |
| 354 | lookup cardinality | InternetPassword: success + one NSData | snapshot and proceed |
| 355 | lookup cardinality | InternetPassword: success + one mutable NSData | snapshot and proceed |
| 356 | lookup cardinality | InternetPassword: success + array one NSData | snapshot and proceed |
| 357 | lookup cardinality | InternetPassword: success + nil | fail closed; zero update/delete/fallback |
| 358 | lookup cardinality | InternetPassword: success + empty array | fail closed; zero update/delete/fallback |
| 359 | lookup cardinality | InternetPassword: success + array two NSData | fail closed; zero update/delete/fallback |
| 360 | lookup cardinality | InternetPassword: success + wrong root string | fail closed; zero update/delete/fallback |
| 361 | lookup cardinality | InternetPassword: success + wrong root dictionary | fail closed; zero update/delete/fallback |
| 362 | lookup cardinality | InternetPassword: success + wrong element | fail closed; zero update/delete/fallback |
| 363 | lookup cardinality | InternetPassword: success + empty NSData | fail closed; zero update/delete/fallback |
| 364 | lookup cardinality | InternetPassword: success + snapshot failure | fail closed; zero update/delete/fallback |
| 365 | lookup cardinality | InternetPassword: success + exception | fail closed; zero update/delete/fallback |
| 366 | lookup cardinality | Certificate: success + one NSData | snapshot and proceed |
| 367 | lookup cardinality | Certificate: success + one mutable NSData | snapshot and proceed |
| 368 | lookup cardinality | Certificate: success + array one NSData | snapshot and proceed |
| 369 | lookup cardinality | Certificate: success + nil | fail closed; zero update/delete/fallback |
| 370 | lookup cardinality | Certificate: success + empty array | fail closed; zero update/delete/fallback |
| 371 | lookup cardinality | Certificate: success + array two NSData | fail closed; zero update/delete/fallback |
| 372 | lookup cardinality | Certificate: success + wrong root string | fail closed; zero update/delete/fallback |
| 373 | lookup cardinality | Certificate: success + wrong root dictionary | fail closed; zero update/delete/fallback |
| 374 | lookup cardinality | Certificate: success + wrong element | fail closed; zero update/delete/fallback |
| 375 | lookup cardinality | Certificate: success + empty NSData | fail closed; zero update/delete/fallback |
| 376 | lookup cardinality | Certificate: success + snapshot failure | fail closed; zero update/delete/fallback |
| 377 | lookup cardinality | Certificate: success + exception | fail closed; zero update/delete/fallback |
| 378 | lookup cardinality | Key: success + one NSData | snapshot and proceed |
| 379 | lookup cardinality | Key: success + one mutable NSData | snapshot and proceed |
| 380 | lookup cardinality | Key: success + array one NSData | snapshot and proceed |
| 381 | lookup cardinality | Key: success + nil | fail closed; zero update/delete/fallback |
| 382 | lookup cardinality | Key: success + empty array | fail closed; zero update/delete/fallback |
| 383 | lookup cardinality | Key: success + array two NSData | fail closed; zero update/delete/fallback |
| 384 | lookup cardinality | Key: success + wrong root string | fail closed; zero update/delete/fallback |
| 385 | lookup cardinality | Key: success + wrong root dictionary | fail closed; zero update/delete/fallback |
| 386 | lookup cardinality | Key: success + wrong element | fail closed; zero update/delete/fallback |
| 387 | lookup cardinality | Key: success + empty NSData | fail closed; zero update/delete/fallback |
| 388 | lookup cardinality | Key: success + snapshot failure | fail closed; zero update/delete/fallback |
| 389 | lookup cardinality | Key: success + exception | fail closed; zero update/delete/fallback |
| 390 | lookup cardinality | Identity: success + one NSData | snapshot and proceed |
| 391 | lookup cardinality | Identity: success + one mutable NSData | snapshot and proceed |
| 392 | lookup cardinality | Identity: success + array one NSData | snapshot and proceed |
| 393 | lookup cardinality | Identity: success + nil | fail closed; zero update/delete/fallback |
| 394 | lookup cardinality | Identity: success + empty array | fail closed; zero update/delete/fallback |
| 395 | lookup cardinality | Identity: success + array two NSData | fail closed; zero update/delete/fallback |
| 396 | lookup cardinality | Identity: success + wrong root string | fail closed; zero update/delete/fallback |
| 397 | lookup cardinality | Identity: success + wrong root dictionary | fail closed; zero update/delete/fallback |
| 398 | lookup cardinality | Identity: success + wrong element | fail closed; zero update/delete/fallback |
| 399 | lookup cardinality | Identity: success + empty NSData | fail closed; zero update/delete/fallback |
| 400 | lookup cardinality | Identity: success + snapshot failure | fail closed; zero update/delete/fallback |
| 401 | lookup cardinality | Identity: success + exception | fail closed; zero update/delete/fallback |
| 402 | lookup status | GenericPassword: errSecItemNotFound | fail; no retry/update/delete |
| 403 | lookup status | GenericPassword: errSecAuthFailed | fail; no retry/update/delete |
| 404 | lookup status | GenericPassword: errSecInteractionNotAllowed | fail; no retry/update/delete |
| 405 | lookup status | GenericPassword: errSecUserCanceled | fail; no retry/update/delete |
| 406 | lookup status | GenericPassword: errSecParam | fail; no retry/update/delete |
| 407 | lookup status | GenericPassword: unexpected | fail; no retry/update/delete |
| 408 | lookup status | InternetPassword: errSecItemNotFound | fail; no retry/update/delete |
| 409 | lookup status | InternetPassword: errSecAuthFailed | fail; no retry/update/delete |
| 410 | lookup status | InternetPassword: errSecInteractionNotAllowed | fail; no retry/update/delete |
| 411 | lookup status | InternetPassword: errSecUserCanceled | fail; no retry/update/delete |
| 412 | lookup status | InternetPassword: errSecParam | fail; no retry/update/delete |
| 413 | lookup status | InternetPassword: unexpected | fail; no retry/update/delete |
| 414 | lookup status | Certificate: errSecItemNotFound | fail; no retry/update/delete |
| 415 | lookup status | Certificate: errSecAuthFailed | fail; no retry/update/delete |
| 416 | lookup status | Certificate: errSecInteractionNotAllowed | fail; no retry/update/delete |
| 417 | lookup status | Certificate: errSecUserCanceled | fail; no retry/update/delete |
| 418 | lookup status | Certificate: errSecParam | fail; no retry/update/delete |
| 419 | lookup status | Certificate: unexpected | fail; no retry/update/delete |
| 420 | lookup status | Key: errSecItemNotFound | fail; no retry/update/delete |
| 421 | lookup status | Key: errSecAuthFailed | fail; no retry/update/delete |
| 422 | lookup status | Key: errSecInteractionNotAllowed | fail; no retry/update/delete |
| 423 | lookup status | Key: errSecUserCanceled | fail; no retry/update/delete |
| 424 | lookup status | Key: errSecParam | fail; no retry/update/delete |
| 425 | lookup status | Key: unexpected | fail; no retry/update/delete |
| 426 | lookup status | Identity: errSecItemNotFound | fail; no retry/update/delete |
| 427 | lookup status | Identity: errSecAuthFailed | fail; no retry/update/delete |
| 428 | lookup status | Identity: errSecInteractionNotAllowed | fail; no retry/update/delete |
| 429 | lookup status | Identity: errSecUserCanceled | fail; no retry/update/delete |
| 430 | lookup status | Identity: errSecParam | fail; no retry/update/delete |
| 431 | lookup status | Identity: unexpected | fail; no retry/update/delete |
| 432 | lookup query | identity.matchQuery | present |
| 433 | lookup query | exact @NO | present |
| 434 | lookup query | exact @YES | present |
| 435 | lookup query | matchLimitAll | present |
| 436 | lookup query | returnPersistentRef YES | present |
| 437 | lookup query | authenticationUIFail | present |
| 438 | lookup forbidden | synchronizableAny | absent |
| 439 | lookup forbidden | returnData | absent |
| 440 | lookup forbidden | returnRef | absent |
| 441 | lookup forbidden | valueData | absent |
| 442 | lookup forbidden | valueRef | absent |
| 443 | lookup forbidden | label fallback | absent |
| 444 | lookup forbidden | applicationTag fallback | absent |
| 445 | lookup forbidden | publicKeyHash fallback | absent |
| 446 | lookup forbidden | subject fallback | absent |
| 447 | lookup forbidden | keySize fallback | absent |
| 448 | update filter | GenericPassword: class | removed |
| 449 | update filter | GenericPassword: accessGroup | removed |
| 450 | update filter | GenericPassword: synchronizable | removed |
| 451 | update filter | GenericPassword: accessControl | removed |
| 452 | update filter | GenericPassword: creationDate | removed |
| 453 | update filter | GenericPassword: modificationDate | removed |
| 454 | update filter | GenericPassword: persistentReference | removed |
| 455 | update filter | GenericPassword: matchLimit | removed |
| 456 | update filter | GenericPassword: returnAttributes | removed |
| 457 | update filter | GenericPassword: returnData | removed |
| 458 | update filter | GenericPassword: returnRef | removed |
| 459 | update filter | GenericPassword: returnPersistentRef | removed |
| 460 | update filter | GenericPassword: authenticationUI | removed |
| 461 | update filter | GenericPassword: operationPrompt | removed |
| 462 | update filter | GenericPassword: valueRef | removed |
| 463 | update filter | GenericPassword: valuePersistentRef | removed |
| 464 | update filter | InternetPassword: class | removed |
| 465 | update filter | InternetPassword: accessGroup | removed |
| 466 | update filter | InternetPassword: synchronizable | removed |
| 467 | update filter | InternetPassword: accessControl | removed |
| 468 | update filter | InternetPassword: creationDate | removed |
| 469 | update filter | InternetPassword: modificationDate | removed |
| 470 | update filter | InternetPassword: persistentReference | removed |
| 471 | update filter | InternetPassword: matchLimit | removed |
| 472 | update filter | InternetPassword: returnAttributes | removed |
| 473 | update filter | InternetPassword: returnData | removed |
| 474 | update filter | InternetPassword: returnRef | removed |
| 475 | update filter | InternetPassword: returnPersistentRef | removed |
| 476 | update filter | InternetPassword: authenticationUI | removed |
| 477 | update filter | InternetPassword: operationPrompt | removed |
| 478 | update filter | InternetPassword: valueRef | removed |
| 479 | update filter | InternetPassword: valuePersistentRef | removed |
| 480 | update filter | Certificate: class | removed |
| 481 | update filter | Certificate: accessGroup | removed |
| 482 | update filter | Certificate: synchronizable | removed |
| 483 | update filter | Certificate: accessControl | removed |
| 484 | update filter | Certificate: creationDate | removed |
| 485 | update filter | Certificate: modificationDate | removed |
| 486 | update filter | Certificate: persistentReference | removed |
| 487 | update filter | Certificate: matchLimit | removed |
| 488 | update filter | Certificate: returnAttributes | removed |
| 489 | update filter | Certificate: returnData | removed |
| 490 | update filter | Certificate: returnRef | removed |
| 491 | update filter | Certificate: returnPersistentRef | removed |
| 492 | update filter | Certificate: authenticationUI | removed |
| 493 | update filter | Certificate: operationPrompt | removed |
| 494 | update filter | Certificate: valueRef | removed |
| 495 | update filter | Certificate: valuePersistentRef | removed |
| 496 | update filter | Key: class | removed |
| 497 | update filter | Key: accessGroup | removed |
| 498 | update filter | Key: synchronizable | removed |
| 499 | update filter | Key: accessControl | removed |
| 500 | update filter | Key: creationDate | removed |
| 501 | update filter | Key: modificationDate | removed |
| 502 | update filter | Key: persistentReference | removed |
| 503 | update filter | Key: matchLimit | removed |
| 504 | update filter | Key: returnAttributes | removed |
| 505 | update filter | Key: returnData | removed |
| 506 | update filter | Key: returnRef | removed |
| 507 | update filter | Key: returnPersistentRef | removed |
| 508 | update filter | Key: authenticationUI | removed |
| 509 | update filter | Key: operationPrompt | removed |
| 510 | update filter | Key: valueRef | removed |
| 511 | update filter | Key: valuePersistentRef | removed |
| 512 | update filter | Identity: class | removed |
| 513 | update filter | Identity: accessGroup | removed |
| 514 | update filter | Identity: synchronizable | removed |
| 515 | update filter | Identity: accessControl | removed |
| 516 | update filter | Identity: creationDate | removed |
| 517 | update filter | Identity: modificationDate | removed |
| 518 | update filter | Identity: persistentReference | removed |
| 519 | update filter | Identity: matchLimit | removed |
| 520 | update filter | Identity: returnAttributes | removed |
| 521 | update filter | Identity: returnData | removed |
| 522 | update filter | Identity: returnRef | removed |
| 523 | update filter | Identity: returnPersistentRef | removed |
| 524 | update filter | Identity: authenticationUI | removed |
| 525 | update filter | Identity: operationPrompt | removed |
| 526 | update filter | Identity: valueRef | removed |
| 527 | update filter | Identity: valuePersistentRef | removed |
| 528 | identity exclusion | GenericPassword: account | removed; identity immutable |
| 529 | identity exclusion | GenericPassword: service | removed; identity immutable |
| 530 | update payload | GenericPassword: valueData | retained |
| 531 | update payload | GenericPassword: nonidentity mutable attr | retained or Security fails closed |
| 532 | update payload | GenericPassword: empty filtered payload | success without update/warning/error |
| 533 | identity exclusion | InternetPassword: account | removed; identity immutable |
| 534 | identity exclusion | InternetPassword: server | removed; identity immutable |
| 535 | identity exclusion | InternetPassword: port | removed; identity immutable |
| 536 | identity exclusion | InternetPassword: protocol | removed; identity immutable |
| 537 | identity exclusion | InternetPassword: authenticationType | removed; identity immutable |
| 538 | identity exclusion | InternetPassword: path | removed; identity immutable |
| 539 | identity exclusion | InternetPassword: securityDomain | removed; identity immutable |
| 540 | update payload | InternetPassword: valueData | retained |
| 541 | update payload | InternetPassword: nonidentity mutable attr | retained or Security fails closed |
| 542 | update payload | InternetPassword: empty filtered payload | success without update/warning/error |
| 543 | identity exclusion | Certificate: issuer | removed; identity immutable |
| 544 | identity exclusion | Certificate: serialNumber | removed; identity immutable |
| 545 | update payload | Certificate: valueData | retained |
| 546 | update payload | Certificate: nonidentity mutable attr | retained or Security fails closed |
| 547 | update payload | Certificate: empty filtered payload | success without update/warning/error |
| 548 | identity exclusion | Key: applicationLabel | removed; identity immutable |
| 549 | identity exclusion | Key: keyClass | removed; identity immutable |
| 550 | identity exclusion | Key: keyType | removed; identity immutable |
| 551 | update payload | Key: valueData | retained |
| 552 | update payload | Key: nonidentity mutable attr | retained or Security fails closed |
| 553 | update payload | Key: empty filtered payload | success without update/warning/error |
| 554 | identity exclusion | Identity: applicationLabel | removed; identity immutable |
| 555 | identity exclusion | Identity: issuer | removed; identity immutable |
| 556 | identity exclusion | Identity: serialNumber | removed; identity immutable |
| 557 | update payload | Identity: valueData | retained |
| 558 | update payload | Identity: nonidentity mutable attr | retained or Security fails closed |
| 559 | update payload | Identity: empty filtered payload | success without update/warning/error |
| 560 | update result | GenericPassword: success | success |
| 561 | update result | GenericPassword: item not found | failed; no retry/delete/rollback |
| 562 | update result | GenericPassword: duplicate | failed; no retry/delete/rollback |
| 563 | update result | GenericPassword: auth failed | failed; no retry/delete/rollback |
| 564 | update result | GenericPassword: interaction denied | failed; no retry/delete/rollback |
| 565 | update result | GenericPassword: user canceled | failed; no retry/delete/rollback |
| 566 | update result | GenericPassword: param | failed; no retry/delete/rollback |
| 567 | update result | GenericPassword: unexpected | failed; no retry/delete/rollback |
| 568 | update result | InternetPassword: success | success |
| 569 | update result | InternetPassword: item not found | failed; no retry/delete/rollback |
| 570 | update result | InternetPassword: duplicate | failed; no retry/delete/rollback |
| 571 | update result | InternetPassword: auth failed | failed; no retry/delete/rollback |
| 572 | update result | InternetPassword: interaction denied | failed; no retry/delete/rollback |
| 573 | update result | InternetPassword: user canceled | failed; no retry/delete/rollback |
| 574 | update result | InternetPassword: param | failed; no retry/delete/rollback |
| 575 | update result | InternetPassword: unexpected | failed; no retry/delete/rollback |
| 576 | update result | Certificate: success | success |
| 577 | update result | Certificate: item not found | failed; no retry/delete/rollback |
| 578 | update result | Certificate: duplicate | failed; no retry/delete/rollback |
| 579 | update result | Certificate: auth failed | failed; no retry/delete/rollback |
| 580 | update result | Certificate: interaction denied | failed; no retry/delete/rollback |
| 581 | update result | Certificate: user canceled | failed; no retry/delete/rollback |
| 582 | update result | Certificate: param | failed; no retry/delete/rollback |
| 583 | update result | Certificate: unexpected | failed; no retry/delete/rollback |
| 584 | update result | Key: success | success |
| 585 | update result | Key: item not found | failed; no retry/delete/rollback |
| 586 | update result | Key: duplicate | failed; no retry/delete/rollback |
| 587 | update result | Key: auth failed | failed; no retry/delete/rollback |
| 588 | update result | Key: interaction denied | failed; no retry/delete/rollback |
| 589 | update result | Key: user canceled | failed; no retry/delete/rollback |
| 590 | update result | Key: param | failed; no retry/delete/rollback |
| 591 | update result | Key: unexpected | failed; no retry/delete/rollback |
| 592 | update result | Identity: success | success |
| 593 | update result | Identity: item not found | failed; no retry/delete/rollback |
| 594 | update result | Identity: duplicate | failed; no retry/delete/rollback |
| 595 | update result | Identity: auth failed | failed; no retry/delete/rollback |
| 596 | update result | Identity: interaction denied | failed; no retry/delete/rollback |
| 597 | update result | Identity: user canceled | failed; no retry/delete/rollback |
| 598 | update result | Identity: param | failed; no retry/delete/rollback |
| 599 | update result | Identity: unexpected | failed; no retry/delete/rollback |
| 600 | race | item disappears | preserve no-delete semantics and terminate once |
| 601 | race | persistent ref invalid | preserve no-delete semantics and terminate once |
| 602 | race | update duplicate conflict | preserve no-delete semantics and terminate once |
| 603 | race | auth-protected item | preserve no-delete semantics and terminate once |
| 604 | race | interaction required | preserve no-delete semantics and terminate once |
| 605 | race | class rejects payload | preserve no-delete semantics and terminate once |
| 606 | race | filter failure | preserve no-delete semantics and terminate once |
| 607 | race | empty payload | preserve no-delete semantics and terminate once |
| 608 | counter | new success | processed once; exactly one success/failed |
| 609 | counter | duplicate NO | processed once; exactly one success/failed |
| 610 | counter | identity fail | processed once; exactly one success/failed |
| 611 | counter | lookup fail | processed once; exactly one success/failed |
| 612 | counter | empty payload | processed once; exactly one success/failed |
| 613 | counter | update success | processed once; exactly one success/failed |
| 614 | counter | update fail | processed once; exactly one success/failed |
| 615 | counter | add fail | processed once; exactly one success/failed |
| 616 | counter aggregate | 1 | processed == succeeded + failed |
| 617 | counter aggregate | 2 | processed == succeeded + failed |
| 618 | counter aggregate | 3 | processed == succeeded + failed |
| 619 | counter aggregate | 10 | processed == succeeded + failed |
| 620 | counter aggregate | 100 | processed == succeeded + failed |
| 621 | counter aggregate | 1000 | processed == succeeded + failed |
| 622 | privacy | access group | absent from new diagnostics/logs |
| 623 | privacy | account | absent from new diagnostics/logs |
| 624 | privacy | service | absent from new diagnostics/logs |
| 625 | privacy | server | absent from new diagnostics/logs |
| 626 | privacy | path | absent from new diagnostics/logs |
| 627 | privacy | security domain | absent from new diagnostics/logs |
| 628 | privacy | protocol | absent from new diagnostics/logs |
| 629 | privacy | authentication type | absent from new diagnostics/logs |
| 630 | privacy | issuer | absent from new diagnostics/logs |
| 631 | privacy | serial | absent from new diagnostics/logs |
| 632 | privacy | application label | absent from new diagnostics/logs |
| 633 | privacy | key class | absent from new diagnostics/logs |
| 634 | privacy | key type | absent from new diagnostics/logs |
| 635 | privacy | value data | absent from new diagnostics/logs |
| 636 | privacy | persistent ref | absent from new diagnostics/logs |
| 637 | privacy | raw item | absent from new diagnostics/logs |
| 638 | privacy | exception text | absent from new diagnostics/logs |
| 639 | non-goal | restore delete | not implemented |
| 640 | non-goal | delete/add | not implemented |
| 641 | non-goal | rollback | not implemented |
| 642 | non-goal | old-value snapshot | not implemented |
| 643 | non-goal | retry add | not implemented |
| 644 | non-goal | retry lookup | not implemented |
| 645 | non-goal | fallback lookup | not implemented |
| 646 | non-goal | schema migration | not implemented |
| 647 | non-goal | workspace hardening | not implemented |
| 648 | non-goal | access-group report | not implemented |
| 649 | non-goal | manager parsing | not implemented |
| 650 | non-goal | bridge changes | not implemented |
| 651 | non-goal | UI | not implemented |
| 652 | non-goal | TASK-4.6 | not implemented |
| 653 | non-regression | TASK-4.1 schema | unchanged |
| 654 | non-regression | result key shape | unchanged |
| 655 | non-regression | emitter | unchanged |
| 656 | non-regression | TASK-4.2 finalizer | unchanged |
| 657 | non-regression | 16 finalizer calls | unchanged |
| 658 | non-regression | 13 exit constants | unchanged |
| 659 | non-regression | wrapper normalizer | unchanged |
| 660 | non-regression | 4 normalizer calls | unchanged |
| 661 | non-regression | TASK-4.3 zero delete | unchanged |
| 662 | non-regression | TASK-4.4 identity | unchanged |
| 663 | non-regression | Makefile entry | unchanged |
| 664 | non-regression | wipe sole delete | unchanged |

## Full authorized production diff
Report self-diff excluded; physical lines right-trimmed for report hygiene.
```diff
diff --git a/KeychainHelper/KeychainBackupHelper.h b/KeychainHelper/KeychainBackupHelper.h
index 02ee22f..f56a412 100644
--- a/KeychainHelper/KeychainBackupHelper.h
+++ b/KeychainHelper/KeychainBackupHelper.h
@@ -35,7 +35,7 @@ typedef NS_OPTIONS(NSUInteger, PXKeychainItemClass) {
 @end

 /// Helper class for keychain backup, restore, and wipe operations.
-/// Uses SecItem APIs (SecItemCopyMatching, SecItemAdd, SecItemDelete).
+/// Uses SecItem APIs (SecItemCopyMatching, SecItemAdd, SecItemUpdate, SecItemDelete).
 @interface KeychainBackupHelper : NSObject

 /// Backup all keychain items matching the specified access groups to a plist file.
@@ -51,9 +51,9 @@ typedef NS_OPTIONS(NSUInteger, PXKeychainItemClass) {

 /// Restore keychain items from a backup plist file.
 /// @param filePath The path to the backup plist file.
-/// @param overwrite Retained for compatibility. Restore never pre-deletes access-group/class contents.
-/// Duplicate existing items are preserved and reported as item failures.
-/// Safe replacement awaits future per-item identity/upsert support.
+/// @param overwrite If NO, new items are added and exact existing duplicates are preserved and reported as item failures.
+/// If YES, new items are added and an existing item is updated in place only after exact identity construction
+/// and unique target resolution. Restore never deletes an item and does not guarantee every duplicate can be updated.
 /// @param error On failure, contains the error information.
 /// @return Result object with statistics, or nil on critical failure.
 + (PXKeychainBackupResult *_Nullable)restoreKeychainFromFile:(NSString *)filePath
diff --git a/KeychainHelper/KeychainBackupHelper.m b/KeychainHelper/KeychainBackupHelper.m
index 1214da7..4b6697f 100644
--- a/KeychainHelper/KeychainBackupHelper.m
+++ b/KeychainHelper/KeychainBackupHelper.m
@@ -1,5 +1,8 @@
 #import "KeychainBackupHelper.h"
+#import "PXKeychainItemIdentity.h"
 #import <Security/Security.h>
+#import <CoreFoundation/CoreFoundation.h>
+#import <math.h>

 NSString * const PXKeychainBackupErrorDomain = @"com.hydra.projectx.keychain";

@@ -92,6 +95,382 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
     return excluded;
 }

+typedef NS_ENUM(NSInteger, PXRestoreItemOutcome) {
+    PXRestoreItemOutcomeSucceeded = 1,
+    PXRestoreItemOutcomeFailedWarning = 2,
+    PXRestoreItemOutcomeFailedError = 3,
+};
+
+static BOOL PXRestoreValueIsExactString(id value) {
+    return [value isKindOfClass:[NSString class]] &&
+           CFGetTypeID((__bridge CFTypeRef)value) == CFStringGetTypeID();
+}
+
+static BOOL PXRestoreValueIsExactData(id value) {
+    return [value isKindOfClass:[NSData class]] &&
+           CFGetTypeID((__bridge CFTypeRef)value) == CFDataGetTypeID();
+}
+
+static BOOL PXRestoreValueIsExactNumber(id value) {
+    return [value isKindOfClass:[NSNumber class]] &&
+           CFGetTypeID((__bridge CFTypeRef)value) == CFNumberGetTypeID();
+}
+
+static CFTypeRef PXCanonicalSecurityClassForSerializedValue(id value) {
+    if (!PXRestoreValueIsExactString(value)) {
+        return NULL;
+    }
+
+    CFStringRef serializedClass = (__bridge CFStringRef)value;
+    CFStringRef candidates[] = {
+        kSecClassGenericPassword,
+        kSecClassInternetPassword,
+        kSecClassCertificate,
+        kSecClassKey,
+        kSecClassIdentity,
+    };
+    CFTypeRef resolvedClass = NULL;
+    NSUInteger matchCount = 0;
+    for (NSUInteger index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++) {
+        if (CFEqual(serializedClass, candidates[index])) {
+            resolvedClass = candidates[index];
+            matchCount++;
+        }
+    }
+    return matchCount == 1 ? resolvedClass : NULL;
+}
+
+static BOOL PXSerializedClassMetadataIsConsistent(NSDictionary *item,
+                                                   CFTypeRef canonicalClass) {
+    id classMetadata = item[@"_class"];
+    if (!classMetadata) {
+        return YES;
+    }
+    if (!PXRestoreValueIsExactString(classMetadata)) {
+        return NO;
+    }
+    NSString *expectedName = PXKeychainClassName(canonicalClass);
+    return [(__bridge NSString *)classMetadata isEqualToString:expectedName];
+}
+
+static BOOL PXDecodeRestoreValue(id serializedValue,
+                                 id *decodedValueOut) {
+    if (!serializedValue || !decodedValueOut) {
+        return NO;
+    }
+
+    id decodedValue = serializedValue;
+    if ([serializedValue isKindOfClass:[NSDictionary class]]) {
+        NSDictionary *wrapped = (NSDictionary *)serializedValue;
+        id typeValue = wrapped[@"_type"];
+        if (typeValue) {
+            if (!PXRestoreValueIsExactString(typeValue)) {
+                return NO;
+            }
+            NSString *type = (NSString *)typeValue;
+            if ([type isEqualToString:@"data"]) {
+                id base64Value = wrapped[@"_base64"];
+                if (!PXRestoreValueIsExactString(base64Value)) {
+                    return NO;
+                }
+                NSData *data = [[NSData alloc] initWithBase64EncodedString:(NSString *)base64Value
+                                                                   options:0];
+                if (!data) {
+                    return NO;
+                }
+                decodedValue = data;
+            } else if ([type isEqualToString:@"date"]) {
+                id timestampValue = wrapped[@"_timestamp"];
+                if (!PXRestoreValueIsExactNumber(timestampValue)) {
+                    return NO;
+                }
+                double timestamp = [(NSNumber *)timestampValue doubleValue];
+                if (!isfinite(timestamp)) {
+                    return NO;
+                }
+                NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
+                if (!date) {
+                    return NO;
+                }
+                decodedValue = date;
+            }
+        }
+    }
+
+    *decodedValueOut = decodedValue;
+    return YES;
+}
+
+static NSDictionary *PXCreateRestoreAddQuery(NSDictionary *item) {
+    if (![item isKindOfClass:[NSDictionary class]] || item.count > 256) {
+        return nil;
+    }
+
+    id serializedClass = item[@"_secClass"];
+    CFTypeRef canonicalClass = PXCanonicalSecurityClassForSerializedValue(serializedClass);
+    if (!canonicalClass || !PXSerializedClassMetadataIsConsistent(item, canonicalClass)) {
+        return nil;
+    }
+
+    NSSet<NSString *> *excluded = PXExcludedRestoreAttributes();
+    NSMutableDictionary *addQuery = [NSMutableDictionary dictionaryWithCapacity:item.count];
+    addQuery[(__bridge id)kSecClass] = (__bridge id)canonicalClass;
+
+    for (id keyObject in item) {
+        if (!PXRestoreValueIsExactString(keyObject)) {
+            return nil;
+        }
+        NSString *key = (NSString *)keyObject;
+        if ([key hasPrefix:@"_"] ||
+            [key isEqualToString:(__bridge NSString *)kSecClass] ||
+            [excluded containsObject:key]) {
+            continue;
+        }
+
+        id decodedValue = nil;
+        if (!PXDecodeRestoreValue(item[key], &decodedValue) || !decodedValue) {
+            return nil;
+        }
+        addQuery[key] = decodedValue;
+    }
+
+    return [NSDictionary dictionaryWithDictionary:addQuery];
+}
+
+static PXKeychainItemIdentity *PXCreateRestoreIdentity(NSDictionary *addQuery,
+                                                        NSError **error) {
+    return [PXKeychainItemIdentity identityForSecurityItemAttributes:addQuery
+                                                               error:error];
+}
+
+static OSStatus PXCopyUniquePersistentReferenceForIdentity(
+    PXKeychainItemIdentity *identity,
+    NSData **persistentReferenceOut) {
+    if (persistentReferenceOut) {
+        *persistentReferenceOut = nil;
+    }
+    if (![identity isKindOfClass:[PXKeychainItemIdentity class]] ||
+        !persistentReferenceOut) {
+        return errSecParam;
+    }
+
+    @try {
+        NSDictionary *matchQuery = identity.matchQuery;
+        if (![matchQuery isKindOfClass:[NSDictionary class]] ||
+            matchQuery.count == 0 || matchQuery.count > 10) {
+            return errSecParam;
+        }
+
+        NSMutableDictionary *lookupQuery =
+            [NSMutableDictionary dictionaryWithDictionary:matchQuery];
+        lookupQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
+        lookupQuery[(__bridge id)kSecReturnPersistentRef] = @YES;
+        PXAddAuthUIFlags(lookupQuery);
+
+        CFTypeRef rawResult = NULL;
+        OSStatus lookupStatus = SecItemCopyMatching((__bridge CFDictionaryRef)lookupQuery,
+                                                     &rawResult);
+        id lookupResult = rawResult ? CFBridgingRelease(rawResult) : nil;
+        if (lookupStatus != errSecSuccess) {
+            return lookupStatus;
+        }
+
+        NSData *persistentReference = nil;
+        if (PXRestoreValueIsExactData(lookupResult)) {
+            persistentReference = (NSData *)lookupResult;
+        } else if ([lookupResult isKindOfClass:[NSArray class]] &&
+                   CFGetTypeID((__bridge CFTypeRef)lookupResult) == CFArrayGetTypeID()) {
+            NSArray *matches = (NSArray *)lookupResult;
+            if (matches.count == 0) {
+                return errSecItemNotFound;
+            }
+            if (matches.count != 1) {
+                return errSecDuplicateItem;
+            }
+            id onlyMatch = matches.firstObject;
+            if (!PXRestoreValueIsExactData(onlyMatch)) {
+                return errSecDecode;
+            }
+            persistentReference = (NSData *)onlyMatch;
+        } else if (!lookupResult) {
+            return errSecItemNotFound;
+        } else {
+            return errSecDecode;
+        }
+
+        if (persistentReference.length == 0) {
+            return errSecDecode;
+        }
+        NSData *snapshot = [[NSData alloc] initWithData:persistentReference];
+        if (!snapshot || snapshot.length == 0 ||
+            ![snapshot isEqualToData:persistentReference]) {
+            return errSecDecode;
+        }
+
+        *persistentReferenceOut = snapshot;
+        return errSecSuccess;
+    } @catch (__unused NSException *exception) {
+        return errSecDecode;
+    }
+}
+
+static NSDictionary *PXCreateUpdateAttributesFromAddQuery(
+    NSDictionary *addQuery,
+    PXKeychainItemIdentity *identity) {
+    if (![addQuery isKindOfClass:[NSDictionary class]] ||
+        ![identity isKindOfClass:[PXKeychainItemIdentity class]] ||
+        addQuery.count == 0 || addQuery.count > 256) {
+        return nil;
+    }
+
+    @try {
+        NSMutableDictionary *updateAttributes =
+            [NSMutableDictionary dictionaryWithDictionary:addQuery];
+
+        NSArray *alwaysExcludedKeys = @[
+            (__bridge id)kSecClass,
+            (__bridge id)kSecAttrAccessGroup,
+            (__bridge id)kSecAttrSynchronizable,
+            (__bridge id)kSecAttrAccessControl,
+            (__bridge id)kSecAttrCreationDate,
+            (__bridge id)kSecAttrModificationDate,
+            (__bridge id)kSecAttrPersistentReference,
+            (__bridge id)kSecMatchLimit,
+            (__bridge id)kSecReturnAttributes,
+            (__bridge id)kSecReturnData,
+            (__bridge id)kSecReturnRef,
+            (__bridge id)kSecReturnPersistentRef,
+            (__bridge id)kSecUseAuthenticationUI,
+            (__bridge id)kSecUseOperationPrompt,
+            (__bridge id)kSecValueRef,
+            (__bridge id)kSecValuePersistentRef,
+        ];
+        for (id key in alwaysExcludedKeys) {
+            [updateAttributes removeObjectForKey:key];
+        }
+        for (id key in PXExcludedRestoreAttributes()) {
+            [updateAttributes removeObjectForKey:key];
+        }
+        for (id key in identity.identityAttributeNames) {
+            if (!PXRestoreValueIsExactString(key)) {
+                return nil;
+            }
+            [updateAttributes removeObjectForKey:key];
+        }
+
+        return [NSDictionary dictionaryWithDictionary:updateAttributes];
+    } @catch (__unused NSException *exception) {
+        return nil;
+    }
+}
+
+static OSStatus PXUpdateExistingRestoreItem(NSData *persistentReference,
+                                             NSDictionary *updateAttributes) {
+    if (!PXRestoreValueIsExactData(persistentReference) ||
+        persistentReference.length == 0 ||
+        ![updateAttributes isKindOfClass:[NSDictionary class]] ||
+        updateAttributes.count == 0) {
+        return errSecParam;
+    }
+
+    @try {
+        NSMutableDictionary *updateQuery = [@{
+            (__bridge id)kSecValuePersistentRef: persistentReference,
+        } mutableCopy];
+        PXAddAuthUIFlags(updateQuery);
+        return SecItemUpdate((__bridge CFDictionaryRef)updateQuery,
+                             (__bridge CFDictionaryRef)updateAttributes);
+    } @catch (__unused NSException *exception) {
+        return errSecParam;
+    }
+}
+
+static PXRestoreItemOutcome PXProcessRestoreItem(NSDictionary *item,
+                                                  BOOL overwrite,
+                                                  NSString **diagnosticOut) {
+    if (diagnosticOut) {
+        *diagnosticOut = nil;
+    }
+
+    @try {
+        NSDictionary *addQuery = PXCreateRestoreAddQuery(item);
+        if (!addQuery) {
+            if (diagnosticOut) {
+                *diagnosticOut = @"A Keychain restore item could not be decoded safely.";
+            }
+            return PXRestoreItemOutcomeFailedError;
+        }
+
+        OSStatus addStatus = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
+        if (addStatus == errSecSuccess) {
+            return PXRestoreItemOutcomeSucceeded;
+        }
+        if (addStatus != errSecDuplicateItem) {
+            if (diagnosticOut) {
+                *diagnosticOut = [NSString stringWithFormat:@"Keychain restore add failed (status=%d).",
+                                  (int)addStatus];
+            }
+            return PXRestoreItemOutcomeFailedError;
+        }
+
+        if (!overwrite) {
+            if (diagnosticOut) {
+                *diagnosticOut = @"An existing Keychain item was preserved because overwrite was not requested.";
+            }
+            return PXRestoreItemOutcomeFailedWarning;
+        }
+
+        NSError *identityError = nil;
+        PXKeychainItemIdentity *identity = PXCreateRestoreIdentity(addQuery, &identityError);
+        if (!identity) {
+            if (diagnosticOut) {
+                *diagnosticOut = [NSString stringWithFormat:@"Exact Keychain item identity could not be constructed (code=%ld).",
+                                  (long)identityError.code];
+            }
+            return PXRestoreItemOutcomeFailedError;
+        }
+
+        NSData *persistentReference = nil;
+        OSStatus lookupStatus =
+            PXCopyUniquePersistentReferenceForIdentity(identity, &persistentReference);
+        if (lookupStatus != errSecSuccess) {
+            if (diagnosticOut) {
+                *diagnosticOut = [NSString stringWithFormat:@"Exact Keychain item lookup failed (status=%d).",
+                                  (int)lookupStatus];
+            }
+            return PXRestoreItemOutcomeFailedError;
+        }
+
+        NSDictionary *updateAttributes =
+            PXCreateUpdateAttributesFromAddQuery(addQuery, identity);
+        if (!updateAttributes) {
+            if (diagnosticOut) {
+                *diagnosticOut = @"Exact Keychain item update attributes could not be created safely.";
+            }
+            return PXRestoreItemOutcomeFailedError;
+        }
+        if (updateAttributes.count == 0) {
+            return PXRestoreItemOutcomeSucceeded;
+        }
+
+        OSStatus updateStatus =
+            PXUpdateExistingRestoreItem(persistentReference, updateAttributes);
+        if (updateStatus == errSecSuccess) {
+            return PXRestoreItemOutcomeSucceeded;
+        }
+        if (diagnosticOut) {
+            *diagnosticOut = [NSString stringWithFormat:@"Exact Keychain item update failed (status=%d).",
+                              (int)updateStatus];
+        }
+        return PXRestoreItemOutcomeFailedError;
+    } @catch (__unused NSException *exception) {
+        if (diagnosticOut) {
+            *diagnosticOut = @"A Keychain restore item could not be processed safely.";
+        }
+        return PXRestoreItemOutcomeFailedError;
+    }
+}
+
 #pragma mark - Implementation

 @implementation KeychainBackupHelper
@@ -316,8 +695,7 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
         }
         return nil;
     }
-
-    // Read backup file.
+
     NSData *plistData = [NSData dataWithContentsOfFile:filePath];
     if (!plistData.length) {
         if (error) {
@@ -327,7 +705,7 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
         }
         return nil;
     }
-
+
     NSError *parseError = nil;
     NSDictionary *backup = [NSPropertyListSerialization propertyListWithData:plistData
                                                                      options:NSPropertyListImmutable
@@ -342,7 +720,7 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
         }
         return nil;
     }
-
+
     NSArray *items = backup[@"items"];
     if (![items isKindOfClass:[NSArray class]]) {
         if (error) {
@@ -352,87 +730,36 @@ static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
         }
         return nil;
     }
-
+
     PXKeychainBackupResult *result = [[PXKeychainBackupResult alloc] init];
     NSMutableArray<NSString *> *warnings = [NSMutableArray array];
     NSMutableArray<NSString *> *errors = [NSMutableArray array];
-    NSSet<NSString *> *excluded = PXExcludedRestoreAttributes();

-    for (NSDictionary *item in items) {
-        if (![item isKindOfClass:[NSDictionary class]]) continue;
-        result.itemsProcessed++;
-
-        // Get the security class.
-        id secClassValue = item[@"_secClass"];
-        if (!secClassValue) {
-            [warnings addObject:@"Item missing _secClass"];
-            result.itemsFailed++;
+    for (id itemObject in items) {
+        if (![itemObject isKindOfClass:[NSDictionary class]]) {
             continue;
         }
-
-        // Build the add query.
-        NSMutableDictionary *addQuery = [NSMutableDictionary dictionary];
-        addQuery[(__bridge id)kSecClass] = secClassValue;
-
-        for (NSString *key in item) {
-            if ([key hasPrefix:@"_"]) continue; // Skip metadata keys
-            if ([excluded containsObject:key]) continue;
-
-            id value = item[key];
-
-            // Decode special types.
-            if ([value isKindOfClass:[NSDictionary class]]) {
-                NSDictionary *wrapped = (NSDictionary *)value;
-                NSString *type = wrapped[@"_type"];
-
-                if ([type isEqualToString:@"data"]) {
-                    NSString *base64 = wrapped[@"_base64"];
-                    if (base64) {
-                        value = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
-                    }
-                } else if ([type isEqualToString:@"date"]) {
-                    NSNumber *timestamp = wrapped[@"_timestamp"];
-                    if (timestamp) {
-                        value = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
-                    }
-                }
-            }
-
-            if (value) {
-                addQuery[key] = value;
-            }
-        }
-
-        // Add the item.
-        // Ensure we can restore synchronizable items.
-        if (addQuery[(__bridge id)kSecAttrSynchronizable]) {
-            // Nothing else to do; keep value as-is.
-        }
-        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
-
-        if (status == errSecSuccess) {
-            result.itemsSucceeded++;
-        } else if (status == errSecDuplicateItem) {
-            NSString *duplicateWarning = overwrite
-                ? [NSString stringWithFormat:@"Overwrite requested but existing item was preserved pending safe per-item replacement: %@",
-                   addQuery[(__bridge id)kSecAttrAccount] ?: @"unknown"]
-                : [NSString stringWithFormat:@"Item already exists; existing item was preserved: %@",
-                   addQuery[(__bridge id)kSecAttrAccount] ?: @"unknown"];
-            [warnings addObject:duplicateWarning];
-            result.itemsFailed++;
-        } else {
-            NSString *acct = addQuery[(__bridge id)kSecAttrAccount];
-            NSString *svc = addQuery[(__bridge id)kSecAttrService];
-            NSString *grp = addQuery[(__bridge id)kSecAttrAccessGroup];
-            [errors addObject:[NSString stringWithFormat:@"Failed to add item (acct=%@ svc=%@ group=%@): %@",
-                              acct ?: @"",
-                              svc ?: @"",
-                              grp ?: @"",
-                              PXSecurityErrorDescription(status)]];
-            result.itemsFailed++;
+
+        result.itemsProcessed++;
+        NSString *diagnostic = nil;
+        PXRestoreItemOutcome outcome = PXProcessRestoreItem((NSDictionary *)itemObject,
+                                                            overwrite,
+                                                            &diagnostic);
+        switch (outcome) {
+            case PXRestoreItemOutcomeSucceeded:
+                result.itemsSucceeded++;
+                break;
+            case PXRestoreItemOutcomeFailedWarning:
+                result.itemsFailed++;
+                [warnings addObject:diagnostic ?: @"An existing Keychain item was preserved."];
+                break;
+            case PXRestoreItemOutcomeFailedError:
+                result.itemsFailed++;
+                [errors addObject:diagnostic ?: @"A Keychain restore item failed safely."];
+                break;
         }
     }
-
+
     result.warnings = warnings;
     result.errors = errors;
     return result;
diff --git a/KeychainHelper/backup_helper.m b/KeychainHelper/backup_helper.m
index 7930929..d851deb 100644
--- a/KeychainHelper/backup_helper.m
+++ b/KeychainHelper/backup_helper.m
@@ -43,7 +43,7 @@ static void printUsage(const char *progname) {
     fprintf(stderr, "  --action <action>   Action to perform: backup, restore, wipe, list\n");
     fprintf(stderr, "  --file <path>       Path to backup/restore file (plist format)\n");
     fprintf(stderr, "  --groups <groups>   Comma-separated list of keychain access groups\n");
-    fprintf(stderr, "  --overwrite         For restore: request replacement; existing duplicates are preserved\n");
+    fprintf(stderr, "  --overwrite         For restore: update one exact existing item in place; never delete\n");
     fprintf(stderr, "  --verbose           Print detailed progress information\n");
     fprintf(stderr, "  --help              Show this help message\n");
 }
diff --git a/scripts/keychain_backup.sh b/scripts/keychain_backup.sh
index aad0ac6..45f0cba 100644
--- a/scripts/keychain_backup.sh
+++ b/scripts/keychain_backup.sh
@@ -961,7 +961,7 @@ print_usage() {
     echo "  list <bundleID>                   List keychain items"
     echo ""
     echo "Options:"
-    echo "  --overwrite   For restore: request replacement; existing duplicates are preserved"
+    echo "  --overwrite   For restore: update one exact existing item in place; never delete"
     echo "  --verbose     Show detailed output"
     echo ""
     echo "Example:"
```

## Whitespace, CRLF, NUL and final-newline audit
| File | Before CRLF | After CRLF | NUL | Final LF | New whitespace errors |
|---|---:|---:|---:|---:|---:|
| `KeychainHelper/KeychainBackupHelper.h` | 86 | 86 | 0 | TRUE | 0 |
| `KeychainHelper/KeychainBackupHelper.m` | 618 | 945 | 0 | TRUE | 0 |
| `KeychainHelper/backup_helper.m` | 565 | 565 | 0 | TRUE | 0 |
| `scripts/keychain_backup.sh` | 1108 | 1108 | 0 | TRUE | 0 |
| report | 0 | 0 | 0 | TRUE | 0 |
Production files preserve CRLF/final newline. Existing untouched trailing spaces remain; diff-check proves none introduced. Report is UTF-8 LF, no NUL/trailing whitespace.

## Build, toolchain and device risks
- Local Objective-C/Theos build not run: clang.exe, make.exe and xcrun.exe unavailable; THEOS unset.
- GitHub Actions pending for Objective-C/ARC compile, Security link, package and Makefile non-regression.
- Device Security.framework behavior pending for five classes, synchronizable distinction, auth-protected records, cardinality and update compatibility.
- Static/model evidence cannot prove live OS behavior.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
