# TASK-3.5 Implementation Report

## Baseline and exact scope

- Baseline: `339ca0129da1af9a87cd5e3bbca7ffff17085352`.
- Authorized production files: `PXBackupArtifactPolicy.h`, `PXBackupArtifactPolicy.m`, `PXBackupArtifactWriter.h`, `PXBackupArtifactWriter.m`, `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-3.5-REPORT.md`.
- No coordinator document was edited, staged, reverted or included.

### Baseline evidence

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
git rev-parse HEAD
339ca0129da1af9a87cd5e3bbca7ffff17085352
git log -5 --oneline
339ca01 phase3(task-3.4): derive preferences inclusion from verified output
849b282 phase3(task-3.3): add common verified artifact writer
dbfeb65 phase3(task-3.2): add per-bundle backup serialization
2db8d44 phase3(task-3.1): create unique partial backup workspace
0ef0631 phase2(task-2.14A): make restore result mutations assertion independent
git diff --check
PASS
```

## Protected production SHA-256 before/after

- Protected entries: 298.
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

## Pre-task producer-policy inventory

- TASK-3.4 had eight verified-writer sites but no policy argument, no retained record policy and no common disposition helper.
- ApplicationData aborted directly; warning-capable optional artifacts appended warnings directly; silent optional artifacts continued ad hoc.
- Zero-byte payloads were accepted uniformly after stable streaming because no semantic class policy existed.

## Exact four enums

| Enum | Exact values |
|---|---|
| Artifact kind | ApplicationData=1, AppGroup=2, ProfileAppData=3, GlobalSafari=4, SystemGlobal=5, SharedSystemDatabase=6, Preferences=7, Keychain=8 |
| Requirement | Required=1, Optional=2 |
| Failure disposition | AbortBackup=1, WarnAndContinue=2, ContinueWithoutWarning=3 |
| Empty-file policy | Reject=1, Allow=2 |

## Immutable policy model

- One subclassing-restricted `NSObject<NSCopying>` with four readonly properties.
- One factory and one file-size method; `init`/`new` unavailable; no public initializer.
- Factory returns the exact base runtime class; unknown kinds return nil.
- `copyWithZone:` returns self; equality/hash include all four fields.
- Implementation imports only its own header and has no filesystem, process, writer, manager, UI, manifest or dispatch dependency.

## Canonical eight-kind matrix

| Kind | Requirement | Failure disposition | Empty file |
|---|---|---|---|
| ApplicationData | Required | AbortBackup | Reject |
| AppGroup | Optional | WarnAndContinue | Reject |
| ProfileAppData | Optional | WarnAndContinue | Reject |
| GlobalSafari | Optional | WarnAndContinue | Reject |
| SystemGlobal | Optional | WarnAndContinue | Reject |
| SharedSystemDatabase | Optional | ContinueWithoutWarning | Allow |
| Preferences | Optional | ContinueWithoutWarning | Reject |
| Keychain | Optional | ContinueWithoutWarning | Reject |

Shared SQLite database, WAL and SHM snapshots are the only zero-length exception because a stable empty snapshot can be valid. All other semantic classes reject zero length.

## Writer API migration and record binding

- `PXBackupArtifactWriter.h` imports the policy header once and retains error codes 1–16 unchanged; code 17 is `PolicyRejected`.
- The policy-free artifact selector was removed. One policy-aware selector remains.
- Public entry requires an exact runtime policy object and does not infer policy from the relative path.
- Every accepted immutable record retains the exact policy object. Equality/hash include policy; manifest representation remains exactly four keys.

## Policy rejection timing

| Pipeline checkpoint | Relative source position |
|---|---:|
| stable read proof | 13957 |
| policy decision | 15017 |
| file fsync | 15386 |
| renameat | 17760 |
| record construction | 22082 |
| accepted-path insertion | 24132 |
| artifact count | 24395 |

Ordered stable-read → policy → fsync → rename → record → accepted state: **True**.

A rejected output uses code 17, field `$.artifact.policy` and generic description `The artifact output was rejected by policy`. It exposes no size, kind, path, bundle identifier or digest.

## Eight policy constructions and writer bindings

| Producer | Policy variable |
|---|---|
| data.tar.gz | `applicationDataArtifactPolicy` |
| App Group loop | `appGroupArtifactPolicy` |
| profile_appdata.tar.gz | `profileAppDataArtifactPolicy` |
| global_safari.tar.gz | `globalSafariArtifactPolicy` |
| system-global loop | `systemGlobalArtifactPolicy` |
| shared DB loop | `sharedSystemDatabaseArtifactPolicy` |
| Preferences | `preferencesArtifactPolicy` |
| keychain.plist | `keychainArtifactPolicy` |

The eight policies are constructed and matrix-validated immediately after initial writer validation and before output directories, debug files, process kill or producer execution. Construction failure returns code 106 with the exact required description.

## Failure-disposition helper

- Exactly one file-local helper and eight call sites.
- Abort requires a fatal error, appends no warning and returns NO.
- WarnAndContinue requires a nonempty warning, appends it once and returns YES.
- ContinueWithoutWarning requires nil warning/fatal inputs and returns YES without mutation.
- Invalid policy or arguments fail closed with generic code 106. No helper side effect is placed in an assertion.

## Required ApplicationData matrix

| Failure class | Outcome |
|---|---|
| producer/tar | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |
| verification | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |
| zero-size policy | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |
| read | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |
| durability | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |
| finalization | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |
| cleanup | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |
| record retention | Abort Backup, nil result, code 105; tar stderr retained when applicable, otherwise exact generic text |

## Optional warning and silent matrix

| Kind | Writer failure behavior |
|---|---|
| AppGroup | exact per-group warning and continue |
| ProfileAppData | exact profile warning and continue |
| GlobalSafari | exact Safari warning and continue |
| SystemGlobal | exact subdirectory warning and continue |
| SharedSystemDatabase | no per-file warning; retain aggregate warning |
| Preferences | no new writer warning; record nil and included false |
| Keychain | no generic writer warning; existing helper/in-app warnings retained |

## Pre-manifest policy audit

- Runs after final writer identity validation and ordered record assembly, before dictionary conversion, total-size accumulation and manifest write.
- Requires exact canonical matrix, writer/record count equality, 1–4096 records, accepted sizes, nondecreasing kinds, one required ApplicationData first, singleton optional classes and optional status for every non-data record.
- It does not repair, reorder, drop or synthesize records. Failure returns code 106 with `Backup artifact policy invariant failed`.

## Manifest v3 and TASK-3.4 non-regression

- Manifest version remains 3 and artifact dictionaries remain only name/path/size/sha256.
- `artifactCount`, overflow-safe `totalSize` and `archiveChecksum` retain verified-record authority.
- Preferences request telemetry, verified inclusion, nonempty excluded locator and GlobalPreferences reporting remain unchanged.
- No policy/kind/requirement metadata is serialized.

## Warning and Phase-3 non-regression

- Exact warning literals retained: True.
- Debug sequence retained: True (54 calls).
- Lock/workspace/writer factory and validation counts remain 1/4, 1/3 and 1/3.
- Eight synchronous producer sites, temporary protocol, streaming digest, strict durability and one artifact-level rename remain.
- Discovery, Restore, UI, Makefile and Keychain helper/bridge/script files are protected and hash-identical.

## Static gates

| Gate | Result |
|---|---|
| artifact kinds | 8 |
| requirements | 2 |
| failure dispositions | 3 |
| empty-file policies | 2 |
| policy classes/factories/size methods | 1 / 1 / 1 |
| policy readwrite properties | 0 |
| writer error codes | 17 |
| writer code 17 | 1 |
| verified-record policy properties | 1 |
| policy-aware public methods | 1 |
| policy-free manager writer calls | 0 |
| writer policy field definitions | 1 |
| writer acceptsFileSize calls | 1 |
| writer PolicyRejected branches | 1 |
| mkdtemp / renameat | 1 / 1 |
| whole-file reads | 0 |
| manifest policy keys | 0 |
| policyForKind calls | 8 |
| canonical policy arrays | 1 |
| failure helper definitions/calls | 1 / 8 |
| audit helper definitions/calls | 1 / 1 |
| policy-aware semantic sites | 8 |
| writer factory/validations | 1 / 3 |
| lock factory/validations | 1 / 4 |
| workspace factory/validations | 1 / 3 |
| protected changed files | 0 |
| policy frontend | PASS |
| writer frontend/analyzer | PASS |
| manager frontend | PASS |
| manager NS_BLOCK_ASSERTIONS frontend | PASS |
| git diff --check | PASS |

## Explicit scenario matrix

Explicit scenarios: 295.

| # | Scenario | Result | Evidence |
|---:|---|---|---|
| 1 | ApplicationData canonical matrix | PASS | Required / AbortBackup / empty Reject. |
| 2 | ApplicationData positive-size acceptance | PASS | Every positive file size is accepted. |
| 3 | ApplicationData zero-size decision | PASS | Empty policy is Reject. |
| 4 | AppGroup canonical matrix | PASS | Optional / WarnAndContinue / empty Reject. |
| 5 | AppGroup positive-size acceptance | PASS | Every positive file size is accepted. |
| 6 | AppGroup zero-size decision | PASS | Empty policy is Reject. |
| 7 | ProfileAppData canonical matrix | PASS | Optional / WarnAndContinue / empty Reject. |
| 8 | ProfileAppData positive-size acceptance | PASS | Every positive file size is accepted. |
| 9 | ProfileAppData zero-size decision | PASS | Empty policy is Reject. |
| 10 | GlobalSafari canonical matrix | PASS | Optional / WarnAndContinue / empty Reject. |
| 11 | GlobalSafari positive-size acceptance | PASS | Every positive file size is accepted. |
| 12 | GlobalSafari zero-size decision | PASS | Empty policy is Reject. |
| 13 | SystemGlobal canonical matrix | PASS | Optional / WarnAndContinue / empty Reject. |
| 14 | SystemGlobal positive-size acceptance | PASS | Every positive file size is accepted. |
| 15 | SystemGlobal zero-size decision | PASS | Empty policy is Reject. |
| 16 | SharedSystemDatabase canonical matrix | PASS | Optional / ContinueWithoutWarning / empty Allow. |
| 17 | SharedSystemDatabase positive-size acceptance | PASS | Every positive file size is accepted. |
| 18 | SharedSystemDatabase zero-size decision | PASS | Empty policy is Allow. |
| 19 | Preferences canonical matrix | PASS | Optional / ContinueWithoutWarning / empty Reject. |
| 20 | Preferences positive-size acceptance | PASS | Every positive file size is accepted. |
| 21 | Preferences zero-size decision | PASS | Empty policy is Reject. |
| 22 | Keychain canonical matrix | PASS | Optional / ContinueWithoutWarning / empty Reject. |
| 23 | Keychain positive-size acceptance | PASS | Every positive file size is accepted. |
| 24 | Keychain zero-size decision | PASS | Empty policy is Reject. |
| 25 | Unknown kind zero returns nil | PASS | Pure immutable model/source matrix proof. |
| 26 | Unknown kind nine returns nil | PASS | Pure immutable model/source matrix proof. |
| 27 | Unknown large kind returns nil | PASS | Pure immutable model/source matrix proof. |
| 28 | Policy init unavailable | PASS | Pure immutable model/source matrix proof. |
| 29 | Policy new unavailable | PASS | Pure immutable model/source matrix proof. |
| 30 | No public initializer | PASS | Pure immutable model/source matrix proof. |
| 31 | Factory returns exact base class | PASS | Pure immutable model/source matrix proof. |
| 32 | Policy copyWithZone identity | PASS | Pure immutable model/source matrix proof. |
| 33 | Policy equality kind field | PASS | Pure immutable model/source matrix proof. |
| 34 | Policy equality requirement field | PASS | Pure immutable model/source matrix proof. |
| 35 | Policy equality disposition field | PASS | Pure immutable model/source matrix proof. |
| 36 | Policy equality empty field | PASS | Pure immutable model/source matrix proof. |
| 37 | Policy hash all four fields | PASS | Pure immutable model/source matrix proof. |
| 38 | Policy model imports own header only | PASS | Pure immutable model/source matrix proof. |
| 39 | Policy model has no mutable global state | PASS | Pure immutable model/source matrix proof. |
| 40 | Policy public readwrite zero | PASS | Pure immutable model/source matrix proof. |
| 41 | ApplicationData only required kind | PASS | Pure immutable model/source matrix proof. |
| 42 | Seven optional kinds | PASS | Pure immutable model/source matrix proof. |
| 43 | Shared DB only empty allowance | PASS | Pure immutable model/source matrix proof. |
| 44 | Writer nil policy rejected | PASS | Writer source/static pipeline proof. |
| 45 | Writer wrong runtime policy rejected | PASS | Writer source/static pipeline proof. |
| 46 | Writer subclass policy rejected | PASS | Writer source/static pipeline proof. |
| 47 | Writer nil producer rejected | PASS | Writer source/static pipeline proof. |
| 48 | Writer clears nonnull error | PASS | Writer source/static pipeline proof. |
| 49 | Policy invalid field path exact | PASS | Writer source/static pipeline proof. |
| 50 | Policy rejection code 17 | PASS | Writer source/static pipeline proof. |
| 51 | Policy rejection field path exact | PASS | Writer source/static pipeline proof. |
| 52 | Policy rejection generic description exact | PASS | Writer source/static pipeline proof. |
| 53 | Policy error excludes size | PASS | Writer source/static pipeline proof. |
| 54 | Policy error excludes kind | PASS | Writer source/static pipeline proof. |
| 55 | Policy error excludes path | PASS | Writer source/static pipeline proof. |
| 56 | Policy error excludes digest | PASS | Writer source/static pipeline proof. |
| 57 | Policy-aware public method exactly one | PASS | Writer source/static pipeline proof. |
| 58 | Policy-free public method absent | PASS | Writer source/static pipeline proof. |
| 59 | Writer imports policy exactly once | PASS | Writer source/static pipeline proof. |
| 60 | Verified record retains exact policy | PASS | Writer source/static pipeline proof. |
| 61 | Record construction rejects wrong policy class | PASS | Writer source/static pipeline proof. |
| 62 | Record equality includes policy | PASS | Writer source/static pipeline proof. |
| 63 | Record hash includes policy | PASS | Writer source/static pipeline proof. |
| 64 | Record copy returns self | PASS | Writer source/static pipeline proof. |
| 65 | Manifest representation has four keys | PASS | Writer source/static pipeline proof. |
| 66 | Manifest representation excludes policy | PASS | Writer source/static pipeline proof. |
| 67 | Manifest representation excludes kind | PASS | Writer source/static pipeline proof. |
| 68 | Manifest representation excludes requirement | PASS | Writer source/static pipeline proof. |
| 69 | Stable read precedes policy gate | PASS | Writer source/static pipeline proof. |
| 70 | Policy gate precedes file fsync | PASS | Writer source/static pipeline proof. |
| 71 | Policy gate precedes renameat | PASS | Writer source/static pipeline proof. |
| 72 | Policy gate precedes record construction | PASS | Writer source/static pipeline proof. |
| 73 | Policy gate precedes accepted path insertion | PASS | Writer source/static pipeline proof. |
| 74 | Policy gate precedes artifact count increment | PASS | Writer source/static pipeline proof. |
| 75 | Rejected payload gets pre-rename cleanup | PASS | Writer source/static pipeline proof. |
| 76 | Rejected payload gets zero final rename | PASS | Writer source/static pipeline proof. |
| 77 | Rejected payload gets zero record acceptance | PASS | Writer source/static pipeline proof. |
| 78 | Rejected payload leaves artifact count unchanged | PASS | Writer source/static pipeline proof. |
| 79 | Writer retains one mkdtemp site | PASS | Writer source/static pipeline proof. |
| 80 | Writer retains one renameat site | PASS | Writer source/static pipeline proof. |
| 81 | Writer retains 64 KiB streaming | PASS | Writer source/static pipeline proof. |
| 82 | Writer retains 64 GiB bound | PASS | Writer source/static pipeline proof. |
| 83 | Writer has zero whole-file reads | PASS | Writer source/static pipeline proof. |
| 84 | Writer has zero shell/process calls | PASS | Writer source/static pipeline proof. |
| 85 | Writer retains no-follow payload open | PASS | Writer source/static pipeline proof. |
| 86 | Writer retains strict fsync | PASS | Writer source/static pipeline proof. |
| 87 | AbortBackup with fatal error | PASS | return NO and propagate exact fatal error |
| 88 | AbortBackup with nil fatal error | PASS | fail closed with code 106 |
| 89 | AbortBackup with warning | PASS | fail closed with code 106 |
| 90 | WarnAndContinue with valid warning | PASS | append once and return YES |
| 91 | WarnAndContinue with empty warning | PASS | fail closed with code 106 |
| 92 | WarnAndContinue with nil warning | PASS | fail closed with code 106 |
| 93 | WarnAndContinue with fatal error | PASS | fail closed with code 106 |
| 94 | ContinueWithoutWarning with nil values | PASS | return YES without warning |
| 95 | ContinueWithoutWarning with warning | PASS | fail closed with code 106 |
| 96 | ContinueWithoutWarning with fatal error | PASS | fail closed with code 106 |
| 97 | Invalid policy object | PASS | fail closed with code 106 |
| 98 | Unknown disposition defensive path | PASS | fail closed with code 106 |
| 99 | ApplicationData policy construction | PASS | Exactly one policyForKind call retained in `applicationDataArtifactPolicy`. |
| 100 | ApplicationData writer binding | PASS | Writer site `data.tar.gz` passes the exact canonical policy. |
| 101 | ApplicationData writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 102 | AppGroup policy construction | PASS | Exactly one policyForKind call retained in `appGroupArtifactPolicy`. |
| 103 | AppGroup writer binding | PASS | Writer site `groups/<group>.tar.gz` passes the exact canonical policy. |
| 104 | AppGroup writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 105 | ProfileAppData policy construction | PASS | Exactly one policyForKind call retained in `profileAppDataArtifactPolicy`. |
| 106 | ProfileAppData writer binding | PASS | Writer site `profile_appdata.tar.gz` passes the exact canonical policy. |
| 107 | ProfileAppData writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 108 | GlobalSafari policy construction | PASS | Exactly one policyForKind call retained in `globalSafariArtifactPolicy`. |
| 109 | GlobalSafari writer binding | PASS | Writer site `global_safari.tar.gz` passes the exact canonical policy. |
| 110 | GlobalSafari writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 111 | SystemGlobal policy construction | PASS | Exactly one policyForKind call retained in `systemGlobalArtifactPolicy`. |
| 112 | SystemGlobal writer binding | PASS | Writer site `global_library_<subdir>.tar.gz` passes the exact canonical policy. |
| 113 | SystemGlobal writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 114 | SharedSystemDatabase policy construction | PASS | Exactly one policyForKind call retained in `sharedSystemDatabaseArtifactPolicy`. |
| 115 | SharedSystemDatabase writer binding | PASS | Writer site `shared_db/<file>` passes the exact canonical policy. |
| 116 | SharedSystemDatabase writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 117 | Preferences policy construction | PASS | Exactly one policyForKind call retained in `preferencesArtifactPolicy`. |
| 118 | Preferences writer binding | PASS | Writer site `preferences/<bundleID>.plist` passes the exact canonical policy. |
| 119 | Preferences writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 120 | Keychain policy construction | PASS | Exactly one policyForKind call retained in `keychainArtifactPolicy`. |
| 121 | Keychain writer binding | PASS | Writer site `keychain.plist` passes the exact canonical policy. |
| 122 | Keychain writer failure helper binding | PASS | Exactly one failure-disposition helper call owns writer failure. |
| 123 | ApplicationData tar producer missing | PASS | Backup aborts with nil result; manager error remains code 105. |
| 124 | ApplicationData tar exit nonzero | PASS | Backup aborts with nil result; manager error remains code 105. |
| 125 | ApplicationData producer creates no payload | PASS | Backup aborts with nil result; manager error remains code 105. |
| 126 | ApplicationData payload type invalid | PASS | Backup aborts with nil result; manager error remains code 105. |
| 127 | ApplicationData stable read failure | PASS | Backup aborts with nil result; manager error remains code 105. |
| 128 | ApplicationData zero-size policy rejection | PASS | Backup aborts with nil result; manager error remains code 105. |
| 129 | ApplicationData file durability failure | PASS | Backup aborts with nil result; manager error remains code 105. |
| 130 | ApplicationData rename failure | PASS | Backup aborts with nil result; manager error remains code 105. |
| 131 | ApplicationData post-rename identity failure | PASS | Backup aborts with nil result; manager error remains code 105. |
| 132 | ApplicationData temporary cleanup failure | PASS | Backup aborts with nil result; manager error remains code 105. |
| 133 | ApplicationData record construction failure | PASS | Backup aborts with nil result; manager error remains code 105. |
| 134 | ApplicationData tar stderr preserved | PASS | Existing stderr remains the error description when tar failed. |
| 135 | ApplicationData generic verified failure text | PASS | Uses exact `Failed to create verified data artifact`. |
| 136 | No manifest without ApplicationData | PASS | Required record is first and audit requires exactly one. |
| 137 | AppGroup producer failure | PASS | Appends exact warning `Failed to archive group <groupID> (<uuid>)` once and continues. |
| 138 | AppGroup verification failure | PASS | Appends exact warning `Failed to archive group <groupID> (<uuid>)` once and continues. |
| 139 | AppGroup zero-size rejection | PASS | Appends exact warning `Failed to archive group <groupID> (<uuid>)` once and continues. |
| 140 | AppGroup durability failure | PASS | Appends exact warning `Failed to archive group <groupID> (<uuid>)` once and continues. |
| 141 | AppGroup finalization failure | PASS | Appends exact warning `Failed to archive group <groupID> (<uuid>)` once and continues. |
| 142 | ProfileAppData producer failure | PASS | Appends exact warning `Failed to archive profile appdata; continuing` once and continues. |
| 143 | ProfileAppData verification failure | PASS | Appends exact warning `Failed to archive profile appdata; continuing` once and continues. |
| 144 | ProfileAppData zero-size rejection | PASS | Appends exact warning `Failed to archive profile appdata; continuing` once and continues. |
| 145 | ProfileAppData durability failure | PASS | Appends exact warning `Failed to archive profile appdata; continuing` once and continues. |
| 146 | ProfileAppData finalization failure | PASS | Appends exact warning `Failed to archive profile appdata; continuing` once and continues. |
| 147 | GlobalSafari producer failure | PASS | Appends exact warning `Failed to archive global Safari library; continuing` once and continues. |
| 148 | GlobalSafari verification failure | PASS | Appends exact warning `Failed to archive global Safari library; continuing` once and continues. |
| 149 | GlobalSafari zero-size rejection | PASS | Appends exact warning `Failed to archive global Safari library; continuing` once and continues. |
| 150 | GlobalSafari durability failure | PASS | Appends exact warning `Failed to archive global Safari library; continuing` once and continues. |
| 151 | GlobalSafari finalization failure | PASS | Appends exact warning `Failed to archive global Safari library; continuing` once and continues. |
| 152 | SystemGlobal producer failure | PASS | Appends exact warning `Failed to archive system global library <subdir>; continuing` once and continues. |
| 153 | SystemGlobal verification failure | PASS | Appends exact warning `Failed to archive system global library <subdir>; continuing` once and continues. |
| 154 | SystemGlobal zero-size rejection | PASS | Appends exact warning `Failed to archive system global library <subdir>; continuing` once and continues. |
| 155 | SystemGlobal durability failure | PASS | Appends exact warning `Failed to archive system global library <subdir>; continuing` once and continues. |
| 156 | SystemGlobal finalization failure | PASS | Appends exact warning `Failed to archive system global library <subdir>; continuing` once and continues. |
| 157 | SharedSystemDatabase producer failure | PASS | Continues without a new generic writer warning. |
| 158 | SharedSystemDatabase verification failure | PASS | Continues without a new generic writer warning. |
| 159 | SharedSystemDatabase policy rejection | PASS | Continues without a new generic writer warning. |
| 160 | SharedSystemDatabase durability failure | PASS | Continues without a new generic writer warning. |
| 161 | SharedSystemDatabase finalization failure | PASS | Continues without a new generic writer warning. |
| 162 | Preferences producer failure | PASS | Continues without a new generic writer warning. |
| 163 | Preferences verification failure | PASS | Continues without a new generic writer warning. |
| 164 | Preferences policy rejection | PASS | Continues without a new generic writer warning. |
| 165 | Preferences durability failure | PASS | Continues without a new generic writer warning. |
| 166 | Preferences finalization failure | PASS | Continues without a new generic writer warning. |
| 167 | Keychain producer failure | PASS | Continues without a new generic writer warning. |
| 168 | Keychain verification failure | PASS | Continues without a new generic writer warning. |
| 169 | Keychain policy rejection | PASS | Continues without a new generic writer warning. |
| 170 | Keychain durability failure | PASS | Continues without a new generic writer warning. |
| 171 | Keychain finalization failure | PASS | Continues without a new generic writer warning. |
| 172 | Preferences source missing | PASS | Keeps exact existing source-missing warning; not a writer-policy warning. |
| 173 | Preferences writer failure inclusion | PASS | Verified record remains nil and `preferences.included` remains false. |
| 174 | Keychain writer failure state | PASS | Record, path and method remain nil; helper/in-app warnings are preserved. |
| 175 | Shared DB aggregate warning when none | PASS | Existing no-files aggregate warning remains. |
| 176 | Shared DB aggregate warning when included | PASS | Existing included-files aggregate warning remains. |
| 177 | Shared DB zero-byte accepted | PASS | Allow policy permits verified empty SQLite/sidecar snapshots. |
| 178 | Audit exact canonical policy count | PASS | requires exactly eight |
| 179 | Audit exact kind order | PASS | requires kinds 1 through 8 |
| 180 | Audit exact policy matrix | PASS | rechecks all four fields |
| 181 | Audit writer count equality | PASS | writer.artifactCount equals record count |
| 182 | Audit minimum record count | PASS | requires at least one |
| 183 | Audit maximum record count | PASS | limits to 4096 |
| 184 | Audit record runtime class | PASS | requires exact verified record class |
| 185 | Audit retained policy runtime class | PASS | requires exact policy class |
| 186 | Audit retained policy pointer | PASS | requires canonical object identity |
| 187 | Audit retained policy equality | PASS | requires all matrix fields equal |
| 188 | Audit retained file-size policy | PASS | rejects size not accepted by retained policy |
| 189 | Audit nondecreasing kind order | PASS | rejects reordered records |
| 190 | Audit exactly one ApplicationData | PASS | rejects absent or duplicate data records |
| 191 | Audit exactly one required total | PASS | rejects extra required records |
| 192 | Audit required record first | PASS | first record must be required ApplicationData |
| 193 | Audit profile singleton | PASS | at most one profile record |
| 194 | Audit Safari singleton | PASS | at most one Safari record |
| 195 | Audit Preferences singleton | PASS | at most one Preferences record |
| 196 | Audit Keychain singleton | PASS | at most one Keychain record |
| 197 | Audit AppGroup multiplicity | PASS | multiple group records allowed |
| 198 | Audit SystemGlobal multiplicity | PASS | multiple system records allowed |
| 199 | Audit Shared DB multiplicity | PASS | multiple shared records allowed |
| 200 | Audit non-data optional rule | PASS | all non-data records are optional |
| 201 | Audit failure no repair | PASS | does not reorder/drop/synthesize records |
| 202 | Audit placement before dictionary conversion | PASS | call precedes artifact dictionaries |
| 203 | Audit placement before total size | PASS | call precedes overflow-safe sum |
| 204 | Audit placement before manifest write | PASS | call precedes writeToFile |
| 205 | Preferences raw request telemetry retained | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 206 | Preferences inclusion derives from verified record | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 207 | Excluded Preferences locator remains nonempty | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 208 | GlobalPreferences option reporting uses inclusion | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 209 | Preferences record insertion remains conditional | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 210 | Policy-rejected Preferences absent from artifacts | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 211 | Policy-rejected Preferences absent from artifactCount | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 212 | Policy-rejected Preferences absent from totalSize | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 213 | Manifest version remains 3 | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 214 | Manifest root field set retained | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 215 | Artifact declaration remains name/path/size/sha256 | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 216 | Artifact count from verified records | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 217 | Total size remains overflow-safe | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 218 | Archive checksum from data record | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 219 | Manifest writeToFile atomically retained | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 220 | No policy metadata in manifest | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 221 | No manifest v4 | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 222 | No final Backup publication rename | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 223 | Partial workspace result retained | PASS | Manifest/TASK-3.4 source non-regression proof. |
| 224 | TASK-3.1 workspace factory retained | PASS | Static hash/source/order gate. |
| 225 | TASK-3.1 three workspace validations retained | PASS | Static hash/source/order gate. |
| 226 | TASK-3.1 partial discovery exclusion unchanged | PASS | Static hash/source/order gate. |
| 227 | TASK-3.2 lock factory retained | PASS | Static hash/source/order gate. |
| 228 | TASK-3.2 four lock validations retained | PASS | Static hash/source/order gate. |
| 229 | TASK-3.2 lock lifetime retained | PASS | Static hash/source/order gate. |
| 230 | TASK-3.3 writer factory retained | PASS | Static hash/source/order gate. |
| 231 | TASK-3.3 three writer validations retained | PASS | Static hash/source/order gate. |
| 232 | TASK-3.3 eight synchronous producer sites retained | PASS | Static hash/source/order gate. |
| 233 | TASK-3.3 temporary prefix retained | PASS | Static hash/source/order gate. |
| 234 | TASK-3.3 payload protocol retained | PASS | Static hash/source/order gate. |
| 235 | TASK-3.3 streaming digest retained | PASS | Static hash/source/order gate. |
| 236 | TASK-3.3 strict durability retained | PASS | Static hash/source/order gate. |
| 237 | TASK-3.3 one artifact renameat retained | PASS | Static hash/source/order gate. |
| 238 | Legacy PXFileSHA256 absent | PASS | Static hash/source/order gate. |
| 239 | Legacy PXHexString absent | PASS | Static hash/source/order gate. |
| 240 | Legacy PXArtifactInfo absent | PASS | Static hash/source/order gate. |
| 241 | Legacy PXVerifyArtifact absent | PASS | Static hash/source/order gate. |
| 242 | Post-hoc verification warning absent | PASS | Static hash/source/order gate. |
| 243 | Public Backup selector unchanged | PASS | Static hash/source/order gate. |
| 244 | Timestamp generation unchanged | PASS | Static hash/source/order gate. |
| 245 | Tar preference unchanged | PASS | Static hash/source/order gate. |
| 246 | Source-container resolution unchanged | PASS | Static hash/source/order gate. |
| 247 | Process-kill ordering unchanged | PASS | Static hash/source/order gate. |
| 248 | Relative artifact paths unchanged | PASS | Static hash/source/order gate. |
| 249 | Keychain groups/fallback unchanged | PASS | Static hash/source/order gate. |
| 250 | Shared DB source specs unchanged | PASS | Static hash/source/order gate. |
| 251 | Restore body unchanged | PASS | Static hash/source/order gate. |
| 252 | Discovery body unchanged | PASS | Static hash/source/order gate. |
| 253 | UI source unchanged | PASS | Static hash/source/order gate. |
| 254 | Makefile unchanged | PASS | Static hash/source/order gate. |
| 255 | No TASK-3.6 work | PASS | Static hash/source/order gate. |
| 256 | Kind 1 size 0 policy decision | PASS | acceptsFileSize returns False. |
| 257 | Kind 1 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 258 | Kind 1 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 259 | Kind 1 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 260 | Kind 2 size 0 policy decision | PASS | acceptsFileSize returns False. |
| 261 | Kind 2 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 262 | Kind 2 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 263 | Kind 2 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 264 | Kind 3 size 0 policy decision | PASS | acceptsFileSize returns False. |
| 265 | Kind 3 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 266 | Kind 3 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 267 | Kind 3 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 268 | Kind 4 size 0 policy decision | PASS | acceptsFileSize returns False. |
| 269 | Kind 4 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 270 | Kind 4 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 271 | Kind 4 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 272 | Kind 5 size 0 policy decision | PASS | acceptsFileSize returns False. |
| 273 | Kind 5 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 274 | Kind 5 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 275 | Kind 5 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 276 | Kind 6 size 0 policy decision | PASS | acceptsFileSize returns True. |
| 277 | Kind 6 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 278 | Kind 6 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 279 | Kind 6 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 280 | Kind 7 size 0 policy decision | PASS | acceptsFileSize returns False. |
| 281 | Kind 7 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 282 | Kind 7 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 283 | Kind 7 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 284 | Kind 8 size 0 policy decision | PASS | acceptsFileSize returns False. |
| 285 | Kind 8 size 1 policy decision | PASS | acceptsFileSize returns True. |
| 286 | Kind 8 size 65536 policy decision | PASS | acceptsFileSize returns True. |
| 287 | Kind 8 size 1048576 policy decision | PASS | acceptsFileSize returns True. |
| 288 | Canonical audit sequence [1] | PASS | Nondecreasing canonical order with one required first record. |
| 289 | Canonical audit sequence [1, 2] | PASS | Nondecreasing canonical order with one required first record. |
| 290 | Canonical audit sequence [1, 2, 2, 3, 4, 5, 6, 6, 7, 8] | PASS | Nondecreasing canonical order with one required first record. |
| 291 | Canonical audit sequence [1, 6] | PASS | Nondecreasing canonical order with one required first record. |
| 292 | Canonical audit sequence [1, 5, 6, 7] | PASS | Nondecreasing canonical order with one required first record. |
| 293 | Canonical audit sequence [1, 8] | PASS | Nondecreasing canonical order with one required first record. |
| 294 | Canonical audit sequence [1, 3, 4] | PASS | Nondecreasing canonical order with one required first record. |
| 295 | Canonical audit sequence [1, 2, 5, 6, 8] | PASS | Nondecreasing canonical order with one required first record. |

## Whitespace, CRLF and NUL audit

- `PXBackupArtifactPolicy.h`: bytes=1648, CRLF=0, bare LF=49, NUL=0, final newline=True.
- `PXBackupArtifactPolicy.m`: bytes=4536, CRLF=0, bare LF=119, NUL=0, final newline=True.
- `PXBackupArtifactWriter.h`: bytes=2948, CRLF=0, bare LF=71, NUL=0, final newline=True.
- `PXBackupArtifactWriter.m`: bytes=83333, CRLF=0, bare LF=1889, NUL=0, final newline=True.
- `AppDataBackupManager.m`: bytes=218803, CRLF=0, bare LF=4133, NUL=0, final newline=True.
- Authorized production diff check: PASS.

## Build status and remaining runtime risks

- Strict Objective-C frontends passed for policy, writer/analyzer, manager integration and the assertion-disabled manager configuration.
- This Windows workspace lacks Theos, Apple clang and xcrun, so linked iOS target validation and device fault injection remain pending in GitHub Actions.
- Remaining risks are target-runtime filesystem durability behavior and real producer fault timing; no source-level gate currently contradicts the implementation.

## Full authorized production diff

```diff
--- a/PXBackupArtifactPolicy.h
+++ b/PXBackupArtifactPolicy.h
@@ -0,0 +1,49 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+typedef NS_ENUM(NSUInteger, PXBackupArtifactKind) {
+    PXBackupArtifactKindApplicationData = 1,
+    PXBackupArtifactKindAppGroup = 2,
+    PXBackupArtifactKindProfileAppData = 3,
+    PXBackupArtifactKindGlobalSafari = 4,
+    PXBackupArtifactKindSystemGlobal = 5,
+    PXBackupArtifactKindSharedSystemDatabase = 6,
+    PXBackupArtifactKindPreferences = 7,
+    PXBackupArtifactKindKeychain = 8,
+};
+
+typedef NS_ENUM(NSUInteger, PXBackupArtifactRequirement) {
+    PXBackupArtifactRequirementRequired = 1,
+    PXBackupArtifactRequirementOptional = 2,
+};
+
+typedef NS_ENUM(NSUInteger, PXBackupArtifactFailureDisposition) {
+    PXBackupArtifactFailureDispositionAbortBackup = 1,
+    PXBackupArtifactFailureDispositionWarnAndContinue = 2,
+    PXBackupArtifactFailureDispositionContinueWithoutWarning = 3,
+};
+
+typedef NS_ENUM(NSUInteger, PXBackupArtifactEmptyFilePolicy) {
+    PXBackupArtifactEmptyFilePolicyReject = 1,
+    PXBackupArtifactEmptyFilePolicyAllow = 2,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupArtifactPolicy : NSObject <NSCopying>
+
+@property (nonatomic, readonly) PXBackupArtifactKind kind;
+@property (nonatomic, readonly) PXBackupArtifactRequirement requirement;
+@property (nonatomic, readonly) PXBackupArtifactFailureDisposition failureDisposition;
+@property (nonatomic, readonly) PXBackupArtifactEmptyFilePolicy emptyFilePolicy;
+
++ (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind;
+
+- (BOOL)acceptsFileSize:(unsigned long long)fileSize;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
--- a/PXBackupArtifactPolicy.m
+++ b/PXBackupArtifactPolicy.m
@@ -0,0 +1,119 @@
+#import "PXBackupArtifactPolicy.h"
+
+@interface PXBackupArtifactPolicy ()
+
+- (instancetype)initWithKind:(PXBackupArtifactKind)kind
+                 requirement:(PXBackupArtifactRequirement)requirement
+          failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
+             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy;
+
+@end
+
+@implementation PXBackupArtifactPolicy {
+    PXBackupArtifactKind _kind;
+    PXBackupArtifactRequirement _requirement;
+    PXBackupArtifactFailureDisposition _failureDisposition;
+    PXBackupArtifactEmptyFilePolicy _emptyFilePolicy;
+}
+
++ (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind {
+    PXBackupArtifactRequirement requirement = PXBackupArtifactRequirementOptional;
+    PXBackupArtifactFailureDisposition failureDisposition =
+        PXBackupArtifactFailureDispositionContinueWithoutWarning;
+    PXBackupArtifactEmptyFilePolicy emptyFilePolicy =
+        PXBackupArtifactEmptyFilePolicyReject;
+
+    switch (kind) {
+        case PXBackupArtifactKindApplicationData:
+            requirement = PXBackupArtifactRequirementRequired;
+            failureDisposition = PXBackupArtifactFailureDispositionAbortBackup;
+            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
+            break;
+        case PXBackupArtifactKindAppGroup:
+        case PXBackupArtifactKindProfileAppData:
+        case PXBackupArtifactKindGlobalSafari:
+        case PXBackupArtifactKindSystemGlobal:
+            requirement = PXBackupArtifactRequirementOptional;
+            failureDisposition = PXBackupArtifactFailureDispositionWarnAndContinue;
+            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
+            break;
+        case PXBackupArtifactKindSharedSystemDatabase:
+            requirement = PXBackupArtifactRequirementOptional;
+            failureDisposition =
+                PXBackupArtifactFailureDispositionContinueWithoutWarning;
+            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyAllow;
+            break;
+        case PXBackupArtifactKindPreferences:
+        case PXBackupArtifactKindKeychain:
+            requirement = PXBackupArtifactRequirementOptional;
+            failureDisposition =
+                PXBackupArtifactFailureDispositionContinueWithoutWarning;
+            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
+            break;
+        default:
+            return nil;
+    }
+
+    return [[PXBackupArtifactPolicy alloc] initWithKind:kind
+                         requirement:requirement
+                  failureDisposition:failureDisposition
+                     emptyFilePolicy:emptyFilePolicy];
+}
+
+- (instancetype)initWithKind:(PXBackupArtifactKind)kind
+                 requirement:(PXBackupArtifactRequirement)requirement
+          failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
+             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy {
+    self = [super init];
+    if (self) {
+        _kind = kind;
+        _requirement = requirement;
+        _failureDisposition = failureDisposition;
+        _emptyFilePolicy = emptyFilePolicy;
+    }
+    return self;
+}
+
+- (PXBackupArtifactKind)kind { return _kind; }
+- (PXBackupArtifactRequirement)requirement { return _requirement; }
+- (PXBackupArtifactFailureDisposition)failureDisposition {
+    return _failureDisposition;
+}
+- (PXBackupArtifactEmptyFilePolicy)emptyFilePolicy { return _emptyFilePolicy; }
+
+- (BOOL)acceptsFileSize:(unsigned long long)fileSize {
+    return fileSize > 0 ||
+           self.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyAllow;
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
+    if (![object isKindOfClass:[PXBackupArtifactPolicy class]]) {
+        return NO;
+    }
+    PXBackupArtifactPolicy *other = object;
+    return self.kind == other.kind &&
+           self.requirement == other.requirement &&
+           self.failureDisposition == other.failureDisposition &&
+           self.emptyFilePolicy == other.emptyFilePolicy;
+}
+
+- (NSUInteger)hash {
+    NSUInteger value = (NSUInteger)self.kind;
+    value ^= (NSUInteger)self.requirement + (NSUInteger)0x9e3779b9 +
+             (value << 6) + (value >> 2);
+    value ^= (NSUInteger)self.failureDisposition + (NSUInteger)0x9e3779b9 +
+             (value << 6) + (value >> 2);
+    value ^= (NSUInteger)self.emptyFilePolicy + (NSUInteger)0x9e3779b9 +
+             (value << 6) + (value >> 2);
+    return value;
+}
+
+@end
--- a/PXBackupArtifactWriter.h
+++ b/PXBackupArtifactWriter.h
@@ -1,4 +1,5 @@
 #import <Foundation/Foundation.h>
+#import "PXBackupArtifactPolicy.h"

 NS_ASSUME_NONNULL_BEGIN

@@ -26,6 +27,7 @@
     PXBackupArtifactWriterErrorDurabilityFailed = 14,
     PXBackupArtifactWriterErrorFinalizationFailed = 15,
     PXBackupArtifactWriterErrorCleanupFailed = 16,
+    PXBackupArtifactWriterErrorPolicyRejected = 17,
 };

 typedef BOOL (^PXBackupArtifactProducer)(NSString *temporaryOutputPath);
@@ -37,6 +39,7 @@
 @property (nonatomic, copy, readonly) NSString *filePath;
 @property (nonatomic, readonly) unsigned long long size;
 @property (nonatomic, copy, readonly) NSString *sha256;
+@property (nonatomic, strong, readonly) PXBackupArtifactPolicy *policy;
 @property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *manifestRepresentation;

 - (instancetype)init NS_UNAVAILABLE;
@@ -54,6 +57,7 @@
                                       error:(NSError **)error;

 - (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
+                                                            policy:(PXBackupArtifactPolicy *)policy
                                                           producer:(PXBackupArtifactProducer)producer
                                                              error:(NSError **)error;

--- a/PXBackupArtifactWriter.m
+++ b/PXBackupArtifactWriter.m
@@ -26,6 +26,7 @@
 static NSString * const PXBackupArtifactParentField = @"$.artifact.parent";
 static NSString * const PXBackupArtifactTemporaryField = @"$.artifact.temporary";
 static NSString * const PXBackupArtifactPayloadField = @"$.artifact.payload";
+static NSString * const PXBackupArtifactPolicyField = @"$.artifact.policy";

 static const NSUInteger PXBackupArtifactMaximumArtifacts = 4096;
 static const NSUInteger PXBackupArtifactMaximumRelativePathBytes = 4096;
@@ -589,7 +590,8 @@
 - (instancetype)initWithRelativePath:(NSString *)relativePath
                             filePath:(NSString *)filePath
                                 size:(unsigned long long)size
-                              sha256:(NSString *)sha256;
+                              sha256:(NSString *)sha256
+                              policy:(PXBackupArtifactPolicy *)policy;

 @end

@@ -598,19 +600,25 @@
     NSString *_filePath;
     unsigned long long _size;
     NSString *_sha256;
+    PXBackupArtifactPolicy *_policy;
     NSDictionary<NSString *, id> *_manifestRepresentation;
 }

 - (instancetype)initWithRelativePath:(NSString *)relativePath
                             filePath:(NSString *)filePath
                                 size:(unsigned long long)size
-                              sha256:(NSString *)sha256 {
+                              sha256:(NSString *)sha256
+                              policy:(PXBackupArtifactPolicy *)policy {
+    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]]) {
+        return nil;
+    }
     self = [super init];
     if (self) {
         _relativePath = [relativePath copy];
         _filePath = [filePath copy];
         _size = size;
         _sha256 = [sha256 copy];
+        _policy = policy;
         _manifestRepresentation = @{
             @"name": _relativePath,
             @"path": _filePath,
@@ -625,6 +633,7 @@
 - (NSString *)filePath { return _filePath; }
 - (unsigned long long)size { return _size; }
 - (NSString *)sha256 { return _sha256; }
+- (PXBackupArtifactPolicy *)policy { return _policy; }
 - (NSDictionary<NSString *,id> *)manifestRepresentation {
     return _manifestRepresentation;
 }
@@ -645,7 +654,8 @@
     return self.size == other.size &&
            [self.relativePath isEqualToString:other.relativePath] &&
            [self.filePath isEqualToString:other.filePath] &&
-           [self.sha256 isEqualToString:other.sha256];
+           [self.sha256 isEqualToString:other.sha256] &&
+           [self.policy isEqual:other.policy];
 }

 - (NSUInteger)hash {
@@ -653,6 +663,7 @@
     value ^= self.filePath.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
     value ^= (NSUInteger)self.size + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
     value ^= self.sha256.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
+    value ^= self.policy.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
     return value;
 }

@@ -1384,10 +1395,18 @@
 }

 - (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
+                                                            policy:(PXBackupArtifactPolicy *)policy
                                                           producer:(PXBackupArtifactProducer)producer
                                                              error:(NSError **)error {
     if (error) {
         *error = nil;
+    }
+    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]]) {
+        PXBackupArtifactSetError(error,
+                                 PXBackupArtifactWriterErrorInvalidInput,
+                                 PXBackupArtifactPolicyField,
+                                 @"The artifact policy is invalid");
+        return nil;
     }
     if (!producer) {
         PXBackupArtifactSetError(error,
@@ -1674,6 +1693,13 @@
                                      @"The artifact digest could not be finalized");
             break;
         }
+        if (![policy acceptsFileSize:streamedBytes]) {
+            PXBackupArtifactSetError(&operationError,
+                                     PXBackupArtifactWriterErrorPolicyRejected,
+                                     PXBackupArtifactPolicyField,
+                                     @"The artifact output was rejected by policy");
+            break;
+        }
         if (!PXBackupArtifactStrictSync(payloadDescriptor)) {
             PXBackupArtifactSetError(&operationError,
                                      PXBackupArtifactWriterErrorDurabilityFailed,
@@ -1803,7 +1829,8 @@
             initWithRelativePath:relativePath
                         filePath:finalFilePath
                             size:streamedBytes
-                          sha256:digestString];
+                          sha256:digestString
+                          policy:policy];
         if (!record) {
             PXBackupArtifactSetError(&operationError,
                                      PXBackupArtifactWriterErrorFinalizationFailed,
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -583,6 +583,194 @@
     if (!preferencesIncluded) [out addObject:@"GlobalPreferences"];
     if (!(options & PXBackupOptionIncludeKeychain)) [out addObject:@"Keychain"];
     return out;
+}
+
+static NSError *PXBackupArtifactPolicyManagerError(NSString *description) {
+    return [NSError errorWithDomain:PXBackupErrorDomain
+                               code:106
+                           userInfo:@{
+                               NSLocalizedDescriptionKey: description,
+                           }];
+}
+
+static BOOL PXBackupArtifactPolicyMatchesCanonicalKind(
+    PXBackupArtifactPolicy *policy,
+    PXBackupArtifactKind expectedKind) {
+    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]] ||
+        policy.kind != expectedKind) {
+        return NO;
+    }
+    switch (expectedKind) {
+        case PXBackupArtifactKindApplicationData:
+            return policy.requirement == PXBackupArtifactRequirementRequired &&
+                   policy.failureDisposition ==
+                       PXBackupArtifactFailureDispositionAbortBackup &&
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject;
+        case PXBackupArtifactKindAppGroup:
+        case PXBackupArtifactKindProfileAppData:
+        case PXBackupArtifactKindGlobalSafari:
+        case PXBackupArtifactKindSystemGlobal:
+            return policy.requirement == PXBackupArtifactRequirementOptional &&
+                   policy.failureDisposition ==
+                       PXBackupArtifactFailureDispositionWarnAndContinue &&
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject;
+        case PXBackupArtifactKindSharedSystemDatabase:
+            return policy.requirement == PXBackupArtifactRequirementOptional &&
+                   policy.failureDisposition ==
+                       PXBackupArtifactFailureDispositionContinueWithoutWarning &&
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyAllow;
+        case PXBackupArtifactKindPreferences:
+        case PXBackupArtifactKindKeychain:
+            return policy.requirement == PXBackupArtifactRequirementOptional &&
+                   policy.failureDisposition ==
+                       PXBackupArtifactFailureDispositionContinueWithoutWarning &&
+                   policy.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyReject;
+    }
+    return NO;
+}
+
+static BOOL PXBackupApplyArtifactFailurePolicy(
+    PXBackupArtifactPolicy *policy,
+    NSMutableArray<NSString *> *warnings,
+    NSString * _Nullable warning,
+    NSError * _Nullable fatalError,
+    NSError **fatalErrorOut) {
+    if (fatalErrorOut) {
+        *fatalErrorOut = nil;
+    }
+    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]]) {
+        if (fatalErrorOut) {
+            *fatalErrorOut = PXBackupArtifactPolicyManagerError(
+                @"Backup artifact policy invariant failed");
+        }
+        return NO;
+    }
+    switch (policy.failureDisposition) {
+        case PXBackupArtifactFailureDispositionAbortBackup:
+            if (![fatalError isKindOfClass:[NSError class]] || warning != nil) {
+                if (fatalErrorOut) {
+                    *fatalErrorOut = PXBackupArtifactPolicyManagerError(
+                        @"Backup artifact policy invariant failed");
+                }
+                return NO;
+            }
+            if (fatalErrorOut) {
+                *fatalErrorOut = fatalError;
+            }
+            return NO;
+        case PXBackupArtifactFailureDispositionWarnAndContinue:
+            if (![warnings isKindOfClass:[NSMutableArray class]] ||
+                ![warning isKindOfClass:[NSString class]] ||
+                warning.length == 0 || fatalError != nil) {
+                if (fatalErrorOut) {
+                    *fatalErrorOut = PXBackupArtifactPolicyManagerError(
+                        @"Backup artifact policy invariant failed");
+                }
+                return NO;
+            }
+            [warnings addObject:[warning copy]];
+            return YES;
+        case PXBackupArtifactFailureDispositionContinueWithoutWarning:
+            if (warning != nil || fatalError != nil) {
+                if (fatalErrorOut) {
+                    *fatalErrorOut = PXBackupArtifactPolicyManagerError(
+                        @"Backup artifact policy invariant failed");
+                }
+                return NO;
+            }
+            return YES;
+    }
+    if (fatalErrorOut) {
+        *fatalErrorOut = PXBackupArtifactPolicyManagerError(
+            @"Backup artifact policy invariant failed");
+    }
+    return NO;
+}
+
+static BOOL PXBackupAuditVerifiedArtifactPolicies(
+    NSArray<PXVerifiedBackupArtifact *> *verifiedArtifactRecords,
+    NSArray<PXBackupArtifactPolicy *> *canonicalArtifactPolicies,
+    NSUInteger writerArtifactCount) {
+    if (![verifiedArtifactRecords isKindOfClass:[NSArray class]] ||
+        ![canonicalArtifactPolicies isKindOfClass:[NSArray class]] ||
+        canonicalArtifactPolicies.count != 8 ||
+        verifiedArtifactRecords.count < 1 ||
+        verifiedArtifactRecords.count > 4096 ||
+        writerArtifactCount != verifiedArtifactRecords.count) {
+        return NO;
+    }
+    for (NSUInteger index = 0; index < canonicalArtifactPolicies.count; index++) {
+        PXBackupArtifactKind expectedKind =
+            (PXBackupArtifactKind)(PXBackupArtifactKindApplicationData + index);
+        if (!PXBackupArtifactPolicyMatchesCanonicalKind(
+                canonicalArtifactPolicies[index], expectedKind)) {
+            return NO;
+        }
+    }
+
+    NSUInteger applicationDataCount = 0;
+    NSUInteger requiredCount = 0;
+    NSUInteger profileCount = 0;
+    NSUInteger safariCount = 0;
+    NSUInteger preferencesCount = 0;
+    NSUInteger keychainCount = 0;
+    PXBackupArtifactKind previousKind = 0;
+
+    for (id value in verifiedArtifactRecords) {
+        if (![value isMemberOfClass:[PXVerifiedBackupArtifact class]]) {
+            return NO;
+        }
+        PXVerifiedBackupArtifact *record = value;
+        PXBackupArtifactPolicy *policy = record.policy;
+        if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]] ||
+            policy.kind < PXBackupArtifactKindApplicationData ||
+            policy.kind > PXBackupArtifactKindKeychain) {
+            return NO;
+        }
+        PXBackupArtifactPolicy *canonicalPolicy =
+            canonicalArtifactPolicies[(NSUInteger)policy.kind - 1];
+        if (policy != canonicalPolicy ||
+            ![policy isEqual:canonicalPolicy] ||
+            ![policy acceptsFileSize:record.size] ||
+            policy.kind < previousKind) {
+            return NO;
+        }
+        previousKind = policy.kind;
+        if (policy.requirement == PXBackupArtifactRequirementRequired) {
+            requiredCount += 1;
+        }
+        if (policy.kind == PXBackupArtifactKindApplicationData) {
+            applicationDataCount += 1;
+        } else if (policy.requirement != PXBackupArtifactRequirementOptional) {
+            return NO;
+        }
+        switch (policy.kind) {
+            case PXBackupArtifactKindProfileAppData:
+                profileCount += 1;
+                break;
+            case PXBackupArtifactKindGlobalSafari:
+                safariCount += 1;
+                break;
+            case PXBackupArtifactKindPreferences:
+                preferencesCount += 1;
+                break;
+            case PXBackupArtifactKindKeychain:
+                keychainCount += 1;
+                break;
+            default:
+                break;
+        }
+    }
+
+    PXVerifiedBackupArtifact *firstRecord = verifiedArtifactRecords.firstObject;
+    return applicationDataCount == 1 &&
+           requiredCount == 1 &&
+           firstRecord.policy.kind == PXBackupArtifactKindApplicationData &&
+           firstRecord.policy.requirement == PXBackupArtifactRequirementRequired &&
+           profileCount <= 1 &&
+           safariCount <= 1 &&
+           preferencesCount <= 1 &&
+           keychainCount <= 1;
 }

 static BOOL PXContainerUUIDMatchesBundleID(NSFileManager *fm, NSString *baseDir, NSString *uuid, NSString *bundleID) {
@@ -1598,6 +1786,66 @@
             });
             return;
         }
+        PXBackupArtifactPolicy *applicationDataArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindApplicationData];
+        PXBackupArtifactPolicy *appGroupArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindAppGroup];
+        PXBackupArtifactPolicy *profileAppDataArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindProfileAppData];
+        PXBackupArtifactPolicy *globalSafariArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindGlobalSafari];
+        PXBackupArtifactPolicy *systemGlobalArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindSystemGlobal];
+        PXBackupArtifactPolicy *sharedSystemDatabaseArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindSharedSystemDatabase];
+        PXBackupArtifactPolicy *preferencesArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindPreferences];
+        PXBackupArtifactPolicy *keychainArtifactPolicy =
+            [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindKeychain];
+
+        BOOL policyConstructionValid =
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                applicationDataArtifactPolicy,
+                PXBackupArtifactKindApplicationData) &&
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                appGroupArtifactPolicy,
+                PXBackupArtifactKindAppGroup) &&
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                profileAppDataArtifactPolicy,
+                PXBackupArtifactKindProfileAppData) &&
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                globalSafariArtifactPolicy,
+                PXBackupArtifactKindGlobalSafari) &&
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                systemGlobalArtifactPolicy,
+                PXBackupArtifactKindSystemGlobal) &&
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                sharedSystemDatabaseArtifactPolicy,
+                PXBackupArtifactKindSharedSystemDatabase) &&
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                preferencesArtifactPolicy,
+                PXBackupArtifactKindPreferences) &&
+            PXBackupArtifactPolicyMatchesCanonicalKind(
+                keychainArtifactPolicy,
+                PXBackupArtifactKindKeychain);
+        if (!policyConstructionValid) {
+            NSError *err = PXBackupArtifactPolicyManagerError(
+                @"Backup artifact policy could not be constructed");
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, err);
+            });
+            return;
+        }
+        NSArray<PXBackupArtifactPolicy *> *canonicalArtifactPolicies = @[
+            applicationDataArtifactPolicy,
+            appGroupArtifactPolicy,
+            profileAppDataArtifactPolicy,
+            globalSafariArtifactPolicy,
+            systemGlobalArtifactPolicy,
+            sharedSystemDatabaseArtifactPolicy,
+            preferencesArtifactPolicy,
+            keychainArtifactPolicy,
+        ];
         NSMutableArray<PXVerifiedBackupArtifact *> *groupArtifactRecords =
             [NSMutableArray array];
         NSMutableArray<PXVerifiedBackupArtifact *> *systemGlobalArtifactRecords =
@@ -1673,6 +1921,7 @@
         NSError *dataArtifactError = nil;
         PXVerifiedBackupArtifact *dataArtifactRecord =
             [artifactWriter writeArtifactAtRelativePath:@"data.tar.gz"
+                                                 policy:applicationDataArtifactPolicy
                                                producer:^BOOL(NSString *temporaryOutputPath) {
                 dataTarResult = [self _tarCreate:tarPath
                                          fromDir:dataContainerPath
@@ -1692,7 +1941,24 @@
             NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                code:105
                                            userInfo:@{NSLocalizedDescriptionKey: msg}];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            NSError *fatalPolicyError = nil;
+            BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                applicationDataArtifactPolicy,
+                warnings,
+                nil,
+                err,
+                &fatalPolicyError);
+            if (!shouldContinue) {
+                dispatch_async(dispatch_get_main_queue(), ^{
+                    if (completion) completion(nil, fatalPolicyError ?: err);
+                });
+                return;
+            }
+            NSError *invariantError = PXBackupArtifactPolicyManagerError(
+                @"Backup artifact policy invariant failed");
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, invariantError);
+            });
             return;
         }
         NSString *dataArchivePath = dataArtifactRecord.filePath;
@@ -1738,6 +2004,7 @@
             NSError *groupArtifactError = nil;
             PXVerifiedBackupArtifact *groupArtifact =
                 [artifactWriter writeArtifactAtRelativePath:relativeArchivePath
+                                                     policy:appGroupArtifactPolicy
                                                    producer:^BOOL(NSString *temporaryOutputPath) {
                     groupTarResult = [self _tarCreate:tarPath
                                               fromDir:info.path
@@ -1746,7 +2013,19 @@
                 }
                                                       error:&groupArtifactError];
             if (!groupArtifact) {
-                [warnings addObject:[NSString stringWithFormat:@"Failed to archive group %@ (%@)", info.groupID, info.uuid]];
+                NSError *fatalPolicyError = nil;
+                BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                    appGroupArtifactPolicy,
+                    warnings,
+                    [NSString stringWithFormat:@"Failed to archive group %@ (%@)", info.groupID, info.uuid],
+                    nil,
+                    &fatalPolicyError);
+                if (!shouldContinue) {
+                    dispatch_async(dispatch_get_main_queue(), ^{
+                        if (completion) completion(nil, fatalPolicyError);
+                    });
+                    return;
+                }
                 continue;
             }
             [groupArtifactRecords addObject:groupArtifact];
@@ -1767,6 +2046,7 @@
                 NSError *profileArtifactError = nil;
                 profileArtifactRecord =
                     [artifactWriter writeArtifactAtRelativePath:@"profile_appdata.tar.gz"
+                                                         policy:profileAppDataArtifactPolicy
                                                        producer:^BOOL(NSString *temporaryOutputPath) {
                         profileTarResult = [self _tarCreate:tarPath
                                                    fromDir:profileAppDataPath
@@ -1775,7 +2055,19 @@
                     }
                                                           error:&profileArtifactError];
                 if (!profileArtifactRecord) {
-                    [warnings addObject:@"Failed to archive profile appdata; continuing" ];
+                    NSError *fatalPolicyError = nil;
+                    BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                        profileAppDataArtifactPolicy,
+                        warnings,
+                        @"Failed to archive profile appdata; continuing",
+                        nil,
+                        &fatalPolicyError);
+                    if (!shouldContinue) {
+                        dispatch_async(dispatch_get_main_queue(), ^{
+                            if (completion) completion(nil, fatalPolicyError);
+                        });
+                        return;
+                    }
                 } else {
                     profileAppDataArchivePath = profileArtifactRecord.filePath;
                 }
@@ -1794,6 +2086,7 @@
                     NSError *safariArtifactError = nil;
                     globalSafariArtifactRecord =
                         [artifactWriter writeArtifactAtRelativePath:@"global_safari.tar.gz"
+                                                             policy:globalSafariArtifactPolicy
                                                            producer:^BOOL(NSString *temporaryOutputPath) {
                             safariTarResult = [self _tarCreate:tarPath
                                                       fromDir:globalSafariPath
@@ -1802,7 +2095,19 @@
                         }
                                                               error:&safariArtifactError];
                     if (!globalSafariArtifactRecord) {
-                        [warnings addObject:@"Failed to archive global Safari library; continuing"];
+                        NSError *fatalPolicyError = nil;
+                        BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                            globalSafariArtifactPolicy,
+                            warnings,
+                            @"Failed to archive global Safari library; continuing",
+                            nil,
+                            &fatalPolicyError);
+                        if (!shouldContinue) {
+                            dispatch_async(dispatch_get_main_queue(), ^{
+                                if (completion) completion(nil, fatalPolicyError);
+                            });
+                            return;
+                        }
                     } else {
                         globalSafariArchivePath = globalSafariArtifactRecord.filePath;
                     }
@@ -1820,6 +2125,7 @@
                 NSError *preferencesArtifactError = nil;
                 preferencesArtifactRecord =
                     [artifactWriter writeArtifactAtRelativePath:preferencesRelativePath
+                                                         policy:preferencesArtifactPolicy
                                                        producer:^BOOL(NSString *temporaryOutputPath) {
                         NSString *cpCmd = [NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null",
                             PXShellQuote(prefSourcePath),
@@ -1828,6 +2134,21 @@
                         return copyResult && copyResult.exitCode == 0;
                     }
                                                           error:&preferencesArtifactError];
+                if (!preferencesArtifactRecord) {
+                    NSError *fatalPolicyError = nil;
+                    BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                        preferencesArtifactPolicy,
+                        warnings,
+                        nil,
+                        nil,
+                        &fatalPolicyError);
+                    if (!shouldContinue) {
+                        dispatch_async(dispatch_get_main_queue(), ^{
+                            if (completion) completion(nil, fatalPolicyError);
+                        });
+                        return;
+                    }
+                }
             } else {
                 [warnings addObject:@"Global preferences plist not found (OK for most apps); skipping"];
             }
@@ -1893,6 +2214,7 @@
             NSError *keychainArtifactError = nil;
             keychainArtifactRecord =
                 [artifactWriter writeArtifactAtRelativePath:@"keychain.plist"
+                                                     policy:keychainArtifactPolicy
                                                    producer:^BOOL(NSString *temporaryOutputPath) {
                     BOOL keychainSuccess = [self _backupKeychainForBundleID:bundleID
                                                                     groups:selectedKeychainGroups
@@ -1934,6 +2256,19 @@
             if (keychainArtifactRecord) {
                 keychainBackupPath = keychainArtifactRecord.filePath;
             } else {
+                NSError *fatalPolicyError = nil;
+                BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                    keychainArtifactPolicy,
+                    warnings,
+                    nil,
+                    nil,
+                    &fatalPolicyError);
+                if (!shouldContinue) {
+                    dispatch_async(dispatch_get_main_queue(), ^{
+                        if (completion) completion(nil, fatalPolicyError);
+                    });
+                    return;
+                }
                 keychainBackupPath = nil;
                 keychainMethod = nil;
             }
@@ -1962,6 +2297,7 @@
             NSError *systemArtifactError = nil;
             PXVerifiedBackupArtifact *systemArtifact =
                 [artifactWriter writeArtifactAtRelativePath:archiveName
+                                                     policy:systemGlobalArtifactPolicy
                                                    producer:^BOOL(NSString *temporaryOutputPath) {
                     systemTarResult = [self _tarCreate:tarPath
                                                fromDir:srcPath
@@ -1970,7 +2306,19 @@
                 }
                                                       error:&systemArtifactError];
             if (!systemArtifact) {
-                [warnings addObject:[NSString stringWithFormat:@"Failed to archive system global library %@; continuing", subdir]];
+                NSError *fatalPolicyError = nil;
+                BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                    systemGlobalArtifactPolicy,
+                    warnings,
+                    [NSString stringWithFormat:@"Failed to archive system global library %@; continuing", subdir],
+                    nil,
+                    &fatalPolicyError);
+                if (!shouldContinue) {
+                    dispatch_async(dispatch_get_main_queue(), ^{
+                        if (completion) completion(nil, fatalPolicyError);
+                    });
+                    return;
+                }
                 continue;
             }
             [systemGlobalArtifactRecords addObject:systemArtifact];
@@ -2015,6 +2363,7 @@
                     NSError *sharedArtifactError = nil;
                     PXVerifiedBackupArtifact *sharedArtifact =
                         [artifactWriter writeArtifactAtRelativePath:dstRel
+                                                             policy:sharedSystemDatabaseArtifactPolicy
                                                            producer:^BOOL(NSString *temporaryOutputPath) {
                             NSString *copyCommand = [NSString stringWithFormat:@"cp -a %@ %@ 2>/dev/null",
                                 PXShellQuote(src),
@@ -2029,6 +2378,20 @@
                             @"libraryRel": rel,
                             @"archive": sharedArtifact.relativePath,
                         }];
+                    } else {
+                        NSError *fatalPolicyError = nil;
+                        BOOL shouldContinue = PXBackupApplyArtifactFailurePolicy(
+                            sharedSystemDatabaseArtifactPolicy,
+                            warnings,
+                            nil,
+                            nil,
+                            &fatalPolicyError);
+                        if (!shouldContinue) {
+                            dispatch_async(dispatch_get_main_queue(), ^{
+                                if (completion) completion(nil, fatalPolicyError);
+                            });
+                            return;
+                        }
                     }
                 }
             }
@@ -2061,6 +2424,17 @@
         [verifiedArtifactRecords addObjectsFromArray:sharedDatabaseArtifactRecords];
         if (preferencesArtifactRecord) [verifiedArtifactRecords addObject:preferencesArtifactRecord];
         if (keychainArtifactRecord) [verifiedArtifactRecords addObject:keychainArtifactRecord];
+
+        if (!PXBackupAuditVerifiedArtifactPolicies(verifiedArtifactRecords,
+                                                   canonicalArtifactPolicies,
+                                                   artifactWriter.artifactCount)) {
+            NSError *err = PXBackupArtifactPolicyManagerError(
+                @"Backup artifact policy invariant failed");
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, err);
+            });
+            return;
+        }

         NSMutableArray<NSDictionary<NSString *, id> *> *artifacts =
             [NSMutableArray arrayWithCapacity:verifiedArtifactRecords.count];
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
