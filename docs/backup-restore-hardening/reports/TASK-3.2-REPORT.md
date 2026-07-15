# TASK-3.2 Implementation Report

## Baseline and exact scope

- Baseline: `2db8d448f1e89e74979a64f38e48ae3304ab353e`.
- Authorized production files: `PXBackupBundleLock.h`, `PXBackupBundleLock.m`, `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-3.2-REPORT.md`.
- TASK-3.1 source review: ACCEPTED; workspace files remain protected and byte-identical.

### Baseline commands

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
git rev-parse HEAD
2db8d448f1e89e74979a64f38e48ae3304ab353e
git log -5 --oneline
2db8d44 phase3(task-3.1): create unique partial backup workspace
0ef0631 phase2(task-2.14A): make restore result mutations assertion independent
fec5966 phase2(task-2.14): add structured restore result
9d046a4 phase2(task-2.13A): implement optional directory tree verifier
08d23dd phase2(task-2.13): add transactional optional component handling
git diff --check
PASS
```

## Protected SHA-256 before/after

- Protected files: 296.
- Changed protected files: 0.

| Path | Before SHA-256 | After SHA-256 | Bytes |
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
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | 1949 |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | 43911 |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | 945 |
| `PXBackupManifestValidator.m` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | 46178 |
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

## Exact public API and eleven-code enum

Exports: `PXBackupBundleLockErrorDomain`, `PXBackupBundleLockErrorFieldPathKey`, and `PXBackupBundleLockFileName`.

Exact persistent file name: `.weaponx-backup.lock`.

| Value | Error code |
|---:|---|
| 1 | `PXBackupBundleLockErrorInvalidInput` |
| 2 | `PXBackupBundleLockErrorRootCreationFailed` |
| 3 | `PXBackupBundleLockErrorRootInspectionFailed` |
| 4 | `PXBackupBundleLockErrorUnsafeRoot` |
| 5 | `PXBackupBundleLockErrorBundleDirectoryCreationFailed` |
| 6 | `PXBackupBundleLockErrorBundleDirectoryInvalid` |
| 7 | `PXBackupBundleLockErrorLockFileOpenFailed` |
| 8 | `PXBackupBundleLockErrorLockFileInvalid` |
| 9 | `PXBackupBundleLockErrorLockUnavailable` |
| 10 | `PXBackupBundleLockErrorFilesystemChanged` |
| 11 | `PXBackupBundleLockErrorLimitExceeded` |

The subclassing-restricted class exposes four copied readonly strings, one factory, one validation method, and no descriptor, path, unlock, timeout, wait, workspace, manifest, artifact, or publication API.

## Input validation matrices

Backup roots are runtime nonempty absolute NUL-free lossless UTF-8 strings, maximum 4096 bytes. Bundle identifiers are exact nonempty non-whitespace safe components, maximum 255 bytes, with no control, DEL, slash, backslash, NUL, `.` or `..`. No trimming, lowercasing, normalization, percent decoding, standardization, or tilde expansion is performed.

## Backup-root and bundle descriptor proof

The lock class mirrors the accepted TASK-3.1 authority boundary: missing root ancestors may be created, the requested final component is inspected with `lstat`, final symlinks/setid/wrong types are rejected, `realpath` establishes the canonical root, and `open(... O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)` binds a retained descriptor. Requested, canonical, and descriptor identities must match. The exact bundle component is inspected with `fstatat(... AT_SYMLINK_NOFOLLOW)`, created with `mkdirat(...,0700)` when absent, opened no-follow/CLOEXEC, checked on the same device, and bound to the canonical root-plus-exact-component path.

## Persistent lock-file proof

The only lock file is a direct child of the retained bundle directory. `openat` uses `O_RDWR|O_CREAT|O_NOFOLLOW|O_CLOEXEC` with mode 0600 and no truncation. Before and after `fchmod(0600)`, namespace and descriptor stats must identify the same regular, single-linked inode on the bundle filesystem. The file is never written or unlinked.

## Exact nonblocking flock behavior

One helper calls exactly `flock(lockDescriptor, LOCK_EX | LOCK_NB)` and retries only `EINTR`. `EWOULDBLOCK`/`EAGAIN` map to `LockUnavailable`; other errors map to `LockFileOpenFailed`. There is no blocking, sleep, timeout, shared fallback, in-memory fallback, or unlocked continuation.

### Darwin same-process serialization proof

Darwin XNU `sys_flock` passes the descriptor fileglob (`fp->fp_glob`) as the BSD flock owner to `VNOP_ADVLOCK`, and `LOCK_NB` omits `F_WAIT`. Independent `openat` calls therefore use independent fileglob owners even inside one process, so concurrent Backup invocations contend on the same inode rather than silently sharing one process-owned lock.

## Serialization and contention matrix

| Domain relationship | Result |
|---|---|
| Same physical root + exact same bundle | one holder; contender gets LockUnavailable |
| Root aliases resolving to same root + same bundle | same persistent inode; serialized |
| Different exact bundles under one root | distinct sibling files; may proceed concurrently |
| Same bundle under different physical roots | distinct domains; may proceed concurrently |
| Holder process crashes | descriptor close releases flock; persistent file remains |

Contention is a hard nil-result/exact-lock-error completion on the main queue before workspace creation, process kill, or output writing.

## Lifecycle, validation, and error privacy

The object retains root, bundle, and lock descriptors, a locked-state flag, and initial identities. Factory failure best-effort unlocks only if acquired and closes all descriptors without unlinking anything. `dealloc` retries `LOCK_UN` only on EINTR, closes lock/bundle/root descriptors, and leaves the persistent file. Validation never reacquires; it checks locked state, descriptor identities/types, nlink, mode, same-device relations, CLOEXEC flags, canonical path identities, and lock namespace identity.

Errors contain only `NSLocalizedDescriptionKey` and `PXBackupBundleLockErrorFieldPathKey`, with one of `$.backupRoot`, `$.bundleIdentifier`, `$.bundleDirectory`, or `$.lock`. No path, identifier, PID, device, inode, errno text, nested error, or namespace entry is exposed.

## Manager pre-side-effect ordering and four validations

```text
background queue
→ active profile ID
→ one _backupRoot read
→ lock factory
→ lock validation #1
→ tar discovery
→ source-container resolution
→ timestamp
→ lock validation #2
→ TASK-3.1 workspace factory
→ workspace validation #1
→ debug/directories/process kill/artifacts
→ workspace validation #2
→ lock validation #3
→ manifest write
→ workspace validation #3
→ lock validation #4
→ PXBackupResult construction
```

The lock and workspace both use `objc_precise_lifetime`. Exact lock errors are propagated unchanged on the main queue.

## TASK-3.1 and Backup non-regression

- `PXBackupPublicationWorkspace.h` remains byte-identical: SHA-256 `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851`, bytes=1869.
- `PXBackupPublicationWorkspace.m` remains byte-identical: SHA-256 `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6`, bytes=48086.
- Backup warning append sequence: baseline=12, current=12, exact order/text equal=True.
- Discovery method byte-identical: True.
- Restore body byte-identical: True.
- Public Backup selector byte-identical: True.
- Manifest version 3, field set, current atomic write call, temporary partial result, and zero publication rename are retained.

## Later-task boundaries

No TASK-3.3 verified writer, Preferences policy, required/optional policy, manifest v4/protocol, final rename/publication, centralized cleanup, stale-partial cleanup, Keychain redesign, UI result redesign, or legacy quarantine is included.

## Static and forbidden gates

| Gate | Required | Actual |
|---|---:|---:|
| error/field/name exports | 1/1/1 | 1/1/1 |
| error codes | 11 | 11 |
| class/properties/factory/validator | 1/4/1/1 | 1/4/1/1 |
| exclusive nonblocking flock sites | 1 | 1 |
| unlock flock sites | 1 | 1 |
| mkdirat/fstatat nofollow | 1/present | 1/5 |
| lock-file unlink/write/truncate | 0/0/0 | 0/0/0 |
| shell/process/sleep/publication rename | 0 | 0 |
| manager root/factory/validations | 1/1/4 | 1/1/4 |
| workspace factory/validations | 1/3 | 1/3 |
| TASK-3.1 workspace diff | 0 | 0 |
| warning sequence diff | 0 | 0 |
| Restore/list/UI/Makefile protected diff | 0 | 0 |
| lock frontend | PASS | PASS |
| manager integration frontend | PASS | PASS |
| git diff --check | PASS | PASS |

## Explicit scenario matrix

Explicit scenarios: 250.

| # | Scenario | Result | Evidence |
|---:|---|---|---|
| 1 | Error domain export | PASS static | Exact header inventory. |
| 2 | Field-path export | PASS static | Exact header inventory. |
| 3 | Lock-name export | PASS static | Exact header inventory. |
| 4 | Exact eleven-code enum | PASS static | Exact header inventory. |
| 5 | Subclassing-restricted class | PASS static | Exact header inventory. |
| 6 | Four copied readonly properties | PASS static | Exact header inventory. |
| 7 | Single public factory | PASS static | Exact header inventory. |
| 8 | Single public validator | PASS static | Exact header inventory. |
| 9 | init unavailable | PASS static | Exact header inventory. |
| 10 | new unavailable | PASS static | Exact header inventory. |
| 11 | No public descriptor | PASS static | Exact header inventory. |
| 12 | No public lock path | PASS static | Exact header inventory. |
| 13 | No public unlock | PASS static | Exact header inventory. |
| 14 | No timeout control | PASS static | Exact header inventory. |
| 15 | No wait control | PASS static | Exact header inventory. |
| 16 | No workspace API | PASS static | Exact header inventory. |
| 17 | No manifest API | PASS static | Exact header inventory. |
| 18 | No publication API | PASS static | Exact header inventory. |
| 19 | Runtime NSString root | accepted when valid | Input matrix and lossless UTF-8 boundary. |
| 20 | Nil root | InvalidInput | Input matrix and lossless UTF-8 boundary. |
| 21 | Non-string root | InvalidInput | Input matrix and lossless UTF-8 boundary. |
| 22 | Empty root | InvalidInput | Input matrix and lossless UTF-8 boundary. |
| 23 | Relative root | InvalidInput | Input matrix and lossless UTF-8 boundary. |
| 24 | Tilde root | InvalidInput | Input matrix and lossless UTF-8 boundary. |
| 25 | NUL root | InvalidInput | Input matrix and lossless UTF-8 boundary. |
| 26 | 4096-byte root | accepted | Input matrix and lossless UTF-8 boundary. |
| 27 | 4097-byte root | LimitExceeded | Input matrix and lossless UTF-8 boundary. |
| 28 | Trailing slash root | accepted with final-component inspection | Input matrix and lossless UTF-8 boundary. |
| 29 | Multiple trailing slashes | accepted with final-component inspection | Input matrix and lossless UTF-8 boundary. |
| 30 | UTF-8 root | accepted losslessly | Input matrix and lossless UTF-8 boundary. |
| 31 | Invalid UTF-8 round trip | rejected | Input matrix and lossless UTF-8 boundary. |
| 32 | Percent text root | not decoded | Input matrix and lossless UTF-8 boundary. |
| 33 | Dot-segment root | not standardized before proof | Input matrix and lossless UTF-8 boundary. |
| 34 | Valid bundle component | accepted exact | Bundle component matrix. |
| 35 | Empty bundle | InvalidInput | Bundle component matrix. |
| 36 | Whitespace-only bundle | InvalidInput | Bundle component matrix. |
| 37 | Dot bundle | InvalidInput | Bundle component matrix. |
| 38 | Dot-dot bundle | InvalidInput | Bundle component matrix. |
| 39 | Slash bundle | InvalidInput | Bundle component matrix. |
| 40 | Backslash bundle | InvalidInput | Bundle component matrix. |
| 41 | NUL bundle | InvalidInput | Bundle component matrix. |
| 42 | Newline bundle | InvalidInput | Bundle component matrix. |
| 43 | Tab bundle | InvalidInput | Bundle component matrix. |
| 44 | DEL bundle | InvalidInput | Bundle component matrix. |
| 45 | 255-byte bundle | accepted | Bundle component matrix. |
| 46 | 256-byte bundle | LimitExceeded | Bundle component matrix. |
| 47 | Multibyte 255-byte bundle | accepted | Bundle component matrix. |
| 48 | Multibyte over-limit bundle | LimitExceeded | Bundle component matrix. |
| 49 | Leading whitespace plus text | accepted unchanged | Bundle component matrix. |
| 50 | Trailing whitespace plus text | accepted unchanged | Bundle component matrix. |
| 51 | Mixed-case bundle | retained exact | Bundle component matrix. |
| 52 | Percent text bundle | not decoded | Bundle component matrix. |
| 53 | Unicode bundle | not normalized | Bundle component matrix. |
| 54 | Exact component used for mkdir/open | PASS static | Bundle component matrix. |
| 55 | Create missing root ancestors | PASS static/frontend | Root authority implementation. |
| 56 | Do not remove root on failure | PASS static/frontend | Root authority implementation. |
| 57 | Inspect requested final component with lstat | PASS static/frontend | Root authority implementation. |
| 58 | Reject final root symlink | PASS static/frontend | Root authority implementation. |
| 59 | Reject root non-directory | PASS static/frontend | Root authority implementation. |
| 60 | Reject root setuid | PASS static/frontend | Root authority implementation. |
| 61 | Reject root setgid | PASS static/frontend | Root authority implementation. |
| 62 | Canonicalize with realpath | PASS static/frontend | Root authority implementation. |
| 63 | Canonical UTF-8 round trip | PASS static/frontend | Root authority implementation. |
| 64 | Canonical root length bound | PASS static/frontend | Root authority implementation. |
| 65 | Open root O_DIRECTORY | PASS static/frontend | Root authority implementation. |
| 66 | Open root O_NOFOLLOW | PASS static/frontend | Root authority implementation. |
| 67 | Open root O_CLOEXEC | PASS static/frontend | Root authority implementation. |
| 68 | Verify root FD_CLOEXEC | PASS static/frontend | Root authority implementation. |
| 69 | Requested/canonical/descriptor identity equality | PASS static/frontend | Root authority implementation. |
| 70 | New final root fchmod 0700 | PASS static/frontend | Root authority implementation. |
| 71 | New final root mode verification | PASS static/frontend | Root authority implementation. |
| 72 | Allow normal ancestor alias after identity proof | PASS static/frontend | Root authority implementation. |
| 73 | Bundle fstatat nofollow | PASS static/frontend | Per-bundle authority implementation. |
| 74 | Bundle mkdirat 0700 when absent | PASS static/frontend | Per-bundle authority implementation. |
| 75 | Bundle symlink rejected | PASS static/frontend | Per-bundle authority implementation. |
| 76 | Bundle wrong type rejected | PASS static/frontend | Per-bundle authority implementation. |
| 77 | Bundle setuid rejected | PASS static/frontend | Per-bundle authority implementation. |
| 78 | Bundle setgid rejected | PASS static/frontend | Per-bundle authority implementation. |
| 79 | Bundle openat directory | PASS static/frontend | Per-bundle authority implementation. |
| 80 | Bundle O_NOFOLLOW | PASS static/frontend | Per-bundle authority implementation. |
| 81 | Bundle O_CLOEXEC | PASS static/frontend | Per-bundle authority implementation. |
| 82 | Bundle namespace/descriptor equality | PASS static/frontend | Per-bundle authority implementation. |
| 83 | Bundle same device as root | PASS static/frontend | Per-bundle authority implementation. |
| 84 | New bundle fchmod 0700 | PASS static/frontend | Per-bundle authority implementation. |
| 85 | New bundle exact mode verification | PASS static/frontend | Per-bundle authority implementation. |
| 86 | Canonical bundle path exact composition | PASS static/frontend | Per-bundle authority implementation. |
| 87 | Canonical bundle path descriptor proof | PASS static/frontend | Per-bundle authority implementation. |
| 88 | Root/bundle retained descriptors | PASS static/frontend | Per-bundle authority implementation. |
| 89 | Exact lock filename |  .weaponx-backup.lock | Persistent lock-file policy. |
| 90 | Lock is direct bundle child | descriptor-relative openat | Persistent lock-file policy. |
| 91 | Open includes O_RDWR | PASS | Persistent lock-file policy. |
| 92 | Open includes O_CREAT | PASS | Persistent lock-file policy. |
| 93 | Open includes O_NOFOLLOW | PASS | Persistent lock-file policy. |
| 94 | Open includes O_CLOEXEC | PASS | Persistent lock-file policy. |
| 95 | Open omits O_TRUNC | PASS | Persistent lock-file policy. |
| 96 | Create mode argument 0600 | PASS | Persistent lock-file policy. |
| 97 | Regular lock required | PASS | Persistent lock-file policy. |
| 98 | Symlink lock rejected | PASS | Persistent lock-file policy. |
| 99 | Directory lock rejected | PASS | Persistent lock-file policy. |
| 100 | FIFO lock rejected | PASS | Persistent lock-file policy. |
| 101 | Socket lock rejected | PASS | Persistent lock-file policy. |
| 102 | Character device lock rejected | PASS | Persistent lock-file policy. |
| 103 | Block device lock rejected | PASS | Persistent lock-file policy. |
| 104 | Lock nlink one required | PASS | Persistent lock-file policy. |
| 105 | Hard-linked lock rejected | PASS | Persistent lock-file policy. |
| 106 | Lock same device as bundle | PASS | Persistent lock-file policy. |
| 107 | Namespace stat matches descriptor | PASS | Persistent lock-file policy. |
| 108 | Mode forced to 0600 | PASS | Persistent lock-file policy. |
| 109 | Mode reinspected | PASS | Persistent lock-file policy. |
| 110 | FD_CLOEXEC verified | PASS | Persistent lock-file policy. |
| 111 | No PID write | PASS | Persistent lock-file policy. |
| 112 | No bundle-ID write | PASS | Persistent lock-file policy. |
| 113 | No path write | PASS | Persistent lock-file policy. |
| 114 | No truncation | PASS | Persistent lock-file policy. |
| 115 | No unlink on success | PASS | Persistent lock-file policy. |
| 116 | No unlink on contention | PASS | Persistent lock-file policy. |
| 117 | No unlink on factory failure | PASS | Persistent lock-file policy. |
| 118 | No unlink on dealloc | PASS | Persistent lock-file policy. |
| 119 | Persistent empty file reusable | PASS policy | Persistent lock-file policy. |
| 120 | One exclusive nonblocking acquisition site | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 121 | Exact LOCK_EX|LOCK_NB | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 122 | EINTR acquisition retry | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 123 | Success retained | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 124 | EWOULDBLOCK maps LockUnavailable | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 125 | EAGAIN maps LockUnavailable | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 126 | Other flock failure maps LockFileOpenFailed | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 127 | No blocking acquisition | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 128 | No sleep on contention | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 129 | No contention retry | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 130 | No configurable timeout | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 131 | No shared fallback | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 132 | No in-memory fallback | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 133 | No unlocked continuation | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 134 | Post-lock root proof repeated | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 135 | Post-lock bundle proof repeated | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 136 | Post-lock namespace/descriptor proof repeated | PASS | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 137 | Same-process independent opens contend on Darwin fileglob identity | PASS XNU source | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 138 | Crash closes descriptor and releases kernel lock | PASS kernel lifecycle | Nonblocking flock policy and Darwin XNU sys_flock fileglob ownership. |
| 139 | Same canonical root + same bundle serializes | PASS | Serialization/contention matrix. |
| 140 | Root alias + same bundle serializes | PASS | Serialization/contention matrix. |
| 141 | Same process concurrent operations serialize | PASS Darwin fileglob | Serialization/contention matrix. |
| 142 | Different process operations serialize | PASS flock | Serialization/contention matrix. |
| 143 | Different bundle under same root may proceed | PASS distinct sibling lock files | Serialization/contention matrix. |
| 144 | Same bundle under different physical roots may proceed | PASS distinct domain | Serialization/contention matrix. |
| 145 | Lock-file existence is not stale lock | PASS | Serialization/contention matrix. |
| 146 | Crash leaves persistent file | PASS | Serialization/contention matrix. |
| 147 | Next operation reuses inode | PASS | Serialization/contention matrix. |
| 148 | Contender gets nil result | PASS manager | Serialization/contention matrix. |
| 149 | Contender gets exact lock-domain error | PASS manager | Serialization/contention matrix. |
| 150 | Contender completion on main queue | PASS manager | Serialization/contention matrix. |
| 151 | Contender creates no workspace | PASS ordering | Serialization/contention matrix. |
| 152 | Contender kills no process | PASS ordering | Serialization/contention matrix. |
| 153 | Contender writes no output | PASS ordering | Serialization/contention matrix. |
| 154 | Contention is not warning | PASS | Serialization/contention matrix. |
| 155 | Validator clears error | PASS | Ownership validation proof. |
| 156 | Validator requires locked state | PASS | Ownership validation proof. |
| 157 | Validator does not reacquire | PASS | Ownership validation proof. |
| 158 | Root descriptor re-fstat | PASS | Ownership validation proof. |
| 159 | Bundle descriptor re-fstat | PASS | Ownership validation proof. |
| 160 | Lock descriptor re-fstat | PASS | Ownership validation proof. |
| 161 | Root retained identity | PASS | Ownership validation proof. |
| 162 | Bundle retained identity | PASS | Ownership validation proof. |
| 163 | Lock retained identity | PASS | Ownership validation proof. |
| 164 | Root directory type | PASS | Ownership validation proof. |
| 165 | Bundle directory type | PASS | Ownership validation proof. |
| 166 | Lock regular type | PASS | Ownership validation proof. |
| 167 | Lock nlink one | PASS | Ownership validation proof. |
| 168 | Lock mode 0600 | PASS | Ownership validation proof. |
| 169 | Root/bundle same device | PASS | Ownership validation proof. |
| 170 | Bundle/lock same device | PASS | Ownership validation proof. |
| 171 | Root FD_CLOEXEC | PASS | Ownership validation proof. |
| 172 | Bundle FD_CLOEXEC | PASS | Ownership validation proof. |
| 173 | Lock FD_CLOEXEC | PASS | Ownership validation proof. |
| 174 | Canonical root path identity | PASS | Ownership validation proof. |
| 175 | Canonical bundle path identity | PASS | Ownership validation proof. |
| 176 | Lock namespace nofollow identity | PASS | Ownership validation proof. |
| 177 | Unlink/recreate detected | PASS | Ownership validation proof. |
| 178 | Symlink replacement detected | PASS | Ownership validation proof. |
| 179 | Mode mutation detected | PASS | Ownership validation proof. |
| 180 | Hard-link mutation detected | PASS | Ownership validation proof. |
| 181 | Retained observations not updated | PASS | Ownership validation proof. |
| 182 | Object owns root descriptor | PASS | Descriptor and lock lifecycle. |
| 183 | Object owns bundle descriptor | PASS | Descriptor and lock lifecycle. |
| 184 | Object owns lock descriptor | PASS | Descriptor and lock lifecycle. |
| 185 | Object owns locked state | PASS | Descriptor and lock lifecycle. |
| 186 | Factory failure unlocks acquired lock | PASS | Descriptor and lock lifecycle. |
| 187 | Factory failure closes lock descriptor | PASS | Descriptor and lock lifecycle. |
| 188 | Factory failure closes bundle descriptor | PASS | Descriptor and lock lifecycle. |
| 189 | Factory failure closes root descriptor | PASS | Descriptor and lock lifecycle. |
| 190 | dealloc retries unlock only EINTR | PASS | Descriptor and lock lifecycle. |
| 191 | dealloc closes lock descriptor | PASS | Descriptor and lock lifecycle. |
| 192 | dealloc closes bundle descriptor | PASS | Descriptor and lock lifecycle. |
| 193 | dealloc closes root descriptor | PASS | Descriptor and lock lifecycle. |
| 194 | Close releases lock if explicit unlock fails | PASS kernel contract | Descriptor and lock lifecycle. |
| 195 | No early unlock API | PASS | Descriptor and lock lifecycle. |
| 196 | Public parameter guard unchanged | PASS | Manager source ordering/count proof. |
| 197 | Existing background queue retained | PASS | Manager source ordering/count proof. |
| 198 | Active profile read before root | PASS | Manager source ordering/count proof. |
| 199 | Backup root read once | PASS | Manager source ordering/count proof. |
| 200 | Lock factory called once | PASS | Manager source ordering/count proof. |
| 201 | Initial lock validation after factory | PASS | Manager source ordering/count proof. |
| 202 | Lock acquired before tar discovery | PASS | Manager source ordering/count proof. |
| 203 | Lock acquired before source resolution | PASS | Manager source ordering/count proof. |
| 204 | Lock acquired before timestamp | PASS | Manager source ordering/count proof. |
| 205 | Second lock validation before workspace | PASS | Manager source ordering/count proof. |
| 206 | Workspace factory called once | PASS | Manager source ordering/count proof. |
| 207 | Same backupRoot reused for workspace | PASS | Manager source ordering/count proof. |
| 208 | Workspace validations remain three | PASS | Manager source ordering/count proof. |
| 209 | Lock held before groups/preferences | PASS | Manager source ordering/count proof. |
| 210 | Lock held before debug writes | PASS | Manager source ordering/count proof. |
| 211 | Lock held before first process kill | PASS | Manager source ordering/count proof. |
| 212 | Lock held during archive generation | PASS | Manager source ordering/count proof. |
| 213 | Third lock validation before manifest | PASS | Manager source ordering/count proof. |
| 214 | Fourth lock validation before result | PASS | Manager source ordering/count proof. |
| 215 | Lock precise lifetime retained | PASS | Manager source ordering/count proof. |
| 216 | Workspace precise lifetime retained | PASS | Manager source ordering/count proof. |
| 217 | Lock error propagated exactly | PASS | Manager source ordering/count proof. |
| 218 | Validation error propagated exactly | PASS | Manager source ordering/count proof. |
| 219 | Lock failures return nil result | PASS | Manager source ordering/count proof. |
| 220 | Lock failures dispatch main queue | PASS | Manager source ordering/count proof. |
| 221 | No manager-domain contention code | PASS | Manager source ordering/count proof. |
| 222 | Temporary partial result unchanged | PASS | Manager source ordering/count proof. |
| 223 | TASK-3.1 workspace header byte-identical | PASS hash | Non-regression and later-task boundary. |
| 224 | TASK-3.1 workspace source byte-identical | PASS hash | Non-regression and later-task boundary. |
| 225 | Partial prefix unchanged | PASS protected | Non-regression and later-task boundary. |
| 226 | mkdtemp workspace unchanged | PASS protected | Non-regression and later-task boundary. |
| 227 | Workspace mode 0700 unchanged | PASS protected | Non-regression and later-task boundary. |
| 228 | Three workspace validations retained | PASS | Non-regression and later-task boundary. |
| 229 | Discovery method byte-identical | PASS | Non-regression and later-task boundary. |
| 230 | Partial-prefix skips unchanged | PASS | Non-regression and later-task boundary. |
| 231 | Temporary workspace result unchanged | PASS | Non-regression and later-task boundary. |
| 232 | No publication rename | PASS | Non-regression and later-task boundary. |
| 233 | No centralized partial cleanup | PASS | Non-regression and later-task boundary. |
| 234 | Lock file is workspace sibling | PASS path authority | Non-regression and later-task boundary. |
| 235 | Backup selector byte-identical | PASS | Non-regression and later-task boundary. |
| 236 | Timestamp format unchanged | PASS protected method | Non-regression and later-task boundary. |
| 237 | Tar preference unchanged | PASS warning/body comparison | Non-regression and later-task boundary. |
| 238 | Source resolution semantics unchanged | PASS body order after lock | Non-regression and later-task boundary. |
| 239 | Process-kill relative artifact timing unchanged | PASS | Non-regression and later-task boundary. |
| 240 | Backup warnings 12/12 exact order | PASS | Non-regression and later-task boundary. |
| 241 | Manifest version 3 retained | PASS | Non-regression and later-task boundary. |
| 242 | Manifest field set unchanged | PASS manager diff | Non-regression and later-task boundary. |
| 243 | Manifest write semantics unchanged | PASS | Non-regression and later-task boundary. |
| 244 | PXBackupResult fields unchanged | PASS | Non-regression and later-task boundary. |
| 245 | Restore body byte-identical | PASS | Non-regression and later-task boundary. |
| 246 | UI protected diff zero | PASS | Non-regression and later-task boundary. |
| 247 | Keychain protected diff zero | PASS | Non-regression and later-task boundary. |
| 248 | Makefile byte-identical | PASS | Non-regression and later-task boundary. |
| 249 | No TASK-3.3 writer | PASS | Non-regression and later-task boundary. |
| 250 | No later task started | PASS | Non-regression and later-task boundary. |

## Whitespace, CRLF, NUL, and generated-file audit

- `PXBackupBundleLock.h`: bytes=1714, SHA-256=`6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9`, CRLF=0, bare LF=43, NUL=0, final newline=True.
- `PXBackupBundleLock.m`: bytes=36342, SHA-256=`563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b`, CRLF=0, bare LF=888, NUL=0, final newline=True.
- `AppDataBackupManager.m`: bytes=198914, SHA-256=`905343e5e401595733804c46ce097e86c6cd7544b8964fe36411dd88400fd873`, CRLF=0, bare LF=3726, NUL=0, final newline=True.
- Temporary frontend stubs and the report generator are outside the implementation scope and will not be committed.
- Authorized source diff check: PASS.

## Build status and remaining runtime risks

- Strict Objective-C frontend gates pass for the pure lock source and exact manager integration blocks.
- Local Windows workspace has no Theos, Apple clang, `make`, or `xcrun`; GitHub Actions/Theos remains the authoritative build/link gate.
- Remaining runtime risk is target-filesystem and target-kernel behavior that cannot be executed in this Windows workspace. Darwin XNU source review supports same-process independent-fileglob contention semantics.

## Full authorized production diff

```diff
diff --git a/PXBackupBundleLock.h b/PXBackupBundleLock.h
new file mode 100644
--- a/PXBackupBundleLock.h
+++ b/PXBackupBundleLock.h
@@ -0,0 +1,43 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSErrorDomain const PXBackupBundleLockErrorDomain;
+FOUNDATION_EXPORT NSString * const PXBackupBundleLockErrorFieldPathKey;
+FOUNDATION_EXPORT NSString * const PXBackupBundleLockFileName;
+
+typedef NS_ERROR_ENUM(PXBackupBundleLockErrorDomain,
+                      PXBackupBundleLockErrorCode) {
+    PXBackupBundleLockErrorInvalidInput = 1,
+    PXBackupBundleLockErrorRootCreationFailed = 2,
+    PXBackupBundleLockErrorRootInspectionFailed = 3,
+    PXBackupBundleLockErrorUnsafeRoot = 4,
+    PXBackupBundleLockErrorBundleDirectoryCreationFailed = 5,
+    PXBackupBundleLockErrorBundleDirectoryInvalid = 6,
+    PXBackupBundleLockErrorLockFileOpenFailed = 7,
+    PXBackupBundleLockErrorLockFileInvalid = 8,
+    PXBackupBundleLockErrorLockUnavailable = 9,
+    PXBackupBundleLockErrorFilesystemChanged = 10,
+    PXBackupBundleLockErrorLimitExceeded = 11,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupBundleLock : NSObject
+
+@property (nonatomic, copy, readonly) NSString *canonicalBackupRootPath;
+@property (nonatomic, copy, readonly) NSString *canonicalBundleDirectoryPath;
+@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
+@property (nonatomic, copy, readonly) NSString *lockFileName;
+
++ (nullable instancetype)acquireLockAtBackupRoot:(NSString *)backupRoot
+                                bundleIdentifier:(NSString *)bundleIdentifier
+                                           error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)validateOwnershipWithError:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXBackupBundleLock.m b/PXBackupBundleLock.m
new file mode 100644
--- a/PXBackupBundleLock.m
+++ b/PXBackupBundleLock.m
@@ -0,0 +1,888 @@
+#import "PXBackupBundleLock.h"
+
+#include <errno.h>
+#include <fcntl.h>
+#include <limits.h>
+#include <stdint.h>
+#include <stdlib.h>
+#include <string.h>
+#include <sys/file.h>
+#include <sys/stat.h>
+#include <sys/types.h>
+#include <unistd.h>
+
+NSErrorDomain const PXBackupBundleLockErrorDomain =
+    @"com.hydra.projectx.backup-bundle-lock";
+NSString * const PXBackupBundleLockErrorFieldPathKey = @"fieldPath";
+NSString * const PXBackupBundleLockFileName = @".weaponx-backup.lock";
+
+static NSString * const PXBackupBundleLockBackupRootField = @"$.backupRoot";
+static NSString * const PXBackupBundleLockBundleIdentifierField = @"$.bundleIdentifier";
+static NSString * const PXBackupBundleLockBundleDirectoryField = @"$.bundleDirectory";
+static NSString * const PXBackupBundleLockLockField = @"$.lock";
+
+static const NSUInteger PXBackupBundleLockMaximumRootBytes = 4096;
+static const NSUInteger PXBackupBundleLockMaximumComponentBytes = 255;
+static const char PXBackupBundleLockFileNameCString[] = ".weaponx-backup.lock";
+
+static void PXBackupBundleLockSetError(NSError **error,
+                                       PXBackupBundleLockErrorCode code,
+                                       NSString *fieldPath,
+                                       NSString *description) {
+    if (!error) {
+        return;
+    }
+    *error = [NSError errorWithDomain:PXBackupBundleLockErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXBackupBundleLockErrorFieldPathKey: fieldPath,
+                             }];
+}
+
+static BOOL PXBackupBundleLockStatIdentityMatches(const struct stat *left,
+                                                   const struct stat *right) {
+    return left && right &&
+           left->st_dev == right->st_dev &&
+           left->st_ino == right->st_ino &&
+           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
+}
+
+static BOOL PXBackupBundleLockDescriptorHasCloseOnExec(int descriptor) {
+    if (descriptor < 0) {
+        return NO;
+    }
+    int flags = -1;
+    do {
+        flags = fcntl(descriptor, F_GETFD);
+    } while (flags < 0 && errno == EINTR);
+    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
+}
+
+static BOOL PXBackupBundleLockStringContainsNull(NSString *value) {
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static NSData *PXBackupBundleLockLosslessUTF8Data(NSString *value) {
+    if (![value isKindOfClass:[NSString class]] ||
+        PXBackupBundleLockStringContainsNull(value)) {
+        return nil;
+    }
+    return [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+}
+
+static BOOL PXBackupBundleLockValidateBackupRoot(NSString *backupRoot,
+                                                  NSData **utf8Data,
+                                                  BOOL *limitExceeded) {
+    if (utf8Data) {
+        *utf8Data = nil;
+    }
+    if (limitExceeded) {
+        *limitExceeded = NO;
+    }
+    if (![backupRoot isKindOfClass:[NSString class]] ||
+        backupRoot.length == 0 ||
+        ![backupRoot hasPrefix:@"/"] ||
+        PXBackupBundleLockStringContainsNull(backupRoot)) {
+        return NO;
+    }
+    NSData *data = PXBackupBundleLockLosslessUTF8Data(backupRoot);
+    if (!data || data.length == 0) {
+        return NO;
+    }
+    if (data.length > PXBackupBundleLockMaximumRootBytes) {
+        if (limitExceeded) {
+            *limitExceeded = YES;
+        }
+        return NO;
+    }
+    if (utf8Data) {
+        *utf8Data = data;
+    }
+    return YES;
+}
+
+static BOOL PXBackupBundleLockValidateSafeComponent(NSString *component,
+                                                     NSData **utf8Data,
+                                                     BOOL *limitExceeded) {
+    if (utf8Data) {
+        *utf8Data = nil;
+    }
+    if (limitExceeded) {
+        *limitExceeded = NO;
+    }
+    if (![component isKindOfClass:[NSString class]] ||
+        component.length == 0 ||
+        [component isEqualToString:@"."] ||
+        [component isEqualToString:@".."]) {
+        return NO;
+    }
+    BOOL containsNonWhitespace = NO;
+    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
+    for (NSUInteger index = 0; index < component.length; index++) {
+        unichar character = [component characterAtIndex:index];
+        if (character == 0 || character == '/' || character == '\\' ||
+            character < 0x20 || character == 0x7f) {
+            return NO;
+        }
+        if (![whitespace characterIsMember:character]) {
+            containsNonWhitespace = YES;
+        }
+    }
+    if (!containsNonWhitespace) {
+        return NO;
+    }
+    NSData *data = PXBackupBundleLockLosslessUTF8Data(component);
+    if (!data || data.length == 0) {
+        return NO;
+    }
+    if (data.length > PXBackupBundleLockMaximumComponentBytes) {
+        if (limitExceeded) {
+            *limitExceeded = YES;
+        }
+        return NO;
+    }
+    if (utf8Data) {
+        *utf8Data = data;
+    }
+    return YES;
+}
+
+static char *PXBackupBundleLockCopyCString(NSData *data) {
+    if (![data isKindOfClass:[NSData class]] || data.length > SIZE_MAX - 1) {
+        return NULL;
+    }
+    char *result = calloc(data.length + 1, 1);
+    if (!result) {
+        return NULL;
+    }
+    if (data.length > 0) {
+        memcpy(result, data.bytes, data.length);
+    }
+    result[data.length] = '\0';
+    return result;
+}
+
+static char *PXBackupBundleLockCopyFinalComponentInspectionPath(const char *path) {
+    if (!path || path[0] != '/') {
+        return NULL;
+    }
+    char *result = strdup(path);
+    if (!result) {
+        return NULL;
+    }
+    size_t length = strlen(result);
+    while (length > 1 && result[length - 1] == '/') {
+        result[length - 1] = '\0';
+        length--;
+    }
+    return result;
+}
+
+static BOOL PXBackupBundleLockEnsureRootExists(const char *path,
+                                                BOOL *finalDirectoryCreated) {
+    if (finalDirectoryCreated) {
+        *finalDirectoryCreated = NO;
+    }
+    if (!path || path[0] != '/') {
+        return NO;
+    }
+    if (strcmp(path, "/") == 0) {
+        return YES;
+    }
+    size_t length = strlen(path);
+    size_t finalComponentLength = length;
+    while (finalComponentLength > 1 && path[finalComponentLength - 1] == '/') {
+        finalComponentLength--;
+    }
+    char *mutablePath = strdup(path);
+    if (!mutablePath) {
+        return NO;
+    }
+    BOOL success = YES;
+    for (size_t index = 1; index < length; index++) {
+        if (mutablePath[index] != '/' || mutablePath[index - 1] == '/') {
+            continue;
+        }
+        mutablePath[index] = '\0';
+        if (mkdir(mutablePath, 0700) == 0) {
+            if (finalDirectoryCreated && index == finalComponentLength) {
+                *finalDirectoryCreated = YES;
+            }
+        } else if (errno != EEXIST) {
+            success = NO;
+            mutablePath[index] = '/';
+            break;
+        }
+        mutablePath[index] = '/';
+    }
+    if (success) {
+        if (mkdir(mutablePath, 0700) == 0) {
+            if (finalDirectoryCreated) {
+                *finalDirectoryCreated = YES;
+            }
+        } else if (errno != EEXIST) {
+            success = NO;
+        }
+    }
+    free(mutablePath);
+    return success;
+}
+
+static NSString *PXBackupBundleLockStringFromFileSystemBytes(const char *bytes,
+                                                              NSUInteger maximumBytes) {
+    if (!bytes) {
+        return nil;
+    }
+    size_t length = strlen(bytes);
+    if (length == 0 || length > maximumBytes) {
+        return nil;
+    }
+    NSString *string = [[NSString alloc] initWithBytes:bytes
+                                                length:length
+                                              encoding:NSUTF8StringEncoding];
+    if (!string) {
+        return nil;
+    }
+    NSData *roundTrip = [string dataUsingEncoding:NSUTF8StringEncoding
+                              allowLossyConversion:NO];
+    if (!roundTrip || roundTrip.length != length ||
+        memcmp(roundTrip.bytes, bytes, length) != 0) {
+        return nil;
+    }
+    return string;
+}
+
+static NSString *PXBackupBundleLockAppendComponent(NSString *parent,
+                                                    NSString *component) {
+    if ([parent isEqualToString:@"/"]) {
+        return [@"/" stringByAppendingString:component];
+    }
+    return [NSString stringWithFormat:@"%@/%@", parent, component];
+}
+
+static BOOL PXBackupBundleLockDirectoryPathMatchesDescriptor(
+    NSString *path,
+    int descriptor,
+    const struct stat *expected) {
+    NSData *pathData = PXBackupBundleLockLosslessUTF8Data(path);
+    char *pathCString = PXBackupBundleLockCopyCString(pathData);
+    if (!pathCString) {
+        return NO;
+    }
+    struct stat pathStat;
+    struct stat descriptorStat;
+    BOOL valid = lstat(pathCString, &pathStat) == 0 &&
+                 !S_ISLNK(pathStat.st_mode) &&
+                 S_ISDIR(pathStat.st_mode) &&
+                 fstat(descriptor, &descriptorStat) == 0 &&
+                 S_ISDIR(descriptorStat.st_mode) &&
+                 PXBackupBundleLockStatIdentityMatches(&pathStat, &descriptorStat) &&
+                 (!expected ||
+                  PXBackupBundleLockStatIdentityMatches(expected, &descriptorStat));
+    free(pathCString);
+    return valid;
+}
+
+static BOOL PXBackupBundleLockProofIsValid(
+    NSString *canonicalRootPath,
+    NSString *canonicalBundlePath,
+    NSString *bundleIdentifier,
+    int rootDescriptor,
+    int bundleDescriptor,
+    int lockDescriptor,
+    const struct stat *expectedRoot,
+    const struct stat *expectedBundle,
+    const struct stat *expectedLock) {
+    if (![canonicalRootPath isKindOfClass:[NSString class]] ||
+        ![canonicalBundlePath isKindOfClass:[NSString class]] ||
+        ![bundleIdentifier isKindOfClass:[NSString class]] ||
+        rootDescriptor < 0 || bundleDescriptor < 0 || lockDescriptor < 0 ||
+        !expectedRoot || !expectedBundle || !expectedLock ||
+        ![canonicalBundlePath isEqualToString:
+            PXBackupBundleLockAppendComponent(canonicalRootPath,
+                                               bundleIdentifier)]) {
+        return NO;
+    }
+
+    struct stat rootStat;
+    struct stat bundleStat;
+    struct stat lockStat;
+    struct stat lockNamespaceStat;
+    if (fstat(rootDescriptor, &rootStat) != 0 ||
+        fstat(bundleDescriptor, &bundleStat) != 0 ||
+        fstat(lockDescriptor, &lockStat) != 0 ||
+        fstatat(bundleDescriptor,
+                PXBackupBundleLockFileNameCString,
+                &lockNamespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0) {
+        return NO;
+    }
+    if (!S_ISDIR(rootStat.st_mode) ||
+        !S_ISDIR(bundleStat.st_mode) ||
+        !S_ISREG(lockStat.st_mode) ||
+        !S_ISREG(lockNamespaceStat.st_mode) ||
+        (rootStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (bundleStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (lockStat.st_mode & 07777) != 0600 ||
+        lockStat.st_nlink != 1 ||
+        lockNamespaceStat.st_nlink != 1 ||
+        rootStat.st_dev != bundleStat.st_dev ||
+        bundleStat.st_dev != lockStat.st_dev ||
+        !PXBackupBundleLockStatIdentityMatches(&rootStat, expectedRoot) ||
+        !PXBackupBundleLockStatIdentityMatches(&bundleStat, expectedBundle) ||
+        !PXBackupBundleLockStatIdentityMatches(&lockStat, expectedLock) ||
+        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, expectedLock) ||
+        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, &lockStat) ||
+        !PXBackupBundleLockDescriptorHasCloseOnExec(rootDescriptor) ||
+        !PXBackupBundleLockDescriptorHasCloseOnExec(bundleDescriptor) ||
+        !PXBackupBundleLockDescriptorHasCloseOnExec(lockDescriptor)) {
+        return NO;
+    }
+    return PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalRootPath,
+                                                             rootDescriptor,
+                                                             expectedRoot) &&
+           PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalBundlePath,
+                                                             bundleDescriptor,
+                                                             expectedBundle);
+}
+
+static int PXBackupBundleLockExclusiveNonblocking(int descriptor) {
+    int result = -1;
+    do {
+        result = flock(descriptor, LOCK_EX | LOCK_NB);
+    } while (result != 0 && errno == EINTR);
+    return result;
+}
+
+static void PXBackupBundleLockBestEffortUnlock(int descriptor) {
+    if (descriptor < 0) {
+        return;
+    }
+    int result = -1;
+    do {
+        result = flock(descriptor, LOCK_UN);
+    } while (result != 0 && errno == EINTR);
+}
+
+@interface PXBackupBundleLock ()
+
+- (instancetype)initWithCanonicalBackupRootPath:(NSString *)canonicalBackupRootPath
+                   canonicalBundleDirectoryPath:(NSString *)canonicalBundleDirectoryPath
+                               bundleIdentifier:(NSString *)bundleIdentifier
+                                    lockFileName:(NSString *)lockFileName
+                                  rootDescriptor:(int)rootDescriptor
+                                bundleDescriptor:(int)bundleDescriptor
+                                  lockDescriptor:(int)lockDescriptor
+                                    rootIdentity:(const struct stat *)rootIdentity
+                                  bundleIdentity:(const struct stat *)bundleIdentity
+                                    lockIdentity:(const struct stat *)lockIdentity;
+
+@end
+
+@implementation PXBackupBundleLock {
+    NSString *_canonicalBackupRootPath;
+    NSString *_canonicalBundleDirectoryPath;
+    NSString *_bundleIdentifier;
+    NSString *_lockFileName;
+    int _rootDescriptor;
+    int _bundleDescriptor;
+    int _lockDescriptor;
+    BOOL _locked;
+    struct stat _rootIdentity;
+    struct stat _bundleIdentity;
+    struct stat _lockIdentity;
+}
+
++ (nullable instancetype)acquireLockAtBackupRoot:(NSString *)backupRoot
+                                bundleIdentifier:(NSString *)bundleIdentifier
+                                           error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+
+    NSData *rootData = nil;
+    NSData *bundleData = nil;
+    NSData *canonicalBundleData = nil;
+    BOOL rootLimitExceeded = NO;
+    BOOL bundleLimitExceeded = NO;
+    char *requestedRootCString = NULL;
+    char *requestedRootInspectionCString = NULL;
+    char *bundleCString = NULL;
+    char *canonicalRootCString = NULL;
+    NSString *canonicalRootPath = nil;
+    NSString *canonicalBundlePath = nil;
+    int rootDescriptor = -1;
+    int bundleDescriptor = -1;
+    int lockDescriptor = -1;
+    BOOL rootCreated = NO;
+    BOOL bundleCreated = NO;
+    BOOL lockAcquired = NO;
+    struct stat requestedRootStat;
+    struct stat canonicalRootStat;
+    struct stat rootStat;
+    struct stat bundleNamespaceStat;
+    struct stat bundleStat;
+    struct stat lockNamespaceStat;
+    struct stat lockStat;
+    PXBackupBundleLock *result = nil;
+
+    if (!PXBackupBundleLockValidateBackupRoot(backupRoot,
+                                              &rootData,
+                                              &rootLimitExceeded)) {
+        PXBackupBundleLockSetError(error,
+                                   rootLimitExceeded
+                                       ? PXBackupBundleLockErrorLimitExceeded
+                                       : PXBackupBundleLockErrorInvalidInput,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root is invalid");
+        goto cleanup;
+    }
+    if (!PXBackupBundleLockValidateSafeComponent(bundleIdentifier,
+                                                 &bundleData,
+                                                 &bundleLimitExceeded)) {
+        PXBackupBundleLockSetError(error,
+                                   bundleLimitExceeded
+                                       ? PXBackupBundleLockErrorLimitExceeded
+                                       : PXBackupBundleLockErrorInvalidInput,
+                                   PXBackupBundleLockBundleIdentifierField,
+                                   @"The bundle identifier is invalid");
+        goto cleanup;
+    }
+
+    requestedRootCString = PXBackupBundleLockCopyCString(rootData);
+    requestedRootInspectionCString =
+        PXBackupBundleLockCopyFinalComponentInspectionPath(requestedRootCString);
+    bundleCString = PXBackupBundleLockCopyCString(bundleData);
+    if (!requestedRootCString || !requestedRootInspectionCString || !bundleCString) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorLimitExceeded,
+                                   (!requestedRootCString ||
+                                    !requestedRootInspectionCString)
+                                       ? PXBackupBundleLockBackupRootField
+                                       : PXBackupBundleLockBundleIdentifierField,
+                                   @"A lock input exceeded resource limits");
+        goto cleanup;
+    }
+
+    if (!PXBackupBundleLockEnsureRootExists(requestedRootCString, &rootCreated)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorRootCreationFailed,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root could not be created");
+        goto cleanup;
+    }
+    if (lstat(requestedRootInspectionCString, &requestedRootStat) != 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorRootInspectionFailed,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root could not be inspected");
+        goto cleanup;
+    }
+    if (S_ISLNK(requestedRootStat.st_mode) ||
+        !S_ISDIR(requestedRootStat.st_mode) ||
+        (requestedRootStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorUnsafeRoot,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root is unsafe");
+        goto cleanup;
+    }
+
+    canonicalRootCString = realpath(requestedRootCString, NULL);
+    if (!canonicalRootCString) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorRootInspectionFailed,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root could not be canonicalized");
+        goto cleanup;
+    }
+    canonicalRootPath = PXBackupBundleLockStringFromFileSystemBytes(
+        canonicalRootCString,
+        PXBackupBundleLockMaximumRootBytes);
+    if (!canonicalRootPath || ![canonicalRootPath hasPrefix:@"/"]) {
+        PXBackupBundleLockSetError(error,
+                                   strlen(canonicalRootCString) >
+                                           PXBackupBundleLockMaximumRootBytes
+                                       ? PXBackupBundleLockErrorLimitExceeded
+                                       : PXBackupBundleLockErrorRootInspectionFailed,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The canonical backup root is invalid");
+        goto cleanup;
+    }
+    if (lstat(canonicalRootCString, &canonicalRootStat) != 0 ||
+        S_ISLNK(canonicalRootStat.st_mode) ||
+        !S_ISDIR(canonicalRootStat.st_mode)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorRootInspectionFailed,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The canonical backup root could not be inspected");
+        goto cleanup;
+    }
+
+    rootDescriptor = open(canonicalRootCString,
+                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (rootDescriptor < 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorRootInspectionFailed,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root could not be opened safely");
+        goto cleanup;
+    }
+    if (rootCreated && fchmod(rootDescriptor, 0700) != 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorRootInspectionFailed,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root permissions could not be secured");
+        goto cleanup;
+    }
+    if (fstat(rootDescriptor, &rootStat) != 0 ||
+        !S_ISDIR(rootStat.st_mode) ||
+        (rootStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (rootCreated && (rootStat.st_mode & 07777) != 0700) ||
+        !PXBackupBundleLockDescriptorHasCloseOnExec(rootDescriptor)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorUnsafeRoot,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root descriptor is invalid");
+        goto cleanup;
+    }
+    if (lstat(requestedRootInspectionCString, &requestedRootStat) != 0 ||
+        lstat(canonicalRootCString, &canonicalRootStat) != 0 ||
+        S_ISLNK(requestedRootStat.st_mode) ||
+        S_ISLNK(canonicalRootStat.st_mode) ||
+        !PXBackupBundleLockStatIdentityMatches(&requestedRootStat, &rootStat) ||
+        !PXBackupBundleLockStatIdentityMatches(&canonicalRootStat, &rootStat)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorFilesystemChanged,
+                                   PXBackupBundleLockBackupRootField,
+                                   @"The backup root identity changed");
+        goto cleanup;
+    }
+
+    if (fstatat(rootDescriptor,
+                bundleCString,
+                &bundleNamespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0) {
+        if (errno != ENOENT) {
+            PXBackupBundleLockSetError(error,
+                                       PXBackupBundleLockErrorBundleDirectoryInvalid,
+                                       PXBackupBundleLockBundleDirectoryField,
+                                       @"The bundle directory could not be inspected");
+            goto cleanup;
+        }
+        if (mkdirat(rootDescriptor, bundleCString, 0700) != 0) {
+            PXBackupBundleLockSetError(
+                error,
+                PXBackupBundleLockErrorBundleDirectoryCreationFailed,
+                PXBackupBundleLockBundleDirectoryField,
+                @"The bundle directory could not be created");
+            goto cleanup;
+        }
+        bundleCreated = YES;
+        if (fstatat(rootDescriptor,
+                    bundleCString,
+                    &bundleNamespaceStat,
+                    AT_SYMLINK_NOFOLLOW) != 0) {
+            PXBackupBundleLockSetError(error,
+                                       PXBackupBundleLockErrorBundleDirectoryInvalid,
+                                       PXBackupBundleLockBundleDirectoryField,
+                                       @"The bundle directory could not be inspected");
+            goto cleanup;
+        }
+    }
+    if (!S_ISDIR(bundleNamespaceStat.st_mode) ||
+        (bundleNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
+                                   PXBackupBundleLockBundleDirectoryField,
+                                   @"The bundle directory is invalid");
+        goto cleanup;
+    }
+
+    bundleDescriptor = openat(rootDescriptor,
+                              bundleCString,
+                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (bundleDescriptor < 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
+                                   PXBackupBundleLockBundleDirectoryField,
+                                   @"The bundle directory could not be opened safely");
+        goto cleanup;
+    }
+    if (bundleCreated && fchmod(bundleDescriptor, 0700) != 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
+                                   PXBackupBundleLockBundleDirectoryField,
+                                   @"The bundle directory permissions could not be secured");
+        goto cleanup;
+    }
+    if (fstat(bundleDescriptor, &bundleStat) != 0 ||
+        !S_ISDIR(bundleStat.st_mode) ||
+        (bundleStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (bundleCreated && (bundleStat.st_mode & 07777) != 0700) ||
+        bundleStat.st_dev != rootStat.st_dev ||
+        !PXBackupBundleLockStatIdentityMatches(&bundleNamespaceStat, &bundleStat) ||
+        !PXBackupBundleLockDescriptorHasCloseOnExec(bundleDescriptor)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
+                                   PXBackupBundleLockBundleDirectoryField,
+                                   @"The bundle directory descriptor is invalid");
+        goto cleanup;
+    }
+
+    canonicalBundlePath = PXBackupBundleLockAppendComponent(canonicalRootPath,
+                                                             bundleIdentifier);
+    canonicalBundleData = PXBackupBundleLockLosslessUTF8Data(canonicalBundlePath);
+    if (!canonicalBundleData ||
+        canonicalBundleData.length > PXBackupBundleLockMaximumRootBytes) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorLimitExceeded,
+                                   PXBackupBundleLockBundleDirectoryField,
+                                   @"The bundle directory path exceeded resource limits");
+        goto cleanup;
+    }
+    if (!PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalRootPath,
+                                                           rootDescriptor,
+                                                           &rootStat) ||
+        !PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalBundlePath,
+                                                           bundleDescriptor,
+                                                           &bundleStat)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorFilesystemChanged,
+                                   PXBackupBundleLockBundleDirectoryField,
+                                   @"The bundle directory identity changed");
+        goto cleanup;
+    }
+
+    lockDescriptor = openat(bundleDescriptor,
+                            PXBackupBundleLockFileNameCString,
+                            O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC,
+                            0600);
+    if (lockDescriptor < 0) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorLockFileOpenFailed,
+                                   PXBackupBundleLockLockField,
+                                   @"The bundle lock file could not be opened");
+        goto cleanup;
+    }
+    if (fstat(lockDescriptor, &lockStat) != 0 ||
+        fstatat(bundleDescriptor,
+                PXBackupBundleLockFileNameCString,
+                &lockNamespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISREG(lockStat.st_mode) ||
+        !S_ISREG(lockNamespaceStat.st_mode) ||
+        lockStat.st_nlink != 1 ||
+        lockNamespaceStat.st_nlink != 1 ||
+        lockStat.st_dev != bundleStat.st_dev ||
+        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, &lockStat)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorLockFileInvalid,
+                                   PXBackupBundleLockLockField,
+                                   @"The bundle lock file is invalid");
+        goto cleanup;
+    }
+    if (fchmod(lockDescriptor, 0600) != 0 ||
+        fstat(lockDescriptor, &lockStat) != 0 ||
+        fstatat(bundleDescriptor,
+                PXBackupBundleLockFileNameCString,
+                &lockNamespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISREG(lockStat.st_mode) ||
+        !S_ISREG(lockNamespaceStat.st_mode) ||
+        (lockStat.st_mode & 07777) != 0600 ||
+        lockStat.st_nlink != 1 ||
+        lockNamespaceStat.st_nlink != 1 ||
+        lockStat.st_dev != bundleStat.st_dev ||
+        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, &lockStat) ||
+        !PXBackupBundleLockDescriptorHasCloseOnExec(lockDescriptor)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorLockFileInvalid,
+                                   PXBackupBundleLockLockField,
+                                   @"The bundle lock file descriptor is invalid");
+        goto cleanup;
+    }
+
+    if (PXBackupBundleLockExclusiveNonblocking(lockDescriptor) != 0) {
+        PXBackupBundleLockErrorCode code =
+            (errno == EWOULDBLOCK || errno == EAGAIN)
+                ? PXBackupBundleLockErrorLockUnavailable
+                : PXBackupBundleLockErrorLockFileOpenFailed;
+        PXBackupBundleLockSetError(error,
+                                   code,
+                                   PXBackupBundleLockLockField,
+                                   code == PXBackupBundleLockErrorLockUnavailable
+                                       ? @"The bundle backup lock is unavailable"
+                                       : @"The bundle backup lock could not be acquired");
+        goto cleanup;
+    }
+    lockAcquired = YES;
+
+    if (!PXBackupBundleLockProofIsValid(canonicalRootPath,
+                                        canonicalBundlePath,
+                                        bundleIdentifier,
+                                        rootDescriptor,
+                                        bundleDescriptor,
+                                        lockDescriptor,
+                                        &rootStat,
+                                        &bundleStat,
+                                        &lockStat)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorFilesystemChanged,
+                                   PXBackupBundleLockLockField,
+                                   @"The bundle lock identity changed");
+        goto cleanup;
+    }
+
+    result = [[PXBackupBundleLock alloc]
+        initWithCanonicalBackupRootPath:canonicalRootPath
+           canonicalBundleDirectoryPath:canonicalBundlePath
+                       bundleIdentifier:bundleIdentifier
+                            lockFileName:PXBackupBundleLockFileName
+                          rootDescriptor:rootDescriptor
+                        bundleDescriptor:bundleDescriptor
+                          lockDescriptor:lockDescriptor
+                            rootIdentity:&rootStat
+                          bundleIdentity:&bundleStat
+                            lockIdentity:&lockStat];
+    if (!result) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorLockFileInvalid,
+                                   PXBackupBundleLockLockField,
+                                   @"The bundle lock could not be retained");
+        goto cleanup;
+    }
+    rootDescriptor = -1;
+    bundleDescriptor = -1;
+    lockDescriptor = -1;
+    lockAcquired = NO;
+
+cleanup:
+    if (lockAcquired && lockDescriptor >= 0) {
+        PXBackupBundleLockBestEffortUnlock(lockDescriptor);
+    }
+    if (lockDescriptor >= 0) {
+        close(lockDescriptor);
+    }
+    if (bundleDescriptor >= 0) {
+        close(bundleDescriptor);
+    }
+    if (rootDescriptor >= 0) {
+        close(rootDescriptor);
+    }
+    free(canonicalRootCString);
+    free(bundleCString);
+    free(requestedRootInspectionCString);
+    free(requestedRootCString);
+    return result;
+}
+
+- (instancetype)initWithCanonicalBackupRootPath:(NSString *)canonicalBackupRootPath
+                   canonicalBundleDirectoryPath:(NSString *)canonicalBundleDirectoryPath
+                               bundleIdentifier:(NSString *)bundleIdentifier
+                                    lockFileName:(NSString *)lockFileName
+                                  rootDescriptor:(int)rootDescriptor
+                                bundleDescriptor:(int)bundleDescriptor
+                                  lockDescriptor:(int)lockDescriptor
+                                    rootIdentity:(const struct stat *)rootIdentity
+                                  bundleIdentity:(const struct stat *)bundleIdentity
+                                    lockIdentity:(const struct stat *)lockIdentity {
+    self = [super init];
+    if (self) {
+        _canonicalBackupRootPath = [canonicalBackupRootPath copy];
+        _canonicalBundleDirectoryPath = [canonicalBundleDirectoryPath copy];
+        _bundleIdentifier = [bundleIdentifier copy];
+        _lockFileName = [lockFileName copy];
+        _rootDescriptor = rootDescriptor;
+        _bundleDescriptor = bundleDescriptor;
+        _lockDescriptor = lockDescriptor;
+        _locked = YES;
+        _rootIdentity = *rootIdentity;
+        _bundleIdentity = *bundleIdentity;
+        _lockIdentity = *lockIdentity;
+    }
+    return self;
+}
+
+- (NSString *)canonicalBackupRootPath {
+    return _canonicalBackupRootPath;
+}
+
+- (NSString *)canonicalBundleDirectoryPath {
+    return _canonicalBundleDirectoryPath;
+}
+
+- (NSString *)bundleIdentifier {
+    return _bundleIdentifier;
+}
+
+- (NSString *)lockFileName {
+    return _lockFileName;
+}
+
+- (BOOL)validateOwnershipWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (!_locked ||
+        _rootDescriptor < 0 ||
+        _bundleDescriptor < 0 ||
+        _lockDescriptor < 0 ||
+        ![_canonicalBackupRootPath isKindOfClass:[NSString class]] ||
+        ![_canonicalBundleDirectoryPath isKindOfClass:[NSString class]] ||
+        ![_bundleIdentifier isKindOfClass:[NSString class]] ||
+        ![_lockFileName isKindOfClass:[NSString class]] ||
+        ![_lockFileName isEqualToString:PXBackupBundleLockFileName] ||
+        ![_canonicalBundleDirectoryPath isEqualToString:
+            PXBackupBundleLockAppendComponent(_canonicalBackupRootPath,
+                                               _bundleIdentifier)]) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorFilesystemChanged,
+                                   PXBackupBundleLockLockField,
+                                   @"The retained bundle lock is invalid");
+        return NO;
+    }
+    if (!PXBackupBundleLockProofIsValid(_canonicalBackupRootPath,
+                                        _canonicalBundleDirectoryPath,
+                                        _bundleIdentifier,
+                                        _rootDescriptor,
+                                        _bundleDescriptor,
+                                        _lockDescriptor,
+                                        &_rootIdentity,
+                                        &_bundleIdentity,
+                                        &_lockIdentity)) {
+        PXBackupBundleLockSetError(error,
+                                   PXBackupBundleLockErrorFilesystemChanged,
+                                   PXBackupBundleLockLockField,
+                                   @"The retained bundle lock identity changed");
+        return NO;
+    }
+    return YES;
+}
+
+- (void)dealloc {
+    if (_lockDescriptor >= 0) {
+        if (_locked) {
+            PXBackupBundleLockBestEffortUnlock(_lockDescriptor);
+            _locked = NO;
+        }
+        close(_lockDescriptor);
+        _lockDescriptor = -1;
+    }
+    if (_bundleDescriptor >= 0) {
+        close(_bundleDescriptor);
+        _bundleDescriptor = -1;
+    }
+    if (_rootDescriptor >= 0) {
+        close(_rootDescriptor);
+        _rootDescriptor = -1;
+    }
+}
+
+@end
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -12,6 +12,7 @@
 #import "PXBackupManifestValidator.h"
 #import "PXBackupArtifactVerifier.h"
 #import "PXBackupArchiveValidator.h"
+#import "PXBackupBundleLock.h"
 #import "PXBackupPublicationWorkspace.h"
 #import "PXRestorePlan.h"
 #import "PXAppGroupRestoreTargetPlan.h"
@@ -1543,6 +1544,26 @@
         CommandRunner *runner = [CommandRunner shared];

         NSString *profileId = [self _activeProfileId];
+        NSString *backupRoot = [self _backupRoot];
+        NSError *bundleLockError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXBackupBundleLock *bundleLock =
+            [PXBackupBundleLock acquireLockAtBackupRoot:backupRoot
+                                       bundleIdentifier:bundleID
+                                                  error:&bundleLockError];
+        if (!bundleLock) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, bundleLockError);
+            });
+            return;
+        }
+        NSError *initialBundleLockValidationError = nil;
+        if (![bundleLock validateOwnershipWithError:&initialBundleLockValidationError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, initialBundleLockValidationError);
+            });
+            return;
+        }

         // Prefer jailbreak/Procursus tar first (often has xattrs/acl support); /usr/bin/tar on iOS may not.
         NSString *tarPath = [runner firstExistingPath:@[
@@ -1612,7 +1633,13 @@
         }

         NSString *timestamp = [self _timestampString];
-        NSString *backupRoot = [self _backupRoot];
+        NSError *preWorkspaceBundleLockValidationError = nil;
+        if (![bundleLock validateOwnershipWithError:&preWorkspaceBundleLockValidationError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, preWorkspaceBundleLockValidationError);
+            });
+            return;
+        }
         NSError *workspaceError = nil;
         __attribute__((objc_precise_lifetime))
         PXBackupPublicationWorkspace *publicationWorkspace =
@@ -2127,6 +2154,13 @@
             });
             return;
         }
+        NSError *preManifestBundleLockValidationError = nil;
+        if (![bundleLock validateOwnershipWithError:&preManifestBundleLockValidationError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, preManifestBundleLockValidationError);
+            });
+            return;
+        }
         NSString *manifestPath = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
         if (![manifest writeToFile:manifestPath atomically:YES]) {
             [warnings addObject:@"Failed to write manifest"];
@@ -2138,6 +2172,13 @@
         if (![publicationWorkspace validateIdentityWithError:&finalWorkspaceIdentityError]) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (completion) completion(nil, finalWorkspaceIdentityError);
+            });
+            return;
+        }
+        NSError *finalBundleLockValidationError = nil;
+        if (![bundleLock validateOwnershipWithError:&finalBundleLockValidationError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, finalBundleLockValidationError);
             });
             return;
         }
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
