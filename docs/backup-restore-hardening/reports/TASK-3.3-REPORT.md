# TASK-3.3 Implementation Report

## Baseline and exact scope

- Baseline: `dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b`.
- Authorized production scope: `PXBackupArtifactWriter.h`, `PXBackupArtifactWriter.m`, and `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-3.3-REPORT.md`.
- TASK-3.2 review status read before implementation: ACCEPTED.
- No coordinator file was edited, staged, reverted, or included.

### Recorded baseline evidence

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
git rev-parse HEAD
dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b
git log -5 --oneline
dbfeb65 phase3(task-3.2): add per-bundle backup serialization
2db8d44 phase3(task-3.1): create unique partial backup workspace
0ef0631 phase2(task-2.14A): make restore result mutations assertion independent
fec5966 phase2(task-2.14): add structured restore result
9d046a4 phase2(task-2.13A): implement optional directory tree verifier
git diff --check
PASS
```

## Protected SHA-256 before/after

- Protected production entries: 298.
- Changed protected entries: 0.

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
| `PXBackupBundleLock.h` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | `6a094c91f862db366d2bb976d889645971dd72f7a1781a027df9d205318c2ce9` | 1714 |
| `PXBackupBundleLock.m` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | `563cb607b41ba12e6620b7a8a72e999a84715fd64b671555d512e8440798613b` | 36342 |
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

## Legacy helper inventory and removal

The baseline manager owned four path-rescan authorities: `PXFileSHA256`, `PXHexString`, `PXArtifactInfo`, and `PXVerifyArtifact`, plus `PXArtifactsTotalSize` and a post-hoc `Backup artifact verification:` warning loop. All definitions/calls are zero after migration. CommonCrypto is now contained by the pure writer.

## Exact public API and sixteen-code enum

| Value | Error code |
|---:|---|
| 1 | `PXBackupArtifactWriterErrorInvalidInput` |
| 2 | `PXBackupArtifactWriterErrorWorkspaceValidationFailed` |
| 3 | `PXBackupArtifactWriterErrorWorkspaceInspectionFailed` |
| 4 | `PXBackupArtifactWriterErrorParentCreationFailed` |
| 5 | `PXBackupArtifactWriterErrorParentInvalid` |
| 6 | `PXBackupArtifactWriterErrorDuplicateArtifact` |
| 7 | `PXBackupArtifactWriterErrorTemporaryCreationFailed` |
| 8 | `PXBackupArtifactWriterErrorProducerFailed` |
| 9 | `PXBackupArtifactWriterErrorOutputMissing` |
| 10 | `PXBackupArtifactWriterErrorOutputInvalid` |
| 11 | `PXBackupArtifactWriterErrorReadFailed` |
| 12 | `PXBackupArtifactWriterErrorFilesystemChanged` |
| 13 | `PXBackupArtifactWriterErrorLimitExceeded` |
| 14 | `PXBackupArtifactWriterErrorDurabilityFailed` |
| 15 | `PXBackupArtifactWriterErrorFinalizationFailed` |
| 16 | `PXBackupArtifactWriterErrorCleanupFailed` |

Exports are exactly `PXBackupArtifactWriterErrorDomain`, `PXBackupArtifactWriterErrorFieldPathKey`, and `PXBackupArtifactTemporaryDirectoryPrefix`. The producer typedef is synchronous and receives only `temporaryOutputPath`.

## Immutable verified artifact

`PXVerifiedBackupArtifact` is subclassing-restricted and `NSCopying`; `copyWithZone:` returns self. Equality/hash use relative path, final file path, unsigned size, and SHA-256. No public initializer exists.

### Exact manifest representation

| Key | Value authority |
|---|---|
| `name` | `relativePath` |
| `path` | `filePath` |
| `size` | exact unsigned streamed size |
| `sha256` | exact lowercase 64-hex digest |

## Workspace binding

The writer requires an exact `PXBackupPublicationWorkspace`, invokes workspace validation before and after its independent no-follow open, proves path/descriptor identity and mode 0700, retains the workspace object, and owns only its independently opened descriptor.

## Relative path and collision matrices

The source enforces exact lossless UTF-8, 4096-byte path, 255-byte component, 32-level depth, control/NUL/backslash/slash rules, reserved names/prefixes, exact round-trip, duplicate, ancestor/descendant, filesystem parent/file, and NFC/NFD alias rejection without rewriting the accepted path.

## Descriptor-relative parent traversal

Parents are inspected with `fstatat(..., AT_SYMLINK_NOFOLLOW)`, created with `mkdirat(..., 0700)`, opened using `O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`, bound by namespace/descriptor identity, kept on the workspace device, and revalidated through the immediate authority descriptor.

## Temporary directory and producer protocol

Each artifact attempt uses exactly one `.weaponx-artifact-partial-XXXXXX` `mkdtemp` direct child. The directory is proven 0700, empty, same-device, no-follow, and CLOEXEC. `payload` must be absent; the synchronous producer is invoked exactly once with `<temp>/payload`.

## Payload policy, streaming SHA-256, and stability

Only a single-linked regular file without setuid/setgid is accepted. Namespace policy is checked before mode repair. The payload is opened no-follow/nonblocking/CLOEXEC, forced and verified 0600, bounded to 64 GiB, streamed through 64 KiB, retried only on EINTR, hashed incrementally, byte-counted overflow-safely, and compared against stable device/inode/type/mode/nlink/size/mtime/ctime snapshots.

## Strict durability and descriptor-relative finalization

The file is strictly fsynced, then writer/parent/temp/payload are revalidated. Final absence is required and the sole publication operation is `renameat(tempFD, "payload", parentFD, finalName)`. The final namespace is proven regular/nlink1/mode0600, the parent is strictly synced, the empty temp is removed, the parent is synced again, and writer/parent identity is revalidated before record acceptance.

## Failure cleanup

Cleanup is descriptor-relative, no-follow, same-device, identity checked, bounded to eight entries, and idempotent by state. Before rename it removes only exact payload and exact empty temp. After rename it rolls back only the retained final identity with nlink1/mode0600, syncs the parent, and preserves unexpected or changed evidence. No TASK-3.1 workspace recursion occurs.

## Error privacy

Public errors contain only `NSLocalizedDescriptionKey` and `PXBackupArtifactWriterErrorFieldPathKey`. No path value, artifact name, bundle ID, temporary name, device/inode, size, digest, errno text, command output, or nested error is exposed.

## Manager writer creation and validation

One precise-lifetime writer is created after accepted workspace creation/initial validation. Writer validations occur immediately after factory, before manifest construction, and before `PXBackupResult`. Accepted TASK-3.2 lock gates remain 1 factory/4 validations; TASK-3.1 workspace gates remain 1 factory/3 validations.

## Eight producer migrations

| Semantic site | Relative path | Existing behavior |
|---|---|---|
| Main data | `data.tar.gz` | hard code 105; tar stderr retained, writer failure generic |
| App Group loop | `groups/<sanitized>.tar.gz` | exact group warning and continue |
| Profile AppData | `profile_appdata.tar.gz` | exact warning and continue |
| Global Safari | `global_safari.tar.gz` | exact warning and continue |
| Preferences | `preferences/<bundleID>.plist` | zero-exit copy, no new warning, inclusion still option-based |
| Keychain | `keychain.plist` | helper/fallback/groups/count/debug/warnings retained; no duplicate writer warning |
| System-global loop | `global_library_<sanitized>.tar.gz` | exact warning and continue |
| Shared DB loop | `shared_db/<name>` | zero-exit copy, no per-file warning |

All producer output selectors receive only `temporaryOutputPath`; direct final producer outputs are zero.

## Verified collection and manifest authority

Records are assembled in exact order: data, App Groups, profile AppData, global Safari, system-global, shared DB, Preferences, Keychain. The artifacts array is built only from `manifestRepresentation`; artifactCount, overflow-safe totalSize, data archiveChecksum, and component mappings derive only from verified records.

## Warning/debug and policy boundaries

- Baseline warning expressions: 12; current: 11; exact sequence after removing the required post-hoc warning: True.
- Debug call count: 54 -> 54; normalized output-authority sequence equal: True.
- Main data remains hard failure; optional component behavior remains warning/skip/continue as before.
- TASK-3.4 Preferences inclusion semantics and TASK-3.5 required/optional formal policy are not implemented.

## Phase 3 non-regression

- `manifestVersion` remains 3 and the existing manifest write remains atomic plist write semantics.
- TASK-3.1 workspace and TASK-3.2 lock files are byte-identical.
- Public Backup selector, discovery, Restore, UI, Makefile, and Keychain helper/bridge/script are unchanged.
- No final Backup rename, publication marker, centralized partial cleanup, or stale cleanup was added.

## Static and forbidden gate table

| Gate | Result |
|---|---|
| error codes | 16 |
| producer typedefs | 1 |
| verified artifact classes | 1 |
| writer classes | 1 |
| writer factories | 1 |
| artifact methods | 1 |
| identity validation methods | 1 |
| public readwrite properties | 0 |
| temporary prefix | .weaponx-artifact-partial- |
| template | .weaponx-artifact-partial-XXXXXX |
| payload | payload |
| mkdtemp sites | 1 |
| renameat sites | 1 |
| whole-file reads | 0 |
| writer shell/process calls | 0 |
| writer NSFileManager calls | 0 |
| file mode | 0600 |
| directory mode | 0700 |
| stream buffer | 64 KiB |
| file maximum | 64 GiB |
| artifact maximum | 4096 |
| manager writer factory calls | 1 |
| manager writer validations | 3 |
| manager semantic writer sites | 8 |
| legacy helper tokens | 0 |
| post-hoc verification loop | 0 |
| direct producer final outputs | 0 |
| Preferences copy || true | 0 |
| shared DB copy || true | 0 |
| lock factory/validations | 1/4 |
| workspace factory/validations | 1/3 |
| manifestVersion | 3 |
| final Backup publication rename | 0 |
| protected changes | 0 |
| writer strict frontend/analyzer | PASS |
| manager integration frontend | PASS |
| git diff --check | PASS |

## Explicit scenario matrix

Explicit scenarios: 324.

| # | Scenario | Result | Evidence |
|---:|---|---|---|
| 1 | Public error InvalidInput | PASS | Exact enum member InvalidInput is present once. |
| 2 | Public error WorkspaceValidationFailed | PASS | Exact enum member WorkspaceValidationFailed is present once. |
| 3 | Public error WorkspaceInspectionFailed | PASS | Exact enum member WorkspaceInspectionFailed is present once. |
| 4 | Public error ParentCreationFailed | PASS | Exact enum member ParentCreationFailed is present once. |
| 5 | Public error ParentInvalid | PASS | Exact enum member ParentInvalid is present once. |
| 6 | Public error DuplicateArtifact | PASS | Exact enum member DuplicateArtifact is present once. |
| 7 | Public error TemporaryCreationFailed | PASS | Exact enum member TemporaryCreationFailed is present once. |
| 8 | Public error ProducerFailed | PASS | Exact enum member ProducerFailed is present once. |
| 9 | Public error OutputMissing | PASS | Exact enum member OutputMissing is present once. |
| 10 | Public error OutputInvalid | PASS | Exact enum member OutputInvalid is present once. |
| 11 | Public error ReadFailed | PASS | Exact enum member ReadFailed is present once. |
| 12 | Public error FilesystemChanged | PASS | Exact enum member FilesystemChanged is present once. |
| 13 | Public error LimitExceeded | PASS | Exact enum member LimitExceeded is present once. |
| 14 | Public error DurabilityFailed | PASS | Exact enum member DurabilityFailed is present once. |
| 15 | Public error FinalizationFailed | PASS | Exact enum member FinalizationFailed is present once. |
| 16 | Public error CleanupFailed | PASS | Exact enum member CleanupFailed is present once. |
| 17 | Error domain export | PASS | Header static inventory matches the exact public boundary. |
| 18 | Field-path export | PASS | Header static inventory matches the exact public boundary. |
| 19 | Temporary-prefix export | PASS | Header static inventory matches the exact public boundary. |
| 20 | Producer typedef exact | PASS | Header static inventory matches the exact public boundary. |
| 21 | Verified artifact restricted | PASS | Header static inventory matches the exact public boundary. |
| 22 | Writer restricted | PASS | Header static inventory matches the exact public boundary. |
| 23 | Record NSCopying | PASS | Header static inventory matches the exact public boundary. |
| 24 | No public record initializer | PASS | Header static inventory matches the exact public boundary. |
| 25 | Record init unavailable | PASS | Header static inventory matches the exact public boundary. |
| 26 | Record new unavailable | PASS | Header static inventory matches the exact public boundary. |
| 27 | Writer init unavailable | PASS | Header static inventory matches the exact public boundary. |
| 28 | Writer new unavailable | PASS | Header static inventory matches the exact public boundary. |
| 29 | Writer factory unique | PASS | Header static inventory matches the exact public boundary. |
| 30 | Artifact method unique | PASS | Header static inventory matches the exact public boundary. |
| 31 | Identity method unique | PASS | Header static inventory matches the exact public boundary. |
| 32 | Public readwrite properties zero | PASS | Header static inventory matches the exact public boundary. |
| 33 | Public descriptor properties zero | PASS | Header static inventory matches the exact public boundary. |
| 34 | Relative path: data.tar.gz | accepted | Strict component/full-path validation preserves exact caller bytes. |
| 35 | Relative path: groups/a.tar.gz | accepted | Strict component/full-path validation preserves exact caller bytes. |
| 36 | Relative path: preferences/com.app.plist | accepted | Strict component/full-path validation preserves exact caller bytes. |
| 37 | Relative path: shared_db/db.sqlite-wal | accepted | Strict component/full-path validation preserves exact caller bytes. |
| 38 | Relative path: empty string | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 39 | Relative path: leading slash | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 40 | Relative path: trailing slash | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 41 | Relative path: empty component | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 42 | Relative path: dot component | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 43 | Relative path: dot-dot component | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 44 | Relative path: embedded dot-dot | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 45 | Relative path: backslash | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 46 | Relative path: NUL | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 47 | Relative path: newline control | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 48 | Relative path: tab control | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 49 | Relative path: DEL control | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 50 | Relative path: Unicode control | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 51 | Relative path: lock component at root | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 52 | Relative path: lock component nested | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 53 | Relative path: manifest component at root | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 54 | Relative path: manifest component nested | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 55 | Relative path: backup partial prefix root | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 56 | Relative path: backup partial prefix nested | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 57 | Relative path: artifact partial prefix root | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 58 | Relative path: artifact partial prefix nested | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 59 | Relative path: 255-byte component | accepted | Strict component/full-path validation preserves exact caller bytes. |
| 60 | Relative path: 256-byte component | limit | Strict component/full-path validation preserves exact caller bytes. |
| 61 | Relative path: 32-level path | accepted | Strict component/full-path validation preserves exact caller bytes. |
| 62 | Relative path: 33-level path | limit | Strict component/full-path validation preserves exact caller bytes. |
| 63 | Relative path: 4096-byte relative path | accepted when components/depth valid | Strict component/full-path validation preserves exact caller bytes. |
| 64 | Relative path: 4097-byte relative path | limit | Strict component/full-path validation preserves exact caller bytes. |
| 65 | Relative path: multibyte UTF-8 | accepted | Strict component/full-path validation preserves exact caller bytes. |
| 66 | Relative path: percent text | accepted without decoding | Strict component/full-path validation preserves exact caller bytes. |
| 67 | Relative path: tilde text | accepted without expansion | Strict component/full-path validation preserves exact caller bytes. |
| 68 | Relative path: mixed case | accepted without lowercasing | Strict component/full-path validation preserves exact caller bytes. |
| 69 | Relative path: leading whitespace component | accepted without trim | Strict component/full-path validation preserves exact caller bytes. |
| 70 | Relative path: trailing whitespace component | accepted without trim | Strict component/full-path validation preserves exact caller bytes. |
| 71 | Relative path: lossy UTF-8 input | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 72 | Relative path: UTF-8 round-trip mismatch | rejected | Strict component/full-path validation preserves exact caller bytes. |
| 73 | Collision policy: exact duplicate | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 74 | Collision policy: accepted ancestor then descendant | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 75 | Collision policy: accepted descendant then ancestor | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 76 | Collision policy: file/parent filesystem collision | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 77 | Collision policy: parent/final filesystem collision | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 78 | Collision policy: NFC duplicate | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 79 | Collision policy: NFD duplicate | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 80 | Collision policy: NFC ancestor alias | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 81 | Collision policy: NFD descendant alias | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 82 | Collision policy: ordinary sibling accepted | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 83 | Collision policy: same parent different final accepted | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 84 | Collision policy: case-distinct path retained | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 85 | Collision policy: percent spelling distinct | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 86 | Collision policy: tilde spelling distinct | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 87 | Collision policy: duplicate rejected before producer | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 88 | Collision policy: collision rejected before mkdtemp | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 89 | Collision policy: failed attempt not accepted | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 90 | Collision policy: successful record accepted once | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 91 | Collision policy: artifact count increments once | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 92 | Collision policy: artifact max 4096 | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 93 | Collision policy: artifact 4097 rejected | PASS | Exact and canonical-equivalence sets enforce duplicate/ancestor/descendant policy. |
| 94 | Workspace binding: workspace exact runtime class | PASS | Factory/validator source proves the retained workspace authority contract. |
| 95 | Workspace binding: workspace subclass rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 96 | Workspace binding: workspace nil rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 97 | Workspace binding: first workspace validation | PASS | Factory/validator source proves the retained workspace authority contract. |
| 98 | Workspace binding: workspace lstat | PASS | Factory/validator source proves the retained workspace authority contract. |
| 99 | Workspace binding: workspace symlink rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 100 | Workspace binding: workspace non-directory rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 101 | Workspace binding: workspace nofollow open | PASS | Factory/validator source proves the retained workspace authority contract. |
| 102 | Workspace binding: workspace descriptor fstat | PASS | Factory/validator source proves the retained workspace authority contract. |
| 103 | Workspace binding: workspace exact mode 0700 | PASS | Factory/validator source proves the retained workspace authority contract. |
| 104 | Workspace binding: workspace CLOEXEC | PASS | Factory/validator source proves the retained workspace authority contract. |
| 105 | Workspace binding: second workspace validation | PASS | Factory/validator source proves the retained workspace authority contract. |
| 106 | Workspace binding: path/descriptor identity equality | PASS | Factory/validator source proves the retained workspace authority contract. |
| 107 | Workspace binding: writer retains workspace object | PASS | Factory/validator source proves the retained workspace authority contract. |
| 108 | Workspace binding: writer owns independent descriptor | PASS | Factory/validator source proves the retained workspace authority contract. |
| 109 | Workspace binding: writer never closes workspace internal descriptors | PASS | Factory/validator source proves the retained workspace authority contract. |
| 110 | Workspace binding: writer validation clears error | PASS | Factory/validator source proves the retained workspace authority contract. |
| 111 | Workspace binding: writer retained identity unchanged | PASS | Factory/validator source proves the retained workspace authority contract. |
| 112 | Workspace binding: workspace replacement rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 113 | Workspace binding: workspace symlink replacement rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 114 | Workspace binding: workspace mode change rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 115 | Workspace binding: workspace descriptor CLOEXEC loss rejected | PASS | Factory/validator source proves the retained workspace authority contract. |
| 116 | Parent traversal: root-level artifact parent | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 117 | Parent traversal: one missing parent | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 118 | Parent traversal: multiple missing parents | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 119 | Parent traversal: existing directory parent | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 120 | Parent traversal: parent symlink rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 121 | Parent traversal: parent regular file rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 122 | Parent traversal: parent FIFO rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 123 | Parent traversal: parent setuid rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 124 | Parent traversal: parent setgid rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 125 | Parent traversal: parent device crossing rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 126 | Parent traversal: parent namespace/descriptor mismatch rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 127 | Parent traversal: parent CLOEXEC required | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 128 | Parent traversal: new parent mode 0700 | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 129 | Parent traversal: existing parent not rewritten | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 130 | Parent traversal: parent path identity proof | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 131 | Parent traversal: immediate authority descriptor retained | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 132 | Parent traversal: parent replacement before rename rejected | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 133 | Parent traversal: no NSFileManager recursion | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 134 | Parent traversal: no shell mkdir | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 135 | Parent traversal: no realpath relative traversal | PASS | Descriptor-relative fstatat/mkdirat/openat traversal enforces the parent contract. |
| 136 | Temporary protocol: one mkdtemp per attempt | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 137 | Temporary protocol: exact template | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 138 | Temporary protocol: exact prefix | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 139 | Temporary protocol: direct final-parent child | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 140 | Temporary protocol: safe generated component | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 141 | Temporary protocol: path/parent namespace match | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 142 | Temporary protocol: temporary directory nofollow open | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 143 | Temporary protocol: temporary mode 0700 | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 144 | Temporary protocol: temporary same device | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 145 | Temporary protocol: temporary CLOEXEC | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 146 | Temporary protocol: temporary initially empty | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 147 | Temporary protocol: payload absent before producer | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 148 | Temporary protocol: producer called exactly once | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 149 | Temporary protocol: producer receives sole payload path | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 150 | Temporary protocol: producer NO maps ProducerFailed | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 151 | Temporary protocol: producer NO with no payload cleanup | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 152 | Temporary protocol: producer NO with exact payload cleanup | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 153 | Temporary protocol: unexpected extra entry preserved | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 154 | Temporary protocol: invalid UTF-8 entry preserved | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 155 | Temporary protocol: identity-changed temp preserved | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 156 | Temporary protocol: mkdtemp binding failure exact empty cleanup | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 157 | Temporary protocol: mkdtemp cleanup failure maps CleanupFailed | PASS | One bounded writer-owned temporary directory mediates every artifact. |
| 158 | Payload verification: payload missing | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 159 | Payload verification: payload symlink | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 160 | Payload verification: payload directory | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 161 | Payload verification: payload FIFO | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 162 | Payload verification: payload socket | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 163 | Payload verification: payload character device | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 164 | Payload verification: payload block device | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 165 | Payload verification: payload unknown type | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 166 | Payload verification: payload hard link | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 167 | Payload verification: payload setuid | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 168 | Payload verification: payload setgid | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 169 | Payload verification: payload mount crossing | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 170 | Payload verification: payload negative size | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 171 | Payload verification: payload zero size | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 172 | Payload verification: payload one byte | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 173 | Payload verification: payload exactly 64 GiB | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 174 | Payload verification: payload above 64 GiB | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 175 | Payload verification: payload namespace/open descriptor mismatch | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 176 | Payload verification: payload O_NONBLOCK | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 177 | Payload verification: payload O_NOFOLLOW | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 178 | Payload verification: payload CLOEXEC | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 179 | Payload verification: payload forced mode 0600 | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 180 | Payload verification: payload verifies mode 0600 | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 181 | Payload verification: 64 KiB buffer | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 182 | Payload verification: EINTR read retry | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 183 | Payload verification: non-EINTR read failure | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 184 | Payload verification: incremental SHA-256 | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 185 | Payload verification: zero-length SHA-256 | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 186 | Payload verification: lowercase 64-hex digest | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 187 | Payload verification: stream byte overflow check | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 188 | Payload verification: stream bytes equal retained size | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 189 | Payload verification: before/after device stable | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 190 | Payload verification: before/after inode stable | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 191 | Payload verification: before/after type/mode stable | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 192 | Payload verification: before/after link count stable | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 193 | Payload verification: before/after size stable | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 194 | Payload verification: before/after mtime stable | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 195 | Payload verification: before/after ctime stable | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 196 | Payload verification: pre-rename descriptor stability | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 197 | Payload verification: file strict fsync | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 198 | Payload verification: unsupported fsync failure | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 199 | Payload verification: no whole-file NSData | PASS | Stable descriptor streaming and policy checks cover this payload case. |
| 200 | Finalization/record: writer revalidation before rename | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 201 | Finalization/record: parent revalidation before rename | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 202 | Finalization/record: temp revalidation before rename | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 203 | Finalization/record: payload revalidation before rename | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 204 | Finalization/record: final name absent | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 205 | Finalization/record: single descriptor-relative renameat | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 206 | Finalization/record: no manager final output | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 207 | Finalization/record: final regular identity | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 208 | Finalization/record: final nlink one | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 209 | Finalization/record: final mode 0600 | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 210 | Finalization/record: final same device | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 211 | Finalization/record: first strict parent sync | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 212 | Finalization/record: temporary empty after rename | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 213 | Finalization/record: temporary exact unlinkat removedir | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 214 | Finalization/record: second strict parent sync | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 215 | Finalization/record: final writer validation | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 216 | Finalization/record: record created after all gates | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 217 | Finalization/record: relativePath exact | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 218 | Finalization/record: filePath exact | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 219 | Finalization/record: size exact unsigned | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 220 | Finalization/record: sha256 exact | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 221 | Finalization/record: manifest name mapping | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 222 | Finalization/record: manifest path mapping | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 223 | Finalization/record: manifest size mapping | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 224 | Finalization/record: manifest sha mapping | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 225 | Finalization/record: record copy returns self | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 226 | Finalization/record: record equality all fields | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 227 | Finalization/record: record hash all fields | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 228 | Finalization/record: accepted-set insertion after record | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 229 | Finalization/record: artifactCount increment after record | PASS | Record acceptance occurs only after rename, durability, cleanup, and identity proof. |
| 230 | Failure cleanup: pre-rename empty temp cleanup | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 231 | Failure cleanup: pre-rename exact payload cleanup | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 232 | Failure cleanup: pre-rename unexpected payload preserve | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 233 | Failure cleanup: pre-rename extra evidence preserve | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 234 | Failure cleanup: post-rename exact final rollback | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 235 | Failure cleanup: post-rename changed final preserve | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 236 | Failure cleanup: post-rename hard-linked final preserve | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 237 | Failure cleanup: post-rename mode-changed final preserve | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 238 | Failure cleanup: rollback parent sync | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 239 | Failure cleanup: temporary cleanup after rollback | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 240 | Failure cleanup: cleanup bounded eight entries | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 241 | Failure cleanup: cleanup nofollow | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 242 | Failure cleanup: cleanup same filesystem | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 243 | Failure cleanup: cleanup identity checked | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 244 | Failure cleanup: cleanup idempotent state model | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 245 | Failure cleanup: no recursive workspace delete | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 246 | Failure cleanup: CleanupFailed overrides unsafe cleanup | PASS | Bounded descriptor-relative rollback removes only exact owned identities. |
| 247 | Manager integration: writer import once | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 248 | Manager integration: writer factory once | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 249 | Manager integration: writer initial validation | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 250 | Manager integration: writer pre-manifest validation | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 251 | Manager integration: writer final validation | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 252 | Manager integration: precise lifetime writer | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 253 | Manager integration: lock factory retained | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 254 | Manager integration: four lock validations retained | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 255 | Manager integration: workspace factory retained | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 256 | Manager integration: three workspace validations retained | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 257 | Manager integration: data producer migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 258 | Manager integration: App Group loop migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 259 | Manager integration: profile migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 260 | Manager integration: Safari migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 261 | Manager integration: Preferences migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 262 | Manager integration: Keychain migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 263 | Manager integration: system-global loop migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 264 | Manager integration: shared DB loop migration | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 265 | Manager integration: data hard error code 105 | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 266 | Manager integration: data tar stderr retained | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 267 | Manager integration: data writer generic error | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 268 | Manager integration: group warning exact | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 269 | Manager integration: profile warning exact | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 270 | Manager integration: Safari warning exact | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 271 | Manager integration: Preferences no new warning | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 272 | Manager integration: Keychain no duplicate writer warning | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 273 | Manager integration: system warning exact | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 274 | Manager integration: shared DB no per-file warning | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 275 | Manager integration: Preferences copy zero exit | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 276 | Manager integration: shared DB copy zero exit | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 277 | Manager integration: no Preferences copy || true | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 278 | Manager integration: no shared DB copy || true | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 279 | Manager integration: zero direct tar final outputs | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 280 | Manager integration: zero direct Keychain final outputs | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 281 | Manager integration: record order data | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 282 | Manager integration: record order groups | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 283 | Manager integration: record order profile | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 284 | Manager integration: record order Safari | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 285 | Manager integration: record order system | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 286 | Manager integration: record order shared DB | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 287 | Manager integration: record order Preferences | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 288 | Manager integration: record order Keychain | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 289 | Manager integration: manifest artifacts from records only | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 290 | Manager integration: artifactCount from records | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 291 | Manager integration: totalSize from records overflow-safe | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 292 | Manager integration: archiveChecksum from data record | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 293 | Manager integration: component mappings from records | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 294 | Manager integration: preferences included remains option-based | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 295 | Manager integration: manifest version 3 | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 296 | Manager integration: manifest write semantics retained | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 297 | Manager integration: partial result retained | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 298 | Manager integration: no Backup publication rename | PASS | Static manager inventory and ordered record construction prove this requirement. |
| 299 | Non-regression: PXFileSHA256 removed | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 300 | Non-regression: PXHexString removed | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 301 | Non-regression: PXArtifactInfo removed | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 302 | Non-regression: PXVerifyArtifact removed | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 303 | Non-regression: post-hoc verification loop removed | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 304 | Non-regression: CommonCrypto manager import removed | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 305 | Non-regression: warning sequence exact minus removed loop | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 306 | Non-regression: debug call sequence preserved | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 307 | Non-regression: public Backup selector byte-identical | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 308 | Non-regression: discovery byte-identical | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 309 | Non-regression: Restore byte-identical | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 310 | Non-regression: TASK-3.1 workspace header byte-identical | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 311 | Non-regression: TASK-3.1 workspace source byte-identical | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 312 | Non-regression: TASK-3.2 lock header byte-identical | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 313 | Non-regression: TASK-3.2 lock source byte-identical | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 314 | Non-regression: UI zero diff | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 315 | Non-regression: Makefile zero diff | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 316 | Non-regression: Keychain helper zero diff | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 317 | Non-regression: Keychain bridge zero diff | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 318 | Non-regression: Keychain script zero diff | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 319 | Non-regression: no TASK-3.4 policy | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 320 | Non-regression: no TASK-3.5 policy | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 321 | Non-regression: no manifest v4 | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 322 | Non-regression: no atomic Backup publication | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 323 | Non-regression: no centralized partial cleanup | PASS | Protected hashes/body comparisons or static token gates are unchanged. |
| 324 | Non-regression: no stale cleanup | PASS | Protected hashes/body comparisons or static token gates are unchanged. |

## Whitespace, CRLF, NUL, and generated-file audit

- `PXBackupArtifactWriter.h`: SHA-256 `0d4b7b258fe4003b6a300a3368dd3d32f71b2cb568ea4bf51d7d6d5f8e78f34e`, bytes=2689, CRLF=0, bare-LF=67, NUL=0, final-newline=True.
- `PXBackupArtifactWriter.m`: SHA-256 `a365bd2039d9265c151b4f7b6b77a11c8aa4a4a2075b6e49230ae47ea89930f6`, bytes=81922, CRLF=0, bare-LF=1862, NUL=0, final-newline=True.
- `AppDataBackupManager.m`: SHA-256 `33b737b46d12574cf0508966cdbb1646c19db7aebf8686a33364a4746e511a3c`, bytes=201675, CRLF=0, bare-LF=3755, NUL=0, final-newline=True.
- Temporary stubs/harnesses exist only under the host temporary directory and are not repository files.
- Repository patch/generator scripts are removed before staging.
- Authorized source `git diff --check`: PASS.

## Build status and remaining runtime risks

- Strict Objective-C frontend plus core/unix malloc analyzer passed for the writer; the exact manager migration harness passed strict frontend checks.
- The Windows workspace has no Theos, Apple clang, xcrun, or linked iOS artifact. GitHub Actions/Theos remains authoritative.
- Remaining runtime risks: Darwin directory fsync behavior on target filesystems, low-storage interruption at strict durability gates, external namespace races around POSIX rename, and producer compliance with the synchronous-write contract.

## Full authorized production diff

```diff
diff --git a/PXBackupArtifactWriter.h b/PXBackupArtifactWriter.h
new file mode 100644
--- a/PXBackupArtifactWriter.h
+++ b/PXBackupArtifactWriter.h
@@ -0,0 +1,67 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+@class PXBackupPublicationWorkspace;
+
+FOUNDATION_EXPORT NSErrorDomain const PXBackupArtifactWriterErrorDomain;
+FOUNDATION_EXPORT NSString * const PXBackupArtifactWriterErrorFieldPathKey;
+FOUNDATION_EXPORT NSString * const PXBackupArtifactTemporaryDirectoryPrefix;
+
+typedef NS_ERROR_ENUM(PXBackupArtifactWriterErrorDomain,
+                      PXBackupArtifactWriterErrorCode) {
+    PXBackupArtifactWriterErrorInvalidInput = 1,
+    PXBackupArtifactWriterErrorWorkspaceValidationFailed = 2,
+    PXBackupArtifactWriterErrorWorkspaceInspectionFailed = 3,
+    PXBackupArtifactWriterErrorParentCreationFailed = 4,
+    PXBackupArtifactWriterErrorParentInvalid = 5,
+    PXBackupArtifactWriterErrorDuplicateArtifact = 6,
+    PXBackupArtifactWriterErrorTemporaryCreationFailed = 7,
+    PXBackupArtifactWriterErrorProducerFailed = 8,
+    PXBackupArtifactWriterErrorOutputMissing = 9,
+    PXBackupArtifactWriterErrorOutputInvalid = 10,
+    PXBackupArtifactWriterErrorReadFailed = 11,
+    PXBackupArtifactWriterErrorFilesystemChanged = 12,
+    PXBackupArtifactWriterErrorLimitExceeded = 13,
+    PXBackupArtifactWriterErrorDurabilityFailed = 14,
+    PXBackupArtifactWriterErrorFinalizationFailed = 15,
+    PXBackupArtifactWriterErrorCleanupFailed = 16,
+};
+
+typedef BOOL (^PXBackupArtifactProducer)(NSString *temporaryOutputPath);
+
+__attribute__((objc_subclassing_restricted))
+@interface PXVerifiedBackupArtifact : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly) NSString *relativePath;
+@property (nonatomic, copy, readonly) NSString *filePath;
+@property (nonatomic, readonly) unsigned long long size;
+@property (nonatomic, copy, readonly) NSString *sha256;
+@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *manifestRepresentation;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupArtifactWriter : NSObject
+
+@property (nonatomic, copy, readonly) NSString *workspacePath;
+@property (nonatomic, readonly) NSUInteger artifactCount;
+
++ (nullable instancetype)writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
+                                      error:(NSError **)error;
+
+- (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
+                                                          producer:(PXBackupArtifactProducer)producer
+                                                             error:(NSError **)error;
+
+- (BOOL)validateIdentityWithError:(NSError **)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXBackupArtifactWriter.m b/PXBackupArtifactWriter.m
new file mode 100644
--- a/PXBackupArtifactWriter.m
+++ b/PXBackupArtifactWriter.m
@@ -0,0 +1,1862 @@
+#import "PXBackupArtifactWriter.h"
+#import "PXBackupPublicationWorkspace.h"
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
+NSErrorDomain const PXBackupArtifactWriterErrorDomain =
+    @"com.hydra.projectx.backup-artifact-writer";
+NSString * const PXBackupArtifactWriterErrorFieldPathKey = @"fieldPath";
+NSString * const PXBackupArtifactTemporaryDirectoryPrefix =
+    @".weaponx-artifact-partial-";
+
+static NSString * const PXBackupArtifactWorkspaceField = @"$.workspace";
+static NSString * const PXBackupArtifactField = @"$.artifact";
+static NSString * const PXBackupArtifactRelativePathField = @"$.artifact.relativePath";
+static NSString * const PXBackupArtifactParentField = @"$.artifact.parent";
+static NSString * const PXBackupArtifactTemporaryField = @"$.artifact.temporary";
+static NSString * const PXBackupArtifactPayloadField = @"$.artifact.payload";
+
+static const NSUInteger PXBackupArtifactMaximumArtifacts = 4096;
+static const NSUInteger PXBackupArtifactMaximumRelativePathBytes = 4096;
+static const NSUInteger PXBackupArtifactMaximumComponentBytes = 255;
+static const NSUInteger PXBackupArtifactMaximumRelativeDepth = 32;
+static const unsigned long long PXBackupArtifactMaximumFileBytes =
+    64ULL * 1024ULL * 1024ULL * 1024ULL;
+static const size_t PXBackupArtifactStreamBufferBytes = 64U * 1024U;
+static const NSUInteger PXBackupArtifactTemporaryOperationalEntries = 1;
+static const NSUInteger PXBackupArtifactFailureCleanupEntries = 8;
+static const NSUInteger PXBackupArtifactMaximumAbsolutePathBytes = 4096;
+static const char PXBackupArtifactTemporaryTemplate[] =
+    ".weaponx-artifact-partial-XXXXXX";
+static const char PXBackupArtifactPayloadName[] = "payload";
+
+#if defined(__APPLE__)
+#define PX_BACKUP_ARTIFACT_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
+#define PX_BACKUP_ARTIFACT_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
+#define PX_BACKUP_ARTIFACT_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
+#define PX_BACKUP_ARTIFACT_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
+#else
+#define PX_BACKUP_ARTIFACT_MTIME_SEC(value) ((value).st_mtim.tv_sec)
+#define PX_BACKUP_ARTIFACT_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
+#define PX_BACKUP_ARTIFACT_CTIME_SEC(value) ((value).st_ctim.tv_sec)
+#define PX_BACKUP_ARTIFACT_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
+#endif
+
+static void PXBackupArtifactSetError(NSError **error,
+                                     PXBackupArtifactWriterErrorCode code,
+                                     NSString *fieldPath,
+                                     NSString *description) {
+    if (!error) {
+        return;
+    }
+    *error = [NSError errorWithDomain:PXBackupArtifactWriterErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXBackupArtifactWriterErrorFieldPathKey: fieldPath,
+                             }];
+}
+
+static BOOL PXBackupArtifactStatIdentityMatches(const struct stat *left,
+                                                const struct stat *right) {
+    return left && right &&
+           left->st_dev == right->st_dev &&
+           left->st_ino == right->st_ino &&
+           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
+}
+
+static BOOL PXBackupArtifactStableFileStatMatches(const struct stat *before,
+                                                   const struct stat *after) {
+    return PXBackupArtifactStatIdentityMatches(before, after) &&
+           (before->st_mode & 07777) == (after->st_mode & 07777) &&
+           before->st_nlink == after->st_nlink &&
+           before->st_size == after->st_size &&
+           PX_BACKUP_ARTIFACT_MTIME_SEC(*before) ==
+               PX_BACKUP_ARTIFACT_MTIME_SEC(*after) &&
+           PX_BACKUP_ARTIFACT_MTIME_NSEC(*before) ==
+               PX_BACKUP_ARTIFACT_MTIME_NSEC(*after) &&
+           PX_BACKUP_ARTIFACT_CTIME_SEC(*before) ==
+               PX_BACKUP_ARTIFACT_CTIME_SEC(*after) &&
+           PX_BACKUP_ARTIFACT_CTIME_NSEC(*before) ==
+               PX_BACKUP_ARTIFACT_CTIME_NSEC(*after);
+}
+
+static BOOL PXBackupArtifactDescriptorHasCloseOnExec(int descriptor) {
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
+static int PXBackupArtifactDuplicateDescriptor(int descriptor) {
+    if (descriptor < 0) {
+        return -1;
+    }
+    int duplicated = -1;
+#if defined(F_DUPFD_CLOEXEC)
+    do {
+        duplicated = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
+    } while (duplicated < 0 && errno == EINTR);
+    if (duplicated >= 0) {
+        return duplicated;
+    }
+#endif
+    do {
+        duplicated = dup(descriptor);
+    } while (duplicated < 0 && errno == EINTR);
+    if (duplicated < 0) {
+        return -1;
+    }
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
+        !PXBackupArtifactDescriptorHasCloseOnExec(duplicated)) {
+        close(duplicated);
+        return -1;
+    }
+    return duplicated;
+}
+
+static BOOL PXBackupArtifactStrictSync(int descriptor) {
+    if (descriptor < 0) {
+        return NO;
+    }
+    int result = -1;
+    do {
+        result = fsync(descriptor);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXBackupArtifactStringContainsNull(NSString *value) {
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static NSData *PXBackupArtifactLosslessUTF8Data(NSString *value) {
+    if (![value isKindOfClass:[NSString class]] ||
+        PXBackupArtifactStringContainsNull(value)) {
+        return nil;
+    }
+    return [value dataUsingEncoding:NSUTF8StringEncoding
+                allowLossyConversion:NO];
+}
+
+static char *PXBackupArtifactCopyCString(NSData *data) {
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
+static NSString *PXBackupArtifactAppendComponent(NSString *parent,
+                                                  NSString *component) {
+    if ([parent isEqualToString:@"/"]) {
+        return [@"/" stringByAppendingString:component];
+    }
+    return [NSString stringWithFormat:@"%@/%@", parent, component];
+}
+
+static BOOL PXBackupArtifactPathRoundTrips(NSString *value,
+                                           NSData *expectedBytes) {
+    NSData *roundTrip = PXBackupArtifactLosslessUTF8Data(value);
+    return roundTrip && expectedBytes &&
+           roundTrip.length == expectedBytes.length &&
+           memcmp(roundTrip.bytes,
+                  expectedBytes.bytes,
+                  expectedBytes.length) == 0;
+}
+
+static BOOL PXBackupArtifactValidateComponent(NSString *component,
+                                              NSData **componentData,
+                                              BOOL *limitExceeded) {
+    if (componentData) {
+        *componentData = nil;
+    }
+    if (limitExceeded) {
+        *limitExceeded = NO;
+    }
+    if (![component isKindOfClass:[NSString class]] || component.length == 0 ||
+        [component isEqualToString:@"."] ||
+        [component isEqualToString:@".."]) {
+        return NO;
+    }
+    NSCharacterSet *controls = [NSCharacterSet controlCharacterSet];
+    for (NSUInteger index = 0; index < component.length; index++) {
+        unichar character = [component characterAtIndex:index];
+        if (character == 0 || character == '\\' || character == '/' ||
+            [controls characterIsMember:character]) {
+            return NO;
+        }
+    }
+    if ([component isEqualToString:@".weaponx-backup.lock"] ||
+        [component isEqualToString:@"manifest.plist"] ||
+        [component hasPrefix:@".weaponx-backup-partial-"] ||
+        [component hasPrefix:PXBackupArtifactTemporaryDirectoryPrefix]) {
+        return NO;
+    }
+    NSData *data = PXBackupArtifactLosslessUTF8Data(component);
+    if (!data || data.length == 0 ||
+        !PXBackupArtifactPathRoundTrips(component, data)) {
+        return NO;
+    }
+    if (data.length > PXBackupArtifactMaximumComponentBytes) {
+        if (limitExceeded) {
+            *limitExceeded = YES;
+        }
+        return NO;
+    }
+    if (componentData) {
+        *componentData = data;
+    }
+    return YES;
+}
+
+static BOOL PXBackupArtifactValidateTemporaryComponent(NSString *component,
+                                                       NSData **componentData) {
+    if (componentData) {
+        *componentData = nil;
+    }
+    if (![component isKindOfClass:[NSString class]] ||
+        component.length == 0 ||
+        ![component hasPrefix:PXBackupArtifactTemporaryDirectoryPrefix] ||
+        [component isEqualToString:@"."] ||
+        [component isEqualToString:@".."]) {
+        return NO;
+    }
+    NSCharacterSet *controls = [NSCharacterSet controlCharacterSet];
+    for (NSUInteger index = 0; index < component.length; index++) {
+        unichar character = [component characterAtIndex:index];
+        if (character == 0 || character == '\\' || character == '/' ||
+            [controls characterIsMember:character]) {
+            return NO;
+        }
+    }
+    NSData *data = PXBackupArtifactLosslessUTF8Data(component);
+    if (!data || data.length == 0 ||
+        data.length > PXBackupArtifactMaximumComponentBytes ||
+        !PXBackupArtifactPathRoundTrips(component, data)) {
+        return NO;
+    }
+    if (componentData) {
+        *componentData = data;
+    }
+    return YES;
+}
+
+static NSArray<NSString *> *PXBackupArtifactValidateRelativePath(
+    NSString *relativePath,
+    BOOL *limitExceeded) {
+    if (limitExceeded) {
+        *limitExceeded = NO;
+    }
+    if (![relativePath isKindOfClass:[NSString class]] ||
+        relativePath.length == 0 ||
+        [relativePath hasPrefix:@"/"] ||
+        [relativePath hasSuffix:@"/"] ||
+        PXBackupArtifactStringContainsNull(relativePath)) {
+        return nil;
+    }
+    NSData *pathData = PXBackupArtifactLosslessUTF8Data(relativePath);
+    if (!pathData || pathData.length == 0 ||
+        !PXBackupArtifactPathRoundTrips(relativePath, pathData)) {
+        return nil;
+    }
+    if (pathData.length > PXBackupArtifactMaximumRelativePathBytes) {
+        if (limitExceeded) {
+            *limitExceeded = YES;
+        }
+        return nil;
+    }
+    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
+    if (components.count == 0 ||
+        components.count > PXBackupArtifactMaximumRelativeDepth) {
+        if (limitExceeded &&
+            components.count > PXBackupArtifactMaximumRelativeDepth) {
+            *limitExceeded = YES;
+        }
+        return nil;
+    }
+    NSMutableArray<NSString *> *validated =
+        [NSMutableArray arrayWithCapacity:components.count];
+    for (id candidate in components) {
+        NSData *componentData = nil;
+        BOOL componentLimitExceeded = NO;
+        if (![candidate isKindOfClass:[NSString class]] ||
+            !PXBackupArtifactValidateComponent(candidate,
+                                               &componentData,
+                                               &componentLimitExceeded)) {
+            if (limitExceeded && componentLimitExceeded) {
+                *limitExceeded = YES;
+            }
+            return nil;
+        }
+        [validated addObject:[(NSString *)candidate copy]];
+    }
+    NSString *joined = [validated componentsJoinedByString:@"/"];
+    if (![joined isEqualToString:relativePath] ||
+        !PXBackupArtifactPathRoundTrips(joined, pathData)) {
+        return nil;
+    }
+    return [validated copy];
+}
+
+static BOOL PXBackupArtifactDirectoryEntries(int descriptor,
+                                             NSUInteger maximumEntries,
+                                             NSArray<NSString *> **entriesOut) {
+    if (entriesOut) {
+        *entriesOut = nil;
+    }
+    int duplicated = PXBackupArtifactDuplicateDescriptor(descriptor);
+    if (duplicated < 0) {
+        return NO;
+    }
+    DIR *directory = fdopendir(duplicated);
+    if (!directory) {
+        close(duplicated);
+        return NO;
+    }
+    NSMutableArray<NSString *> *entries = [NSMutableArray array];
+    BOOL complete = YES;
+    errno = 0;
+    struct dirent *entry = NULL;
+    while ((entry = readdir(directory)) != NULL) {
+        if (strcmp(entry->d_name, ".") == 0 ||
+            strcmp(entry->d_name, "..") == 0) {
+            continue;
+        }
+        if (entries.count >= maximumEntries) {
+            complete = NO;
+            break;
+        }
+        size_t length = strlen(entry->d_name);
+        NSString *name = [[NSString alloc] initWithBytes:entry->d_name
+                                                 length:length
+                                               encoding:NSUTF8StringEncoding];
+        NSData *roundTrip = [name dataUsingEncoding:NSUTF8StringEncoding
+                                allowLossyConversion:NO];
+        if (!name || !roundTrip || roundTrip.length != length ||
+            memcmp(roundTrip.bytes, entry->d_name, length) != 0) {
+            complete = NO;
+            break;
+        }
+        [entries addObject:name];
+    }
+    if (!entry && errno != 0) {
+        complete = NO;
+    }
+    if (closedir(directory) != 0) {
+        complete = NO;
+    }
+    if (complete && entriesOut) {
+        *entriesOut = [entries copy];
+    }
+    return complete;
+}
+
+static BOOL PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
+    int parentDescriptor,
+    const char *name,
+    const struct stat *expectedIdentity,
+    dev_t expectedDevice) {
+    if (parentDescriptor < 0 || !name || !expectedIdentity) {
+        return NO;
+    }
+    struct stat namespaceStat;
+    if (fstatat(parentDescriptor,
+                name,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(namespaceStat.st_mode) ||
+        namespaceStat.st_dev != expectedDevice ||
+        !PXBackupArtifactStatIdentityMatches(&namespaceStat,
+                                            expectedIdentity)) {
+        return NO;
+    }
+    int descriptor = openat(parentDescriptor,
+                            name,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (descriptor < 0) {
+        return NO;
+    }
+    struct stat descriptorStat;
+    NSArray<NSString *> *entries = nil;
+    BOOL safe = fstat(descriptor, &descriptorStat) == 0 &&
+                S_ISDIR(descriptorStat.st_mode) &&
+                descriptorStat.st_dev == expectedDevice &&
+                PXBackupArtifactStatIdentityMatches(&descriptorStat,
+                                                    expectedIdentity) &&
+                PXBackupArtifactStatIdentityMatches(&descriptorStat,
+                                                    &namespaceStat) &&
+                PXBackupArtifactDescriptorHasCloseOnExec(descriptor) &&
+                PXBackupArtifactDirectoryEntries(descriptor,
+                                                 PXBackupArtifactFailureCleanupEntries,
+                                                 &entries) &&
+                entries.count == 0;
+    struct stat finalNamespaceStat;
+    safe = safe &&
+           fstatat(parentDescriptor,
+                   name,
+                   &finalNamespaceStat,
+                   AT_SYMLINK_NOFOLLOW) == 0 &&
+           S_ISDIR(finalNamespaceStat.st_mode) &&
+           PXBackupArtifactStatIdentityMatches(&finalNamespaceStat,
+                                               expectedIdentity) &&
+           unlinkat(parentDescriptor, name, AT_REMOVEDIR) == 0 &&
+           PXBackupArtifactStrictSync(parentDescriptor);
+    close(descriptor);
+    return safe;
+}
+
+static BOOL PXBackupArtifactPathMatchesDirectoryDescriptor(
+    NSString *path,
+    int descriptor,
+    const struct stat *expectedIdentity) {
+    NSData *pathData = PXBackupArtifactLosslessUTF8Data(path);
+    char *pathCString = PXBackupArtifactCopyCString(pathData);
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
+                 PXBackupArtifactStatIdentityMatches(&pathStat,
+                                                     &descriptorStat) &&
+                 (!expectedIdentity ||
+                  PXBackupArtifactStatIdentityMatches(expectedIdentity,
+                                                      &descriptorStat));
+    free(pathCString);
+    return valid;
+}
+
+static BOOL PXBackupArtifactDirectoryIdentityValid(int descriptor,
+                                                    const struct stat *expected,
+                                                    dev_t expectedDevice,
+                                                    BOOL requireMode0700) {
+    struct stat current;
+    return descriptor >= 0 &&
+           fstat(descriptor, &current) == 0 &&
+           S_ISDIR(current.st_mode) &&
+           (current.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+           (!requireMode0700 || (current.st_mode & 07777) == 0700) &&
+           current.st_dev == expectedDevice &&
+           PXBackupArtifactStatIdentityMatches(&current, expected) &&
+           PXBackupArtifactDescriptorHasCloseOnExec(descriptor);
+}
+
+static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
+                                           size_t length) {
+    static const char alphabet[] = "0123456789abcdef";
+    if (!digest || length != CC_SHA256_DIGEST_LENGTH) {
+        return nil;
+    }
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
+@interface PXBackupArtifactParentBinding : NSObject
+
+@property (nonatomic, assign) int descriptor;
+@property (nonatomic, assign) int authorityDescriptor;
+@property (nonatomic, copy) NSData *authorityComponentData;
+@property (nonatomic, copy) NSString *path;
+@property (nonatomic, assign) struct stat identity;
+@property (nonatomic, assign) struct stat authorityIdentity;
+@property (nonatomic, assign) BOOL workspaceRoot;
+
+- (const struct stat *)identityPointer;
+- (const struct stat *)authorityIdentityPointer;
+
+@end
+
+@implementation PXBackupArtifactParentBinding
+
+- (instancetype)init {
+    self = [super init];
+    if (self) {
+        _descriptor = -1;
+        _authorityDescriptor = -1;
+    }
+    return self;
+}
+
+- (const struct stat *)identityPointer {
+    return &_identity;
+}
+
+- (const struct stat *)authorityIdentityPointer {
+    return &_authorityIdentity;
+}
+
+- (void)dealloc {
+    if (_descriptor >= 0) {
+        close(_descriptor);
+        _descriptor = -1;
+    }
+    if (_authorityDescriptor >= 0) {
+        close(_authorityDescriptor);
+        _authorityDescriptor = -1;
+    }
+}
+
+@end
+
+@interface PXBackupArtifactTemporaryBinding : NSObject
+
+@property (nonatomic, assign) int descriptor;
+@property (nonatomic, copy) NSString *path;
+@property (nonatomic, copy) NSString *name;
+@property (nonatomic, copy) NSData *nameData;
+@property (nonatomic, assign) struct stat identity;
+
+- (const struct stat *)identityPointer;
+
+@end
+
+@implementation PXBackupArtifactTemporaryBinding
+
+- (instancetype)init {
+    self = [super init];
+    if (self) {
+        _descriptor = -1;
+    }
+    return self;
+}
+
+- (const struct stat *)identityPointer {
+    return &_identity;
+}
+
+- (void)dealloc {
+    if (_descriptor >= 0) {
+        close(_descriptor);
+        _descriptor = -1;
+    }
+}
+
+@end
+
+@interface PXVerifiedBackupArtifact ()
+
+- (instancetype)initWithRelativePath:(NSString *)relativePath
+                            filePath:(NSString *)filePath
+                                size:(unsigned long long)size
+                              sha256:(NSString *)sha256;
+
+@end
+
+@implementation PXVerifiedBackupArtifact {
+    NSString *_relativePath;
+    NSString *_filePath;
+    unsigned long long _size;
+    NSString *_sha256;
+    NSDictionary<NSString *, id> *_manifestRepresentation;
+}
+
+- (instancetype)initWithRelativePath:(NSString *)relativePath
+                            filePath:(NSString *)filePath
+                                size:(unsigned long long)size
+                              sha256:(NSString *)sha256 {
+    self = [super init];
+    if (self) {
+        _relativePath = [relativePath copy];
+        _filePath = [filePath copy];
+        _size = size;
+        _sha256 = [sha256 copy];
+        _manifestRepresentation = @{
+            @"name": _relativePath,
+            @"path": _filePath,
+            @"size": [NSNumber numberWithUnsignedLongLong:_size],
+            @"sha256": _sha256,
+        };
+    }
+    return self;
+}
+
+- (NSString *)relativePath { return _relativePath; }
+- (NSString *)filePath { return _filePath; }
+- (unsigned long long)size { return _size; }
+- (NSString *)sha256 { return _sha256; }
+- (NSDictionary<NSString *,id> *)manifestRepresentation {
+    return _manifestRepresentation;
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
+    if (![object isKindOfClass:[PXVerifiedBackupArtifact class]]) {
+        return NO;
+    }
+    PXVerifiedBackupArtifact *other = object;
+    return self.size == other.size &&
+           [self.relativePath isEqualToString:other.relativePath] &&
+           [self.filePath isEqualToString:other.filePath] &&
+           [self.sha256 isEqualToString:other.sha256];
+}
+
+- (NSUInteger)hash {
+    NSUInteger value = self.relativePath.hash;
+    value ^= self.filePath.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
+    value ^= (NSUInteger)self.size + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
+    value ^= self.sha256.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
+    return value;
+}
+
+@end
+
+@interface PXBackupArtifactWriter ()
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                    workspacePath:(NSString *)workspacePath
+               workspaceDescriptor:(int)workspaceDescriptor
+                 workspaceIdentity:(const struct stat *)workspaceIdentity;
+
+@end
+
+@implementation PXBackupArtifactWriter {
+    PXBackupPublicationWorkspace *_workspace;
+    NSString *_workspacePath;
+    int _workspaceDescriptor;
+    struct stat _workspaceIdentity;
+    NSMutableSet<NSString *> *_acceptedPaths;
+    NSMutableSet<NSString *> *_acceptedNormalizedAliases;
+    NSUInteger _artifactCount;
+}
+
++ (nullable instancetype)writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
+                                      error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (!workspace ||
+        ![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]]) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorInvalidInput,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace input is invalid");
+        return nil;
+    }
+    NSError *workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError]) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorWorkspaceValidationFailed,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace identity is invalid");
+        return nil;
+    }
+    NSString *workspacePath = workspace.workspacePath;
+    NSData *workspaceData = PXBackupArtifactLosslessUTF8Data(workspacePath);
+    if (!workspaceData || workspaceData.length == 0 ||
+        workspaceData.length > PXBackupArtifactMaximumAbsolutePathBytes ||
+        ![workspacePath hasPrefix:@"/"] ||
+        !PXBackupArtifactPathRoundTrips(workspacePath, workspaceData)) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorInvalidInput,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace path is invalid");
+        return nil;
+    }
+    char *workspaceCString = PXBackupArtifactCopyCString(workspaceData);
+    if (!workspaceCString) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorLimitExceeded,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace exceeded resource limits");
+        return nil;
+    }
+    struct stat pathStat;
+    struct stat descriptorStat;
+    int descriptor = -1;
+    BOOL valid = lstat(workspaceCString, &pathStat) == 0 &&
+                 !S_ISLNK(pathStat.st_mode) &&
+                 S_ISDIR(pathStat.st_mode);
+    if (valid) {
+        descriptor = open(workspaceCString,
+                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        valid = descriptor >= 0 &&
+                fstat(descriptor, &descriptorStat) == 0 &&
+                S_ISDIR(descriptorStat.st_mode) &&
+                (descriptorStat.st_mode & 07777) == 0700 &&
+                PXBackupArtifactStatIdentityMatches(&pathStat,
+                                                    &descriptorStat) &&
+                PXBackupArtifactDescriptorHasCloseOnExec(descriptor);
+    }
+    free(workspaceCString);
+    if (!valid) {
+        if (descriptor >= 0) {
+            close(descriptor);
+        }
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorWorkspaceInspectionFailed,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace could not be opened safely");
+        return nil;
+    }
+    workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError] ||
+        !PXBackupArtifactPathMatchesDirectoryDescriptor(workspacePath,
+                                                        descriptor,
+                                                        &descriptorStat)) {
+        close(descriptor);
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorFilesystemChanged,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace identity changed");
+        return nil;
+    }
+    PXBackupArtifactWriter *writer =
+        [[PXBackupArtifactWriter alloc] initWithWorkspace:workspace
+                                           workspacePath:workspacePath
+                                      workspaceDescriptor:descriptor
+                                        workspaceIdentity:&descriptorStat];
+    if (!writer) {
+        close(descriptor);
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorWorkspaceInspectionFailed,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace writer could not be retained");
+        return nil;
+    }
+    return writer;
+}
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                    workspacePath:(NSString *)workspacePath
+               workspaceDescriptor:(int)workspaceDescriptor
+                 workspaceIdentity:(const struct stat *)workspaceIdentity {
+    NSMutableSet<NSString *> *acceptedPaths = [NSMutableSet set];
+    NSMutableSet<NSString *> *acceptedAliases = [NSMutableSet set];
+    NSString *copiedWorkspacePath = [workspacePath copy];
+    if (!acceptedPaths || !acceptedAliases || !copiedWorkspacePath) {
+        return nil;
+    }
+    self = [super init];
+    if (self) {
+        _workspace = workspace;
+        _workspacePath = copiedWorkspacePath;
+        _workspaceDescriptor = workspaceDescriptor;
+        _workspaceIdentity = *workspaceIdentity;
+        _acceptedPaths = acceptedPaths;
+        _acceptedNormalizedAliases = acceptedAliases;
+        _artifactCount = 0;
+    }
+    return self;
+}
+
+- (NSString *)workspacePath { return _workspacePath; }
+- (NSUInteger)artifactCount { return _artifactCount; }
+
+- (BOOL)validateIdentityWithError:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (!_workspace || _workspaceDescriptor < 0 ||
+        ![_workspacePath isKindOfClass:[NSString class]]) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorFilesystemChanged,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The retained writer identity is invalid");
+        return NO;
+    }
+    NSError *workspaceError = nil;
+    if (![_workspace validateIdentityWithError:&workspaceError]) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorWorkspaceValidationFailed,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The workspace identity is invalid");
+        return NO;
+    }
+    struct stat descriptorStat;
+    if (fstat(_workspaceDescriptor, &descriptorStat) != 0 ||
+        !S_ISDIR(descriptorStat.st_mode) ||
+        (descriptorStat.st_mode & 07777) != 0700 ||
+        !PXBackupArtifactStatIdentityMatches(&descriptorStat,
+                                            &_workspaceIdentity) ||
+        !PXBackupArtifactDescriptorHasCloseOnExec(_workspaceDescriptor) ||
+        !PXBackupArtifactPathMatchesDirectoryDescriptor(_workspacePath,
+                                                        _workspaceDescriptor,
+                                                        &_workspaceIdentity)) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorFilesystemChanged,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The writer workspace identity changed");
+        return NO;
+    }
+    return YES;
+}
+
+- (BOOL)acceptedPathConflicts:(NSString *)relativePath {
+    if ([_acceptedPaths containsObject:relativePath]) {
+        return YES;
+    }
+    NSString *candidatePrefix = [relativePath stringByAppendingString:@"/"];
+    for (NSString *accepted in _acceptedPaths) {
+        if ([relativePath hasPrefix:[accepted stringByAppendingString:@"/"]] ||
+            [accepted hasPrefix:candidatePrefix]) {
+            return YES;
+        }
+    }
+    NSString *precomposed = [relativePath precomposedStringWithCanonicalMapping];
+    NSString *decomposed = [relativePath decomposedStringWithCanonicalMapping];
+    NSString *precomposedPrefix = [precomposed stringByAppendingString:@"/"];
+    NSString *decomposedPrefix = [decomposed stringByAppendingString:@"/"];
+    for (NSString *acceptedAlias in _acceptedNormalizedAliases) {
+        if ([acceptedAlias isEqualToString:precomposed] ||
+            [acceptedAlias isEqualToString:decomposed] ||
+            [precomposed hasPrefix:[acceptedAlias stringByAppendingString:@"/"]] ||
+            [decomposed hasPrefix:[acceptedAlias stringByAppendingString:@"/"]] ||
+            [acceptedAlias hasPrefix:precomposedPrefix] ||
+            [acceptedAlias hasPrefix:decomposedPrefix]) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+- (PXBackupArtifactParentBinding *)openParentForComponents:(NSArray<NSString *> *)components
+                                                     error:(NSError **)error {
+    int currentDescriptor = PXBackupArtifactDuplicateDescriptor(_workspaceDescriptor);
+    if (currentDescriptor < 0) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorParentInvalid,
+                                 PXBackupArtifactParentField,
+                                 @"The artifact parent could not be opened safely");
+        return nil;
+    }
+    struct stat currentIdentity;
+    if (fstat(currentDescriptor, &currentIdentity) != 0 ||
+        !PXBackupArtifactStatIdentityMatches(&currentIdentity,
+                                            &_workspaceIdentity)) {
+        close(currentDescriptor);
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorFilesystemChanged,
+                                 PXBackupArtifactParentField,
+                                 @"The artifact parent identity changed");
+        return nil;
+    }
+    int authorityDescriptor = -1;
+    struct stat authorityIdentity;
+    memset(&authorityIdentity, 0, sizeof(authorityIdentity));
+    NSData *authorityComponentData = nil;
+    NSString *currentPath = _workspacePath;
+    NSUInteger parentCount = components.count > 0 ? components.count - 1 : 0;
+    for (NSUInteger index = 0; index < parentCount; index++) {
+        NSString *component = components[index];
+        NSData *componentData = PXBackupArtifactLosslessUTF8Data(component);
+        char *componentCString = PXBackupArtifactCopyCString(componentData);
+        if (!componentCString) {
+            if (authorityDescriptor >= 0) close(authorityDescriptor);
+            close(currentDescriptor);
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorLimitExceeded,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent exceeded resource limits");
+            return nil;
+        }
+        struct stat namespaceStat;
+        BOOL created = NO;
+        if (fstatat(currentDescriptor,
+                    componentCString,
+                    &namespaceStat,
+                    AT_SYMLINK_NOFOLLOW) != 0) {
+            if (errno != ENOENT) {
+                free(componentCString);
+                if (authorityDescriptor >= 0) close(authorityDescriptor);
+                close(currentDescriptor);
+                PXBackupArtifactSetError(error,
+                                         PXBackupArtifactWriterErrorParentInvalid,
+                                         PXBackupArtifactParentField,
+                                         @"The artifact parent could not be inspected");
+                return nil;
+            }
+            if (mkdirat(currentDescriptor, componentCString, 0700) != 0) {
+                free(componentCString);
+                if (authorityDescriptor >= 0) close(authorityDescriptor);
+                close(currentDescriptor);
+                PXBackupArtifactSetError(error,
+                                         PXBackupArtifactWriterErrorParentCreationFailed,
+                                         PXBackupArtifactParentField,
+                                         @"The artifact parent could not be created");
+                return nil;
+            }
+            created = YES;
+            if (fstatat(currentDescriptor,
+                        componentCString,
+                        &namespaceStat,
+                        AT_SYMLINK_NOFOLLOW) != 0) {
+                free(componentCString);
+                if (authorityDescriptor >= 0) close(authorityDescriptor);
+                close(currentDescriptor);
+                PXBackupArtifactSetError(error,
+                                         PXBackupArtifactWriterErrorParentInvalid,
+                                         PXBackupArtifactParentField,
+                                         @"The artifact parent could not be inspected");
+                return nil;
+            }
+        }
+        if (!S_ISDIR(namespaceStat.st_mode) ||
+            (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+            free(componentCString);
+            if (authorityDescriptor >= 0) close(authorityDescriptor);
+            close(currentDescriptor);
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorParentInvalid,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent is invalid");
+            return nil;
+        }
+        int nextDescriptor = openat(currentDescriptor,
+                                    componentCString,
+                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        if (nextDescriptor < 0) {
+            free(componentCString);
+            if (authorityDescriptor >= 0) close(authorityDescriptor);
+            close(currentDescriptor);
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorParentInvalid,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent could not be opened safely");
+            return nil;
+        }
+        if (created && fchmod(nextDescriptor, 0700) != 0) {
+            close(nextDescriptor);
+            free(componentCString);
+            if (authorityDescriptor >= 0) close(authorityDescriptor);
+            close(currentDescriptor);
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorParentInvalid,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent permissions could not be secured");
+            return nil;
+        }
+        struct stat nextIdentity;
+        BOOL valid = fstat(nextDescriptor, &nextIdentity) == 0 &&
+                     S_ISDIR(nextIdentity.st_mode) &&
+                     (nextIdentity.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                     (!created || (nextIdentity.st_mode & 07777) == 0700) &&
+                     nextIdentity.st_dev == _workspaceIdentity.st_dev &&
+                     PXBackupArtifactStatIdentityMatches(&namespaceStat,
+                                                        &nextIdentity) &&
+                     PXBackupArtifactDescriptorHasCloseOnExec(nextDescriptor);
+        NSString *nextPath = PXBackupArtifactAppendComponent(currentPath,
+                                                             component);
+        NSData *nextPathData = PXBackupArtifactLosslessUTF8Data(nextPath);
+        valid = valid && nextPathData &&
+                nextPathData.length <= PXBackupArtifactMaximumAbsolutePathBytes &&
+                PXBackupArtifactPathMatchesDirectoryDescriptor(nextPath,
+                                                               nextDescriptor,
+                                                               &nextIdentity);
+        if (!valid) {
+            close(nextDescriptor);
+            free(componentCString);
+            if (authorityDescriptor >= 0) close(authorityDescriptor);
+            close(currentDescriptor);
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorFilesystemChanged,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent identity changed");
+            return nil;
+        }
+        if (authorityDescriptor >= 0) {
+            close(authorityDescriptor);
+        }
+        authorityDescriptor = currentDescriptor;
+        authorityIdentity = currentIdentity;
+        authorityComponentData = componentData;
+        currentDescriptor = nextDescriptor;
+        currentIdentity = nextIdentity;
+        currentPath = nextPath;
+        free(componentCString);
+    }
+    PXBackupArtifactParentBinding *binding =
+        [[PXBackupArtifactParentBinding alloc] init];
+    if (!binding) {
+        if (authorityDescriptor >= 0) close(authorityDescriptor);
+        close(currentDescriptor);
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorLimitExceeded,
+                                 PXBackupArtifactParentField,
+                                 @"The artifact parent exceeded resource limits");
+        return nil;
+    }
+    binding.descriptor = currentDescriptor;
+    binding.authorityDescriptor = authorityDescriptor;
+    binding.authorityComponentData = authorityComponentData;
+    binding.path = currentPath;
+    binding.identity = currentIdentity;
+    binding.authorityIdentity = authorityIdentity;
+    binding.workspaceRoot = parentCount == 0;
+    return binding;
+}
+
+- (BOOL)validateParentBinding:(PXBackupArtifactParentBinding *)parent
+                        error:(NSError **)error {
+    if (!parent ||
+        !PXBackupArtifactDirectoryIdentityValid(parent.descriptor,
+                                                [parent identityPointer],
+                                                _workspaceIdentity.st_dev,
+                                                NO) ||
+        !PXBackupArtifactPathMatchesDirectoryDescriptor(parent.path,
+                                                        parent.descriptor,
+                                                        [parent identityPointer])) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorFilesystemChanged,
+                                 PXBackupArtifactParentField,
+                                 @"The artifact parent identity changed");
+        return NO;
+    }
+    if (parent.workspaceRoot) {
+        if (!PXBackupArtifactStatIdentityMatches([parent identityPointer],
+                                                &_workspaceIdentity)) {
+            PXBackupArtifactSetError(error,
+                                     PXBackupArtifactWriterErrorFilesystemChanged,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent identity changed");
+            return NO;
+        }
+        return YES;
+    }
+    char *componentCString =
+        PXBackupArtifactCopyCString(parent.authorityComponentData);
+    struct stat namespaceStat;
+    BOOL valid = componentCString && parent.authorityDescriptor >= 0 &&
+                 PXBackupArtifactDirectoryIdentityValid(parent.authorityDescriptor,
+                                                         [parent authorityIdentityPointer],
+                                                         _workspaceIdentity.st_dev,
+                                                         NO) &&
+                 fstatat(parent.authorityDescriptor,
+                         componentCString,
+                         &namespaceStat,
+                         AT_SYMLINK_NOFOLLOW) == 0 &&
+                 S_ISDIR(namespaceStat.st_mode) &&
+                 PXBackupArtifactStatIdentityMatches(&namespaceStat,
+                                                     [parent identityPointer]);
+    free(componentCString);
+    if (!valid) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorFilesystemChanged,
+                                 PXBackupArtifactParentField,
+                                 @"The artifact parent namespace changed");
+        return NO;
+    }
+    return YES;
+}
+
+- (PXBackupArtifactTemporaryBinding *)createTemporaryUnderParent:(PXBackupArtifactParentBinding *)parent
+                                                           error:(NSError **)error {
+    NSString *templateName = [[NSString alloc]
+        initWithBytes:PXBackupArtifactTemporaryTemplate
+               length:strlen(PXBackupArtifactTemporaryTemplate)
+             encoding:NSASCIIStringEncoding];
+    NSString *templatePath = templateName
+        ? PXBackupArtifactAppendComponent(parent.path, templateName)
+        : nil;
+    NSData *templateData = PXBackupArtifactLosslessUTF8Data(templatePath);
+    if (!templateData ||
+        templateData.length > PXBackupArtifactMaximumAbsolutePathBytes) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorLimitExceeded,
+                                 PXBackupArtifactTemporaryField,
+                                 @"The temporary artifact path exceeded resource limits");
+        return nil;
+    }
+    char *templateCString = PXBackupArtifactCopyCString(templateData);
+    if (!templateCString) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorLimitExceeded,
+                                 PXBackupArtifactTemporaryField,
+                                 @"The temporary artifact path exceeded resource limits");
+        return nil;
+    }
+    char *createdCString = mkdtemp(templateCString);
+    if (!createdCString) {
+        free(templateCString);
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorTemporaryCreationFailed,
+                                 PXBackupArtifactTemporaryField,
+                                 @"The temporary artifact directory could not be created");
+        return nil;
+    }
+    const char *nameCString = strrchr(createdCString, '/');
+    nameCString = nameCString ? nameCString + 1 : createdCString;
+    struct stat createdIdentity;
+    BOOL createdIdentityKnown =
+        lstat(createdCString, &createdIdentity) == 0 &&
+        !S_ISLNK(createdIdentity.st_mode) &&
+        S_ISDIR(createdIdentity.st_mode);
+    size_t nameLength = strlen(nameCString);
+    NSString *name = [[NSString alloc] initWithBytes:nameCString
+                                              length:nameLength
+                                            encoding:NSUTF8StringEncoding];
+    NSData *nameData = nil;
+    NSString *createdPath = [[NSString alloc]
+        initWithBytes:createdCString
+               length:strlen(createdCString)
+             encoding:NSUTF8StringEncoding];
+    NSData *createdPathData = PXBackupArtifactLosslessUTF8Data(createdPath);
+    BOOL validName = PXBackupArtifactValidateTemporaryComponent(name,
+                                                                &nameData) &&
+                     createdPathData &&
+                     createdPathData.length <=
+                         PXBackupArtifactMaximumAbsolutePathBytes &&
+                     [createdPath isEqualToString:
+                         PXBackupArtifactAppendComponent(parent.path, name)];
+    if (!validName) {
+        BOOL cleanupSucceeded = createdIdentityKnown &&
+            PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
+                parent.descriptor,
+                nameCString,
+                &createdIdentity,
+                _workspaceIdentity.st_dev);
+        free(templateCString);
+        PXBackupArtifactSetError(error,
+                                 cleanupSucceeded
+                                     ? PXBackupArtifactWriterErrorTemporaryCreationFailed
+                                     : PXBackupArtifactWriterErrorCleanupFailed,
+                                 PXBackupArtifactTemporaryField,
+                                 cleanupSucceeded
+                                     ? @"The temporary artifact directory name is invalid"
+                                     : @"Owned temporary artifact state could not be cleaned safely");
+        return nil;
+    }
+    struct stat pathStat = createdIdentity;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    int descriptor = -1;
+    BOOL valid = createdIdentityKnown &&
+                 fstatat(parent.descriptor,
+                         nameCString,
+                         &namespaceStat,
+                         AT_SYMLINK_NOFOLLOW) == 0 &&
+                 S_ISDIR(namespaceStat.st_mode) &&
+                 PXBackupArtifactStatIdentityMatches(&pathStat,
+                                                     &namespaceStat);
+    if (valid) {
+        descriptor = openat(parent.descriptor,
+                            nameCString,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+        valid = descriptor >= 0 &&
+                fchmod(descriptor, 0700) == 0 &&
+                fstat(descriptor, &descriptorStat) == 0 &&
+                S_ISDIR(descriptorStat.st_mode) &&
+                (descriptorStat.st_mode & 07777) == 0700 &&
+                descriptorStat.st_dev == _workspaceIdentity.st_dev &&
+                PXBackupArtifactStatIdentityMatches(&pathStat,
+                                                    &descriptorStat) &&
+                PXBackupArtifactStatIdentityMatches(&namespaceStat,
+                                                    &descriptorStat) &&
+                PXBackupArtifactDescriptorHasCloseOnExec(descriptor);
+    }
+    NSArray<NSString *> *initialEntries = nil;
+    valid = valid &&
+            PXBackupArtifactDirectoryEntries(descriptor,
+                                             PXBackupArtifactTemporaryOperationalEntries,
+                                             &initialEntries) &&
+            initialEntries.count == 0;
+    if (!valid) {
+        if (descriptor >= 0) close(descriptor);
+        BOOL cleanupSucceeded = createdIdentityKnown &&
+            PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
+                parent.descriptor,
+                nameCString,
+                &createdIdentity,
+                _workspaceIdentity.st_dev);
+        free(templateCString);
+        PXBackupArtifactSetError(error,
+                                 cleanupSucceeded
+                                     ? PXBackupArtifactWriterErrorTemporaryCreationFailed
+                                     : PXBackupArtifactWriterErrorCleanupFailed,
+                                 PXBackupArtifactTemporaryField,
+                                 cleanupSucceeded
+                                     ? @"The temporary artifact directory is invalid"
+                                     : @"Owned temporary artifact state could not be cleaned safely");
+        return nil;
+    }
+    PXBackupArtifactTemporaryBinding *binding =
+        [[PXBackupArtifactTemporaryBinding alloc] init];
+    if (!binding) {
+        close(descriptor);
+        BOOL cleanupSucceeded =
+            PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
+                parent.descriptor,
+                nameCString,
+                &createdIdentity,
+                _workspaceIdentity.st_dev);
+        free(templateCString);
+        PXBackupArtifactSetError(error,
+                                 cleanupSucceeded
+                                     ? PXBackupArtifactWriterErrorLimitExceeded
+                                     : PXBackupArtifactWriterErrorCleanupFailed,
+                                 PXBackupArtifactTemporaryField,
+                                 cleanupSucceeded
+                                     ? @"The temporary artifact binding exceeded resource limits"
+                                     : @"Owned temporary artifact state could not be cleaned safely");
+        return nil;
+    }
+    free(templateCString);
+    binding.descriptor = descriptor;
+    binding.path = createdPath;
+    binding.name = name;
+    binding.nameData = nameData;
+    binding.identity = descriptorStat;
+    return binding;
+}
+
+- (BOOL)validateTemporaryBinding:(PXBackupArtifactTemporaryBinding *)temporary
+                          parent:(PXBackupArtifactParentBinding *)parent {
+    char *nameCString = PXBackupArtifactCopyCString(temporary.nameData);
+    struct stat namespaceStat;
+    BOOL valid = temporary && nameCString &&
+                 PXBackupArtifactDirectoryIdentityValid(temporary.descriptor,
+                                                         [temporary identityPointer],
+                                                         _workspaceIdentity.st_dev,
+                                                         YES) &&
+                 fstatat(parent.descriptor,
+                         nameCString,
+                         &namespaceStat,
+                         AT_SYMLINK_NOFOLLOW) == 0 &&
+                 S_ISDIR(namespaceStat.st_mode) &&
+                 PXBackupArtifactStatIdentityMatches(&namespaceStat,
+                                                     [temporary identityPointer]) &&
+                 PXBackupArtifactPathMatchesDirectoryDescriptor(temporary.path,
+                                                                temporary.descriptor,
+                                                                [temporary identityPointer]);
+    free(nameCString);
+    return valid;
+}
+
+- (BOOL)cleanupParent:(PXBackupArtifactParentBinding *)parent
+             temporary:(PXBackupArtifactTemporaryBinding *)temporary
+        payloadIdentity:(const struct stat *)payloadIdentity
+           finalNameData:(NSData *)finalNameData
+            finalRenamed:(BOOL)finalRenamed
+        temporaryRemoved:(BOOL)temporaryRemoved {
+    BOOL safe = YES;
+    if (finalRenamed && payloadIdentity && finalNameData) {
+        char *finalNameCString = PXBackupArtifactCopyCString(finalNameData);
+        struct stat finalStat;
+        if (!finalNameCString ||
+            fstatat(parent.descriptor,
+                    finalNameCString,
+                    &finalStat,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            !S_ISREG(finalStat.st_mode) ||
+            finalStat.st_nlink != 1 ||
+            (finalStat.st_mode & 07777) != 0600 ||
+            finalStat.st_dev != _workspaceIdentity.st_dev ||
+            !PXBackupArtifactStatIdentityMatches(&finalStat,
+                                                payloadIdentity) ||
+            unlinkat(parent.descriptor, finalNameCString, 0) != 0 ||
+            !PXBackupArtifactStrictSync(parent.descriptor)) {
+            safe = NO;
+        }
+        free(finalNameCString);
+    }
+    if (!temporaryRemoved && temporary) {
+        NSArray<NSString *> *entries = nil;
+        if (!PXBackupArtifactDirectoryEntries(temporary.descriptor,
+                                              PXBackupArtifactFailureCleanupEntries,
+                                              &entries)) {
+            safe = NO;
+        } else {
+            for (NSString *entryName in entries) {
+                if (![entryName isEqualToString:@"payload"]) {
+                    safe = NO;
+                    continue;
+                }
+                struct stat namespaceStat;
+                if (fstatat(temporary.descriptor,
+                            PXBackupArtifactPayloadName,
+                            &namespaceStat,
+                            AT_SYMLINK_NOFOLLOW) != 0 ||
+                    !S_ISREG(namespaceStat.st_mode) ||
+                    namespaceStat.st_nlink != 1 ||
+                    namespaceStat.st_dev != _workspaceIdentity.st_dev ||
+                    (payloadIdentity &&
+                     !PXBackupArtifactStatIdentityMatches(&namespaceStat,
+                                                         payloadIdentity))) {
+                    safe = NO;
+                    continue;
+                }
+                int descriptor = openat(temporary.descriptor,
+                                        PXBackupArtifactPayloadName,
+                                        O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+                struct stat descriptorStat;
+                BOOL exact = descriptor >= 0 &&
+                             fstat(descriptor, &descriptorStat) == 0 &&
+                             S_ISREG(descriptorStat.st_mode) &&
+                             descriptorStat.st_nlink == 1 &&
+                             descriptorStat.st_dev == _workspaceIdentity.st_dev &&
+                             PXBackupArtifactStatIdentityMatches(&namespaceStat,
+                                                                &descriptorStat) &&
+                             (!payloadIdentity ||
+                              PXBackupArtifactStatIdentityMatches(payloadIdentity,
+                                                                  &descriptorStat));
+                if (descriptor >= 0) close(descriptor);
+                if (!exact ||
+                    unlinkat(temporary.descriptor,
+                             PXBackupArtifactPayloadName,
+                             0) != 0) {
+                    safe = NO;
+                }
+            }
+        }
+        NSArray<NSString *> *remaining = nil;
+        char *temporaryNameCString =
+            PXBackupArtifactCopyCString(temporary.nameData);
+        struct stat temporaryNamespaceStat;
+        BOOL removable = temporaryNameCString &&
+                         PXBackupArtifactDirectoryEntries(temporary.descriptor,
+                                                          1,
+                                                          &remaining) &&
+                         remaining.count == 0 &&
+                         fstatat(parent.descriptor,
+                                 temporaryNameCString,
+                                 &temporaryNamespaceStat,
+                                 AT_SYMLINK_NOFOLLOW) == 0 &&
+                         S_ISDIR(temporaryNamespaceStat.st_mode) &&
+                         PXBackupArtifactStatIdentityMatches(&temporaryNamespaceStat,
+                                                            [temporary identityPointer]) &&
+                         unlinkat(parent.descriptor,
+                                  temporaryNameCString,
+                                  AT_REMOVEDIR) == 0 &&
+                         PXBackupArtifactStrictSync(parent.descriptor);
+        free(temporaryNameCString);
+        if (!removable) {
+            safe = NO;
+        }
+    }
+    return safe;
+}
+
+- (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
+                                                          producer:(PXBackupArtifactProducer)producer
+                                                             error:(NSError **)error {
+    if (error) {
+        *error = nil;
+    }
+    if (!producer) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorInvalidInput,
+                                 PXBackupArtifactField,
+                                 @"The artifact producer is invalid");
+        return nil;
+    }
+    BOOL limitExceeded = NO;
+    NSArray<NSString *> *components =
+        PXBackupArtifactValidateRelativePath(relativePath, &limitExceeded);
+    if (!components) {
+        PXBackupArtifactSetError(error,
+                                 limitExceeded
+                                     ? PXBackupArtifactWriterErrorLimitExceeded
+                                     : PXBackupArtifactWriterErrorInvalidInput,
+                                 PXBackupArtifactRelativePathField,
+                                 @"The artifact relative path is invalid");
+        return nil;
+    }
+    if (_artifactCount >= PXBackupArtifactMaximumArtifacts) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorLimitExceeded,
+                                 PXBackupArtifactField,
+                                 @"The artifact count exceeded resource limits");
+        return nil;
+    }
+    if ([self acceptedPathConflicts:relativePath]) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorDuplicateArtifact,
+                                 PXBackupArtifactRelativePathField,
+                                 @"The artifact path conflicts with an accepted artifact");
+        return nil;
+    }
+    NSString *finalFilePath = PXBackupArtifactAppendComponent(_workspacePath,
+                                                              relativePath);
+    NSData *finalFilePathData = PXBackupArtifactLosslessUTF8Data(finalFilePath);
+    if (!finalFilePathData ||
+        finalFilePathData.length > PXBackupArtifactMaximumAbsolutePathBytes) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorLimitExceeded,
+                                 PXBackupArtifactField,
+                                 @"The finalized artifact path exceeded resource limits");
+        return nil;
+    }
+    NSError *identityError = nil;
+    if (![self validateIdentityWithError:&identityError]) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorWorkspaceValidationFailed,
+                                 PXBackupArtifactWorkspaceField,
+                                 @"The writer workspace identity is invalid");
+        return nil;
+    }
+    NSError *operationError = nil;
+    PXBackupArtifactParentBinding *parent =
+        [self openParentForComponents:components error:&operationError];
+    if (!parent) {
+        if (error) *error = operationError;
+        return nil;
+    }
+    NSString *finalComponent = components.lastObject;
+    NSData *finalNameData = PXBackupArtifactLosslessUTF8Data(finalComponent);
+    char *finalNameCString = PXBackupArtifactCopyCString(finalNameData);
+    if (!finalNameCString) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorLimitExceeded,
+                                 PXBackupArtifactRelativePathField,
+                                 @"The artifact name exceeded resource limits");
+        return nil;
+    }
+    struct stat existingFinalStat;
+    if (fstatat(parent.descriptor,
+                finalNameCString,
+                &existingFinalStat,
+                AT_SYMLINK_NOFOLLOW) == 0 ||
+        errno != ENOENT) {
+        free(finalNameCString);
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorDuplicateArtifact,
+                                 PXBackupArtifactRelativePathField,
+                                 @"The final artifact already exists");
+        return nil;
+    }
+    PXBackupArtifactTemporaryBinding *temporary =
+        [self createTemporaryUnderParent:parent error:&operationError];
+    if (!temporary) {
+        free(finalNameCString);
+        if (error) *error = operationError;
+        return nil;
+    }
+    struct stat payloadIdentity;
+    memset(&payloadIdentity, 0, sizeof(payloadIdentity));
+    BOOL payloadIdentityKnown = NO;
+    BOOL finalRenamed = NO;
+    BOOL temporaryRemoved = NO;
+    int payloadDescriptor = -1;
+    NSString *digestString = nil;
+    unsigned long long streamedBytes = 0;
+    PXVerifiedBackupArtifact *record = nil;
+
+    do {
+        struct stat preProducerPayloadStat;
+        if (fstatat(temporary.descriptor,
+                    PXBackupArtifactPayloadName,
+                    &preProducerPayloadStat,
+                    AT_SYMLINK_NOFOLLOW) == 0 ||
+            errno != ENOENT) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorOutputInvalid,
+                                     PXBackupArtifactPayloadField,
+                                     @"The producer output location is not empty");
+            break;
+        }
+        NSString *payloadPath = PXBackupArtifactAppendComponent(temporary.path,
+                                                                @"payload");
+        NSData *payloadPathData = PXBackupArtifactLosslessUTF8Data(payloadPath);
+        if (!payloadPathData ||
+            payloadPathData.length > PXBackupArtifactMaximumAbsolutePathBytes) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorLimitExceeded,
+                                     PXBackupArtifactPayloadField,
+                                     @"The producer output path exceeded resource limits");
+            break;
+        }
+        BOOL producerSucceeded = producer(payloadPath);
+        if (!producerSucceeded) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorProducerFailed,
+                                     PXBackupArtifactPayloadField,
+                                     @"The artifact producer failed");
+            break;
+        }
+        NSArray<NSString *> *temporaryEntries = nil;
+        if (!PXBackupArtifactDirectoryEntries(temporary.descriptor,
+                                              PXBackupArtifactTemporaryOperationalEntries + 1,
+                                              &temporaryEntries)) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorWorkspaceInspectionFailed,
+                                     PXBackupArtifactTemporaryField,
+                                     @"The temporary artifact directory could not be inspected");
+            break;
+        }
+        if (temporaryEntries.count == 0) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorOutputMissing,
+                                     PXBackupArtifactPayloadField,
+                                     @"The producer output is missing");
+            break;
+        }
+        if (temporaryEntries.count != 1 ||
+            ![temporaryEntries.firstObject isEqualToString:@"payload"]) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorOutputInvalid,
+                                     PXBackupArtifactTemporaryField,
+                                     @"The producer created unexpected temporary output");
+            break;
+        }
+        struct stat payloadNamespaceStat;
+        if (fstatat(temporary.descriptor,
+                    PXBackupArtifactPayloadName,
+                    &payloadNamespaceStat,
+                    AT_SYMLINK_NOFOLLOW) != 0) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorOutputMissing,
+                                     PXBackupArtifactPayloadField,
+                                     @"The producer output is missing");
+            break;
+        }
+        if (!S_ISREG(payloadNamespaceStat.st_mode) ||
+            payloadNamespaceStat.st_nlink != 1 ||
+            (payloadNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+            payloadNamespaceStat.st_dev != _workspaceIdentity.st_dev ||
+            payloadNamespaceStat.st_size < 0 ||
+            (unsigned long long)payloadNamespaceStat.st_size >
+                PXBackupArtifactMaximumFileBytes) {
+            PXBackupArtifactSetError(&operationError,
+                                     (payloadNamespaceStat.st_size >= 0 &&
+                                      (unsigned long long)payloadNamespaceStat.st_size >
+                                          PXBackupArtifactMaximumFileBytes)
+                                         ? PXBackupArtifactWriterErrorLimitExceeded
+                                         : PXBackupArtifactWriterErrorOutputInvalid,
+                                     PXBackupArtifactPayloadField,
+                                     @"The producer output is invalid");
+            break;
+        }
+        payloadDescriptor = openat(temporary.descriptor,
+                                   PXBackupArtifactPayloadName,
+                                   O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+        if (payloadDescriptor < 0) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorOutputInvalid,
+                                     PXBackupArtifactPayloadField,
+                                     @"The producer output could not be opened safely");
+            break;
+        }
+        if (fchmod(payloadDescriptor, 0600) != 0 ||
+            fstat(payloadDescriptor, &payloadIdentity) != 0 ||
+            !S_ISREG(payloadIdentity.st_mode) ||
+            payloadIdentity.st_nlink != 1 ||
+            (payloadIdentity.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+            (payloadIdentity.st_mode & 07777) != 0600 ||
+            payloadIdentity.st_dev != _workspaceIdentity.st_dev ||
+            payloadIdentity.st_size < 0 ||
+            (unsigned long long)payloadIdentity.st_size >
+                PXBackupArtifactMaximumFileBytes ||
+            !PXBackupArtifactStatIdentityMatches(&payloadNamespaceStat,
+                                                &payloadIdentity) ||
+            !PXBackupArtifactDescriptorHasCloseOnExec(payloadDescriptor)) {
+            PXBackupArtifactSetError(&operationError,
+                                     (payloadIdentity.st_size >= 0 &&
+                                      (unsigned long long)payloadIdentity.st_size >
+                                          PXBackupArtifactMaximumFileBytes)
+                                         ? PXBackupArtifactWriterErrorLimitExceeded
+                                         : PXBackupArtifactWriterErrorOutputInvalid,
+                                     PXBackupArtifactPayloadField,
+                                     @"The producer output is invalid");
+            break;
+        }
+        payloadIdentityKnown = YES;
+        CC_SHA256_CTX digestContext;
+        CC_SHA256_Init(&digestContext);
+        unsigned char *buffer = malloc(PXBackupArtifactStreamBufferBytes);
+        if (!buffer) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorLimitExceeded,
+                                     PXBackupArtifactPayloadField,
+                                     @"The artifact stream exceeded resource limits");
+            break;
+        }
+        BOOL readSucceeded = YES;
+        for (;;) {
+            ssize_t count = read(payloadDescriptor,
+                                 buffer,
+                                 PXBackupArtifactStreamBufferBytes);
+            if (count < 0 && errno == EINTR) {
+                continue;
+            }
+            if (count < 0) {
+                readSucceeded = NO;
+                break;
+            }
+            if (count == 0) {
+                break;
+            }
+            unsigned long long unsignedCount = (unsigned long long)count;
+            if (streamedBytes > ULLONG_MAX - unsignedCount ||
+                streamedBytes + unsignedCount > PXBackupArtifactMaximumFileBytes) {
+                readSucceeded = NO;
+                limitExceeded = YES;
+                break;
+            }
+            CC_SHA256_Update(&digestContext, buffer, (CC_LONG)count);
+            streamedBytes += unsignedCount;
+        }
+        free(buffer);
+        if (!readSucceeded ||
+            streamedBytes != (unsigned long long)payloadIdentity.st_size) {
+            PXBackupArtifactSetError(&operationError,
+                                     limitExceeded
+                                         ? PXBackupArtifactWriterErrorLimitExceeded
+                                         : PXBackupArtifactWriterErrorReadFailed,
+                                     PXBackupArtifactPayloadField,
+                                     @"The artifact could not be read completely");
+            break;
+        }
+        struct stat afterReadStat;
+        if (fstat(payloadDescriptor, &afterReadStat) != 0 ||
+            !PXBackupArtifactStableFileStatMatches(&payloadIdentity,
+                                                   &afterReadStat)) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorFilesystemChanged,
+                                     PXBackupArtifactPayloadField,
+                                     @"The artifact changed while being verified");
+            break;
+        }
+        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
+        CC_SHA256_Final(digest, &digestContext);
+        digestString = PXBackupArtifactHexDigest(digest,
+                                                CC_SHA256_DIGEST_LENGTH);
+        if (!digestString || digestString.length != 64) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorReadFailed,
+                                     PXBackupArtifactPayloadField,
+                                     @"The artifact digest could not be finalized");
+            break;
+        }
+        if (!PXBackupArtifactStrictSync(payloadDescriptor)) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorDurabilityFailed,
+                                     PXBackupArtifactPayloadField,
+                                     @"The artifact could not be synchronized");
+            break;
+        }
+        identityError = nil;
+        if (![self validateIdentityWithError:&identityError] ||
+            ![self validateParentBinding:parent error:&operationError] ||
+            ![self validateTemporaryBinding:temporary parent:parent]) {
+            if (!operationError) {
+                PXBackupArtifactSetError(&operationError,
+                                         PXBackupArtifactWriterErrorFilesystemChanged,
+                                         PXBackupArtifactTemporaryField,
+                                         @"The artifact namespace changed before finalization");
+            }
+            break;
+        }
+        struct stat payloadNamespaceRevalidation;
+        struct stat preRenameDescriptorStat;
+        if (fstat(payloadDescriptor, &preRenameDescriptorStat) != 0 ||
+            !PXBackupArtifactStableFileStatMatches(&payloadIdentity,
+                                                   &preRenameDescriptorStat) ||
+            fstatat(temporary.descriptor,
+                    PXBackupArtifactPayloadName,
+                    &payloadNamespaceRevalidation,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            !S_ISREG(payloadNamespaceRevalidation.st_mode) ||
+            payloadNamespaceRevalidation.st_nlink != 1 ||
+            (payloadNamespaceRevalidation.st_mode & 07777) != 0600 ||
+            !PXBackupArtifactStatIdentityMatches(&payloadNamespaceRevalidation,
+                                                &payloadIdentity) ||
+            fstatat(parent.descriptor,
+                    finalNameCString,
+                    &existingFinalStat,
+                    AT_SYMLINK_NOFOLLOW) == 0 ||
+            errno != ENOENT) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorFilesystemChanged,
+                                     PXBackupArtifactPayloadField,
+                                     @"The artifact namespace changed before finalization");
+            break;
+        }
+        if (renameat(temporary.descriptor,
+                     PXBackupArtifactPayloadName,
+                     parent.descriptor,
+                     finalNameCString) != 0) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorFinalizationFailed,
+                                     PXBackupArtifactField,
+                                     @"The artifact could not be finalized");
+            break;
+        }
+        finalRenamed = YES;
+        struct stat finalNamespaceStat;
+        if (fstatat(parent.descriptor,
+                    finalNameCString,
+                    &finalNamespaceStat,
+                    AT_SYMLINK_NOFOLLOW) != 0 ||
+            !S_ISREG(finalNamespaceStat.st_mode) ||
+            finalNamespaceStat.st_nlink != 1 ||
+            (finalNamespaceStat.st_mode & 07777) != 0600 ||
+            finalNamespaceStat.st_dev != _workspaceIdentity.st_dev ||
+            !PXBackupArtifactStatIdentityMatches(&finalNamespaceStat,
+                                                &payloadIdentity)) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorFilesystemChanged,
+                                     PXBackupArtifactField,
+                                     @"The finalized artifact identity is invalid");
+            break;
+        }
+        if (!PXBackupArtifactStrictSync(parent.descriptor)) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorDurabilityFailed,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent could not be synchronized");
+            break;
+        }
+        NSArray<NSString *> *remainingEntries = nil;
+        char *temporaryNameCString =
+            PXBackupArtifactCopyCString(temporary.nameData);
+        struct stat temporaryNamespaceStat;
+        BOOL removed = temporaryNameCString &&
+                       PXBackupArtifactDirectoryEntries(temporary.descriptor,
+                                                        1,
+                                                        &remainingEntries) &&
+                       remainingEntries.count == 0 &&
+                       fstatat(parent.descriptor,
+                               temporaryNameCString,
+                               &temporaryNamespaceStat,
+                               AT_SYMLINK_NOFOLLOW) == 0 &&
+                       S_ISDIR(temporaryNamespaceStat.st_mode) &&
+                       PXBackupArtifactStatIdentityMatches(&temporaryNamespaceStat,
+                                                          [temporary identityPointer]) &&
+                       unlinkat(parent.descriptor,
+                                temporaryNameCString,
+                                AT_REMOVEDIR) == 0;
+        free(temporaryNameCString);
+        if (!removed) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorCleanupFailed,
+                                     PXBackupArtifactTemporaryField,
+                                     @"The temporary artifact directory could not be removed safely");
+            break;
+        }
+        temporaryRemoved = YES;
+        if (!PXBackupArtifactStrictSync(parent.descriptor)) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorDurabilityFailed,
+                                     PXBackupArtifactParentField,
+                                     @"The artifact parent could not be synchronized");
+            break;
+        }
+        identityError = nil;
+        if (![self validateIdentityWithError:&identityError] ||
+            ![self validateParentBinding:parent error:&operationError]) {
+            if (!operationError) {
+                PXBackupArtifactSetError(&operationError,
+                                         PXBackupArtifactWriterErrorFilesystemChanged,
+                                         PXBackupArtifactWorkspaceField,
+                                         @"The writer identity changed after finalization");
+            }
+            break;
+        }
+        record = [[PXVerifiedBackupArtifact alloc]
+            initWithRelativePath:relativePath
+                        filePath:finalFilePath
+                            size:streamedBytes
+                          sha256:digestString];
+        if (!record) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorFinalizationFailed,
+                                     PXBackupArtifactField,
+                                     @"The verified artifact record could not be retained");
+            break;
+        }
+    } while (0);
+
+    if (payloadDescriptor >= 0) {
+        close(payloadDescriptor);
+        payloadDescriptor = -1;
+    }
+    if (!record) {
+        BOOL cleanupSucceeded =
+            [self cleanupParent:parent
+                       temporary:temporary
+                  payloadIdentity:payloadIdentityKnown ? &payloadIdentity : NULL
+                     finalNameData:finalNameData
+                      finalRenamed:finalRenamed
+                  temporaryRemoved:temporaryRemoved];
+        if (!cleanupSucceeded) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorCleanupFailed,
+                                     PXBackupArtifactField,
+                                     @"Owned artifact state could not be cleaned safely");
+        }
+        free(finalNameCString);
+        if (error) {
+            *error = operationError ?: [NSError errorWithDomain:PXBackupArtifactWriterErrorDomain
+                                                            code:PXBackupArtifactWriterErrorFinalizationFailed
+                                                        userInfo:@{
+                                                            NSLocalizedDescriptionKey: @"The artifact operation failed",
+                                                            PXBackupArtifactWriterErrorFieldPathKey: PXBackupArtifactField,
+                                                        }];
+        }
+        return nil;
+    }
+    [_acceptedPaths addObject:[relativePath copy]];
+    [_acceptedNormalizedAliases addObject:
+        [relativePath precomposedStringWithCanonicalMapping]];
+    [_acceptedNormalizedAliases addObject:
+        [relativePath decomposedStringWithCanonicalMapping]];
+    _artifactCount += 1;
+    free(finalNameCString);
+    return record;
+}
+
+- (void)dealloc {
+    if (_workspaceDescriptor >= 0) {
+        close(_workspaceDescriptor);
+        _workspaceDescriptor = -1;
+    }
+}
+
+@end
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -13,6 +13,7 @@
 #import "PXBackupArtifactVerifier.h"
 #import "PXBackupArchiveValidator.h"
 #import "PXBackupBundleLock.h"
+#import "PXBackupArtifactWriter.h"
 #import "PXBackupPublicationWorkspace.h"
 #import "PXRestorePlan.h"
 #import "PXAppGroupRestoreTargetPlan.h"
@@ -27,7 +28,6 @@
 #import "common/PXProcessKiller.h"
 #import "common/PXPaths.h"

-#import <CommonCrypto/CommonDigest.h>
 #import <notify.h>

 static NSString * const PXBackupErrorDomain = @"com.hydra.projectx.backup";
@@ -567,62 +567,6 @@
     return [NSString stringWithFormat:@"dataBackupKeychainGroups_%@", bundleID ?: @""];
 }

-static NSData *PXFileSHA256(NSString *path) {
-    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
-    if (!fh) return nil;
-    CC_SHA256_CTX ctx;
-    CC_SHA256_Init(&ctx);
-    for (;;) {
-        @autoreleasepool {
-            NSData *data = [fh readDataOfLength:(1024 * 1024)];
-            if (!data.length) {
-                break;
-            }
-            CC_SHA256_Update(&ctx, data.bytes, (CC_LONG)data.length);
-        }
-    }
-    [fh closeFile];
-    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
-    CC_SHA256_Final(digest, &ctx);
-    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
-}
-
-static NSString *PXHexString(NSData *data) {
-    if (!data.length) return @"";
-    const unsigned char *bytes = data.bytes;
-    NSMutableString *out = [NSMutableString stringWithCapacity:data.length * 2];
-    for (NSUInteger i = 0; i < data.length; i++) {
-        [out appendFormat:@"%02x", bytes[i]];
-    }
-    return out;
-}
-
-static NSDictionary *PXArtifactInfo(NSString *path, NSString *name) {
-    if (!path.length) return nil;
-    NSFileManager *fm = [NSFileManager defaultManager];
-    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
-    NSNumber *size = attrs[NSFileSize];
-    NSData *sha = PXFileSHA256(path);
-    return @{
-        @"name": name ?: path.lastPathComponent ?: @"",
-        @"path": path,
-        @"size": size ?: @0,
-        @"sha256": sha ? PXHexString(sha) : @""
-    };
-}
-
-static unsigned long long PXArtifactsTotalSize(NSArray<NSDictionary *> *artifacts) {
-    unsigned long long total = 0;
-    for (NSDictionary *artifact in artifacts) {
-        if (![artifact isKindOfClass:[NSDictionary class]]) continue;
-        NSNumber *size = artifact[@"size"];
-        if ([size respondsToSelector:@selector(unsignedLongLongValue)]) {
-            total += [size unsignedLongLongValue];
-        }
-    }
-    return total;
-}
-
 static NSArray<NSString *> *PXIncludedOptionNames(PXBackupOptions options) {
     NSMutableArray<NSString *> *out = [NSMutableArray arrayWithObject:@"DataContainer"];
     if (options & PXBackupOptionIncludeAppGroups) [out addObject:@"AppGroups"];
@@ -637,31 +581,6 @@
     if (!(options & PXBackupOptionIncludePreferences)) [out addObject:@"GlobalPreferences"];
     if (!(options & PXBackupOptionIncludeKeychain)) [out addObject:@"Keychain"];
     return out;
-}
-
-static NSString *PXVerifyArtifact(NSString *backupDir, NSDictionary *artifact) {
-    if (!backupDir.length || ![artifact isKindOfClass:[NSDictionary class]]) return @"invalid artifact metadata";
-    NSString *name = [artifact[@"name"] isKindOfClass:[NSString class]] ? artifact[@"name"] : nil;
-    if (!name.length) return @"artifact missing name";
-    NSString *path = [backupDir stringByAppendingPathComponent:name];
-    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
-        return [NSString stringWithFormat:@"artifact missing: %@", name];
-    }
-    NSNumber *expectedSize = artifact[@"size"];
-    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
-    NSNumber *actualSize = attrs[NSFileSize];
-    if ([expectedSize respondsToSelector:@selector(unsignedLongLongValue)] && [actualSize respondsToSelector:@selector(unsignedLongLongValue)] &&
-        [expectedSize unsignedLongLongValue] != [actualSize unsignedLongLongValue]) {
-        return [NSString stringWithFormat:@"artifact size mismatch: %@", name];
-    }
-    NSString *expectedHash = [artifact[@"sha256"] isKindOfClass:[NSString class]] ? artifact[@"sha256"] : nil;
-    if (expectedHash.length) {
-        NSString *actualHash = PXHexString(PXFileSHA256(path));
-        if (actualHash.length && ![actualHash isEqualToString:expectedHash]) {
-            return [NSString stringWithFormat:@"artifact sha256 mismatch: %@", name];
-        }
-    }
-    return nil;
 }

 static BOOL PXContainerUUIDMatchesBundleID(NSFileManager *fm, NSString *baseDir, NSString *uuid, NSString *bundleID) {
@@ -1659,6 +1578,35 @@
             });
             return;
         }
+        NSError *artifactWriterError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXBackupArtifactWriter *artifactWriter =
+            [PXBackupArtifactWriter writerForWorkspace:publicationWorkspace
+                                                 error:&artifactWriterError];
+        if (!artifactWriter) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, artifactWriterError);
+            });
+            return;
+        }
+        NSError *initialArtifactWriterIdentityError = nil;
+        if (![artifactWriter validateIdentityWithError:&initialArtifactWriterIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, initialArtifactWriterIdentityError);
+            });
+            return;
+        }
+        NSMutableArray<PXVerifiedBackupArtifact *> *groupArtifactRecords =
+            [NSMutableArray array];
+        NSMutableArray<PXVerifiedBackupArtifact *> *systemGlobalArtifactRecords =
+            [NSMutableArray array];
+        NSMutableArray<PXVerifiedBackupArtifact *> *sharedDatabaseArtifactRecords =
+            [NSMutableArray array];
+        PXVerifiedBackupArtifact *profileArtifactRecord = nil;
+        PXVerifiedBackupArtifact *globalSafariArtifactRecord = nil;
+        PXVerifiedBackupArtifact *preferencesArtifactRecord = nil;
+        PXVerifiedBackupArtifact *keychainArtifactRecord = nil;
+
         NSString *backupDir = publicationWorkspace.workspacePath;
         NSString *debugBefore = [backupDir stringByAppendingPathComponent:@"debug_before_backup.txt"];
         NSString *debugAfter = [backupDir stringByAppendingPathComponent:@"debug_after_backup.txt"];
@@ -1719,16 +1667,33 @@
         // Ensure target app is not running while archiving.
         [self _killRelatedProcessesForBundleID:bundleID];

-        NSString *dataArchivePath = [backupDir stringByAppendingPathComponent:@"data.tar.gz"];
-        CommandResult *tarRes = [self _tarCreate:tarPath fromDir:dataContainerPath toArchive:dataArchivePath];
-        if (tarRes.exitCode != 0 || ![fm fileExistsAtPath:dataArchivePath]) {
-            NSString *msg = tarRes.stderrString.length ? tarRes.stderrString : @"tar failed for data container";
+        __block CommandResult *dataTarResult = nil;
+        NSError *dataArtifactError = nil;
+        PXVerifiedBackupArtifact *dataArtifactRecord =
+            [artifactWriter writeArtifactAtRelativePath:@"data.tar.gz"
+                                               producer:^BOOL(NSString *temporaryOutputPath) {
+                dataTarResult = [self _tarCreate:tarPath
+                                         fromDir:dataContainerPath
+                                       toArchive:temporaryOutputPath];
+                return dataTarResult && dataTarResult.exitCode == 0;
+            }
+                                                  error:&dataArtifactError];
+        if (!dataArtifactRecord) {
+            NSString *msg = nil;
+            if (!dataTarResult || dataTarResult.exitCode != 0) {
+                msg = dataTarResult.stderrString.length
+                    ? dataTarResult.stderrString
+                    : @"tar failed for data container";
+            } else {
+                msg = @"Failed to create verified data artifact";
+            }
             NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                code:105
                                            userInfo:@{NSLocalizedDescriptionKey: msg}];
             dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
             return;
         }
+        NSString *dataArchivePath = dataArtifactRecord.filePath;

         NSMutableArray<NSDictionary *> *groupManifests = [NSMutableArray array];
         NSArray<AppGroupContainerInfo *> *groupContainers = @[];
@@ -1766,18 +1731,27 @@

         for (AppGroupContainerInfo *info in groupContainers) {
             NSString *archiveName = [NSString stringWithFormat:@"%@.tar.gz", PXSanitizeFilenameComponent(info.groupID)];
-            NSString *archivePath = [groupsDir stringByAppendingPathComponent:archiveName];
-
-            CommandResult *r = [self _tarCreate:tarPath fromDir:info.path toArchive:archivePath];
-            if (r.exitCode != 0 || ![fm fileExistsAtPath:archivePath]) {
+            NSString *relativeArchivePath = [@"groups" stringByAppendingPathComponent:archiveName];
+            __block CommandResult *groupTarResult = nil;
+            NSError *groupArtifactError = nil;
+            PXVerifiedBackupArtifact *groupArtifact =
+                [artifactWriter writeArtifactAtRelativePath:relativeArchivePath
+                                                   producer:^BOOL(NSString *temporaryOutputPath) {
+                    groupTarResult = [self _tarCreate:tarPath
+                                              fromDir:info.path
+                                            toArchive:temporaryOutputPath];
+                    return groupTarResult && groupTarResult.exitCode == 0;
+                }
+                                                      error:&groupArtifactError];
+            if (!groupArtifact) {
                 [warnings addObject:[NSString stringWithFormat:@"Failed to archive group %@ (%@)", info.groupID, info.uuid]];
                 continue;
             }
-
+            [groupArtifactRecords addObject:groupArtifact];
             [groupManifests addObject:@{
                 @"groupID": info.groupID,
                 @"uuid": info.uuid,
-                @"archive": [@"groups" stringByAppendingPathComponent:archiveName]
+                @"archive": groupArtifact.relativePath,
             }];
         }

@@ -1787,11 +1761,21 @@
         if (profileAppDataPath.length) {
             BOOL isDir = NO;
             if ([fm fileExistsAtPath:profileAppDataPath isDirectory:&isDir] && isDir) {
-                profileAppDataArchivePath = [backupDir stringByAppendingPathComponent:@"profile_appdata.tar.gz"];
-                CommandResult *r = [self _tarCreate:tarPath fromDir:profileAppDataPath toArchive:profileAppDataArchivePath];
-                if (r.exitCode != 0 || ![fm fileExistsAtPath:profileAppDataArchivePath]) {
+                __block CommandResult *profileTarResult = nil;
+                NSError *profileArtifactError = nil;
+                profileArtifactRecord =
+                    [artifactWriter writeArtifactAtRelativePath:@"profile_appdata.tar.gz"
+                                                       producer:^BOOL(NSString *temporaryOutputPath) {
+                        profileTarResult = [self _tarCreate:tarPath
+                                                   fromDir:profileAppDataPath
+                                                 toArchive:temporaryOutputPath];
+                        return profileTarResult && profileTarResult.exitCode == 0;
+                    }
+                                                          error:&profileArtifactError];
+                if (!profileArtifactRecord) {
                     [warnings addObject:@"Failed to archive profile appdata; continuing" ];
-                    profileAppDataArchivePath = nil;
+                } else {
+                    profileAppDataArchivePath = profileArtifactRecord.filePath;
                 }
             }
         }
@@ -1804,11 +1788,21 @@
             if (globalSafariPath.length) {
                 BOOL isDir = NO;
                 if ([fm fileExistsAtPath:globalSafariPath isDirectory:&isDir] && isDir) {
-                    globalSafariArchivePath = [backupDir stringByAppendingPathComponent:@"global_safari.tar.gz"];
-                    CommandResult *r = [self _tarCreate:tarPath fromDir:globalSafariPath toArchive:globalSafariArchivePath];
-                    if (r.exitCode != 0 || ![fm fileExistsAtPath:globalSafariArchivePath]) {
+                    __block CommandResult *safariTarResult = nil;
+                    NSError *safariArtifactError = nil;
+                    globalSafariArtifactRecord =
+                        [artifactWriter writeArtifactAtRelativePath:@"global_safari.tar.gz"
+                                                           producer:^BOOL(NSString *temporaryOutputPath) {
+                            safariTarResult = [self _tarCreate:tarPath
+                                                      fromDir:globalSafariPath
+                                                    toArchive:temporaryOutputPath];
+                            return safariTarResult && safariTarResult.exitCode == 0;
+                        }
+                                                              error:&safariArtifactError];
+                    if (!globalSafariArtifactRecord) {
                         [warnings addObject:@"Failed to archive global Safari library; continuing"];
-                        globalSafariArchivePath = nil;
+                    } else {
+                        globalSafariArchivePath = globalSafariArtifactRecord.filePath;
                     }
                 }
             }
@@ -1816,12 +1810,25 @@

         BOOL prefsIncluded = (options & PXBackupOptionIncludePreferences) != 0;
         NSString *prefSourcePath = [self _preferencesPlistPathForBundleID:bundleID];
-        NSString *prefDestPath = [prefsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleID]];
+        NSString *prefDestPath = nil;
         if (prefsIncluded) {
             if ([fm fileExistsAtPath:prefSourcePath]) {
-                NSString *cpCmd = [NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null || true", PXShellQuote(prefSourcePath), PXShellQuote(prefDestPath)];
-                [runner run:cpCmd];
-                [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(prefDestPath)]];
+                NSString *preferencesRelativePath =
+                    [NSString stringWithFormat:@"preferences/%@.plist", bundleID];
+                NSError *preferencesArtifactError = nil;
+                preferencesArtifactRecord =
+                    [artifactWriter writeArtifactAtRelativePath:preferencesRelativePath
+                                                       producer:^BOOL(NSString *temporaryOutputPath) {
+                        NSString *cpCmd = [NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null",
+                            PXShellQuote(prefSourcePath),
+                            PXShellQuote(temporaryOutputPath)];
+                        CommandResult *copyResult = [runner run:cpCmd];
+                        return copyResult && copyResult.exitCode == 0;
+                    }
+                                                          error:&preferencesArtifactError];
+                if (preferencesArtifactRecord) {
+                    prefDestPath = preferencesArtifactRecord.filePath;
+                }
             } else {
                 [warnings addObject:@"Global preferences plist not found (OK for most apps); skipping"];
             }
@@ -1830,10 +1837,9 @@
         // Keychain backup
         BOOL keychainIncluded = (options & PXBackupOptionIncludeKeychain) != 0;
         NSString *keychainBackupPath = nil;
-        NSString *keychainMethod = nil;
+        __block NSString *keychainMethod = nil;
         NSArray<NSString *> *selectedKeychainGroups = @[];
         if (keychainIncluded) {
-            keychainBackupPath = [backupDir stringByAppendingPathComponent:@"keychain.plist"];
             // Default selection: ALL groups from entitlements if no saved preference.
             id saved = [[NSUserDefaults standardUserDefaults] objectForKey:PXBackupKeychainGroupsKey(bundleID)];
             if ([saved isKindOfClass:[NSArray class]] && [(NSArray *)saved count] > 0) {
@@ -1884,40 +1890,52 @@
                 }
             }

-            BOOL keychainSuccess = [self _backupKeychainForBundleID:bundleID
-                                                            groups:selectedKeychainGroups
-                                                            toFile:keychainBackupPath
-                                                          warnings:warnings];
-            if (!keychainSuccess) {
-                keychainBackupPath = nil; // Mark as not included if failed
+            NSError *keychainArtifactError = nil;
+            keychainArtifactRecord =
+                [artifactWriter writeArtifactAtRelativePath:@"keychain.plist"
+                                                   producer:^BOOL(NSString *temporaryOutputPath) {
+                    BOOL keychainSuccess = [self _backupKeychainForBundleID:bundleID
+                                                                    groups:selectedKeychainGroups
+                                                                    toFile:temporaryOutputPath
+                                                                  warnings:warnings];
+                    if (!keychainSuccess) {
+                        return NO;
+                    }
+                    keychainMethod = @"helper";
+                    [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]];
+                    PXDebugHeader(debugKeychain, @"Keychain Backup Result");
+                    PXDebugAppendLine(debugKeychain, @"status=ok");
+                    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"archive=%@", temporaryOutputPath]);
+                    PXDebugRun(runner, debugKeychain, @"ls keychain.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]);
+
+                    // If helper cannot access restricted groups (e.g. *.platformFamily), fallback to in-app export.
+                    NSUInteger count = PXKeychainPlistItemCount(temporaryOutputPath);
+                    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItems=%lu", (unsigned long)count]);
+                    if (count == 0 && PXGroupsContainPlatformFamily(selectedKeychainGroups)) {
+                        PXDebugAppendLine(debugKeychain, @"helper returned 0 items; trying in-app export");
+                        BOOL inAppOK = [self _inAppKeychainBackupForBundleID:bundleID
+                                                               containerPath:dataContainerPath
+                                                                      groups:selectedKeychainGroups
+                                                                      toFile:temporaryOutputPath
+                                                                   debugPath:debugKeychain
+                                                                    warnings:warnings];
+                        if (inAppOK) {
+                            keychainMethod = @"in_app";
+                            [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]];
+                            PXDebugRun(runner, debugKeychain, @"ls keychain.plist (after in-app)", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(temporaryOutputPath)]);
+                            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItemsAfterInApp=%lu", (unsigned long)PXKeychainPlistItemCount(temporaryOutputPath)]);
+                        } else {
+                            PXDebugAppendLine(debugKeychain, @"in-app export failed");
+                        }
+                    }
+                    return YES;
+                }
+                                                      error:&keychainArtifactError];
+            if (keychainArtifactRecord) {
+                keychainBackupPath = keychainArtifactRecord.filePath;
             } else {
-                keychainMethod = @"helper";
-                [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]];
-                PXDebugHeader(debugKeychain, @"Keychain Backup Result");
-                PXDebugAppendLine(debugKeychain, @"status=ok");
-                PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"archive=%@", keychainBackupPath]);
-                PXDebugRun(runner, debugKeychain, @"ls keychain.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]);
-
-                // If helper cannot access restricted groups (e.g. *.platformFamily), fallback to in-app export.
-                NSUInteger count = PXKeychainPlistItemCount(keychainBackupPath);
-                PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItems=%lu", (unsigned long)count]);
-                if (count == 0 && PXGroupsContainPlatformFamily(selectedKeychainGroups)) {
-                    PXDebugAppendLine(debugKeychain, @"helper returned 0 items; trying in-app export");
-                    BOOL inAppOK = [self _inAppKeychainBackupForBundleID:bundleID
-                                                           containerPath:dataContainerPath
-                                                                  groups:selectedKeychainGroups
-                                                                  toFile:keychainBackupPath
-                                                               debugPath:debugKeychain
-                                                                warnings:warnings];
-                    if (inAppOK) {
-                        keychainMethod = @"in_app";
-                        [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]];
-                        PXDebugRun(runner, debugKeychain, @"ls keychain.plist (after in-app)", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]);
-                        PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItemsAfterInApp=%lu", (unsigned long)PXKeychainPlistItemCount(keychainBackupPath)]);
-                    } else {
-                        PXDebugAppendLine(debugKeychain, @"in-app export failed");
-                    }
-                }
+                keychainBackupPath = nil;
+                keychainMethod = nil;
             }
         }

@@ -1938,17 +1956,28 @@
             }

             NSString *archiveName = [NSString stringWithFormat:@"global_library_%@.tar.gz", PXSanitizeFilenameComponent(subdir)];
-            NSString *archivePath = [backupDir stringByAppendingPathComponent:archiveName];
-
             [self _killRelatedProcessesForBundleID:bundleID];
             PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"item=%@ path=%@", subdir, srcPath]);
-            CommandResult *r = [self _tarCreate:tarPath fromDir:srcPath toArchive:archivePath];
-            if (r.exitCode != 0 || ![fm fileExistsAtPath:archivePath]) {
+            __block CommandResult *systemTarResult = nil;
+            NSError *systemArtifactError = nil;
+            PXVerifiedBackupArtifact *systemArtifact =
+                [artifactWriter writeArtifactAtRelativePath:archiveName
+                                                   producer:^BOOL(NSString *temporaryOutputPath) {
+                    systemTarResult = [self _tarCreate:tarPath
+                                               fromDir:srcPath
+                                             toArchive:temporaryOutputPath];
+                    return systemTarResult && systemTarResult.exitCode == 0;
+                }
+                                                      error:&systemArtifactError];
+            if (!systemArtifact) {
                 [warnings addObject:[NSString stringWithFormat:@"Failed to archive system global library %@; continuing", subdir]];
                 continue;
             }
-
-            [systemGlobalManifests addObject:@{ @"subdir": subdir, @"archive": archiveName }];
+            [systemGlobalArtifactRecords addObject:systemArtifact];
+            [systemGlobalManifests addObject:@{
+                @"subdir": subdir,
+                @"archive": systemArtifact.relativePath,
+            }];
         }

         // Shared system DBs: back up for system apps (can impact multiple apps).
@@ -1973,7 +2002,6 @@
                         continue;
                     }
                     NSString *dstRel = [@"shared_db" stringByAppendingPathComponent:bn];
-                    NSString *dst = [backupDir stringByAppendingPathComponent:dstRel];

                     // Best-effort stop associated daemons first.
                     [self _killRelatedProcessesForBundleID:bundleID];
@@ -1984,10 +2012,23 @@
                     [NSThread sleepForTimeInterval:0.15];

                     PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"copy %@ -> %@", src, dstRel]);
-                    [runner run:[NSString stringWithFormat:@"cp -a %@ %@ 2>/dev/null || true", PXShellQuote(src), PXShellQuote(dst)]];
-                    [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(dst)]];
-                    if ([fm fileExistsAtPath:dst]) {
-                        [sharedSystemDBFiles addObject:@{ @"libraryRel": rel, @"archive": dstRel }];
+                    NSError *sharedArtifactError = nil;
+                    PXVerifiedBackupArtifact *sharedArtifact =
+                        [artifactWriter writeArtifactAtRelativePath:dstRel
+                                                           producer:^BOOL(NSString *temporaryOutputPath) {
+                            NSString *copyCommand = [NSString stringWithFormat:@"cp -a %@ %@ 2>/dev/null",
+                                PXShellQuote(src),
+                                PXShellQuote(temporaryOutputPath)];
+                            CommandResult *copyResult = [runner run:copyCommand];
+                            return copyResult && copyResult.exitCode == 0;
+                        }
+                                                              error:&sharedArtifactError];
+                    if (sharedArtifact) {
+                        [sharedDatabaseArtifactRecords addObject:sharedArtifact];
+                        [sharedSystemDBFiles addObject:@{
+                            @"libraryRel": rel,
+                            @"archive": sharedArtifact.relativePath,
+                        }];
                     }
                 }
             }
@@ -2003,54 +2044,37 @@
         NSString *iosVersion = device.systemVersion ?: @"";
         // profileId already computed above

-        NSMutableArray *artifacts = [NSMutableArray array];
-        NSDictionary *dataArtifact = PXArtifactInfo(dataArchivePath, @"data.tar.gz");
-        if (dataArtifact) [artifacts addObject:dataArtifact];
-        for (NSDictionary *g in groupManifests) {
-            NSString *rel = g[@"archive"]; // groups/<name>.tar.gz
-            if ([rel isKindOfClass:[NSString class]]) {
-                NSString *abs = [backupDir stringByAppendingPathComponent:(NSString *)rel];
-                NSDictionary *gi = PXArtifactInfo(abs, rel);
-                if (gi) [artifacts addObject:gi];
-            }
-        }
-        if (profileAppDataArchivePath) {
-            NSDictionary *a = PXArtifactInfo(profileAppDataArchivePath, @"profile_appdata.tar.gz");
-            if (a) [artifacts addObject:a];
-        }
-        if (globalSafariArchivePath) {
-            NSDictionary *a = PXArtifactInfo(globalSafariArchivePath, @"global_safari.tar.gz");
-            if (a) [artifacts addObject:a];
-        }
-        for (NSDictionary *g in systemGlobalManifests) {
-            NSString *rel = g[@"archive"]; // global_library_*.tar.gz
-            if ([rel isKindOfClass:[NSString class]] && rel.length) {
-                NSString *abs = [backupDir stringByAppendingPathComponent:(NSString *)rel];
-                NSDictionary *gi = PXArtifactInfo(abs, rel);
-                if (gi) [artifacts addObject:gi];
-            }
-        }
-        for (NSDictionary *d in sharedSystemDBFiles) {
-            NSString *rel = [d[@"archive"] isKindOfClass:[NSString class]] ? d[@"archive"] : nil;
-            if (!rel.length) continue;
-            NSString *abs = [backupDir stringByAppendingPathComponent:rel];
-            NSDictionary *di = PXArtifactInfo(abs, rel);
-            if (di) [artifacts addObject:di];
-        }
-        if (prefDestPath && [[NSFileManager defaultManager] fileExistsAtPath:prefDestPath]) {
-            NSDictionary *a = PXArtifactInfo(prefDestPath, [NSString stringWithFormat:@"preferences/%@.plist", bundleID]);
-            if (a) [artifacts addObject:a];
-        }
-        if (keychainBackupPath && [[NSFileManager defaultManager] fileExistsAtPath:keychainBackupPath]) {
-            NSDictionary *a = PXArtifactInfo(keychainBackupPath, @"keychain.plist");
-            if (a) [artifacts addObject:a];
-        }
-
-        for (NSDictionary *artifact in artifacts) {
-            NSString *verifyWarning = PXVerifyArtifact(backupDir, artifact);
-            if (verifyWarning.length) {
-                [warnings addObject:[@"Backup artifact verification: " stringByAppendingString:verifyWarning]];
-            }
+        NSError *preManifestArtifactWriterIdentityError = nil;
+        if (![artifactWriter validateIdentityWithError:&preManifestArtifactWriterIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, preManifestArtifactWriterIdentityError);
+            });
+            return;
+        }
+        NSMutableArray<PXVerifiedBackupArtifact *> *verifiedArtifactRecords =
+            [NSMutableArray array];
+        [verifiedArtifactRecords addObject:dataArtifactRecord];
+        [verifiedArtifactRecords addObjectsFromArray:groupArtifactRecords];
+        if (profileArtifactRecord) [verifiedArtifactRecords addObject:profileArtifactRecord];
+        if (globalSafariArtifactRecord) [verifiedArtifactRecords addObject:globalSafariArtifactRecord];
+        [verifiedArtifactRecords addObjectsFromArray:systemGlobalArtifactRecords];
+        [verifiedArtifactRecords addObjectsFromArray:sharedDatabaseArtifactRecords];
+        if (preferencesArtifactRecord) [verifiedArtifactRecords addObject:preferencesArtifactRecord];
+        if (keychainArtifactRecord) [verifiedArtifactRecords addObject:keychainArtifactRecord];
+
+        NSMutableArray<NSDictionary<NSString *, id> *> *artifacts =
+            [NSMutableArray arrayWithCapacity:verifiedArtifactRecords.count];
+        unsigned long long totalArtifactSize = 0;
+        for (PXVerifiedBackupArtifact *artifactRecord in verifiedArtifactRecords) {
+            if (totalArtifactSize > ULLONG_MAX - artifactRecord.size) {
+                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                                   code:105
+                                               userInfo:@{NSLocalizedDescriptionKey: @"Backup artifact size overflow"}];
+                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                return;
+            }
+            totalArtifactSize += artifactRecord.size;
+            [artifacts addObject:artifactRecord.manifestRepresentation];
         }

         NSString *toolVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
@@ -2062,8 +2086,6 @@
         if (systemGlobalManifests.count || sharedSystemDBFiles.count) {
             [restoreNotes addObject:@"This backup includes system/global data that may affect more than one app."];
         }
-
-        unsigned long long totalArtifactSize = PXArtifactsTotalSize(artifacts);

         NSDictionary *manifest = @{
             @"manifestVersion": @3,
@@ -2080,9 +2102,9 @@
             @"sourceDataContainerUUID": dataUUID ?: @"",
             @"includedOptions": PXIncludedOptionNames(options),
             @"excludedOptions": PXExcludedOptionNames(options),
-            @"artifactCount": @(artifacts.count),
+            @"artifactCount": @(verifiedArtifactRecords.count),
             @"totalSize": @(totalArtifactSize),
-            @"archiveChecksum": dataArtifact[@"sha256"] ?: @"",
+            @"archiveChecksum": dataArtifactRecord.sha256 ?: @"",
             @"warnings": [warnings copy],
             @"restoreCompatibility": @{
                 @"targetBundleID": bundleID ?: @"",
@@ -2092,29 +2114,29 @@
             },
             @"data": @{
                 @"uuid": dataUUID,
-                @"archive": @"data.tar.gz",
+                @"archive": dataArtifactRecord.relativePath,
                 @"containerPath": dataContainerPath
             },
             @"applicationGroups": groupIDs ?: @[],
             @"appGroups": groupManifests,
             @"preferences": @{
                 @"included": @(prefsIncluded),
-                @"archive": [NSString stringWithFormat:@"preferences/%@.plist", bundleID]
+                @"archive": preferencesArtifactRecord.relativePath ?: @""
             },
             @"keychain": @{
                 @"included": @(keychainBackupPath != nil),
-                @"archive": keychainBackupPath ? @"keychain.plist" : @"",
+                @"archive": keychainArtifactRecord.relativePath ?: @"",
                 @"groupsSelected": selectedKeychainGroups ?: @[],
                 @"method": keychainMethod ?: @""
             },
             @"profileAppData": @{
                 @"included": @(profileAppDataArchivePath != nil),
-                @"archive": profileAppDataArchivePath ? @"profile_appdata.tar.gz" : @"",
+                @"archive": profileArtifactRecord.relativePath ?: @"",
                 @"path": profileAppDataPath ?: @""
             },
             @"globalSafari": @{
                 @"included": @(globalSafariArchivePath != nil),
-                @"archive": globalSafariArchivePath ? @"global_safari.tar.gz" : @"",
+                @"archive": globalSafariArtifactRecord.relativePath ?: @"",
                 @"path": globalSafariPath ?: @""
             },
             @"systemGlobalLibrary": @{
@@ -2179,6 +2201,13 @@
         if (![bundleLock validateOwnershipWithError:&finalBundleLockValidationError]) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (completion) completion(nil, finalBundleLockValidationError);
+            });
+            return;
+        }
+        NSError *finalArtifactWriterIdentityError = nil;
+        if (![artifactWriter validateIdentityWithError:&finalArtifactWriterIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, finalArtifactWriterIdentityError);
             });
             return;
         }
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
