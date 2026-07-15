# TASK-3.8 Report — Publish Completed Backup Atomically

## Baseline and exact scope

- Required baseline: `bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a`.
- Observed HEAD before edits: `bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a`.
- Host: `DESKTOP-JATSMMU`.
- TASK-3.7 review was read in full and reports ACCEPTED/COMPLETED.
- Authorized production files: `PXBackupDirectoryPublisher.h`, `PXBackupDirectoryPublisher.m`, `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-3.8-REPORT.md`.
- No TASK-3.9, TASK-3.10, publication marker, index, Restore or UI work was performed.

### Baseline command evidence

```text
git status --short --untracked-files=all
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
?? docs/backup-restore-hardening/reviews/TASK-3.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.6-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.6A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-3.7-REVIEW.md
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
?? docs/backup-restore-hardening/tasks/TASK-3.2-add-per-bundle-backup-serialization.md
?? docs/backup-restore-hardening/tasks/TASK-3.3-add-common-verified-artifact-writer.md
?? docs/backup-restore-hardening/tasks/TASK-3.4-derive-preferences-inclusion-from-verified-output.md
?? docs/backup-restore-hardening/tasks/TASK-3.5-define-required-and-optional-artifact-policy.md
?? docs/backup-restore-hardening/tasks/TASK-3.6-introduce-manifest-schema-v4.md
?? docs/backup-restore-hardening/tasks/TASK-3.6A-fix-v4-malformed-type-exception-safety.md
?? docs/backup-restore-hardening/tasks/TASK-3.7-write-and-validate-manifest-atomically.md
?? docs/backup-restore-hardening/tasks/TASK-3.8-publish-completed-backup-atomically.md
```

```text
git rev-parse HEAD
bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a
```

```text
git log -6 --oneline
bf9e518 phase3(task-3.7): write and validate manifest atomically
3a7d3f8 phase3(task-3.6A): make manifest v4 type validation exception safe
c11ac70 phase3(task-3.6): introduce backup manifest schema v4
5366c50 phase3(task-3.5): define backup artifact policy
339ca01 phase3(task-3.4): derive preferences inclusion from verified output
849b282 phase3(task-3.3): add common verified artifact writer
```

```text
git diff --check
PASS (no output)
```

## Protected SHA-256 before and after

Protected production files checked: 306. Changed: 0.

| Protected production file | SHA-256 before | SHA-256 after | Bytes |
|---|---|---|---:|
| `.DS_Store` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | 14340 |
| `.github/workflows/build-ios-arm.yml` | `43814c1ab1f47aee5dd88864aefc2068de5f91f23ce24df96394647958c5706e` | `43814c1ab1f47aee5dd88864aefc2068de5f91f23ce24df96394647958c5706e` | 4548 |
| `.gitignore` | `5f4946295e8cee11cf3e4b1ea686c1abdf2c68aeb1c49f482452e889b68bcec2` | `5f4946295e8cee11cf3e4b1ea686c1abdf2c68aeb1c49f482452e889b68bcec2` | 111 |
| `Agent.md` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | 6521 |
| `AppDataBackupManager.h` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | 1442 |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | 336 |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | 28132 |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | 4768 |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | 370484 |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | 1061 |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | 11626 |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | 1356 |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | 11499 |
| `AppVersionManager.h` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | 1295 |
| `AppVersionManager.m` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | 15049 |
| `AppVersionSpoofingViewController.h` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | 678 |
| `AppVersionSpoofingViewController.m` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | 85181 |
| `Assets.xcassets/.DS_Store` | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | `dd93a4f43f346f9e8065cbfb6c3fb69910f2f284de52be4db2cfb2444895390a` | 6148 |
| `Assets.xcassets/AppIcon.appiconset/114.png` | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | `166c1096529e278504a87b29a4d38d2e0161bc204d2d040b9ad8609d4fc7a50f` | 8495 |
| `Assets.xcassets/AppIcon.appiconset/120.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 |
| `Assets.xcassets/AppIcon.appiconset/180.png` | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | `6ca7f490751306e8f228bfcfc2fe75bddd348c68e37286b9830915c8e559efc0` | 17711 |
| `Assets.xcassets/AppIcon.appiconset/29.png` | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | `744b7d04bb3fc1a604aab8e0c226db5511e57e836eac3ae19f9393f5dc579d51` | 1323 |
| `Assets.xcassets/AppIcon.appiconset/40.png` | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | `009124d0d893d71e2e9a131acbbc2d8a60dc260d743bdda73d4009b948039fa1` | 2181 |
| `Assets.xcassets/AppIcon.appiconset/57.png` | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | `800c14a931ca8b7b6b2a5bdf6514d982e190e1ce62313e3ec928ef1a485e4e13` | 3277 |
| `Assets.xcassets/AppIcon.appiconset/58.png` | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | `cca475fd7868d52db5451b870d1451a4ecc4d742f86c7b57a64ee9da16ae42d5` | 3350 |
| `Assets.xcassets/AppIcon.appiconset/60.png` | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | `89074f9c04cfc686b1522ec7be34d2cd6a2d378b948747ae1d5945a9fe056d5f` | 3536 |
| `Assets.xcassets/AppIcon.appiconset/80.png` | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | `413476ef167e7507abca272e00adfe6654fed084f82b22a67df41e9eae28b883` | 5273 |
| `Assets.xcassets/AppIcon.appiconset/87.png` | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | `72e90989084a130368405d67a6be27aef16014bb1c06a2dbb0f6afe4470a16b7` | 5820 |
| `Assets.xcassets/AppIcon.appiconset/Contents.json` | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | `eb58f836a1ae5cdb9b42d5f6877f76ba678bf7310ffe1e0478bb39530c7425f6` | 1655 |
| `Assets.xcassets/AppIcon.appiconset/Thumbs.db` | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | `d8108e4360bcc91b08e0ea8699131d923ea32bda8672a5ea5095c20b8afecf5f` | 3584 |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | 159 |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | 9567 |
| `BottomButtons.h` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | 849 |
| `BottomButtons.m` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | 24605 |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | 1562 |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | 49583 |
| `ContainerManager.h` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | 1109 |
| `ContainerManager.m` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | 4393 |
| `CopyHelper.h` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | 531 |
| `CopyHelper.m` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | 6147 |
| `DEBIAN/postinst` | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | `672605bb1f4db0ab20e7a9ed08741597ec89f91a5d19be04ddca12ba75024a72` | 4119 |
| `DEBIAN/preinst` | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | `c5da98965be1131bb53af46b1f4ab17be0fa45aba9881550c3c6f497bba9e30e` | 198 |
| `DEBIAN/prerm` | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | `cf8dbdff236c16a3e219a18e9a28a24370781d4315821da45c26c53f94ab22d6` | 126 |
| `DeviceSpecificSpoofingViewController+EditLabel.h` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | 161 |
| `DeviceSpecificSpoofingViewController+EditLabel.m` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | 9198 |
| `DeviceSpecificSpoofingViewController+ProfileManagerDelegate.m` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | 508 |
| `DeviceSpecificSpoofingViewController.h` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | 134 |
| `DeviceSpecificSpoofingViewController.m` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | 56660 |
| `DevicesViewController.h` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | 1160 |
| `DevicesViewController.m` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | 38275 |
| `DomainManagementViewController.h` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | 112 |
| `DomainManagementViewController.m` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | 30905 |
| `DoorDashOrderViewController.h` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | 668 |
| `DoorDashOrderViewController.m` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | 37685 |
| `DownloadResourcesViewController.h` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | 96 |
| `DownloadResourcesViewController.m` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | 2456 |
| `FileManagerViewController.h` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | 658 |
| `FileManagerViewController.m` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | 55902 |
| `FixVersionAppsViewController.h` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | 93 |
| `FixVersionAppsViewController.m` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | 7764 |
| `FreezeManager.h` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | 385 |
| `FreezeManager.m` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | 8975 |
| `Icon.png` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | `6dc938664f361ba919f2c77e6b0b576e73151a687f46144022345cb8261c34b2` | 9368 |
| `Improvement_Plan.md` | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | `6707b1154da25fb64f56380146a0172ec1d2e4d22d4242a90a81f953252a67c3` | 12526 |
| `Info.plist` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | 7202 |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | 153 |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | 10227 |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | 4280 |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | 27970 |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | 14129 |
| `LaunchScreen.storyboard` | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | `36cf5911aab28984a57eecb7544336636bd75a763961075505be9720bd1f23bb` | 3134 |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | 9146 |
| `Making` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `MatrixRainView.h` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | 273 |
| `Newplan.md` | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | `d2f5a2d387bd4e513f9981f6071b889c3ff723043d2c661ccebe7bafc55df204` | 17391 |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | 2039 |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | 18688 |
| `PXAppGroupRestoreTransaction.h` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | 2235 |
| `PXAppGroupRestoreTransaction.m` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | 138376 |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | 2361 |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | 89098 |
| `PXBackupArtifactPolicy.h` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | `52da8d6a0537d6a9647af13b9a992d5e131d6405f3ea2759f6a811b7ad90f80f` | 1648 |
| `PXBackupArtifactPolicy.m` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | `c40df7376b918cadf79508a9cb45aa04bf27390e015e80e442a41764be13f7bc` | 4536 |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 |
| `PXBackupArtifactWriter.h` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | `5e91f6db0b8921f6980e4db53eb06edf2b505be05eacc16334bca6f7a80bb1e8` | 2948 |
| `PXBackupArtifactWriter.m` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | `0362e20b17155d1182b528779c749bd23ffa4614436e03231a8c3e1ac9b4f330` | 83333 |
| `PXBackupBundleLock.h` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 |
| `PXBackupBundleLock.m` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 |
| `PXBackupManifestV4.h` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | 2354 |
| `PXBackupManifestV4.m` | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | `db7e09ceeee46049ff180e88293e6088b652b8ae1c231ad2c3ec825cd5bd9fd7` | 44234 |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 |
| `PXBackupManifestValidator.m` | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | `e3403920f816cbf6c8c1c135d835786fa83f56a36901a9e41427e86cf6bb1820` | 91751 |
| `PXBackupManifestWriter.h` | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | 2431 |
| `PXBackupManifestWriter.m` | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | 54069 |
| `PXBackupPublicationWorkspace.h` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | 1869 |
| `PXBackupPublicationWorkspace.m` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | 48086 |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | 1288 |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | 4389 |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | 3467 |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | 10564 |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | 1290 |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | 8332 |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | 1213 |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | 32523 |
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | 2061 |
| `PXMainDataRestoreTransaction.m` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | 115847 |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | 2511 |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | 67751 |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | 4209 |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | 100980 |
| `PXOptionalRestoreTransaction.h` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | 4050 |
| `PXOptionalRestoreTransaction.m` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | `b766f73f7b49877ab589f35ae9dc7d0f89e80638526e6c5663777ac6a1a48c1c` | 240408 |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | 1691 |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | 5304 |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | 4947 |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | 48523 |
| `PXRestoreResult.h` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | 4512 |
| `PXRestoreResult.m` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | 15842 |
| `PlistViewerViewController.h` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | 184 |
| `PlistViewerViewController.m` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | 26767 |
| `ProfileButtonsView.h` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | 254 |
| `ProfileButtonsView.m` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | 5381 |
| `ProfileCreationViewController.h` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | 388 |
| `ProfileCreationViewController.m` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | 7575 |
| `ProfileManagerViewController.h` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | 783 |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | 159713 |
| `ProgressHUDView.h` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | 522 |
| `ProgressHUDView.m` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | 2263 |
| `ProjectX` | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | `a81b074d511a8a7c94032dabd27feb7cdf43585788e559b2858b934dd2224c9e` | 1691136 |
| `ProjectX.entitlements` | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | `224bece3b1e28d417a1b9c1f70c82aa1453d8af9562e0bc3298279aec4dc459c` | 1747 |
| `ProjectX.h` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | 1623 |
| `ProjectXInstaller.h` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | 1231 |
| `ProjectXInstaller.m` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | 1898 |
| `ProjectXSceneDelegate.h` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | 192 |
| `ProjectXSceneDelegate.m` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | 12181 |
| `ProjectXTweak.dylib` | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | `e024784ca18867a8eb9924a7342da693c6fccb8af97716446a611db13dc8b171` | 945152 |
| `ProjectXTweak.plist` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | 429 |
| `ProjectXTweak/AAA_TestCtor.m` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | 1614 |
| `ProjectXTweak/AppContainerHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/AppGroupHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/AppInstallHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/AppVersionHooks.h` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | 546 |
| `ProjectXTweak/AppVersionHooks.x` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | 25202 |
| `ProjectXTweak/BatteryHooks.x` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | 17019 |
| `ProjectXTweak/BootTimeHooks.x` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | 26933 |
| `ProjectXTweak/CanvasFingerprintHooks.x` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | 27600 |
| `ProjectXTweak/CoreDataHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/DeviceModelHooks.x` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | 9012 |
| `ProjectXTweak/DeviceSpecHooks.x` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | 81702 |
| `ProjectXTweak/DomainBlockingHooks.x` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | 27065 |
| `ProjectXTweak/FirebasePerfDisableScoped.x` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | 2515 |
| `ProjectXTweak/HookOwnership.h` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | 541 |
| `ProjectXTweak/IOSVersionHooks.x` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | 112809 |
| `ProjectXTweak/JailbreakBypassHooks.x` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | 142382 |
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/LocaleTimeZoneHooks.x` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | 4909 |
| `ProjectXTweak/Makefile.bak` | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | `b509097c737be4b6eff89ff01f49cd3b690d9217e89b304be17718b1c61ec018` | 999 |
| `ProjectXTweak/MethodSwizzler.h` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | 341 |
| `ProjectXTweak/MethodSwizzler.m` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | 1903 |
| `ProjectXTweak/MissingSpoofHooks.x` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | 9793 |
| `ProjectXTweak/MobileGestalt.h` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | 11371 |
| `ProjectXTweak/NetworkConnectionTypeHooks.x` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | 56573 |
| `ProjectXTweak/ObjcClassPairGuard.x` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | 5439 |
| `ProjectXTweak/PXFileDebug.h` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | 6957 |
| `ProjectXTweak/PXNativeHookCoordinator.h` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | 9000 |
| `ProjectXTweak/PXNativeHookCoordinator.m` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | 28291 |
| `ProjectXTweak/PXScope.h` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | 1747 |
| `ProjectXTweak/PXScope.m` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | 20405 |
| `ProjectXTweak/PasteboardHooks.x` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | 37855 |
| `ProjectXTweak/SpringBoardLaunchHook.x` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | 16185 |
| `ProjectXTweak/StorageHooks.x` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | 41482 |
| `ProjectXTweak/ThemeHooks.x` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | 19043 |
| `ProjectXTweak/Tweak.x` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | 196955 |
| `ProjectXTweak/UUIDHooks.x` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | 43164 |
| `ProjectXTweak/UberURLHooks.x` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | 40212 |
| `ProjectXTweak/UserDefaultsHooks.x` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | 26089 |
| `ProjectXTweak/VPNDetectionBypass.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `ProjectXTweak/WiFiHook.x` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | 40848 |
| `ProjectXViewController.h` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | 853 |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | 372278 |
| `README.md` | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | `de0e61f9ee6cb9ac61e0db218ae510cf9fcc0bd84ec8f0229e76c7ed3117a0d2` | 184 |
| `SecurityTabViewController+IPMonitorInfo.m` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | 967 |
| `SecurityTabViewController.h` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | 5441 |
| `SecurityTabViewController.m` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | 293431 |
| `TabBarController+DeviceAlerts.h` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `TabBarController+DeviceAlerts.m` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 |
| `TabBarController.h` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | 1019 |
| `TabBarController.m` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | 28147 |
| `TestCtorTweak/Makefile` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | 217 |
| `TestCtorTweak/TestCtorTweak.plist` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | 315 |
| `TestCtorTweak/Tweak.x` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | 351 |
| `ToolViewController.h` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | 280 |
| `ToolViewController.m` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | 59814 |
| `URLMonitor.h` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | 727 |
| `URLMonitor.m` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | 8827 |
| `UberOrderViewController.h` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | 608 |
| `UberOrderViewController.m` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | 39801 |
| `VersionManagementViewController.h` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | 955 |
| `VersionManagementViewController.m` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | 68330 |
| `WeaponXGuardian.m` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | 16859 |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | 386 |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | 21970 |
| `WeaponXMountDaemon/WeaponXDaemon.m` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | 19900 |
| `WeaponXMountDaemon/WeaponXMountDaemon.m` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | 11205 |
| `WebKit_Filtering.md` | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | `17e394e126e548a068785f0ab05a383726590e3f8e2ae99a285bc655c13a8c22` | 5499 |
| `com.hydra.weaponx.guardian.plist` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | 1145 |
| `common/AppContainerUUIDManager.h` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | 542 |
| `common/AppContainerUUIDManager.m` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | 3559 |
| `common/AppGroupUUIDManager.h` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | 406 |
| `common/AppGroupUUIDManager.m` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | 3449 |
| `common/AppInstallUUIDManager.h` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | 532 |
| `common/AppInstallUUIDManager.m` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | 3539 |
| `common/BatteryManager.h` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | 685 |
| `common/BatteryManager.m` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | 13918 |
| `common/CarrierDB.h` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | 1418 |
| `common/CarrierDB.m` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | 12622 |
| `common/CoreDataUUIDManager.h` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | 422 |
| `common/CoreDataUUIDManager.m` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | 3450 |
| `common/DBDebugLogger.h` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | 262 |
| `common/DBDebugLogger.m` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | 2783 |
| `common/DeviceModelManager.h` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | 1697 |
| `common/DeviceModelManager.m` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | 37928 |
| `common/DeviceNameManager.h` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | 385 |
| `common/DeviceNameManager.m` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | 11474 |
| `common/DomainBlockingSettings.h` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | 882 |
| `common/DomainBlockingSettings.m` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | 12424 |
| `common/DyldCacheUUIDManager.h` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | 411 |
| `common/DyldCacheUUIDManager.m` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | 3458 |
| `common/IDFAManager.h` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | 335 |
| `common/IDFAManager.m` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | 2745 |
| `common/IDFVManager.h` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | 335 |
| `common/IDFVManager.m` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | 2712 |
| `common/IOSBuildDB.h` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | 1092 |
| `common/IOSBuildDB.m` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | 9567 |
| `common/IOSVersionInfo.h` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | 592 |
| `common/IOSVersionInfo.m` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | 15529 |
| `common/IPMonitorService.h` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | 224 |
| `common/IPMonitorService.m` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | 25567 |
| `common/IPStatusCacheManager.h` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | 990 |
| `common/IPStatusCacheManager.m` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | 12562 |
| `common/IPStatusViewController.h` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | 271 |
| `common/IPStatusViewController.m` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | 62749 |
| `common/IPhoneModelDB.h` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | 885 |
| `common/IPhoneModelDB.m` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | 6198 |
| `common/IdentifierManager.h` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | 3082 |
| `common/IdentifierManager.m` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | 160824 |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | 405 |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | 3479 |
| `common/LocationSpoofingManager.h` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | 3202 |
| `common/LocationSpoofingManager.m` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | 65282 |
| `common/NetworkManager.h` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | 1065 |
| `common/NetworkManager.m` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | 17926 |
| `common/PXPaths.h` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | 616 |
| `common/PXPaths.m` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | 2283 |
| `common/PXProcessKiller.h` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | 554 |
| `common/PXProcessKiller.m` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | 4565 |
| `common/PassThroughWindow.h` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | 75 |
| `common/PassThroughWindow.m` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | 486 |
| `common/PasteboardUUIDManager.h` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | 415 |
| `common/PasteboardUUIDManager.m` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | 3466 |
| `common/ProfileIndicatorView.h` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | 174 |
| `common/ProfileIndicatorView.m` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | 56659 |
| `common/ProfileManager.h` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | 2322 |
| `common/ProfileManager.m` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | 72206 |
| `common/ProjectXLogging.h` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | 460 |
| `common/ProjectXLogging.m` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | 4712 |
| `common/ScoreMeterView.h` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | 200 |
| `common/ScoreMeterView.m` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | 2650 |
| `common/SerialNumberManager.h` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | 486 |
| `common/SerialNumberManager.m` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | 6005 |
| `common/StorageManager.h` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | 3350 |
| `common/StorageManager.m` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | 9610 |
| `common/SystemUUIDManager.h` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | 387 |
| `common/SystemUUIDManager.m` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | 3422 |
| `common/UIButton+SafeConfiguration.h` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | 984 |
| `common/UIButton+SafeConfiguration.m` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | 1672 |
| `common/UIButtonCompat.h` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | 1581 |
| `common/UIButtonCompat.m` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | 5833 |
| `common/UptimeManager.h` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | 1039 |
| `common/UptimeManager.m` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | 18221 |
| `common/UserDefaultsUUIDManager.h` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | 425 |
| `common/UserDefaultsUUIDManager.m` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | 3484 |
| `common/VersionCompare.h` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | 519 |
| `common/VersionCompare.m` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | 1936 |
| `common/WiFiManager.h` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | 664 |
| `common/WiFiManager.m` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | 26544 |
| `control` | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | `fcc89e22298b1a2eefa691d09462d1ae6bb86b805deb43ec71d40bce6e33a4ea` | 469 |
| `data/carrier_db.json` | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | `003d4bc3cfb44f7af45ba59e65afc9305957f0ba57a7b42db44a114402192e1b` | 17230 |
| `ent.plist` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | 2881 |
| `iOSVersionManager.h` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | 404 |
| `include/.DS_Store` | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | `d1b132f85d7cbdb006d39402f5e3ab335ddfcb296b2090c6676887034c73894b` | 6148 |
| `include/HookKit` | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | `27fc5a751717503f49497e1a9e6b5a08347bb83c55478387f073e96fc8e82737` | 38 |
| `include/ellekit/ellekit.h` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | 5050 |
| `include/substrate.h` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | 44 |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | 912 |
| `layout/Library/libSandy/projectx_filesystem_access.plist` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | 2557 |
| `location.png` | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | `28129305b1bf9bef807b3473f85fc507f1ee21186168e4513b1c875ec94eb889` | 6132 |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | 23462 |
| `postinst` | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | `a0143e7e9e08efca6dd430098185cc816cfdf7c8bb025d504430a74d4b2917e7` | 6118 |
| `scripts/audit_native_hooks.sh` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | 4225 |
| `scripts/keychain_backup.sh` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | 32096 |
| `scripts/setup_altlist.sh` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | 1567 |
| `setup_app.sh` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | 1679 |
| `setup_dependencies.sh` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | 524 |
| `weaponx-debug.sh` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | 6254 |

## TASK-3.1 temporary-result inventory

- Baseline successful Backup returned `publicationWorkspace.workspacePath` and `manifestWriter.manifestPath`.
- TASK-3.8 replaces both successful result assignments with publisher-owned final paths.
- Static result-partial assignment count after correction: 0.
- Successful result final assignments: exactly 2.

## Exact public API and eighteen errors

- Exports: 2. Error codes: 18. Publisher classes: 1.
- Factories: 1. Publish methods: 1. Validation methods: 1.
- Readonly properties: 7. Public readwrite properties: 0.

The exact error enumeration is contiguous from `InvalidInput = 1` through `RollbackFailed = 18`. No descriptor, rename, rollback, cleanup or bypass API is public.

## Timestamp, UUID and final-name proof

- Timestamp requires exactly 15 ASCII bytes in `yyyyMMdd-HHmmss`, UTC, non-lenient parse and exact formatter round trip.
- Backup identifier requires exactly 36 ASCII bytes, lowercase hex, canonical hyphen positions and exact `NSUUID` lowercase round trip.
- Final directory name is created once as `<timestamp>-<backupIdentifier>`.
- Final component is bounded to 255 lossless UTF-8 bytes and rejects slash, backslash, NUL/control, dot components, all reserved partial prefixes, the lock filename and `manifest.plist`.
- Final absolute path remains within 4096 bytes.
- Timestamp prefix preserves current lexical newest-first sorting while UUID prevents same-second collisions.

## Parent/workspace retained authority and collision behavior

- Factory requires exact workspace and lock runtime classes, matching bundle IDs and canonical bundle-directory paths.
- Lock ownership and TASK-3.1 workspace identity are validated before authority is retained.
- Parent is lstat/open/fstat bound with no-follow, directory/no-setid and CLOEXEC proof.
- Workspace is inspected and opened descriptor-relatively, exact mode 0700, same filesystem and exact path/namespace/FD identity.
- Existing final file, directory or symlink returns `FinalDirectoryAlreadyExists`; there is no alternate-name fallback or overwrite.
- Factory performs no rename and creates no marker.

## Lifecycle, readiness and pre-publication order

- Publisher retains workspace, lock, parent/workspace descriptors and initial identities; dealloc closes only owned descriptors.
- Every public publish call consumes the single attempt, including malformed writer inputs.
- Artifact and manifest writers must be exact runtime classes, validate successfully and belong to the exact workspace.
- Manifest must be written, 1..128 MiB, lowercase SHA-256, immutable, validator-accepted, v4, exact backupID/timestamp/protocol/state/count/size/checksum.
- Final name must remain absent and no `.weaponx-manifest-partial-*` child may remain.
- Workspace is strictly fsynced before forward rename.

## Atomic forward publication and durability

- File-local `renameat` implementation sites: 1.
- Forward helper calls: 1. Reverse helper calls: 1.
- Forward arguments are retained parent FD + original partial name to the same parent FD + final name.
- Immediately before rename the lock, parent, workspace and collision absence are reproved.
- After rename the old partial name must be absent and final namespace must be the exact retained workspace inode.
- Retained workspace and parent directories are strictly fsynced.
- Final directory is independently opened no-follow/CLOEXEC, exact mode 0700 and same identity.

## Final manifest replay and acceptance ordering

- Final `manifest.plist` is opened descriptor-relatively, regular, nlink 1, mode 0600, same filesystem and exact TASK-3.7 size.
- Read-back uses a 64-KiB buffer, rejects early EOF/extra bytes, computes lowercase SHA-256 and proves stat stability.
- Parsed immutable dictionary passes `PXBackupManifestValidator`, deep-equals TASK-3.7 retained representation and matches backupID/timestamp/artifactCount/totalSize/archiveChecksum.
- Final directory and manifest descriptors are retained.
- `published = YES` is assigned only after all final bindings and replay proofs pass.

## Unpublished/published identity validation

- Unpublished validation calls lock + TASK-3.1 workspace validation and requires original partial namespace/FD/path identity plus final absence.
- Published validation intentionally does not call the old path-based TASK-3.1 workspace validator.
- Published validation requires original partial absence, final namespace/descriptor identity, final manifest identity, digest, parse, validator and retained representation/aggregate equality.
- Replacement identities are never adopted.

## Reverse rollback and evidence preservation

- Every failure after successful forward rename and before acceptance enters reverse rollback.
- Reverse preconditions require exact final workspace inode, original partial absence and retained parent identity.
- Reverse uses the same file-local rename helper, strict parent fsync, final absence and restored exact partial identity.
- Successful rollback returns the original publication error and leaves `published == NO`.
- Any rollback/proof/fsync ambiguity returns `RollbackFailed` and preserves manifest/artifact/directory evidence.
- No recursive cleanup or deletion is performed.

## Error privacy

- Publisher errors use only `NSLocalizedDescriptionKey` and `PXBackupDirectoryPublisherErrorFieldPathKey`.
- No raw path/name, bundle ID, timestamp, backup ID, inode/device, digest, size, errno text, nested error, stdout or stderr is exposed.

## Manager integration and final result paths

- Publisher factory/validations/publish: 1 / 3 / 1.
- Publisher is created after canonical policy construction and one backup UUID, before output/debug/process kill/producers.
- Existing TASK-3.7 final validations run before publisher pre-validation and publication.
- After forward directory rename the manager calls only publisher post-publication validation; it does not revalidate path-based workspace/artifact/manifest writers.
- `out.backupDirectory = directoryPublisher.publishedDirectoryPath`.
- `out.manifestPath = directoryPublisher.publishedManifestPath`.
- Publisher failures are hard failures: nil result, exact publisher NSError, main queue, one completion.

## RRS, discovery and sorting compatibility

- Immediate RRS/Restore callers continue receiving an explicit path, now the visible final directory.
- `listBackupDirectoriesForBundleID:` is byte-identical.
- Existing discovery skips partial names and includes final nonpartial directories containing `manifest.plist`.
- `<timestamp>-<UUID>` retains timestamp-first lexical ordering.

## TASK-3.1 through TASK-3.7 non-regression

- Workspace, bundle lock, artifact policy/writer, manifest v4/validator and manifest writer sources are byte-identical.
- Timestamp method, warning sequence, debug sequence, public Backup selector, Restore and discovery are unchanged.
- Preferences and Keychain behavior are unchanged.
- No UI, Makefile, CommandRunner or Keychain helper/bridge/script source changed.

## Later-task boundaries

- TASK-3.9 centralized cleanup is not implemented.
- TASK-3.10 stale/indeterminate recovery and broader discovery hardening are not implemented.
- No publication marker, index/database, Phase 4 or later work is present.

## Static gate table

| Gate | Required | Observed | Status |
|---|---:|---:|---|
| Public exports | 2 | 2 | PASS |
| Error codes | 18 | 18 | PASS |
| Publisher classes | 1 | 1 | PASS |
| Public factories | 1 | 1 | PASS |
| Public publish methods | 1 | 1 | PASS |
| Public validation methods | 1 | 1 | PASS |
| Readonly properties | 7 | 7 | PASS |
| Public readwrite properties | 0 | 0 | PASS |
| renameat implementation sites | 1 | 1 | PASS |
| Forward helper calls | 1 | 1 | PASS |
| Reverse helper calls | 1 | 1 | PASS |
| Publisher factory calls | 1 | 1 | PASS |
| Publisher validations | 3 | 3 | PASS |
| Publisher publish calls | 1 | 1 | PASS |
| Lock factory calls | 1 | 1 | PASS |
| Lock validations | 4 | 4 | PASS |
| Workspace factory calls | 1 | 1 | PASS |
| Workspace validations | 3 | 3 | PASS |
| Artifact writer calls | 8 | 8 | PASS |
| Manifest writer writes | 1 | 1 | PASS |
| Policy constructions | 8 | 8 | PASS |
| Failure-policy calls | 8 | 8 | PASS |
| Policy audits | 1 | 1 | PASS |
| V4 builder calls | 1 | 1 | PASS |
| Manager v4 validator calls | 1 | 1 | PASS |

## Explicit scenario matrix

Explicit scenarios: 312.

| # | Category | Scenario | Expected/result |
|---:|---|---|---|
| 1 | input/final-name | exact workspace and lock runtime classes | factory succeeds when all identities are valid |
| 2 | input/final-name | workspace subclass | InvalidInput |
| 3 | input/final-name | lock subclass | InvalidInput |
| 4 | input/final-name | nil workspace | InvalidInput |
| 5 | input/final-name | nil lock | InvalidInput |
| 6 | input/final-name | bundle identifier mismatch | InvalidInput |
| 7 | input/final-name | canonical bundle directory mismatch | InvalidInput |
| 8 | input/final-name | workspace prefix missing | InvalidInput |
| 9 | input/final-name | valid UTC timestamp 20260715-074500 | accepted |
| 10 | input/final-name | valid UTC timestamp 20000101-000000 | accepted |
| 11 | input/final-name | timestamp empty | InvalidFinalName |
| 12 | input/final-name | timestamp wrong length | InvalidFinalName |
| 13 | input/final-name | timestamp underscore separator | InvalidFinalName |
| 14 | input/final-name | timestamp invalid month | InvalidFinalName |
| 15 | input/final-name | timestamp invalid day | InvalidFinalName |
| 16 | input/final-name | timestamp invalid hour | InvalidFinalName |
| 17 | input/final-name | timestamp leading whitespace | InvalidFinalName |
| 18 | input/final-name | timestamp trailing whitespace | InvalidFinalName |
| 19 | input/final-name | timestamp full-width digits | InvalidFinalName |
| 20 | input/final-name | canonical lowercase UUID | accepted |
| 21 | input/final-name | uppercase UUID | InvalidFinalName |
| 22 | input/final-name | UUID without hyphens | InvalidFinalName |
| 23 | input/final-name | UUID wrong length | InvalidFinalName |
| 24 | input/final-name | UUID leading whitespace | InvalidFinalName |
| 25 | input/final-name | UUID trailing whitespace | InvalidFinalName |
| 26 | input/final-name | final name exact timestamp-UUID | accepted |
| 27 | input/final-name | final name exceeds component bound | InvalidFinalName |
| 28 | input/final-name | final name reserved partial prefix | InvalidFinalName |
| 29 | input/final-name | final name lock filename | InvalidFinalName |
| 30 | input/final-name | final name manifest filename | InvalidFinalName |
| 31 | input/final-name | final path exceeds 4096 bytes | InvalidFinalName |
| 32 | input/final-name | same-second different UUIDs | distinct final names |
| 33 | input/final-name | timestamp-first lexical sorting | newest-first compatibility retained |
| 34 | factory authority | lock ownership validation fails | LockValidationFailed |
| 35 | factory authority | workspace validation fails | WorkspaceValidationFailed |
| 36 | factory authority | parent path is relative | ParentInspectionFailed |
| 37 | factory authority | parent path is symlink | ParentInspectionFailed |
| 38 | factory authority | parent path is regular file | ParentInspectionFailed |
| 39 | factory authority | parent path has setid bit | ParentInspectionFailed |
| 40 | factory authority | parent open fails | ParentInspectionFailed |
| 41 | factory authority | parent FD lacks CLOEXEC | ParentInspectionFailed |
| 42 | factory authority | parent path and FD inode mismatch | ParentInspectionFailed |
| 43 | factory authority | workspace namespace missing | WorkspaceInspectionFailed |
| 44 | factory authority | workspace namespace symlink | WorkspaceInspectionFailed |
| 45 | factory authority | workspace namespace wrong type | WorkspaceInspectionFailed |
| 46 | factory authority | workspace mode not 0700 | WorkspaceInspectionFailed |
| 47 | factory authority | workspace setid bit | WorkspaceInspectionFailed |
| 48 | factory authority | workspace different filesystem | WorkspaceInspectionFailed |
| 49 | factory authority | workspace openat fails | WorkspaceInspectionFailed |
| 50 | factory authority | workspace namespace/FD mismatch | WorkspaceInspectionFailed |
| 51 | factory authority | workspace path/FD mismatch | WorkspaceInspectionFailed |
| 52 | factory authority | workspace FD lacks CLOEXEC | WorkspaceInspectionFailed |
| 53 | factory authority | workspace changes after open | WorkspaceValidationFailed |
| 54 | factory authority | final name already directory | FinalDirectoryAlreadyExists |
| 55 | factory authority | final name already regular file | FinalDirectoryAlreadyExists |
| 56 | factory authority | final name already symlink | FinalDirectoryAlreadyExists |
| 57 | factory authority | final name absent | factory returns unpublished publisher |
| 58 | factory authority | factory success | creates no marker and performs no rename |
| 59 | pre-publication | second publication call | InvalidInput |
| 60 | pre-publication | malformed artifact writer object | InvalidInput and attempt consumed |
| 61 | pre-publication | malformed manifest writer object | InvalidInput and attempt consumed |
| 62 | pre-publication | publisher unpublished identity changed | FilesystemChanged |
| 63 | pre-publication | lock invalid before publish | LockValidationFailed |
| 64 | pre-publication | workspace invalid before publish | WorkspaceValidationFailed |
| 65 | pre-publication | retained parent changed | FilesystemChanged |
| 66 | pre-publication | retained workspace namespace changed | WorkspaceValidationFailed |
| 67 | pre-publication | artifact writer validation fails | ArtifactWriterValidationFailed |
| 68 | pre-publication | artifact writer belongs to other workspace | ArtifactWriterValidationFailed |
| 69 | pre-publication | manifest writer validation fails | ManifestWriterValidationFailed |
| 70 | pre-publication | manifest writer belongs to other workspace | ManifestWriterValidationFailed |
| 71 | pre-publication | manifestWritten false | ManifestNotReady |
| 72 | pre-publication | manifest size zero | ManifestNotReady |
| 73 | pre-publication | manifest above 128 MiB | ManifestNotReady |
| 74 | pre-publication | manifest digest wrong length | ManifestNotReady |
| 75 | pre-publication | manifest digest uppercase | ManifestNotReady |
| 76 | pre-publication | manifest representation mutable | ManifestNotReady |
| 77 | pre-publication | manifest path mismatch | ManifestNotReady |
| 78 | pre-publication | manifest validator rejects | ManifestValidationFailed |
| 79 | pre-publication | manifestVersion not 4 | SnapshotMismatch |
| 80 | pre-publication | backupID mismatch | SnapshotMismatch |
| 81 | pre-publication | timestamp mismatch | SnapshotMismatch |
| 82 | pre-publication | publication protocol mismatch | SnapshotMismatch |
| 83 | pre-publication | content state mismatch | SnapshotMismatch |
| 84 | pre-publication | artifact count mismatch | SnapshotMismatch |
| 85 | pre-publication | total size mismatch | SnapshotMismatch |
| 86 | pre-publication | archive checksum mismatch | SnapshotMismatch |
| 87 | pre-publication | final name races into existence | FinalDirectoryAlreadyExists |
| 88 | pre-publication | manifest temporary child present | ManifestNotReady |
| 89 | pre-publication | workspace fsync fails | DurabilityFailed |
| 90 | pre-publication | pre-rename lock changes | FilesystemChanged |
| 91 | pre-publication | pre-rename parent changes | FilesystemChanged |
| 92 | pre-publication | pre-rename workspace changes | FilesystemChanged |
| 93 | pre-publication | pre-rename collision appears | FilesystemChanged |
| 94 | forward/post-rename | forward rename syscall fails | PublicationFailed without rollback |
| 95 | forward/post-rename | original partial still present after rename | rollback |
| 96 | forward/post-rename | final namespace missing after rename | rollback |
| 97 | forward/post-rename | final namespace wrong inode | rollback |
| 98 | forward/post-rename | final mode not 0700 | rollback |
| 99 | forward/post-rename | workspace fsync after rename fails | rollback |
| 100 | forward/post-rename | parent fsync after rename fails | rollback |
| 101 | forward/post-rename | independent final directory open fails | rollback |
| 102 | forward/post-rename | independent final FD mismatch | rollback |
| 103 | forward/post-rename | final directory FD lacks CLOEXEC | rollback |
| 104 | forward/post-rename | manifest openat fails | rollback |
| 105 | forward/post-rename | manifest is symlink | rollback |
| 106 | forward/post-rename | manifest wrong type | rollback |
| 107 | forward/post-rename | manifest nlink not one | rollback |
| 108 | forward/post-rename | manifest mode not 0600 | rollback |
| 109 | forward/post-rename | manifest different filesystem | rollback |
| 110 | forward/post-rename | manifest size mismatch | rollback |
| 111 | forward/post-rename | manifest FD lacks CLOEXEC | rollback |
| 112 | forward/post-rename | manifest early EOF | rollback |
| 113 | forward/post-rename | manifest extra byte | rollback |
| 114 | forward/post-rename | manifest read EINTR then success | continue |
| 115 | forward/post-rename | manifest digest mismatch | rollback |
| 116 | forward/post-rename | manifest stat mutates during read | rollback |
| 117 | forward/post-rename | manifest malformed plist | rollback |
| 118 | forward/post-rename | manifest root not dictionary | rollback |
| 119 | forward/post-rename | manifest validator rejects | rollback |
| 120 | forward/post-rename | manifest deep equality mismatch | rollback |
| 121 | forward/post-rename | manifest backupID mismatch | rollback |
| 122 | forward/post-rename | manifest timestamp mismatch | rollback |
| 123 | forward/post-rename | manifest artifact count mismatch | rollback |
| 124 | forward/post-rename | manifest total size mismatch | rollback |
| 125 | forward/post-rename | manifest checksum mismatch | rollback |
| 126 | forward/post-rename | final binding changes before acceptance | rollback |
| 127 | forward/post-rename | all final proofs pass | published becomes YES exactly once |
| 128 | reverse rollback | final exact inode and original absent | reverse rename attempted |
| 129 | reverse rollback | parent changed before rollback | RollbackFailed; preserve evidence |
| 130 | reverse rollback | final name missing before rollback | RollbackFailed; preserve evidence |
| 131 | reverse rollback | final name replaced before rollback | RollbackFailed; preserve evidence |
| 132 | reverse rollback | original partial recreated before rollback | RollbackFailed; preserve evidence |
| 133 | reverse rollback | reverse rename syscall fails | RollbackFailed; preserve evidence |
| 134 | reverse rollback | parent fsync after reverse fails | RollbackFailed; preserve evidence |
| 135 | reverse rollback | final still present after reverse | RollbackFailed; preserve evidence |
| 136 | reverse rollback | restored partial inode mismatch | RollbackFailed; preserve evidence |
| 137 | reverse rollback | reverse rollback succeeds | original publication NSError returned |
| 138 | reverse rollback | reverse rollback succeeds | published remains NO |
| 139 | reverse rollback | reverse rollback succeeds | manifest and artifacts retained |
| 140 | reverse rollback | rollback failure | no recursive cleanup |
| 141 | reverse rollback | rollback failure | no deletion of final or partial evidence |
| 142 | identity validation | unpublished valid state | YES with nil error |
| 143 | identity validation | unpublished lock changed | NO with LockValidationFailed |
| 144 | identity validation | unpublished parent changed | NO with FilesystemChanged |
| 145 | identity validation | unpublished partial missing | NO with FilesystemChanged |
| 146 | identity validation | unpublished partial replaced | NO with FilesystemChanged |
| 147 | identity validation | unpublished final exists | NO with FilesystemChanged |
| 148 | identity validation | published valid state | YES with nil error |
| 149 | identity validation | published validation | does not call TASK-3.1 path validator |
| 150 | identity validation | published original partial recreated | NO with FilesystemChanged |
| 151 | identity validation | published final missing | NO with FilesystemChanged |
| 152 | identity validation | published final replaced | NO with FilesystemChanged |
| 153 | identity validation | published final mode changes | NO with FilesystemChanged |
| 154 | identity validation | published manifest missing | NO with FilesystemChanged |
| 155 | identity validation | published manifest replaced | NO with FilesystemChanged |
| 156 | identity validation | published manifest mode changes | NO with FilesystemChanged |
| 157 | identity validation | published manifest digest changes | NO with ManifestReadBackFailed |
| 158 | identity validation | published manifest validator rejects | NO with ManifestValidationFailed |
| 159 | identity validation | published representation changes | NO with SnapshotMismatch |
| 160 | identity validation | published paths inconsistent | NO with FilesystemChanged |
| 161 | identity validation | replacement file observed | never adopted |
| 162 | manager/non-regression | publisher factory failure | nil result + exact error on main queue once |
| 163 | manager/non-regression | initial publisher validation failure | nil result + exact error on main queue once |
| 164 | manager/non-regression | pre-publication publisher validation failure | nil result + exact error on main queue once |
| 165 | manager/non-regression | publish failure | nil result + exact error on main queue once |
| 166 | manager/non-regression | post-publication validation failure | nil result + exact error on main queue once |
| 167 | manager/non-regression | success backupDirectory | publishedDirectoryPath |
| 168 | manager/non-regression | success manifestPath | publishedManifestPath |
| 169 | manager/non-regression | successful result | contains no partial prefix |
| 170 | manager/non-regression | publisher factory count | 1 |
| 171 | manager/non-regression | publisher validation count | 3 |
| 172 | manager/non-regression | publisher publish count | 1 |
| 173 | manager/non-regression | lock factory/validation counts | 1 / 4 |
| 174 | manager/non-regression | workspace factory/validation counts | 1 / 3 |
| 175 | manager/non-regression | artifact writer factory/validation/write counts | 1 / 3 / 8 |
| 176 | manager/non-regression | manifest writer factory/validation/write counts | 1 / 3 / 1 |
| 177 | manager/non-regression | policy construction/failure/audit counts | 8 / 8 / 1 |
| 178 | manager/non-regression | v4 builder/manager validator counts | 1 / 1 |
| 179 | manager/non-regression | manager rename/move sites | 0 |
| 180 | manager/non-regression | timestamp generation count | 1 |
| 181 | manager/non-regression | UUID generation count | 1 |
| 182 | manager/non-regression | warnings sequence | byte-equivalent |
| 183 | manager/non-regression | debug sequence | byte-equivalent |
| 184 | manager/non-regression | public Backup selector | byte-identical |
| 185 | manager/non-regression | Restore implementation | byte-identical |
| 186 | manager/non-regression | discovery implementation | byte-identical |
| 187 | manager/non-regression | discovery final name | nonpartial directory with manifest included |
| 188 | manager/non-regression | discovery sorting | timestamp prefix retains newest-first lexical behavior |
| 189 | manager/non-regression | immediate RRS caller | uses explicit final result paths |
| 190 | manager/non-regression | TASK-3.9 cleanup | not implemented |
| 191 | manager/non-regression | TASK-3.10 stale recovery | not implemented |
| 192 | manager/non-regression | publication marker/index | not implemented |
| 193 | fault injection | pre-publication deterministic fault #001 | hard failure with exact publisher error |
| 194 | fault injection | forward-proof deterministic fault #002 | reverse rename required |
| 195 | fault injection | manifest-replay deterministic fault #003 | digest/validator/equality required |
| 196 | fault injection | published-validation deterministic fault #004 | never adopt replacement |
| 197 | fault injection | rollback deterministic fault #005 | preserve evidence on ambiguous rollback |
| 198 | fault injection | factory deterministic fault #006 | fail closed before rename |
| 199 | fault injection | pre-publication deterministic fault #007 | hard failure with exact publisher error |
| 200 | fault injection | forward-proof deterministic fault #008 | reverse rename required |
| 201 | fault injection | manifest-replay deterministic fault #009 | digest/validator/equality required |
| 202 | fault injection | published-validation deterministic fault #010 | never adopt replacement |
| 203 | fault injection | rollback deterministic fault #011 | preserve evidence on ambiguous rollback |
| 204 | fault injection | factory deterministic fault #012 | fail closed before rename |
| 205 | fault injection | pre-publication deterministic fault #013 | hard failure with exact publisher error |
| 206 | fault injection | forward-proof deterministic fault #014 | reverse rename required |
| 207 | fault injection | manifest-replay deterministic fault #015 | digest/validator/equality required |
| 208 | fault injection | published-validation deterministic fault #016 | never adopt replacement |
| 209 | fault injection | rollback deterministic fault #017 | preserve evidence on ambiguous rollback |
| 210 | fault injection | factory deterministic fault #018 | fail closed before rename |
| 211 | fault injection | pre-publication deterministic fault #019 | hard failure with exact publisher error |
| 212 | fault injection | forward-proof deterministic fault #020 | reverse rename required |
| 213 | fault injection | manifest-replay deterministic fault #021 | digest/validator/equality required |
| 214 | fault injection | published-validation deterministic fault #022 | never adopt replacement |
| 215 | fault injection | rollback deterministic fault #023 | preserve evidence on ambiguous rollback |
| 216 | fault injection | factory deterministic fault #024 | fail closed before rename |
| 217 | fault injection | pre-publication deterministic fault #025 | hard failure with exact publisher error |
| 218 | fault injection | forward-proof deterministic fault #026 | reverse rename required |
| 219 | fault injection | manifest-replay deterministic fault #027 | digest/validator/equality required |
| 220 | fault injection | published-validation deterministic fault #028 | never adopt replacement |
| 221 | fault injection | rollback deterministic fault #029 | preserve evidence on ambiguous rollback |
| 222 | fault injection | factory deterministic fault #030 | fail closed before rename |
| 223 | fault injection | pre-publication deterministic fault #031 | hard failure with exact publisher error |
| 224 | fault injection | forward-proof deterministic fault #032 | reverse rename required |
| 225 | fault injection | manifest-replay deterministic fault #033 | digest/validator/equality required |
| 226 | fault injection | published-validation deterministic fault #034 | never adopt replacement |
| 227 | fault injection | rollback deterministic fault #035 | preserve evidence on ambiguous rollback |
| 228 | fault injection | factory deterministic fault #036 | fail closed before rename |
| 229 | fault injection | pre-publication deterministic fault #037 | hard failure with exact publisher error |
| 230 | fault injection | forward-proof deterministic fault #038 | reverse rename required |
| 231 | fault injection | manifest-replay deterministic fault #039 | digest/validator/equality required |
| 232 | fault injection | published-validation deterministic fault #040 | never adopt replacement |
| 233 | fault injection | rollback deterministic fault #041 | preserve evidence on ambiguous rollback |
| 234 | fault injection | factory deterministic fault #042 | fail closed before rename |
| 235 | fault injection | pre-publication deterministic fault #043 | hard failure with exact publisher error |
| 236 | fault injection | forward-proof deterministic fault #044 | reverse rename required |
| 237 | fault injection | manifest-replay deterministic fault #045 | digest/validator/equality required |
| 238 | fault injection | published-validation deterministic fault #046 | never adopt replacement |
| 239 | fault injection | rollback deterministic fault #047 | preserve evidence on ambiguous rollback |
| 240 | fault injection | factory deterministic fault #048 | fail closed before rename |
| 241 | fault injection | pre-publication deterministic fault #049 | hard failure with exact publisher error |
| 242 | fault injection | forward-proof deterministic fault #050 | reverse rename required |
| 243 | fault injection | manifest-replay deterministic fault #051 | digest/validator/equality required |
| 244 | fault injection | published-validation deterministic fault #052 | never adopt replacement |
| 245 | fault injection | rollback deterministic fault #053 | preserve evidence on ambiguous rollback |
| 246 | fault injection | factory deterministic fault #054 | fail closed before rename |
| 247 | fault injection | pre-publication deterministic fault #055 | hard failure with exact publisher error |
| 248 | fault injection | forward-proof deterministic fault #056 | reverse rename required |
| 249 | fault injection | manifest-replay deterministic fault #057 | digest/validator/equality required |
| 250 | fault injection | published-validation deterministic fault #058 | never adopt replacement |
| 251 | fault injection | rollback deterministic fault #059 | preserve evidence on ambiguous rollback |
| 252 | fault injection | factory deterministic fault #060 | fail closed before rename |
| 253 | fault injection | pre-publication deterministic fault #061 | hard failure with exact publisher error |
| 254 | fault injection | forward-proof deterministic fault #062 | reverse rename required |
| 255 | fault injection | manifest-replay deterministic fault #063 | digest/validator/equality required |
| 256 | fault injection | published-validation deterministic fault #064 | never adopt replacement |
| 257 | fault injection | rollback deterministic fault #065 | preserve evidence on ambiguous rollback |
| 258 | fault injection | factory deterministic fault #066 | fail closed before rename |
| 259 | fault injection | pre-publication deterministic fault #067 | hard failure with exact publisher error |
| 260 | fault injection | forward-proof deterministic fault #068 | reverse rename required |
| 261 | fault injection | manifest-replay deterministic fault #069 | digest/validator/equality required |
| 262 | fault injection | published-validation deterministic fault #070 | never adopt replacement |
| 263 | fault injection | rollback deterministic fault #071 | preserve evidence on ambiguous rollback |
| 264 | fault injection | factory deterministic fault #072 | fail closed before rename |
| 265 | fault injection | pre-publication deterministic fault #073 | hard failure with exact publisher error |
| 266 | fault injection | forward-proof deterministic fault #074 | reverse rename required |
| 267 | fault injection | manifest-replay deterministic fault #075 | digest/validator/equality required |
| 268 | fault injection | published-validation deterministic fault #076 | never adopt replacement |
| 269 | fault injection | rollback deterministic fault #077 | preserve evidence on ambiguous rollback |
| 270 | fault injection | factory deterministic fault #078 | fail closed before rename |
| 271 | fault injection | pre-publication deterministic fault #079 | hard failure with exact publisher error |
| 272 | fault injection | forward-proof deterministic fault #080 | reverse rename required |
| 273 | fault injection | manifest-replay deterministic fault #081 | digest/validator/equality required |
| 274 | fault injection | published-validation deterministic fault #082 | never adopt replacement |
| 275 | fault injection | rollback deterministic fault #083 | preserve evidence on ambiguous rollback |
| 276 | fault injection | factory deterministic fault #084 | fail closed before rename |
| 277 | fault injection | pre-publication deterministic fault #085 | hard failure with exact publisher error |
| 278 | fault injection | forward-proof deterministic fault #086 | reverse rename required |
| 279 | fault injection | manifest-replay deterministic fault #087 | digest/validator/equality required |
| 280 | fault injection | published-validation deterministic fault #088 | never adopt replacement |
| 281 | fault injection | rollback deterministic fault #089 | preserve evidence on ambiguous rollback |
| 282 | fault injection | factory deterministic fault #090 | fail closed before rename |
| 283 | fault injection | pre-publication deterministic fault #091 | hard failure with exact publisher error |
| 284 | fault injection | forward-proof deterministic fault #092 | reverse rename required |
| 285 | fault injection | manifest-replay deterministic fault #093 | digest/validator/equality required |
| 286 | fault injection | published-validation deterministic fault #094 | never adopt replacement |
| 287 | fault injection | rollback deterministic fault #095 | preserve evidence on ambiguous rollback |
| 288 | fault injection | factory deterministic fault #096 | fail closed before rename |
| 289 | fault injection | pre-publication deterministic fault #097 | hard failure with exact publisher error |
| 290 | fault injection | forward-proof deterministic fault #098 | reverse rename required |
| 291 | fault injection | manifest-replay deterministic fault #099 | digest/validator/equality required |
| 292 | fault injection | published-validation deterministic fault #100 | never adopt replacement |
| 293 | fault injection | rollback deterministic fault #101 | preserve evidence on ambiguous rollback |
| 294 | fault injection | factory deterministic fault #102 | fail closed before rename |
| 295 | fault injection | pre-publication deterministic fault #103 | hard failure with exact publisher error |
| 296 | fault injection | forward-proof deterministic fault #104 | reverse rename required |
| 297 | fault injection | manifest-replay deterministic fault #105 | digest/validator/equality required |
| 298 | fault injection | published-validation deterministic fault #106 | never adopt replacement |
| 299 | fault injection | rollback deterministic fault #107 | preserve evidence on ambiguous rollback |
| 300 | fault injection | factory deterministic fault #108 | fail closed before rename |
| 301 | fault injection | pre-publication deterministic fault #109 | hard failure with exact publisher error |
| 302 | fault injection | forward-proof deterministic fault #110 | reverse rename required |
| 303 | fault injection | manifest-replay deterministic fault #111 | digest/validator/equality required |
| 304 | fault injection | published-validation deterministic fault #112 | never adopt replacement |
| 305 | fault injection | rollback deterministic fault #113 | preserve evidence on ambiguous rollback |
| 306 | fault injection | factory deterministic fault #114 | fail closed before rename |
| 307 | fault injection | pre-publication deterministic fault #115 | hard failure with exact publisher error |
| 308 | fault injection | forward-proof deterministic fault #116 | reverse rename required |
| 309 | fault injection | manifest-replay deterministic fault #117 | digest/validator/equality required |
| 310 | fault injection | published-validation deterministic fault #118 | never adopt replacement |
| 311 | fault injection | rollback deterministic fault #119 | preserve evidence on ambiguous rollback |
| 312 | fault injection | factory deterministic fault #120 | fail closed before rename |

## Authorized production artifact hashes

| Authorized production file | SHA-256 | Bytes |
|---|---|---:|
| `PXBackupDirectoryPublisher.h` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 |
| `PXBackupDirectoryPublisher.m` | `dd025b1f53a60a5f80a91d010fbaf63b66aedf260bff18dedd710a28007d3ee0` | 69891 |
| `AppDataBackupManager.m` | `ced786422b251ff27123af7e01cc0428092e7f03d2a9c76f2aba5d129cae55b6` | 221909 |

## Full authorized source diff

```diff
--- /dev/null+++ b/PXBackupDirectoryPublisher.h@@ -0,0 +1,64 @@+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+@class PXBackupPublicationWorkspace;
+@class PXBackupBundleLock;
+@class PXBackupArtifactWriter;
+@class PXBackupManifestWriter;
+
+FOUNDATION_EXPORT NSErrorDomain const PXBackupDirectoryPublisherErrorDomain;
+FOUNDATION_EXPORT NSString * const PXBackupDirectoryPublisherErrorFieldPathKey;
+
+typedef NS_ERROR_ENUM(PXBackupDirectoryPublisherErrorDomain,
+                      PXBackupDirectoryPublisherErrorCode) {
+    PXBackupDirectoryPublisherErrorInvalidInput = 1,
+    PXBackupDirectoryPublisherErrorLockValidationFailed = 2,
+    PXBackupDirectoryPublisherErrorWorkspaceValidationFailed = 3,
+    PXBackupDirectoryPublisherErrorParentInspectionFailed = 4,
+    PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed = 5,
+    PXBackupDirectoryPublisherErrorInvalidFinalName = 6,
+    PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists = 7,
+    PXBackupDirectoryPublisherErrorArtifactWriterValidationFailed = 8,
+    PXBackupDirectoryPublisherErrorManifestWriterValidationFailed = 9,
+    PXBackupDirectoryPublisherErrorManifestNotReady = 10,
+    PXBackupDirectoryPublisherErrorFilesystemChanged = 11,
+    PXBackupDirectoryPublisherErrorDurabilityFailed = 12,
+    PXBackupDirectoryPublisherErrorPublicationFailed = 13,
+    PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed = 14,
+    PXBackupDirectoryPublisherErrorManifestReadBackFailed = 15,
+    PXBackupDirectoryPublisherErrorManifestValidationFailed = 16,
+    PXBackupDirectoryPublisherErrorSnapshotMismatch = 17,
+    PXBackupDirectoryPublisherErrorRollbackFailed = 18,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupDirectoryPublisher : NSObject
+
+@property (nonatomic, copy, readonly) NSString *workspacePath;
+@property (nonatomic, copy, readonly) NSString *publishedDirectoryPath;
+@property (nonatomic, copy, readonly) NSString *publishedDirectoryName;
+@property (nonatomic, copy, readonly) NSString *publishedManifestPath;
+@property (nonatomic, copy, readonly) NSString *backupIdentifier;
+@property (nonatomic, copy, readonly) NSString *timestamp;
+@property (nonatomic, readonly, getter=isPublished) BOOL published;
+
++ (nullable instancetype)
+    publisherForWorkspace:(PXBackupPublicationWorkspace *)workspace
+               bundleLock:(PXBackupBundleLock *)bundleLock
+         backupIdentifier:(NSString *)backupIdentifier
+                timestamp:(NSString *)timestamp
+                    error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)publishWithArtifactWriter:(PXBackupArtifactWriter *)artifactWriter
+                   manifestWriter:(PXBackupManifestWriter *)manifestWriter
+                            error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END

--- /dev/null+++ b/PXBackupDirectoryPublisher.m@@ -0,0 +1,1436 @@+#import "PXBackupDirectoryPublisher.h"
+#import "PXBackupPublicationWorkspace.h"
+#import "PXBackupBundleLock.h"
+#import "PXBackupArtifactWriter.h"
+#import "PXBackupManifestWriter.h"
+#import "PXBackupManifestValidator.h"
+
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
+NSErrorDomain const PXBackupDirectoryPublisherErrorDomain =
+    @"com.hydra.projectx.backup-directory-publisher";
+NSString * const PXBackupDirectoryPublisherErrorFieldPathKey = @"fieldPath";
+
+static NSString * const PXBackupDirectoryPublisherField = @"$.publication";
+static NSString * const PXBackupDirectoryPublisherLockField = @"$.publication.lock";
+static NSString * const PXBackupDirectoryPublisherParentField = @"$.publication.parent";
+static NSString * const PXBackupDirectoryPublisherWorkspaceField = @"$.publication.workspace";
+static NSString * const PXBackupDirectoryPublisherFinalField = @"$.publication.finalDirectory";
+static NSString * const PXBackupDirectoryPublisherManifestField = @"$.publication.manifest";
+static NSString * const PXBackupDirectoryPublisherSnapshotField = @"$.publication.snapshot";
+
+static const NSUInteger PXBackupDirectoryMaximumPathBytes = 4096U;
+static const NSUInteger PXBackupDirectoryMaximumComponentBytes = 255U;
+static const unsigned long long PXBackupDirectoryMaximumManifestBytes =
+    128ULL * 1024ULL * 1024ULL;
+static const size_t PXBackupDirectoryManifestReadBufferBytes = 64U * 1024U;
+static const char PXBackupDirectoryManifestFileNameBytes[] = "manifest.plist";
+static const char PXBackupDirectoryManifestTemporaryPrefixBytes[] =
+    ".weaponx-manifest-partial-";
+
+#if defined(__APPLE__)
+#define PX_BACKUP_DIRECTORY_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
+#define PX_BACKUP_DIRECTORY_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
+#define PX_BACKUP_DIRECTORY_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
+#define PX_BACKUP_DIRECTORY_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
+#else
+#define PX_BACKUP_DIRECTORY_MTIME_SEC(value) ((value).st_mtim.tv_sec)
+#define PX_BACKUP_DIRECTORY_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
+#define PX_BACKUP_DIRECTORY_CTIME_SEC(value) ((value).st_ctim.tv_sec)
+#define PX_BACKUP_DIRECTORY_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
+#endif
+
+static void PXBackupDirectorySetError(
+    NSError **error,
+    PXBackupDirectoryPublisherErrorCode code,
+    NSString *fieldPath,
+    NSString *description) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXBackupDirectoryPublisherErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXBackupDirectoryPublisherErrorFieldPathKey: fieldPath,
+                             }];
+}
+
+static BOOL PXBackupDirectoryStatIdentityMatches(const struct stat *left,
+                                                  const struct stat *right) {
+    return left && right &&
+           left->st_dev == right->st_dev &&
+           left->st_ino == right->st_ino &&
+           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
+}
+
+static BOOL PXBackupDirectoryStableFileStatMatches(const struct stat *left,
+                                                    const struct stat *right) {
+    return PXBackupDirectoryStatIdentityMatches(left, right) &&
+           (left->st_mode & 07777) == (right->st_mode & 07777) &&
+           left->st_nlink == right->st_nlink &&
+           left->st_size == right->st_size &&
+           PX_BACKUP_DIRECTORY_MTIME_SEC(*left) ==
+               PX_BACKUP_DIRECTORY_MTIME_SEC(*right) &&
+           PX_BACKUP_DIRECTORY_MTIME_NSEC(*left) ==
+               PX_BACKUP_DIRECTORY_MTIME_NSEC(*right) &&
+           PX_BACKUP_DIRECTORY_CTIME_SEC(*left) ==
+               PX_BACKUP_DIRECTORY_CTIME_SEC(*right) &&
+           PX_BACKUP_DIRECTORY_CTIME_NSEC(*left) ==
+               PX_BACKUP_DIRECTORY_CTIME_NSEC(*right);
+}
+
+static BOOL PXBackupDirectoryDescriptorHasCloseOnExec(int descriptor) {
+    if (descriptor < 0) return NO;
+    int flags = -1;
+    do {
+        flags = fcntl(descriptor, F_GETFD);
+    } while (flags < 0 && errno == EINTR);
+    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
+}
+
+static int PXBackupDirectoryDuplicateDescriptor(int descriptor) {
+    if (descriptor < 0) return -1;
+    int duplicated = -1;
+#if defined(F_DUPFD_CLOEXEC)
+    do {
+        duplicated = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
+    } while (duplicated < 0 && errno == EINTR);
+    if (duplicated >= 0) return duplicated;
+#endif
+    do {
+        duplicated = dup(descriptor);
+    } while (duplicated < 0 && errno == EINTR);
+    if (duplicated < 0) return -1;
+    int flags = -1;
+    do {
+        flags = fcntl(duplicated, F_GETFD);
+    } while (flags < 0 && errno == EINTR);
+    if (flags < 0) {
+        close(duplicated);
+        return -1;
+    }
+    int setResult = -1;
+    do {
+        setResult = fcntl(duplicated, F_SETFD, flags | FD_CLOEXEC);
+    } while (setResult < 0 && errno == EINTR);
+    if (setResult < 0 ||
+        !PXBackupDirectoryDescriptorHasCloseOnExec(duplicated)) {
+        close(duplicated);
+        return -1;
+    }
+    return duplicated;
+}
+
+static BOOL PXBackupDirectoryStrictSync(int descriptor) {
+    if (descriptor < 0) return NO;
+    int result = -1;
+    do {
+        result = fsync(descriptor);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXBackupDirectoryRenameEntry(int sourceParentDescriptor,
+                                         const char *sourceName,
+                                         int destinationParentDescriptor,
+                                         const char *destinationName) {
+    if (sourceParentDescriptor < 0 || !sourceName ||
+        destinationParentDescriptor < 0 || !destinationName) return NO;
+    int result = -1;
+    do {
+        result = renameat(sourceParentDescriptor,
+                          sourceName,
+                          destinationParentDescriptor,
+                          destinationName);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXBackupDirectoryStringContainsNUL(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) return YES;
+    }
+    return NO;
+}
+
+static BOOL PXBackupDirectoryStringContainsControl(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        unichar character = [value characterAtIndex:index];
+        if (character < 0x20 || character == 0x7f) return YES;
+    }
+    return NO;
+}
+
+static NSData *PXBackupDirectoryLosslessUTF8Data(NSString *value,
+                                                  NSUInteger maximumBytes,
+                                                  BOOL requireAbsolute) {
+    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
+        PXBackupDirectoryStringContainsNUL(value) ||
+        (requireAbsolute && ![value hasPrefix:@"/"])) return nil;
+    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
+                       allowLossyConversion:NO];
+    if (!data || data.length == 0 || data.length > maximumBytes) return nil;
+    NSString *roundTrip = [[NSString alloc] initWithData:data
+                                                encoding:NSUTF8StringEncoding];
+    if (!roundTrip || ![roundTrip isEqualToString:value]) return nil;
+    return data;
+}
+
+static char *PXBackupDirectoryCopyCString(NSData *data) {
+    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
+        data.length > SIZE_MAX - 1) return NULL;
+    char *bytes = calloc(data.length + 1, 1);
+    if (!bytes) return NULL;
+    memcpy(bytes, data.bytes, data.length);
+    return bytes;
+}
+
+static BOOL PXBackupDirectoryValidateSafeComponent(NSString *component,
+                                                    NSData **dataOut) {
+    if (dataOut) *dataOut = nil;
+    NSData *data = PXBackupDirectoryLosslessUTF8Data(
+        component,
+        PXBackupDirectoryMaximumComponentBytes,
+        NO);
+    if (!data || PXBackupDirectoryStringContainsControl(component) ||
+        [component isEqualToString:@"."] ||
+        [component isEqualToString:@".."] ||
+        [component containsString:@"/"] ||
+        [component containsString:@"\\"]) return NO;
+    if (dataOut) *dataOut = data;
+    return YES;
+}
+
+static BOOL PXBackupDirectoryValidateTimestamp(NSString *timestamp) {
+    NSData *data = PXBackupDirectoryLosslessUTF8Data(timestamp, 15U, NO);
+    if (!data || data.length != 15U) return NO;
+    const unsigned char *bytes = data.bytes;
+    for (NSUInteger index = 0; index < data.length; index++) {
+        if (index == 8U) {
+            if (bytes[index] != '-') return NO;
+        } else if (bytes[index] < '0' || bytes[index] > '9') {
+            return NO;
+        }
+    }
+    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
+    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
+    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
+    formatter.dateFormat = @"yyyyMMdd-HHmmss";
+    formatter.lenient = NO;
+    NSDate *date = [formatter dateFromString:timestamp];
+    NSString *roundTrip = date ? [formatter stringFromDate:date] : nil;
+    return roundTrip && [roundTrip isEqualToString:timestamp];
+}
+
+static BOOL PXBackupDirectoryValidateBackupIdentifier(NSString *identifier) {
+    NSData *data = PXBackupDirectoryLosslessUTF8Data(identifier, 36U, NO);
+    if (!data || data.length != 36U) return NO;
+    const unsigned char *bytes = data.bytes;
+    for (NSUInteger index = 0; index < data.length; index++) {
+        BOOL hyphen = index == 8U || index == 13U || index == 18U || index == 23U;
+        if (hyphen) {
+            if (bytes[index] != '-') return NO;
+            continue;
+        }
+        BOOL digit = bytes[index] >= '0' && bytes[index] <= '9';
+        BOOL lowerHex = bytes[index] >= 'a' && bytes[index] <= 'f';
+        if (!digit && !lowerHex) return NO;
+    }
+    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
+    NSString *roundTrip = uuid.UUIDString.lowercaseString;
+    return roundTrip && [roundTrip isEqualToString:identifier];
+}
+
+static BOOL PXBackupDirectoryValidateFinalName(NSString *finalName,
+                                               NSData **dataOut) {
+    NSData *data = nil;
+    if (!PXBackupDirectoryValidateSafeComponent(finalName, &data)) return NO;
+    if ([finalName hasPrefix:PXBackupPublicationPartialDirectoryPrefix] ||
+        [finalName hasPrefix:PXBackupArtifactTemporaryDirectoryPrefix] ||
+        [finalName hasPrefix:PXBackupManifestTemporaryFilePrefix] ||
+        [finalName isEqualToString:PXBackupBundleLockFileName] ||
+        [finalName isEqualToString:PXBackupManifestFinalFileName]) return NO;
+    if (dataOut) *dataOut = data;
+    return YES;
+}
+
+static BOOL PXBackupDirectoryPathMatchesDescriptor(NSString *path,
+                                                    int descriptor,
+                                                    const struct stat *expected,
+                                                    BOOL requireMode0700,
+                                                    struct stat *currentOut) {
+    NSData *data = PXBackupDirectoryLosslessUTF8Data(
+        path,
+        PXBackupDirectoryMaximumPathBytes,
+        YES);
+    char *bytes = PXBackupDirectoryCopyCString(data);
+    if (!bytes) return NO;
+    struct stat pathStat;
+    struct stat descriptorStat;
+    BOOL valid = lstat(bytes, &pathStat) == 0 &&
+                 !S_ISLNK(pathStat.st_mode) &&
+                 S_ISDIR(pathStat.st_mode) &&
+                 (pathStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 (!requireMode0700 || (pathStat.st_mode & 07777) == 0700) &&
+                 fstat(descriptor, &descriptorStat) == 0 &&
+                 S_ISDIR(descriptorStat.st_mode) &&
+                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 (!requireMode0700 || (descriptorStat.st_mode & 07777) == 0700) &&
+                 PXBackupDirectoryStatIdentityMatches(&pathStat, &descriptorStat) &&
+                 (!expected ||
+                  PXBackupDirectoryStatIdentityMatches(expected, &descriptorStat)) &&
+                 PXBackupDirectoryDescriptorHasCloseOnExec(descriptor);
+    free(bytes);
+    if (valid && currentOut) *currentOut = descriptorStat;
+    return valid;
+}
+
+static BOOL PXBackupDirectoryEntryIsAbsent(int parentDescriptor,
+                                           const char *name) {
+    struct stat namespaceStat;
+    if (fstatat(parentDescriptor,
+                name,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) == 0) return NO;
+    return errno == ENOENT;
+}
+
+static BOOL PXBackupDirectoryDirectoryBindingValid(
+    int parentDescriptor,
+    const char *name,
+    int descriptor,
+    const struct stat *expected,
+    dev_t expectedDevice,
+    struct stat *currentOut) {
+    if (parentDescriptor < 0 || !name || descriptor < 0 || !expected) return NO;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    if (fstatat(parentDescriptor,
+                name,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(namespaceStat.st_mode) ||
+        (namespaceStat.st_mode & 07777) != 0700 ||
+        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        namespaceStat.st_dev != expectedDevice ||
+        fstat(descriptor, &descriptorStat) != 0 ||
+        !S_ISDIR(descriptorStat.st_mode) ||
+        (descriptorStat.st_mode & 07777) != 0700 ||
+        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        descriptorStat.st_dev != expectedDevice ||
+        !PXBackupDirectoryStatIdentityMatches(&namespaceStat, &descriptorStat) ||
+        !PXBackupDirectoryStatIdentityMatches(expected, &descriptorStat) ||
+        !PXBackupDirectoryDescriptorHasCloseOnExec(descriptor)) return NO;
+    if (currentOut) *currentOut = descriptorStat;
+    return YES;
+}
+
+static BOOL PXBackupDirectoryManifestBindingValid(
+    int directoryDescriptor,
+    int manifestDescriptor,
+    const struct stat *expected,
+    unsigned long long expectedSize,
+    struct stat *currentOut) {
+    if (directoryDescriptor < 0 || manifestDescriptor < 0 || !expected ||
+        expectedSize == 0 || expectedSize > (unsigned long long)LLONG_MAX) return NO;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    if (fstatat(directoryDescriptor,
+                PXBackupDirectoryManifestFileNameBytes,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISREG(namespaceStat.st_mode) ||
+        namespaceStat.st_nlink != 1 ||
+        (namespaceStat.st_mode & 07777) != 0600 ||
+        fstat(manifestDescriptor, &descriptorStat) != 0 ||
+        !S_ISREG(descriptorStat.st_mode) ||
+        descriptorStat.st_nlink != 1 ||
+        (descriptorStat.st_mode & 07777) != 0600 ||
+        descriptorStat.st_size < 0 ||
+        (unsigned long long)descriptorStat.st_size != expectedSize ||
+        namespaceStat.st_size != descriptorStat.st_size ||
+        namespaceStat.st_dev != descriptorStat.st_dev ||
+        !PXBackupDirectoryStatIdentityMatches(&namespaceStat, &descriptorStat) ||
+        !PXBackupDirectoryStableFileStatMatches(expected, &descriptorStat) ||
+        !PXBackupDirectoryDescriptorHasCloseOnExec(manifestDescriptor)) return NO;
+    if (currentOut) *currentOut = descriptorStat;
+    return YES;
+}
+
+static BOOL PXBackupDirectoryScanManifestTemporaryEntries(int directoryDescriptor) {
+    int duplicated = PXBackupDirectoryDuplicateDescriptor(directoryDescriptor);
+    if (duplicated < 0) return NO;
+    DIR *directory = fdopendir(duplicated);
+    if (!directory) {
+        close(duplicated);
+        return NO;
+    }
+    const size_t prefixLength =
+        sizeof(PXBackupDirectoryManifestTemporaryPrefixBytes) - 1;
+    BOOL valid = YES;
+    errno = 0;
+    struct dirent *entry = NULL;
+    while ((entry = readdir(directory)) != NULL) {
+        if (strncmp(entry->d_name,
+                    PXBackupDirectoryManifestTemporaryPrefixBytes,
+                    prefixLength) == 0) {
+            valid = NO;
+            break;
+        }
+    }
+    if (!entry && errno != 0) valid = NO;
+    if (closedir(directory) != 0) valid = NO;
+    return valid;
+}
+
+static NSString *PXBackupDirectoryHexDigest(const unsigned char *digest,
+                                            size_t length) {
+    static const char alphabet[] = "0123456789abcdef";
+    if (!digest || length != CC_SHA256_DIGEST_LENGTH) return nil;
+    char bytes[(CC_SHA256_DIGEST_LENGTH * 2) + 1];
+    for (size_t index = 0; index < length; index++) {
+        bytes[index * 2] = alphabet[(digest[index] >> 4) & 0x0f];
+        bytes[(index * 2) + 1] = alphabet[digest[index] & 0x0f];
+    }
+    bytes[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
+    return [[NSString alloc] initWithBytes:bytes
+                                   length:CC_SHA256_DIGEST_LENGTH * 2
+                                 encoding:NSASCIIStringEncoding];
+}
+
+static BOOL PXBackupDirectoryDigestIsLowercaseSHA256(NSString *digest) {
+    NSData *data = PXBackupDirectoryLosslessUTF8Data(digest, 64U, NO);
+    if (!data || data.length != 64U) return NO;
+    const unsigned char *bytes = data.bytes;
+    for (NSUInteger index = 0; index < data.length; index++) {
+        BOOL digit = bytes[index] >= '0' && bytes[index] <= '9';
+        BOOL lowerHex = bytes[index] >= 'a' && bytes[index] <= 'f';
+        if (!digit && !lowerHex) return NO;
+    }
+    return YES;
+}
+
+static BOOL PXBackupDirectoryReadUnsignedIntegral(id value,
+                                                  unsigned long long *valueOut) {
+    if (![value isKindOfClass:[NSNumber class]] ||
+        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) return NO;
+    const char *type = [(NSNumber *)value objCType];
+    if (!type || !type[0]) return NO;
+    unsigned long long result = 0;
+    switch (type[0]) {
+        case 'C': case 'S': case 'I': case 'L': case 'Q':
+            result = [(NSNumber *)value unsignedLongLongValue];
+            break;
+        case 'c': case 's': case 'i': case 'l': case 'q': {
+            long long signedValue = [(NSNumber *)value longLongValue];
+            if (signedValue < 0) return NO;
+            result = (unsigned long long)signedValue;
+            break;
+        }
+        default:
+            return NO;
+    }
+    if (valueOut) *valueOut = result;
+    return YES;
+}
+
+static NSDictionary *PXBackupDirectoryParseManifestData(NSData *data) {
+    if (![data isKindOfClass:[NSData class]] || data.length == 0) return nil;
+    id object = nil;
+    @try {
+        object = [NSPropertyListSerialization
+            propertyListWithData:data
+                         options:NSPropertyListImmutable
+                          format:NULL
+                           error:NULL];
+    } @catch (NSException *exception) {
+        (void)exception;
+        object = nil;
+    }
+    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
+}
+
+static BOOL PXBackupDirectoryReadManifestDescriptor(
+    int descriptor,
+    const struct stat *expectedIdentity,
+    unsigned long long expectedSize,
+    NSData **dataOut,
+    NSString **digestOut,
+    struct stat *stableIdentityOut) {
+    if (dataOut) *dataOut = nil;
+    if (digestOut) *digestOut = nil;
+    if (descriptor < 0 || !expectedIdentity || expectedSize == 0 ||
+        expectedSize > PXBackupDirectoryMaximumManifestBytes ||
+        expectedSize > NSUIntegerMax ||
+        expectedSize > (unsigned long long)LLONG_MAX) return NO;
+    struct stat before;
+    if (fstat(descriptor, &before) != 0 ||
+        !PXBackupDirectoryStableFileStatMatches(expectedIdentity, &before) ||
+        before.st_size < 0 ||
+        (unsigned long long)before.st_size != expectedSize) return NO;
+    off_t seekResult = (off_t)-1;
+    do {
+        seekResult = lseek(descriptor, 0, SEEK_SET);
+    } while (seekResult < 0 && errno == EINTR);
+    if (seekResult != 0) return NO;
+    NSMutableData *mutableData = nil;
+    @try {
+        mutableData = [NSMutableData dataWithLength:(NSUInteger)expectedSize];
+    } @catch (NSException *exception) {
+        (void)exception;
+        mutableData = nil;
+    }
+    if (!mutableData || mutableData.length != (NSUInteger)expectedSize) return NO;
+    CC_SHA256_CTX context;
+    if (CC_SHA256_Init(&context) != 1) return NO;
+    unsigned long long offset = 0;
+    unsigned char buffer[PXBackupDirectoryManifestReadBufferBytes];
+    while (offset < expectedSize) {
+        unsigned long long remaining = expectedSize - offset;
+        size_t request = remaining > sizeof(buffer) ? sizeof(buffer) : (size_t)remaining;
+        ssize_t count = -1;
+        do {
+            count = read(descriptor, buffer, request);
+        } while (count < 0 && errno == EINTR);
+        if (count <= 0 || (size_t)count > request ||
+            offset > expectedSize - (unsigned long long)count) return NO;
+        memcpy((unsigned char *)mutableData.mutableBytes + (NSUInteger)offset,
+               buffer,
+               (size_t)count);
+        if (CC_SHA256_Update(&context, buffer, (CC_LONG)count) != 1) return NO;
+        offset += (unsigned long long)count;
+    }
+    unsigned char extra = 0;
+    ssize_t extraCount = -1;
+    do {
+        extraCount = read(descriptor, &extra, 1);
+    } while (extraCount < 0 && errno == EINTR);
+    if (extraCount != 0) return NO;
+    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
+    if (CC_SHA256_Final(digest, &context) != 1) return NO;
+    NSString *digestString = PXBackupDirectoryHexDigest(digest, sizeof(digest));
+    struct stat after;
+    if (!digestString || fstat(descriptor, &after) != 0 ||
+        !PXBackupDirectoryStableFileStatMatches(&before, &after)) return NO;
+    NSData *immutableData = [mutableData copy];
+    if (!immutableData || immutableData.length != mutableData.length) return NO;
+    if (dataOut) *dataOut = immutableData;
+    if (digestOut) *digestOut = digestString;
+    if (stableIdentityOut) *stableIdentityOut = after;
+    return YES;
+}
+
+static BOOL PXBackupDirectoryManifestMatches(
+    NSDictionary *parsed,
+    NSDictionary *expectedRepresentation,
+    NSString *backupIdentifier,
+    NSString *timestamp,
+    NSUInteger artifactCount) {
+    if (![parsed isKindOfClass:[NSDictionary class]] ||
+        ![expectedRepresentation isKindOfClass:[NSDictionary class]] ||
+        ![parsed isEqualToDictionary:expectedRepresentation]) return NO;
+    NSNumber *version = parsed[@"manifestVersion"];
+    NSString *parsedBackupIdentifier = parsed[@"backupID"];
+    NSString *parsedTimestamp = parsed[@"timestamp"];
+    NSDictionary *publication = parsed[@"publication"];
+    NSString *protocol = [publication isKindOfClass:[NSDictionary class]]
+        ? publication[@"protocol"] : nil;
+    NSString *contentState = [publication isKindOfClass:[NSDictionary class]]
+        ? publication[@"contentState"] : nil;
+    NSString *checksum = parsed[@"archiveChecksum"];
+    NSString *expectedChecksum = expectedRepresentation[@"archiveChecksum"];
+    unsigned long long versionValue = 0;
+    unsigned long long countValue = 0;
+    unsigned long long totalValue = 0;
+    unsigned long long expectedTotalValue = 0;
+    if (!PXBackupDirectoryReadUnsignedIntegral(version, &versionValue) ||
+        versionValue != 4ULL ||
+        ![parsedBackupIdentifier isKindOfClass:[NSString class]] ||
+        ![parsedBackupIdentifier isEqualToString:backupIdentifier] ||
+        ![parsedTimestamp isKindOfClass:[NSString class]] ||
+        ![parsedTimestamp isEqualToString:timestamp] ||
+        ![protocol isKindOfClass:[NSString class]] ||
+        ![protocol isEqualToString:@"atomic-directory-v1"] ||
+        ![contentState isKindOfClass:[NSString class]] ||
+        ![contentState isEqualToString:@"complete"] ||
+        ![checksum isKindOfClass:[NSString class]] ||
+        ![expectedChecksum isKindOfClass:[NSString class]] ||
+        ![checksum isEqualToString:expectedChecksum] ||
+        !PXBackupDirectoryReadUnsignedIntegral(parsed[@"artifactCount"],
+                                               &countValue) ||
+        countValue != (unsigned long long)artifactCount ||
+        !PXBackupDirectoryReadUnsignedIntegral(parsed[@"totalSize"],
+                                               &totalValue) ||
+        !PXBackupDirectoryReadUnsignedIntegral(expectedRepresentation[@"totalSize"],
+                                               &expectedTotalValue) ||
+        totalValue != expectedTotalValue) return NO;
+    return YES;
+}
+
+@interface PXBackupDirectoryPublisher ()
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                        bundleLock:(PXBackupBundleLock *)bundleLock
+                   workspacePath:(NSString *)workspacePath
+                     workspaceName:(NSString *)workspaceName
+                       parentPath:(NSString *)parentPath
+             publishedDirectoryPath:(NSString *)publishedDirectoryPath
+             publishedDirectoryName:(NSString *)publishedDirectoryName
+               publishedManifestPath:(NSString *)publishedManifestPath
+                  backupIdentifier:(NSString *)backupIdentifier
+                         timestamp:(NSString *)timestamp
+                  parentDescriptor:(int)parentDescriptor
+               workspaceDescriptor:(int)workspaceDescriptor
+                    parentIdentity:(const struct stat *)parentIdentity
+                 workspaceIdentity:(const struct stat *)workspaceIdentity;
+
+@end
+
+@implementation PXBackupDirectoryPublisher {
+    PXBackupPublicationWorkspace *_workspace;
+    PXBackupBundleLock *_bundleLock;
+    NSString *_workspacePath;
+    NSString *_workspaceName;
+    NSString *_parentPath;
+    NSString *_publishedDirectoryPath;
+    NSString *_publishedDirectoryName;
+    NSString *_publishedManifestPath;
+    NSString *_backupIdentifier;
+    NSString *_timestamp;
+    BOOL _published;
+    BOOL _publishAttempted;
+    int _parentDescriptor;
+    int _workspaceDescriptor;
+    int _finalDirectoryDescriptor;
+    int _finalManifestDescriptor;
+    struct stat _parentIdentity;
+    struct stat _workspaceIdentity;
+    struct stat _finalDirectoryIdentity;
+    struct stat _finalManifestIdentity;
+    unsigned long long _acceptedManifestSize;
+    NSString *_acceptedManifestSHA256;
+    NSDictionary<NSString *, id> *_acceptedManifestRepresentation;
+    NSUInteger _acceptedArtifactCount;
+}
+
++ (nullable instancetype)
+    publisherForWorkspace:(PXBackupPublicationWorkspace *)workspace
+               bundleLock:(PXBackupBundleLock *)bundleLock
+         backupIdentifier:(NSString *)backupIdentifier
+                timestamp:(NSString *)timestamp
+                    error:(NSError **)error {
+    if (error) *error = nil;
+    if (![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]] ||
+        ![bundleLock isMemberOfClass:[PXBackupBundleLock class]]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidInput,
+                                  PXBackupDirectoryPublisherField,
+                                  @"The directory publication inputs are invalid");
+        return nil;
+    }
+    if (![workspace.bundleIdentifier isEqualToString:bundleLock.bundleIdentifier] ||
+        ![workspace.canonicalBundleDirectoryPath
+            isEqualToString:bundleLock.canonicalBundleDirectoryPath] ||
+        ![workspace.workspaceName hasPrefix:PXBackupPublicationPartialDirectoryPrefix]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidInput,
+                                  PXBackupDirectoryPublisherField,
+                                  @"The directory publication identity is invalid");
+        return nil;
+    }
+    if (!PXBackupDirectoryValidateTimestamp(timestamp) ||
+        !PXBackupDirectoryValidateBackupIdentifier(backupIdentifier)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The final backup directory identity is invalid");
+        return nil;
+    }
+    NSError *lockError = nil;
+    if (![bundleLock validateOwnershipWithError:&lockError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorLockValidationFailed,
+                                  PXBackupDirectoryPublisherLockField,
+                                  @"The backup lock failed validation");
+        return nil;
+    }
+    NSError *workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorWorkspaceValidationFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The backup workspace failed validation");
+        return nil;
+    }
+    NSString *parentPath = bundleLock.canonicalBundleDirectoryPath;
+    NSString *workspacePath = workspace.workspacePath;
+    NSString *expectedWorkspacePath =
+        [parentPath stringByAppendingPathComponent:workspace.workspaceName];
+    NSString *publishedDirectoryName =
+        [NSString stringWithFormat:@"%@-%@", timestamp, backupIdentifier];
+    NSString *publishedDirectoryPath =
+        [parentPath stringByAppendingPathComponent:publishedDirectoryName];
+    NSString *publishedManifestPath =
+        [publishedDirectoryPath stringByAppendingPathComponent:PXBackupManifestFinalFileName];
+    NSData *parentPathData = PXBackupDirectoryLosslessUTF8Data(
+        parentPath,
+        PXBackupDirectoryMaximumPathBytes,
+        YES);
+    NSData *workspaceNameData = nil;
+    NSData *publishedNameData = nil;
+    NSData *publishedPathData = PXBackupDirectoryLosslessUTF8Data(
+        publishedDirectoryPath,
+        PXBackupDirectoryMaximumPathBytes,
+        YES);
+    if (!parentPathData || !publishedPathData ||
+        ![workspacePath isEqualToString:expectedWorkspacePath] ||
+        !PXBackupDirectoryValidateSafeComponent(workspace.workspaceName,
+                                                &workspaceNameData) ||
+        !PXBackupDirectoryValidateFinalName(publishedDirectoryName,
+                                            &publishedNameData)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The final backup directory name is invalid");
+        return nil;
+    }
+    char *parentPathBytes = PXBackupDirectoryCopyCString(parentPathData);
+    char *workspaceNameBytes = PXBackupDirectoryCopyCString(workspaceNameData);
+    char *publishedNameBytes = PXBackupDirectoryCopyCString(publishedNameData);
+    int parentDescriptor = -1;
+    int workspaceDescriptor = -1;
+    PXBackupDirectoryPublisher *publisher = nil;
+    struct stat parentPathStat;
+    struct stat parentDescriptorStat;
+    struct stat workspacePathStat;
+    struct stat workspaceNamespaceStat;
+    struct stat workspaceDescriptorStat;
+    if (!parentPathBytes || !workspaceNameBytes || !publishedNameBytes) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The final backup path exceeds resource limits");
+        goto cleanup;
+    }
+    if (lstat(parentPathBytes, &parentPathStat) != 0 ||
+        S_ISLNK(parentPathStat.st_mode) ||
+        !S_ISDIR(parentPathStat.st_mode) ||
+        (parentPathStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorParentInspectionFailed,
+                                  PXBackupDirectoryPublisherParentField,
+                                  @"The backup parent directory is invalid");
+        goto cleanup;
+    }
+    parentDescriptor = open(parentPathBytes,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (parentDescriptor < 0 ||
+        fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
+        !S_ISDIR(parentDescriptorStat.st_mode) ||
+        (parentDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        !PXBackupDirectoryStatIdentityMatches(&parentPathStat,
+                                              &parentDescriptorStat) ||
+        !PXBackupDirectoryDescriptorHasCloseOnExec(parentDescriptor)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorParentInspectionFailed,
+                                  PXBackupDirectoryPublisherParentField,
+                                  @"The backup parent descriptor is invalid");
+        goto cleanup;
+    }
+    if (fstatat(parentDescriptor,
+                workspaceNameBytes,
+                &workspaceNamespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(workspaceNamespaceStat.st_mode) ||
+        (workspaceNamespaceStat.st_mode & 07777) != 0700 ||
+        (workspaceNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        workspaceNamespaceStat.st_dev != parentDescriptorStat.st_dev) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The backup workspace namespace is invalid");
+        goto cleanup;
+    }
+    workspaceDescriptor = openat(parentDescriptor,
+                                 workspaceNameBytes,
+                                 O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (workspaceDescriptor < 0 ||
+        fstat(workspaceDescriptor, &workspaceDescriptorStat) != 0 ||
+        !S_ISDIR(workspaceDescriptorStat.st_mode) ||
+        (workspaceDescriptorStat.st_mode & 07777) != 0700 ||
+        workspaceDescriptorStat.st_dev != parentDescriptorStat.st_dev ||
+        !PXBackupDirectoryStatIdentityMatches(&workspaceNamespaceStat,
+                                              &workspaceDescriptorStat) ||
+        !PXBackupDirectoryDescriptorHasCloseOnExec(workspaceDescriptor) ||
+        !PXBackupDirectoryPathMatchesDescriptor(workspacePath,
+                                                workspaceDescriptor,
+                                                &workspaceDescriptorStat,
+                                                YES,
+                                                &workspacePathStat)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The backup workspace descriptor is invalid");
+        goto cleanup;
+    }
+    workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorWorkspaceValidationFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The backup workspace identity changed");
+        goto cleanup;
+    }
+    if (!PXBackupDirectoryEntryIsAbsent(parentDescriptor, publishedNameBytes)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The final backup directory already exists");
+        goto cleanup;
+    }
+    publisher = [[PXBackupDirectoryPublisher alloc]
+        initWithWorkspace:workspace
+               bundleLock:bundleLock
+            workspacePath:workspacePath
+            workspaceName:workspace.workspaceName
+              parentPath:parentPath
+  publishedDirectoryPath:publishedDirectoryPath
+  publishedDirectoryName:publishedDirectoryName
+    publishedManifestPath:publishedManifestPath
+         backupIdentifier:backupIdentifier
+                timestamp:timestamp
+         parentDescriptor:parentDescriptor
+      workspaceDescriptor:workspaceDescriptor
+           parentIdentity:&parentDescriptorStat
+        workspaceIdentity:&workspaceDescriptorStat];
+    if (!publisher) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The directory publisher could not retain its authority");
+        goto cleanup;
+    }
+    parentDescriptor = -1;
+    workspaceDescriptor = -1;
+
+cleanup:
+    free(parentPathBytes);
+    free(workspaceNameBytes);
+    free(publishedNameBytes);
+    if (workspaceDescriptor >= 0) close(workspaceDescriptor);
+    if (parentDescriptor >= 0) close(parentDescriptor);
+    return publisher;
+}
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                        bundleLock:(PXBackupBundleLock *)bundleLock
+                     workspacePath:(NSString *)workspacePath
+                     workspaceName:(NSString *)workspaceName
+                        parentPath:(NSString *)parentPath
+          publishedDirectoryPath:(NSString *)publishedDirectoryPath
+          publishedDirectoryName:(NSString *)publishedDirectoryName
+            publishedManifestPath:(NSString *)publishedManifestPath
+               backupIdentifier:(NSString *)backupIdentifier
+                      timestamp:(NSString *)timestamp
+               parentDescriptor:(int)parentDescriptor
+            workspaceDescriptor:(int)workspaceDescriptor
+                 parentIdentity:(const struct stat *)parentIdentity
+              workspaceIdentity:(const struct stat *)workspaceIdentity {
+    self = [super init];
+    if (self) {
+        _workspace = workspace;
+        _bundleLock = bundleLock;
+        _workspacePath = [workspacePath copy];
+        _workspaceName = [workspaceName copy];
+        _parentPath = [parentPath copy];
+        _publishedDirectoryPath = [publishedDirectoryPath copy];
+        _publishedDirectoryName = [publishedDirectoryName copy];
+        _publishedManifestPath = [publishedManifestPath copy];
+        _backupIdentifier = [backupIdentifier copy];
+        _timestamp = [timestamp copy];
+        _parentDescriptor = parentDescriptor;
+        _workspaceDescriptor = workspaceDescriptor;
+        _finalDirectoryDescriptor = -1;
+        _finalManifestDescriptor = -1;
+        if (parentIdentity) _parentIdentity = *parentIdentity;
+        if (workspaceIdentity) _workspaceIdentity = *workspaceIdentity;
+    }
+    return self;
+}
+
+- (NSString *)workspacePath { return _workspacePath; }
+- (NSString *)publishedDirectoryPath { return _publishedDirectoryPath; }
+- (NSString *)publishedDirectoryName { return _publishedDirectoryName; }
+- (NSString *)publishedManifestPath { return _publishedManifestPath; }
+- (NSString *)backupIdentifier { return _backupIdentifier; }
+- (NSString *)timestamp { return _timestamp; }
+- (BOOL)isPublished { return _published; }
+
+- (BOOL)validateIdentityWithError:(NSError **)error {
+    if (error) *error = nil;
+    NSError *lockError = nil;
+    if (![_bundleLock validateOwnershipWithError:&lockError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorLockValidationFailed,
+                                  PXBackupDirectoryPublisherLockField,
+                                  @"The retained backup lock is invalid");
+        return NO;
+    }
+    if (!PXBackupDirectoryPathMatchesDescriptor(_parentPath,
+                                                _parentDescriptor,
+                                                &_parentIdentity,
+                                                NO,
+                                                NULL)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherParentField,
+                                  @"The retained parent directory identity changed");
+        return NO;
+    }
+    NSData *workspaceNameData = nil;
+    NSData *publishedNameData = nil;
+    if (!PXBackupDirectoryValidateSafeComponent(_workspaceName,
+                                                &workspaceNameData) ||
+        !PXBackupDirectoryValidateFinalName(_publishedDirectoryName,
+                                            &publishedNameData)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherField,
+                                  @"The retained publication names are inconsistent");
+        return NO;
+    }
+    char *workspaceNameBytes = PXBackupDirectoryCopyCString(workspaceNameData);
+    char *publishedNameBytes = PXBackupDirectoryCopyCString(publishedNameData);
+    NSData *manifestData = nil;
+    NSString *manifestDigest = nil;
+    NSDictionary *parsed = nil;
+    NSError *validationError = nil;
+    BOOL valid = NO;
+    if (!workspaceNameBytes || !publishedNameBytes) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherField,
+                                  @"The retained publication names exceed limits");
+        goto cleanup;
+    }
+    if (!_published) {
+        NSError *workspaceError = nil;
+        if (_finalDirectoryDescriptor >= 0 || _finalManifestDescriptor >= 0 ||
+            _acceptedManifestSize != 0 || _acceptedManifestSHA256 != nil ||
+            _acceptedManifestRepresentation != nil ||
+            ![_workspace validateIdentityWithError:&workspaceError] ||
+            !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                     workspaceNameBytes,
+                                                     _workspaceDescriptor,
+                                                     &_workspaceIdentity,
+                                                     _parentIdentity.st_dev,
+                                                     NULL) ||
+            !PXBackupDirectoryPathMatchesDescriptor(_workspacePath,
+                                                    _workspaceDescriptor,
+                                                    &_workspaceIdentity,
+                                                    YES,
+                                                    NULL) ||
+            !PXBackupDirectoryEntryIsAbsent(_parentDescriptor,
+                                            publishedNameBytes)) {
+            PXBackupDirectorySetError(error,
+                                      PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                      PXBackupDirectoryPublisherWorkspaceField,
+                                      @"The unpublished workspace identity changed");
+            goto cleanup;
+        }
+        valid = YES;
+        goto cleanup;
+    }
+    if (_finalDirectoryDescriptor < 0 || _finalManifestDescriptor < 0 ||
+        _acceptedManifestSize == 0 ||
+        !PXBackupDirectoryDigestIsLowercaseSHA256(_acceptedManifestSHA256) ||
+        ![_acceptedManifestRepresentation isKindOfClass:[NSDictionary class]] ||
+        [_acceptedManifestRepresentation isKindOfClass:[NSMutableDictionary class]] ||
+        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
+        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                 publishedNameBytes,
+                                                 _finalDirectoryDescriptor,
+                                                 &_finalDirectoryIdentity,
+                                                 _parentIdentity.st_dev,
+                                                 NULL) ||
+        !PXBackupDirectoryStatIdentityMatches(&_workspaceIdentity,
+                                              &_finalDirectoryIdentity) ||
+        ![_publishedDirectoryPath isEqualToString:
+            [_parentPath stringByAppendingPathComponent:_publishedDirectoryName]] ||
+        ![_publishedManifestPath isEqualToString:
+            [_publishedDirectoryPath stringByAppendingPathComponent:
+                PXBackupManifestFinalFileName]]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The published directory identity changed");
+        goto cleanup;
+    }
+    struct stat finalManifestStat;
+    if (!PXBackupDirectoryManifestBindingValid(_finalDirectoryDescriptor,
+                                               _finalManifestDescriptor,
+                                               &_finalManifestIdentity,
+                                               _acceptedManifestSize,
+                                               &finalManifestStat)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The published manifest identity changed");
+        goto cleanup;
+    }
+    struct stat stableManifestIdentity;
+    if (!PXBackupDirectoryReadManifestDescriptor(_finalManifestDescriptor,
+                                                 &finalManifestStat,
+                                                 _acceptedManifestSize,
+                                                 &manifestData,
+                                                 &manifestDigest,
+                                                 &stableManifestIdentity) ||
+        ![manifestDigest isEqualToString:_acceptedManifestSHA256]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestReadBackFailed,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The published manifest content changed");
+        goto cleanup;
+    }
+    parsed = PXBackupDirectoryParseManifestData(manifestData);
+    validationError = nil;
+    if (!parsed ||
+        ![PXBackupManifestValidator validateManifestObject:parsed
+                                                     error:&validationError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestValidationFailed,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The published manifest failed validation");
+        goto cleanup;
+    }
+    if (!PXBackupDirectoryManifestMatches(parsed,
+                                          _acceptedManifestRepresentation,
+                                          _backupIdentifier,
+                                          _timestamp,
+                                          _acceptedArtifactCount)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorSnapshotMismatch,
+                                  PXBackupDirectoryPublisherSnapshotField,
+                                  @"The published manifest no longer matches its accepted snapshot");
+        goto cleanup;
+    }
+    valid = YES;
+
+cleanup:
+    free(workspaceNameBytes);
+    free(publishedNameBytes);
+    return valid;
+}
+
+- (BOOL)publishWithArtifactWriter:(PXBackupArtifactWriter *)artifactWriter
+                   manifestWriter:(PXBackupManifestWriter *)manifestWriter
+                            error:(NSError **)error {
+    if (error) *error = nil;
+    if (_publishAttempted || _published) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidInput,
+                                  PXBackupDirectoryPublisherField,
+                                  @"The directory publisher has already been used");
+        return NO;
+    }
+    _publishAttempted = YES;
+    if (![artifactWriter isMemberOfClass:[PXBackupArtifactWriter class]] ||
+        ![manifestWriter isMemberOfClass:[PXBackupManifestWriter class]]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidInput,
+                                  PXBackupDirectoryPublisherField,
+                                  @"The directory publication writers are invalid");
+        return NO;
+    }
+    NSData *workspaceNameData = nil;
+    NSData *publishedNameData = nil;
+    char *workspaceNameBytes = NULL;
+    char *publishedNameBytes = NULL;
+    BOOL forwardRenamed = NO;
+    BOOL accepted = NO;
+    int finalDirectoryDescriptor = -1;
+    int finalManifestDescriptor = -1;
+    NSError *originalError = nil;
+    NSError *identityError = nil;
+    NSError *lockError = nil;
+    NSError *workspaceError = nil;
+    NSError *artifactError = nil;
+    NSError *manifestWriterError = nil;
+    NSDictionary *manifestRepresentation = nil;
+    NSString *manifestDigest = nil;
+    NSData *manifestData = nil;
+    NSDictionary *parsedManifest = nil;
+    NSError *validationError = nil;
+    struct stat finalNamespaceIdentity;
+    struct stat finalDirectoryIdentity;
+    struct stat finalManifestIdentity;
+    struct stat stableManifestIdentity;
+    memset(&finalNamespaceIdentity, 0, sizeof(finalNamespaceIdentity));
+    memset(&finalDirectoryIdentity, 0, sizeof(finalDirectoryIdentity));
+    memset(&finalManifestIdentity, 0, sizeof(finalManifestIdentity));
+    memset(&stableManifestIdentity, 0, sizeof(stableManifestIdentity));
+
+    if (!PXBackupDirectoryValidateSafeComponent(_workspaceName,
+                                                &workspaceNameData) ||
+        !PXBackupDirectoryValidateFinalName(_publishedDirectoryName,
+                                            &publishedNameData)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The retained final directory name is invalid");
+        goto cleanup;
+    }
+    workspaceNameBytes = PXBackupDirectoryCopyCString(workspaceNameData);
+    publishedNameBytes = PXBackupDirectoryCopyCString(publishedNameData);
+    if (!workspaceNameBytes || !publishedNameBytes) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The retained final directory name exceeds limits");
+        goto cleanup;
+    }
+    identityError = nil;
+    if (![self validateIdentityWithError:&identityError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The directory publisher identity is invalid");
+        goto cleanup;
+    }
+    lockError = nil;
+    if (![_bundleLock validateOwnershipWithError:&lockError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorLockValidationFailed,
+                                  PXBackupDirectoryPublisherLockField,
+                                  @"The backup lock failed pre-publication validation");
+        goto cleanup;
+    }
+    workspaceError = nil;
+    if (![_workspace validateIdentityWithError:&workspaceError] ||
+        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                 workspaceNameBytes,
+                                                 _workspaceDescriptor,
+                                                 &_workspaceIdentity,
+                                                 _parentIdentity.st_dev,
+                                                 NULL)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorWorkspaceValidationFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The backup workspace failed pre-publication validation");
+        goto cleanup;
+    }
+    artifactError = nil;
+    if (![artifactWriter validateIdentityWithError:&artifactError] ||
+        ![artifactWriter.workspacePath isEqualToString:_workspacePath]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorArtifactWriterValidationFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The artifact writer failed publication validation");
+        goto cleanup;
+    }
+    manifestWriterError = nil;
+    if (![manifestWriter validateIdentityWithError:&manifestWriterError] ||
+        ![manifestWriter.workspacePath isEqualToString:_workspacePath]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestWriterValidationFailed,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The manifest writer failed publication validation");
+        goto cleanup;
+    }
+    manifestRepresentation = manifestWriter.manifestRepresentation;
+    manifestDigest = manifestWriter.manifestSHA256;
+    if (!manifestWriter.isManifestWritten || manifestWriter.manifestSize == 0 ||
+        manifestWriter.manifestSize > PXBackupDirectoryMaximumManifestBytes ||
+        !PXBackupDirectoryDigestIsLowercaseSHA256(manifestDigest) ||
+        ![manifestRepresentation isKindOfClass:[NSDictionary class]] ||
+        [manifestRepresentation isKindOfClass:[NSMutableDictionary class]] ||
+        ![manifestWriter.manifestPath isEqualToString:
+            [_workspacePath stringByAppendingPathComponent:
+                PXBackupManifestFinalFileName]]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestNotReady,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The manifest is not ready for directory publication");
+        goto cleanup;
+    }
+    validationError = nil;
+    if (![PXBackupManifestValidator validateManifestObject:manifestRepresentation
+                                                     error:&validationError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestValidationFailed,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The accepted manifest failed publication validation");
+        goto cleanup;
+    }
+    if (!PXBackupDirectoryManifestMatches(manifestRepresentation,
+                                          manifestRepresentation,
+                                          _backupIdentifier,
+                                          _timestamp,
+                                          artifactWriter.artifactCount)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorSnapshotMismatch,
+                                  PXBackupDirectoryPublisherSnapshotField,
+                                  @"The accepted manifest does not match publication identity");
+        goto cleanup;
+    }
+    if (!PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The final backup directory already exists");
+        goto cleanup;
+    }
+    if (!PXBackupDirectoryScanManifestTemporaryEntries(_workspaceDescriptor)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestNotReady,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The workspace contains a manifest temporary entry");
+        goto cleanup;
+    }
+    if (!PXBackupDirectoryStrictSync(_workspaceDescriptor)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorDurabilityFailed,
+                                  PXBackupDirectoryPublisherWorkspaceField,
+                                  @"The backup workspace could not be synchronized");
+        goto cleanup;
+    }
+    lockError = nil;
+    if (![_bundleLock validateOwnershipWithError:&lockError] ||
+        !PXBackupDirectoryPathMatchesDescriptor(_parentPath,
+                                                _parentDescriptor,
+                                                &_parentIdentity,
+                                                NO,
+                                                NULL) ||
+        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                 workspaceNameBytes,
+                                                 _workspaceDescriptor,
+                                                 &_workspaceIdentity,
+                                                 _parentIdentity.st_dev,
+                                                 NULL) ||
+        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The publication filesystem identity changed before rename");
+        goto cleanup;
+    }
+    if (!PXBackupDirectoryRenameEntry(_parentDescriptor,
+                                      workspaceNameBytes,
+                                      _parentDescriptor,
+                                      publishedNameBytes)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorPublicationFailed,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The backup directory could not be published atomically");
+        goto cleanup;
+    }
+    forwardRenamed = YES;
+    if (!PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
+        fstatat(_parentDescriptor,
+                publishedNameBytes,
+                &finalNamespaceIdentity,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(finalNamespaceIdentity.st_mode) ||
+        (finalNamespaceIdentity.st_mode & 07777) != 0700 ||
+        !PXBackupDirectoryStatIdentityMatches(&_workspaceIdentity,
+                                              &finalNamespaceIdentity)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The published directory namespace is invalid");
+        goto rollback;
+    }
+    if (!PXBackupDirectoryStrictSync(_workspaceDescriptor) ||
+        !PXBackupDirectoryStrictSync(_parentDescriptor)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorDurabilityFailed,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The published directory could not be synchronized");
+        goto rollback;
+    }
+    finalDirectoryDescriptor = openat(_parentDescriptor,
+                                      publishedNameBytes,
+                                      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (finalDirectoryDescriptor < 0 ||
+        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                 publishedNameBytes,
+                                                 finalDirectoryDescriptor,
+                                                 &_workspaceIdentity,
+                                                 _parentIdentity.st_dev,
+                                                 &finalDirectoryIdentity)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The published directory descriptor is invalid");
+        goto rollback;
+    }
+    finalManifestDescriptor = openat(finalDirectoryDescriptor,
+                                     PXBackupDirectoryManifestFileNameBytes,
+                                     O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    if (finalManifestDescriptor < 0 ||
+        fstat(finalManifestDescriptor, &finalManifestIdentity) != 0 ||
+        !S_ISREG(finalManifestIdentity.st_mode) ||
+        finalManifestIdentity.st_nlink != 1 ||
+        (finalManifestIdentity.st_mode & 07777) != 0600 ||
+        finalManifestIdentity.st_dev != finalDirectoryIdentity.st_dev ||
+        finalManifestIdentity.st_size < 0 ||
+        (unsigned long long)finalManifestIdentity.st_size !=
+            manifestWriter.manifestSize ||
+        !PXBackupDirectoryDescriptorHasCloseOnExec(finalManifestDescriptor) ||
+        !PXBackupDirectoryManifestBindingValid(finalDirectoryDescriptor,
+                                               finalManifestDescriptor,
+                                               &finalManifestIdentity,
+                                               manifestWriter.manifestSize,
+                                               NULL)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The published manifest descriptor is invalid");
+        goto rollback;
+    }
+    if (!PXBackupDirectoryReadManifestDescriptor(finalManifestDescriptor,
+                                                 &finalManifestIdentity,
+                                                 manifestWriter.manifestSize,
+                                                 &manifestData,
+                                                 &manifestDigest,
+                                                 &stableManifestIdentity) ||
+        ![manifestDigest isEqualToString:manifestWriter.manifestSHA256]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestReadBackFailed,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The published manifest could not be read back exactly");
+        goto rollback;
+    }
+    parsedManifest = PXBackupDirectoryParseManifestData(manifestData);
+    validationError = nil;
+    if (!parsedManifest ||
+        ![PXBackupManifestValidator validateManifestObject:parsedManifest
+                                                     error:&validationError]) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorManifestValidationFailed,
+                                  PXBackupDirectoryPublisherManifestField,
+                                  @"The published manifest failed validation");
+        goto rollback;
+    }
+    if (!PXBackupDirectoryManifestMatches(parsedManifest,
+                                          manifestWriter.manifestRepresentation,
+                                          _backupIdentifier,
+                                          _timestamp,
+                                          artifactWriter.artifactCount)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorSnapshotMismatch,
+                                  PXBackupDirectoryPublisherSnapshotField,
+                                  @"The published manifest does not match its accepted snapshot");
+        goto rollback;
+    }
+    if (!PXBackupDirectoryPathMatchesDescriptor(_parentPath,
+                                                _parentDescriptor,
+                                                &_parentIdentity,
+                                                NO,
+                                                NULL) ||
+        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
+        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                 publishedNameBytes,
+                                                 finalDirectoryDescriptor,
+                                                 &finalDirectoryIdentity,
+                                                 _parentIdentity.st_dev,
+                                                 NULL) ||
+        !PXBackupDirectoryManifestBindingValid(finalDirectoryDescriptor,
+                                               finalManifestDescriptor,
+                                               &stableManifestIdentity,
+                                               manifestWriter.manifestSize,
+                                               NULL)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The published backup identity changed before acceptance");
+        goto rollback;
+    }
+    _finalDirectoryDescriptor = finalDirectoryDescriptor;
+    finalDirectoryDescriptor = -1;
+    _finalManifestDescriptor = finalManifestDescriptor;
+    finalManifestDescriptor = -1;
+    _finalDirectoryIdentity = finalDirectoryIdentity;
+    _finalManifestIdentity = stableManifestIdentity;
+    _acceptedManifestSize = manifestWriter.manifestSize;
+    _acceptedManifestSHA256 = [manifestWriter.manifestSHA256 copy];
+    _acceptedManifestRepresentation =
+        [manifestWriter.manifestRepresentation copy];
+    _acceptedArtifactCount = artifactWriter.artifactCount;
+    _published = YES;
+    accepted = YES;
+    if (error) *error = nil;
+    goto cleanup;
+
+rollback:
+    originalError = error ? *error : nil;
+    if (finalManifestDescriptor >= 0) {
+        close(finalManifestDescriptor);
+        finalManifestDescriptor = -1;
+    }
+    if (finalDirectoryDescriptor >= 0) {
+        close(finalDirectoryDescriptor);
+        finalDirectoryDescriptor = -1;
+    }
+    if (!PXBackupDirectoryPathMatchesDescriptor(_parentPath,
+                                                _parentDescriptor,
+                                                &_parentIdentity,
+                                                NO,
+                                                NULL) ||
+        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
+        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                 publishedNameBytes,
+                                                 _workspaceDescriptor,
+                                                 &_workspaceIdentity,
+                                                 _parentIdentity.st_dev,
+                                                 NULL) ||
+        !PXBackupDirectoryRenameEntry(_parentDescriptor,
+                                      publishedNameBytes,
+                                      _parentDescriptor,
+                                      workspaceNameBytes) ||
+        !PXBackupDirectoryStrictSync(_parentDescriptor) ||
+        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes) ||
+        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
+                                                 workspaceNameBytes,
+                                                 _workspaceDescriptor,
+                                                 &_workspaceIdentity,
+                                                 _parentIdentity.st_dev,
+                                                 NULL)) {
+        PXBackupDirectorySetError(error,
+                                  PXBackupDirectoryPublisherErrorRollbackFailed,
+                                  PXBackupDirectoryPublisherFinalField,
+                                  @"The failed directory publication could not be rolled back safely");
+        goto cleanup;
+    }
+    forwardRenamed = NO;
+    if (error) *error = originalError;
+
+cleanup:
+    if (finalManifestDescriptor >= 0) close(finalManifestDescriptor);
+    if (finalDirectoryDescriptor >= 0) close(finalDirectoryDescriptor);
+    free(workspaceNameBytes);
+    free(publishedNameBytes);
+    (void)forwardRenamed;
+    return accepted;
+}
+
+- (void)dealloc {
+    if (_finalManifestDescriptor >= 0) close(_finalManifestDescriptor);
+    if (_finalDirectoryDescriptor >= 0) close(_finalDirectoryDescriptor);
+    if (_workspaceDescriptor >= 0) close(_workspaceDescriptor);
+    if (_parentDescriptor >= 0) close(_parentDescriptor);
+}
+
+@end

--- a/AppDataBackupManager.m+++ b/AppDataBackupManager.m@@ -16,6 +16,7 @@ #import "PXBackupBundleLock.h"
 #import "PXBackupArtifactWriter.h"
 #import "PXBackupManifestWriter.h"
+#import "PXBackupDirectoryPublisher.h"
 #import "PXBackupPublicationWorkspace.h"
 #import "PXRestorePlan.h"
 #import "PXAppGroupRestoreTargetPlan.h"
@@ -1849,6 +1850,27 @@             keychainArtifactPolicy,
         ];
         NSString *backupIdentifier = [NSUUID UUID].UUIDString.lowercaseString;
+        NSError *directoryPublisherError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXBackupDirectoryPublisher *directoryPublisher =
+            [PXBackupDirectoryPublisher publisherForWorkspace:publicationWorkspace
+                                                   bundleLock:bundleLock
+                                             backupIdentifier:backupIdentifier
+                                                    timestamp:timestamp
+                                                        error:&directoryPublisherError];
+        if (!directoryPublisher) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, directoryPublisherError);
+            });
+            return;
+        }
+        NSError *initialDirectoryPublisherIdentityError = nil;
+        if (![directoryPublisher validateIdentityWithError:&initialDirectoryPublisherIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, initialDirectoryPublisherIdentityError);
+            });
+            return;
+        }
         NSMutableArray<PXVerifiedBackupArtifact *> *groupArtifactRecords =
             [NSMutableArray array];
         NSMutableArray<PXVerifiedBackupArtifact *> *systemGlobalArtifactRecords =
@@ -2612,9 +2634,32 @@             });
             return;
         }
+        NSError *prePublicationDirectoryPublisherIdentityError = nil;
+        if (![directoryPublisher validateIdentityWithError:&prePublicationDirectoryPublisherIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, prePublicationDirectoryPublisherIdentityError);
+            });
+            return;
+        }
+        NSError *directoryPublicationError = nil;
+        if (![directoryPublisher publishWithArtifactWriter:artifactWriter
+                                            manifestWriter:manifestWriter
+                                                     error:&directoryPublicationError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, directoryPublicationError);
+            });
+            return;
+        }
+        NSError *postPublicationDirectoryPublisherIdentityError = nil;
+        if (![directoryPublisher validateIdentityWithError:&postPublicationDirectoryPublisherIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, postPublicationDirectoryPublisherIdentityError);
+            });
+            return;
+        }
         PXBackupResult *out = [[PXBackupResult alloc] init];
-        out.backupDirectory = publicationWorkspace.workspacePath;
-        out.manifestPath = manifestWriter.manifestPath;
+        out.backupDirectory = directoryPublisher.publishedDirectoryPath;
+        out.manifestPath = directoryPublisher.publishedManifestPath;
         out.warnings = warnings;

         dispatch_async(dispatch_get_main_queue(), ^{
```

## Whitespace, CRLF and NUL audit

- New/modified production files use LF, contain zero NUL bytes and end with a final newline.
- Report uses LF, contains zero NUL bytes and ends with a final newline.
- `git diff --check` is required before and after commit.

## Build status and remaining runtime risks

- Strict Objective-C frontend/analyzer for the publisher: PASS.
- Strict manager integration frontend harness: PASS.
- Executable timestamp/UUID/publication/rollback model: PASS.
- Full Theos/iOS compile/link and target-filesystem crash-point replay remain pending because the Windows workspace has no Theos, Apple clang, xcrun or target APFS runtime.
- Remaining authoritative gates are GitHub Actions and device-level rename/fsync/fault-injection replay.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
